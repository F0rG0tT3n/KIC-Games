local _, Games = ...
local B, R = Games.Blindshot, Games.Blindshot.Rules
-- Fractional, monotonic host clock; do not quantize subsecond shots to the
-- integer GetServerTime clock. Guests anchor each newer snapshot locally.
function B:Now()
    if self:IsAuthority() then
        return (self.clockEpoch or GetServerTime()) + GetTime() - (self.clockLocal or GetTime())
    end
    return self.view and (self.view.clock or GetServerTime()) + GetTime() - (self.receivedAt or GetTime())
        or GetServerTime()
end
function B:Party()
    return Games:GroupChannel() == "PARTY"
        and not IsInRaid()
        and GetNumGroupMembers() >= 2
        and GetNumGroupMembers() <= 5
end
function B:IsAuthority()
    return self.practice or Games:IsHost()
end
function B:SessionValid(s)
    if
        type(s) ~= "table"
        or not Games:ValidData(s)
        or s.gameID ~= "blindshot"
        or s.gameVersion ~= Games.Registry.blindshot.version
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
        or #s.members < 2
        or #s.members > 5
    then
        return false
    end
    local seen = {}
    for _, p in ipairs(s.members) do
        if
            type(p) ~= "table"
            or type(p.name) ~= "string"
            or #p.name > 100
            or Games:NormalizeName(p.name) ~= p.name
            or seen[p.name]
            or type(p.ready) ~= "boolean"
            or p.version ~= s.gameVersion
            or p.request ~= nil and (type(p.request) ~= "string" or #p.request > 100)
        then
            return false
        end
        seen[p.name] = true
    end
    return seen[s.host] and seen[Games:PlayerName()] or false
end
function B:Save()
    if self.practice or not self.running or not self.session then
        return
    end
    local lobby = Games.Lobby
    if not lobby or lobby.id ~= self.session.id or lobby.run ~= self.session.run or lobby.status ~= "running" then
        return
    end
    local view, state = Games.Copy(self.view), Games.Copy(self.authority)
    if view then
        view.clock = self:Now()
    end
    if state then
        state.clock = self:Now()
    end
    self:Storage().active = {
        session = Games.Copy(lobby),
        state = state,
        view = view,
        draft = Games.Copy(self.draft),
        inputSeq = self.inputSeq,
    }
end
function B:Publish(target, localOnly)
    if not self.authority or not self.running or not self:IsAuthority() then
        return
    end
    if not localOnly then
        self.authority.rev = self.authority.rev + 1
    end
    self.authority.clock = self:Now()
    local view = R.Public(self.authority)
    if self.view and (self.view.phase ~= view.phase or self.view.round ~= view.round) then
        self.notice = nil
    end
    self.view = view
    self:Save()
    if not localOnly then
        self.context:SendState("blindshot_view", R.Pack(self.view), target)
    end
    self:Render()
end
function B:Ack(sender, seq, accepted)
    local last = self.acks[sender] or -100
    if GetTime() - last < 0.4 then
        return
    end
    self.acks[sender] = GetTime()
    local p = R.Player(self.authority, sender)
    self.context:SendState("blindshot_ack", {
        id = self.authority.id,
        round = self.authority.round,
        seq = seq,
        accepted = accepted == true,
        locked = p and p.locked == true,
    }, sender)
end
function B:SyncRequested(sender)
    if not self.authority or not R.Player(self.authority, sender) then
        return
    end
    -- Startup lobby snapshots can be queued under the client's addon-message
    -- throttle. Wait for every board to load before spending anyone's AIM time,
    -- and avoid queuing a duplicate full snapshot for every startup sync request.
    if self.authority.phase == "PREPARE" then
        if self.authority.round == 1 then
            self.readyPeers[sender] = true
        elseif GetTime() - (self.lastPublish or -100) >= 8 then
            self.lastPublish = GetTime()
            self:Publish()
        end
        return
    end
    -- Every public snapshot is identical for all participants. A burst of sync
    -- requests needs one shared response, not N copies ahead of the next phase.
    if GetTime() - (self.lastSyncReply or -100) >= 3 and GetTime() - (self.lastPublish or -100) >= 3 then
        self.lastSyncReply, self.lastPublish = GetTime(), GetTime()
        self:Publish()
    end
end
function B:RoundReady(data, sender)
    local s = self.authority
    if
        self.running
        and self:IsAuthority()
        and s
        and s.phase == "PREPARE"
        and type(data) == "table"
        and data.id == s.id
        and data.round == s.round
        and R.Player(s, sender)
    then
        self.readyPeers[sender] = true
    end
end
function B:SendRoundReady()
    local v = self.view
    if
        not self.practice
        and not self:IsAuthority()
        and v
        and v.phase == "PREPARE"
        and v.round > 1
        and GetTime() - (self.lastRoundReady or -100) >= 2
    then
        self.lastRoundReady = GetTime()
        self.context:SendAction("blindshot_ready", { id = v.id, round = v.round })
    end
end
function B:HostAction(data, sender)
    local s = self.authority
    if
        not self.running
        or not s
        or not self:IsAuthority()
        or not (self.practice or self:Party())
        or type(data) ~= "table"
        or not Games:ValidData(data)
        or data.id ~= s.id
        or data.round ~= s.round
        or not R.Int(data.seq, 1, 1000000)
    then
        return
    end
    local p = R.Player(s, sender)
    if not p or not p.alive then
        return
    end
    local old = s.drafts[sender]
    if p.locked or old and data.seq <= old.seq then
        if data.lock then
            self:Ack(sender, data.seq, p.locked)
        end
        return
    end
    if s.phase ~= "AIM" or self:Now() > s.deadline or not R.Action(data, s.radius) or data.lock ~= true then
        self:Ack(sender, data.seq, false)
        return
    end
    s.drafts[sender] = { x = data.x, y = data.y, dx = data.dx, dy = data.dy, seq = data.seq, lock = data.lock }
    self:Save()
    if data.lock then
        p.locked = true
        self:Ack(sender, data.seq, true)
        if R.AllLocked(s) then
            R.Reveal(s, self:Now())
        end
        -- Several locks often arrive in adjacent ticks. Coalesce their public
        -- status updates so a redundant partial roster cannot delay the reveal
        -- and next PLAN behind WoW's addon-message throttle. Private ACKs stay immediate.
        self.lockPublishAt = self.lockPublishAt or GetTime() + 0.35
        self.needsPublish = true
    end
end
function B:Receive(event, data, sender)
    if not self.running or sender ~= self.session.host or type(data) ~= "table" then
        return
    end
    if event == "blindshot_view" then
        data = R.Unpack(data, self.session)
        if not data or self.view and data.rev <= self.view.rev then
            return
        end
        if self.view and (self.view.phase ~= data.phase or self.view.round ~= data.round) then
            self.notice = nil
        end
        -- GetServerTime is coarse but shared: discard obvious transport age
        -- conservatively, then use the fractional snapshot clock for playback.
        data.clock = math.max(data.clock or 0, GetServerTime() - 1)
        -- Never rewind an ongoing sequence on a delayed newer heartbeat.
        if self.view and data.sequenceID and data.sequenceID == self.view.sequenceID then
            data.clock = math.max(data.clock or 0, self:Now())
        end
        self.receivedAt = GetTime()
        self.view, self.lastHeard, self.waiting = Games.Copy(data), GetTime(), false
        if self.pending and data.round ~= self.pending.round then
            self.pending = nil
        end
        local own = R.Player(self.view, Games:PlayerName())
        if own.locked or data.phase ~= "AIM" then
            self.pending = nil
        end
        self:EnsureDraft()
        self:SendRoundReady()
        self:Save()
        self:Render()
    elseif event == "blindshot_ack" then
        if
            not self.pending
            or data.id ~= self.pending.id
            or data.round ~= self.pending.round
            or data.seq ~= self.pending.seq
            or type(data.accepted) ~= "boolean"
            or type(data.locked) ~= "boolean"
        then
            return
        end
        if data.accepted and data.locked then
            self.lockConfirmed = self.pending.round
            self.pending, self.notice = nil, "Locked in. Waiting for the reveal."
        elseif not data.accepted then
            self.pending, self.notice = nil, "Lock not accepted. Check the round and your position."
        end
        self:Render()
    end
end
function B:EnsureDraft()
    local v = self.view
    if not v or self.draftRound == v.round then
        return
    end
    local _, index = R.Player(v, Games:PlayerName())
    self.draft = R.Default(index, #v.players, v.radius)
    self.draft.lock, self.draft.auto = false, nil
    self.draftRound, self.inputSeq, self.pending, self.lockConfirmed = v.round, 0, nil, nil
    self.dirty, self.notice = false, nil
end
function B:CanInput()
    local v = self.view
    local own = v and R.Player(v, Games:PlayerName())
    return self.running
        and v
        and v.phase == "AIM"
        and own
        and own.alive
        and not own.locked
        and self.lockConfirmed ~= v.round
        and not self.pending
        and not self.waiting
        and (self.practice or self:Party())
        and self:Now() <= v.deadline
end
function B:SendDraft(lock)
    if lock ~= true then
        return false, "Use Lock In to submit your final choice."
    end
    self:CancelMouseInput()
    if not self:CanInput() or not R.Action(self.draft, self.view.radius) then
        return false
    end
    self.inputSeq = self.inputSeq + 1
    local data = {
        id = self.view.id,
        round = self.view.round,
        seq = self.inputSeq,
        x = self.draft.x,
        y = self.draft.y,
        dx = self.draft.dx,
        dy = self.draft.dy,
        lock = lock == true,
    }
    if lock then
        self.pending = Games.Copy(data)
    end
    local ok, err = self.context:SendAction("blindshot_input", data)
    self.lastInputAt, self.dirty = GetTime(), not ok
    if not ok then
        self.pending, self.notice = nil, err or "Waiting for the host."
    end
    self:Save()
    self:Render()
    return ok, err
end
function B:Tick()
    if not self.running then
        return
    end
    if self.practice and self.finishing then
        self:UpdateClock()
        return
    end
    local now, time = self:Now(), GetTime()
    if not self.practice and not self:Party() then
        self.context:AbortGame()
        return
    end
    if self:IsAuthority() and self.authority then
        local s, changed = self.authority, false
        local preparing = s.phase == "PREPARE"
        local boardsReady = true
        if preparing then
            for _, p in ipairs(s.players) do
                if p.alive and not self.readyPeers[p.name] then
                    boardsReady = false
                end
            end
            if not boardsReady then
                if now >= self.startGrace then
                    self.context:AbortGame()
                    return
                end
                s.deadline = now + 1
            end
        end
        if boardsReady and now >= s.deadline then
            if s.phase == "PREPARE" then
                R.BeginAim(s, now)
                changed = true
            elseif s.phase == "AIM" then
                R.Reveal(s, now)
                changed = true
            elseif s.phase == "REVEAL" then
                R.Resolve(s, now)
                changed = true
            elseif s.phase == "FIRING" then
                R.EndRound(s, now)
                changed = true
            elseif s.phase == "ROUND_END" then
                R.Next(s, now)
                if s.phase == "PREPARE" then
                    self.readyPeers = { [Games:PlayerName()] = true }
                    if self.practice then
                        for _, p in ipairs(s.players) do
                            self.readyPeers[p.name] = true
                        end
                    end
                    self.startGrace = now + 45
                end
                changed = true
            end
        end
        if self.practice and s.phase == "AIM" then
            self:PreparePracticePlayers()
        end
        -- REVEAL already carries the entire timed plan. Do not enqueue that
        -- same large plan again at FIRING/ROUND_END; clients derive both phases.
        local automatic = s.phase == "FIRING" or s.phase == "ROUND_END"
        local publishLocks = self.needsPublish and (s.phase ~= "AIM" or time >= (self.lockPublishAt or 0))
        if
            changed
            or publishLocks
            or not automatic and (not preparing or boardsReady) and time - (self.lastPublish or -100) >= 4
        then
            local localOnly = changed and automatic and not self.needsPublish
            self.needsPublish = false
            self.lockPublishAt = nil
            self.lastPublish = time
            self:Publish(nil, localOnly)
        end
        if s.phase == "MATCH_END" and not self.finishing then
            self.finishing = true
            local summary = s.winner and ("Blindshot: " .. s.winner .. " wins after " .. s.round .. " rounds.")
                or "Blindshot: draw after " .. s.round .. " rounds."
            self.context:FinishGame({ summary = summary, entries = R.Entries(s) })
            return
        end
    else
        self:SendRoundReady()
        self.waiting = time - (self.lastHeard or time) > 12
        if (not self.view or self.waiting) and time - (self.lastSync or -100) >= 5 then
            self.lastSync = time
            Games:Send("GAME_SYNC", {
                target = self.session.host,
                id = self.session.id,
                run = self.session.run,
                gameID = "blindshot",
                gameVersion = Games.Registry.blindshot.version,
            })
        end
    end
    self:EnsureDraft()
    if self.pending and time - (self.lastInputAt or 0) >= 1 then
        self.lastInputAt = time
        self.context:SendAction("blindshot_input", self.pending)
    end
    if time - (self.lastSave or -100) >= 1 then
        self.lastSave = time
        self:Save()
    end
    self:UpdateClock()
    if
        self.view
        and (self.view.phase == "FIRING" or self.view.phase == "REVEAL")
        and self.root
        and self.root:IsVisible()
    then
        self:Render()
    end
end
function B:Start(context, session, restored, practice)
    self:CancelMouseInput()
    self.zoomMotion, self.zoomRadius = nil, nil
    self.unit = self.baseUnit
    assert(self:SessionValid(session), "Blindshot requires an ordinary PARTY lobby")
    self.practice = practice == true
    self.clockEpoch, self.clockLocal, self.receivedAt = GetServerTime(), GetTime(), GetTime()
    self.context, self.session, self.running = context, Games.Copy(session), true
    self.authority, self.view, self.pending, self.draft = nil, nil, nil, nil
    self.acks, self.inputSeq = {}, 0
    self.readyPeers = { [Games:PlayerName()] = true }
    if self.practice then
        for _, p in ipairs(session.members) do
            self.readyPeers[p.name] = true
        end
    end
    self.startGrace = GetServerTime() + 45
    self.finishing, self.waiting, self.notice, self.draftRound = false, false, nil, nil
    self.needsPublish = false
    self.lockPublishAt = nil
    self.lastSyncReply = nil
    self.lastPublish, self.lastSync, self.lastInputAt, self.lastSave, self.lastRoundReady = nil, nil, nil, nil, nil
    self.lastHeard = GetTime()
    local saved = restored and self:Storage().active
    if context.isHost then
        if saved and R.ValidAuthority(saved.state, session) then
            self.authority = Games.Copy(saved.state)
            self.clockEpoch = math.max(self.clockEpoch, self.authority.clock or 0)
            if self.authority.phase == "AIM" then
                self.authority.deadline = math.max(self.authority.deadline, self:Now() + 3)
            end
        else
            assert(not restored, "Blindshot host recovery data is missing or invalid")
            self.authority = R.New(session, GetServerTime())
        end
        self.view = R.Public(self.authority)
    elseif saved and R.ValidView(saved.view, session) then
        self.view = Games.Copy(saved.view)
        self.view.clock = math.max(self.view.clock or 0, GetServerTime() - 1)
        self.waiting = true
    end
    self:EnsureDraft()
    if saved and self.view and R.Action(saved.draft, self.view.radius) then
        self.draft = Games.Copy(saved.draft)
        self.inputSeq = R.Int(saved.inputSeq, 0, 999999) and saved.inputSeq or 0
    end
    self.root:Show()
    if context.isHost then
        self:Publish()
    end
    context:NewTicker(0.1, function()
        self:Tick()
    end)
    self:Save()
    self:Render()
end
-- Preserve the exact presentation clock before SavedVariables are flushed by
-- /reload or logout, including a guest reloading between two shot impacts.
local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("PLAYER_LOGOUT")
lifecycle:SetScript("OnEvent", function()
    B:Save()
end)
