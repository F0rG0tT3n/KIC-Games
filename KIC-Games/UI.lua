local _, Games = ...
local UI = { listingRows = {} }
UI.BASE_WIDTH, UI.BASE_HEIGHT = 1120, 700
Games.UI = UI
local Theme = Games.Theme
local GOLD = Theme.Colors.accent

-- Use the same record provider as gameplay and sharing, including games with
-- a separate score bucket for their current ruleset.
function UI:GetPersonalBest(id)
    local module = id == "tetris" and Games.Tetris
        or id == "bejeweled" and Games.Bejeweled
        or id == "kic_bejeweled" and Games.KICBejeweled
        or id == "chess" and Games.Chess
        or id == "blindshot" and Games.Blindshot
        or id == "minesweeper" and Games.Minesweeper
    local saved = module and module:Storage() or Games.DB[id]
    return type(saved) == "table" and type(saved.best) == "table" and saved.best or nil
end
function UI:GetPersonalBestMode(id)
    return id == "kic_bejeweled" and Games.KICBejeweled:ModeLabel() or nil
end

local function label(parent, value, x, y, width, template)
    return Theme:Label(parent, value, x, y, width, template)
end

local function panel(parent, width, height, x, y)
    return Theme:Panel(parent, width, height, x, y)
end

local function action(fn)
    return function()
        local ok, err = fn()
        if ok == false and err then
            Games:Notify(err)
        end
    end
end

local function button(parent, value, width, x, y, callback)
    return Theme:Button(parent, value, width, x, y, callback)
end

local function scroll(parent, width, height, x, y)
    return Theme:Scroll(parent, width, height, x, y)
end

local function enable(widget, condition)
    if condition then
        widget:Enable()
    else
        widget:Disable()
    end
end

