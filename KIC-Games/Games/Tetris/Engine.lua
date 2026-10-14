local _, Games = ...
Games.Tetris = {}
local T = Games.Tetris
local E = {}
E.__index = E
T.Engine = E
E.Width, E.Height, E.Hidden = 10, 22, 2
E.Shapes = {
    I = { size = 4, { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } },
    J = { size = 3, { 0, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },
    L = { size = 3, { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },
    O = { size = 2, { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
    S = { size = 3, { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } },
    T = { size = 3, { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },
    Z = { size = 3, { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } },
}
E.Kinds = { "I", "J", "L", "O", "S", "T", "Z" }

function E:Cells(kind, rotation, x, y)
    local shape, cells = self.Shapes[kind], {}
    for i, cell in ipairs(shape) do
        local cx, cy = cell[1], cell[2]
        for _ = 1, kind == "O" and 0 or rotation % 4 do
            cx, cy = shape.size - 1 - cy, cx
        end
        cells[i] = { x + cx, y + cy }
    end
    return cells
end

function E:Fits(kind, rotation, x, y)
    for _, c in ipairs(self:Cells(kind, rotation, x, y)) do
        if c[1] < 1 or c[1] > self.Width or c[2] < 1 or c[2] > self.Height or self.board[c[2]][c[1]] then
            return false
        end
    end
    return true
end

function E:FillQueue()
    while #self.queue < 6 do
        local bag = {}
        for i, kind in ipairs(self.Kinds) do
            bag[i] = kind
        end
        for i = #bag, 2, -1 do
            local j = self.random(i)
            bag[i], bag[j] = bag[j], bag[i]
        end
        for _, kind in ipairs(bag) do
            self.queue[#self.queue + 1] = kind
        end
    end
end

function E:Spawn(kind)
    if not kind then
        self:FillQueue()
        kind = table.remove(self.queue, 1)
        self:FillQueue()
    end
    self.kind, self.rotation, self.x, self.y = kind, 0, kind == "O" and 5 or 4, 2
    self.fall, self.lockTime, self.resets = 0, 0, 0
    self.gameover = not self:Fits(kind, 0, self.x, self.y)
    self.revision = self.revision + 1
end

function E.New(random)
    local self = setmetatable({
        board = {},
        queue = {},
        random = random or math.random,
        score = 0,
        lines = 0,
        level = 1,
        revision = 0,
        canHold = true,
    }, E)
    for y = 1, E.Height do
        self.board[y] = {}
    end
    self:Spawn()
    return self
end

function E:AddScore(points)
    self.score = math.min(2147483647, self.score + points)
    self.revision = self.revision + 1
end

function E:Grounded()
    return not self:Fits(self.kind, self.rotation, self.x, self.y + 1)
end

function E:Move(dx, dy)
    if self.gameover or not self:Fits(self.kind, self.rotation, self.x + dx, self.y + dy) then
        return false
    end
    local grounded = self:Grounded()
    self.x, self.y = self.x + dx, self.y + dy
    if grounded and dx ~= 0 and self.resets < 15 then
        self.lockTime, self.resets = 0, self.resets + 1
    elseif dy > 0 then
        self.lockTime = 0
    end
    self.revision = self.revision + 1
    return true
end

function E:Rotate(direction)
    if self.gameover or self.kind == "O" then
        return false
    end
    local rotation = (self.rotation + direction) % 4
    -- Small wall/floor kicks; deliberately not the full SRS ruleset.
    for _, kick in ipairs({
        { 0, 0 },
        { -1, 0 },
        { 1, 0 },
        { -2, 0 },
        { 2, 0 },
        { 0, -1 },
        { -1, -1 },
        { 1, -1 },
        {
            0,
            -2,
        },
    }) do
        if self:Fits(self.kind, rotation, self.x + kick[1], self.y + kick[2]) then
            if self:Grounded() and self.resets < 15 then
                self.lockTime, self.resets = 0, self.resets + 1
            end
            self.rotation, self.x, self.y = rotation, self.x + kick[1], self.y + kick[2]
            self.revision = self.revision + 1
            return true
        end
    end
    return false
end

function E:Ghost()
    local y = self.y
    while self:Fits(self.kind, self.rotation, self.x, y + 1) do
        y = y + 1
    end
    return y
end

function E:ClearLines()
    local kept, count = {}, 0
    for y = self.Height, 1, -1 do
        local full = true
        for x = 1, self.Width do
            if not self.board[y][x] then
                full = false
                break
            end
        end
        if full then
            count = count + 1
        else
            table.insert(kept, 1, self.board[y])
        end
    end
    while #kept < self.Height do
        table.insert(kept, 1, {})
    end
    self.board = kept
    if count > 0 then
        self:AddScore(({ 100, 300, 500, 800 })[count] * self.level)
        self.lines = self.lines + count
        self.level = math.floor(self.lines / 10) + 1
    end
    return count
end

function E:Lock()
    if self.gameover then
        return
    end
    for _, c in ipairs(self:Cells(self.kind, self.rotation, self.x, self.y)) do
        self.board[c[2]][c[1]] = self.kind
    end
    self:ClearLines()
    self.canHold = true
    for y = 1, self.Hidden do
        if next(self.board[y]) then
            self.gameover = true
            self.revision = self.revision + 1
            return
        end
    end
    self:Spawn()
end

function E:SoftDrop()
    if self:Move(0, 1) then
        self:AddScore(1)
        return true
    end
    return false
end

function E:HardDrop()
    if self.gameover then
        return
    end
    local y = self:Ghost()
    self:AddScore((y - self.y) * 2)
    self.y = y
    self:Lock()
end

function E:Hold()
    if self.gameover or not self.canHold then
        return false
    end
    local old = self.hold
    self.hold = self.kind
    self:Spawn(old)
    self.canHold = false
    return true
end

function E:Update(dt)
    if self.gameover then
        return
    end
    dt = math.min(math.max(dt, 0), 0.25)
    local grounded = self:Grounded()
    self.fall = self.fall + dt
    local interval = math.max(0.065, 0.8 * 0.85 ^ (self.level - 1))
    while self.fall >= interval do
        self.fall = self.fall - interval
        if not self:Move(0, 1) then
            break
        end
    end
    if self:Grounded() then
        self.lockTime = self.lockTime + (grounded and dt or 0)
        if self.lockTime >= 0.5 then
            self:Lock()
        end
    else
        self.lockTime = 0
    end
end
