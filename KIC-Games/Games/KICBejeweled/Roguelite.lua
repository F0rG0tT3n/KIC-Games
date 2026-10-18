local _, Games = ...
local R = {}
Games.KICBejeweled.Roguelite = R

-- Phase 1: repeatable upgrades and bounded 8x8-board effects. "max = math.huge"
-- means the draft never removes that upgrade due to stack count. Mechanical
-- caps apply to *events*, not to power acquisition; overflow must remain useful.
-- A few one-off rule-changing relics remain deliberately unique.
local INFINITE = math.huge
R.Cards = {
    { id = "mana_capacitor", title = "Mana Capacitor", rarity = "common", max = INFINITE, description = "+20 max Energy per stack (capacity cap 200); overflow boosts scoring Energy." },
    { id = "time_bender", title = "Time Bender", rarity = "rare", max = INFINITE, description = "7% less remaining Energy drain per stack; approaches 1/s without reaching zero." },
    { id = "adrenaline", title = "Adrenaline", rarity = "common", max = INFINITE, description = "+10% scoring Energy per stack." },
    { id = "quick_hands", title = "Quick Hands", rarity = "common", max = INFINITE, description = "+4 Energy per stack for a quick swap; excess stacks boost scoring Energy." },
    { id = "capacitor_recovery", title = "Capacitor Recovery", rarity = "common", max = INFINITE, description = "+10% post-draft Energy per stack (max 80%); extra stacks boost scoring Energy." },
    { id = "last_stand", title = "Last Stand", rarity = "rare", max = INFINITE, description = "+25% scoring Energy per stack while under 25% Energy." },
    { id = "reckless_rush", title = "Reckless Rush", rarity = "epic", max = INFINITE, description = "+20% scoring Energy per stack, but +12% drain per stack." },
    { id = "second_wind", title = "Second Wind", rarity = "epic", max = 1, description = "Once per run, survive Energy depletion and restore 35%. Unique relic." },
    { id = "bomb_factory", title = "Bomb Factory", rarity = "common", max = INFINITE, description = "Each stack accelerates Bomb generation; max 3 new Bombs per swap. Overflow boosts Bomb scores." },
    { id = "static_charge", title = "Static Charge", rarity = "common", max = INFINITE, description = "Each stack accelerates Lightning generation; max 3 new Lightning Gems per swap." },
    { id = "blast_radius", title = "Blast Radius", rarity = "rare", max = INFINITE, description = "Bombs clear 5x5 (cap). Additional stacks: +10% Bomb-related score each." },
    { id = "explosive_refund", title = "Explosive Refund", rarity = "common", max = INFINITE, description = "+3 Energy per Bomb activation per stack; per-move cap scales to 80." },
    { id = "conductive_gems", title = "Conductive Gems", rarity = "common", max = INFINITE, description = "+3 Energy per Lightning activation per stack; per-move cap scales to 80." },
    { id = "avalanche", title = "Avalanche", rarity = "common", max = INFINITE, description = "+5 Energy per extra cascade depth per stack; capped per move." },
    { id = "volatile_fusion", title = "Volatile Fusion", rarity = "epic", max = 1, description = "Bomb + Bomb combos clear 7x7. Unique relic." },
    { id = "chaos_theory", title = "Chaos Theory", rarity = "legendary", max = 1, description = "Every 10th successful swap creates up to three Bomb/Lightning gems. Unique relic." },
    { id = "overclocked_battery", title = "Overclocked Battery", rarity = "rare", max = INFINITE, description = "+50 max Energy (cap 200), +0.45 Energy/s drain per stack; overflow boosts scoring Energy." },
    { id = "shrapnel", title = "Shrapnel", rarity = "rare", max = INFINITE, description = "Increasing chance to spawn 1 extra Bomb after Bomb moves; overflow boosts Bomb score." },
    { id = "infernal_core", title = "Infernal Core", rarity = "legendary", max = 1, description = "First Bomb each move causes an extra random 3x3 explosion. Unique relic." },
    { id = "overload", title = "Overload", rarity = "rare", max = INFINITE, description = "Lightning clears 3 rows and 3 columns (cap); further stacks increase Lightning score." },
    { id = "forked_strike", title = "Forked Strike", rarity = "rare", max = INFINITE, description = "+1 extra Lightning row/column per stack (max 3); overflow boosts Lightning score." },
    { id = "stormcaller", title = "Stormcaller", rarity = "epic", max = INFINITE, description = "Lightning activations create free Lightning more often (down to every activation); overflow boosts its score." },
    { id = "thunder_god", title = "Thunder God", rarity = "legendary", max = 1, description = "First Lightning per move hits 2 extra rows and columns. Unique relic." },
    { id = "arcane_resonance", title = "Arcane Resonance", rarity = "common", max = INFINITE, description = "+8 Energy per Orb activation per stack; per-move cap scales to 80." },
    { id = "prismatic_dust", title = "Prismatic Dust", rarity = "common", max = INFINITE, description = "+3 extra normal gems cleared by Orb (max 8); excess stacks boost Orb score." },
    { id = "prismatic_echo", title = "Prismatic Echo", rarity = "epic", max = INFINITE, description = "Increasing chance to preserve an Orb after normal use (max 65%); high stacks boost Orb score." },
    { id = "spectrum_collapse", title = "Spectrum Collapse", rarity = "legendary", max = 1, description = "Orb + normal gem clears a second different gem type. Unique relic." },
    { id = "orb_amplifier", title = "Orb Amplifier", rarity = "rare", max = INFINITE, description = "+100% score from Orb + normal clear per stack." },
    { id = "lucky_strike", title = "Lucky Strike", rarity = "common", max = INFINITE, description = "Increasing chance to generate random Bomb/Lightning after moves; max 2 spawns per swap." },
    { id = "gravity_rift", title = "Gravity Rift", rarity = "rare", max = INFINITE, description = "Lower the move's gem-clear threshold for spawning Lightning (min 6); high stacks improve yield." },
    { id = "combo_alchemy", title = "Combo Alchemy", rarity = "epic", max = INFINITE, description = "+12 Energy per stack for activating 2+ special types in a move; capped per move." },
    -- PHASE 2: scoring / critical builds (10)
    { id = "critical_match", title = "Critical Match", rarity = "common", max = INFINITE, description = "+5% critical clear chance per stack (max 75%)." },
    { id = "critical_power", title = "Critical Power", rarity = "rare", max = INFINITE, description = "+15% critical damage multiplier per stack. Grants a 5% base crit chance." },
    { id = "cascade_mastery", title = "Cascade Mastery", rarity = "common", max = INFINITE, description = "+6% points per additional cascade depth per stack." },
    { id = "perfect_four", title = "Perfect Four", rarity = "common", max = INFINITE, description = "+12% points for a longest match of exactly four per stack." },
    { id = "five_star", title = "Five Star", rarity = "rare", max = INFINITE, description = "+20% points for straight 5+ matches per stack." },
    { id = "jewel_collector", title = "Jewel Collector", rarity = "common", max = INFINITE, description = "+2% wave points per three gems cleared per stack." },
    { id = "special_savant", title = "Special Savant", rarity = "rare", max = INFINITE, description = "+12% points per activated special type per stack." },
    { id = "rainbow_bounty", title = "Rainbow Bounty", rarity = "rare", max = INFINITE, description = "+10% points on waves creating any special gem per stack." },
    { id = "streak_keeper", title = "Streak Keeper", rarity = "common", max = INFINITE, description = "+5% points per fast swap streak (up to 10) per stack." },
    { id = "high_roller", title = "High Roller", rarity = "epic", max = INFINITE, description = "+3% chance per stack to double a clear's points (max 50%)." },
    -- PHASE 2: echo / secondary clear builds (8); extra effects are bounded
    { id = "echo_strike", title = "Echo Strike", rarity = "common", max = INFINITE, description = "Chance to clear up to four additional normal gems each wave." },
    { id = "aftershock", title = "Aftershock", rarity = "rare", max = INFINITE, description = "Bomb waves may trigger one extra 3x3 burst per wave." },
    { id = "chain_surge", title = "Chain Surge", rarity = "rare", max = INFINITE, description = "Lightning waves may zap up to two extra lines." },
    { id = "orb_afterimage", title = "Orb Afterimage", rarity = "epic", max = INFINITE, description = "Orb waves may clear one additional color, once per wave." },
    { id = "fracture_wave", title = "Fracture Wave", rarity = "common", max = INFINITE, description = "Cascade waves may shatter up to five extra normal gems." },
    { id = "resonant_burst", title = "Resonant Burst", rarity = "epic", max = INFINITE, description = "Special + special swaps can trigger a bonus 3x3 blast." },
    { id = "shatterstorm", title = "Shatterstorm", rarity = "rare", max = INFINITE, description = "Four-or-better matches may clear one additional row." },
    { id = "crystal_echo", title = "Crystal Echo", rarity = "common", max = INFINITE, description = "Large clear waves may shatter up to four further normal gems." },
    -- PHASE 2: gem manipulation (9)
    { id = "color_affinity", title = "Color Affinity", rarity = "common", max = INFINITE, description = "New gems increasingly favor one attuned gem color (max 65% chance)." },
    { id = "prism_filter", title = "Prism Filter", rarity = "common", max = INFINITE, description = "New gems increasingly avoid the board's most common color (max 70%)." },
    { id = "transmutation", title = "Transmutation", rarity = "common", max = INFINITE, description = "Increasing chance to recolor a random normal gem after a move; max 3." },
    { id = "gem_magnet", title = "Gem Magnet", rarity = "rare", max = INFINITE, description = "Increasing chance to recolor normals to your attuned color; max 3." },
    { id = "chromatic_storm", title = "Chromatic Storm", rarity = "rare", max = INFINITE, description = "Every few moves, recolor up to four normal gems safely." },
    { id = "lucky_alignment", title = "Lucky Alignment", rarity = "common", max = INFINITE, description = "+10% points per stack on clears matching your attuned color." },
    { id = "crystal_multiplication", title = "Crystal Multiplication", rarity = "epic", max = INFINITE, description = "Clearing many gems creates bonus Bombs or Lightning (within spawn budget)." },
    { id = "void_reversal", title = "Void Reversal", rarity = "rare", max = INFINITE, description = "Every few moves, safely exchange two normal gems on the board." },
    { id = "fate_weaver", title = "Fate Weaver", rarity = "common", max = INFINITE, description = "Reshuffle draft restores +5% max Energy per stack, capped at 95%." },
    -- PHASE 2: cursed tradeoffs (9)
    { id = "blood_pact", title = "Blood Pact", rarity = "rare", max = INFINITE, description = "+18% points and +10% Energy drain per stack." },
    { id = "glass_cannon", title = "Glass Cannon", rarity = "epic", max = INFINITE, description = "+30% points but -10 maximum Energy per stack (minimum 50)." },
    { id = "greedy_hands", title = "Greedy Hands", rarity = "rare", max = INFINITE, description = "Better Rare/Epic/Legendary drafts, but -3% post-draft Energy per stack." },
    { id = "volatile_heart", title = "Volatile Heart", rarity = "rare", max = INFINITE, description = "+25% score below half Energy, but +12% drain per stack." },
    { id = "feast_or_famine", title = "Feast or Famine", rarity = "rare", max = INFINITE, description = "+15% score above half Energy; -5% below half, per stack." },
    { id = "unstable_essence", title = "Unstable Essence", rarity = "epic", max = INFINITE, description = "Additional random special spawn charge each move, but +0.2 Energy/sec drain." },
    { id = "entropy_tax", title = "Entropy Tax", rarity = "epic", max = INFINITE, description = "+2% score per Ascension level per stack, but +0.15 drain/sec." },
    { id = "risk_reversal", title = "Risk Reversal", rarity = "rare", max = INFINITE, description = "+30% score below 25% Energy; +10% drain above 75%, per stack." },
    { id = "curse_of_haste", title = "Curse of Haste", rarity = "rare", max = INFINITE, description = "+5 quick-swap Energy per stack, but +0.15 Energy/sec drain." },
    -- PHASE 2: Energy and survival (8)
    { id = "energy_siphon", title = "Energy Siphon", rarity = "common", max = INFINITE, description = "+0.5 Energy per gem cleared per stack, per-move capped." },
    { id = "combo_battery", title = "Combo Battery", rarity = "common", max = INFINITE, description = "+2 Energy per special activation per stack, capped per move." },
    { id = "cascade_fuel", title = "Cascade Fuel", rarity = "common", max = INFINITE, description = "+3 Energy per cascade step beyond the first per stack." },
    { id = "emergency_reserve", title = "Emergency Reserve", rarity = "rare", max = INFINITE, description = "Reduce drain when under 25% Energy by 8% of remaining drain per stack." },
    { id = "overheal_conversion", title = "Overheal Conversion", rarity = "rare", max = INFINITE, description = "Bank surplus Energy on reaching full, shielding later drain (up to 10/stack)." },
    { id = "charge_acceleration", title = "Charge Acceleration", rarity = "common", max = INFINITE, description = "+15% Energy from scoring while below half Energy per stack." },
    { id = "regenerative_field", title = "Regenerative Field", rarity = "rare", max = INFINITE, description = "8% less remaining Energy drain per stack (minimum 1/s)." },
    { id = "ascension_heal", title = "Ascension Heal", rarity = "rare", max = INFINITE, description = "+4% maximum Energy after each draft per stack, up to 95% total refill." },
}
-- Illustration metadata is independent of gameplay and SavedVariables.
-- Every card belongs to one of the nine new visual families.
-- Add future card IDs here to give them the corresponding draft illustration.
R.CardArtwork = {
    -- Energy
    mana_capacitor = "upgrade-energy",
    time_bender = "upgrade-energy",
    adrenaline = "upgrade-energy",
    quick_hands = "upgrade-energy",
    capacitor_recovery = "upgrade-energy",
    last_stand = "upgrade-energy",
    second_wind = "upgrade-energy",
    overclocked_battery = "upgrade-energy",
    energy_siphon = "upgrade-energy",
    combo_battery = "upgrade-energy",
    cascade_fuel = "upgrade-energy",
    emergency_reserve = "upgrade-energy",
    overheal_conversion = "upgrade-energy",
    charge_acceleration = "upgrade-energy",
    regenerative_field = "upgrade-energy",
    ascension_heal = "upgrade-energy",
    -- Bomb
    bomb_factory = "upgrade-bomb",
    blast_radius = "upgrade-bomb",
    explosive_refund = "upgrade-bomb",
    volatile_fusion = "upgrade-bomb",
    shrapnel = "upgrade-bomb",
    infernal_core = "upgrade-bomb",
    -- Lightning
    static_charge = "upgrade-lightning",
    conductive_gems = "upgrade-lightning",
    overload = "upgrade-lightning",
    forked_strike = "upgrade-lightning",
    stormcaller = "upgrade-lightning",
    thunder_god = "upgrade-lightning",
    gravity_rift = "upgrade-lightning",
    -- Orb
    arcane_resonance = "upgrade-orb",
    prismatic_dust = "upgrade-orb",
    prismatic_echo = "upgrade-orb",
    spectrum_collapse = "upgrade-orb",
    orb_amplifier = "upgrade-orb",
    -- Critical
    critical_match = "upgrade-critical",
    critical_power = "upgrade-critical",
    cascade_mastery = "upgrade-critical",
    perfect_four = "upgrade-critical",
    five_star = "upgrade-critical",
    jewel_collector = "upgrade-critical",
    special_savant = "upgrade-critical",
    rainbow_bounty = "upgrade-critical",
    streak_keeper = "upgrade-critical",
    high_roller = "upgrade-critical",
    -- Echo
    echo_strike = "upgrade-echo",
    aftershock = "upgrade-echo",
    chain_surge = "upgrade-echo",
    orb_afterimage = "upgrade-echo",
    fracture_wave = "upgrade-echo",
    resonant_burst = "upgrade-echo",
    shatterstorm = "upgrade-echo",
    crystal_echo = "upgrade-echo",
    -- Transmutation
    color_affinity = "upgrade-transmutation",
    prism_filter = "upgrade-transmutation",
    transmutation = "upgrade-transmutation",
    gem_magnet = "upgrade-transmutation",
    chromatic_storm = "upgrade-transmutation",
    lucky_alignment = "upgrade-transmutation",
    crystal_multiplication = "upgrade-transmutation",
    void_reversal = "upgrade-transmutation",
    fate_weaver = "upgrade-transmutation",
    -- Cursed
    reckless_rush = "upgrade-cursed",
    blood_pact = "upgrade-cursed",
    glass_cannon = "upgrade-cursed",
    greedy_hands = "upgrade-cursed",
    volatile_heart = "upgrade-cursed",
    feast_or_famine = "upgrade-cursed",
    unstable_essence = "upgrade-cursed",
    entropy_tax = "upgrade-cursed",
    risk_reversal = "upgrade-cursed",
    curse_of_haste = "upgrade-cursed",
    -- Chaos
    avalanche = "upgrade-chaos",
    chaos_theory = "upgrade-chaos",
    lucky_strike = "upgrade-chaos",
    combo_alchemy = "upgrade-chaos",
}
R.ByID = {}
for _, card in ipairs(R.Cards) do
    card.stackMode = card.max == INFINITE and "repeatable" or "unique"
    card.artKey = R.CardArtwork[card.id] or "icon-gem"
    R.ByID[card.id] = card
