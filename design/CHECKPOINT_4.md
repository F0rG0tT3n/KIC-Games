# Gameplay checkpoint - 0.12.0

Both Bejeweled and Tetris screens are implemented together, following the actual
`design/references/new-bejeweled.png` and `new-tetris.png` compositions. No ZIP was
created. The approved Launcher layout is retained.

## Changed files and behavior

- `KIC-Games/Games/Bejeweled/UI.lua`: supplied artwork, compact icon instructions,
  ordered Hint/Pause/Share/Class Options, centered square-cell 8x8 board, separate
  score/gold best/moves/gems/cascade/tip presentation. Selection, hover, hint,
  valid-swap border, pulsing matches and a brief score flash use existing updates.
  Drag hit-testing and animation offsets use the measured resized cell step.
- `KIC-Games/Games/Tetris/UI.lua`: title/block brand, intro, individual keycaps and
  left actions; centered square-cell 10x20 grid; grouped STATS, five actual NEXT
  slots, actual HOLD with violet accents/crest, and Pause. NEXT reflows from five
  columns to three at narrow widths. Empty preview cells are transparent and
  pieces are centered within slots. Board/preview textures remain pooled.
- `KIC-Games/GameplayUI.lua`, `Theme.lua`: extensions to the existing shared theme,
  including premium board, fitted scores, icon buttons/rows, keycaps, gold-best
  treatment and pause menus. See [component API](COMPONENTS.md).
- `KIC-Games/UI.lua`, `Launcher.lua`: responsive gameplay content rectangle and
  header with Back to Launcher, current group status and X. Both navigation and
  Close immediately pause bundled games, release held keys/cancel a drag, and
  preserve the active model/session. Resume reopens the paused run. Explicit
  Restart/Stop live in the in-game pause menu; Launcher/lobby Stop and slash
  commands still use the existing urgent stop path. Other registered modules
  retain the previous container dimensions.
- `Artwork.lua`, `Media/Shared/Icons/*.tga`, `tools/generate_gameplay_icons.py`:
  eleven matching original transparent masks and optional gameplay decoration
  slots. Supplied artwork and existing navigation textures are unchanged.
- `KIC-Games.toc`, `Core.lua`, README and CHANGELOG: new shared helper load entry,
  version 0.12.0 and usage documentation. `tests/framework.lua`, `tests/artwork.py`:
  focused gameplay integration/layout/input/asset regressions and preview export.

## Preserved functionality

The engine and module files, protocol, lobbies and saved-data schema are unchanged.
This includes all Bejeweled match/swap/cascade/scoring/hint behavior and existing
animation delays; Tetris movement, rotations/kicks, gravity, lock timing, drops,
hold, queue, ghost, score and levels; shared 13-class presets/fallback icons;
saved personal bests, editable chat drafts, results and recent launches. Restart
uses existing AbortGame/StartSingleplayer and saves the old run's best. Resume
does not create a new history entry or reset the board. Multiplayer discovery,
host/join/ready/countdown/interrupt behavior remains covered by integration tests.

## Automated and offline validation

Run from the repository root:

```text
lua tests/tetris.lua
lua tests/bejeweled.lua
lua tests/framework.lua
python tests/artwork.py
git diff --check
```

Final results: Tetris **44,303** assertions; Bejeweled **68,272** assertions;
framework **1,443** assertions using actual bundled AceComm/ChatThrottleLib and
isolated mock clients. All **24** runtime TGAs pass encoding, dimensions, alpha,
case-sensitive path and TOC coverage/load-order checks. Changed Lua files are
also parsed/formatted using StyLua's Lua 5.1 mode.

The new cases cover 1000x700, 1120x700, 1500x900 and narrow/tall 1000x1000 panel
bounds; square boards/cells, queue slots, artwork layers, button order and control
spacing; Back/Close/Options/Resume preserving the actual session/model/history;
pause-menu restart/stop; resized drag validity/timing and close cleanup; score
flash completion, large score fitting/saved-best retention, and no UI allocations
during gameplay/rapid rotation or resize.

Constructor snapshots can be exported with:

```text
lua tests/framework.lua --preview D:/WowAddons/.tools/kic-games-ui-preview
```

Offline Pillow renders from these snapshots were inspected at default, compact,
wide, tall, 100%/120% and paused layouts. They are **not WoW screenshots**. Native
font metrics, texture filtering, clipping, backdrop draw order and keyboard/mouse
propagation must still be checked in the actual client. The local preview images
are development artifacts outside the installable addon, under the path above.

## Artwork limits

The reference's full illustrated frame skins, ornate crown and standalone crystal
cluster were not supplied as component textures. They have registered replaceable
native/geometric/reused-art placeholders, with dimensions/alpha/placement in
[MISSING_ASSETS.md](MISSING_ASSETS.md). This preserves composition and interactive
controls without using screenshots as interfaces. Exact painted glow and engraved
border detail will require those final assets; this checkpoint does not claim
pixel-perfect visual parity.

## Required live WoW verification

1. `/reload`, open Home, feature both games and confirm their Launcher artwork
   still appears. Start each game and check the logo/title/subtitle, Back, real
   party status and X; no standalone gameplay header Stop/Options/Results.
2. Resize each screen at the four sizes above where the screen allows, then use
   Options for 100% and 120%. Check square cells, board prominence, art visibility,
   text/score readability, ornaments, all controls and NEXT/HOLD clipping.
3. In Bejeweled, test click selection, right-click clear, hover, Hint, valid and
   invalid swaps with both clicking and dragging, off-board drops, cascades and
   score flashes. Resize before dragging. Pause and Close during a drag/cascade;
   return and resume without duplicate moves or a floating icon left behind.
4. In Tetris, rapidly move/rotate (including wall kicks and reverse rotation),
   soft/hard drop, hold twice, inspect all five NEXT slots and the ghost. Verify
   level/line/score updates. Open chat while holding a key: it must auto-pause,
   release gameplay keys and let typing reach chat normally.
5. For both, Back to Launcher then Resume must retain the board/score. X, reopen
   via `/kicgames`, then Resume must retain them too. Pause menu Resume/Restart/
   Stop must work; `/kicgames stop` must still stop immediately. Check that restart
   preserves the previous best and recent history remains unique.
6. Open Class Options from either game, change class and return: both use the
   same preset without resetting their score/board. Check all 13 classes for
   missing icons, especially Hunter/Shaman, and verify settings after `/reload`.
7. Share Best should prepare the correct editable chat draft. Finish each game
   normally: its result dialog should appear above the main window, remain
   movable, and support replay/share. Check saved best/history in Results.
8. With another client and a multiplayer module installed, test discovery,
   host/join/ready/3-2-1 start, Back/Resume and urgent stop. Confirm group status
   updates while a solo game is open and that unchanged module UI remains usable.

No live WoW verification was performed in this development environment.
