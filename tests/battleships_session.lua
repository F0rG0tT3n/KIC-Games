local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local clients, checks, blocked = {}, 0, {}
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
            for _, frame in ipairs(c.frames) do
                if frame.shown and frame.scripts.OnUpdate then
                    frame.scripts.OnUpdate(frame, 0.1)
                end
            end
        end
        local count = #h.packets
        for _ = 1, count do
            local packet = table.remove(h.packets, 1)
            check(packet.channel == "PARTY" and #packet.body <= 255, "Invalid transport")
            for _, c in ipairs(clients) do
                if not blocked[c.name] and not blocked["from:" .. packet.sender] then
                    c:event("CHAT_MSG_ADDON", packet.prefix, packet.body, packet.channel, packet.sender)
                end
            end
        end
    end
end
local function waitFor(predicate, message)
    for _ = 1, 80 do
        if predicate() then
            check(true, message)
            return
        end
        pump(0.25)
    end
    for _, c in ipairs(clients) do
        print(c.name, c.games.Lobby and c.games.Lobby.status)
        for _, notice in ipairs(c.notices) do
            print(notice)
        end
    end
    error(message)
end
for i = 1, 3 do
    clients[i] = h.client("Naval" .. i, "Realm")
end
for _, c in ipairs(clients) do
    for _, other in ipairs(clients) do
        if c ~= other then
            c.roster[#c.roster + 1] = other.name
        end
    end
end
local a, b, spectator = clients[1], clients[2], clients[3]
local G, H, S = a.games, b.games, spectator.games
local A, B = G.Battleships, H.Battleships
local R = A.Rules
check(G.Registry.battleships.mode == "multiplayer" and G.Registry.battleships.maxPlayers == 2, "Registration")
check(not G:StartSingleplayer("battleships"), "Naval game launched solo")
check(G:CreateLobby("battleships"), "Host lobby")
waitFor(function()
    return H.Listings[a.name]
end, "Lobby not discovered")
check(H:JoinLobby(a.name, G.Lobby.id), "Join request")
waitFor(function()
    return H.Lobby and #G.Lobby.members == 2
end, "Guest not admitted")
check(S:JoinLobby(a.name, G.Lobby.id), "Third-player request")
waitFor(function()
    return not S.Pending
end, "Third-player request unresolved")
check(not S.Lobby and #G.Lobby.members == 2, "Third player admitted")
check(G:Ready(true) and H:Ready(true), "Ready failed")
waitFor(function()
    return A.view and B.view and A.running and B.running
end, "Match did not start")
local matchID = G.Lobby.id
check(A.view.phase == "setup" and B.view.phase == "setup", "Missing setup")
check(A.view.enemyFleet == "" and B.view.enemyFleet == "", "Enemy fleet disclosed")
check(not S.ActiveGame and not S.Battleships.view, "Spectator received game view")
for _, module in ipairs({ A, B }) do
    check(module.root:IsVisible() and module.root.width == module.root:GetParent().width, "Board not in main window")
    check(module.step >= 22 and module.summary and not module.summary:IsShown(), "Initial UI")
    module.auto.scripts.OnClick()
    check(R.EncodeFleet(module.draft), "Auto-place button")
end
-- Manual placement, invalid placement and keyboard rotation share the real UI callbacks.
B.clear.scripts.OnClick()
B.boards[1].cells[1].scripts.OnClick(nil, "LeftButton")
check(B.draft[1] and B.selected == 2, "Placement did not select next ship")
B.boards[1].cells[1].scripts.OnClick(nil, "LeftButton")
check(not B.draft[2], "Overlapping placement accepted")
B.root.scripts.OnKeyDown(B.root, "R")
check(B.vertical and B.root.propagate == false, "R did not rotate")
B.root.scripts.OnKeyUp(B.root, "R")
B.auto.scripts.OnClick()
check(A:Request("lock") and B:Request("lock"), "Lock request failed")
waitFor(function()
    return A.view.phase == "battle" and B.view.phase == "battle"
end, "Fleets did not synchronize")
check(A.view.turn == 1 and A.view.ownReady and B.view.ownReady, "Initial turn")
check(A.view.enemyFleet == "" and B.view.enemyFleet == "", "Battle leaked fleet")
check(not B:Request("fire", 1), "Guest fired out of turn")
local enemyBoard = R.Board(R.DecodeFleet(A.authority.fleets[2]))
local ownBoard = R.Board(R.DecodeFleet(A.authority.fleets[1]))
local targets, misses = {}, {}
for i = 1, 100 do
    if enemyBoard[i] > 0 then
        targets[#targets + 1] = i
    end
    if ownBoard[i] == 0 then
        misses[#misses + 1] = i
    end
end
local function fire(module, index)
    local rev = A.authority.rev
    check(module:Request("fire", index), "Shot rejected locally")
    waitFor(function()
        return A.authority.rev == rev + 1 and B.view.rev == rev + 1
    end, "Shot not acknowledged")
end
fire(A, targets[1])
local revision = A.authority.rev
-- The host rejects spectators and malformed input even if called directly.
A:HostAction({ seq = 2, rev = revision, op = "fire", cell = 100 }, spectator.name)
A:HostAction({ seq = 2, rev = revision, op = "fire", cell = 101 }, b.name)
check(A.authority.rev == revision, "Invalid input changed authoritative state")
-- Duplicate guest actions are idempotent and missing action packets are retried.
blocked["from:" .. b.name] = true
check(B:Request("fire", misses[1]), "Pending guest shot")
local pending = H.Copy(B.pending)
pump(2.5)
check(B.pending and A.authority.rev == revision, "Dropped shot incorrectly acknowledged")
b:event("PLAYER_LOGOUT")
local pendingReload = h.client("Naval2", "Realm", H.Copy(H.DB))
pendingReload.roster = b.roster
clients[2], b, H = pendingReload, pendingReload, pendingReload.games
B = H.Battleships
check(B.running and B.pending and B.pending.seq == pending.seq, "Reload lost pending action")
blocked["from:" .. b.name] = nil
waitFor(function()
    return not B.pending and A.authority.rev == revision + 1
end, "Retry did not recover")
A:HostAction(pending, b.name)
pump(0.5)
check(A.authority.rev == revision + 1, "Duplicate applied twice")
-- Stale and wrong-seat snapshots cannot rewind or replace the guest's board.
local old = R.Pack(R.View(R.New(1), 2))
B:Receive("bs_view", old, a.name)
B:Receive("bs_view", R.Pack(R.View(A.authority, 1)), a.name)
check(B.view.rev == A.authority.rev, "Invalid snapshot replaced view")
-- Guest reload retains private layout and the same lobby/run.
b:event("PLAYER_LOGOUT")
local saved = H.Copy(H.DB)
local reloaded = h.client("Naval2", "Realm", saved)
reloaded.roster = b.roster
clients[2], b, H = reloaded, reloaded, reloaded.games
B = H.Battleships
check(B.running and H.Lobby.id == matchID and B.view.rev == A.authority.rev, "Guest recovery failed")
waitFor(function()
    return not B.waiting
end, "Guest did not reconnect")
-- Host recovery retains the authoritative board and accepted action counters.
a:event("PLAYER_LOGOUT")
saved = G.Copy(G.DB)
reloaded = h.client("Naval1", "Realm", saved)
reloaded.roster = a.roster
clients[1], a, G = reloaded, reloaded, reloaded.games
A, R = G.Battleships, G.Battleships.Rules
check(A.running and A.authority.rev == B.view.rev and A.view.phase == "battle", "Host recovery failed")
pump(1)
for i = 2, 17 do
    fire(A, targets[i])
    if i < 17 then
        fire(B, misses[i])
    end
end
waitFor(function()
    return not G.ActiveGame and not H.ActiveGame
end, "Winner did not finish both clients")
check(A.view.phase == "ended" and B.view.phase == "ended" and A.view.winner == 1, "Final view lost")
check(A.view.enemyFleet ~= "" and B.view.enemyFleet ~= "", "Final fleets not revealed")
check(
    A.root:IsVisible() and B.root:IsVisible() and G.UI.completedGame and H.UI.completedGame,
    "Final board left main window"
)
check(A.summary:IsShown() and B.summary:IsShown(), "Result popup missing")
check(A.summary.heading.text == "VICTORY!" and B.summary.heading.text == "DEFEAT", "Outcome display")
check(A.summary.details.text:find("17 / 17", 1, true), "Result score missing")
check(A:Storage().stats.wins == 1 and B:Storage().stats.losses == 1, "Lifetime stats")
A:RecordStats(A.result)
check(A:Storage().stats.completed == 1, "Duplicate result counted twice")
check(not A:Storage().active and not B:Storage().active, "Completed match recoverable")
G.UI.resultGameID = "battleships"
G.UI:RefreshResults()
check(G.UI.bestScore.text == "1W / 0L" and G.UI.resultShareBest:IsEnabled(), "Results integration")
A.summary.again.scripts.OnClick()
B.summary.again.scripts.OnClick()
waitFor(function()
    return A.running and B.running and G.Lobby.run == 2 and B.view and B.view.phase == "setup"
end, "Rematch failed")
check(
    G.Lobby.id == matchID and A.view.turn == 2 and A.view.rev == 0 and next(A.draft) == nil,
    "Rematch reused board/starter"
)
check(not A.summary:IsShown() and not B.summary:IsShown(), "Old popup remains")
check(B:Request("resign"), "Setup resign failed")
waitFor(function()
    return not G.ActiveGame and not H.ActiveGame
end, "Resign did not end match")
check(A.view.reason == "resigned" and B.view.reason == "resigned", "Resign state")
check(A:Storage().stats.wins == 2 and B:Storage().stats.losses == 2, "Resign stats")
A.summary.menu.scripts.OnClick()
check(G.UI.launcherPage == "home" and not A.summary:IsShown() and not G.UI.completedGame, "Back to menu failed")
-- Heartbeats keep an idle, hidden match alive; loss of the guest's outbound
-- transport must not be masked by the host publishing its own snapshots.
check(G:Ready(true) and H:Ready(true), "Third run Ready")
waitFor(function()
    return A.running and B.running and B.view
end, "Third run did not start")
G.UI:OpenLauncher("home")
H.UI:OpenLauncher("home")
pump(20)
check(A.running and B.running and not A.waiting and not B.waiting, "Hidden idle match timed out")
blocked["from:" .. b.name] = true
pump(25)
check(
    A.waiting and A.running and A.status.text:find("Connection interrupted", 1, true),
    "Missing heartbeat not detected"
)
pump(25)
blocked["from:" .. b.name] = nil
waitFor(function()
    return not G.ActiveGame and not H.ActiveGame
end, "Connection loss did not interrupt both clients")
check(A:Storage().stats.completed == 2 and B:Storage().stats.completed == 2, "Connection loss awarded a winner")
check(not A:Storage().active and not B:Storage().active, "Interrupted match persisted")
for _, c in ipairs(clients) do
    for _, notice in ipairs(c.notices) do
        check(
            not notice:find("/ timer:", 1, true) and not notice:find("/ On", 1, true),
            "Module callback error: " .. notice
        )
    end
end
print("PASS: " .. checks .. " Battleships real PARTY transport, privacy, retries, recovery, results and rematch checks")
