# Options 2.0 checkpoint - 0.13.0

The complete Graphics/Audio/Window page is embedded in the existing Launcher's
right content region. It reuses Theme/GameplayUI components and the supplied
Options mockup's navy/cyan/violet visual language. The explicit new requirements
take precedence over the old mockup's popup, accent colors and extra window
controls. No release ZIP was made.

## Implemented systems and changed files

- `Options.lua`: compact single-page Graphics/Audio tabs; premium theme choices;
  side-by-side class/spec icon dropdowns and Follow controls on both pages, sharing
  one saved profile. Original Graphics disables and dims the graphics profile
  controls; Arcade Sounds does the same on Audio, preserving all saved choices.
  Includes a read-only six-piece game-specific preview, real audio preview
  buttons, Enable toggle and shared native sliders. The base/minimum canvas fits
  both pages including previews without scrolling; clipped scrolling remains a
  fallback for future modules with extra preview events.
  Window has one 75%-150% Interface Scale slider, 5% increments, and optional
  Reset to 100%. No presets, dimension fields, aspect controls or resize grip.
- `Profiles.lua`: one runtime class/spec catalog from `GetNumClasses`,
  `GetClassInfo`, `C_SpecializationInfo.GetNumSpecializationsForClassID` and
  `GetSpecializationInfoForClassID`. Names/icons/roles come from the client; spec
  IDs are stable saved keys. No hardcoded specialization counts. Player detection
  reads current class and specialization; it never changes the player's spec.
- `ProfileData.lua`: asset curation for 40 specs, including Devourer, with seven
  distinct icon slots per profile. It does not define the selectable catalog.
  API-discovered future specs get a visible specialization/class-icon fallback
  before curation. `IconPresets.lua` remains the legacy class fallback catalog.
- `Settings.lua`: schema-2 migration, shared choices and validated setters. Manual
  selections survive Follow mode. Spec-change/enter-world/login events refresh
  the following profile and UI. Neither cosmetic nor audio changes reset models,
  scores, queues, RNG, bests, results or recent launches.
- `Graphics.lua`: per-game original-piece providers and shared icon/preview API.
  `Artwork.lua`, `Media/KICUI/Pieces/`, `tools/generate_original_pieces.py`: seven
  original faceted gems and one neutral beveled block, tinted by Tetris piece kind.
- `Audio.lua`: logical event registry, game/spec profiles, enabled/zero-volume
  gates, tracked sound handles, immediate stop, preview playback, throttling,
  at-most-two remembered voices, priority end sounds and verified kit fallback.
- Tetris `UI.lua`/`Module.lua`: live original/spec board, ghost, NEXT and HOLD
  rendering; instance adapters forward unchanged Move/Rotate/Hold/Lock rules and
  then report relevant sound events. Starting Tetris preserves Follow mode.
- Bejeweled `UI.lua`/`Module.lua`: original/spec piece and drag artwork, selection/
  swap/clear/cascade/end sound hooks. Directional one-tile drag semantics remain.
- `Core.lua`, TOC, README, game guides, CHANGELOG: initialization/load order,
  version and new usage. No engine, network, lobby or result protocol changes.
- Tests: expanded framework mock/spec fixture, independent asset snapshots,
  `options_assets.py`, artwork/TOC coverage and offline constructor snapshots.

## Saved settings and compatibility

Under `KICGamesDB.settings`: `schemaVersion=2`, `graphicsTheme` (`class/original`),
`manualClass` (class token), `manualSpecID`, `manualSpecs` (remembered per class),
`followCharacter`, `soundTheme` (`arcade/class`), `soundsEnabled`, `soundVolume`
(0..1, default .6), `windowScale` (.75..1.5, default 1).

Existing `classPreset` or old Tetris preset migrates to manual class selection;
the initial manual spec is the first available one from the client API. Missing
preferences default to Class Spells, Follow My Character ON and Class &
Specialization audio. Explicit saved Original/Arcade/manual choices survive;
disabled profile controls keep their values, and each page's theme only gates its
own controls. Class audio can be configured while graphics uses Original.
Legacy windowWidth/windowHeight are retained as unused data. The user canvas
starts at 1120x700; the old public sizing hook remains only for module/testing
compatibility and does not persist or expose dimension settings.

Scale is absolute relative to UIParent, not cumulatively multiplied. Child UI
inherits it; UIParent-owned result dialogs receive the same applied scale.
Scale changes center/clamp the window. If the requested scale cannot fit, a smaller
applied scale is shown explicitly while the requested percentage remains saved.
Display/UI-scale events recalculate fitting. No board rebuild or game reset is
needed, and active pointer tracking is safely cancelled when scale changes.

## Audio API audit and limitations

The checked [Retail Sound API declaration](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua)
supports `volumeOverride` in `C_Sound.PlaySoundWithOptions` and the sixth argument
of `C_Sound.PlaySound`. Arcade playback uses that capability. The eleven selected
kits are checked against Blizzard's
[SoundKit constants](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua).
SpellIDs are never treated as SoundKitIDs.

The 29 available curated spec audio profiles use named, verified archive spell
**FileDataIDs**, played through `PlaySoundFile(..., "SFX")`. That path has no
implemented independent per-effect volume control. The Audio page states this:
nonzero file effects follow WoW SFX volume; the slider independently controls kit
effects, while 0%/Off stops and gates both. Changing volume stops existing handles
because there is no per-handle gain setter here. Legacy clients without the modern
kit API likewise use explicitly reported SFX-level playback. No global CVars change.

