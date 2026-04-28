---
# radietto-75qp
title: Initialize Flutter project with dependencies
status: completed
type: task
priority: high
created_at: 2026-04-28T13:52:16Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-yc8w
blocking:
    - radietto-vzuq
    - radietto-3wqe
    - radietto-uoku
    - radietto-7qw5
    - radietto-gh81
---

Create the Flutter project and add all required dependencies.

## Dependencies needed:
- youtube_explode_dart: YouTube search and stream extraction
- just_audio: Audio playback engine
- audio_service: Background audio and lock screen controls  
- flutter_dotenv: .env file loading for API keys
- http: HTTP client for OpenRouter API calls
- shared_preferences: Local persistence for user tastes
- provider: State management

## Checklist
- [x] Run flutter create (or set up from scratch in current dir)
- [x] Add all dependencies to pubspec.yaml
- [x] Configure Android manifest for background audio (foreground service, internet, wake lock)
- [x] Configure iOS Info.plist for background audio mode
- [x] Set up .gitignore (exclude .env)
- [x] Create directory structure: lib/models, lib/services, lib/screens, lib/widgets, lib/providers
- [x] Set up main.dart with dotenv loading and basic MaterialApp with radio-themed design
- [x] Load .env file at startup