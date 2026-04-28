---
# radietto-ut0o
title: Station Generation & Queue Engine
status: completed
type: epic
priority: normal
created_at: 2026-04-28T13:52:09Z
updated_at: 2026-04-28T14:00:44Z
parent: radietto-g23a
---

Core engine that ties LLM, YouTube, and playback together.

## Checklist
- [x] Pre-defined station templates (moods/vibes with names, taglines, emojis)
- [x] Station initialization: generate 5 songs per station via LLM on app start
- [x] Queue replenishment: when 2 songs left, generate 5 more in background
- [x] Feed user ratings (thumbs up/down/skip) back into LLM prompt for next batch
- [x] YouTube resolution pipeline: search + extract stream URL for each song
- [x] Handle YouTube resolution failures (skip to next song in queue)
- [x] Station warm-up tracking (available once first YouTube match resolves)