function UI:Initialize()
    local frame = panel(UIParent, self.BASE_WIDTH, self.BASE_HEIGHT, 0, 0)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    Theme:Window(frame, false, true)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        UI:HideAuxiliaryWindows()
        UI:PauseGameplay()
    end)
    frame:Hide()
    _G.KICGamesWindow = frame
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesWindow"
    self.frame = frame
    Theme:Art(frame, "logo", 64, 64, 18, -9, 1, "ARTWORK")
    local title = label(frame, "|cff14d6ffKIC|r GAMES", 94, -18, 360, "GameFontNormalLarge")
    title:SetFont("Fonts\\ARIALN.TTF", 28, "")
    title:SetTextColor(unpack(Theme.Colors.text))
    label(frame, "A little play between adventures", 94, -53, 410, "GameFontHighlightSmall")
    self.closeButton = Theme:CloseButton(frame)
    self.optionsButton = button(frame, "Options", 90, 440, -34, function()
        UI:ShowOptions()
    end)
    self.homeButton = button(frame, "Launcher", 100, 742, -34, function()
        UI:OpenLauncher("home")
    end)
    self.homeButton.gameIcon = Theme:GameIcon(self.homeButton, "icon-back", 20)
    self.homeButton:Hide()
    self.resultsButton = button(frame, "Results", 90, 536, -34, function()
        UI:ShowResults()
    end)
    self.abortButton = button(frame, "|cffff6060Stop game|r", 110, 628, -34, function()
        local page = UI.launcherPage
        Games:AbortGame()
        UI:OpenLauncher(page)
    end)
    self.abortButton:Hide()
    self.continueButton = button(frame, "Continue game", 136, 478, -34, function()
        local id = Games.ActiveGame and Games.ActiveGame.game.id
        local module = id == "tetris" and Games.Tetris
            or id == "bejeweled" and Games.Bejeweled
            or id == "kic_bejeweled" and Games.KICBejeweled
        if module and module.running and module.paused then
            UI:ShowGame()
            module:Pause(false)
        end
    end)
    self.continueButton:Hide()
    self.continueButton.variant = "continue"
    self.home = CreateFrame("Frame", nil, frame)
    self.home:SetAllPoints()
    self.tab = Games.DB.launcherTab == "singleplayer" and "singleplayer" or "multiplayer"
    self.singleTab = button(self.home, "Singleplayer", 165, 20, -80, function()
        UI:SelectTab("singleplayer")
    end)
    self.multiTab = button(self.home, "Multiplayer", 165, 190, -80, function()
        UI:SelectTab("multiplayer")
    end)

    local browser = panel(self.home, 355, 186, 20, -384)
    self.browserPanel = browser
    self.browserTitle = label(browser, "PARTY LOBBIES", 14, -14, 205, "GameFontNormal")
    self.browserRefresh = button(browser, "Refresh", 90, 248, -9, function()
        Games:Discover()
    end)
    self.browser = scroll(browser, 303, 126, 14, -44)
    self.emptyLobbies =
        label(self.browser, "No lobbies found.\n\nCreate one, or ask a party member with KIC-Games to host.", 0, 0, 290)
    self.emptyLobbiesDetail = label(self.browser, "Host a game or wait for someone in your party.", 0, -30, 290)
    self.emptyLobbiesDetail:SetHeight(48)

    local lobbyPanel = panel(self.home, 485, 450, 395, -120)
    self.lobbyPanel = lobbyPanel
    self.lobbyTitle = label(lobbyPanel, "YOUR LOBBY", 16, -14, 450, "GameFontNormal")
    self.lobbyInfo = label(lobbyPanel, "", 16, -45, 450)
    self.selectedGame = label(lobbyPanel, "", 16, -107, 450, "GameFontNormalLarge")
    self.selectedGame:SetHeight(38)
    self.gameInfo = label(lobbyPanel, "", 16, -153, 450, "GameFontHighlightSmall")
    self.gameInfo:SetHeight(30)
    self.players = label(lobbyPanel, "", 16, -193, 450)
    self.players:SetSpacing(8)
    self.lobbySlots = {}
    self.countdownText = label(lobbyPanel, "", 16, -308, 450, "GameFontNormalLarge")
    self.countdownText:SetJustifyH("CENTER")
    self.hint = label(lobbyPanel, "", 16, -340, 450, "GameFontHighlightSmall")
    self.leave = button(lobbyPanel, "Leave lobby", 125, 16, -393, function()
        Games:LeaveLobby()
    end)
    self.ready = button(
        lobbyPanel,
        "Ready",
        120,
        151,
        -393,
        action(function()
            local own = Games:LocalMember()
            return Games:Ready(Games.Lobby.status ~= "countdown" and own and not own.ready)
        end)
    )
    self.start = button(lobbyPanel, "Auto start", 145, 281, -393, function() end)
    self.start:Disable()
    self.showGame = button(lobbyPanel, "Open game", 120, 151, -393, function()
        UI:ShowGame()
    end)
    self.endGame = button(
        lobbyPanel,
        "Stop match",
        145,
        281,
        -393,
        action(function()
            return Games:AbortGame()
        end)
    )

    self.singlePanel = panel(self.home, 485, 450, 395, -120)
    self.soloSection = label(self.singlePanel, "PLAY SOLO", 16, -14, 450, "GameFontNormal")
    self.soloTitle = label(self.singlePanel, "", 16, -58, 450, "GameFontNormalLarge")
    self.soloDescription = label(self.singlePanel, "", 16, -100, 450)
    self.soloDescription:SetHeight(90)
    self.soloHint = label(self.singlePanel, "", 16, -220, 450)
    self.soloPlay = button(
        self.singlePanel,
        "Play",
        145,
        16,
        -393,
        action(function()
            return Games:StartSingleplayer(UI.selectedSolo)
        end)
    )
    Theme:Select(self.soloPlay, true)
    self.soloOpen = button(self.singlePanel, "Open game", 145, 16, -393, function()
        UI:ShowGame()
    end)
    self.soloLeave = button(self.singlePanel, "Leave current lobby", 190, 16, -350, function()
        Games:LeaveLobby()
    end)
    self.footer = label(frame, "", 22, -669, 980, "GameFontHighlightSmall")
    self.gameContainer = panel(frame, 860, 450, 130, -116)
    self.gameContainer:Hide()
    self:InitializeLauncher()
    self:CreateResultsWindow()
    self:CreateOptions()
    self:LayoutLauncher()
    self:InitializeResize()
    self:CreateMinimapButton()
    frame:SetScript("OnUpdate", function()
        UI:UpdateCountdown()
    end)
    self:Refresh()
