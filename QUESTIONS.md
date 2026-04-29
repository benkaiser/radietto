# Open Questions for Radietto

Outstanding product/technical questions worth revisiting. Resolved items have
been removed (custom-station persistence, history view, queue visibility,
upfront YouTube warm-up cost, stream URL freshness, OpenRouter provider
routing).

## Product / UX

1. **Station list size** — ships with 10 pre-baked templates. Warm-up is
   now cheap (one LLM call per station, no YouTube), but 10 LLM calls
   on first launch is still a noticeable burst. Consider lazy-warming
   only the top N until the user scrolls.
2. **Cross-station feedback sharing** — feedback is per-station today.
   Should a thumbs-up on "Iron Tempo" influence "Highway One" too?
   Current take: keep per-station so vibes stay distinct, but worth
   confirming once we have real listening data.
3. **Skip vs thumbs-down** — both advance. Skip = neutral hint;
   thumbs-down = strong negative + auto-skip. Recently refined so a
   thumbs-up + skip preserves the upvote. Is auto-advance on
   thumbs-down still the right call long-term?

## Technical

4. **Mid-stream error recovery** — initial load failures in
   `_playSongSnappy` advance to the next song, but a
   `playbackEventStream` error mid-song doesn't auto-skip. Should add
   a player error listener that calls `_advanceToNext()`.
5. **iOS smoke test** — `UIBackgroundModes: audio` is configured but
   the app hasn't been run on a real iOS device. macOS works.
6. **API key in `.env` shipping with the app** — currently `.env` is
   bundled as an asset, so the OpenRouter key ships in the APK and is
   trivially extractable. Fine for prototype; **must** move to a
   backend proxy or BYO-key flow before any public release.
7. **No tests** — no widget or unit tests yet. Worth adding once the
   API surface stabilizes; the JIT pipeline (Player → Engine →
   YoutubeService split) is now stable enough to be worth covering.
