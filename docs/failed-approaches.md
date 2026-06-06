# Failed Approaches — What Didn't Work and Why

## 1. LiteSpeed Basic Auth Direct

**Objective:** Expose dashboard via LiteSpeed with HTTP Basic Auth.

**Why it failed:** The Hermes Dashboard has its own authentication layer (token-based). Basic Auth credentials were accepted by LiteSpeed but not translated into dashboard session tokens.

**Lesson:** Don't mix authentication layers.

---

## 2. LiteSpeed Proxy to Backend (No Auth)

**Objective:** Proxy requests from LiteSpeed directly to the dashboard.

**Why it failed:** LiteSpeed's extprocessor did not recognize WebSocket upgrade requests. Without `websocket 1`, OLS treated WebSocket connections as regular HTTP.

**Lesson:** OLS needs explicit WebSocket configuration.

---

## 3. LiteSpeed with `websocket 1`

**Objective:** Add `websocket 1` to the LiteSpeed extprocessor.

**Why it failed:** `websocket 1` at the extprocessor level is necessary but not sufficient. OLS also needs explicit `context` rules for each WebSocket path.

**Lesson:** OLS WebSocket support requires both extprocessor-level and context-level configuration.

---

## 4. Remove `websocket 1` from Extprocessor

**Objective:** Let the backend handle WebSocket natively.

**Why it failed:** Without `websocket 1`, OLS doesn't attempt WebSocket upgrade at all.

**Lesson:** OLS must have `websocket 1` for any WebSocket to work.

---

## 5. Specific Contexts for WebSocket Paths

**Objective:** Add explicit context rules for `/api/ws`, `/api/events`, `/api/pty`.

**Why it failed:** Context rules in OLS are path-matched but the WebSocket upgrade handshake still goes through the extprocessor layer. The two layers don't always agree.

**Lesson:** OLS context rules are not a reliable fix for WebSocket routing.

---

## 6. Direct Extprocessor to Backend (Bypass Nginx)

**Objective:** Point LiteSpeed extprocessor directly to the dashboard, bypassing Nginx.

**Why it failed:** The problem was never Nginx. The problem was OLS's WebSocket handling.

**Lesson:** Don't blame the wrong component.

---

## 7. Frontend Auto-Reconnect Patch

**Objective:** Fix `events feed disconnected` by adding auto-reconnect to React ChatSidebar.

**Why it failed:** The patch placed `useRef()` inside `useEffect()`, violating React's Rules of Hooks. This caused a white screen.

**Lesson:** Frontend patches must respect framework invariants. Test in isolation.

---

## 8. Conclude PASS by Seeing HTTP 101

**Objective:** Validate the fix by checking if WebSocket returns HTTP 101.

**Why it failed:** HTTP 101 only means the upgrade handshake succeeded. It doesn't mean the persistent connection is stable.

**Lesson:** Test the full WebSocket lifecycle: connect → send → receive → persist.

---

## 9. Assume Browser/Cache Issue

**Objective:** Clear browser cache to fix WebSocket failures.

**Why it failed:** The problem was server-side (OLS), not client-side.

**Lesson:** Test with multiple clients before assuming a client-side issue.

---

## 10. Assume HERMES_TUI_DIR Alone Fixes Everything

**Objective:** Set `HERMES_TUI_DIR` and expect the dashboard to work fully.

**Why it failed:** `HERMES_TUI_DIR` only fixes the npm install crash. It doesn't fix `MemoryDenyWriteExecute` or OLS WebSocket issues.

**Lesson:** Diagnose each symptom independently.

---

## Summary

| # | Approach | Failed Because | Lesson |
|---|----------|---------------|--------|
| 1 | Basic Auth | Auth layer mismatch | Don't mix auth layers |
| 2 | Proxy no auth | No websocket 1 | OLS needs WS config |
| 3 | websocket 1 | Contexts also needed | OLS WS is fragile |
| 4 | Remove websocket 1 | No WS at all | Must have websocket 1 |
| 5 | Specific contexts | Intermittent | OLS WS is unreliable |
| 6 | Bypass Nginx | OLS still broken | Blame the right component |
| 7 | Frontend patch | React hooks violation | Test patches in isolation |
| 8 | HTTP 101 = PASS | Connection still closes | Test full WS lifecycle |
| 9 | Browser cache | Server-side issue | Test multiple clients |
| 10 | TUI dir = everything | Independent problems | Diagnose each symptom |
