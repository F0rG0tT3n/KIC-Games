-- Run from the repository root: lua tests/chess_lobby.lua
local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks, clients = 0, {}
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function pump(seconds)
    for _ = 1, math.ceil(seconds * 10) do
        h.advance(0.1)
        for _, c in ipairs(clients) do
            for _, timer in ipairs(c.scheduled or {}) do
                if not timer.cancelled and c.env.GetTime() >= timer.at then
                    timer.at = c.env.GetTime() + timer.period
                    timer.callback()
                end
            end
            c.games.Chess:Tick()
            for _, frame in ipairs(c.frames) do
                if frame.shown and frame.scripts.OnUpdate then
                    frame.scripts.OnUpdate(frame, 0.1)
                end
            end
        end
        local count = #h.packets
        for _ = 1, count do
            local p = table.remove(h.packets, 1)
            check(p.channel == "PARTY" and #p.body <= 255, "Invalid lobby transport")
            for _, c in ipairs(clients) do
                c:event("CHAT_MSG_ADDON", p.prefix, p.body, p.channel, p.sender)
            end
        end
    end
end
local function waitFor(predicate, message)
    for _ = 1, 40 do
        if predicate() then
            check(true, message)
            return
        end
        pump(0.5)
    end
    error(message)
end
for i = 1, 3 do
    clients[i] = h.client("LobbyChess" .. i, "Realm")
end
for _, c in ipairs(clients) do
    for _, other in ipairs(clients) do
        if c ~= other then
            c.roster[#c.roster + 1] = other.name
        end
    end
    check(c.games.UI:LaunchGame("chess"), "Chess card did not open multiplayer")
end
local a, b, spectator = clients[1], clients[2], clients[3]
local G, H, S = a.games, b.games, spectator.games
local chessCard
for _, card in ipairs(G.UI.launcherCards) do
    if card:IsShown() and card.game.id == "chess" then
        chessCard = card
    end
end
check(chessCard and chessCard.play:IsVisible() and chessCard.play:IsEnabled(), "Host game hidden for Chess")
chessCard.play.scripts.OnClick()
check(G.Lobby and G.Lobby.status == "waiting" and #G.Lobby.members == 1, "Host did not create a waiting lobby")
local id = G.Lobby.id
waitFor(function()
    return H.Listings[a.name] and S.Listings[a.name]
end, "Party cannot discover waiting lobby")
check(H.UI.listingRows[1]:IsVisible(), "Lobby browser row hidden")
H.UI.listingRows[1].scripts.OnClick()
waitFor(function()
    return H.Lobby and #G.Lobby.members == 2
end, "Browser Join did not admit player")
check(H.Lobby.id == id and H.UI.ready:IsVisible() and G.UI.ready:IsVisible(), "Joined lobby has no Ready control")
check(not G.ActiveGame and not H.ActiveGame, "Joining started without Ready")
check(S:JoinLobby(a.name, id), "Full lobby request could not be sent")
waitFor(function()
    return not S.Pending
end, "Full lobby request never resolved")
check(not S.Lobby and #G.Lobby.members == 2, "Chess admitted a third participant")
G.UI.ready.scripts.OnClick()
pump(2)
check(G.Lobby.status == "waiting" and not G.ActiveGame, "One ready player started game")
H.UI.ready.scripts.OnClick()
waitFor(function()
    return G.Lobby.status == "countdown"
end, "All ready did not start countdown")
check(not G.ActiveGame and not H.ActiveGame, "Game opened before countdown")
check(H:Ready(false), "Guest could not cancel readiness during countdown")
waitFor(function()
    return G.Lobby.status == "waiting" and H.Lobby.status == "waiting"
end, "Unready did not cancel countdown")
check(not G.ActiveGame and not H.ActiveGame, "Canceled countdown opened game")
check(G:Ready(true) and H:Ready(true), "Could not ready after canceled countdown")
waitFor(function()
    return G.Chess:CanInput() or H.Chess:CanInput()
end, "Shared lobby did not start Chess")
check(G.Chess.running and H.Chess.running, "Chess board missing on one client")
check(G.Lobby.run == 1 and H.Lobby.run == 1 and G.Lobby.id == id, "Start replaced lobby identity")
check(not S.ActiveGame and not S.Chess.match, "Party spectator became participant")
check(not G.Chess.Challenge and not G.Chess.inviteWindow, "Challenge-only path still exposed")
local oldID = G.Chess.match.info.id
local mover = G.Chess.match.state.turn == 1 and G.Chess.match.info.white or G.Chess.match.info.black
check((mover == a.name and G or H).Chess:Request("e2e4"), "First lobby move failed")
waitFor(function()
    return G.Chess.match.seq == 1 and H.Chess.match.seq == 1
end, "Lobby move did not synchronize")
H.UI:OpenLauncher("multiplayer")
H.UI.endGame.scripts.OnClick()
waitFor(function()
    return G.Lobby.status == "waiting" and H.Lobby.status == "waiting"
end, "Stop did not return both players to lobby")
check(
    G.Lobby.id == id and #G.Lobby.members == 2 and not G.ActiveGame and not H.ActiveGame,
    "Stop destroyed reusable lobby"
)
check(not G:LocalMember().ready and not H:LocalMember().ready, "Stop left stale Ready flags")
check(G.Chess:Storage().stats.completed == 0 and H.Chess:Storage().stats.completed == 0, "Stop awarded a Chess result")
check(G:Ready(true) and H:Ready(true), "Rematch Ready failed")
waitFor(function()
    return G.Chess.running
        and H.Chess.running
        and G.Chess.match.info.id ~= oldID
        and not G.Chess.match.recovering
        and not H.Chess.match.recovering
end, "Rematch failed")
check(G.Lobby.id == id and G.Lobby.run == 2 and H.Lobby.run == 2, "Rematch did not reuse lobby with next round")
check(G.Chess.match.seq == 0 and H.Chess.match.seq == 0 and #G.Chess.match.state.moves == 0, "Rematch reused old board")
G.Chess:ReceiveControl({ op = "interrupt", version = "1", target = a.name, id = oldID }, b.name)
check(G.Chess.running and not G.Chess.match.abandoned, "Old-round control interrupted rematch")
local invalid = G:GetSession()
invalid.chess.white = spectator.name
check(not H:ValidSnapshot(invalid, a.name), "Snapshot assigned a spectator to White")
invalid = G:GetSession()
invalid.chess.white = G.Chess.match.info.black
check(not H:ValidSnapshot(invalid, a.name), "Snapshot changed colors during an active round")
-- A host reload preserves the second round, snapshot revision and join tokens.
local saved = G.Copy(G.DB)
local oldRevision = G.Lobby.revision
local reloaded = h.client("LobbyChess1", "Realm", saved)
reloaded.roster = a.roster
clients[1], a, G = reloaded, reloaded, reloaded.games
waitFor(function()
    return G.Chess.running and not G.Chess.match.recovering and not H.Chess.match.recovering
end, "Round-two host reload failed")
check(G.Lobby.id == id and G.Lobby.run == 2 and G.Lobby.revision >= oldRevision, "Reload reset lobby round/revision")
H:LeaveLobby()
waitFor(function()
    return #G.Lobby.members == 1 and G.Lobby.status == "waiting"
end, "Guest Leave did not remove member after host reload")
check(not H.Lobby and not H.ActiveGame and not G.ActiveGame, "Leave leaked an active game")
check(G.Chess:Storage().stats.completed == 0, "Leaving awarded a win")
G:LeaveLobby()
waitFor(function()
    return not S.Listings[a.name]
end, "Host Close left advertised lobby")
check(not G.Lobby and not G.ActiveGame, "Host could not close lobby")
-- Chess selection respects the same capacity/readiness/version rules as other games.
for _, c in ipairs(clients) do
    c.games:RegisterGame({
        id = "lobby_fixture",
        title = "Lobby Fixture",
        version = "1",
        mode = "multiplayer",
        minPlayers = 2,
        maxPlayers = 3,
        OnStart = function() end,
        CreateUI = function(_, parent)
            return c.env.CreateFrame("Frame", nil, parent)
        end,
    })
end
check(G:CreateLobby("lobby_fixture"), "Generic multiplayer Host failed")
waitFor(function()
    return H.Listings[a.name] and S.Listings[a.name]
end, "Generic lobby not advertised")
check(H:JoinLobby(a.name, G.Lobby.id), "Generic guest Join failed")
waitFor(function()
    return H.Lobby and #G.Lobby.members == 2
end, "Generic first guest missing")
check(S:JoinLobby(a.name, G.Lobby.id), "Generic third-player Join failed")
waitFor(function()
    return S.Lobby and #G.Lobby.members == 3
end, "Generic third member missing")
check(not G:SelectGame("chess"), "Three-player lobby selected two-player Chess")
S:LeaveLobby()
waitFor(function()
    return #G.Lobby.members == 2
end, "Generic Leave failed")
check(G:Ready(true), "Generic Ready failed")
H.Registry.chess.version = "outdated"
check(G:SelectGame("chess"), "Shared lobby cannot switch to Chess")
waitFor(function()
    return H.Lobby.gameID == "chess" and G.Lobby.members[2].version == "outdated"
end, "Chess version negotiation failed")
check(not G:LocalMember().ready and not H:LocalMember().ready, "Switching games retained Ready flags")
check(not H:Ready(true) and not G:CanStart(), "Different Chess versions could start")
H.Registry.chess.version = "2"
G:PublishLobby()
waitFor(function()
    return G.Lobby.members[2].version == "2"
end, "Matching Chess version not recognized")
check(G:Ready(true) and H:Ready(true), "Matching clients cannot ready after game switch")
waitFor(function()
    return G.Chess.running and H.Chess.running and not G.Chess.match.recovering and not H.Chess.match.recovering
end, "Switched lobby could not start Chess")
check(G:AbortGame(), "Host cannot stop Chess through shared controls")
waitFor(function()
    return G.Lobby.status == "waiting" and H.Lobby.status == "waiting"
end, "Host stop did not preserve shared lobby")
for _, c in ipairs(clients) do
    check(#c.chatMessages == 0, "Lobby emitted visible party chat")
    for _, notice in ipairs(c.notices) do
        check(not notice:find(" / OnStart:", 1, true) and not notice:find(" / CreateUI:", 1, true), notice)
    end
end
print(string.format("PASS: %d Chess Host/Join/Ready/countdown, capacity, stop/rematch and reload assertions", checks))
