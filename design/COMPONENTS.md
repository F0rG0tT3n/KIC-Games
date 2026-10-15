# Shared Neon Arcade Command components

Access with `local Theme = KICGames.Theme`. Constructors take a parent and
logical UI coordinates. They inherit the parent's scale; callers own gameplay,
networking and saved data. None of the components starts a game or invents data.
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
