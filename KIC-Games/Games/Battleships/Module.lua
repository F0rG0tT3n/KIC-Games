local _, Games = ...
local B, R = Games.Battleships, Games.Battleships.Rules

function B:Storage()
    if type(Games.DB.battleships) ~= "table" then
        Games.DB.battleships = {}
    end
    local db = Games.DB.battleships
    if type(db.stats) ~= "table" then
        db.stats = {}
    end
    for _, key in ipairs({ "completed", "wins", "losses" }) do
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
    if result.status ~= "completed" then
        return
    end
    local db = self:Storage()
    for _, id in ipairs(db.counted) do
        if id == result.id then
            return
        end
    end
    for _, entry in ipairs(result.entries) do
        if entry.player == Games:PlayerName() and (entry.outcome == "win" or entry.outcome == "loss") then
            table.insert(db.counted, 1, result.id)
            while #db.counted > 256 do
                table.remove(db.counted)
            end
            db.stats.completed = db.stats.completed + 1
            local key = entry.outcome == "win" and "wins" or "losses"
            db.stats[key] = db.stats[key] + 1
            return
        end
    end
end
function B:ShareBest()
    local s = self:Storage().stats
    return Games:ShareBestToGroup(
        string.format("KIC Battleships: %d wins / %d losses (%d matches)", s.wins, s.losses, s.completed)
    )
end
function B:Initialize()
    local db = self:Storage()
    for _, result in ipairs(Games.DB.results) do
        if result.gameID == "battleships" then
            self:RecordStats(result)
        end
    end
    local saved = db.active
    if saved == nil then
        return
    end
    if
        type(saved) ~= "table"
        or not Games:ValidData(saved)
        or Games.Lobby
        or Games.ActiveGame
        or not self:SessionValid(saved.session)
        or saved.session.host == Games:PlayerName() and not R.ValidAuthority(saved.state)
        or saved.session.host ~= Games:PlayerName() and saved.view ~= nil and not R.ValidView(saved.view, 2)
    then
        db.active = nil
        Games:Notify("Battleships recovery was unavailable; no winner was awarded.")
        return
    end
    Games.Lobby = Games.Copy(saved.session)
    if not Games:StartModule(true) then
        db.active = nil
        Games:ResetLobby("reload")
        Games:Notify("Battleships could not resume; no winner was awarded.")
    end
end
function B:Rematch()
    self.summary:Hide()
    Games.UI:OpenLauncher("multiplayer")
    if Games.Lobby and Games.Lobby.gameID == "battleships" and Games.Lobby.status == "waiting" then
        Games:Ready(true)
    end
end
Games:RegisterGame({
    id = "battleships",
    title = "Battleships",
    version = "1",
    mode = "multiplayer",
    minPlayers = 2,
    maxPlayers = 2,
    partyOnly = true,
    icon = 237284,
    description = "Deploy five ships, then take turns firing at the hidden enemy fleet. Sink them all to win. PARTY only, 2 players.",
    CreateUI = function(_, parent)
        return B:CreateUI(parent)
    end,
    OnStart = function(context, session, restored)
        B:Start(context, session, restored)
    end,
    OnStop = function(_, reason)
        B.running, B.pending, B.hover = false, nil, nil
        B:Storage().active = nil
        B.root:EnableKeyboard(false)
        B.root:SetPropagateKeyboardInput(true)
        if reason == "completed" and B.result then
            -- A result can still arrive after all final-board packets were
            -- lost. Keep the last known board and show the confirmed outcome.
            B.view = B.view or R.View(R.New(1), B.seat)
            Games.UI.completedGame = { game = Games.Registry.battleships, frame = B.root }
            Games.UI:ShowGame()
            B:Render()
            B:ShowResult()
        else
            B.summary:Hide()
        end
    end,
    OnMessage = function(_, event, data, sender, kind)
        if kind == "state" then
            B:Receive(event, data, sender)
        elseif event == "bs_input" then
            B:HostAction(data, sender)
        elseif B.authority and B:Seat(sender) == 2 then
            if event == "bs_ping" then
                B:SyncRequested(sender)
            elseif
                event == "bs_end_ack"
                and type(data) == "table"
                and data.rev == B.authority.rev
                and B.authority.phase == "ended"
            then
                B.endAck = true
            end
        end
    end,
    OnSyncRequested = function(_, sender)
        B:SyncRequested(sender)
    end,
    OnResult = function(_, result)
        if B.session and result.id == B.session.id .. ":" .. B.session.run then
            B.result = Games.Copy(result)
            B:RecordStats(result)
        end
    end,
})
