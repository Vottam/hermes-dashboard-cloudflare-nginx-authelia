# Kanban Module — Notes

## Overview

The Hermes Agent Kanban plugin provides a visual task board accessible at `/kanban`.
It uses WebSocket (`/api/plugins/kanban/events`) for real-time updates and
REST API for board/task CRUD.

## WebSocket Endpoints

| Endpoint | Protocol | Purpose |
|----------|----------|---------|
| `/api/plugins/kanban/events` | WebSocket | Real-time board updates |
| `/api/plugins/kanban/board` | REST | Board data |
| `/api/plugins/kanban/boards` | REST | List boards |
| `/api/plugins/kanban/profiles` | REST | Worker profiles |
| `/api/plugins/kanban/orchestration` | REST | Orchestration settings |

## Polling Fallback

If WebSocket fails, the Kanban falls back to HTTP polling (fetch every ~150ms).
This was implemented as a reliability measure during the LiteSpeed troubleshooting.
The polling fallback remains active and is transparent to users.

## Columns

Default board columns:
- **Triage** — Raw ideas, needs spec
- **Todo** — Waiting on dependencies or unassigned
- **Scheduled** — Waiting on time delay or follow-up
- **Ready** — Dependencies satisfied, needs assignment
- **In Progress** — Claimed by worker, in-flight
- **Blocked** — Worker needs human input
- **Review** — Completed, needs review
- **Done** — Completed

## Validation

```bash
# Check Kanban API
curl -s http://127.0.0.1:9119/api/plugins/kanban/board?board=default | python3 -m json.tool

# Check WebSocket (via Nginx)
curl -I http://127.0.0.1:4180/api/plugins/kanban/events
# Expected: HTTP 101 Switching Protocols (when authenticated)
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Board loads but no tasks | API unreachable | Check dashboard service |
| `events feed disconnected` | WebSocket broken | Check tunnel/Nginx |
| Columns visible but empty | No tasks in DB | Normal for new board |
| Polling instead of WebSocket | WS connection failed | Check proxy chain |
