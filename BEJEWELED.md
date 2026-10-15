# Bejeweled

Open **Singleplayer → Bejeweled → Play**, or use `/kicbejeweled`.
This is a relaxed, untimed singleplayer match-three game on an 8×8 board, using
Original colored gems or the same class/spec spell profiles as Tetris. Choose
**Options -> Graphics** for the theme, class/spec, Follow My Character and preview.
The selection applies immediately to both games and is saved between sessions.
**Audio** independently selects arcade or class/spec effects, mute and volume.
Verified spell SoundKits and arcade fallback effects use Master with the addon
volume slider. Unmapped spell files are represented by arcade sounds. 0% or Off
silences all KIC effects.

The reference layout places artwork, instructions and Pause/Share/
Options on the left, the square board in the center, and real score/gold best/
statistics/tips on the right. Cyan layered board edges and diamonds use the same
shared theme as the Launcher. Selection, hover, valid swaps, matches/cascades and
score gains have lightweight visual feedback.

## Playing

Click an icon, then click an icon immediately above, below, left or right to swap.
Alternatively, hold the left mouse button and drag onto a tile immediately above,
below, left or right. The swap starts as soon as the cursor enters that neighbor;
you do not need to drag a full tile's width or height. Starting near an edge needs
only the short remaining distance and the gap. Gaps and diagonal tiles do not
trigger a swap. Fast movement also detects the first neighbor crossed between
updates, even if the cursor ends farther away or outside the board.
There is exactly one swap attempt per press. Invalid matches use the existing
rollback animation. Releasing before entering/crossing a neighbor cancels drag
swapping; a moved gesture cannot also click-select or click-swap. Stationary
clicks still select and swap as before.
Hit testing uses actual tile rectangles and effective UI scale. Pause, menus,
hiding, resizing/rebuilding and stopping
cancel active tracking. The temporary update handler is removed on trigger,
cancellation or release; no additional drag polling runs while idle.
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

The **Hint (3/3)** button offers three hints per run. Each successful request
makes both gems of a valid swap bounce vertically and glow until you interact.
There are no automatic hints. An already displayed hint cannot consume another
use; unavailable or blocked hints cost nothing. Pause/reopen preserves the remaining
count; restarting gives three uses again. Hints never swap gems or spend points.
Sparkles and a brief flash now begin while the matched gems are still visible.
Three-in-a-row uses a small burst, four adds more sparks, and five or more gives
a stronger board flash and a larger burst. Above the board, beneath Back to Launcher,
each run length from three through eight has its own callout, with points beneath
it. Cascades add Combo, Super Combo or Mega Combo labels. Crossings of triples
still use the three-gem visual tier.
There is no timer or move limit. A run ends when the settled board has no legal
swaps left. This initial version uses ordinary gems; long matches clear all gems
in their line, and crossing matches count their intersection once.

## Score, records and sharing

Each cleared gem earns **50 × cascade number** points: the first clear uses ×1,
the next automatic clear uses ×2, and so on. The multiplier resets on your next
manual swap. The side panel shows score, best score, accepted moves, cleared gems
and your largest cascade. Manual hints and invalid swaps do not add points or moves.

The account-wide best is saved under `KICGamesDB.bejeweled.best`, with score,
moves, gems, best cascade and timestamp. It updates after each clear and survives
a quick interruption. WoW writes SavedVariables on UI reload or normal logout;
the active board is not restored after reloading.

**Share best**, or `/kicbejeweled share`, immediately sends your best to instance
(`/i`) chat, using plain hyphen separators. Sharing pauses and saves an active run.
Without an instance group, a local notice appears and no message is sent.

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
`Module.lua` registers the game and handles saved records, results and instance-chat sharing.
It uses seven fixed WoW class texture FileDataIDs from `IconPresets.lua`, independent
of spell lookups; the fallback is the selected class icon. No separate addon installation is needed,
and the game sends no multiplayer addon messages. Combat handling is outside scope.

Run `lua tests/bejeweled.lua` for the rules checks and `lua tests/framework.lua`
for launcher, animation, focus, result, persistence and quick-stop integration checks.
