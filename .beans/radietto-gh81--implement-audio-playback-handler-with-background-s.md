---
# radietto-gh81
title: Implement audio playback handler with background support
status: completed
type: feature
priority: high
created_at: 2026-04-28T13:53:00Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-ksk4
blocking:
    - radietto-0xbu
    - radietto-72gk
---

Build the audio handler that plays YouTube audio streams with background playback support.

## Architecture (following reference project pattern):
- Subclass BaseAudioHandler with SeekHandler mixin
- Wrap just_audio AudioPlayer
- Connect to audio_service for OS-level playback controls

## Features:
- Load and play audio from stream URLs
- Background playback (continues when app is backgrounded)
- Lock screen / notification media controls (play, pause, skip)
- Track position and duration streams
- Auto-advance to next song when current finishes
- Lazy pre-fetch: when current song has ≤20 seconds remaining, resolve next song's YouTube stream
- Media notification with song title, artist

## Checklist
- [x] Create lib/services/audio_handler.dart
- [x] Implement BaseAudioHandler subclass with just_audio
- [x] Set up audio_service initialization in main.dart
- [x] Play/pause/stop/seek controls
- [x] Media notification with song info
- [x] Stream position tracking
- [x] Auto-advance and pre-fetch trigger at 20s remaining
- [x] Handle playback errors gracefully (skip to next)