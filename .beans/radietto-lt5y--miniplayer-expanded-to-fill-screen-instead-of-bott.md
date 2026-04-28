---
# radietto-lt5y
title: MiniPlayer expanded to fill screen instead of bottom strip
status: completed
type: bug
priority: high
created_at: 2026-04-28T21:19:31Z
updated_at: 2026-04-28T21:19:31Z
---

After tapping a station, the MiniPlayer (in Scaffold.bottomNavigationBar) was filling the entire screen instead of sitting as a bottom strip. The body grid was hidden and only the song info + play/next buttons appeared, vertically centered.

Root cause: MiniPlayer's root Material widget had no height constraint. When placed in bottomNavigationBar, it expanded to consume all available vertical space.

Fix: Wrapped the InkWell child of Material in SizedBox(height: 64) so MiniPlayer always renders as a fixed-height bottom strip.