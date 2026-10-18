local old = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = old
local owner = h.client("PracticeBlindshot", "Realm")
local G, B = owner.games, owner.games.Blindshot
local R, checks = B.Rules, 0
local function check(v, message)
    assert(v, message)
    checks = checks + 1
end
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
owner.grouped = false
local saved = G.Copy(G.DB)
local send, record, action, state = G.Send, G.RecordResult, G.SendGameAction, G.SendGameState
G.Send = function()
    error("Local test used party transport")
end
G.SendGameAction, G.SendGameState = G.Send, G.Send
G.RecordResult = function()
    error("Local test recorded a multiplayer result")
end
local function command(value)
    owner.env.SlashCmdList.KICBLINDSHOTTEST(value or "")
end
local function pump(seconds)
    for _ = 1, math.ceil(seconds * 10) do
        h.advance(0.1)
        for _, timer in ipairs(owner.scheduled or {}) do
            if not timer.cancelled and owner.env.GetTime() >= timer.at then
                timer.at = owner.env.GetTime() + timer.period
                timer.callback()
            end
        end
    end
end
local function waitFor(predicate, message)
    for _ = 1, 200 do
        if predicate() then
            check(true, message)
            return
        end
        pump(0.1)
    end
    error(message .. ": " .. table.concat(owner.notices, "; "))
end
local function mouse(x, y, button)
    local px, py = B:Project(x, y)
    local scale = B.arena:GetEffectiveScale()
    owner.env.cursorX = (B.arena:GetLeft() + px) * scale
    owner.env.cursorY = (B.arena:GetTop() - py) * scale
    owner.env.mouseDown = true
    B.arena.scripts.OnMouseDown(B.arena, button)
    owner.env.mouseDown = false
    B.arena.scripts.OnMouseUp(B.arena, button)
