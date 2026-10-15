local _, Games = ...
local serial = 0

local function text(value, max)
    return type(value) == "string" and #value <= max
end

local function integer(value, min, max)
    return type(value) == "number" and value % 1 == 0 and value >= min and value <= max
end

local function member(lobby, name)
    if not lobby then
        return
    end
    for _, entry in ipairs(lobby.members) do
        if entry.name == name then
            return entry
        end
    end
end

local function sameMembers(a, b)
    if #a.members ~= #b.members then
        return false
    end
    for i, entry in ipairs(a.members) do
        if entry.name ~= b.members[i].name then
            return false
        end
    end
    return true
end

function Games:LocalMember()
    return member(self.Lobby, self:PlayerName())
end

function Games:InvalidateReadiness()
    self.Lobby.epoch = self.Lobby.epoch + 1
    for _, entry in ipairs(self.Lobby.members) do
        entry.ready = false
    end
end

function Games:PublishLobby()
    if not self:IsHost() then
        return
    end
    self.Lobby.revision = self.Lobby.revision + 1
    if self.Lobby.mode == "multiplayer" then
        local game = self.Registry[self.Lobby.gameID]
        self.Lobby.gameTitle = game and game.title or ""
        self.Lobby.maxPlayers = game and game.maxPlayers or self.MAX_PLAYERS
        self:UpdateListing(self.Lobby)
        self:Send("SNAPSHOT", self:GetSession())
    end
    self:Changed()
end

function Games:CreateLobby(gameID)
    if self.Lobby or self.Pending then
        return false, "Leave the current lobby first."
    end
    local channel = self:GroupChannel()
    if not channel then
        return false, "Join a party first."
    end
    local game = gameID and self.Registry[gameID]
    if gameID and (not game or game.mode ~= "multiplayer") then
        return false, "Choose a multiplayer game."
    end
    serial = serial + 1
    self.Lobby = {
        id = UnitGUID("player") .. ":" .. GetServerTime() .. ":" .. serial,
        host = self:PlayerName(),
        channel = channel,
        revision = 0,
        run = 0,
        epoch = 0,
        startedAt = 0,
        mode = "multiplayer",
        countdownToken = 0,
        gameID = game and game.id or "",
        gameVersion = game and game.version or "",
        status = "waiting",
        members = { { name = self:PlayerName(), ready = false, version = game and game.version or "" } },
    }
    self:PublishLobby()
    return true
end

function Games:StartSingleplayer(gameID)
    local game = self.Registry[gameID]
    if not game or game.mode ~= "singleplayer" then
        return false, "Choose a singleplayer game."
    end
    if self.Pending or (self.Lobby and (self.Lobby.mode ~= "singleplayer" or self.Lobby.status ~= "waiting")) then
        return false, "Leave or stop the current session first."
    end
    if self.Lobby then
        self:ResetLobby("new_solo")
    end
    serial = serial + 1
    self.Lobby = {
        id = UnitGUID("player") .. ":" .. GetServerTime() .. ":" .. serial,
        mode = "singleplayer",
        host = self:PlayerName(),
        revision = 0,
        run = 0,
        epoch = 0,
        countdownToken = 0,
        startedAt = 0,
        status = "waiting",
        gameID = game.id,
        gameVersion = game.version,
        gameTitle = game.title,
        maxPlayers = 1,
        members = { { name = self:PlayerName(), ready = true, version = game.version } },
    }
    return self:LaunchGame()
end

function Games:UpdateListing(data)
    local previous = self.Listings[data.host]
    if
        previous
        and previous.id == data.id
        and (data.revision < previous.revision or data.countdownToken < previous.countdownToken)
    then
        return false
    end
    self.Listings[data.host] = {
        id = data.id,
        host = data.host,
        gameID = data.gameID,
        gameTitle = data.gameTitle,
        gameVersion = data.gameVersion,
        status = data.status,
        count = #data.members,
        max = data.maxPlayers,
        seen = GetTime(),
        rejoin = member(data, self:PlayerName()) ~= nil,
        revision = data.revision,
        countdownToken = data.countdownToken,
    }
    return true
