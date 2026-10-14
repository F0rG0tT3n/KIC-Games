# KIC-Games API v2

## Register a module

A separate game addon should load after the framework:

```toc
## Interface: 120105
## Title: KIC Example Game
## Dependencies: KIC-Games
Example.lua
```

Register once during addon loading, before the user joins a lobby. `id` is a
stable unique identifier (1-32 letters/digits/underscores/hyphens). `version` is
the game's wire/rules version, not necessarily its release number. Versions must
match exactly before players can ready. Player limits are integers from 1 to 5.

```lua
KICGames:RegisterGame({
    id = "my_game",
    title = "My Game",
    description = "A short description",
    version = "1",
    minPlayers = 2,
    maxPlayers = 5,

    CreateUI = function(context, parent)
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetAllPoints(parent)
        context.frame = frame
        return frame
    end,

    OnStart = function(context, session, restored)
        -- Start a round. Only the host creates authoritative initial state.
        -- A restored guest receives state through OnSyncRequested below.
        if context.isHost then context.state = { turn = 1 } end
    end,

    OnMessage = function(context, event, data, sender, kind)
        if kind == "action" and context.isHost then
            -- Validate the event, payload, sender's turn and all game rules.
            -- Update context.state, then publish it to the participants:
            -- context:SendState("snapshot", context.state)
        elseif kind == "state" and event == "snapshot" then
            context.state = data
            -- Render the received authoritative state.
        end
    end,

    OnSyncRequested = function(context, player)
        -- Called on the host after a guest starts/rejoins a running round.
        context:SendState("snapshot", context.state, player)
    end,

    OnStop = function(context, reason)
        -- Release module-owned resources here.
        -- context:NewTicker / context:After timers are already cancelled.
        -- The returned UI frame is hidden automatically.
    end,
})
```

This is an API illustration, not an installed playable game. Never register
placeholder games merely to populate the launcher.

## Hooks

All hooks receive the per-round `context` as their first argument, without a
module-table `self`. Hook failures are caught and shown in the local chat frame.

| Hook | Arguments after context | Purpose |
| --- | --- | --- |
| `CreateUI` | `parent` | Required. Build the module's own UI inside the 860 x 450 game area; return its root frame. |
| `OnStart` | `session, restored` | Required. Start a round. `restored` is true for a guest recovering an already-running match. |
| `OnMessage` | `event, data, sender, kind` | Optional. `action` reaches only the host; `state` originates only from the host. |
| `OnSyncRequested` | `player` | Optional, required for recoverable games. Host sends a full module state to this participant. |
| `OnPlayersChanged` | `session` | Optional. Active roster-change notification; departures normally interrupt the round. |
| `OnResult` | `result` | Optional. Receive an authoritative result if the module is still active when it arrives. |
| `OnStop` | `reason` | Optional. Always release module-owned timers/UI references here, including immediate interruption. |

`reason` may be `completed`, `aborted`, `left`, `closed`, `group_changed`,
`host_timeout`, `removed`, `lobby`, `restart` or `error`. A cancelled guest may
already have stopped before the host's result arrives; `OnResult` is therefore
not guaranteed on abrupt interruption. Use `OnStop` for cleanup and the shared
result APIs for history. Never infer a win/loss solely from the teardown reason.

## Context

| API | Behavior |
| --- | --- |
| `context.isHost` | Whether this client hosts this round. |
| `context.player` | Local canonical `Character-Realm` name. |
| `context:GetSession()` | Detached session copy, or nil after this round ends. |
| `context:SendAction(event, data)` | Route an input to the host. A host's own input is delivered locally through the same hook. |
| `context:SendState(event, data, target)` | Host only. Broadcast state, or deliver to one canonical participant name. Broadcast includes the host locally. |
| `context:FinishGame(result)` | Host only. Finalize a normal result, return everyone to the lobby and reset readiness. |
| `context:EndGame(result)` | Alias for `FinishGame`. Manual interruption uses `AbortGame`. |
| `context:AbortGame()` | Any participant. Stop locally immediately; request shared interruption. |
| `context:NewTicker(seconds, callback)` | Create a repeating timer that is cancelled on stop. Callback receives context. |
| `context:After(seconds, callback)` | Create a cancellable one-shot timer with the same lifecycle guard. |
| `context:Show()` | Reopen the active game UI. |

Send methods return `true` if accepted locally, or `false, reason` if rejected.
Timer methods return a WoW timer handle, or `nil, reason`; delays must be greater
than zero and at most 3600 seconds. Framework-managed callbacks do not run after
their module instance ends, even if an old callback was already queued.
Acceptance does not guarantee delivery by the WoW server. Modules requiring
delivery acknowledgment must implement sequence numbers and acknowledgments.
Targeting uses a recipient field on the group channel, so it supports cross-realm
group members without relying on cross-realm whispers. Other group members can
still observe the wire data; this is not confidential communication.

## Session

