# KIC-Games code review and implementation report

Date: 2026-10-15. Baseline: `395247a` (`Swap Bejeweled tiles when dragging across a neighbor`).
Target retained: addon **0.13.0**, interface **120105**, framework protocol **v3**.

## 1. Executive summary

The project entered this review with a clean tracked working tree and a substantial passing test suite. Its strongest foundations are the independent rules engines, explicit game registration, per-round contexts, defensive payload validation, authoritative host model, separate urgent-control transport, pooled UI elements, and checked graphics/audio fixtures. A rewrite was neither necessary nor justified.

The review found real gaps outside the existing tests: character switching discarded saved match history; membership changes could retain obsolete readiness; module callbacks could replace or clear a session underneath lifecycle code; failed startup reported success; malformed roster tables escaped complete validation; delayed rejection messages could cancel a newer join; routine refreshes closed dropdowns; and minimap drag cleanup and saved-angle validation were incomplete. Tetris also repeated persistence work while idle and repaint work while chat had focus.

These paths are corrected, with **16 focused regression scenarios / 40 assertions** added to the existing integration harness. Fifteen scenarios reproduce pre-existing defects; the final scenario guards a saving regression caught and corrected during the second review of this change. Existing gameplay rules, visual layout, keybindings, slash commands, asset IDs, settings keys, and saved record formats remain intact. The shared 20-record account history limit remains intact; filtering by character now happens when reading results, rather than destructively at login.

This is a stronger Beta candidate, not a claim of live-client certification. No WoW client was run. The remaining release checks and upstream transport limitations are explicit below.

### Review coverage

All **30 TOC-loaded Lua files** were inspected: 25 addon-owned files and five vendored library files. Development generators, test suites/fixtures, TOC, vendor manifest, and current API/game documentation were also reviewed.

| Area | Files and conclusions |
| --- | --- |
| Initialization and public API | `Core.lua`, TOC: library/dependency order is valid; saved initialization precedes login UI creation; registry and callback protections retained. Startup and teardown isolation strengthened. |
| Multiplayer | `Communication.lua`, `Lobby.lua`, `Countdown.lua`, `Results.lua`: checked sender/channel/session/round/version guards, readiness, retries, countdown tokens, join acknowledgments, interruption, host timeout, result reconciliation and managed timers. Fixed the issues listed below. |
| Shared presentation | `Artwork.lua`, `Theme.lua`, `GameplayUI.lua`, `UI.lua`, `Launcher.lua`, `Options.lua`, `ResultsUI.lua`: inspected native frame construction, clipping, reuse, navigation, pause behavior, input propagation, scale, dropdowns, results and auxiliary windows. No layout redesign. |
| Profiles and persistence | `IconPresets.lua`, `ProfileData.lua`, `Profiles.lua`, `Settings.lua`, `Graphics.lua`, `Audio.lua`: inspected all 40 profiles, original providers, manual/follow selection, migrations, fallbacks, audio resolution and throttling. Existing IDs retained. |
| Bejeweled | `Games/Bejeweled/{Engine,UI,Module}.lua`: checked matching, crossing/long matches, invalid-swap rollback, scoring, cascades, gravity, hints, directional drag, scale cancellation, pause, completion and best scores. |
| Tetris | `Games/Tetris/{Engine,Presets,UI,Module}.lua`: checked bag, collision, rotation/kicks, hold, gravity, lock delay/reset cap, line compaction/scoring, top-out, keyboard repeat, pause, completion and best scores. |
| Dependencies and packaging | LibStub, CallbackHandler, ChatThrottleLib, AceComm, AceSerializer; six vendor/license hashes; all TOC paths and 32 runtime textures. Vendor sources and binary assets were not modified. |

## 2. Problems found and fixed

Severity reflects impact in the affected path, not an assertion that every user would encounter it.

