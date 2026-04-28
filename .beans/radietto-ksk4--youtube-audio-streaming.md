---
# radietto-ksk4
title: YouTube Audio Streaming
status: completed
type: epic
priority: normal
created_at: 2026-04-28T13:51:49Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-g23a
---

Implement YouTube search, stream extraction, and audio playback with background support.

## Checklist
- [x] YouTube search service using youtube_explode_dart (first result / I'm feeling lucky)
- [x] Audio stream URL extraction using androidVr client
- [x] Rate limiting (max 1 request every 2 seconds) for youtube_explode_dart calls
- [x] Audio player service with just_audio + audio_service for background playback
- [x] Lock screen / notification media controls
- [x] Lazy pre-fetching (fetch next track when current is in last 20 seconds)
- [x] Queue management (play next, handle errors/unavailable tracks)