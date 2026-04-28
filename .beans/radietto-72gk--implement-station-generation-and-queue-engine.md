---
# radietto-72gk
title: Implement station generation and queue engine
status: completed
type: feature
priority: high
created_at: 2026-04-28T13:53:49Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-ut0o
blocking:
    - radietto-adth
---

Build the core engine that orchestrates station creation, song generation, YouTube resolution, and queue management.

## Pre-defined Station Templates:
Generate ~8-10 stations covering various moods:
1. 🏋️ "Iron Tempo" - "Fuel for your grind" (workout)
2. ☀️ "Golden Hour Radio" - "Breezy tunes for sunny days" (sunny/chill)
3. 🌙 "Midnight Drift" - "Late-night sonic journeys" (late night)
4. 🎉 "Main Stage" - "Peak energy bangers" (party)
5. 📚 "The Study" - "Focus-friendly frequencies" (study/focus)
6. 💔 "Heartbreak Hotel FM" - "Songs that understand" (sad/emotional)
7. 🚗 "Highway One" - "Open road anthems" (driving)
8. 🍳 "Sunday Morning" - "Easy listening for lazy days" (morning/relax)
9. 🌊 "Tidal Waves" - "Ambient electronic explorations" (ambient/electronic)
10. 🔥 "The Underground" - "Deep cuts and hidden gems" (discovery)

## Queue Engine Logic:
1. On app start, for each station: call LLM to generate 5 songs
2. For each song returned, resolve YouTube search + stream URL (rate limited)
3. Station becomes "warmed up" once first song has a resolved stream URL
4. When a station is playing and gets down to 2 unplayed songs, generate 5 more
5. New generations include recent feedback to improve selections

## Checklist
- [x] Create lib/services/station_engine.dart
- [x] Define pre-built station templates
- [x] Implement station initialization (parallel LLM calls for all stations)
- [x] Implement YouTube resolution pipeline (sequential due to rate limiting)
- [x] Implement queue replenishment trigger (2 songs remaining)
- [x] Feed ratings into next generation prompt
- [x] Handle custom prompt-based station creation
- [x] Track station warm-up state