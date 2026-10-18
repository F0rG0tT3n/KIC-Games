-- Run from repository root: lua tests/blindshot_rules.lua
local G = {}
function G.Copy(v)
    if type(v) ~= "table" then
        return v
    end
    local out = {}
    for k, x in pairs(v) do
        out[k] = G.Copy(x)
    end
    return out
end
function G:ValidData()
    return true
end
function G:IsArray(v)
    if type(v) ~= "table" then
        return false
    end
    for k in pairs(v) do
        if type(k) ~= "number" or k < 1 or k > #v or k % 1 ~= 0 then
            return false
        end
    end
    return true
end
assert(loadfile("KIC-Games/Games/Blindshot/Rules.lua"))("KIC-Games", G)
local R, checks = G.Blindshot.Rules, 0
local function check(v, why)
    assert(v, why)
    checks = checks + 1
end
local function new(n)
    local session = { id = "blindshot-test", run = 1, members = {} }
    for i = 1, n do
        session.members[i] = { name = "Player" .. i .. "-Realm" }
    end
    return R.New(session, 100), session
end
for i, size in ipairs({ 1000, 820, 680, 560, 460, 460, 460 }) do
    check(R.Radius(i) == size, "Shrink schedule")
end
for round = 2, R.MAX_ROUNDS do
    check(
        R.Radius(round, 2) <= R.Radius(round, 3) and R.Radius(round, 3) < R.Radius(round, 4),
        "Endgame shrink did not strengthen"
    )
    for count = 2, 5 do
        check(R.Radius(round, count) <= R.Radius(round - 1, count), "Arena grew between rounds")
    end
end
check(R.Radius(5, 2) == 150 and R.Radius(R.MAX_ROUNDS, 2) == 150, "Duel minimum not reached/retained")
check(R.Radius(R.MAX_ROUNDS, 3) == 240, "Three-player minimum changed")
check(not R.ClampPosition(math.huge, 0, 150) and not R.ClampPosition(0 / 0, 0, 150), "Invalid cursor accepted")
-- At the duel minimum, even two colliding requests at any legal first center
-- must settle legally. Test both rotated priorities and every angular sector.
for round = 5, 6 do
    for angle = 0, 355, 5 do
        for _, distance in ipairs({ 0, 30, 60, 90, 114, 1000 }) do
            local a = angle * math.pi / 180
            local x, y = R.ClampPosition(math.cos(a) * distance, math.sin(a) * distance, 150)
            check(R.Position(x, y, 150), "Clamp leaves a body beyond circular boundary")
            local duel = new(2)
            duel.round, duel.radius = round, R.Radius(round, 2)
            for _, p in ipairs(duel.players) do
                duel.drafts[p.name] = { x = x, y = y, dx = 1000, dy = 0, seq = 1, lock = true }
            end
            local shots = R.Place(duel)
            check(
                #shots == 2 and R.Action(shots[1], 150) and R.Action(shots[2], 150),
                "Minimum duel settlement left the arena"
            )
            check(
                (shots[1].x - shots[2].x) ^ 2 + (shots[1].y - shots[2].y) ^ 2 >= R.SPACING ^ 2,
                "Minimum duel positions overlap"
            )
        end
    end
end
check(R.Position(964, 0, 1000) and not R.Position(965, 0, 1000), "Player body crossed edge")
check(not R.Position(0 / 0, 0, 1000) and not R.Position("0", 0, 1000), "Invalid coordinate accepted")
check(not R.Action({ x = 0, y = 0, dx = 0, dy = 0 }, 1000), "Zero direction accepted")
check(not R.Direction(math.huge, 1), "Infinite direction accepted")
check(R.Hit({ x = -300, y = 0, dx = 1000, dy = 0 }, { x = 300, y = R.HIT }), "Tangent hit missed")
check(not R.Hit({ x = -300, y = 0, dx = 1000, dy = 0 }, { x = 300, y = R.HIT + 1 }), "Outside beam hit")
check(not R.Hit({ x = 300, y = 0, dx = 1000, dy = 0 }, { x = -300, y = 0 }), "Backward ray hit")
check(
    R.Contact({ x = -300, y = 0, dx = 1000, dy = 0 }, { x = 300, y = 36 }) == 0.6,
    "Tangent contact endpoint incorrect"
)
check(not R.Contact({ x = -300, y = 0, dx = 1000, dy = 0 }, { x = 300, y = 37 }), "Miss generated a stopping point")
check(R.SHOT_TIME == 0.6 and R.SPACING >= 2 * R.HIT, "Cadence or identical nonoverlapping hitboxes changed")
for _, radius in ipairs({ 1000, 820, 680, 560, 460 }) do
    for angle = 0, 345, 15 do
        local a = angle * math.pi / 180
        local inside, outside = radius - R.HIT - 2, radius - R.HIT + 2
        local function point(distance)
            return math.floor(math.cos(a) * distance + 0.5), math.floor(math.sin(a) * distance + 0.5)
        end
        local x, y = point(inside)
        check(R.Position(x, y, radius), "Circular boundary rejects an interior token")
        x, y = point(outside)
        check(not R.Position(x, y, radius), "Circular boundary allows a crossing token")
    end