end
local weights = { common = 58, rare = 28, epic = 11, legendary = 3 }
local rarities = { "common", "rare", "epic", "legendary" }
local function clamp(value, low, high)
    return math.min(high, math.max(low, value))
end
local function cappedBonus(value, cap)
    return math.min(math.max(0, value), cap)
end
function R.New(random)
    return setmetatable({
        random = random or math.random,
        maxEnergy = 100, energy = 70, level = 0, survived = 0,
        stacks = {}, offers = {}, pending = false, over = false, buildRevision = 0,
        secondWindUsed = false, moves = 0, waveCount = 0,
        scoring = 0, bombActivations = 0, lightningActivations = 0,
        orbActivations = 0, clearedThisMove = 0, specialTypes = {}, stormProgress = 0,
        cascadeDepth = 1, quickBonus = 0, readyFor = nil,
        bombCharge = 0, lightningCharge = 0, luckyCharge = 0, unstableCharge = 0, multiplicationCharge = 0,
        tunedKind = nil, moveStreak = 0, reserveEnergy = 0, kindBonus = 0,
        matchedFour = false, matchedFive = false, createdSpecial = false,
    }, { __index = R })
end
function R:Stacks(id)
    return self.stacks[id] or 0
end
function R:AttunedKind()
    if not self.tunedKind then self.tunedKind = self.random(7) end
    return self.tunedKind
