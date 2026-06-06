# Why OpenLiteSpeed/CyberPanel Was Bypassed

## The Core Problem

OpenLiteSpeed (OLS), as deployed via CyberPanel, cannot reliably proxy WebSocket
connections to Node.js backends. This is not a configuration issue — it is a
fundamental limitation of OLS's WebSocket reverse proxy implementation.

## What Was Tried

### Attempt 1: Basic `websocket 1` in extprocessor

Adding `websocket 1` to the OLS extprocessor configuration is the documented way
to enable WebSocket support. This was necessary but insufficient.

**Result:** `/api/ws` returned 404. `/api/pty` still failed.

### Attempt 2: Context rules for each WebSocket path

OLS needs explicit `context` rules for each WebSocket path:
- `/api/ws`
- `/api/events`
- `/api/pty`

**Result:** Intermittent success. Behavior changed between OLS restarts.

### Attempt 3: Direct extprocessor to backend (bypass Nginx)

Pointing OLS extprocessor directly to the Node.js backend on port 9119.

**Result:** Same failures. Nginx was never the problem.

### Attempt 4: Remove `websocket 1` entirely

Trying to let the backend handle WebSocket natively without OLS involvement.

**Result:** All WebSocket connections returned 404. OLS must have `websocket 1`
for any WebSocket to work, but having it doesn't guarantee success.

## The Smoking Gun

OLS logs showed:
```
Cannot found WebSocket backend URI: [/api/pty]
```

This error means OLS received the WebSocket upgrade request but could not match
it to any configured backend. Adding context rules for each path partially helped
but never fully resolved the issue.

## Why Cloudflare Tunnel Is the Correct Solution

1. **Cloudflare Edge natively supports WebSocket** — No proxy configuration needed
2. **No public ports** — `cloudflared` connects outbound-only to Cloudflare
3. **Nginx handles the local upgrade** — Nginx has reliable WebSocket support
4. **OLS is completely removed** — No OLS in the path for the dashboard domain

## When to Use OLS vs. Cloudflare Tunnel

| Use Case | OLS | Cloudflare Tunnel |
|----------|-----|-------------------|
| Static sites | ✓ Good | Overkill |
| PHP apps (WordPress) | ✓ Good | Overkill |
| Node.js with WebSocket | ✗ Unreliable | ✓ Recommended |
| Internal tools | ✓ OK | ✓ Better |
| No public IP needed | N/A | ✓ Built-in |

## Recommendation

For Node.js backends that use WebSocket (chat, real-time updates, PTY terminals),
use Cloudflare Tunnel instead of OpenLiteSpeed. The tunnel eliminates the proxy
layer entirely and provides better security (no public ports).