end

function Games:SelectGame(id)
    if not self:IsHost() or (self.Lobby.status ~= "waiting" and self.Lobby.status ~= "countdown") then
        return false, "Only the host can select a game in the lobby."
    end
    local game = self.Registry[id]
    if not game or game.mode ~= self.Lobby.mode then
        return false, "This game is not installed."
    end
    if self.Lobby.gameID == id and self.Lobby.gameVersion == game.version then
        return true
    end
    if #self.Lobby.members > game.maxPlayers then
        return false, "Too many players for this game."
    end
    if self.Lobby.status == "countdown" then
        self:CancelCountdown(true)
    end
    self.Lobby.gameID, self.Lobby.gameVersion = id, game.version
    self.Lobby.result = nil
    self:InvalidateReadiness()
    for _, entry in ipairs(self.Lobby.members) do
        entry.version = entry.name == self:PlayerName() and game.version or ""
    end
    self:PublishLobby()
    return true
end

function Games:Discover()
    if self.LastDiscover and GetTime() - self.LastDiscover < 5 then
        return
    end
    self.LastDiscover = GetTime()
    self:Send("DISCOVER", {})
    self:Changed()
end

function Games:JoinLobby(host, id)
    if self.Lobby or self.Pending then
        return false, "Leave the current lobby first."
    end
    local listing = self.Listings[host]
    if not listing or listing.id ~= id or not self:Roster()[host] then
        return false, "This lobby is no longer available."
    end
    if listing.status == "running" and not listing.rejoin then
        return false, "This game has already started."
    end
    self.JoinSerial = (self.JoinSerial or 0) + 1
    local request = UnitGUID("player") .. ":" .. GetServerTime() .. ":" .. self.JoinSerial
    self.Pending = { host = host, id = id, at = GetTime(), request = request }
    local game = self.Registry[listing.gameID]
    local ok, err = self:Send(
        "JOIN",
        { target = host, id = id, gameID = listing.gameID, version = game and game.version or "", request = request }
    )
    if not ok then
        self.Pending = nil
    end
    self:Changed()
    return ok, err
end

function Games:ResetLobby(reason)
    self:ClearCountdownTimer()
    if self.Lobby and self.Lobby.status == "running" and reason ~= "reload" then
        local result = self:BuildResult("aborted", reason)
        if result then
            result.provisional = true
            self:RecordResult(result)
        end
    end
    self.Lobby, self.Pending, self.LastSnapshot = nil, nil, nil
    self.StoppedRound = nil
    self.PendingAbort = nil
    self:StopModule(reason)
    self:Changed()
end

function Games:LeaveLobby()
    local lobby, pending = self.Lobby, self.Pending
    if lobby then
        if lobby.status == "countdown" and self:IsHost() then
            self:CancelCountdown(true, true)
        end
        if self:IsHost() and lobby.status == "running" then
            self:FinishRound("aborted", "closed")
            if self.Lobby ~= lobby then
                return
            end
        end
        if lobby.mode == "multiplayer" then
            self:Send(self:IsHost() and "CLOSE" or "LEAVE", {
                id = lobby.id,
                target = not self:IsHost() and lobby.host or nil,
                request = self:LocalMember() and self:LocalMember().request,
            })
        end
        self.Listings[lobby.host] = nil
    elseif pending then
        self:Send("LEAVE", { id = pending.id, target = pending.host, request = pending.request })
    end
    self:ResetLobby("left")
end

