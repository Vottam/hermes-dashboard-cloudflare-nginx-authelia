# Troubleshooting Guide

## Chat / PTY Issues

### `[session ended (code 1006)]`

**Meaning:** WebSocket connection was established but closed abnormally.

**Causes:**
1. Proxy in the path doesn't support WebSocket (most common)
2. Backend crashed
3. `MemoryDenyWriteExecute=true` causing V8 crash

**Diagnosis:**
```bash
systemctl is-active hermes-dashboard.service
journalctl -u hermes-dashboard.service | grep -i "v8\|fatal\|crash\|coredump"
systemctl show hermes-dashboard.service --property=MemoryDenyWriteExecute
# Expected: MemoryDenyWriteExecute=false
curl -s http://127.0.0.1:9119/api/status
curl -s http://127.0.0.1:4180/api/status
```

**Fix:** Ensure Cloudflare Tunnel is active and DNS points to Cloudflare.

---

### `events feed disconnected`

**Meaning:** Kanban WebSocket connection was lost.

**Causes:**
1. Same as code 1006 — proxy doesn't support WebSocket
2. Network interruption
3. Dashboard service restart

**Diagnosis:**
```bash
journalctl -u cloudflared | grep "Registered tunnel connection"
tail -f /var/log/nginx/access.log | grep "api/events"
```

---

### `WebSocket connection failed`

**Meaning:** WebSocket connection could not be established at all.

**Causes:**
1. DNS still pointing to server IP (not Cloudflare)
2. cloudflared service not running
3. Nginx not running

**Diagnosis:**
```bash
dig +short hermes.example.com
# Expected: Cloudflare IPs (104.x.x.x, 172.x.x.x), NOT server IP
systemctl is-active cloudflared
systemctl is-active nginx
```

---

### `Cannot found WebSocket backend URI`

**Meaning:** OpenLiteSpeed could not route the WebSocket request.

**Cause:** OLS limitation — this error is unfixable in OLS.

**Fix:** Use Cloudflare Tunnel to bypass OLS entirely.

---

## Dashboard Startup Issues

### `V8_Fatal SetPermissionsOnExecutableMemoryChunk`

**Meaning:** Node.js crashed because V8 JIT couldn't allocate executable memory.

**Fix:**
```bash
cat > /etc/systemd/system/hermes-dashboard.service.d/20-node-execmem-fix.conf << 'EOF'
[Service]
MemoryDenyWriteExecute=false
EOF
systemctl daemon-reload
systemctl restart hermes-dashboard.service
```

---

### `npm install` crash / dashboard won't start

**Meaning:** Dashboard is trying to build TUI from source.

**Fix:**
```bash
cat > /etc/systemd/system/hermes-dashboard.service.d/10-tui-dir.conf << 'EOF'
[Service]
Environment=HERMES_TUI_DIR=/opt/hermes-agent/ui-tui
EOF
systemctl daemon-reload
systemctl restart hermes-dashboard.service
```

---

### White screen on dashboard

**Meaning:** React render error, usually from a bad frontend patch.

**Fix:** Revert the offending frontend patch and rebuild.

---

## Authelia Issues

### Authelia 401 loop (redirect cycle)

**Meaning:** Browser can't establish Authelia session.

**Causes:**
1. `X-Forwarded-Proto` not set to `https` in Nginx
2. Cookie `Secure: true` but Nginx serves HTTP
3. `authelia_url` mismatch

**Fix:** Ensure `proxy_set_header X-Forwarded-Proto https;` is set in all Nginx locations that proxy to Authelia.

---

### Basic Auth loop

**Meaning:** Browser keeps asking for credentials.

**Cause:** Don't use Basic Auth with the dashboard. Use Authelia instead.

**Fix:** Remove Basic Auth from Nginx config, use `auth_request` with Authelia.

---

## Cloudflare Tunnel Issues

### `active_sessions: 0` in dashboard

**Meaning:** Dashboard is running but no chat sessions are active.

**Causes:**
1. No one has sent a message yet
2. WebSocket not working (check tunnel)
3. Gateway not running

**Diagnosis:**
```bash
curl -s http://127.0.0.1:9119/api/status | python3 -m json.tool
systemctl is-active cloudflared
```

---

### HTTP 101 but connection closes immediately

**Meaning:** WebSocket upgrade succeeded but the persistent connection is not stable.

**Causes:**
1. Proxy timeout too short
2. Backend crashing
3. Network instability

**Diagnosis:**
```bash
grep "proxy_read_timeout" /etc/nginx/conf.d/
journalctl -u hermes-dashboard.service --since "5 minutes ago"
```

---

## 502 Bad Gateway on Nginx

**Meaning:** Nginx can't reach the backend.

**Causes:**
1. Dashboard service not running
2. Wrong port in `proxy_pass`
3. Firewall blocking localhost

**Diagnosis:**
```bash
systemctl is-active hermes-dashboard.service
curl -s http://127.0.0.1:9119/api/status
grep "proxy_pass" /etc/nginx/conf.d/hermes-dashboard.conf
```

---

## 401/403 on Authelia

**Meaning:** Authelia is blocking access.

**Causes:**
1. Session expired
2. Wrong credentials
3. Access control policy too restrictive

**Diagnosis:**
```bash
journalctl -u authelia --since "5 minutes ago"
grep -A 10 "access_control" /etc/authelia/*/configuration.yml
```

---

## Kanban Opens but Chat/PTY Fails

**Meaning:** Kanban works but chat doesn't.

**Causes:**
1. Kanban uses polling fallback, chat needs WebSocket
2. `/api/pty` endpoint specifically broken
3. Different auth requirements

**Fix:** Check WebSocket path specifically. Kanban may work via polling while chat needs persistent WebSocket.

---

## Cloudflare Tunnel Active but Backend Doesn't Respond

**Meaning:** Tunnel is up, but Nginx/backend is unreachable.

**Diagnosis:**
```bash
# Check cloudflared can reach Nginx
curl -s http://127.0.0.1:4180/
# Check Nginx can reach dashboard
curl -s http://127.0.0.1:9119/api/status
# Check cloudflared logs
journalctl -u cloudflared --since "5 minutes ago" | grep -i "error\|fail"
```
