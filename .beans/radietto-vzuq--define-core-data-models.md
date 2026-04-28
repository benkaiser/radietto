---
# radietto-vzuq
title: Define core data models
status: completed
type: task
priority: normal
created_at: 2026-04-28T13:52:24Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-k0z7
blocking:
    - radietto-3wqe
    - radietto-uoku
    - radietto-7qw5
    - radietto-gh81
    - radietto-72gk
---

Create all data model classes for the app.

## Models:
1. **GenrePreference** - genre name (String), value (double, 0-10, default 5.0)
2. **RadioStation** - id, name, tagline, emoji, mood/prompt, list of songs, isWarmedUp flag
3. **Song** - title, artist, youtubeVideoId (nullable), streamUrl (nullable), status (pending/resolved/failed)
4. **SongRating** - enum: thumbsUp, thumbsDown, skip
5. **RatedSong** - Song + SongRating pair for feedback history

## Checklist
- [x] Create lib/models/genre_preference.dart
- [x] Create lib/models/radio_station.dart  
- [x] Create lib/models/song.dart
- [x] Create lib/models/song_rating.dart
- [x] Add JSON serialization methods for persistence