end
function R:MaxEnergy()
    return clamp(100 + 20 * self:Stacks("mana_capacitor")
        + 50 * self:Stacks("overclocked_battery") - 10 * self:Stacks("glass_cannon"), 50, 200)
end
function R:ActivePowerScore(p, random)
    local bonus = 0
    local events = p.events or {}
    local activatedTypes = 0
    for _, kind in ipairs({ "bomb", "lightning", "orb" }) do
        if (events[kind .. "Activate"] or 0) > 0 then activatedTypes = activatedTypes + 1 end
    end
    local created = (events.bombCreate or 0) + (events.lightningCreate or 0)
        + (events.orbCreate or 0)
    local gain = math.max(0, p.count or 0)
    bonus = bonus + 0.06 * self:Stacks("cascade_mastery") * math.max(0, (p.cascade or 1) - 1)
        + (p.longest == 4 and 0.12 * self:Stacks("perfect_four") or 0)
        + (p.longest >= 5 and 0.20 * self:Stacks("five_star") or 0)
        + 0.02 * self:Stacks("jewel_collector") * math.floor(gain / 3)
        + 0.12 * self:Stacks("special_savant") * activatedTypes
        + (created > 0 and 0.10 * self:Stacks("rainbow_bounty") or 0)
        + 0.05 * self:Stacks("streak_keeper") * math.min(10, self.moveStreak)
        + (p.attunedMatch and 0.1 * self:Stacks("lucky_alignment") or 0)
        + 0.18 * self:Stacks("blood_pact")
        + 0.30 * self:Stacks("glass_cannon")
        + 0.02 * self.level * self:Stacks("entropy_tax")
        + (self.energy < self.maxEnergy * 0.5 and 0.25 * self:Stacks("volatile_heart") or 0)
        + (self.energy < self.maxEnergy * 0.25 and 0.30 * self:Stacks("risk_reversal") or 0)
    local feast = self:Stacks("feast_or_famine")
    local penalty = self.energy < self.maxEnergy * 0.5 and -0.05 * feast or 0.15 * feast
    local multiplier = math.max(0.5, 1 + bonus + penalty)
    local critStacks, powerStacks = self:Stacks("critical_match"), self:Stacks("critical_power")
    if critStacks > 0 or powerStacks > 0 then
        local chance = math.min(75, 5 * critStacks + (powerStacks > 0 and 5 or 0))
        if random(100) <= chance then
            multiplier = multiplier * math.min(100, 1.5 + 0.15 * powerStacks)
        end
    end
    if self:Stacks("high_roller") > 0 and random(100) <= math.min(50, 3 * self:Stacks("high_roller")) then
        multiplier = multiplier * 2
    end
    local overflow = self:CappedUpgradeOverflow()
    return math.min(1000000, multiplier * (1 + 0.015 * overflow))
