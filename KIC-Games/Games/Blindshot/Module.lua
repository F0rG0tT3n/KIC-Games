local _, Games = ...
local B, R = Games.Blindshot, Games.Blindshot.Rules
function B:Storage()
    if type(Games.DB.blindshot) ~= "table" then
        Games.DB.blindshot = {}
    end
    local db = Games.DB.blindshot
    if type(db.stats) ~= "table" then
        db.stats = {}
    end
    for _, key in ipairs({ "completed", "wins", "losses", "draws", "rounds", "eliminations" }) do
        if not R.Int(db.stats[key], 0, 2147483647) then
            db.stats[key] = 0
        end
    end
    if type(db.counted) ~= "table" then
        db.counted = {}
    end
    return db
end
function B:RecordStats(result)
    if result.practice or result.status ~= "completed" then
        return
    end
    local db = self:Storage()
    for _, id in ipairs(db.counted) do
        if id == result.id then
            return
        end
    end
    local own
    for _, entry in ipairs(result.entries) do
        if entry.player == Games:PlayerName() then
            own = entry
        end
    end
    if
        not own
        or not own.outcome
        or type(own.stats) ~= "table"
        or not R.Int(own.stats.rounds, 0, R.MAX_ROUNDS)
        or not R.Int(own.stats.eliminations, 0, 4)
    then
        return
    end
    table.insert(db.counted, 1, result.id)
    while #db.counted > 256 do
        table.remove(db.counted)
    end
    db.stats.completed = db.stats.completed + 1
    local key = own.outcome == "win" and "wins" or own.outcome == "draw" and "draws" or "losses"
    db.stats[key] = db.stats[key] + 1
    db.stats.rounds = db.stats.rounds + own.stats.rounds
    db.stats.eliminations = db.stats.eliminations + own.stats.eliminations
end
function B:OnResult(result)
    if not self.session or result.id ~= self.session.id .. ":" .. self.session.run then
        return
    end
    self:Storage().active = nil
    self:RecordStats(result)
    Games.UI:ShowHome()
    self:ShowResult(result)
end
function B:Initialize()
    self:RegisterPracticeCommand()
    local db = self:Storage()
    for _, result in ipairs(Games.DB.results) do
        if result.gameID == "blindshot" then
            self:RecordStats(result)
        end
    end
    local saved = db.active
    if saved == nil then
        return
    end
    if
        type(saved) ~= "table"
        or Games.Lobby
        or Games.ActiveGame
        or not self:SessionValid(saved.session)
        or saved.session.host == Games:PlayerName() and not R.ValidAuthority(saved.state, saved.session)
        or saved.session.host ~= Games:PlayerName() and not R.ValidView(saved.view, saved.session)
    then
        db.active = nil
        Games:Notify("Blindshot recovery was unavailable; no winner was awarded.")
        return
    end
    Games.Lobby = Games.Copy(saved.session)
    if not Games:StartModule(true) then
        db.active = nil
        Games:ResetLobby("reload")
        Games:Notify("Blindshot could not resume; no winner was awarded.")
    end
end
Games:RegisterGame({
    id = "blindshot",
    title = "Blindshot",
    version = "5",
    mode = "multiplayer",
    minPlayers = 2,
    maxPlayers = 5,
    partyOnly = true,
    icon = Games.Artwork["blindshot-card"].file,
    description = "Hide, aim and lock in. A random firing order decides who shoots first. Survive the shrinking arena. PARTY only, 2-5 players.",
    CreateUI = function(_, parent)
        return B:CreateUI(parent)
    end,
    OnStart = function(context, session, restored)
        B:Start(context, session, restored)
    end,
    OnStop = function(_, reason)
        B:CancelMouseInput()
        B.running, B.pending = false, nil
        if B.practice then
            B.practice, B.authority, B.view, B.session, B.draft = false, nil, nil, nil, nil
            B.practiceRound, B.dirty, B.notice = nil, false, nil
            if B.resultWindow then
                B.resultWindow:Hide()
            end
            return
        end
        -- /reload restores SavedVariables without invoking OnStop. Every actual
        -- teardown ends this local module; never resurrect a deliberately left match.
        B:Storage().active = nil
    end,
    OnMessage = function(_, event, data, sender, kind)
        if kind == "action" and event == "blindshot_ready" then
            B:RoundReady(data, sender)
        elseif kind == "action" and event == "blindshot_input" then
            B:HostAction(data, sender)
        elseif kind == "state" then
            B:Receive(event, data, sender)
        end
    end,
    OnSyncRequested = function(_, sender)
        B:SyncRequested(sender)
    end,
    OnResult = function(_, result)
        B:OnResult(result)
    end,
})
