# Repository Metadata

## Repository

- **Name:** `hermes-dashboard-cloudflare-nginx-authelia`
- **Title:** Hermes Dashboard behind Cloudflare Tunnel, Nginx and Authelia
- **Description:** Reproducible deployment guide for exposing the Hermes Agent Dashboard with Chat/PTY WebSockets and Kanban behind Cloudflare Tunnel, local Nginx and Authelia, bypassing OpenLiteSpeed/CyberPanel WebSocket failures.
- **License:** MIT
- **Status:** Production validated

## Keywords / Tags

### Primary
```
hermes-agent
hermes-dashboard
cloudflare-tunnel
cloudflared
authelia
nginx
reverse-proxy
websocket
```

### Technology
```
openlitespeed
cyberpanel
code-1006
systemd
node-js
react
kanban
dashboard
almalinux
rhel9
pty
```

### Problem
```
SetPermissionsOnExecutableMemoryChunk
MemoryDenyWriteExecute
V8_Fatal
npm-install-crash
events-feed-disconnected
session-ended-1006
websocket-connection-failed
cannot-found-websocket-backend-uri
```

### Solution
```
cloudflare-tunnel-websocket
authelia-sso
nginx-reverse-proxy
systemd-drop-in
tui-dir-fix
execmem-fix
```

## Full Search String

```
hermes-agent cloudflare-tunnel authelia nginx websocket pty code-1006
openlitespeed cyberpanel reverse-proxy SetPermissionsOnExecutableMemoryChunk
MemoryDenyWriteExecute V8_Fatal hermes-dashboard kanban
```

## Target Audience

- DevOps engineers deploying Hermes Agent Dashboard
- System administrators troubleshooting WebSocket proxy issues
- Anyone using OpenLiteSpeed/CyberPanel with Node.js backends
- Cloudflare Tunnel users needing WebSocket support

## Related Technologies

| Technology | Version Used | Role |
|-----------|-------------|------|
| Hermes Agent | 0.16.0 | Dashboard backend |
| Authelia | 4.39.20 | SSO authentication |
| cloudflared | 2026.5.2 | Tunnel client |
| Nginx | 1.24+ | Local reverse proxy |
| Node.js | 22.x | Dashboard runtime |
| OpenLiteSpeed | 1.7.x | Bypassed (was causing issues) |
| CyberPanel | 2.3.x | Bypassed (was causing issues) |
| AlmaLinux | 9.8 | Host OS |