end
-- Immutable limits, shared by every wave to avoid rebuilding tables in OnUpdate.
local overflowLimits = {
    critical_match = 15, high_roller = 17,
    echo_strike = 10, aftershock = 8, chain_surge = 8,
    orb_afterimage = 11, fracture_wave = 9, resonant_burst = 8,
    shatterstorm = 9, crystal_echo = 9,
    color_affinity = 10, prism_filter = 10,
    transmutation = 8, gem_magnet = 8, chromatic_storm = 12,
    void_reversal = 9, fate_weaver = 19,
    greedy_hands = 10, regenerative_field = 35,
}
function R:CappedUpgradeOverflow()
    -- Extra stacks beyond safe effect limits still provide scoring/energy.
    local result = 0
    for id, limit in pairs(overflowLimits) do
        result = result + math.max(0, self:Stacks(id) - limit)
    end
    return result
end
function R:RollRefillKind(random, board)
    local kind = random(7)
    local affinity = self:Stacks("color_affinity")
    if affinity > 0 and random(1000) <= math.min(650, affinity * 65) then
        kind = self:AttunedKind()
    end
    local filter = self:Stacks("prism_filter")
    if filter > 0 and random(1000) <= math.min(700, filter * 70) then
        local counts = { 0, 0, 0, 0, 0, 0, 0 }
        for y = 1, 8 do for x = 1, 8 do
            local piece = board[y][x]
            if piece and piece ~= 22 then counts[(piece - 1) % 7 + 1] = counts[(piece - 1) % 7 + 1] + 1 end
        end end
        local common = 1
        for i = 2, 7 do if counts[i] > counts[common] then common = i end end
        if kind == common then kind = (common - 1 + random(6)) % 7 + 1 end
    end
    return kind
