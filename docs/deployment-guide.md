# Deployment Guide — Cloudflare Tunnel + Nginx + Authelia

## Prerequisites

- AlmaLinux 9 / RHEL 9 / compatible
- Hermes Agent installed at `/opt/hermes-agent`
- Node.js v22+
- Nginx installed
- Authelia v4.39+ installed
- Cloudflare account with managed zone
- Cloudflare API token: `Zone DNS Edit` + `Account Cloudflare Tunnel Edit`

## Step 1: Systemd Fixes (Required Before Anything Else)

### 1a. HERMES_TUI_DIR

```bash
mkdir -p /etc/systemd/system/hermes-dashboard.service.d
cat > /etc/systemd/system/hermes-dashboard.service.d/10-tui-dir.conf << 'EOF'
[Service]
Environment=HERMES_TUI_DIR=/opt/hermes-agent/ui-tui
EOF
```

### 1b. MemoryDenyWriteExecute

```bash
cat > /etc/systemd/system/hermes-dashboard.service.d/20-node-execmem-fix.conf << 'EOF'
[Service]
MemoryDenyWriteExecute=false
EOF
```

### 1c. Reload and restart

```bash
systemctl daemon-reload
systemctl restart hermes-dashboard.service
systemctl is-active hermes-dashboard.service
```

## Step 2: Nginx + Authelia (Local Proxy)

Nginx listens on `127.0.0.1:4180` and routes:
- `/portal` → Authelia `127.0.0.1:9091` (public, no auth)
- `/` → Hermes Dashboard `127.0.0.1:9119` (protected by Authelia `auth_request`)
- `/api/*` → Hermes Dashboard with WebSocket upgrade headers

See [examples/nginx/hermes-dashboard.conf](../examples/nginx/hermes-dashboard.conf) for full config.

See [examples/authelia/access-control-fragment.yml](../examples/authelia/access-control-fragment.yml) for Authelia ACL.

## Step 3: Install cloudflared

```bash
curl -fsSL -o /usr/local/bin/cloudflared \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /usr/local/bin/cloudflared
cloudflared --version
```

## Step 4: Create Tunnel (Non-Interactive via API)

```python
import requests, json, os

token = "YOUR_CLOUDFLARE_API_TOKEN"
account_id = "YOUR_ACCOUNT_ID"
zone_id = "YOUR_ZONE_ID"
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

# Create tunnel
resp = requests.post(
    f"https://api.cloudflare.com/client/v4/accounts/{account_id}/cfd_tunnel",
    headers=headers,
    json={"name": "hermes-dashboard", "tunnel_type": "cfd_tunnel"}
)
tunnel = resp.json()["result"]
tunnel_id = tunnel["id"]

# Save credentials
os.makedirs("/root/.cloudflared", exist_ok=True)
with open(f"/root/.cloudflared/{tunnel_id}.json", "w") as f:
    json.dump(tunnel["credentials_file"], f)
os.chmod(f"/root/.cloudflared/{tunnel_id}.json", 0o600)
```

## Step 5: Create cloudflared Config

See [examples/cloudflared/config.yml](../examples/cloudflared/config.yml).

```bash
chmod 600 /etc/cloudflared/config.yml
cloudflared tunnel --config /etc/cloudflared/config.yml ingress validate
```

## Step 6: Route DNS

```python
# Delete existing A record, create CNAME
requests.delete(
    f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{a_record_id}",
    headers=headers
)
requests.post(
    f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
    headers=headers,
    json={
        "type": "CNAME",
        "name": "hermes",
        "content": f"{tunnel_id}.cfargotunnel.com",
        "proxied": True,
        "ttl": 1
    }
)
```

## Step 7: Install and Start Service

```bash
cloudflared service install
systemctl daemon-reload
systemctl enable --now cloudflared
systemctl is-active cloudflared
```

## Step 8: Validate

```bash
# DNS resolves to Cloudflare
dig +short hermes.example.com
# Expected: 104.x.x.x or 172.x.x.x (Cloudflare anycast)

# cloudflared has active connections
journalctl -u cloudflared | grep "Registered tunnel connection"
# Expected: 4 connections with protocol=quic

# Nginx receives traffic
tail -f /var/log/nginx/access.log
# Expected: requests from 127.0.0.1

# Browser test: open https://hermes.example.com/chat
# Expected: Authelia login → Dashboard → Chat with MODEL: live
```

## Rollback

If the tunnel breaks access:

```bash
# Stop tunnel
systemctl stop cloudflared
systemctl disable cloudflared

# Restore DNS (create A record pointing to server IP)
# Via Cloudflare API or dashboard:
# A hermes → SERVER_IP (DNS only, not proxied)
```

Do NOT delete the tunnel in Cloudflare without authorization.
