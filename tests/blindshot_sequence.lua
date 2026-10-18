-- Authoritative event playback, duplicate/delayed snapshots and mid-fire reload.
local old = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = old
local host, guest = h.client("SequenceHost", "Realm"), h.client("SequenceGuest", "Realm")
local G, B = host.games, host.games.Blindshot
local C, R = guest.games.Blindshot, B.Rules
local checks = 0
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local names = { host.name, guest.name, "Third-Realm", "Fourth-Realm", "Fifth-Realm" }
local session = {
    id = "sequence-test",
    run = 1,
    revision = 1,
    epoch = 0,
    countdownToken = 0,
    host = host.name,
    channel = "PARTY",
    mode = "multiplayer",
    status = "running",
    gameID = "blindshot",
    gameVersion = G.Registry.blindshot.version,
    startedAt = host.env.GetServerTime(),
    members = {},
}
for _, name in ipairs(names) do
    session.members[#session.members + 1] = { name = name, ready = true, version = G.Registry.blindshot.version }
end
for _, client in ipairs({ host, guest }) do
    for _, name in ipairs(names) do
        if name ~= client.name then
            client.roster[#client.roster + 1] = name
        end
    end
    client.games.Lobby = G.Copy(session)
    client.games.Blindshot:CreateUI(client.games.UI:GetGameContainer())
    client.games.Blindshot:Start({
        isHost = client == host,
        NewTicker = function() end,
        SendState = function()
            return true
        end,
        SendAction = function()
            return true
        end,
        FinishGame = function()
            error("Fixture should retain three survivors")
        end,
    }, session, false)
end
local now = B:Now()
R.BeginAim(B.authority, now)
local choices =
    { { -500, 0, 1000, 0 }, { -300, 400, 1000, 0 }, { 0, 0, 0, 1000 }, { 400, 400, 0, -1000 }, { 0, -500, 0, -1000 } }
for i, p in ipairs(B.authority.players) do
    local a = choices[i]
    B.authority.drafts[p.name] = { x = a[1], y = a[2], dx = a[3], dy = a[4], seq = 1, lock = true }
    p.locked = true
end
R.Reveal(B.authority, now, function(low, high)
    return high
end)
B:Publish()
local reveal = R.Pack(B.view)
C:Receive("blindshot_view", reveal, host.name)
check(
    C.view.sequenceID == B.view.sequenceID and R.Pack(C.view).o == reveal.o and R.Pack(C.view).q == reveal.q,
    "Host/client order or event plan differs"
)
check(#B.view.order == 5 and #B.view.sequence == 3 and B.view.sequence[3].shooter == 5, "Dead turns were not skipped")
for i, event in ipairs(C.view.sequence) do
    check(
        event.id == B.view.sequence[i].id and event.id == C.view.sequenceID .. ":" .. i,
        "Event identity changed between clients"
    )
end
local revision = C.view.rev
C:Receive("blindshot_view", reveal, guest.name)
check(C.view.rev == revision, "Non-host changed sequence")
local start = R.Presentation(C.view, C.view.fireAt - 0.01)
check(
    start.phase == "REVEAL" and R.Alive(start) == 5 and #start.events == 0,
    "Reveal disclosed animation results early"
)
local firing = R.Presentation(C.view, C.view.fireAt + 0.3)
check(
    firing.phase == "FIRING" and firing.current == 1 and not firing.players[3].alive and firing.players[4].alive,
    "Reveal plan did not start locally or applied future kills"
)
local second = R.Presentation(C.view, C.view.fireAt + 1.1)
check(
    second.current == 2 and not second.players[4].alive and second.players[2].alive,
    "Second shooter timing incorrect"
)
local third = R.Presentation(C.view, C.view.fireAt + 1.65)
check(third.current == 5 and third.players[5].alive, "Skipped dead turns consumed time")
local ended = R.Presentation(C.view, C.view.fireAt + #C.view.sequence * R.SHOT_TIME + 0.1)
check(ended.phase == "ROUND_END" and R.Alive(ended) == 3, "Client did not derive round completion from reveal plan")
for _, change in ipairs({
    function(v)
        v.order[2] = v.order[1]
    end,
    function(v)
        v.sequence[2].shooter = 3
    end,
    function(v)
        v.sequence[1].targets = { 4 }
    end,
    function(v)
        v.sequence[1].targets = { 3, 3 }
    end,
    function(v)
        v.sequenceID = "previous-round"
    end,
    function(v)
        v.fireAt = math.huge
    end,
}) do
    local bad = G.Copy(B.view)
    change(bad)
    local ok, valid = pcall(R.ValidView, bad, session)
    check(ok and not valid, "Corrupt authoritative plan accepted or crashed")
end
for _, change in ipairs({ { "o", "1|1|3|4|5" }, { "q", "1,32" }, { "q", "1,3|2,8|5,0" }, { "f", -1 }, { "a", 0 / 0 } }) do
    local bad = G.Copy(reveal)
    bad[change[1]] = change[2]
    local ok, view = pcall(R.Unpack, bad, session)
    check(ok and not view, "Malformed wire sequence accepted or crashed")
end
h.advance(1.1)
B:Tick()
check(B.authority.phase == "FIRING" and R.Alive(B.authority) == 3, "Authority did not commit plan")
check(B.authority.deadline == B.authority.fireAt + 3 * R.SHOT_TIME, "Firing duration includes skipped turns")
local fire = R.Pack(B.view)
B:Publish(guest.name)
fire = R.Pack(B.view)
C:Receive("blindshot_view", fire, host.name)
local received = C.receivedAt
h.advance(0.35)
local clock = C:Now()
C:Receive("blindshot_view", reveal, host.name)
C:Receive("blindshot_view", fire, host.name)
check(C.receivedAt == received and C:Now() >= clock, "Duplicate or out-of-order packet restarted playback")
local delayed = G.Copy(fire)
delayed.v = delayed.v + 1
delayed.a = math.floor(B.authority.fireAt * 1000)
C:Receive("blindshot_view", delayed, host.name)
check(C:Now() >= clock, "Delayed newer checkpoint rewound playback")
local kills = B.authority.players[1].kills + B.authority.players[2].kills
check(not R.Resolve(B.authority, B:Now()) and kills == 2, "Reexecuted committed sequence")
C:Save()
local guestClock = C:Now()
local resumedGuest = h.client("SequenceGuest", "Realm", guest.games.Copy(guest.games.DB))
resumedGuest.roster = guest.roster
check(
    resumedGuest.games.Blindshot.running and not resumedGuest.games.Blindshot.authority,
    "Mid-fire guest reload lost session or acquired authority"
)
check(
    resumedGuest.games.Blindshot.view.sequenceID == C.view.sequenceID
        and resumedGuest.games.Blindshot:Now() >= guestClock,
    "Guest reload restarted animation clock"
)
B:Save()
local saved = G.Copy(G.DB)
local reloaded = h.client("SequenceHost", "Realm", saved)
reloaded.roster = host.roster
local recovered = reloaded.games.Blindshot
check(recovered.running and recovered.authority.phase == "FIRING", "Mid-fire host reload failed")
check(
    recovered.authority.sequenceID == B.authority.sequenceID
        and R.Pack(recovered.view).o == fire.o
        and R.Pack(recovered.view).q == fire.q,
    "Reload regenerated order or event IDs"
)
h.advance(3)
recovered:Tick()
check(
    recovered.authority.phase == "ROUND_END"
        and recovered.authority.players[1].kills == 1
        and recovered.authority.players[2].kills == 1,
    "Reload replayed kills"
)
h.advance(2.1)
recovered:Tick()
check(
    recovered.authority.round == 2 and recovered.authority.radius == R.Radius(2, 3) and not recovered.view.sequence,
    "Sequence completion did not shrink/clear old plan"
)
local nextView = R.Pack(recovered.view)
recovered:Publish(guest.name)
nextView = R.Pack(recovered.view)
C:Receive("blindshot_view", nextView, host.name)
local nextRevision = C.view.rev
C:Receive("blindshot_view", fire, host.name)
check(C.view.round == 2 and C.view.rev == nextRevision and not C.view.shots, "Previous round's sequence resurfaced")
-- New rounds wait for matching public-board acknowledgements. Old generic sync
-- requests cannot skip that gate, and public replies coalesce across peers.
recovered:RoundReady({ id = recovered.authority.id, round = 1 }, guest.name)
recovered:SyncRequested(guest.name)
check(not recovered.readyPeers[guest.name], "Stale acknowledgement or sync unlocked a new round")
recovered:RoundReady({ id = recovered.authority.id, round = 2 }, "Outsider-Realm")
check(not recovered.readyPeers["Outsider-Realm"], "Outsider acknowledged a round")
h.advance(1.1)
recovered:Tick()
check(recovered.authority.phase == "PREPARE", "New planning timer started before boards were ready")
for _, p in ipairs(recovered.authority.players) do
    if p.alive then
        recovered:RoundReady({ id = recovered.authority.id, round = 2 }, p.name)
    end
end
h.advance(1.1)
recovered:Tick()
check(recovered.authority.phase == "AIM", "Ready survivors did not enter planning")
local send, publications = recovered.context.SendState, 0
recovered.context.SendState = function(_, event)
    if event == "blindshot_view" then
        publications = publications + 1
    end
    return true
end
h.advance(3.1)
recovered:SyncRequested(guest.name)
recovered:SyncRequested(names[5])
check(publications == 1, "Simultaneous sync requests queued duplicate public snapshots")
publications = 0
local a = R.Default(1, 5, recovered.authority.radius)
recovered:HostAction(
    { id = recovered.authority.id, round = 2, seq = 1, x = a.x, y = a.y, dx = a.dx, dy = a.dy, lock = true },
    host.name
)
recovered:Tick()
check(publications == 0, "Partial lock roster published before its coalescing window")
h.advance(0.4)
recovered:Tick()
check(publications == 1, "Coalesced lock status never published")
recovered.context.SendState = send
for _, client in ipairs({ host, guest, reloaded }) do
    for _, notice in ipairs(client.notices) do
        check(not notice:find(" / OnStart:", 1, true) and not notice:find(" / CreateUI:", 1, true), notice)
    end
end
print(
    string.format(
        "PASS: %d Blindshot event timeline, deterministic clients, duplicate/delayed packets and firing recovery assertions",
        checks
    )
)
