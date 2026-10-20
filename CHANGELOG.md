# Changelog

## Unreleased - Minesweeper

- Finished Minesweeper boards stay in the main three-panel game window. A compact Bejeweled-style result popup shows win/loss, score (revealed safe tiles), time, best time and difficulty, with Play again and Back to menu. Closing it preserves the board; scores and outcomes enter the shared result history.
- Added singleplayer Minesweeper to the shared launcher, Home feature/recent cards and Singleplayer library, using the supplied hero and card artwork converted to WoW textures.
- Added Beginner (9x9/10), Intermediate (16x16/40), Expert (30x16/99), safe first openings, iterative flood reveal, flag/question/clear marking, elapsed time and saved best times by difficulty.
- Added responsive three-panel gameplay, one-click new runs and win/loss results with the final board, revealed mines and incorrect flags. Completed runs also enter the shared result history.

## 0.17.0 - Multiplayer browser and dedicated lobby

- Simplified Graphics Live Preview and Audio Sound Preview by removing their game-selection buttons while retaining piece icons and sound-event tests. Follow My Character now has its own row below the profile heading. Shifted the lower blocks and compacted preview layouts so both tabs still fit the minimum supported canvas without scrolling.
- Added Share Best to the Results header for the selected game: saved Tetris/Bejeweled/KIC Bejeweled bests (with KIC mode), or Chess/Blindshot lifetime records. Reuses automatic group-chat selection and /say fallback, preserves active gameplay, and disables sharing when a selected module has no saved best. Added per-game selection, mode, channel and layout coverage.
- Added a host-only Announce Lobby button beside Leave Lobby while waiting. It sends an English group-chat announcement with the current game name and joined/capacity count; guests, closed/starting/running lobbies and changed/missing groups cannot announce. Added permission, occupancy, state, group routing and scaled layout coverage.
- Fixed Share Best in Tetris, Bejeweled and KIC Bejeweled: explicit clicks/commands now send to the current instance group (/i), raid (/raid), party (/p), or /say when solo. Sharing saves the current best without opening the pause menu or changing an existing pause. Added button, channel selection, solo fallback and legacy sender coverage.
- Blindshot now uses left click/hold movement and right click/hold aiming, legal boundary clamping, local-only adjustments and final Lock In submission. Added colored player-name firing order with wrapping/scrolling, smooth circular arena auto zoom and stronger survivor-dependent shrinking down to a legal 150-unit duel radius. Blindshot protocol 5 requires matching updated clients. Expanded controls, camera, minimum-radius placement and party/recovery tests.
- Fixed a false Chess draw-claim test failure caused by checking before the throttled terminal commit arrived. The test now waits for both clients and explicitly covers host/guest claims, unchanged board history, matching journals and exactly one drawn result.
- Blindshot now uses a true top-down circular arena, hitbox-aligned portrait bodies and click-drag aiming with release confirmation. Preserved the nearest-target/non-piercing weapon and shrink schedule; sequential shots now run 0.6 seconds apart. Added per-round board acknowledgements and coalesced lock/sync snapshots to prevent throttle backlogs. Blindshot protocol 4 requires matching updated clients.
- Home now features the active runtime session with Continue Game; otherwise, each Home entry uniformly showcases an installed game from either mode. Refreshes and resizing keep the choice stable, and idle multiplayer features open the browser without hosting. Existing hero layout and Recent Games are preserved.
- Browser v2 replaces selection/details with direct Host Game actions, a responsive two-column library matching Singleplayer and a persistent independently scrolling party-lobby sidebar. Narrow windows use one game column; no-party cards retain artwork and show the hosting restriction.
- Separated Multiplayer into a full-width registry-backed game browser and a dedicated main-content lobby. Host/Join opens the lobby; Back to Games preserves it, Resume Lobby and global Multiplayer return to it, and Leave explicitly ends membership.
- Reused premium GameCard components with an opt-in artwork header and registered descriptions/player limits. Installed Chess and Blindshot appear side by side; future modules populate the same responsive grid.
- Fixed multiplayer artwork proportions at all card widths and changed the selected game's button label to Selected.
- Added explicit Join/Resume actions, Waiting/Starting/In Game/Unavailable labels and actual module/version/capacity/session eligibility reasons to party listings. Expired or out-of-party listings are hidden and stale clicks are revalidated.
- Expanded player slots into responsive cards with name, host/local role, index and Ready state. Joined/Ready totals, countdown and actions occupy the footer; narrow layouts scroll the player area.
- Preserved the existing host-authoritative Ready/countdown/start protocol, game modules, artwork, settings and save schema. No remote push or release package was produced for this redesign.

