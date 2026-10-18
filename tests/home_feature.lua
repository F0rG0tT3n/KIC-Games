-- Real launcher/session lifecycle; deterministic random indices, no statistical flakiness.
local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local checks = 0
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local c = h.client("Feature", "Realm")
c.grouped = false
local G, U = c.games, c.games.UI
local originalRandom, draws, nextIndex = c.env.math.random, 0, 1
c.env.math.random = function(n)
    draws = draws + 1
    check(n == #G:GetGames(), "Featured selection is not uniform over the installed registry")
    return nextIndex
end
U:OpenLauncher("home")
check(draws == 1 and U.featuredID == G:GetGames()[1].id, "First Home opening did not choose a game")
local chosen, frames = U.featuredID, #c.frames
for _ = 1, 8 do
    U:Refresh()
    U:RefreshLauncherStatus()
    U.frame.scripts.OnUpdate(U.frame, 0.1)
    U.nav.home.scripts.OnEnter()
    U.nav.home.scripts.OnLeave()
    U:OpenLauncher("home")
end
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    U:SetWindowScale(scale)
    U:SetWindowSize(1120, 700)
end
check(draws == 1 and U.featuredID == chosen and #c.frames == frames, "Refreshing Home rerolled or rebuilt its UI")
local modes = {}
for i, game in ipairs(G:GetGames()) do
    U:OpenLauncher("options")
    nextIndex = i
    local before = draws
    U:OpenLauncher("home")
    check(draws == before + 1 and U.featuredID == game.id, "Registry index did not select exactly its game")
    check(
        U.soloTitle.text == game.title:upper() and U.soloDescription.text == game.description,
        "Hero metadata incorrect"
    )
    check(
        U.heroArt.artKey == game.id:gsub("_", "-") .. "-hero" and U.hero:GetHeight() == 256,
        "Hero artwork or dimensions changed"
    )
    check(U.soloPlay:IsShown() and not U.soloOpen:IsShown(), "Idle hero incorrectly offers Continue")
    modes[game.mode] = true
    if game.mode == "multiplayer" then
        check(
            U.soloPlay.text == "View lobby" and U.heroBadge.text:find(U:PlayerCount(game), 1, true),
            "Party feature lacks action/count"
        )
        U.soloPlay.scripts.OnClick()
        check(
            U.launcherPage == "multiplayer" and U.multiplayerView == "browser" and U.selectedMulti == game.id,
            "Party feature navigated incorrectly"
        )
        check(
            not G.Lobby and not G.Pending and not G.ActiveGame,
            "Random party feature automatically hosted or started"
        )
    else
        check(U.soloPlay.text == "Play", "Idle solo feature lacks Play")
    end
end
check(modes.singleplayer and modes.multiplayer, "No-party showcase excluded a game mode")
U:OpenLauncher("home")
local before = draws
U:HideAll()
U:Toggle()
check(draws == before + 1, "Reopening a closed Home did not reroll")
c.env.math.random = originalRandom

-- Real solo sessions remain authoritative while paused/hidden and never restart.
for _, id in ipairs({ "bejeweled", "tetris" }) do
    U:FeatureGame(id)
    U.soloPlay.scripts.OnClick()
    check(G.ActiveGame and G.ActiveGame.game.id == id, "Play did not start the featured solo game")
    local active = G.ActiveGame
    local module = id == "bejeweled" and G.Bejeweled or G.Tetris
    local model, run = module.model, G.Lobby.run
    U:OpenLauncher("options")
    U:FeatureGame(id == "tetris" and "chess" or "tetris")
    U:OpenLauncher("home")
    check(
        U.featuredID == id and U.soloOpen:IsShown() and U.soloOpen.text == "Continue Game",
        "Active solo game lost priority"
    )
    check(not U.soloPlay:IsShown() and U.heroArt.artKey == id .. "-hero", "Active solo hero is incorrect")
    local activeDraws = 0
    c.env.math.random = function()
        activeDraws = activeDraws + 1
        return 1
    end
    U:HideAll()
    U:Toggle()
    U:OpenLauncher("results")
    U:OpenLauncher("home")
    U:SetWindowScale(1)
    U:Refresh()
    check(U.featuredID == id and activeDraws == 0, "Hidden active session lost priority or drew a random game")
    U.soloOpen.scripts.OnClick()
    check(
        G.ActiveGame == active and module.model == model and G.Lobby.run == run and U.gameContainer:IsVisible(),
        "Continue reset the session"
    )
    c.env.math.random = originalRandom
    U:OpenLauncher("home")
    local completedDraws = 0
    c.env.math.random = function(n)
        completedDraws = completedDraws + 1
        return n
    end
    check(
        G:FinishGame({ summary = "Feature test complete", entries = { { player = c.name, score = 10 } } }),
        "Could not finish session"
    )
    check(
        not G.ActiveGame and completedDraws == 1 and not U.soloOpen:IsShown(),
        "Completion on Home did not return to random showcase"
    )
    local after = U.featuredID
    U:Refresh()
    check(completedDraws == 1 and U.featuredID == after, "Completed session rerolls on every refresh")
    local results = #G:GetResults()
    -- An already-ended Continue callback must not fall through to Play.
    U.soloOpen.scripts.OnClick()
    check(not G.ActiveGame and #G:GetResults() == results, "Stale Continue callback started another game")
    c.env.math.random = originalRandom
end

-- Registry additions/removals, missing artwork, empty/one-game libraries.
local function registration(id)
    return {
        id = id,
        title = "Future " .. id,
        mode = "multiplayer",
        version = "1",
        minPlayers = 2,
        maxPlayers = 4,
        description = "Future game registry description.",
        icon = 134400,
        CreateUI = function(_, parent)
            return c.env.CreateFrame("Frame", nil, parent)
        end,
        OnStart = function() end,
    }
end
U:OpenLauncher("home")
local stable = U.featuredID
G:RegisterGame(registration("zz_future"))
check(U.featuredID == stable, "Adding a game changed a still-valid Home choice")
c.env.math.random = function(n)
    return n
end
U:OpenLauncher("options")
U:OpenLauncher("home")
-- GetGames sorts by title, so explicitly enumerate every index of the extended pool.
for i, game in ipairs(G:GetGames()) do
    if game.id == "zz_future" then
        c.env.math.random = function(n)
            check(n == 6, "New registration was not included")
            return i
        end
    end
end
U:OpenLauncher("options")
U:OpenLauncher("home")
check(
    U.featuredID == "zz_future"
        and U.heroFallback:IsShown()
        and U.soloDescription.text == G.Registry.zz_future.description,
    "Future game or artwork fallback missing"
)
G.Registry.zz_future = nil
c.env.math.random = function()
    return 1
end
U:Refresh()
check(U.featuredID ~= "zz_future" and G.Registry[U.featuredID], "Removed featured game remained visible")
local registry = G.Registry
G.Registry = { only = registration("only"), invalid = registration("invalid") }
G.Registry.invalid.OnStart = nil
local singleDraws = 0
c.env.math.random = function(n)
    singleDraws = singleDraws + 1
    check(n == 1, "Invalid/unimplemented registration entered random pool")
    return 1
end
U:Refresh()
check(U.featuredID == "only", "Single valid game was not featured")
G.Registry = {}
U:Refresh()
check(
    not U.featuredID and not U.soloPlay:IsShown() and not U.soloOpen:IsShown(),
    "Empty registry did not show safe empty hero"
)
check(singleDraws == 1, "Empty registry attempted an invalid random draw")
G.Registry = registry
c.env.math.random = originalRandom

-- Actual two-client multiplayer matches and a real recoverable Chess journal.
local peers = {}
local function pump(seconds)
    for _ = 1, math.ceil(seconds * 10) do
        h.advance(0.1)
        for _, peer in ipairs(peers) do
            for _, timer in ipairs(peer.scheduled or {}) do
                if not timer.cancelled and peer.env.GetTime() >= timer.at then
                    timer.at = peer.env.GetTime() + timer.period
                    timer.callback()
                end
            end
            for _, frame in ipairs(peer.frames) do
                if frame.shown and frame.scripts.OnUpdate then
                    frame.scripts.OnUpdate(frame, 0.1)
                end
            end
        end
        local count = #h.packets
        for _ = 1, count do
            local packet = table.remove(h.packets, 1)
            for _, peer in ipairs(peers) do
                peer:event("CHAT_MSG_ADDON", packet.prefix, packet.body, packet.channel, packet.sender)
            end
        end
    end
end
for _, id in ipairs({ "chess", "blindshot" }) do
    local host, guest = h.client("FeatureHost" .. id, "Realm"), h.client("FeatureGuest" .. id, "Realm")
    peers = { host, guest }
    host.roster, guest.roster = { guest.name }, { host.name }
    local games, ui = host.games, host.games.UI
    check(games:CreateLobby(id), "Could not create party lobby")
    ui:OpenLauncher("home")
    check(not ui:FeaturedActiveGame() and not ui.soloOpen:IsShown(), "Unstarted lobby counted as active gameplay")
    ui:FeatureGame(id)
    local waiting = games.Lobby
    ui.soloPlay.scripts.OnClick()
    check(games.Lobby == waiting and ui.multiplayerView == "browser", "View Lobby replaced/hosted or skipped browser")
    pump(6)
    local joined, joinReason = guest.games:JoinLobby(host.name, games.Lobby.id)
    check(joined, "Guest could not join: " .. tostring(joinReason))
    pump(3)
    check(games:Ready(true) and guest.games:Ready(true), "Could not ready multiplayer match")
    pump(6)
    check(games.ActiveGame and guest.games.ActiveGame, "Multiplayer match did not start")
    local active, lobbyID, run = games.ActiveGame, games.Lobby.id, games.Lobby.run
    ui:OpenLauncher("home")
    ui:FeatureGame("bejeweled")
    check(ui.featuredID == id and ui.soloOpen:IsShown(), "Active multiplayer game lost priority")
    ui:HideAll()
    ui:Toggle()
    check(ui.featuredID == id and ui.heroArt.artKey == id .. "-hero", "Hidden multiplayer match lost artwork/priority")
    ui.soloOpen.scripts.OnClick()
    check(
        games.ActiveGame == active and games.Lobby.id == lobbyID and games.Lobby.run == run,
        "Multiplayer Continue reset the match"
    )
    if id == "chess" then
        local saved = games.Copy(games.DB)
        local reloaded = h.client("FeatureHost" .. id, "Realm", saved)
        reloaded.roster = { guest.name }
        peers, host, games, ui = { reloaded, guest }, reloaded, reloaded.games, reloaded.games.UI
        pump(10)
        ui:OpenLauncher("home")
        check(
            games.ActiveGame and ui.featuredID == "chess" and ui.soloOpen:IsShown(),
            "Recovered session did not take priority"
        )
    end
    games:LeaveLobby()
    guest.games:LeaveLobby()
end
local stale = h.client("StaleFeature", "Realm", { launcherPage = "home", activeGame = "tetris", featuredID = "tetris" })
stale.games.UI:OpenLauncher("home")
check(
    not stale.games.ActiveGame and not stale.games.UI.soloOpen:IsShown(),
    "Stale saved values invented an active game"
)
check(#G:GetRecentGames() == 2 and G:GetRecentGames()[1].id == "tetris", "Featured choices polluted Recent Games")
print(
    string.format(
        "PASS: %d Home feature priority, uniform selection, stable refresh, navigation, lifecycle and recovery assertions",
        checks
    )
)
