## Radietto

This is an app that tries to bring the ease of Pandora radio, with the mix of LLMs to automatically soundtrack your life.

Plan would be:
- user first imputs their tastes as sliders for different very broad genres (rock, pop, jazz, classical, metal, electronic, hip-hop, country, etc.), then the app will go ahead and create a playlist for a whole bunch of moods and styles with soundtracks that loosely fit the user tastes. The sliders should be neutral by default (no preference for or against any genre), and the user can adjust them as much or as little as they want. This allows users to skip this step if they just want neutral radio.
- use can go back to customize this later, but by default coming back to the app it just loads in with the existing setlist.
- users can thumbs up, thumbs down or skip songs. The way the app learns is that it stores these ratings and the LLM uses them to inform generations of future songs for the current setlist.

From a performance side, the app only generates 5 songs per setlist initially, and then once it gets to 2 songs left in the setlist, it generates 5 more songs. This way the app is always generating songs in the background while the user is listening to the current setlist, and it can use the ratings from the current setlist to inform the next setlist.

These setlists or radios, should have fun names that sound like a radio station for that mood or vibe, and a short tagline describing the vibe. For example, a radio for working out might be called "Pump Up Jams" with a tagline of "High energy tracks to get you moving", while a radio for relaxing might be called "Chill Vibes" with a tagline of "Laid-back tunes for unwinding". We can pre-generate the station names and taglines, but the LLM will generate the actual song names at runtime based on the user tastes and feedback.

TODO for the future, we will come up with some nice cover images for each radio station as well, but for now just use an emoji.

We should also allow the user to spawn a setlist based on a prompt (e.g. going for a sunny bike ride with family, cooking dinner and feeling fancy, etc).

## Technical side

This app will be a flutter app. For now the app will use a pre-baked openrouter token for the LLM calls (.env has OPENROUTER_API_KEY already in it), eventually we will make this either a BYO LLM (OpenRouter OAuth, custom OpenAI compatible endpoint, etc) or a subscription model where users can pay for the LLM calls (i.e. up to 10,000 AI song selections per month for $5).

We will use the same approach for audio source fetching as `/Users/benkaiser/scratch/ytiframe_flutter_test` to power the youtube audio stream playback (and background audio playing).

For LLM calls, we are essentially prompting the LLM to give us a JSON formatted response with a list of songs for a mood and grounded on the user tastes + feedback (up/down/skip). The LLM will provide the song name and artist.

From this list, we will automatically search (youtube_explode_dart pub supports this) for a matching youtube video (I'm feeling lucky style, first result) and pull the audio stream for that video to play in the app.

This initial view where we are warming up each of the setlists after chosing the taste sliders, show this to the user as a loading on each of them until we have at least resolved at least one track from youtube for each setlist (having one known youtube match makes it "available").

The app should fetch the youtube track lazily, i.e. when a song is in the last 20 seconds, we should fetch the youtube track and prep the stream for playing the next song.

We should avoid spamming the youtube endpoint by rate-limiting all our youtube_explode_dart calls to at most 1 every 2 seconds.

The prompt needs to be much more thought out, but as a rough starting:
```
Give me a setlist of 5 songs for a sunny afternoon bike ride.
On a scale of 0 being hate, 5 being neutral and 10 being absolutely love, always preference this genre. My taste for electronic music is a 6.
Every other genre is 5.

Unless I am specifying a 10, please make sure to keep things balanced.
```

The ideas here being we don't want the LLM going off the rails only sticking purely to the users preferences, unless they have gone high enough on a genre to indicate they really want that genre. We also want to make sure the LLM is aware of the user tastes for each generation, so it can learn from the feedback and adjust the next generations accordingly.