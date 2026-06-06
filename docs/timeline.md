# Timeline — Hermes Dashboard Cloudflare Tunnel Deployment

## Chronological Sequence

### Phase 1 — Initial Setup
1. **Dashboard exposed on 127.0.0.1:9119** — systemd service bound to localhost only.
2. **LiteSpeed proxy + Basic Auth attempt** — HTTP worked, WebSocket failed.

### Phase 2 — Host Header & Auth Issues
3. **Host header mismatch** — Dashboard rejected requests. Fix: `HERMES_DASHBOARD_TRUSTED_HOSTS` patch.
4. **Migration to Authelia + Nginx local** — Replaced Basic Auth with Authelia SSO.
5. **Authelia subpath correction** — Authelia served on `/portal` subpath.

### Phase 3 — Kanban Works, Chat Doesn't
6. **Kanban visual working** — Board rendered, but live updates broken.
7. **Kanban polling fallback** — Events feed disconnected. Fixed with polling.
8. **Chat WebSocket failures** — `code 1006`, `npm install` crash, `V8_Fatal`.

### Phase 4 — Systemd Fixes
9. **HERMES_TUI_DIR fix** — Resolved npm install crashes.
10. **MemoryDenyWriteExecute fix** — Resolved V8_Fatal crashes.

### Phase 5 — LiteSpeed WebSocket Diagnosis
11. **Backend direct test** — 200 OK. Backend healthy.
12. **Nginx local test** — 302 to Authelia. Nginx healthy.
13. **Browser via LiteSpeed 443** — `/api/pty` failed.

### Phase 6 — Failed LiteSpeed Fixes
14. **Remove `websocket 1`** — Did not fix.
15. **Add specific contexts** — Partially helped but never fully resolved.
16. **Direct extprocessor to backend** — Still failed.
17. **Research confirmed** — OLS has known WebSocket limitations.

### Phase 7 — Cloudflare Tunnel
18. **Cloudflare Tunnel deployed** — tunnel created via API, DNS CNAME pointed to `cfargotunnel.com`.
19. **Result: PASS** — Chat functional, Kanban functional, tool calls working, MODEL: live, no code 1006.

## Key Metrics

- Total diagnostic iterations: 15+ distinct approaches tried
- Systemd fixes required: 2 (TUI dir + exec memory)
- Failed proxy approaches: 4 (Basic Auth, proxy, websocket 1, contexts)
- Final solution: Cloudflare Tunnel (bypasses all proxy issues)
