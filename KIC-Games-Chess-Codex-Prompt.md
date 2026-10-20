# KIC-Games — Implement Chess, a complete party multiplayer game

Implement a new **fully playable, rules-correct two-player Chess game** inside the existing World of Warcraft Retail addon KIC-Games. The supplied Chess artwork has **already been copied into the project**. Use it directly; do not regenerate or substitute artwork. This is a new multiplayer game, not a replacement for Bejeweled, KIC Bejeweled or Tetris.

## Non-negotiable boundaries

- Preserve all existing games, their logic, scores, menus, artwork and working audio/volume settings. Do not redesign the shared launcher or Options UI.
- Reuse the actual existing architecture: `Games:RegisterGame`, `Lobby.lua`, `Communication.lua`, `Games:SendGameAction`, `Games:SendGameState`, AceComm-3.0/AceSerializer, `Theme.lua`, `Artwork.lua` and the existing Results framework. Inspect the real APIs first rather than assuming the examples below are exact signatures.
- Only **two active players in the same party** may participate in a given Chess match. The party may have 2–5 members; everyone else must not be able to move or affect the game. For the first version, support ordinary PARTY groups and explain unsupported RAID/instance-party scenarios rather than silently routing through another channel.
- **Never use WHISPER** and never generate visible PARTY chat messages. Use only the addon's existing PARTY addon-message transport, validation and throttling; target recipients via validated identity fields in payloads while still broadcasting on PARTY.
- No external chess server, external service, matchmaking, spectator mode, real-time piece synchronization, chess AI, clocks, ratings, or CurseForge release ZIP in this task.
- No unnecessary refactor of generic KIC systems; narrow additions to the lobby/network layer are allowed only when Chess truly needs them.
- Finish a functional Chess game; do not stop at a rules prototype, registration-only module or placeholder game card.

## 1. Finished artwork (already installed)

All paths below are relative to the addon root `KIC-Games/`, and must exist before starting. Use WoW texture paths rooted at `Interface\\AddOns\\KIC-Games\\Media\\Chess\\...` (or use the actual addon name from `...` at runtime). Register these centrally in `Artwork.lua`, following the existing Bejeweled/Tetris conventions:

**Launcher**
- `Media/Chess/chess-hero.tga` — 1024 × 512, left portion intentionally dark for the launcher text overlay; use for Featured/hero artwork.
- `Media/Chess/chess-card.tga` — 256 × 256, use for game card, Recent Games and multiplayer list.

**Chess pieces — 12 distinct transparent 128 × 128 TGA textures**
- `Media/Chess/Pieces/white-king.tga`, `white-queen.tga`, `white-rook.tga`, `white-bishop.tga`, `white-knight.tga`, `white-pawn.tga`
- `Media/Chess/Pieces/black-king.tga`, `black-queen.tga`, `black-rook.tga`, `black-bishop.tga`, `black-knight.tga`, `black-pawn.tga`

**Board square textures — 64 × 64 TGA**
- `Media/Chess/Squares/square-light.tga`
- `Media/Chess/Squares/square-dark.tga`
- `Media/Chess/Squares/square-selected.tga` (transparent overlay)
- `Media/Chess/Squares/square-valid-move.tga` (transparent overlay)
- `Media/Chess/Squares/square-last-move.tga` (transparent overlay)
- `Media/Chess/Squares/square-check.tga` (transparent overlay)

Use the *provided pieces* on the board and for captured-piece lists. Do not use Unicode characters, text placeholders or arbitrary spell icons when these assets exist. Reuse the existing KIC neon-fantasy style and frame system. Board backgrounds and highlights must not obscure piece silhouettes. Preserve logical hit areas through UI scaling. For best readability make pieces approximately 85–92% of cell size, centered, with alpha blending. If you encounter missing files, report their exact paths rather than inventing replacements.

## 2. Register Chess as a game

