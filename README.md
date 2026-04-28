# Radietto 📻

> An experimental LLM-powered radio app. Like Pandora, but the DJ is an LLM.

Radietto is a Flutter mobile app that uses an LLM to curate radio-style station queues, then streams the matching audio from YouTube. Tell it your taste across a few genres (or don't), pick a vibe, hit play, and the LLM keeps the queue refilled — learning from your thumbs up / thumbs down / skips as the session goes.

This is a weekend-experiment / proof-of-concept. Lots of rough edges. Not production-ready. Read [`QUESTIONS.md`](QUESTIONS.md) for known caveats.

## How it works

1. **Onboarding** — twelve genre sliders (Rock, Pop, Jazz, …) from 0 (hate) to 10 (love), default 5 (neutral). Skippable.
2. **Stations** — ten pre-baked themed stations ship with the app (`Iron Tempo`, `Golden Hour Radio`, `Midnight Drift`, etc.), plus a "Custom" button to spawn a new station from a freeform prompt like *"cooking dinner and feeling fancy"*.
3. **Generation** — when a station needs songs, the app calls OpenRouter using `openai/gpt-oss-120b` with provider preference for **Cerebras** (fastest available throughput) and asks for a 5-song JSON list grounded in the station vibe + your taste sliders + your recent feedback.
4. **Playback** — for each suggested song, the app uses [`youtube_explode_dart`](https://pub.dev/packages/youtube_explode_dart) to search YouTube (first result) and extract the audio-only stream URL via the `androidVr` client. [`just_audio`](https://pub.dev/packages/just_audio) + [`audio_service`](https://pub.dev/packages/audio_service) handle playback with lock-screen controls and background audio.
5. **Feedback loop** — thumbs up / down / skip on each track gets fed back into the next LLM call so the queue gradually drifts toward what you're actually enjoying.
6. **Caching** — stations and their queues persist to disk between launches. Stream URLs are *not* cached (YouTube signed URLs expire) but `videoId`s are, so refreshes only need a single rate-limited manifest call instead of a full search.

## Tech stack

- Flutter 3.41 / Dart 3.11
- `provider` for state, `shared_preferences` for persistence
- `flutter_dotenv` for the OpenRouter key
- Built and tested on Android (Pixel 9 Pro XL, Android 16). iOS background-audio mode is configured but not smoke-tested.

## Setup

```bash
git clone https://github.com/benkaiser/radietto.git
cd radietto
flutter pub get
cp .env.example .env
# edit .env and put your OpenRouter API key (https://openrouter.ai/keys)
flutter run
```

## ⚠️ Caveats

- **API key bundling.** The `.env` file is shipped as a Flutter asset, which means whatever key you put in there is trivially extractable from the APK. Fine for a personal prototype; do not ship to a public store this way.
- **Rate limiting.** All YouTube extraction calls are throttled to one every 2 seconds globally. First-launch warm-up of all 10 stations therefore takes a few minutes. Subsequent launches are near-instant thanks to caching.
- **YouTube as the audio backend** is fragile by design — videos get pulled, signed URLs expire, regional blocks apply.
- **No tests** in this initial version.
- **No backend.** Everything runs on-device against OpenRouter directly.

## License

MIT. Build whatever you want from it.
