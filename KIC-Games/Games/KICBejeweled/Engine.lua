local _, Games = ...
local Base = Games.Bejeweled.Engine
local E = setmetatable({}, { __index = Base })
E.__index = E
Games.KICBejeweled = { Engine = E }
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
    local p =
        { cells = {}, created = {}, events = {}, bonus = 0, activations = 0, longest = 3, blasts = {}, orbTargets = {} }
    local pieces, queued, queue, activated, protected = {}, {}, {}, {}, {}
    local run = self.roguelite
    p.cascade = self.cascade
    -- Plan can execute multiple times per swap due to cascades. Track once-per-
    -- move upgrade effects by actual engine move ID, not the UI frame counter.
    if run and run.engineMove ~= self.moves then
        run.engineMove = self.moves
        run.infernalUsed, run.thunderUsed = false, false
    end
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
        p.blasts[#p.blasts + 1] = { kind = "bomb", x = c.x, y = c.y, radius = radius }
        for y = c.y - radius, c.y + radius do
            for x = c.x - radius, c.x + radius do
                at(x, y)
            end
        end
    end
    local function cross(id, radius)
        local c = cell(id)
        p.blasts[#p.blasts + 1] = { kind = "lightning", x = c.x, y = c.y, radius = radius }
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
                p.orbTargets[id] = true
                hit(id)
            end
        end
    end
    local function randomExtra(rows, columns)
        for _ = 1, rows do
            local y = self.random(8)
            for x = 1, 8 do at(x, y) end
        end
        for _ = 1, columns do
            local x = self.random(8)
            for y = 1, 8 do at(x, y) end
        end
    end
    local function orbExtras(targetKind)
        if not run then return end
        if run:Stacks("spectrum_collapse") > 0 then
            local kinds = {}
            for k = 1, 7 do
                if k ~= targetKind then
                    for id = 1, 64 do
                        if E.Kind(pieces[id]) == k then
                            kinds[#kinds + 1] = k
                            break
                        end
                    end
                end
            end
            if #kinds > 0 then
                color(kinds[self.random(#kinds)])
            end
        end
        local dust = math.min(8, run:Stacks("prismatic_dust") * 3)
        if dust > 0 then
            local candidates = {}
            for id = 1, 64 do
                if pieces[id] and not queued[id] and not E.Special(pieces[id]) then
                    candidates[#candidates + 1] = id
                end
            end
            for _ = 1, math.min(dust, #candidates) do
                local index = self.random(#candidates)
                hit(table.remove(candidates, index))
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
        if run and run:Stacks("lucky_alignment") > 0 and g.cells[1] then
            local piece = pieces[g.cells[1]]
            if E.Kind(piece) == run:AttunedKind() then p.attunedMatch = true end
        end
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
                    p.orbTargets[id] = true
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
                if not special then
                    p.orbNormal = true
                    orbExtras(kind)
                    local echo = run and run:Stacks("prismatic_echo") or 0
                    local echoChance = echo > 0 and math.min(65, math.floor(65 * (1 - 0.7 ^ echo))) or 0
                    if echoChance > 0 and self.random(100) <= echoChance then
                        -- Keep the used Orb at its original board location;
                        -- it cannot trigger again in this resolution.
                        p.created[orb], protected[orb] = E.Orb, true
                    end
                end
            end
        else
            activate(a)
            activate(b)
            -- Direct special combos bypass the normal queue for their consumed
            -- inputs, but still qualify for one-shot roguelite augmentations.
            if run and run:Stacks("infernal_core") > 0 and not run.infernalUsed and
                (sa == "bomb" or sb == "bomb") then
                run.infernalUsed = true
                area(self.random(64), 1)
            end
            if run and (sa == "lightning" or sb == "lightning") then
                if run:Stacks("forked_strike") > 0 then
                    local count = (sa == "lightning" and 1 or 0) + (sb == "lightning" and 1 or 0)
                    for _ = 1, count * math.min(3, run:Stacks("forked_strike")) do
                        if self.random(2) == 1 then randomExtra(1, 0) else randomExtra(0, 1) end
                    end
                end
                if run:Stacks("thunder_god") > 0 and not run.thunderUsed then
                    run.thunderUsed = true
                    randomExtra(2, 2)
                end
            end
            if sa == "bomb" and sb == "bomb" then
                area(b, self.roguelite and self.roguelite:Stacks("volatile_fusion") > 0 and 3 or 2)
            else
                cross(b, 1)
            end
        end
    end
    -- Phase-2 wave effects operate on the same bounded clear queue. An extra
    -- cell is enqueued once, and all specials still use the existing one-shot
    -- activation guard. No extra gravity phase or recursive resolve is added.
    if run then
        local function proc(id, rate)
            local stacks = run:Stacks(id)
            return stacks > 0 and self.random(100) <= math.min(85, rate * stacks)
        end
        local function extraNormals(amount)
            local candidates = {}
            for i = 1, 64 do
                if pieces[i] and not queued[i] and not E.Special(pieces[i]) then
                    candidates[#candidates + 1] = i
                end
            end
            for _ = 1, math.min(amount, #candidates) do
                local index = self.random(#candidates)
                hit(table.remove(candidates, index))
            end
        end
        local hadBomb, hadLightning, hadOrb = false, false, false
        for _, id in ipairs(queue) do
            local special = E.Special(pieces[id])
            hadBomb = hadBomb or special == "bomb"
            hadLightning = hadLightning or special == "lightning"
            hadOrb = hadOrb or special == "orb"
        end
        if proc("echo_strike", 9) then extraNormals(math.min(4, 1 + math.floor((run:Stacks("echo_strike") - 1) / 3))) end
        if hadBomb and proc("aftershock", 12) then area(self.random(64), 1) end
        if hadLightning and proc("chain_surge", 12) then
            for _ = 1, math.min(2, math.ceil(run:Stacks("chain_surge") / 4)) do
                if self.random(2) == 1 then randomExtra(1, 0) else randomExtra(0, 1) end
            end
        end
        if hadOrb and proc("orb_afterimage", 8) then
            local colors = {}
            for kind = 1, 7 do
                for id = 1, 64 do
                    if E.Kind(pieces[id]) == kind and not queued[id] then
                        colors[#colors + 1] = kind
                        break
                    end
                end
            end
            if #colors > 0 then color(colors[self.random(#colors)]) end
        end
        if self.cascade > 1 and proc("fracture_wave", 10) then
            extraNormals(math.min(5, 1 + math.floor(run:Stacks("fracture_wave") / 3)))
        end
        if combination and proc("resonant_burst", 12) then area(self.random(64), 1) end
        if p.longest >= 4 and proc("shatterstorm", 10) then randomExtra(1, 0) end
        if #queue >= 8 and proc("crystal_echo", 10) then
            extraNormals(math.min(4, math.ceil(run:Stacks("crystal_echo") / 3)))
        end
    end
    local cursor = 1
    while cursor <= #queue do
        local id = queue[cursor]
        cursor = cursor + 1
        local special = activate(id)
        if special == "bomb" then
            area(id, run and run:Stacks("blast_radius") > 0 and 2 or 1)
            if run and run:Stacks("infernal_core") > 0 and not run.infernalUsed then
                run.infernalUsed = true
                area(self.random(64), 1)
            end
        elseif special == "lightning" then
            cross(id, run and run:Stacks("overload") > 0 and 1 or 0)
            if run and run:Stacks("forked_strike") > 0 then
                for _ = 1, math.min(3, run:Stacks("forked_strike")) do
                    if self.random(2) == 1 then randomExtra(1, 0) else randomExtra(0, 1) end
                end
            end
            if run and run:Stacks("thunder_god") > 0 and not run.thunderUsed then
                run.thunderUsed = true
                randomExtra(2, 2)
            end
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
    if run then
        local multiplier = math.min(1000000,
            run:SpecialScoreMultiplier(p.events, p.orbNormal) * run:ActivePowerScore(p, self.random))
        p.gain = p.gain * multiplier
    end
    -- Use the existing score ceiling to keep very deep roguelite runs finite.
    p.gain = math.floor(math.min(2147483647, p.gain) + 0.5)
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
    -- Commit accepted-move state before scoring its first wave. Invalid swaps
    -- never consume quick-swap timing or change the streak.
    if self.roguelite then
        self.roguelite:OnSwap()
        self.roguelite.inMove = true
        self.roguelite.trackedMoves = self.moves
    end
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

-- Only the KIC Bejeweled run with relevant manipulation upgrades changes refill
-- distribution. Existing original Bejeweled and early-run refill remain intact.
function E:Refill()
    local run = self.roguelite
    if not run or (run:Stacks("color_affinity") == 0 and run:Stacks("prism_filter") == 0) then
        return Base.Refill(self)
    end
    local drops = {}
    for x = 1, 8 do
        local write = 8
        for y = 8, 1, -1 do
            local piece = self.board[y][x]
            if piece then
                self.board[write][x] = piece
                if write ~= y then drops[(write - 1) * 8 + x] = y end
                write = write - 1
            end
        end
        for y = write, 1, -1 do
            self.board[y][x] = run:RollRefillKind(self.random, self.board)
            drops[(y - 1) * 8 + x] = y - write
        end
    end
    return drops
end

-- All manipulation powers operate on a settled board. Invalid proposals roll
-- back immediately: never introduce a spontaneous match or remove every move.
function E:TransmuteNormals(amount, target)
    if self.phase ~= "idle" or self.gameover then return 0 end
    local changed = 0
    for _ = 1, math.min(4, math.max(0, math.floor(amount or 0))) do
        local candidates = {}
        for y = 1, 8 do for x = 1, 8 do
            local piece = self.board[y][x]
            if piece and not E.Special(piece) and piece ~= target then
                candidates[#candidates + 1] = { x, y }
            end
        end end
        for _ = 1, math.min(32, #candidates) do
            local index = self.random(#candidates)
            local point = table.remove(candidates, index)
            local x, y = point[1], point[2]
            local old = self.board[y][x]
            local newKind = type(target) == "number" and target or self.random(7)
            if newKind == old then newKind = newKind % 7 + 1 end
            self.board[y][x] = newKind
            if #self:Patterns() == 0 and self:FindMove() then
                changed = changed + 1
                break
            end
            self.board[y][x] = old
        end
    end
    if changed > 0 then self.revision = self.revision + 1 end
    return changed
end
function E:ExchangeRandomNormals()
    if self.phase ~= "idle" or self.gameover then return false end
    local candidates = {}
    for y = 1, 8 do for x = 1, 8 do
        local piece = self.board[y][x]
        if piece and not E.Special(piece) then candidates[#candidates + 1] = { x, y } end
    end end
    if #candidates < 2 then return false end
    for _ = 1, 32 do
        local a, b = candidates[self.random(#candidates)], candidates[self.random(#candidates)]
        if (a[1] ~= b[1] or a[2] ~= b[2])
            and self.board[a[2]][a[1]] ~= self.board[b[2]][b[1]] then
            self:Exchange(a[1], a[2], b[1], b[2])
            if #self:Patterns() == 0 and self:FindMove() then
                self.revision = self.revision + 1
                return true
            end
            self:Exchange(a[1], a[2], b[1], b[2])
        end
    end
    return false
end

-- The draft's free alternative rearranges the existing pieces only. Keep
-- specials and their underlying gem kinds intact; do not change points, moves,
-- or other run state. A settled board must have no automatic match and must
-- offer at least one legal swap. All attempts are bounded and transactional.
function E:ReshuffleAll()
    self.lastShuffle = nil
    if self.phase ~= "idle" or self.gameover then
        return false
    end
    local original = self.board
    local pieces = {}
    for y = 1, 8 do
        for x = 1, 8 do
            local piece = original[y] and original[y][x]
            if not piece then
                return false
            end
            pieces[#pieces + 1] = piece
        end
    end
    for _ = 1, 256 do
        local mixed = {}
        local sourceByDestination = {}
        for i = 1, 64 do
            mixed[i] = pieces[i]
            sourceByDestination[i] = i
        end
        for i = 64, 2, -1 do
            local j = self.random(i)
            mixed[i], mixed[j] = mixed[j], mixed[i]
            sourceByDestination[i], sourceByDestination[j] = sourceByDestination[j], sourceByDestination[i]
        end
        local different = false
        for i = 1, 64 do
            if mixed[i] ~= pieces[i] then
                different = true
                break
            end
        end
        if different then
            local board = {}
            for y = 1, 8 do
                board[y] = {}
                for x = 1, 8 do
                    board[y][x] = mixed[(y - 1) * 8 + x]
                end
            end
            self.board = board
            if #self:Patterns() == 0 and self:FindMove() then
                self.revision = self.revision + 1
                self.lastResolution = nil
                -- Even identical gem types have unique source cells. Preserve
                -- their actual permutation for deterministic visual animation.
                self.lastShuffle = { sourceByDestination = sourceByDestination }
                return true
            end
        end
    end
    -- No eligible reshuffle was found. Leave everything exactly as it was;
    -- the player may still choose an upgrade or retry the reshuffle action.
    self.board = original
    return false
end

-- Post-resolution special creation for Arcane Rush upgrades. The underlying
-- gem kind is retained and only an eligible normal gem can be transformed.
-- This never starts another resolution or modifies the original Bejeweled engine.
function E:SpawnRandomSpecial(special)
    if self.phase ~= "idle" or self.gameover or (special ~= "bomb" and special ~= "lightning") then
        return false
    end
    local eligible = {}
    for y = 1, 8 do
        for x = 1, 8 do
            local piece = self.board[y][x]
            if piece and not E.Special(piece) then
                eligible[#eligible + 1] = { x, y }
            end
        end
    end
    if #eligible == 0 then
        return false
    end
    local chosen = eligible[self.random(#eligible)]
    local x, y = chosen[1], chosen[2]
    self.board[y][x] = E.Piece(E.Kind(self.board[y][x]), special)
    self.revision = self.revision + 1
    return true
end
