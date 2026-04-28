---
# radietto-efj9
title: Persist stations & lazy-refresh expired stream URLs
status: completed
type: feature
priority: high
created_at: 2026-04-28T20:52:59Z
updated_at: 2026-04-28T20:57:35Z
---

On every cold start the app burns OpenRouter credits + makes ~100 youtube_explode_dart calls because nothing is cached.

## Plan
1. Persist each station's queue (song id, title, artist, youtubeVideoId, thumbnail, duration, played, rating) to SharedPreferences as JSON.
2. Persist custom user-created stations (id, name, tagline, emoji, moodPrompt) too.
3. On launch, restore stations + queues. A station is "warm" if any unplayed song has a videoId (we don't need streamUrl yet — fetch on demand).
4. Stream URLs are NOT persisted (they expire). When a song needs to play and streamUrl is null but videoId exists, fetch the manifest only (skip search). This is one rate-limited call instead of two.
5. Save on every meaningful state change (queue updated, song played, rating added).

## Checklist
- [x] Add toJson/fromJson to Song model
- [x] Add toJson/fromJson to RadioStation model  
- [x] Add StationStorage service
- [x] Wire StationEngine to load on init, save on changes
- [x] YoutubeService: add resolveByVideoId() that skips search
- [x] On playback: if song has videoId but no streamUrl, refresh