---
# radietto-uo0o
title: SQLite lock from flutter_cache_manager on artUri
status: completed
type: bug
priority: high
created_at: 2026-04-28T20:40:07Z
updated_at: 2026-04-28T20:40:26Z
---

Unhandled exception at startup:
DatabaseException(database is locked (code 5 SQLITE_BUSY)) sql 'BEGIN EXCLUSIVE'
Stack: CacheObjectProvider.open → CacheStore (flutter_cache_manager) → triggered by audio_service trying to cache the MediaItem artUri (YouTube thumbnail).

Likely causes:
1. Dev hot-restart re-opens DB while previous handle still owns the lock
2. YouTube thumbnail URLs are very long signed URLs that may not cache cleanly

## Checklist
- [x] Make artUri optional/safer — wrap in try/catch around URI parsing
- [x] Provide an option to skip artwork entirely (avoids the cache manager path)
- [x] Document that error is non-fatal and is a known dev hot-restart artifact