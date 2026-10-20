# Artwork replacement slots

All eight supplied textures needed by this checkpoint are present and copied,
unchanged, to `KIC-Games/Media/`. No game artwork is missing for the two
installed games. PUG concept artwork is intentionally unused and is not registered
as a game. References and source PNGs are not runtime textures.

The following separate decorative components appear in the mockup but were not
included as standalone textures. They use tasteful native geometry. Replace the
corresponding `file=false` entry in `KIC-Games/Artwork.lua`
with the final runtime path; no changes to interactive layout are needed.

| Registry key / asset | Intended size / ratio | Placement and desired art | Preferred runtime filename | Current fallback |
| --- | --- | --- | --- | --- |
| `window-frame` | 1120×700 reference; 8:5, transparent center | Outer shell and modal frames; fine cyan/violet stepped corners, restrained glow; keep a transparent center so native text remains readable | `window-frame.tga` | `Theme.lua:StylePremiumFrame`: layered inset lines, L corners and static glow on shell/hero/sidebar; legacy modal windows retain `NeonBorder` |
| `button-frame` | 256×64; 4:1, transparent center | Primary Play buttons; cyan chamfered outline and subtle glow | `button-frame.tga` | `Theme.lua:StyleNeonButton` / `PaintNeonButton`: blue surface, inset borders, corner accents, highlight and normal/hover/pressed/selected/disabled states |
| `generic-hero` | 1024×512; 2:1 | Fallback only for future/third-party registered games without supplied hero art; subtle arcade scene, dark text-safe right half | `generic-hero.tga` | `Theme.lua:SetArt` + `Launcher.lua:RefreshFeature`: navy panel with actual module icon, cyan panel edge and native game details |
| `generic-card` | 256×256; 1:1 | Future/third-party game card fallback; muted arcade motif | `generic-card.tga` | `Theme.lua:SetArt` + `Launcher.lua:RefreshLauncher`: tinted navy card and actual module icon |
| `stat-frame` | 512x128; 4:1, transparent center | Reusable StatPanel, score/best/metadata surfaces; navy/cyan engraved border with restrained glow | `stat-frame.tga` | `Theme.lua:StatPanel` / `StylePremiumFrame`: native layered borders and cyan/violet L corners |
| `card-frame` | 512x512; 1:1 source, transparent center | Registry GameCard outline; quiet cyan corners and fine inner edge; keep title, image and action regions clear | `card-frame.tga` | `Theme.lua:GameCard`: native premium outline, ordered art/shade/icon stack, mode rule and NeonButtons |
| `status-frame` | 512x128; 4:1 source, transparent center | Party StatusPanel and lobby/discovery panel borders; thin icy edges with subtle cyan glow | `status-frame.tga` | `Theme.lua:StatusPanel` / `StylePremiumFrame`: layered native frame with real text, party icon and status pip |

The generic slots are conditional fallbacks, not missing art for Bejeweled or
Tetris. No screenshots were cropped to manufacture UI components, and no artwork
was downloaded. The launcher organization checkpoint adds five original custom
navigation symbols, described below. Native borders use corners rather than
pretending to reproduce a complete illustrated frame skin.

## Navigation icons supplied in launcher organization checkpoint

The five former letter placeholders are replaced by original, matching 64x64 RGBA
TGA masks in `KIC-Games/Media/Shared/Navigation/`: `nav-home.tga`,
`nav-singleplayer.tga`, `nav-multiplayer.tga`, `nav-results.tga`, `nav-options.tga`.
They depict a house, person, group of three, trophy and gear. They are complete
runtime artwork, not missing-asset slots. `Artwork.lua` remains the replacement
point if a different art set is desired. `Theme.lua:NavigationButton` renders
24 UI-pixel icons with state tint and a static additive glow; no text substitutes.

The local Blizzard UI source was checked first (GroupFinder atlas uses and
available navigation references). It did not provide a verified matching set for
all five symbols. `tools/generate_navigation_icons.py` is the editable geometric
source; it supersamples the shapes before exporting uncompressed TGA alpha masks.
It is development tooling and must not be included in installable packages.

## Shared component checkpoint notes

These skin slots are replaceable placeholders, not claims of matching every
illustrated detail in the reference. Their files must live in the addon runtime
`Media/Shared/` directory and be registered via `base .. "Shared/filename.tga"` in
Artwork.lua. Transparent centers are required, especially for the hero frame.
Source PNGs, mockups and developer previews remain outside the installable addon.
Current geometry follows each component's anchors and scales without stretching
its corner strokes; final artwork should support the actual responsive aspect
ratios (prefer a scalable border design rather than a baked full-panel image).

SectionHeader title/divider/cap/pip, Separator, Highlight, AccentPip and
CornerOrnament are deliberate native UI primitives. They need no missing image
file. Illustrated corner/glow variants can replace the parent component's
window/button/card/stat/status skin through the registry. They do not require
screenshots, fake Unicode ornaments, extra icon downloads or continuously running
animation. All eight supplied artwork TGAs and the five navigation TGAs remain
unchanged. The gameplay checkpoint adds the optional decorative slots below.

