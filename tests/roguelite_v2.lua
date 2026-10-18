-- Run from the repository root: lua tests/roguelite_v2.lua
local Games = {}
local root = 'KIC-Games/Games/'
local function load(rel)
  local fn= assert(loadfile(root..rel))
  fn('KIC-Games', Games)
end
load('Bejeweled/Engine.lua')
load('KICBejeweled/Engine.lua')
load('KICBejeweled/Roguelite.lua')
local R=Games.KICBejeweled.Roguelite
local E=Games.KICBejeweled.Engine
assert(#R.Cards == 75, 'card count')
local ids={}
for _,c in ipairs(R.Cards) do assert(not ids[c.id],c.id);ids[c.id]=true end
local r=R.New(function(n) return 1 end)
assert(r.maxEnergy==100 and r.energy==70)
assert(r:DrainRate()==4)
r.stacks.overclocked_battery=1
r.energy=100
r:DrawOffers()
-- Explicitly inspect energy max after selection with a synthetic draft.
r.pending=true; r.offers={R.ByID.overclocked_battery}
assert(r:Choose('overclocked_battery'))
assert(r.maxEnergy==200 and r.level==1)
assert(r:DrainRate() > 4)
local m=E.New(function(n) return 1 end)
m.roguelite=r
m.phase='idle';m.gameover=false
r.moves=10;r.stacks.chaos_theory=1;r.stacks.lucky_strike=1;r.stacks.gravity_rift=1
r.clearedThisMove=14
r:AfterMove(m)
local specials=0
for y=1,8 do for x=1,8 do if E.Special(m.board[y][x]) then specials=specials+1 end end end
assert(specials>=4, 'special spawn: '..specials)
-- Exercise planning with upgrades, including bounded extra blast/row effects.
local m2=E.New(function(n) return 1 end)
local run=R.New(function(n) return 1 end)
run.stacks.infernal_core=1;run.stacks.blast_radius=1; run.stacks.overload=1
run.stacks.forked_strike=1;run.stacks.thunder_god=1
m2.roguelite=run
m2.board[1][1]=E.Piece(1,'bomb');m2.board[1][2]=E.Piece(2,'lightning')
m2:Plan({{cells={1,2}, set={[1]=true,[2]=true}, longest=3}},nil,nil)
assert(m2.plan.count>0)
assert(run.infernalUsed and run.thunderUsed)
-- Orb keeps its identity if prismatic echo succeeds.
local m3=E.New(function(n) return 1 end)
local run3=R.New(function(n) return 1 end)
run3.stacks.prismatic_echo=1;run3.stacks.spectrum_collapse=1
run3.stacks.prismatic_dust=1;run3.stacks.orb_amplifier=1
m3.roguelite=run3; m3.cascade=1
m3.board[1][1]=E.Orb; m3.board[1][2]=2
m3:Plan({},nil,{1,2})
assert(m3.plan.created[1]==E.Orb)
assert(m3.plan.orbNormal and m3.plan.gain > 0)
-- Basic draft offer validity.
for level=0,20 do
 local a=R.New(function(n)return n end)
 a.level=level;a:DrawOffers()
 assert(#a.offers==3)
 local seen={}
 for _,v in ipairs(a.offers) do assert(not seen[v.id]); seen[v.id]=true end
end
print('PASS: 75 cards, Energy, upgrade selection, post-move spawns, bomb/lightning/orb plans')

-- Decay and one-time rescue are not allowed to run under paused/hidden state.
local survival = R.New(function(n) return 1 end)
survival.energy = 0.1
survival:Tick(0.25, false)
assert(survival.energy == 0.1 and not survival.over)
survival.stacks.second_wind = 1
assert(survival:Tick(0.25, true) == "second_wind")
assert(survival.energy == 35 and survival.secondWindUsed)
survival.energy = 0.1
assert(survival:Tick(0.25, true) == "depleted" and survival.over)
-- Max Energy capacity is capped, but overflow cards stay eligible and improve
-- score-to-Energy conversion; only unique relics disappear after acquisition.
local capped = R.New(function(n) return 1 end)
capped.maxEnergy = 200
capped.stacks.mana_capacitor = 12
capped.stacks.overclocked_battery = 4
assert(capped:CapacityOverflow() > 0 and capped:EnergyFactor() > 1)
capped:DrawOffers()
assert(#capped.offers == 3)
assert(R.ByID.mana_capacitor.max == math.huge)
-- Verify direct engine planning is bounded even when many specials are present.
local stress = E.New(function(n) return 1 end)
local abilities = R.New(function(n) return 1 end)
for _, key in ipairs({"infernal_core", "blast_radius", "overload", "forked_strike", "thunder_god"}) do
    abilities.stacks[key] = 1
end
stress.roguelite = abilities
stress.cascade = 1
for y=1,8 do for x=1,8 do
    stress.board[y][x] = E.Piece((x + y) % 7 + 1, (x + y) % 2 == 0 and "bomb" or "lightning")
end end
local targets={}
for i=1,64 do targets[i]=i end
stress:Plan({{cells=targets,set={},longest=3}},nil,nil)
assert(stress.plan.count <= 64 and stress.plan.activations <= 64)
print('PASS: depletion, Second Wind, max-cap offering and bounded 64-cell reaction')
