import json
import re
import sqlite3
import sys

RADARR = "/tank/services/radarr"

with open(f"{RADARR}/config.xml") as f:
    api_key = re.search(r"<ApiKey>([^<]+)</ApiKey>", f.read()).group(1)

con = sqlite3.connect(f"file:{RADARR}/radarr.db?mode=ro", uri=True)
row = con.execute(
    "select Settings from DownloadClients where Implementation = 'QBittorrent'"
).fetchone()
if row is None:
    sys.exit("qBittorrent download client is not configured in Radarr")
settings = json.loads(row[0])

print(json.dumps({
    "radarr_api_key": api_key,
    "qbittorrent_username": settings["username"],
    "qbittorrent_password": settings["password"],
}))
