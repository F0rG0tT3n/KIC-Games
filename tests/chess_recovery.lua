local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local clients, checks = {}, 0
local function check(v, message)
    assert(v, message)
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
            c.games.Chess:Tick()
        end
        local count = #h.packets
        for _ = 1, count do
            local p = table.remove(h.packets, 1)
            check(p.channel == "PARTY" and #p.body <= 255, "Invalid transport")
            for _, c in ipairs(clients) do
                c:event("CHAT_MSG_ADDON", p.prefix, p.body, p.channel, p.sender)
            end
        end
    end
end
local function setup()
    local a, b = h.client("RecoveryHost", "Realm"), h.client("RecoveryGuest", "Realm")
    a.roster = { b.name }
    b.roster = { a.name }
    clients = { a, b }
    pump(6)
    check(a.games:CreateLobby("chess"), "Host failed")
    pump(2)
    check(b.games:JoinLobby(a.name, a.games.Lobby.id), "Join failed")
    pump(2)
    check(a.games:Ready(true) and b.games:Ready(true), "Ready failed")
    pump(6)
    check(a.games.Chess.running and b.games.Chess.running, "Start failed")
    return a, b
end
local a, b = setup()
local oldSave = a.games.Copy(a.games.DB)
for _, uci in ipairs({ "e2e4", "e7e5", "g1f3" }) do
    local m = a.games.Chess.match
    local actor = m.state.turn == 1 and m.info.white or m.info.black
    check((actor == a.name and a or b).games.Chess:Request(uci), "Move failed")
    pump(2)
end
local saved = a.games.Copy(a.games.DB)
local reload = h.client("RecoveryHost", "Realm", saved)
reload.roster = { b.name }
clients = { reload, b }
a = reload
pump(10)
local A, B = a.games.Chess, b.games.Chess
check(
    A.match.seq == 3 and B.match.seq == 3 and not A.match.recovering and not B.match.recovering,
    "Authoritative host reload did not reconcile"
)
check(A:Digest(A.match) == B:Digest(B.match) and A.match.state.san[3] == "Nf3", "Host reload changed state/history")
local savedA, savedB = a.games.Copy(a.games.DB), b.games.Copy(b.games.DB)
a = h.client("RecoveryHost", "Realm", savedA)
b = h.client("RecoveryGuest", "Realm", savedB)
a.roster = { b.name }
b.roster = { a.name }
clients = { a, b }
A = a.games.Chess
B = b.games.Chess
pump(10)
check(
    A.match.seq == 3 and B.match.seq == 3 and not A.match.recovering and not B.match.recovering,
    "Simultaneous reload did not reconcile"
)
local newerDigest = B:Digest(B.match)
-- Simulate restoring an older host backup. The guest must refuse rollback.
reload = h.client("RecoveryHost", "Realm", a.games.Copy(oldSave))
reload.roster = { b.name }
clients = { reload, b }
a = reload
A = a.games.Chess
pump(10)
check(
    A.match.seq == 0 and A.match.recovering and B.match.seq == 3 and B:Digest(B.match) == newerDigest,
    "Old host backup overwrote newer state"
)
pump(125)
check(
    A.match.abandoned and B.match.abandoned and A:Storage().stats.completed == 0 and B:Storage().stats.completed == 0,
    "Unreconcilable state invented a winner"
)

a, b = setup()
A, B = a.games.Chess, b.games.Chess
local E = A.Engine
local long
for seed = 1, 40 do
    local m = A:NewMatch(A.match.info)
    m.recovering = false
    local random = seed
    for _ = 1, 150 do
        if m.ended then
            break
        end
        random = (random * 48271) % 2147483647
        local moves = E.LegalMoves(m.state)
        local move = moves[random % #moves + 1]
        local actor = m.state.turn == 1 and m.info.white or m.info.black
        m = assert(A:Transition(m, actor, E.UCI(move)))
    end
    if m.seq == 150 and not m.ended then
        long = m
        break
    end
end
check(long ~= nil, "No long legal recovery fixture")
A.match = long
A:Save()
local chunks, maxChunk = 0, 0
local control = A.Control
function A:Control(op, target, fields)
    if op == "chunk" then
        chunks = chunks + 1
        local count = 0
        for _ in fields.log:gmatch("%S+") do
            count = count + 1
        end
        maxChunk = math.max(maxChunk, count)
    end
    return control(self, op, target, fields)
end
B:Recover()
pump(35)
check(chunks >= 3 and maxChunk <= 64, "Snapshot recovery was not bounded/chunked")
check(
    B.match.seq == 150 and B:Digest(B.match) == A:Digest(A.match) and not B.match.recovering,
    "Multi-chunk recovery did not reproduce authoritative history"
)
check(#B.match.state.san == 150 and #B.match.state.moves == 150, "Recovery lost move history")

-- Completed game recovery remains safe if the host crashes before finalizing.
B:Abandon("local_timeout", true)
check(b.games:GetResults("chess")[1].provisional and not b.games.Lobby, "Provisional interruption fixture failed")
local n = assert(A:Transition(A.match, b.name, "resign"))
A.match = n
A:Save()
saved = a.games.Copy(a.games.DB)
reload = h.client("RecoveryHost", "Realm", saved)
reload.roster = { b.name }
clients = { reload, b }
a = reload
A = a.games.Chess
pump(30)
check(A.match.finished and B.match.finished, "Terminal journal did not finalize after host reload")
check(
    A:Storage().stats.completed == 1 and B:Storage().stats.completed == 1,
    "Recovered terminal result duplicated or lost"
)
local result = a.games:GetResults("chess")[1]
check(result and result.status == "completed" and #b.games:GetResults("chess") == 1, "Recovered result missing")
check(A:Storage().stats.wins == 1 and B:Storage().stats.losses == 1, "Recovered resignation outcome wrong")

-- Malformed control messages are ignored without throwing or changing identity.
for _, data in ipairs({
    { op = "start" },
    { op = "chunk", id = A.match.info.id, cursor = {}, total = 10, log = {} },
    { op = "invite", info = { id = "bad" } },
    { op = "head", id = A.match.info.id, seq = "wrong", digest = {} },
}) do
    data.version = "1"
    data.target = a.name
    check(
        pcall(function()
            A:ReceiveControl(data, b.name)
        end),
        "Malformed control crashed receiver"
    )
end

local bad = a.games.Copy(oldSave)
bad.chess.active.journal = "w:e2e9"
local corrupt = h.client("RecoveryHost", "Realm", bad).games
check(
    corrupt.Chess:Storage().active == nil and corrupt:GetResults("chess")[1].status == "aborted",
    "Invalid recoverable state was not recorded as interrupted"
)
check(corrupt.Chess:Storage().stats.completed == 0, "Invalid recovery invented a completion")
print(
    string.format(
        "PASS: %d Chess host reload, rollback refusal, bounded snapshots and final recovery assertions",
        checks
    )
)
