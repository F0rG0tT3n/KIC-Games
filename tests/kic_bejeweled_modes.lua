-- Run from repository root: lua tests/kic_bejeweled_modes.lua
local previous = arg[1]
arg[1] = "--harness"
local harness = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = harness.client("ModeTester", "Realm", {
    kic_bejeweled = {
        best = { score = 100, moves = 1, cleared = 3, bestCascade = 1 },
        arcaneRush = { best = { score = 2222, moves = 10, cleared = 30, bestCascade = 2 } },
    },
})
local G, D, checks = owner.games, owner.games.KICBejeweled, 0
local E = D.Engine
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function start()
    check(G:StartSingleplayer("kic_bejeweled"), "New game did not start")
    check(D.choosingMode and D.modeDim:IsShown() and not D.run and not D.model.roguelite,
        "New game must wait for mode selection without a survival run")
    check(D:Blocked() and not D.energyFrame:IsShown() and not D.energyBarFrame:IsShown()
        and not D.draftDim:IsShown(), "Pending selection allows gameplay or shows upgrade UI")
end
local function board()
    for y = 1, 8 do for x = 1, 8 do D.model.board[y][x] = (x + 2 * y) % 7 + 1 end end
    D.model.board[1][1], D.model.board[1][2], D.model.board[1][3], D.model.board[2][2] = 1, 2, 1, 1
    D.model.phase, D.model.gameover = "idle", false
    D:Render()
end
local function reopen()
    local model, run, mode = D.model, D.run, D.mode
    G.UI:ShowHome()
    owner.env.SlashCmdList.KICBEJEWELED("")
    check(D.model == model and D.run == run and D.mode == mode, "Reopen changed the active run")
    D:Pause(false)
end
start()
check(D.modeCards.normal.record.text == "Best: 100" and D.modeCards.roguelike.record.text == "Best: 2222",
    "Picker must display separate mode records")
local revision = D.model.revision
for _ = 1, 30 do D:Advance(1) end
check(D.model.score == 0 and D.model.moves == 0 and D.model.revision == revision,
    "Game advanced before a mode was selected")
check(not D:TrySwap(2, 1, 2, 2) and not D:Hint(), "Input accepted before selection")
check(not D:ChooseMode("unknown") and D.choosingMode, "Invalid mode bypassed picker")
reopen()
check(D.choosingMode and D.modeDim:IsShown(), "Pending picker lost on reopen")
D.modeCards.normal.button.scripts.OnClick()
check(D.mode == "normal" and not D.choosingMode and not D.modeDim:IsShown(), "Normal button failed")
check(not D.run and not D.model.roguelite and not D.energyFrame:IsShown()
    and not D.energyBarFrame:IsShown() and not D.draftDim:IsShown(), "Normal enabled survival features")
check(not D:ChooseMode("roguelike") and D.mode == "normal", "Mode changed in the middle of a run")
check(D.tagline.text:find("NORMAL", 1, true) and not D.tipText.text:find("Energy", 1, true),
    "Normal retains roguelike instructions")
board()
for _ = 1, 600 do D:Advance(0.1) end
check(D.running and D.model.score == 0 and not D.run, "Waiting ended Normal mode")
reopen()
check(not D.modeDim:IsShown() and not D.choosingMode, "Reopen presented a new mode choice")

-- Use actual special combos and the full renderer/animation lifecycle in Normal.
D.model.board[4][4], D.model.board[4][5] = E.Piece(1, "bomb"), E.Piece(2, "lightning")
D.model.board[8][8] = E.Orb
D:Render()
check(D.cells[28].specialArt.special == "bomb" and D.cells[29].specialArt.special == "lightning"
    and D.cells[64].specialArt.special == "orb", "Normal lost Bomb, Zap or Orb artwork")
check(D:TrySwap(4, 4, 5, 4), "Normal rejected special combination")
for _ = 1, 400 do
    D:Advance(0.1)
    check(not D.run and not D.draftDim:IsShown() and not D.modeDim:IsShown(),
        "Normal cascade triggered a draft or mode choice")
    if D.model.phase == "idle" and not D.swap and not D.fall then break end
