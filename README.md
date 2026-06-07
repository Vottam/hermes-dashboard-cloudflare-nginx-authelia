# Hermes Dashboard behind Cloudflare Tunnel, Nginx and Authelia

> Reproducible deployment guide for exposing the Hermes Agent Dashboard with Chat/PTY WebSockets and Kanban behind Cloudflare Tunnel, local Nginx and Authelia, bypassing OpenLiteSpeed/CyberPanel WebSocket failures.

## Status

**PRODUCTION VALIDATED** — Chat/PTY, Kanban, tool calls, and `MODEL: live` were confirmed working through Cloudflare Tunnel.

The final public path avoids OpenLiteSpeed/CyberPanel for this subdomain because OpenLiteSpeed WebSocket proxying was unreliable for the Hermes Dashboard PTY and event streams.

## Problem

The Hermes Agent Dashboard provides:

- Chat
- PTY terminal
- Kanban board
- Tool calls
- Live model status

The original public architecture used OpenLiteSpeed/CyberPanel as the reverse proxy. Normal HTTP requests worked, but WebSocket connections failed repeatedly.

Observed symptoms included:

- `/api/pty` closing with WebSocket `code 1006`
- Kanban event stream disconnects
- Chat sessions ending unexpectedly
- OpenLiteSpeed errors such as `Cannot found WebSocket backend URI: [/api/pty]`

## Why OpenLiteSpeed/CyberPanel Was Bypassed

OpenLiteSpeed required explicit WebSocket context handling and still behaved inconsistently for the Hermes Node.js backend.

Failed approaches included:

- Basic Auth in front of the dashboard
- OpenLiteSpeed WebSocket contexts
- CyberPanel vhost adjustments
- Partial proxy rewrites
- Repeated context-specific WebSocket fixes

The stable solution was to remove OpenLiteSpeed from the public path for this specific subdomain.

## Final Architecture

```text
Browser
  |
  v
Cloudflare Edge
  |
  v
Cloudflare Tunnel / cloudflared
  |
  v
Nginx on 127.0.0.1:4180
  |
  +--> Authelia on 127.0.0.1:9091/portal
  |
  +--> Hermes Dashboard on 127.0.0.1:9119
         |
         +--> /api/pty     WebSocket
         +--> /api/ws      WebSocket
         +--> /api/events  WebSocket / event stream
         +--> /api/*       REST endpoints
```

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
  troubleshooting.md               # Symptom -> cause -> fix
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

MIT — See [LICENSE](LICENSE).

## Credits

Developed through iterative diagnosis on AlmaLinux 9.8 with OpenLiteSpeed/CyberPanel, Hermes Agent, Authelia, and cloudflared. The key insight: OpenLiteSpeed's WebSocket reverse proxy is fundamentally unreliable for Node.js backends — remove it from the path rather than patching around it.