end
function R:CapacityOverflow()
    return math.max(0, 20 * self:Stacks("mana_capacitor")
        + 50 * self:Stacks("overclocked_battery") - 100)
end
function R:RecoveryFraction()
    return math.min(0.8, 0.5 + 0.1 * self:Stacks("capacitor_recovery"))
end
function R:DrainRate()
    local base = 4 + math.floor(self.level / 3) * 0.5 + 0.45 * self:Stacks("overclocked_battery")
        + 0.2 * self:Stacks("unstable_essence") + 0.15 * self:Stacks("entropy_tax")
        + 0.15 * self:Stacks("curse_of_haste")
    base = base * (1 + 0.12 * self:Stacks("reckless_rush")
        + 0.10 * self:Stacks("blood_pact") + 0.12 * self:Stacks("volatile_heart")
        + (self.energy > self.maxEnergy * 0.75 and 0.10 * self:Stacks("risk_reversal") or 0))
    -- Time Bender is infinitely repeatable without allowing an energy-free run.
    local rate = 1 + math.max(0, base - 1) * (0.93 ^ self:Stacks("time_bender"))
    if self.energy < self.maxEnergy * 0.25 then
        rate = 1 + (rate - 1) * (0.92 ^ self:Stacks("emergency_reserve"))
    end
    rate = 1 + (rate - 1) * (0.92 ^ self:Stacks("regenerative_field"))
    return math.max(1, rate)
end
function R:Tick(dt, interactive)
    if self.pending or self.over or not interactive then return end
    local elapsed = clamp(tonumber(dt) or 0, 0, 0.25)
    self.survived = self.survived + elapsed
    self.readyFor = (self.readyFor or 0) + elapsed
    local drain = self:DrainRate() * elapsed
    if self.reserveEnergy > 0 then
        local absorbed = math.min(self.reserveEnergy, drain)
        self.reserveEnergy = self.reserveEnergy - absorbed
        drain = drain - absorbed
    end
    self.energy = math.max(0, self.energy - drain)
    if self.energy <= 0 then
        if self:Stacks("second_wind") > 0 and not self.secondWindUsed then
            self.secondWindUsed = true
            self.energy = self.maxEnergy * 0.35
            return "second_wind"
        end
        self.over = true
        return "depleted"
    end
end
function R:OnSwap()
    if self.readyFor and self.readyFor <= 2 then
        self.quickBonus = math.min(80, 4 * self:Stacks("quick_hands")
            + 5 * self:Stacks("curse_of_haste"))
        self.moveStreak = self.moveStreak + 1
    else
        self.quickBonus = 0
        self.moveStreak = 0
    end
    self.readyFor = nil
    self.moves = self.moves + 1
    self.scoring, self.bombActivations, self.lightningActivations, self.orbActivations = 0, 0, 0, 0
    self.clearedThisMove, self.specialTypes = 0, {}
    self.cascadeDepth, self.waveCount = 1, 0
    -- Preserve the per-move 42 base-Energy cap while crediting each wave now.
    self.creditedScoreBase, self.creditedBonus = 0, 0
    self.matchedFour, self.matchedFive, self.createdSpecial, self.kindBonus = false, false, false, 0
