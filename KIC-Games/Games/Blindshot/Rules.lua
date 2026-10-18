local _, Games = ...
local B = {}
Games.Blindshot = B
local R = { HIT = 36, SPACING = 100, AIM_TIME = 15, MAX_ROUNDS = 12, SHOT_TIME = 0.6, IMPACT_TIME = 0.28 }
B.Rules = R
local schedule = { 1000, 820, 680, 560, 460 }
function R.Int(v, low, high)
    return type(v) == "number" and v == v and v % 1 == 0 and v >= low and v <= high
end
local function round(v)
    return math.floor(v + 0.5)
end
function R.Radius(n, players)
    local base = schedule[math.min(#schedule, n)]
    if players and players <= 2 then
        return math.max(150, math.floor(base * 0.68 ^ (n - 1) + 0.5))
    elseif players == 3 then
        return math.max(240, math.floor(base * 0.88 ^ (n - 1) + 0.5))
    end
    return base
end
function R.StartCount(s)
    local count = 0
    for _, p in ipairs(s.players) do
        if p.alive or p.deathRound == s.round then
            count = count + 1
        end
    end
    return count
end
function R.Position(x, y, radius)
    return R.Int(x, -1000, 1000) and R.Int(y, -1000, 1000) and x * x + y * y <= (radius - R.HIT) ^ 2
end
function R.ClampPosition(x, y, radius)
    if
        type(x) ~= "number"
        or type(y) ~= "number"
        or x ~= x
        or y ~= y
        or math.abs(x) == math.huge
        or math.abs(y) == math.huge
    then
        return nil
    end
    x, y = round(x), round(y)
    local limit = radius - R.HIT
    local length = math.sqrt(x * x + y * y)
    if length > limit then
        -- One simulation unit of rounding room keeps diagonal integer centers
        -- legal after quantization without changing the collision radius.
        x, y = round(x / length * (limit - 1)), round(y / length * (limit - 1))
    end
    return x, y
end
function R.Direction(dx, dy)
    if type(dx) ~= "number" or type(dy) ~= "number" or dx ~= dx or dy ~= dy then
        return nil
    end
    local magnitude = math.max(math.abs(dx), math.abs(dy))
    if magnitude < 0.001 or magnitude == math.huge then
        return nil
    end
    return round(dx / magnitude * 1000), round(dy / magnitude * 1000)
end
function R.Action(a, radius)
    return type(a) == "table"
        and R.Position(a.x, a.y, radius)
        and R.Int(a.dx, -1000, 1000)
        and R.Int(a.dy, -1000, 1000)
        and (a.dx ~= 0 or a.dy ~= 0)
end
function R.Default(index, count, radius)
    local angle = 2 * math.pi * (index - 1) / count
    local x, y = round(math.cos(angle) * radius * 0.6), round(math.sin(angle) * radius * 0.6)
    local dx, dy = R.Direction(-x, -y)
    return { x = x, y = y, dx = dx, dy = dy, seq = 0, lock = true, auto = true }
end
function R.New(session, now)
    local s = {
        id = session.id .. ":" .. session.run,
        rev = 0,
        round = 1,
        radius = 1000,
        phase = "PREPARE",
        deadline = now + 1,
        players = {},
        drafts = {},
        events = {},
    }
    for _, entry in ipairs(session.members) do
        s.players[#s.players + 1] = { name = entry.name, alive = true, locked = false, rounds = 0, kills = 0 }
    end
    return s
end
function R.Player(s, name)
    for i, p in ipairs(s.players) do
        if p.name == name then
            return p, i
        end
    end
end
function R.Alive(s)
    local n = 0
    for _, p in ipairs(s.players) do
        if p.alive then
            n = n + 1
        end
    end
    return n
end
function R.AllLocked(s)
    for _, p in ipairs(s.players) do
        if p.alive and not p.locked then
            return false
        end
    end
    return true
end
function R.BeginAim(s, now)
    s.phase, s.deadline, s.drafts, s.shots = "AIM", now + R.AIM_TIME, {}, nil
    s.order, s.sequence, s.sequenceID, s.fireAt = nil, nil, nil, nil
    s.events, s.hits, s.missed = {}, {}, false
    for _, p in ipairs(s.players) do
        p.locked = false
        if p.alive then
            p.rounds = p.rounds + 1
        end
    end
end
-- Resolve colliding *hidden* requests only after lock-in. Never disclose whether
-- another player occupies a requested point. Priority rotates every round.
function R.Place(s)
    local placed, output = {}, {}
    local function free(x, y)
        if not R.Position(x, y, s.radius) then
            return false
        end
        for _, p in ipairs(placed) do
            if (p.x - x) ^ 2 + (p.y - y) ^ 2 < R.SPACING ^ 2 then
                return false
            end
        end
        return true
    end
    for offset = 1, #s.players do
        local index = (offset + s.round - 2) % #s.players + 1
        local player = s.players[index]
        if player.alive then
            local a = s.drafts[player.name] or R.Default(index, #s.players, s.radius)
            local x, y = a.x, a.y
            if not free(x, y) then
                local found
                for ring = 1, 40 do
                    for direction = 0, 31 do
                        local angle = direction * math.pi / 16
                        local cx, cy =
                            round(a.x + ring * 50 * math.cos(angle)), round(a.y + ring * 50 * math.sin(angle))
                        if free(cx, cy) then
                            x, y, found = cx, cy, true
                            break
                        end
                    end
                    if found then
                        break
                    end
                end
                assert(found, "Blindshot placement capacity exhausted")
            end
            local shot = {
                name = player.name,
                x = x,
                y = y,
                dx = a.dx,
                dy = a.dy,
                auto = a.auto == true,
                shifted = x ~= a.x or y ~= a.y,
            }
            placed[#placed + 1], output[player.name] = shot, shot
        end
    end
    local shots = {}
    for _, p in ipairs(s.players) do
        if output[p.name] then
            shots[#shots + 1] = output[p.name]
        end
    end
    return shots
end
function R.Hit(shot, target)
    local x, y = target.x - shot.x, target.y - shot.y
    local dot, cross = x * shot.dx + y * shot.dy, x * shot.dy - y * shot.dx
    return dot > 0 and cross * cross <= R.HIT * R.HIT * (shot.dx * shot.dx + shot.dy * shot.dy)
end
function R.RayEnd(shot, radius)
    local d2 = shot.dx * shot.dx + shot.dy * shot.dy
    local dot = shot.x * shot.dx + shot.y * shot.dy
    local t = (-dot + math.sqrt(math.max(0, dot * dot + d2 * (radius * radius - shot.x ^ 2 - shot.y ^ 2)))) / d2
    return shot.x + shot.dx * t, shot.y + shot.dy * t
end
-- Parameter along the ray at the near edge of a target's hit circle.
function R.Contact(shot, target)
    if not R.Hit(shot, target) then
        return nil
    end
    local x, y = target.x - shot.x, target.y - shot.y
    local d2 = shot.dx * shot.dx + shot.dy * shot.dy
    local dot, cross = x * shot.dx + y * shot.dy, x * shot.dy - y * shot.dx
    return math.max(0, (dot - math.sqrt(math.max(0, R.HIT * R.HIT * d2 - cross * cross))) / d2)
end
function R.FiringEnd(v, shot)
    local _, index = R.Player(v, shot.name)
    for _, event in ipairs(v.sequence or {}) do
        if event.shooter == index and event.targets[1] then
            local name = v.players[event.targets[1]].name
            for _, target in ipairs(v.shots) do
                if target.name == name then
                    local t = R.Contact(shot, target)
                    return shot.x + shot.dx * t, shot.y + shot.dy * t
                end
            end
        end
    end
    return R.RayEnd(shot, v.radius)
end
-- Fisher-Yates is called only by the authority, once per round. The injected
-- integer generator also allows deterministic fixtures without a second engine.
function R.Shuffle(s, random)
    local order = {}
    for i, p in ipairs(s.players) do
        if p.alive then
            order[#order + 1] = i
        end
    end
    random = random or math.random
    for i = #order, 2, -1 do
        local j = random(1, i)
        order[i], order[j] = order[j], order[i]
    end
    return order
end
function R.Plan(s, order)
    local alive, shots, sequence = {}, {}, {}
    for _, a in ipairs(s.shots) do
        local _, index = R.Player(s, a.name)
        alive[index], shots[index] = true, a
    end
    for _, index in ipairs(order) do
        if alive[index] then
            local event = { id = s.id .. ":" .. s.round .. ":" .. (#sequence + 1), shooter = index, targets = {} }
            local nearest, distance
            for target in ipairs(s.players) do
                if target ~= index and alive[target] then
                    local contact = R.Contact(shots[index], shots[target])
                    if contact and (not distance or contact < distance) then
                        nearest, distance = target, contact
                    end
                end
            end
            if nearest then
                event.targets[1] = nearest
            end
            for _, target in ipairs(event.targets) do
                alive[target] = nil
            end
            sequence[#sequence + 1] = event
        end
    end
    return sequence
end
function R.Reveal(s, now, random)
    if s.phase ~= "AIM" then
        return false
    end
    for i, p in ipairs(s.players) do
        if p.alive then
            if not s.drafts[p.name] then
                s.drafts[p.name] = R.Default(i, #s.players, s.radius)
            end
            s.drafts[p.name].auto = not p.locked
            p.locked = true
        end
    end
    s.shots, s.phase, s.deadline = R.Place(s), "REVEAL", now + 1
    s.order = R.Shuffle(s, random)
    s.sequence = R.Plan(s, s.order)
    s.sequenceID, s.fireAt = s.id .. ":" .. s.round, now + 1
    return true
end
function R.Resolve(s, now)
    if s.phase ~= "REVEAL" then
        return false
    end
    local events, hits = {}, {}
    for _, event in ipairs(s.sequence) do
        events[#events + 1] = "P" .. event.shooter .. " FIRED"
        local shooter = s.players[event.shooter]
        for _, target in ipairs(event.targets) do
            local p = s.players[target]
            p.alive, p.deathRound = false, s.round
            shooter.kills = shooter.kills + 1
            hits[#hits + 1] = { event.shooter, target }
            events[#events + 1] = "P" .. event.shooter .. " ELIMINATED P" .. target
        end
        if #event.targets == 0 then
            events[#events + 1] = "P" .. event.shooter .. " MISSED"
        end
    end
    s.events, s.hits, s.missed = events, hits, #hits == 0
    s.phase = "FIRING"
    s.deadline = s.fireAt + #s.sequence * R.SHOT_TIME
    return true
end
-- Pure presentation: repeated snapshots never execute gameplay or add kills.
-- FIRING snapshots contain the final authoritative players and the entire plan.
-- Rewind that copy, then expose only events whose beam has reached its target.
function R.PlaybackPhase(v, now)
    if (v.phase == "REVEAL" or v.phase == "FIRING") and v.sequence then
        if now < v.fireAt then
            return "REVEAL"
        end
        return now < v.fireAt + #v.sequence * R.SHOT_TIME and "FIRING" or "ROUND_END"
    end
    return v.phase
end
function R.Presentation(v, now)
    local out = Games.Copy(v)
    out.phase = R.PlaybackPhase(v, now)
    out.events, out.hits = {}, {}
    if not v.sequence then
        return out
    end
    local elapsed = now - v.fireAt
    if v.phase ~= "REVEAL" and v.phase ~= "FIRING" then
        elapsed = 100
    end
    if v.phase ~= "REVEAL" then
        for _, event in ipairs(v.sequence) do
            for _, index in ipairs(event.targets) do
                out.players[index].alive, out.players[index].deathRound = true, nil
                out.players[event.shooter].kills = out.players[event.shooter].kills - 1
            end
        end
    end
    for i, event in ipairs(v.sequence) do
        local age = elapsed - (i - 1) * R.SHOT_TIME
        if age >= 0 then
            out.events[#out.events + 1] = "P" .. event.shooter .. " FIRED"
            if age < R.SHOT_TIME then
                out.current, out.shotAge = event.shooter, age
            end
        end
        if age >= R.IMPACT_TIME then
            for _, index in ipairs(event.targets) do
                out.players[index].alive, out.players[index].deathRound = false, v.round
                out.players[event.shooter].kills = out.players[event.shooter].kills + 1
                out.events[#out.events + 1] = "P" .. event.shooter .. " ELIMINATED P" .. index
                out.hits[#out.hits + 1] = { event.shooter, index }
                if age < 0.65 then
                    out.impacts = out.impacts or {}
                    out.impacts[index] = (0.65 - age) / (0.65 - R.IMPACT_TIME)
                end
            end
            if #event.targets == 0 then
                out.events[#out.events + 1] = "P" .. event.shooter .. " MISSED"
            end
        end
    end
    return out
end
function R.EndRound(s, now)
    s.phase, s.deadline = "ROUND_END", now + 2
end
function R.Next(s, now)
    if R.Alive(s) <= 1 or s.round >= R.MAX_ROUNDS then
        s.phase, s.deadline = "MATCH_END", now
        if R.Alive(s) == 1 then
            for _, p in ipairs(s.players) do
                if p.alive then
                    s.winner = p.name
                end
            end
        else
            s.draw = true
        end
    else
        s.round = s.round + 1
        s.radius, s.phase, s.deadline, s.shots = R.Radius(s.round, R.Alive(s)), "PREPARE", now + 1, nil
        s.drafts = {}
        s.order, s.sequence, s.sequenceID, s.fireAt = nil, nil, nil, nil
        s.events, s.hits, s.missed = {}, {}, false
        for _, p in ipairs(s.players) do
            p.locked = false
        end
    end
end
local phases = { PREPARE = true, AIM = true, REVEAL = true, FIRING = true, ROUND_END = true, MATCH_END = true }
function R.Public(s)
    local v = {
        id = s.id,
        rev = s.rev,
        round = s.round,
        radius = s.radius,
        phase = s.phase,
        deadline = s.deadline,
        players = Games.Copy(s.players),
        events = Games.Copy(s.events),
        winner = s.winner,
        draw = s.draw,
        hits = Games.Copy(s.hits or {}),
        missed = s.missed == true,
        clock = s.clock,
    }
    if s.phase ~= "PREPARE" and s.phase ~= "AIM" then
        v.shots = Games.Copy(s.shots)
        v.order, v.sequence = Games.Copy(s.order), Games.Copy(s.sequence)
        v.sequenceID, v.fireAt = s.sequenceID, s.fireAt
    end
    return v
end
function R.ValidView(v, session)
    if
        type(v) ~= "table"
        or not Games:ValidData(v)
        or v.id ~= session.id .. ":" .. session.run
        or not R.Int(v.rev, 0, 2147483647)
        or not R.Int(v.round, 1, R.MAX_ROUNDS)
        or not phases[v.phase]
        or type(v.deadline) ~= "number"
        or v.deadline ~= v.deadline
        or v.deadline < 0
        or v.deadline > 9999999999
        or not Games:IsArray(v.players)
        or #v.players ~= #session.members
        or not Games:IsArray(v.events)
        or #v.events > 20
        or v.drafts ~= nil
    then
        return false
    end
    for i, p in ipairs(v.players) do
        if
            type(p) ~= "table"
            or p.name ~= session.members[i].name
            or type(p.alive) ~= "boolean"
            or type(p.locked) ~= "boolean"
            or not R.Int(p.rounds, 0, v.round)
            or not R.Int(p.kills, 0, 4)
            or p.x ~= nil
            or p.y ~= nil
            or p.dx ~= nil
            or p.dy ~= nil
            or p.deathRound ~= nil and not R.Int(p.deathRound, 1, v.round)
            or p.alive and p.deathRound ~= nil
        then
            return false
        end
    end
    if v.radius ~= R.Radius(v.round, R.StartCount(v)) then
        return false
    end
    for _, line in ipairs(v.events) do
        if type(line) ~= "string" or #line > 240 then
            return false
        end
    end
    if v.shots ~= nil then
        if v.phase == "AIM" or v.phase == "PREPARE" or not Games:IsArray(v.shots) or #v.shots > #v.players then
            return false
        end
        local seen = {}
        for i, a in ipairs(v.shots) do
            if not R.Action(a, v.radius) or not R.Player(v, a.name) or seen[a.name] then
                return false
            end
            seen[a.name] = true
            for j = 1, i - 1 do
                local other = v.shots[j]
                if (a.x - other.x) ^ 2 + (a.y - other.y) ^ 2 < R.SPACING ^ 2 then
                    return false
                end
            end
        end
    elseif v.phase ~= "PREPARE" and v.phase ~= "AIM" then
        return false
    end
    if v.shots then
        if not R.ValidSequence(v) then
            return false
        end
    elseif v.order ~= nil or v.sequence ~= nil or v.sequenceID ~= nil or v.fireAt ~= nil then
        return false
    end
    if v.clock ~= nil and (type(v.clock) ~= "number" or v.clock ~= v.clock or v.clock < 0 or v.clock > 9999999999) then
        return false
    end
    if v.winner ~= nil and (not R.Player(v, v.winner) or v.phase ~= "MATCH_END") then
        return false
    end
    return v.draw == nil or type(v.draw) == "boolean" and v.phase == "MATCH_END"
end
function R.ValidSequence(v)
    if
        not Games:IsArray(v.order)
        or #v.order ~= #v.shots
        or not Games:IsArray(v.sequence)
        or #v.sequence > #v.order
        or v.sequenceID ~= v.id .. ":" .. v.round
        or type(v.fireAt) ~= "number"
        or v.fireAt ~= v.fireAt
        or v.fireAt < 0
        or v.fireAt > 9999999999
    then
        return false
    end
    local available, seen, dead = {}, {}, {}
    for _, shot in ipairs(v.shots) do
        local _, index = R.Player(v, shot.name)
        available[index] = true
    end
    for _, index in ipairs(v.order) do
        if not R.Int(index, 1, #v.players) or not available[index] or seen[index] then
            return false
        end
        seen[index] = true
    end
    local step = 0
    for _, index in ipairs(v.order) do
        if not dead[index] then
            step = step + 1
            local event = v.sequence[step]
            if
                type(event) ~= "table"
                or event.id ~= v.sequenceID .. ":" .. step
                or event.shooter ~= index
                or not Games:IsArray(event.targets)
                or #event.targets > 1
            then
                return false
            end
            local previous = 0
            for _, target in ipairs(event.targets) do
                if
                    not R.Int(target, previous + 1, #v.players)
                    or target == index
                    or not available[target]
                    or dead[target]
                then
                    return false
                end
                previous, dead[target] = target, true
            end
        end
    end
    if step ~= #v.sequence then
        return false
    end
    local expected = R.Plan(v, v.order)
    if #expected ~= #v.sequence then
        return false
    end
    for i, event in ipairs(expected) do
        local received = v.sequence[i]
        if received.shooter ~= event.shooter or #received.targets ~= #event.targets then
            return false
        end
        for j, index in ipairs(event.targets) do
            if received.targets[j] ~= index then
                return false
            end
        end
        if v.phase ~= "REVEAL" and v.players[event.shooter].kills < #event.targets then
            return false
        end
    end
    for i, p in ipairs(v.players) do
        if available[i] then
            if v.phase == "REVEAL" then
                if not p.alive then
                    return false
                end
            elseif p.alive == (dead[i] == true) or dead[i] and p.deathRound ~= v.round then
                return false
            end
        elseif p.alive then
            return false
        end
    end
    return true
end
function R.ValidAuthority(s, session)
    if type(s) ~= "table" or not Games:ValidData(s) or type(s.drafts) ~= "table" then
        return false
    end
    if not R.ValidView(R.Public(s), session) then
        return false
    end
    for name, action in pairs(s.drafts) do
        if not R.Player(s, name) or not R.Action(action, s.radius) or not R.Int(action.seq, 0, 1000000) then
            return false
        end
    end
    return true
end
function R.Entries(s)
    local result = {}
    local noSurvivors = R.Alive(s) == 0
    for _, p in ipairs(s.players) do
        local finalist = p.alive or noSurvivors and p.deathRound == s.round
        local outcome = s.winner and (p.name == s.winner and "win" or "loss") or (finalist and "draw" or "loss")
        result[#result + 1] = {
            player = p.name,
            outcome = outcome,
            score = p.kills,
            rank = (outcome == "win" or outcome == "draw") and 1 or 2,
            stats = { rounds = p.rounds, eliminations = p.kills },
        }
    end
    return result
end
