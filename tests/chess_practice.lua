-- Run from the repository root: lua tests/chess_practice.lua
local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local owner = h.client("LocalChess", "Realm")
local G, C = owner.games, owner.games.Chess
local E = C.Engine
local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if not equal(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end
local saved = G.Copy(G.DB)
G.Send = function()
    error("Local Chess attempted network traffic")
end
G.SendGameAction = G.Send
G.SendGameState = G.Send
local function command(text)
    owner.env.SlashCmdList.KICCHESSTEST(text or "")
end
local function click(name)
    for _, cell in ipairs(C.cells) do
        if cell.square == E.Square(name) then
            cell.scripts.OnClick()
            return
        end
    end
    error("No cell for " .. name)
end
local function move(from, to)
    local seq = C.match.seq
    click(from)
    click(to)
    check(C.match.seq == seq + 1, "Legal local move failed: " .. from .. to)
    check(C.match.practice and not C.match.recovering, "Local move entered multiplayer recovery")
    check(C.cells[1].square == E.Square("a8"), "Local board flipped after a move")
end
local function position(fen)
    command("new")
    C.match.state = assert(E.New(fen))
    C:Render()
end
check(owner.env.SLASH_KICCHESSTEST1 == "/kicchesstest", "Test command missing")
check(owner.env.SLASH_KICCHESSTEST2 == "/kicchess", "Short alias missing")
command()
check(G.ActiveGame and G.ActiveGame.game.id == "chess" and not G.Lobby, "Local board requires a lobby")
check(C.root:IsShown() and G.UI.gameContainer:IsShown() and G.UI.frame:IsShown(), "Command did not open real UI")
check(C:CanInput() and C.match.practice and not C:Party(), "Solo player cannot move")
check(C.opponent.text:find("both sides", 1, true), "Local UI misidentifies the opponent")
click("e7")
check(not C.selected, "Black selected on White's turn")
click("e2")
click("e5")
check(C.match.seq == 0 and C.match.state.board[E.Square("e2")] == 1, "Illegal move changed board")
C.selected = nil
move("e2", "e4")
move("e7", "e5")
check(C.historyText.text:find("1. e4   e5", 1, true), "SAN history missing both sides")
local current = C.match
G.UI.frame:Hide()
command()
check(C.match == current and G.UI.frame:IsShown(), "Reopening restarted local game")
G.UI:OpenLauncher("home")
command("test")
check(C.match == current and G.UI.gameContainer:IsShown(), "Launcher round trip lost board")
owner.roster = { "Friend-Realm" }
owner:event("GROUP_ROSTER_UPDATE")
h.advance(150)
C:Tick()
C:Save()
check(not C.match.recovering and C:CanInput(), "Party change or time paused local test")
owner.roster = {}
owner:event("GROUP_ROSTER_UPDATE")
check(equal(G.DB.chess, saved.chess) and equal(G.DB.results, saved.results), "Practice wrote records or recovery")

-- Castling, en passant and king safety use the same engine through real cells.
position("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
move("e1", "g1")
check(C.match.state.board[E.Square("f1")] == 4, "White castling did not move rook")
move("e8", "c8")
check(C.match.state.board[E.Square("d8")] == -4, "Black castling did not move rook")
position("7k/3p4/8/4P3/8/8/8/7K b - - 0 1")
move("d7", "d5")
move("e5", "d6")
check(C.match.state.board[E.Square("d5")] == 0 and #C.match.state.captured == 1, "En passant failed")
position("4r2k/8/8/8/8/8/4R3/4K3 w - - 0 1")
click("e2")
click("d2")
check(C.match.seq == 0, "Local test allowed exposing own king")

for _, side in ipairs({ 1, -1 }) do
    for index, kind in ipairs({ "q", "r", "b", "n" }) do
        position(side == 1 and "7k/P7/8/8/8/8/8/7K w - - 0 1" or "7k/8/8/8/8/8/p7/7K b - - 0 1")
        click(side == 1 and "a7" or "a2")
        click(side == 1 and "a8" or "a1")
        check(C.promotion:IsShown(), "Local promotion picker missing")
        for _, choice in ipairs(C.promotionButtons) do
            check(
                choice.piece.drawLayer == "OVERLAY" and choice.piece:IsVisible(),
                "Local promotion piece hidden behind backdrop"
            )
        end
        local color = side == 1 and "white" or "black"
        check(
            C.promotionButtons[1].piece.textureValue == G.Artwork["chess-" .. color .. "-queen"].file,
            "Wrong local promotion color"
        )
        C.promotionButtons[index].scripts.OnClick()
        check(C.match.state.last.promotion == kind and not C.promotion:IsShown(), "Local promotion choice failed")
    end
end

command("new")
move("f2", "f3")
move("e7", "e5")
move("g2", "g4")
move("d8", "h4")
check(C.match.ended and C.match.ended.winner == -1 and not C:CanInput(), "Checkmate did not end local game")
check(C.resultText.text:find("Black wins", 1, true), "Local checkmate result missing")
check(
    C.resultWindow:IsShown()
        and C.resultPractice
        and C.resultMainButton.text == "New test game"
        and C.resultSecondaryButton.text == "Leave test",
    "Local result restart/exit controls missing"
)
C.practiceNew.scripts.OnClick()
check(C.match.seq == 0 and C:CanInput(), "New local game button failed")
check(not C.resultWindow:IsShown() and C.practiceLeave:IsVisible(), "Restart left result open or exit hidden")
check(C.practiceNew:GetParent() == C.right and C.practiceLeave:GetParent() == C.right, "Test controls are not grouped")
check(C:Request("offer"), "Local draw offer failed")
check(C.drawButton.text == "Accept draw" and C.declineDraw:IsShown(), "Local draw controls missing")
C.declineDraw.scripts.OnClick()
check(not C.match.offer and not C.match.ended, "Local draw decline failed")
check(not C:Request("offer"), "Local test allowed a duplicate draw offer on the same move")
move("e2", "e4")
C.drawButton.scripts.OnClick()
C.drawButton.scripts.OnClick()
check(C.match.ended and C.match.ended.winner == 0, "Local draw agreement failed")
C.resultMainButton.scripts.OnClick()
check(C.match.seq == 0 and not C.resultWindow:IsShown(), "Result restart failed")
position("7k/8/8/8/8/8/R7/7K w - - 100 51")
C.claimDraw.scripts.OnClick()
check(C.match.ended and C.match.ended.reason == "fifty-move rule", "Local draw claim failed")
command("new")
move("e2", "e4")
C.resignButton.scripts.OnClick()
check(C.match.ended and C.match.ended.winner == 1, "Local resignation used wrong side")
check(equal(G.DB.chess, saved.chess) and equal(G.DB.results, saved.results), "Local results changed statistics")
command("stop")
check(not C.match and not G.ActiveGame and not C.root:IsShown() and not C.running, "Stop left local game running")
check(not C.resultWindow:IsShown(), "Stop left result popup visible")
command()
C.practiceLeave.scripts.OnClick()
check(not C.match and not G.ActiveGame and not C.running, "Leave test button did not stop game")
command()
C:Request("resign")
C.resultSecondaryButton.scripts.OnClick()
check(not C.match and not G.ActiveGame and not C.resultWindow:IsShown(), "Result exit did not stop local test")
command()
G:AbortGame()
check(not C.match and not G.ActiveGame, "Shared stop did not end local test")
command()
G:LeaveLobby()
check(not C.match and not G.ActiveGame, "Shared leave did not end local test")
command()
check(G:StartSingleplayer("bejeweled"), "Local test blocked switching to another game")
check(not C.match and not C.root:IsShown() and not C.running, "Switching games leaked local Chess state")
command("new")
check(G.ActiveGame.game.id == "bejeweled" and not C.match, "Test command replaced an active game")
G:AbortGame()
G:LeaveLobby()
local other = h.client("Opponent", "Realm")
owner.roster, other.roster = { other.name }, { owner.name }
G.Send = function()
    return true
end
check(G:CreateLobby("chess"), "Local command damaged multiplayer hosting")
command()
check(not C.match and G.Lobby and G.Lobby.status == "waiting", "Test command replaced a multiplayer lobby")
check(equal(G.DB.chess.stats, saved.chess.stats), "Local testing changed Chess win/loss records")
print(
    string.format("PASS: %d local Chess command, board input, rules, lifecycle and record isolation assertions", checks)
)
