-- Run from the repository root: lua tests/roguelite_stacking_phase1.lua
local Games = {}
local function load(rel)
    assert(loadfile('KIC-Games/Games/' .. rel))('KIC-Games', Games)
end
load('Bejeweled/Engine.lua')
load('KICBejeweled/Engine.lua')
load('KICBejeweled/Roguelite.lua')
local E, R = Games.KICBejeweled.Engine, Games.KICBejeweled.Roguelite
local function near(a,b) assert(math.abs(a-b) < 0.000001, tostring(a)..' vs '..tostring(b)) end
local unique, repeatable, ids = 0, 0, {}
for _, card in ipairs(R.Cards) do
    assert(not ids[card.id]); ids[card.id] = true
    if card.max == math.huge then repeatable = repeatable + 1 else
        assert(card.max == 1); unique = unique + 1
    end
    assert(card.title and card.description and card.rarity)
    assert(card.stackMode == (card.max == math.huge and 'repeatable' or 'unique'))
end
assert(#R.Cards == 75 and repeatable == 69 and unique == 6)

local run = R.New(function(n) return 1 end)
run.stacks.mana_capacitor = 5
run.stacks.overclocked_battery = 1
run.maxEnergy = 200
near(run:CapacityOverflow(), 50)
local beforeGain = run:EnergyFactor()
run.stacks.mana_capacitor = 6
assert(run:EnergyFactor() > beforeGain, 'capacity overflow provides no gain')
local previous = run:DrainRate()
for stack = 1, 80 do
    run.stacks.time_bender = stack
    local rate = run:DrainRate()
    assert(rate >= 1 and rate < previous, 'time bender did not improve drain')
    previous = rate
end
run.stacks.capacitor_recovery=10
near(run:RecoveryFraction(), 0.8)
run.pending=true;run.offers={R.ByID.mana_capacitor}
assert(run:Choose('mana_capacitor') and run.maxEnergy == 200)
near(run.energy, 160)
assert(run:Stacks('mana_capacitor') == 7)

local sample = R.New(function(n) return n end)
for _, card in ipairs(R.Cards) do
    sample.stacks[card.id] = card.max == math.huge and 250 or 1
end
sample:DrawOffers()
assert(#sample.offers == 3, 'draft exhausted with 250 stacks')
for _, card in ipairs(sample.offers) do assert(card.max == math.huge) end

local stable = R.New(function(n) return 1 end)
local baseline = stable:EnergyFactor()
stable.stacks.adrenaline=10
assert(stable:EnergyFactor() > baseline)
stable.stacks.quick_hands=25
assert(stable:EnergyFactor() > baseline + 1)
stable.stacks.reckless_rush=12
assert(stable:DrainRate() > 4 and stable:EnergyFactor() > 3)
stable.energy=1; stable.stacks.last_stand=20
assert(stable:EnergyFactor() > 10)

local fake = { counts = {bomb=0, lightning=0} }
function fake:SpawnRandomSpecial(kind)
    self.counts[kind] = self.counts[kind] + 1
    return true
end
local factory = R.New(function(n) return 1 end)
factory.stacks.bomb_factory=100
factory.stacks.static_charge=100
factory.stacks.lucky_strike=100
factory.moves=1
factory:AfterMove(fake)
assert(fake.counts.bomb <= 3 and fake.counts.lightning <= 3, 'unbounded per-move special generation')
assert(fake.counts.bomb + fake.counts.lightning == 6, 'global per-move spawn budget not enforced')
for i=2,60 do factory.moves=i;factory:AfterMove(fake) end
assert(fake.counts.bomb + fake.counts.lightning <= 6 * 60)

local bounded = R.New(function(n) return 1 end)
for _, key in ipairs({'bomb_factory','static_charge','shrapnel','blast_radius','overload',
    'forked_strike','stormcaller','prismatic_dust','prismatic_echo','orb_amplifier'}) do
    bounded.stacks[key] = 50
end
assert(bounded:SpecialScoreMultiplier({ bombActivate=1 },false)>1)
assert(bounded:SpecialScoreMultiplier({ lightningActivate=1 },false)>1)
assert(bounded:SpecialScoreMultiplier({ orbActivate=1 },true)>50)

local model=E.New(function(n) return 1 end)
model.roguelite=bounded
model.cascade=1
model.board[1][1]=E.Piece(1,'bomb')
model.board[1][2]=E.Piece(2,'lightning')
model:Plan({{cells={1,2},set={[1]=true,[2]=true},longest=3}},nil,nil)
assert(model.plan.count<=64 and model.plan.activations<=64 and model.plan.gain>=0)
local bomb = E.New(function(n) return 1 end)
bomb.roguelite=bounded
bomb.cascade=1
bomb.board[4][4]=E.Piece(1,'bomb')
bomb:Plan({{cells={28},set={[28]=true},longest=3}},nil,nil)
local found=false
for _, b in ipairs(bomb.plan.blasts) do
    if b.kind=='bomb' then assert(b.radius==2);found=true end
end
assert(found,'blast radius cap must be 5x5')

local orb=E.New(function(n) return 1 end)
orb.roguelite=bounded
orb.cascade=1
orb.board[1][1]=E.Orb
orb.board[1][2]=1
orb:Plan({},nil,{1,2})
assert(orb.plan.count<=64 and orb.plan.gain>=0)

-- Scoring still produces an identifiable resolution after the 32-bit score
-- ceiling, so the UI can grant Energy from wave.gain instead of score delta.
local cappedScore=E.New(function(n) return 1 end)
cappedScore.score=2147483647
cappedScore.cascade=1
cappedScore:Plan({{cells={1,2,3},set={[1]=true,[2]=true,[3]=true},longest=3}},nil,nil)
cappedScore:Step()
assert(cappedScore.score==2147483647 and cappedScore.lastResolution.gain>0)
local scored = R.New(function(n) return 1 end)
scored.energy = 40
scored:OnWave(cappedScore.lastResolution.gain,cappedScore.lastResolution.events,1,cappedScore.lastResolution.count)
scored:SettleMove()
assert(scored.energy>40,'scoring cannot earn Energy at cap')

local depleted=R.New(function(n) return 1 end)
depleted.stacks.time_bender=200
assert(depleted:DrainRate()>=1)
depleted.energy=0.01
assert(depleted:Tick(0.25,true)=='depleted')
assert(depleted.over)
print('PASS: 75 cards (69 repeatable, 6 unique), 250-stack draft, energy cap overflow')
print('PASS: diminishing drain, progressive scoring, controlled special spawning')
print('PASS: 5x5 Bomb cap, bounded 8x8 effects, 0 Energy still ends the run')
