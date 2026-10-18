local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = h.client("ResultSharer", "Realm")
local G, U = owner.games, owner.games.UI
local checks = 0
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
G.DB.tetris = { best = { score = 11111, lines = 11, level = 3 } }
G.DB.bejeweled = { best = { score = 22222, moves = 22, cleared = 222, bestCascade = 2 } }
G.DB.kic_bejeweled = {
    lastMode = "normal",
    best = { score = 33333, moves = 33, cleared = 333, bestCascade = 3 },
    arcaneRush = { best = { score = 44444, moves = 44, cleared = 444, bestCascade = 4 } },
}
local chess = G.Chess:Storage().stats
chess.wins, chess.losses, chess.draws, chess.completed = 7, 2, 1, 10
chess.lastOpponent = "Opponent-Realm"
local blind = G.Blindshot:Storage().stats
blind.wins, blind.losses, blind.draws, blind.completed = 8, 3, 2, 13
blind.rounds, blind.eliminations = 50, 24
U:OpenLauncher("results")
check(U.resultShareBest:IsVisible(), "Results Share Best button missing")
local function select(id)
    local games = G:GetGames()
    for i, game in ipairs(games) do
        if game.id == id then
            U.resultGameButtons[i].scripts.OnClick()
            return
        end
    end
    error("Missing selector for " .. id)
end
local cases = {
    { "tetris", "KIC Tetris best: 11111 points", "Lines: 11" },
    { "bejeweled", "KIC Bejeweled best: 22222 points", "Gems: 222" },
    { "kic_bejeweled", "KIC Bejeweled (Normal) best: 33333 points", "Gems: 333" },
    { "chess", "KIC Chess record: 7W / 2L / 1D", "Opponent-Realm" },
    { "blindshot", "KIC Blindshot record: 8W / 3L / 2D", "Eliminations: 24" },
}
for _, channel in ipairs({ "PARTY", "RAID", "INSTANCE_CHAT", "SAY" }) do
    owner.grouped, owner.channel = channel ~= "SAY", channel
    for _, case in ipairs(cases) do
        local before = #owner.chatMessages
        select(case[1])
        check(#owner.chatMessages == before, "Selecting a result sent chat")
        check(U.resultShareBest:IsEnabled(), "Selected installed game cannot share")
        U.resultShareBest.scripts.OnClick()
        local sent = owner.chatMessages[#owner.chatMessages]
        check(
            #owner.chatMessages == before + 1 and sent.channel == channel,
            "Result share used wrong channel or sent twice"
        )
        check(
            sent.message:find(case[2], 1, true) and sent.message:find(case[3], 1, true),
            "Result share used another game's record"
        )
    end
end
G.DB.kic_bejeweled.lastMode = "roguelike"
select("kic_bejeweled")
U.resultShareBest.scripts.OnClick()
check(
    owner.chatMessages[#owner.chatMessages].message:find("KIC Bejeweled (Roguelike) best: 44444 points", 1, true),
    "Wrong KIC Bejeweled mode bucket"
)
-- The selected record must win over the active game's ID and unsaved score.
check(G:StartSingleplayer("tetris"), "Could not start selection-isolation fixture")
G.Tetris.model.score = 99999
U:OpenLauncher("results")
select("bejeweled")
local active, paused = G.ActiveGame, G.Tetris.paused
U.resultShareBest.scripts.OnClick()
check(
    owner.chatMessages[#owner.chatMessages].message:find("22222 points", 1, true),
    "Active game's score replaced selected record"
)
check(
    G.ActiveGame == active and G.Tetris.paused == paused and G.Tetris.model.score == 99999,
    "Sharing changed active gameplay"
)
check(
    not G.Chess.root and not G.Blindshot.root and not G.Bejeweled.root and not G.KICBejeweled.root,
    "Results sharing initialized another game's UI"
)
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    U:SetWindowScale(scale)
    check(
        U.resultShareBest:IsVisible() and U.resultShareBest:GetWidth() == 160,
        "Share button clipped or disappeared at scale"
    )
    check(
        U.resultsHeading:GetWidth() + U.resultShareBest:GetWidth() <= U.content:GetWidth(),
        "Results title overlaps share button"
    )
end
local before = #owner.chatMessages
U.resultGameID = "uninstalled"
check(not U:ShareSelectedBest() and #owner.chatMessages == before, "Invalid selection shared another game's score")
G:RegisterGame({
    id = "empty_record",
    title = "Empty Record",
    version = "1",
    mode = "singleplayer",
    OnStart = function() end,
    CreateUI = function() end,
})
select("empty_record")
check(
    not U.resultShareBest:IsEnabled() and not U:ShareSelectedBest() and #owner.chatMessages == before,
    "Missing best generated a fake result"
)
print(
    string.format(
        "PASS: %d Results selection, per-game record sharing, mode, chat routing and layout assertions",
        checks
    )
)