end
function R:OnWave(gain, events, cascade, cleared, longest, attuned)
    self.scoring = self.scoring + math.max(0, gain or 0)
    self.waveCount = self.waveCount + 1
    self.clearedThisMove = self.clearedThisMove + math.max(0, cleared or 0)
    self.cascadeDepth = math.max(self.cascadeDepth, cascade or 1)
    self.matchedFour = self.matchedFour or longest == 4
    self.matchedFive = self.matchedFive or (longest or 0) >= 5
    self.kindBonus = self.kindBonus + (attuned and (cleared or 0) or 0)
    events = events or {}
    self.bombActivations = self.bombActivations + (events.bombActivate or 0)
    self.lightningActivations = self.lightningActivations + (events.lightningActivate or 0)
    self.orbActivations = self.orbActivations + (events.orbActivate or 0)
    for _, kind in ipairs({ "bomb", "lightning", "orb" }) do
        if (events[kind .. "Activate"] or 0) > 0 then self.specialTypes[kind] = true end
    end
    -- Each resolved clear wave can independently fill Energy and pause the
    -- cascade for a draft. A later wave may trigger another draft after choice.
    self:CreditWaveEnergy()
end
function R:Earn(value)
    if self.pending or self.over then return end
    local awarded = math.max(0, value)
    local surplus = math.max(0, self.energy + awarded - self.maxEnergy)
    self.energy = clamp(self.energy + awarded, 0, self.maxEnergy)
    if self:Stacks("overheal_conversion") > 0 and surplus > 0 then
        self.reserveEnergy = math.min(10 * self:Stacks("overheal_conversion"),
            self.reserveEnergy + surplus)
    end
    if self.energy >= self.maxEnergy then
        self.pending = true
        self:DrawOffers()
    end
end
function R:EnergyFactor()
    local factor = 1 + 0.1 * self:Stacks("adrenaline") + 0.2 * self:Stacks("reckless_rush")
    -- The first 100 bonus-capacity points are real capacity. Later ones convert
    -- into a never-dead +0.2% scoring Energy per unused capacity point.
    factor = factor + self:CapacityOverflow() * 0.002
        + 0.03 * math.max(0, self:Stacks("capacitor_recovery") - 3)
        + 0.02 * math.max(0, self:Stacks("quick_hands") - 15)
    -- Shared post-cap conversion: even an upgrade whose spawn/bonus effect
    -- has hit a safe per-move limit remains useful to a long-running build.
    factor = factor + 0.02 * (
        math.max(0, self:Stacks("static_charge") - 35)
        + math.max(0, self:Stacks("lucky_strike") - 27)
        + math.max(0, self:Stacks("gravity_rift") - 5)
        + math.max(0, self:Stacks("explosive_refund") - 25)
        + math.max(0, self:Stacks("conductive_gems") - 25)
        + math.max(0, self:Stacks("arcane_resonance") - 25)
        + math.max(0, self:Stacks("avalanche") - 25)
        + math.max(0, self:Stacks("combo_alchemy") - 7))
    if self.energy < self.maxEnergy * 0.5 then
        factor = factor * (1 + 0.15 * self:Stacks("charge_acceleration"))
    end
    if self.energy < self.maxEnergy * 0.25 then
        factor = factor * (1 + 0.25 * self:Stacks("last_stand"))
    end
    factor = factor + 0.01 * self:CappedUpgradeOverflow()
    return math.min(1000000, factor)
end
-- Score bonuses use actual special activations; cosmetic explosions do not
-- create unlimited extra gameplay events. Mechanical caps remain unchanged.
function R:SpecialScoreMultiplier(events, orbNormal)
    events = events or {}
    local bonus = 0
    if (events.bombActivate or 0) > 0 then
        bonus = bonus + 0.10 * math.max(0, self:Stacks("blast_radius") - 1)
            + 0.05 * math.max(0, self:Stacks("bomb_factory") - 8)
            + 0.05 * math.max(0, self:Stacks("shrapnel") - 11)
    end
    if (events.lightningActivate or 0) > 0 then
        bonus = bonus + 0.10 * math.max(0, self:Stacks("overload") - 1)
            + 0.08 * math.max(0, self:Stacks("forked_strike") - 3)
            + 0.08 * math.max(0, self:Stacks("stormcaller") - 3)
            + 0.04 * math.max(0, self:Stacks("static_charge") - 8)
    end
    if orbNormal then
        bonus = bonus + self:Stacks("orb_amplifier")
            + 0.10 * math.max(0, self:Stacks("prismatic_dust") - 3)
            + 0.04 * math.max(0, self:Stacks("prismatic_echo") - 8)
    end
    return 1 + bonus
end

