---
# radietto-9c1w
title: Tap-to-play should not auto-open NowPlayingScreen + status bar fix
status: completed
type: bug
priority: high
created_at: 2026-04-28T21:06:43Z
updated_at: 2026-04-28T21:10:30Z
---

Two issues:
1. Tapping a station auto-pushes the full NowPlayingScreen, surprising the user. Should just start audio and reveal the mini-player at the bottom of the browser. NowPlayingScreen should only open via tapping the mini-player.
2. Status bar still overlapping content despite previous edge-to-edge fixes. Need explicit AnnotatedRegion + padding on the AppBar.