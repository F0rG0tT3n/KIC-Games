local _, Games = ...
local B, R = Games.Blindshot, Games.Blindshot.Rules

-- Local-only harness for the real UI, phase runner and simulation. It creates no
-- framework lobby and never uses the party transport or result recorder.
function B:PracticeRandom(low, high)
    self.practiceSeed = self.practiceSeed * 48271 % 2147483647
    return low + self.practiceSeed % (high - low + 1)
end
function B:PreparePracticePlayers()
    local s = self.authority
    if self.practiceRound == s.round then
        return
    end
    self.practiceRound = s.round
    local function point()
        for _ = 1, 64 do
            local x, y = self:PracticeRandom(-s.radius, s.radius), self:PracticeRandom(-s.radius, s.radius)
            if R.Position(x, y, s.radius) then
                return x, y
            end
        end
        return 0, 0
    end
    for _, p in ipairs(s.players) do
        if p.alive and p.name ~= Games:PlayerName() then
            local x, y = point()
            local tx, ty = point()
            local dx, dy = R.Direction(tx - x, ty - y)
            s.drafts[p.name] = { x = x, y = y, dx = dx or 1000, dy = dy or 0, seq = 1, lock = true }
            p.locked = true
        end
    end
    if R.AllLocked(s) then
        R.Reveal(s, self:Now())
    end
    self.needsPublish = true
end
function B:FinishPractice(details)
    self.practiceResult = {
        id = self.session.id .. ":" .. self.session.run,
        practice = true,
        status = "completed",
        summary = details.summary,
        entries = Games.Copy(details.entries),
    }
    self:ShowResult(self.practiceResult)
    self:Render()
    return true
end
function B:StartPractice(reset, count)
    if count ~= nil and not R.Int(count, 2, 5) then
        return false, "Local Blindshot supports 2-5 players: /kicblindshottest [2-5 | new | stop]"
    end
    if self.practice and not reset and (not count or count == self.practiceCount) then
        Games.UI:ShowGame()
        return true
    end
    if Games.Lobby or Games.Pending or Games.ActiveGame and not self.practice then
        return false, "Finish or leave the current session before starting a local Blindshot test."
    end
    count = count or self.practiceCount or 5
    Games:StopModule("local_blindshot_restart")
    self.practiceSerial = (self.practiceSerial or 0) + 1
    self.practiceCount, self.practiceRound, self.practiceResult = count, nil, nil
    self.practiceSeed = (GetServerTime() + self.practiceSerial * 7919) % 2147483646 + 1
    self.practice = true
    local session = {
        id = "local-blindshot-" .. self.practiceSerial,
        run = 1,
        revision = 1,
        epoch = 0,
        host = Games:PlayerName(),
        channel = "PARTY",
        mode = "multiplayer",
        status = "running",
        gameID = "blindshot",
        gameVersion = Games.Registry.blindshot.version,
        countdownToken = 0,
        startedAt = GetServerTime(),
        members = {},
    }
    session.members[1] = { name = session.host, ready = true, version = session.gameVersion }
    for i = 2, count do
        local name = "TestPlayer" .. i .. "-Blindshot"
        if name == session.host then
            name = "OtherTestPlayer" .. i .. "-Blindshot"
        end
        session.members[i] = { name = name, ready = true, version = session.gameVersion }
    end
    local active = { game = Games.Registry.blindshot, context = {}, timers = {} }
    Games.ActiveGame = active
    local function current()
        return Games.ActiveGame == active and B.practice
    end
    local context = { isHost = true, player = Games:PlayerName() }
    function context:SendAction(event, data)
        if not current() then
            return false
        end
        if event == "blindshot_input" then
            B:HostAction(data, session.host)
        end
        return true
    end
    function context:SendState(event, data, target)
        if not current() then
            return false
        end
        if not target or target == session.host then
            B:Receive(event, data, session.host)
        end
        return true
    end
    function context:FinishGame(details)
        if not current() then
            return false
        end
        return B:FinishPractice(details)
    end
    function context:AbortGame()
        if current() then
            return B:StopPractice()
        end
        return false
    end
    function context:GetSession()
        return current() and Games.Copy(session) or nil
    end
    function context:NewTicker(seconds, callback)
        local timer = C_Timer.NewTicker(seconds, function()
            if current() then
                callback(context)
            end
        end)
        active.timers[timer] = true
        return timer
    end
    active.context = context
    local ok, frame = Games:CallGame("CreateUI", Games.UI:GetGameContainer())
    if not ok then
        Games:StopModule("error")
        return false, "Could not open the local Blindshot board."
    end
    active.frame = frame
    if self.resultWindow then
        self.resultWindow:Hide()
    end
    local started, err = pcall(self.Start, self, context, session, false, true)
    if not started then
        Games:StopModule("error")
        return false, "Local Blindshot could not start: " .. tostring(err)
    end
    Games.UI:ShowGame()
    return true
end
function B:StopPractice()
    if not self.practice then
        return false, "No local Blindshot test is running."
    end
    Games:StopModule("local_blindshot_stop")
    Games.UI:OpenLauncher("home")
    return true
end
function B:RegisterPracticeCommand()
    SLASH_KICBLINDSHOTTEST1 = "/kicblindshottest"
    SLASH_KICBLINDSHOTTEST2 = "/kicblindshot"
    SlashCmdList.KICBLINDSHOTTEST = function(input)
        local command = (input or ""):lower():match("^%s*(.-)%s*$")
        local number = tonumber(command) or tonumber(command:match("^new%s+(%d+)$"))
        local ok, err
        if command == "" or command == "test" then
            ok, err = self:StartPractice()
        elseif command == "new" or command == "reset" or number then
            ok, err = self:StartPractice(true, number)
        elseif command == "stop" or command == "exit" then
            ok, err = self:StopPractice()
        else
            ok, err = false, "Local Blindshot: /kicblindshottest [2-5 | new | stop]"
        end
        if ok == false and err then
            Games:Notify(err)
        end
    end
end