end
-- Exact quarter-turn rotations must preserve hit/miss and near-circle contact.
for _, offset in ipairs({ 0, R.HIT, R.HIT + 1 }) do
    local shot, target = { x = -300, y = 0, dx = 1000, dy = 0 }, { x = 300, y = offset }
    local hit, contact = R.Hit(shot, target), R.Contact(shot, target)
    for _ = 1, 4 do
        shot.x, shot.y, shot.dx, shot.dy = -shot.y, shot.x, -shot.dy, shot.dx
        target.x, target.y = -target.y, target.x
        check(R.Hit(shot, target) == hit and R.Contact(shot, target) == contact, "Ray-vs-circle favors an axis")
    end
end
local s, session = new(2)
R.BeginAim(s, 101)
s.drafts[s.players[1].name] = { x = -400, y = 0, dx = 1000, dy = 0, seq = 1 }
s.drafts[s.players[2].name] = { x = 400, y = 0, dx = -1000, dy = 0, seq = 1 }
local public = R.Public(s)
check(not public.shots and not public.drafts and not public.players[1].x, "AIM reveals hidden positions")
check(R.ValidView(public, session), "Valid public view rejected")
public.shots = { s.drafts[s.players[1].name] }
check(not R.ValidView(public, session), "AIM accepted shot leak")
local function identity(low, high)
    return high
