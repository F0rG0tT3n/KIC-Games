# Artwork replacement slots — Launcher checkpoint

All eight supplied textures needed by this checkpoint are present and copied,
unchanged, to `KIC-Games/Media/KICUI/`. No game artwork is missing for the two
installed games. PUG concept artwork is intentionally unused and is not registered
as a game. References and source PNGs are not runtime textures.

The following separate decorative components appear in the mockup but were not
included as standalone textures. They use tasteful native geometry or letter
badges. Replace the corresponding `file=false` entry in `KIC-Games/Artwork.lua`
with the final runtime path; no changes to interactive layout are needed.

| Registry key / asset | Intended size / ratio | Placement and desired art | Preferred runtime filename | Current fallback |
| --- | --- | --- | --- | --- |
| `window-frame` | 1120×700 reference; 8:5, transparent center | Outer shell and modal frames; fine cyan/violet stepped corners, restrained glow; keep a transparent center so native text remains readable | `window-frame.tga` | `Theme.lua:NeonBorder`: thin native panel border and cyan/violet corner strokes |
| `button-frame` | 256×64; 4:1, transparent center | Primary Play buttons; cyan chamfered outline and subtle glow | `button-frame.tga` | `Theme.lua:Primary` / `NeonBorder`: blue surface, cyan border, static corner strokes and native hover/pressed/disabled states |
| `nav-home` | 32×32; 1:1, alpha | Sidebar home symbol, monochrome pale cyan | `nav-home.tga` | `Launcher.lua:InitializeLauncher`: blue badge and H |
| `nav-singleplayer` | 32×32; 1:1, alpha | Sidebar single-person symbol | `nav-singleplayer.tga` | Same, badge and 1 |
| `nav-multiplayer` | 32×32; 1:1, alpha | Sidebar group symbol | `nav-multiplayer.tga` | Same, badge and M |
| `nav-results` | 32×32; 1:1, alpha | Sidebar trophy symbol | `nav-results.tga` | Same, badge and R |
| `nav-options` | 32×32; 1:1, alpha | Sidebar gear symbol | `nav-options.tga` | Same, badge and O |
| `generic-hero` | 1024×512; 2:1 | Fallback only for future/third-party registered games without supplied hero art; subtle arcade scene, dark text-safe right half | `generic-hero.tga` | `Theme.lua:SetArt` + `Launcher.lua:RefreshLauncher`: navy panel with actual module icon, cyan panel edge and native game details |
| `generic-card` | 256×256; 1:1 | Future/third-party game card fallback; muted arcade motif | `generic-card.tga` | `Theme.lua:SetArt` + `Launcher.lua:RefreshLauncher`: tinted navy card and actual module icon |

The generic slots are conditional fallbacks, not missing art for Bejeweled or
Tetris. No screenshots were cropped to manufacture UI components, and no extra
artwork was downloaded or generated. Native borders use corners rather than
pretending to reproduce a complete illustrated frame skin.
