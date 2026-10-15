# Checkpoint 1 — shared design system and Launcher

Implemented against `references/new-launcher.png` and the supplied asset manifest.
This checkpoint stops before the Bejeweled, Tetris and Options layout redesigns.

## Completed

- `KIC-Games/Artwork.lua`: centralized runtime art and replaceable fallback slots.
- `KIC-Games/Theme.lua`: navy/cyan/violet palette, spacing/type tokens, aspect-preserving
  artwork loader, native borders, primary/hover/pressed/disabled states, pooled cards
  and existing reusable panel/modal/scroll helpers.
- `KIC-Games/Launcher.lua`: Home/Singleplayer/Multiplayer/Results/Options sidebar,
  supplied feature art and thumbnails, real Play/Resume actions, selected-game
  details, saved records, registry-driven cards and actual roster status.
- `KIC-Games/UI.lua`: branded shell, centered existing game container, common header,
  footer, Launcher integration and existing multiplayer actions repositioned in
  their page. No duplicate visible solo heading or Home header-menu controls.
- `KIC-Games/Options.lua`: only resize calculations were adapted to the new base
  window size (1120×700). The Options presentation and settings are unchanged.
- Eight supplied TGAs copied byte-for-byte into `KIC-Games/Media/KICUI/`.
  No runtime references to mockups/source PNGs, no PUG registration, no ZIP.

Game rules, game UI source files, networking, communication prefixes, registration
contracts, class presets, records, slash commands and minimap behavior remain in
place. Existing mode/size settings are retained; a Home page preference is added
without replacing the previous Singleplayer/Multiplayer setting. Scales still
clamp to the screen when necessary.

## Automated / offline checks

- `lua tests/framework.lua`: original isolated-client lifecycle/network/input/result
  suite plus Launcher navigation, CTA/resume, real registry/roster, third-party
  modules, fallback textures, frame reuse and 100%/120% scaling checks.
- `lua tests/tetris.lua` and `lua tests/bejeweled.lua`: unchanged rule checks.
- `python tests/artwork.py`: eight runtime paths, uncompressed power-of-two TGA
  headers/dimensions, source hashes when the supplied root-level kit is present,
  no copied PUG art and TOC dependencies.
- StyLua Lua 5.1 syntax/format and `git diff --check`.
- Offline previews generated from the actual mocked constructors using supplied
  TGAs at 100% and 120%. They are layout approximations, not WoW screenshots.

## Missing artwork / known visual limitations

See [MISSING_ASSETS.md](MISSING_ASSETS.md). Separate frame skins, primary-button
skins and five navigation symbols were not supplied; native strokes, blue surfaces
and letter badges currently fill those slots. The generic hero/card fallback is
only needed by future third-party games without their own art. Provided hero art
is cropped proportionally to the wide panel rather than stretched.

No known functional regression was observed in the available checks. Live font
metrics, TGA decoding/orientation, native frame levels and mouse hit areas still
require the following in-game checks. The multiplayer page retains its working
browser/lobby controls; its detailed presentation is not a new multiplayer game.

## Required in-game verification before the next checkpoint

1. Reload and open `/kicgames`. Home should show exactly the registered games
   (currently Bejeweled and Tetris), the logo, real group state, two artwork cards
   and the selected game's feature panel. PUG must not appear as installed.
2. Set exact scales with `/run KICGames.UI:SetWindowScale(1)` and then
   `/run KICGames.UI:SetWindowScale(1.2)` on a display where 1344×840 fits. Check
   hero crop, text contrast, thumbnails, gutters, wrapping, footer and Resize.
   All buttons must remain readable and clickable without overlap. Inspect TGA
   orientation and transparent edges, especially logo and sidebar decoration.
3. Hover, press and leave the primary buttons and cards. Select Details / the
   card body, switch featured games, and verify the correct artwork, description,
   score and Play action. There should be no stale feature art or duplicate CTA.
4. Play each game, return to Launcher, resume the same round, and try selecting
   the other game while one is active. It must not start a second session.
   Test Bejeweled clicking/dragging and Tetris arrows/Space/C/P at both scales;
   returning to Launcher, chat, Results or Options must still pause safely.
5. Open Results and Options from the sidebar, close them and press Escape.
   Check modal strata, focus, dragging and scale. Existing class selection,
   Reset size, records and chat drafts must still work. Options/game layouts
   are intentionally awaiting later redesign checkpoints.
6. Drag the main window and Resize handle, release outside the grip, close during
   a resize, and reload. Verify saved scale/page/class, screen clamping and that
   no resize or decorative frame intercepts gameplay input.
7. Join/leave a real group and verify the header count/state updates. Multiplayer
   must show the real game library and discovered lobbies. With no multiplayer
   module installed, Host stays unavailable. With compatible clients/module,
   verify host/join/ready/3-2-1 and Stop match. No fabricated counts or games.
8. Use Stop match and `/kicgames stop` while playing or with a modal open. The
   session/windows must stop immediately, preserve earned best scores and leave
   no floating icon or keyboard capture. Check slash/minimap reopening afterward.

Proceed to the game screens and Options as separate changes only after this
Launcher checkpoint has been visually assessed in the client.