function Games:Ready(value)
    if
        not self.Lobby
        or (self.Lobby.status ~= "waiting" and self.Lobby.status ~= "countdown")
        or not self:Compatible(self.Lobby)
    then
        return false, "Install the selected game and matching version first."
    end
    if self.Lobby.status == "countdown" and value == true then
        return true
    end
    if self:IsHost() then
        self:LocalMember().ready = value == true
        if self.Lobby.status == "countdown" then
            self:CancelCountdown(false)
        end
        self:PublishLobby()
        self:MaybeStartCountdown()
        return true
    end
    if self.Lobby.status == "countdown" and value ~= true then
        self:LocalMember().ready = false
        self.StoppedRound = { id = self.Lobby.id, run = self.Lobby.run + 1, token = self.Lobby.countdownToken }
        self.PendingAbort = { id = self.Lobby.id, run = self.Lobby.run + 1, token = self.Lobby.countdownToken }
        self:SendControl(
            "UNREADY",
            { id = self.Lobby.id, run = self.Lobby.run, token = self.Lobby.countdownToken, epoch = self.Lobby.epoch }
        )
        self:Changed()
    end
    return self:Send("READY", {
        target = self.Lobby.host,
        id = self.Lobby.id,
        gameID = self.Lobby.gameID,
        version = self.Lobby.gameVersion,
        epoch = self.Lobby.epoch,
        ready = value == true,
    })
end

function Games:CanStart()
    if not self:IsHost() or (self.Lobby.status ~= "waiting" and self.Lobby.status ~= "countdown") then
        return false, "Only the host can start."
    end
    local game = self.Registry[self.Lobby.gameID]
    if not game then
        return false, "Choose an installed game first."
    end
    if #self.Lobby.members < game.minPlayers then
        return false, "Waiting for more players."
    end
    if #self.Lobby.members > game.maxPlayers then
        return false, "Too many players."
    end
    for _, entry in ipairs(self.Lobby.members) do
        if not entry.ready or entry.version ~= game.version then
            return false, "Every player must have the game and be ready."
        end
    end
    return true
end

function Games:StartGame()
    if self.Lobby and self.Lobby.mode == "singleplayer" then
        return self:LaunchGame()
    end
    return self:BeginCountdown()
end

function Games:LaunchGame()
    local ok, err = self:CanStart()
    if not ok then
        return false, err
    end
    local lobby = self.Lobby
    self.Lobby.status = "running"
    self.Lobby.run = self.Lobby.run + 1
    self.Lobby.startedAt = GetServerTime()
    self.Lobby.countdownAt = nil
    self.Lobby.countdownHide = nil
    self.Lobby.result, self.StoppedRound = nil, nil
    self:PublishLobby()
    local started = self:StartModule(false)
    if started == false then
        if self.Lobby == lobby and lobby.status == "running" then
            self:FinishRound("aborted", "error")
        end
        return false, "The game module could not start."
    end
    return true
end

function Games:ReturnToLobby()
    return self:FinishRound("aborted", "host_end")
end

function Games:RemoveMember(name)
    if not self:IsHost() or name == self.Lobby.host then
        return
    end
    local lobby, run = self.Lobby, self.Lobby.run
    for i, entry in ipairs(lobby.members) do
        if entry.name == name then
            if self.Lobby.status == "countdown" then
                self:CancelCountdown(true, true)
            end
            if self.Lobby.status == "running" then
                self:FinishRound("aborted", "player_left", nil, name)
                if self.Lobby ~= lobby or lobby.run ~= run then
                    return
                end
            end
            table.remove(self.Lobby.members, i)
            self:InvalidateReadiness()
            self:PublishLobby()
            return
        end
    end
end

function Games:ValidSnapshot(data, sender)
    if
        not text(data.id, 100)
        or data.id == ""
        or data.host ~= sender
        or data.channel ~= self:GroupChannel()
        or data.mode ~= "multiplayer"
        or not text(data.gameTitle, 80)
        or not integer(data.maxPlayers, 1, self.MAX_PLAYERS)
        or not text(data.gameID, 32)
        or not text(data.gameVersion, 32)
        or not integer(data.revision, 0, 2147483647)
        or not integer(data.run, 0, 2147483647)
        or not integer(data.epoch, 0, 2147483647)
        or not integer(data.startedAt, 0, 9999999999)
        or not integer(data.countdownToken, 0, 2147483647)
        or (data.status ~= "waiting" and data.status ~= "countdown" and data.status ~= "running")
        or not self:IsArray(data.members)
        or #data.members < 1
        or #data.members > self.MAX_PLAYERS
    then
        return false
    end
    if #data.members > data.maxPlayers then
        return false
    end
    if data.status == "countdown" and (not integer(data.countdownAt, 0, 9999999999) or data.gameID == "") then
        return false
    end
    if data.status ~= "countdown" and data.countdownAt ~= nil then
        return false
    end
    if data.countdownHide ~= nil and (data.status ~= "waiting" or type(data.countdownHide) ~= "boolean") then
        return false
    end
    if data.status == "running" and (data.gameID == "" or data.run == 0) then
        return false
    end
    if data.result ~= nil and (data.status ~= "waiting" or not self:ValidResult(data.result, data)) then
        return false
    end
    local roster, names = self:Roster(), {}
    for _, entry in ipairs(data.members) do
        if
            type(entry) ~= "table"
            or not text(entry.name, 100)
            or not roster[entry.name]
            or names[entry.name]
            or type(entry.ready) ~= "boolean"
            or not text(entry.version, 32)
            or (entry.request ~= nil and (not text(entry.request, 100) or entry.request == ""))
        then
            return false
        end
        names[entry.name] = true
    end
    return names[sender] == true
