local old = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = old
local owner = h.client("ProtocolHost", "Realm")
local G, R = owner.games, owner.games.Blindshot.Rules
local checks = 0
local function check(v, why)
    assert(v, why)
    checks = checks + 1
end
local session = { id = "Player-1-long-identity:1800000000:555", run = 17, members = {} }
for i = 1, 5 do
    session.members[i] = { name = string.rep("Player", 7) .. i .. "-" .. string.rep("Realm", 7) }
end
local s = R.New(session, 1800000000)
R.BeginAim(s, 1800000001)
for _, p in ipairs(s.players) do
    s.drafts[p.name] = { x = 0, y = 0, dx = 1000, dy = 0, seq = 1 }
end
local serializer = owner.env.LibStub("AceSerializer-3.0")
local function roundTrip()
    local v = R.Public(s)
    local packed = R.Pack(v)
    local decoded = R.Unpack(packed, session)
    check(
        decoded
            and decoded.phase == s.phase
            and decoded.round == s.round
            and decoded.radius == s.radius
            and #decoded.players == 5,
        "Wire roundtrip failed"
    )
    for i, p in ipairs(decoded.players) do
        check(
            p.name == s.players[i].name
                and p.alive == s.players[i].alive
                and p.kills == s.players[i].kills
                and p.rounds == s.players[i].rounds,
            "Player metrics changed in codec"
        )
    end
    local body = serializer:Serialize(G.API_VERSION, "GAME_STATE", {
        id = session.id,
        run = session.run,
        gameID = "blindshot",
        gameVersion = G.Registry.blindshot.version,
        event = "blindshot_view",
        payload = packed,
    })
    check(#body < 1000, "Compact view too large with long names")
    for _, p in ipairs(s.players) do
        check(not body:find(p.name, 1, true), "State repeats roster names")
    end
    return packed, decoded
end
local packet = roundTrip()
check(packet.c == nil and not R.Unpack(packet, session).shots, "Wire AIM leaks positions")
for _, change in ipairs({
    { "p", 0 },
    { "r", 100 },
    { "i", "wrong" },
    { "v", -1 },
    { "s", "" },
    { "s", "1,,2,0,0" },
    { "s", "|||||" },
    { "s", "1,1,0,0,0|" },
    { "s", "1,1,0,0,0|1,1,0,0,0|1,1,0,0,0|1,1,0,0,0|1,1,0,0,0|1,1,0,0,0" },
    { "h", "1,99" },
    { "h", "1,1" },
    { "h", "1,-1" },
    { "h", "nil,2" },
    { "w", 999 },
    { "t", 0 / 0 },
    { "c", "1,0,0,1000,0,0" },
}) do
    local bad = G.Copy(packet)
    bad[change[1]] = change[2]
    local ok, v = pcall(R.Unpack, bad, session)
    check(ok and not v, "Malformed packet accepted or crashed: " .. change[1])
end
R.Reveal(s, 1800000002)
roundTrip()
R.Resolve(s, 1800000003)
local _, decoded = roundTrip()
check(#decoded.events == #s.events, "Hit log lost in codec")
R.EndRound(s, 1800000004)
roundTrip()
R.Next(s, 1800000006)
roundTrip()
if s.phase == "PREPARE" then
    check(not R.Public(s).shots, "Previous volley leaked into next round")
end
-- Radius derives from the host's roster at round start, including casualties
-- of that round. Resolve must never change camera scale mid-volley.
s = R.New(session, 1800000010)
s.round, s.radius = 2, R.Radius(2, 5)
s.players[1].alive, s.players[1].deathRound = false, 2
s.players[2].alive, s.players[2].deathRound = false, 2
s.players[3].alive, s.players[3].deathRound = false, 2
local _, afterKills = roundTrip()
check(afterKills.radius == 820 and R.StartCount(afterKills) == 5, "Casualties shrank current round on decode")
R.Next(s, 1800000011)
local _, duel = roundTrip()
check(duel.radius == R.Radius(3, 2) and R.StartCount(duel) == 2, "Next duel radius not synchronized")
s.radius = 820
check(not R.ValidView(R.Public(s), session), "Incorrect survivor-dependent radius accepted")
local badSaves = { true, 22, "bad", { session = {} }, { session = { gameID = "blindshot" }, state = true } }
for _, bad in ipairs(badSaves) do
    local c = h.client("BrokenSave", "Realm", { blindshot = { active = bad } })
    check(not c.games.ActiveGame and not c.games.Blindshot:Storage().active, "Malformed recovery crashed or launched")
end
print(
    string.format(
        "PASS: %d Blindshot compact protocol, privacy, payload bounds and malformed recovery assertions",
        checks
    )
)
