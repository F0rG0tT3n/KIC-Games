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

function Games:PublishLobby()
    if not self:IsHost() then
        return
    end
    self.Lobby.revision = self.Lobby.revision + 1
    self:Send("SNAPSHOT", self:GetSession())
    self:Changed()
end

function Games:CreateLobby()
    if self.Lobby or self.Pending then
        return false, "Leave the current lobby first."
    end
    local channel = self:GroupChannel()
    if not channel then
        return false, "Join a party first."
    end
    serial = serial + 1
    self.Lobby = {
        id = UnitGUID("player") .. ":" .. GetServerTime() .. ":" .. serial,
        host = self:PlayerName(),
        channel = channel,
        revision = 0,
        run = 0,
        epoch = 0,
        gameID = "",
        gameVersion = "",
        status = "waiting",
        members = { { name = self:PlayerName(), ready = false, version = "" } },
    }
    self:PublishLobby()
    return true
end

function Games:SelectGame(id)
    if not self:IsHost() or self.Lobby.status ~= "waiting" then
        return false, "Only the host can select a game in the lobby."
    end
    local game = self.Registry[id]
    if not game then
        return false, "This game is not installed."
    end
    if #self.Lobby.members > game.maxPlayers then
        return false, "Too many players for this game."
    end
    self.Lobby.gameID, self.Lobby.gameVersion = id, game.version
    self.Lobby.epoch = self.Lobby.epoch + 1
    for _, entry in ipairs(self.Lobby.members) do
        entry.ready = false
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
    self.Pending = { host = host, id = id, at = GetTime() }
    local game = self.Registry[listing.gameID]
    local ok, err =
        self:Send("JOIN", { target = host, id = id, gameID = listing.gameID, version = game and game.version or "" })
    if not ok then
        self.Pending = nil
    end
    self:Changed()
    return ok, err
end

function Games:ResetLobby(reason)
    self:StopModule(reason)
    self.Lobby, self.Pending, self.LastSnapshot = nil, nil, nil
    self:Changed()
end

function Games:LeaveLobby()
    local lobby, pending = self.Lobby, self.Pending
    if lobby then
        self:Send(
            self:IsHost() and "CLOSE" or "LEAVE",
            { id = lobby.id, target = not self:IsHost() and lobby.host or nil }
        )
    elseif pending then
        self:Send("LEAVE", { id = pending.id, target = pending.host })
    end
    self:ResetLobby("left")
end

function Games:Ready(value)
    if not self.Lobby or self.Lobby.status ~= "waiting" or not self:Compatible(self.Lobby) then
        return false, "Install the selected game and matching version first."
    end
    if self:IsHost() then
        self:LocalMember().ready = value == true
        self:PublishLobby()
        return true
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
    if not self:IsHost() or self.Lobby.status ~= "waiting" then
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
    local ok, err = self:CanStart()
    if not ok then
        return false, err
    end
    self.Lobby.status = "running"
    self.Lobby.run = self.Lobby.run + 1
    self:PublishLobby()
    self:StartModule(false)
    if not self.ActiveGame then
        self:ReturnToLobby()
    end
    return true
end

function Games:ReturnToLobby()
    if not self:IsHost() then
        return false, "Only the host can end the game."
    end
    self:StopModule("ended")
    self.Lobby.status = "waiting"
    self.Lobby.epoch = self.Lobby.epoch + 1
    for _, entry in ipairs(self.Lobby.members) do
        entry.ready = false
    end
    self:PublishLobby()
    return true
end

