local _, Games = ...
local C, E = Games.Chess, Games.Chess.Engine
local VERSION = "1"
local function integer(v, low, high)
    return type(v) == "number" and v % 1 == 0 and v >= low and v <= high
end
local function text(v, max)
    return type(v) == "string" and #v > 0 and #v <= max
end
local function checksum(v)
    return type(v) == "string" and #v == 16 and v:match("^%x+$") ~= nil
end
local function moveFields(data)
    if not text(data.token, 24) then
        return false
    end
    if data.token:match("^[a-h][1-8][a-h][1-8][qrnb]?$") then
        return data.from == E.Square(data.token:sub(1, 2))
            and data.to == E.Square(data.token:sub(3, 4))
            and data.promotion == (#data.token == 5 and data.token:sub(5, 5) or nil)
    end
    return data.from == nil and data.to == nil and data.promotion == nil
end
local function now()
    return GetTime()
end
local function identity(name)
    return text(name, 100) and Games:NormalizeName(name) == name
end
local function opponent(info)
    return info.white == Games:PlayerName() and info.black or info.white
end
local function actorSide(info, actor)
    return actor == info.white and 1 or actor == info.black and -1 or nil
end
function C:Party()
    return Games:GroupChannel() == "PARTY"
        and not IsInRaid()
        and GetNumGroupMembers() >= 2
        and GetNumGroupMembers() <= 5
end
function C:Eligible()
    local names = {}
    if self:Party() then
        for name in pairs(Games:Roster()) do
            if name ~= Games:PlayerName() then
                local connected = true
                if UnitIsConnected then
                    for i = 1, GetNumSubgroupMembers() do
                        if Games:PlayerName("party" .. i) == name then
                            connected = UnitIsConnected("party" .. i) ~= false
                        end
                    end
                end
                if connected then
                    names[#names + 1] = name
                end
            end
        end
    end
    table.sort(names)
    return names
end
function C:Active()
    return self.match and not self.match.finished and not self.match.abandoned
end
function C:InfoValid(info)
    return type(info) == "table"
        and Games:ValidData(info)
        and text(info.id, 100)
        and identity(info.host)
        and identity(info.white)
        and identity(info.black)
        and info.white ~= info.black
        and (info.host == info.white or info.host == info.black)
        and info.version == VERSION
        and integer(info.startedAt, 0, 9999999999)
        and (
            info.sessionID == nil and info.run == nil
            or text(info.sessionID, 80)
                and integer(info.run, 1, 2147483647)
                and info.id == info.sessionID .. ":r" .. info.run
        )
end
function C:ResultID(info)
    return (info.sessionID or info.id) .. ":" .. (info.run or 1)
end
-- Only the color assignment is extra snapshot data; identity and round already
-- belong to the shared lobby. Keep advertisements small on WoW's message budget.
function C:LobbyInfo(lobby)
    if type(lobby.chess) ~= "table" or not Games:IsArray(lobby.members) or #lobby.members ~= 2 then
        return nil
    end
    local first, second = lobby.members[1], lobby.members[2]
    if type(first) ~= "table" or type(second) ~= "table" then
        return nil
    end
    local white = lobby.chess.white
    if white ~= first.name and white ~= second.name then
        return nil
    end
    if type(lobby.id) ~= "string" or not integer(lobby.run, 1, 2147483647) then
        return nil
    end
    return {
        id = lobby.id .. ":r" .. lobby.run,
        sessionID = lobby.id,
        run = lobby.run,
        host = lobby.host,
        white = white,
        black = white == first.name and second.name or first.name,
        version = VERSION,
        startedAt = lobby.startedAt,
    }
end
function C:LobbyInfoValid(lobby)
    if lobby.channel ~= "PARTY" then
        return false
    end
    local current = self.match and self.match.info
    local info = self:LobbyInfo(lobby)
    if not lobby.chess and current and not current.sessionID and self:InfoValid(current) then
        -- Existing pre-lobby journals can finish after upgrading the addon.
        if
            lobby.id ~= current.id
            or lobby.run ~= 1
            or lobby.host ~= current.host
            or not Games:IsArray(lobby.members)
            or #lobby.members ~= 2
        then
            return false
        end
        local first, second = lobby.members[1].name, lobby.members[2].name
        return first ~= second
            and (first == current.white or first == current.black)
            and (second == current.white or second == current.black)
    end
    if not self:InfoValid(info) then
        return false
    end
    if current and current.id == info.id then
        return current.white == info.white and current.black == info.black and current.host == info.host
    end
    return true
end
function C:PrepareLobby(lobby)
    lobby.chess = { white = lobby.members[math.random(2)].name }
end
function C:StartLobby(session)
    if session.chess then
        assert(self:LobbyInfoValid(session), "Invalid Chess lobby participants or round")
        local info = self:LobbyInfo(session)
        if not self.match or self.match.info.id ~= info.id then
            self.match = self:NewMatch(info)
        end
    else
        -- Resume journals saved before Chess adopted the shared lobby flow.
        assert(self.match and self.match.info.id == session.id, "Missing Chess recovery journal")
    end
    self.match.lastHeard = now()
    self.match.recovering, self.match.recoverSince = true, now()
    self.pending, self.recovery, self.selected, self.claiming = nil, nil, nil, nil
    self:Save()
    self:Head()
end
function C:Control(op, target, fields)
    if not self:Party() or not identity(target) or not Games:Roster()[target] then
        return false
    end
    local data = fields or {}
    data.op, data.target, data.version = op, target, VERSION
    return Games:Send("CHESS", data)
end
function C:NewMatch(info)
    return {
        info = Games.Copy(info),
        state = assert(E.New()),
        seq = 0,
        journal = {},
        offerPly = {},
        lastHeard = now(),
        recovering = true,
    }
end
function C:Digest(m)
    return E.Digest(m.state)
        .. E.Checksum(table.concat({
            tostring(m.seq),
            m.offer or "",
            m.trailHash or "0",
            tostring(m.offerPly[m.info.white] or -1),
            tostring(m.offerPly[m.info.black] or -1),
            m.ended and m.ended.reason or "",
            m.ended and tostring(m.ended.winner) or "",
        }, "|"))
end
function C:Transition(m, actor, token)
    local side = actorSide(m.info, actor)
    if not side or m.ended or not text(token, 24) then
        return nil, "Invalid participant or ended match"
    end
    local n = {
        info = m.info,
        practice = m.practice,
        state = m.state,
        seq = m.seq + 1,
        journal = m.journal,
        offer = m.offer,
        offerPly = Games.Copy(m.offerPly),
    }
    if token:match("^[a-h][1-8][a-h][1-8][qrnb]?$") then
        if m.state.turn ~= side then
            return nil, "Not your turn"
        end
        local state, err = E.PlayUCI(m.state, token)
        if not state then
            return nil, err
        end
        n.state = state
        if n.offer and n.offer ~= actor then
            n.offer = nil
        end
        local status = E.Status(state)
        if status.over then
            n.ended = { winner = status.winner, reason = status.reason }
        end
    elseif token == "offer" then
        if m.offer or m.offerPly[actor] == #m.state.moves then
            return nil, "Draw already offered for this move"
        end
        n.offer = actor
        n.offerPly[actor] = #m.state.moves
    elseif token == "accept" or token == "decline" then
        if not m.offer or m.offer == actor then
            return nil, "No opponent draw offer"
        end
        n.offer = nil
        if token == "accept" then
            n.ended = { winner = 0, reason = "draw by agreement" }
        end
    elseif token == "resign" then
        local canMate = false
        for _, piece in ipairs(m.state.board) do
            if piece * -side > 0 and math.abs(piece) ~= 6 then
                canMate = true
            end
        end
        n.ended = {
            winner = canMate and -side or 0,
            reason = canMate and "resignation" or "resignation; no possible mate",
        }
    else
        local kind, intended = token:match("^(%a+):([a-h][1-8][a-h][1-8][qrnb]?)$")
        kind = kind or token
        if
            side ~= m.state.turn
            or (kind ~= "threefold" and kind ~= "fifty")
            or not E.Claim(m.state, kind, intended)
        then
            return nil, "No valid draw claim"
        end
        n.ended = { winner = 0, reason = kind == "threefold" and "threefold repetition" or "fifty-move rule" }
    end
    n.journal = {}
    for i, value in ipairs(m.journal) do
        n.journal[i] = value
    end
    n.journal[#n.journal + 1] = (side == 1 and "w:" or "b:") .. token
    n.trailHash = E.Checksum((m.trailHash or "0") .. "|" .. actor .. "|" .. token)
    n.lastHeard, n.recovering = m.lastHeard, m.recovering
    return n
end
function C:Save()
    local m = self.match
    if m and m.practice then
        return
    end
    if not m or m.finished or m.abandoned then
        self:Storage().active = nil
        return
    end
    local lobby = Games.Lobby
    self:Storage().active = {
        info = Games.Copy(m.info),
        journal = table.concat(m.journal, " "),
        lobby = m.info.sessionID and lobby and lobby.id == m.info.sessionID and lobby.run == m.info.run and Games.Copy(
            lobby
        ) or nil,
    }
end
function C:Replay(info, journal)
    if not self:InfoValid(info) or type(journal) ~= "string" or #journal > 2000000 then
        return nil
    end
    local m = self:NewMatch(info)
    local count = 0
    for item in journal:gmatch("%S+") do
        count = count + 1
        if count > 200000 then
            return nil
        end
        local color, token = item:match("^([wb]):(.+)$")
        if not color then
            return nil
        end
        m = self:Transition(m, color == "w" and info.white or info.black, token)
        if not m then
            return nil
        end
    end
    return m
end
function C:Begin(info, restored, savedLobby)
    if not self:InfoValid(info) or not actorSide(info, Games:PlayerName()) then
        return false
    end
    if Games.Lobby then
        if Games.Lobby.gameID ~= "chess" then
            return false
        end
        Games:ResetLobby("reload")
    end
    if not restored then
        self.match = self:NewMatch(info)
    end
    local m = self.match
    m.lastHeard, m.recovering, m.recoverSince = now(), true, now()
    Games.Lobby = {
        id = info.sessionID or info.id,
        host = info.host,
        channel = "PARTY",
        revision = type(savedLobby) == "table" and integer(savedLobby.revision, 1, 2147483647) and savedLobby.revision
            or 1,
        run = info.run or 1,
        epoch = type(savedLobby) == "table" and integer(savedLobby.epoch, 0, 2147483647) and savedLobby.epoch or 0,
        startedAt = info.startedAt,
        mode = "multiplayer",
        countdownToken = type(savedLobby) == "table"
                and integer(savedLobby.countdownToken, 0, 2147483647)
                and savedLobby.countdownToken
            or 0,
        gameID = "chess",
        gameVersion = Games.Registry.chess.version,
        gameTitle = "Chess",
        maxPlayers = 2,
        status = "running",
        members = {
            { name = info.host, ready = true, version = Games.Registry.chess.version },
            {
                name = info.host == info.white and info.black or info.white,
                ready = true,
                version = Games.Registry.chess.version,
            },
        },
    }
    if info.sessionID then
        Games.Lobby.chess = { white = info.white }
        if type(savedLobby) == "table" and Games:IsArray(savedLobby.members) and #savedLobby.members == 2 then
            for _, entry in ipairs(Games.Lobby.members) do
                for _, saved in ipairs(savedLobby.members) do
                    if type(saved) == "table" and saved.name == entry.name and text(saved.request, 100) then
                        entry.request = saved.request
                    end
                end
            end
        end
    end
    -- The host need not be the group leader, and the group may contain spectators.
    self.pending, self.recovery = nil, nil
    self.notice = "Chess with " .. opponent(info) .. ". Reopen the board from the launcher."
    self:Save()
    local ok = Games:StartModule(restored == true)
    if ok then
        self:Head()
        self:RefreshAll()
    else
        self:Abandon("module_error")
    end
    return ok
end
function C:Request(token)
    local m = self.match
    if m and m.practice then
        return self:PracticeAction(token)
    end
    if not m or m.finished or m.abandoned or m.ended or m.recovering or self.pending or not self:Party() then
        return false, "Chess is waiting for synchronization."
    end
    if not self:Transition(m, Games:PlayerName(), token) then
        return false, "Illegal action."
    end
    local data = {
        id = m.info.id,
        actor = Games:PlayerName(),
        expected = m.info.host,
        seq = m.seq,
        previous = self:Digest(m),
        token = token,
    }
    if token:match("^[a-h][1-8][a-h][1-8][qrnb]?$") then
        data.from, data.to = E.Square(token:sub(1, 2)), E.Square(token:sub(3, 4))
        data.promotion = #token == 5 and token:sub(5, 5) or nil
    end
    self.pending = { data = data, at = now() }
    local ok, err = Games:SendGameAction("chess_action", data)
    if not ok then
        self.pending = nil
    end
    self:RefreshAll()
    return ok, err
end
function C:Move(from, to, promotion)
    if not E.Name(from) or not E.Name(to) then
        return false
    end
    return self:Request(E.Name(from) .. E.Name(to) .. (promotion or ""))
end
function C:HostAction(data, sender)
    local m = self.match
    if
        not m
        or m.info.host ~= Games:PlayerName()
        or m.recovering
        or type(data) ~= "table"
        or not Games:ValidData(data)
        or data.id ~= m.info.id
        or data.actor ~= sender
        or data.expected ~= m.info.host
        or not actorSide(m.info, sender)
    then
        return
    end
    if not moveFields(data) or data.seq ~= m.seq or data.previous ~= self:Digest(m) then
        self:Head(sender, data)
        return
    end
    local n = self:Transition(m, sender, data.token)
    if not n then
        self:Head(sender, data)
        return
    end
    n.lastHeard = now()
    n.recovering = false
    self.match = n
    self.pending = nil
    self:Save()
    Games:SendGameState("chess_commit", {
        id = n.info.id,
        actor = sender,
        expected = opponent(n.info),
        seq = n.seq,
        previous = data.previous,
        token = data.token,
        from = data.from,
        to = data.to,
        promotion = data.promotion,
        digest = self:Digest(n),
    }, opponent(n.info))
    self:RefreshAll()
    if n.ended then
        self:Finalize()
    end
end
function C:Commit(data, sender)
    local m = self.match
    if
        not m
        or type(data) ~= "table"
        or not Games:ValidData(data)
        or sender ~= m.info.host
        or data.id ~= m.info.id
        or data.expected ~= Games:PlayerName()
        or not integer(data.seq, 1, 200000)
        or not checksum(data.digest)
        or not checksum(data.previous)
        or not moveFields(data)
    then
        return
    end
    m.lastHeard = now()
    if data.seq <= m.seq then
        if data.seq == m.seq and data.digest == self:Digest(m) then
            self.pending = nil
        end
        return
    end
    if data.seq ~= m.seq + 1 or data.previous ~= self:Digest(m) then
        self:Recover()
        return
    end
    local n = self:Transition(m, data.actor, data.token)
    if not n or data.digest ~= self:Digest(n) then
        self:Recover()
        return
    end
    n.lastHeard, n.recovering = now(), false
    self.match = n
    self.pending, self.recovery = nil, nil
    self:Save()
    self:RefreshAll()
    if n.ended then
        self:RecordRecoveredFinal()
    end
end
function C:Head(target, rejected)
    local m = self.match
    if not m or m.abandoned then
        return
    end
    self:Control("head", target or opponent(m.info), {
        id = m.info.id,
        seq = m.seq,
        digest = self:Digest(m),
        finished = m.finished == true,
        rejected = rejected and rejected.token,
        requestSeq = rejected and rejected.seq,
    })
end
function C:Recover()
    local m = self.match
    if not m or m.finished then
        return
    end
    m.recovering = true
    m.recoverSince = m.recoverSince or now()
    if Games:PlayerName() == m.info.host then
        self:Head()
        return
    end
    if not self.recovery then
        self.recovery = { id = m.info.id, base = m.seq, at = now() }
        self:Control("sync", m.info.host, { id = m.info.id, known = m.seq, cursor = 0 })
    end
    self:RefreshAll()
end
function C:SendChunk(target, cursor, known)
    local m = self.match
    if
        not m
        or m.info.host ~= Games:PlayerName()
        or target ~= opponent(m.info)
        or not integer(cursor, 0, m.seq)
        or not integer(known, 0, 200000)
    then
        return
    end
    if known > m.seq then
        self.notice = "Recovery refused: peer has a newer sequence. Match paused."
        return
    end
    local items = {}
    for i = cursor + 1, math.min(cursor + 64, m.seq) do
        items[#items + 1] = m.journal[i]
    end
    self:Control(
        "chunk",
        target,
        { id = m.info.id, cursor = cursor, total = m.seq, log = table.concat(items, " "), digest = self:Digest(m) }
    )
end
function C:Chunk(data, sender)
    local m, r = self.match, self.recovery
    if
        not m
        or not r
        or sender ~= m.info.host
        or data.id ~= m.info.id
        or not integer(data.total, m.seq, 200000)
        or not integer(data.cursor, 0, data.total)
        or type(data.log) ~= "string"
        or #data.log > 3500
        or not checksum(data.digest)
    then
        return
    end
    if data.cursor == 0 then
        r.work = self:NewMatch(m.info)
        r.total = data.total
        r.digest = data.digest
    end
    if not r.work or data.cursor ~= r.work.seq or data.total ~= r.total or data.digest ~= r.digest then
        return
    end
    local count = 0
    for item in data.log:gmatch("%S+") do
        count = count + 1
        if count > 128 then
            return
        end
        local color, token = item:match("^([wb]):(.+)$")
        if not color then
            return
        end
        local n = self:Transition(r.work, color == "w" and m.info.white or m.info.black, token)
        if not n or n.seq > data.total then
            return
        end
        r.work = n
    end
    r.at = now()
    m.lastHeard = now()
    if r.work.seq == r.total then
        if r.total < m.seq or self:Digest(r.work) ~= r.digest then
            return
        end
        r.work.recovering = false
        r.work.lastHeard = now()
        self.match = r.work
        self.pending, self.recovery = nil, nil
        self:Save()
        self:Head()
        self:RefreshAll()
        if self.match.ended then
            self:RecordRecoveredFinal()
        end
    elseif count > 0 then
        self:Control("sync", sender, { id = m.info.id, known = m.seq, cursor = r.work.seq })
    end
end
function C:ReceiveControl(data, sender)
    if
        self.match and self.match.practice
        or not self:Party()
        or type(data) ~= "table"
        or data.target ~= Games:PlayerName()
        or data.version ~= VERSION
        or not Games:Roster()[sender]
        or sender == Games:PlayerName()
    then
        return
    end
    do
        local m = self.match
        if not m or data.id ~= m.info.id or sender ~= opponent(m.info) then
            return
        end
        if data.op == "interrupt" then
            self:Abandon("opponent_interrupted", true)
            return
        end
        if data.op == "head" and integer(data.seq, 0, 200000) and checksum(data.digest) then
            m.lastHeard = now()
            if
                sender == m.info.host
                and self.pending
                and data.rejected == self.pending.data.token
                and data.requestSeq == self.pending.data.seq
            then
                self.pending = nil
                self.notice = "Host rejected the action; the board is unchanged."
                self.actionNotice = self.notice
            end
            if data.seq == m.seq and data.digest == self:Digest(m) then
                m.recovering = false
                m.recoverSince = nil
                self.recovery = nil
                self:RefreshAll()
                if m.finished and not data.finished then
                    self:Head(sender)
                end
                if m.ended and not m.finished and Games:PlayerName() == m.info.host then
                    self:Finalize()
                end
            elseif Games:PlayerName() == m.info.host then
                if data.seq > m.seq then
                    m.recovering = true
                    m.recoverSince = m.recoverSince or now()
                else
                    self:Head()
                end
            else
                self:Recover()
            end
        elseif data.op == "sync" then
            self:SendChunk(sender, data.cursor, data.known)
        elseif data.op == "chunk" then
            self:Chunk(data, sender)
        end
    end
end
function C:Entries()
    local m = self.match
    local winner = m.ended.winner
    return {
        { player = m.info.white, outcome = winner == 0 and "draw" or winner == 1 and "win" or "loss" },
        { player = m.info.black, outcome = winner == 0 and "draw" or winner == -1 and "win" or "loss" },
    }
end
function C:ValidateResult(result, sender)
    local m = self.match
    if not m or m.info.host ~= sender or result.id ~= self:ResultID(m.info) then
        return false
    end
    if result.status == "aborted" then
        return true
    end
    if not m.ended then
        self:Recover()
        return false
    end
    local entries = {}
    for _, entry in ipairs(self:Entries()) do
        entries[entry.player] = entry.outcome
    end
    if #result.entries ~= 2 then
        return false
    end
    for _, entry in ipairs(result.entries) do
        if entries[entry.player] ~= entry.outcome then
            return false
        end
    end
    return true
end
function C:Finalize()
    local m = self.match
    if m and m.ended and not m.finished and Games:IsHost() and Games.ActiveGame then
        self.context:FinishGame({ summary = "Chess: " .. m.ended.reason, entries = self:Entries() })
    end
end
function C:RecordRecoveredFinal()
    local m = self.match
    if not m or not m.ended or m.finished then
        return
    end
    local sameLobby = Games.Lobby
        and Games.Lobby.gameID == "chess"
        and Games.Lobby.id == (m.info.sessionID or m.info.id)
        and Games.Lobby.run == (m.info.run or 1)
    if sameLobby and Games:IsHost() then
        self:Finalize()
        return
    end
    local result
    if sameLobby then
        result = Games:BuildResult(
            "completed",
            "finished",
            { summary = "Chess: " .. m.ended.reason, entries = self:Entries() }
        )
    else
        -- A verified terminal journal can arrive after a provisional local
        -- interruption. Do not replace a different game's current lobby.
        result = {
            id = self:ResultID(m.info),
            sessionID = m.info.sessionID or m.info.id,
            host = m.info.host,
            gameID = "chess",
            gameVersion = Games.Registry.chess.version,
            run = m.info.run or 1,
            startedAt = m.info.startedAt,
            endedAt = math.max(m.info.startedAt, GetServerTime()),
            status = "completed",
            reason = "finished",
            summary = "Chess: " .. m.ended.reason,
            entries = self:Entries(),
        }
    end
    if result then
        Games:RecordResult(result)
        self:OnResult(result)
        if sameLobby and not m.info.sessionID then
            Games:ResetLobby("reload")
        end
    end
end
function C:Abandon(reason, remote)
    local m = self.match
    if m and m.practice then
        self:StopPractice()
        return
    end
    if not m or m.finished or m.abandoned then
        return
    end
    if not remote then
        self:Control("interrupt", opponent(m.info), { id = m.info.id })
    end
    m.abandoned = true
    self.notice = "Chess interrupted: " .. reason .. ". No winner awarded."
    local result = Games:BuildResult("aborted", reason)
    if result then
        result.provisional = true
        Games:RecordResult(result)
    end
    self:Storage().active = nil
    Games:ResetLobby("reload")
    self:RefreshAll()
    Games:Notify(self.notice)
end
function C:Tick()
    if self.match and self.match.practice then
        return
    end
    local m = self.match
    if
        m
        and m.finished
        and not m.info.sessionID
        and Games.Lobby
        and Games.Lobby.gameID == "chess"
        and Games.Lobby.status == "waiting"
    then
        Games:ResetLobby("reload")
    end
    if not m or m.finished or m.abandoned then
        return
    end
    local present = false
    for _, name in ipairs(self:Eligible()) do
        if name == opponent(m.info) then
            present = true
        end
    end
    if not self:Party() or not present or now() - m.lastHeard > 20 then
        m.recovering = true
        m.recoverSince = m.recoverSince or now()
    end
    if m.recoverSince and now() - m.recoverSince > 120 then
        self:Abandon("recovery_timeout")
        return
    end
    if self.pending and now() - self.pending.at > 3 then
        self:Recover()
        self.pending = nil
    end
    if self.recovery and now() - self.recovery.at > 15 then
        self.recovery = nil
        self:Recover()
    end
    if now() - (self.lastPing or 0) >= 5 then
        self.lastPing = now()
        self:Head()
    end
    self:RefreshAll()
end
function C:Initialize()
    self:RegisterPracticeCommand()
    self:Storage()
    for _, result in ipairs(Games.DB.results) do
        if result.gameID == "chess" then
            self:RecordStats(result)
        end
    end
    local saved = self:Storage().active
    if type(saved) == "table" and self:InfoValid(saved.info) and actorSide(saved.info, Games:PlayerName()) then
        self.match = self:Replay(saved.info, saved.journal)
        if self.match then
            self:Begin(saved.info, true, saved.lobby)
        else
            self:Begin(saved.info, false)
            self:Abandon("invalid_recovery")
        end
    elseif saved ~= nil then
        self:Storage().active = nil
        Games:Notify("Chess recovery identity was invalid; the match was not resumed and no winner was awarded.")
    end
    self.ticker = C_Timer.NewTicker(1, function()
        self:Tick()
    end)
end