## 0.16.1 - Local test controls, single-target shots and lobby slots

- Added always-visible New test game / Leave test controls to local Chess and matching restart/exit buttons in its local result popup. Local play still controls both sides without network traffic or records.
- Blindshot now hits only the nearest living opponent along the ray. The tracer ends at that opponent's hit-circle surface; no piercing or additional elimination credit. Blindshot protocol is now 3, requiring the same update on all participants.
- Clients derive FIRING and ROUND_END from the full timed reveal plan instead of receiving redundant full-plan broadcasts. This prevents message-queue growth across multiple five-player rounds.
- Replaced lobby roster text with player-capacity slot rectangles showing names, Open Slot and Ready/Playing state: two for Chess, five for Blindshot. Empty slots reflect lobby membership, not the party roster.
- Added lobby slot/layout tests and updated Chess local lifecycle and Blindshot nearest-hit, tracer, multi-round transport and recovery tests.

## 0.16.0 - Blindshot firing order and arena

- Replaced simultaneous fire with one host-shuffled order per round, authoritative piercing-shot events, immediate per-shot elimination and skipped dead turns. Living shooters fire 0.8 seconds apart.
- Added versioned sequence IDs, compact millisecond clocks, local event playback, duplicate/stale rejection and host/guest recovery during firing. Blindshot protocol version is now 2; every party member needs the update.
- Rebuilt the native arena with layered stone masonry, a floating lower edge, etched rings and cyan boundary glow. No additional runtime art files are required.
- Added masked player portraits, fallback fantasy tokens, colored order badges, local-player rings, current-shooter pulse, animated tracer, impact flashes, death crosses and a compact combat log.
- Updated local tests to use the same sequence engine and added timeline, delayed-message, skip, multi-kill, reload and UI coverage. No shared Options or lobby behavior changed.

## 0.15.0 - KIC Blindshot

- Added `/kicblindshottest` (alias `/kicblindshot`) for local testing with 2–5 simulated participants, real phases/UI, restart/exit controls and no party traffic or multiplayer records.
- Added a 2–5 player PARTY-only Blindshot module using the shared Host / Join / Ready / countdown flow.
- Added hidden position/aim selection, lock acknowledgements/retries, a 15-second timeout with documented fallback, simultaneous multi-hit rays, elimination, shrinking platforms and a bounded 12-round draw rule.
- Added a three-column native arena UI, both supplied artwork assets, scaled click/right-click controls, hidden/spectator markers, reveal/fire effects and a result popup.
- Added compact validated state messages, startup synchronization, host/guest reload recovery and shared clean interruption on party departure.
- Added lifetime match/win/draw/round/elimination records and validated optional result metrics without changing other games' records.
- Preserved original artwork outside the addon and normalized runtime TGAs to WoW-compatible dimensions; no substitute art generated.
- Added simulation, protocol, two/five-client transport and UI tests. See `BLINDSHOT.md` for rules, limitations and live party test steps.

## 0.14.0 - Multiplayer Chess

