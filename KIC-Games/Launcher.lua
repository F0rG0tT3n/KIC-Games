local addonName, Games = ...
local UI, Theme = Games.UI, Games.Theme
local library = {
    ["2048"] = {
        hero = "2048-hero",
        card = "2048-card",
        summary = "Slide equal tiles together, build your score, and reach 2048. Drag or use the arrow keys.",
    },
    minesweeper = {
        hero = "minesweeper-hero",
        card = "minesweeper-card",
        summary = "Reveal safe tiles, flag hidden mines, and beat your best time.",
    },
    blindshot = {
        hero = "blindshot-hero",
        card = "blindshot-card",
        summary = "Aim in secret, fire in random order, and outlast the party.",
    },
    chess = {
        hero = "chess-hero",
        card = "chess-card",
        summary = "Challenge a friend to a two-player chess match. No clocks or AI.",
    },
    bejeweled = {
        hero = "bejeweled-hero",
        card = "bejeweled-card",
        summary = "Match class icons, trigger cascades, and chase your high score.",
    },
    kic_bejeweled = {
        hero = "kic-bejeweled-hero",
        card = "kic-bejeweled-card",
        summary = "Match gems, unleash power combos, or brave a Roguelike run.",
    },
    tetris = {
        hero = "tetris-hero",
        card = "tetris-card",
        summary = "Stack colorful blocks, clear lines, and beat your high score.",
    },
}
local function place(frame, parent, x, y, width, height)
    if parent then
        frame:SetParent(parent)
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", x, y)
    if width and height then
        frame:SetSize(width, height)
    elseif width then
        frame:SetWidth(width)
    end
end
local function invoke(fn)
    return function()
        local ok, err = fn()
        if ok == false and err then
            Games:Notify(err)
        end
    end
end
local pages = { home = true, singleplayer = true, multiplayer = true, results = true, options = true }
function UI:OpenLauncher(page, browse)
    page = pages[page] and page or "home"
    if page == "multiplayer" then
        local joined = Games.Lobby and Games.Lobby.mode == "multiplayer" or Games.Pending
        self.multiplayerView = joined and not browse and "lobby" or "browser"
    end
    local changed = self.launcherPage ~= page
    if page == "home" and changed then
        self.featureRollPending = true
    end
    self.launcherPage, Games.DB.launcherPage = page, page
    if page == "singleplayer" or page == "multiplayer" then
        self.tab, Games.DB.launcherTab = page, page
    end
    if changed and self.cardScroll then
        self.cardScroll:SetVerticalScroll(0)
    end
    self:ShowHome()
    self.frame:Show()
    if changed and page == "multiplayer" then
        Games:Discover()
    end
end
function UI:SelectMultiplayer(id)
    if not Games.Registry[id] or Games.Registry[id].mode ~= "multiplayer" then
        return false
    end
    -- Highlighting a browser card never changes a joined session.
    self.selectedMulti = id
    self:Refresh()
    return true
end
function UI:FeatureGame(id)
    local game = Games.Registry[id]
    if not game then
        return false
    end
    if game.mode == "multiplayer" then
        local ok, err = self:SelectMultiplayer(id)
        if ok == false then
            return ok, err
        end
    else
        self.selectedSolo = id
    end
    self.featuredID = id
    self:Refresh()
    return true
end
function UI:FeatureEligible(game)
    return type(game) == "table"
        and Games.Registry[game.id] == game
        and (game.mode == "singleplayer" or game.mode == "multiplayer")
        and type(game.OnStart) == "function"
        and type(game.CreateUI) == "function"
end
function UI:FeaturedActiveGame()
    local active = Games.ActiveGame
    if not active or not active.frame or not self:FeatureEligible(active.game) or Games:IsRoundStopped() then
        return nil
    end
    local lobby = Games.Lobby
    if lobby and (lobby.status ~= "running" or lobby.gameID ~= active.game.id or not Games:Compatible(lobby)) then
        return nil
    end
    -- ActiveGame is created by the real lifecycle (including local practice),
    -- never inferred from saved records or an unstarted multiplayer lobby.
    return active
