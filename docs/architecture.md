# Architecture — Hermes Dashboard + Cloudflare Tunnel

## Final Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET                                  │
│                                                                  │
│  Browser (HTTPS)                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  https://hermes-kvm4.example.com/chat                     │   │
│  │  TLS 1.3, HTTP/2, WebSocket                               │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUDFLARE EDGE                               │
│                                                                  │
│  • TLS termination (Universal SSL cert)                          │
│  • WAF / DDoS protection                                         │
│  • WebSocket support (native)                                    │
│  • Anycast routing                                               │
│                                                                  │
│  DNS: hermes-kvm4.example.com → CNAME → TUNNEL_UUID.cfargotunnel.com
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼  QUIC (UDP 443), 4 connections
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUDFLARED (systemd)                         │
│                                                                  │
│  /usr/local/bin/cloudflared                                      │
│  Config: /etc/cloudflared/config.yml                             │
│  Creds:  /root/.cloudflared/TUNNEL_UUID.json                    │
│                                                                  │
│  • Maintains persistent QUIC connections to Cloudflare           │
│  • Forwards ingress traffic to local services                    │
│  • No public ports opened (outbound-only)                        │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                           ▼  HTTP (127.0.0.1:4180)
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX (127.0.0.1:4180)                        │
│                                                                  │
│  • Local reverse proxy (not exposed to internet)                 │
│  • Routes /portal to Authelia                                    │
│  • Routes / to Hermes Dashboard                                  │
│  • Handles WebSocket upgrade headers (Upgrade, Connection)       │
│  • auth_request for Authelia validation                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  location /portal  →  proxy_pass 127.0.0.1:9091         │    │
│  │  location /        →  auth_request /authelia             │    │
│  │                      proxy_pass 127.0.0.1:9119          │    │
│  │  location /api/*   →  WebSocket headers + proxy_pass     │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────┬───────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
┌──────────────────────┐  ┌───────────────────────────────────────┐
│  AUTHELIA            │  │  HERMES DASHBOARD                     │
│  127.0.0.1:9091      │  │  127.0.0.1:9119                       │
│                      │  │                                       │
│  • SSO login form    │  │  • Chat (WebSocket /api/pty)          │
│  • Session cookies   │  │  • Kanban (WebSocket /api/events)     │
│  • JWT validation    │  │  • Gateway status (/api/status)       │
│  • /portal subpath   │  │  • Tool calls (REST /api/tools)       │
│                      │  │  • Node.js v22 + React frontend       │
└──────────────────────┘  └───────────────────────────────────────┘
```

## Why This Architecture Works

### Why port 4180 (Nginx) and not 9119 (Dashboard) directly?

- Nginx handles WebSocket upgrade headers (`Upgrade: websocket`, `Connection: upgrade`)
- Nginx provides `auth_request` integration with Authelia
- Nginx buffers and proxies correctly for both HTTP and WebSocket
- Dashboard on 9119 is HTTP-only (no TLS), Nginx adds the protocol layer

### Why Authelia was preserved

- Authelia provides proper SSO with session management
- Form-based login is more user-friendly than Basic Auth
- Session cookies + JWT provide secure authentication
- `/portal` subpath keeps auth separate from app routes

### Why LiteSpeed was removed

- OpenLiteSpeed has unreliable WebSocket reverse proxy support
- `Cannot found WebSocket backend URI` errors were unfixable
- CyberPanel auto-regeneration could overwrite manual fixes
- Cloudflare Tunnel eliminates the need for a public-facing proxy entirely

### How Cloudflare Tunnel solves WebSocket

- Cloudflare Edge natively supports WebSocket (HTTP 101 Switching Protocols)
- `cloudflared` maintains persistent QUIC connections to Cloudflare
- Ingress rules forward WebSocket requests to local Nginx
- Nginx handles the actual WebSocket upgrade to the dashboard
- No public port 4180 needed — cloudflared connects outbound-only

## Port Summary

| Service | Bind | Public | Protocol |
|---------|------|--------|----------|
| cloudflared metrics | 127.0.0.1:20241 | No | HTTP |
| Nginx | 127.0.0.1:4180 | No | HTTP |
| Authelia | 127.0.0.1:9091 | No | HTTP |
| Hermes Dashboard | 127.0.0.1:9119 | No | HTTP |
| cloudflared tunnel | outbound only | No | QUIC |

## Security Layers

1. **Cloudflare Edge**: TLS, WAF, DDoS protection, bot detection
2. **Cloudflare Tunnel**: No public ports, authenticated origin
3. **Authelia**: SSO authentication, session management
4. **Nginx**: Local-only, auth_request validation
5. **Dashboard**: Trusted hosts validation, token-based sessions
