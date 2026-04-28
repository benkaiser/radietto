---
# radietto-3wqe
title: Set up state management with providers
status: completed
type: task
priority: normal
created_at: 2026-04-28T13:52:32Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-k0z7
blocking:
    - radietto-sfe2
    - radietto-adth
    - radietto-0xbu
    - radietto-72gk
---

Create providers/notifiers for app state management.

## Providers needed:
1. **TasteProvider** - manages genre preferences, saves/loads from SharedPreferences
2. **StationProvider** - manages list of radio stations, their queues, warm-up state
3. **PlayerProvider** - wraps audio handler, manages current playing station/song, playback state
4. **FeedbackProvider** - stores user ratings, provides rating history for LLM context

## Checklist
- [x] Create lib/providers/taste_provider.dart
- [x] Create lib/providers/station_provider.dart
- [x] Create lib/providers/player_provider.dart
- [x] Wire up providers in main.dart with MultiProvider
- [x] Implement local persistence for taste preferences