local _, Games = ...

function Games:ClearCountdownTimer()
    if self.CountdownTimer then
        self.CountdownTimer:Cancel()
        self.CountdownTimer = nil
    end
end

function Games:CountdownRemaining()
    local lobby = self.Lobby
    if not lobby or lobby.status ~= "countdown" then
        return nil
    end
    return math.max(0, math.min(3, lobby.countdownAt - GetServerTime()))
end

function Games:ShowCountdown()
    if self.UI.frame then
        self.UI:SelectTab("multiplayer")
        self.UI:ShowHome()
        self.UI.frame:Show()
        self.UI:UpdateCountdown()
    end
end

function Games:CancelCountdown(resetReady, hide)
    if not self:IsHost() or self.Lobby.status ~= "countdown" then
        return false
    end
    self:ClearCountdownTimer()
    local lobby = self.Lobby
    lobby.status, lobby.countdownAt = "waiting", nil
    lobby.countdownHide = hide == true
    lobby.countdownToken = lobby.countdownToken + 1
    self.StoppedRound, self.PendingAbort = nil, nil
    if resetReady then
        self:InvalidateReadiness()
    else
        lobby.epoch = lobby.epoch + 1
    end
    self:SendControl("COUNTDOWN_CANCEL", {
        id = lobby.id,
        run = lobby.run,
        token = lobby.countdownToken,
        epoch = lobby.epoch,
        reset = resetReady == true,
        hide = hide == true,
    })
    self:PublishLobby()
    if hide then
        self.UI:HideAll()
    end
    return true
end

function Games:BeginCountdown()
    local ok, err = self:CanStart()
    if not ok then
        return false, err
    end
    if self.Lobby.status == "countdown" then
        return true
    end
    local lobby = self.Lobby
    lobby.status, lobby.countdownAt = "countdown", GetServerTime() + 3
    lobby.countdownHide = nil
    lobby.countdownToken = lobby.countdownToken + 1
    lobby.result = nil
    local id, token = lobby.id, lobby.countdownToken
    self:PublishLobby()
    self:SendControl(
        "COUNTDOWN",
        { id = id, run = lobby.run, token = token, epoch = lobby.epoch, at = lobby.countdownAt }
    )
    self:ShowCountdown()
    self:ClearCountdownTimer()
    local timer
    timer = C_Timer.NewTicker(0.1, function()
        if
            not Games.Lobby
            or Games.Lobby.id ~= id
            or Games.Lobby.countdownToken ~= token
            or Games.Lobby.status ~= "countdown"
        then
            timer:Cancel()
            if Games.CountdownTimer == timer then
                Games.CountdownTimer = nil
            end
            return
        end
        if not Games:CanStart() then
            Games:CancelCountdown(true)
            return
        end
        if GetServerTime() >= Games.Lobby.countdownAt then
            Games:ClearCountdownTimer()
            Games:LaunchGame()
        end
    end)
    self.CountdownTimer = timer
    return true
end

function Games:MaybeStartCountdown()
    if self:IsHost() and self.Lobby.mode == "multiplayer" and self.Lobby.status == "waiting" and self:CanStart() then
        self:BeginCountdown()
    end
end

function Games:ReceiveCountdown(kind, data, sender)
    local lobby = self.Lobby
    if not lobby or lobby.mode ~= "multiplayer" or data.id ~= lobby.id then
        return
    end
    if kind == "UNREADY" then
        if
            not self:IsHost()
            or lobby.status ~= "countdown"
            or data.run ~= lobby.run
            or data.token ~= lobby.countdownToken
            or data.epoch ~= lobby.epoch
        then
            return
        end
        for _, entry in ipairs(lobby.members) do
            if entry.name == sender then
                entry.ready = false
                self:CancelCountdown(false)
                return
            end
        end
        return
    end
    if
        sender ~= lobby.host
        or data.run ~= lobby.run
        or lobby.status == "running"
        or type(data.token) ~= "number"
        or data.token % 1 ~= 0
        or data.token <= lobby.countdownToken
        or data.token > 2147483647
        or type(data.epoch) ~= "number"
        or data.epoch % 1 ~= 0
        or data.epoch < lobby.epoch
        or data.epoch > 2147483647
    then
        return
    end
    if kind == "COUNTDOWN" then
        if
            type(data.at) ~= "number"
            or data.at % 1 ~= 0
            or data.at < 0
            or data.at > 9999999999
            or data.epoch ~= lobby.epoch
            or not self:Compatible(lobby)
        then
            return
        end
        lobby.status, lobby.countdownAt = "countdown", data.at
        lobby.countdownToken, lobby.epoch = data.token, data.epoch
        for _, entry in ipairs(lobby.members) do
            entry.ready = true
        end
        self:ShowCountdown()
    elseif kind == "COUNTDOWN_CANCEL" then
        lobby.status, lobby.countdownAt = "waiting", nil
        lobby.countdownToken, lobby.epoch = data.token, data.epoch
        self.StoppedRound, self.PendingAbort = nil, nil
        if data.reset then
            for _, entry in ipairs(lobby.members) do
                entry.ready = false
            end
        end
        if data.hide then
            self.UI:HideAll()
        end
    end
    self:UpdateListing(lobby)
    self:Changed()
end
