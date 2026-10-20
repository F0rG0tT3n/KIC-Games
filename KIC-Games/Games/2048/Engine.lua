local _, Games = ...
local G = { Engine = {} }
Games.Game2048 = G
local E = G.Engine
local Model = {}
Model.__index = Model
E.Size, E.Target = 4, 2048

local directions = {
    left = function(lane, offset)
        return (lane - 1) * 4 + offset
    end,
    right = function(lane, offset)
        return lane * 4 - offset + 1
    end,
    up = function(lane, offset)
        return (offset - 1) * 4 + lane
    end,
    down = function(lane, offset)
        return (4 - offset) * 4 + lane
    end,
}

function E.New(random)
    local m =
        setmetatable({ board = {}, score = 0, moves = 0, state = "playing", random = random or math.random }, Model)
    for i = 1, 16 do
        m.board[i] = 0
    end
    m:Spawn()
    m:Spawn()
    return m
end

function Model:Highest()
    local highest = 0
    for _, value in ipairs(self.board) do
        highest = math.max(highest, value)
    end
    return highest
end

function Model:Spawn()
    local empty = {}
    for i, value in ipairs(self.board) do
        if value == 0 then
            empty[#empty + 1] = i
        end
    end
    if #empty == 0 then
        return nil
    end
    local index = empty[self.random(#empty)]
    self.board[index] = self.random(10) == 1 and 4 or 2
    return index
end

function Model:CanMove()
    for i, value in ipairs(self.board) do
        if value == 0 or i % 4 ~= 0 and value == self.board[i + 1] or i <= 12 and value == self.board[i + 4] then
            return true
        end
    end
    return false
end

-- Compress from the leading edge, pairing original tiles only once per move.
-- Tracks retain the old tile values/positions for the UI's slide animation.
function Model:Move(direction)
    local at = directions[direction]
    if not at or self.state ~= "playing" then
        return false
    end
    local nextBoard, tracks, merged, gain = {}, {}, {}, 0
    for i = 1, 16 do
        nextBoard[i] = 0
    end
    for lane = 1, 4 do
        local values = {}
        for offset = 1, 4 do
            local index = at(lane, offset)
            if self.board[index] ~= 0 then
                values[#values + 1] = { index = index, value = self.board[index] }
            end
        end
        local source, output = 1, 1
        while source <= #values do
            local first, second = values[source], values[source + 1]
            local target = at(lane, output)
            local combine = second and first.value == second.value
            nextBoard[target] = first.value * (combine and 2 or 1)
            tracks[#tracks + 1] = { from = first.index, to = target, value = first.value }
            if combine then
                tracks[#tracks + 1] = { from = second.index, to = target, value = second.value }
                merged[target] = true
                gain = gain + nextBoard[target]
            end
            source, output = source + (combine and 2 or 1), output + 1
        end
    end
    local changed = false
    for i = 1, 16 do
        if nextBoard[i] ~= self.board[i] then
            changed = true
            break
        end
    end
    if not changed then
        return false
    end
    self.board, self.score, self.moves = nextBoard, self.score + gain, self.moves + 1
    local spawned = self:Spawn()
    if self:Highest() >= E.Target then
        self.state = "won"
    elseif not self:CanMove() then
        self.state = "lost"
    end
    self.lastMove = { tracks = tracks, merged = merged, spawned = spawned, gain = gain }
    return true
end
