local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks = 0
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local c = h.client("Slider", "Realm")
c.grouped = false
local Games, U, G = c.games, c.games.UI, c.games.Game2048
local function settle()
    G:Advance(0.25)
    G:Advance(0.25)
end
local function fixture(values)
    G:CancelDrag()
    G.animation, G.pop = nil, nil
    for i = 1, 16 do
        G.model.board[i] = values[i] or 0
    end
    G.model.score, G.model.moves, G.model.state = 0, 0, "playing"
    G.model.random = function(n)
        return n
    end
    G:Render()
end
local function begin(button)
    c.env.mouseDown = true
    c.env.cursorX, c.env.cursorY = 400, 500
    G.canvas.scripts.OnMouseDown(G.canvas, button or "LeftButton")
end
local function finish(dx, dy, outside)
    c.env.cursorX, c.env.cursorY = c.env.cursorX + dx, c.env.cursorY + dy
    c.env.mouseDown = false
    if outside then
        G:Advance(0.01)
    else
        G.canvas.scripts.OnMouseUp(G.canvas, "LeftButton")
    end
end

check(Games.Registry["2048"].mode == "singleplayer", "2048 registration missing")
U:OpenLauncher("singleplayer")
local card
for _, entry in ipairs(U.launcherCards) do
    if entry.game and entry.game.id == "2048" then
        card = entry
    end
end
check(card and card.icon.textureValue == Games.Artwork["2048-card"].file, "2048 tile/artwork missing")
U:OpenLauncher("home")
U:FeatureGame("2048")
check(U.heroArt.textureValue == Games.Artwork["2048-hero"].file, "Supplied hero not selected")
U.soloPlay.scripts.OnClick()
check(G.running and G.root:IsVisible() and Games.ActiveGame.game.id == "2048", "Launcher did not start 2048")
local frames = #c.frames
for _ = 1, 3 do
    check(G:NewGame(), "Restart failed")
end
check(#c.frames == frames, "Restart leaked frames")

for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    U:SetWindowScale(scale)
    local physical = G.step * 0.8 * G.canvas:GetEffectiveScale()
    for _, direction in ipairs({ { -physical, 0, 1 }, { physical, 0, 4 }, { 0, physical, 1 }, { 0, -physical, 13 } }) do
        fixture(direction[2] == 0 and { 2, 2 } or { 2, 0, 0, 0, 2 })
        begin()
        check(G.drag ~= nil, "Left press did not begin a gesture")
        finish(direction[1], direction[2])
        check(
            not G.drag and G.model.moves == 1 and G.model.score == 4 and G.model.board[direction[3]] == 4,
            "Scaled swipe direction or merge incorrect"
        )
        check(G.animation and not G:Move("right"), "Animation accepted overlapping moves")
        settle()
        check(not G.animation and not G.pop, "Animation did not finish")
    end
end
fixture({ 2, 2 })
begin()
finish(3, 4)
check(G.model.moves == 0 and not G.drag, "Small click jitter moved the board")
begin("RightButton")
check(not G.drag, "Right mouse began a swipe")
c.env.mouseDown = false
begin()
finish(-2000, 0, true)
check(G.model.moves == 1 and not G.drag, "Release outside board lost or duplicated a gesture")
settle()
fixture({ 2, 2 })
begin()
c.env.cursorX = c.env.cursorX - 100
c.env.keyboardFocus = {}
G:Advance(0.02)
check(not G.drag and G.model.moves == 0, "Chat focus did not cancel a gesture")
G:KeyDown("LEFT")
check(G.model.moves == 0 and G.root.propagate, "Typing intercepted gameplay keys")
c.env.keyboardFocus = nil
c.env.mouseDown = false
begin()
U:SetWindowScale(1)
finish(-100, 0)
check(G.model.moves == 0, "Scale change committed an old gesture")
fixture({ 2, 2 })
begin()
U:SetWindowSize(1000, 700)
finish(-100, 0)
check(G.model.moves == 0, "Resize committed an old gesture")
begin()
G.root.scripts.OnHide()
finish(-100, 0)
check(G.model.moves == 0 and not G.drag, "Hidden board retained its gesture")

for _, key in ipairs({ "LEFT", "A", "RIGHT", "D", "UP", "W", "DOWN", "S" }) do
    fixture((key == "UP" or key == "W" or key == "DOWN" or key == "S") and { 2, 0, 0, 0, 2 } or { 2, 2 })
    G.keys = {}
    G:KeyDown(key)
    G:KeyDown(key)
    check(G.model.moves == 1 and G.model.score == 4 and not G.root.propagate, "Movement key incorrect/repeated")
    G.root.scripts.OnKeyUp(G.root, key)
    settle()
end
fixture({ 2 })
check(not G:Move("left") and G.model.moves == 0, "Blocked swipe counted as a turn")
local model = G.model
U:OpenLauncher("home")
U:ShowGame()
check(G.model == model, "Launcher navigation reset the run")
for _, size in ipairs({ { 1000, 700 }, { 1120, 700 }, { 1500, 850 } }) do
    U:SetWindowSize(size[1], size[2])
    check(
        G.board:GetWidth() == G.board:GetHeight()
            and G.board:GetWidth() <= G.root:GetWidth() - G.left:GetWidth() - G.right:GetWidth() - 32,
        "2048 board is not responsive/square"
    )
    check(G.tileSize >= 70, "Tiles became unreadable")
end

fixture({ 1024, 1024 })
check(G:Move("left"), "Winning move failed")
settle()
check(not Games.ActiveGame and not Games.Lobby and G.summary:IsShown(), "Win did not finalize and show popup")
check(G.summary.heading.text == "2048 REACHED!" and G.model.score == 2048, "Win score/status incorrect")
check(G.root:IsVisible() and G.board:GetParent() == G.root, "Win moved board into popup")
check(
    G:Storage().best.score == 2048 and Games:GetResults("2048")[1].entries[1].outcome == "win",
    "Best/history missing"
)
local saved = G:Storage().best.score
G.summary.again.scripts.OnClick()
check(G.running and G.model.moves == 0 and not G.summary:IsShown(), "Popup replay failed")
fixture({ 2, 2, 8, 16, 8, 16, 32, 64, 16, 32, 64, 128, 32, 64, 128, 256 })
G:Move("left")
settle()
check(G.summary:IsShown() and G.summary.heading.text == "NO MOVES LEFT", "Loss popup missing")
check(
    G:Storage().best.score == saved and Games:GetResults("2048")[1].entries[1].outcome == "loss",
    "Loss changed best/history"
)
G.summary.menu.scripts.OnClick()
check(
    U.home:IsShown() and not G.summary:IsShown() and not U.completedGame and not G.root:IsShown(),
    "Back to menu failed"
)
check(Games:GetRecentGames()[1].id == "2048", "Home recent game missing")
local restored = h.client("Slider", "Realm", Games.Copy(Games.DB))
check(restored.games.Game2048:Storage().best.score == saved, "Best score did not survive reload")
check(G:NewGame(), "Could not restart after menu")
begin()
Games:AbortGame()
check(
    not G.drag and not G.running and not G.summary:IsShown() and not G.root.keyboardEnabled,
    "Abort left active input"
)
check(
    Games:StartSingleplayer("tetris") and Games.Tetris.root:IsVisible() and not G.root:IsShown(),
    "Another game failed after 2048"
)
Games:AbortGame()
check(#c.notices == 0, "Lifecycle errors: " .. table.concat(c.notices, "; "))
print("PASS: 2048 launcher, drag, keyboard, animation, lifecycle and persistence, " .. checks .. " checks")