end
check(owner.env.SLASH_KICBLINDSHOTTEST1 == "/kicblindshottest", "Test command missing")
check(owner.env.SLASH_KICBLINDSHOTTEST2 == "/kicblindshot", "Short command alias missing")
command()
check(
    B.practice and B.running and not G.Lobby and G.ActiveGame.game.id == "blindshot",
    "Test created a multiplayer lobby"
)
check(B.root:IsVisible() and G.UI.frame:IsShown(), "Command did not open real UI")
check(#B.authority.players == 5 and B.practiceCount == 5, "Default test is not five players")
waitFor(function()
    return B.view.phase == "AIM"
end, "Solo test never reached AIM")
check(B:CanInput() and not B:Party(), "Party requirement blocked local input")
check(B.roundBanner.text:find("TEST /", 1, true), "Test screen not identified")
check(B.backButton.text == "New test game" and B.leaveButton.text == "Leave test", "Local controls missing")
for i = 2, 5 do
    check(
        B.authority.players[i].locked and R.Action(B.authority.drafts[B.authority.players[i].name], 1000),
        "Dummy did not choose a valid hidden shot"
    )
    check(not B.markers[i]:IsShown(), "Dummy position visible during AIM")
end
check(not B.view.shots and not B.view.drafts, "Test exposes hidden opponents")
-- Make a deterministic missed volley to exercise the real shrink/next-round path.
for i = 2, 5 do
    local a = R.Default(i, 5, 1000)
    a.dx, a.dy = R.Direction(a.x, a.y)
    B.authority.drafts[B.authority.players[i].name] = a
end
mouse(600, 0, "LeftButton")
mouse(1000, 0, "RightButton")
check(B.draft.x == 600 and B.draft.dx == 1000, "Local click position/aim input failed")
B.lockButton.scripts.OnClick()
waitFor(function()
    return B.view.phase == "REVEAL"
end, "Solo Lock did not reveal")
check(#B.view.shots == 5 and B.beams.used == 20, "Solo reveal missing players or arrows")
waitFor(function()
    return B.view.phase == "FIRING"
end, "Solo volley did not resolve")
check(R.Alive(B.view) == 5, "Outward volley did not miss")
waitFor(function()
    return B.view.round == 2 and B.view.phase == "AIM"
end, "Solo test did not advance round")
check(B.view.radius == 820 and B.practiceRound == 2 and B:CanInput(), "Shrink or second-round input failed")
check(not B.view.shots and not B.markers[2]:IsShown(), "Next AIM leaked prior volley")
local current, deadline = B.authority, B.authority.deadline
G.UI:OpenLauncher("home")
G.UI.frame:Hide()
command()
check(
    B.authority == current and B.authority.deadline == deadline and B.root:IsVisible(),
    "Reopening restarted local test"
)
owner.grouped, owner.roster = true, { "Friend-Realm" }
owner:event("GROUP_ROSTER_UPDATE")
G:Tick()
pump(1)
check(B.practice and B.running and not G.Lobby, "Party change affected local test")
-- A knocked-out tester can spectate; automatic opponents must not wait for
-- the dead player's input or consume an unnecessary full AIM timer.
B.authority.players[1].alive, B.authority.players[1].deathRound = false, 2
R.EndRound(B.authority, owner.env.GetServerTime())
R.Next(B.authority, owner.env.GetServerTime())
B:Publish()
waitFor(function()
    return B.view.round == 3 and B.view.phase == "REVEAL"
end, "Simulated survivors did not continue automatically")
check(not B:CanInput() and #B.view.shots == 4, "Eliminated tester still acted or fired")
check(equal(saved.blindshot, G.DB.blindshot) and equal(saved.results, G.DB.results), "Local play changed saves/stats")
command("new 2")
check(#B.authority.players == 2 and B.practiceCount == 2 and B.view.round == 1, "Player-count/reset command failed")
waitFor(function()
    return B:CanInput()
end, "New two-player test did not start")
local id = B.authority.id
command("6")
check(B.authority.id == id and B.practiceCount == 2, "Invalid player count replaced game")
local opponent = B.authority.players[2].name
B.authority.drafts[opponent] = { x = 400, y = 0, dx = 1000, dy = 0, seq = 1, lock = true }
B.draft = { x = -400, y = 0, dx = 1000, dy = 0 }
check(B:SendDraft(true), "Local winning lock failed")
waitFor(function()
    return B.practiceResult ~= nil
end, "Local win did not end match")
check(B.practiceResult.practice and B.practiceResult.entries[1].outcome == "win", "Local result wrong")
check(
    B.resultWindow:IsVisible()
        and B.resultMainButton.text == "New test game"
        and B.resultSecondaryButton.text == "Exit test",
    "Local result controls missing"
)
local revision = B.view.rev
pump(5)
check(B.view.rev == revision, "Finished local match kept advancing")
B:RecordStats(B.practiceResult)
check(
    equal(saved.blindshot, G.DB.blindshot) and equal(saved.results, G.DB.results),
    "Local result changed multiplayer records"
)
B.resultMainButton.scripts.OnClick()
check(
    B.practiceCount == 2 and not B.practiceResult and not B.resultWindow:IsShown(),
    "Result restart did not preserve player count"
)
waitFor(function()
    return B:CanInput()
end, "Restarted test did not start")
opponent = B.authority.players[2].name
B.authority.drafts[opponent] = { x = 400, y = 0, dx = -1000, dy = 0, seq = 1, lock = true }
B.draft = { x = -400, y = 0, dx = 1000, dy = 0 }
B:SendDraft(true)
waitFor(function()
    return B.practiceResult ~= nil
end, "Local facing duel did not finish")
check(
    B.practiceResult.entries[1].outcome ~= B.practiceResult.entries[2].outcome,
    "Local sequential duel did not produce one winner"
)
B.resultSecondaryButton.scripts.OnClick()
check(not B.practice and not B.running and not G.ActiveGame and not B.root:IsShown(), "Result exit leaked active test")
pump(2)
check(not G.ActiveGame and not B.authority, "Old timer revived test")
command("5")
check(B.practiceCount == 5 and B.running, "Numeric player-count command failed")
B.backButton.scripts.OnClick()
check(B.practiceCount == 5 and B.view.round == 1, "New test game button failed")
B.leaveButton.scripts.OnClick()
check(not G.ActiveGame and not B.practice, "Leave test button failed")
for _, count in ipairs({ 3, 4 }) do
    command(tostring(count))
    waitFor(function()
        return B:CanInput()
    end, "Middle-size local test did not start")
    check(#B.authority.players == count and B.practiceCount == count, "Local test count differs from simulation")
    command("stop")
end
command()
check(G:AbortGame() and not B.practice and not G.ActiveGame, "Shared Stop did not stop local test")
command()
G:LeaveLobby()
check(not B.practice and not G.ActiveGame and not G.Lobby, "Shared Leave did not stop local test")
command()
check(not G.Chess:StartPractice(), "Chess replaced active Blindshot test")
command("stop")
check(G.Chess:StartPractice(), "Local cleanup damaged Chess test")
check(not B:StartPractice(), "Blindshot replaced Chess test")
G.Chess:StopPractice()
command()
check(G:StartSingleplayer("bejeweled"), "Could not switch from local test to normal game")
check(not B.practice and not B.running and not B.root:IsShown(), "Switching games leaked local test")
check(not B:StartPractice(), "Test replaced an active normal game")
G.Send, G.RecordResult, G.SendGameAction, G.SendGameState = send, record, action, state
G:AbortGame()
G:LeaveLobby()
check(G:CreateLobby("blindshot"), "Local test damaged multiplayer hosting")
check(not B:StartPractice() and G.Lobby.gameID == "blindshot", "Test replaced an existing multiplayer lobby")
G:LeaveLobby()
check(#owner.chatMessages == 0, "Local test emitted visible chat")
check(equal(saved.blindshot.stats, G.DB.blindshot.stats), "Testing changed Blindshot lifetime records")
for _, notice in ipairs(owner.notices) do
    check(not notice:find(" / timer:", 1, true) and not notice:find(" / CreateUI:", 1, true), notice)
end
print(
    string.format(
        "PASS: %d local Blindshot command, simulated players, full rounds/results and record-isolation assertions",
        checks
    )
)