- Unified Chess with the shared multiplayer Host / Join / Ready / three-second countdown flow, replacing challenge popups. Added reusable lobbies, round-specific match IDs, version checks and lobby-aware recovery for rematches.
- Fixed the four promotion piece icons rendering behind their button backgrounds.
- Fixed Chess invitations appearing behind the launcher and added Accept/Decline challenge controls directly to the Chess panel.
- Added `/kicchesstest` (alias `/kicchess`) for local play of both sides using the real Chess UI and rules, with restart/exit commands and no multiplayer records or recovery saves.
- Added two-player Chess through targeted challenges in ordinary 2-5 member PARTY groups. The challenger remains the authority independently of color or group leadership.
- Added pure Lua rules, legal king safety, castling, en passant, four promotions, FEN, SAN, repetition, draw claims and automatic draws.
- Integrated all twenty supplied Chess textures into the launcher, three-column board UI, highlights, capture trays and promotion picker.
- Reused existing addon-message and action/state APIs with participant, sequence, turn and digest validation. No WHISPER or visible party-chat messages.
- Added persistent journals, bounded recovery chunks, reload/reconnect reconciliation, rollback refusal and safe interrupted results. Closing the UI preserves the match.
- Added lifetime Chess records and idempotent completed results. Existing singleplayer records/settings remain intact.
- Added engine, session, recovery, artwork and UI regressions. See `CHESS.md` for live test instructions and the conservative dead-position detection scope.

## Unreleased - KIC Bejeweled mode selection

- Every new run, restart and replay offers a Normal / Roguelike popup; reopening an active run preserves its mode.
- Normal keeps Bombs, Zaps and Orbs without Energy, levels, power cards or survival drain. Roguelike retains the existing survival rules.
- Mode selection blocks play until a choice, with a Back to Launcher action to cancel.
- Normal reuses the untimed best-score bucket; Roguelike keeps its separate Arcane Rush bucket. The picker shows both records, and gameplay/sharing/launcher/Results identify the selected mode.
- Added integration coverage for selection, cancellation, Normal special combos and unlimited thinking time, Roguelike drafts, mode switches, restart/reopen and isolated records.

## Unreleased - Arcane Rush integration fixes

- Fixed reshuffles with special-gem overlays and restored static artwork after animation.
- Reflowed the right statistics column so Energy and active powers fit alongside all statistics.
- Launcher, Results, gameplay and sharing now use the Arcane Rush best, preserving legacy records.
- Accepted swaps update streak and quick-swap state before first-wave scoring; invalid swaps preserve it.
- Gem Magnet skips gems already attuned instead of recoloring them away from its target.
- Updated overlay, artwork and draft-aware checks; added real-renderer integration regressions for these fixes.

## Unreleased - KIC Bejeweled name

- Standardized KIC Bejeweled throughout module names, game ID, files, artwork, tests and documentation.
- `/kicbejeweled` now opens KIC Bejeweled; standard Bejeweled uses `/bejeweled`. The previous command remains a compatibility alias.
- Existing scores, history and recent-game entries migrate automatically to `kic_bejeweled`, preserving untimed and Arcane Rush records separately.

## Unreleased - KIC Bejeweled special gem readability

- Bombs now have octagonal ember armor, hazard teeth and a compact fused explosive core; Lightning has cyan directional brackets and a bold white bolt; Color Orbs have a circular rainbow halo, orbit and prismatic core.
- Underlying original gems and class/spec spell icons remain visible. Geometry is cached per tile, while existing update timing gives glow layers a subtle pulse. Small labels are secondary.
- Added visual regressions for both graphics modes, interface scales, label-independent silhouettes and center emblems; reviewed an offline board-size preview. Live WoW rendering remains to be checked.

## Unreleased - Manual Bejeweled hints

- Restored Hint buttons in standard Bejeweled and KIC Bejeweled, with a visible three-use allowance per run. Removed automatic hints; both suggested tiles retain the existing vertical bounce.
- Pause/reopen preserves remaining uses; restart restores three. Blocked/no-move requests and repeat clicks on an active hint do not spend uses.

## Unreleased - KIC Bejeweled special visuals

- Replaced opaque special overlays with thin orange/cyan/rainbow corner rails and small bottom badges, keeping gem and class/spec icons readable during swaps, falls and dragging.
- Bombs now produce expanding fiery shockwaves and debris; Lightning discharges along affected rows and columns; Color Orbs send descending cyan/violet bolts to every cleared color target (all 64 cells for Orb + Orb).
- Special clears wait for their impact animation; effects respect pause, restart/stop, scale, board clipping and Off/Subtle/Full settings. Recycled textures have a fixed budget and do not use game RNG or timers.
- Added dedicated effect regressions and inspected an offline geometry preview. Live WoW rendering still needs verification.

