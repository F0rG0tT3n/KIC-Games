# Changelog

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
