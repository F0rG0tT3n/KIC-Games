local _, Games = ...
-- Shared lifecycle; each call closes over its own controller and storage ID.
function Games:RegisterBejeweledModule(B, id, title, slash)
    B.gameID = id
    B.Gems = {}
    for i, kind in ipairs(Games.IconPresets.Kinds) do
        B.Gems[i] = { color = Games.IconPresets.Colors[kind] }
    end
    local function number(value)
        return type(value) == "number" and value == value and value >= 0 and value <= 2147483647 and math.floor(value)
            or 0
    end
    function B:Storage()
        if type(Games.DB[id]) ~= "table" then
            Games.DB[id] = {}
        end
        local s = Games.DB[id]
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
        self.icons = Games:GetPieceIcons(id)
        self.fallbackIcon = shared.FallbackIcons[token] or shared.FallbackIcons.MAGE
        if self.ExtendPieces then
            self:ExtendPieces()
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
            "KIC " .. title .. " best: %d points - %d gems - %d moves - Cascade x%d",
            best.score,
            best.cleared,
            best.moves,
            best.bestCascade
        )
        return Games:ShareBestToInstance(message)
    end
    function B:Complete()
        if not self.running then
            return
        end
        Games.Audio:Play(id, "gameOver")
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
        id = id,
        icon = 133251,
        title = title,
        version = "1",
        mode = "singleplayer",
        minPlayers = 1,
        maxPlayers = 1,
        description = B.description
            or "Swap neighboring class ability icons to match three or more. Chain cascades, beat your saved best and share it. Relaxed play, no time limit.",
        CreateUI = function(_, parent)
            return B:CreateUI(parent)
        end,
        OnStart = function(context)
            B:CancelDrag()
            B:ClearMatchEffect()
            B.context, B.model = context, B.Engine.New()
            B.running, B.paused = true, false
            B.selected, B.hint, B.swap, B.fall = nil, nil, nil, nil
            B.phaseTime, B.message = 0, "Select a gem, then a neighbor."
            B.scoreIdleTime, B.hintPulseTime, B.matchEffect, B.effectPending = 0, 0, nil, nil
            B.hintsRemaining = 3
            B.effectBanner:Hide()
            B.effectDetail:Hide()
            B.effectFlash:SetAlpha(0)
            for _, cell in ipairs(B.cells) do
                cell.spark:SetAlpha(0)
            end
            for _, particle in ipairs(B.effectParticles) do
                particle:Hide()
            end
            B:ApplyPreset(Games:GetClassPreset())
            B.root:Show()
            B:Render()
        end,
        OnStop = function()
            B:CancelDrag()
            B:SaveBest()
            B.running = false
            B.swap, B.fall, B.selected, B.hint = nil, nil, nil, nil
            B:ClearMatchEffect()
            B.effectPending = nil
            B.effectBanner:Hide()
            B.effectDetail:Hide()
            B.effectFlash:SetAlpha(0)
            for _, cell in ipairs(B.cells) do
                cell.spark:SetAlpha(0)
            end
            for _, particle in ipairs(B.effectParticles) do
                particle:Hide()
            end
            B.context = nil
            if B.summary then
                B.summary:Hide()
            end
        end,
    })
    _G["SLASH_" .. slash .. "1"] = "/" .. slash:lower()
    SlashCmdList[slash] = function(message)
        if message:lower():match("^%s*share%s*$") then
            B:ShareBest()
        elseif Games.ActiveGame and Games.ActiveGame.game.id == id then
            Games.UI:ShowGame()
        else
            local ok, err = Games:StartSingleplayer(id)
            if ok == false and err then
                Games:Notify(err)
            end
        end
    end
end
Games:RegisterBejeweledModule(Games.Bejeweled, "bejeweled", "Bejeweled", "KICBEJEWELED")