`KICGames:GetSession()` and `context:GetSession()` return copies shaped like:

```lua
{
    id = "unique host session id",
    host = "Character-Realm",
    channel = "PARTY", -- RAID or INSTANCE_CHAT also possible
    gameID = "my_game",
    gameVersion = "1",
    status = "waiting", -- or running
    revision = 3,
    run = 0, -- increments on each start
    epoch = 0, -- invalidates old readiness requests on selection/end
    startedAt = 0, -- server timestamp set on start
    result = nil, -- final result present while waiting after a round
    members = {
        { name = "Character-Realm", ready = true, version = "1" },
    },
}
```

Do not mutate `KICGames.Lobby` or rely on its internal shape changing without an
API version update. The host's game rules must validate every incoming action;
membership validation does not make another player's input trustworthy.

## Results and interruption

The game decides its rules, scores and winners. Only the host can finalize a
completed result. For example, using actual canonical names from the session:

```lua
context:FinishGame({
    summary = "The final round is complete.", -- at most 160 bytes
    entries = {
        { player = "Anna-Realm", score = 100, rank = 1, outcome = "win" },
        { player = "Bela-Realm", score = 80, rank = 2, outcome = "loss" },
    },
})
```

`entries` is optional. Every participant is included in the final result;
supplied entries enrich those participants. Unknown/duplicate players, nonfinite
scores, invalid ranks and unknown outcomes are rejected. Score and rank are
optional, ties are allowed, and outcome must be `win`, `loss` or `draw` if given.
The framework does not invent outcomes from scores. Shared history sorts by
supplied rank and then player name.

Every game inherits the framework's **Stop match** button and `/kicgames stop`.
Any participant may interrupt; there is no vote or confirmation. The local UI
closes and module timers stop without waiting for acknowledgment. The control
message uses a separate prefix and ALERT priority, independent of a module's
NORMAL multipart queue. WoW can still delay delivery to other clients.

The host records `status = "aborted"` and a reason/initiator; interrupted matches
have no scores, ranks, wins or losses. The lobby remains open with readiness
reset. A guest stores a provisional interrupted result until the host's final
snapshot arrives. A finalized result wins over a late cancellation. Old running
snapshots and old module contexts cannot resume a locally stopped round.

`KICGames:GetResults(gameID)` returns copies of the most recent 20 local match
records, optionally filtered by game ID. `KICGames:GetResultStats(gameID)` counts
completed/interrupted matches and explicit local wins/losses/draws in that
retained history. Those are not lifetime totals. Result fields include `id`,
`sessionID`, `run`, `host`, `gameID`, `gameVersion`, `startedAt`, `endedAt`,
`status`, `reason`, `summary`, `entries` and optional `abortedBy`/`provisional`.
Repeated snapshots are deduplicated by match ID. Only matches containing the
local player are stored. The framework owns history persistence and presentation.

## Payload and performance rules

- Event names: nonempty strings of at most 40 bytes.
- Data: nil, booleans, finite numbers, strings or acyclic tables with string/number keys.
- Individual strings: at most 4096 bytes. Table nesting: at most 8 levels, with
  at most 512 total entries. Total serialized message: at most 12288 bytes.
- AceSerializer handles Lua values; AceComm splits messages into legal WoW
  packets and ChatThrottleLib queues/retries client throttling.
- For shared simulation, transmit choices and occasional compact snapshots.
  Sending every animation frame will build up a queue and delay gameplay.
- Network envelopes include game ID and version as well as session and round;
  equal event names in different games cannot reach each other's message handlers.
- The framework protects the session/round and host authority. Game modules own
  state sequencing, resync contents, randomness, rule validation and timers.
- Initialize guest UI before state arrives; show a waiting state until the host's
  snapshot is received. A fresh module cannot reconstruct a game from lobby
  membership alone.
- Reuse UI frames or explicitly release them; WoW frames are not garbage collected.
  Prefer context-managed timers. Cancel any other timers in `OnStop`. Old context
  methods are disabled after their module instance ends.

## Other public entry points

`KICGames.API_VERSION`, `KICGames.VERSION`, `KICGames:GetGames()`,
`KICGames:IsHost()`, `KICGames:CreateLobby()`, `KICGames:Discover()`,
`KICGames:JoinLobby(host, id)`, `KICGames:SelectGame(id)`,
`KICGames:Ready(boolean)`, `KICGames:CanStart()`, `KICGames:StartGame()`,
`KICGames:ReturnToLobby()` (host interruption), `KICGames:AbortGame()`,
`KICGames:FinishGame(result)`, `KICGames:GetResults(gameID)`,
`KICGames:GetResultStats(gameID)` and `KICGames:LeaveLobby()` are available to integrations.

API v2 requires a module-owned `CreateUI` and adds result/timer/interruption APIs.
The network prefixes changed from v1 so incompatible framework versions do not
share a lobby. Separate modules continue to declare `## Dependencies: KIC-Games`.