end

function Games:AcceptSnapshot(data, sender)
    if not self:ValidSnapshot(data, sender) then
        return
    end
    local game = self.Registry[data.gameID]
    if not self:UpdateListing(data) then
        return
    end
    local old = self.Lobby
    local relevant = old and old.id == data.id and old.host == sender
        or self.Pending and self.Pending.id == data.id and self.Pending.host == sender
    if not relevant then
        -- A player who left immediately can still receive the host's final result.
        local last = self.LastResult
        if last and last.provisional and data.result and last.id == data.result.id and last.host == sender then
            self:RecordResult(data.result)
        end
        self:Changed()
        return
    end
    if self.Pending then
        local own = member(data, self:PlayerName())
        -- An earlier roster containing us must not acknowledge a new join request.
        if not own or own.request ~= self.Pending.request then
            return
        end
    end
    if old and (data.revision < old.revision or data.countdownToken < old.countdownToken) then
        return
    end
    if
        self:IsRoundStopped()
        and (
            (data.status == "running" and data.run == self.StoppedRound.run)
            or (
                data.status == "countdown"
                and data.run + 1 == self.StoppedRound.run
                and (not self.StoppedRound.token or data.countdownToken == self.StoppedRound.token)
            )
        )
    then
        -- An older running heartbeat cannot reopen a locally interrupted match.
        self.LastSnapshot = GetTime()
        return
    end
    if not member(data, self:PlayerName()) then
        if old then
            self:ResetLobby("removed")
        end
        return
    end
    self.Lobby, self.Pending, self.LastSnapshot = self.Copy(data), nil, GetTime()
    local accepted = self.Lobby
    if data.result then
        self:RecordResult(data.result)
        self:CallGame("OnResult", self.Copy(data.result))
        if self.Lobby ~= accepted then
            return
        end
    end
    if self.StoppedRound and self.StoppedRound.run < data.run then
        self.StoppedRound = nil
    end
    local changedGame = not old or old.gameID ~= data.gameID or old.gameVersion ~= data.gameVersion
    if data.status == "waiting" then
        self.PendingAbort = nil
        self.StoppedRound = nil
        self:StopModule(data.result and data.result.status or "lobby")
        if self.Lobby ~= accepted then
            return
        end
        if old and old.status == "running" and data.result and data.result.status == "aborted" then
            self.UI:HideAll()
        end
        if old and old.status == "countdown" and data.countdownHide then
            self.UI:HideAll()
        end
        local own = self:LocalMember()
        local version = game and game.version or ""
        if own.version ~= version then
            self:Send(
                "SUPPORT",
                { target = sender, id = data.id, gameID = data.gameID, epoch = data.epoch, version = version }
            )
        end
    elseif data.status == "countdown" then
        self:ShowCountdown()
    elseif not self.ActiveGame or changedGame or not old or old.run ~= data.run then
        self:StartModule(not old or old.status == "running")
    elseif not sameMembers(old, data) then
        self:CallGame("OnPlayersChanged", self:GetSession())
    end
    self:Changed()
end