## Gameplay checkpoint (0.12.0)

The actual `new-bejeweled.png` and `new-tetris.png` references include illustrated
frames and ornaments that are not separate files in the supplied runtime kit.
Their overall composition is implemented with native controls and the existing
supplied artwork. These replacements are intentionally more geometric than the
painted reference; they are not pixel-perfect texture replicas.

| Registry key / asset | Approximate source size and alpha | Intended appearance and use | Current replaceable placeholder |
| --- | --- | --- | --- |
| `game-board-frame` | 1024x1024 RGBA, transparent center; must support square and tall variants | Stepped cyan double frame, soft outward bloom, luminous corner cuts and diamonds around both boards | `file=false`; `Theme:GameBoard` supplies layered PremiumFrame, inset L rails, static glow and four separate diamond textures. Supply an edge-only TGA via Artwork.lua; use scalable borders for final aspect-specific work. |
| `game-stats-frame` | 512x1024 RGBA, transparent center | Engraved cyan/gold crown-top Bejeweled statistics frame; compatible shared Tetris statistics border | `file=false`; PremiumFrame native rails/corners, separate crown and supplied low-alpha lion crest; gold best uses tinted native premium edges. |
| `gem-cluster` | 256x128 RGBA, fully transparent background | Low violet/blue crystal cluster above Bejeweled's tip panel | `file=false`; a muted crop of the supplied `bejeweled-card` in the same bounded decoration region. Replace this slot without editing the game UI. Hidden when the compact region cannot fit. |
| `ornament-crown` | 64x64 RGBA mask | Illustrated gold crown above Bejeweled stats, beside BEST in both games | Original geometric `Shared/Icons/crown.tga`, tinted gold. Replace the central registry path for a more ornate crown. |
| `ornament-diamond` | 64x64 RGBA mask | Thin luminous cyan lozenge at each board edge | Original geometric `Shared/Icons/diamond.tga`. Replace through the registry for illustrated glow. |

Preferred final filenames are `game-board-frame.tga`, `game-stats-frame.tga`,
`gem-cluster.tga`, `crown.tga`, and `diamond.tga`, inside runtime Media.
Keep transparency around ornaments and inside border centers; do not bake text,
scores, icons or buttons into them. Every registered real path currently exists.

Nine matching gameplay action/instruction masks (`gem`, `hint`, `share`, `swap`,
`clock`, `infinity`, `cascade`, `pause`, `back`) plus the two ornaments are original
64x64 antialiased RGBA TGAs in `Media/Shared/Icons/`. They use shared Theme tint,
are centrally replaceable, and avoid missing Blizzard atlas dependencies.
`tools/generate_gameplay_icons.py` is their editable geometric source and belongs
outside installable packages. The Tetris title icon uses the supplied `tetris-card`
artwork, matching its Launcher icon.
All eight supplied artwork TGAs and five existing navigation TGAs remain unchanged.


## Options 2.0 original artwork and profile audio (0.13.0)

The supplied kit contains game promo art, not individual classic game pieces.
Eight original geometric placeholders are provided in runtime
`Media/Bejeweled/Pieces/`: `gem-1.tga` through `gem-7.tga`, and
`Media/Tetris/Pieces/block.tga`.
All are 64x64, uncompressed RGBA with antialiased transparent edges. The gems
have distinct colored/faceted silhouettes (hexagon, diamond, octagon, triangle,
square, star, pentagon). The neutral beveled block is tinted by the actual
Tetris kind, including NEXT/HOLD/ghost. They use no generic spell textures.

Replace Artwork.lua keys `original-gem-1` .. `original-gem-7` and
`original-block` with final classic gem/block artwork. Preserve 1:1 dimensions,
transparent background, clear silhouettes and readable internal facets; keep
6-8px source padding so native icon cropping does not clip highlights.
`tools/generate_original_pieces.py` is the editable geometric source. These are
replaceable art placeholders, not missing/broken file references.

### Icon profile verification and substitutes

All 40 curated profiles provide seven distinct, archive-verified texture IDs.
266 slots resolve directly from current spell tooltip metadata. Devourer's
seven new void spell textures are verified directly by archive filename and do
not invent SpellIDs. Seven lookups were unavailable; the following profiles use
archive-pinned same-class substitutes to keep all seven match symbols visible:

| Spec ID / profile | Unavailable spell metadata lookup(s) | Visible substitute texture(s) |
| --- | --- | --- |
| 65 / PALADIN Holy | 31842 | 135891 (`spell_holy_crusaderstrike.blp`) |
| 254 / HUNTER Marksmanship | 19434, 194386 | 132157 (`ability_hunter_aimedshot.blp`), 236179 (`ability_hunter_focusedaim.blp`) |
| 256 / PRIEST Discipline | 194509 | 135924 (`spell_holy_holysmite.blp`) |
| 258 / PRIEST Shadow | 228260 | 462324 (`spell_shadow_mindflay.blp`) |
| 263 / SHAMAN Enhancement | 8232 | 136114 (`spell_nature_windfury.blp`) |
| 270 / MONK Mistweaver | 191837 | 1360978 (`ability_monk_essencefont.blp`) |

