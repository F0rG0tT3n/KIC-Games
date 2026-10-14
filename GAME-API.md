# KIC-Games API v1

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
        -- Cancel module timers and release resources here.
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
| `CreateUI` | `parent` | Optional. Build inside the 860 x 450 game area; return the root frame so it can be hidden on stop. |
| `OnStart` | `session, restored` | Required. Start a round. `restored` is true for a guest recovering an already-running match. |
| `OnMessage` | `event, data, sender, kind` | Optional. `action` reaches only the host; `state` originates only from the host. |
| `OnSyncRequested` | `player` | Optional, required for recoverable games. Host sends a full module state to this participant. |
| `OnPlayersChanged` | `session` | Optional. Active roster-change notification; v1 normally ends the round on departures. |
| `OnStop` | `reason` | Optional. Tear down timers/UI references. |

`reason` may be `ended`, `left`, `closed`, `group_changed`, `host_timeout`,
`removed`, `lobby`, `restart` or `error`. On a host, a departure ends the round
with `ended`. Do not infer gameplay outcomes solely from the teardown reason.

## Context

| API | Behavior |
| --- | --- |
| `context.isHost` | Whether this client hosts this round. |
| `context.player` | Local canonical `Character-Realm` name. |
| `context:GetSession()` | Detached session copy, or nil after this round ends. |
| `context:SendAction(event, data)` | Route an input to the host. A host's own input is delivered locally through the same hook. |
| `context:SendState(event, data, target)` | Host only. Broadcast state, or deliver to one canonical participant name. Broadcast includes the host locally. |
| `context:EndGame()` | Host only. End the round and reset readiness in the lobby. |
| `context:Show()` | Reopen the active game UI. |

Send methods return `true` if accepted locally, or `false, reason` if rejected.
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
    members = {
        { name = "Character-Realm", ready = true, version = "1" },
    },
}
```

Do not mutate `KICGames.Lobby` or rely on its internal shape changing without an
API version update. The host's game rules must validate every incoming action;
membership validation does not make another player's input trustworthy.

## Payload and performance rules

- Event names: nonempty strings of at most 40 bytes.
- Data: nil, booleans, finite numbers, strings or acyclic tables with string/number keys.
- Individual strings: at most 4096 bytes. Table nesting: at most 8 levels, with
  at most 512 total entries. Total serialized message: at most 12288 bytes.
- AceSerializer handles Lua values; AceComm splits messages into legal WoW
  packets and ChatThrottleLib queues/retries client throttling.
- For shared simulation, transmit choices and occasional compact snapshots.
  Sending every animation frame will build up a queue and delay gameplay.
- The framework protects the session/round and host authority. Game modules own
  state sequencing, resync contents, randomness, rule validation and timers.
- Initialize guest UI before state arrives; show a waiting state until the host's
  snapshot is received. A fresh module cannot reconstruct a game from lobby
  membership alone.
- Reuse UI frames or explicitly release them; WoW frames are not garbage collected.
  Cancel timers in `OnStop`. Old context send methods are disabled after their round.

## Other public entry points

`KICGames.API_VERSION`, `KICGames.VERSION`, `KICGames:GetGames()`,
`KICGames:IsHost()`, `KICGames:CreateLobby()`, `KICGames:Discover()`,
`KICGames:JoinLobby(host, id)`, `KICGames:SelectGame(id)`,
`KICGames:Ready(boolean)`, `KICGames:CanStart()`, `KICGames:StartGame()`,
`KICGames:ReturnToLobby()` and `KICGames:LeaveLobby()` are available to integrations.
