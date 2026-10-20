-- Run from the repository root: lua tests/kic_bejeweled.lua
local Games, tests = {}, 0
assert(loadfile("KIC-Games/Games/Bejeweled/Engine.lua"))("KIC-Games", Games)
assert(loadfile("KIC-Games/Games/KICBejeweled/Engine.lua"))("KIC-Games", Games)
local E, Base = Games.KICBejeweled.Engine, Games.Bejeweled.Engine
local function check(value, message)
    assert(value, message)
    tests = tests + 1
end
local function key(x, y)
    return (y - 1) * 8 + x
end
local function plain(engine)
    local m = (engine or E).New()
    for y = 1, 8 do
        for x = 1, 8 do
            m.board[y][x] = (x + 2 * y) % 6 + 1
        end
    end
    return m
end
local function digest(m)
    local rows = {}
    for _, row in ipairs(m.board) do
        rows[#rows + 1] = table.concat(row, ",")
    end
    return table.concat(rows, ";")
end
local function plan(m, destination)
    m.cascade = 1
    m:Plan(m:Patterns(), destination)
    return m.plan
end
local function seed(m, coordinates, kind)
    for _, c in ipairs(coordinates) do
        m.board[c[2]][c[1]] = kind or 7
    end
end
local function affected(p)
    local set = {}
    for _, c in ipairs(p.cells) do
        local id = key(c.x, c.y)
        check(not set[id], "A cell was queued/scored twice")
        set[id] = true
    end
    return set
end
math.randomseed(456713)
check(E ~= Base and E.Swap ~= Base.Swap and E.Refill ~= Base.Refill, "KIC Bejeweled engine not isolated")
local constant = E.New(function()
    return 1
end)
check(#constant:Matches() == 0 and constant:FindMove(), "Bounded opening generator failed")
for count = 3, 8 do
    for _, vertical in ipairs({ false, true }) do
        local m = plain()
        for i = 1, count do
            m.board[vertical and i or 1][vertical and 1 or i] = 7
        end
        local expected = count >= 5 and "orb" or count == 4 and "bomb" or nil
        local destination = vertical and key(1, 3) or key(3, 1)
        local p = plan(m, destination)
        check(#p.cells == count, "Straight pattern lost cells")
        check(E.Special(p.created[destination]) == expected, "Wrong straight special or player placement")
        m:Step()
        check(
            E.Special(m.board[vertical and 3 or 1][vertical and 1 or 3]) == expected,
            "Special did not survive creation"
        )
        check(m.cleared == count - (expected and 1 or 0), "Creation counted survivor as removed")
        check(
            m.score == (count - (expected and 1 or 0)) * 50 + (expected and E.CreationBonus[expected] or 0),
            "Creation scoring wrong"
        )
    end
end
do
    local m = plain()
    seed(m, { { 1, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 } })
    m.board[1][2] = E.Piece(7, "bomb")
    local p = plan(m, key(1, 1))
    check(p.events.bombCreate == 1 and p.events.bombActivate == 1, "Special underlying color did not match")
    check(p.activated[key(2, 1)] and not p.activated[key(1, 1)], "New special activated during creation")
    m:Step()
    check(m.board[1][1] == E.Piece(7, "bomb"), "Explosion destroyed protected creation")
    m = plain()
    for x = 1, 5 do
        m.board[1][x] = E.Orb
    end
    check(#m:Matches() == 0, "Colorless Orbs formed an ordinary match")
    m = plain()
    m.board[1][1], m.board[1][2] = E.Piece(1, "bomb"), E.Piece(2, "lightning")
    local hint = m:FindMove()
    check(hint and hint.x == 1 and hint.y == 1 and hint.tx == 2, "No-move search missed adjacent non-Orb specials")
end
-- Actual moved-gem destination, both orientations and both swap directions.
for _, vertical in ipairs({ false, true }) do
    for _, reverse in ipairs({ false, true }) do
        local m = plain()
        seed(m, vertical and { { 1, 1 }, { 1, 2 }, { 1, 4 }, { 2, 3 } } or { { 1, 1 }, { 2, 1 }, { 4, 1 }, { 3, 2 } })
        local x, y, tx, ty = 3, 2, 3, 1
        if vertical then
            x, y, tx, ty = 2, 3, 1, 3
        end
        if reverse then
            x, y, tx, ty = tx, ty, x, y
        end
        check(m:Swap(x, y, tx, ty), "Four-forming swap rejected")
        local location = reverse and key(1, 1) or key(tx, ty)
        check(E.Special(m.plan.created[location]) == "bomb", "Destination/fallback placement wrong")
    end
end
local shapes = {
    { { 3, 3 }, { 4, 3 }, { 5, 3 }, { 4, 4 }, { 4, 5 } }, -- T
    { { 3, 3 }, { 3, 4 }, { 3, 5 }, { 4, 5 }, { 5, 5 } }, -- L
    { { 3, 4 }, { 4, 4 }, { 5, 4 }, { 4, 3 }, { 4, 5 } }, -- cross
}
for _, coordinates in ipairs(shapes) do
    local m = plain()
    seed(m, coordinates)
    local p = plan(m)
    check(#m:Patterns() == 1 and m:Patterns()[1].special == "lightning", "T/L/cross not detected")
    local first = math.huge
    for _, c in ipairs(p.cells) do
        first = math.min(first, key(c.x, c.y))
    end
    check(E.Special(p.created[first]) == "lightning", "Cascade placement is not row-major")
    m:Step()
    check(
        E.Special(m.board[math.floor((first - 1) / 8) + 1][(first - 1) % 8 + 1]) == "lightning",
        "Lightning cleared on creation"
    )
end
do
    local m = plain()
    seed(m, { { 2, 3 }, { 3, 3 }, { 4, 3 }, { 5, 3 }, { 6, 3 }, { 4, 4 }, { 4, 5 } })
    local p = plan(m)
    check(p.events.orbCreate == 1 and not p.events.lightningCreate, "Five did not override T/L")
    m = plain()
    seed(m, { { 2, 3 }, { 3, 3 }, { 4, 3 }, { 5, 3 }, { 4, 4 }, { 4, 5 } })
    p = plan(m)
    check(p.events.lightningCreate == 1 and not p.events.bombCreate, "T/L did not override four")
    m = plain()
    seed(m, { { 1, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 } })
    seed(m, { { 4, 6 }, { 5, 6 }, { 6, 6 }, { 7, 6 } }, 7)
    p = plan(m)
    check(p.events.bombCreate == 2 and #p.cells == 8, "Independent patterns merged or lost")
    m = plain()
    seed(m, { { 1, 1 }, { 2, 1 }, { 3, 1 }, { 5, 5 }, { 6, 5 }, { 7, 5 } })
    p = plan(m)
    check(not next(p.created), "Separate triples misidentified as T/L")
end
-- Activate exactly one special using a synthetic hit, independent of matching.
for _, special in ipairs({ "bomb", "lightning" }) do
    for _, center in ipairs({ { 1, 1 }, { 8, 1 }, { 1, 8 }, { 8, 8 }, { 4, 4 }, { 1, 4 } }) do
        local m, x, y = plain(), center[1], center[2]
        m.board[y][x] = E.Piece(1, special)
        m.cascade = 1
        m:Plan({ { cells = { key(x, y) }, longest = 3 } })
        local set = affected(m.plan)
        for yy = 1, 8 do
            for xx = 1, 8 do
                local expected = special == "bomb" and math.abs(xx - x) <= 1 and math.abs(yy - y) <= 1
                    or special == "lightning" and (xx == x or yy == y)
                check((set[key(xx, yy)] == true) == expected, "Wrong activation footprint/edge clipping")
            end
        end
        check(m.plan.activations == 1 and m.plan.events[special .. "Activate"] == 1, "Double activation")
    end
end
for kind = 1, 7 do
    for _, reverse in ipairs({ false, true }) do
        local m = plain()
        m.board[4][4], m.board[4][5] = E.Orb, kind
        local expected = { [key(4, 4)] = true, [key(5, 4)] = true }
        for y = 1, 8 do
            for x = 1, 8 do
                if m.board[y][x] == kind then
                    expected[key(x, y)] = true
                end
            end
        end
        check(m:Swap(reverse and 5 or 4, 4, reverse and 4 or 5, 4), "Orb-normal swap rejected")
        local set = affected(m.plan)
        for id = 1, 64 do
            check(set[id] == expected[id], "Orb targeted wrong color")
        end
        check(m.plan.activations == 1 and not m.plan.events.combination, "Orb-normal scored special combo")
    end
end
for _, combo in ipairs({
    { "bomb", "bomb" },
    { "bomb", "lightning" },
    { "lightning", "lightning" },
    { "orb", "bomb" },
    { "orb", "lightning" },
    { "orb", "orb" },
}) do
    for _, reverse in ipairs({ false, true }) do
        for _, origin in ipairs({ { 3, 4 }, { 1, 1 }, { 7, 8 } }) do
            local m, x, y = plain(), origin[1], origin[2]
            m.board[y][x], m.board[y][x + 1] = E.Piece(2, combo[1]), E.Piece(2, combo[2])
            local from, to = reverse and x + 1 or x, reverse and x or x + 1
            check(m:Swap(from, y, to, y), "Direct special swap rejected")
            local p, expected = m.plan, {}
            local function area(cx, cy, cross, radius)
                for yy = 1, 8 do
                    for xx = 1, 8 do
                        if
                            cross and (math.abs(xx - cx) <= radius or math.abs(yy - cy) <= radius)
                            or not cross and math.abs(xx - cx) <= radius and math.abs(yy - cy) <= radius
                        then
                            expected[key(xx, yy)] = true
                        end
                    end
                end
            end
            if combo[1] ~= "orb" then
                area(to, y, combo[2] ~= "bomb", combo[2] == "bomb" and 2 or 1)
            elseif combo[2] == "orb" then
                for id = 1, 64 do
                    expected[id] = true
                end
            else
                expected[key(from, y)], expected[key(to, y)] = true, true
                for yy = 1, 8 do
                    for xx = 1, 8 do
                        if E.Kind(m.board[yy][xx]) == 2 then
                            area(xx, yy, combo[2] == "lightning", combo[2] == "bomb" and 1 or 0)
                        end
                    end
                end
            end
            local set = affected(p)
            for id = 1, 64 do
                check(set[id] == expected[id], "Combination footprint mismatch: " .. table.concat(combo, "+"))
            end
            check(
                p.events.combination == 1 and not next(p.created),
                "Combination created a survivor or duplicate bonus"
            )
            check(p.activations <= 64, "Unbounded queue")
            local gain = p.gain
            m:Step()
            check(m.score == gain and m.cleared == #p.cells and m.phase == "falling", "Combo score/phase wrong")
        end
    end
end
do
    local m = plain()
    for y = 1, 8 do
        for x = 1, 8 do
            m.board[y][x] = E.Piece((x + y) % 7 + 1, "bomb")
        end
    end
    m.board[1][1] = E.Orb
    m.cascade = 2
    m:Plan({ { cells = { key(4, 4) }, longest = 3 } })
    local p = m.plan
    check(#affected(p) == 64 and p.activations == 64, "Dense chain did not terminate/visit all specials once")
    check(
        p.events.bombActivate == 63 and p.events.orbActivate == 1 and p.events.majorChain == 1,
        "Chain bonuses duplicated"
    )
    check(p.gain == (64 * 50 + 63 * 150 + 400 + 250) * 2, "Chain score wrong")
    m.score = 2147483640
    m:Step()
    check(m.score == 2147483647, "Score overflow")
end
do
    local m = plain()
    local before = digest(m)
    check(not m:FindMove(), "Plain board has a phantom move")
    for _, coords in ipairs({ { 1, 1, 2, 1 }, { 0, 1, 1, 1 }, { 1, 1, 3, 1 }, { 1.5, 1, 2, 1 } }) do
        check(not m:Swap(table.unpack(coords)) and before == digest(m) and m.moves == 0, "Invalid swap failed rollback")
    end
    m.board[1][1] = E.Orb
    m:CheckEnd()
    check(not m.gameover and m:FindMove(), "Special move missing from no-moves search")
    check(m:Swap(1, 1, 2, 1), "Legal Orb swap rejected")
    check(not m:Swap(1, 1, 2, 1) and m.moves == 1, "Resolution accepted duplicate move")
    m:Step()
    check(not m:Swap(1, 1, 2, 1), "Falling accepted input")
    m = plain()
    m.board[6][1], m.board[7][1], m.board[8][1] = E.Piece(3, "lightning"), E.Orb, nil
    local drops = m:Refill()
    check(m.board[8][1] == E.Orb and m.board[7][1] == E.Piece(3, "lightning"), "Gravity lost special identity/order")
    check(drops[key(1, 8)] == 7 and drops[key(1, 7)] == 6, "Special animation origins wrong")
    local standard = plain(Base)
    for x = 1, 5 do
        standard.board[1][x] = 7
    end
    standard.pending, standard.cascade, standard.phase = standard:Matches(), 1, "clearing"
    standard:Step()
    check(standard.score == 250 and standard.board[1][1] == nil, "Original rules changed")
end
-- Randomized real moves exercise full refill/cascade completion and invariants.
for run = 1, 30 do
    local m = E.New()
    check(#m:Matches() == 0 and m:FindMove(), "Bad initial board")
    for move = 1, 50 do
        if m.gameover then
            break
        end
        local before, hint = digest(m), m:FindMove()
        check(
            digest(m) == before and hint and m:Swap(hint.x, hint.y, hint.tx, hint.ty),
            "Hint mutated board or invalid"
        )
        local steps = 0
        while m.phase == "clearing" or m.phase == "falling" do
            if m.plan then
                affected(m.plan)
                check(m.plan.activations <= 64, "Unbounded activation")
            end
            m:Step()
            steps = steps + 1
            check(steps < 200, "Cascade did not complete")
        end
        check(#m:Matches() == 0 and m.moves == move and m.gameover == (m:FindMove() == nil), "Unsettled board")
        for y = 1, 8 do
            for x = 1, 8 do
                local piece = m.board[y][x]
                check(type(piece) == "number" and piece >= 1 and piece <= 22, "Refill has invalid piece")
            end
        end
    end
end
-- Full addon in the existing mocked-client harness, including actual UI paths.
local previous = arg[1]
arg[1] = "--harness"
local harness = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = harness.client("KICGemTester", "GemRealm", {
    bejeweled = { best = { score = 1234, moves = 12 } },
    tetris = { best = { score = 4321 } },
})
owner.grouped = false
local G, D = owner.games, owner.games.KICBejeweled
check(
    G.Registry.bejeweled and G.Registry.kic_bejeweled and #G:GetGames("singleplayer") == 5,
    "Independent registration missing"
)
check(G.Registry.kic_bejeweled.title == "KIC Bejeweled", "Wrong title")
G.UI:OpenLauncher("singleplayer")
check(G.UI.launcherCards[3].icon.textureValue == G.Artwork["kic-bejeweled-card"].file, "KIC Bejeweled card missing")
G.UI:OpenLauncher("home")
G.UI:FeatureGame("kic_bejeweled")
check(
    G.UI.heroArt.textureValue == G.Artwork["kic-bejeweled-hero"].file
        and G.Artwork["kic-bejeweled-hero"].textSide == "left",
    "Wrong hero"
)
check(G:StartSingleplayer("kic_bejeweled") and D.running and #D.cells == 64, "KIC Bejeweled not playable")
D:ChooseMode("roguelike")
check(D.title.text == "KIC BEJEWELED" and G.DB.recentGames[1] == "kic_bejeweled", "Title/recent integration missing")
check(D.root ~= G.Bejeweled.root and D.Gems ~= G.Bejeweled.Gems, "UI state shared")
local baseIcons = G:GetPieceIcons("bejeweled")
for _, theme in ipairs({ "original", "class" }) do
    G:SetOption("graphicsTheme", theme)
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        G.UI:SetWindowScale(scale)
        for i, special in ipairs({ "bomb", "lightning", "orb" }) do
            D.model.board[1][i] = E.Piece(i, special)
        end
        D:Render()
        for i, special in ipairs({ "bomb", "lightning", "orb" }) do
            local c = D.cells[i]
            check(c.width == c.height and c.specialArt.label:IsShown(), "Special overlay/scaling missing")
            check(c.specialArt.overlay.points[1][2] == c.icon, "Special not anchored to moving icon")
            if i < 3 then
                check(
                    c.icon.textureValue == G:GetPieceIcons("bejeweled")[i],
                    "Special replaced underlying class/original icon"
                )
            end
        end
        check(#G:GetPieceIcons("bejeweled") == 7, "KIC Bejeweled mutated shared graphics")
    end
end
check(#baseIcons == 7, "Shared class icons mutated")
G.UI:SetWindowScale(1)
D.model = plain(D.Engine)
D:Render()
local before = digest(D.model)
check(not D:TrySwap(1, 1, 2, 1) and D.swap and not D.swap.valid, "UI rollback missing")
for _ = 1, 4 do
    D:Advance(0.1)
end
check(not D.swap and digest(D.model) == before, "UI rollback did not finish")
D.model.board[4][4], D.model.board[4][5] = E.Piece(1, "bomb"), E.Piece(2, "lightning")
D:Render()
-- Exact same directional drag path, including one-attempt suppression on release.
local scale = D.board:GetEffectiveScale()
owner.env.cursorX = (D.board:GetLeft() + D.boardInset + 3 * D.step + D.tileSize / 2) * scale
owner.env.cursorY = (D.board:GetTop() - D.boardInset - 3 * D.step - D.tileSize / 2) * scale
owner.env.mouseDown = true
local source = D.cells[key(4, 4)]
source.scripts.OnMouseDown(source, "LeftButton")
check(D.drag and D.dragFrame.specialArt.label.text == "BOMB", "Special drag ghost missing")
owner.env.cursorX = owner.env.cursorX + D.step * scale
D:UpdateDrag()
check(D.swap and D.swap.valid and D.model.moves == 1, "Directional special swap failed")
owner.env.mouseDown = false
source.scripts.OnMouseUp(source, "LeftButton")
source.scripts.OnClick(source, "LeftButton")
check(D.model.moves == 1, "Drag release duplicated swap")
local model, p = D.model, D.model.plan
D:Pause(true)
D:Advance(1)
check(D.model == model and D.model.plan == p and D.swap.time == 0, "Pause advanced resolution")
G.UI:ShowHome()
check(G.UI.continueButton:IsShown(), "KIC Bejeweled resume button missing")
G.UI.continueButton.scripts.OnClick()
check(D.model == model and not D.paused, "Resume discarded run")
for _ = 1, 400 do
    harness.advance(0.1)
    D:Advance(0.1)
    if D.run.pending then D:ReshuffleDraft() end
    if model.phase == "idle" and not D.fall then
        break
    end
end
check(model.phase == "idle" and model.score > 0, "UI resolution failed to settle")
check(
    D:Storage().best.score == model.score and G.DB.bejeweled.best.score == 1234 and G.DB.tetris.best.score == 4321,
    "Scores not isolated"
)
-- Every hook is audible through the shared volume path; mute and zero silence it.
for _, theme in ipairs({ "arcade", "class" }) do
    G:SetOption("soundTheme", theme)
    G:SetOption("soundsEnabled", true)
    G:SetOption("soundVolume", 0.25)
    for name in pairs(D.SoundEvents) do
        harness.advance(1)
        local count = #owner.sounds
        D:PlayResolution({ events = { [name] = 1 } }, 2)
        check(
            #owner.sounds == count + 1
                and owner.sounds[#owner.sounds].volume == 0.25 * G.Audio.gain
                and owner.sounds[#owner.sounds].channel == "Master",
            "Special hook bypassed volume/channel: " .. name
        )
        D:PlayResolution({ events = { [name] = 1 } }, 2)
        check(#owner.sounds == count + 1, "Resolution sound not throttled")
    end
    for _, muted in ipairs({ true, false }) do
        G:SetOption("soundsEnabled", not muted)
        G:SetOption("soundVolume", muted and 0.25 or 0)
        local count = #owner.sounds
        harness.advance(1)
        D:PlayResolution({ events = { combination = 1, majorChain = 1 } }, 1)
        check(#owner.sounds == count, "Mute/zero volume leaked special sound")
    end
end
G:SetOption("effectsLevel", 0)
check(not D.matchEffect and D.effectFlash.alpha == 0, "Effects off left KIC Bejeweled animation")
local best = D:Storage().best.score
D:Pause(true)
D.pauseOverlay.restart.scripts.OnClick()
D:ChooseMode("roguelike")
check(
    D.running
        and not D.paused
        and D.model ~= model
        and D.model.score == 0
        and not D.model.plan
        and not D.swap
        and not D.fall
        and not D.drag
        and not D.matchEffect,
    "Restart kept transient state"
)
check(D:Storage().best.score == best, "Restart erased best")
D.model = plain(D.Engine)
D.model.score = best + 100
D.model:CheckEnd()
D:Advance(0)
check(not G.ActiveGame and not D.running and D.summary:IsShown(), "No-moves finish missing")
local results = G:GetResults("kic_bejeweled")
check(results[1].entries[1].score == best + 100 and #G:GetResults("bejeweled") == 0, "Result isolation failed")
G.UI:ShowResults()
G.UI.resultGameID = "kic_bejeweled"
G.UI:RefreshResults()
check(
    G.UI.bestScore.text == (best + 100) .. " points" and G.UI.bestMetadata.text:find("Gems:", 1, true),
    "Results best/metadata missing"
)
local reload = harness.client("KICGemTester", "GemRealm", G.DB)
check(
    reload.games.KICBejeweled:Storage().best.score == best + 100
        and reload.games.Bejeweled:Storage().best.score == 1234
        and reload.games.DB.tetris.best.score == 4321,
    "Reload lost or migrated scores"
)
check(#reload.games:GetResults("kic_bejeweled") == #results, "Reload lost history")
G:StartSingleplayer("kic_bejeweled")
D:ChooseMode("roguelike")
G.UI.frame:Hide()
check(D.paused, "Close did not pause")
G.UI.frame:Show()
G.UI:ShowGame()
D:Pause(false)
D.pauseOverlay.stop.scripts.OnClick()
check(not D.running and not G.ActiveGame and G.UI.frame:IsShown(), "Stop lifecycle failed")
check(#harness.packets == 0, "KIC Bejeweled emitted network traffic")
print(string.format("PASS: %d KIC Bejeweled engine and integration assertions", tests))
