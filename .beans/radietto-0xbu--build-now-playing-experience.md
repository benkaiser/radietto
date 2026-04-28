---
# radietto-0xbu
title: Build now-playing experience
status: completed
type: feature
priority: normal
created_at: 2026-04-28T13:53:28Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-hldl
---

Create the now-playing UI with playback controls and feedback.

## Design:
- Full-screen or bottom-sheet now-playing view
- Station emoji (large) as album art placeholder
- Song title and artist
- Progress bar / seek slider with elapsed and total time
- Playback controls: previous (disabled for radio), play/pause, skip forward
- Feedback row: thumbs down, thumbs up buttons
- Station name in header
- Mini player bar at bottom of radio browser screen when playing

## Behavior:
- Thumbs up: mark song as liked, inform next LLM generation
- Thumbs down: mark song as disliked, skip to next song
- Skip: mark song as skipped, advance to next
- Play/pause: toggle playback
- Show loading state while next track is being fetched
- Swipe down or back to collapse to mini player

## Checklist
- [x] Create lib/screens/now_playing_screen.dart
- [x] Create lib/widgets/mini_player.dart
- [x] Song info display (title, artist, station emoji)
- [x] Progress bar with position tracking
- [x] Play/pause/skip controls
- [x] Thumbs up/down feedback buttons
- [x] Loading state for track transitions
- [x] Mini player bar widget for radio browser screen