function Games:RemoveMember(name)
    if not self:IsHost() or name == self.Lobby.host then
        return
    end
    for i, entry in ipairs(self.Lobby.members) do
        if entry.name == name then
            table.remove(self.Lobby.members, i)
            if self.Lobby.status == "running" then
                self:ReturnToLobby()
            else
                self:PublishLobby()
            end
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
        or not text(data.gameID, 32)
        or not text(data.gameVersion, 32)
        or not integer(data.revision, 0, 2147483647)
        or not integer(data.run, 0, 2147483647)
        or not integer(data.epoch, 0, 2147483647)
        or (data.status ~= "waiting" and data.status ~= "running")
        or type(data.members) ~= "table"
        or #data.members < 1
        or #data.members > self.MAX_PLAYERS
    then
        return false
    end
    if data.status == "running" and (data.gameID == "" or data.run == 0) then
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
    self.Listings[sender] = {
        id = data.id,
        host = sender,
        gameID = data.gameID,
        gameVersion = data.gameVersion,
        status = data.status,
        count = #data.members,
        max = game and game.maxPlayers or self.MAX_PLAYERS,
        seen = GetTime(),
        rejoin = member(data, self:PlayerName()) ~= nil,
    }
    local old = self.Lobby
    local relevant = old and old.id == data.id and old.host == sender
        or self.Pending and self.Pending.id == data.id and self.Pending.host == sender
    if not relevant then
        self:Changed()
        return
    end
    if old and data.revision < old.revision then
        return
    end
    if not member(data, self:PlayerName()) then
        if old then
            self:ResetLobby("removed")
        end
        return
    end
    self.Lobby, self.Pending, self.LastSnapshot = self.Copy(data), nil, GetTime()
    local changedGame = not old or old.gameID ~= data.gameID or old.gameVersion ~= data.gameVersion
    if data.status == "waiting" then
        self:StopModule("lobby")
        local own = self:LocalMember()
        local version = game and game.version or ""
        if own.version ~= version then
            self:Send(
                "SUPPORT",
                { target = sender, id = data.id, gameID = data.gameID, epoch = data.epoch, version = version }
            )
        end
    elseif not self.ActiveGame or changedGame or not old or old.run ~= data.run then
        self:StartModule(not old or old.status == "running")
    elseif not sameMembers(old, data) then
        self:CallGame("OnPlayersChanged", self:GetSession())
    end
    self:Changed()
end

function Games:SendGameAction(event, payload)
    if not self.Lobby or self.Lobby.status ~= "running" or not text(event, 40) or event == "" then
        return false, "No running game or invalid event."
    end
    if not self:ValidData(payload) then
        return false, "Invalid game data."
    end
    if self:IsHost() then
        self:CallGame("OnMessage", event, self.Copy(payload), self:PlayerName(), "action")
        return true
    end
    return self:Send(
        "GAME_ACTION",
        { target = self.Lobby.host, id = self.Lobby.id, run = self.Lobby.run, event = event, payload = payload }
    )
end

function Games:SendGameState(event, payload, target)
    if not self:IsHost() or self.Lobby.status ~= "running" or not text(event, 40) or event == "" then
        return false, "Only the running game's host can publish state."
    end
    if target and not member(self.Lobby, target) then
        return false, "Player is not in this game."
    end
    local ok, err = self:Send(
        "GAME_STATE",
        { target = target, id = self.Lobby.id, run = self.Lobby.run, event = event, payload = payload }
    )
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
        if self.Pending and self.Pending.host == sender and self.Pending.id == data.id then
            self.Pending = nil
            self:Notify(text(data.reason, 120) and data.reason or "Unable to join this lobby.")
            self:Changed()
        end
        return
    end
    local lobby = self.Lobby
    if not lobby or data.id ~= lobby.id then
        return
    end
    if kind == "JOIN" and self:IsHost() then
        local existing = member(lobby, sender)
        local game = self.Registry[lobby.gameID]
        local max = game and game.maxPlayers or self.MAX_PLAYERS
        if not existing and (lobby.status ~= "waiting" or #lobby.members >= max) then
            self:Send(
                "REJECT",
                { target = sender, id = lobby.id, reason = "The lobby is full or the game has started." }
            )
        else
            if not existing then
                lobby.members[#lobby.members + 1] = {
                    name = sender,
                    ready = false,
                    version = data.gameID == lobby.gameID and text(data.version, 32) and data.version or "",
                }
            end
            self:PublishLobby()
        end
    elseif kind == "LEAVE" and self:IsHost() then
        self:RemoveMember(sender)
    elseif (kind == "READY" or kind == "SUPPORT") and self:IsHost() and lobby.status == "waiting" then
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
        self:PublishLobby()
    elseif lobby.status == "running" and data.run == lobby.run and member(lobby, sender) then
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
    for host, listing in pairs(self.Listings) do
        if now - listing.seen > 60 then
            self.Listings[host] = nil
        end
    end
    if self.Pending and now - self.Pending.at > 20 then
        -- Cancel on the host too; a delayed acceptance must not occupy a slot.
        self:Send("LEAVE", { target = self.Pending.host, id = self.Pending.id })
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