end
R.Reveal(s, 116, identity)
check(s.shots[1].x == -400 and s.shots[1].auto, "Timeout did not retain submitted draft")
check(#s.order == 2 and s.order[1] == 1 and #s.sequence == 1, "Dead pending turn not skipped")
check(not R.Reveal(s, 116, identity), "Duplicate reveal rerolled order")
R.Resolve(s, 117)
check(R.Alive(s) == 1 and s.players[1].kills == 1 and s.players[2].kills == 0, "Dead player fired")
check(not R.Resolve(s, 118) and s.players[1].kills == 1, "Repeated resolution counted a second shot")
local start = R.Presentation(R.Public(s), 117)
check(R.Alive(start) == 2 and start.current == 1 and #start.events == 1, "Premature death before impact")
local impact = R.Presentation(R.Public(s), 117.3)
check(R.Alive(impact) == 1 and impact.impacts[2] and #impact.events == 2, "Impact did not reveal death")
R.EndRound(s, 118)
R.Next(s, 120)
check(s.phase == "MATCH_END" and s.winner == s.players[1].name, "First shooter should win facing duel")
check(R.Entries(s)[1].outcome == "win" and R.Entries(s)[2].outcome == "loss", "Winner metrics")
local multi = new(5)
R.BeginAim(multi, 101)
for i, p in ipairs(multi.players) do
    multi.drafts[p.name] = { x = (i - 3) * 180, y = 0, dx = 1000, dy = 0, seq = 1 }
end
R.Reveal(multi, 102, identity)
local overlap = G.Copy(R.Public(multi))
overlap.shots[2].x, overlap.shots[2].y = overlap.shots[1].x, overlap.shots[1].y
check(
    not R.ValidView(overlap, { id = "blindshot-test", run = 1, members = multi.players }),
    "Revealed overlap passed validation"
)
check(
    #multi.order == 5 and #multi.sequence == 3 and multi.sequence[1].targets[1] == 2,
    "First shot did not stop at nearest opponent"
)
check(
    multi.sequence[2].shooter == 3 and multi.sequence[2].targets[1] == 4,
    "Living shooter or dead-turn skip incorrect"
)
R.Resolve(multi, 103)
check(
    multi.players[1].kills == 1 and multi.players[2].kills == 0 and R.Alive(multi) == 3,
    "Shot pierced or credited extra kills"
)
check(multi.deadline == 103 + 3 * R.SHOT_TIME, "Skipped players introduced dead time")
local ex, ey = R.FiringEnd(R.Public(multi), multi.shots[1])
check(ex == multi.shots[2].x - R.HIT and ey == 0, "Tracer passed through target surface")
-- Roster order is deliberately different from physical distance.
local nearest = new(3)
R.BeginAim(nearest, 101)
for i, p in ipairs(nearest.players) do
    nearest.drafts[p.name] = { x = ({ -500, 500, 0 })[i], y = 0, dx = 1000, dy = 0, seq = 1 }
end
R.Reveal(nearest, 102, identity)
check(
    nearest.sequence[1].targets[1] == 3 and #nearest.sequence[1].targets == 1,
    "Selected roster-first instead of nearest target"
)
check(nearest.sequence[2].shooter == 2, "Eliminated nearest opponent still fired")
R.Resolve(nearest, 103)
check(nearest.players[2].alive and not nearest.players[3].alive, "Farther enemy was hit through the first target")
-- An earlier casualty does not shield a living opponent from later shots.
local corpses = new(3)
R.BeginAim(corpses, 101)
for i, p in ipairs(corpses.players) do
    corpses.drafts[p.name] = { x = (i - 2) * 400, y = 0, dx = i == 3 and -1000 or 1000, dy = 0, seq = 1 }
end
R.Reveal(corpses, 102, identity)
check(corpses.sequence[2].shooter == 3 and corpses.sequence[2].targets[1] == 1, "Dead body blocked a later shot")
-- Random orders change across rounds and form permutations of living players.
local permutations = {}
for seed = 1, 100 do
    math.randomseed(seed)
    local game = new(5)
    game.players[3].alive = false
    local order = R.Shuffle(game)
    local seen = {}
    for _, index in ipairs(order) do
        check(index ~= 3 and not seen[index], "Order repeated a player or included eliminated player")
        seen[index] = true
    end
    check(#order == 4, "Order omitted a living player")
    permutations[table.concat(order, ",")] = true
end
local count = 0
for _ in pairs(permutations) do
    count = count + 1
end
check(count > 1, "Shuffle never changes")
-- Zero-survivor defensive end condition remains a draw. With one non-self-hitting
-- weapon, a normal sequential exchange always leaves at least one survivor.
local empty = new(2)
for _, p in ipairs(empty.players) do
    p.alive = false
    p.deathRound = 1
end
R.Next(empty, 200)
check(empty.draw and not empty.winner, "No-survivor state did not draw")
check(R.Entries(empty)[1].outcome == "draw" and R.Entries(empty)[2].outcome == "draw", "Finalists not drawn")
local missing = new(5)
R.BeginAim(missing, 101)
R.Reveal(missing, 116)
check(#missing.shots == 5, "AFK players did not receive fallback shots")
for _, shot in ipairs(missing.shots) do
    check(shot.auto and R.Action(shot, 1000), "Invalid fallback")
end
for seed = 1, 100 do
    local game, lobby = new(5)
    game.round, game.radius = (seed - 1) % 12 + 1, R.Radius((seed - 1) % 12 + 1)
    R.BeginAim(game, 101)
    for _, p in ipairs(game.players) do
        game.drafts[p.name] = { x = 0, y = 0, dx = 1000, dy = 0, seq = 1 }
    end
    local shots = R.Place(game)
    local expectedFirst = (game.round - 1) % 5 + 1
    check(shots[expectedFirst].x == 0 and shots[expectedFirst].y == 0, "Collision priority did not rotate")
    for i, shot in ipairs(shots) do
        check(R.Action(shot, game.radius), "Collision settlement outside platform")
        local x, y = R.RayEnd(shot, game.radius)
        check(math.abs(x * x + y * y - game.radius ^ 2) < 0.001, "Ray did not stop at edge")
        for j = i + 1, #shots do
            check(
                (shot.x - shots[j].x) ^ 2 + (shot.y - shots[j].y) ^ 2 >= R.SPACING ^ 2,
                "Overlapping settled positions"
            )
        end
    end
    R.Reveal(game, 102)
    check(R.ValidAuthority(game, lobby), "Valid host recovery rejected")
    R.Resolve(game, 103)
    check(R.Alive(game) <= 5 and R.ValidView(R.Public(game), lobby), "Resolved state invalid")
end
local cap = new(5)
cap.round, cap.radius = R.MAX_ROUNDS, R.Radius(R.MAX_ROUNDS)
R.Next(cap, 500)
check(cap.phase == "MATCH_END" and cap.draw, "Stalemate round cap did not draw")
print(
    string.format(
        "PASS: %d Blindshot sequential ray, shrink, hidden-state, spacing, fallback and result assertions",
        checks
    )
)
