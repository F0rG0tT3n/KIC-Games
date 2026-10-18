# Chess

Chess is a separate two-player multiplayer game in KIC-Games 0.14.0. It uses
the supplied twenty Chess textures and the existing lobby, AceComm transport,
game lifecycle, launcher, Interface Scale and Results systems. It has no AI,
chess clocks or spectator participants. Other games keep their rules and settings.

## Local board and gameplay test

After `/reload`, use `/kicchesstest` (alias `/kicchess`) to open the real Chess UI
without a party. You control White and Black in alternating turns. The board stays
in White's orientation; legal moves, check, castling, en passant, promotion, draw
claims and game endings use the same engine as multiplayer.

Reusing the command resumes the current local board. Use **New test game** or
`/kicchesstest new` to reset it, and **Leave test** or `/kicchesstest stop` to exit.
The two test controls stay below move history, including during draw offers.
Game endings open a local-only result popup with the same restart/exit controls.
`reset` and `exit` are aliases for `new` and `stop`. Offer/accept/decline
draw controls let you act for both sides; Resign applies to the side to move.
An active game, lobby or pending join must be closed before starting the test.
Local games send no game messages, do not affect records or match history, and
are discarded on UI reload.

## Playing with two WoW clients

1. Install the same inner `KIC-Games` folder on both clients. It must contain the
   updated TOC, `Games/Chess/` and `Media/KICUI/Chess/`. Reload both UIs; restart
   the client if the addon was newly installed.
2. Put both characters in the same ordinary PARTY group. It can have two to five
   members. RAID and INSTANCE_CHAT are deliberately unsupported.
3. On player A, open `/kicgames`, choose Multiplayer, then Chess, and click
   **Host game**. Anyone in the party can host; group leadership is irrelevant.
4. Player B opens Multiplayer, finds A's advertised Chess lobby on the left,
   and clicks it to join. Only two players can join a Chess lobby; the remaining
   party members can see the listing without becoming participants.
5. Both players click **Ready**. When both are ready, the shared three-second
   countdown starts and opens both boards. **Not ready** cancels the countdown.
   White/Black are assigned by the lobby host at each round's start and stay fixed
   throughout recovery. White moves first; each player sees their own side below.
6. Click your piece, then a highlighted destination. Invalid or out-of-turn
   clicks cannot change the board. Promotion offers graphical Queen, Rook,
   Bishop and Knight choices. Guest moves wait for host acknowledgement.
7. Use Offer draw, Accept/Decline draw, Resign or Claim draw as appropriate.
   Claim draw adjudicates an available claim immediately; otherwise select the
   intended move to claim a resulting third repetition or fiftieth move. Cancel
   draw claim returns to ordinary move selection without moving a piece.
8. Back to Launcher or closing the window preserves the match. Reopen through
   the Chess card or Open game in the multiplayer panel. Closing a window
   never resigns.

All multiplayer games use the shared Host / Join / Ready / countdown flow.
The lobby shows exactly two rectangular slots: joined player names or **Open Slot**,
with host and Ready/Playing status. Other party members do not occupy a slot until
they join the lobby.
Chess no longer uses challenges or invitation popups. Completed or manually stopped
rounds keep the lobby available for a rematch; both players must ready up again.
Leaving removes the player; the host can close the lobby. No visible party-chat
or WHISPER messages are sent.

## Rules

`Games/Chess/Engine.lua` is independent of WoW frames, time, SavedVariables and
networking. Its deterministic state contains a 64-square board, side to move,
castling rights, en-passant target, halfmove/fullmove counters, captures, UCI/SAN
history and exact repetition-position counts.

- Legal movement and captures for every piece, pins, check escapes and king
  safety. Kings cannot be captured as ordinary pieces.
- Both castling directions/colors, including rights loss after king/rook
  movement or rook capture. Only required king squares must be unattacked;
  attacks on an irrelevant rook/b-file square do not prohibit castling.
- En passant, including rejection when it exposes the king. A non-capturable
  en-passant target does not change repetition identity.
- All four promotions, SAN disambiguation, check and mate suffixes.
- Checkmate, stalemate, resignation, agreed draws, current/intended-position
  threefold and fifty-move claims, and automatic fivefold/75-move draws.
  Checkmate takes precedence over the 75-move rule.
- Conservative dead-material detection: bare kings; a lone bishop/knight versus
  a bare king; and bishops confined to one color complex. Two knights versus a
  king and opposite-color bishops are not auto-drawn merely because mate cannot
  be forced. Resigning to a bare king does not invent a mating win.
- FEN parsing/output, validated replay/serialization and integrity checks that
  include repetition history.