end
check(D.model.phase == "idle" and D.model.score > 100, "Normal combo did not settle/score")
local normalScore = D.model.score
check(G.DB.kic_bejeweled.best.score == normalScore and G.DB.kic_bejeweled.arcaneRush.best.score == 2222,
    "Normal overwrote Roguelike record")
owner.grouped, owner.channel = true, "INSTANCE_CHAT"
D:ShareBest()
check(owner.chatMessages[#owner.chatMessages].message:find("KIC Bejeweled (Normal) best:", 1, true),
    "Shared record does not identify Normal mode")
D:Pause(false)
D.model.phase, D.model.gameover = "over", true
D:Advance(0)
check(not D.running and D.summary:IsShown() and D.summaryHeading.text == "NO MOVES LEFT",
    "Normal no-moves completion failed")
check(G.LastResult.summary:find("Normal:", 1, true)
    and not D.summaryText.text:find("Ascension", 1, true), "Normal completion uses survival summary")
G.UI:ShowResults()
G.UI.resultGameID = "kic_bejeweled"
G.UI:RefreshResults()
check(G.UI.bestScore.text == normalScore .. " points"
    and G.UI.bestMetadata.text:find("Mode: Normal", 1, true), "Results uses wrong mode record")

start()
check(D.modeCards.normal.record.text == "Best: " .. normalScore, "Picker lost updated Normal best")
D.modeCards.roguelike.button.scripts.OnClick()
check(D.mode == "roguelike" and D.run and D.model.roguelite == D.run
    and D.run.energy == 70 and D.run.level == 0, "Roguelike did not initialize existing rules")
check(D.energyFrame:IsShown() and D.energyBarFrame:IsShown(), "Roguelike Energy HUD missing")
D:Advance(0.1)
check(D.run.energy < 70, "Roguelike Energy no longer drains")
reopen()
check(not D.modeDim:IsShown(), "Reopened Roguelike asks for a mode again")
board()
D.run.energy = 88
check(D:TrySwap(2, 1, 2, 2), "Roguelike fixture swap rejected")
for _ = 1, 100 do
    D:Advance(0.1)
    if D.run.pending then break end
end
check(D.run.pending and D.draftDim:IsShown() and not D.modeDim:IsShown(), "Roguelike draft no longer opens")
D.draftCards[1].button.scripts.OnClick()
check(D.run.level == 1 and not D.run.pending, "Roguelike card choice no longer grants levels")

-- Restart always offers a fresh choice; switching away drops all survival state.
D:Pause(true)
D.pauseOverlay.restart.scripts.OnClick()
check(D.choosingMode and D.modeDim:IsShown() and not D.run and not D.model.roguelite,
    "Restart retained mode or survival upgrades")
D.modeCards.normal.button.scripts.OnClick()
check(D.mode == "normal" and not D.run and not D.energyFrame:IsShown()
    and not D.energyBarFrame:IsShown() and not D.draftDim:IsShown(), "Roguelike state leaked into Normal")
check(D:Storage().best.score == normalScore and D.tagline.text:find("NORMAL", 1, true),
    "Switching to Normal lost record or instructions")
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    G.UI:SetWindowScale(scale)
    check(not D.energyFrame:IsShown() and not D.energyBarFrame:IsShown(), "Layout re-enabled survival HUD")
end
local reload = harness.client("ModeTester", "Realm", G.DB).games
check(reload.KICBejeweled:GetMode() == "normal" and reload.UI:GetPersonalBest("kic_bejeweled").score == normalScore,
    "Reload forgot last record mode")
G:AbortGame()
start()
local normalBest, rogueBest = G.DB.kic_bejeweled.best.score, G.DB.kic_bejeweled.arcaneRush.best.score
D.modeCancel.scripts.OnClick()
check(not G.ActiveGame and not D.running and not D.modeDim:IsShown(), "Cancel did not leave picker")
check(G.DB.kic_bejeweled.best.score == normalBest and G.DB.kic_bejeweled.arcaneRush.best.score == rogueBest,
    "Cancel changed records")
start()
check(D.choosingMode, "New run after cancel skipped picker")
G:AbortGame()
check(#harness.packets == 0, "Mode selection emitted multiplayer traffic")
print(string.format("PASS: %d KIC Bejeweled mode selection and isolation assertions", checks))
