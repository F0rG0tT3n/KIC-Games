-- Run from repository root: lua tests/roguelite_integration.lua
local previous = arg[1]
arg[1] = "--harness"
local harness = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = harness.client("RushReview", "Realm", {
    kic_bejeweled = { best = { score = 987654, moves = 10, cleared = 30, bestCascade = 2 } },
})
local G, D = owner.games, owner.games.KICBejeweled
local E, R = D.Engine, D.Roguelite
local count = 0
local function check(value, message)
    assert(value, message)
    count = count + 1
end
check(G:StartSingleplayer("kic_bejeweled"), "Arcane Rush failed to start")
D:ChooseMode("roguelike")

-- Exercise the actual renderer, including retained art on a now-normal cell.
for i, special in ipairs({ "bomb", "lightning", "orb" }) do
    D.model.board[1][i] = E.Piece(i, special)
end
D:Render()
D.model.board[1][2] = 2
D:Render()
D.run.pending = true
D.run:DrawOffers()
local moves, score = D.model.moves, D.model.score
D:ReshuffleDraft()
check(D.shuffleAnimation and not D.run.pending, "Reshuffle did not start")
check(D:Blocked(), "Reshuffle did not lock input")
for _, cell in ipairs(D.cells) do
    check(not cell.icon:IsShown(), "Static icon visible during reshuffle")
    local art = cell.specialArt
    if art then
        check(not art.overlay:IsShown() and not art.glow:IsShown()
            and not art.backdrop:IsShown() and not art.label:IsShown(), "Static special layer leaked")
    end
end
local resetEnergy = D.run.energy
for _ = 1, 10 do
    if not D.shuffleAnimation then break end
    D:Advance(0.1)
end
check(not D.shuffleAnimation and not D:Blocked(), "Reshuffle failed to unlock input")
check(D.run.energy == resetEnergy and D.model.moves == moves and D.model.score == score,
    "Cosmetic reshuffle changed gameplay state")
for _, cell in ipairs(D.cells) do
    check(cell.icon:IsShown(), "Icon did not return after reshuffle")
    if cell.specialArt and cell.specialArt.special then
        check(cell.specialArt.overlay:IsShown(), "Special did not return after reshuffle")
    end
end

-- Check real frame rectangles at every supported interface scale.
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    G.UI:SetWindowScale(scale)
    local bottom = 0
    for _, frame in ipairs({ D.scorePanel, D.bestPanel, D.moveRow, D.clearedRow,
        D.cascadeRow, D.energyFrame, D.tipPanel }) do
        local top = -frame.points[1][3]
        check(top >= bottom, "Right-column panels overlap")
        bottom = top + frame:GetHeight()
    end
    check(bottom <= D.right:GetHeight(), "Right-column panels exceed available height")
    check(-D.energyHint.points[1][3] + D.energyHint:GetStringHeight() <= D.energyFrame:GetHeight(),
        "Energy hint exceeds its panel")
end

-- Legacy records remain preserved, while every current-mode surface agrees.
D.model.score = 1234
D:SaveBest()
check(G.DB.kic_bejeweled.best.score == 987654, "Legacy record overwritten")
check(D:Storage().best.score == 1234, "Rush score not saved separately")
G.UI:OpenLauncher("home")
G.UI:FeatureGame("kic_bejeweled")
check(G.UI:GetPersonalBest("kic_bejeweled").score == 1234
    and G.UI:GetPersonalBestMode("kic_bejeweled") == "Roguelike", "Launcher record provider exposes legacy record")
G.UI:ShowResults()
G.UI.resultGameID = "kic_bejeweled"
G.UI:RefreshResults()
check(G.UI.bestScore.text == "1234 points", "Results displays legacy record")
owner.grouped, owner.channel = true, "INSTANCE_CHAT"
D:ShareBest()
check(owner.chatMessages[#owner.chatMessages].message:find("1234", 1, true), "Share displays legacy record")
local reloaded = harness.client("RushReview", "Realm", G.DB).games
check(reloaded.UI:GetPersonalBest("kic_bejeweled").score == 1234
    and reloaded.DB.kic_bejeweled.best.score == 987654, "Reload lost score isolation")

local function rng(seed)
    return function(n)
        seed = (seed * 48271) % 2147483647
        return seed % n + 1
    end
end
local function board()
    local model = E.New(rng(79))
    for y = 1, 8 do for x = 1, 8 do model.board[y][x] = (x + 2 * y) % 7 + 1 end end
    model.board[1][1], model.board[1][2], model.board[1][3], model.board[2][2] = 1, 2, 1, 1
    return model
end
for _, case in ipairs({ { 1, 0, 158, 1 }, { 3, 5, 150, 0 } }) do
    local model, run = board(), R.New(rng(91))
    model.roguelite = run
    run.stacks.streak_keeper = 1
    run.readyFor, run.moveStreak = case[1], case[2]
    check(model:Swap(2, 1, 2, 2), "Fixture swap rejected")
    check(model.plan.gain == case[3] and run.moveStreak == case[4], "First wave uses stale streak")
    check(run.moves == 1 and run.trackedMoves == model.moves and run.inMove, "Move state not committed")
    G.UI:ShowGame()
    D:Pause(false)
    D.model, D.run = model, run
    D.swap, D.fall = nil, nil
    D:Advance(0)
    check(run.moves == 1 and run.moveStreak == case[4], "UI counted accepted swap twice")
end
local model, run = board(), R.New(rng(12))
model.roguelite = run
run.readyFor, run.moveStreak = 1, 4
check(not model:Swap(7, 8, 8, 8), "Fixture invalid swap accepted")
check(run.readyFor == 1 and run.moveStreak == 4 and run.moves == 0,
    "Invalid swap consumed streak/timing")

-- Fixed-target mutation must preserve gems already attuned, with real board
-- validation still enforcing no spontaneous matches and at least one move.
model = board()
local attuned = model.board[1][1]
local before, alreadyAttuned = {}, {}
for y = 1, 8 do
    before[y] = {}
    for x = 1, 8 do
        before[y][x] = model.board[y][x]
        if before[y][x] == attuned then alreadyAttuned[#alreadyAttuned + 1] = { x, y } end
    end
end
model.random = function() return 1 end
check(model:TransmuteNormals(4, attuned) > 0, "Magnet fixture made no changes")
for _, point in ipairs(alreadyAttuned) do
    check(model.board[point[2]][point[1]] == attuned, "Magnet recolored an already-attuned gem")
end
for y = 1, 8 do for x = 1, 8 do
    check(model.board[y][x] == before[y][x] or model.board[y][x] == attuned,
        "Magnet produced a different color")
end end
check(#model:Patterns() == 0 and model:FindMove(), "Magnet invalidated settled board")
print(string.format("PASS: %d roguelite renderer, layout, records and power regression assertions", count))
