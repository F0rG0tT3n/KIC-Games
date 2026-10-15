local previous = arg[1]
arg[1] = "--harness"
local harness = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = harness.client("SpecialEffects", "Realm")
local G, D = owner.games, owner.games.BejeweledDeluxe
local E, count = D.Engine, 0
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function reset()
    G:AbortGame()
    G:StartSingleplayer("bejeweled_deluxe")
    for y = 1, 8 do
        for x = 1, 8 do
            D.model.board[y][x] = (x + 2 * y) % 6 + 1
        end
    end
end
local function effect()
    local _, tier, length = D:MatchSoundEvent()
    D:StartMatchEffect(tier, length, D.model.pending, D.model.cascade, D.model.plan.gain)
end
local function hidden()
    check(not D.specialEffect, "Effect state leaked")
    for _, t in ipairs(D.specialTextures or {}) do
        check(not t:IsShown(), "Effect texture leaked")
    end
end
local function hit(kind, x, y)
    reset()
    D.model.board[y][x] = E.Piece(7, kind)
    D.model.cascade = 1
    D.model:Plan({ { cells = { (y - 1) * 8 + x }, longest = 3 } })
    effect()
end
for _, theme in ipairs({ "original", "class" }) do
    G:SetOption("graphicsTheme", theme)
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        reset()
        G.UI:SetWindowScale(scale)
        for x, special in ipairs({ "bomb", "lightning", "orb" }) do
            D.model.board[1][x] = E.Piece(x, special)
            D:Render()
            local cell = D.cells[x]
            check(not cell.deluxeArt.glow and #cell.deluxeArt.parts == 8, "Opaque overlay returned")
            for _, rail in ipairs(cell.deluxeArt.parts) do
                local point = rail.points[1]
                check(
                    point[2] == cell.icon
                        and math.max(math.abs(point[4]), math.abs(point[5])) >= (D.tileSize - 10) * 0.49,
                    "Rail covers center or detached from icon"
                )
                check(math.min(rail.width, rail.height) <= 1.5, "Border obscures icon")
            end
            check(cell.deluxeArt.label.points[1][5] < 0, "Badge overlaps icon center")
        end
    end
end
G:SetOption("effectsLevel", 2)
for _, center in ipairs({ { 1, 1 }, { 4, 4 }, { 8, 8 } }) do
    hit("bomb", center[1], center[2])
    local e = D.specialEffect
    check(#e.bombs == 1 and e.bombs[1].x == center[1] and e.bombs[1].radius == 1, "Bomb origin wrong")
    D:UpdateMatchEffect(0.15)
    check(D.specialTextureCount > 0 and D.effectFlash.alpha == 0, "Bomb effect missing or opaque flash")
    local before = D.specialTextures[1].points[1][4]
    D:UpdateMatchEffect(0.1)
    check(D.specialTextures[1].points[1][4] ~= before, "Explosion does not expand")
    check(D:GetClearDuration() == 0.65, "Bomb clears before effect")
end
hit("lightning", 3, 6)
check(D.specialEffect.rows[6] == 2.5 and D.specialEffect.columns[3] == 5.5, "Lightning misses actual row/column")
D:UpdateMatchEffect(0.3)
check(D.specialTextureCount == 32, "Lightning cross missing strokes")
reset()
D.model.board[4][4], D.model.board[4][5] = E.Orb, 3
check(D.model:Swap(4, 4, 5, 4), "Orb move rejected")
effect()
local targets = D.specialEffect.targets
for _, target in ipairs(targets) do
    check(E.Kind(D.model.board[math.floor(target.y) + 1][math.floor(target.x) + 1]) == 3, "Storm targets wrong color")
end
check(#targets > 1 and D:GetClearDuration() == 0.85, "Orb storm timing/targets missing")
D:UpdateMatchEffect(0.15)
check(D.specialTextureCount > 0, "Descending storm did not animate")
local e, phase = D.specialEffect, D.model.phase
D:Pause(true)
D:Advance(1)
check(e.time == 0.15 and D.model.phase == phase, "Pause advanced special effect")
D:Pause(false)
D:ClearMatchEffect()
hidden()
reset()
D.model.board[4][4], D.model.board[4][5] = E.Orb, E.Orb
D.model:Swap(4, 4, 5, 4)
effect()
check(#D.specialEffect.targets == 64, "Board-clear storm does not hit all cells")
D:UpdateMatchEffect(0.3)
check(D.specialTextureCount <= 1024 and D.specialTextureCount >= 512, "Storm texture budget or coverage wrong")
D:UpdateMatchEffect(0.05)
local poolSize = #D.specialTextures
D:UpdateMatchEffect(0.01)
check(#D.specialTextures == poolSize, "Effects allocate every frame")
G:SetOption("effectsLevel", 0)
hidden()
effect()
check(not D.specialEffect and D:GetClearDuration() == 0.3, "Effects Off changes visuals/timing incorrectly")
G:SetOption("effectsLevel", 1)
effect()
check(D.specialEffect.level == 1, "Subtle mode missing")
D:UpdateMatchEffect(0.3)
check(D.specialTextures[2].alpha < 0.4, "Subtle storm not reduced")
D:UpdateMatchEffect(2)
hidden()
G:SetOption("effectsLevel", 2)
hit("bomb", 4, 4)
D:UpdateMatchEffect(0.2)
D.pauseOverlay.restart.scripts.OnClick()
hidden()
hit("lightning", 3, 3)
D:UpdateMatchEffect(0.2)
G:AbortGame()
hidden()
-- Original Bejeweled keeps its old timing and has no new effect hooks.
check(not G.Bejeweled.GetClearDuration and not G.Bejeweled.specialTextures, "Original game got Deluxe effects")
print(string.format("PASS: %d Deluxe overlay and activation-effect assertions", count))