| ID | Severity | Location | Original problem and implemented solution |
| --- | --- | --- | --- |
| R01 | High | `Results.lua`: `InitializeResults`, `GetResults`, `RecordResult` | Account-wide SavedVariables were filtered destructively to the character logging in. Preserve all valid retained records during initialization; filter personal results on reads and select the newest personal `LastResult`. No migration or key rename. |
| R02 | High | `Lobby.lua`: `Receive(JOIN)`, `RemoveMember`; readiness paths | Joining/leaving a waiting lobby did not reset existing ready flags or invalidate queued READY packets. Centralized `InvalidateReadiness` clears flags and advances the existing epoch. Rejoining with a new request before launch refreshes compatibility and cancels countdown; an identical request is idempotent. Running-match recovery is preserved. |
| R03 | High | `Core.lua`: `StartModule`; `Results.lua`: `FinishRound`; `Lobby.lua`: reset/leave/departure/snapshot paths | Hooks can complete, leave or replace their session. Old code could dereference a cleared lobby or stop the replacement game. Capture and recheck module/session/round ownership after callbacks; detach reset state before teardown callbacks. Apply the guards on both host and guest paths. |
| R04 | Medium | `Core.lua`: `StartModule`; `Lobby.lua`: `LaunchGame` | An `OnStart` or UI-factory failure could still return launch success. Startup now returns an explicit result, and failure finalizes only the failed session as interrupted and returns `false, reason`. Recent-game history still requires a successful active launch. |
| R05 | Medium | `Communication.lua`: `IsArray`; `Lobby.lua`: `ValidSnapshot`; `Results.lua` validators | Roster validation used `#` and `ipairs` without excluding keyed/sparse data. Reuse the result validator's dense-array rule for both results and rosters, so every accepted roster entry is validated. |
| R06 | Medium | `Lobby.lua`: `Receive(REJECT/JOIN)` | A rejection for an older request to the same host/session could cancel a new pending join. Hosts now echo the request ID and updated guests ignore mismatching rejection IDs. The optional field is compatible with protocol v3; request-less legacy rejections remain accepted. |
| R07 | Medium | `Options.lua`: `Theme:SettingsDropdown` / `SetOptions` | Every routine refresh closed/repopulated profile menus, including lobby heartbeats. Compare entry keys/names/icons, selection and enabled state; retain the open menu when unchanged. Real option/catalog changes still close it, and stale selected indices are cleared. |
| R08 | Medium | `Core.lua`: SavedVariables initialization | NaN/infinite minimap angles passed `tonumber` and reached trigonometry/frame positioning. Reject nonfinite values and normalize valid angles modulo 360. Existing valid positions remain equivalent. |
| R09 | Low | `UI.lua`: `CreateMinimapButton` | Hiding the minimap during a drag retained its temporary OnUpdate handler. Share cleanup between OnDragStop and OnHide. |
| R10 | Low | `Games/Tetris/UI.lua`: `Advance` | Idle updates repeatedly normalized saved data; chat focus repeatedly released keys and repainted an already-paused game. Save when the score changes, tracked independently of drawing; pause once on the focus transition. Existing stop/share persistence paths remain. |
| R11 | Low | Bejeweled/Tetris UI and modules; `UI.lua` | Removed unreachable drag-target highlighting, permanently hidden preset labels and their setters, and the obsolete undefined `StopResize` branch. No visible elements removed. |
| R12 | Low | README, game manuals and `GAME-API.md` | Public docs still described the superseded SFX routing and omitted the profile audit command. Corrected Master-channel descriptions, documented history retention and startup failure behavior, and linked the audit. Historical design checkpoints remain historical records. |

## 3. Architecture improvements

- **Readiness has one operation.** `Lobby.lua:InvalidateReadiness` owns clearing ready flags and advancing the epoch. Membership changes, game selection, completed rounds and countdown resets reuse it. Transport fields and the existing state machine remain unchanged.
- **Array validation belongs to shared data validation.** The former private `Results.lua` array helper moved to `Games:IsArray` in `Communication.lua`. Both roster and result validation use it; there is no new validation framework or runtime file.
- **Lifecycle work is scoped to its owner.** Startup/finish/reset paths no longer assume that module hooks leave the active session unchanged. Guards protect replacement sessions without changing hook signatures.
- **History storage and personal presentation are separated.** Account storage is not destructively rewritten to serve a character-specific view.
- **Dropdown refresh is conditional.** Unchanged option data reuses existing rows, scripts and open state. This also removes needless work on routine refreshes.

