"""Copy embedded SRT tracks out of MKVs into Plex sidecar files.

Plex for PS5 stalls on embedded SRT: the subtitle stream from the transcoder
times out, the client re-requests it, and Plex kills and restarts the
transcoder every few seconds. Sidecar .srt files are served as plain files.
"""
import glob
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

MEDIA_ROOTS = {"/tank/media/tv": "/tv", "/tank/media/movies": "/movies"}
PLEX_URL = "http://127.0.0.1:32400"
PLEX_PREFS = "/tank/services/plex/Library/Application Support/Plex Media Server/Preferences.xml"
STATE_FILE = Path(os.environ.get("STATE_DIRECTORY", "/var/lib/plex-subtitles")) / "state.json"
# Sonarr/Radarr copy files across datasets; a file this fresh may still be growing.
SETTLE_SECONDS = 300
ISO_639_1 = {"eng": "en", "rus": "ru", "ger": "de", "deu": "de", "fre": "fr", "fra": "fr",
             "spa": "es", "ita": "it", "por": "pt", "ukr": "uk", "jpn": "ja"}


def sidecar_suffix(stream):
    tags = stream.get("tags", {})
    disposition = stream.get("disposition", {})
    title = tags.get("title", "").lower()
    language = tags.get("language", "und")
    if disposition.get("forced") or "forced" in title:
        return f"{language}.forced"
    if disposition.get("hearing_impaired") or "sdh" in title:
        return f"{language}.sdh"
    return language


def equivalent_names(stem, suffix):
    language, _, flag = suffix.partition(".")
    tail = f".{flag}" if flag else ""
    codes = {language, ISO_639_1.get(language, language)}
    return {f"{stem}.{code}{tail}.srt" for code in codes}


def plan_extraction(stem, streams, existing_names):
    taken = set(existing_names)
    plan = []
    for stream in streams:
        if stream.get("codec_name") != "subrip":
            continue
        suffix = sidecar_suffix(stream)
        if equivalent_names(stem, suffix) & taken:
            continue
        name = f"{stem}.{suffix}.srt"
        taken.add(name)
        plan.append((stream["index"], name))
    return plan


def is_sdh(plex_stream):
    return plex_stream.get("hearingImpaired") == "1" or "sdh" in (plex_stream.get("title") or "").lower()


def is_forced(plex_stream):
    return plex_stream.get("forced") == "1" or "forced" in (plex_stream.get("title") or "").lower()


def external_replacement(subtitle_streams):
    selected = next((s for s in subtitle_streams if s.get("selected") == "1"), None)
    if selected is None or selected.get("key"):
        return None
    for s in subtitle_streams:
        if (s.get("key") and s.get("languageCode") == selected.get("languageCode")
                and is_sdh(s) == is_sdh(selected) and is_forced(s) == is_forced(selected)):
            return s.get("id")
    return None


def container_path(host_path):
    for host_root, plex_root in MEDIA_ROOTS.items():
        if host_path.startswith(host_root + "/"):
            return plex_root + host_path[len(host_root):]
    return None


def probe_subtitles(video):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "s", "-of", "json",
         "-show_entries", "stream=index,codec_name:stream_tags:stream_disposition", str(video)],
        capture_output=True, text=True, check=True).stdout
    return json.loads(out).get("streams", [])


def extract(video, plan):
    outputs = []
    for index, name in plan:
        partial = video.parent / f"{name}.part"
        outputs += ["-map", f"0:{index}", "-c:s", "copy", "-f", "srt", str(partial)]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), *outputs], check=True)
    for _, name in plan:
        os.replace(video.parent / f"{name}.part", video.parent / name)


def remove_sidecars(folder, names):
    for name in names:
        (folder / name).unlink(missing_ok=True)


def sync_sidecars(state, now):
    changed = []
    for root in MEDIA_ROOTS:
        for video in Path(root).rglob("*.mkv"):
            key = str(video)
            mtime = video.stat().st_mtime
            entry = state.get(key)
            if now - mtime < SETTLE_SECONDS or (entry and entry["mtime"] == mtime):
                continue
            if entry:
                remove_sidecars(video.parent, entry["sidecars"])
            existing = {p.name for p in video.parent.glob(f"{glob.escape(video.stem)}.*.srt")}
            try:
                plan = plan_extraction(video.stem, probe_subtitles(video), existing)
                if plan:
                    extract(video, plan)
            except subprocess.CalledProcessError as e:
                print(f"FAILED {video}: {e}", file=sys.stderr)
                continue
            for _, name in plan:
                print(f"extracted {video.parent / name}")
            state[key] = {"mtime": mtime, "sidecars": [name for _, name in plan],
                          "has_external": bool(existing or plan), "pending_refresh": bool(plan)}
            changed.append(key)
    for key in [k for k in state if not Path(k).exists()]:
        remove_sidecars(Path(key).parent, state.pop(key)["sidecars"])
        print(f"removed sidecars of deleted {key}")
    return changed


class Plex:
    def __init__(self):
        self.token = re.search(r'PlexOnlineToken="([^"]+)"', Path(PLEX_PREFS).read_text()).group(1)

    def call(self, path, method="GET", **params):
        params["X-Plex-Token"] = self.token
        req = urllib.request.Request(f"{PLEX_URL}{path}?{urllib.parse.urlencode(params)}", method=method)
        with urllib.request.urlopen(req, timeout=30) as r:
            body = r.read()
        return ET.fromstring(body) if body.strip() else None

    def items_by_file(self):
        items = {}
        for section in self.call("/library/sections").iter("Directory"):
            item_type = {"movie": 1, "show": 4}.get(section.get("type"))
            if item_type is None:
                continue
            for video in self.call(f"/library/sections/{section.get('key')}/all", type=item_type).iter("Video"):
                for part in video.iter("Part"):
                    items[part.get("file")] = video.get("ratingKey")
        return items


def sync_plex(state):
    plex = Plex()
    items = plex.items_by_file()
    for key, entry in state.items():
        rating_key = items.get(container_path(key))
        if not entry["has_external"] or rating_key is None:
            continue
        if entry.get("pending_refresh"):
            plex.call(f"/library/metadata/{rating_key}/refresh", method="PUT")
            entry["pending_refresh"] = False
            print(f"refreshed {key}")
            continue
        part = plex.call(f"/library/metadata/{rating_key}").find(".//Part")
        subtitles = [s for s in part.iter("Stream") if s.get("streamType") == "3"]
        replacement = external_replacement(subtitles)
        if replacement:
            plex.call(f"/library/parts/{part.get('id')}", method="PUT", subtitleStreamID=replacement)
            print(f"selected external subtitle {replacement} for {key}")


def main():
    state = json.loads(STATE_FILE.read_text()) if STATE_FILE.exists() else {}
    try:
        sync_sidecars(state, time.time())
    finally:
        STATE_FILE.write_text(json.dumps(state, indent=1))
    try:
        sync_plex(state)
    finally:
        STATE_FILE.write_text(json.dumps(state, indent=1))


if __name__ == "__main__":
    main()
