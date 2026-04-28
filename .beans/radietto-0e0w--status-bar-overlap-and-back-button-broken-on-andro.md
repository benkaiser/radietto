---
# radietto-0e0w
title: Status bar overlap and back button broken on Android 16
status: completed
type: bug
priority: high
created_at: 2026-04-28T20:49:37Z
updated_at: 2026-04-28T20:51:52Z
---

Two issues on Pixel 9 Pro XL (Android 16):
1. App content draws behind the status bar (edge-to-edge enforcement in Android 15+ targetSdk 35+).
2. System back button does not pop the Navigator — once on NowPlayingScreen, user is stuck.

## Checklist
- [x] Configure proper edge-to-edge with system UI overlay style
- [x] Add SafeArea / annotated region for status bar
- [x] Fix back navigation from NowPlayingScreen