The independent engines, existing shared theme, original graphics providers, class/spec catalog and audio backend were retained. There was no justification for consolidating the two different gameplay loops or rewriting the Options page. No new dependency, service, global event bus, gameplay framework or public API rename was introduced.

## 4. Removed code

| Removed implementation | Evidence and replacement |
| --- | --- |
| Private `Results.lua` `array` helper | Identical responsibility is now shared through `Games:IsArray`; callers updated. |
| Repeated ready-reset loops | Replaced by `InvalidateReadiness` where clearing readiness and advancing the epoch are one state transition. Guest receipt of host control packets still applies host-provided epochs. |
| Bejeweled `dragTarget` resets/read/highlight branch | Whole-repository search found no non-nil assignment. Actual dragging commits immediately when crossing a neighbor; it does not maintain a pending target. |
| Both games' `presetLabel` font strings and setter branches | Created hidden, never laid out or shown; active profile presentation already belongs to Options. |
| `UI.StopResize` conditional call | No assignment, implementation, callback registration or documented API exists; the resize grip was already removed. Normal StopMovingOrSizing remains. |

No files, binary assets, saved keys or public compatibility aliases were deleted. `Tetris/Presets.lua`, `GetIcons`, `SelectPreset`, `EndGame`, shared component APIs and internal sizing hooks remain because tests, documented consumers or external modules may use them. Untracked source/reference artwork was preserved, including files that are not shipped by the inner addon directory.

## 5. Bugs corrected and behavior preserved

The regression scenarios cover login on two characters and back; waiting-roster changes and old READY packets; countdown rejoin and duplicate JOIN handling; malformed rosters; stale/matching/legacy rejection packets; failed startup; UI factories that replace their game and then fail; result hooks that leave or launch another game; guest result/departure callbacks; menu refreshes; nonfinite saved angles; and minimap drag teardown.

The engine review found no verified rule defect requiring an engine change. Specifically:

- Bejeweled unions matched cells, counts crossing intersections once, rejects unmatched swaps without consuming moves, preserves falling-gem order, and scores `50 * cleared cells * cascade`. Its longest straight match selects 3/4/5+ audio; disjoint or crossing triples are not incorrectly promoted solely by total cell count. Directional drag and its one-attempt-per-press behavior remain intact.
- **Bejeweled has no reshuffle mechanic.** It deliberately ends a settled no-move board, as documented in `BEJEWELED.md`. Adding automatic reshuffling would change the requested preserved mechanics.
- Tetris retains seven-bag generation, single hold per lock, the existing small kick list, a 0.5-second grounded lock delay, the existing reset limit, and 100/300/500/800 line scoring at the pre-clear level. It is intentionally not full SRS and has no T-spin/combo/back-to-back bonuses.
- Pause, navigation, close/reopen, restart, result dialogs, scale controls, Original Graphics/Audio and chat drafts retain their existing interaction contracts. Active boards remain unsaved across reload, as before.

## 6. Performance improvements

Tetris no longer calls `SaveBest` on every unchanged update. The regression probe performs 20 idle updates with zero save calls, then changes the score and verifies a prompt save. A separate probe forces a cosmetic redraw between scoring and the next update and confirms that persistence still runs. The last saved score is reset for each new game. Chat focus causes one pause/paint transition and no repeated paints in the following 20 updates. These are call-count improvements, not measured in-game CPU or FPS claims.

Unchanged dropdown refreshes skip row rewriting and callback replacement, and preserve the open menu. A refresh test also verifies that it creates no new frames. Two permanently hidden font strings and unreachable per-cell drag-target checks are removed. Minimap drag polling is explicitly cleared on hide.

The existing revision-based Tetris board drawing, event-driven idle Bejeweled drawing, reused board textures/cards/menu rows, two-handle audio cap, discovery throttling, 15-second heartbeat, and bounded result history were retained. Large UI rewrites and speculative caches were avoided.

## 7. Remaining issues and verification limits

