---
# radietto-4rpj
title: MainActivity must extend AudioServiceActivity
status: completed
type: bug
priority: high
created_at: 2026-04-28T20:44:12Z
updated_at: 2026-04-28T20:44:12Z
---

On launch, AudioService.init() threw:
PlatformException(The Activity class declared in your AndroidManifest.xml is wrong or has not provided the correct FlutterEngine.)

Root cause: audio_service plugin requires the Android MainActivity to extend AudioServiceActivity (or FlutterFragmentActivity) — the default FlutterActivity doesn't expose the necessary plugin engine hooks.

Fix: Updated android/app/src/main/kotlin/com/benkaiser/radietto/MainActivity.kt to extend com.ryanheise.audioservice.AudioServiceActivity. Verified app runs and audio streams play.