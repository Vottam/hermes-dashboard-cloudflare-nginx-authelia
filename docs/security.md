# Security Notes

## Threat Model

This architecture assumes the following threats:

1. **Unauthorized access to dashboard** — Mitigated by Authelia SSO
2. **WebSocket hijacking** — Mitigated by TLS (Cloudflare edge) + session tokens
3. **DDoS / brute force** — Mitigated by Cloudflare WAF + Authelia rate limiting
4. **Man-in-the-middle** — Mitigated by TLS everywhere (edge to browser)
5. **Credential theft** — Mitigated by no public ports, tunnel-only access

## Security Layers

### Layer 1: Cloudflare Edge
- TLS 1.3 termination
- WAF rules
- DDoS protection
- Bot detection
- Rate limiting (optional)

### Layer 2: Cloudflare Tunnel
- No public ports opened on the server
- Outbound-only connections (QUIC to Cloudflare)
- Authenticated origin (tunnel credentials)
- No direct server IP exposure

### Layer 3: Authelia
- Single sign-on (SSO)
- Session-based authentication
- Rate limiting on login attempts
- Configurable policies (one_factor, two_factor)

### Layer 4: Nginx (Local)
- Listens on 127.0.0.1 only (not accessible externally)
- `auth_request` validates every request with Authelia
- Clears `Authorization` header (prevents Basic Auth bypass)

### Layer 5: Hermes Dashboard
- Trusted hosts validation
- Token-based session management
- WebSocket origin checking

## Network Isolation

| Service | Bind Address | Exposed? |
|---------|-------------|----------|
| cloudflared | outbound only | No |
| Nginx | 127.0.0.1:4180 | No |
| Authelia | 127.0.0.1:9091 | No |
| Dashboard | 127.0.0.1:9119 | No |

All dashboard-related services are bound to `127.0.0.1` only.

## Cloudflare Tunnel Security

- No public port 4180 needed — cloudflared connects outbound-only to Cloudflare
- QUIC protocol (UDP 443) for tunnel connections
- Tunnel credentials authenticate the origin to Cloudflare edge
- No inbound firewall rules required

## Authelia Cookie Security

Authelia session cookies are set with:
- `Secure: true` — Only sent over HTTPS
- `HttpOnly: true` — Not accessible via JavaScript
- `SameSite: Lax` — Not sent on cross-site requests
- `Domain: hermes-kvm4.example.com` — Scoped to the dashboard domain

## Pre-Publication Security Checklist

Before publishing any configuration to a public repository:

1. **Never publish:**
   - Cloudflare API tokens
   - Tunnel credentials JSON files
   - cert.pem or any certificate files
   - Private keys (.key, .pem)
   - Authelia JWT secrets, session secrets, storage encryption keys
   - User password hashes
   - .env files with real values
   - Real domain names (use example.com)
   - Real server IP addresses (use 192.0.2.x RFC 5737 range)
   - Session tokens or cookies
   - WebSocket tokens in query strings

2. **Always use placeholders:**
   - `<TUNNEL-UUID>` for tunnel UUIDs
   - `YOUR_API_TOKEN` for API tokens
   - `REPLACE_WITH_RANDOM_SECRET` for secrets
   - `hermes-kvm4.example.com` for domains
   - `192.0.2.x` for IP addresses

3. **Run before every push:**
   ```bash
   ./scripts/scan-for-secrets.sh .
   ```

4. **Manual review:**
   - Grep for `password`, `secret`, `token`, `cookie`, `PRIVATE KEY`
   - Verify no real values in examples/
   - Check .gitignore excludes sensitive file types

## Audit Trail

- cloudflared logs: `journalctl -u cloudflared`
- Nginx access logs: `/var/log/nginx/access.log`
- Nginx error logs: `/var/log/nginx/error.log`
- Authelia logs: `/var/log/authelia/`
- Dashboard logs: `journalctl -u hermes-dashboard.service`
