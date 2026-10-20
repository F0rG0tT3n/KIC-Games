local _, Games = ...
local M = Games.Minesweeper

function M:Storage()
    if type(Games.DB.minesweeper) ~= "table" then
        Games.DB.minesweeper = {}
    end
    local storage = Games.DB.minesweeper
    if not self.Engine.ByID[storage.difficulty] then
        storage.difficulty = "beginner"
    end
    if type(storage.best) ~= "table" then
        storage.best = {}
    end
    for _, difficulty in ipairs(self.Engine.Difficulties) do
        local best = storage.best[difficulty.id]
        if type(best) ~= "number" or best ~= best or best < 0 or best > 2147483647 then
            storage.best[difficulty.id] = nil
        end
    end
    return storage
end

function M:Elapsed()
    if self.finishedTime then
        return self.finishedTime
    end
    return self.startedAt and math.max(0, GetTime() - self.startedAt) or 0
end

function M:TimeText(seconds)
    if not seconds then
        return "--:--"
    end
    local tenths = math.floor(seconds * 10 + 0.00001)
    return string.format("%02d:%02d.%d", math.floor(tenths / 600), math.floor(tenths / 10) % 60, tenths % 10)
end

function M:NewGame(difficulty)
    if not self.Engine.ByID[difficulty] then
        return false
    end
    self:Storage().difficulty = difficulty
    if Games.ActiveGame then
        if Games.ActiveGame.game.id ~= "minesweeper" then
            return false
        end
        Games:AbortGame()
    end
    Games.UI:ClearCompletedGame()
    local ok, err = Games:StartSingleplayer("minesweeper")
    if ok == false and err then
        Games:Notify(err)
    end
    return ok
end

function M:Click(x, y, button)
    if not self.running or not self.context or not self.context:GetSession() then
        return
    end
    local changed
    if button == "RightButton" then
        changed = self.model:CycleMark(x, y)
    elseif button == "LeftButton" then
        changed = self.model:Reveal(x, y)
        if changed and not self.startedAt then
            self.startedAt = GetTime()
        end
    end
    if not changed then
        return
    end
    if self.model.state == "won" or self.model.state == "lost" then
        self:Complete()
    else
        self:Render()
    end
end

function M:Complete()
    if not self.running then
        return
    end
    self.finishedTime = self:Elapsed()
    local won, storage = self.model.state == "won", self:Storage()
    local previous = storage.best[self.model.difficulty]
    self.newBest = won and (not previous or self.finishedTime < previous)
    local context = self.context
    local difficulty = self.Engine.ByID[self.model.difficulty]
    local ok, err = context:FinishGame({
        summary = string.format(
            "%s - %s - %s",
            won and "WIN" or "LOSS",
            difficulty.title,
            self:TimeText(self.finishedTime)
        ),
        entries = {
            {
                player = context.player,
                score = self.model.revealed,
                outcome = won and "win" or "loss",
            },
        },
    })
    if ok then
        if self.newBest then
            storage.best[self.model.difficulty] = self.finishedTime
            Games:Changed()
        end
        self:Render()
        self:ShowResult()
    elseif err then
        Games:Notify(err)
    end
end

Games:RegisterGame({
    id = "minesweeper",
    title = "Minesweeper",
    icon = Games.Artwork["minesweeper-card"].file,
    version = "1",
    mode = "singleplayer",
    minPlayers = 1,
    maxPlayers = 1,
    description = "Reveal safe tiles, read the numbers and flag hidden mines. Three classic difficulties, a safe first reveal and saved best times.",
    CreateUI = function(_, parent)
        return M:CreateUI(parent)
    end,
    OnStart = function(context)
        M.context = context
        M.model = M.Engine.New(M:Storage().difficulty)
        M.running, M.startedAt, M.finishedTime, M.newBest, M.updateTime = true, nil, nil, false, 0
        M.summary:Hide()
        M.board:SetParent(M.root)
        M:LayoutUI()
        M.root:Show()
    end,
    OnStop = function()
        M.running, M.context = false, nil
        M.summary:Hide()
    end,
})

SLASH_KICMINESWEEPER1 = "/kicminesweeper"
SlashCmdList.KICMINESWEEPER = function()
    if Games.ActiveGame and Games.ActiveGame.game.id == "minesweeper" then
        Games.UI:ShowGame()
    else
        local ok, err = Games:StartSingleplayer("minesweeper")
        if ok == false and err then
            Games:Notify(err)
        end
    end
end
