#!/usr/bin/env bash
set -euo pipefail
PANEL_URL="${1:-}"
NODE_ID="${2:-}"
NODE_TOKEN="${3:-}"
if [[ -z "$PANEL_URL" || -z "$NODE_ID" || -z "$NODE_TOKEN" ]]; then
  echo 'usage: curl -fsSL PANEL_URL/static/install-rathole-agent.sh | bash -s -- PANEL_URL NODE_ID NODE_TOKEN'
  exit 2
fi
install -d -m 0750 /opt/rvg-rathole
curl -fsSL "$PANEL_URL/static/rathole_agent.py" -o /opt/rvg-rathole/rathole_agent.py
chmod 0750 /opt/rvg-rathole/rathole_agent.py
python3 - <<'PY'
import urllib.request, json, os, platform, zipfile
url='https://api.github.com/repos/rathole-org/rathole/releases/tags/v0.5.0'
try:
    arch=platform.machine().lower()
    if arch in ('x86_64','amd64'):
        wanted=['x86_64-unknown-linux-gnu']
    elif arch in ('aarch64','arm64'):
        wanted=['aarch64-unknown-linux-gnu','arm64-unknown-linux-gnu']
    else:
        raise SystemExit(f'unsupported CPU architecture: {arch}')
    data=json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'RVG-Rathole-Agent'}),timeout=20))
    assets=data.get('assets',[])
    asset=next((a for a in assets if any(tag in a.get('name','') for tag in wanted) and a.get('name','').endswith('.zip')),None)
    if not asset:
        raise SystemExit(f'Rathole release asset was not found for architecture: {arch}')
    out='/opt/rvg-rathole/rathole.zip'
    urllib.request.urlretrieve(asset['browser_download_url'], out)
    with zipfile.ZipFile(out) as z:
        member=next((n for n in z.namelist() if n.endswith('/rathole') or n=='rathole'), None)
        if not member: raise SystemExit('rathole binary not found in archive')
        z.extract(member, '/opt/rvg-rathole')
    src='/opt/rvg-rathole/'+member
    os.replace(src,'/opt/rvg-rathole/rathole')
    os.chmod('/opt/rvg-rathole/rathole',0o750)
    os.remove(out)
except Exception as e:
    raise SystemExit(f'install rathole failed: {e}')
PY
cat >/etc/systemd/system/rvg-rathole.service <<EOF
[Unit]
Description=RVG Rathole Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/rvg-rathole/rathole --client /opt/rvg-rathole/client.toml
Restart=always
RestartSec=1
NoNewPrivileges=true
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
cat >/etc/systemd/system/rvg-rathole-agent.service <<EOF
[Unit]
Description=RVG Rathole Panel Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=RVG_PANEL_URL=$PANEL_URL
Environment=RVG_NODE_ID=$NODE_ID
Environment=RVG_NODE_TOKEN=$NODE_TOKEN
Environment=RVG_AGENT_DIR=/opt/rvg-rathole
ExecStart=/usr/bin/python3 /opt/rvg-rathole/rathole_agent.py
Restart=always
RestartSec=2
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now rvg-rathole-agent.service
systemctl enable rvg-rathole.service
printf '\nAgent installed. The panel will now manage the Rathole client configuration.\n'