These substitutes can be replaced in ProfileData.lua without changing game rules.
Texture rejection at runtime retains the existing visible class-icon fallback.
New client-discovered specs without curation use their official spec icon plus
class textures; newly introduced classes use the known visible fallback until
curated. Such future profiles are selectable through the native API catalog,
not omitted because an asset table lacks them.

### Exact pending sound mappings

Verified spell-file audio exists for 29 profiles. The file IDs and archive names
are recorded in `tests/options-assets.json` and ProfileData.lua; these are file
identifiers, not SoundKitIDs. `select/move/swap` use the short profile slot,
`land/clear` the impact slot, and `combo` the stronger slot. Mage profiles use
separate arcane/fire/frost selections, impacts and explosion/nova effects.
Every missing event below uses the selected game's verified arcade SoundKit,
with an explicit fallback notice on the Audio page. No bespoke end/victory spell
sounds have been curated yet. Files were checked by archive metadata, not
listened to inside the client; duration/loudness and build availability need QA.

| Stable spec ID | Class / specialization | Curated spell slots | Events still using arcade fallback |
| --- | --- | --- | --- |
| 71 | WARRIOR / Arms | 3 | gameOver, victory |
| 72 | WARRIOR / Fury | 3 | gameOver, victory |
| 73 | WARRIOR / Protection | 0 | all eight events |
| 65 | PALADIN / Holy | 0 | all eight events |
| 66 | PALADIN / Protection | 3 | gameOver, victory |
| 70 | PALADIN / Retribution | 3 | gameOver, victory |
| 253 | HUNTER / Beast Mastery | 3 | gameOver, victory |
| 254 | HUNTER / Marksmanship | 3 | gameOver, victory |
| 255 | HUNTER / Survival | 3 | gameOver, victory |
| 259 | ROGUE / Assassination | 3 | gameOver, victory |
| 260 | ROGUE / Outlaw | 3 | gameOver, victory |
| 261 | ROGUE / Subtlety | 3 | gameOver, victory |
| 256 | PRIEST / Discipline | 3 | gameOver, victory |
| 257 | PRIEST / Holy | 0 | all eight events |
| 258 | PRIEST / Shadow | 3 | gameOver, victory |
| 250 | DEATHKNIGHT / Blood | 3 | gameOver, victory |
| 251 | DEATHKNIGHT / Frost | 3 | gameOver, victory |
| 252 | DEATHKNIGHT / Unholy | 3 | gameOver, victory |
| 262 | SHAMAN / Elemental | 3 | gameOver, victory |
| 263 | SHAMAN / Enhancement | 3 | gameOver, victory |
| 264 | SHAMAN / Restoration | 3 | gameOver, victory |
| 62 | MAGE / Arcane | 3 | gameOver, victory |
| 63 | MAGE / Fire | 3 | gameOver, victory |
| 64 | MAGE / Frost | 3 | gameOver, victory |
| 265 | WARLOCK / Affliction | 1 | land, clear, combo, gameOver, victory |
| 266 | WARLOCK / Demonology | 3 | gameOver, victory |
| 267 | WARLOCK / Destruction | 3 | gameOver, victory |
| 268 | MONK / Brewmaster | 3 | gameOver, victory |
| 270 | MONK / Mistweaver | 0 | all eight events |
| 269 | MONK / Windwalker | 0 | all eight events |
| 102 | DRUID / Balance | 3 | gameOver, victory |
| 103 | DRUID / Feral | 2 | combo, gameOver, victory |
| 104 | DRUID / Guardian | 3 | gameOver, victory |
| 105 | DRUID / Restoration | 3 | gameOver, victory |
| 577 | DEMONHUNTER / Havoc | 0 | all eight events |
| 581 | DEMONHUNTER / Vengeance | 0 | all eight events |
| 1480 | DEMONHUNTER / Devourer | 0 | all eight events |
| 1467 | EVOKER / Devastation | 0 | all eight events |
| 1468 | EVOKER / Preservation | 0 | all eight events |
| 1473 | EVOKER / Augmentation | 0 | all eight events |

To complete these profiles, provide curated **SoundKitIDs** (preferred for
independent volume) or replacement file IDs/paths for the listed logical events
via `Audio:RegisterSpec(specID, events)`. Custom short one-shot files should use
appropriate, licensed sound assets with brief tails and no looping background.
Do not substitute a SpellID for a SoundKitID.

The `PlaySoundFile(..., "SFX")` route used by named spell files has no supported
independent per-effect gain in this implementation. The Audio page states that
nonzero spell-file playback follows WoW SFX volume; Off/0% immediately stops and
silences all addon effects. Current Retail SoundKit playback uses documented
`C_Sound.PlaySoundWithOptions` / `C_Sound.PlaySound` volumeOverride. Older clients
without those functions also show the SFX-level limitation. No global audio CVar
is changed, and unsupported volume is never presented as working.

Sources: [archive file list](https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv),
[Retail Sound API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SoundDocumentation.lua),
[Blizzard SoundKit constants](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SoundKitConstants.lua).
The checked metadata snapshot is dated 2026-10-15. See OPTIONS_2.md for live tests.
