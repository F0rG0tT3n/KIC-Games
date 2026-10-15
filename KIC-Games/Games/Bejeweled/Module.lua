local _, Games = ...
local B = Games.Bejeweled
B.Gems = {}
for i, kind in ipairs(Games.IconPresets.Kinds) do
    B.Gems[i] = { color = Games.IconPresets.Colors[kind] }
end
local function number(value)
    return type(value) == "number" and value == value and value >= 0 and value <= 2147483647 and math.floor(value) or 0
end
function B:Storage()
    if type(Games.DB.bejeweled) ~= "table" then
        Games.DB.bejeweled = {}
    end
    local s = Games.DB.bejeweled
    if type(s.best) ~= "table" then
        s.best = {}
    end
    for _, key in ipairs({ "score", "moves", "cleared", "bestCascade" }) do
        s.best[key] = number(s.best[key])
    end
    return s
end
function B:ApplyPreset(token)
    local shared = Games.IconPresets
    local preset = shared.ByToken[token]
    if not preset then
        return
    end
    self.icons = {}
    for i, icon in ipairs(preset.icons) do
        self.icons[i] = icon
    end
    self.fallbackIcon = shared.FallbackIcons[token]
    if self.presetLabel then
        self.presetLabel:SetText(preset.name .. " icons")
    end
    self:Render()
end
function B:SaveBest()
    local m, s = self.model, self:Storage()
    if m and m.score > s.best.score then
        s.best = {
            score = m.score,
            moves = m.moves,
            cleared = m.cleared,
            bestCascade = m.bestCascade,
            achievedAt = GetServerTime(),
        }
    end
end
function B:ShareBest()
    if self.running then
        self:Pause(true)
        self:SaveBest()
    end
    local best = self:Storage().best
    local message = string.format(
        "KIC Bejeweled best: %d points | %d gems | %d moves | Cascade x%d",
        best.score,
        best.cleared,
        best.moves,
        best.bestCascade
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
function B:Complete()
    if not self.running then
        return
    end
    self:SaveBest()
    local m, context = self.model, self.context
    local details = string.format("%d points, %d gems, %d moves", m.score, m.cleared, m.moves)
    if context:FinishGame({ summary = details, entries = { { player = context.player, score = m.score } } }) then
        self.summaryText:SetText(
            string.format(
                "Score: %d\nBest: %d\nGems: %d    Moves: %d\nBest cascade: x%d",
                m.score,
                self:Storage().best.score,
                m.cleared,
                m.moves,
                m.bestCascade
            )
        )
        self.summary:Show()
    end
end
Games:RegisterGame({
    id = "bejeweled",
    icon = 133251,
    title = "Bejeweled",
    version = "1",
    mode = "singleplayer",
    minPlayers = 1,
    maxPlayers = 1,
    description = "Swap neighboring class ability icons to match three or more. Chain cascades, beat your saved best and share it. Relaxed play, no time limit.",
    CreateUI = function(_, parent)
        return B:CreateUI(parent)
    end,
    OnStart = function(context)
        B.context, B.model = context, B.Engine.New()
        B.running, B.paused = true, false
        B.selected, B.hint, B.swap, B.fall = nil, nil, nil, nil
        B.phaseTime, B.message = 0, "Select a gem, then a neighbor."
        B:ApplyPreset(Games:GetClassPreset())
        B.root:Show()
        B:Render()
    end,
    OnStop = function()
        B:SaveBest()
        B.running = false
        B.swap, B.fall, B.selected, B.hint = nil, nil, nil, nil
        B.context = nil
        if B.summary then
            B.summary:Hide()
        end
    end,
})
SLASH_KICBEJEWELED1 = "/kicbejeweled"
SlashCmdList.KICBEJEWELED = function(message)
    if message:lower():match("^%s*share%s*$") then
        B:ShareBest()
    elseif Games.ActiveGame and Games.ActiveGame.game.id == "bejeweled" then
        Games.UI:ShowGame()
    else
        local ok, err = Games:StartSingleplayer("bejeweled")
        if ok == false and err then
            Games:Notify(err)
        end
    end
end
