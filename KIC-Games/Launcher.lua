local _, Games = ...
local UI, Theme = Games.UI, Games.Theme
local library = {
    bejeweled = {
        hero = "bejeweled-hero",
        card = "bejeweled-card",
        tagline = "MATCH / CASCADE / REPEAT",
        summary = "Match 3+ in a row or column.\nCascades multiply points.",
    },
    tetris = {
        hero = "tetris-hero",
        card = "tetris-card",
        tagline = "STACK / CLEAR / REPEAT",
        summary = "Stack, clear lines,\nbeat your best.",
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
function UI:OpenLauncher(page)
    page = pages[page] and page or "home"
    local changed = self.launcherPage ~= page
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
    if Games.Lobby then
        if not Games:IsHost() or Games.Lobby.mode ~= "multiplayer" or Games.Lobby.status == "running" then
            return false, "Leave the current game or lobby before changing games."
        end
        local ok, err = Games:SelectGame(id)
        if ok == false then
            return ok, err
        end
    end
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
        self:OpenLauncher("multiplayer")
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
        return not Games.Pending
            and (
                not Games.Lobby
                or Games:IsHost() and Games.Lobby.mode == "multiplayer" and Games.Lobby.status ~= "running"
            )
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
    self.sidebar = Theme:Panel(self.home, 188, 548, 18, -96)
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
    self.hero = self.singlePanel
    self.soloSection:Hide()
    place(self.hero, self.content, 0, 0, 882, 256)
    -- BackdropTemplate owns BACKGROUND/BORDER. Keep the hero stack explicitly
    -- above its opaque Center when the panel is reparented, resized or refreshed.
    self.heroArt = Theme:Art(self.hero, "bejeweled-hero", 880, 254, 1, -1, 1, "ARTWORK")
    self.heroShade = self.hero:CreateTexture(nil, "ARTWORK", nil, 1)
    self.heroShade:SetColorTexture(0.008, 0.02, 0.05, 0.72)
    self.heroFallback = self.hero:CreateTexture(nil, "ARTWORK", nil, 2)
    self.heroFallback:SetSize(112, 112)
    self.heroFallback:SetPoint("TOPLEFT", 100, -70)
    self.heroBadge = Theme:Label(self.hero, "SOLO GAME", 0, 0, 220, "GameFontHighlightSmall")
    self.heroBadge:SetTextColor(unpack(Theme.Colors.accent))
    self.heroTagline = Theme:Label(self.hero, "", 0, 0, 420)
    self.heroTagline:SetTextColor(unpack(Theme.Colors.accent))
    self.heroRecord = Theme:Label(self.hero, "", 0, 0, 230, "GameFontHighlightSmall")
    self.soloTitle:SetFont("Fonts\\ARIALN.TTF", 32, "")
    self.soloDescription:SetFont("Fonts\\ARIALN.TTF", 14, "")
    Theme:Primary(self.soloPlay)
    Theme:Primary(self.soloOpen)
    self.soloPlay.caption:SetFont("Fonts\\ARIALN.TTF", 18, "")
    self.soloOpen.caption:SetFont("Fonts\\ARIALN.TTF", 18, "")
    self.soloOpen:SetText("Resume")
    self.soloPlay:SetScript(
        "OnClick",
        invoke(function()
            return self:LaunchGame(self.featuredID)
        end)
    )
    self.soloOpen:SetScript(
        "OnClick",
        invoke(function()
            return self:LaunchGame(self.featuredID)
        end)
    )
    self.soloHint:Hide()
    self.soloLeave:SetText("Leave lobby")
    self.installedTitle = Theme:Label(self.content, "RECENT GAMES", 0, -274, 550, "GameFontNormalLarge")
    self.installedTitle:SetFont(Theme.Fonts.display, 18, "")
    self.installedTitle:SetTextColor(unpack(Theme.Colors.accent))
    self.pageTitle = Theme:Label(self.content, "", 0, -6, 600, "GameFontNormalLarge")
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
    self.recentPrevious = Theme:Button(self.content, "Prev", 60, 0, 0, function()
        self.recentPage = self.recentPage - 1
        self:RefreshLauncher()
    end)
    self.recentNext = Theme:Button(self.content, "Next", 60, 0, 0, function()
        self.recentPage = self.recentPage + 1
        self:RefreshLauncher()
    end)
    self.recentIndicator = Theme:Label(self.content, "", 0, 0, 70, "GameFontHighlightSmall")
    self.recentIndicator:SetJustifyH("CENTER")
    self.pageBack = Theme:Button(self.content, "Back to game", 140, 0, 0, function()
        self:ShowGame()
    end)
    self.pageBack:SetFrameLevel(self.content:GetFrameLevel() + 5)
    self.groupPanel = Theme:Panel(self.frame, 264, 54, 796, -18)
    self.groupStatus = Theme:Label(self.groupPanel, "", 14, -8, 236)
    self.groupDetail = Theme:Label(self.groupPanel, "", 14, -31, 236, "GameFontHighlightSmall")
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
    place(self.gameContainer, nil, (width - 860) / 2, -116)
    place(self.optionsButton, nil, width - 526, -30, 80, 28)
    place(self.resultsButton, nil, width - 438, -30, 80, 28)
    place(self.homeButton, nil, width - 232, -30, 94, 28)
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
    self.groupStatus:SetText(channel and (IsInRaid() and "Raid connected" or "Party connected") or "No group")
    self.groupDetail:SetText(
        channel
                and (string.format(
                    "%d member%s / %s",
                    count,
                    count == 1 and "" or "s",
                    channel == "INSTANCE_CHAT" and "Instance group" or "Ready for party games"
                ))
            or "Solo play mode"
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
    local libraryPage = self.launcherPage == "singleplayer" or multi
    local settingsPage = self.launcherPage == "options"
    local resultsPage = self.launcherPage == "results"
    local width, height = self.content:GetWidth(), self.content:GetHeight()
    self.optionsButton:SetShown(inGame)
    self.resultsButton:SetShown(inGame)
    place(self.abortButton, nil, self.frame:GetWidth() - (inGame and 350 or 452), -30, 110, 28)
    self.groupPanel:SetShown(not inGame)
    self.launcherMotto:SetShown(not inGame)
    self.hero:SetShown(home)
    self.multiplayerPage:SetShown(multi)
    self.browserPanel:SetShown(multi)
    self.lobbyPanel:SetShown(multi)
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
    elseif multi then
        gridWidth, gridHeight = math.max(290, math.floor(width * 0.39)), 226
        local lobbyX = gridWidth + 16
        place(self.lobbyPanel, nil, lobbyX, 0, width - lobbyX, height)
        place(self.browserPanel, nil, 0, -308, gridWidth, height - 308)
        place(self.browser:GetParent(), nil, 14, -44, gridWidth - 28, height - 368)
        place(self.browserRefresh, nil, gridWidth - 104, -9, 90, 28)
        self.browser:SetWidth(gridWidth - 44)
        for _, row in ipairs(self.listingRows) do
            row:SetWidth(gridWidth - 44)
            row.title:SetWidth(gridWidth - 56)
            row.detail:SetWidth(gridWidth - 56)
        end
        self.emptyLobbies:SetWidth(gridWidth - 44)
        for _, field in ipairs({
            self.lobbyTitle,
            self.lobbyInfo,
            self.selectedGame,
            self.gameInfo,
            self.players,
            self.countdownText,
            self.hint,
        }) do
            field:SetWidth(width - lobbyX - 32)
        end
        local actionWidth = (width - lobbyX - 48) / 3
        for i, pair in ipairs({
            { self.create, self.leave },
            { self.ready, self.showGame },
            { self.start, self.endGame },
        }) do
            for _, b in ipairs(pair) do
                place(b, nil, 16 + (i - 1) * (actionWidth + 8), -(height - 52), actionWidth, 32)
            end
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
    self.cardColumns = columns
    local pagesCount = math.max(1, math.ceil(#games / columns))
    self.recentPage = math.max(1, math.min(self.recentPage, pagesCount))
    local first = home and (self.recentPage - 1) * columns + 1 or 1
    local last = home and math.min(#games, first + columns - 1) or #games
    local cardWidth = (available - (columns - 1) * 14) / columns
    self.installedTitle:SetText("RECENT GAMES")
    self.pageTitle:SetText(multi and "MULTIPLAYER" or "SINGLEPLAYER")
    self.pageTitle:SetWidth(multi and gridWidth or width)
    self.pageSubtitle:SetWidth(multi and gridWidth or width)
    self.pageSubtitle:SetText(
        string.format(
            "%d installed game(s) / %s",
            #games,
            multi and "Host or join with your party" or "Play at your own pace"
        )
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
    for i = first, last do
        local index, game = i - first + 1, games[i]
        local card = self.launcherCards[index]
        if not card then
            card = Theme:GameCard(self.cardList, cardWidth, 226)
            self.launcherCards[index] = card
        end
        local id, art = game.id, library[game.id]
        place(
            card,
            nil,
            ((index - 1) % columns) * (cardWidth + 14),
            -math.floor((index - 1) / columns) * 240,
            cardWidth,
            226
        )
        card.art:SetSize(cardWidth, 226)
        Theme:SetArt(card.art, art and art.card or "generic-card", cardWidth, 226, 0.19)
        Theme:SetArt(card.icon, art and art.card or "generic-card", 80, 80, 1)
        if not art then
            card.icon:SetTexture(game.icon or "Interface\\Icons\\INV_Misc_Dice_01")
        end
        card.title:SetWidth(cardWidth - 126)
        card.title:SetHeight(48)
        card.title:SetText(game.title)
        place(card.mode, nil, 110, -77, cardWidth - 126)
        card.mode:SetText(
            game.mode == "singleplayer" and "SOLO" or string.format("PARTY / %d-%d", game.minPlayers, game.maxPlayers)
        )
        card.detail:SetWidth(cardWidth - 32)
        card.detail:SetText(art and art.summary or game.description or "")
        card.play:SetWidth(cardWidth - 104)
        card.play:SetText(
            Games.ActiveGame and Games.ActiveGame.game.id == id and "Resume"
                or game.mode == "singleplayer" and "Play"
                or "View lobby"
        )
        card.play:SetScript(
            "OnClick",
            invoke(function()
                return self:LaunchGame(id)
            end)
        )
        if self:CanLaunch(game) then
            card.play:Enable()
        else
            card.play:Disable()
        end
        place(card.details, nil, cardWidth - 72, -178, 56, 34)
        card.details:SetScript(
            "OnClick",
            invoke(function()
                local ok, err = self:FeatureGame(id)
                if ok then
                    self:OpenLauncher(multi and "multiplayer" or "home")
                end
                return ok, err
            end)
        )
        card:SetScript(
            "OnClick",
            invoke(function()
                return self:FeatureGame(id)
            end)
        )
        Theme:Select(card, (multi and self.selectedMulti or self.featuredID) == id)
        card:Show()
    end
    self.cardList:SetHeight(
        math.max(gridHeight, #games == 0 and 206 or math.ceil((last - first + 1) / columns) * 240 - 14)
    )
    if not home then
        return
    end
    place(self.hero, nil, 0, 0, width, 256)
    self.heroArt:SetSize(width - 2, 254)
    self:RefreshFeature(width)
end
function UI:RefreshFeature(width)
    local selected = Games.Registry[self.featuredID] or Games.Registry[self.selectedSolo] or Games:GetGames()[1]
    self.featuredID = selected and selected.id
    if not selected then
        Theme:SetArt(self.heroArt, "generic-hero", width - 2, 254, 1)
        self.heroShade:Hide()
        self.heroFallback:Hide()
        self.soloLeave:Hide()
        place(self.heroBadge, nil, 28, -24, 400)
        place(self.soloTitle, nil, 28, -64, width - 56, 42)
        place(self.soloDescription, nil, 28, -132, width - 56, 58)
        self.soloTitle:SetText("Your next adventure")
        self.soloDescription:SetText("Install a KIC Games module to begin.")
        self.soloPlay:Hide()
        self.soloOpen:Hide()
        self.heroRecord:SetText("")
        self.heroBadge:SetText("GAME LIBRARY")
        self.heroTagline:SetText("")
        return
    end
    local art = library[selected.id]
    self.heroShade:Show()
    local asset = art and Games.Artwork[art.hero]
    local x = asset and asset.textSide == "left" and 28 or math.max(28, width - 460)
    local textWidth = math.min(432, width - x - 24)
    Theme:SetArt(self.heroArt, art and art.hero or "generic-hero", width - 2, 254, 1)
    self.heroShade:ClearAllPoints()
    self.heroShade:SetPoint("TOPLEFT", x - 12, -1)
    self.heroShade:SetSize(456, 254)
    self.heroFallback:SetShown(art == nil)
    self.heroFallback:SetTexture(selected.icon or "Interface\\Icons\\INV_Misc_Dice_01")
    place(self.heroBadge, nil, x, -22, textWidth)
    self.heroBadge:SetText(selected.mode == "singleplayer" and "SOLO GAME" or "PARTY GAME")
    place(self.soloTitle, nil, x, -54, textWidth, 42)
    self.soloTitle:SetText(selected.title:upper())
    place(self.heroTagline, nil, x, -104, textWidth)
    self.heroTagline:SetText(art and art.tagline or "PLAY / TOGETHER")
    place(self.soloDescription, nil, x, -131, textWidth, 58)
    self.soloDescription:SetText(selected.description or "")
    place(self.soloPlay, nil, x, -202, 190, 36)
    place(self.soloOpen, nil, x, -202, 190, 36)
    local resume = Games.ActiveGame and Games.ActiveGame.game.id == selected.id
    self.soloOpen:SetShown(resume == true)
    self.soloPlay:SetShown(not resume)
    self.soloPlay:SetText(selected.mode == "singleplayer" and "Play" or "View lobby")
    if self:CanLaunch(selected) then
        self.soloPlay:Enable()
    else
        self.soloPlay:Disable()
    end
    local saved = Games.DB[selected.id]
    local score = type(saved) == "table" and type(saved.best) == "table" and saved.best.score
    local record = type(score) == "number"
        and score == score
        and score >= 0
        and score <= 2147483647
        and ("Personal best: " .. tostring(score))
    self.heroRecord:SetText(
        record
            or (
                selected.mode == "singleplayer" and "Your next personal best awaits."
                or "Open the party lobby to host or join."
            )
    )
    place(self.heroRecord, nil, x + 208, -212, 222)
    local leaving = Games.Pending ~= nil or Games.Lobby and Games.Lobby.mode == "multiplayer"
    place(self.soloLeave, nil, x + 208, -202, 170, 36)
    self.soloLeave:SetShown(leaving)
    self.heroRecord:SetShown(not leaving)
    self.soloHint:Hide()
end
