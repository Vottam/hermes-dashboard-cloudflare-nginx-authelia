# Lessons Learned

## Technical Lessons

### 1. OpenLiteSpeed WebSocket Support Is Unreliable

OpenLiteSpeed (OLS) has fundamental limitations with WebSocket reverse proxying. The `extprocessor websocket 1` directive is necessary but not sufficient. Context rules for each WebSocket path help but don't fully resolve the issue. CyberPanel auto-regeneration can overwrite manual fixes.

**Takeaway:** Don't use OLS for WebSocket proxying to Node.js backends. Use Cloudflare Tunnel, Nginx, or HAProxy instead.

### 2. systemd Hardening Breaks Node.js

`MemoryDenyWriteExecute=true` (a systemd hardening default) blocks `mprotect(PROT_EXEC)`, which V8's JIT compiler requires. This causes immediate Node.js crashes with `V8_Fatal SetPermissionsOnExecutableMemoryChunk`.

**Takeaway:** Always set `MemoryDenyWriteExecute=false` for Node.js services under systemd.

### 3. HERMES_TUI_DIR Is Mandatory

Without `HERMES_TUI_DIR=/opt/hermes-agent/ui-tui`, the dashboard tries to run `npm install` on every start, which crashes.

**Takeaway:** Always set `HERMES_TUI_DIR` in the systemd environment for Hermes Dashboard.

### 4. Cloudflare Tunnel Eliminates Proxy Problems

By using Cloudflare Tunnel, the public-facing proxy is completely removed from the path. Cloudflare Edge handles TLS and WebSocket natively.

**Takeaway:** When proxy problems are unfixable, bypass the proxy entirely.

### 5. HTTP 101 Is Necessary but Not Sufficient

Seeing HTTP 101 doesn't mean WebSocket is working. The connection must stay open and data must flow bidirectionally.

**Takeaway:** Validate WebSocket by sending and receiving data, not just checking the upgrade.

### 6. Frontend Patches Must Respect Framework Invariants

A React patch that placed `useRef()` inside `useEffect()` violated React's Rules of Hooks, causing a white screen.

**Takeaway:** Test frontend patches in isolation. Respect framework invariants.

### 7. Diagnose Each Symptom Independently

Multiple independent problems produced overlapping symptoms. Fixing one didn't fix the others.

**Takeaway:** Don't assume one fix solves everything.

## Process Lessons

### 8. Test Backend Directly First

Before debugging proxy issues, test the backend directly. If the backend works directly but fails through the proxy, the proxy is the problem.

**Takeaway:** Always isolate the problem layer before attempting fixes.

### 9. Multiple Clients Rule Out Browser Issues

If a problem reproduces across different browsers, incognito mode, and different devices, it's server-side.

**Takeaway:** Test with multiple clients before assuming a client-side issue.

### 10. Document Failures, Not Just Successes

Every failed approach taught something about the system.

**Takeaway:** Failed approaches are valuable documentation.
