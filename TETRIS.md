# KIC Tetris

Open `/kicgames`, choose **Singleplayer → Tetris → Play**. `/kictetris` also
starts a game or reopens your active Tetris window. No party is required and
the game sends no addon messages.

## Controls

| Key | Action |
| --- | --- |
| Left / Right | Move; hold to repeat |
| Up / X | Rotate clockwise |
| Z | Rotate counterclockwise |
| Down | Soft drop; hold to repeat |
| Space | Hard drop and lock immediately |
| C | Hold or swap the current piece; once per lock |
| P | Pause / resume |

The board has 10 columns and 20 visible rows, with two hidden spawn rows.
Each piece kind has its own bright color and spell icon. A translucent ghost
shows where hard drop will land. Five upcoming pieces and the held piece are
shown beside the board. Pieces come from shuffled seven-piece bags.

Choose any of the 13 **class icon presets** during play. Your selection is saved;
the default is your own class. Presets are cosmetic and use the same rules and
high score. Each preset uses seven fixed spell texture FileDataIDs supplied by WoW,
independent of spell availability or the spell cache. All 91 slots were checked
against the [WoW archive file list](https://github.com/wowdev/wow-listfile).
If the client rejects a texture, the renderer uses that class's icon instead.
Selecting another preset does not
restart the game.

## Score and speed

- One / two / three / four cleared lines: 100 / 300 / 500 / 800 × current level.
- Soft drop: 1 point per moved row. Hard drop: 2 points per moved row.
- Start at level 1; advance one level per 10 cleared lines.
- Gravity accelerates from 0.8 seconds per row to a minimum of 0.065 seconds.
- Grounded pieces have a 0.5-second lock delay. Up to 15 grounded movement or
  rotation resets are allowed per piece. Rotation uses small wall/floor kicks,
  rather than the complete competitive SRS specification. No combo, T-spin or
  back-to-back bonuses are implemented.

A blocked spawn or blocks remaining in the hidden rows after a lock ends the
game. Game over records a completed framework result and shows your score,
best score, and **Play again / Share best** actions.

## Saved best and sharing

The best score is account-wide within the client's SavedVariables. It stores
score, cleared lines, level, icon preset and timestamp under `KICGamesDB.tetris`.
The best is updated as you earn points, including before a quick interruption.
WoW writes SavedVariables to disk on UI reload or normal logout; a client crash
can lose changes since the last save. Active board state is not restored on reload.

Click **Share best to chat** or use `/kictetris share` at any time. This opens a
normal chat draft with your saved record. It defaults to instance, raid or party
chat when grouped, and say when solo. You can edit it or choose another channel,
then press Enter to send. Nothing is sent automatically.

## Leaving for the dungeon

**Stop match** or `/kicgames stop` immediately closes the game and releases its
keyboard input. The framework records an interrupted match without a loss;
your earned best score remains saved. No confirmation is required.

Using **Launcher**, closing the window, or focusing a chat/edit box automatically
pauses play and releases held movement keys. Reopen via **Open game** or
`/kictetris`, then press **P** or **Resume**. Escape and other non-game keys keep
their normal WoW behavior. Combat-specific handling is outside this addon scope.

## Module layout

`Games/Tetris/Engine.lua` contains standalone rules; `Presets.lua` contains spell
texture IDs and colors; `UI.lua` handles rendering and input; `Module.lua` registers the
game and connects persistence, completion and chat sharing to the framework.
They are bundled in the existing addon folder, so one KIC-Games installation or
junction is enough. The multiplayer protocol remains API v3.

Chat drafting follows Blizzard's
[ChatFrameUtil.OpenChat](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua),
with a legacy fallback when available.
