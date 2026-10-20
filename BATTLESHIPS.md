# Battleships

Two players in an ordinary WoW PARTY, using the shared **Multiplayer → Host Game → Join → Ready** flow. Both players need this addon version. A larger party may contain spectators, but the lobby admits exactly two players. Raids and instance chat are not supported.

Each player has a 10×10 grid and five ships: Carrier (5), Battleship (4), Cruiser (3), Submarine (3), Destroyer (2). Ships may touch, but cannot overlap or extend outside the grid.

- Select a ship on the left, then click your grid to place it. Hover previews whether the placement fits. Selecting an already placed ship lets you reposition it before locking.
- **Right-click** your grid or press **R** to rotate the selected placement. Keyboard shortcuts respect chat focus.
- **Auto-place** arranges all five ships; **Clear** removes your draft.
- Click **Lock fleet** when ready. Locked fleets cannot be changed. The battle starts once both players have locked.
- Click an unmarked enemy square on your turn. Each shot passes the turn, including hits. Dots mark misses, X marks hits and # marks sunk ships.
- Destroy all 17 enemy ship squares to win, or use **Resign** to concede. The host fires first in the first match; the starting player alternates on rematches.

The main window keeps both boards after the battle. The result popup shows victory/defeat, score (successful hits), shots and ships remaining, with **Rematch** and **Back to menu**. Rematch marks you ready in the existing lobby; both players must ready up. Wins and losses persist in Results and can be shared through the usual Share Best control.

Closing the window or browsing the launcher preserves a live match. `/reload` restores the saved session, own placement and pending action. Duplicated actions cannot fire twice; unacknowledged actions retry. No heartbeat for 16 seconds shows a connection warning, and 45 seconds interrupts the match without awarding a winner. Leaving/stopping a game also interrupts it. The host waits for acknowledgement of the final board before completing, with an eight-second fallback; if the final board is unavailable, the popup still shows the confirmed score/outcome and labels the board as the last confirmed snapshot.

## Artwork

Copy the runtime artwork into the installable addon directory:

| File | Dimensions |
| --- | --- |
| `KIC-Games/Media/Battleships/battleships-hero.tga` | 1024×512 |
| `KIC-Games/Media/Battleships/battleships-card.tga` | 256×256 |

Use uncompressed true-color 24/32-bit TGA, matching the existing assets. The hero uses the launcher's right-aligned artwork presentation. Until the files are supplied, the launcher and game use native fallback artwork; boards and ship states are rendered by the existing native UI components. Restart WoW after adding new texture files so its file cache picks them up.

## Implementation and validation

`Rules.lua` handles placement, fleet encoding, shots, sinking and validated views. `Session.lua` owns the host-authoritative state, recipient-specific snapshots, sequence/revision checks, retries, heartbeats and reload recovery. `UI.lua` renders both grids inside the standard three-panel game container. `Module.lua` provides registration, persistence and result hooks.

The enemy fleet is absent from live opponent views and is revealed at the end. This follows the existing trusted-host PARTY transport: it is not encrypted or intended to prevent a modified addon from inspecting PARTY traffic or host state.

Run `lua tests/battleships_rules.lua`, `lua tests/battleships_session.lua`, `lua tests/battleships_ui.lua` and `python tests/artwork.py` from the repository root. Session tests use isolated clients and the real AceComm/ChatThrottleLib transport. A live two-player WoW smoke test is still needed for actual in-game rendering and latency.
