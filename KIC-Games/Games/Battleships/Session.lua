local _, Games = ...
local B, R = Games.Battleships, Games.Battleships.Rules

function B:Party()
    return Games:GroupChannel() == "PARTY" and not IsInRaid() and GetNumGroupMembers() >= 2
end
function B:Seat(name)
    for i, member in ipairs(self.session.members) do
        if member.name == name then
            return i
        end
    end
end
function B:SessionValid(s)
    if
        type(s) ~= "table"
        or not Games:ValidData(s)
        or s.gameID ~= "battleships"
        or s.gameVersion ~= Games.Registry.battleships.version
        or s.mode ~= "multiplayer"
        or s.channel ~= "PARTY"
        or s.status ~= "running"
        or type(s.id) ~= "string"
        or #s.id == 0
        or #s.id > 100
        or not R.Int(s.run, 1, 2147483647)
        or not R.Int(s.revision, 0, 2147483647)
        or not R.Int(s.epoch, 0, 2147483647)
        or not R.Int(s.countdownToken, 0, 2147483647)
        or not R.Int(s.startedAt, 0, 9999999999)
        or not Games:IsArray(s.members)
        or #s.members ~= 2
    then
        return false
    end
    local seen = {}
    for _, member in ipairs(s.members) do
        if
            type(member) ~= "table"
            or type(member.name) ~= "string"
            or #member.name > 100
            or Games:NormalizeName(member.name) ~= member.name
            or seen[member.name]
            or type(member.ready) ~= "boolean"
            or member.version ~= s.gameVersion
        then
            return false
        end
        seen[member.name] = true
    end
    return s.host == s.members[1].name and seen[Games:PlayerName()] == true
end
function B:Save()
    local lobby = Games.Lobby
    if
        not self.running
        or not lobby
        or lobby.status ~= "running"
        or lobby.id ~= self.session.id
        or lobby.run ~= self.session.run
    then
        return
    end
    self:Storage().active = {
        session = Games.Copy(lobby),
        state = Games.Copy(self.authority),
        view = Games.Copy(self.view),
        draft = Games.Copy(self.draft),
        pending = Games.Copy(self.pending),
        vertical = self.vertical,
        selected = self.selected,
    }
end
function B:SetView(view)
    if self.view and view.rev < self.view.rev then
        return
    end
    if not self.view or view.rev > self.view.rev then
        self.notice = nil
    end
    self.view = view
    if not self.authority then
        self.lastHeard, self.waiting = GetTime(), false
    end
    if self.pending and view.ack >= self.pending.seq then
        self.pending = nil
    end
    if view.ownReady then
        self.draft = R.DecodeFleet(view.ownFleet)
    end
    self:Save()
    self:Render()
end
function B:Publish()
    if not self.running or not self.authority then
        return
    end
    self.lastPublish = GetTime()
    self:SetView(R.View(self.authority, 1))
    -- Only each recipient's own fleet appears in their live view. The host
    -- adjudicates shots; this uses the launcher's trusted PARTY transport.
    self.context:SendState("bs_view", R.Pack(R.View(self.authority, 2)), self.session.members[2].name)
    if self.authority.phase == "ended" then
        self.endingAt = self.endingAt or GetTime()
    end
end
function B:SyncRequested(sender)
    if not self.running or not self.authority or self:Seat(sender) ~= 2 then
        return
    end
    self.lastHeard = GetTime()
    if GetTime() - (self.lastPublish or -100) >= 3 then
        self:Publish()
    end
end
function B:HostAction(data, sender)
    if not self.running or not self.authority or not self:Party() or not Games:ValidData(data) then
        return
    end
    local seat = self:Seat(sender)
    if not seat or not R.Action(data) then
        return
    end
    if seat == 2 then
        self.lastHeard = GetTime()
    end
    if data.seq <= self.authority.acks[seat] then
        if GetTime() - (self.lastPublish or -100) >= 0.4 then
            self:Publish()
        end
        return
    end
    local ok, code = R.Apply(self.authority, seat, data)
    if ok then
        self:Publish()
    else
        local rejection = { seq = data.seq, rev = self.authority.rev, code = code }
        if seat == 1 then
            self:Rejected(rejection)
        else
            self.context:SendState("bs_reject", rejection, sender)
        end
        if GetTime() - (self.lastPublish or -100) >= 0.4 then
            self:Publish()
        end
    end
end
function B:Rejected(data)
    if
        type(data) ~= "table"
        or not R.Int(data.rev, 0, 203)
        or not R.Errors[data.code]
        or not self.pending
        or data.seq ~= self.pending.seq
    then
        return
    end
    self.pending, self.notice = nil, R.Errors[data.code]
    self:Save()
    self:Render()
end
function B:Receive(event, data, sender)
    if not self.running or self.authority or sender ~= self.session.host then
        return
    end
    if event == "bs_view" then
        local view = R.Unpack(data, self.seat)
        if not view or self.view and view.rev < self.view.rev then
            return
        end
        self:SetView(view)
        if view.phase == "ended" then
            self.context:SendAction("bs_end_ack", { rev = view.rev })
        end
    elseif event == "bs_reject" then
        self:Rejected(data)
    end
