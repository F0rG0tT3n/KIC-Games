local _, Games = ...
local C = Games.Chess
function C:Storage()
    if type(Games.DB.chess) ~= "table" then
        Games.DB.chess = {}
    end
    local db = Games.DB.chess
    if type(db.stats) ~= "table" then
        db.stats = {}
    end
    for _, key in ipairs({ "completed", "wins", "losses", "draws" }) do
        local v = db.stats[key]
        db.stats[key] = type(v) == "number" and v == v and v >= 0 and v <= 2147483647 and math.floor(v) or 0
    end
    db.stats.lastOpponent = type(db.stats.lastOpponent) == "string"
            and #db.stats.lastOpponent <= 100
            and db.stats.lastOpponent
        or nil
    local ended = db.lastEndedAt
    db.lastEndedAt = type(ended) == "number" and ended == ended and ended >= 0 and ended <= 9999999999 and ended or 0
    if type(db.counted) ~= "table" then
        db.counted = {}
    end
    return db
end
function C:RecordStats(result)
    if result.status ~= "completed" then
        return
    end
    local db = self:Storage()
    for _, id in ipairs(db.counted) do
        if id == result.id then
            return
        end
    end
    local own, other
    for _, entry in ipairs(result.entries) do
        if entry.player == Games:PlayerName() then
            own = entry
        else
            other = entry.player
        end
    end
    if not own or not other or not own.outcome then
        return
    end
    table.insert(db.counted, 1, result.id)
    while #db.counted > 256 do
        table.remove(db.counted)
    end
    db.stats.completed = db.stats.completed + 1
    local key = own.outcome == "win" and "wins" or own.outcome == "loss" and "losses" or "draws"
    db.stats[key] = db.stats[key] + 1
    if (db.lastEndedAt or 0) <= result.endedAt then
        db.stats.lastOpponent = other
        db.lastEndedAt = result.endedAt
    end
