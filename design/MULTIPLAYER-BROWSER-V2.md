# Multiplayer Browser v2

Implemented October 17, 2026 in the existing unreleased 0.17.0 working tree.

## Layout and components

The Multiplayer Browser uses approximately 65% of the main content width for the
game library and 35% for a full-height Party Lobbies sidebar, separated by a
16-unit gutter. At the standard 1120 x 700 window, installed games appear in two
columns. At 1000 x 700, the library uses one column to preserve readable cards.
Wide windows retain two columns. Registered games populate additional rows.

Game cards reuse Theme.GameCard, the existing square card artwork, native icon
fallbacks, typography, aspect-preserving image crops, premium borders and neon
buttons. The multiplayer variant places the player count and description below
the icon/title, with a hosting restriction and full-width Host Game button below.
The navy backdrop remains slightly translucent. Reused Home/Singleplayer cards
restore their original layout, text styling, secondary actions and opacity.

There is no selected-game details frame or separate Host Game widget. Each card
calls the existing CreateLobby with its own registry ID. Hosting restrictions
match the existing session/group checks, while CreateLobby remains authoritative.
No-party browsing retains all artwork and descriptions, disables hosting and
shows "Join a party to host".

The sidebar reuses the existing discovery, refresh, expiry, roster filtering and
Join validation. Each compact lobby card shows game, host, joined/capacity,
status, restriction and a distinct Join/Resume/Rejoin action. The empty state
uses two short labels instead of a placeholder card. Back to Games exposes a
Resume Lobby button inside the sidebar above its list.

The shared Theme.Scroll helper supplies two distinct clipped scroll frames,
scroll children, wheel handlers and scrollbars. The game library scrolls below
its title/subtitle; the sidebar list scrolls below its own header and optional
Resume action. Scrolling either does not change the other's offset. Resizing
changes visual geometry without creating or replacing a session.

Host and Join still open the existing full-width dedicated Lobby View. Library
and discovery frames are hidden there. Ready, Unready, countdown, auto-start,
host authority, leaving and game protocols are unchanged.

## Changed files

- `KIC-Games/Launcher.lua`: columns/sidebar geometry, direct card hosting,
  per-game hosting reasons, removed details panel, Resume placement.
- `KIC-Games/Theme.lua`: shared GameCard's compact multiplayer variant and pooled
  presentation reset; no new renderer or artwork assets.
- `KIC-Games/UI.lua`: stacked discovery cards, sidebar geometry and empty labels;
  removed obsolete standalone host control.
- `tests/multiplayer_navigation.lua`: direct hosting, no-party state, six-game
  grid, long metadata, independent scrolling, refresh, resize/scale and Resume.
- `tests/framework.lua`, `tests/chess_lobby.lua`, `tests/chess_ui.lua`,
  `tests/blindshot_session.lua`, `tests/lobby_slots.lua`: updated callers and
  assertions for direct card hosting and the removal of the details frame.
- `README.md`, `CHANGELOG.md`, this report: current browser behavior and checks.

## Validation

- All 31 runnable Lua suites passed, including Chess, Blindshot, shared transport,
  Bejeweled, KIC Bejeweled, Tetris, recovery and local practice suites.
- Shared framework: 3711 assertions. Final targeted browser suite: 240 assertions.
- Chess lobby: 194; Blindshot session: 772; lobby slots/layout: 73 assertions.
- Artwork validation: 69 runtime TGAs, paths, dimensions and load order passed.
- Options asset validation passed.
- Changed Lua files passed StyLua verification/checking with Lua 5.1 syntax.
- Offline constructor previews were rendered and visually reviewed for normal,
  narrow, populated, six-game, no-party and Resume browser states. Additional
  wide/scrolled and existing dedicated-lobby states were also rendered. These
  are mock UI previews, not screenshots of a live WoW client.

Preview artifacts:
`D:\WowAddons\.tools\kic-multiplayer-browser-v2-preview`.

## Remaining live checks

After `/reload`, inspect the browser at your actual display/Interface Scale.
Confirm font wrapping, truncation, scrollbars, hover highlights and image contrast.
With a second party member, host/join Chess and Blindshot, Back/Resume, Ready,
cancel a countdown with Unready, then start and leave a match. Check that the
dedicated lobby occupies the full main content region and that browser elements
do not remain visible over it. No live WoW validation was performed here.

## Local checkpoint

An isolated Git snapshot repository preserves the pre-change tree and completed
implementation at:
`D:\WowAddons\backups\KIC-Games-browser-v2-20261017`.
The original repository's existing branch and index were left intact. No remote
push or CurseForge ZIP was produced.
