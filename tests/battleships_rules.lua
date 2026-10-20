local G = {}
assert(loadfile("KIC-Games/Games/Battleships/Rules.lua"))("KIC-Games", G)
local R, checks = G.Battleships.Rules, 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function validate(s)
    check(R.ValidAuthority(s), "Invalid authoritative state at " .. s.rev)
    for seat = 1, 2 do
        local v = R.View(s, seat)
        check(R.ValidView(v, seat), "Invalid player view")
        check(R.Unpack(R.Pack(v), seat) ~= nil, "Snapshot did not round-trip")
        check(v.enemyFleet == (s.phase == "ended" and s.fleets[3 - seat] or ""), "Enemy fleet leaked")
    end
end
check(R.Coordinate(1) == "A1" and R.Coordinate(100) == "J10", "Coordinates")
local draft = {}
check(R.Place(draft, 1, 1, 1, false), "Carrier placement")
check(not R.Place(draft, 2, 3, 1, true), "Overlapping ship accepted")
check(not R.Place(draft, 2, 9, 9, true), "Out of bounds accepted")
check(not R.Place(draft, 2, 0, 1, false), "Invalid coordinate accepted")
check(not R.EncodeFleet(draft), "Partial fleet locked")
check(not R.DecodeFleet("00H00H00H00H00H"), "Overlapping fleet decoded")
check(not R.DecodeFleet(string.rep("9", 15)), "Invalid fleet decoded")
for seed = 1, 12 do
    math.randomseed(seed)
    local fleet = R.RandomFleet(seed == 1 and function()
        return 1
    end or nil)
    local encoded = R.EncodeFleet(fleet)
    check(encoded and R.EncodeFleet(R.DecodeFleet(encoded)) == encoded, "Fleet codec")
    local count = 0
    for _, ship in ipairs(R.Board(fleet)) do
        if ship > 0 then
            count = count + 1
        end
    end
    check(count == 17, "Wrong ship coverage")
    for starter = 1, 2 do
        local s = R.New(starter)
        validate(s)
        check(not R.Apply(s, starter, { seq = 1, rev = 0, op = "fire", cell = 1 }), "Shot during setup")
        check(R.Apply(s, 1, { seq = 1, rev = 0, op = "lock", fleet = encoded }), "Host lock")
        validate(s)
        -- Both players can lock against the same setup revision.
        check(R.Apply(s, 2, { seq = 1, rev = 0, op = "lock", fleet = encoded }), "Concurrent guest lock")
        validate(s)
        local rev = s.rev
        check(
            not R.Apply(s, starter, { seq = 2, rev = 1, op = "fire", cell = 1 }) and s.rev == rev,
            "Stale shot changed state"
        )
        check(not R.Apply(s, 3 - starter, { seq = 2, rev = rev, op = "fire", cell = 1 }), "Wrong turn")
        local board, targets, misses = R.Board(fleet), {}, {}
        for i = 1, 100 do
            if board[i] > 0 then
                targets[#targets + 1] = i
            else
                misses[#misses + 1] = i
            end
        end
        for turn = 1, 33 do
            local seat = s.turn
            local index = seat == starter and targets[math.ceil(turn / 2)] or misses[math.floor(turn / 2)]
            local action = { seq = s.acks[seat] + 1, rev = s.rev, op = "fire", cell = index }
            check(R.Apply(s, seat, action), "Valid shot rejected")
            validate(s)
            check(not R.Apply(s, seat, action), "Repeated action accepted")
        end
        check(s.phase == "ended" and s.winner == starter and R.Hits(s.shots[starter]) == 17, "Fleet victory")
        check(R.Remaining(s.shots[starter], encoded) == 0, "Sunk count")
        check(
            not R.Apply(s, 3 - starter, { seq = s.acks[3 - starter] + 1, rev = s.rev, op = "resign" }),
            "Ended game changed"
        )
        local forged = R.View(s, 1)
        forged.enemyFleet = "bad"
        check(not R.ValidView(forged, 1), "Malformed final fleet accepted")
    end
end
for seat = 1, 2 do
    local s = R.New(1)
    check(R.Apply(s, seat, { seq = 1, rev = 0, op = "resign" }), "Setup resignation")
    validate(s)
    check(s.winner == 3 - seat, "Wrong resignation winner")
end
local s = R.New(1)
local v = R.View(s, 2)
v.enemyFleet = R.EncodeFleet(R.RandomFleet())
check(not R.ValidView(v, 2), "Live enemy fleet accepted")
check(not R.Unpack({ 2, 0 }, 2), "Truncated snapshot accepted")
check(not R.Action({ seq = 0 / 0, rev = 0, op = "resign" }), "NaN sequence accepted")
check(not R.Action({ seq = 1, rev = 0, op = "fire", cell = 101 }), "Invalid target accepted")
print("PASS: " .. checks .. " Battleships placement, turns, shots, sinking, views and validation checks")
