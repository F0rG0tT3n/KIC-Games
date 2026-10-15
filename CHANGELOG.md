# Changelog

## 0.12.0 - 2026-10-15 - Both gameplay screens

- Replaced the Tetris gameplay title's flat block placeholder with the supplied Tetris artwork used by the Launcher.
- Renamed the Launcher header action to Stop game; it ends the active instance and keeps the current Launcher page open.
- Pause-menu Stop match returns to the visible Launcher after ending the run; the urgent-stop command still closes the addon window.
- Rebuilt Bejeweled around the supplied artwork/instructions/actions, centered square 8x8 class-icon board, and score/gold-best/statistics/tip composition.
- Rebuilt Tetris with a left information/keycap panel, square-cell 10x20 playfield, grouped score/best/lines/level, five real queue slots, violet hold and Pause action.
- Extended the shared Theme with framed boards, diamond/crown accents, icon actions/rows, keycaps, fitted scores, gold-best panels and reusable pause menus; registered eleven small original transparent TGA masks.
- Gameplay headers show Back to Launcher, live group status and Close; Back/Close immediately pause without replacing the run. Restart/Stop remain in the pause menu and urgent-stop slash commands remain available.
- Preserved engines, simulation timing, saved schema, class presets, results/recent-game integration and multiplayer protocol. Drag distances and cursor hit-testing now follow the resized Bejeweled board.
- Added focused responsive, navigation, input, pause-menu, feedback and frame-reuse regressions; documented illustrated skin/ornament replacements. No ZIP or changes to the approved Launcher presentation beyond the gameplay header/container integration.

## 0.11.0 - 2026-10-15 - Shared premium UI components

- Removed the Featured Game surface's opaque native backdrop fill and normalized texture tint/blend/visibility when refreshing artwork.
- Added opt-in PremiumFrame, NeonButton, StatPanel, GameCard, SectionHeader and StatusPanel components, with static corner ornaments, pips, dividers and highlights.
- Applied shared styling to the Launcher shell/sidebar, feature panel, cards, party/lobby information, headings, actions and saved-best panel.
- Centralized card presentation and responsive updates in GameCard:SetGame; retained real launch/resume/details actions.
- Added replaceable stat/card/status skin slots to Artwork.lua and documented native placeholders and the component API.
- Added component-state, missing-skin, data/action, responsive reuse and hero-surface regressions. No gameplay-screen redesign, protocol change or ZIP.

## 0.10.1 - 2026-10-15 - Featured artwork layering fix

- Put Featured Game artwork above the native panel backdrop, with explicit image/shade/fallback draw order and native text/buttons on top.
- Kept both original hero TGAs, paths, crop logic and Play/Resume behavior unchanged.
- Added draw-layer regression checks for both games after navigation and narrow/default/wide resizing.
- Live WoW verification: reload, feature Bejeweled and Tetris, resize and visit other pages before returning Home; inspect artwork and text at 100%/120%.

## 0.10.0 - 2026-10-15 - Launcher organization checkpoint

- Replaced Home's installed list with saved, unique recent launches and a responsive carousel (up to three cards), plus an empty-state library shortcut.
- Added unbounded registry-driven, clipped scroll grids for both game modes, keeping multiplayer discovery and host/join/ready controls accessible.
- Moved Options and Results into the shared launcher content region, with safe return to an active game, scrollable settings and per-game real saved records.
- Added responsive window dimensions alongside the existing saved UI scale, and Reset Size for both.
- Replaced all five letter navigation badges with original transparent TGA icons and shared hover/selected/disabled styling.
- Added malformed-history, reload, 24-games-per-mode, carousel, resize, page navigation, records, session and frame-reuse regressions.
- Kept protocol v3 and game rules/UI unchanged. No new ZIP; game-specific redesigns remain deferred.

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