function Games:SendGameAction(event, payload)
    if
        not self.Lobby
        or self.Lobby.status ~= "running"
        or self:IsRoundStopped()
        or not text(event, 40)
        or event == ""
    then
        return false, "No running game or invalid event."
    end
    if not self:ValidData(payload) then
        return false, "Invalid game data."
    end
    if self:IsHost() then
        self:CallGame("OnMessage", event, self.Copy(payload), self:PlayerName(), "action")
        return true
    end
    return self:Send("GAME_ACTION", {
        target = self.Lobby.host,
        id = self.Lobby.id,
        run = self.Lobby.run,
        gameID = self.Lobby.gameID,
        gameVersion = self.Lobby.gameVersion,
        event = event,
        payload = payload,
    })
end

function Games:SendGameState(event, payload, target)
    if
        not self:IsHost()
        or self.Lobby.status ~= "running"
        or self:IsRoundStopped()
        or not text(event, 40)
        or event == ""
    then
        return false, "Only the running game's host can publish state."
    end
    if target and not member(self.Lobby, target) then
        return false, "Player is not in this game."
    end
    if self.Lobby.mode == "singleplayer" then
        if not self:ValidData(payload) then
            return false, "Invalid game data."
        end
        self:CallGame("OnMessage", event, self.Copy(payload), self:PlayerName(), "state")
        return true
    end
    local ok, err = self:Send("GAME_STATE", {
        target = target,
        id = self.Lobby.id,
        run = self.Lobby.run,
        gameID = self.Lobby.gameID,
        gameVersion = self.Lobby.gameVersion,
        event = event,
        payload = payload,
    })
    if ok and (not target or target == self:PlayerName()) then
        self:CallGame("OnMessage", event, self.Copy(payload), self:PlayerName(), "state")
    end
    return ok, err
end

