# KIC Games — Implement Neon Arcade Command UI using the supplied artwork

You are working inside the KIC-Games World of Warcraft Retail addon project. Inspect the actual files and game registry first; do not assume file names or APIs.

## The provided assets are already in this project

Visual mockups (DESIGN TARGETS, NOT FLAT UI IMAGES):
- design/references/new-launcher.png
- design/references/new-bejeweled.png
- design/references/new-tetris.png
- design/references/new-options.png

Current UI references:
- design/references/old-launcher.png
- design/references/old-bejeweled.png
- design/references/old-tetris.png
- design/references/old-options.png

Use the preprocessed World of Warcraft-compatible TGA textures in Media.
Consult design/asset-manifest.json for exact intended usage and source PNGs
in design/sources/ if an asset needs to be cropped or adjusted.

Existing art:
- logo-d20.tga: header/brand icon
- crest-lion.tga: subtle low-opacity decorative watermark
- sidebar-decor.tga: muted sidebar decoration
- background-hall.tga: faint atmospheric background
- bejeweled-hero.tga and bejeweled-card.tga: Bejeweled artworks
- tetris-hero.tga and tetris-card.tga: Tetris artworks
- pug-hero.tga and pug-card.tga: PUG Simulator CONCEPT assets only

## Goal

Recreate the supplied modern Neon Arcade Command UI design faithfully,
within the real constraints of native WoW Lua frames, textures, button
states, layering and game module APIs. Premium dark navy/charcoal surfaces,
cyan highlights, violet secondary accents, selective subtle glow, readable
typography, clear hierarchy, consistent gutters and rich game card artwork.

## Non-negotiable preservation

- NO gameplay changes to Bejeweled or Tetris. Maintain the actual game rules,
  movement/keyboard bindings, score logic, pause, class icon selection,
  game results and saved high scores.
- Preserve current SavedVariables and migration behavior.
- Preserve existing slash commands, minimap button, launcher/game selection,
  multiplayer lobby/network architecture, version checks, and any existing
  public game registration interfaces.
- Existing launcher resize/drag/window scale and reload persistence must work.
- Do not alter unrelated projects or files.
- No gameplay additions, fake button behavior, or hardcoded fake player counts.
- Never register/show PUG Simulator as an installed playable game merely
  because its artwork exists. Use the current game's registry as the source
  of truth. A coming-soon teaser is optional ONLY if clearly labeled and
  not counted as installed; avoid adding it if this complicates the launcher.

## Implementation guidelines

1. Implement a reusable shared UI design system: palette, spacing, font
   hierarchy, button/hover/disabled states, frame panels, borders, game cards,
   modal shells, reusable texture loader.
2. Make the new Launcher: left sidebar Home / Singleplayer / Multiplayer /
   Results / Options, feature artwork panel and Play CTA, dynamic game cards,
   game details, accurate group status. The existing functionality must remain
   discoverable and working.
3. Rebuild the Bejeweled presentation around its actual 8x8 board and current
   controls. Keep square cells, central focus, compact info/action left panel
   and score/stat right panel; no clipping or stretched icons.
4. Rebuild Tetris presentation around the actual 10x20 grid, with clear
   NEXT / HOLD / SCORE / BEST / LINES / LEVEL, working keyboard focus and
   controls. No gameplay input regressions or UI drag intercepting inputs.
5. Rebuild Options modal, preserving actual implemented options, including
   class selection, scaling and reset. Do not create controls without logic.
6. Keep readability across reasonable window sizes and scales, and implement
   adaptive layouts or minimum size when necessary to avoid overlap.
7. UI artwork should only be decorative; native frames and font strings must
   remain the actual interactive UI. Never use a whole mockup screenshot as
   one giant UI texture.
8. Keep CPU overhead low; no expensive continuously updating textures or
   excessive OnUpdate loops for decorative effects.

## Art integration & placeholder rules

- Use supplied TGA art where semantically relevant. Only use sources in
  design/sources if conversion/adjustment is required. The current TGA
  textures are ready-to-reference in addon Lua paths.
- Use the player's actual WoW spell/class textures for dynamic gameplay
  icons, rather than replacing gameplay icon data with artwork.
- If ANY needed decorative asset is absent, create a tasteful native WoW
  UI placeholder (solid/gradient-like panel, thin colored edge, simple
  icon/art fallback) so the layout remains complete and functional.
- Record each missing asset in design/MISSING_ASSETS.md with: asset name,
  intended resolution/aspect ratio, intended placement, description,
  preferred replacement filename, and current placeholder code location.
- Make placeholders REPLACEABLE via a centralized asset registry, so that
  a final PNG/TGA/BLP can be swapped in later without redoing layout logic.
- Do NOT generate low-quality approximations by cropping UI screenshots,
  do NOT invent nonexistent WoW API features, do NOT download assets
  without necessity, and do NOT block implementation while waiting for art.
- No empty black box for missing art if a styled fallback can work.

## Workflow & acceptance

FIRST: inspect existing modules and write a brief implementation plan.
THEN: implement the shared system and new Launcher as the first checkpoint;
run available static checks/tests and report what must be visually validated
in-game before continuing. After that checkpoint, implement Bejeweled,
Tetris and Options as separate cohesive changes, preserving logic.

Check texture paths, TOC load order, missing files, nil references,
resizing at 100% and 120%, frames layering, proper mouse/keyboard events,
settings persistence, no duplicate controls and no incorrect interaction
with other Blizzard UI. No claims of real in-game visual verification unless
you actually observed it in WoW.

Deliver a concise report with changed files, completed screens, any known
issues, all placeholders needing artwork, and exact manual in-game tests.
Packaging into the final addon ZIP should include only necessary runtime
files (including Media), not mockup/design/reference PNGs.
