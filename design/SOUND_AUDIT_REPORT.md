# Targeted spell icon and sound audit

Date: 2026-10-15. Checkpoint base: `736cbca`. Research target: 12.1.5; no live WoW client was available for this audit.

## Results and limits

- **40 valid icon profiles**, exactly seven distinct named texture FileDataIDs each (280 slots). All 360 supplied candidates were compared. **63 slots replaced**, 217 retained. Original Graphics assets/providers and all seven Devourer icons are unchanged.
- **35 partial spell-audio profiles** resolve at least one specialization file; the other five use arcade effects. **34** have explicit new tier/cascade mappings. The existing 29 legacy profiles and their 84 sound FileDataIDs were retained.
- **91 distinct officially named FileDataIDs** back **186 explicit internal event mappings**; 27 were reused from the legacy pool, 64 were added. There are **148 distinct referenced spell files** in total: 146 have official/verified archive filename mappings; two unchanged Feral legacy files have community-name evidence only.
- **11 existing SoundKit IDs** remain verified against the checked Blizzard SOUNDKIT constants. **Zero of the 15 candidate research SoundKits were adopted**: a spell link and an example file do not establish exact kit membership, intended content or duration.
- Seven profiles have all four statically identified line-tier files: Fury (72), Retribution (70), Discipline (256), Enhancement (263), Fire (63), Destruction (267), Balance (102). These use four different ability names/files rather than variants of one clip. **No specialization has a complete, auditioned audio profile**; end/victory effects remain arcade for all 40.
- Static checks establish spell names, texture identities, filename-to-ID associations, event routing and fallback behavior. They do **not** establish audibility/presence in the installed client, perceived intensity, loudness, clip duration or current-build SoundKit membership. All new sound selections require in-game listening.

## Sources and verification

Research input: `design/import/KIC_Games_40_Specs_Spells_Sounds_2026-10-15.zip`.
Archive SHA-256: `c1810b5e198e34798cac92084380f46e451cc9c69655ac23ee5739a9291ea3ea`.

