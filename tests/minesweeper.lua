-- Pure rules tests: lua tests/minesweeper.lua
local Games, checks = {}, 0
assert(loadfile("KIC-Games/Games/Minesweeper/Engine.lua"))("KIC-Games", Games)
local E = Games.Minesweeper.Engine
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local function coords(m, i)
    return (i - 1) % m.width + 1, math.floor((i - 1) / m.width) + 1
end
local function reveal(m, i)
    return m:Reveal(coords(m, i))
end

-- Every difficulty and every possible first square, including corners/edges.
for _, preset in ipairs(E.Difficulties) do
    for first = 1, preset.width * preset.height do
        local m = E.New(preset.id, function()
            return 1
        end)
        check(m.state == "ready" and m.revealed == 0, "Run must start unplaced")
        check(reveal(m, first), "First reveal rejected")
        check(not m.cells[first].mine and m.cells[first].count == 0, "First reveal is not an open safe square")
        local mines, revealed = 0, 0
        for i, cell in ipairs(m.cells) do
            if cell.mine then
                mines = mines + 1
            end
            if cell.revealed then
                check(not cell.mine and cell.mark == 0, "Flood exposed a mine or retained a mark")
                revealed = revealed + 1
            end
            local adjacent = 0
            m:Neighbors(i, function(_, neighbor)
                if neighbor.mine then
                    adjacent = adjacent + 1
                end
            end)
            check(adjacent == cell.count, "Adjacent count incorrect, possibly wrapped across an edge")
            if cell.revealed and cell.count == 0 then
                m:Neighbors(i, function(_, neighbor)
                    check(neighbor.revealed, "Zero flood did not reveal its boundary")
                end)
            end
        end
        check(mines == preset.mines and revealed == m.revealed, "Mine or reveal count incorrect")
        check(m.width == preset.width and m.height == preset.height, "Difficulty dimensions changed")
    end
end

local m = E.New("beginner", function()
    return 1
end)
check(m:CycleMark(9, 9) and m.cells[81].mark == 1 and m.flagged == 1, "First right click must flag")
check(not m:Reveal(9, 9) and m.state == "ready", "A flagged tile started/revealed the board")
check(m:CycleMark(9, 9) and m.cells[81].mark == 2 and m.flagged == 0, "Second click must question")
check(m:CycleMark(9, 9) and m.cells[81].mark == 0 and m.flagged == 0, "Third click must clear")
-- A flag blocks flood fill; question marks can be revealed and clear naturally.
m:CycleMark(1, 9)
m:CycleMark(2, 9)
m:CycleMark(2, 9)
m:Reveal(9, 9)
check(not m.cells[73].revealed and m.cells[73].mark == 1, "Flood ignored a flag")
check(m.cells[74].revealed and m.cells[74].mark == 0, "Flood did not clear a question mark")
check(not m:CycleMark(9, 9) and not m:Reveal(9, 9), "Revealed tiles accepted input")
for _, point in ipairs({ { 0, 1 }, { 10, 1 }, { 1, 10 }, { 1.5, 2 }, { 1, -1 } }) do
    check(not m:Reveal(point[1], point[2]) and not m:CycleMark(point[1], point[2]), "Invalid coordinates accepted")
end
for i, cell in ipairs(m.cells) do
    if cell.mine then
        check(reveal(m, i) and m.state == "lost" and m.detonated == i, "Mine did not end the run")
        break
    end
end
local count = m.revealed
check(not m:Reveal(1, 9) and not m:CycleMark(1, 9) and m.revealed == count, "Loss accepted more actions")

-- Win by revealing all safe tiles, without flagging any mine.
for _, preset in ipairs(E.Difficulties) do
    local rng = 42
    local function random(n)
        rng = (rng * 16807) % 2147483647
        return rng % n + 1
    end
    local won = E.New(preset.id, random)
    won:Reveal(1, 1)
    for i, cell in ipairs(won.cells) do
        if not cell.mine and not cell.revealed then
            reveal(won, i)
        end
    end
    check(won.state == "won" and won.revealed == #won.cells - won.mines and won.flagged == 0, "Safe tiles did not win")
    check(not won:CycleMark(1, 1) and not won:Reveal(1, 1), "Win accepted more actions")
end
check(E.New("unknown").difficulty == "beginner", "Unknown difficulty did not fall back")
print("PASS: Minesweeper rules, " .. checks .. " checks")