Rules reference: [FIDE Laws of Chess](https://handbook.fide.com/chapter/E012023).
Automatic dead-position detection is material based: arbitrary composed locked-pawn
fortresses are not exhaustively solved. Such positions can end by agreement.
Do not advertise exhaustive FIDE dead-position adjudication until this is extended.

## Protocol and recovery

`Session.lua` extends the existing PARTY addon-message transport. Targeted `CHESS`
control messages handle heartbeats and recovery outside an active module.
Discovery, advertisements, join consent, readiness, countdown and startup use the
normal shared lobby lifecycle and `StartModule`. Snapshots carry only White's name
as additional Chess data; the shared lobby supplies participants and round identity.
No separate communication library or whisper route is introduced.

Moves, draw actions and resignation use `SendGameAction("chess_action", payload)`.
The lobby host is the sole authority even when Black. Host moves go through the
same validation as guest moves. Requests contain match ID, actor, expected host,
expected sequence, previous digest and action token. Match IDs include the lobby
round, so stale controls from an earlier round cannot affect a rematch. Move requests also contain
numeric from/to squares and an optional promotion, which must agree with the UCI token.

The host verifies sender, participants, session, turn, sequence, digest and legality,
persists the accepted journal, and sends a targeted `SendGameState("chess_commit", ...)`.
Guests independently replay the transition and verify its digest. A heartbeat is
not a move acknowledgement. Duplicate/stale actions, inconsistent move fields and
malformed promotions cannot apply another transition. The digest covers board,
counters, repetition/captures, sequence, draw state and journal chain. It is an
integrity checksum, not a cryptographic signature; WoW supplies sender identity.

Normal moves send deltas, not boards. Recovery transfers a sequence/digest and
journal chunks of at most 64 accepted actions. Reconstructed state stays private
until complete verification. An older host snapshot cannot overwrite a newer
local sequence. Out-of-order chunks, stale sessions and checksum disagreement
are rejected. Stalled requests retry after 15 seconds through AceComm throttling.

Heartbeats run every five seconds. Missing communication, a disconnected member,
roster loss or an unsupported channel suspends input. A 120-second recovery grace
starts after suspension. Unreconcilable sessions become interrupted with no winner.
A later verified terminal journal can replace a provisional interruption without
replacing another game's current lobby.

Reload recovery reconstructs both clients from their journal and reconciles with
the same host; there is no host election. Both sides may reload together.
WoW flushes SavedVariables at reload/logout; Lua cannot write them to disk on
demand. An abrupt process crash may therefore leave a stale host backup. Refusing
rollback and recording interruption is intentional in that situation.

## Records and lifecycle

`KICGamesDB.chess.active` holds only recoverable match identity/participants and
the accepted journal and lobby recovery metadata (revision, round and join tokens).
Completion or abandonment removes it. `chess.stats` stores
completed games, wins, losses, draws and last opponent. `chess.lastGame` keeps
the latest completed SAN-history tail (200 plies).

The normal Results system stores both participants' outcomes under `chess` with
stable result IDs across reloads. A bounded counted-result ledger prevents duplicate
statistics; a verified completion can replace a provisional interruption.
Interruptions never increase wins or completed counts. Results shows lifetime
Chess totals and last opponent instead of a fabricated high score. The shared
match-history limit remains 20.

## Source map

New runtime files, in TOC order:

- `Games/Chess/Engine.lua`: pure rules, FEN, SAN, repetition and perft.
- `Games/Chess/Session.lua`: lobby round identity, authority, journal and recovery.
- `Games/Chess/UI.lua`: board, promotion, captures and history; the shared UI supplies the lobby controls.
- `Games/Chess/Module.lua`: registration, lifecycle and persistent records.

Scoped framework changes are in `Core.lua`, `Lobby.lua`, `Results.lua`, `UI.lua`,
`Launcher.lua` and `ResultsUI.lua`. They initialize/dispatch Chess, preserve its
sessions during roster changes, retain two participants, hide generic Stop Game
controls and display Chess records. `Artwork.lua` registers the twenty supplied
assets; the TOC loads the new files. No supplied image bytes were edited or generated.
The addon version is 0.14.0; the shared transport API version is unchanged.

## Automated verification

Run from the repository root:

```powershell
lua tests/chess_engine.lua
lua tests/chess_session.lua
lua tests/chess_lobby.lua
lua tests/chess_recovery.lua
lua tests/chess_ui.lua
lua tests/chess_practice.lua
lua tests/framework.lua
lua tests/bejeweled.lua
lua tests/kic_bejeweled.lua
lua tests/kic_bejeweled_modes.lua
lua tests/kic_bejeweled_migration.lua
lua tests/kic_bejeweled_effects.lua
lua tests/roguelite_integration.lua
lua tests/bejeweled_hints.lua
lua tests/share_best.lua
lua tests/tetris.lua
python tests/artwork.py
python tests/options_assets.py
```

The focused roguelite suites also run from the repository root:

```powershell
Get-ChildItem tests -Filter roguelite_*.lua | ForEach-Object { lua $_.FullName }
```

Engine checks include starting perft 20 / 400 / 8902 / 197281 and Kiwipete
48 / 2039 / 97862. Multiplayer tests use the real bundled AceComm, AceSerializer
and ChatThrottleLib in isolated mocked clients: five-member parties, lobby discovery/join/capacity, Ready and countdown cancellation,
reusable lobbies, round isolation, dropped commits, host/guest/simultaneous reloads,
rollback refusal, multi-chunk/terminal recovery, draw claims, mate, resignation
and duplicate results. UI tests cover both orientations, supplied artwork,
75%-150% scale, hitboxes, layering, captures and all promotion choices.

These are offline tests; no live two-client WoW verification is claimed.

## Before beta

- Run the two-client steps on the actual Retail build, including five-person
  parties and the lobby host playing each color.
- Exercise castling, en passant, underpromotion, long names, capture trays and
  history scrolling at 75%, 100% and 150% Interface Scale.
- Reload each client and both; close/reopen; disconnect/reconnect during the
  grace period; verify that party departure creates interruption, not victory.
- Test delayed/lost messages alongside other busy addons. Failed recovery must
  remain interrupted without an invented result.
- Extend composed dead-position adjudication before claiming exhaustive coverage
  of every FIDE dead position.

No remote push or CurseForge release ZIP is included.
