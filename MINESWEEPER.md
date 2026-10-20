# Minesweeper

Open **Singleplayer > Minesweeper > Play**, or use `/kicminesweeper`.
The game also participates in Home's featured selection and appears in Recent
Games after launching, following the existing launcher behavior.

Reveal every non-mine square to win. Left click reveals; right click cycles
**flag > question mark > clear**. Flags protect squares from reveal and flood
fill. A question mark can be revealed normally. Numbers count mines in the
eight surrounding squares; revealing a zero opens its connected empty area and
numbered boundary. The first reveal and its neighbors are always safe.

| Difficulty | Board | Mines |
| --- | --- | --- |
| Beginner | 9 x 9 | 10 |
| Intermediate | 16 x 16 | 40 |
| Expert | 30 x 16 | 99 |

Click a difficulty or **New game** to start a fresh board. The timer starts on
the first reveal and keeps running when the launcher, Options or another window
is open. Mines left equals mine count minus flags; question marks do not reduce
it. Winning requires revealing safe squares, regardless of flags.

The final board and both side panels remain in the main KIC Games window after
a win or loss. The board header shows WIN or LOSS. A compact Bejeweled-style
result popup shows the outcome, score (one point per revealed safe tile), time,
best time and difficulty, with **Play again** and **Back to menu** buttons.
Closing the popup leaves the final board visible in the main window.
After a loss, `*` shows mines,
the red square identifies the detonated mine, and `X` identifies incorrect flags.
**Play again** immediately starts another board at the same difficulty.

Best winning times, measured to tenths for display and compared at full precision,
are stored separately in `KICGamesDB.minesweeper.best`. The last difficulty is
remembered. Active boards are not restored after `/reload`. Completed wins and
losses use the shared result history; restarting an unfinished run uses the
existing abort lifecycle.

Runtime code lives in `KIC-Games/Games/Minesweeper/`: `Engine.lua` contains pure
rules, `UI.lua` uses shared Theme/GameplayUI components, and `Module.lua` handles
registration, lifecycle and saved data. No multiplayer messages are added.
The supplied PNG originals remain in `Media/KICUI/Minesweeper`; the adjacent
uncompressed power-of-two TGAs are registered in `Artwork.lua`. Rebuild them
with `python tools/normalize_minesweeper_art.py` (Pillow required).

From this repository's root, run `lua tests/minesweeper.lua`,
`lua tests/minesweeper_ui.lua`, `lua tests/framework.lua` and
`python tests/artwork.py`. Rules tests cover every possible first square across
all three difficulties. Integration tests cover real launcher/session paths,
marking, timing, results, restart reuse, sizing, artwork and saved-data reloads.
Offline mock renders verify layout; actual WoW mouse handling and texture loading
still need an in-client smoke check.
