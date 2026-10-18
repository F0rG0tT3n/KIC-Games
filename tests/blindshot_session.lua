local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks, clients, drop = 0, {}, nil
local function check(v, why)
    assert(v, why)
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
            for _, f in ipairs(c.frames) do
                if f.shown and f.scripts.OnUpdate then
                    f.scripts.OnUpdate(f, 0.1)
                end
            end
        end
        local count = #h.packets
        for _ = 1, count do
            local p = table.remove(h.packets, 1)
            check(p.channel == "PARTY" and #p.body <= 255, "Non-party or oversized traffic")
            for _, c in ipairs(clients) do
                if not drop or not drop(p, c) then
                    c:event("CHAT_MSG_ADDON", p.prefix, p.body, p.channel, p.sender)
                end
            end
        end
    end
end
local function waitFor(predicate, why, seconds)
    for _ = 1, (seconds or 20) * 10 do
        if predicate() then
            check(true, why)
            return
        end
        pump(0.1)
    end
    for _, c in ipairs(clients) do
        print(
            "STATE",
            c.name,
            c.games.Lobby and c.games.Lobby.status,
            c.games.Blindshot.running,
            c.games.Blindshot.view and c.games.Blindshot.view.phase,
            c.games.Blindshot.view and c.games.Blindshot.view.round,
            c.env.GetServerTime()
        )
        for _, notice in ipairs(c.notices) do
            print(notice)
        end
    end
    error(why)
end
local serial = 0
local function setup(n)
    serial = serial + 1
    clients = {}
    for i = 1, n do
        clients[i] = h.client("Blind" .. serial .. "Player" .. i, "Realm")
    end
    for _, c in ipairs(clients) do
        for _, other in ipairs(clients) do
            if c ~= other then
                c.roster[#c.roster + 1] = other.name
            end
        end
    end
    local a = clients[1]
    check(not a.games:StartSingleplayer("blindshot"), "Blindshot exposed singleplayer")
    a.channel = "RAID"
    check(not a.games:CreateLobby("blindshot"), "Raid hosting accepted")
    a.channel = "INSTANCE_CHAT"
    check(not a.games:CreateLobby("blindshot"), "Instance hosting accepted")
    a.channel = "PARTY"
    check(a.games.UI:LaunchGame("blindshot"), "Launcher did not open multiplayer")
    for _, card in ipairs(a.games.UI.launcherCards) do
        if card:IsShown() and card.game.id == "blindshot" then
            card.play.scripts.OnClick()
            break
        end
    end
    check(a.games.Lobby and a.games.Lobby.gameID == "blindshot", "Host UI failed")
    check(
        a.games.UI.lobbyPanel:IsVisible() and not a.games.UI.cardScroll:IsVisible() and a.games.UI.lobbySlotCount == 5,
        "Blindshot host did not enter dedicated five-slot lobby"
    )
    waitFor(function()
        for i = 2, n do
            if not clients[i].games.Listings[a.name] then
                return false
            end
        end
        return true
    end, "Lobby not discovered")
    for i = 2, n do
        check(clients[i].games:JoinLobby(a.name, a.games.Lobby.id), "Join failed")
        local wanted = i
        waitFor(function()
            return #a.games.Lobby.members == wanted and clients[wanted].games.Lobby
        end, "Join not acknowledged")
        check(
            clients[i].games.UI.lobbyPanel:IsShown() and not clients[i].games.UI.browserPanel:IsShown(),
            "Blindshot guest still sees game browser"
        )
    end
    for _, c in ipairs(clients) do
        check(c.games:Ready(true), "Ready failed")
    end
    waitFor(function()
        for _, c in ipairs(clients) do
            local B = c.games.Blindshot
            if not B.running or not B.view or B.view.phase ~= "AIM" then
                return false
            end
        end
        return true
    end, "All boards did not reach AIM", 45)
    for _, c in ipairs(clients) do
        check(c.games.Blindshot.root:IsVisible(), "Game UI did not open")
        check(c.games.Blindshot:CanInput(), "Living player cannot aim")
        check(not c.games.Blindshot.view.shots and not c.games.Blindshot.view.drafts, "Hidden state leaked")
    end
    return clients[1], clients[2]
end
local function aim(c, x, y, dx, dy, lock)
    local B = c.games.Blindshot
    B.draft = { x = x, y = y, dx = dx, dy = dy }
    return B:SendDraft(lock)
end
local a, b = setup(2)
local A, B = a.games.Blindshot, b.games.Blindshot
a.env.math.random = function(low, high)
    return high
end
local publications = 0
local sendState = a.games.SendGameState
function a.games:SendGameState(event, data, target)
    if event == "blindshot_view" then
        publications = publications + 1
        check(not data.drafts, "Host published private drafts")
        if data.p == 1 or data.p == 2 then
            check(not data.c, "Early position reveal")
        end
    end
    return sendState(self, event, data, target)
end
check(not aim(b, 400, 0, 0, 1000, false), "Unlocked draft was transmitted")
pump(1)
check(not A.authority.drafts[b.name], "Host received an unlocked choice")
check(not B.authority and not b.games.DB.blindshot.active.state, "Guest acquired host-only authority")
check(not A.view.shots and not A.view.players[2].x, "Host UI leaked enemy location")
A:HostAction({ id = "wrong", round = 1, seq = 100, x = 0, y = 0, dx = 1000, dy = 0, lock = true }, b.name)
A:HostAction({ id = A.authority.id, round = 0, seq = 100, x = 0, y = 0, dx = 1000, dy = 0, lock = true }, b.name)
A:HostAction({ id = A.authority.id, round = 1, seq = 100, x = 999, y = 999, dx = 1000, dy = 0, lock = true }, b.name)
A:HostAction({ id = A.authority.id, round = 1, seq = 100, x = 0, y = 0, dx = 1000, dy = 0, lock = false }, b.name)
check(not A.authority.drafts[b.name] and not A.authority.players[2].locked, "Invalid action changed lock")
a.games.UI:OpenLauncher("home")
a.games.UI.frame:Hide()
check(A.running and A.authority.phase == "AIM", "Closing UI ended match")
a.games.UI:LaunchGame("blindshot")
check(A.root:IsVisible() and A.running, "Resume did not reopen board")
check(aim(a, -400, 0, 1000, 0, true), "Host lock failed")
check(A.authority.phase == "AIM" and A.Rules.Alive(A.authority) == 2, "Host fired before everybody locked")
check(aim(b, 400, 0, 0, 1000, true), "Guest lock failed")
waitFor(function()
    return A.authority.phase == "REVEAL" or A.authority.phase == "FIRING"
end, "Locks did not reveal")
local frozen = a.games.Copy(A.authority.drafts[b.name])
A:HostAction({ id = A.authority.id, round = 1, seq = 999, x = 0, y = 100, dx = -1000, dy = 0, lock = true }, b.name)
check(A.authority.drafts[b.name].x == frozen.x, "Locked position changed")
waitFor(function()
    return not a.games.ActiveGame and not b.games.ActiveGame
end, "Winner did not finalize", 30)
check(A:Storage().stats.wins == 1 and B:Storage().stats.losses == 1, "Wrong winner")
check(A:Storage().stats.rounds == 1 and A:Storage().stats.eliminations == 1, "Missing metrics")
check(A.resultWindow:IsVisible() and B.resultWindow:IsVisible(), "Result dialogs missing")
check(a.games.Lobby.status == "waiting" and b.games.Lobby.status == "waiting", "Match destroyed reusable lobby")
local result = a.games:GetResults("blindshot")[1]
check(result.entries[1].stats and result.id == A.session.id .. ":1", "Result metrics not persisted")
a.games:RecordResult(result)
A:RecordStats(result)
check(A:Storage().stats.completed == 1, "Duplicate result counted")
a.games.UI.resultGameID = "blindshot"
a.games.UI:OpenLauncher("results")
check(
    a.games.UI.bestPanel.label.text == "BLINDSHOT RECORD"
        and a.games.UI.bestMetadata.text:find("Eliminations: 1", 1, true),
    "Results UI missing metrics"
)
check(publications > 0 and not A:Storage().active and not B:Storage().active, "Completed state retained recovery")
local previousMatch = A.view.id
check(a.games:Ready(true) and b.games:Ready(true), "Rematch Ready failed")
waitFor(function()
    return A.running
        and B.running
        and A.view
        and B.view
        and A.view.id ~= previousMatch
        and A.view.phase == "AIM"
        and B.view.phase == "AIM"
end, "Blindshot rematch did not start", 30)
check(A.session.run == 2 and B.session.run == 2 and A.authority.round == 1, "Rematch retained round state")
A:HostAction({ id = previousMatch, round = 1, seq = 999, x = 0, y = 0, dx = 1000, dy = 0, lock = true }, b.name)
check(not A.authority.players[2].locked, "Previous-match action locked rematch")
check(aim(a, -400, 0, 1000, 0, true) and aim(b, 400, 0, -1000, 0, true), "Rematch actions failed")
waitFor(function()
    return B:Storage().stats.completed == 2
end, "Rematch result missing", 30)
check(A:Storage().stats.wins == 2 and A:Storage().stats.draws == 0, "Rematch corrupted lifetime results")
b.games:LeaveLobby()
waitFor(function()
    return #a.games.Lobby.members == 1
end, "Leaving waiting Blindshot lobby did not update roster")
check(a.games.Lobby.status == "waiting" and not a.games.ActiveGame, "Lobby Leave started or destroyed the host lobby")
a.games:LeaveLobby()

-- Five players in one line: each shot stops at the first living opponent.
-- The same fixture ends over three shrinking rounds, with no multi-hit credit.
a, b = setup(5)
A, B = a.games.Blindshot, b.games.Blindshot
local automaticSnapshots = 0
local originalState = a.games.SendGameState
function a.games:SendGameState(event, data, target)
    if event == "blindshot_view" and not target and (data.p == 4 or data.p == 5) then
        automaticSnapshots = automaticSnapshots + 1
    end
    return originalState(self, event, data, target)
end
a.env.math.random = function(low, high)
    return high
end
for round = 1, 3 do
    waitFor(function()
        for _, c in ipairs(clients) do
            local v = c.games.Blindshot.view
            if not v or v.round ~= round or v.phase ~= "AIM" then
                return false
            end
        end
        return true
    end, "Five-player round " .. round .. " did not synchronize", 30)
    for i, c in ipairs(clients) do
        if A.authority.players[i].alive then
            local step = math.min(180, math.floor((A.authority.radius - A.Rules.HIT) / 2))
            check(aim(c, (i - 3) * step, 0, 1000, 0, true), "Five-player lock failed")
        end
    end
end
waitFor(function()
    return not a.games.ActiveGame
end, "Five-player result did not finalize", 40)
waitFor(function()
    for _, c in ipairs(clients) do
        if c.games.Blindshot:Storage().stats.completed ~= 1 then
            return false
        end
    end
    return true
end, "Five-player results did not reach everybody", 30)
check(A:Storage().stats.wins == 1 and A:Storage().stats.eliminations == 3, "Single-target score wrong")
check(clients[2].games.Blindshot:Storage().stats.eliminations == 0, "Eliminated shooter fired")
check(clients[3].games.Blindshot:Storage().stats.eliminations == 1, "Later living shooter did not fire")
check(automaticSnapshots == 0, "Automatic firing/end phases retransmitted the complete plan")

-- Facing duel: the first shooter wins; the eliminated opponent never fires.
a, b = setup(2)
A, B = a.games.Blindshot, b.games.Blindshot
a.env.math.random = function(low, high)
    return high
end
check(aim(a, -400, 0, 1000, 0, true) and aim(b, 400, 0, -1000, 0, true), "Mutual lock failed")
waitFor(function()
    return B:Storage().stats.completed == 1
end, "Mutual kill did not finish", 30)
check(A:Storage().stats.wins == 1 and B:Storage().stats.losses == 1, "Sequential duel did not select first shooter")

-- A lost lock action is retried with the same sequence and applied once.
a, b = setup(2)
A, B = a.games.Blindshot, b.games.Blindshot
a.env.math.random = function(low, high)
    return high
end
drop = function(packet)
    return packet.sender == b.name
end
check(aim(b, 400, 0, 0, 1000, true), "Dropped lock submission failed")
pump(2)
check(B.pending and not A.authority.players[2].locked, "Dropped action unexpectedly committed")
drop = nil
waitFor(function()
    return A.authority.players[2].locked
end, "Lock retry did not reach host")
local once = A.authority.drafts[b.name].seq
pump(1)
check(A.authority.drafts[b.name].seq == once, "Lock retry applied a new sequence")
check(aim(a, -400, 0, 1000, 0, true), "Host cannot finish retry fixture")
waitFor(function()
    return B:Storage().stats.completed == 1
end, "Retried lock match did not finish", 30)
check(A:Storage().stats.wins == 1, "Retry changed outcome")

-- Timer expiry uses host fallbacks for players who never locked; local edits
-- are deliberately unknown to the host.
a, b = setup(2)
A, B = a.games.Blindshot, b.games.Blindshot
a.env.math.random = function(low, high)
    return high
end
check(aim(a, -400, 300, 0, 1000, true), "Timeout fixture lock failed")
check(not aim(b, 400, 0, 1000, 0, false), "Timeout fixture transmitted an unlocked draft")
waitFor(function()
    return A.authority.round == 2
end, "Missed volley did not advance/shrink", 30)
check(
    A.authority.radius == A.Rules.Radius(2, 2) and A.authority.players[1].alive and A.authority.players[2].alive,
    "Shrink killed a survivor"
)
waitFor(function()
    return B.view and B.view.round == 2 and B.view.phase == "AIM"
end, "Second AIM not synchronized")
check(not B.view.shots and not A.view.shots, "Previous volley visible during new AIM")
check(A.authority.players[1].rounds == 2, "Round counter did not advance")

-- Guest and host reload preserve hidden actions without exposing them.
local guestSave = b.games.Copy(b.games.DB)
local newGuest = h.client(b.name:match("^(.-)%-"), "Realm", guestSave)
newGuest.roster = b.roster
clients[2], b, B = newGuest, newGuest, newGuest.games.Blindshot
waitFor(function()
    return B.running and B.view and not B.waiting
end, "Guest reload failed")
check(not B.authority and not B.view.shots, "Guest reload leaked hidden choices")
check(aim(b, 200, 150, 0, 1000, true), "Recovered guest cannot lock")
waitFor(function()
    return A.authority.players[2].locked
end, "Recovered lock not received")
local hostSave = a.games.Copy(a.games.DB)
local newHost = h.client(a.name:match("^(.-)%-"), "Realm", hostSave)
newHost.roster = a.roster
clients[1], a, A = newHost, newHost, newHost.games.Blindshot
waitFor(function()
    return A.running and A.authority and A.authority.players[2].locked
end, "Host reload lost lock")
check(A.authority.drafts[b.name].x == 200 and A.authority.round == 2, "Host recovery lost secret action")
check(
    (A.view.phase ~= "AIM" or not A.view.shots) and (B.view.phase ~= "AIM" or not B.view.shots),
    "Host reload published secrets"
)
if A:CanInput() then
    check(aim(a, -300, -200, -1000, 0, true), "Recovered host cannot lock")
else
    check(A.authority.phase ~= "AIM", "Recovered host cannot input during AIM")
end
waitFor(function()
    return A.authority.round == 3 or not A.running
end, "Recovered host did not advance", 30)

-- Leaving a live match follows the shared clean-interruption policy.
if a.games.ActiveGame then
    b.games:LeaveLobby()
    waitFor(function()
        return not a.games.ActiveGame
    end, "Guest Leave did not end live match")
    check(A:Storage().stats.completed == 0, "Departure awarded a winner")
end
a, b = setup(2)
A, B = a.games.Blindshot, b.games.Blindshot
a.env.math.random = function(low, high)
    return high
end
a.games:LeaveLobby()
waitFor(function()
    return not b.games.Lobby and not B.running
end, "Host Close did not end match")
check(B:Storage().stats.completed == 0 and not B:Storage().active, "Host Close left a saved winner/match")
for _, c in ipairs(clients) do
    check(#c.chatMessages == 0, "Visible chat emitted")
    for _, notice in ipairs(c.notices) do
        check(
            not notice:find(" / OnStart:", 1, true)
                and not notice:find(" / CreateUI:", 1, true)
                and not notice:find(" / timer:", 1, true),
            notice
        )
    end
end
for _, count in ipairs({ 3, 4 }) do
    local first = setup(count)
    for i, client in ipairs(clients) do
        local rules = client.games.Blindshot.Rules
        local draft = rules.Default(i, count, 1000)
        local dx, dy = rules.Direction(draft.x, draft.y)
        check(aim(client, draft.x, draft.y, dx, dy, true), "Middle-size party could not lock")
    end
    waitFor(function()
        for _, client in ipairs(clients) do
            local view = client.games.Blindshot.view
            if not view or view.round ~= 2 or view.phase ~= "AIM" then
                return false
            end
        end
        return true
    end, "Middle-size party did not synchronize the next shrinking round", 30)
    check(
        first.games.Blindshot.Rules.Alive(first.games.Blindshot.authority) == count,
        "Outward shots incorrectly hit in middle-size party"
    )
    first.games:LeaveLobby()
    pump(3)
end
print(
    string.format(
        "PASS: %d Blindshot 2-5 player lobby, hidden input, timeout, result, reload and leave assertions",
        checks
    )
)
