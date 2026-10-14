local _, Games = ...
local LIMIT = 20
local function stringValue(value, limit)
    return type(value) == "string" and #value <= limit
end
local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function integer(value, min, max)
    return finite(value) and value % 1 == 0 and value >= min and value <= max
end
local function array(value)
    if type(value) ~= "table" then
        return false
    end
    local length = #value
    for key in pairs(value) do
        if not integer(key, 1, length) then
            return false
        end
    end
    for i = 1, length do
        if value[i] == nil then
            return false
        end
    end
    return true
end
local function includes(result, player)
    for _, entry in ipairs(result.entries) do
        if entry.player == player then
            return true
        end
    end
    return false
end

function Games:ValidResult(result, lobby)
    if
        type(result) ~= "table"
        or not self:ValidData(result)
        or not stringValue(result.id, 120)
        or not stringValue(result.sessionID, 100)
        or not stringValue(result.host, 100)
        or not stringValue(result.gameID, 32)
        or not stringValue(result.gameVersion, 32)
        or not stringValue(result.summary, 160)
        or not stringValue(result.reason, 40)
        or not integer(result.run, 1, 2147483647)
        or not integer(result.startedAt, 0, 9999999999)
        or not integer(result.endedAt, result.startedAt, 9999999999)
        or (result.provisional ~= nil and (type(result.provisional) ~= "boolean" or result.status ~= "aborted"))
        or result.id ~= result.sessionID .. ":" .. result.run
        or (result.status ~= "completed" and result.status ~= "aborted")
        or not array(result.entries)
        or #result.entries < 1
        or #result.entries > self.MAX_PLAYERS
    then
        return false
    end
    if
        lobby
        and (
            result.sessionID ~= lobby.id
            or result.host ~= lobby.host
            or result.run ~= lobby.run
            or result.gameID ~= lobby.gameID
            or result.gameVersion ~= lobby.gameVersion
            or result.provisional ~= nil
        )
    then
        return false
    end
    if result.abortedBy ~= nil and not stringValue(result.abortedBy, 100) then
        return false
    end
    local names = {}
    for _, entry in ipairs(result.entries) do
        if
            type(entry) ~= "table"
            or not stringValue(entry.player, 100)
            or names[entry.player]
            or (entry.score ~= nil and not finite(entry.score))
            or (entry.rank ~= nil and not integer(entry.rank, 1, self.MAX_PLAYERS))
            or (entry.outcome ~= nil and entry.outcome ~= "win" and entry.outcome ~= "loss" and entry.outcome ~= "draw")
        then
            return false
        end
        if result.status == "aborted" and (entry.score ~= nil or entry.rank ~= nil or entry.outcome ~= nil) then
            return false
        end
        names[entry.player] = true
    end
    return names[result.host] == true and (result.abortedBy == nil or names[result.abortedBy] == true)
end

