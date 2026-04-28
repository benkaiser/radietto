---
# radietto-7qw5
title: Implement YouTube search and stream service
status: completed
type: feature
priority: high
created_at: 2026-04-28T13:52:51Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-ksk4
blocking:
    - radietto-72gk
    - radietto-gh81
---

Build the YouTube search and audio stream extraction service.

## Requirements:
- Use youtube_explode_dart for search and stream extraction
- Search by "artist - title" and take first result (I'm feeling lucky)
- Extract audio-only stream URL using androidVr client (critical for native playback)
- Rate limit: max 1 youtube_explode_dart call every 2 seconds
- Properly close YoutubeExplode instances after each use

## Checklist
- [x] Create lib/services/youtube_service.dart
- [x] Implement search by song title + artist
- [x] Implement stream URL extraction with androidVr client
- [x] Add rate limiting (1 request per 2 seconds via a throttle/queue)
- [x] Error handling for unavailable/blocked videos
- [x] Return resolved Song model with videoId and streamUrl