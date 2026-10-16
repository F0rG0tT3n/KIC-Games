KIC Games UI Kit — Codex handoff
================================

Purpose
-------
Reference mockups, separate artwork sources, and WoW-compatible TGA textures for
the "Neon Arcade Command UI" redesign. This is NOT a standalone addon.

Install
-------
1. Extract the CONTENTS of this ZIP into your existing KIC-Games project root.
   Example: D:\WowAddons\KIC-Games\
2. Verify these relative paths now exist:
   design/references/new-launcher.png
   design/references/new-bejeweled.png
   design/references/new-tetris.png
   design/references/new-options.png
   Media/KICUI/logo-d20.tga
   Media/KICUI/bejeweled-hero.tga
   CODEX_PROMPT.md
3. In Codex, open the KIC-Games PROJECT folder, not the parent WowAddons directory.
4. Paste the prompt from CODEX_PROMPT.md.

What is included
----------------
design/references: four new UI mockups + four original screenshots.
design/sources: ten original art PNG files (safe for further image editing).
Media/KICUI: ten resized .tga textures ready for WoW native UI.
design/asset-manifest.json: per-image usage and exact relative paths.

Important
---------
* The mockup PNG files are visual references, not textures to show wholesale
  as an entire screen. All controls must be native clickable WoW UI components.
* TGA textures are already resized to common power-of-two dimensions.
* If a visual element is missing, implement a styled placeholder and register
  the missing asset in design/MISSING_ASSETS.md for later replacement.
* The PUG art is FUTURE/CONCEPT content. Do not show the game as installed
  or playable until the existing game registry actually registers it.
* Current behavior, keyboard controls, saved settings, high scores, lobby
  logic, frame resizing and positioning must be preserved.
* Check all supplied graphics in WoW for correct orientation, layering and UVs.