end
function UI:SelectHomeFeature()
    local active = self:FeaturedActiveGame()
    if active then
        self.featuredID = active.game.id
    elseif
        self.featureRollPending
        or self.featureWasActive
        or not self:FeatureEligible(Games.Registry[self.featuredID])
    then
        local eligible = {}
        for _, game in ipairs(Games:GetGames()) do
            if self:FeatureEligible(game) then
                eligible[#eligible + 1] = game
            end
        end
        local selected = #eligible > 0 and eligible[math.random(#eligible)] or nil
        self.featuredID = selected and selected.id
    end
    self.featureRollPending, self.featureWasActive = nil, active ~= nil
    return Games.Registry[self.featuredID], active
end
function UI:LaunchGame(id)
    local game = Games.Registry[id]
    if not game then
        return false, "This game is no longer installed."
    end
    if Games.ActiveGame and Games.ActiveGame.game.id == id then
        self:ShowGame()
        return true
    end
    if game.mode == "multiplayer" then
        local ok, err = self:SelectMultiplayer(id)
        if ok == false then
            return ok, err
        end
        self:OpenLauncher("multiplayer", true)
        return true
    end
    self.selectedSolo = id
    return Games:StartSingleplayer(id)
end
function UI:CanLaunch(game)
    if not game then
        return false
    end
    if Games.ActiveGame and Games.ActiveGame.game.id == game.id then
        return true
    end
    if game.mode == "multiplayer" then
        return true
    end
    return not Games.Pending
        and (not Games.Lobby or Games.Lobby.mode == "singleplayer" and Games.Lobby.status == "waiting")
end
function UI:InitializeLauncher()
    local saved = Games.DB.launcherPage or Games.DB.launcherTab
    self.launcherPage = pages[saved] and saved or "home"
    self.launcherCards, self.recentPage = {}, 1
    self.content = CreateFrame("Frame", nil, self.home)
    self.content:SetPoint("TOPLEFT", 222, -96)
    self.content:SetSize(882, 548)
    self.multiplayerPage = CreateFrame("Frame", nil, self.content)
    self.multiplayerPage:SetAllPoints(self.content)
    self.hallArt = Theme:Art(self.home, "hall", 1088, 562, 16, -82, 0.13)
    self.sidebar = Theme:PremiumFrame(self.home, 188, 548, 18, -96)
    self.sidebarCrest = Theme:Art(self.sidebar, "crest", 142, 142, 23, -325, 0.09, "ARTWORK")
    self.sidebarArt = Theme:Art(self.sidebar, "sidebar", 186, 265, 1, -282, 0.48)
    self.nav = {}
    for i, entry in ipairs({
        { "home", "Home" },
        { "singleplayer", "Singleplayer", self.singleTab },
        { "multiplayer", "Multiplayer", self.multiTab },
        { "results", "Results" },
        { "options", "Options" },
    }) do
        local id = entry[1]
        self.nav[id] = Theme:NavigationButton(self.sidebar, "nav-" .. id, entry[2], 8, -18 - (i - 1) * 54, function()
            self:OpenLauncher(id)
        end, entry[3])
    end
    -- The old text library is replaced by the shared card grid. Lobby actions stay native.
    place(self.browserPanel, self.multiplayerPage, 0, -284, 340, 264)
    place(self.browser:GetParent(), nil, 14, -44, 312, 204)
    place(self.lobbyPanel, self.multiplayerPage, 356, 0, 526, 548)
    Theme:StylePremiumFrame(self.browserPanel, "status-frame")
    Theme:StylePremiumFrame(self.lobbyPanel, "status-frame")
    self.browserTitle:Hide()
    self.browserHeading = Theme:SectionHeader(self.browserPanel, "PARTY LOBBIES", 212, 14, -14, 14)
    self.lobbyTitle:Hide()
    self.lobbyTitle = Theme:SectionHeader(self.lobbyPanel, "YOUR LOBBY", 494, 16, -14, 16)
    self.resumeLobby = Theme:NeonButton(self.browserPanel, "Resume Lobby", 156, 0, 0, function()
        self:OpenLauncher("multiplayer")
    end, 32, true)
    self.lobbyBack = Theme:NeonButton(self.lobbyPanel, "Back to Games", 140, 0, 0, function()
        self:OpenLauncher("multiplayer", true)
    end, 32)
    self.announceLobby = Theme:NeonButton(
        self.lobbyPanel,
        "Announce Lobby",
        176,
        0,
        0,
        invoke(function()
            return Games:AnnounceLobby()
        end),
        32
    )
    self.lobbyArt = Theme:Art(self.lobbyPanel, "generic-card", 96, 64, 20, -20, 1, "ARTWORK")
    self.lobbySummary = Theme:Label(self.lobbyPanel, "", 20, -416, 400)
    self.slotArea, self.slotScroll = Theme:Scroll(self.lobbyPanel, 842, 256, 20, -136)
    for _, b in ipairs({
        self.leave,
        self.ready,
        self.start,
        self.showGame,
        self.endGame,
        self.browserRefresh,
        self.optionsButton,
        self.resultsButton,
        self.homeButton,
        self.abortButton,
        self.continueButton,
    }) do
        Theme:StyleNeonButton(b)
    end
    self.hero = self.singlePanel
    self.soloSection:Hide()
    place(self.hero, self.content, 0, 0, 882, 256)
    -- Artwork surfaces have no opaque native Center at all. Only an edge-only
    -- backdrop and OVERLAY ornaments can overlap the explicit ARTWORK stack.
    Theme:StylePremiumFrame(self.hero, "window-frame", { artwork = true })
    -- All wordmarks are baked into the left side of the hero art.
    -- Use a soft bottom fade only: never cover the wordmark with a half-screen rectangle.
    self.heroArt = Theme:Art(self.hero, "bejeweled-hero", 880, 254, 1, -1, 1, "ARTWORK")
    self.heroShade = self.hero:CreateTexture(nil, "ARTWORK", nil, 1)
    self.heroShade:SetTexture(Games.Artwork["hero-footer-fade"].file)
    self.heroShade:SetTexCoord(0, 1, 0, 1)
    self.heroShade:SetBlendMode("BLEND")
    self.heroShade:SetPoint("TOPLEFT", 1, -1)
    self.heroShade:SetSize(880, 254)
    self.heroFallback = self.hero:CreateTexture(nil, "ARTWORK", nil, 2)
    self.heroFallback:SetSize(112, 112)
    self.heroFallback:SetPoint("TOPRIGHT", -52, -68)
    -- The featured game's wordmark lives in the hero TGA, not in a UI font.
    -- Keep the reusable native title only as a fallback for missing artwork.
    self.soloTitle:SetFont("Fonts\\ARIALN.TTF", 32, "")
    self.soloDescription:SetFont("Fonts\\ARIALN.TTF", 17, "")
    self.soloDescription:SetShadowColor(0, 0, 0, 0.95)
    self.soloDescription:SetShadowOffset(1, -1)
    Theme:Primary(self.soloPlay)
    Theme:Primary(self.soloOpen)
    self.soloPlay.caption:SetFont("Fonts\\ARIALN.TTF", 18, "")
    self.soloOpen.caption:SetFont("Fonts\\ARIALN.TTF", 18, "")
    self.soloOpen:SetText("Continue Game")
    self.soloPlay:SetScript(
        "OnClick",
        invoke(function()
            return self:LaunchGame(self.featuredID)
        end)
    )
    self.soloOpen:SetScript(
        "OnClick",
        invoke(function()
            if self:FeaturedActiveGame() then
                self:ShowGame()
                return true
            end
            self:Refresh()
            return false, "This game has ended."
        end)
    )
    self.soloHint:Hide()
    self.soloLeave:SetText("Leave lobby")
    self.installedTitle = Theme:SectionHeader(self.content, "RECENT GAMES", 650, 0, -274, 18)
    self.pageTitle = Theme:SectionHeader(self.content, "", 600, 0, -6, 22)
    self.pageSubtitle = Theme:Label(self.content, "", 0, -36, 700, "GameFontHighlightSmall")
    self.cardList, self.cardScroll = Theme:Scroll(self.content, 882, 238, 0, -310)
    self.noGames = Theme:Label(self.cardList, "", 24, -24, 650, "GameFontNormalLarge")
    self.noGames:SetHeight(56)
    self.emptyDetail = Theme:Label(self.cardList, "", 24, -92, 650)
    self.emptyDetail:SetHeight(56)
    self.browseGames = Theme:Button(self.cardList, "Browse installed games", 224, 24, -166, function()
        self:OpenLauncher("singleplayer")
    end, 36)
    Theme:Primary(self.browseGames)
    self.recentPrevious = Theme:NeonButton(self.content, "Prev", 60, 0, 0, function()
        self.recentPage = self.recentPage - 1
        self:RefreshLauncher()
    end)
    self.recentNext = Theme:NeonButton(self.content, "Next", 60, 0, 0, function()
        self.recentPage = self.recentPage + 1
        self:RefreshLauncher()
    end)
    self.recentIndicator = Theme:Label(self.content, "", 0, 0, 70, "GameFontHighlightSmall")
    self.recentIndicator:SetJustifyH("CENTER")
    self.pageBack = Theme:NeonButton(self.content, "Back to game", 140, 0, 0, function()
        self:ShowGame()
    end)
    self.pageBack:SetFrameLevel(self.content:GetFrameLevel() + 5)
    self.groupPanel = Theme:StatusPanel(self.frame, 264, 54, 796, -18)
    self.groupStatus, self.groupDetail = self.groupPanel.title, self.groupPanel.detail
    self.launcherMotto =
        Theme:Label(self.frame, "Games today. Raids tomorrow.", 810, -669, 220, "GameFontHighlightSmall")
    self.launcherMotto:SetTextColor(unpack(Theme.Colors.accent))
    self.frame:SetScript("OnSizeChanged", function()
        self:LayoutLauncher()
    end)
end
function UI:LayoutLauncher()
    if not self.content or self.layingOut then
        return
    end
    self.layingOut = true
    local width, height = self.frame:GetWidth(), self.frame:GetHeight()
    self.content:SetSize(width - 238, height - 152)
    self.sidebar:SetHeight(height - 152)
    self.hallArt:SetSize(width - 32, height - 138)
    Theme:SetArt(self.hallArt, "hall", width - 32, height - 138, 0.13)
    place(self.sidebarArt, nil, 1, -(height - 152 - 265), 186, 265)
    place(self.sidebarCrest, nil, 23, -(height - 152 - 223), 142, 142)
    place(self.groupPanel, nil, width - 324, -18)
    self.footer:ClearAllPoints()
    self.footer:SetPoint("BOTTOMLEFT", 22, 17)
    self.footer:SetWidth(width - 310)
    self.launcherMotto:ClearAllPoints()
    self.launcherMotto:SetPoint("BOTTOMRIGHT", -90, 17)
    self.launcherMotto:SetWidth(220)
    self:LayoutGameContainer()
    place(self.optionsButton, nil, width - 526, -30, 80, 28)
    place(self.resultsButton, nil, width - 438, -30, 80, 28)
    Theme:PlaceGameButton(self.homeButton, width - 522, 26, 182, 36)
    self.homeButton:SetText("Back to Launcher")
    if self.optionsFrame then
        self:LayoutOptions()
    end
    if self.resultsFrame then
        self:LayoutResults()
    end
    self.layingOut = false
    self:RefreshLauncher()
end
function UI:RefreshLauncherStatus()
    if not self.groupStatus then
        return
    end
    local channel = Games:GroupChannel()
    local count = 0
    if channel then
        for _ in pairs(Games:Roster()) do
            count = count + 1
        end
    end
    self.groupPanel:SetStatus(
        channel and (IsInRaid() and "Raid connected" or "Party connected") or "No group",
        channel
                and (string.format(
                    "%d member%s / %s",
                    count,
                    count == 1 and "" or "s",
                    channel == "INSTANCE_CHAT" and "Instance group" or "Ready for party games"
                ))
            or "Solo play mode",
        channel ~= nil
    )
    self.footer:SetText(
        string.format(
            "KIC-Games %s   |   %d installed game(s)   |   %s",
            Games.VERSION,
            #Games:GetGames(),
            channel and "Group connected" or "No group"
        )
    )
end
function UI:RefreshLauncher()
    if not self.content then
        return
    end
    local inGame = self.gameContainer:IsShown()
    local home, multi = self.launcherPage == "home", self.launcherPage == "multiplayer"
    local inLobby = multi
        and self.multiplayerView == "lobby"
        and (Games.Lobby and Games.Lobby.mode == "multiplayer" or Games.Pending) ~= nil
    local libraryPage = self.launcherPage == "singleplayer" or multi and not inLobby
    local settingsPage = self.launcherPage == "options"
    local resultsPage = self.launcherPage == "results"
    local width, height = self.content:GetWidth(), self.content:GetHeight()
    self.optionsButton:Hide()
    self.resultsButton:Hide()
    if inGame then
        self.abortButton:Hide()
    end
    place(self.abortButton, nil, self.frame:GetWidth() - (inGame and 350 or 452), -30, 110, 28)
    place(self.continueButton, nil, self.frame:GetWidth() - 596, -30, 136, 28)
    local activeID = Games.ActiveGame and Games.ActiveGame.game.id
    local activeModule = activeID == "tetris" and Games.Tetris
        or activeID == "bejeweled" and Games.Bejeweled
        or activeID == "kic_bejeweled" and Games.KICBejeweled
    self.continueButton:SetShown(
        not inGame and activeModule and activeModule.running and activeModule.paused and not Games:IsRoundStopped()
    )
    self.groupPanel:Show()
    self.launcherMotto:SetShown(not inGame)
    self.hero:SetShown(home)
    self.multiplayerPage:SetShown(multi)
    self.browserPanel:SetShown(multi and not inLobby)
    self.lobbyPanel:SetShown(inLobby == true)
    self.resumeLobby:SetShown(
        multi and not inLobby and (Games.Lobby and Games.Lobby.mode == "multiplayer" or Games.Pending) ~= nil
    )
    if multi then
        if inLobby then
            place(self.lobbyPanel, nil, 0, 0, width, height)
            local pendingListing = Games.Pending and Games.Listings[Games.Pending.host]
            local game =
                Games.Registry[Games.Lobby and Games.Lobby.gameID or pendingListing and pendingListing.gameID or self.selectedMulti]
            local art = game and library[game.id]
            Theme:SetArt(self.lobbyArt, art and art.card or "generic-card", 96, 64, 1)
            if not art and game then
                self.lobbyArt:SetTexture(game.icon or "Interface\\Icons\\INV_Misc_Dice_01")
            end
            self:LayoutLobbySlots()
        end
    end
    self.installedTitle:SetShown(home)
    self.cardScroll:SetShown(home or libraryPage)
    self.pageTitle:SetShown(libraryPage)
    self.pageSubtitle:SetShown(libraryPage)
    if self.optionsFrame then
        self.optionsFrame:SetShown(settingsPage and not inGame)
    end
    if self.resultsFrame then
        self.resultsFrame:SetShown(resultsPage and not inGame)
    end
    self.pageBack:SetShown(not inGame and (settingsPage or resultsPage) and Games.ActiveGame ~= nil)
    place(self.pageBack, nil, width - 158, -4, 140, 28)
    self.singleTab:SetText("Singleplayer")
    self.multiTab:SetText("Multiplayer")
    for name, b in pairs(self.nav) do
        b:Enable()
        Theme:Select(b, name == self.launcherPage)
    end
    self:RefreshLauncherStatus()
    if settingsPage and self.optionsFrame then
        self:RefreshOptions()
    end
    if resultsPage and self.resultsFrame then
        self:RefreshResults()
    end
    self.recentPrevious:Hide()
    self.recentNext:Hide()
    self.recentIndicator:Hide()
    if not home and not libraryPage then
        return
    end
    local gridWidth, gridHeight, gridY = width, height - 66, -66
    if home then
        gridHeight, gridY = height - 310, -310
        place(self.hero, nil, 0, 0, width, 256)
        self.heroArt:SetSize(width - 2, 254)
        self:RefreshFeature(width)
    elseif multi then
        local sidebarWidth = math.max(260, math.floor((width - 16) * 0.35))
        gridWidth, gridHeight, gridY = width - sidebarWidth - 16, height - 66, -66
        place(self.browserPanel, nil, gridWidth + 16, 0, sidebarWidth, height)
        self:LayoutPartyLobbies(sidebarWidth, height)
        place(self.resumeLobby, nil, 14, -46, sidebarWidth - 28, 30)
        if self.resumeLobby:IsShown() then
            place(self.browser:GetParent(), nil, 14, -88, sidebarWidth - 28, height - 102)
        end
    end
    place(self.cardScroll, nil, 0, gridY, gridWidth, gridHeight)
    local available = gridWidth - 18
    self.cardList:SetWidth(available)
    local games = home and Games:GetRecentGames() or Games:GetGames(multi and "multiplayer" or "singleplayer")
    local columns = math.max(1, math.floor((available + 14) / 270))
    if home then
        columns = math.min(3, columns)
    end
    if multi then
        columns = available >= 514 and 2 or 1
    end
    self.cardColumns = columns
    local pagesCount = math.max(1, math.ceil(#games / columns))
    self.recentPage = math.max(1, math.min(self.recentPage, pagesCount))
    local first = home and (self.recentPage - 1) * columns + 1 or 1
    local last = home and math.min(#games, first + columns - 1) or #games
    local cardWidth = (available - (columns - 1) * 14) / columns
    self.installedTitle:SetText("RECENT GAMES")
    self.installedTitle:SetWidth(width - 232)
    self.pageTitle:SetText(multi and "MULTIPLAYER" or "SINGLEPLAYER")
    self.pageTitle:SetWidth(gridWidth)
    self.pageSubtitle:SetWidth(gridWidth)
    self.pageSubtitle:SetText(
        multi and "Host or join games with your party"
            or string.format("%d installed game(s) / %s", #games, "Play at your own pace")
    )
    if home then
        self.cardScroll:SetVerticalScroll(0)
        place(self.recentPrevious, nil, width - 212, -270, 60, 28)
        place(self.recentIndicator, nil, width - 146, -278, 70)
        place(self.recentNext, nil, width - 70, -270, 60, 28)
        local carousel = #games > columns
        self.recentPrevious:SetShown(carousel)
        self.recentNext:SetShown(carousel)
        self.recentIndicator:SetShown(carousel)
        self.recentIndicator:SetText(string.format("%d / %d", self.recentPage, pagesCount))
        if self.recentPage > 1 then
            self.recentPrevious:Enable()
        else
            self.recentPrevious:Disable()
        end
        if self.recentPage < pagesCount then
            self.recentNext:Enable()
        else
            self.recentNext:Disable()
        end
    end
    for _, card in ipairs(self.launcherCards) do
        card:Hide()
    end
    self.noGames:SetShown(#games == 0)
    self.emptyDetail:SetShown(#games == 0)
    self.browseGames:SetShown(home and #games == 0 and #Games:GetGames() > 0)
    self.noGames:SetWidth(available - 48)
    self.emptyDetail:SetWidth(available - 48)
    self.noGames:SetText(home and "Your next favorite starts here" or "Your library is ready for more")
    self.emptyDetail:SetText(
        home and "Launch an installed game to keep it close. Your recent games will appear here."
            or "Installed game modules for this mode will appear here automatically."
    )
    self.browseGames:SetScript("OnClick", function()
        self:OpenLauncher(#Games:GetGames("singleplayer") > 0 and "singleplayer" or "multiplayer")
    end)
    local cardHeight = multi and 260 or 226
    local rowStep = cardHeight + 14
    for i = first, last do
        local index, game = i - first + 1, games[i]
        local card = self.launcherCards[index]
        if not card then
            card = Theme:GameCard(self.cardList, cardWidth, 226)
            self.launcherCards[index] = card
        end
        local id, art = game.id, library[game.id]
        local hostReason = multi and self:HostUnavailable(game) or nil
        place(
            card,
            nil,
            ((index - 1) % columns) * (cardWidth + 14),
            -math.floor((index - 1) / columns) * rowStep,
            cardWidth,
            cardHeight
        )
        card:SetGame(game, {
            art = art and art.card,
            description = multi and game.description or art and art.summary,
            browser = multi,
            modeLabel = multi and ("MULTIPLAYER / " .. self:PlayerCount(game)) or nil,
            playLabel = multi and "Host Game" or nil,
            reason = hostReason,
            resume = Games.ActiveGame and Games.ActiveGame.game.id == id,
            enabled = multi and not hostReason or not multi and self:CanLaunch(game),
            selected = (multi and self.selectedMulti or self.featuredID) == id,
            onPlay = invoke(function()
                if multi then
                    return Games:CreateLobby(id)
                end
                return self:LaunchGame(id)
            end),
            onDetails = invoke(function()
                if multi then
                    return self:SelectMultiplayer(id)
                end
                self:OpenLauncher("home")
                return self:FeatureGame(id)
            end),
            onSelect = invoke(function()
                return multi and self:SelectMultiplayer(id) or self:FeatureGame(id)
            end),
        })
        card:Show()
    end
    self.cardList:SetHeight(
        math.max(gridHeight, #games == 0 and 206 or math.ceil((last - first + 1) / columns) * rowStep - 14)
    )
end
function UI:HostUnavailable(game)
    return not game and "Game module is not installed"
        or Games.Pending and "Joining a lobby..."
        or Games.Lobby and "Resume your current lobby"
        or Games.ActiveGame and "Finish your current game first"
        or not Games:GroupChannel() and "Join a party to host"
        or game.partyOnly
            and (Games:GroupChannel() ~= "PARTY" or IsInRaid() or GetNumGroupMembers() < 2 or GetNumGroupMembers() > 5)
            and "Requires a PARTY of 2-5"
end
function UI:RefreshFeature(width)
    local selected, active = self:SelectHomeFeature()
    if not selected then
        Theme:SetArt(self.heroArt, "generic-hero", width - 2, 254, 1)
        self.heroShade:Hide()
        self.heroFallback:Hide()
        self.soloLeave:Hide()
        self.soloTitle:Show()
        place(self.soloTitle, nil, 28, -64, width - 56, 42)
        place(self.soloDescription, nil, 28, -132, width - 56, 58)
        self.soloTitle:SetText("Your next adventure")
        self.soloDescription:SetText("Install a KIC Games module to begin.")
        self.soloPlay:Hide()
        self.soloOpen:Hide()
        self.soloHint:Hide()
        return
    end

    local art = library[selected.id]
    Theme:SetArt(self.heroArt, art and art.hero or "generic-hero", width - 2, 254, 1)
    -- Scale the gradient with the hero viewport, not the underlying source image.
    -- It begins near the bottom: the illuminated game wordmark stays untouched.
    self.heroShade:Show()
    self.heroShade:ClearAllPoints()
    self.heroShade:SetPoint("TOPLEFT", 1, -1)
    self.heroShade:SetSize(width - 2, 254)
    self.heroFallback:SetShown(not self.heroArt.artLoaded)
    self.heroFallback:SetTexture(selected.icon or "Interface\\Icons\\INV_Misc_Dice_01")

    -- The native game title is only a safety net when the TGA is unavailable.
    self.soloTitle:SetShown(not self.heroArt.artLoaded)
    if not self.heroArt.artLoaded then
        place(self.soloTitle, nil, 30, -60, width - 64, 44)
        self.soloTitle:SetText(selected.title:upper())
    end

    -- Compact, consistent action row at bottom left for all installed games.
    -- Description sits alongside Play rather than covering the baked-in logo.
    local actionX, actionY, actionWidth, actionHeight = 30, -207, 206, 40
    local leaving = Games.Pending ~= nil or Games.Lobby and Games.Lobby.mode == "multiplayer"
    local leaveWidth = 146
    local detailX = actionX + actionWidth + 20 + (leaving and leaveWidth + 16 or 0)
    place(self.soloDescription, nil, detailX, -195, math.max(120, width - detailX - 26), 56)
    self.soloDescription:SetJustifyV("MIDDLE")
    self.soloDescription:SetText(art and art.summary or selected.description or "")
    place(self.soloPlay, nil, actionX, actionY, actionWidth, actionHeight)
    place(self.soloOpen, nil, actionX, actionY, actionWidth, actionHeight)
    local resume = active ~= nil
    self.soloOpen:SetShown(resume)
    self.soloPlay:SetShown(not resume)
    self.soloPlay:SetText(selected.mode == "singleplayer" and "Play" or "View lobby")
    if self:CanLaunch(selected) then
        self.soloPlay:Enable()
    else
        self.soloPlay:Disable()
    end

    -- Keep the secondary lobby escape action accessible alongside Play.
    place(self.soloLeave, nil, actionX + actionWidth + 12, -209, leaveWidth, 36)
    self.soloLeave:SetShown(leaving == true)
    self.soloHint:Hide()
end
