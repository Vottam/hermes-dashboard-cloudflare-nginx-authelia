# DO NOT PUBLISH — Pre-Publication Security Checklist

**Before publishing ANY file to GitHub, verify NONE of the following are present:**

## Cloudflare Secrets
- [ ] Cloudflare API Token
- [ ] Tunnel credentials JSON
- [ ] Tunnel UUID in plain text (use `<TUNNEL-UUID>` placeholder)
- [ ] Account ID / Zone ID

## TLS / Certificates
- [ ] `cert.pem` or any certificate files
- [ ] Private keys (`.key`, `.pem`)
- [ ] Let's Encrypt account credentials

## Authelia Secrets
- [ ] `AUTHELIA_JWT_SECRET`
- [ ] `AUTHELIA_SESSION_SECRET`
- [ ] `AUTHELIA_STORAGE_ENCRYPTION_KEY`
- [ ] User password hashes
- [ ] Any `.env` files with secrets

## Server Identity
- [ ] Real domain name (use `example.com`)
- [ ] Real server IP addresses (use `192.0.2.x`)
- [ ] Real hostnames
- [ ] Real usernames

## Session / Auth
- [ ] Session tokens
- [ ] Cookies with values
- [ ] API keys or bearer tokens
- [ ] WebSocket tokens in query strings

## Credentials Files
- [ ] `/root/.cloudflared/*.json` — NEVER publish
- [ ] `/root/hermes-secrets/*` — NEVER publish
- [ ] Any `.env` file with real values

## Sanitization Checklist

Before committing each file:
1. Search for real domain names → replace with `example.com`
2. Search for real IPs → replace with `192.0.2.x`
3. Search for UUIDs → replace with `<UUID-HERE>`
4. Search for secrets/tokens → replace with `<REPLACE-ME>`
5. Verify no `.json` credential files are included
6. Verify no `.env` files with real values are included
7. Verify no log files with real data are included
8. Run `scripts/scan-for-secrets.sh .`
