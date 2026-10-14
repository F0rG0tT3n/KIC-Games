local _, Games = ...
local UI = { gameRows = {}, listingRows = {} }
Games.UI = UI
local Theme = Games.Theme
local GOLD = Theme.Colors.accent

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
    local frame = panel(UIParent, 900, 630, 0, 0)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    Theme:Window(frame)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
        UI:HideAuxiliaryWindows()
    end)
    frame:Hide()
    _G.KICGamesWindow = frame
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesWindow"
    self.frame = frame
    local title = label(frame, "KIC / GAMES", 22, -18, 400, "GameFontNormalLarge")
    title:SetTextColor(unpack(GOLD))
    label(frame, "A little play between adventures", 22, -47, 490, "GameFontHighlightSmall")
    Theme:CloseButton(frame)
    self.homeButton = button(frame, "Launcher", 100, 742, -34, function()
        UI:ShowHome()
    end)
    self.homeButton:Hide()
    self.resultsButton = button(frame, "Results", 90, 536, -34, function()
        UI:ShowResults()
    end)
    self.abortButton = button(frame, "|cffff6060Stop match|r", 110, 628, -34, function()
        Games:AbortGame()
    end)
    self.abortButton:Hide()
    self.home = CreateFrame("Frame", nil, frame)
    self.home:SetAllPoints()
    self.tab = Games.DB.launcherTab == "singleplayer" and "singleplayer" or "multiplayer"
    self.singleTab = button(self.home, "Singleplayer", 165, 20, -80, function()
        UI:SelectTab("singleplayer")
    end)
    self.multiTab = button(self.home, "Multiplayer", 165, 190, -80, function()
        UI:SelectTab("multiplayer")
    end)

    local library = panel(self.home, 355, 252, 20, -120)
    self.libraryPanel = library
    self.libraryTitle = label(library, "MULTIPLAYER GAMES", 14, -14, 290, "GameFontNormal")
    self.library, self.libraryScroll = scroll(library, 303, 199, 14, -40)
    self.emptyGames = label(
        self.library,
        "Your game library is empty.\n\nKIC-Games is the launcher and multiplayer framework. Games will appear here when their modules are installed.\n\nYou can already create a lobby and invite party members to join it.",
        0,
        0,
        292
    )

    local browser = panel(self.home, 355, 186, 20, -384)
    self.browserPanel = browser
    label(browser, "PARTY LOBBIES", 14, -14, 205, "GameFontNormal")
    button(browser, "Refresh", 90, 248, -9, function()
        Games:Discover()
    end)
    self.browser = scroll(browser, 303, 126, 14, -44)
    self.emptyLobbies =
        label(self.browser, "No lobbies found.\n\nCreate one, or ask a party member with KIC-Games to host.", 0, 0, 290)

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
    self.countdownText = label(lobbyPanel, "", 16, -308, 450, "GameFontNormalLarge")
    self.countdownText:SetJustifyH("CENTER")
    self.hint = label(lobbyPanel, "", 16, -340, 450, "GameFontHighlightSmall")
    self.create = button(
        lobbyPanel,
        "Host game",
        135,
        16,
        -393,
        action(function()
            return Games:CreateLobby(UI.selectedMulti)
        end)
    )
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
    label(self.singlePanel, "PLAY SOLO", 16, -14, 450, "GameFontNormal")
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
    self.footer = label(frame, "", 22, -591, 850, "GameFontHighlightSmall")
    self.gameContainer = panel(frame, 860, 450, 20, -80)
    self.gameContainer:Hide()
    self:CreateResultsWindow()
    self:CreateMinimapButton()
    frame:SetScript("OnUpdate", function()
        UI:UpdateCountdown()
    end)
    self:Refresh()
end

function UI:SelectTab(mode)
    if mode ~= "singleplayer" and mode ~= "multiplayer" then
        return
    end
    local changed = self.tab ~= mode
    if changed then
        self:HideAuxiliaryWindows()
    end
    self.tab, Games.DB.launcherTab = mode, mode
    self:Refresh()
    if changed and mode == "multiplayer" then
        Games:Discover()
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

function UI:CreateResultsWindow()
    local frame = panel(UIParent, 640, 470, 0, 0)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    Theme:Window(frame, true)
    _G.KICGamesResultsWindow = frame
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesResultsWindow"
    label(frame, "Match history", 24, -22, 540, "GameFontNormalLarge")
    label(frame, "Last 20 matches. Interrupted matches never count as a loss.", 20, -48, 580, "GameFontHighlightSmall")
    Theme:CloseButton(frame)
    self.resultSummary = label(frame, "", 20, -76, 580)
    self.resultList = scroll(frame, 571, 323, 20, -116)
    self.resultText = label(self.resultList, "", 0, 0, 560)
    self.resultText:SetSpacing(4)
    frame:Hide()
    self.resultsFrame = frame
end

function UI:ShowResults()
    self:HideAuxiliaryWindows()
    self:RefreshResults()
    self.resultsFrame:Show()
    self.resultsFrame:Raise()
