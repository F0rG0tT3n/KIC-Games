local _, Games = ...
local Base = Games.Bejeweled.Engine
local E = setmetatable({}, { __index = Base })
E.__index = E
Games.BejeweledDeluxe = { Engine = E }
-- Value pieces keep Exchange/Refill and their animation origins unchanged.
-- 1..7 normal, 8..14 Bomb, 15..21 Lightning, 22 colorless Orb.
E.Orb = 22
E.CreationBonus = { bomb = 100, lightning = 200, orb = 300 }
E.ActivationBonus = { bomb = 150, lightning = 250, orb = 400 }
function E.Kind(piece)
    if piece and piece ~= E.Orb then
        return (piece - 1) % 7 + 1
    end
end
function E.Special(piece)
    if piece == E.Orb then
        return "orb"
    end
    if piece and piece > 14 then
        return "lightning"
    end
    if piece and piece > 7 then
        return "bomb"
    end
end
function E.Piece(kind, special)
    return special == "orb" and E.Orb or kind + (special == "bomb" and 7 or special == "lightning" and 14 or 0)
end
local function key(x, y)
    return (y - 1) * 8 + x
end
local function cell(id)
    return { x = (id - 1) % 8 + 1, y = math.floor((id - 1) / 8) + 1 }
end
local function inside(x, y)
    return type(x) == "number"
        and type(y) == "number"
        and x % 1 == 0
        and y % 1 == 0
        and x >= 1
        and x <= 8
        and y >= 1
        and y <= 8
end
function E.New(random)
    return setmetatable(Base.New(random), E)
