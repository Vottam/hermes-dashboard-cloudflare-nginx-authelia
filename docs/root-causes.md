# Root Causes — Hermes Dashboard WebSocket/PTY Failures

## A) HERMES_TUI_DIR Missing

**Symptom:** Dashboard service crashed on start. `npm install` ran and failed.

**Root Cause:** The Hermes Dashboard service did not have `HERMES_TUI_DIR` set. Without this environment variable, the dashboard assumed it needed to build the TUI frontend from source, triggering `npm install` which crashed due to missing build dependencies or permission issues.

**Fix:**
```ini
# /etc/systemd/system/hermes-dashboard.service.d/10-tui-dir.conf
[Service]
Environment=HERMES_TUI_DIR=/opt/hermes-agent/ui-tui
```

**Why it works:** The pre-built TUI files already exist at `/opt/hermes-agent/ui-tui`. Setting this variable tells the dashboard to use the pre-built files instead of trying to build from source.

**Impact:** Without this fix, the dashboard never starts. This was the first blocker.

---

## B) MemoryDenyWriteExecute=true

**Symptom:** Node.js crashed in under 100ms with `V8_Fatal SetPermissionsOnExecutableMemoryChunk`. No dashboard process ever stayed alive.

**Root Cause:** systemd's `MemoryDenyWriteExecute=true` (a hardening default) blocks the `mprotect(PROT_EXEC)` system call that the V8 JavaScript JIT compiler needs. V8 allocates memory, writes compiled code to it, then marks it as executable. With `MemoryDenyWriteExecute=true`, this `mprotect` call is blocked by the kernel, causing V8 to crash fatally.

**Fix:**
```ini
# /etc/systemd/system/hermes-dashboard.service.d/20-node-execmem-fix.conf
[Service]
MemoryDenyWriteExecute=false
```

**Why it works:** Setting this to `false` allows the V8 JIT to mark memory pages as executable, which is required for JavaScript execution in Node.js.

**Impact:** Without this fix, the dashboard crashes immediately on every start. This is a known issue with Node.js + systemd hardening.

---

## C) OpenLiteSpeed in the WebSocket Path

**Symptom:** `/api/pty` returned `code 1006` (abnormal closure) in the browser. Chat showed `[session ended (code 1006)]`. Kanban showed `events feed disconnected`. LiteSpeed logs showed `Cannot found WebSocket backend URI: [/api/pty]`.

**Root Cause:** OpenLiteSpeed (OLS) has unreliable WebSocket reverse proxy support:

1. **extprocessor requires `websocket 1`** — Without this directive, OLS does not attempt WebSocket upgrade. But even with it, the upgrade handshake was unreliable.
2. **Context matching is path-specific** — OLS needs explicit `context` rules for each WebSocket path. Generic extprocessor-level `websocket 1` was insufficient.
3. **Inconsistent behavior** — Sometimes `/api/ws` returned 404, sometimes 101 then immediate close.
4. **CyberPanel interference** — CyberPanel auto-generates OLS vhost configurations, which could overwrite manual WebSocket fixes.

**Diagnosis path:**
- Backend direct (`curl 127.0.0.1:9119/api/status`) → 200 OK
- Nginx local (`curl 127.0.0.1:4180/`) → 302 to Authelia
- Browser via LiteSpeed 443 → `/api/pty` failed
- Conclusion: Only the LiteSpeed hop broke WebSocket

**Fix:** Remove LiteSpeed from the path entirely using Cloudflare Tunnel.

**Why it works:** Cloudflare Edge natively supports WebSocket. `cloudflared` forwards traffic to local Nginx over HTTP. Nginx correctly handles the WebSocket upgrade to the Node.js dashboard.

---

## Summary Table

| # | Root Cause | Symptom | Fix | Priority |
|---|-----------|---------|-----|----------|
| A | HERMES_TUI_DIR missing | npm install crash | systemd drop-in | Blocker |
| B | MemoryDenyWriteExecute=true | V8_Fatal crash | systemd drop-in | Blocker |
| C | OpenLiteSpeed WebSocket | code 1006 | Cloudflare Tunnel | Critical |