- Stable ID: `chess`.
- Title: `CHESS` or `KIC CHESS` (prefer launcher conventions).
- Mode: `multiplayer`, `minPlayers = 2`, `maxPlayers = 2`, no AI.
- Only two players join the chess match even if the surrounding party has up to five players.
- Install through the existing registry and include the new Lua files in the `.toc` file in valid dependency order.
- Use the existing launcher, Multiplayer list, Play/Resume, Back to Launcher, X hide, Results and game lifecycle patterns.
- Set game version explicitly for compatibility checks.

## 3. Challenges, party member selection and match lifecycle

- In the Chess multiplayer screen list currently eligible PARTY members with normalized Name-Realm identities.
- Select a single opponent, then press **Challenge**. The recipient receives Accept/Decline; outsiders in the same party ignore targeted messages.
- Invitations expire, can be canceled and can be declined; handle simultaneous challenges predictably.
- Resolve white/black by an explicitly agreed Random assignment (optionally a color preference if easily supported). Both players must see the same final assignment before the first move.
- The match begins with a known standard initial position, agreed match ID and sequence number 0.
- The two participants can each be in only one active Chess match. Never route moves to a different opponent or stale match.
- Support one participant leaving the party, invitation cancel, logout/offline, `/reload`, game window hide, return to launcher and reenter. A hidden window must not automatically resign.
- On transport interruption, show Waiting/Reconnecting; do not silently declare a winner. Persist recoverable session state where safe, then reconcile with the other client on reload. If recovery is impossible, show an explicit aborted result rather than a fictitious win.
- Integrate with the existing lobby readiness/start/finish lifecycle; do not bypass it in a way that corrupts other party games.

## 4. Pure Lua, rules-complete chess engine

Implement the rules engine independent of WoW APIs, frames, transport or saved variables. Prefer a testable representation with a serializable board, side to move, castling rights, en passant target, halfmove/fullmove clocks and repetition history.

Must correctly implement:
- Standard initial layout; white starts; all six piece moves and captures.
- Pawn two-square initial move, diagonal capture, promotion to **Queen/Rook/Bishop/Knight** with explicit UI choice.
- En passant only on the immediately available turn, including rejection of moves that would expose the king to check.
- Both-side kingside and queenside castling, rook/king movement rights and checks on initial, transit and destination squares. The rook may move through an attacked square if all king conditions hold.
- Legality filtering: cannot move pinned pieces illegally or leave/put own king in check; kings may not be captured as ordinary pieces.
- Check, checkmate, stalemate, valid resignation, consensual draw.
- Correct threefold repetition and fifty-move **claim** handling; recognize supported automatic fivefold/75-move draw rules and dead/insufficient-mating-material cases without false positives.
- Legal move generation and deterministic result handling.
- Move notation in SAN, move history and FEN-style deterministic serialization for tests/recovery.
- Do not substitute pseudo-legal moves for actual legal moves.

## 5. Host-authoritative multiplayer state

Use the existing `Games:SendGameAction` (participant actions to host) and `Games:SendGameState` (host authoritative broadcasts), wherever appropriate. The local host invokes a validated action through the same move handling logic rather than a separate special path.

Protocol events should cover: challenge/accept/decline, agreed match start, move request, accepted move result, state-sync request/reply, draw offer/accept/reject, resign and terminal result. Fit the actual message envelope and avoid introducing duplicate transport layers.

Move request includes stable match ID, normalized sender/recipient identities, next expected sequence, from/to squares, optional promotion, and expected-state digest. Never accept client-supplied scores, board changes or game outcomes at face value.

Host validation must check:
1. Sender really belongs to this match and is still in the party.
2. It is their turn.
3. Requested move is legal according to the authoritative engine.
4. Sequence and previous digest are correct.
5. Valid requests are applied **exactly once**, then acknowledged/broadcast to both clients.

Clients rebuild/verify the state deterministically and request an authenticated bounded snapshot on mismatches. Handle duplicates, stale packets, out-of-order packets, delayed acknowledgments, aborted sessions and party roster changes. Never fork two independently authoritative boards. No per-frame network traffic: chess is turn-based.