function Games:InitializeResults()
    local results = {}
    for _, result in ipairs(type(self.DB.results) == "table" and self.DB.results or {}) do
        if #results >= LIMIT then
            break
        end
        if self:ValidResult(result) and includes(result, self:PlayerName()) then
            results[#results + 1] = self.Copy(result)
        end
    end
    self.DB.results = results
    self.LastResult = results[1]
end

function Games:GetResults(gameID)
    local results = {}
    for _, result in ipairs(self.DB.results) do
        if not gameID or result.gameID == gameID then
            results[#results + 1] = self.Copy(result)
        end
    end
    return results
end

function Games:GetResultStats(gameID)
    local stats = { completed = 0, aborted = 0, wins = 0, losses = 0, draws = 0 }
    for _, result in ipairs(self:GetResults(gameID)) do
        if result.status == "aborted" then
            stats.aborted = stats.aborted + 1
        else
            stats.completed = stats.completed + 1
            for _, entry in ipairs(result.entries) do
                if entry.player == self:PlayerName() then
                    if entry.outcome == "win" then
                        stats.wins = stats.wins + 1
                    elseif entry.outcome == "loss" then
                        stats.losses = stats.losses + 1
                    elseif entry.outcome == "draw" then
                        stats.draws = stats.draws + 1
                    end
                end
            end
        end
    end
    return stats
end

function Games:RecordResult(result)
    if not self:ValidResult(result) or not includes(result, self:PlayerName()) then
        return false
    end
    local history = self.DB.results
    for i, old in ipairs(history) do
        if old.id == result.id then
            -- A host's final result can replace a local interrupted/disconnect fallback.
            if not old.provisional or result.provisional then
                return true
            end
            history[i] = self.Copy(result)
            self.LastResult = history[1]
            return true
        end
    end
    table.insert(history, 1, self.Copy(result))
    while #history > LIMIT do
        table.remove(history)
    end
    self.LastResult = history[1]
    return true
end

function Games:BuildResult(status, reason, details, abortedBy)
    local lobby = self.Lobby
    if not lobby or lobby.run == 0 then
        return nil, "No match has started."
    end
    details = details or {}
    if
        type(details) ~= "table"
        or not self:ValidData(details)
        or (details.summary ~= nil and not stringValue(details.summary, 160))
        or (details.entries ~= nil and not array(details.entries))
    then
        return nil, "Invalid match result."
    end
    local result = {
        id = lobby.id .. ":" .. lobby.run,
        sessionID = lobby.id,
        host = lobby.host,
        gameID = lobby.gameID,
        gameVersion = lobby.gameVersion,
        run = lobby.run,
        startedAt = lobby.startedAt,
        endedAt = math.max(lobby.startedAt, GetServerTime()),
        status = status,
        reason = reason,
        summary = status == "aborted" and "Match interrupted." or (details.summary or "Match completed."),
        abortedBy = abortedBy,
        entries = {},
    }
    local byName = {}
    for _, participant in ipairs(lobby.members) do
        local entry = { player = participant.name }
        result.entries[#result.entries + 1] = entry
        byName[entry.player] = entry
    end
    if status == "completed" then
        local seen = {}
        for _, entry in ipairs(details.entries or {}) do
            if type(entry) ~= "table" or not byName[entry.player] or seen[entry.player] then
                return nil, "Invalid result participant."
            end
            seen[entry.player] = true
            byName[entry.player].score, byName[entry.player].rank, byName[entry.player].outcome =
                entry.score, entry.rank, entry.outcome
        end
    end
    if not self:ValidResult(result, lobby) then
        return nil, "Invalid scores, ranks or outcomes."
    end
    table.sort(result.entries, function(a, b)
        if (a.rank or 99) ~= (b.rank or 99) then
            return (a.rank or 99) < (b.rank or 99)
        end
        return a.player < b.player
    end)
    return result
end

function Games:IsRoundStopped()
    local stopped, lobby = self.StoppedRound, self.Lobby
    return stopped
            and lobby
            and stopped.id == lobby.id
            and stopped.run == (lobby.status == "countdown" and lobby.run + 1 or lobby.run)
            and (not stopped.token or stopped.token == lobby.countdownToken)
        or false
end

function Games:StopRoundLocally(reason, hide)
    if not self.Lobby then
        return
    end
    self.StoppedRound = { id = self.Lobby.id, run = self.Lobby.run }
    self:StopModule(reason)
    if hide then
        self.UI:HideAll()
    end
    self:Changed()
end

function Games:FinishRound(status, reason, details, abortedBy)
    if not self:IsHost() or self.Lobby.status ~= "running" then
        return false, "Only the running game's host can finalize a match."
    end
    local result, err = self:BuildResult(status, reason, details, abortedBy)
    if not result then
        return false, err
    end
    -- Finalize the shared state before hooks, disabling stale callbacks immediately.
    self.Lobby.status, self.Lobby.result = "waiting", result
    self.Lobby.epoch = self.Lobby.epoch + 1
    for _, entry in ipairs(self.Lobby.members) do
        entry.ready = false
    end
    self.StoppedRound = { id = self.Lobby.id, run = self.Lobby.run }
    self:RecordResult(result)
    self:CallGame("OnResult", self.Copy(result))
    self:StopModule(status == "aborted" and "aborted" or "completed")
    if status == "aborted" then
        self.UI:HideAll()
    end
    if self.Lobby.mode == "singleplayer" then
        self.Lobby, self.StoppedRound = nil, nil
        self:Changed()
    else
        self:PublishLobby()
    end
    return true
end

function Games:FinishGame(details)
    return self:FinishRound("completed", "finished", details)
end

function Games:AbortGame()
    local lobby = self.Lobby
    if not lobby or (lobby.status ~= "running" and lobby.status ~= "countdown") or self:IsRoundStopped() then
        self.UI:HideAll()
        return false, "No running match."
    end
    -- Stop locally before even attempting transport. A send failure must not trap the UI.
    local packet = {
        id = lobby.id,
        run = lobby.status == "countdown" and lobby.run + 1 or lobby.run,
        token = lobby.countdownToken,
    }
    self.UI:HideAll()
    if lobby.status == "countdown" then
        if self:IsHost() then
            self:CancelCountdown(true, true)
        else
            self.StoppedRound = { id = lobby.id, run = lobby.run + 1, token = lobby.countdownToken }
            self.PendingAbort = packet
            self:Changed()
        end
    elseif self:IsHost() then
        self:FinishRound("aborted", "player_abort", nil, self:PlayerName())
    else
        local result = self:BuildResult("aborted", "player_abort", nil, self:PlayerName())
        if result then
            result.provisional = true
            self:RecordResult(result)
        end
        self:StopRoundLocally("aborted", true)
        self.PendingAbort = packet
    end
    if lobby.mode == "multiplayer" then
        pcall(self.SendControl, self, "ABORT", packet)
    end
    self.UI:HideAll()
    return true
end

function Games:ReceiveControl(kind, data, sender)
    if kind ~= "ABORT" then
        self:ReceiveCountdown(kind, data, sender)
        return
    end
    local lobby = self.Lobby
    if
        not lobby
        or lobby.mode ~= "multiplayer"
        or (lobby.status ~= "running" and lobby.status ~= "countdown")
        or data.id ~= lobby.id
        or data.run ~= (lobby.status == "countdown" and lobby.run + 1 or lobby.run)
        or (data.token ~= nil and data.token ~= lobby.countdownToken)
    then
        return
    end
    local participant = false
    for _, entry in ipairs(lobby.members) do
        if entry.name == sender then
            participant = true
            break
        end
    end
    if not participant then
        return
    end
    if lobby.status == "countdown" then
        if self:IsHost() then
            self:CancelCountdown(true, true)
        elseif not self:IsRoundStopped() then
            self.StoppedRound = { id = lobby.id, run = lobby.run + 1, token = lobby.countdownToken }
            self:Changed()
        end
        self.UI:HideAll()
    elseif self:IsHost() then
        self:FinishRound("aborted", "player_abort", nil, sender)
        self.UI:HideAll()
    elseif not self:IsRoundStopped() then
        local result = self:BuildResult("aborted", "player_abort", nil, sender)
        if result then
            result.provisional = true
            self:RecordResult(result)
        end
        self:StopRoundLocally("aborted", true)
    end
end
