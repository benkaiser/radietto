---
# radietto-xzza
title: Cached stations show 'warming up' on launch
status: completed
type: bug
priority: high
created_at: 2026-04-28T21:03:08Z
updated_at: 2026-04-28T21:03:08Z
---

After persistence shipped, cold-start cached stations were still showing 'warming up' even though their queues had cached YouTube videoIds.

Root cause: UI ready-check used station.firstPlayable (requires streamUrl), but streamUrl is intentionally not persisted (YouTube signed URLs expire). Now uses firstResolvableUnplayed (videoId is enough — streamUrl will be lazily refreshed at play time).

Fix: RadioBrowserScreen now uses firstResolvableUnplayed for the ready indicator and tap handler.