local _, Games = ...
Games.Bejeweled = {}
local B, E = Games.Bejeweled, {}
B.Engine, E.__index = E, E
E.Size, E.Kinds = 8, 7

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
function E:Matches()
    local found, cells = {}, {}
    local function add(x, y)
        local key = (y - 1) * 8 + x
        if not found[key] then
            found[key] = true
            cells[#cells + 1] = { x = x, y = y }
        end
    end
    for y = 1, 8 do
        local x = 1
        while x <= 8 do
            local finish, kind = x, self.board[y][x]
            while finish < 8 and kind and self.board[y][finish + 1] == kind do
                finish = finish + 1
            end
            if kind and finish - x >= 2 then
                for col = x, finish do
                    add(col, y)
                end
            end
            x = finish + 1
        end
    end
    for x = 1, 8 do
        local y = 1
        while y <= 8 do
            local finish, kind = y, self.board[y][x]
            while finish < 8 and kind and self.board[finish + 1][x] == kind do
                finish = finish + 1
            end
            if kind and finish - y >= 2 then
                for row = y, finish do
                    add(x, row)
                end
            end
            y = finish + 1
        end
    end
    return cells
end
function E:Exchange(x, y, tx, ty)
    self.board[y][x], self.board[ty][tx] = self.board[ty][tx], self.board[y][x]
end
function E:FindMove()
    for y = 1, 8 do
        for x = 1, 8 do
            for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
                local tx, ty = x + d[1], y + d[2]
                if inside(tx, ty) and self.board[y][x] ~= self.board[ty][tx] then
                    self:Exchange(x, y, tx, ty)
                    local matched = #self:Matches() > 0
                    self:Exchange(x, y, tx, ty)
                    if matched then
                        return { x = x, y = y, tx = tx, ty = ty }
                    end
                end
            end
        end
    end
end
function E:Generate(forced)
    self.board = {}
    for y = 1, 8 do
        self.board[y] = {}
        for x = 1, 8 do
            local options = {}
            for kind = 1, 7 do
                if
                    not (x > 2 and self.board[y][x - 1] == kind and self.board[y][x - 2] == kind)
                    and not (y > 2 and self.board[y - 1][x] == kind and self.board[y - 2][x] == kind)
                then
                    options[#options + 1] = kind
                end
            end
            local fixed = forced
                and (
                    (y == 1 and x == 1 and 1)
                    or (y == 1 and x == 2 and 2)
                    or (y == 1 and x == 3 and 1)
                    or (y == 2 and x == 2 and 1)
                )
            self.board[y][x] = fixed or options[self.random(#options)]
        end
    end
end
function E.New(random)
    local self = setmetatable({
        random = random or math.random,
        score = 0,
        moves = 0,
        cleared = 0,
        cascade = 0,
        bestCascade = 0,
        phase = "idle",
        revision = 0,
        gameover = false,
    }, E)
    for _ = 1, 20 do
        self:Generate()
        if self:FindMove() then
            return self
        end
    end
    -- Bounded fallback for unusual RNGs: a guaranteed opening move, without starting matches.
    self:Generate(true)
    return self
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
    self:Exchange(x, y, tx, ty)
    local matches = self:Matches()
    if #matches == 0 then
        self:Exchange(x, y, tx, ty)
        return false
    end
    self.moves, self.cascade, self.pending, self.phase = self.moves + 1, 1, matches, "clearing"
    self.revision = self.revision + 1
    return true
end
function E:Refill()
    local drops = {}
    for x = 1, 8 do
        local write = 8
        for y = 8, 1, -1 do
            local kind = self.board[y][x]
            if kind then
                self.board[write][x] = kind
                if write ~= y then
                    drops[(write - 1) * 8 + x] = y
                end
                write = write - 1
            end
        end
        for y = write, 1, -1 do
            self.board[y][x] = self.random(7)
            drops[(y - 1) * 8 + x] = y - write
        end
    end
    return drops
end
function E:CheckEnd()
    self.gameover = self:FindMove() == nil
    self.phase = self.gameover and "over" or "idle"
end
function E:Step()
    if self.phase == "clearing" then
        local count = #self.pending
        for _, c in ipairs(self.pending) do
            self.board[c.y][c.x] = nil
        end
        self.score = math.min(2147483647, self.score + count * 50 * self.cascade)
        self.cleared = self.cleared + count
        self.bestCascade = math.max(self.bestCascade, self.cascade)
        self.lastGain = count * 50 * self.cascade
        self.pending, self.phase = nil, "falling"
    elseif self.phase == "falling" then
        local drops = self:Refill()
        local matches = self:Matches()
        if #matches > 0 then
            self.cascade, self.pending, self.phase = self.cascade + 1, matches, "clearing"
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
