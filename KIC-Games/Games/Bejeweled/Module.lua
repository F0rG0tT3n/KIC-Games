local _, Games = ...
local B = Games.Bejeweled
-- Texture FileDataIDs checked against the same archive index as the Tetris presets.
B.Gems = {
    { icon = 133251, name = "Ruby", color = { 1, 0.25, 0.35 } }, -- inv_jewelcrafting_livingruby_02
    { icon = 133268, name = "Sapphire", color = { 0.25, 0.6, 1 } }, -- inv_jewelcrafting_starofelune_02
    { icon = 133241, name = "Dawnstone", color = { 1, 0.85, 0.2 } }, -- inv_jewelcrafting_dawnstone_02
    { icon = 133255, name = "Amethyst", color = { 0.72, 0.35, 1 } }, -- inv_jewelcrafting_nightseye_02
    { icon = 133258, name = "Topaz", color = { 1, 0.5, 0.15 } }, -- inv_jewelcrafting_nobletopaz_02
    { icon = 133271, name = "Emerald", color = { 0.25, 0.95, 0.55 } }, -- inv_jewelcrafting_talasite_02
    { icon = 237236, name = "Diamond", color = { 0.8, 0.95, 1 } }, -- inv_jewelcrafting_icediamond_02
}
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
    title = "Bejeweled",
    version = "1",
    mode = "singleplayer",
    minPlayers = 1,
    maxPlayers = 1,
    description = "Swap neighboring WoW gems to match three or more. Chain cascades, beat your saved best and share it. Relaxed play, no time limit.",
    CreateUI = function(_, parent)
        return B:CreateUI(parent)
    end,
    OnStart = function(context)
        B.context, B.model = context, B.Engine.New()
        B.running, B.paused = true, false
        B.selected, B.hint, B.swap, B.fall = nil, nil, nil, nil
        B.phaseTime, B.message = 0, "Select a gem, then a neighbor."
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
