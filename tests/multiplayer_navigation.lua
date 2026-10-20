-- Real shared transport/session lifecycle with the browser and lobby as separate pages.
local old = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = old
local checks, clients = 0, {}
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local function pump(seconds)
    for _ = 1, math.ceil(seconds * 10) do
        h.advance(0.1)
        for _, c in ipairs(clients) do
            for _, timer in ipairs(c.scheduled or {}) do
                if not timer.cancelled and c.env.GetTime() >= timer.at then
                    timer.at = c.env.GetTime() + timer.period
                    timer.callback()
                end
            end
            for _, frame in ipairs(c.frames) do
                if frame.shown and frame.scripts.OnUpdate then
                    frame.scripts.OnUpdate(frame, 0.1)
                end
            end
        end
        local count = #h.packets
        for _ = 1, count do
            local packet = table.remove(h.packets, 1)
            check(packet.channel == "PARTY" and #packet.body <= 255, "Unexpected transport channel or packet size")
            for _, c in ipairs(clients) do
                c:event("CHAT_MSG_ADDON", packet.prefix, packet.body, packet.channel, packet.sender)
            end
        end
    end
end
local function waitFor(predicate, why)
    for _ = 1, 400 do
        if predicate() then
            check(true, why)
            return
        end
        pump(0.1)
    end
    error(why)
end
for i = 1, 3 do
    clients[i] = h.client("Navigation" .. i, "Realm")
end
for _, c in ipairs(clients) do
    for _, other in ipairs(clients) do
        if c ~= other then
            c.roster[#c.roster + 1] = other.name
        end
    end
    c.games.UI:OpenLauncher("multiplayer")
end
local a, b = clients[1], clients[2]
local G, H, U, V = a.games, b.games, a.games.UI, b.games.UI
local function gameCard(ui, id)
    for _, card in ipairs(ui.launcherCards) do
        if card:IsShown() and card.game.id == id then
            return card
        end
    end
    error("Missing game card: " .. id)
end
local function checkCardPresentation()
    for _, card in ipairs(U.launcherCards) do
        if card:IsShown() then
            local asset = G.Artwork[card.art.artKey]
            local uv = card.art.texCoord
            local sourceRatio = asset.width * (uv[2] - uv[1]) / (asset.height * (uv[4] - uv[3]))
            check(
                math.abs(sourceRatio - card.art:GetWidth() / card.art:GetHeight()) < 0.00001,
                "Game artwork is stretched instead of cropped to its displayed dimensions"
            )
            if card.presentation.browser then
                check(
                    card.play.caption.text == "Host Game"
                        and card.hostReason:IsShown() == (card.presentation.reason ~= nil),
                    "Game card lost its direct host action or eligibility reason"
                )
            end
        end
    end
end
check(
    U.cardColumns == 2 and U.launcherCards[1]:IsVisible() and U.launcherCards[2]:IsVisible(),
    "Installed multiplayer games are not side by side"
)
check(
    U.launcherCards[3]:IsShown() and U.cardList:GetHeight() > U.cardScroll:GetHeight(),
    "Third multiplayer game is not reachable by scrolling"
)
check(
    U.browserPanel:IsVisible() and U.multiplayerDetails == nil and not U.lobbyPanel:IsVisible(),
    "Browser includes an empty lobby"
)
for i, game in ipairs(G:GetGames("multiplayer")) do
    local card = U.launcherCards[i]
    check(
        card.component == "GameCard" and card.game == game and card.detail.text == game.description,
        "Card duplicates registry metadata"
    )
    check(card.mode.text == "MULTIPLAYER / " .. U:PlayerCount(game), "Card player count/category incorrect")
    check(
        card.art.textureValue == G.Artwork[game.id .. "-card"].file
            and card.icon:IsShown()
            and card.art:GetHeight() == card:GetHeight(),
        "Card artwork not prominent"
    )
    check(
        not card.details:IsShown() and card.play:GetWidth() == card:GetWidth() - 32,
        "Browser card has duplicate detail actions"
    )
end
checkCardPresentation()
check(U:SelectMultiplayer("blindshot"), "Could not highlight Blindshot")
checkCardPresentation()
check(gameCard(U, "chess").play:IsEnabled(), "Chess cannot host directly")
gameCard(U, "chess").play.scripts.OnClick()
local lobby, id = G.Lobby, G.Lobby.id
check(lobby.gameID == "chess", "Card hosted the highlighted game instead of its own game")
check(U.multiplayerView == "lobby" and U.lobbyPanel:IsVisible(), "Host did not navigate to lobby")
check(not U.cardScroll:IsVisible() and not U.browserPanel:IsVisible(), "Lobby still contains browser UI")
check(U.lobbyPanel:GetWidth() == U.content:GetWidth() and U.lobbyPanel.points[1][2] == 0, "Lobby is not full width")
check(
    U.lobbySlotCount == 2 and U.lobbySlots[1].role.text == "HOST" and U.lobbySlots[2].name.text == "Open Slot",
    "Host slots incorrect"
)
U.lobbyBack.scripts.OnClick()
check(
    G.Lobby == lobby and U.resumeLobby:IsVisible() and U.cardScroll:IsVisible(),
    "Back to Games silently left or hid Resume"
)
check(
    U.resumeLobby:GetParent() == U.browserPanel and U.browser:GetParent().points[1][3] == -88,
    "Resume is covered by sidebar or lobby list"
)
U:SelectMultiplayer("blindshot")
checkCardPresentation()
check(
    G.Lobby.gameID == "chess" and G.Lobby.id == id and not gameCard(U, "blindshot").play:IsEnabled(),
    "Browsing another game replaced current session"
)
U.resumeLobby.scripts.OnClick()
check(G.Lobby == lobby and U.lobbyPanel:IsVisible(), "Resume created another lobby")
U:OpenLauncher("home")
U.nav.multiplayer.scripts.OnClick()
check(U.lobbyPanel:IsVisible() and G.Lobby == lobby, "Global Multiplayer did not resume lobby")
waitFor(function()
    return H.Listings[a.name]
end, "Guest did not discover hosted lobby")
local function rowFor(host)
    for _, row in ipairs(V.listingRows) do
        if row:IsShown() and row.detail.text == "Host: " .. host then
            return row
        end
    end
end
V:Refresh()
local row = rowFor(a.name)
check(row and row.status.text == "Waiting" and row.join:IsEnabled(), "Discovery lacks eligible Join/status")
local chess = H.Registry.chess
H.Registry.chess = nil
V:Refresh()
row = rowFor(a.name)
check(
    not row.join:IsEnabled() and row.status.text == "Unavailable" and row.reason.text == "Game module is not installed",
    "Missing module Join was enabled or reason hidden"
)
H.Registry.chess = chess
local version = chess.version
chess.version = "different"
V:Refresh()
check(
    row.reason.text == "Different game module version" and not row.join:IsEnabled(),
    "Version mismatch reason incorrect"
)
chess.version = version
V:Refresh()
local available = H.Copy(H.Listings[a.name])
available.count = available.max
local allowed, reason, status = V:LobbyAvailability(available)
check(not allowed and reason == "Lobby is full" and status == "Waiting", "Full lobby reason incorrect")
available.count = 1
available.status = "running"
allowed, reason, status = V:LobbyAvailability(available)
check(not allowed and reason == "Game has already started" and status == "In Game", "Running lobby reason incorrect")
available.rejoin = true
check(V:LobbyAvailability(available), "Eligible rejoin was disabled")
local oldChannel = b.channel
b.channel = "RAID"
allowed, reason, status = V:LobbyAvailability(available)
check(
    not allowed and status == "Unavailable" and reason:find("PARTY", 1, true),
    "Unsupported group has no actual reason"
)
b.channel = oldChannel
row.join.scripts.OnClick()
check(H.Pending and V.lobbyPanel:IsVisible(), "Join request did not navigate to shared joining view")
check(V.selectedGame.text == "Chess", "Pending join displayed the independently selected browser game")
waitFor(function()
    return H.Lobby and #G.Lobby.members == 2
end, "Join did not complete")
check(
    V.lobbyPanel:IsVisible() and not V.cardScroll:IsVisible() and V.lobbySlotCount == 2,
    "Guest did not use dedicated lobby"
)
check(V.lobbySlots[1].name.text == a.name and V.lobbySlots[2].role.text == "YOU", "Guest slot identity incorrect")
G:Ready(true)
pump(2)
check(G.Lobby.status == "waiting" and not G.ActiveGame, "Started below required readiness")
check(U.lobbySummary.text == "2/2 joined  /  1/2 ready", "Joined/Ready counts incorrect")
H:Ready(true)
waitFor(function()
    return G.Lobby.status == "countdown"
end, "All Ready did not start countdown")
check(H:Ready(false), "Guest could not unready during countdown")
waitFor(function()
    return G.Lobby.status == "waiting" and H.Lobby.status == "waiting"
end, "Unready did not cancel countdown")
check(not G.ActiveGame and not H.ActiveGame, "Canceled countdown launched a game")
check(G:Ready(true) and H:Ready(true), "Could not ready again")
waitFor(function()
    return G.ActiveGame and H.ActiveGame and G.Chess.running and H.Chess.running
end, "Chess did not launch")
check(U.gameContainer:IsVisible() and V.gameContainer:IsVisible(), "Game page not shown")
check(G.Lobby.id == id and H.Lobby.id == id and G.Lobby.run == 1, "Start duplicated or replaced session")
V:OpenLauncher("multiplayer")
check(V.lobbyPanel:IsVisible() and V.showGame:IsVisible(), "Active game cannot resume from lobby")
V.lobbyBack.scripts.OnClick()
check(
    H.ActiveGame and V.resumeLobby:IsVisible() and not gameCard(V, "chess").play:IsEnabled(),
    "Browsing ended live game"
)
V.nav.multiplayer.scripts.OnClick()
V.leave.scripts.OnClick()
waitFor(function()
    return not H.Lobby and not G.ActiveGame
end, "Leave did not interrupt cleanly")
check(V.multiplayerView == "browser" and V.browserPanel:IsVisible(), "Leave did not return to browser")
G:LeaveLobby()
-- Discovery filters removed hosts and expired listings without inventing sessions.
V:Refresh()
local fake = H.Copy(H.Listings[a.name] or {
    id = "stale",
    host = a.name,
    gameID = "chess",
    gameTitle = "Chess",
    gameVersion = version,
    status = "waiting",
    count = 1,
    max = 2,
})
fake.seen = b.env.GetTime() - 61
H.Listings[a.name] = fake
V:Refresh()
check(not rowFor(a.name), "Expired listing still shown")
fake.seen = b.env.GetTime()
H.Listings["Outsider-Realm"] = H.Copy(fake)
H.Listings["Outsider-Realm"].host = "Outsider-Realm"
H.Listings[a.name] = nil
V:Refresh()
check(
    V.emptyLobbies:IsShown() and V.emptyLobbies.text == "No party lobbies found." and V.emptyLobbiesDetail:IsShown(),
    "Empty discovery state is wrong or includes outsiders"
)
-- New registry entries populate rows without a second details panel.
G:RegisterGame({
    id = "future_party",
    title = "Future Party",
    mode = "multiplayer",
    version = "1",
    minPlayers = 3,
    maxPlayers = 4,
    description = "A future registry-provided description.",
    icon = 134400,
    OnStart = function() end,
    CreateUI = function(_, parent)
        return a.env.CreateFrame("Frame", nil, parent)
    end,
})
U:OpenLauncher("multiplayer")
check(#G:GetGames("multiplayer") == 4 and U.launcherCards[4]:IsVisible(), "Future module missing from browser")
U:SelectMultiplayer("future_party")
check(
    gameCard(U, "future_party").detail.text == G.Registry.future_party.description
        and gameCard(U, "future_party").mode.text:find("3-4 players", 1, true),
    "Future metadata hardcoded"
)
for _, size in ipairs({ { 1000, 700 }, { 1120, 700 }, { 1500, 900 } }) do
    U:SetWindowSize(size[1], size[2])
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        U:SetWindowScale(scale)
        checkCardPresentation()
        check(
            U.cardScroll.points[1][2] + U.cardScroll:GetWidth() + 14 <= U.browserPanel.points[1][2],
            "Game library overlaps lobby sidebar"
        )
        check(
            -U.browserPanel.points[1][3] + U.browserPanel:GetHeight() <= U.content:GetHeight() + 0.01,
            "Party list overflows content"
        )
    end
end
U:OpenLauncher("singleplayer")
checkCardPresentation()
local reused = U.launcherCards[1]
check(
    reused.game.mode == "singleplayer"
        and reused.details:IsShown()
        and reused.icon:IsShown()
        and reused.art:GetHeight() == reused:GetHeight()
        and reused.title.points[1][2] == 110,
    "Multiplayer card layout leaked into Singleplayer"
)
U:OpenLauncher("multiplayer")
checkCardPresentation()
check(
    not U.launcherCards[1].details:IsShown() and U.launcherCards[1].art:GetHeight() == U.launcherCards[1]:GetHeight(),
    "Reused multiplayer card did not restore browser presentation"
)
-- Seven games form four rows, while a large lobby list scrolls independently.
for i = 1, 3 do
    G:RegisterGame({
        id = "future_" .. i,
        title = "An unusually long multiplayer game title " .. i,
        mode = "multiplayer",
        version = "1",
        minPlayers = 2,
        maxPlayers = 5,
        description = string.rep("A longer description that must stay inside its card. ", 6),
        icon = 134400,
        OnStart = function() end,
        CreateUI = function(_, parent)
            return a.env.CreateFrame("Frame", nil, parent)
        end,
    })
end
U:SetWindowSize(1120, 700)
U:SetWindowScale(1)
U:Refresh()
check(U.cardColumns == 2 and #G:GetGames("multiplayer") == 7, "Seven-game library is not two columns")
check(U.launcherCards[7].points[1][3] == -822 and U.cardList:GetHeight() == 1082, "Seven games did not form four rows")
for i = 1, 14 do
    local host = "Sidebar" .. i .. "-Realm"
    a.roster[#a.roster + 1] = host
    G.Listings[host] = {
        id = "sidebar-" .. i,
        host = host,
        gameID = "chess",
        gameTitle = "Chess",
        gameVersion = G.Registry.chess.version,
        status = "waiting",
        count = 1,
        max = 2,
        seen = a.env.GetTime(),
    }
end
U:Refresh()
local sidebarScroll = U.browser:GetParent()
U.cardScroll:SetVerticalScroll(0)
sidebarScroll:SetVerticalScroll(0)
U.cardScroll.scripts.OnMouseWheel(U.cardScroll, -3)
check(U.cardScroll:GetVerticalScroll() > 0 and sidebarScroll:GetVerticalScroll() == 0, "Game scroll moved lobby list")
local libraryOffset = U.cardScroll:GetVerticalScroll()
sidebarScroll.scripts.OnMouseWheel(sidebarScroll, -3)
check(
    sidebarScroll:GetVerticalScroll() > 0 and U.cardScroll:GetVerticalScroll() == libraryOffset,
    "Lobby scroll moved games"
)
check(U.cardScroll.scrollBar:IsShown() and sidebarScroll.scrollBar:IsShown(), "Independent scrollbars missing")
check(
    U.listingRows[1].capacity.text == "1/2 players" and U.listingRows[1].title.text == "Chess",
    "Lobby metadata missing"
)
local rowCount = #U.listingRows
U:Refresh()
check(#U.listingRows == rowCount, "Refresh duplicated lobby cards")
local discover, refreshed = G.Discover, false
G.Discover = function()
    refreshed = true
end
U.browserRefresh.scripts.OnClick()
G.Discover = discover
check(refreshed, "Sidebar Refresh no longer discovers lobbies")
for _, size in ipairs({ { 1000, 700 }, { 1120, 700 }, { 1500, 900 } }) do
    U:SetWindowSize(size[1], size[2])
    check(U.cardColumns == (size[1] == 1000 and 1 or 2), "Responsive library columns incorrect")
    for _, card in ipairs(U.launcherCards) do
        if card:IsShown() then
            check(
                card:GetWidth() >= 250 and card.points[1][2] + card:GetWidth() <= U.cardList:GetWidth() + 0.01,
                "Game card clipped"
            )
            check(-card.play.points[1][3] + card.play:GetHeight() <= card:GetHeight(), "Host action exceeds card")
        end
    end
end
local solo = h.client("BrowserSolo", "Realm")
solo.grouped = false
solo.games.UI:OpenLauncher("multiplayer")
for _, card in ipairs(solo.games.UI.launcherCards) do
    if card:IsShown() then
        check(
            not card.play:IsEnabled() and card.hostReason.text == "Join a party to host",
            "No-party host eligibility incorrect"
        )
        check(
            card.art:IsVisible() and card.icon:IsVisible() and card.detail:IsVisible(),
            "No-party browsing hid card content"
        )
    end
end
for _, c in ipairs(clients) do
    check(#c.chatMessages == 0, "Visible chat emitted")
    for _, notice in ipairs(c.notices) do
        check(not notice:find(" / CreateUI:", 1, true) and not notice:find(" / OnStart:", 1, true), notice)
    end
end
print(
    string.format(
        "PASS: %d multiplayer browser, full-width host/guest lobby, metadata, navigation, discovery and start-flow assertions",
        checks
    )
)