-- Calculate the accumulated per-move bonus with the SAME limits as before.
-- Taking positive differences at each wave gives immediate feedback without
-- multiplying capped bonuses by the number of cascades.
function R:MoveEnergyBonuses()
    local typeCount = 0
    for _ in pairs(self.specialTypes) do typeCount = typeCount + 1 end
    return cappedBonus(self.bombActivations * 3 * self:Stacks("explosive_refund"),
            math.min(80, 24 + 2 * self:Stacks("explosive_refund")))
        + cappedBonus(self.lightningActivations * 3 * self:Stacks("conductive_gems"),
            math.min(80, 20 + 2 * self:Stacks("conductive_gems")))
        + cappedBonus(math.max(0, self.cascadeDepth - 1) * 5 * self:Stacks("avalanche"),
            math.min(80, 30 + 2 * self:Stacks("avalanche")))
        + cappedBonus(self.orbActivations * 8 * self:Stacks("arcane_resonance"),
            math.min(80, 24 + 2 * self:Stacks("arcane_resonance")))
        + (typeCount >= 2 and cappedBonus(12 * self:Stacks("combo_alchemy"), 80) or 0)
        + self.quickBonus
        + cappedBonus(self.clearedThisMove * 0.5 * self:Stacks("energy_siphon"), 70)
        + cappedBonus((self.bombActivations + self.lightningActivations + self.orbActivations)
            * 2 * self:Stacks("combo_battery"), 70)
        + cappedBonus(math.max(0, self.cascadeDepth - 1) * 3 * self:Stacks("cascade_fuel"), 70)
end
function R:CreditWaveEnergy()
    if self.over or self.pending then return end
    -- The first 525 score points over the ENTIRE move yield at most 42 base
    -- Energy. Subsequent waves may still award new event/cascade bonuses.
    local base = math.min(42, self.scoring * 0.08)
    local bonus = self:MoveEnergyBonuses()
    local scoreDelta = math.max(0, base - (self.creditedScoreBase or 0))
    local bonusDelta = math.max(0, bonus - (self.creditedBonus or 0))
    self.creditedScoreBase = base
    self.creditedBonus = math.max(bonus, self.creditedBonus or 0)
    if scoreDelta > 0 or bonusDelta > 0 then
        self:Earn(scoreDelta * self:EnergyFactor() + bonusDelta)
    end
end
function R:SettleMove()
    if self.over then return end
    -- Only a fallback for a zero-wave edge case. Normal drafts are opened
    -- immediately when their clear wave fills Energy, not at move settlement.
    self:CreditWaveEnergy()
    self.scoring, self.quickBonus = 0, 0
    if self.energy >= self.maxEnergy and not self.pending then
        self.pending = true
        self:DrawOffers()
    end
end

-- Keep fractional generator progress across moves. Spawn limits are per move;
-- extra earned charges are NOT carried across a capped burst or they would
-- accumulate indefinitely and cause unbounded work in subsequent moves.
function R:GenerateCharged(spawn, field, perMove, count, kind)
    local available = math.max(0, math.min(count, 3))
    if available == 0 then return end
    local charge = (self[field] or 0) + perMove
    local creations = math.min(available, math.floor(charge))
    for _ = 1, creations do
        if not spawn(kind == "random" and
            (self.random(2) == 1 and "bomb" or "lightning") or kind) then
            break
        end
    end
    -- Keep the fractional part; discard excess over the event budget.
    self[field] = math.min(charge - math.floor(charge), 0.999999)