Missing file playback or rejected files fall back to a verified arcade kit.
Eleven specs need curated spell audio; all specs use arcade end/victory effects,
and two partially mapped profiles need additional clear/combo files. The exact
per-profile/event gaps and icon substitutes are in
[MISSING_ASSETS.md](MISSING_ASSETS.md). They are visible fallbacks, not claims that
every specialization has a complete bespoke sound set. Raw client asset metadata
does not establish actual sound duration, loudness or availability in the user's
installed build; listening checks remain required.

## Reuse APIs

```lua
local token, specID = KICGames:GetSelectedProfile()
local icons = KICGames:GetPieceIcons("bejeweled") -- seven array entries
KICGames:SetOption("graphicsTheme", "original")
KICGames:SetManualClass("MAGE") -- rejected while following
KICGames:SetManualSpec(62)
KICGames:SetOption("followCharacter", true)
KICGames:SetOption("soundTheme", "class") -- independent of graphics mode
KICGames.Audio:Play("tetris", "clear")
KICGames.Audio:StopAll()
```

Future modules register original assets with
`Graphics:Register(gameID, {original={seven textures}, tint=false})`, and logical
events with `Audio:RegisterGame(gameID, {clear={kit=verifiedID}, ...})`.
Register before UI creation to appear in preview game choices. The Options page
is registry-driven, with no game-specific settings code required. Add curated
art via `Profiles:Register(specID, {class=token, icons={...}})` or central data;
audio replacements use `Audio:RegisterSpec(specID, {clear={kit=verifiedID}, ...})`.
Using curated kits for future spec audio also enables independent volume.
`Theme:SettingsSlider` uses native input with shared colors and state text.

## Verification

Run `lua tests/tetris.lua`, `lua tests/bejeweled.lua`, `lua tests/framework.lua`,
`python tests/artwork.py`, `python tests/options_assets.py`, StyLua Lua51 checks,
and `git diff --check`. The full integration suite covers API catalog expansion,
all 40 curated specs and distinct icons, profile selection/follow events/manual
restore, live original/class previews, unchanged active game models, audio
enabled/volume/preview/failure/legacy/throttle/game-event paths, persisted settings
and bests, screen fitting, disabled-theme profile behavior, shared audio profile
controls, and single-page layout at 75/100/120/150% on the minimum canvas.
Standalone engine suites and multiplayer integration regressions remain included.
Final results: **2,549** framework assertions, **44,303** Tetris assertions and
**68,272** Bejeweled assertions; all texture/profile/TOC, Lua51 and whitespace
checks pass. Tetris best records also retain optional graphics/spec metadata so
an Original-block record is shared accurately after later theme changes; old
records keep their original class labels.

Independent audit fixtures verify 280 icon slots (273 unique texture files),
266 successful spell metadata mappings, archive-pinned substitutes, 29 sound
profiles, 11 SoundKit constants, 32 runtime TGAs and TOC ordering. Fixtures are
development data, not runtime catalogs. Texture/sound archive verification was
performed on 2026-10-15; IDs are not invented.

Offline constructor JSON/Pillow previews were inspected under
`D:/WowAddons/.tools/kic-games-ui-preview/options2-*.png`, including each tab at
75/100/120/150%, compact audio, original gems/blocks, disabled profile controls
and class audio limitations.
These are not live WoW screenshots. Approximate font metrics and mocked native
slider positioning cannot replace in-client visual/input/listening checks.

## Live WoW checklist

1. `/reload`; open Options from the sidebar and each game's Options action.
   Confirm three tabs, safe Back to game, and the entire Graphics/Audio content
   including previews visible without scrolling, especially at 1000x700.
2. Inspect every class and its client-provided spec list, especially Devourer and
   all Evoker/Druid specs. Compare Arcane/Fire/Frost and all same-class profiles;
   verify seven visible matching symbols in Bejeweled and NEXT/HOLD/ghost in Tetris.
3. Switch Original/Class graphics during each active run. Verify the same board,
   queue, held piece, score and high score; resume normal input/one-tile drag.
   Original must dim and disable Follow/class/spec. Class audio remains editable
   on Audio; Arcade Sounds must dim only that page's profile controls.
4. Select a manual class/spec, enable Follow, change actual character spec through
   WoW, then disable Follow. Confirm automatic update, locked selectors and manual
   restoration. Changing addon settings must never change the player's real spec.
5. Preview arcade audio for each game at 0/25/60/100%, then disable sounds during
   an effect. Check mute/stop, gameplay selection, moves, swaps, landing, clear,
   cascade/combo and game over. Listen for excessive overlap or long borrowed files.
6. Select Original graphics plus class audio; compare Mage schools and other
   profiles. Confirm the SFX-volume notice and documented fallback status. Off/0%
   must mute files too. Confirm WoW's global audio settings stay unchanged.
7. Set Interface Scale to 75/100/120/150% repeatedly, move the window, scale again,
   and use a smaller screen. Check clipping, scrolling, square cells, Tetris ratio,
   auxiliary results, pointer tracking and the explicit screen-fit note.
8. Verify Window contains only Interface Scale and its optional reset. No resize
   grip, width/height controls, presets, aspect control or second scale control.
9. Reload/relog with manual and Follow configurations, audio disabled, and a
   nondefault scale. Confirm all settings, previous bests, results and recent
   launches survive. Active runs still follow the existing nonpersistent reload
   lifecycle. Verify multiplayer host/join/ready/countdown/stop with a second client.

No live WoW testing was performed in this environment.
