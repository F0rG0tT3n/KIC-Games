local previous = arg[1]
arg[1] = "--harness"
local harness = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local tests = 0
local function check(value, message)
    assert(value, message)
    tests = tests + 1
end
for _, game in ipairs({ { "bejeweled", "Bejeweled" }, { "kic_bejeweled", "KICBejeweled" } }) do
    local owner = harness.client("Hints", "Realm")
    local G, B = owner.games, owner.games[game[2]]
    G:StartSingleplayer(game[1])
    if B.ChooseMode then B:ChooseMode("roguelike") end
    local function board(playable)
        for y = 1, 8 do
            for x = 1, 8 do
                B.model.board[y][x] = (x + 2 * y) % 7 + 1
            end
        end
        if playable then
            B.model.board[1][1], B.model.board[1][2], B.model.board[1][3], B.model.board[2][2] = 1, 2, 1, 1
        end
        B:Render()
    end
    board(true)
    check(
        B.hintsRemaining == 3 and B.hintButton:IsEnabled() and B.hintButton.text == "Hint (3/3)",
        "New run must have three hints"
    )
    for _ = 1, 120 do
        B:Advance(0.1)
    end
    check(not B.hint and B.hintsRemaining == 3, "Automatic hint still exists")
    B:Pause(true)
    check(not B:Hint() and B.hintsRemaining == 3 and not B.hintButton:IsEnabled(), "Paused hint consumed a use")
    B:Pause(false)
    for use = 1, 3 do
        B.hintButton.scripts.OnClick()
        check(B.hint and B.hintsRemaining == 3 - use, "Hint did not consume exactly one use")
        check(B.hintButton.text == "Hint (" .. (3 - use) .. "/3)", "Hint count label wrong")
        check(not B:Hint() and B.hintsRemaining == 3 - use, "Repeated active hint consumed a use")
        local hint = B.hint
        local a, b = B.cells[(hint.y - 1) * 8 + hint.x], B.cells[(hint.ty - 1) * 8 + hint.tx]
        local beforeA, beforeB = a.icon.points[1][3], b.icon.points[1][3]
        B:Advance(0.1)
        check(a.icon.points[1][3] ~= beforeA and b.icon.points[1][3] ~= beforeB, "Both tiles must bounce")
        check(B.model.score == 0 and B.model.moves == 0, "Hint changed score or moves")
        B:Click(1, 1, "RightButton")
        check(not B.hint, "Interaction did not clear hint")
        if use == 1 then
            G.UI:ShowHome()
            G.UI:ShowGame()
            B:Pause(false)
            check(B.hintsRemaining == 2, "Reopening replenished hints")
        end
    end
    check(not B.hintButton:IsEnabled() and not B:Hint() and B.hintsRemaining == 0, "Fourth hint was available")
    B:Advance(60)
    check(not B.hint and B.hintsRemaining == 0, "Waiting replenished hints")
    B:Pause(true)
    B.pauseOverlay.restart.scripts.OnClick()
    if B.ChooseMode then B:ChooseMode("roguelike") end
    check(B.hintsRemaining == 3 and not B.hint, "Restart did not reset hint budget")
    board(false)
    check(not B:Hint() and B.hintsRemaining == 3, "No-move hint consumed a use")
    board(true)
    B:TrySwap(2, 1, 2, 2)
    check(not B:Hint() and B.hintsRemaining == 3 and not B.hintButton:IsEnabled(), "Resolving board accepted hint")
    for _ = 1, 300 do
        B:Advance(0.1)
        if B.run and B.run.pending then B:ReshuffleDraft() end
        if B.model.phase == "idle" and not B.fall then
            break
        end
    end
    check(B.hintsRemaining == 3, "Cascade altered hint budget")
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        G.UI:SetWindowScale(scale)
        local y = -B.hintButton.points[1][3]
        check(y >= 0 and y + B.hintButton.height <= B.left.height, "Hint button outside panel")
        check(
            B.pauseButton.points[1][3] > B.hintButton.points[1][3]
                and B.hintButton.points[1][3] > B.shareButton.points[1][3],
            "Hint button overlaps action order"
        )
    end
    if game[1] == "kic_bejeweled" then
        G:AbortGame()
        G:StartSingleplayer(game[1])
    if B.ChooseMode then B:ChooseMode("roguelike") end
        board(false)
        B.model.board[1][1] = B.Engine.Orb
        check(B:Hint() and B.hint.x == 1 and B.hint.y == 1, "Hint missed valid Orb swap")
    end
end
print(string.format("PASS: %d manual Bejeweled hint assertions", tests))
