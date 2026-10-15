# Shared Neon Arcade Command components

Access with `local Theme = KICGames.Theme`. Constructors take a parent and
logical UI coordinates. They inherit the parent's scale; callers own gameplay,
networking and saved data. Presentation components do not invent data; gameplay
pause-menu actions delegate to the existing framework start/stop lifecycle.
They do not register decorative timers, keyboard handlers or mouse-catching
overlay frames. Existing `Panel`, `Button` and two-argument `Window` remain
compatible with the current game screens.

| Component | Interface | Contract |
| --- | --- | --- |
| PremiumFrame | `Theme:PremiumFrame(parent, width, height, x, y, options)` | Native surface, layered inset borders, cyan L corners, violet lower-right accent and subtle static glow. `options.skin` selects Artwork.lua skin; `options.compact` shortens corners; `options.artwork=true` removes opaque backdrop fill for art surfaces. |
| Existing frame adapter | `Theme:StylePremiumFrame(frame, key, options)` | Idempotent decoration for an existing native frame. Does not replace scripts. Pick artwork mode before the first call. |
| NeonButton | `Theme:NeonButton(parent, text, width, x, y, onClick, height, primary)` | Real native Button, normal/hover/pressed/selected/disabled states; selected buttons still show press feedback. Enable/Disable and existing callbacks work normally. |
| Existing button adapter | `Theme:StyleNeonButton(button, primary)` | Opt in an existing styled Theme button without changing its click action. `Theme:Primary` uses the same adapter. |
| StatPanel | `Theme:StatPanel(parent, title, width, height, x, y)` | `panel:SetStat(value, detail)` preserves zero; nil displays "No record". `.label`, `.value`, `.detail` are native font strings. Intended minimum height 112 for the three text rows. |
| StatusPanel | `Theme:StatusPanel(parent, width, height, x, y)` | `panel:SetStatus(title, detail, connected)` updates actual information and a state pip. No fabricated member count. Intended height 54 or more. |
| GameCard | `Theme:GameCard(parent, width, height)` | `card:SetGame(registeredGame, options)` binds presentation and real callbacks; reflows on size changes without creating new frames. Launcher uses width >=256 and height 226. |
| SectionHeader | `Theme:SectionHeader(parent, title, width, x, y, fontSize)` | Native title plus divider, short cyan cap and icy pip. `header:SetText(title)` and native SetWidth/SetSize reflow the divider. |

`GameCard:SetGame` presentation options:

```lua
card:SetGame(KICGames.Registry.tetris, {
    art = "tetris-card", -- Artwork.lua key; omit to use the module icon fallback
    description = "Stack, clear lines, beat your best.",
    resume = false,
    enabled = true,
    selected = false,
    onPlay = function() KICGames.UI:LaunchGame("tetris") end,
    onDetails = function() KICGames.UI:FeatureGame("tetris") end,
    onSelect = function() KICGames.UI:FeatureGame("tetris") end,
})
```

The caller must handle any returned launch/selection errors (the Launcher uses
its existing notification wrapper). Primary/details controls without their
callbacks are disabled. Registry title, mode and player bounds supply the labels.
Artwork, shade, icon, labels and action buttons have explicit drawing order.

Decorative primitives return native textures:

```lua
Theme:Separator(parent, x, y, width, color, alpha)
Theme:Highlight(parent, x, y, width, height, color, alpha)
Theme:AccentPip(parent, x, y, size, color)
Theme:CornerOrnament(parent, "TOPLEFT", inset, length, color) -- four textures
```

Colors use Theme.Colors; spacing, type and component defaults are centralized in
Theme.Spacing, Theme.Type and Theme.Components. Geometry uses anchored textures,
so resizing does not need continuously running layout or animation loops.

Artwork goes through `Theme:Art(..., layer, subLevel)` / `Theme:SetArt`. Loading
resets tint to white, blend to BLEND, visibility and aspect-preserving UV crop.
Consumers apply intentional state tint/blend afterwards (e.g. navigation glow).
Featured Game uses an edge-only native backdrop, ARTWORK 0 image, ARTWORK 1
translucent text-side shade, ARTWORK 2 fallback icon and OVERLAY text. No native
opaque Center can cover the image. Buttons remain native child controls.