end

function UI:RefreshResults()
    if not self.resultsFrame then
        return
    end
    local stats, lines = Games:GetResultStats(), {}
    self.resultSummary:SetText(
        string.format(
            "Completed: %d | Interrupted: %d | Wins: %d | Losses: %d | Draws: %d",
            stats.completed,
            stats.aborted,
            stats.wins,
            stats.losses,
            stats.draws
        )
    )
    for _, result in ipairs(Games:GetResults()) do
        local game = Games.Registry[result.gameID]
        lines[#lines + 1] = (game and game.title or result.gameID)
            .. " - "
            .. (result.status == "aborted" and "Interrupted" or "Completed")
            .. " (round "
            .. result.run
            .. ")"
        lines[#lines + 1] = result.summary
        if result.status == "aborted" then
            lines[#lines + 1] = "Reason: " .. result.reason .. (result.abortedBy and (" / " .. result.abortedBy) or "")
        end
        for _, entry in ipairs(result.entries) do
            local detail = (entry.rank and ("#" .. entry.rank .. "  ") or "") .. entry.player
            if entry.score ~= nil then
                detail = detail .. "  |  " .. tostring(entry.score)
            end
            if entry.outcome then
                detail = detail .. "  |  " .. entry.outcome
            end
            lines[#lines + 1] = detail
        end
        lines[#lines + 1] = " "
    end
    self.resultText:SetText(#lines > 0 and table.concat(lines, "\n") or "No matches yet.")
    self.resultList:SetHeight(math.max(310, self.resultText:GetStringHeight() + 8))
end

function UI:GetGameContainer()
    return self.gameContainer
end

function UI:ShowHome()
    self:HideAuxiliaryWindows()
    self.home:Show()
    self.gameContainer:Hide()
    self.homeButton:Hide()
    self:Refresh()
end

function UI:ShowGame()
    if not Games.ActiveGame then
        return
    end
    self:HideAuxiliaryWindows()
    self.home:Hide()
    self.gameContainer:Show()
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
    if not Games.ActiveGame and self.gameContainer:IsShown() then
        self:ShowHome()
        return
    end
    local games = Games:GetGames(self.tab)
    local soloGames, multiGames = Games:GetGames("singleplayer"), Games:GetGames("multiplayer")
    self.singleTab:SetText("Singleplayer (" .. #soloGames .. ")")
    self.multiTab:SetText("Multiplayer (" .. #multiGames .. ")")
    enable(self.singleTab, self.tab ~= "singleplayer")
    enable(self.multiTab, self.tab ~= "multiplayer")
    Theme:Select(self.singleTab, self.tab == "singleplayer")
    Theme:Select(self.multiTab, self.tab == "multiplayer")
    self.browserPanel:SetShown(self.tab == "multiplayer")
    self.lobbyPanel:SetShown(self.tab == "multiplayer")
    self.singlePanel:SetShown(self.tab == "singleplayer")
    self.libraryPanel:SetHeight(self.tab == "singleplayer" and 450 or 252)
    self.libraryScroll:SetHeight(self.tab == "singleplayer" and 397 or 199)
    self.libraryTitle:SetText(self.tab == "singleplayer" and "SINGLEPLAYER GAMES" or "MULTIPLAYER GAMES")
    self.emptyGames:SetText(
        self.tab == "singleplayer" and "No singleplayer games installed yet.\n\nInstalled solo games will appear here."
            or "No multiplayer games installed yet.\n\nInstalled party games will appear here."
    )
    if not Games.Registry[self.selectedSolo] then
        self.selectedSolo = soloGames[1] and soloGames[1].id
    end
    if not Games.Registry[self.selectedMulti] then
        self.selectedMulti = multiGames[1] and multiGames[1].id
    end
    self.emptyGames:SetShown(#games == 0)
    for _, row in ipairs(self.gameRows) do
        row:Hide()
    end
    for i, game in ipairs(games) do
        local row = self.gameRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.library, "BackdropTemplate")
            row:SetSize(301, 62)
            Theme:StyleButton(row)
            row.title = label(row, "", 6, -5, 288, "GameFontNormal")
            row.detail = label(row, "", 6, -28, 288, "GameFontHighlightSmall")
            row.title:SetHeight(18)
            row.detail:SetHeight(32)
            self.gameRows[i] = row
        end
        local registeredID = game.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 68)
        row.title:SetText(game.title)
        local selectedID = self.tab == "singleplayer" and self.selectedSolo or self.selectedMulti
        Theme:Select(row, game.id == selectedID)
        if game.id == selectedID then
            row.title:SetTextColor(unpack(GOLD))
        else
            row.title:SetTextColor(0.8, 0.8, 0.8)
        end
        row.detail:SetText(
            game.mode == "singleplayer" and "Solo game / Play at your pace"
                or string.format("Party game / %d-%d players", game.minPlayers, game.maxPlayers)
        )
        row:SetScript(
            "OnClick",
            action(function()
                if UI.tab == "singleplayer" then
                    UI.selectedSolo = registeredID
                    UI:Refresh()
                    return true
                end
                UI.selectedMulti = registeredID
                if Games:IsHost() and Games.Lobby.mode == "multiplayer" then
                    return Games:SelectGame(registeredID)
                end
                UI:Refresh()
                return true
            end)
        )
        enable(
            row,
            self.tab == "singleplayer"
                or not Games.Lobby
                or (Games:IsHost() and Games.Lobby.mode == "multiplayer" and Games.Lobby.status ~= "running")
        )
        row:Show()
    end
    self.library:SetHeight(math.max(185, #games * 68))

    local listings = {}
    for host, listing in pairs(Games.Listings) do
        listings[#listings + 1] = listing
    end
    table.sort(listings, function(a, b)
        return a.host < b.host
    end)
    self.emptyLobbies:SetShown(#listings == 0)
    for _, row in ipairs(self.listingRows) do
        row:Hide()
    end
    for i, listing in ipairs(listings) do
        local row = self.listingRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.browser, "BackdropTemplate")
            row:SetSize(301, 56)
            Theme:StyleButton(row)
            row.title = label(row, "", 6, -3, 290, "GameFontNormal")
            row.detail = label(row, "", 6, -24, 290, "GameFontHighlightSmall")
            row.title:SetHeight(18)
            row.detail:SetHeight(30)
            self.listingRows[i] = row
        end
        local host, id = listing.host, listing.id
        local game = Games.Registry[listing.gameID]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 60)
        row.title:SetText(
            (game and game.title or (listing.gameTitle ~= "" and listing.gameTitle or "Choosing a game"))
                .. "  "
                .. listing.count
                .. "/"
                .. listing.max
        )
        row.detail:SetText(
            string.format(
                "Host: %s\n%s",
                host,
                listing.status == "countdown" and "Starting - click to join"
                    or (
                        listing.status == "running" and (listing.rejoin and "Click to rejoin" or "Game in progress")
                        or "Waiting - click to join"
                    )
            )
        )
        row:SetScript(
            "OnClick",
            action(function()
                if Games.Lobby and Games.Lobby.host == host and Games.Lobby.id == id then
                    return true
                end
                return Games:JoinLobby(host, id)
            end)
        )
        local joined = Games.Lobby and Games.Lobby.host == host and Games.Lobby.id == id
        enable(
            row,
            joined
                or (
                    not Games.Lobby
                    and not Games.Pending
                    and (listing.status ~= "running" or listing.rejoin)
                    and (listing.count < listing.max or listing.rejoin)
                )
        )
        row:Show()
    end
    self.browser:SetHeight(math.max(112, #listings * 60))

    local current, pending = Games.Lobby, Games.Pending
    local lobby = current and current.mode == "multiplayer" and current or nil
    local running = lobby and lobby.status == "running"
    local counting = lobby and lobby.status == "countdown"
    local interrupted = (running or counting) and Games:IsRoundStopped()
    self.abortButton:SetShown(
        current and (current.status == "running" or current.status == "countdown") and not Games:IsRoundStopped()
    )
    self:UpdateCountdown()
    self:RefreshSingleplayer()
    self:RefreshResults()
    self.create:SetShown(not lobby)
    enable(self.create, Games:GroupChannel() ~= nil and not current and not pending and self.selectedMulti ~= nil)
    self.leave:SetShown(lobby ~= nil or pending ~= nil)
    if pending then
        self.create:Hide()
    end
    self.ready:SetShown(lobby ~= nil and not running)
    self.start:SetShown(lobby ~= nil and not running and not counting)
    self.showGame:SetShown(running and Games.ActiveGame ~= nil)
    self.endGame:SetShown((running or counting) and not interrupted)
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
        local lines = {}
        for _, entry in ipairs(lobby.members) do
            local state = lobby.gameID == "" and "Waiting"
                or (
                    entry.version ~= lobby.gameVersion and "Missing / different game version"
                    or (entry.ready and "|cff70db88Ready|r" or "Not ready")
                )
            if running then
                state = "Playing"
            end
            lines[#lines + 1] = entry.name .. (entry.name == lobby.host and " (host)" or "") .. "  -  " .. state
        end
        self.players:SetText(table.concat(lines, "\n"))
        local own = Games:LocalMember()
        self.ready:SetText((counting or (own and own.ready)) and "Not ready" or "Ready")
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
        local selected = Games.Registry[self.selectedMulti]
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
                    and "A solo game is active. Use Singleplayer to reopen it, or Stop match to finish it."
                or (
                    Games:GroupChannel() and "Ready to create or join a lobby."
                    or "Join a WoW party to use multiplayer lobbies."
                )
        )
    end
    self.footer:SetText(
        string.format(
            "KIC-Games %s  |  %d installed game(s)  |  %s",
            Games.VERSION,
            #games,
            Games:GroupChannel() and "Group connected" or "No group"
        )
    )
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
    map:SetScript("OnDragStop", function()
        map:SetScript("OnUpdate", nil)
    end)
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
