# Open Questions for Radietto

Outstanding product/technical questions worth revisiting. Resolved items have
been removed (custom-station persistence, history view, queue visibility,
upfront YouTube warm-up cost, stream URL freshness, OpenRouter provider
routing, cross-station feedback sharing, skip-vs-thumbs-down semantics,
mid-stream error recovery, mid-song resume).

## Product / UX

1. **Station list size** — ships with 10 pre-baked templates. Acceptable
   today; revisit if we want to expand the catalogue and warm-up cost
   becomes noticeable again.

## Technical

2. **iOS smoke test** — `UIBackgroundModes: audio` is configured but
   the app hasn't been run on a real iOS device. macOS works.
3. **API key in `.env` shipping with the app** — currently `.env` is
   bundled as an asset, so the OpenRouter key ships in the APK and is
   trivially extractable. Fine for prototype; **must** move to a
   backend proxy or BYO-key flow before any public release.
4. **No tests** — no widget or unit tests yet. Worth adding once the
   API surface stabilizes; the JIT pipeline (Player → Engine →
   YoutubeService split) is now stable enough to be worth covering.

