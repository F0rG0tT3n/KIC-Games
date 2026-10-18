-- Run from the repository root: lua tests/roguelite_midcascade_draft.lua
-- Lightweight model/UI integration without a WoW client.
local Games = { Theme = {} }
local function load(rel)
    assert(loadfile('KIC-Games/Games/' .. rel))('KIC-Games', Games)
end
load('Bejeweled/Engine.lua')
load('KICBejeweled/Engine.lua')
load('KICBejeweled/Roguelite.lua')
local D = Games.KICBejeweled
local R = D.Roguelite
local E = D.Engine
-- Base UI's Advance normally performs one clearing/refill/animation step.
D.Advance = function(self)
    self.baseSteps = (self.baseSteps or 0) + 1
    local nextStep = table.remove(self.steps, 1)
    assert(nextStep, 'unexpected base Advance')
    self.model.phase = nextStep.phase
    if nextStep.wave then
        self.model.lastResolution = nextStep.wave
    end
end
D.Blocked = function() return false end
D.Render = function() end
D.Storage = function() return {best = { score = 0 }} end
load('KICBejeweled/RogueliteUI.lua')
-- The presentation functions are replaced with counters while all state
-- transitions and the actual engine/Roguelite logic remain live.
local function rng(seed)
    return function(n)
        seed = (seed * 48271) % 2147483647
        return (seed % n) + 1
    end
end
local function makeUI(steps)
    local m = E.New(rng(99))
    m.phase, m.gameover, m.moves = 'clearing', false, 1
    local run = R.New(rng(29))
    run.energy, run.trackedMoves = 88, 0
    local ui = setmetatable({
        model=m, run=run, running=true, steps=steps,
        root={ IsVisible=function() return true end },
        draftDim={ Hide=function() end },
        CancelDrag=function() end,
        Render=function() end, RefreshEnergy=function() end,
        PresentUpgradeDraft=function(self)
            self.presented = (self.presented or 0) + 1
        end,
        BeginReshuffleAnimation=function(self, shuffle)
            assert(shuffle and #shuffle.sourceByDestination == 64)
            self.reshuffles = (self.reshuffles or 0) + 1
            return true
        end,
    }, { __index=D })
    return ui,m,run
end
local a, m, run = makeUI({
    {phase='falling',wave={gain=150,count=3,cascade=1,events={}}},
    {phase='clearing'},
    {phase='falling',wave={gain=400,count=8,cascade=2,events={bombActivate=2}}},
    {phase='idle'},
})
run.stacks.explosive_refund = 10
-- First wave should interrupt the chain immediately, *not* advance gravity.
a:Advance(0.1)
assert(run.pending and a.presented==1 and m.phase=='falling')
assert(a.baseSteps==1 and run.scoring==150 and run.creditedScoreBase==12)
a:Advance(0.1)
assert(a.baseSteps==1 and run.pending, 'chain advanced while draft was open')
a:PickUpgrade(1)
assert(not run.pending and run.level==1)
assert(run.inMove and run.scoring==150, 'mid-chain choice reset move accounting')
-- Gravity / refill resumes, then the next wave credits fresh Energy.
a:Advance(0.1)
assert(m.phase=='clearing' and a.baseSteps==2)
a:Advance(0.1)
assert(a.presented==2 and run.pending and m.phase=='falling',
    'a later cascade wave must be able to cause another draft')
assert(run.scoring==550 and run.creditedScoreBase==42, 'waves double-credited the shared base cap')
a:PickUpgrade(1)
assert(not run.pending and run.level==2)
a:Advance(0.1)
assert(m.phase=='idle' and not run.inMove and a.baseSteps==4,
    'original chain did not finish after drafting')
assert(run.creditedScoreBase==42, 'settlement reset the shared move score budget')
print('PASS: mid-cascade draft pauses at exact clear wave, resumes, may draft again, no duplicate Energy')
-- The reshuffle choice made mid-chain should queue a real 64-piece
-- permutation, rather than try to shuffle a partially refilled board.
local b, bm, br = makeUI({
    {phase='falling',wave={gain=150,count=3,cascade=1,events={}}},
    {phase='idle'},
})
b:Advance(0.1)
assert(br.pending)
b:ReshuffleDraft()
assert(not br.pending and b.deferredReshuffle and br.level==0,
    'reshuffle mid-cascade must be deferred and must not grant Ascension')
b:Advance(0.1)
assert(not b.deferredReshuffle and b.reshuffles==1 and br.level==0,
    'deferred reshuffle was not animated after settling')
assert(bm.phase=='idle' and #bm:Patterns()==0 and bm:FindMove(),
    'reshuffle must leave valid moves and no immediate match')
print('PASS: Reshuffle chosen mid-cascade waits for a settled board and preserves power choice cost')
-- If there are no moves after the last refill, a previously selected queued
-- reshuffle has priority over completing the run.
local c, cm, cr=makeUI({})
c.deferredReshuffle=true
cm.phase, cm.gameover = 'over', true
c:Complete()
assert(c.reshuffles==1 and not c.deferredReshuffle and cm.phase=='idle' and not cm.gameover,
    'queued reshuffle did not rescue a no-moves board')
print('PASS: queued reshuffle rescues deadlock before game-over completion')

-- Cards obtained mid-chain must never retroactively pay for earlier events.
local retro = R.New(rng(51))
retro.energy = 20
retro:OnSwap()
retro.inMove = true
retro:OnWave(100, {bombActivate=2}, 1, 3)
assert(retro.creditedBonus == 0 and retro.bombActivations == 2)
retro.pending = true
retro.offers = { R.ByID.explosive_refund }
assert(retro:Choose('explosive_refund'))
assert(retro.creditedBonus == 6 and not retro.pending,
    'newly acquired bonus must watermark pre-existing activations')
local before = retro.energy
retro:OnWave(100, {bombActivate=1}, 2, 3)
assert(math.abs((retro.energy - before) - 11) < 0.001,
    'one additional Bomb should add +3 special Energy and +8 score Energy')
print('PASS: newly acquired power affects subsequent waves, not earlier activations')
