# Artwork replacement slots — Launcher checkpoint

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
unchanged. No new game artwork is missing.
