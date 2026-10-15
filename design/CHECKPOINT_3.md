# Checkpoint 3 - Shared premium UI foundation (0.11.0)

This checkpoint builds the reusable presentation components before either game
screen is redesigned. The supplied Launcher, Bejeweled and Tetris mockups guided
the cyan/violet border hierarchy, bright corners, fine separators and quiet glow.
The Launcher integration is a proof of concept, not a pixel-perfect refinement.
No ZIP was created.

## Featured Game artwork

The earlier draw-layer patch is retained. The hero now additionally opts into an
**edge-only backdrop**: it has no opaque native BackdropTemplate Center texture
that could cover the artwork. Image, translucent text-side shade and fallback
icon have explicit ARTWORK sublevels; text remains OVERLAY and actions remain
real child buttons. Loading artwork resets stale tint, blend mode, visibility
and UV crop. If texture loading reports failure, the actual game icon supplies
the existing replaceable fallback instead of an empty dark area.

Both original 1024x512 hero TGAs, all other supplied art and runtime paths are
unchanged. Tests validate both featured games after narrow/default/wide resizing
and page navigation, including a deliberately hidden/black-tinted/additive
texture. Live WoW rendering still needs confirmation; offline checks cannot
prove the client has rendered a TGA.

## Shared components

Implemented in `KIC-Games/Theme.lua`, with optional skins in `Artwork.lua`:

- **PremiumFrame**: native surface, two inset border layers, cyan L corners,
  violet lower-right accent and low-opacity static glow. An idempotent adapter
  styles existing frames. Artwork surfaces explicitly omit opaque backdrop fill.
- **NeonButton**: native button/action with normal, hover, pressed, selected and
  disabled states, highlight, inset edges and corner glow. Pressed feedback takes
  precedence over selection; disabling clears pressed state and removes glow.
- **StatPanel**: title/value/detail presentation, zero-safe SetStat, honest
  missing-value text and responsive text widths. Data belongs to the caller.
- **GameCard**: ordered artwork/shade/icon presentation, title/mode/detail/rule,
  NeonButton actions and reusable SetGame binding. Reflows without frame creation.
  Missing callbacks disable their controls rather than presenting fake actions.
- **SectionHeader**: native title with measured-width divider, cyan cap and pip.
- **StatusPanel**: actual title/detail, group icon and connection-state pip.
- **Primitives**: CornerOrnament, AccentPip, Separator and Highlight. These are
  static native textures, not overlay frames that catch mouse or keyboard input.

See [COMPONENTS.md](COMPONENTS.md) for constructor signatures, data/callback
contracts, minimum sizes, artwork ordering and replacement instructions.
Existing Panel/Button and legacy modal Window calls remain compatible; components
are opt-in. No decorative animation, OnUpdate loop or external dependency was added.

## Launcher proof of concept / changed files

- `Theme.lua`: shared component constructors/adapters, primitives, centralized
  component tokens and safe artwork loading. GameCard presentation moved here
  from the Launcher so future modules can reuse it.
- `Artwork.lua`: added optional `stat-frame`, `card-frame`, `status-frame` slots.
- `Launcher.lua`: PremiumFrame sidebar, hero and lobby/discovery panels;
  NeonButton navigation/actions/carousel; SectionHeader page/lobby/recent titles;
  StatusPanel party information; GameCard:SetGame for registry-backed cards.
- `UI.lua`: opt-in premium main window and retained browser title reference.
- `ResultsUI.lua`: real saved-best data presented through StatPanel.
- `Core.lua`, `KIC-Games.toc`: version 0.11.0 only; protocol remains v3.
- `tests/framework.lua`: component state, primitive ownership, backdrop absence,
  texture normalization, custom-skin fallback/replacement, frame reuse and proof
  of component integration; more accurate draw-layer/backdrop/resize mock data.
- `README.md`, `CHANGELOG.md`, `MISSING_ASSETS.md`, `COMPONENTS.md`,
  `SHARED_COMPONENTS_PLAN.md` and this report document the checkpoint.

Game source files, rules, class presets, scores, SavedVariables schema, settings,
navigation, resizing and multiplayer/countdown/results-storage logic are intact.
The full existing suite still covers active-game return, keyboard/chat safety,
Bejeweled dragging, urgent stopping and 24 temporary modules per game mode.

## Verification

- Framework integration suite: 1,299 assertions using the real bundled libraries
  in isolated mocked WoW clients, including the new component regressions.
- Tetris engine/icon suite: 44,303 assertions.
- Bejeweled engine suite: 68,272 assertions.
- Artwork checks: all 13 runtime TGAs, dimensions, power-of-two encoding, navigation
  alpha, supplied-file hashes and exact TOC/runtime paths. No artwork was added
  or changed, and no temporary game appears in runtime files.
- StyLua Lua 5.1 formatting/syntax and `git diff --check`.
- Inspected offline constructor previews with the actual supplied TGA art at
  100%/120%, plus multiplayer, results and narrow/scrolling libraries. The preview
  export now includes draw layers/sublevels and whether a backdrop has a fill.

## Placeholders and required live WoW checks

Window/button/stat/card/status illustrated skins are unavailable as separate
textures. Their native, replaceable equivalents and exact preferred filenames
are listed in [MISSING_ASSETS.md](MISSING_ASSETS.md). Generic module hero/card art
also remains a conditional fallback. No additional artwork is needed to use the
components; final illustrated skins can be supplied later.

1. `/reload`, open Home and feature **both Bejeweled and Tetris**. Confirm visible
   artwork at 100% and 120%, correct crop, side-specific shade and readable text.
   Resize and visit every page, then return Home; the artwork must remain visible.
2. Inspect native frame corners, inset borders, glow, dividers, pips and sidebar
   icons at your usual UI scale. Check that decorative regions never cover labels
   or intercept clicks; font metrics and subpixel edge appearance need the client.
3. Hover/press/release Play, Details, sidebar and lobby buttons. Test release
   outside a button, disabled hosting/second-game actions, selected navigation,
   carousel boundaries and immediate Stop match. Feedback must reset correctly.
4. Browse/scroll both libraries and resize at different widths; cards, rules,
   actions and scrollbars must remain clipped and aligned. Verify saved window
   size, class, scale and recent ordering after reload. Reset Size must still work.
5. Open Options/Results during each game, return to the same board, resume, type
   in chat, and stop. Verify zero/best statistics and match history against saved
   values. Individual game screens retain their current presentation.
6. With two real clients and a compatible multiplayer module, check party status,
   discovery, hosting/joining, ready/unready, 3-2-1, rejoin and immediate stop. The
   protocol and real member counts must be unchanged.

No live WoW visual verification is claimed. Stop here before the Bejeweled and
Tetris screen redesigns.
