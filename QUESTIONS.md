# Open Questions for Radietto MVP

These came up during initial implementation — worth revisiting before/after first user test.

## Product / UX

1. **Station list size** — currently ships with 10 pre-baked stations. Is that too many to warm up at once on first launch? May want to lazy-warm (only warm a station when the user scrolls near it, or only warm the top N).
2. **Custom station persistence** — custom stations only live for the session right now. Should they persist across app restarts? If so, how do we surface them (pinned at top, separate "My Stations" tab)?
3. **History / "recently played" view** — not in MVP. Worth it?
4. **Cross-station feedback sharing** — feedback right now is per-station. Should a thumbs-up on "Iron Tempo" influence "Highway One" (since both are user-rated tracks)? My current take: keep per-station so vibes stay distinct, but worth confirming.
5. **Skip vs thumbs-down** — both currently advance. Skip = neutral hint; thumbs-down = strong negative. Is auto-advance on thumbs-down the right call? Pandora does this; some apps don't.
6. **Visible queue** — the spec mentions "queue visibility (upcoming songs)" in the radio screen epic. Not implemented in MVP — would clutter the now-playing screen. Worth adding as a swipe-up or separate tab?

## Technical

7. **OpenRouter `provider` block format** — I'm using `{"order": ["cerebras"], "allow_fallbacks": true, "sort": "throughput"}`. The exact field names in the current OpenRouter API spec should be double-checked; the routing might want `"providers"` or different casing. If Cerebras is unavailable for `openai/gpt-oss-120b`, fallback should still work since `allow_fallbacks: true`.
8. **Rate limiting youtube_explode_dart** — currently a global 1 req/2s queue. With ~10 stations × 5 songs × 2 calls (search + manifest) = 100 calls = ~3.3 minutes just to warm up everything. That feels slow. Options: (a) increase the rate, (b) only warm one song per station first (parallelize first-song-of-each), then fill out the rest. Currently we do them sequentially per station.
9. **Stream URL freshness** — YouTube stream URLs from `androidVr` client expire (typically a few hours). Currently we fetch them up front; if the user lets the queue sit too long they may go stale. Should re-resolve right before playing if too old.
10. **Error recovery** — if `just_audio` fails to load a stream URL mid-listen (network blip, expired URL), we don't currently catch and skip. Should add an error listener and call `_advanceToNext()`.
11. **iOS** — only Android manifest was configured for foreground service. iOS gets `UIBackgroundModes: audio`, but I haven't smoke-tested on a real iOS device.
12. **API key in .env shipping with the app** — currently `.env` is bundled as an asset (so the OpenRouter key ships in the APK and is trivially extractable). Fine for the prototype as the spec says, but **must** move to a backend proxy or BYO-key flow before any public release.
13. **No tests** — no widget or unit tests written for MVP. Worth adding once API surface stabilizes.
