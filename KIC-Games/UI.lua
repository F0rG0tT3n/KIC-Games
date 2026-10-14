local _, Games = ...
local UI = { gameRows = {}, listingRows = {} }
Games.UI = UI
local GOLD = { 1, 0.82, 0.35 }

local function label(parent, value, x, y, width, template)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    font:SetPoint("TOPLEFT", x, y)
    font:SetWidth(width)
    font:SetJustifyH("LEFT")
    font:SetText(value)
    return font
end

local function panel(parent, width, height, x, y)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.055, 0.065, 0.085, 0.98)
    frame:SetBackdropBorderColor(0.25, 0.28, 0.34, 1)
    return frame
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
    local result = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    result:SetSize(width, 26)
    result:SetPoint("TOPLEFT", x, y)
    result:SetText(value)
    result:SetScript("OnClick", callback)
    return result
end

local function scroll(parent, width, height, x, y)
    local frame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", x, y)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(width, 1)
    frame:SetScrollChild(child)
    return child
end

local function enable(widget, condition)
    if condition then
        widget:Enable()
    else
        widget:Disable()
    end
end

function UI:Initialize()
    local frame = panel(UIParent, 900, 590, 0, 0)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame:Hide()
    _G.KICGamesWindow = frame
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesWindow"
    self.frame = frame
    local title = label(frame, "KIC-Games", 22, -20, 400, "GameFontNormalLarge")
    title:SetTextColor(unpack(GOLD))
    label(frame, "Party games for the time between adventures", 22, -47, 540, "GameFontHighlightSmall")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    self.homeButton = button(frame, "Launcher", 100, 742, -34, function()
        UI:ShowHome()
    end)
    self.homeButton:Hide()
    self.home = CreateFrame("Frame", nil, frame)
    self.home:SetAllPoints()

    local library = panel(self.home, 355, 252, 20, -80)
    label(library, "GAMES", 14, -14, 290, "GameFontNormal")
    self.library = scroll(library, 303, 199, 14, -40)
    self.emptyGames = label(
        self.library,
        "Your game library is empty.\n\nKIC-Games is the launcher and multiplayer framework. Games will appear here when their modules are installed.\n\nYou can already create a lobby and invite party members to join it.",
        0,
        0,
        292
    )

    local browser = panel(self.home, 355, 186, 20, -344)
    label(browser, "PARTY LOBBIES", 14, -14, 205, "GameFontNormal")
    button(browser, "Refresh", 90, 248, -9, function()
        Games:Discover()
    end)
    self.browser = scroll(browser, 303, 126, 14, -44)
    self.emptyLobbies =
        label(self.browser, "No lobbies found.\n\nCreate one, or ask a party member with KIC-Games to host.", 0, 0, 290)

    local lobbyPanel = panel(self.home, 485, 450, 395, -80)
    self.lobbyTitle = label(lobbyPanel, "YOUR LOBBY", 16, -14, 450, "GameFontNormal")
    self.lobbyInfo = label(lobbyPanel, "", 16, -45, 450)
    self.selectedGame = label(lobbyPanel, "", 16, -107, 450, "GameFontNormalLarge")
    self.gameInfo = label(lobbyPanel, "", 16, -138, 450, "GameFontHighlightSmall")
    self.players = label(lobbyPanel, "", 16, -193, 450)
    self.players:SetSpacing(12)
    self.hint = label(lobbyPanel, "", 16, -340, 450, "GameFontHighlightSmall")
    self.create = button(
        lobbyPanel,
        "Create lobby",
        135,
        16,
        -393,
        action(function()
            return Games:CreateLobby()
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
            return Games:Ready(own and not own.ready)
        end)
    )
    self.start = button(
        lobbyPanel,
        "Start game",
        145,
        281,
        -393,
        action(function()
            return Games:StartGame()
        end)
    )
    self.showGame = button(lobbyPanel, "Open game", 120, 151, -393, function()
        UI:ShowGame()
    end)
    self.endGame = button(
        lobbyPanel,
        "End game",
        145,
        281,
        -393,
        action(function()
            return Games:ReturnToLobby()
        end)
    )

    self.footer = label(frame, "", 22, -551, 850, "GameFontHighlightSmall")
    self.gameContainer = panel(frame, 860, 450, 20, -80)
    self.gameContainer:Hide()
    self:CreateMinimapButton()
    self:Refresh()
end

function UI:GetGameContainer()
    return self.gameContainer
end

function UI:ShowHome()
    self.home:Show()
    self.gameContainer:Hide()
    self.homeButton:Hide()
    self:Refresh()
end

