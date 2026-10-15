# Master-channel audio backend

Date: 2026-10-15. Original backend research began at checkpoint `7493007`; this document records the later volume correction.

## Playback contract (volume correction, 2026-10-15)

The previous version still sent unmapped spell files and failed mapped kits through `PlaySoundFile(..., "Master")`. Master routing alone did not provide independent addon volume, so nonzero slider levels could sound equally loud. This correction removes that playback path. `PlaySoundFile` and legacy `PlaySound` are never called by the backend.

The runtime now plays only verified SoundKitIDs through `C_Sound.PlaySound` or `C_Sound.PlaySoundWithOptions`, always requesting `Master` and passing `soundVolume * Audio.gain` as `volumeOverride`. The internal shared gain is 0.65; the saved slider remains a normalized 0..1 value. At 0%, or while muted, no new sound starts and tracked handles stop. Settings also stops active handles on any volume change, preventing a previously loud effect from continuing. The backend does not read or write WoW audio CVars. If the volume-capable API is unavailable, the effect is silent rather than uncontrolled.

For a profile FileDataID, the verified single-file kit is preferred. When no verified kit exists, the game's corresponding arcade event kit is used. Failed mapped kits can retry only that arcade kit. All original profile FileDataIDs and event routing remain in data for future verification. This temporarily substitutes arcade effects for 134 of 148 distinct spell files. Missing profile events already used arcade kits. No SoundKitID was inferred from a SpellID or FileDataID.

