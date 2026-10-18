local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks, clients, drop = 0, {}, nil
local function check(v, s)
    assert(v, s)
    checks = checks + 1
end
local function pump(seconds)
    for _ = 1, math.ceil((seconds or 2) * 10) do
        h.advance(0.1)
        for _, c in ipairs(clients) do
            for _, timer in ipairs(c.scheduled or {}) do
                if not timer.cancelled and c.env.GetTime() >= timer.at then
                    timer.at = c.env.GetTime() + timer.period
                    timer.callback()
                end
            end
            for _, f in ipairs(c.frames) do
                if f.shown and f.scripts.OnUpdate then
                    f.scripts.OnUpdate(f, 0.1)
                end
            end
            c.games.Chess:Tick()
        end
        local count = #h.packets
        for _ = 1, count do
            local p = table.remove(h.packets, 1)
            check(p.channel == "PARTY", "Chess used a non-PARTY transport")
            check(#p.body <= 255, "Addon packet exceeds client limit")
            for _, c in ipairs(clients) do
                if not drop or not drop(p, c) then
                    c:event("CHAT_MSG_ADDON", p.prefix, p.body, p.channel, p.sender)
                end
            end
        end
    end
end
local function group(count)
    clients = {}
    for i = 1, count do
        clients[i] = h.client("Chess" .. i, "Realm" .. i)
    end
    for _, c in ipairs(clients) do
        c.roster = {}
        for _, other in ipairs(clients) do
            if c ~= other then
                c.roster[#c.roster + 1] = other.name
            end
        end
    end
    return clients[1], clients[2]
end
local function match(a, b)
    for _ = 1, 20 do
        if
            not a.games.Lobby
            or a.games.Lobby.status == "waiting" and b.games.Lobby and b.games.Lobby.status == "waiting"
        then
            break
        end
        pump(1)
    end
    if not a.games.Lobby then
        check(a.games:CreateLobby("chess"), "Host failed")
        pump(1)
        check(b.games.Listings[a.name], "Chess lobby not advertised")
        check(b.games:JoinLobby(a.name, a.games.Lobby.id), "Join failed")
        pump(2)
    else
        check(a.games.Lobby.status == "waiting" and b.games.Lobby.status == "waiting", "Completed lobby not reusable")
    end
    check(a.games:Ready(true) and b.games:Ready(true), "Ready failed")
    for _ = 1, 30 do
        pump(1)
        if
            a.games.Chess.running
            and b.games.Chess.running
            and not a.games.Chess.match.recovering
            and not b.games.Chess.match.recovering
        then
            break
        end
    end
    local A, B = a.games.Chess, b.games.Chess
    check(
        A.running and B.running and not A.match.recovering and not B.match.recovering,
        "Match did not synchronize/start: "
            .. tostring(a.games.Lobby and a.games.Lobby.status)
            .. "/"
            .. tostring(a.games.Lobby and a.games.Lobby.run)
            .. " / "
            .. tostring(b.games.Lobby and b.games.Lobby.status)
            .. "/"
            .. tostring(b.games.Lobby and b.games.Lobby.run)
            .. " host running="
            .. tostring(A.running)
            .. " guest running="
            .. tostring(B.running)
            .. " recovering="
            .. tostring(A.match and A.match.recovering)
            .. "/"
            .. tostring(B.match and B.match.recovering)
            .. " notices="
            .. table.concat(a.notices, "; ")
            .. " / "
            .. table.concat(b.notices, "; ")
    )
    check(
        A.match.info.id == B.match.info.id
            and A.match.info.white == B.match.info.white
            and A.match.info.black == B.match.info.black,
        "Match/color agreement differs"
    )
    return A, B
end
local function mover(a, b)
    local p = a.games.Chess.match
    local name = p.state.turn == 1 and p.info.white or p.info.black
    return a.name == name and a or b
end
local function move(a, b, uci)
    local expected = a.games.Chess.match.seq + 1
    local c = mover(a, b)
    check(c.games.Chess:Request(uci), "Legal move request rejected: " .. uci)
    for _ = 1, 24 do
        pump(0.5)
        if a.games.Chess.match.seq == expected and b.games.Chess.match.seq == expected then
            break
        end
    end
    local A, B = a.games.Chess, b.games.Chess
    check(
        A.match.seq == expected and B.match.seq == expected and A:Digest(A.match) == B:Digest(B.match),
        "Move diverged: " .. uci
    )
end
local a, b = group(5)
local A, B = a.games.Chess, b.games.Chess
pump(6)
check(#A:Eligible() == 4, "Five-player party did not expose four opponents")
check(
    a.games.Registry.chess.mode == "multiplayer"
        and a.games.Registry.chess.minPlayers == 2
        and a.games.Registry.chess.maxPlayers == 2,
    "Chess registration incorrect"
)
check(not a.games:StartSingleplayer("chess"), "Chess registered as solo")
a.channel = "INSTANCE_CHAT"
check(not a.games:CreateLobby("chess"), "Instance group accepted")
a.channel = "RAID"
check(not a.games:CreateLobby("chess"), "Raid group accepted")
a.channel = "PARTY"
A, B = match(a, b)
for i = 3, 5 do
    check(not clients[i].games.ActiveGame and not clients[i].games.Chess.match, "Spectator joined match")
    check(clients[i].games.Listings[a.name], "Spectator cannot see Chess lobby")
end
check(#a.games.Lobby.members == 2 and #b.games.Lobby.members == 2, "Party size leaked into chess participants")
check(not a.games:CreateLobby("chess"), "Second simultaneous lobby accepted")
local oldID = A.match.info.id
local nonMover = mover(a, b) == a and b or a
check(not nonMover.games.Chess:Request("e2e4"), "Wrong turn accepted locally")
local host = A.match.info.host == a.name and A or B
local other = host == A and B or A
local peerName = other == A and a.name or b.name
other.pending = { data = { token = "e2e4", seq = other.match.seq }, at = 0 }
other:ReceiveControl({
    op = "head",
    target = peerName,
    version = "1",
    id = other.match.info.id,
    seq = host.match.seq,
    digest = host:Digest(host.match),
    finished = false,
}, host.match.info.host)
check(other.pending ~= nil, "Heartbeat acknowledged an action that the host had not accepted")
other.pending = nil
local digest, seq = host:Digest(host.match), host.match.seq
for _, data in ipairs({
    {
        id = oldID,
        actor = host.match.info.host,
        expected = host.match.info.host,
        seq = seq,
        previous = digest,
        token = "e2e4",
    },
    {
        id = "stale",
        actor = other.match.info.white,
        expected = host.match.info.host,
        seq = seq,
        previous = digest,
        token = "e2e4",
    },
    {
        id = oldID,
        actor = clients[3].name,
        expected = host.match.info.host,
        seq = seq,
        previous = digest,
        token = "e2e4",
    },
}) do
    host:HostAction(data, clients[3].name)
end
check(host.match.seq == seq, "Forged/nonparticipant action changed board")
move(a, b, "e2e4")
move(a, b, "e7e5")
move(a, b, "g1f3")
local current = host.match
local bad = {
    id = oldID,
    actor = other == A and a.name or b.name,
    expected = current.info.host,
    seq = current.seq + 1,
    previous = host:Digest(current),
    token = "b8c6",
}
host:HostAction(bad, bad.actor)
check(host.match.seq == current.seq, "Wrong expected sequence applied")
bad.seq = current.seq
bad.previous = "00000000"
host:HostAction(bad, bad.actor)
check(host.match.seq == current.seq, "Bad previous digest applied")
bad.id = "previous-match"
bad.previous = host:Digest(current)
host:HostAction(bad, bad.actor)
check(host.match.seq == current.seq, "Stale match applied")
-- Replay an already accepted journal action as an old request.
bad.id = oldID
bad.seq = 0
bad.token = "e2e4"
host:HostAction(bad, bad.actor)
check(host.match.seq == current.seq, "Duplicate request applied twice")
local wrong = {
    id = oldID,
    actor = bad.actor,
    expected = other == A and a.name or b.name,
    seq = current.seq + 1,
    previous = "00000000",
    token = "b8c6",
    digest = "00000000",
}
other:Commit(wrong, host.match.info.host)
check(other.match.seq == current.seq, "Out-of-order commit changed board")
pump(4)
check(not other.match.recovering and other.match.seq == host.match.seq, "Checksum recovery failed")
-- Lose a committed move; heartbeat triggers bounded journal snapshot recovery.
local hostClient = host == A and a or b
local guestClient = host == A and b or a
local guest = guestClient.games.Chess
drop = function(packet, c)
    return c == guestClient and packet.sender == hostClient.name
end
local currentMover = mover(a, b)
if currentMover ~= hostClient then
    drop = nil
    move(a, b, "b8c6")
    drop = function(packet, c)
        return c == guestClient and packet.sender == hostClient.name
    end
end
check(host:Request(host.match.state.turn == 1 and "f1b5" or "b8c6"), "Host move for loss test failed")
pump(2)
check(host.match.seq > guest.match.seq, "Loss simulation failed")
drop = nil
pump(9)
check(
    host.match.seq == guest.match.seq
        and host:Digest(host.match) == guest:Digest(guest.match)
        and not guest.match.recovering,
    "Dropped move did not recover"
)
-- Closing/back/reopen must preserve the match and never resign.
local before = host.match.seq
hostClient.games.UI:ShowHome()
hostClient.games.UI.frame:Hide()
pump(1)
hostClient.games.UI:LaunchGame("chess")
check(host.running and host.match.seq == before and not host.match.ended, "Closing UI resigned or reset match")
-- Reload guest from SavedVariables, with the original client removed from delivery.
local save = guestClient.games.Copy(guestClient.games.DB)
local guestIndex = guestClient == a and 1 or 2
local reloaded = h.client(guestIndex == 1 and "Chess1" or "Chess2", guestIndex == 1 and "Realm1" or "Realm2", save)
reloaded.roster = guestClient.roster
clients[guestIndex] = reloaded
if guestIndex == 1 then
    a = reloaded
    A = a.games.Chess
else
    b = reloaded
    B = b.games.Chess
end
guestClient = reloaded
guest = reloaded.games.Chess
pump(8)
check(
    guest.running and not guest.match.recovering and guest.match.seq == host.match.seq,
    "Guest reload did not reconcile"
)
check(guest.match.state.san[1] == "e4", "Reload lost SAN history")
-- Temporary disconnect freezes input and reconnect resumes without a winner.
drop = function(packet, c)
    return c == guestClient or packet.sender == guestClient.name
end
hostClient.disconnected = { [guestClient.name] = true }
pump(25)
check(host.match.recovering and not host.match.ended, "Disconnect awarded victory")
drop = nil
hostClient.disconnected = nil
pump(8)
check(not host.match.recovering and not guest.match.recovering, "Reconnect failed")
-- Draw offer/decline/accept, including exactly-once persistent outcomes.
check(host:Request("offer"), "Draw offer failed")
pump(2)
check(guest.match.offer == hostClient.name, "Draw offer did not synchronize")
check(guest:Request("decline"), "Draw decline failed")
pump(2)
check(not host.match.offer and not guest.match.offer, "Draw decline did not synchronize")
check(guest:Request("offer"), "Return draw offer failed")
pump(2)
check(host:Request("accept"), "Draw acceptance failed")
pump(4)
check(
    #hostClient.games:GetResults("chess") == 1 and #guestClient.games:GetResults("chess") == 1,
    "Results not recorded on both clients"
)
check(host:Storage().stats.draws == 1 and guest:Storage().stats.draws == 1, "Draw statistics missing")
local result = hostClient.games:GetResults("chess")[1]
host:RecordStats(result)
hostClient.games:RecordResult(result)
check(host:Storage().stats.completed == 1, "Duplicate result counted twice")
hostClient.games.UI.resultGameID = "chess"
hostClient.games.UI:OpenLauncher("results")
check(hostClient.games.UI.bestScore.text == "0W / 0L / 1D", "Chess Results record missing")
-- A second match can end in resignation; previous-match traffic is ignored.
host, guest = match(hostClient, guestClient)
host:HostAction(
    { id = oldID, actor = guestClient.name, expected = hostClient.name, seq = 0, previous = digest, token = "resign" },
    guestClient.name
)
check(not host.match.ended, "Old match resigned a new match")
check(guest:Request("resign"), "Resignation failed")
pump(10)
check(host:Storage().stats.wins == 1 and guest:Storage().stats.losses == 1, "Resignation outcomes wrong")
-- Permanent loss becomes interrupted with no invented win or extra completed count.
host, guest = match(hostClient, guestClient)
local completed = host:Storage().stats.completed
drop = function(packet, c)
    return c == guestClient or packet.sender == guestClient.name
end
hostClient.disconnected = { [guestClient.name] = true }
pump(145)
drop = nil
hostClient.disconnected = nil
check(
    host.match.abandoned and host:Storage().stats.completed == completed,
    "Permanent disconnect invented a completion"
)
check(hostClient.games:GetResults("chess")[1].status == "aborted", "Interrupted result missing")
-- Engine endings and pre-move draw claims use the same authoritative pipeline.
host, guest = match(hostClient, guestClient)
for _, uci in ipairs({ "f2f3", "e7e5", "g2g4", "d8h4" }) do
    move(hostClient, guestClient, uci)
end
pump(3)
check(
    host.match.finished and guest.match.finished and host.match.state.san[4] == "Qh4#",
    "Checkmate failed to finalize on both clients"
)
check(hostClient.games:GetResults("chess")[1].summary == "Chess: checkmate", "Checkmate result missing")
for _, claimantRole in ipairs({ "host", "guest" }) do
    -- Seven moves leave Black to claim. Exercise both authority paths instead
    -- of letting random color assignment decide which one gets tested.
    local random = hostClient.env.math.random
    hostClient.env.math.random = function(...)
        if select("#", ...) == 1 and (...) == 2 then
            return claimantRole == "host" and 2 or 1
        end
        return random(...)
    end
    host, guest = match(hostClient, guestClient)
    hostClient.env.math.random = random
    for _, uci in ipairs({ "g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1" }) do
        move(hostClient, guestClient, uci)
    end
    local claimant = mover(hostClient, guestClient).games.Chess
    check(claimant == (claimantRole == "host" and host or guest), "Draw claimant color fixture incorrect")
    local hostCompleted, guestCompleted = host:Storage().stats.completed, guest:Storage().stats.completed
    check(claimant:Request("threefold:f6g8"), "Intended-move draw claim rejected")
    -- The real throttled PARTY queue may deliver the terminal commit after four
    -- seconds. Wait for completion, with the same bound as move synchronization.
    for _ = 1, 24 do
        pump(0.5)
        if host.match.finished and guest.match.finished then
            break
        end
    end
    check(host.match.finished and guest.match.finished, "Intended claim did not synchronize on both clients")
    check(
        #host.match.state.moves == 7
            and #guest.match.state.moves == 7
            and host.match.seq == 8
            and guest.match.seq == 8
            and host:Digest(host.match) == guest:Digest(guest.match),
        "Intended claim played the move or diverged between clients"
    )
    for _, client in ipairs({ hostClient, guestClient }) do
        local result = client.games:GetResults("chess")[1]
        check(
            result.summary == "Chess: threefold repetition" and result.status == "completed",
            "Claimed draw result missing"
        )
        for _, entry in ipairs(result.entries) do
            check(entry.outcome == "draw", "Intended claim awarded a winner")
        end
    end
    check(
        host:Storage().stats.completed == hostCompleted + 1 and guest:Storage().stats.completed == guestCompleted + 1,
        "Intended claim recorded more than one completion"
    )
end
for _, c in ipairs(clients) do
    check(#c.chatMessages == 0, "Chess emitted visible chat")
    for _, notice in ipairs(c.notices) do
        check(not notice:find(" / OnStart:", 1, true) and not notice:find(" / CreateUI:", 1, true), notice)
    end
end
print(string.format("PASS: %d Chess session, transport, recovery and integration assertions", checks))
