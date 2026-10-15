-- Run from the repository root: lua tests/bejeweled.lua
local Games = {}
assert(loadfile("KIC-Games/Games/Bejeweled/Engine.lua"))("KIC-Games", Games)
local E, tests = Games.Bejeweled.Engine, 0
local function check(value, message)
    assert(value, message)
    tests = tests + 1
end
local function plain()
    local m = E.New()
    for y = 1, 8 do
        for x = 1, 8 do
            m.board[y][x] = (x + 2 * y) % 7 + 1
        end
    end
    return m
end
local function playable()
    local m = plain()
    m.board[1][1], m.board[1][2], m.board[1][3], m.board[2][2] = 1, 2, 1, 1
    return m
end
local function digest(m)
    local rows = {}
    for _, row in ipairs(m.board) do
        rows[#rows + 1] = table.concat(row, ",")
    end
    return table.concat(rows, ";")
end
math.randomseed(104153)
for seed = 1, 100 do
    local m = E.New()
    check(#m:Matches() == 0, "Initial board contains free matches")
    local before = digest(m)
    local move = m:FindMove()
    check(move ~= nil, "Initial board has no move")
    check(digest(m) == before, "Hint search changed the board")
    for y = 1, 8 do
        for x = 1, 8 do
            check(m.board[y][x] >= 1 and m.board[y][x] <= 7, "Invalid generated gem")
        end
    end
end
local constant = E.New(function()
    return 1
end)
check(#constant:Matches() == 0 and constant:FindMove(), "Bounded RNG fallback did not make a playable board")
local m = plain()
check(m:FindMove() == nil, "No-move board was not recognized")
m:CheckEnd()
check(m.gameover and m.phase == "over", "No moves did not end the run")
check(not m:Swap(1, 1, 2, 1), "Ended run accepted a move")
m = playable()
check(#m:Matches() == 0, "Move fixture contains a preexisting match")
local before = digest(m)
for _, move in ipairs({
    { 0, 1, 1, 1 },
    { 1, 1, 1, 1 },
    { 1, 1, 2, 2 },
    { 1.5, 1, 2, 1 },
    { 1, 1, 9, 1 },
    { 8, 8, 7, 8 },
}) do
    check(not m:Swap(table.unpack(move)), "Invalid swap accepted")
    check(digest(m) == before and m.score == 0 and m.moves == 0, "Invalid swap changed the run")
end
check(m:Swap(2, 1, 2, 2), "Valid vertical swap was rejected")
check(m.phase == "clearing" and #m.pending == 3 and m.moves == 1, "Valid move did not schedule three gems")
check(not m:Swap(2, 1, 3, 1), "Input was accepted during a cascade")
m:Step()
check(m.score == 150 and m.cleared == 3 and m.bestCascade == 1, "Basic clear score or gem count is wrong")
check(m.board[1][1] == nil and m.board[1][2] == nil and m.board[1][3] == nil, "Matched gems were not removed")
m.random = function()
    return 1
end
local drops = m:Step()
check(drops[1] and drops[2] and drops[3], "Refill did not return falling-gem origins")
check(m.phase == "clearing" and m.cascade == 2, "Refill did not discover a chain reaction")
m:Step()
check(m.score == 450 and m.cleared == 6 and m.bestCascade == 2, "Cascade multiplier is wrong")
for count = 3, 5 do
    m = plain()
    for x = 1, count do
        m.board[1][x] = 6
    end
    check(#m:Matches() == count, "Long horizontal match detection is wrong")
end
m = plain()
for _, c in ipairs({ { 3, 4 }, { 4, 4 }, { 5, 4 }, { 4, 3 }, { 4, 5 } }) do
    m.board[c[2]][c[1]] = 7
end
check(#m:Matches() == 5, "Crossing matches double-counted the center")
m = plain()
local six, four = m.board[6][1], m.board[4][1]
m.board[5][1], m.board[7][1] = nil, nil
drops = m:Refill()
check(m.board[7][1] == six and m.board[6][1] == four, "Gravity changed gem ordering")
check(drops[(7 - 1) * 8 + 1] == 6 and drops[(6 - 1) * 8 + 1] == 4, "Fall animation origins are wrong")
m = playable()
m.score = 2147483640
m:Swap(2, 1, 2, 2)
m:Step()
check(m.score == 2147483647, "Score exceeded the saved/result limit")
-- Deterministic runs through real swaps, every clear/refill and game-over decisions.
for run = 1, 30 do
    local game = E.New()
    for move = 1, 30 do
        if game.gameover then
            break
        end
        local hint = game:FindMove()
        check(hint and game:Swap(hint.x, hint.y, hint.tx, hint.ty), "Hint was not a legal move")
        local steps = 0
        while game.phase == "clearing" or game.phase == "falling" do
            game:Step()
            steps = steps + 1
            check(steps < 200, "Cascade did not settle")
        end
        check(#game:Matches() == 0, "Settled board still has matches")
        check(game.moves == move, "Accepted move count is wrong")
        for y = 1, 8 do
            for x = 1, 8 do
                check(
                    type(game.board[y][x]) == "number" and game.board[y][x] >= 1 and game.board[y][x] <= 7,
                    "Refill left invalid cells"
                )
            end
        end
        check(game.gameover == (game:FindMove() == nil), "Game-over decision disagrees with move search")
    end
end
print(string.format("PASS: %d Bejeweled engine assertions", tests))
