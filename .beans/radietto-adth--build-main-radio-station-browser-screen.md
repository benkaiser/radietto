---
# radietto-adth
title: Build main radio station browser screen
status: completed
type: feature
priority: normal
created_at: 2026-04-28T13:53:18Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-hldl
---

Create the main screen showing all available radio stations.

## Design:
- App bar with "Radietto" title and settings gear icon
- Grid of station cards, each showing:
  - Large emoji icon
  - Station name (fun radio-style name)
  - Short tagline
  - Loading spinner overlay while warming up
  - Checkmark/ready indicator once first track resolves
- Floating action button or prominent button for "Create Custom Station"
- Bottom now-playing mini bar (shown when a station is active)

## Behavior:
- On load, all stations begin warming up (LLM generates songs, YouTube resolves first track)
- Tap a ready station to start playing
- Tap a warming-up station shows "warming up..." toast
- Settings gear navigates to taste re-tuning screen

## Checklist
- [x] Create lib/screens/radio_browser_screen.dart
- [x] Station card widget with emoji, name, tagline, loading state
- [x] Grid layout for stations
- [x] Custom station creation dialog/bottom sheet with prompt input
- [x] Settings navigation
- [x] Integration with StationProvider for station list and warm-up states