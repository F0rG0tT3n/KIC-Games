# Shared premium components checkpoint

1. Fix the Featured Game surface before polishing it: remove its opaque native
   backdrop fill, retain explicit image/shade/text ordering, and normalize artwork
   texture state. Validate both original TGAs and navigation/resize paths.
2. Add opt-in reusable PremiumFrame, NeonButton, StatPanel, GameCard,
   SectionHeader and StatusPanel components to Theme.lua. Keep legacy Panel and
   Button helpers compatible so individual game screens remain unchanged.
3. Add reusable corner, pip, separator and highlight primitives. Use native static
   geometry for unavailable illustrated skins, with Artwork.lua replacement slots
   and descriptions in MISSING_ASSETS.md. No decorative timers or input handlers.
4. Apply the components to the Launcher shell/sidebar, feature surface, cards,
   section headings, party/lobby status and saved-stat presentation as a proof of
   concept. Keep page layouts, data sources, controls and protocol intact.
5. Run the full existing suite plus component-state, asset fallback, frame reuse,
   hero layering and responsive layout checks; inspect offline 100%/120% previews.
   Create a commit checkpoint with component API and required live WoW tests.

Stop before game-screen redesigns. No ZIP is requested.
