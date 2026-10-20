-- Run from repository root: lua tests/kic_bejeweled_migration.lua
local previous = arg[1]
arg[1] = "--harness"
local harness = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
-- Old identifiers appear only in compatibility code and these migration fixtures.
local oldID, newID = "bejeweled_deluxe", "kic_bejeweled"
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local seed = harness.client("Migration", "Realm")
local G = seed.games
check(G:StartSingleplayer(newID), "Renamed game did not start")
G.KICBejeweled:ChooseMode("roguelike")
G.KICBejeweled.model.score = 1234
G.KICBejeweled:Complete()
local result = G.DB.results[1]
check(result and G:ValidResult(result), "Result fixture is invalid")
result.gameID = oldID

local function save()
    return {
        [oldID] = {
            best = { score = 900, moves = 12, cleared = 30, bestCascade = 4 },
            arcaneRush = { best = { score = 500, moves = 7, cleared = 22, bestCascade = 3 }, custom = true },
            custom = { preserved = true },
        },
        bejeweled = { best = { score = 42 } },
        recentGames = { oldID, "tetris", newID, "bejeweled" },
        results = { G.Copy(result) },
    }
end
local owner = harness.client("Migration", "Realm", save())
local games, env = owner.games, owner.env
check(not games.Registry[oldID] and games.Registry[newID].title == "KIC Bejeweled", "Old game registration remains")
check(games.DB[oldID] == nil and games.DB[newID].best.score == 900, "Untimed record was not migrated")
check(games.KICBejeweled:Storage().best.score == 500, "Rush record was not migrated")
check(games.DB[newID].custom.preserved and games.DB[newID].arcaneRush.custom, "Additional save fields lost")
check(games.DB.bejeweled.best.score == 42, "Standard Bejeweled record changed")
check(#games.DB.results == 1 and #games:GetResults(newID) == 1 and #games:GetResults(oldID) == 0,
    "Result history lost or still uses old ID")
check(games.LastResult.gameID == newID, "LastResult was initialized before migration")
local recent = games:GetRecentIDs()
check(#recent == 3 and recent[1] == newID and recent[2] == "tetris" and recent[3] == "bejeweled",
    "Recent order lost or renamed entry duplicated")
games.UI:OpenLauncher("home")
games.UI:FeatureGame(newID)
check(games.UI:GetPersonalBest(newID).score == 500 and games.UI:GetPersonalBestMode(newID) == "Roguelike"
    and games.UI.heroArt.artKey == "kic-bejeweled-hero", "Launcher failed after migration")
games.UI:ShowResults()
games.UI.resultGameID = newID
games.UI:RefreshResults()
check(games.UI.bestScore.text == "500 points", "Results failed after migration")
check(env.SLASH_KICBEJEWELED1 == "/kicbejeweled" and env.SLASH_BEJEWELED1 == "/bejeweled",
    "Primary commands collide")
check(env.SLASH_KICBEJEWELED2 == "/kicbejeweleddeluxe", "Legacy command alias missing")
env.SlashCmdList.KICBEJEWELED("")
check(games.ActiveGame.game.id == newID, "New command opens wrong game")
games:AbortGame()
env.SlashCmdList.BEJEWELED("")
check(games.ActiveGame.game.id == "bejeweled", "Standard command opens wrong game")

local reloaded = harness.client("Migration", "Realm", games.DB).games
check(reloaded.DB[oldID] == nil and reloaded.KICBejeweled:Storage().best.score == 500,
    "Repeated migration changed scores")
check(reloaded.DB[newID].best.score == 900 and #reloaded:GetRecentIDs() == 3,
    "Repeated migration changed untimed records or recent entries")
local both = save()
both[newID] = {
    best = { score = 1200, moves = 20 },
    arcaneRush = { best = { score = 100, moves = 2 } },
    custom = { current = true },
}
local merged = harness.client("Migration", "Realm", both).games
check(merged.DB[newID].best.score == 1200 and merged.DB[newID].best.moves == 20,
    "Higher current untimed record or its metadata lost")
check(merged.KICBejeweled:Storage().best.score == 500 and merged.KICBejeweled:Storage().best.moves == 7,
    "Higher old Rush record or its metadata lost")
check(merged.DB[newID].custom.current and merged.DB[newID].custom.preserved
    and merged.DB[newID].arcaneRush.custom, "Merged save fields lost")
local newer = save()
newer[newID] = { best = { score = 100 }, arcaneRush = { best = { score = 2000, moves = 30 } } }
local opposite = harness.client("Migration", "Realm", newer).games
check(opposite.DB[newID].best.score == 900 and opposite.KICBejeweled:Storage().best.score == 2000,
    "Rulesets were merged together or higher records lost")
print(string.format("PASS: %d KIC Bejeweled naming, command and save-migration assertions", checks))