Offline tests check exact playback API, kit, channel and normalized override at 0%, 10%, 25%, 50% and 100%, with both sound themes and SFX enabled/disabled. They cannot establish perceived loudness or the native Master mixing formula. In a live client, `C_Sound.GetSoundScaledVolume(soundHandle)` accepts a playing handle; after a KIC preview, `/dump C_Sound.GetSoundScaledVolume(KICGames.Audio.handles[1])` can help compare effective levels where this API is available. A handle may already have ended, so repeat with a currently playing effect. The API and argument are documented in [Blizzard's generated sound documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua).

## Verified file-to-kit adapter

Fourteen of the 148 current spell files have an adopted exact single-file kit. The backend adapter leaves ProfileData and all Class/Spec/Original selections unchanged. Each selected kit has exactly one entry referring to the original FileDataID, entry gain 1, no player condition, SoundType 1, no flags, no advanced settings, no bus/mix-group override, no pitch adjustment or pitch/volume randomization. This avoids substituting random multi-file/loop/voice kits. Intrinsic kit/mixer volume still requires listening; a verified association is not a loudness guarantee.

Client data was retrieved directly from the pinned **12.1.0.69933** [SoundKitEntry CSV](https://wago.tools/db2/SoundKitEntry/csv?build=12.1.0.69933) and [SoundKit CSV](https://wago.tools/db2/SoundKit/csv?build=12.1.0.69933). This is historical data evidence, not proof that the kit still exists in the installed 12.1.5 client. The exact source rows, build, source URLs and SHA-256 digests are retained in `tests/master-sound-kits.json`; the full exports are development cache only.

The [generated client API documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua) and matching local client-source snapshot verify the current parameter positions and structured names, including volumeOverride. They do not document a precise native mixing formula.

| Original FileDataID | Verified single-file SoundKitID | Original sound path |
|---:|---:|---|
| 568008 | 22468 | `sound/spells/starfireimpact.ogg` |
| 568075 | 47725 | `sound/spells/killcommand.ogg` |
| 568080 | 10020 | `sound/spells/mutilate_impact_chest.ogg` |
| 568516 | 1490 | `sound/spells/lightningboltimpact.ogg` |
| 568678 | 11769 | `sound/spells/arcaneexplosion.ogg` |
| 569021 | 47726 | `sound/spells/spell_hu_killcommand_impact.ogg` |
| 569157 | 13103 | `sound/spells/shaman_feralspiritimpact.ogg` |
| 569315 | 20591 | `sound/spells/mangle_impact.ogg` |
| 569378 | 86009 | `sound/spells/frostnova.ogg` |
| 569384 | 24161 | `sound/spells/spell_shadowstrike_cast.ogg` |
| 569403 | 12349 | `sound/spells/ice_lance_impact1.ogg` |
| 569471 | 10136 | `sound/spells/shadowstrike_impact_chest.ogg` |
| 569555 | 20599 | `sound/spells/backstab_impact_chest.ogg` |
| 569658 | 10139 | `sound/spells/unstableaffliction_impact_chest.ogg` |

The 15 earlier research-kit links were not sufficient evidence by themselves; none of their example FileDataIDs are among the 148 currently referenced files. The new adapter uses direct SoundKitEntry/SoundKit rows instead. Other kits were rejected when they contained multiple files, advanced settings, nonzero flags, routing/pitch/randomization overrides or otherwise failed the strict criteria. FileDataIDs are never passed as SoundKitIDs.

## Spell files awaiting verified kits

**134 of the 148 distinct spell FileDataIDs still have no verified single-file SoundKit adapter.** They now use volume-controlled arcade event sounds. The table below lists those FileDataIDs by profile for future adapter research. Original/Arcade effects use the existing verified kits. The exact intrinsic loudness of every kit still needs live listening.

| Specialization | Remaining file-only FileDataIDs |
|---|---|
| WARRIOR Arms (71) | 1258146, 1267929, 1267930, 1267931 |
| WARRIOR Fury (72) | 1276021, 1276022, 1276023, 1276028, 1335795, 1455742 |
| WARRIOR Protection (73) | 1337829, 1362397 |
| PALADIN Holy (65) | 569623, 1884443, 2818300 |
| PALADIN Protection (66) | 1360126, 1360127, 1360128 |
| PALADIN Retribution (70) | 638272, 638274, 638276, 1253380, 1254585, 1264929, 1455052 |
| HUNTER Beast Mastery (253) | 569707, 1303796, 1451134 |
| HUNTER Marksmanship (254) | 1313130, 1315078, 1590095, 1590096, 1591768 |
| HUNTER Survival (255) | 1302244, 1302245, 1302246 |
| ROGUE Assassination (259) | 1301162, 1301172, 1301173 |
| ROGUE Outlaw (260) | 569227, 1360714, 1360715, 1360716, 1537119 |
| ROGUE Subtlety (261) | 1305797, 1311840 |
| PRIEST Discipline (256) | 1694004, 1708153, 1708154, 1708155, 1708158, 1708212 |
| PRIEST Holy (257) | 569611, 1693996, 1698678 |
| PRIEST Shadow (258) | 629052, 1714480, 1714481 |
| DEATHKNIGHT Blood (250) | 1272242, 1272243, 1272244, 1278529 |
| DEATHKNIGHT Frost (251) | 986405, 986407, 986409, 1272250, 1272260 |
| DEATHKNIGHT Unholy (252) | 1273702, 1273703, 1273704, 1343035 |
| SHAMAN Elemental (262) | 568527, 569147, 569666, 2576255 |
| SHAMAN Enhancement (263) | 1369104, 1369112, 1369113, 1369114, 1395052 |
| SHAMAN Restoration (264) | 568572, 1937566, 1937576, 1937577, 1937578 |
| MAGE Arcane (62) | 568149, 568341, 1662811, 1668195 |
| MAGE Fire (63) | 568461, 1390656, 1392377, 1686527, 1686530 |
| MAGE Frost (64) | 1631359, 1631379, 1631383 |
| WARLOCK Affliction (265) | 2068252, 2101389 |
| WARLOCK Demonology (266) | 568058, 999327, 999328, 999329, 2068311 |
| WARLOCK Destruction (267) | 593894, 1489078, 2068263, 2068264, 2068265, 2125625 |
| MONK Brewmaster (268) | 574719, 606779, 612300, 612302, 612304, 1483241 |
| MONK Windwalker (269) | 574719, 1378203 |
| DRUID Balance (102) | 568563, 1597431, 1597457, 1597458, 1597459 |
| DRUID Feral (103) | 3055167, 3151159 |
| DRUID Guardian (104) | 568496, 568676, 568870 |
| DRUID Restoration (105) | 1687849, 1687852, 1687853, 1687854, 1687861 |
| DEMONHUNTER Havoc (577) | 1280632 |
| DEMONHUNTER Vengeance (581) | 1345254 |

Full ID-to-path names for these 134 files remain in `tests/sound-research.json` (`soundFiles`). If a mapped kit fails at runtime, its arcade fallback is played with the same requested gain. No file is played directly.

The Options page was left unchanged as requested. Its existing help text still warns that file-backed profiles have effects outside slider control; that warning now describes the old backend. The control itself sends the saved 0..1 value correctly.

## Automated checks and live verification

The framework tests exercise Original and Class/Spec effects at 0%, 10%, 25%, 50% and 100%, including a mapped Starfire sample (FileDataID 568008, kit 22468), an unmapped Fire sample (1390656), both games, SFX disabled/enabled, mapped-kit failure, the structured API, and missing modern APIs. They reject all file playback and global CVar writes. A volume change is checked to stop the prior handle. Other engine and asset suites run separately.

In a live Retail client, listen to both modes at these five slider levels with Master enabled and SFX disabled, then repeat with SFX enabled and different Master levels. Confirm that 0% is silent, higher levels rise as intended, fallback effects suit the events, and changing the slider stops an active louder effect. Where available, inspect a current handle with `C_Sound.GetSoundScaledVolume`; the API cannot replace listening and offline mocks cannot establish perceived loudness or the native mix equation. The 14 mapped kits were verified against historical client data and still need current-build listening.