1. **Live client validation is still required.** No WoW process was run. Native rendering, hit testing at fractional effective scale, real keyboard/combat restrictions, actual audio mixing/asset presence, and server delivery cannot be certified by the mocks. Interface 120105 was retained rather than guessed or bumped.
2. **Spell audio is intentionally partial.** The fixtures contain 40 profiles with seven distinct icon choices each, 35 partial spell-audio profiles, 11 arcade SoundKits and 14 verified single-file kit adapters. Mistweaver, Devourer and the three Evoker profiles have no curated spell audio. Missing events use arcade fallbacks. Of 148 distinct spell files, 134 still lack an adopted independent-volume adapter. Two retained Feral legacy filenames have community evidence only. No IDs were invented or replaced during this review. Asset checks verify consistency with the recorded evidence, not fresh extraction from an installed client. See [the sound audit](SOUND_AUDIT_REPORT.md) and [Master backend report](AUDIO_MASTER_BACKEND.md).
3. **AceComm buffers before addon validation.** Its shared multipart spool has no timeout/byte cap, and KIC-Games' 12,288-byte/sender checks apply after reassembly. Incomplete or deliberately excessive fragmented input can therefore retain memory before those guards. The vendored shared library was not monkey-patched: that could affect unrelated addons and requires dedicated upstream/transport compatibility work. This is a remaining transport-hardening risk, not a claim of fully bounded network memory.
4. **Legacy request-less rejections cannot be correlated precisely.** Updated hosts include the request ID. Old v3 hosts remain compatible but retain the older retry-race limitation until upgraded; strict rejection of their packets would break compatibility.
5. **Third-party extension limits remain.** The launcher is registry-driven, but pause/layout/cosmetic application includes explicit adapters for the two bundled games. Options builds its provider selectors at login; late registration of new preview events/providers is not fully dynamic. The documented registration-before-play/load-order contract works; a generic live provider lifecycle would be a separate API change.
6. **Managed timer retention merits future hardening.** Completed one-shots are removed and all tracked timers are cancelled at stop, but a module repeatedly creating and manually cancelling timers can retain cancelled handles until the round ends. Neither bundled game uses those managed timers for its frame loop. A wrapper must preserve the documented native timer-handle API before this is changed.
7. **History remains bounded.** Character switching no longer erases other characters' retained records, but the existing account-wide limit still evicts the oldest record after 20. Previously deleted history cannot be reconstructed. Best scores remain account-wide and retain their existing keys.

Current API checks used Blizzard-generated client source mirrored in [SoundDocumentation.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua), [SpecializationInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua), and the client [class menu](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ClassMenu/Blizzard_ClassMenu.lua). The source supports the existing sound argument names/positions and specialization enumeration; it does not establish a native volume-mixing equation or certify the installed client build.

## 8. Test results

| Check | Before | Final |
| --- | ---: | ---: |
| `lua tests/framework.lua` | PASS, 3,555 assertions | PASS, 3,595 assertions |
| `lua tests/tetris.lua` | PASS, 44,303 assertions | PASS, 44,303 assertions |
| `lua tests/bejeweled.lua` | PASS, 68,272 assertions | PASS, 68,272 assertions |
| `python tests/artwork.py` | PASS, 32 runtime TGAs and TOC checks | PASS |
| `python tests/options_assets.py` | PASS, 40 profiles / 280 icon slots / audio evidence | PASS |
| `lua tests/framework.lua --audit` | New scenarios reproduce pre-fix failures | PASS, 16 scenarios / 40 assertions |
| `luac -p` | Final-only supplementary check | PASS, all 30 runtime Lua files |
| StyLua parser with `--syntax Lua51` | Final-only supplementary check | PASS, all 30 runtime Lua files |
| StyLua `--check` | Changed-file check | PASS, all changed/new Lua files |
| Vendor SHA-256 manifest | Sources retained | PASS, all six library/license entries |
| `git diff --check` | Tracked tree initially clean | PASS |

The runtime tests use **Lua 5.4.6**, mocked WoW APIs, and the real bundled serializer/communication/throttle libraries. Lua 5.1 grammar was checked separately with StyLua 2.5.2. This is not execution in WoW's Lua VM. No Luacheck installation was available; no claim of a separate semantic lint pass is made.

Existing suites exercise initialization and both registered games, navigation, settings migration/persistence, all 40 spec selections, original/class graphics, detailed audio tiers/fallbacks/mute/throttle/Master arguments, input and pause behavior, engine invariants, scaling, party/raid/instance channels, stale messages, timeout/rejoin, interruption, result deduplication and timer cleanup. New scenarios use the same isolated-client harness and are automatically included in the full framework suite.

