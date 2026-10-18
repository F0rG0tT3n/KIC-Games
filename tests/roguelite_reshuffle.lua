-- Run from the repository root: lua tests/roguelite_reshuffle.lua
local Games = {}
local function load(rel)
    assert(loadfile('KIC-Games/Games/' .. rel))('KIC-Games', Games)
end
load('Bejeweled/Engine.lua')
load('KICBejeweled/Engine.lua')
load('KICBejeweled/Roguelite.lua')
local E, R = Games.KICBejeweled.Engine, Games.KICBejeweled.Roguelite
local function counts(board)
    local bag = {}
    for y = 1, 8 do
        for x = 1, 8 do
            local gem = board[y][x]
            bag[gem] = (bag[gem] or 0) + 1
        end
    end
    return bag
end
local function equal(a, b)
    for key, value in pairs(a) do assert(b[key] == value, 'mismatched piece '..tostring(key)) end
    for key, value in pairs(b) do assert(a[key] == value, 'extra piece '..tostring(key)) end
end
local function signature(board)
    local values = {}
    for y = 1, 8 do for x = 1, 8 do values[#values+1] = board[y][x] end end
    return table.concat(values, ',')
end
local function rng(seed)
    return function(n)
        seed = (seed * 48271) % 2147483647
        return (seed % n) + 1
    end
end
local total = 0
for seed = 1, 50 do
    local model = E.New(rng(seed))
    -- Add an Orb and two types of specials; keep the exact same inventory.
    model.board[1][1] = E.Orb
    model.board[2][2] = E.Piece(E.Kind(model.board[2][2]), 'bomb')
    model.board[3][3] = E.Piece(E.Kind(model.board[3][3]), 'lightning')
    local before, original = counts(model.board), signature(model.board)
    local oldRevision = model.revision
    model.score, model.moves, model.cleared = 12345, 7, 32
    assert(model:ReshuffleAll(), 'unable to reshuffle seed ' .. seed)
    assert(signature(model.board) ~= original, 'board unchanged')
    equal(counts(model.board), before)
    assert(#model:Patterns() == 0, 'preexisting match')
    assert(model:FindMove(), 'board has no legal moves')
    assert(model.revision == oldRevision + 1, 'revision not updated')
    assert(model.score == 12345 and model.moves == 7 and model.cleared == 32, 'stats changed')
    total = total + 1
end
-- A different effect-level/score state must not influence the shuffle draft cost.
local run = R.New(rng(99))
run.stacks.capacitor_recovery = 2
run.level = 4
run.maxEnergy = 150
run.pending = true
run.offers = {R.ByID.bomb_factory, R.ByID.avalanche, R.ByID.mana_capacitor}
assert(run:FinishReshuffleDraft(), 'could not skip draft')
assert(run.energy == 105 and run.level == 4 and not run.pending, 'incorrect draft state')
assert(#run.offers == 0 and run:Stacks('capacitor_recovery') == 2, 'lost or added upgrades')
assert(not run:FinishReshuffleDraft(), 'double skip accepted')
-- Many-stack builds must always have 3 repeatable offers. Reshuffle remains
-- available as the fourth, power-free draft option.
local all = R.New(rng(98))
all.maxEnergy = 200
for _, card in ipairs(R.Cards) do
    all.stacks[card.id] = card.max == math.huge and 100 or card.max
end
all.energy = 199
all:Earn(1)
assert(all.pending and #all.offers == 3, 'repeatable draft pool depleted')
assert(all:FinishReshuffleDraft(), 'long-running build cannot reshuffle')
-- An unsolvable all-one-type board must be restored exactly on failure.
local impossible = E.New(rng(123))
for y = 1, 8 do for x = 1, 8 do impossible.board[y][x] = 1 end end
local previous = impossible.board
local rev = impossible.revision
assert(not impossible:ReshuffleAll())
assert(impossible.board == previous and impossible.revision == rev, 'failed reshuffle mutated board')
impossible.gameover = true
assert(not impossible:ReshuffleAll(), 'gameover reshuffle allowed')
print('PASS: 50 shuffles, exact piece preservation, valid moves, no instant matches, safe failure')
print('PASS: reshuffle energy cost, no power/level award, persistent repeatable card pool')
