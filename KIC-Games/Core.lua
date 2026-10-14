local addonName, Games = ...
_G.KICGames = Games

Games.VERSION = "0.1.0"
Games.API_VERSION = 1
Games.PREFIX = "KICGames1"
Games.Registry = {}
Games.Listings = {}
Games.MAX_PLAYERS = 5

function Games:Notify(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100KIC-Games:|r " .. tostring(message))
    end
end

function Games:Changed()
    if self.UI then
        self.UI:Refresh()
    end
end

function Games:NormalizeName(name)
    if type(name) ~= "string" or name == "" or #name > 100 then
        return nil
    end
    if not name:find("-", 1, true) then
        name = name .. "-" .. GetNormalizedRealmName()
    end
    return name:gsub("%s", "")
end

function Games:PlayerName(unit)
    local name, realm = UnitFullName(unit or "player")
    if not name then
        return nil
    end
    return self:NormalizeName(name .. "-" .. ((realm and realm ~= "") and realm or GetNormalizedRealmName()))
end

function Games:GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid() then
        return "RAID"
    end
    if IsInGroup() then
        return "PARTY"
    end
end

function Games:Roster()
    local roster = { [self:PlayerName()] = true }
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = self:PlayerName("raid" .. i)
            if name then
                roster[name] = true
            end
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            local name = self:PlayerName("party" .. i)
            if name then
                roster[name] = true
            end
        end
    end
    return roster
end

function Games.Copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = Games.Copy(item)
    end
    return result
end

function Games:RegisterGame(game)
    assert(type(game) == "table", "RegisterGame expects a table")
    assert(type(game.id) == "string" and #game.id <= 32 and game.id:match("^[%w_%-]+$"), "Invalid game id")
    assert(not self.Registry[game.id], "Game already registered: " .. game.id)
    assert(type(game.title) == "string" and #game.title > 0 and #game.title <= 80, "Invalid game title")
    assert(type(game.version) == "string" and #game.version > 0 and #game.version <= 32, "Game version required")
    assert(type(game.OnStart) == "function", "Game OnStart callback required")
    game.minPlayers = game.minPlayers or 2
    game.maxPlayers = game.maxPlayers or 5
    assert(
        game.minPlayers >= 1
            and game.minPlayers % 1 == 0
            and game.maxPlayers % 1 == 0
            and game.maxPlayers >= game.minPlayers
            and game.maxPlayers <= self.MAX_PLAYERS,
        "Games support 1-5 players"
    )
    for _, hook in ipairs({ "CreateUI", "OnStop", "OnMessage", "OnSyncRequested", "OnPlayersChanged" }) do
        assert(game[hook] == nil or type(game[hook]) == "function", "Invalid callback: " .. hook)
    end
    self.Registry[game.id] = game
    self:Changed()
end

function Games:GetGames()
    local list = {}
    for _, game in pairs(self.Registry) do
        list[#list + 1] = game
    end
    table.sort(list, function(a, b)
        return a.title < b.title
    end)
    return list
end

function Games:GetSession()
    return self.Copy(self.Lobby)
end

function Games:IsHost()
    return self.Lobby and self.Lobby.host == self:PlayerName() or false
end

function Games:Compatible(lobby)
    local game = self.Registry[lobby.gameID]
    return game and game.version == lobby.gameVersion
end

function Games:CallGame(hook, ...)
    local active = self.ActiveGame
    if not active or type(active.game[hook]) ~= "function" then
        return
    end
    local ok, result = pcall(active.game[hook], active.context, ...)
    if not ok then
        self:Notify(active.game.title .. " / " .. hook .. ": " .. tostring(result))
        return false
    end
    return true, result
end

function Games:StopModule(reason)
    local active = self.ActiveGame
    if not active then
        return
    end
    -- Detach before invoking module code so an OnStop hook can safely end the round.
    self.ActiveGame = nil
    if active.game.OnStop then
        local ok, err = pcall(active.game.OnStop, active.context, reason)
        if not ok then
            self:Notify(active.game.title .. " / OnStop: " .. tostring(err))
        end
    end
    if active.frame then
        active.frame:Hide()
    end
end

function Games:StartModule(restored)
    local lobby = self.Lobby
    if not lobby or not self:Compatible(lobby) then
        return
    end
    self:StopModule("restart")
    local game = self.Registry[lobby.gameID]
    local sessionID, run = lobby.id, lobby.run
    local function current()
        return Games.Lobby
            and Games.Lobby.id == sessionID
            and Games.Lobby.run == run
            and Games.Lobby.status == "running"
    end
    local context = {
        isHost = self:IsHost(),
        player = self:PlayerName(),
        GetSession = function()
            return current() and Games:GetSession() or nil
        end,
        SendAction = function(_, event, data)
            if not current() then
                return false, "This game has ended."
            end
            return Games:SendGameAction(event, data)
        end,
        SendState = function(_, event, data, target)
            if not current() then
                return false, "This game has ended."
            end
            return Games:SendGameState(event, data, target)
        end,
        EndGame = function()
            if current() then
                return Games:ReturnToLobby()
            end
            return false
        end,
        Show = function()
            if current() then
                Games.UI:ShowGame()
            end
        end,
    }
    self.ActiveGame = { game = game, context = context }
    if game.CreateUI then
        local ok, frame = self:CallGame("CreateUI", self.UI:GetGameContainer())
        if not ok then
            self:StopModule("error")
            return
        end
        self.ActiveGame.frame = frame
    end
    if not self:CallGame("OnStart", self:GetSession(), restored == true) then
        self:StopModule("error")
        return
    end
    if not self.ActiveGame or not self.Lobby or self.Lobby.status ~= "running" then
        return
    end
    self.UI:ShowGame()
    if not self:IsHost() then
        self:Send("GAME_SYNC", { id = lobby.id, run = lobby.run, target = lobby.host })
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        if type(KICGamesDB) ~= "table" then
            KICGamesDB = {}
        end
        Games.DB = KICGamesDB
        Games.DB.minimapAngle = tonumber(Games.DB.minimapAngle) or 220
    elseif event == "PLAYER_LOGIN" then
        Games:InitializeCommunication()
        Games.UI:Initialize()
        SLASH_KICGAMES1 = "/kicgames"
        SLASH_KICGAMES2 = "/kicgame"
        SlashCmdList.KICGAMES = function(text)
            if text:lower():match("^%s*refresh%s*$") then
                Games:Discover()
            elseif text:lower():match("^%s*leave%s*$") then
                Games:LeaveLobby()
            else
                Games.UI:Toggle()
            end
        end
        Games.Ticker = C_Timer.NewTicker(15, function()
            Games:Tick()
        end)
    elseif event == "GROUP_ROSTER_UPDATE" and Games.Comm then
        Games:GroupChanged()
    end
end)