- Read all three supplied CSVs, the combined JSON and implementation notes. All 480 selected sound fields were blank. Candidate spell names/SpellIDs were never treated as sound IDs.
- Resolved supplied SpellIDs using the existing checked spell snapshot and [spell tooltip metadata](https://nether.wowhead.com/tooltip/spell/153626); mapped icon names to archive texture FileDataIDs. All 63 replacement slots also agree with exact official/verified archive filename mappings. Of 283 distinct supplied spell IDs, 278 resolved to named textures; exact-name comparison additionally rejected the Devouring Plague / Shadow Word: Madness name mismatch. Existing valid icons fill unresolved or duplicate choices. The five failed lookups were 121411, 19434, 194509, 205385 and 370452.
- Cross-checked every newly selected sound file against the [official/verified filename list](https://github.com/wowdev/wow-listfile/releases/latest/download/verified-listfile.csv), not just fuzzy community names. See the [listfile provenance and limitations](https://github.com/wowdev/wow-listfile#verified-listfile). The development fixture records every selected sound path and its filename-verification status.
- Retained Feral files 3055167 and 3151159 as existing working preferences, but did not promote them or the new unverified Feral/Guardian candidates to verified tier mappings. All newly selected tier files have exact verified names.
- Rejected misleading cross-class matches: Warlock Metamorphosis for Demon Hunter, Ulduar/Kologarn Eye Beam for Havoc, Consume Magic for Devourer Consume, and Fel Eruption for Evoker Eruption. Channel/state/precast/travel/loop files were excluded. The supplied 3.7-second Avenging Wrath cast was not selected; a named impact was used instead.

## Icon substitutions

Only slots absent from the selected verified priority set were replaced. Retained icons stay in their previous piece slots; this is a targeted curation change, not a claim that every prior icon was broken. Each replacement below is a verified higher-priority candidate from that specialization shortlist.

| Spec | Slot | Previous icon / FileDataID | Replacement / FileDataID (resolved SpellID) |
|---|---:|---|---|
| WARRIOR Fury (72) | 4 | Enraged Regeneration / 132345 | Execute / 135358 (SpellID 5308) |
| WARRIOR Protection (73) | 7 | Shockwave / 236312 | Ignore Pain / 1377132 (SpellID 190456) |
| PALADIN Holy (65) | 7 | spell_holy_crusaderstrike.blp / 135891 | Word of Glory / 133192 (SpellID 85673) |
| PALADIN Protection (66) | 6 | Blessed Hammer / 535595 | Word of Glory / 133192 (SpellID 85673) |
| PALADIN Retribution (70) | 4 | Crusader Strike / 135891 | Judgment / 135959 (SpellID 20271) |
| HUNTER Beast Mastery (253) | 5 | Beast Cleave / 461121 | Cobra Shot / 461114 (SpellID 193455) |
| HUNTER Beast Mastery (253) | 6 | Aspect of the Wild / 136074 | Multi-Shot / 132330 (SpellID 2643) |
| HUNTER Beast Mastery (253) | 7 | Revive Pet / 132163 | Kill Shot / 236174 (SpellID 53351) |
| HUNTER Marksmanship (254) | 6 | ability_hunter_aimedshot.blp / 132157 | Steady Shot / 132213 (SpellID 56641) |
| HUNTER Marksmanship (254) | 7 | ability_hunter_focusedaim.blp / 236179 | Kill Shot / 236174 (SpellID 53351) |
| HUNTER Survival (255) | 4 | Carve / 1376039 | Kill Command / 132176 (SpellID 34026) |
| HUNTER Survival (255) | 5 | Harpoon / 1376040 | Kill Shot / 236174 (SpellID 53351) |
| ROGUE Assassination (259) | 7 | Shiv / 135428 | Fan of Knives / 236273 (SpellID 51723) |
| ROGUE Subtlety (261) | 5 | Shadow Blades / 376022 | Black Powder / 608955 (SpellID 319175) |
| PRIEST Discipline (256) | 2 | Atonement / 458720 | Mind Blast / 136224 (SpellID 8092) |
| PRIEST Discipline (256) | 5 | Rapture / 237548 | Power Word: Barrier / 253400 (SpellID 62618) |
| PRIEST Discipline (256) | 6 | Purge the Wicked / 236216 | Shadow Word: Pain / 136207 (SpellID 589) |
| PRIEST Holy (257) | 4 | Guardian Spirit / 237542 | Flash Heal / 135907 (SpellID 2061) |
| PRIEST Holy (257) | 6 | Divine Hymn / 237540 | Heal / 135913 (SpellID 2060) |
| PRIEST Shadow (258) | 5 | Shadow Word: Madness / 7569529 | Void Torrent / 1386551 (SpellID 263165) |
| PRIEST Shadow (258) | 6 | Shadowfiend / 136199 | Dispersion / 237563 (SpellID 47585) |
| PRIEST Shadow (258) | 7 | spell_shadow_mindflay.blp / 462324 | Shadow Word: Death / 136149 (SpellID 32379) |
| DEATHKNIGHT Blood (250) | 6 | Bonestorm / 342917 | Death and Decay / 136144 (SpellID 43265) |
| DEATHKNIGHT Frost (251) | 6 | Frostscythe / 7439190 | Frostwyrm's Fury / 341980 (SpellID 279302) |
| DEATHKNIGHT Frost (251) | 7 | Breath of Sindragosa / 1029007 | Glacial Advance / 537514 (SpellID 194913) |
| DEATHKNIGHT Unholy (252) | 6 | Dark Transformation / 342913 | Outbreak / 348565 (SpellID 77575) |
| DEATHKNIGHT Unholy (252) | 7 | Unholy Blight / 136132 | Epidemic / 136066 (SpellID 207317) |
| SHAMAN Elemental (262) | 7 | Elemental Blast / 651244 | Chain Lightning / 136015 (SpellID 188443) |
| SHAMAN Enhancement (263) | 5 | Sundering / 524794 | Lightning Bolt / 136048 (SpellID 188196) |
| SHAMAN Enhancement (263) | 6 | Ice Strike / 135845 | Chain Lightning / 136015 (SpellID 188443) |
| SHAMAN Enhancement (263) | 7 | spell_nature_windfury.blp / 136114 | Flame Shock / 135813 (SpellID 188389) |
| SHAMAN Restoration (264) | 5 | Healing Tide Totem / 538569 | Healing Surge / 136044 (SpellID 8004) |
| SHAMAN Restoration (264) | 6 | Earth Shield / 136089 | Healing Stream Totem / 135127 (SpellID 5394) |
| MAGE Arcane (62) | 7 | Presence of Mind / 136031 | Arcane Orb / 1033906 (SpellID 153626) |
| MAGE Fire (63) | 7 | Dragon's Breath / 134153 | Scorch / 135827 (SpellID 2948) |
| MAGE Frost (64) | 6 | Icy Veins / 135838 | Frost Nova / 135848 (SpellID 122) |
| WARLOCK Affliction (265) | 5 | Malefic Rapture / 236296 | Drain Soul / 136163 (SpellID 198590) |
| WARLOCK Affliction (265) | 7 | Siphon Life / 136188 | Vile Taint / 1391774 (SpellID 278350) |
| WARLOCK Demonology (266) | 7 | Summon Vilefiend / 1616211 | Shadow Bolt / 136197 (SpellID 686) |
| WARLOCK Destruction (267) | 7 | Channel Demonfire / 840407 | Havoc / 460695 (SpellID 80240) |
| MONK Brewmaster (268) | 6 | Fortifying Brew / 615341 | Tiger Palm / 606551 (SpellID 100780) |
| MONK Brewmaster (268) | 7 | Rushing Jade Wind / 606549 | Exploding Keg / 7439206 (SpellID 325153) |
| MONK Mistweaver (270) | 4 | Revival / 1020466 | Sheilun's Gift / 1242282 (SpellID 205406) |
| MONK Mistweaver (270) | 5 | Life Cocoon / 627485 | Thunder Focus Tea / 611418 (SpellID 116680) |
| MONK Mistweaver (270) | 7 | ability_monk_essencefont.blp / 1360978 | Rising Sun Kick / 642415 (SpellID 107428) |
| MONK Windwalker (269) | 5 | Touch of Death / 606552 | Tiger Palm / 606551 (SpellID 100780) |
| MONK Windwalker (269) | 6 | Storm, Earth, and Fire / 136038 | Blackout Kick / 574575 (SpellID 100784) |
| DRUID Feral (103) | 7 | Primal Wrath / 1392547 | Brutal Slash / 132141 (SpellID 202028) |
| DRUID Guardian (104) | 5 | Barkskin / 136097 | Thrash / 451161 (SpellID 106830) |
| DRUID Guardian (104) | 6 | Survival Instincts / 236169 | Swipe / 134296 (SpellID 213764) |
| DRUID Guardian (104) | 7 | Incarnation: Guardian of Ursoc / 571586 | Berserk / 236149 (SpellID 106951) |
| DRUID Restoration (105) | 7 | Flourish / 538743 | Efflorescence / 134222 (SpellID 145205) |
| DEMONHUNTER Havoc (577) | 5 | Metamorphosis / 1247262 | Demon's Bite / 135561 (SpellID 162243) |
| DEMONHUNTER Havoc (577) | 6 | Immolation Aura / 1344649 | Annihilation / 1303275 (SpellID 201427) |
| DEMONHUNTER Havoc (577) | 7 | Essence Break / 136189 | Death Sweep / 1309099 (SpellID 210152) |
| DEMONHUNTER Vengeance (581) | 1 | Fiery Brand / 1344647 | Fracture / 1388065 (SpellID 263642) |
| DEMONHUNTER Vengeance (581) | 5 | Metamorphosis / 1247263 | Shear / 1344648 (SpellID 203782) |
| DEMONHUNTER Vengeance (581) | 7 | Infernal Strike / 1344650 | Fel Devastation / 1450143 (SpellID 212084) |
| EVOKER Devastation (1467) | 5 | Dragonrage / 4622452 | Deep Breath / 4622450 (SpellID 357210) |
| EVOKER Preservation (1468) | 5 | Rewind / 4622474 | Living Flame / 4622464 (SpellID 361469) |
| EVOKER Preservation (1468) | 6 | Temporal Anomaly / 4630480 | Verdant Embrace / 4622471 (SpellID 360995) |
| EVOKER Augmentation (1473) | 6 | Blistering Scales / 5199621 | Fire Breath / 4622458 (SpellID 357208) |
| EVOKER Augmentation (1473) | 7 | Source of Magic / 4630412 | Living Flame / 4622464 (SpellID 361469) |

Full nine-candidate comparisons, rejected resolutions and exact old/new texture paths are in `tests/sound-research.json`. Aimed Shot and Power Word: Radiance failed metadata resolution; their valid existing archive icons were preserved. No replacement uses a raw SpellID as a texture.

## Internal dispatch and fallback rules

- Tetris measures `m.lines` immediately before/after the unchanged lock operation. Zero lines emits only the existing landing event; 1/2/3/4 lines emit their respective `tetris_*` event once. Already-ended locks emit nothing. Move/rotate/hold/pause/game-over behavior and engine logic are unchanged.
- Bejeweled measures the longest contiguous horizontal or vertical run on the intact board before Step erases pending gems. Separate triples and intersecting triples remain match-3 even when total cleared cells is 5 or 6. Runs 5 through 8 map to match-5-plus. One event is emitted per resolution; scoring still uses the full pending-cell count and existing cascade multiplier.
- Cascade depth travels separately from run strength. For cascading 3/4 matches, a verified cascade effect or existing legacy combo can replace the basic sound; a 5+ iconic selection is not downgraded. There is no extra simultaneous cascade playback.
- Detailed mappings are explicit FileDataIDs in `ProfileData.lua`. Missing low-tier entries may reuse the existing valid legacy clear effect; remaining absent tiers use the existing verified arcade kits. No spell ID is inferred to be a sound ID.
- Arcade line-clear kits are 865 / 1204 / 10590 / 73279, and match kits are 1204 / 10590 / 73279. Arcade cascades use the existing combo kit. Actual file playback failure or a missing file API falls back to these kits without mutating the spec mapping or retrying a failed cascade indefinitely.
- Resolution effects take precedence over a just-played movement click, replace prior handles and share a 100ms per-game cooldown across tiers. Normal input throttling, bounded handles and priority end sounds remain intact.
- The public preview list remains exactly `select, move, swap, land, clear, combo, gameOver, victory`; no new UI controls are created. Profiles gaining new spell files also expose a valid existing preview event so the unchanged SFX-volume notice stays accurate. Mute/0%, kit volumeOverride, file SFX-channel behavior and file failure fallback remain functional.

## Per-specialization coverage and missing mappings

Legend: T1/T2/T3/T4 = four Tetris line tiers; B3/B4/B5 = Bejeweled contiguous runs; C = cascade override. `F` means explicit named event file, `L` a retained legacy low-tier/combo file, `S` another selected file exposed through the compatible clear/combo preview, `B` the base match sound without a separate cascade override, and `A` arcade fallback. Every non-`F` cell lacks an explicit candidate-specific mapping and still needs curation/audition. All files, including `F`, need current-client listening. Game over/victory are `A` for every row.

| Spec | T1 | T2 | T3 | T4 | B3 | B4 | B5 | C |
|---|---|---|---|---|---|---|---|---|
| WARRIOR Arms (71) | F | A | F | A | F | A | A | F |
| WARRIOR Fury (72) | F | F | F | F | F | F | F | F |
| WARRIOR Protection (73) | F | F | A | A | F | F | A | B |
| PALADIN Holy (65) | S | F | F | F | S | F | F | F |
| PALADIN Protection (66) | L | A | F | A | L | A | A | F |
| PALADIN Retribution (70) | F | F | F | F | F | F | F | F |
| HUNTER Beast Mastery (253) | F | A | F | F | F | A | F | F |
| HUNTER Marksmanship (254) | L | F | F | F | L | F | F | F |
| HUNTER Survival (255) | F | F | A | A | F | F | A | L |
| ROGUE Assassination (259) | F | A | F | A | F | A | A | F |
| ROGUE Outlaw (260) | F | F | F | A | F | F | A | F |
| ROGUE Subtlety (261) | F | F | F | A | F | F | A | F |
| PRIEST Discipline (256) | F | F | F | F | F | F | F | F |
| PRIEST Holy (257) | F | F | F | A | F | F | A | F |
| PRIEST Shadow (258) | L | F | A | A | L | F | A | L |
| DEATHKNIGHT Blood (250) | L | F | F | A | L | F | A | F |
| DEATHKNIGHT Frost (251) | F | F | F | A | F | F | A | F |
| DEATHKNIGHT Unholy (252) | L | F | F | A | L | F | A | F |
| SHAMAN Elemental (262) | F | F | F | A | F | F | A | F |
| SHAMAN Enhancement (263) | F | F | F | F | F | F | F | F |
| SHAMAN Restoration (264) | F | F | F | A | F | F | A | F |
| MAGE Arcane (62) | F | F | F | A | F | F | A | F |
| MAGE Fire (63) | F | F | F | F | F | F | F | F |
| MAGE Frost (64) | F | F | F | A | F | F | A | F |
| WARLOCK Affliction (265) | F | F | F | A | F | F | A | F |
| WARLOCK Demonology (266) | F | F | F | A | F | F | A | F |
| WARLOCK Destruction (267) | F | F | F | F | F | F | F | F |
| MONK Brewmaster (268) | F | F | A | F | F | F | F | L |
| MONK Mistweaver (270) | A | A | A | A | A | A | A | A |
| MONK Windwalker (269) | F | A | A | F | F | A | F | S |
| DRUID Balance (102) | F | F | F | F | F | F | F | F |
| DRUID Feral (103) | L | A | A | A | L | A | A | B |
| DRUID Guardian (104) | L | F | F | A | L | F | A | F |
| DRUID Restoration (105) | F | F | F | A | F | F | A | F |
| DEMONHUNTER Havoc (577) | S | F | A | A | S | F | A | B |
| DEMONHUNTER Vengeance (581) | S | F | A | A | S | F | A | B |
| DEMONHUNTER Devourer (1480) | A | A | A | A | A | A | A | A |
| EVOKER Devastation (1467) | A | A | A | A | A | A | A | A |
| EVOKER Preservation (1468) | A | A | A | A | A | A | A | A |
| EVOKER Augmentation (1473) | A | A | A | A | A | A | A | A |

Mistweaver, Devourer, Devastation, Preservation and Augmentation have no adopted spell-audio files and retain safe arcade playback. Missing event keys, rejected community-only candidates and all exact selected IDs/paths are recorded per spec in the development fixture. Rotation/landing/swap keep their pre-existing generic hooks; the research aliases are not additional controls/events. No researched kit was silently substituted for an unresolved event.

## Candidate SoundKit review

The example FileDataID names below agree with the archive index. The CSV itself warns that exact kit-to-file mapping and auditory suitability are unverified. The source spell page was not independently accessible in this run, so these **SoundKits remain unselected**. Durations are the supplied research claims, not measurements by this implementation.

| Candidate kit | Example file | Supplied duration | Decision |
|---:|---:|---:|---|
| 49435 | 1093773 | 1.9s | Not selected: kit membership and listening unverified. |
| 120394 | 1955772 | 3.7s | Not selected: kit membership and listening unverified. |
| 120399 | 1264932 | 2.8s | Not selected: kit membership and listening unverified. |
| 120400 | 1413279 | 2.4s | Not selected: kit membership and listening unverified. |
| 120457 | 1965755 | 2.6s | Not selected: kit membership and listening unverified. |
| 88848 | 1696828 | 2.3s | Not selected: kit membership and listening unverified. |
| 88849 | 1696829 | 2.2s | Not selected: kit membership and listening unverified. |
| 88850 | 1696830 | 1.9s | Not selected: kit membership and listening unverified. |
| 88851 | 1696831 | 2.1s | Not selected: kit membership and listening unverified. |
| 350940 | 1696836 | 1.2s | Not selected: kit membership and listening unverified. |
| 350941 | 1696837 | 1.1s | Not selected: kit membership and listening unverified. |
| 350160 | 568812 | 2.6s | Not selected: kit membership and listening unverified. |
| 85517 | 1634611 | 2.3s | Not selected: kit membership and listening unverified. |
| 85518 | 1634616 | 1.7s | Not selected: kit membership and listening unverified. |
| 28906 | 903822 | 1.9s | Not selected: kit membership and listening unverified. |

## Checks and in-game verification

- `lua tests/framework.lua`: **3,447 assertions**. Covers real 0/1/2/3/4-line locks, both-axis runs 3-8, separate/crossing triples, mixed 3+4 runs, unchanged scoring, one sound dispatch per resolution, cascade context, all 40 spec/internal-event fallbacks, eight stable preview buttons, file/API failure, Original Audio, volume/mute, cooldown and overlap handling.
- `lua tests/tetris.lua`: **44,303 assertions**. `lua tests/bejeweled.lua`: **68,272 assertions**. Engine suites remain unchanged.
- `python tests/options_assets.py`: all 40 profiles, 280 distinct-within-profile icons, 360 candidates, 63 substitutions, explicit sound maps, official-name evidence and the 11 existing kit constants.
- `python tests/artwork.py`: runtime textures/paths/TOC coverage. StyLua Lua51 and `git diff --check` pass.
- Compared protected files with the base checkpoint: Options, Launcher, Theme, Artwork, Settings, Profiles, Graphics, TOC and both engines are unchanged. No runtime assets, SavedVariables schema, UI layout, scaling or multiplayer code changed.

In WoW, listen to every selected file/tier for shortness, loudness, actual presence and light-to-iconic progression; filename identity alone does not prove intensity. Pay particular attention to iconic casts/impacts (Odyn's Fury, Wake of Ashes, Avenging Wrath, Feral Spirit, Summon Infernal, Exploding Keg and Celestial Alignment), and reject any long sequences or vocal/loop-like content. Compare same-class specs, rapid cascades, immediate move/rotate-to-lock, paused/resumed games, zero/off mute and both themes. Verify icon loading on all 40 specs, especially preserved unresolved candidates and Devourer. Check that failed files audibly use arcade fallback and that global WoW audio settings stay unchanged. **No actual in-game playback, listening or visual verification was performed.**

## Exact changed files

- `KIC-Games/ProfileData.lua`: targeted texture substitutions and explicit named internal sound data; legacy sound arrays retained.
- `KIC-Games/Audio.lua`: internal mappings, guarded preview registry, cascade/fallback routing, reliable failed-file retry and resolution voice priority.
- `KIC-Games/Games/Tetris/Module.lua`: audio dispatch from actual line delta only.
- `KIC-Games/Games/Bejeweled/UI.lua`: sound-only contiguous-run classifier and resolution dispatch; no visual/input/layout changes.
- `tests/framework.lua`: targeted dispatch/fallback/scoring/settings/UI-stability regressions.
- `tests/options_assets.py`: extended data/evidence validation.
- `tests/options-assets.json`: updated checked data fixture.
- `tests/options-icon-files.lua`: verified new texture lookup entries, retaining older fixture entries.
- `tests/sound-research.json`: development-only candidate comparisons, substitutions, sound-name evidence, rejected mappings and research provenance.
- `design/SOUND_AUDIT_REPORT.md`: this audit.

Only the four existing runtime Lua files change. Supporting fixtures and this report are necessary for reproducible verification and the requested audit; none are TOC entries or runtime addon files. No research archive was extracted into the runtime tree. **No release ZIP was created.**
