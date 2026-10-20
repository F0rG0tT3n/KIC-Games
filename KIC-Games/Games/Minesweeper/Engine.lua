local _, Games = ...
local M = { Engine = {} }
Games.Minesweeper = M
local E = M.Engine
E.Difficulties = {
    { id = "beginner", title = "Beginner", width = 9, height = 9, mines = 10 },
    { id = "intermediate", title = "Intermediate", width = 16, height = 16, mines = 40 },
    { id = "expert", title = "Expert", width = 30, height = 16, mines = 99 },
}
E.ByID = {}
for _, difficulty in ipairs(E.Difficulties) do
    E.ByID[difficulty.id] = difficulty
end
local Model = {}
Model.__index = Model

function E.New(difficulty, random)
    local preset = E.ByID[difficulty] or E.ByID.beginner
    local m = setmetatable({
        difficulty = preset.id,
        width = preset.width,
        height = preset.height,
        mines = preset.mines,
        cells = {},
        revealed = 0,
        flagged = 0,
        state = "ready",
        random = random or math.random,
    }, Model)
    for i = 1, m.width * m.height do
        m.cells[i] = { mine = false, count = 0, revealed = false, mark = 0 }
    end
    return m
end

function Model:Index(x, y)
    if
        type(x) == "number"
        and type(y) == "number"
        and x % 1 == 0
        and y % 1 == 0
        and x >= 1
        and x <= self.width
        and y >= 1
        and y <= self.height
    then
        return (y - 1) * self.width + x
    end
end

function Model:Neighbors(index, callback)
    local x, y = (index - 1) % self.width + 1, math.floor((index - 1) / self.width) + 1
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local neighbor = self:Index(x + dx, y + dy)
                if neighbor then
                    callback(neighbor, self.cells[neighbor])
                end
            end
        end
    end
end

-- Defer placement until the first reveal. Its entire neighborhood is safe,
-- giving every run an open starting area without rerolling an existing board.
function Model:Place(first)
    local excluded, available = { [first] = true }, {}
    self:Neighbors(first, function(i)
        excluded[i] = true
    end)
    for i = 1, #self.cells do
        if not excluded[i] then
            available[#available + 1] = i
        end
    end
    for i = 1, self.mines do
        local j = i - 1 + self.random(#available - i + 1)
        available[i], available[j] = available[j], available[i]
        self.cells[available[i]].mine = true
    end
    for i, cell in ipairs(self.cells) do
        if cell.mine then
            self:Neighbors(i, function(_, neighbor)
                neighbor.count = neighbor.count + 1
            end)
        end
    end
    self.state = "playing"
end

function Model:CycleMark(x, y)
    local index = self:Index(x, y)
    local cell = index and self.cells[index]
    if not cell or cell.revealed or self.state == "won" or self.state == "lost" then
        return false
    end
    if cell.mark == 1 then
        self.flagged = self.flagged - 1
    end
    cell.mark = (cell.mark + 1) % 3
    if cell.mark == 1 then
        self.flagged = self.flagged + 1
    end
    return true
end

function Model:Reveal(x, y)
    local index = self:Index(x, y)
    local cell = index and self.cells[index]
    if not cell or cell.revealed or cell.mark == 1 or self.state == "won" or self.state == "lost" then
        return false
    end
    if self.state == "ready" then
        self:Place(index)
    end
    if cell.mine then
        cell.revealed, cell.mark = true, 0
        self.state, self.detonated = "lost", index
        return true
    end
    -- Queue each square once; iterative flood fill avoids a deep Lua call stack.
    local queue, queued, head = { index }, { [index] = true }, 1
    while head <= #queue do
        local i = queue[head]
        head = head + 1
        local current = self.cells[i]
        if not current.revealed and current.mark ~= 1 and not current.mine then
            current.revealed, current.mark = true, 0
            self.revealed = self.revealed + 1
            if current.count == 0 then
                self:Neighbors(i, function(nextIndex, neighbor)
                    if not queued[nextIndex] and not neighbor.revealed and neighbor.mark ~= 1 and not neighbor.mine then
                        queued[nextIndex] = true
                        queue[#queue + 1] = nextIndex
                    end
                end)
            end
        end
    end
    if self.revealed == #self.cells - self.mines then
        self.state = "won"
    end
    return true
end