end
-- Connected components of intersecting straight runs, not adjacent same-color
-- cells or aggregate match counts. A perpendicular intersection is a T/L/cross.
function E:Patterns()
    local runs, parents, owner = {}, {}, {}
    local function root(i)
        while parents[i] ~= i do
            i = parents[i]
        end
        return i
    end
    local function run(x, y, dx, dy, length)
        local n = #runs + 1
        local r = { cells = {}, length = length, axis = dx == 1 and "h" or "v" }
        runs[n], parents[n] = r, n
        for offset = 0, length - 1 do
            local id = key(x + offset * dx, y + offset * dy)
            r.cells[#r.cells + 1] = id
            if owner[id] then
                parents[root(n)] = root(owner[id])
            end
            owner[id] = n
        end
    end
    for axis = 1, 2 do
        for line = 1, 8 do
            local pos = 1
            while pos <= 8 do
                local x, y = axis == 1 and pos or line, axis == 1 and line or pos
                local kind, finish = E.Kind(self.board[y][x]), pos
                while kind and finish < 8 do
                    local nextPiece
                    if axis == 1 then
                        nextPiece = self.board[line][finish + 1]
                    else
                        nextPiece = self.board[finish + 1][line]
                    end
                    if E.Kind(nextPiece) ~= kind then
                        break
                    end
                    finish = finish + 1
                end
                if kind and finish - pos >= 2 then
                    run(x, y, axis == 1 and 1 or 0, axis == 2 and 1 or 0, finish - pos + 1)
                end
                pos = finish + 1
            end
        end
    end
    local groups, ordered = {}, {}
    for i, r in ipairs(runs) do
        local id = root(i)
        if not groups[id] then
            groups[id] = { cells = {}, set = {}, longest = 0, axes = {} }
            ordered[#ordered + 1] = groups[id]
        end
        local g = groups[id]
        g.longest, g.axes[r.axis] = math.max(g.longest, r.length), true
        for _, k in ipairs(r.cells) do
            if not g.set[k] then
                g.cells[#g.cells + 1], g.set[k] = k, true
            end
        end
    end
    for _, g in ipairs(ordered) do
        table.sort(g.cells)
        g.special = g.longest >= 5 and "orb"
            or g.axes.h and g.axes.v and "lightning"
            or g.longest == 4 and "bomb"
            or nil
    end
    table.sort(ordered, function(a, b)
        return a.cells[1] < b.cells[1]
    end)
    return ordered
end
function E:Matches()
    local cells = {}
    for _, g in ipairs(self:Patterns()) do
        for _, id in ipairs(g.cells) do
            cells[#cells + 1] = cell(id)
        end
    end
    return cells
end
function E:Direct(a, b)
    return a and b and (a == E.Orb or b == E.Orb or E.Special(a) and E.Special(b)) or false
end
function E:FindMove()
    for y = 1, 8 do
        for x = 1, 8 do
            for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
                local tx, ty = x + d[1], y + d[2]
                if inside(tx, ty) then
                    if self:Direct(self.board[y][x], self.board[ty][tx]) then
                        return { x = x, y = y, tx = tx, ty = ty }
                    end
                    self:Exchange(x, y, tx, ty)
                    local valid = #self:Matches() > 0
                    self:Exchange(x, y, tx, ty)
                    if valid then
                        return { x = x, y = y, tx = tx, ty = ty }
                    end
                end
            end
        end
    end
end
-- Build the entire clear before animating it. Each occupied cell enters this
-- bounded queue once (at most 64); gravity never runs inside a chain reaction.
function E:Plan(patterns, destination, combination)
    local p = { cells = {}, created = {}, events = {}, bonus = 0, activations = 0, longest = 3 }
    local pieces, queued, queue, activated, protected = {}, {}, {}, {}, {}
    for y = 1, 8 do
        for x = 1, 8 do
            pieces[key(x, y)] = self.board[y][x]
        end
    end
    local function event(name, bonus)
        p.events[name] = (p.events[name] or 0) + 1
        p.bonus = p.bonus + (bonus or 0)
    end
    local function hit(id)
        if pieces[id] and not queued[id] then
            queued[id], queue[#queue + 1] = true, id
            p.cells[#p.cells + 1] = cell(id)
        end
    end
    local function at(x, y)
        if inside(x, y) then
            hit(key(x, y))
        end
    end
    local function area(id, radius)
        local c = cell(id)
        for y = c.y - radius, c.y + radius do
            for x = c.x - radius, c.x + radius do
                at(x, y)
            end
        end
    end
    local function cross(id, radius)
        local c = cell(id)
        for offset = -radius, radius do
            for i = 1, 8 do
                at(i, c.y + offset)
                at(c.x + offset, i)
            end
        end
    end
    local function color(kind)
        for id = 1, 64 do
            if E.Kind(pieces[id]) == kind then
                hit(id)
            end
        end
    end
    local function activate(id)
        local special = E.Special(pieces[id])
        if not special or activated[id] then
            return false
        end
        activated[id], p.activations = true, p.activations + 1
        event(special .. "Activate", E.ActivationBonus[special])
        return special
    end
    for _, g in ipairs(patterns) do
        p.longest = math.max(p.longest, g.longest)
        if g.special then
            -- Player destination first; cascades choose topmost, then leftmost.
            local id = destination and g.set[destination] and destination or g.cells[1]
            p.created[id], protected[id] = E.Piece(E.Kind(pieces[id]), g.special), true
            event(g.special .. "Create", E.CreationBonus[g.special])
        end
        for _, id in ipairs(g.cells) do
            hit(id)
        end
    end
    if combination then
        local a, b = combination[1], combination[2]
        local sa, sb = E.Special(pieces[a]), E.Special(pieces[b])
        hit(a)
        hit(b)
        if sa and sb then
            event("combination", 500)
        end
        if sa == "orb" or sb == "orb" then
            local orb, other = sa == "orb" and a or b, sa == "orb" and b or a
            local special, kind = E.Special(pieces[other]), E.Kind(pieces[other])
            activate(orb)
            if special == "orb" then
                activate(other)
                event("boardClear", 1000)
                for id = 1, 64 do
                    hit(id)
                end
            else
                if special then
                    for id = 1, 64 do
                        if E.Kind(pieces[id]) == kind then
                            pieces[id] = E.Piece(kind, special)
                        end
                    end
                end
                color(kind)
            end
        else
            activate(a)
            activate(b)
            if sa == "bomb" and sb == "bomb" then
                area(b, 2)
            else
                cross(b, 1)
            end
        end
    end
    local cursor = 1
    while cursor <= #queue do
        local id = queue[cursor]
        cursor = cursor + 1
        local special = activate(id)
        if special == "bomb" then
            area(id, 1)
        elseif special == "lightning" then
            cross(id, 0)
        elseif special == "orb" then
            -- A hit Orb targets the most numerous color, lowest kind breaks ties.
            local counts, selected = {}, 1
            for k = 1, 7 do
                counts[k] = 0
            end
            for k = 1, 64 do
                local kind = E.Kind(pieces[k])
                if kind then
                    counts[kind] = counts[kind] + 1
                end
            end
            for k = 2, 7 do
                if counts[k] > counts[selected] then
                    selected = k
                end
            end
            color(selected)
        end
    end
    p.activated, p.count = activated, 0
    for _, c in ipairs(p.cells) do
        if not protected[key(c.x, c.y)] then
            p.count = p.count + 1
        end
    end
    if p.activations >= 3 then
        event("majorChain", 250)
    end
    p.gain = (p.count * 50 + p.bonus) * self.cascade
    self.plan, self.pending, self.phase = p, p.cells, "clearing"
end
function E:Swap(x, y, tx, ty)
    if
        self.gameover
        or self.phase ~= "idle"
        or not inside(x, y)
        or not inside(tx, ty)
        or math.abs(tx - x) + math.abs(ty - y) ~= 1
    then
        return false
    end
    local direct = self:Direct(self.board[y][x], self.board[ty][tx])
    self:Exchange(x, y, tx, ty)
    local patterns = self:Patterns()
    if not direct and #patterns == 0 then
        self:Exchange(x, y, tx, ty)
        return false
    end
    self.moves, self.cascade = self.moves + 1, 1
    -- Direct combinations consume their inputs; ordinary matches are discovered
    -- after refill, so the combination cannot create a replacement at its center.
    self:Plan(direct and {} or patterns, key(tx, ty), direct and { key(x, y), key(tx, ty) } or nil)
    self.revision = self.revision + 1
    return true
end
function E:Step()
    if self.phase == "clearing" then
        local p = self.plan
        for _, c in ipairs(p.cells) do
            self.board[c.y][c.x] = nil
        end
        for id, piece in pairs(p.created) do
            local c = cell(id)
            self.board[c.y][c.x] = piece
        end
        self.score = math.min(2147483647, self.score + p.gain)
        self.cleared, self.lastGain = self.cleared + p.count, p.gain
        self.bestCascade = math.max(self.bestCascade, self.cascade)
        self.lastResolution, self.plan, self.pending, self.phase = p, nil, nil, "falling"
    elseif self.phase == "falling" then
        local drops = self:Refill()
        local patterns = self:Patterns()
        if #patterns > 0 then
            self.cascade = self.cascade + 1
            self:Plan(patterns)
        else
            self:CheckEnd()
        end
        self.revision = self.revision + 1
        return drops
    else
        return
    end
    self.revision = self.revision + 1
end
