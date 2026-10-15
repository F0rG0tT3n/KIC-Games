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
| `window-frame` | 1120×700 reference; 8:5, transparent center | Outer shell and modal frames; fine cyan/violet stepped corners, restrained glow; keep a transparent center so native text remains readable | `window-frame.tga` | `Theme.lua:NeonBorder`: thin native panel border and cyan/violet corner strokes |
| `button-frame` | 256×64; 4:1, transparent center | Primary Play buttons; cyan chamfered outline and subtle glow | `button-frame.tga` | `Theme.lua:Primary` / `NeonBorder`: blue surface, cyan border, static corner strokes and native hover/pressed/disabled states |
| `generic-hero` | 1024×512; 2:1 | Fallback only for future/third-party registered games without supplied hero art; subtle arcade scene, dark text-safe right half | `generic-hero.tga` | `Theme.lua:SetArt` + `Launcher.lua:RefreshLauncher`: navy panel with actual module icon, cyan panel edge and native game details |
| `generic-card` | 256×256; 1:1 | Future/third-party game card fallback; muted arcade motif | `generic-card.tga` | `Theme.lua:SetArt` + `Launcher.lua:RefreshLauncher`: tinted navy card and actual module icon |

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
