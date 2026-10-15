# Bejeweled

Open **Singleplayer → Bejeweled → Play**, or use `/kicbejeweled`.
This is a relaxed, untimed singleplayer match-three game on an 8×8 board, using
the same class ability icons as Tetris. Choose one of 13 classes in **Options**;
the setting applies to both games immediately and is saved between sessions.

The reference layout places artwork, instructions and Hint/Pause/Share/Class
Options on the left, the square board in the center, and real score/gold best/
statistics/tips on the right. Cyan layered board edges and diamonds use the same
shared theme as the Launcher. Selection, hover, valid swaps, matches/cascades and
score gains have lightweight visual feedback.

## Playing

Click an icon, then click an icon immediately above, below, left or right to swap.
Alternatively, drag an icon onto one of those neighbors and release. The icon
follows the cursor and a neighboring drop target is highlighted. Invalid matches
animate back; dropping on the original cell, a non-neighbor or outside the board
cancels the drag without spending a move. Dragging works at resized UI scales.
Opening a menu, hiding the game or stopping the match cancels any active drag.
The selected cell has a thick gold outline, a bright background and a selection
label so it stays distinct from the board and yellow hint outlines.
A swap must create a horizontal or vertical line of at least three matching gems.
An invalid swap animates back and does not count as a move. Click the selected
gem again, or right-click any cell, to clear your selection. Clicking a different
non-neighbor selects that gem instead.

Matches disappear, gems fall into the gaps, and new gems enter from above.
New matches create cascades until the board settles. Input is blocked during
swap and cascade animations. The starting board has no automatic matches and
always has a legal move.

**Hint** highlights one available swap for three seconds without spending points.
There is no timer or move limit. A run ends when the settled board has no legal
swaps left. This initial version uses ordinary gems; long matches clear all gems
in their line, and crossing matches count their intersection once.

## Score, records and sharing

Each cleared gem earns **50 × cascade number** points: the first clear uses ×1,
the next automatic clear uses ×2, and so on. The multiplier resets on your next
manual swap. The side panel shows score, best score, accepted moves, cleared gems
and your largest cascade. Hints and invalid swaps do not add points or moves.

The account-wide best is saved under `KICGamesDB.bejeweled.best`, with score,
moves, gems, best cascade and timestamp. It updates after each clear and survives
a quick interruption. WoW writes SavedVariables on UI reload or normal logout;
the active board is not restored after reloading.

**Share best**, or `/kicbejeweled share`, opens an editable normal chat draft.
It defaults to instance/raid/party chat when grouped, or say when solo. Press Enter
to send. Sharing pauses an active run and never sends a message automatically.

## Pausing and stopping

Use **Pause / Resume**. Hiding the game, returning to Launcher, opening match
history or focusing a chat/edit box pauses the board and its animations. Reopen
with **Open game** or `/kicbejeweled`, then click **Resume**.

**Stop match** in the pause menu or `/kicgames stop` immediately ends the session without a
confirmation. The framework records it as interrupted, without a loss. Game over
instead records your score and opens a movable result dialog above the launcher,
with **Play again / Share best**. Closing the launcher also closes that dialog.
The pause menu also offers **Restart run**, preserving the old run's best score.
**Back to Launcher** and X preserve the current board until it is resumed; they
do not restart the game. Active boards still do not survive a UI reload.

## Module

`Games/Bejeweled/Engine.lua` contains pure rules, move search and staged cascades.
`UI.lua` handles the board, animations, hints, pauses and result dialog.
`Module.lua` registers the game and handles saved records, results and chat drafts.
It uses seven fixed WoW class texture FileDataIDs from `IconPresets.lua`, independent
of spell lookups; the fallback is the selected class icon. No separate addon installation is needed,
and the game sends no multiplayer addon messages. Combat handling is outside scope.

Run `lua tests/bejeweled.lua` for the rules checks and `lua tests/framework.lua`
for launcher, animation, focus, result, persistence and quick-stop integration checks.
