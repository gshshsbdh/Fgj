FROM python:3.11-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 RATHOLE_ENABLE_SERVER=1 RATHOLE_BIN=/usr/local/bin/rathole
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN python - <<'PY'
import json, os, pathlib, urllib.request, zipfile
version = os.environ.get('RATHOLE_VERSION','v0.5.0')
url=f'https://api.github.com/repos/rathole-org/rathole/releases/tags/{version}'
req=urllib.request.Request(url, headers={'User-Agent':'RVG-Rathole-Builder'})
data=json.load(urllib.request.urlopen(req, timeout=30))
asset=next((a for a in data.get('assets',[]) if 'x86_64-unknown-linux-gnu' in a.get('name','')), None)
if not asset:
    raise SystemExit('Rathole x86_64 Linux asset not found')
archive='/tmp/rathole.zip'
urllib.request.urlretrieve(asset['browser_download_url'], archive)
with zipfile.ZipFile(archive) as z:
    member=next((n for n in z.namelist() if n == 'rathole' or n.endswith('/rathole')), None)
    if not member: raise SystemExit('rathole binary missing')
    data=z.read(member)
pathlib.Path('/usr/local/bin/rathole').write_bytes(data)
pathlib.Path('/usr/local/bin/rathole').chmod(0o755)
os.unlink(archive)
PY
COPY . .
RUN chmod +x install-rathole-agent.sh rathole_agent.py
CMD ["python", "main.py"]
