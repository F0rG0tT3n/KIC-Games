local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks = 0
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local c = h.client("Miner", "Realm")
c.grouped = false
local G, U, M = c.games, c.games.UI, c.games.Minesweeper
local function click(i, button)
    M.cells[i].scripts.OnClick(M.cells[i], button or "LeftButton")
end
local function new(difficulty)
    check(M:NewGame(difficulty), "Could not start " .. difficulty)
    check(G.ActiveGame.game.id == "minesweeper" and M.running, "Session did not start")
end
local function win()
    if M.model.state == "ready" then
        click(1)
    end
    h.advance(12.345)
    for i, cell in ipairs(M.model.cells) do
        if not cell.mine and not cell.revealed then
            click(i)
        end
    end
end

check(G.Registry.minesweeper.mode == "singleplayer", "Missing solo registry entry")
U:OpenLauncher("singleplayer")
local found = false
for _, card in ipairs(U.launcherCards) do
    if card.game and card.game.id == "minesweeper" then
        found = true
    end
end
check(found, "Singleplayer library omitted Minesweeper")
for _, card in ipairs(U.launcherCards) do
    if card.game and card.game.id == "minesweeper" then
        check(card.icon.textureValue == G.Artwork["minesweeper-card"].file, "Library tile uses the wrong artwork")
        check(card.game.mode == "singleplayer", "Library tile is not singleplayer")
    end