function Games:Receive(kind, data, sender)
    if data.target and data.target ~= self:PlayerName() then
        return
    end
    if kind == "DISCOVER" then
        if self:IsHost() then
            if not self.LastDiscoveryResponse or GetTime() - self.LastDiscoveryResponse >= 2 then
                self.LastDiscoveryResponse = GetTime()
                self:PublishLobby()
            end
        end
        return
    elseif kind == "SNAPSHOT" then
        self:AcceptSnapshot(data, sender)
        return
    elseif kind == "CLOSE" then
        local listing = self.Listings[sender]
        if listing and listing.id == data.id then
            self.Listings[sender] = nil
        end
        if
            self.Lobby and self.Lobby.host == sender and self.Lobby.id == data.id
            or self.Pending and self.Pending.host == sender and self.Pending.id == data.id
        then
            self:ResetLobby("closed")
            self:Notify("The host closed the lobby.")
        end
        self:Changed()
        return
    elseif kind == "REJECT" then
        if
            self.Pending
            and self.Pending.host == sender
            and self.Pending.id == data.id
            and (data.request == nil or data.request == self.Pending.request)
        then
            self.Pending = nil
            self:Notify(text(data.reason, 120) and data.reason or "Unable to join this lobby.")
            self:Changed()
        end
        return
    end
    local lobby = self.Lobby
    if not lobby or lobby.mode ~= "multiplayer" or data.id ~= lobby.id then
        return
    end
    if kind == "JOIN" and self:IsHost() then
        if not text(data.request, 100) or data.request == "" then
            return
        end
        local existing = member(lobby, sender)
        local game = self.Registry[lobby.gameID]
        local max = game and game.maxPlayers or self.MAX_PLAYERS
        if not existing and ((lobby.status ~= "waiting" and lobby.status ~= "countdown") or #lobby.members >= max) then
            self:Send("REJECT", {
                target = sender,
                id = lobby.id,
                request = data.request,
                reason = "The lobby is full or the game has started.",
            })
        else
            if not existing then
                if lobby.status == "countdown" then
                    self:CancelCountdown(true)
                end
                lobby.members[#lobby.members + 1] = {
                    name = sender,
                    ready = false,
                    version = data.gameID == lobby.gameID and text(data.version, 32) and data.version or "",
                    request = data.request,
                }
                self:InvalidateReadiness()
            else
                if existing.request ~= data.request and lobby.status ~= "running" then
                    if lobby.status == "countdown" then
                        self:CancelCountdown(true)
                    else
                        self:InvalidateReadiness()
                    end
                    existing.version = data.gameID == lobby.gameID and text(data.version, 32) and data.version or ""
                end
                existing.request = data.request
            end
            self:PublishLobby()
        end
    elseif kind == "LEAVE" and self:IsHost() then
        local entry = member(lobby, sender)
        if entry and entry.request == data.request then
            self:RemoveMember(sender)
        end
    elseif
        (kind == "READY" or kind == "SUPPORT")
        and self:IsHost()
        and (lobby.status == "waiting" or lobby.status == "countdown")
    then
        local entry = member(lobby, sender)
        if not entry or data.gameID ~= lobby.gameID or data.epoch ~= lobby.epoch or not text(data.version, 32) then
            return
        end
        if kind == "SUPPORT" then
            if entry.version == data.version then
                return
            end
            entry.version, entry.ready = data.version, false
        else
            if data.version ~= lobby.gameVersion or type(data.ready) ~= "boolean" then
                return
            end
            entry.ready, entry.version = data.ready, data.version
        end
        if lobby.status == "countdown" and (not entry.ready or entry.version ~= lobby.gameVersion) then
            self:CancelCountdown(false)
        end
        self:PublishLobby()
        self:MaybeStartCountdown()
    elseif
        lobby.status == "running"
        and not self:IsRoundStopped()
        and data.run == lobby.run
        and data.gameID == lobby.gameID
        and data.gameVersion == lobby.gameVersion
        and member(lobby, sender)
    then
        if kind == "GAME_SYNC" and self:IsHost() then
            self:CallGame("OnSyncRequested", sender)
        elseif text(data.event, 40) and data.event ~= "" then
            if kind == "GAME_ACTION" and self:IsHost() then
                self:CallGame("OnMessage", data.event, data.payload, sender, "action")
            elseif kind == "GAME_STATE" and sender == lobby.host then
                self:CallGame("OnMessage", data.event, data.payload, sender, "state")
            end
        end
    end
end

function Games:GroupChanged()
    local roster, channel = self:Roster(), self:GroupChannel()
    for host in pairs(self.Listings) do
        if not roster[host] then
            self.Listings[host] = nil
        end
    end
    if self.Pending and not roster[self.Pending.host] then
        self.Pending = nil
    end
    if self.Lobby then
        if self.Lobby.mode == "singleplayer" then
            self:Changed()
            return
        end
        if channel ~= self.Lobby.channel or not roster[self.Lobby.host] then
            self:ResetLobby("group_changed")
            self.Listings = {}
        elseif self:IsHost() then
            local departed = {}
            for _, entry in ipairs(self.Lobby.members) do
                if not roster[entry.name] then
                    departed[#departed + 1] = entry.name
                end
            end
            for _, name in ipairs(departed) do
                self:RemoveMember(name)
            end
        end
    end
    self:Changed()
end

function Games:Tick()
    local now = GetTime()
    if
        self.PendingAbort
        and self.Lobby
        and (self.Lobby.status == "running" or self.Lobby.status == "countdown")
        and self:IsRoundStopped()
    then
        pcall(self.SendControl, self, "ABORT", self.PendingAbort)
    end
    for host, listing in pairs(self.Listings) do
        if now - listing.seen > 60 then
            self.Listings[host] = nil
        end
    end
    if self.Pending and now - self.Pending.at > 20 then
        -- Cancel on the host too; a delayed acceptance must not occupy a slot.
        self:Send("LEAVE", { target = self.Pending.host, id = self.Pending.id, request = self.Pending.request })
        self.Pending = nil
        self:Notify("Joining timed out. Refresh the list and try again.")
    end
    if self:IsHost() then
        self:PublishLobby()
    elseif self.Lobby and self.LastSnapshot and now - self.LastSnapshot > 90 then
        self:ResetLobby("host_timeout")
        self:Notify("The host is no longer responding.")
    end
    self:Changed()
end
