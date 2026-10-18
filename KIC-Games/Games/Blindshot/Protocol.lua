local _, Games = ...
local R = Games.Blindshot.Rules
local phases = { "PREPARE", "AIM", "REVEAL", "FIRING", "ROUND_END", "MATCH_END" }
-- Use lobby roster indices and bounded integer tuples on the existing action/state
-- transport. Repeating five names in every player, shot and hit exhausts WoW's
-- addon-message budget. Human-readable state exists only after decoding locally.
function R.Pack(v)
    local players, shots, hits, sequence, phase = {}, {}, {}, {}, nil
    for i, value in ipairs(phases) do
        if value == v.phase then
            phase = i
        end
    end
    for i, p in ipairs(v.players) do
        players[i] =
            table.concat({ p.alive and 1 or 0, p.locked and 1 or 0, p.rounds, p.kills, p.deathRound or 0 }, ",")
    end
    for _, a in ipairs(v.shots or {}) do
        local _, index = R.Player(v, a.name)
        shots[#shots + 1] =
            table.concat({ index, a.x, a.y, a.dx, a.dy, (a.auto and 1 or 0) + (a.shifted and 2 or 0) }, ",")
    end
    for _, hit in ipairs(v.hits or {}) do
        hits[#hits + 1] = hit[1] .. "," .. hit[2]
    end
    local _, winner = R.Player(v, v.winner)
    for _, event in ipairs(v.sequence or {}) do
        local mask = 0
        for _, target in ipairs(event.targets) do
            mask = mask + 2 ^ (target - 1)
        end
        sequence[#sequence + 1] = string.format("%d,%d", event.shooter, mask)
    end
    return {
        i = v.id,
        v = v.rev,
        r = v.round,
        p = phase,
        t = math.floor(v.deadline * 1000 + 0.5),
        s = table.concat(players, "|"),
        c = v.shots and table.concat(shots, "|") or nil,
        h = table.concat(hits, "|"),
        w = winner,
        d = v.draw,
        m = v.missed,
        o = v.order and table.concat(v.order, "|"),
        q = v.sequence and table.concat(sequence, "|"),
        f = v.fireAt and math.floor(v.fireAt * 1000 + 0.5),
        a = v.clock and math.floor(v.clock * 1000 + 0.5),
    }
end
local function tuples(value, fields, maximum)
    if type(value) ~= "string" or #value > 1000 or value:find("[^%d,|%-]") then
        return nil
    end
    local out = {}
    if value == "" then
        return out
    end
    if value:sub(1, 1) == "|" or value:sub(-1) == "|" or value:find("||", 1, true) then
        return nil
    end
    for item in value:gmatch("[^|]+") do
        local row = {}
        if item:sub(1, 1) == "," or item:sub(-1) == "," or item:find(",,", 1, true) then
            return nil
        end
        for token in item:gmatch("[^,]+") do
            if not token:match("^%-?%d+$") then
                return nil
            end
            row[#row + 1] = tonumber(token)
        end
        if #row ~= fields then
            return nil
        end
        out[#out + 1] = row
        if #out > maximum then
            return nil
        end
    end
    return out
end
function R.Unpack(data, session)
    if
        type(data) ~= "table"
        or not Games:ValidData(data)
        or not R.Int(data.p, 1, 6)
        or not R.Int(data.r, 1, R.MAX_ROUNDS)
        or type(data.i) ~= "string"
        or not R.Int(data.t, 0, 9999999999000)
        or data.a ~= nil and not R.Int(data.a, 0, 9999999999000)
    then
        return nil
    end
    local flags = tuples(data.s, 5, #session.members)
    local shots = data.c ~= nil and tuples(data.c, 6, #session.members) or nil
    local hits = tuples(data.h, 2, 20)
    if not flags or #flags ~= #session.members or not hits or data.c ~= nil and not shots then
        return nil
    end
    local v = {
        id = data.i,
        rev = data.v,
        round = data.r,
        phase = phases[data.p],
        deadline = data.t / 1000,
        players = {},
        events = {},
        hits = hits,
        missed = data.m == true,
        draw = data.d,
        clock = data.a and data.a / 1000,
    }
    for i, row in ipairs(flags) do
        if not R.Int(row[1], 0, 1) or not R.Int(row[2], 0, 1) or not R.Int(row[5], 0, data.r) then
            return nil
        end
        v.players[i] = {
            name = session.members[i].name,
            alive = row[1] == 1,
            locked = row[2] == 1,
            rounds = row[3],
            kills = row[4],
            deathRound = row[5] ~= 0 and row[5] or nil,
        }
    end
    v.radius = R.Radius(v.round, R.StartCount(v))
    if shots then
        local order, sequence = tuples(data.o, 1, #session.members), tuples(data.q, 2, #session.members)
        if not order or not sequence then
            return nil
        end
        v.order, v.sequence = {}, {}
        if not R.Int(data.f, 0, 9999999999000) then
            return nil
        end
        v.sequenceID, v.fireAt = v.id .. ":" .. v.round, data.f / 1000
        for _, row in ipairs(order) do
            v.order[#v.order + 1] = row[1]
        end
        for _, row in ipairs(sequence) do
            if not R.Int(row[1], 1, #session.members) or not R.Int(row[2], 0, 2 ^ #session.members - 1) then
                return nil
            end
            local event = { id = v.sequenceID .. ":" .. (#v.sequence + 1), shooter = row[1], targets = {} }
            for index = 1, #session.members do
                if math.floor(row[2] / 2 ^ (index - 1)) % 2 == 1 then
                    event.targets[#event.targets + 1] = index
                end
            end
            v.sequence[#v.sequence + 1] = event
        end
        v.shots = {}
        for _, row in ipairs(shots) do
            if not R.Int(row[1], 1, #session.members) or not R.Int(row[6], 0, 3) then
                return nil
            end
            v.shots[#v.shots + 1] = {
                name = session.members[row[1]].name,
                x = row[2],
                y = row[3],
                dx = row[4],
                dy = row[5],
                auto = row[6] % 2 == 1,
                shifted = row[6] >= 2,
            }
        end
    elseif data.o ~= nil or data.q ~= nil or data.f ~= nil then
        return nil
    end
    for _, hit in ipairs(hits) do
        if not R.Int(hit[1], 1, #session.members) or not R.Int(hit[2], 1, #session.members) or hit[1] == hit[2] then
            return nil
        end
        v.events[#v.events + 1] = session.members[hit[1]].name .. " hit " .. session.members[hit[2]].name
    end
    if #v.events == 0 and v.missed then
        v.events[1] = "All shots missed. Reposition for the next volley."
    end
    if data.w ~= nil then
        if not R.Int(data.w, 1, #session.members) then
            return nil
        end
        v.winner = session.members[data.w].name
    end
    if not R.ValidView(v, session) then
        return nil
    end
    if v.sequence and v.phase ~= "REVEAL" then
        v.events = R.Presentation(v, v.fireAt + 100).events
    end
    return v
end