end
U:OpenLauncher("home")
U:FeatureGame("minesweeper")
check(U.heroArt.textureValue == G.Artwork["minesweeper-hero"].file, "Hero ignores Minesweeper artwork")
check(G.Registry.minesweeper.icon == G.Artwork["minesweeper-card"].file, "Card icon ignores supplied artwork")
check(G:StartSingleplayer("minesweeper"), "Launcher start failed")
check(M.board:GetParent() == M.root and M.cells[81]:IsShown(), "Initial board missing")
click(81, "RightButton")
check(M.model.flagged == 1 and M:Elapsed() == 0 and not M.startedAt, "Marking starts the timer")
click(81, "RightButton")
click(81, "RightButton")
click(1)
check(M.startedAt and M.model.state == "playing", "Reveal did not start timer")
h.advance(4.2)
M.root.scripts.OnUpdate(M.root, 0.2)
check(M:Elapsed() >= 4.2 and M.readouts[1].value.text == "00:04.2", "Timer did not advance")
local model = M.model
U:OpenLauncher("home")
h.advance(2)
U:ShowGame()
check(M.model == model and M:Elapsed() >= 6.2, "Launcher navigation reset or paused the timed run")
for _, dimensions in ipairs({ { 1000, 640 }, { 1120, 700 }, { 1500, 850 } }) do
    U:SetWindowSize(dimensions[1], dimensions[2])
    for _, difficulty in ipairs(M.Engine.Difficulties) do
        new(difficulty.id)
        check(
            M.board:GetWidth() <= M.root:GetWidth() - M.left:GetWidth() - M.right:GetWidth() - 32,
            "Board exceeds center width"
        )
        check(
            M.board:GetHeight() < M.root:GetHeight() - 90 and M.cellSize >= 16,
            string.format(
                "Board height or cell legibility regressed: %s, board=%s root=%s cell=%s",
                difficulty.id,
                M.board:GetHeight(),
                M.root:GetHeight(),
                M.cellSize
            )
        )
        check(#M.cells <= 480 and M.cells[difficulty.width * difficulty.height]:IsShown(), "Wrong board cell pool")
    end
end
new("beginner")
local frames = #c.frames
new("beginner")
check(#c.frames == frames, "Restart leaked UI frames")
win()
check(not G.ActiveGame and not G.Lobby, "Win did not finalize the framework session")
check(
    M.boardTitle.text:find("WIN", 1, true) and M.board:GetParent() == M.root,
    "Win moved the board out of the game view"
)
check(
    U.frame:IsShown() and U.gameContainer:IsShown() and M.root:IsVisible() and not U.home:IsShown(),
    "Win did not keep the three-panel game visible in the main window"
)
check(M.summary:IsShown() and c.env.KICGamesMinesweeperResult == M.summary, "Win result popup missing")
check(
    M.summary.heading.text:find("WIN", 1, true) and M.summary.details.text:find("Score: " .. M.model.revealed, 1, true),
    "Win popup omits outcome or score"
)
check(M.summary:GetWidth() == 440 and M.summary:GetHeight() == 284, "Result popup differs from Bejeweled sizing")
check(M.summary:GetScale() == U.frame:GetScale(), "Result popup ignores interface scale")
M.summary:Hide()
check(M.root:IsVisible() and M.board:GetParent() == M.root, "Closing the popup hid or moved the board")
check(M.restart.text == "Play again", "Finished board has no replay action")
check(M.newBest and M:Storage().best.beginner == M.finishedTime, "Best time not saved")
check(G:GetResults("minesweeper")[1].entries[1].outcome == "win", "Framework history lost win outcome")
check(G:GetResults("minesweeper")[1].entries[1].score == M.model.revealed, "Framework history lost the score")
local resultCount = #G:GetResults("minesweeper")
for _, dimensions in ipairs({ { 1000, 700 }, { 1500, 850 } }) do
    U:SetWindowSize(dimensions[1], dimensions[2])
    U:Refresh()
    U:ShowGame()
    check(
        M.root:IsVisible() and M.board:GetParent() == M.root and not U.home:IsShown(),
        "Refreshing or resizing discarded the completed board"
    )
    check(M.root:GetWidth() == U.frame:GetWidth() - 40, "Completed board lost the normal game layout")
end
check(#G:GetResults("minesweeper") == resultCount, "Viewing a completed board duplicated the result")
local saved, finished = M:Storage().best.beginner, M.finishedTime
h.advance(20)
click(2, "RightButton")
check(M:Elapsed() == finished, "Finished timer or cells still active")
new("beginner")
check(
    M.board:GetParent() == M.root and not U.completedGame and M.restart.text == "New game",
    "Restart did not reset the normal game view"
)
click(1)
local wrongFlag, mine
for i, cell in ipairs(M.model.cells) do
    if cell.mine and not mine then
        mine = i
    end
    if not cell.mine and not cell.revealed and not wrongFlag then
        wrongFlag = i
    end
end
click(wrongFlag, "RightButton")
click(mine)
check(
    M.root:IsVisible() and U.gameContainer:IsShown() and M.boardTitle.text:find("LOSS", 1, true),
    "Inline loss result missing"
)
check(
    M.board:GetParent() == M.root and M.left:IsVisible() and M.right:IsVisible(),
    "Loss moved the board or hid its panels"
)
check(
    M.summary:IsShown()
        and M.summary.heading.text:find("GAME OVER", 1, true)
        and M.summary.details.text:find("Score: " .. M.model.revealed, 1, true),
    "Loss popup omits outcome or score"
)
check(M.cells[wrongFlag].text.text == "X" and M.cells[mine].text.text == "*", "Postmortem omits mines/incorrect flags")
check(
    M:Storage().best.beginner == saved and G:GetResults("minesweeper")[1].entries[1].outcome == "loss",
    "Loss changed best/history"
)
for _, id in ipairs({ "intermediate", "expert" }) do
    new(id)
    win()
    check(M:Storage().best[id] ~= nil, "Difficulty best missing")
end
new("beginner")
h.advance(60)
win()
check(M:Storage().best.beginner == saved, "A slower win replaced the best time")
M.summary.again.scripts.OnClick()
check(M.running and M.model.state == "ready" and not M.summary:IsShown(), "Popup Play again failed")
G:AbortGame()
check(not M.running and not U.completedGame and not M.root:IsShown(), "Abort left active UI")
U:OpenLauncher("home")
check(G:GetRecentGames()[1].id == "minesweeper", "Minesweeper omitted from Home recent cards")
check(
    U.launcherCards[1].game.id == "minesweeper"
        and U.launcherCards[1].icon.textureValue == G.Artwork["minesweeper-card"].file,
    "Home recent card omitted Minesweeper artwork"
)
U:FeatureGame("minesweeper")
check(U.heroRecord.text == "Beginner best: " .. M:TimeText(saved), "Home best time does not match saved data")
new("beginner")
win()
M.summary.menu.scripts.OnClick()
check(
    not U.completedGame and not M.root:IsShown() and U.home:IsShown() and not M.summary:IsShown(),
    "Popup Back to menu retained the completed view"
)
check(G:StartSingleplayer("tetris"), "Could not start another game after viewing a result")
check(
    G.Tetris.root:IsVisible() and not M.root:IsShown() and not U.completedGame,
    "Completed board leaked into another game"
)
G:AbortGame()
new("beginner")
win()
check(G:StartSingleplayer("tetris"), "Direct game start blocked by a completed Minesweeper board")
check(
    G.Tetris.root:IsVisible() and not M.root:IsShown() and not U.completedGame and not M.summary:IsShown(),
    "Direct start retained the old board or popup"
)
G:AbortGame()
local restored = h.client("Miner", "Realm", G.Copy(G.DB))
check(restored.games.Minesweeper:Storage().best.beginner == saved, "Best times did not survive reload")
restored.games.DB.minesweeper = { difficulty = "bad", best = { beginner = 0 / 0, intermediate = -1, expert = "bad" } }
local clean = restored.games.Minesweeper:Storage()
check(clean.difficulty == "beginner" and not next(clean.best), "Malformed saved data not repaired")
check(#c.notices == 0, "Lifecycle emitted errors: " .. table.concat(c.notices, "; "))
print("PASS: Minesweeper UI, lifecycle, persistence and artwork, " .. checks .. " checks")
