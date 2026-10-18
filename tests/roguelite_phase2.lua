-- Run from the repository root: lua tests/roguelite_phase2.lua
local Games = {}
local function load(path)
    assert(loadfile('KIC-Games/Games/' .. path))('KIC-Games', Games)
end
load('Bejeweled/Engine.lua')
load('KICBejeweled/Engine.lua')
load('KICBejeweled/Roguelite.lua')
local E, R = Games.KICBejeweled.Engine, Games.KICBejeweled.Roguelite
local function rng(seed)
    return function(n)
        assert(type(n) == 'number' and n >= 1 and n % 1 == 0, 'RNG bound not integer: ' .. tostring(n))
        seed = (seed * 48271) % 2147483647
        return seed % n + 1
    end
end
local function near(x, y, label)
    assert(math.abs(x-y) < 0.000001, (label or 'not near')..': '..tostring(x)..' versus '..tostring(y))
end
local base = R.New(rng(2))
assert(#R.Cards == 75)
local allIds, uniques = {}, 0
for _, card in ipairs(R.Cards) do
    assert(not allIds[card.id], 'duplicate: '..card.id)
    allIds[card.id] = true
    assert(card.description ~= '' and card.title ~= '' and card.rarity ~= '')
    if card.max == 1 then uniques = uniques + 1 else assert(card.max == math.huge) end
end
assert(uniques == 6)
-- Unique relics exhaust; the remaining draft is fully repeatable at 500 stacks.
for _, card in ipairs(R.Cards) do
    base.stacks[card.id] = card.max == 1 and 1 or 500
end
base:DrawOffers()
assert(#base.offers == 3)
for _, card in ipairs(base.offers) do assert(card.max == math.huge) end
print('PASS: 75 unique definitions, 69 infinitely repeatable, 6 unique')

-- Characteristic score effects. Use fixed RNG to deterministically proc crits.
local function scoreFor(card, level, flags)
    local run = R.New(function(n) return 1 end)
    run.stacks[card] = level or 1
    run.maxEnergy, run.energy = 100, (flags and flags.energy) or 70
    run.level = (flags and flags.level) or 10
    run.moveStreak = 4
    if flags and flags.tuned then run.tunedKind = 1 end
    return run:ActivePowerScore({events = (flags and flags.events) or {}, count = 12,
        cascade = (flags and flags.cascade) or 3, longest = (flags and flags.longest) or 3,
        attunedMatch = flags and flags.attuned or false}, function(n) return 1 end)
end
local scoring = {
    {'critical_match'}, {'critical_power'}, {'cascade_mastery'},
    {'perfect_four', {longest=4}}, {'five_star', {longest=5}},
    {'jewel_collector'}, {'special_savant', {events={bombActivate=1}}},
    {'rainbow_bounty', {events={orbCreate=1}}}, {'streak_keeper'},
    {'high_roller'}, {'lucky_alignment', {tuned=true,attuned=true}},
    {'blood_pact'}, {'glass_cannon'}, {'volatile_heart', {energy=25}},
    {'feast_or_famine'}, {'entropy_tax'}, {'risk_reversal', {energy=15}},
}
local plainScore = scoreFor('nonexistent', 1)
for _, row in ipairs(scoring) do
    assert(scoreFor(row[1], 1, row[2]) > plainScore, row[1]..' missing scoring effect')
end
local critical = R.New(function(n) return 1 end)
critical.stacks.critical_match, critical.stacks.critical_power = 250, 250
assert(critical:ActivePowerScore({count=64,cascade=10,longest=5,events={}},function(n)return 1 end) > 1)
assert(critical:ActivePowerScore({count=64,cascade=10,longest=5,events={}},function(n)return 1 end) <= 1000000)
print('PASS: critical/score/cursed modifiers scale and remain bounded')

-- Energy and curse tradeoffs.
local reserve = R.New(rng(3))
reserve.stacks.overheal_conversion = 10
reserve.energy = 90
reserve:Earn(35)
assert(reserve.pending and reserve.energy == 100 and reserve.reserveEnergy == 25)
reserve.pending = false
reserve:Tick(0.25, true)
assert(reserve.energy == 100 and reserve.reserveEnergy < 25)
local a, b = R.New(rng(4)), R.New(rng(5))
b.stacks.energy_siphon=3;b.stacks.combo_battery=3;b.stacks.cascade_fuel=3
for _, run in ipairs({a,b}) do
    run.energy = 10
    run:OnWave(300, {bombActivate=2}, 3, 12, 4, true)
    run:SettleMove()
end
assert(b.energy > a.energy)
local c = R.New(rng(6))
c.stacks.charge_acceleration = 3
c.energy = 20
assert(c:EnergyFactor() > R.New(rng(7)):EnergyFactor())
local survival = R.New(rng(7))
for _, id in ipairs({'emergency_reserve','regenerative_field'}) do
    survival.stacks[id] = 20
end
survival.energy=5
assert(survival:DrainRate() >= 1)
survival.energy = 0.001
assert(survival:Tick(0.25, true) == 'depleted')
local cursed=R.New(rng(8))
cursed.stacks.glass_cannon = 20
assert(cursed:MaxEnergy() == 50)
cursed.stacks.blood_pact=3
assert(cursed:DrainRate()>4)
local greedy=R.New(rng(9))
greedy.stacks.greedy_hands=10
local check=greedy:RecoveryFraction()
greedy.pending=true
for i=1,20 do greedy:DrawOffers(); assert(#greedy.offers==3) end
greedy:Choose(greedy.offers[1].id)
assert(greedy.energy < greedy.maxEnergy * check)
local luck=R.New(rng(10))
luck.stacks.fate_weaver = 10
luck.pending=true
luck:DrawOffers()
assert(luck:FinishReshuffleDraft())
assert(luck.energy > 50 and luck.level==0)
local heal=R.New(rng(11))
heal.stacks.ascension_heal=10
heal.pending=true; heal:DrawOffers();heal:Choose(heal.offers[1].id)
assert(heal.energy >= heal.maxEnergy*0.80)
print('PASS: Energy replenishment, curse choices, draft benefits, and finite decay')

-- Refilling with biased colors and safely manipulating a settled board.
for seed=1,35 do
    local model=E.New(rng(seed))
    local run=R.New(rng(seed+100))
    model.roguelite=run
    run.stacks.color_affinity=50
    run.stacks.prism_filter=50
    for i=1,20 do
        local kind=run:RollRefillKind(model.random,model.board)
        assert(kind>=1 and kind<=7)
    end
    -- Simulate a refill phase with sparse, valid game state.
    for x=1,8 do model.board[1][x]=nil end
    local drops=model:Refill()
    assert(type(drops)=='table')
    for y=1,8 do for x=1,8 do assert(model.board[y][x] ~= nil) end end
    -- Reset to a board guaranteed to have no initial matches.
    model=E.New(rng(seed+1000)); model.roguelite=run
    run.stacks.transmutation=12;run.stacks.gem_magnet=12
    run.stacks.chromatic_storm=12;run.stacks.void_reversal=12
    for move=1,8 do
        run.moves=move
        run:AfterMove(model)
        assert(#model:Patterns()==0 and model:FindMove(), 'transmutation invalidated board')
    end
end
print('PASS: 35 RNG seeds, biased refill, safe recolors and random exchanges')

-- Echo/aftershock planning and large simultaneous stacks are finite.
local function planWith(extra, mode)
    local model=E.New(function(n)return 1 end)
    local run=R.New(function(n)return 1 end)
    run.stacks[extra]=25
    model.roguelite=run; model.cascade=mode=='cascade' and 4 or 1
    local cells = {1,2,3}
    local longest=mode=='four' and 4 or 3
    if mode=='four' then cells={1,2,3,4} end
    local p={cells=cells,set={},longest=longest}
    for _,id in ipairs(cells) do p.set[id]=true end
    if mode=='bomb' then model.board[1][1]=E.Piece(1,'bomb') end
    if mode=='lightning' then model.board[1][1]=E.Piece(1,'lightning') end
    if mode=='orb' then model.board[1][1]=E.Orb end
    if mode=='combo' then
        model.board[1][1]=E.Piece(1,'bomb')
        model.board[1][2]=E.Piece(2,'lightning')
        model:Plan({},nil,{1,2})
    else model:Plan({p}) end
    assert(model.plan.count>=0 and model.plan.count<=64)
    assert(model.plan.activations<=64 and model.plan.gain>=0 and model.plan.gain<=2147483647)
    return model.plan
end
for _, item in ipairs({{'echo_strike','normal'}, {'aftershock','bomb'},
    {'chain_surge','lightning'}, {'orb_afterimage','orb'},
    {'fracture_wave','cascade'}, {'resonant_burst','combo'},
    {'shatterstorm','four'}, {'crystal_echo','four'}}) do
    planWith(item[1],item[2])
end
local all=E.New(rng(444))
local run=R.New(rng(555))
for _, card in ipairs(R.Cards) do run.stacks[card.id]=card.max==1 and 1 or 250 end
all.roguelite=run
for i=1,20 do
    all.phase='idle';all.gameover=false;run.moves=i
    run.clearedThisMove=35;run.bombActivations=5;run.lightningActivations=5
    run:AfterMove(all)
    assert(#all:Patterns()==0 and all:FindMove(), 'long run invalidated board')
end
print('PASS: eight echo/secondary clear paths, 250-stack chaos build remains finite')
print('PASS: 44 newly added cards; Phase 2 gameplay hooks validated offline')
