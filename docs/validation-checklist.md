# Validation Checklist

Use this checklist to verify the deployment is working correctly.

## Local Services

- [ ] `systemctl is-active hermes-dashboard` → `active` (or `hermes-kvm4-dashboard`)
- [ ] `systemctl is-active nginx` → `active`
- [ ] `systemctl is-active authelia` → `active` (or `authelia-hermes-kvm4`)
- [ ] `systemctl is-active cloudflared` → `active`

## Local Ports

- [ ] `curl -s http://127.0.0.1:9119/api/status` → HTTP 200, JSON with version
- [ ] `curl -s http://127.0.0.1:4180/` → HTTP 302 (redirect to Authelia)
- [ ] `curl -s http://127.0.0.1:9091/` → HTTP 200 or 302 (Authelia running)

## Cloudflare Tunnel

- [ ] `journalctl -u cloudflared | grep "Registered tunnel connection"` → 4 connections
- [ ] All connections show `protocol=quic`
- [ ] No errors in `journalctl -u cloudflared --since "15 minutes ago"`

## DNS

- [ ] `dig +short hermes-kvm4.example.com` → Cloudflare IPs (104.x.x.x, 172.x.x.x)
- [ ] Does NOT return server's real IP
- [ ] CNAME points to `*.cfargotunnel.com`

## External HTTPS

- [ ] `curl -sI https://hermes-kvm4.example.com/` → HTTP 302
- [ ] Server header contains `cloudflare`
- [ ] Redirect location contains `/portal/`

## Authelia Login

- [ ] Browser opens `https://hermes-kvm4.example.com/`
- [ ] Redirects to Authelia login page
- [ ] Login form renders (username + password fields)
- [ ] After login, redirects to dashboard

## Dashboard

- [ ] `https://hermes-kvm4.example.com/chat` loads
- [ ] "Gateway Status: Running" visible
- [ ] "MODEL: live" indicator visible
- [ ] Terminal input textbox present and usable
- [ ] No `[session ended (code 1006)]` message
- [ ] No "WebSocket connection failed" message
- [ ] No JavaScript errors in browser console

## Chat/PTY

- [ ] Can type message in terminal input
- [ ] Pressing Enter sends the message
- [ ] Message appears in chat history
- [ ] Assistant response appears (may take 10-30s)
- [ ] Tool calls visible (read_file, etc.)
- [ ] "Active Sessions: 1" or more after sending

## Kanban

- [ ] `https://hermes-kvm4.example.com/kanban` loads
- [ ] Board selector shows "Default" board
- [ ] Columns visible: Triage, Todo, Scheduled, Ready, In Progress, Blocked, review, Done
- [ ] Tasks visible in columns
- [ ] No 502, 403, or 302 redirect errors
- [ ] No "events feed disconnected" message

## Security Validation

- [ ] `MemoryDenyWriteExecute=false` in systemd drop-in
- [ ] `HERMES_TUI_DIR=/opt/hermes-agent/ui-tui` in systemd drop-in
- [ ] No coredumps for node/npm
- [ ] No V8_Fatal errors in journal
- [ ] Nginx only listens on 127.0.0.1:4180
- [ ] Dashboard only listens on 127.0.0.1:9119
- [ ] Authelia only listens on 127.0.0.1:9091

## Pre-Publication (for repo contributors)

- [ ] `./scripts/scan-for-secrets.sh .` passes
- [ ] No real domains in examples (use example.com)
- [ ] No real IPs in examples (use 192.0.2.x)
- [ ] No tokens, passwords, or secrets in any file
- [ ] `.gitignore` excludes .env, *.key, *.pem, *.json credentials
- [ ] SHA256SUMS.txt regenerated after changes