Skins are optional transparent-center textures registered by key in Artwork.lua.
Missing/failed skin loads fall back to native geometry. Set the slot's file to a
real runtime path, then reload; no launcher layout edits are required. See
[MISSING_ASSETS.md](MISSING_ASSETS.md) for artwork specifications. Full-frame
skins must preserve a transparent center; procedural corners remain crisp across
aspect ratios while final illustrated/scalable skins are unavailable.

## Gameplay extensions (0.12.0)

`GameplayUI.lua` extends the same `Games.Theme` table, after Theme.lua in the TOC.
It owns presentation helpers, never engine state or network behavior. Coordinates
in `PlaceGame` / `PlaceGameButton` use positive **downward** Y, unlike the older
negative-Y Theme constructors. Layout only runs on construction/navigation/resize.

| Helper | Contract |
| --- | --- |
| `PlaceGame(frame, x, y, width, height)` | Reanchors an existing object at TOPLEFT; optional measured width/height. |
| `GameLabel(parent, text, size, color)` | Native label using shared fonts and palette. |
| `ScoreValue(label, value, maxSize)` | Updates real text and fits its font to the current width; caches formatting until text/width/size changes. |
| `GameIcon(parent, registryKey, size, color)` | Shared Artwork texture with state-independent theme tint. |
| `GameButton(parent, text, iconKey, callback, primary)` | NeonButton plus centrally registered icon; `PlaceGameButton` lays out both caption and icon. |
| `GameBoard(parent)` | PremiumFrame with the optional `game-board-frame` skin, inset corner rails, static glow and four edge diamonds. |
| `InstructionRow(parent, iconKey, text)` | Compact icon and reflowing two-line instruction. |
| `GameStatRow(parent, iconKey, title)` | Icon/title, right-aligned `.value`, and thin divider. |
| `KeycapRow(parent, key, action)` | Native keycap frame and separate action label. |
| `GoldBest(parent)` | Gold premium border, crown, BEST label and fitted `.value`. |
| `TintFrame(frame, color)` | Applies a shared accent to premium edges/corners or a custom skin. |
| `PauseMenu(board, gameID, module)` | Native Resume/Restart/Stop actions; calls existing module/framework lifecycle. `.Layout(width,x,y)` places the fixed-height menu above board/drag layers. No per-frame timers. |

`StatPanel(..., options)` accepts `{plain=true}` for grouped readouts inside an
already framed panel. It retains `.label`, `.value`, `.detail` and SetStat; callers
can hide detail and adjust the label/value positions for shorter readouts.
Each game owns one pooled board and preview set. Bejeweled feedback uses its
existing Advance callback; Tetris continues to paint on engine revision changes.
PauseMenu dims the whole board on a separate mouse-blocking layer above drag
icons and below the opaque menu. Its show/hide scripts synchronize the dimmer;
resuming removes it. The centered menu caps its width at 320 UI pixels and uses
a bright cyan premium border, larger heading and divider for contrast. Both
layers are created once, with no decorative update loop or extra texture files.

## Options 2.0 controls

`Theme:SettingsDropdown(parent, popupParent, root, title, onSelection)` composes
a NeonButton with an icon, current selection and arrow, plus a pooled scrolling
PremiumFrame menu. `SetOptions(entries, selectedKey, enabled)` takes entries with
`key`, `name` and `icon`; `Layout(x,y,width)` places its label and field. Menus
inherit the window scale and live outside the clipped settings scroll child,
opening above the field when space below is limited. Selection, Escape, outside
clicks and Options navigation close the menu. Graphics places class and filtered
specialization dropdowns side by side; Follow mode disables both.

`Theme:SettingsSlider(parent, min, max, step, onValue)` is a native horizontal
slider with the shared navy track, cyan fill, icy thumb, current percentage and
endpoint labels. `slider:Layout(x,y,width)` places its track and labels. It is
used once for interface scale in Window and once for game volume in Audio;
the two controls have separate settings and callbacks. Options synchronization
guards programmatic refreshes against recursive setters. No decorative update
loop, second scaling control or custom widget framework is introduced.

Graphics/audio choices compose existing NeonButtons, PremiumFrames, icon textures
and SectionHeaders. Read-only previews use the same shared graphics provider as
the games. See [OPTIONS_2.md](OPTIONS_2.md) for settings, profile, graphics and audio
registration APIs, migration, playback limitations and validation.