function UI:ShowGame()
    if not Games.ActiveGame then
        return
    end
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
    local games = Games:GetGames()
    self.emptyGames:SetShown(#games == 0)
    for _, row in ipairs(self.gameRows) do
        row:Hide()
    end
    for i, game in ipairs(games) do
        local row = self.gameRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.library)
            row:SetSize(301, 62)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.title = label(row, "", 6, -5, 288, "GameFontNormal")
            row.detail = label(row, "", 6, -28, 288, "GameFontHighlightSmall")
            self.gameRows[i] = row
        end
        local registeredID = game.id
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 68)
        row.title:SetText(game.title)
        row.detail:SetText(
            string.format(
                "%d-%d players | v%s\n%s",
                game.minPlayers,
                game.maxPlayers,
                game.version,
                game.description or ""
            )
        )
        row:SetScript(
            "OnClick",
            action(function()
                return Games:SelectGame(registeredID)
            end)
        )
        enable(row, Games:IsHost() and Games.Lobby.status == "waiting")
        row:Show()
    end
    self.library:SetHeight(math.max(185, #games * 68))

    local listings = {}
    for host, listing in pairs(Games.Listings) do
        if host ~= Games:PlayerName() then
            listings[#listings + 1] = listing
        end
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
            row = CreateFrame("Button", nil, self.browser)
            row:SetSize(301, 56)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.title = label(row, "", 6, -3, 290, "GameFontNormal")
            row.detail = label(row, "", 6, -24, 290, "GameFontHighlightSmall")
            self.listingRows[i] = row
        end
        local host, id = listing.host, listing.id
        local game = Games.Registry[listing.gameID]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 60)
        row.title:SetText(host)
        row.detail:SetText(
            string.format(
                "%s | %d players\n%s",
                game and game.title or (listing.gameID ~= "" and listing.gameID or "Choosing a game"),
                listing.count,
                listing.status == "running" and (listing.rejoin and "Click to rejoin" or "Game in progress")
                    or "Click to join"
            )
        )
        row:SetScript(
            "OnClick",
            action(function()
                return Games:JoinLobby(host, id)
            end)
        )
        enable(row, not Games.Lobby and not Games.Pending and (listing.status == "waiting" or listing.rejoin))
        row:Show()
    end
    self.browser:SetHeight(math.max(112, #listings * 60))

    local lobby, pending = Games.Lobby, Games.Pending
    local running = lobby and lobby.status == "running"
    self.create:SetShown(not lobby)
    enable(self.create, Games:GroupChannel() ~= nil and not pending)
    self.leave:SetShown(lobby ~= nil or pending ~= nil)
    if pending then
        self.create:Hide()
    end
    self.ready:SetShown(lobby ~= nil and not running)
    self.start:SetShown(lobby ~= nil and not running)
    self.showGame:SetShown(running and Games.ActiveGame ~= nil)
    self.endGame:SetShown(running and Games:IsHost())
    if lobby then
        local game = Games.Registry[lobby.gameID]
        self.lobbyTitle:SetText(running and "GAME IN PROGRESS" or "YOUR LOBBY")
        self.lobbyInfo:SetText(
            "Host: "
                .. lobby.host
                .. "\n\n"
                .. (Games:IsHost() and "You are hosting this lobby." or "You joined this lobby.")
        )
        self.selectedGame:SetText(game and game.title or (lobby.gameID ~= "" and lobby.gameID or "No game selected"))
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
        self.ready:SetText(own and own.ready and "Not ready" or "Ready")
        enable(self.ready, Games:Compatible(lobby))
        local canStart, reason = Games:CanStart()
        enable(self.start, canStart)
        self.hint:SetText(
            running and "Use Open game to return to the match. The host can end it here."
                or (
                    Games:IsHost() and (canStart and "Everyone is ready. You can start." or reason)
                    or "Mark yourself ready when the selected game is installed."
                )
        )
    else
        self.lobbyTitle:SetText(pending and "JOINING LOBBY" or "PLAY WITH YOUR PARTY")
        self.lobbyInfo:SetText(
            pending and ("Waiting for " .. pending.host .. "...")
                or "Create a lobby, or join one from the list on the left."
        )
        self.selectedGame:SetText("")
        self.gameInfo:SetText("")
        self.players:SetText(
            "Every player needs KIC-Games and the selected game module.\n\nUp to five players can join a lobby.\n\nParty members join voluntarily; creating a lobby does not send a normal chat message."
        )
        self.hint:SetText(
            Games:GroupChannel() and "Ready to create or join a lobby."
                or "Join a WoW party to use multiplayer lobbies."
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