end
function C:OnResult(result)
    local m = self.match
    if not m or result.id ~= self:ResultID(m.info) then
        return
    end
    m.finished = true
    m.abandoned = result.status == "aborted"
    m.result = Games.Copy(result)
    self.notice = result.status == "completed" and result.summary or "Chess interrupted; no winner awarded."
    self:Storage().active = nil
    self:RecordStats(result)
    local san = {}
    for i = math.max(1, #m.state.san - 199), #m.state.san do
        san[#san + 1] = m.state.san[i]
    end
    self:Storage().lastGame = {
        id = result.id,
        moves = table.concat(san, " "),
        opponent = m.info.white == Games:PlayerName() and m.info.black or m.info.white,
    }
    self:RefreshAll()
    self:ShowResult(result)
end
-- A local test uses the real board and rules without creating a network lobby,
-- recovery save, result, or record. StopModule still owns the UI lifecycle.
function C:StartPractice(reset)
    local localMatch = self.match and self.match.practice
    if localMatch and not reset and Games.ActiveGame and Games.ActiveGame.game.id == "chess" then
        Games.UI:ShowGame()
        return true
    end
    if Games.Lobby or Games.Pending or Games.ActiveGame and not localMatch or self:Active() and not localMatch then
        return false, "Finish or leave the current session before starting a local Chess test."
    end
    Games:StopModule("local_chess_restart")
    self.practiceSerial = (self.practiceSerial or 0) + 1
    self.match = self:NewMatch({
        id = "local-chess-" .. self.practiceSerial,
        white = "Local White",
        black = "Local Black",
    })
    self.match.practice, self.match.recovering = true, false
    self.selected, self.claiming, self.pending, self.recovery = nil, nil, nil, nil
    self.notice, self.actionNotice = nil, nil
    if self.resultWindow then
        self.resultWindow:Hide()
    end
    local active = { game = Games.Registry.chess, context = {}, timers = {} }
    Games.ActiveGame = active
    local ok, frame = Games:CallGame("CreateUI", Games.UI:GetGameContainer())
    if not ok then
        Games:StopModule("error")
        return false, "Could not open the local Chess board."
    end
    active.frame = frame
    self.running = true
    frame:Show()
    self:Render()
    Games.UI:ShowGame()
    return true
end
function C:PracticeAction(token)
    local m = self.match
    if not m or not m.practice or not self.running or m.ended then
        return false, "This local game has ended. Start a new local game to play again."
    end
    local actor = m.state.turn == 1 and m.info.white or m.info.black
    if (token == "accept" or token == "decline") and m.offer then
        actor = m.offer == m.info.white and m.info.black or m.info.white
    end
    local nextMatch, err = self:Transition(m, actor, token)
    if not nextMatch then
        return false, err or "Illegal action."
    end
    self.match = nextMatch
    self:RefreshAll()
    if nextMatch.ended then
        local ended = nextMatch.ended
        self:ShowResult({
            practice = true,
            summary = (ended.winner == 0 and "Draw" or ended.winner == 1 and "White wins" or "Black wins")
                .. "\n"
                .. ended.reason,
            entries = {},
        })
    end
    return true
end
function C:StopPractice()
    if not self.match or not self.match.practice then
        return false, "No local Chess test is running."
    end
    Games:StopModule("local_chess_stop")
    Games.UI:OpenLauncher("home")
    return true
end
function C:RegisterPracticeCommand()
    SLASH_KICCHESSTEST1 = "/kicchesstest"
    SLASH_KICCHESSTEST2 = "/kicchess"
    SlashCmdList.KICCHESSTEST = function(text)
        local command = (text or ""):lower():match("^%s*(.-)%s*$")
        local ok, err
        if command == "" or command == "test" then
            ok, err = self:StartPractice()
        elseif command == "new" or command == "reset" then
            ok, err = self:StartPractice(true)
        elseif command == "stop" or command == "exit" then
            ok, err = self:StopPractice()
        else
            ok, err = false, "Local Chess: /kicchesstest [new | stop]"
        end
        if ok == false and err then
            Games:Notify(err)
        end
    end
end
Games:RegisterGame({
    id = "chess",
    title = "Chess",
    version = "2",
    mode = "multiplayer",
    minPlayers = 2,
    maxPlayers = 2,
    partyOnly = true,
    icon = Games.Artwork["chess-card"].file,
    description = "Host or join a two-player lobby in an ordinary party. Both players ready up to start. No clocks or AI.",
    CreateUI = function(_, parent)
        return C:CreateUI(parent)
    end,
    OnStart = function(context, session)
        C.context, C.running = context, true
        C:StartLobby(session)
        C.root:Show()
        C:Render()
    end,
    OnStop = function(_, reason)
        C.running = false
        C.pending = nil
        if C.promotion then
            C.promotion:Hide()
        end
        if C.match and C.match.practice then
            if C.resultWindow then
                C.resultWindow:Hide()
            end
            C.match, C.selected, C.claiming, C.recovery = nil, nil, nil, nil
            C.notice, C.actionNotice, C.promotionMove = nil, nil, nil
            return
        end
        if
            C.match
            and C.match.info.sessionID
            and (
                reason == "aborted"
                or reason == "left"
                or reason == "closed"
                or reason == "removed"
                or reason == "host_timeout"
            )
        then
            C.match.abandoned = true
            C:Storage().active = nil
            return
        end
        if C:Active() then
            C.match.recovering = true
            C.match.recoverSince = C.match.recoverSince or GetTime()
            C:Save()
        end
    end,
    OnMessage = function(_, event, data, sender, kind)
        if not C:Party() then
            return
        end
        if kind == "action" and event == "chess_action" then
            C:HostAction(data, sender)
        elseif kind == "state" and event == "chess_commit" then
            C:Commit(data, sender)
        end
    end,
    OnSyncRequested = function(_, sender)
        C:Head(sender)
    end,
    OnResult = function(_, result)
        C:OnResult(result)
    end,
})