end
-- All deferred special creation happens only once the current move is fully
-- resolved. Newly generated pieces are not triggered within the same move.
function R:AfterMove(model)
    -- Queue every source first, then share the six-spawn budget fairly.
    -- Rotating the starting index avoids starving Chaos/Lucky/Storm upgrades
    -- whenever Bomb Factory and Static Charge are heavily stacked.
    local requests = {}
    local function spawn(kind)
        requests[#requests + 1] = kind
        return true
    end
    local bombs = self:Stacks("bomb_factory")
    if bombs > 0 then
        self:GenerateCharged(spawn, "bombCharge", 0.20 + 0.08 * (bombs - 1), 3, "bomb")
    end
    local lightning = self:Stacks("static_charge")
    if lightning > 0 then
        self:GenerateCharged(spawn, "lightningCharge", 0.24 + 0.08 * (lightning - 1), 3, "lightning")
    end
    if self:Stacks("chaos_theory") > 0 and self.moves % 10 == 0 then
        for _ = 1, 3 do spawn(self.random(2) == 1 and "bomb" or "lightning") end
    end
    local lucky = self:Stacks("lucky_strike")
    if lucky > 0 then
        self:GenerateCharged(spawn, "luckyCharge", 0.14 + 0.07 * (lucky - 1), 2, "random")
    end
    local rift = self:Stacks("gravity_rift")
    if rift > 0 and self.clearedThisMove >= math.max(6, 12 - 2 * (rift - 1)) then
        for _ = 1, math.min(2, 1 + math.floor((rift - 1) / 4)) do
            spawn("lightning")
        end
    end
    local shrapnel = self:Stacks("shrapnel")
    if shrapnel > 0 and self.bombActivations > 0 and
        self.random(100000) / 100000 <= math.min(0.9, 1 - 0.8 ^ shrapnel) then
        spawn("bomb")
    end
    if self:Stacks("stormcaller") > 0 then
        self.stormProgress = self.stormProgress + self.lightningActivations
        local threshold = math.max(1, 4 - self:Stacks("stormcaller"))
        if self.stormProgress >= threshold then
            spawn("lightning")
            self.stormProgress = self.stormProgress % threshold
        end
    end
    local multiplication = self:Stacks("crystal_multiplication")
    if multiplication > 0 then
        self.multiplicationCharge = self.multiplicationCharge
            + self.clearedThisMove * math.min(0.15, 0.01 * multiplication)
        for _ = 1, math.min(2, math.floor(self.multiplicationCharge)) do
            spawn(self.random(2) == 1 and "bomb" or "lightning")
        end
        self.multiplicationCharge = self.multiplicationCharge % 1
    end
    local unstable = self:Stacks("unstable_essence")
    if unstable > 0 then
        self:GenerateCharged(spawn, "unstableCharge", 0.12 * unstable, 2, "random")
    end
    local total = #requests
    if total > 0 then
        local start = self.moves % total + 1
        local attempts = math.min(6, total)
        for i = 0, attempts - 1 do
            model:SpawnRandomSpecial(requests[(start + i - 1) % total + 1])
        end
    end
    -- Recolor and exchange ordinary pieces only after the settled board exists.
    -- Each mutation is transactional: no automatic match or no-move deadlock.
    local trans = self:Stacks("transmutation")
    if trans > 0 and self.random(100) <= math.min(85, trans * 12) then
        model:TransmuteNormals(math.min(3, math.max(1, math.floor(trans / 5) + 1)), "random")
    end
    local magnet = self:Stacks("gem_magnet")
    if magnet > 0 and self.random(100) <= math.min(80, magnet * 10) then
        model:TransmuteNormals(math.min(3, math.max(1, math.floor(magnet / 5) + 1)), self:AttunedKind())
    end
    local storm = self:Stacks("chromatic_storm")
    if storm > 0 and self.moves % math.max(2, 7 - math.min(storm, 5)) == 0 then
        model:TransmuteNormals(math.min(4, 1 + math.floor(storm / 3)), "random")
    end
    local reversal = self:Stacks("void_reversal")
    if reversal > 0 and self.moves % math.max(2, 9 - math.min(7, reversal)) == 0 then
        model:ExchangeRandomNormals()
    end
end
function R:DrawOffers()
    local pool = {}
    for _, card in ipairs(R.Cards) do
        if self:Stacks(card.id) < card.max then pool[#pool + 1] = card end
    end
    self.offers = {}
    for _ = 1, math.min(3, #pool) do
        local tiers, total = {}, 0
        for _, rarity in ipairs(rarities) do
            local candidates = {}
            for _, card in ipairs(pool) do
                if card.rarity == rarity then candidates[#candidates + 1] = card end
            end
            if #candidates > 0 then
                local greed = math.min(40, self:Stacks("greedy_hands") * 4)
                local weight = weights[rarity] + (rarity ~= "common" and math.min(12, self.level) or 0)
                    + (rarity == "rare" and greed or 0)
                    + (rarity == "epic" and math.floor(greed * 0.65) or 0)
                    + (rarity == "legendary" and math.floor(greed * 0.35) or 0)
                tiers[#tiers + 1] = { candidates = candidates, weight = weight }
                total = total + weight
            end
        end
        local roll, tier = self.random(total)
        for _, choice in ipairs(tiers) do
            roll = roll - choice.weight
            if roll <= 0 then tier = choice; break end
        end
        local chosen = tier.candidates[self.random(#tier.candidates)]
        self.offers[#self.offers + 1] = chosen
        for i, candidate in ipairs(pool) do
            if candidate.id == chosen.id then table.remove(pool, i); break end
        end
    end
end
function R:FinishDraft()
    local fraction = clamp(self:RecoveryFraction()
        + 0.04 * self:Stacks("ascension_heal")
        - 0.03 * self:Stacks("greedy_hands"), 0.25, 0.95)
    self.energy = self.maxEnergy * fraction
    self.offers, self.pending, self.readyFor = {}, false, 0
end
function R:Choose(id)
    if not self.pending or self.over then return false end
    local selected
    for _, card in ipairs(self.offers) do
        if card.id == id and self:Stacks(id) < card.max then selected = card; break end
    end
    if not selected then return false end
    self.stacks[id] = self:Stacks(id) + 1
    self.buildRevision = self.buildRevision + 1
    self.maxEnergy = self:MaxEnergy()
    if self:Stacks("color_affinity") + self:Stacks("gem_magnet") + self:Stacks("lucky_alignment") > 0 then
        self:AttunedKind()
    end
    self.level = self.level + 1
    if self.inMove then
        -- A card acquired between cascade waves affects future effects, not
        -- special activations that already happened earlier in this swap.
        -- Keep the cumulative bonus watermark without awarding it again.
        self.creditedBonus = math.max(self.creditedBonus or 0, self:MoveEnergyBonuses())
    end
    self:FinishDraft()
    return true
end
function R:FinishReshuffleDraft()
    if not self.pending or self.over then return false end
    self:FinishDraft()
    local extra = math.min(0.95, 0.05 * self:Stacks("fate_weaver")) * self.maxEnergy
    self.energy = math.min(self.maxEnergy * 0.95, self.energy + extra)
    return true
end
function R:BuildText()
    local parts = {}
    for _, card in ipairs(R.Cards) do
        local count = self:Stacks(card.id)
        if count > 0 then parts[#parts + 1] = card.title .. (count > 1 and " x" .. count or "") end
    end
    return #parts > 0 and table.concat(parts, ", ") or "No upgrades"
end