**UI comparison:** generated 54 deterministic before/after snapshots from the actual UI constructors in isolated copies of baseline and updated sources. Visible-element dimensions, text, texture/style/layer/scale properties and local anchor offsets matched with **zero differences**. Frame allocation IDs and object-reference IDs were normalized, and hidden elements excluded. Existing parent/layout assertions also passed. This is a structural snapshot comparison, not a rendered pixel comparison or in-game visual test. Subsequent rejection and score-save fixes do not change UI construction or layout.

The original five suites had no baseline failure. Every newly reported failing scenario was reproduced before its fix; the first 14 were also rerun together against the original runtime. The added rejection scenario failed before its transport fix. The sixteenth scenario caught a regression in the initial optimization: using draw revision to decide whether to save allowed a cosmetic redraw to consume a pending score change. Persistence now tracks the last saved score independently, and the new regression test passes. One intermediate formatter check required a second formatter pass; the final formatting check passes. No unresolved automated test failure remains.

### Required manual smoke checks

- On the targeted Retail client, load/reload with existing SavedVariables, switch characters, and confirm retained history, personal filtering and best scores.
- Open every launcher page; operate both dropdowns through a heartbeat; exercise 75%, 100%, 120% and 150% preferences plus small-screen fitting. Check result dialogs and Escape/close behavior.
- Play both games through pause, chat focus, close/reopen, restart and completion. For Bejeweled, test all four drag directions, fast boundary crossing, invalid rollback, cascades and no-move completion at multiple effective scales. For Tetris, test hold, repeated keys, kicks, locking, all four clear tiers and top-out.
- Listen to Original and class/spec effects, including the five fallback-only profiles, missing-file fallback, mapped kits, unmapped files, Master volume changes, mute and 0%. Confirm actual mixing without changing global CVars from the addon.
- With two real clients and a test multiplayer module, exercise ready/unready, membership changes, countdown reload, running rejoin, disconnect, throttled large state transfer and urgent stop. The addon ships two solo games; mocked fixtures are not a shipped multiplayer game.
- Check input/close behavior when combat begins while a game or dropdown is open, with Lua errors enabled. No secure gameplay actions or new combat hooks were introduced.

## 9. Files changed

Modified runtime files:

- `KIC-Games/Communication.lua`
- `KIC-Games/Core.lua`
- `KIC-Games/Countdown.lua`
- `KIC-Games/Lobby.lua`
- `KIC-Games/Results.lua`
- `KIC-Games/Options.lua`
- `KIC-Games/UI.lua`
- `KIC-Games/Games/Bejeweled/Module.lua`
- `KIC-Games/Games/Bejeweled/UI.lua`
- `KIC-Games/Games/Tetris/Module.lua`
- `KIC-Games/Games/Tetris/UI.lua`

Modified tests/documentation: `tests/framework.lua`, `README.md`, `GAME-API.md`, `BEJEWELED.md`, `TETRIS.md`.

Added: `tests/audit_regressions.lua`, `design/CODE_REVIEW_REPORT.md`.

No files moved or deleted. No binary, TOC, engine, profile ID, vendor, version or unrelated project changes. No release ZIP created and no remote push performed.

Pre-existing untracked paths preserved and excluded from the local checkpoint: `CODEX_PROMPT.md`, `README.txt`, top-level `Media/`, `design/asset-manifest.json`, `design/references/`, and `design/sources/`. Validation copies/snapshots are development scratch data outside this repository.

## 10. Final release assessment

**Conditional go for a public CurseForge Beta after the manual smoke checks above.** Automated validation is green, confirmed defects are fixed, the final diff is limited, and the presentation comparison found no visible-property regression. The second review checked callback guards, readiness epochs, history compatibility, remaining duplication, dead code, load order and the final diff; its confirmed additional issues were fixed and retested.

The outstanding release gate is live-client QA, particularly keyboard/combat behavior, real sound/texture availability and two-client transport. Partial spell audio is a documented fallback limitation, not a missing core game feature. Upstream multipart buffering remains a hardening concern that should be tracked before claiming robust behavior against hostile traffic. An unconditional stable/production-ready release claim is not supported by this offline review.