end
function B:Request(op, value)
    local v = self.view
    if
        not self.running
        or not self.context:GetSession()
        or not v
        or self.pending
        or self.waiting
        or v.phase == "ended"
    then
        return false
    end
    if op == "lock" and (v.phase ~= "setup" or v.ownReady or not R.EncodeFleet(self.draft)) then
        return false
    end
    if
        op == "fire"
        and (
            v.phase ~= "battle"
            or v.turn ~= self.seat
            or not R.Int(value, 1, 100)
            or v.outgoing:sub(value, value) ~= "0"
        )
    then
        return false
    end
    local action = { op = op, seq = v.ack + 1, rev = v.rev }
    if op == "lock" then
        action.fleet = R.EncodeFleet(self.draft)
    elseif op == "fire" then
        action.cell = value
    end
    if not R.Action(action) then
        return false
    end
    self.pending, self.lastInput = action, GetTime()
    self:Save()
    self.context:SendAction("bs_input", action)
    self:Render()
    return true
end
function B:Finish()
    if self.finishing or not self.running or not self.authority then
        return
    end
    self.finishing = true
    local s, entries = self.authority, {}
    for seat, member in ipairs(self.session.members) do
        entries[seat] = {
            player = member.name,
            score = R.Hits(s.shots[seat]),
            outcome = s.winner == seat and "win" or "loss",
        }
    end
    self.context:FinishGame({
        summary = "Battleships: "
            .. self.session.members[s.winner].name:sub(1, 90)
            .. (s.reason == "resigned" and " wins by resignation." or " destroyed the enemy fleet."),
        entries = entries,
    })
end
function B:Tick()
    if not self.running or not self.context:GetSession() then
        return
    end
    local now = GetTime()
    if self.authority and self.authority.phase == "ended" then
        if self.endAck or now - self.endingAt >= 8 then
            self:Finish()
            return
        end
        if now - self.lastPublish >= 3 then
            self:Publish()
        end
        return
    end
    local quiet = now - self.lastHeard
    local waiting = quiet > 16
    if not self:Party() or quiet > 45 then
        Games:Notify("Battleships connection lost; no winner was awarded.")
        self.context:AbortGame()
        return
    end
    if waiting ~= self.waiting then
        self.waiting = waiting
        self:Render()
    end
    if self.authority then
        if now - (self.lastPublish or -100) >= 8 then
            self:Publish()
        end
    elseif now - (self.lastPing or -100) >= (self.view and 8 or 2) then
        self.lastPing = now
        self.context:SendAction("bs_ping", {})
    end
    if self.pending and now - self.lastInput >= 2 then
        self.lastInput = now
        self.context:SendAction("bs_input", self.pending)
    end
end
function B:Start(context, session, restored)
    assert(self:SessionValid(session), "Battleships requires a two-player PARTY lobby")
    local saved = restored and self:Storage().active
    self.context, self.session, self.running = context, Games.Copy(session), true
    self.seat = self:Seat(context.player)
    self.authority, self.view, self.pending = nil, nil, nil
    self.draft, self.vertical, self.selected = {}, false, 1
    self.notice, self.hover, self.result, self.endingAt, self.endAck, self.finishing = nil, nil, nil, nil, false, false
    self.waiting, self.lastHeard, self.lastPing, self.lastPublish = false, GetTime(), nil, nil
    if context.isHost then
        if saved and R.ValidAuthority(saved.state) then
            self.authority = Games.Copy(saved.state)
        else
            assert(not restored, "Battleships host recovery data is unavailable")
            self.authority = R.New(session.run % 2 == 1 and 1 or 2)
        end
        self.view = R.View(self.authority, self.seat)
    elseif saved and R.ValidView(saved.view, self.seat) then
        self.view = Games.Copy(saved.view)
    end
    if saved then
        if R.DraftValid(saved.draft) then
            self.draft = Games.Copy(saved.draft)
        end
        self.vertical = saved.vertical == true
        self.selected = R.Int(saved.selected, 1, 5) and saved.selected or 1
        if
            self.view
            and R.Action(saved.pending)
            and saved.pending.seq == self.view.ack + 1
            and saved.pending.rev <= self.view.rev
        then
            self.pending, self.lastInput = Games.Copy(saved.pending), GetTime() - 2
        end
    end
    if self.view and self.view.ownReady then
        self.draft = R.DecodeFleet(self.view.ownFleet)
    end
    self.summary:Hide()
    self.root:EnableKeyboard(true)
    self.root:Show()
    if self.authority then
        self:Publish()
    end
    context:NewTicker(0.1, function()
        self:Tick()
    end)
    self:Save()
    self:Render()
end
local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_LOGOUT")
lifecycle:SetScript("OnEvent", function()
    B:Save()
end)
