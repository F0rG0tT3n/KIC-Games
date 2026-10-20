local Games, checks = {}, 0
assert(loadfile("KIC-Games/Games/2048/Engine.lua"))("KIC-Games", Games)
local E = Games.Game2048.Engine
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local function board(values, spawn)
    local m = E.New(function(n)
        return n
    end)
    for i = 1, 16 do
        m.board[i] = values[i] or 0
    end
    if not spawn then
        m.Spawn = function() end
    end
    return m
end
local function row(m, first, expected)
    for i, value in ipairs(expected) do
        check(m.board[first + i - 1] == value, "Wrong tile at " .. (first + i - 1))
    end
end
local cases = {
    { { 2, 2, 2, 2 }, { 4, 4, 0, 0 }, 8 },
    { { 2, 2, 4, 0 }, { 4, 4, 0, 0 }, 4 },
    { { 4, 0, 4, 4 }, { 8, 4, 0, 0 }, 8 },
    { { 2, 4, 4, 2 }, { 2, 8, 2, 0 }, 8 },
    { { 2, 0, 2, 2 }, { 4, 2, 0, 0 }, 4 },
}
for _, case in ipairs(cases) do
    local m = board(case[1])
    check(m:Move("left"), "Legal move rejected")
    row(m, 1, case[2])
    check(m.score == case[3] and m.moves == 1, "Score or move counter incorrect")
end
local m = board({ 2, 2, 4, 0 })
check(m:Move("right"), "Right failed")
row(m, 1, { 0, 0, 4, 4 })
check(m.score == 4, "Right merge chained")
m = board({ 2, 0, 0, 0, 2, 0, 0, 0, 4, 0, 0, 0, 4 })
check(m:Move("up"), "Up failed")
check(
    m.board[1] == 4 and m.board[5] == 8 and m.board[9] == 0 and m.board[13] == 0 and m.score == 12,
    "Up ordering/merges incorrect"
)
m = board({ 2, 0, 0, 0, 2, 0, 0, 0, 4, 0, 0, 0, 4 })
check(m:Move("down"), "Down failed")
check(
    m.board[1] == 0 and m.board[5] == 0 and m.board[9] == 4 and m.board[13] == 8 and m.score == 12,
    "Down ordering/merges incorrect"
)
m = board({ 2 })
local calls = 0
m.random = function(n)
    calls = calls + 1
    return n
end
check(
    not m:Move("left") and not m:Move("invalid") and calls == 0 and m.moves == 0 and m.score == 0,
    "Invalid moves changed the run or consumed RNG"
)
check(m.lastMove == nil, "No-op manufactured animation metadata")
local full = { 2, 4, 2, 4, 4, 2, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2 }
m = board(full)
check(not m:CanMove(), "Rows wrapped or diagonal tiles allowed a move")
m.board[16] = 0
check(m:CanMove(), "Empty square did not permit a move")
m.board[16] = 4
check(m:CanMove(), "Adjacent equal tiles did not permit a move")
m = board({ 1024, 1024 })
check(m:Move("left") and m.state == "won" and m:Highest() == 2048 and m.score == 2048, "2048 did not win")
check(not m:Move("right") and m.moves == 1, "Win accepted further input")
m = board({ 2, 2, 8, 16, 8, 16, 32, 64, 16, 32, 64, 128, 32, 64, 128, 256 }, true)
check(m:Move("left") and m.state == "lost" and not m:CanMove(), "Final spawn did not detect a blocked board")
check(not m:Move("right"), "Loss accepted further input")
local initial = E.New(function(n)
    return n == 10 and 1 or 1
end)
check(initial.board[1] == 4 and initial.board[2] == 4, "Spawn probability branch for 4 is broken")
initial = E.New(function(n)
    return n
end)
check(
    initial.board[16] == 2 and initial.board[15] == 2 and initial.score == 0,
    "Initial run does not have two unscored tiles"
)

local seed = 12345
local function random(n)
    seed = seed * 16807 % 2147483647
    return seed % n + 1
end
for _ = 1, 250 do
    local values = {}
    for i = 1, 16 do
        values[i] = random(4) == 1 and 0 or 2 ^ random(6)
    end
    for _, direction in ipairs({ "left", "right", "up", "down" }) do
        local model = board(values, true)
        model.random = random
        local sum, tiles = 0, 0
        for _, value in ipairs(values) do
            sum = sum + value
            if value > 0 then
                tiles = tiles + 1
            end
        end
        local changed = model:Move(direction)
        local after = 0
        for _, value in ipairs(model.board) do
            after = after + value
        end
        if changed then
            local last = model.lastMove
            check(after == sum + model.board[last.spawned], "Move lost tile mass")
            check(model.board[last.spawned] == 2 or model.board[last.spawned] == 4, "Invalid spawned value")
            check(
                #last.tracks == tiles and model.score == last.gain and model.moves == 1,
                "Animation/score state mismatched rules"
            )
            local seen = {}
            for _, track in ipairs(last.tracks) do
                check(
                    not seen[track.from] and track.value == values[track.from] and track.to >= 1 and track.to <= 16,
                    "Invalid slide track"
                )
                seen[track.from] = true
            end
        else
            check(after == sum and model.moves == 0 and model.score == 0, "No-op mutated board")
        end
    end
end
print("PASS: 2048 rules and slide metadata, " .. checks .. " checks")
