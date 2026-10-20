local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local c = h.client("Admiral", "Realm")
c.roster = { "Opponent-Realm" }
local G, U, B = c.games, c.games.UI, c.games.Battleships
local R = B.Rules
U:OpenLauncher("multiplayer")
local card
for _, item in ipairs(U.launcherCards) do
    if item.game and item.game.id == "battleships" then
        card = item
    end
end
check(card and card.icon.textureValue == G.Artwork["battleships-card"].file, "Card artwork")
U:OpenLauncher("home")
U:FeatureGame("battleships")
check(U.heroArt.textureValue == G.Artwork["battleships-hero"].file, "Hero artwork")
c.env.rejectTexture = G.Artwork["battleships-hero"].file
U:Refresh()
check(U.heroFallback:IsShown() and U.soloPlay:IsEnabled(), "Missing hero broke fallback/launch")
c.env.rejectTexture = G.Artwork["battleships-card"].file
G.Lobby = {
    id = "battleships-ui",
    host = c.name,
    channel = "PARTY",
    revision = 1,
    run = 1,
    epoch = 0,
    startedAt = c.env.GetServerTime(),
    mode = "multiplayer",
    countdownToken = 0,
    gameID = "battleships",
    gameTitle = "Battleships",
    gameVersion = "1",
    maxPlayers = 2,
    status = "running",
    members = { { name = c.name, ready = true, version = "1" }, { name = c.roster[1], ready = true, version = "1" } },
}
check(G:StartModule(), "Start UI fixture")
check(B.brand.textureValue == G.Registry.battleships.icon, "Missing card broke native icon")
c.env.rejectTexture = nil
local frames = #c.frames
for _, size in ipairs({ { 1000, 700 }, { 1120, 700 }, { 1500, 700 }, { 1500, 900 } }) do
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        U:SetWindowSize(size[1], size[2])
        U:SetWindowScale(scale)
        check(B.root:GetWidth() == U.gameContainer:GetWidth(), "Responsive root width")
        check(B.step >= 22 and B.step <= 32, "Unreadable cell size")
        local first, second = B.boards[1], B.boards[2]
        check(first.points[1][2] >= B.left:GetWidth() + 12, "Board overlaps left panel")
        check(second.points[1][2] + second.width <= B.right.points[1][2] - 12, "Board overlaps stats panel")
        check(first.points[1][2] + first.width + 12 <= second.points[1][2], "Boards overlap")
        check(-B.legend.points[1][3] + B.legend.height <= -B.status.points[1][3], "Legend overlaps status")
        for _, board in ipairs(B.boards) do
            for _, cell in ipairs(board.cells) do
                check(cell.width >= 20 and cell.width == cell.height, "Cell is not readable/square")
                check(
                    cell.points[1][2] + cell.width <= board.width - 6
                        and -cell.points[1][3] + cell.height <= board.height - 6,
                    "Cell outside board"
                )
            end
        end
    end
end
check(#c.frames == frames, "Resize/scale leaked frames")
U:SetWindowSize(1120, 700)
U:SetWindowScale(1)
c.env.keyboardFocus = {}
B.root.scripts.OnKeyDown(B.root, "R")
check(not B.vertical and B.root.propagate, "Rotation stole chat input")
c.env.keyboardFocus = nil
B.root.scripts.OnKeyDown(B.root, "R")
B.root.scripts.OnKeyDown(B.root, "R")
check(B.vertical and not B.root.propagate, "Key repeat rotated twice")
B.root.scripts.OnKeyUp(B.root, "R")
B.root.scripts.OnKeyDown(B.root, "ESCAPE")
check(B.root.propagate, "Unrelated key captured")
B.boards[1].cells[100].scripts.OnEnter()
check(B.boards[1].cells[100].background[1] > 0.5, "Invalid placement preview missing")
B.boards[1].cells[100].scripts.OnLeave()
B.boards[1].cells[1].scripts.OnEnter()
check(B.boards[1].cells[1].background[2] > 0.5, "Valid placement preview missing")
B.auto.scripts.OnClick()
check(B.lock:IsEnabled(), "Complete fleet cannot lock")
local code = R.EncodeFleet(B.draft)
check(R.Apply(B.authority, 1, { seq = 1, rev = 0, op = "lock", fleet = code }), "Own fixture lock")
check(R.Apply(B.authority, 2, { seq = 1, rev = 0, op = "lock", fleet = code }), "Enemy fixture lock")
B.hover = nil
B:Publish()
local layout, water = R.DecodeFleet(code), {}
local board = R.Board(layout)
for i = 1, 100 do
    if board[i] == 0 then
        water[#water + 1] = i
    end
end
local carrier = R.Cells(1, layout[1])
for i, index in ipairs(carrier) do
    check(
        R.Apply(B.authority, 1, { seq = B.authority.acks[1] + 1, rev = B.authority.rev, op = "fire", cell = index }),
        "Hit fixture"
    )
    check(
        R.Apply(B.authority, 2, {
            seq = B.authority.acks[2] + 1,
            rev = B.authority.rev,
            op = "fire",
            cell = i == 1 and carrier[1] or water[i],
        }),
        "Incoming fixture"
    )
end
B:Publish()
check(B.boards[2].cells[carrier[1]].mark.text == "#", "Sunk ship marker")
check(B.boards[1].cells[carrier[1]].mark.text == "X", "Incoming hit marker")
check(B.boards[1].cells[water[2]].mark.text == ".", "Miss marker")
local hidden = R.Cells(2, layout[2])[1]
check(B.boards[1].cells[hidden].background[2] > B.boards[2].cells[hidden].background[2], "Live enemy ships visible")
check(not B.lock:IsEnabled() and not B.auto:IsEnabled() and not B.shipButtons[1]:IsEnabled(), "Locked fleet editable")
local revision = B.view.rev
U:OpenLauncher("home")
check(B.running and not B.root:IsVisible(), "Navigation stopped match")
U:ShowGame()
check(B.root:IsVisible() and B.view.rev == revision, "Resume replaced board")
-- Finish without a final view: confirmed result still produces a popup and
-- preserves the last synchronized board instead of opening a separate game.
check(
    R.Apply(B.authority, 2, { seq = B.authority.acks[2] + 1, rev = B.authority.rev, op = "resign" }),
    "Resign fixture"
)
B:Finish()
check(
    not G.ActiveGame and U.completedGame and B.root:IsVisible() and B.summary:IsShown(),
    "Missing final view lost result UI"
)
check(
    B.summary.heading.text == "VICTORY!" and B.summary.details.text:find("5 / 17", 1, true),
    "Confirmed score/outcome missing"
)
check(B.summary.details.text:find("Final board unavailable", 1, true), "Stale board presented as final")
B.summary.menu.scripts.OnClick()
G:LeaveLobby()
check(
    G:StartSingleplayer("2048") and G.Game2048.root:IsVisible() and not B.root:IsShown(),
    "Existing game failed after Battleships"
)
G:AbortGame()
check(#c.notices == 0, "UI errors: " .. table.concat(c.notices, "; "))
print("PASS: " .. checks .. " Battleships artwork fallback, layout, scale, input, markers and final-board UI checks")
