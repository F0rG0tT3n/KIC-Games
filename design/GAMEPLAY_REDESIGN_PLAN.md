# Both gameplay screens - implementation plan

1. Match `new-bejeweled.png` and `new-tetris.png` compositions with responsive
   three-column gameplay layouts. Keep the approved Launcher presentation intact.
2. Share the logo/status/Back to Launcher/Close header. Hide the gameplay header
   stop/options/results actions; provide Resume/Restart/Stop in each pause menu.
   Keep the established session lifecycle and urgent-stop slash action.
3. Build Bejeweled artwork/instruction/action left panel, square 8x8 board,
   score/gold best/stat/tip right panel. Adapt hit-testing and existing animation
   distances to the measured cell step; never change swap/cascade rules or delays.
4. Build Tetris information/keycap/action left panel, tall square-cell 10x20 grid,
   grouped stats/queue/hold/pause right panel. Pool every cell/preview texture.
5. Extend shared Theme/Artwork components for board ornaments, gold/crown stats,
   keycaps, icon rows and pause menus. Reuse supplied art; create matching small
   original icon masks and document unavailable illustrated skin/ornament assets.
6. Run all engines, integration, input, lifecycle, resizing, saved-data and asset
   checks. Inspect offline previews at minimum/default/wide sizes and 100%/120%.
   Commit both screens together and document exact live WoW verification steps.

No engine/protocol/SavedVariables-schema changes or ZIP. Complete both games
without an approval pause between them.
