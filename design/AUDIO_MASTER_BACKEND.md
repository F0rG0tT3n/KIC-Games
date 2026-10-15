# Master-channel audio backend

Date: 2026-10-15. Base checkpoint: `7493007`. Only `KIC-Games/Audio.lua` changes at runtime.

## Playback contract

- Every explicit KIC-Games playback path now requests **Master**: preferred `C_Sound.PlaySound`, structured `C_Sound.PlaySoundWithOptions`, `PlaySoundFile`, legacy `PlaySound` and failed-file/kit fallbacks. No backend path uses the default channel or SFX.
- SoundKit playback prefers `C_Sound.PlaySound(kit, "Master", true, false, nil, soundVolume)`. When only the structured modern API exists, it receives `uiSoundSubType="Master"` and the same normalized `volumeOverride`. The existing 0-100% slider supplies 0..1 directly.
- The backend does not read, multiply, compensate for or write WoW Master/SFX CVars. It lets the native mixer handle the explicitly requested channel. **The exact relationship between volumeOverride and Master gain has not been tested in a live client and is not assumed to be a simple product.**
- Addon 0% and mute stop tracked handles and prevent every new kit/file call, including previews and fallbacks. Existing settings, profiles, throttling, resolution priority, handle limits and internal event routing are preserved.
- File sounds with no verified simple kit still use `PlaySoundFile(FileDataID, "Master")`. That API receives no invented gain parameter; nonzero addon levels do not independently attenuate those files. Their actual output follows the native Master path and requires client verification.
- On clients older than interface 120100, with an unknown build, or without either modern kit API, legacy kits remain safely routed to Master but have no independent nonzero addon gain. A verified file-to-kit mapping uses the original file if modern kit playback fails or is unavailable; if that file also fails, the existing arcade fallback remains.

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

## Remaining independent-volume limitations

**134 of the 148 distinct spell FileDataIDs remain file-only.** Addon 25%, 50% and 100% therefore use the same file API without addon gain; 0%/mute still gate and stop them. The following table lists every remaining file-only ID by profile. Empty rows mean no remaining file-only effects in that profile, not a complete specialization sound set. Original/Arcade effects use the 11 existing verified SoundKits and accept normalized gain through the modern API.

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

Full ID-to-path names for these 134 files remain in `tests/sound-research.json` (`soundFiles`). If one of the 14 mapped kits fails at runtime, its original-file fallback also temporarily lacks independent nonzero gain. No global volume manipulation is used to hide these limitations.

**Frozen Options wording:** Options.lua was not changed as requested. Its existing file-effect notice still mentions SFX. That wording is now stale: this backend routes those files through Master. Some notices also conservatively classify an entire file-backed profile even when individual effects now use mapped kits. The slider itself is unchanged and supplies its real saved value to the backend.

## Automated checks versus live verification

- Framework: **3,538 assertions**. The new backend contract tests drive the real existing volume slider at 0/25/50/100%, check explicit Master arguments under both simulated SFX states and Master settings 0/25/50/100%, verify preferred and structured kit APIs, all 14 mapped samples, mapped-kit failure, file-API absence, legacy fallback, unconverted files, file-to-arcade fallback, mute and previews. Global CVar writes throw and reads are counted; the backend uses neither.
- Those tests use API doubles: simulated Master/SFX settings verify routing/noninterference only. They **do not** emulate native audio mixing or establish audibility when SFX is off or Master changes.
- Tetris: 44,303 assertions. Bejeweled: 68,272 assertions. Profile/assets, runtime texture/TOC coverage, Lua51 formatting and whitespace checks pass.
- Protected-file comparison confirms Options, layouts, Theme, artwork, settings/schema, ProfileData, gameplay modules/engines and other UI code are unchanged.

### Required live-client listening matrix (not run here)

1. With the existing Options previews, test Original/Arcade (kit), a mapped class sample (e.g. Arcane Mage Combo preview, FileDataID 568678 / kit 11769), and an unmapped sample (Fire Combustion, file 1390656, from a four-line clear). Include the generic Class/Spec preview buttons and actual game events; no new preview controls were added.
2. For each, test addon 0/25/50/100% with WoW Master at 0/25/50/100%, then repeat with SFX enabled and disabled. Set these through the normal WoW UI yourself; the addon must never change them. Record audibility and relative levels rather than assuming the product of the two values.
3. At Master 0, verify silence. At nonzero Master, verify that disabling SFX does not silence the explicitly Master-routed sounds. Check monotonic kit attenuation at addon 25/50/100% and compare how each responds when Master changes.
4. For file-only sounds, verify Master routing and the documented unchanged nonzero addon level; 0%/mute must remain silent. Repeat with muted addon previews and mute during an active effect, confirming stopped handles and no new playback.
5. Listen to each mapped kit to confirm it is the intended single original sample and still exists in the current build. Verify fallback behavior on unavailable kit/file paths, and compare gain/priority with rapid input and cascade events.
6. If available, read `C_Sound.GetSoundScaledVolume(handle)` while a diagnostic kit is still active to help record native scaling, and corroborate it with listening. This API alone is not a substitute for measuring/observing the final channel output. No diagnostic utility or UI was added.

**No live WoW playback or native Master/volumeOverride mixing verification was possible in this environment.** Master-relative independent gain is implemented as a native API request for supported kits, not claimed as acoustically verified. If the live matrix reveals bypassing or double scaling, adjust only after collecting those results; do not compensate speculatively by reading/multiplying Master CVars.

## Exact scope

- `KIC-Games/Audio.lua`: explicit Master playback, preferred modern kit API and a 14-entry verified file-to-kit adapter with original-file fallback.
- `tests/framework.lua`: API recording and focused backend regression checks.
- `tests/options_assets.py`: Master contract and strict kit metadata checks.
- `tests/master-sound-kits.json`: development-only pinned source evidence.
- `design/AUDIO_MASTER_BACKEND.md`: this report and pending live matrix.

No other runtime file, profile data, UI, layout, gameplay behavior or SavedVariables structure changes. No release ZIP.
