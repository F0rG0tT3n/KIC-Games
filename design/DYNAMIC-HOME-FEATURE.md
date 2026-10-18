# Dynamic Home featured game

Implemented October 17, 2026 in the existing unreleased 0.17.0 working tree.

## Selection and lifecycle

The Home hero first checks the existing `Games.ActiveGame`. It must reference an
installed game with working registration callbacks and an instantiated frame,
and the round must not be stopped. When there is a shared lobby, it must be a
running match with a matching game and compatible module version. A waiting or
countdown lobby without an active module does not qualify. Hidden or paused
frames still qualify. Existing runtime local-practice sessions also retain their
normal continuation behavior. No active session is inferred from saved records.

Without an active session, Home builds an eligible list from the game registry
and chooses `math.random(#eligible)`: one uniform index across both modes. Party
membership does not filter the showcase. Registry entries lacking the required
mode or executable OnStart/CreateUI callbacks are excluded. Newly installed
registrations join the next selection; removal of the current choice triggers a
replacement. Empty and one-game registries are handled without invalid draws.
Consecutive draws may choose the same game, preserving equal probability.

A new choice is requested when navigating into Home from another page or
reopening the addon on Home. Transitioning back from an active session also
requests a new choice. A presentation-only flag detects a previously displayed
active session ending while Home is visible. Routine refreshes, score/group
updates, hover, window size and Interface Scale changes do not request a draw.
Selection flags and the chosen ID live only in the UI object; there are no new
SavedVariables or competing active-session records.

The existing hero frame, anchors, artwork, shade, description, record provider,
Recent Games and pagination remain in place. Active games expose Continue Game,
which calls the existing ShowGame navigation and never launches a new module.
An obsolete Continue callback only refreshes and reports that the game ended.
Idle solo games retain Play and the normal launch lifecycle. Idle multiplayer
games show their player count and View lobby, which selects the game and opens
the existing Multiplayer Browser without hosting or changing a joined session.

## Changed files

- `KIC-Games/Launcher.lua`: registry eligibility, active-session priority,
  event-triggered random selection, safe Continue callback and party feature
  navigation; existing hero presentation is reused.
- `KIC-Games/UI.lua`: Home entry/reopening notification in ShowHome.
- `tests/home_feature.lua`: deterministic choice coverage and real lifecycle tests.
- `README.md`, `CHANGELOG.md`, this report: behavior and validation notes.

## Validation

The focused Home suite passes 87 assertions covering every installed game index,
both modes without a party, Home re-entry/reopening, stable updates and geometry,
actual Bejeweled/Tetris sessions, actual two-client Chess/Blindshot matches,
hidden sessions, safe Continue, completion while Home is visible, recoverable
Chess journals, stale saved values, future/missing/invalid registrations, missing
optional artwork, empty/one-game pools and unchanged Recent Games history.

The complete 32-suite Lua regression run includes the shared framework, browser
navigation, Chess and Blindshot transport/recovery, practice modes and existing
singleplayer games. Runtime artwork validation and changed-file Lua 5.1 syntax
verification/checking also pass. No live WoW client validation was performed.

After `/reload`, check Home entry, pause/close/reopen and Continue on solo games;
host/join a multiplayer match and return Home; finish a match while Home is open.
Confirm hero text and buttons at your actual Interface Scale. Existing pause
overlays continue to work normally when returning to a paused game.

## Checkpoint

The pre-change and completed source snapshots are preserved in the isolated Git
repository `D:\WowAddons\backups\KIC-Games-dynamic-home-20261017`.
The primary repository's existing branch/index were left intact. No remote push
or CurseForge ZIP was produced.
