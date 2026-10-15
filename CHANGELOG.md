# Changelog

## 0.9.0 - 2026-10-15 — Launcher redesign checkpoint

- Added the supplied Neon Arcade artwork to a centralized runtime texture catalog with documented native replacement slots.
- Added Home/Singleplayer/Multiplayer/Results/Options navigation, a feature artwork panel, live game cards, real records and group status.
- Preserved launch/resume, multiplayer controls, saved settings, slash/minimap access and proportional resizing in a 1120×700 shell.
- Added native shared palette, typography tokens, primary/button states, static neon corners and reusable card/artwork helpers.
- Added runtime artwork checks and Launcher integration/100%-120% scale coverage; documented required live WoW visual checks.
- Deferred Bejeweled, Tetris and Options layout redesigns to their own checkpoints. No ZIP was produced.

## 0.8.0 - 2026-10-15

- Added Bejeweled drag-and-drop swaps with a floating class icon, neighbor highlighting and scale-aware drop targets.
- Kept click-to-swap and cancelled off-board/non-neighbor drops, paused drags and stale release/click events safely.
- Moved the Tetris board left and consolidated score, controls, sharing, previews, hold and options into one right sidebar.
- Added regression checks for scaled drags, invalid drops, menu/stop cleanup and the Tetris sidebar layout.

## 0.7.0 - 2026-10-15

- Moved class icon presets out of Tetris into a shared Options menu; one saved selection now updates both games live.
- Migrated existing Tetris class preferences and replaced Bejeweled jewel tiles with class ability icons.
- Made Bejeweled selection more visible with a thick gold frame, bright tile background and selection label.
- Added a bottom-right proportional resize handle, saved screen-bounded UI scale and Reset size in Options.
- Renamed the main heading to KIC GAMES and added jewel / tetromino icons to the game library.
- Added regression checks for shared class changes, migration, live board preservation, selection and resizing.

## 0.6.0 - 2026-10-15

- Added Bejeweled as a second independent singleplayer module with an 8×8 board and seven fixed WoW gem icons.
- Added adjacent swaps, match-three lines, falling gems, animated cascades, free hints and untimed no-moves game over.
- Added cascade scoring, saved high scores, editable chat sharing, replay and movable results.
- Paused gameplay and animations on hidden windows, chat focus or match history; kept immediate framework stopping.
- Added pure engine checks and integration coverage for launching, animation input locks, pauses, records, results and replay.

## 0.5.0 - 2026-10-14

- Restyled the launcher, lobby, Tetris and result dialogs with dark cards, blue accents, clean typography, custom flat buttons and thin scrollbars.
- Made both match history and Tetris game-over windows independently draggable and raised them above the launcher with explicit overlay strata.
- Added automatic game-over dialog cleanup when closing the launcher, plus Escape support.
- Added a readable pause overlay and paused Tetris while match history is open.
- Added regression checks for result-window strata, dragging, raising, input pausing and close cleanup.

## 0.4.1 - 2026-10-14

- Replaced spell-dependent icon lookup in all 13 Tetris class presets with 91 audited texture FileDataIDs.
- Fixed retired Arcane Shot, Lightning Bolt and Chain Lightning lookups and pinned the familiar Aimed Shot icon.
- Added class-icon fallback when a client rejects a texture; removed the question-mark fallback.
- Added coverage for every preset without spell APIs and rejected-texture rendering.

## 0.4.0 - 2026-10-14

- Bundled Tetris as an independent singleplayer module with colorful WoW spell icons and 13 saved class presets.
- Added seven-piece bags, rotation kicks, ghost landing, five-piece previews, hold, soft/hard drop, levels and line scores.
- Added account-wide saved best scores and editable chat drafts from the game, game-over dialog or `/kictetris share`.
- Added automatic pause on hidden windows or edit-box focus and keyboard cleanup on immediate match interruption.
- Added game-over results and replay, pooled UI frames, and shared cleanup of module auxiliary windows.
- Added deterministic engine and randomized invariant checks plus framework integration coverage for Tetris.
- Kept multiplayer communication and API at v3; no additional addon installation is required.

## 0.3.0 - 2026-10-14

- Added separate Singleplayer and Multiplayer tabs and filtered game libraries.
- Added party-independent local launch and results for singleplayer modules.
- Added selected-game hosting, visible independent party hosts, title/capacity/status listings and click-to-join.
- Replaced the manual multiplayer start step with an automatic synchronized 3-2-1 countdown when everyone is ready.
- Cancelled countdowns safely on unready, roster/game changes or quick interruption.
- Added countdown tokens and correlated join requests to reject delayed state and stale leave/join messages.
- Added API v3 documentation and regression checks for tabs, simultaneous hosts, solo sessions and countdown races.

## 0.2.0 - 2026-10-14

- Added one-click match interruption for every participant, shared across all games.
- Added `/kicgames stop`, `/kicgames abort`, and `/kicgames results`.
- Interrupts close local windows immediately and use a separate prioritized queue.
- Added shared validated results, score/rank/outcome presentation and a last-20-match history.
- Interrupted rounds never count as defeats; late snapshots cannot reopen them.
- Required module-owned UI factories and scoped messages by game ID/version.
- Added module-managed timers, automatic cleanup and guarded per-instance contexts.
- Added API v2 documentation and multi-client regression checks for urgent stopping and results.

## 0.1.0 - 2026-10-14

- Added a game launcher, an empty-library state, a party lobby browser and a
  draggable dice minimap button.
- Added opt-in 1-5 player lobbies with host selection, compatible game versions,
  readiness, game start/end and guest rejoining.
- Added a public game-module registry, lifecycle hooks and per-round contexts.
- Added host-authoritative action/state routing with session and round validation.
- Bundled AceComm, AceSerializer and ChatThrottleLib with their dependencies.
- Added isolated-client integration checks and game-module API documentation.
