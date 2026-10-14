-- Pure engine checks; no WoW APIs required. Run: lua tests/tetris.lua
local Games = {}
assert(loadfile("KIC-Games/Games/Tetris/Engine.lua"))("KIC-Games", Games)
local E, tests = Games.Tetris.Engine, 0
local function check(value, message)
    assert(value, message)
    tests = tests + 1
end
local function new()
    return E.New(function(n)
        return n
    end)
end
local m = new()
local seen = { [m.kind] = true }
for i = 1, 6 do
    seen[m.queue[i]] = true
end
local count = 0
for _ in pairs(seen) do
    count = count + 1
end
check(count == 7, "Seven-bag did not contain every kind exactly once")
for _, kind in ipairs(E.Kinds) do
    local cells = E:Cells(kind, 0, 4, 3)
    local rotated = E:Cells(kind, 4, 4, 3)
    for i, c in ipairs(cells) do
        check(c[1] == rotated[i][1] and c[2] == rotated[i][2], "Four rotations changed shape")
    end
end
check(not m:Fits("I", 0, -1, 3) and not m:Fits("I", 0, 9, 3), "Horizontal bounds not enforced")
check(not m:Fits("O", 0, 5, 22) and not m:Fits("O", 0, 5, 0), "Vertical bounds not enforced")
m:Spawn("T")
m.rotation, m.x, m.y = 1, 0, 4
check(m:Fits(m.kind, m.rotation, m.x, m.y), "Wall-kick setup invalid")
check(m:Rotate(1) and m.x > 0, "Rotation did not kick away from wall")
m:Spawn("I")
local first = m.kind
check(m:Hold() and m.hold == first and not m.canHold, "Hold did not store current piece")
check(not m:Hold(), "Hold allowed twice before lock")
local drop = m:Ghost() - m.y
m:HardDrop()
check(m.score == drop * 2 and m.canHold, "Hard drop scoring or hold reset failed")
check(m:SoftDrop() and m.score == drop * 2 + 1, "Soft drop scoring failed")
for lines = 1, 4 do
    local c = new()
    for y = 23 - lines, 22 do
        for x = 1, 10 do
            c.board[y][x] = "J"
        end
    end
    c.board[22 - lines][1] = "Z"
    check(c:ClearLines() == lines, "Wrong line-clear count")
    check(c.score == ({ 100, 300, 500, 800 })[lines] and c.lines == lines, "Line scoring failed")
    check(c.board[22][1] == "Z" and not c.board[1][1], "Line compaction lost blocks")
end
m = new()
m.lines = 9
for x = 1, 10 do
    m.board[22][x] = "O"
end
m:ClearLines()
check(m.level == 2 and m.score == 100, "Level transition scored against wrong level")
for x = 1, 10 do
    m.board[22][x] = "O"
end
m:ClearLines()
check(m.score == 300, "Level multiplier failed")
m = new()
local y = m.y
for _ = 1, 4 do
    m:Update(0.2)
end
check(m.y == y + 1, "Gravity did not advance")
m.y = m:Ghost()
local locked = m.kind
m:Update(0.25)
check(not next(m.board[22]), "Piece locked before lock delay")
m:Update(0.25)
check(next(m.board[22]) ~= nil, "Piece did not lock after delay")
m = new()
m.board[2][5] = "Z"
m:Spawn("O")
check(m.gameover, "Spawn collision did not end game")
m = new()
m.board[1][1] = "Z"
m:HardDrop()
check(m.gameover, "Hidden-row top-out not detected")
m = new()
m.score = 2147483646
m:AddScore(100)
check(m.score == 2147483647, "Score exceeded framework limit")
math.randomseed(3421)
for _ = 1, 100 do
    local c = E.New()
    for _ = 1, 200 do
        if c.gameover then
            break
        end
        for _ = 1, math.random(0, 8) do
            c:Move(math.random(0, 1) * 2 - 1, 0)
            c:Rotate(math.random(0, 1) * 2 - 1)
        end
        if math.random(1, 4) == 1 then
            c:Hold()
        end
        c:HardDrop()
        for row = 1, 22 do
            for col, kind in pairs(c.board[row]) do
                check(col >= 1 and col <= 10 and E.Shapes[kind], "Random play wrote invalid board cells")
            end
        end
    end
end
print(string.format("PASS: %d Tetris engine assertions", tests))