end

function UI:SelectTab(mode)
    if mode == "singleplayer" or mode == "multiplayer" then
        self:OpenLauncher(mode)
    end
end

function UI:UpdateCountdown()
    if not self.countdownText then
        return
    end
    local remaining = Games:CountdownRemaining()
    local display = remaining ~= nil and not Games:IsRoundStopped() and remaining or false
    if self.lastCountdownDisplay == display then
        return
    end
    self.lastCountdownDisplay = display
    self.countdownText:SetShown(display ~= false)
    if remaining ~= nil then
        self.countdownText:SetText(remaining > 0 and ("Game starts in " .. remaining .. "...") or "Starting...")
    end
end

function UI:RefreshSingleplayer()
    local game = Games.Registry[self.selectedSolo]
    local lobby = Games.Lobby
    local running = lobby and lobby.mode == "singleplayer" and lobby.status == "running"
    self.soloTitle:SetText(game and game.title or "Choose a singleplayer game")
    self.soloDescription:SetText(
        game and (game.description or "") or "Installed solo games will appear in the library."
    )
    self.soloHint:SetText(
        lobby and lobby.mode == "multiplayer" and "You are in a multiplayer lobby. Leave it before playing solo."
            or "Singleplayer games work without a party. Results and quick stopping are shared with the framework."
    )
    self.soloPlay:SetShown(not running)
    enable(
        self.soloPlay,
        game and not Games.Pending and (not lobby or (lobby.mode == "singleplayer" and lobby.status == "waiting"))
    )
    self.soloOpen:SetShown(running and Games.ActiveGame ~= nil)
    self.soloLeave:SetShown(Games.Pending ~= nil or (lobby and lobby.mode == "multiplayer"))
end

