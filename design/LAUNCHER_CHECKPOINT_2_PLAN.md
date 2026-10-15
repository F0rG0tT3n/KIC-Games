# Launcher organization checkpoint

1. Store deduplicated launch history at the successful module-start boundary;
   filter missing modules on read without deleting their saved IDs.
2. Give the sidebar one content region. Home gets a responsive recent carousel;
   both libraries use clipped native ScrollFrames and pooled registry cards.
   Keep the existing lobby browser and host/join/ready controls alongside the
   multiplayer library. Make Options and Results embedded, scrollable pages.
3. Preserve saved scale and add saved logical window dimensions so the resize
   grip can reflow columns. Keep the game boards unchanged and centered.
4. Check available Blizzard navigation artwork; supply a consistent transparent
   TGA icon set if there is no verified matching set. Share state styling.
5. Extend isolated-client regressions with 20+ temporary games, malformed/reload
   history, responsive navigation, real results, input safety and persistence.
   Run all existing checks and inspect offline previews at 100% and 120%.

No gameplay redesign, protocol changes, temporary shipped games or new ZIP.
Live WoW clipping, texture and input verification remains a separate manual step.
