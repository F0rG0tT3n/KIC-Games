local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks, serial = 0, 0
local function check(v, message)
    assert(v, message)
    checks = checks + 1
end
local function fixture(side)
    serial = serial + 1
    local owner = h.client("ChessUI" .. serial, "Realm")
    local G, C = owner.games, owner.games.Chess
    local own, other = owner.name, "Other-Realm"
    owner.roster = { other }
    local info = {
        id = "ui-chess-" .. serial,
        host = own,
        white = side == 1 and own or other,
        black = side == -1 and own or other,
        version = "1",
        startedAt = owner.env.GetServerTime(),
    }
    check(C:Begin(info), "Chess UI failed to construct")
    check(C:LobbyInfoValid(G.Lobby), "Legacy saved Chess session cannot recover through lobby snapshots")
    C.match.recovering = false
    C:Render()
    return owner, G, C, C.Engine
end
local function cell(C, E, name)
    for _, c in ipairs(C.cells) do
        if c.square == E.Square(name) then
            return c
        end
    end
    error("Missing square " .. name)
end
local owner, G, C, E = fixture(1)
check(G.Registry.chess.icon == G.Artwork["chess-card"].file, "Chess icon ignores supplied artwork")
G.UI:OpenLauncher("home")
G.UI:FeatureGame("chess")
check(
    G.UI.heroArt.textureValue == G.Artwork["chess-hero"].file and G.Artwork["chess-hero"].textSide == "left",
    "Launcher hero or left-side text placement incorrect"
)
G.UI:OpenLauncher("multiplayer")
check(not G.UI.browserPanel:IsVisible() and G.UI.showGame:IsShown(), "Chess lobby integration missing")
check(G.UI.abortButton:IsShown() and G.UI.endGame:IsShown(), "Shared multiplayer stop controls missing")
G.UI:ShowGame()
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    G.UI:SetWindowScale(scale)
    check(C.board:GetWidth() == C.board:GetHeight() and C.board:GetWidth() >= 512, "Board is not large/square")
    local seen = {}
    for _, c in ipairs(C.cells) do
        check(c:GetWidth() == C.cellSize and c:GetHeight() == C.cellSize, "Input hitbox does not match cell")
        check(math.abs(c.piece:GetWidth() / c:GetWidth() - 0.9) < 0.001, "Piece size outside 85-92% range")
        check(c.base.drawLayer == "BACKGROUND" and c.piece.drawLayer == "OVERLAY", "Piece/square layering incorrect")
        for _, overlay in pairs(c.overlays) do
            check(overlay.drawLayer == "ARTWORK", "Highlight drawn over piece")
        end
        if c.piece:IsShown() then
            seen[c.piece.textureValue] = true
        end
    end
    local textures = 0
    for _ in pairs(seen) do
        textures = textures + 1
    end
    check(textures == 12, "Starting position does not use all twelve supplied piece textures")
    check(C.cells[1].square == E.Square("a8") and C.cells[57].square == E.Square("a1"), "White orientation incorrect")
    check(C.fileLabels[1].text == "A" and C.rankLabels[1].text == 8, "White coordinates incorrect")
end
local e2, e4, e3 = cell(C, E, "e2"), cell(C, E, "e4"), cell(C, E, "e3")
e2.scripts.OnClick()
check(
    e2.overlays.selected:IsShown() and e4.overlays["valid-move"]:IsShown() and e3.overlays["valid-move"]:IsShown(),
    "Legal move highlights missing"
)
local before = C.match.seq
cell(C, E, "e5").scripts.OnClick()
check(C.match.seq == before and C.match.state.board[E.Square("e2")] == 1, "Invalid destination changed board")
e2.scripts.OnClick()
e4.scripts.OnClick()
check(C.match.state.board[E.Square("e4")] == 1 and C.match.state.san[1] == "e4", "Click-to-move failed")
check(e2.overlays["last-move"]:IsShown() and e4.overlays["last-move"]:IsShown(), "Last move highlight missing")
before = C.match.seq
cell(C, E, "a7").scripts.OnClick()
cell(C, E, "a6").scripts.OnClick()
check(C.match.seq == before, "Out-of-turn board click changed state")
check(
    C.historyText.text:find("1. e4", 1, true) and C.historyScroll.scripts.OnMouseWheel,
    "SAN history is not scrollable"
)
C.match.state = assert(E.New("4r2k/8/8/8/8/8/8/4K3 w - - 0 1"))
C.match.seq = C.match.seq + 1
C:Render()
check(cell(C, E, "e1").overlays.check:IsShown(), "Checked king not highlighted")
-- Captured-piece trays must use the same piece assets and stay in their panel.
C.match.state.captured = { -1, -2, -3, -4, -5, 1, 2, 3, 4, 5 }
C:Render()
check(
    C.captureIcons[1][1].textureValue == G.Artwork["chess-black-pawn"].file
        and C.captureIcons[2][1].textureValue == G.Artwork["chess-white-pawn"].file,
    "Capture artwork wrong"
)
check(C.captureIcons[1][1]:IsShown() and not C.captureIcons[1][6]:IsShown(), "Capture tray leaked icons")
local blackOwner, blackG, blackC, blackE = fixture(-1)
check(
    blackC.cells[1].square == blackE.Square("h1") and blackC.cells[57].square == blackE.Square("h8"),
    "Black orientation incorrect"
)
check(blackC.fileLabels[1].text == "H" and blackC.rankLabels[1].text == 1, "Black coordinates incorrect")
check(
    cell(blackC, blackE, "h8").piece.textureValue == blackG.Artwork["chess-black-rook"].file,
    "Black pieces are not at the bottom"
)

for _, side in ipairs({ 1, -1 }) do
    for index, kind in ipairs({ "q", "r", "b", "n" }) do
        local o, g, c, e = fixture(side)
        c.match.state = assert(e.New(side == 1 and "7k/P7/8/8/8/8/8/7K w - - 0 1" or "7k/8/8/8/8/8/p7/7K b - - 0 1"))
        c.match.seq = c.match.seq + 1
        c:Render()
        local from, to = side == 1 and "a7" or "a2", side == 1 and "a8" or "a1"
        cell(c, e, from).scripts.OnClick()
        cell(c, e, to).scripts.OnClick()
        check(c.promotion:IsShown() and c.match.state.board[e.Square(from)] == side, "Promotion applied before choice")
        local prefix = side == 1 and "white" or "black"
        for i, piece in ipairs({ "queen", "rook", "bishop", "knight" }) do
            check(
                c.promotionButtons[i].piece.drawLayer == "OVERLAY" and c.promotionButtons[i].piece:IsVisible(),
                "Promotion piece hidden behind button backdrop"
            )
            check(
                c.promotionButtons[i].piece.textureValue == g.Artwork["chess-" .. prefix .. "-" .. piece].file,
                "Promotion picker uses wrong art"
            )
        end
        c.promotionButtons[index].scripts.OnClick()
        check(not c.promotion:IsShown() and c.match.state.last.promotion == kind, "Graphical promotion choice failed")
    end
end
check(
    not G.Bejeweled.root and not G.KICBejeweled.root and not G.Tetris.root,
    "Chess constructed unrelated game screens"
)
check(#owner.chatMessages == 0 and #blackOwner.chatMessages == 0, "UI emitted visible chat")
print(
    string.format(
        "PASS: %d Chess artwork, board geometry, input, orientation, promotion and launcher assertions",
        checks
    )
)
