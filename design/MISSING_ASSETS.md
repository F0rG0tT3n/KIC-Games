# Artwork replacement slots

All eight supplied textures needed by this checkpoint are present and copied,
unchanged, to `KIC-Games/Media/KICUI/`. No game artwork is missing for the two
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
TGA masks in `KIC-Games/Media/KICUI/Navigation/`: `nav-home.tga`,
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
`Media/KICUI/` directory and be registered via `base .. "filename.tga"` in
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
| `ornament-crown` | 64x64 RGBA mask | Illustrated gold crown above Bejeweled stats, beside BEST in both games | Original geometric `Icons/crown.tga`, tinted gold. Replace the central registry path for a more ornate crown. |
| `ornament-diamond` | 64x64 RGBA mask | Thin luminous cyan lozenge at each board edge | Original geometric `Icons/diamond.tga`. Replace through the registry for illustrated glow. |

Preferred final filenames are `game-board-frame.tga`, `game-stats-frame.tga`,
`gem-cluster.tga`, `crown.tga`, and `diamond.tga`, inside runtime Media/KICUI.
Keep transparency around ornaments and inside border centers; do not bake text,
scores, icons or buttons into them. Every registered real path currently exists.

Nine matching gameplay action/instruction masks (`gem`, `hint`, `share`, `swap`,
`clock`, `infinity`, `cascade`, `pause`, `back`) plus the two ornaments are original
64x64 antialiased RGBA TGAs in `Media/KICUI/Icons/`. They use shared Theme tint,
are centrally replaceable, and avoid missing Blizzard atlas dependencies.
`tools/generate_gameplay_icons.py` is their editable geometric source and belongs
outside installable packages. The Tetris brand uses four native violet squares.
All eight supplied artwork TGAs and five existing navigation TGAs remain unchanged.
