local addonName, Games = ...
_G.KICGames = Games

Games.VERSION = "0.11.0"
Games.API_VERSION = 3
Games.PREFIX = "KICGames3"
Games.CONTROL_PREFIX = "KICGames3Ctl"
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
    assert(type(game.CreateUI) == "function", "Every game module must provide its own CreateUI callback")
    game.mode = game.mode or "multiplayer"
    assert(game.mode == "singleplayer" or game.mode == "multiplayer", "Invalid game mode")
    game.minPlayers = game.minPlayers or (game.mode == "singleplayer" and 1 or 2)
    game.maxPlayers = game.maxPlayers or (game.mode == "singleplayer" and 1 or 5)
    assert(
        game.minPlayers >= 1
            and game.minPlayers % 1 == 0
            and game.maxPlayers % 1 == 0
            and game.maxPlayers >= game.minPlayers
            and game.maxPlayers <= self.MAX_PLAYERS,
        "Games support 1-5 players"
    )
    assert(
        game.mode ~= "singleplayer" or (game.minPlayers == 1 and game.maxPlayers == 1),
        "Singleplayer games require exactly one player"
    )
    for _, hook in ipairs({ "OnStop", "OnMessage", "OnSyncRequested", "OnPlayersChanged", "OnResult" }) do
        assert(game[hook] == nil or type(game[hook]) == "function", "Invalid callback: " .. hook)
    end
    self.Registry[game.id] = game
    self:Changed()
end

function Games:GetGames(mode)
    local list = {}
    for _, game in pairs(self.Registry) do
        if not mode or game.mode == mode then
            list[#list + 1] = game
        end
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
    return game and game.version == lobby.gameVersion and game.mode == lobby.mode
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
    -- Detach before hooks so teardown cannot dispatch another game action.
    self.ActiveGame = nil
    if active.frame then
        active.frame:Hide()
    end
    for timer in pairs(active.timers) do
        timer:Cancel()
    end
    if active.game.OnStop then
        local ok, err = pcall(active.game.OnStop, active.context, reason)
        if not ok then
            self:Notify(active.game.title .. " / OnStop: " .. tostring(err))
        end
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
    local active
    local function current()
        return Games.Lobby
            and Games.Lobby.id == sessionID
            and Games.Lobby.run == run
            and Games.Lobby.status == "running"
            and not Games:IsRoundStopped()
            and Games.ActiveGame == active
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
        FinishGame = function(_, result)
            if current() then
                return Games:FinishGame(result)
            end
            return false
        end,
        AbortGame = function()
            if current() then
                return Games:AbortGame()
            end
            return false
        end,
        Show = function()
            if current() then
                Games.UI:ShowGame()
            end
        end,
    }
    -- EndGame remains an alias for a normal completion; manual stopping uses AbortGame.
    context.EndGame = context.FinishGame
    active = { game = game, context = context, timers = {} }
    self.ActiveGame = active
    local function timer(seconds, callback, repeating)
        if
            not current()
            or type(seconds) ~= "number"
            or seconds ~= seconds
            or seconds <= 0
            or seconds > 3600
            or type(callback) ~= "function"
        then
            return nil, "Invalid timer or ended game."
        end
        local handle
        local function fire()
            if not repeating then
                active.timers[handle] = nil
            end
            if not current() then
                return
            end
            local ok, err = pcall(callback, context)
            if not ok then
                Games:Notify(game.title .. " / timer: " .. tostring(err))
            end
        end
        handle = (repeating and C_Timer.NewTicker or C_Timer.NewTimer)(seconds, fire)
        active.timers[handle] = true
        return handle
    end
    context.NewTicker = function(_, seconds, callback)
        return timer(seconds, callback, true)
    end
    context.After = function(_, seconds, callback)
        return timer(seconds, callback, false)
    end
    if game.CreateUI then
        local ok, frame = self:CallGame("CreateUI", self.UI:GetGameContainer())
        if not ok then
            self:StopModule("error")
            return
        end
        if self.ActiveGame ~= active then
            if frame then
                frame:Hide()
            end
            return
        end
        if (type(frame) ~= "table" and type(frame) ~= "userdata") or type(frame.Hide) ~= "function" then
            self:Notify(game.title .. " / CreateUI: return the module's root frame.")
            self:StopModule("error")
            return
        end
        active.frame = frame
    end
    if not self:CallGame("OnStart", self:GetSession(), restored == true) then
        self:StopModule("error")
        return
    end
    if not self.ActiveGame or not self.Lobby or self.Lobby.status ~= "running" then
        return
    end
    self:RecordGameLaunch(game.id)
    self.UI:ShowGame()
    if not self:IsHost() and lobby.mode == "multiplayer" then
        self:Send("GAME_SYNC", {
            id = lobby.id,
            run = lobby.run,
            target = lobby.host,
            gameID = lobby.gameID,
            gameVersion = lobby.gameVersion,
        })
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
        Games:InitializeResults()
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
            elseif text:lower():match("^%s*stop%s*$") or text:lower():match("^%s*abort%s*$") then
                Games:AbortGame()
            elseif text:lower():match("^%s*results%s*$") then
                Games.UI:ShowResults()
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
