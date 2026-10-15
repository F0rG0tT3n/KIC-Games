local _, Games = ...
local T = Games.Tetris
local lineEvents = { "tetris_1_line", "tetris_2_lines", "tetris_3_lines", "tetris_4_lines" }
local function number(value)
    return type(value) == "number" and value == value and value >= 0 and value <= 2147483647 and math.floor(value) or 0
end
function T:Storage()
    local db = Games.DB
    if type(db.tetris) ~= "table" then
        db.tetris = {}
    end
    local s = db.tetris
    s.preset = Games:GetClassPreset()
    if type(s.best) ~= "table" then
        s.best = {}
    end
    s.best.score = number(s.best.score)
    s.best.lines = number(s.best.lines)
    s.best.level = math.max(1, number(s.best.level))
    if not self.ByToken[s.best.preset] and not Games.Profiles.byClass[s.best.preset] then
        s.best.preset = s.preset
    end
    return s
end
function T:SaveBest()
    local m, s = self.model, self:Storage()
    if m and m.score > s.best.score then
        s.best = {
            score = m.score,
            lines = m.lines,
            level = m.level,
            preset = s.preset,
            specID = select(2, Games:GetSelectedProfile()),
            graphicsTheme = Games:GetSettings().graphicsTheme,
            achievedAt = GetServerTime(),
        }
    end
    self.lastSavedScore = m and m.score
end
function T:ShareBest()
    if self.running then
        self:Pause(true)
        self:SaveBest()
    end
    local best = self:Storage().best
    local message = string.format(
        "KIC Tetris best: %d points | %d lines | Level %d | %s",
        best.score,
        best.lines,
        best.level,
        Games.Graphics:Label("tetris", best)
    )
    local channel = Games:GroupChannel()
    local prefix = channel == "INSTANCE_CHAT" and "/i "
        or channel == "RAID" and "/raid "
        or channel == "PARTY" and "/p "
        or "/s "
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if open then
        open(prefix .. message)
    else
        Games:Notify(message)
    end
end
function T:Complete()
    if not self.running then
        return
    end
    Games.Audio:Play("tetris", "gameOver")
    self:SaveBest()
    local m, context = self.model, self.context
    local score, lines, level = m.score, m.lines, m.level
    local ok = context:FinishGame({
        summary = string.format("%d points, %d lines, level %d", score, lines, level),
        entries = { { player = context.player, score = score } },
    })
    if ok then
        self.summaryText:SetText(
            string.format(
                "Score: %d\nLines: %d    Level: %d\nBest: %d\n%s",
                score,
                lines,
                level,
                self:Storage().best.score,
                Games.Graphics:Label("tetris")
            )
        )
        self.summary:Show()
    end
end
function T:AttachAudio(model)
    local move, rotate, hold, lock = model.Move, model.Rotate, model.Hold, model.Lock
    model.Move = function(m, dx, dy)
        local result = move(m, dx, dy)
        if result and dx ~= 0 then
            Games.Audio:Play("tetris", "move")
        end
        return result
    end
    model.Rotate = function(m, direction)
        local result = rotate(m, direction)
        if result then
            Games.Audio:Play("tetris", "move")
        end
        return result
    end
    model.Hold = function(m)
        local result = hold(m)
        if result then
            Games.Audio:Play("tetris", "select")
        end
        return result
    end
    model.Lock = function(m)
        local lines, ended = m.lines, m.gameover
        local result = lock(m)
        if not ended then
            local cleared = m.lines - lines
            Games.Audio:Play("tetris", lineEvents[cleared] or "land")
            if cleared > 0 then
                T:ShowLineEffect(cleared)
            end
        end
        return result
    end
end
Games:RegisterGame({
    id = "tetris",
    icon = 237284, -- inv_misc_dice_01; small blocks for the launcher
    iconPattern = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } },
    iconColor = { 0.8, 0.3, 1 },
    title = "Tetris",
    version = "1",
    mode = "singleplayer",
    minPlayers = 1,
    maxPlayers = 1,
    description = "Colorful Tetris with 13 WoW class icon presets. Clear lines, save your best score and share it to chat. Arrow keys, Space, C and P.",
    CreateUI = function(_, parent)
        return T:CreateUI(parent)
    end,
    OnStart = function(context)
        T.context = context
        T.model = T.Engine.New()
        T:AttachAudio(T.model)
        T.running, T.paused, T.drawRevision = true, false, nil
        T.lastSavedScore = nil
        T:ClearLineEffect()
        T:ReleaseKeys()
        T:Storage()
        T:ApplyPreset(Games:GetClassPreset())
        T.root:EnableKeyboard(true)
        T.root:Show()
    end,
    OnStop = function()
        T:SaveBest()
        T.running = false
        T:ClearLineEffect()
        T:ReleaseKeys()
        T.root:EnableKeyboard(false)
        T.summary:Hide()
        T.context = nil
    end,
})
SLASH_KICTETRIS1 = "/kictetris"
SlashCmdList.KICTETRIS = function(message)
    if message:lower():match("^%s*share%s*$") then
        T:ShareBest()
    else
        if Games.ActiveGame and Games.ActiveGame.game.id == "tetris" then
            Games.UI:ShowGame()
        else
            local ok, err = Games:StartSingleplayer("tetris")
            if ok == false and err then
                Games:Notify(err)
            end
        end
    end
end
