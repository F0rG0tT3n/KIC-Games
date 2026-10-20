# Checkpoint 2 - Launcher navigation and libraries (0.10.0)

Implemented the follow-up launcher request against the working 0.9.0 UI.
Bejeweled and Tetris gameplay UI redesigns have not started. No new ZIP is made.

## Completed and changed files

- `KIC-Games/Settings.lua`, `Core.lua`: successful module starts update
  `KICGamesDB.recentGames`, newest first, one ID per game. Resume, lobby browsing,
  failed startup and countdown cancellation do not add launches. Sparse or invalid
  history is filtered; unknown module IDs remain saved for later reinstallation.
- `Launcher.lua`: one content region controlled by all five sidebar entries;
  Home retains the feature panel and gets recent cards, empty state, browse
  shortcut and Prev/Next/page indicator. At most three cards are visible, with
  fewer columns in narrow windows. Both mode libraries use pooled registry cards
  in a native clipped ScrollFrame with mouse wheel and scrollbar. Multiplayer
  retains discovery, joining, hosting, readiness, countdown and immediate stop.
  There is no artificial library limit. Optional title search was not added.
- `Options.lua`: embedded scrollable Appearance, Window, Controls and About
  sections; all 13 class choices with audited existing class textures; live shared
  class settings, scale controls and Reset Size. Resize now changes logical
  dimensions so columns reflow; UI scale remains a separate saved setting.
  `windowWidth`/`windowHeight` extend the existing settings table. Legacy
  `windowScale` and class settings remain valid. Active sessions get Back to game.
- New `ResultsUI.lua`: embedded, independently scrollable game selector and
  records; reads `GetResults`, `GetResultStats` and actual saved best values.
  Only existing statistics are shown. No-score/no-match/no-game states are real
  empty states. Retained `optionsFrame`/`resultsFrame` references keep existing
  game input blockers working without popup windows.
- `UI.lua`: shared-page initialization, responsive shell integration and retained
  lobby/browser actions. Removed the superseded text library and standalone
  history window. Existing game container stays 860x450 and is centered.
- `Theme.lua`, `Artwork.lua`, `Media/Shared/Navigation/*.tga`: reusable navigation
  buttons with original 64x64 transparent house, person, group, trophy and gear
  icons rendered at 24 UI pixels. Muted, hover, selected and disabled tints/glow
  share button state handling. Scrollbars sit inside their clipped viewports.
  Navigation has no letters, emoji, continuous animation or decorative OnUpdate.
- `KIC-Games.toc`: load ResultsUI and bump version; Core reports 0.10.0. API and
  protocol remain v3, including communication prefixes and packet schemas.
- `tests/framework.lua`, `tests/artwork.py`: expanded regressions and asset/path
  validation. Temporary stress-test and preview registrations are only in tests.
- `tools/generate_navigation_icons.py`: editable original icon geometry and TGA
  exporter; development-only Pillow tool, not an addon runtime dependency.
- `README.md`, `CHANGELOG.md`, `MISSING_ASSETS.md`,
  `LAUNCHER_CHECKPOINT_2_PLAN.md` and this report document the checkpoint.

No `Games/Tetris/`, `Games/Bejeweled/`, networking, countdown or results-storage
logic is changed. The eight supplied artwork TGAs are unchanged. There are no new
missing-art placeholders. The existing frame/button skins and generic module-art
fallbacks remain listed in [MISSING_ASSETS.md](MISSING_ASSETS.md).

## Verification

- Framework integration suite: 1,227 assertions with real bundled communication
  libraries in isolated mocked WoW clients. Covers actual solo and multiplayer
  launch history, repeated/resumed/failed launches, sparse/invalid/missing-module
  history, saved-variable startup/reload, carousel boundaries, narrow/wide grids,
  all sidebar pages, real saved records, safe active-game return, class/scale/size
  persistence, input pause/drag cleanup, lobby compatibility and frame reuse.
- Stress registry: 24 temporary singleplayer plus 24 multiplayer modules, in
  addition to the two installed solo games. Checks every card, wheel scrolling,
  layout bounds, clipping configuration, responsive columns and lobby access.
  Results also exercises all 50 registered modules. Nothing is shipped in runtime.
- Tetris engine/icon suite: 44,303 assertions. Bejeweled engine: 68,272 assertions.
- Artwork checks: all 13 runtime TGAs, actual dimensions, power-of-two uncompressed
  encoding, antialiased navigation alpha, original supplied-file hashes, exact
  runtime/TOC path casing and Lua load order; no unused TGA or letter placeholders.
- StyLua Lua 5.1 syntax/format checks and `git diff --check`.
- Offline constructor snapshots inspected for Home at 100%/120%, mode libraries,
  multiplayer controls, full-page Options/Results and long/scrolled libraries.
  These use real runtime art and mocked geometry; they are not WoW screenshots.

## Required live WoW tests before any gameplay UI redesign

1. `/reload`, then `/kicgames`. On a fresh history, verify the empty Recent Games
   state and browse shortcut. Launch Tetris, then Bejeweled, then Tetris again;
   reload and confirm newest-first unique cards. Resume must keep the same board.
   Footer must still count all installed games. Only registered games appear.
2. Inspect all five sidebar icons at 100% and 120% (and your usual UI scale).
   Check transparent edges, correct orientation, 24px square proportions,
   alignment, normal/hover/selected colors and restrained glow. No missing tiles,
   pixelated masks, stretched artwork, overlapping labels or letter substitutes.
3. Drag Resize horizontally and vertically, release outside the grip, close
   during resize and reopen. Narrow/wide libraries must reflow without overlapping
   the sidebar, footer, scrollbar or multiplayer panels. Adjust scale in Options,
   reload to confirm persistence, then Reset Size. Legacy saved scale must load.
4. With development-only temporary modules, browse 20+ games in each mode; wheel
   and drag the scrollbar to the last card, and click it. Confirm native clipping
   of artwork, text, card borders and buttons at both viewport edges. Resize while
   scrolled. With 4+ actually launched modules, test recent Prev/Next/page counts
   and the transition between two and three visible cards. Remove test modules.
5. Visit Home, Singleplayer, Multiplayer, Results and Options repeatedly. Exactly
   one content page should be visible. Scroll Options to Window, Controls and
   About; test all 13 class choices and both scale controls. No detached popups.
6. From each active solo game, open Options/Results, change class, navigate pages
   and use Back to game or Resume. Board/score must survive; resume the paused
   game explicitly. Test Tetris keys, Bejeweled drag cancellation, chat typing,
   Escape/main-window close and Stop match from either settings/results page.
7. Results must match existing saved bests (including Tetris lines/level and
   Bejeweled moves/gems/cascade) and real framework match history. Switch games;
   games without records need honest empty states. Confirm interrupted matches
   remain interrupted and no saved score changes from merely viewing Results.
8. With two real compatible clients and an installed multiplayer module, verify
   discovery, host selection, join, ready/unready, game switching, 3-2-1, start,
   rejoin and immediate Stop match. Browse libraries and open Options/Results
   during a round, return to that session, then stop. Confirm actual party count.

Native TGA decoding, font metrics, clipping/hit-testing, inherited frame layering
and real addon-message delivery still require these client checks. No live WoW
visual verification has been performed in this checkpoint.
