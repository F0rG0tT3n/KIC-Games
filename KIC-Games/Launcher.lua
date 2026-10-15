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
function UI:OpenLauncher(page)
    if page == "singleplayer" or page == "multiplayer" then
        self:SelectTab(page)
    else
        self.launcherPage = "home"
        Games.DB.launcherPage = "home"
    end
    self:ShowHome()
    self.frame:Show()
end
function UI:FeatureGame(id)
    local game = Games.Registry[id]
    if not game then
        return false
    end
    self.featuredID = id
    if game.mode == "singleplayer" then
        self.selectedSolo = id
    else
        self.selectedMulti = id
    end
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
        self.selectedMulti = id
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
        return true
    end -- opens the real host/join page
    return not Games.Pending
        and (not Games.Lobby or Games.Lobby.mode == "singleplayer" and Games.Lobby.status == "waiting")
end
function UI:InitializeLauncher()
    self.launcherPage = Games.DB.launcherPage or Games.DB.launcherTab or "home"
    if self.launcherPage ~= "singleplayer" and self.launcherPage ~= "multiplayer" then
        self.launcherPage = "home"
    end
    self.launcherCards = {}
    self.multiplayerPage = CreateFrame("Frame", nil, self.home)
    self.multiplayerPage:SetAllPoints(self.home)
    Theme:Art(self.home, "hall", 1088, 562, 16, -82, 0.13)
    self.sidebar = Theme:Panel(self.home, 188, 548, 18, -96)
    Theme:Art(self.sidebar, "crest", 142, 142, 23, -325, 0.09, "ARTWORK")
    Theme:Art(self.sidebar, "sidebar", 186, 265, 1, -282, 0.48)
    self.nav = {}
    local entries = {
        {
            id = "home",
            text = "Home",
            fn = function()
                self:OpenLauncher("home")
            end,
        },
        {
            id = "singleplayer",
            text = "Singleplayer",
            button = self.singleTab,
            fn = function()
                self:OpenLauncher("singleplayer")
            end,
        },
        {
            id = "multiplayer",
            text = "Multiplayer",
            button = self.multiTab,
            fn = function()
                self:OpenLauncher("multiplayer")
            end,
        },
        {
            id = "results",
            text = "Results",
            fn = function()
                self:ShowResults()
            end,
        },
        {
            id = "options",
            text = "Options",
            fn = function()
                self:ShowOptions()
            end,
        },
    }
    for i, entry in ipairs(entries) do
        local b = entry.button or Theme:Button(self.sidebar, entry.text, 172, 8, -18 - (i - 1) * 54, entry.fn, 46)
        place(b, self.sidebar, 8, -18 - (i - 1) * 54, 172, 46)
        b:SetScript("OnClick", entry.fn)
        b.caption:ClearAllPoints()
        b.caption:SetPoint("LEFT", 46, 0)
        b.caption:SetWidth(120)
        b.caption:SetJustifyH("LEFT")
        self.nav[entry.id] = b
        local key = "nav-" .. entry.id
        local asset = Games.Artwork[key]
        Theme:Art(b, key, 24, 24, 12, -11, 1, "ARTWORK")
        if not asset.file then
            Theme:Label(b, asset.glyph, 17, -14, 22):SetTextColor(unpack(Theme.Colors.accent))
        end
    end
    -- Keep multiplayer state/actions intact; only move their native panels.
    place(self.libraryPanel, self.multiplayerPage, 222, -96, 340, 252)
    place(self.browserPanel, self.multiplayerPage, 222, -360, 340, 280)
    place(self.lobbyPanel, self.multiplayerPage, 578, -96, 526, 544)
    place(self.browser:GetParent(), nil, 14, -44, 303, 216)
    place(self.create, nil, 16, -492)
    place(self.leave, nil, 16, -492)
    place(self.ready, nil, 151, -492)
    place(self.showGame, nil, 151, -492)
    place(self.start, nil, 281, -492)
    place(self.endGame, nil, 281, -492)
    -- Reuse the real solo actions and text as the featured panel; no duplicate CTA.
    self.hero = self.singlePanel
    self.soloSection:Hide()
    place(self.hero, self.home, 222, -96, 882, 256)
    self.heroArt = Theme:Art(self.hero, "bejeweled-hero", 880, 254, 1, -1, 1)
    self.heroShade = self.hero:CreateTexture(nil, "BACKGROUND", nil, 1)
    self.heroShade:SetColorTexture(0.008, 0.02, 0.05, 0.72)
    self.heroFallback = self.hero:CreateTexture(nil, "ARTWORK")
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
    self.installedTitle = Theme:Label(self.home, "INSTALLED GAMES", 222, -370, 870, "GameFontNormalLarge")
    self.installedTitle:SetFont("Fonts\\ARIALN.TTF", 18, "")
    self.installedTitle:SetTextColor(unpack(Theme.Colors.accent))
    self.cardList, self.cardScroll = Theme:Scroll(self.home, 866, 238, 222, -402)
    self.noGames = Theme:Label(self.cardList, "No games installed for this mode.", 16, -32, 810)
    self.groupPanel = Theme:Panel(self.frame, 264, 54, 796, -18)
    self.groupStatus = Theme:Label(self.groupPanel, "", 14, -8, 236)
    self.groupDetail = Theme:Label(self.groupPanel, "", 14, -31, 236, "GameFontHighlightSmall")
    self.launcherMotto =
        Theme:Label(self.frame, "Games today. Raids tomorrow.", 810, -669, 220, "GameFontHighlightSmall")
    self.launcherMotto:SetTextColor(unpack(Theme.Colors.accent))
    place(self.optionsButton, nil, 594, -30, 80, 28)
    place(self.resultsButton, nil, 682, -30, 80, 28)
    place(self.abortButton, nil, 770, -30, 110, 28)
    place(self.homeButton, nil, 888, -30, 94, 28)
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
    if not self.launcherCards then
        return
    end
    local inGame = self.gameContainer:IsShown()
    local multi = self.launcherPage == "multiplayer"
    self.optionsButton:SetShown(inGame)
    self.resultsButton:SetShown(inGame)
    place(self.abortButton, nil, inGame and 770 or 668, -30, 110, 28)
    self.groupPanel:SetShown(not inGame)
    self.launcherMotto:SetShown(not inGame)
    self.hero:SetShown(not multi)
    self.multiplayerPage:SetShown(multi)
    self.libraryPanel:SetShown(multi)
    self.browserPanel:SetShown(multi)
    self.lobbyPanel:SetShown(multi)
    self.libraryPanel:SetHeight(252)
    self.libraryScroll:SetHeight(199)
    self.libraryTitle:SetText("MULTIPLAYER GAMES")
    self.installedTitle:SetShown(not multi)
    self.cardScroll:SetShown(not multi)
    self.singleTab:SetText("Singleplayer")
    self.multiTab:SetText("Multiplayer")
    self.singleTab:Enable()
    self.multiTab:Enable()
    for name, b in pairs(self.nav) do
        Theme:Select(b, name == self.launcherPage)
    end
    self:RefreshLauncherStatus()
    if multi then
        return
    end
    local games = Games:GetGames(self.launcherPage == "singleplayer" and "singleplayer" or nil)
    local selected = Games.Registry[self.featuredID]
    if self.launcherPage == "singleplayer" then
        selected = Games.Registry[self.selectedSolo]
    end
    if not selected or self.launcherPage == "singleplayer" and selected.mode ~= "singleplayer" then
        selected = Games.Registry[self.selectedSolo]
        if not selected or self.launcherPage == "singleplayer" and selected.mode ~= "singleplayer" then
            selected = games[1]
        end
    end
    self.featuredID = selected and selected.id
    self.installedTitle:SetText(string.format("INSTALLED GAMES  /  %d", #games))
    self.noGames:SetShown(#games == 0)
    for _, card in ipairs(self.launcherCards) do
        card:Hide()
    end
    local columns = math.max(1, math.min(3, #games))
    local width = (866 - (columns - 1) * 14) / columns
    for i, game in ipairs(games) do
        local card = self.launcherCards[i]
        if not card then
            card = Theme:GameCard(self.cardList, width, 226)
            self.launcherCards[i] = card
        end
        local id = game.id
        local art = library[id]
        card:SetSize(width, 226)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", ((i - 1) % columns) * (width + 14), -math.floor((i - 1) / columns) * 240)
        card.art:SetSize(width, 226)
        Theme:SetArt(card.art, art and art.card or "generic-card", width, 226, 0.19)
        Theme:SetArt(card.icon, art and art.card or "generic-card", 80, 80, 1)
        if not art then
            card.icon:SetTexture(game.icon or "Interface\\Icons\\INV_Misc_Dice_01")
        end
        card.title:SetWidth(width - 126)
        card.title:SetText(game.title)
        card.mode:SetWidth(width - 126)
        card.mode:SetText(
            game.mode == "singleplayer" and "SOLO" or string.format("PARTY / %d-%d", game.minPlayers, game.maxPlayers)
        )
        card.detail:SetWidth(width - 32)
        card.detail:SetText(art and art.summary or game.description or "")
        card.play:SetWidth(width - 104)
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
        place(card.details, nil, width - 72, -178, 56, 34)
        card.details:SetScript("OnClick", function()
            self:FeatureGame(id)
        end)
        card:SetScript("OnClick", function()
            self:FeatureGame(id)
        end)
        Theme:Select(card, self.featuredID == id)
        card:Show()
    end
    self.cardList:SetHeight(math.max(226, math.ceil(#games / columns) * 240 - 14))
    if not selected then
        Theme:SetArt(self.heroArt, "generic-hero", 880, 254, 1)
        self.heroShade:Hide()
        self.heroFallback:Hide()
        self.soloLeave:Hide()
        place(self.heroBadge, nil, 28, -24, 400)
        place(self.soloTitle, nil, 28, -64, 800, 42)
        place(self.soloDescription, nil, 28, -132, 800, 58)
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
    local x = asset and asset.textSide == "left" and 28 or 422
    local textWidth = 432
    Theme:SetArt(self.heroArt, art and art.hero or "generic-hero", 880, 254, 1)
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