## Unreleased - Direct Share Best

- Share Best in Tetris, Bejeweled and KIC Bejeweled now sends directly to instance (`/i`) chat on an explicit click or share command. No chat draft or Enter key is required.
- Replaced pipe separators with hyphens and sanitized the shared sender. Outside an instance group, show a local notice instead of switching channels.

## Unreleased - KIC Bejeweled

- Added standalone `kic_bejeweled` with Bomb, Lightning and colorless Orb creation, all special combinations, bounded chain resolution and deterministic cascade scoring.
- Reused Bejeweled's board UI, directional drag, animations and lifecycle with separate state and saved scores. Standard Bejeweled's engine and all Tetris gameplay remain unchanged.
- Integrated supplied KIC Bejeweled hero/card art, launcher/recent/results/resume paths, special overlays in both graphics modes, and existing volume-controlled audio events.
- Added dedicated engine/client integration tests and documented rules, scoring, file inventory and live-client checks in `KIC-BEJEWELED.md`. No remote push or release ZIP.

## 0.13.0 - 2026-10-15 - Options 2.0

- Bejeweled drag swaps now trigger on entering/crossing an actual adjacent tile rather than a full-tile displacement. Gaps and diagonal cells do not trigger; fast drags detect the first crossed neighbor, with one attempt per press and existing rollback/click behavior preserved.
- Returning from gameplay features the active game on Home, including its artwork, title and resume action, while preserving the paused session.
- Mute Sounds now shows ON when muted and OFF when audible. Muting disables previews and dims/disables the volume slider without losing its saved level; unmuting restores controls. Audio help now describes Master routing.
- Replaced Options with embedded Graphics, Audio and Window tabs using shared premium frames, neon choices, class/spec selectors, toggles, sliders and live previews.
- Class and specialization now use side-by-side icon dropdowns in one panel. The spec menu follows the selected class; long lists scroll, menus dismiss on selection/Escape/outside click/navigation, and Follow My Character locks both controls while preserving manual choices.
- Graphics and Audio now fit on one page with their previews. Both tabs expose the same shared Follow/class/spec profile; Original Graphics and Arcade Sounds dim and disable their corresponding profile controls. New preferences default to Class Spells, Follow ON and Class & Specialization audio, preserving existing saved choices.
- Added API-enumerated class/spec metadata, 40 distinct seven-icon profiles, stable spec IDs, remembered manual choices and Follow My Character specialization updates.
- Added original faceted gem and beveled block textures, with live cosmetic switching for both games, NEXT and HOLD.
- Added a shared extensible audio registry, actual gameplay event hooks, separate arcade/spec sound themes, enable/volume controls, playable previews, throttling, bounded overlap and safe fallback kits. Current SoundKits receive per-sound volume; spell files explicitly follow WoW SFX volume, while Off/0% mute everything.
- Migrated shared settings without resetting records, results, recent games or sessions. Window now has only a 75%-150% scale slider in 5% steps and optional 100% reset; removed resize controls and stopped applying obsolete saved dimensions.
- Added current asset audits, specialization/audio/migration/scaling regressions and offline previews. Missing sound mappings and replacement art are documented. No ZIP or live WoW testing.

## 0.12.0 - 2026-10-15 - Both gameplay screens

- Bejeweled now swaps during a held directional drag at exactly one rendered tile width/height along the dominant axis. It measures from mouse-down with effective UI scale, swaps only one neighbor once per gesture, suppresses release clicks, and cancels outside-board destinations. Temporary tracking ends immediately on trigger/release/cancellation; matching, scoring and rollback timing are unchanged.
- Increased pause-menu contrast in both games with a board dimmer, opaque navy surface, brighter cyan frame, larger heading and centered compact card.
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