Use bounded message sizes and reuse existing throttling, serialization and validation. Do not send whole board snapshots per move unless recovering state; only send compact move updates during normal play. An opponent must never be able to move your pieces or forge a win.

## 6. KIC Chess UI

Reuse the existing three-column neon UI styling and `Theme.lua` components; do not redo the main launcher.

**Left panel:** Chess hero/game identification, opponent identity, player color, match status, Challenge/Accept/Decline as appropriate, Offer Draw, Resign, Back to Launcher (existing navigation). Avoid an extra destructive Stop button.

**Center:** large **8×8** square board, readable at all supported KIC Interface Scale values. Render the provided 12 transparent piece TGAs over the provided light/dark square textures. Board orientation is White at bottom for White, rotated 180° for Black. Correct A–H and 1–8 coordinates. Click to select, click highlighted legal destination to move; drag-and-drop is optional only if it does not delay a working version. Show selected square, legal target dots, last move and check using the supplied textures; highlight captures distinctly using a border if needed. Promotion opens a selection overlay using the supplied same-color promotion piece icons. Prevent out-of-turn local moves and illegal move attempts. Preserve board dimensions; do not reduce the board to fit cosmetic extras.

**Right panel:** player names (white/black), turn/status (CHECK / CHECKMATE / DRAW), captured pieces, scrollable SAN history with move numbers, draw offer state and final game result. Use readable type sizes and prevent clipping at lower UI scales.

Show pending move state if waiting for host confirmation; do not optimistic-apply a move and leave it duplicated on acknowledgement. Hide/reopen must preserve the active match.

## 7. Scores and persistence

Use existing Results patterns, but keep Chess records separate from score-based minigames:
- Completed games, wins, losses, draws, opponent and optional date/move history.
- Only record terminal matches once using match ID; do not double-count after duplicate packets/reload.
- An ordinary disconnect is **not** automatically a win.
- Respect existing SavedVariables keys and backward compatibility; do not erase or overwrite other games' results.

## 8. Automated and multiplayer testing

Create deterministic engine tests and simulated two-client protocol tests. Cover at least:
- Starting-position perft counts 20 (depth 1), 400 (depth 2), 8902 (depth 3), and one other known position if practical.
- All piece moves, pins, checks, checkmate, stalemate, illegal king movement.
- En passant including discovered-check cases; castling constraints and lost rights; all four promotion types.
- Fifty-move/repetition and dead-position cases.
- FEN/SAN/serialization round-trips.
- Invitations, 2-player selection in 3–5-member party, declining/expiration, color negotiation, move acknowledgements, duplicates, stale match IDs and malformed payloads.
- Sequence errors, checksums, state recovery, reconnect/reload, opponent leaving, resign and draw results.
- No visible chat messages, no WHISPER traffic, no uncontrolled message spam.
- Artwork exists, all 12 pieces have unique registry entries, board assets load, and TOC order is valid.
- Regression smoke tests: Bejeweled, KIC Bejeweled, Tetris, launcher, results, current audio backend.

Provide a simple developer-only way to run both chess sides in a pure-Lua test harness without needing two live WoW clients. Do not register a separate chess singleplayer game.

## 9. Execution and completion

Inspect the codebase, create a brief plan internally, then implement in this order: pure engine + tests → session protocol + simulated-client tests → full board and lobby UI with the installed artwork → persistence/results → regression checks. Use local Git checkpoints if safe. No remote pushes. Do not stop after a prototype or ask for approval halfway through normal implementation.

At the end report exact files added/changed, protocol summary, implemented rules, test results, and an explicit two-WoW-client test checklist. Be truthful about tests that require an actual WoW client. No CurseForge ZIP. Do not modify existing game behavior or redesign global UI.

**Definition of done:** Two users who both have KIC-Games in the same PARTY can challenge each other, accept, play correct chess including castling/en-passant/promotion, see synchronized moves and results, recover a temporarily interrupted match when feasible, and leave/reopen the launcher without losing a healthy session. All supplied Chess art is used in the correct places.
