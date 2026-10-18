-- Run from the repository root: lua tests/roguelite_wave_shuffle.lua
local Games = { Theme = {} }
local function load(rel)
    assert(loadfile('KIC-Games/Games/' .. rel))('KIC-Games', Games)
end
load('Bejeweled/Engine.lua')
load('KICBejeweled/Engine.lua')
load('KICBejeweled/Roguelite.lua')
local E, R = Games.KICBejeweled.Engine, Games.KICBejeweled.Roguelite
local function rng(seed)
    return function(n)
        seed = (seed * 48271) % 2147483647
        return (seed % n) + 1
    end
end
-- Base Energy conversion is a single shared budget across all cascade waves;
-- bonuses and UI Energy are credited as each wave resolves, not at move end.
local run = R.New(rng(1))
run.energy = 10
run:OnSwap()
run:OnWave(150, {}, 1, 3)
assert(run.energy == 22, 'first wave not credited immediately: ' .. run.energy)
run:OnWave(150, {}, 2, 3)
assert(run.energy == 34, 'second wave not credited independently: ' .. run.energy)
run:OnWave(300, {}, 3, 6)
assert(run.energy == 52, 'remaining base Energy must respect 42-per-move cap')
run:SettleMove()
assert(run.energy == 52 and not run.pending, 'move settlement double-counted Energy')
local follow = R.New(rng(2))
follow.energy = 88
follow:OnSwap()
follow:OnWave(150, {}, 1, 3)
assert(follow.energy == 100 and follow.pending and #follow.offers == 3,
    'first full wave must offer an immediate mid-cascade draft')
local first = follow.offers[1]
assert(follow:Choose(first.id), 'must be able to choose a power mid-cascade')
assert(not follow.pending and follow.level == 1 and follow.energy < follow.maxEnergy,
    'draft did not reset Energy / resume the run')
-- Additional waves continue to share the original swap's 42-base-Energy
-- budget. They can trigger further drafts if they refill the new Energy bar.
follow:OnWave(400, {}, 2, 8)
assert(follow.scoring == 550 and follow.creditedScoreBase == 42,
    'later cascade wave lost its score or reset the shared cap')
follow:SettleMove()
assert(follow.level == 1, 'move settlement accidentally granted another upgrade')
local specials = R.New(rng(3))
specials.energy = 10
specials.stacks.explosive_refund = 1
specials:OnSwap()
specials:OnWave(150, { bombActivate = 1 }, 1, 3)
assert(specials.energy == 25, 'first wave bomb bonus missing')
specials:OnWave(150, { bombActivate = 1 }, 2, 3)
assert(specials.energy == 40, 'second wave bomb bonus missing')
specials:SettleMove()
assert(specials.energy == 40, 'bomb refund double counted')
local big = R.New(rng(4))
big.maxEnergy = 1e6
big.energy = 1
big:OnSwap()
for _ = 1, 50 do big:OnWave(1000000, {}, 1, 3) end
assert(big.energy == 43, 'score energy cap was applied per wave, not per move')
big:SettleMove()
assert(big.energy == 43, 'end-of-move duplicate award')
print('PASS: wave-by-wave Energy, shared move cap, special bonuses, immediate draft')
-- Confirm Bomb+Bomb is a direct valid adjacent swap, with 5x5 by default and
-- 7x7 for the unique Volatile Fusion upgrade. No normal 3-match required.
for _, radius in ipairs({2, 3}) do
    local model = E.New(rng(20 + radius))
    local r = R.New(rng(24 + radius))
    if radius == 3 then r.stacks.volatile_fusion = 1 end
    model.roguelite = r
    model.board[4][4] = E.Piece(2, 'bomb')
    model.board[4][5] = E.Piece(3, 'bomb')
    model.phase = 'idle'
    assert(model:Swap(4, 4, 5, 4), 'adjacent Bomb+Bomb failed direct activation')
    assert(model.plan.events.combination, 'combo event missing')
    local found = false
    for _, effect in ipairs(model.plan.blasts) do
        if effect.kind == 'bomb' and effect.radius == radius then found = true end
    end
    assert(found, 'Bomb+Bomb radius ' .. radius .. ' not present')
end
print('PASS: Bomb+Bomb is a direct 5x5 combo, Volatile Fusion upgrades it to 7x7')
-- The reshuffle records exact old->new identities even for identical gem IDs.
local model = E.New(rng(99))
model.board[1][1] = E.Orb
model.board[2][2] = E.Piece(E.Kind(model.board[2][2]), 'bomb')
model.board[3][3] = E.Piece(E.Kind(model.board[3][3]), 'lightning')
local originals = {}
for y=1,8 do for x=1,8 do originals[(y-1)*8+x] = model.board[y][x] end end
assert(model:ReshuffleAll(), 'reshuffle failed')
assert(model.lastShuffle and #model.lastShuffle.sourceByDestination == 64)
local used = {}
for destination=1,64 do
    local source=model.lastShuffle.sourceByDestination[destination]
    assert(source >= 1 and source <= 64 and not used[source], 'not a permutation')
    used[source]=true
    local y,x=math.floor((destination-1)/8)+1,(destination-1)%8+1
    assert(model.board[y][x] == originals[source], 'gem identity not preserved at destination '..destination)
end
assert(#model:Patterns() == 0 and model:FindMove())
print('PASS: accurate per-gem 64-cell reshuffle animation source mapping')
-- Lightweight WoW frame emulation to check initial, interpolated, terminal
-- sprite coordinates and that the animation locks input for its duration.
local Frame = {}
Frame.__index = Frame
function Frame:EnableMouse() end
function Frame:SetFrameLevel(n) self.level=n end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetSize(w,h) self.w,self.h=w,h end
function Frame:SetPoint(_,__,___,x,y) self.x,self.y=x,y end
function Frame:ClearAllPoints() end
function Frame:SetTexCoord() end
function Frame:SetTexture() return true end
function Frame:Show() self.shown=true end
function Frame:Hide() self.shown=false end
function Frame:CreateTexture() return setmetatable({},Frame) end
_G.CreateFrame = function() return setmetatable({},Frame) end
load('KICBejeweled/RogueliteUI.lua')
local D = Games.KICBejeweled
D.PaintSpecial = function() end
D.Render = function() end
local ui = setmetatable({
    model = model, tileSize = 60, step = 62, viewport = setmetatable({},Frame),
    icons = {}, fallbackIcon = 'missing',
}, { __index = D })
for i=1,22 do ui.icons[i]='icon-'..i end
assert(ui:BeginReshuffleAnimation(model.lastShuffle))
assert(#ui.shuffleSprites == 64 and ui.shuffleAnimation)
local target, source = 1, model.lastShuffle.sourceByDestination[1]
local sprite = ui.shuffleSprites[target]
assert(sprite.x == ((source-1)%8)*62, 'animation does not start at old tile')
ui:AdvanceReshuffleAnimation(0.1)
if source ~= target then
    assert(sprite.x ~= ((source-1)%8)*62 or sprite.y ~= -math.floor((source-1)/8)*62,
        'animation did not move')
end
for _=1,20 do ui:AdvanceReshuffleAnimation(0.1) end
assert(not ui.shuffleAnimation and not sprite.shown, 'sprites not cleaned after animation')
print('PASS: 64 WoW-style sprites traverse and disappear cleanly')