function UI:RegisterAuxiliaryWindow(frame)
    self.auxiliaryWindows = self.auxiliaryWindows or {}
    self.auxiliaryWindows[#self.auxiliaryWindows + 1] = frame
    frame:SetScale(self.frame:GetScale())
end

function UI:HideAuxiliaryWindows()
    for _, frame in ipairs(self.auxiliaryWindows or {}) do
        frame:Hide()
    end
end

function UI:HideAll()
    self:HideAuxiliaryWindows()
    if self.frame then
        self.frame:Hide()
    end
    if self.resultsFrame then
        self.resultsFrame:Hide()
    end
end

function UI:GetGameContainer()
    self:LayoutGameContainer()
    return self.gameContainer
end
function UI:LayoutGameContainer()
    local displayed = Games.ActiveGame or self.completedGame
    local id = displayed and displayed.game.id
    local module = id == "bejeweled" and Games.Bejeweled
        or id == "tetris" and Games.Tetris
        or id == "kic_bejeweled" and Games.KICBejeweled
        or id == "chess" and Games.Chess
        or id == "blindshot" and Games.Blindshot
        or id == "minesweeper" and Games.Minesweeper
    self.gameContainer:ClearAllPoints()
    if module then
        self.gameContainer:SetPoint("TOPLEFT", 20, -100)
        self.gameContainer:SetSize(self.frame:GetWidth() - 40, self.frame:GetHeight() - 134)
        self.gameContainer:SetBackdrop(nil)
        if module.root then
            module:LayoutUI()
        end
    else
        self.gameContainer:SetPoint("TOPLEFT", (self.frame:GetWidth() - 860) / 2, -116)
        self.gameContainer:SetSize(860, 450)
        self.gameContainer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
    end
end

function UI:PauseGameplay()
    local id = Games.ActiveGame and Games.ActiveGame.game.id
    local module = id == "tetris" and Games.Tetris
        or id == "bejeweled" and Games.Bejeweled
        or id == "kic_bejeweled" and Games.KICBejeweled
    if module and module.running then
        module:Pause(true)
    end
end

-- Completed solo boards remain viewable without retaining a running session.
function UI:ClearCompletedGame()
    local completed = self.completedGame
    self.completedGame = nil
    if completed and completed.frame then
        completed.frame:Hide()
    end
end

function UI:ShowHome()
    self:ClearCompletedGame()
    if self.launcherPage == "home" and (not self.home:IsShown() or not self.frame:IsShown()) then
        self.featureRollPending = true
    end
    self:PauseGameplay()
    self:HideAuxiliaryWindows()
    self.home:Show()
    self.gameContainer:Hide()
    self.homeButton:Hide()
    self:Refresh()
end

function UI:ShowGame()
    local displayed = Games.ActiveGame or self.completedGame
    if not displayed then
        return
    end
    if Games.ActiveGame then
        self:ClearCompletedGame()
    end
    self:HideAuxiliaryWindows()
    self.home:Hide()
    self.resultsFrame:Hide()
    self.optionsFrame:Hide()
    self:LayoutGameContainer()
    self.gameContainer:Show()
    if displayed.frame then
        displayed.frame:Show()
    end
    self.homeButton:Show()
    self.frame:Show()
    self:Refresh()
end

function UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:ShowHome()
        self.frame:Show()
        Games:Discover()
    end
end

function UI:Refresh()
    if not self.frame then
        return
    end
    if not Games.ActiveGame and not self.completedGame and self.gameContainer:IsShown() then
        self:ShowHome()
        return
    end
    local soloGames, multiGames = Games:GetGames("singleplayer"), Games:GetGames("multiplayer")
    if not Games.Registry[self.selectedSolo] then
        self.selectedSolo = soloGames[1] and soloGames[1].id
    end
    if not Games.Registry[self.selectedMulti] then
        self.selectedMulti = multiGames[1] and multiGames[1].id
    end
    self:RefreshPartyLobbies()
    local current, pending = Games.Lobby, Games.Pending
    local lobby = current and current.mode == "multiplayer" and current or nil
    local running = lobby and lobby.status == "running"
    local counting = lobby and lobby.status == "countdown"
    local interrupted = (running or counting) and Games:IsRoundStopped()
    self.abortButton:SetShown(
        current and (current.status == "running" or current.status == "countdown") and not Games:IsRoundStopped()
    )
    local key = lobby and (lobby.host .. ":" .. lobby.id) or pending and (pending.host .. ":" .. pending.id)
    if key ~= self.multiplayerSessionKey then
        self.multiplayerSessionKey = key
        self.multiplayerView = key and "lobby" or "browser"
        if key and not self.gameContainer:IsShown() then
            self.launcherPage, Games.DB.launcherPage = "multiplayer", "multiplayer"
        end
    end
    self:UpdateCountdown()
    self:RefreshSingleplayer()
    self:RefreshResults()
    self.leave:SetShown(lobby ~= nil or pending ~= nil)
    self.ready:SetShown(lobby ~= nil and not running)
    self.start:Hide()
    self.showGame:SetShown(running and Games.ActiveGame ~= nil)
    self.endGame:SetShown((running or counting) and not interrupted)
    self.announceLobby:SetShown(lobby ~= nil and Games:IsHost() and not running and not counting)
    enable(self.announceLobby, Games:CanAnnounceLobby())
    if lobby then
        local game = Games.Registry[lobby.gameID]
        self.lobbyTitle:SetText(
            interrupted and "MATCH INTERRUPTED"
                or (counting and "STARTING GAME" or (running and "GAME IN PROGRESS" or "YOUR LOBBY"))
        )
        self.lobbyInfo:SetText(
            "Host: "
                .. lobby.host
                .. "\n\n"
                .. (Games:IsHost() and "You are hosting this lobby." or "You joined this lobby.")
        )
        self.selectedGame:SetText(
            game and game.title or (lobby.gameTitle ~= "" and lobby.gameTitle or "No game selected")
        )
        self.gameInfo:SetText(
            game and (game.description or "")
                or (
                    lobby.gameID ~= "" and "Install the selected game module to play."
                    or "The host can select a game from the library."
                )
        )
        local own = Games:LocalMember()
        self.ready:SetText((counting or (own and own.ready)) and "Unready" or "Ready")
        enable(self.ready, Games:Compatible(lobby))
        local canStart, reason = Games:CanStart()
        self.hint:SetText(
            interrupted and "Match stopped locally. Waiting for the host to finalize the lobby."
                or (
                    (running or counting)
                        and "Any participant can stop the match immediately. No confirmation needed."
                    or (
                        Games:IsHost() and (canStart and "Everyone is ready. Starting automatically." or reason)
                        or "When everyone is ready, the game starts after 3, 2, 1."
                    )
                )
        )
    else
        self.lobbyTitle:SetText(pending and "JOINING LOBBY" or "PLAY WITH YOUR PARTY")
        self.lobbyInfo:SetText(
            pending and ("Waiting for " .. pending.host .. "...")
                or "Choose a multiplayer game, then click Host game. Or join a party lobby on the left."
        )
        local pendingListing = pending and Games.Listings[pending.host]
        local selected = Games.Registry[pendingListing and pendingListing.gameID or self.selectedMulti]
        self.selectedGame:SetText(selected and selected.title or "Choose a multiplayer game")
        self.gameInfo:SetText(
            selected and (selected.description or "") or "Select an installed game in the library to host it."
        )
        self.players:SetText(
            "Anyone in the party can host.\n\nEvery participant needs the selected game module.\n\nReady up together for an automatic 3, 2, 1 start."
        )
        self.hint:SetText(
            current
                    and current.mode == "singleplayer"
                    and "A solo game is active. Use Singleplayer to reopen it, or Stop game to finish it."
                or (
                    Games:GroupChannel() and "Ready to create or join a lobby."
                    or "Join a WoW party to use multiplayer lobbies."
                )
        )
    end
    self:RefreshLobbySlots(lobby)
    self.footer:SetText(
        string.format(
            "KIC-Games %s  |  %d installed game(s)  |  %s",
            Games.VERSION,
            #Games:GetGames(),
            Games:GroupChannel() and "Group connected" or "No group"
        )
    )
    self:RefreshLauncher()
end

function UI:PlayerCount(game)
    if not game then
        return ""
    end
    return game.minPlayers == game.maxPlayers and (game.maxPlayers .. " players")
        or (game.minPlayers .. "-" .. game.maxPlayers .. " players")
end
function UI:LobbyAvailability(listing)
    local current = Games.Lobby
    local joined = current and current.host == listing.host and current.id == listing.id
    local status = listing.status == "running" and "In Game"
        or listing.status == "countdown" and "Starting"
        or "Waiting"
    if joined then
        return true, nil, status, true
    end
    local game = Games.Registry[listing.gameID]
    if not game then
        return false,
            listing.gameID == "" and "Host has not selected a game" or "Game module is not installed",
            "Unavailable"
    end
    if game.mode ~= "multiplayer" or game.version ~= listing.gameVersion then
        return false, "Different game module version", "Unavailable"
    end
    if
        game.partyOnly
        and (Games:GroupChannel() ~= "PARTY" or IsInRaid() or GetNumGroupMembers() < 2 or GetNumGroupMembers() > 5)
    then
        return false, "Requires an ordinary PARTY of 2-5 players", "Unavailable"
    end
    if listing.status == "running" and not listing.rejoin then
        return false, "Game has already started", status
    end
    if listing.count >= listing.max and not listing.rejoin then
        return false, "Lobby is full", status
    end
    if current then
        return false, "Leave your current lobby first", status
    end
    if Games.Pending then
        return false, "Joining a lobby...", status
    end
    if Games.ActiveGame then
        return false, "Finish your current game first", status
    end
    return true, nil, status
end
function UI:RefreshPartyLobbies()
    local listings, roster = {}, Games:Roster()
    for host, listing in pairs(Games.Listings) do
        if roster[host] and GetTime() - listing.seen <= 60 then
            listings[#listings + 1] = listing
        end
    end
    table.sort(listings, function(a, b)
        return a.host < b.host
    end)
    self.emptyLobbies:SetText("No party lobbies found.")
    self.emptyLobbies:SetShown(#listings == 0)
    self.emptyLobbiesDetail:SetShown(#listings == 0)
    for _, row in ipairs(self.listingRows) do
        row:Hide()
    end
    for i, listing in ipairs(listings) do
        local row = self.listingRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.browser, "BackdropTemplate")
            Theme:StyleButton(row)
            Theme:StylePremiumFrame(row, "card-frame", { compact = true })
            row.title = label(row, "", 12, -8, 450, "GameFontNormal")
            row.title:SetHeight(18)
            row.title:SetMaxLines(1)
            row.detail = label(row, "", 12, -30, 450, "GameFontHighlightSmall")
            row.detail:SetHeight(16)
            row.detail:SetMaxLines(1)
            row.reason = label(row, "", 12, -49, 450, "GameFontHighlightSmall")
            row.reason:SetHeight(30)
            row.reason:SetMaxLines(2)
            row.status = label(row, "", 0, 0, 124, "GameFontHighlightSmall")
            row.status:SetJustifyH("RIGHT")
            row.status:SetMaxLines(1)
            row.capacity = label(row, "", 12, -51, 200, "GameFontHighlightSmall")
            row.join = Theme:NeonButton(row, "Join", 96, 0, 0, function() end, 30, true)
            self.listingRows[i] = row
        end
        local host, id = listing.host, listing.id
        local game = Games.Registry[listing.gameID]
        local eligible, reason, status, joined = self:LobbyAvailability(listing)
        row.title:SetText(game and game.title or listing.gameTitle ~= "" and listing.gameTitle or "Choosing a game")
        row.detail:SetText("Host: " .. host)
        row.capacity:SetText(listing.count .. "/" .. listing.max .. " players")
        row.reason:SetText(reason or (joined and "Your current lobby" or ""))
        row.status:SetText(status)
        row.join:SetText(joined and "Resume" or listing.rejoin and "Rejoin" or "Join")
        local click = action(function()
            -- Revalidate on click, including a listing that expired between refreshes.
            local latest = Games.Listings[host]
            if not latest or latest.id ~= id or not Games:Roster()[host] or GetTime() - latest.seen > 60 then
                self:Refresh()
                return false, "This lobby is no longer available."
            end
            local allowed, why, _, isJoined = self:LobbyAvailability(latest)
            if not allowed then
                return false, why
            end
            if isJoined then
                self:OpenLauncher("multiplayer")
                return true
            end
            return Games:JoinLobby(host, id)
        end)
        row:SetScript("OnClick", click)
        row.join:SetScript("OnClick", click)
        row:SetEnabled(eligible)
        row.join:SetEnabled(eligible)
        Theme:Select(row, joined)
        row:Show()
    end
    self.browser:SetHeight(math.max(80, #listings * 156 - 10))
    if self.browserHeading then
        self:LayoutPartyLobbies(self.browserPanel:GetWidth(), self.browserPanel:GetHeight())
    end
end
function UI:LayoutPartyLobbies(width, height)
    self.browserPanel:SetSize(width, height)
    local scroll = self.browser:GetParent()
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 14, -46)
    scroll:SetSize(width - 28, math.max(50, height - 60))
    self.browser:SetWidth(width - 46)
    self.browserHeading.title:SetFont(Theme.Fonts.display, width < 290 and 12 or 14, "")
    self.browserHeading:SetWidth(width - 112)
    self.browserRefresh:ClearAllPoints()
    self.browserRefresh:SetPoint("TOPLEFT", width - 90, -10)
    self.browserRefresh:SetWidth(76)
    self.emptyLobbies:SetWidth(width - 46)
    self.emptyLobbies:SetHeight(24)
    self.emptyLobbiesDetail:SetWidth(width - 46)
    for i, row in ipairs(self.listingRows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 156)
        row:SetSize(width - 46, 146)
        row.title:SetWidth(width - 70)
        row.detail:SetWidth(width - 70)
        row.reason:ClearAllPoints()
        row.reason:SetPoint("TOPLEFT", 12, -75)
        row.reason:SetWidth(width - 70)
        row.capacity:SetWidth(90)
        row.status:ClearAllPoints()
        row.status:SetPoint("TOPRIGHT", -12, -51)
        row.status:SetWidth(width - 180)
        row.join:ClearAllPoints()
        row.join:SetPoint("TOPLEFT", 12, -106)
        row.join:SetWidth(width - 70)
    end
end
function UI:LayoutLobbySlots()
    if not self.slotScroll then
        return
    end
    local width, height = self.lobbyPanel:GetWidth(), self.lobbyPanel:GetHeight()
    self.lobbyArt:ClearAllPoints()
    self.lobbyArt:SetPoint("TOPLEFT", 20, -20)
    self.lobbyTitle:ClearAllPoints()
    self.lobbyTitle:SetPoint("TOPLEFT", 132, -18)
    self.lobbyTitle:SetWidth(width - 330)
    self.selectedGame:ClearAllPoints()
    self.selectedGame:SetPoint("TOPLEFT", 132, -52)
    self.selectedGame:SetWidth(width - 320)
    self.lobbyInfo:ClearAllPoints()
    self.lobbyInfo:SetPoint("TOPLEFT", 132, -88)
    self.lobbyInfo:SetWidth(width - 160)
    self.lobbyInfo:SetHeight(28)
    self.gameInfo:Hide()
    self.players:Hide()
    self.lobbyBack:ClearAllPoints()
    self.lobbyBack:SetPoint("TOPRIGHT", -20, -20)
    self.slotScroll:ClearAllPoints()
    self.slotScroll:SetPoint("TOPLEFT", 20, -136)
    self.slotScroll:SetSize(width - 40, height - 292)
    local count = self.lobbySlotCount or 0
    local available = width - 58
    local columns = count <= 2 and math.max(1, count) or (available >= 660 and 3 or 2)
    local rows = math.max(1, math.ceil(count / columns))
    local cardWidth = (available - (columns - 1) * 14) / columns
    local cardHeight = math.max(
        count <= 2 and 190 or 112,
        math.min(count <= 2 and 240 or 136, (height - 292 - (rows - 1) * 14) / rows)
    )
    for i, slot in ipairs(self.lobbySlots) do
        local row = math.floor((i - 1) / columns)
        local inRow = math.min(columns, count - row * columns)
        local x = ((i - 1) % columns) * (cardWidth + 14) + (available - (inRow * cardWidth + (inRow - 1) * 14)) / 2
        slot:ClearAllPoints()
        slot:SetPoint("TOPLEFT", x, -row * (cardHeight + 14))
        slot:SetSize(cardWidth, cardHeight)
        slot.index:ClearAllPoints()
        slot.index:SetPoint("TOPRIGHT", -16, -14)
        slot.index:SetJustifyH("RIGHT")
        slot.index:SetFont(Theme.Fonts.display, count <= 2 and 32 or 22, "")
        slot.role:ClearAllPoints()
        slot.role:SetPoint("TOPLEFT", 16, -18)
        slot.name:ClearAllPoints()
        slot.name:SetPoint("TOPLEFT", 16, count <= 2 and -82 or -46)
        slot.name:SetWidth(cardWidth - 32)
        slot.name:SetHeight(26)
        slot.name:SetFont(Theme.Fonts.display, count <= 2 and 20 or 16, "")
        slot.state:ClearAllPoints()
        slot.state:SetPoint("TOPLEFT", 16, count <= 2 and -124 or -80)
        slot.state:SetWidth(cardWidth - 32)
        slot.state:SetJustifyH("LEFT")
    end
    self.slotArea:SetSize(available, math.max(height - 292, rows * (cardHeight + 14) - 14))
    self.lobbySummary:ClearAllPoints()
    self.lobbySummary:SetPoint("TOPLEFT", 20, -height + 132)
    self.lobbySummary:SetWidth(width - 360)
    self.countdownText:ClearAllPoints()
    self.countdownText:SetPoint("TOPRIGHT", -20, -height + 136)
    self.countdownText:SetWidth(310)
    self.hint:ClearAllPoints()
    self.hint:SetPoint("TOPLEFT", 20, -height + 96)
    self.hint:SetWidth(width - 40)
    self.hint:SetHeight(32)
    for _, entry in ipairs({
        { self.leave, 20, 160 },
        { self.endGame, 196, 160 },
        { self.announceLobby, 196, 176 },
        { self.ready, width - 196, 176 },
        { self.showGame, width - 196, 176 },
    }) do
        entry[1]:ClearAllPoints()
        entry[1]:SetPoint("TOPLEFT", entry[2], -height + 52)
        entry[1]:SetSize(entry[3], 32)
    end
end
function UI:RefreshLobbySlots(lobby)
    if not self.slotArea then
        return
    end
    local game = lobby and Games.Registry[lobby.gameID]
    self.lobbySlotCount = lobby and (game and game.maxPlayers or lobby.maxPlayers or Games.MAX_PLAYERS) or 0
    local ready = 0
    for i = 1, self.lobbySlotCount do
        local slot = self.lobbySlots[i]
        if not slot then
            slot = Theme:PremiumFrame(self.slotArea, 260, 120, 0, 0, { compact = true, skin = "card-frame" })
            slot.index = label(slot, tostring(i), 0, 0, 48)
            slot.name = label(slot, "", 16, -46, 220)
            slot.name:SetMaxLines(1)
            slot.role = label(slot, "", 16, -18, 160, "GameFontHighlightSmall")
            slot.role:SetTextColor(unpack(Theme.Colors.accent))
            slot.state = label(slot, "", 16, -80, 220)
            self.lobbySlots[i] = slot
        end
        local entry = lobby.members[i]
        if entry and entry.ready then
            ready = ready + 1
        end
        slot.name:SetText(entry and entry.name or "Open Slot")
        slot.role:SetText(
            entry and (entry.name == lobby.host and "HOST" or entry.name == Games:PlayerName() and "YOU" or "PLAYER")
                or "WAITING FOR PLAYER"
        )
        local state = entry
                and (lobby.status == "running" and "Playing" or lobby.gameID == "" and "Waiting" or entry.version ~= lobby.gameVersion and "Version mismatch" or entry.ready and "Ready" or "Not ready")
            or "Join this lobby to play"
        slot.state:SetText(state)
        slot.name:SetTextColor(unpack(entry and Theme.Colors.text or Theme.Colors.muted))
        slot.state:SetTextColor(unpack(state == "Ready" and Theme.Colors.success or Theme.Colors.muted))
        slot:SetBackdropBorderColor(unpack(entry and Theme.Colors.accent or Theme.Colors.border))
        slot:Show()
    end
    for i = self.lobbySlotCount + 1, #self.lobbySlots do
        self.lobbySlots[i]:Hide()
    end
    self.lobbySummary:SetText(
        lobby
                and string.format(
                    "%d/%d joined  /  %d/%d ready",
                    #lobby.members,
                    self.lobbySlotCount,
                    ready,
                    #lobby.members
                )
            or "Waiting for the host..."
    )
    if lobby then
        local state = lobby.status == "running" and "In Game" or lobby.status == "countdown" and "Starting" or "Waiting"
        self.lobbyInfo:SetText("Host: " .. lobby.host .. "  /  " .. state)
    end
    self.leave:SetText(lobby and "Leave Lobby" or "Cancel join")
    self:LayoutLobbySlots()
end
function UI:CreateMinimapButton()
    local map = CreateFrame("Button", "KICGamesMinimapButton", Minimap)
    map:SetSize(31, 31)
    map:SetFrameStrata("MEDIUM")
    map:SetNormalTexture("Interface\\Icons\\INV_Misc_Dice_01")
    map:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
    map:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    local ring = map:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(53, 53)
    ring:SetPoint("TOPLEFT")
    local function position()
        local angle = math.rad(Games.DB.minimapAngle)
        map:ClearAllPoints()
        map:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 82, math.sin(angle) * 82)
    end
    map:RegisterForDrag("LeftButton")
    map:SetScript("OnDragStart", function()
        map:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            Games.DB.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
            position()
        end)
    end)
    local function stopDrag()
        map:SetScript("OnUpdate", nil)
    end
    map:SetScript("OnDragStop", stopDrag)
    map:SetScript("OnHide", stopDrag)
    map:SetScript("OnClick", function()
        UI:Toggle()
    end)
    map:SetScript("OnEnter", function()
        GameTooltip:SetOwner(map, "ANCHOR_LEFT")
        GameTooltip:AddLine("KIC-Games", unpack(GOLD))
        GameTooltip:AddLine("Click: open launcher", 1, 1, 1)
        GameTooltip:AddLine("Drag: move minimap button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    map:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    position()
    self.minimap = map
end
