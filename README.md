# Hermes Dashboard behind Cloudflare Tunnel, Nginx and Authelia

> Reproducible deployment guide for exposing the Hermes Agent Dashboard with Chat/PTY WebSockets and Kanban behind Cloudflare Tunnel, local Nginx and Authelia, bypassing OpenLiteSpeed/CyberPanel WebSocket failures.

## Status

**PRODUCTION VALIDATED** — Chat/PTY, Kanban, tool calls, and MODEL: live all confirmed working via browser through Cloudflare Tunnel. No WebSocket `code 1006`.

## Problem

The Hermes Agent Dashboard (chat, PTY terminal, Kanban board) was inaccessible via the public internet. The original architecture used OpenLiteSpeed/CyberPanel as the public-facing reverse proxy on port 443, forwarding to the Hermes Dashboard on `127.0.0.1:9119`. While HTTP requests worked, **WebSocket connections consistently failed** — the chat showed `[session ended (code 1006)]`, the Kanban events feed disconnected, and `/api/pty` never established a persistent connection.

## Why OpenLiteSpeed/CyberPanel Was Bypassed

OpenLiteSpeed (OLS) has fundamental limitations with WebSocket reverse proxying to Node.js backends:

1. **`extprocessor websocket 1` is required but insufficient** — OLS needs explicit context rules for each WebSocket path, and even then the upgrade handshake is unreliable
2. **`Cannot found WebSocket backend URI`** — OLS cannot reliably match WebSocket upgrade requests to backends
3. **Inconsistent behavior** — connections sometimes return 404, sometimes 101 then immediate close
4. **CyberPanel auto-regeneration** overwrites manual OLS vhost fixes

After 15+ diagnostic iterations, the conclusion was to remove OLS from the path entirely.

## Final Architecture

```
Browser (HTTPS)
    │
    ▼
Cloudflare Edge (TLS termination + WAF)
    │
    ▼  QUIC (4 connections)
cloudflared service (systemd)
    │
    ▼  HTTP local
Nginx 127.0.0.1:4180
    │
    ├── /portal ──► Authelia 127.0.0.1:9091/portal (auth)
    │
    └── / ────────► Hermes Dashboard 127.0.0.1:9119
                     ├── /api/pty    (WebSocket — chat terminal)
                     ├── /api/ws     (WebSocket — gateway events)
                     ├── /api/events (WebSocket — kanban events)
                     └── /api/*      (REST — status, config, etc.)
```

**Key point:** OpenLiteSpeed is completely out of the path. DNS CNAME points to Cloudflare, not to the server IP.

## Components

| Component | Role | Bind |
|-----------|------|------|
| Cloudflare Edge | TLS termination, WAF, WebSocket | Public |
| cloudflared | Tunnel client (QUIC) | Outbound only |
| Nginx | Local reverse proxy, auth_request | 127.0.0.1:4180 |
| Authelia | SSO authentication | 127.0.0.1:9091/portal |
| Hermes Dashboard | Chat, PTY, Kanban, tool calls | 127.0.0.1:9119 |

## Quick Start

1. **Systemd fixes** (required before anything):
   ```bash
   mkdir -p /etc/systemd/system/hermes-dashboard.service.d
   cat > /etc/systemd/system/hermes-dashboard.service.d/10-tui-dir.conf << 'EOF'
   [Service]
   Environment=HERMES_TUI_DIR=/opt/hermes-agent/ui-tui
   EOF
   cat > /etc/systemd/system/hermes-dashboard.service.d/20-node-execmem-fix.conf << 'EOF'
   [Service]
   MemoryDenyWriteExecute=false
   EOF
   systemctl daemon-reload
   systemctl restart hermes-dashboard.service
   ```

2. **Nginx + Authelia** — see [examples/nginx/](examples/nginx/) and [examples/authelia/](examples/authelia/)

3. **Cloudflare Tunnel** — see [examples/cloudflared/](examples/cloudflared/)

4. **Validate** — see [docs/validation-checklist.md](docs/validation-checklist.md)

## Repository Structure

```
README.md                          # This file
REPO-METADATA.md                   # Keywords, tags, metadata
.gitignore                         # Excludes secrets, credentials, logs
docs/
  architecture.md                  # Detailed architecture
  deployment-guide.md              # Step-by-step setup
  kanban.md                        # Kanban-specific notes
  litespeed-bypass.md              # Why OLS was bypassed
  security.md                      # Security considerations
  troubleshooting.md               # Symptom → cause → fix
  validation-checklist.md          # Post-deployment verification
  root-causes.md                   # Root cause analysis
  failed-approaches.md             # What didn't work
  lessons-learned.md               # Key takeaways
  timeline.md                      # Chronological sequence
  do-not-publish-checklist.md      # Pre-publish security checklist
examples/
  nginx/hermes-dashboard.conf      # Nginx config (sanitized)
  cloudflared/config.yml           # cloudflared config (sanitized)
  authelia/access-control-fragment.yml  # Authelia ACL (sanitized)
  systemd/hermes-dashboard.service.d-override.conf  # systemd drop-ins
scripts/
  check-local-stack.sh             # Validate local services
  check-public-endpoint.sh         # Validate public endpoint
  scan-for-secrets.sh              # Pre-publish secret scanner
.github/workflows/
  lint.yml                         # CI: shell check + secret scan
```

## Minimal Validation

```bash
# Local stack
./scripts/check-local-stack.sh

# Public endpoint
./scripts/check-public-endpoint.sh https://hermes-kvm4.example.com

# Secret scan (before publishing)
./scripts/scan-for-secrets.sh .
```

## Troubleshooting (Summary)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `code 1006` | WebSocket proxy broken | Use Cloudflare Tunnel |
| `V8_Fatal` crash | `MemoryDenyWriteExecute=true` | Set `=false` |
| `npm install` crash | `HERMES_TUI_DIR` not set | Set TUI dir path |
| Authelia 401 loop | Cookie/headers | Check `X-Forwarded-Proto https` |
| `Cannot found WebSocket backend URI` | OLS limitation | Bypass OLS |
| White screen | React hooks error | Revert bad frontend patches |

See [docs/troubleshooting.md](docs/troubleshooting.md) for full guide.

## Security and Sanitization

- **Never publish:** API tokens, tunnel credentials JSON, cert.pem, passwords, session tokens, real domains, real IPs
- All configs in this repo use `example.com` placeholders
- Run `scripts/scan-for-secrets.sh` before publishing
- See [docs/do-not-publish-checklist.md](docs/do-not-publish-checklist.md)

## Documentation Links

- [Architecture](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Root Causes](docs/root-causes.md)
- [Failed Approaches](docs/failed-approaches.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Security](docs/security.md)
- [Validation Checklist](docs/validation-checklist.md)
- [Lessons Learned](docs/lessons-learned.md)

## License

MIT — See [LICENSE](LICENSE) (add your preferred license file).

## Credits

Developed through iterative diagnosis on AlmaLinux 9.8 with OpenLiteSpeed/CyberPanel, Hermes Agent v0.16.0, Authelia v4.39.20, and cloudflared 2026.5.2. The key insight: OpenLiteSpeed's WebSocket reverse proxy is fundamentally unreliable for Node.js backends — remove it from the path rather than patching around it.
