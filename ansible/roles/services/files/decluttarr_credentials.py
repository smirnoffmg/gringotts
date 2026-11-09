import json
import re
import sqlite3
import sys

RADARR = "/tank/services/radarr"
SONARR = "/tank/services/sonarr"


def api_key(service_dir):
    with open(f"{service_dir}/config.xml") as f:
        return re.search(r"<ApiKey>([^<]+)</ApiKey>", f.read()).group(1)


con = sqlite3.connect(f"file:{RADARR}/radarr.db?mode=ro", uri=True)
row = con.execute(
    "select Settings from DownloadClients where Implementation = 'QBittorrent'"
).fetchone()
if row is None:
    sys.exit("qBittorrent download client is not configured in Radarr")
settings = json.loads(row[0])

print(json.dumps({
    "radarr_api_key": api_key(RADARR),
    "sonarr_api_key": api_key(SONARR),
    "qbittorrent_username": settings["username"],
    "qbittorrent_password": settings["password"],
}))
