local _, Games = ...
local D, Theme = Games.KICBejeweled, Games.Theme
local R = D.Roguelite
local baseCreateUI, baseLayoutUI, baseAdvance = D.CreateUI, D.LayoutUI, D.Advance
local baseBlocked, baseRender, baseStorage = D.Blocked, D.Render, D.Storage
local white = "Interface\\Buttons\\WHITE8X8"
local rarityColors = {
    common = { 0.75, 0.8, 0.9 },
    rare = { 0.22, 0.7, 1 },
    epic = { 0.72, 0.4, 1 },
    legendary = { 1, 0.76, 0.18 },
}

local function powerSummary(run, maxLines)
    local lines = {}
    for _, card in ipairs(R.Cards) do
        local count = run:Stacks(card.id)
        if count > 0 then
            lines[#lines + 1] = card.title .. (count > 1 and " x" .. count or "")
        end
    end
    if #lines == 0 then
        return "No powers yet. Reach max Energy to draft one.", "No upgrades"
    end
    local full = table.concat(lines, ", ")
    if run.tunedKind then full = full .. "\nAttuned gem type: " .. run.tunedKind end
    maxLines = math.max(2, maxLines or 5)
    if #lines > maxLines then
        local visible = {}
        for i = 1, maxLines - 1 do
            visible[#visible + 1] = lines[i]
        end
        visible[#visible + 1] = "+" .. (#lines - (maxLines - 1)) .. " more"
        return table.concat(visible, "\n"), full
    end
    return table.concat(lines, "\n"), full
end

-- Existing KIC Bejeweled records stay in the original best field. Arcane Rush has its
-- own score bucket because timed-survival scores are not comparable with old
-- no-timer KIC Bejeweled records. Neither mode overwrites the other.
function D:Storage()
    local s = baseStorage(self)
    if self:GetMode() == "normal" then return s end
    if type(s.arcaneRush) ~= "table" then
        s.arcaneRush = {}
    end
    if type(s.arcaneRush.best) ~= "table" then
        s.arcaneRush.best = { score = 0, moves = 0, cleared = 0, bestCascade = 0 }
    end
    return { best = s.arcaneRush.best }
end
function D:SaveBest()
    local m = self.model
    if not m or self.choosingMode then
        return
    end
    local s = baseStorage(self)
    if self:GetMode() == "normal" then
        if m.score > s.best.score then
            s.best = { score = m.score, moves = m.moves, cleared = m.cleared,
                bestCascade = m.bestCascade, achievedAt = GetServerTime() }
        end
        return
    end
    if type(s.arcaneRush) ~= "table" then
        s.arcaneRush = {}
    end
    local best = s.arcaneRush.best
    if type(best) ~= "table" or type(best.score) ~= "number" or m.score > best.score then
        s.arcaneRush.best = {
            score = m.score, moves = m.moves, cleared = m.cleared,
            bestCascade = m.bestCascade, achievedAt = GetServerTime(),
            ascension = self.run and self.run.level or 0,
        }
    end
end
function D:OnRunStopped()
    self:StopReshuffleAnimation()
    self.deferredReshuffle = nil
    if self.draftDim then
        self.draftDim:Hide()
    end
    if self.modeDim then self.modeDim:Hide() end
    self.choosingMode = false
end
function D:Blocked()
    return self.choosingMode or self.shuffleAnimation ~= nil or (self.run and self.run.pending) or baseBlocked(self)
end

-- Score was already committed by the engine at each cleared wave. Credit the
-- matching Energy immediately and pause between waves for an upgrade draft.
-- The current clear is committed; only future gravity/cascade steps are held.
function D:Advance(dt)
    if self.choosingMode then return end
    if not self.running or not self.run then
        return baseAdvance(self, dt)
    end
    if self.shuffleAnimation then
        -- The reshuffle is a game input lock, not a WoW protected frame block.
        -- Never tick survival Energy during this cosmetic animation.
        if self.root:IsVisible() and not self.paused then
            self:AdvanceReshuffleAnimation(dt)
        end
        return
    end
    if self.run.pending or self.run.over then
        return
    end
    local m, run = self.model, self.run
    local interactive = self.root:IsVisible()
        and not self.paused and not self.swap and not self.fall
        and m.phase == "idle" and not baseBlocked(self)
    local tick = run:Tick(dt, interactive)
    if tick == "depleted" then
        self.message = "Energy depleted!"
        m.gameover, m.phase = true, "over"
        self:Complete()
        return
    elseif tick == "second_wind" then
        self.message = "SECOND WIND! Energy restored!"
    end
    if m.moves > run.trackedMoves then
        run.trackedMoves = m.moves
        run.inMove = true
        run:OnSwap()
    end
    local previousResolution = m.lastResolution
    baseAdvance(self, dt)
    if self.model ~= m or not self.running then
        return
    end
    -- Observe each unique engine clear resolution (not the capped score), so
    -- Energy updates on the same wave as its score, with no double credit.
    if m.lastResolution and m.lastResolution ~= previousResolution then
        local wave = m.lastResolution
        run:OnWave(wave.gain or m.lastGain or 0, wave.events, wave.cascade or m.cascade,
            wave.count, wave.longest, wave.attunedMatch)
        if run.pending then
            -- Step() has already committed this wave and moved the model to
            -- "falling". The next Step() cannot run until PickUpgrade closes
            -- this modal, so the remaining chain is preserved exactly.
            self:PresentUpgradeDraft()
            self:RefreshEnergy()
            return
        end
    end
    if run.inMove and m.phase == "idle" and not self.swap and not self.fall then
        run.inMove = false
        run:SettleMove()
        -- Deferred generators still execute exactly once per complete swap,
        -- even if several drafts interrupted its individual cascade waves.
        run:AfterMove(m)
        if self.deferredReshuffle then
            self:ApplyDeferredReshuffle()
        end
        if run.pending then
            self:PresentUpgradeDraft()
        end
        self:Render()
    end
    self:RefreshEnergy()
end
function D:Complete()
    if not self.running or self.choosingMode then
        return
    end
    if self.mode == "normal" then
        Games.Audio:Play(self.gameID, "gameOver")
        self:SaveBest()
        local m, context = self.model, self.context
        local details = string.format("Normal: %d points, %d gems, %d moves", m.score, m.cleared, m.moves)
        if context:FinishGame({ summary = details, entries = { { player = context.player, score = m.score } } }) then
            self.summaryHeading:SetText("NO MOVES LEFT")
            self.summaryText:SetText(string.format(
                "Normal mode\nScore: %d\nBest: %d\nGems: %d    Moves: %d\nBest cascade: x%d",
                m.score, self:Storage().best.score, m.cleared, m.moves, m.bestCascade))
            self.summary:Show()
        end
        return
    end
    -- An in-cascade Reshuffle choice is scheduled for a stable board. The
    -- engine can find no moves at the end of refill; give the scheduled
    -- reshuffle its one chance to rescue that board before completing.
    if self.deferredReshuffle and self.model and self.model.phase == "over" then
        local m = self.model
        m.phase, m.gameover = "idle", false
        if self:ApplyDeferredReshuffle() then
            return
        end
        m.phase, m.gameover = "over", true
    end
    Games.Audio:Play(self.gameID, "gameOver")
    self:SaveBest()
    local m, context, run = self.model, self.context, self.run
    local time = run and run.survived or 0
    local level = run and run.level or 0
    local details = string.format("Roguelike: %d points; Ascension %d; %ds survived", m.score, level, math.floor(time))
    if context:FinishGame({ summary = details, entries = { { player = context.player, score = m.score } } }) then
        self.summaryHeading:SetText(run and run.over and "ENERGY DEPLETED" or "RUN COMPLETE")
        self.summaryText:SetText(string.format(
            "Score: %d   |   Best: %d\nAscension: %d   |   Survival: %02d:%02d\nGems: %d   Moves: %d   Cascade: x%d\nBuild: %s",
            m.score, self:Storage().best.score, level, math.floor(time / 60), math.floor(time % 60),
            m.cleared, m.moves, m.bestCascade, run and run:BuildText():sub(1, 100) or "No upgrades"
        ))
        self.summary:Show()
    end
end

function D:RefreshEnergy()
    if not self.run then
        return
    end
    local run = self.run
    local fraction = math.min(1, math.max(0, run.energy / run.maxEnergy))
    if self.energyBarFill and self.energyBarRail then
        local height = math.max(1, (self.energyBarRail:GetHeight() - 4) * fraction)
        self.energyBarFill:SetHeight(height)
        self.energyBarFill:SetVertexColor(fraction < 0.2 and 1 or 0.75, fraction < 0.2 and 0.22 or 0.62,
            fraction < 0.2 and 0.3 or 1, 1)
    end
    if self.energyValue then
        self.energyValue:SetText(string.format("%d / %d", math.floor(run.energy + 0.5), run.maxEnergy))
    end
    if self.energyInfo then
        self.energyInfo:SetText(string.format("ASCENSION %d", run.level))
    end
    if self.energyDrain then
        self.energyDrain:SetText(string.format("DRAIN %.1f/s", run:DrainRate()))
    end
    if self.energyHint then
        if run.pending then
            self.energyHint:SetText("CHOOSE POWER")
        elseif fraction < 0.2 then
            self.energyHint:SetText("LOW ENERGY!")
        else
            self.energyHint:SetText("Fill to upgrade")
        end
    end
    -- This runs during the game's OnUpdate. Build long power lists only when
    -- a card was actually acquired, not on every rendered Energy tick.
    if self.powerSummaryRun ~= run or self.powerSummaryRevision ~= run.buildRevision then
        local summary, full = powerSummary(run, 5)
        self.powerSummaryFull = full
        self.powerSummaryRun = run
        self.powerSummaryRevision = run.buildRevision
        if self.tipText then self.tipText:SetText(summary) end
        if self.tipPanel then self.tipPanel.buildDescription = full end
    end
    if self.statusText then self.statusText:SetText("ACTIVE POWERS") end
end
function D:Render()
    baseRender(self)
    if self.mode == "roguelike" and self.model and self.scoreText then
        Theme:ScoreValue(self.scoreText, self.model.score, 48)
    end
    -- The underlying board stays in its final arrangement, but during the
    -- reshuffle its icons are represented solely by the moving overlay sprites.
    if self.shuffleAnimation then
        for _, boardCell in ipairs(self.cells or {}) do
            boardCell.icon:Hide()
            local art = boardCell.specialArt
            if art then
                art.label:Hide()
                art.backdrop:Hide()
                art.glow:Hide()
                art.overlay:Hide()
            end
        end
    end
    if self.energyFrame then
        self:RefreshEnergy()
    end
end
function D:PresentUpgradeDraft()
    if not self.draftDim or not self.run or not self.run.pending then
        return
    end
    self.draftSubtitle:SetText(self.deferredReshuffle
        and "Reshuffle already queued. Choose a power to continue the cascade."
        or (#self.run.offers > 0
            and "Choose a power now; the cascade resumes afterward"
            or "All powers maxed. Reshuffle the board to continue"))
    if self.shuffleDraftButton then
        if self.deferredReshuffle then self.shuffleDraftButton:Disable()
        else self.shuffleDraftButton:Enable() end
    end
    for i, cardFrame in ipairs(self.draftCards) do
        local card = self.run.offers[i]
        cardFrame:SetShown(card ~= nil)
        if card then
            local color = rarityColors[card.rarity] or rarityColors.common
            cardFrame.cardData = card
            cardFrame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            cardFrame.name:SetText(card.title)
            cardFrame.name:SetTextColor(color[1], color[2], color[3], 1)
            cardFrame.rarity:SetText(string.upper(card.rarity))
            cardFrame.rarity:SetTextColor(color[1], color[2], color[3], 1)
            cardFrame.description:SetText(card.description)
            -- Keep illustration colors intact; only the frame/name carry rarity tint.
            Theme:SetArt(cardFrame.emblem, card.artKey or "icon-gem", 90, 90, 1)
            cardFrame.emblem:SetVertexColor(1, 1, 1, 1)
            cardFrame.artBorder:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            cardFrame.stack:SetText("Owned: " .. self.run:Stacks(card.id) .. " / " .. (card.max == math.huge and "∞" or card.max))
            cardFrame.button:SetText("CHOOSE " .. i)
        end
    end
    self.draftDim:Show()
    self:CancelDrag()
end
-- Cosmetic permutation animation: all 64 existing pieces move from their
-- exact old tile to the tile selected by the validated engine reshuffle.
-- The game state is final immediately; only presentation/input waits 0.85s.
function D:StopReshuffleAnimation()
    self.shuffleAnimation = nil
    for _, sprite in ipairs(self.shuffleSprites or {}) do sprite:Hide() end
end
function D:PositionReshuffleSprites(progress)
    local a = self.shuffleAnimation
    if not a then return end
    -- Smooth ease-in/ease-out, visibly trackable across the complete board.
    local t = math.max(0, math.min(1, progress))
    local eased = t * t * (3 - 2 * t)
    for destination = 1, 64 do
        local sprite = self.shuffleSprites[destination]
        local from = a.sourceByDestination[destination]
        local sx, sy = (from - 1) % 8, math.floor((from - 1) / 8)
        local dx, dy = (destination - 1) % 8, math.floor((destination - 1) / 8)
        sprite:ClearAllPoints()
        sprite:SetPoint("TOPLEFT", self.viewport, "TOPLEFT",
            (sx + (dx - sx) * eased) * self.step,
            -(sy + (dy - sy) * eased) * self.step)
    end
end
function D:BeginReshuffleAnimation(permutation)
    if not permutation or not permutation.sourceByDestination then return false end
    self.shuffleSprites = self.shuffleSprites or {}
    for destination = 1, 64 do
        local sprite = self.shuffleSprites[destination]
        if not sprite then
            sprite = CreateFrame("Frame", nil, self.viewport)
            sprite:EnableMouse(false)
            sprite.icon = sprite:CreateTexture(nil, "ARTWORK")
            sprite.icon:SetPoint("TOPLEFT", 5, -5)
            sprite.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
            self.shuffleSprites[destination] = sprite
        end
        sprite:SetFrameLevel(self.viewport:GetFrameLevel() + 20)
        sprite:SetSize(self.tileSize, self.tileSize)
        sprite.icon:SetSize(self.tileSize - 10, self.tileSize - 10)
        local y, x = math.floor((destination - 1) / 8) + 1, (destination - 1) % 8 + 1
        local piece = self.model.board[y][x]
        if sprite.icon:SetTexture(self.icons[piece]) == false then
            sprite.icon:SetTexture(self.fallbackIcon)
        end
        self:PaintSpecial(sprite, piece)
        sprite:Show()
    end
    self.shuffleAnimation = { sourceByDestination = permutation.sourceByDestination,
        time = 0, duration = 0.85 }
    self:PositionReshuffleSprites(0)
    self:Render()
    return true
end
function D:AdvanceReshuffleAnimation(dt)
    local a = self.shuffleAnimation
    if not a then return end
    a.time = math.min(a.duration, a.time + math.max(0, math.min(0.1, dt or 0)))
    self:PositionReshuffleSprites(a.time / a.duration)
    if a.time >= a.duration then
        self:StopReshuffleAnimation()
        self:Render()
    end
end
-- Deferred reshuffle is used only if the player chooses the fourth option
-- during an unfinished cascade. ReshuffleAll requires a full idle 8x8 board.
function D:ApplyDeferredReshuffle()
    if not self.deferredReshuffle or not self.model then return false end
    local m = self.model
    if m.phase ~= "idle" or m.gameover then return false end
    self.deferredReshuffle = nil
    if not m:ReshuffleAll() then
        self.message = "Could not reshuffle after the cascade."
        return false
    end
    local permutation = m.lastShuffle
    self.selected, self.hint, self.phaseTime = nil, nil, 0
    self.message = "All gems reshuffled! No upgrade selected."
    if not self:BeginReshuffleAnimation(permutation) then self:Render() end
    m.lastShuffle = nil
    return true
end
function D:ReshuffleDraft()
    if not self.run or not self.run.pending or not self.model then
        return
    end
    if self.model.phase ~= "idle" then
        -- Do not attempt to permute a half-cleared/half-refilled board.
        -- Consume the reshuffle choice now, resume remaining chain waves,
        -- and animate the actual permutation once the board is stable.
        if self.deferredReshuffle then
            self.draftSubtitle:SetText("A reshuffle is already queued. Choose a power.")
            return
        end
        if not self.run:FinishReshuffleDraft() then return end
        self.deferredReshuffle = true
        self.draftDim:Hide()
        self:CancelDrag()
        self.message = "Reshuffle queued after the cascade."
        self:Render()
        return
    end
    -- The model keeps the original source index for each destination, even
    -- when two gems share the same class icon or an identical special type.
    if not self.model:ReshuffleAll() then
        self.message = "Unable to reshuffle safely. Choose a power or try again."
        self.draftSubtitle:SetText("Shuffle unavailable. Try again or choose a power.")
        return
    end
    local permutation = self.model.lastShuffle
    if not self.run:FinishReshuffleDraft() then
        return
    end
    self.draftDim:Hide()
    self:CancelDrag()
    self.selected, self.hint, self.phaseTime = nil, nil, 0
    self.message = "All gems reshuffled! No upgrade selected."
    if not self:BeginReshuffleAnimation(permutation) then
        self:Render()
    end
    self.model.lastShuffle = nil
end

function D:PickUpgrade(i)
    if not self.run or not self.run.pending then
        return
    end
    local card = self.run.offers[i]
    if not card or not self.run:Choose(card.id) then
        return
    end
    self.draftDim:Hide()
    self.message = card.title .. " acquired!"
    self:Render()
end

function D:CreateUI(parent)
    if self.root then
        self:LayoutUI()
        return self.root
    end
    baseCreateUI(self, parent)
    -- Use the original Bejeweled board geometry unchanged. The compact vertical
    -- Energy HUD shares a compact, coordinated statistics column.
    local frame = Theme:PremiumFrame(self.right, 210, 120, 0, 0, { compact = true })
    frame:SetFrameLevel(self.right:GetFrameLevel() + 2)
    self.energyFrame = frame
    self.energyTitle = Theme:Label(frame, "ENERGY", 12, -10, 170, "GameFontNormalLarge")
    self.energyTitle:SetTextColor(unpack(Theme.Colors.violet))
    self.energyValue = Theme:Label(frame, "70 / 100", 12, -38, 170)
    self.energyInfo = Theme:Label(frame, "ASCENSION 0", 12, -62, 170, "GameFontHighlightSmall")
    self.energyDrain = Theme:Label(frame, "DRAIN 4.0/s", 12, -82, 170, "GameFontHighlightSmall")
    self.energyHint = Theme:Label(frame, "Fill to upgrade", 12, -102, 170, "GameFontHighlightSmall")
    self.energyHint:SetTextColor(unpack(Theme.Colors.accent))
    local energyBar = Theme:PremiumFrame(self.root, 40, 320, 0, 0, { compact = true })
    energyBar:SetFrameLevel(self.board:GetFrameLevel() + 3)
    self.energyBarFrame = energyBar
    self.energyBarRail = Theme:Panel(energyBar, 20, 280, 0, 0)
    self.energyBarRail:SetBackdropColor(0.025, 0.055, 0.13, 1)
    self.energyBarFill = self.energyBarRail:CreateTexture(nil, "ARTWORK")
    self.energyBarFill:SetPoint("BOTTOMLEFT", self.energyBarRail, "BOTTOMLEFT", 2, 2)
    self.energyBarFill:SetPoint("BOTTOMRIGHT", self.energyBarRail, "BOTTOMRIGHT", -2, 2)
    self.energyBarFill:SetHeight(1)
    self.energyBarFill:SetTexture(white)
    self.energyBarFill:SetVertexColor(0.75, 0.62, 1, 1)
    self.tipPanel:EnableMouse(true)
    self.tipPanel:SetScript("OnEnter", function(f)
        if not self.run then return end
        GameTooltip:SetOwner(f, "ANCHOR_LEFT")
        GameTooltip:SetText("ACTIVE POWERS")
        GameTooltip:AddLine(f.buildDescription or "No upgrades", 0.78, 0.86, 1, true)
        GameTooltip:Show()
    end)
    self.tipPanel:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.draftDim = CreateFrame("Frame", nil, self.root, "BackdropTemplate")
    self.draftDim:SetAllPoints(self.root)
    self.draftDim:SetFrameLevel(self.root:GetFrameLevel() + 80)
    self.draftDim:EnableMouse(true)
    self.draftDim:SetBackdrop({ bgFile = white })
    self.draftDim:SetBackdropColor(0, 0.008, 0.024, 0.8)
    local modal = Theme:PremiumFrame(self.draftDim, 790, 480, 0, 0)
    modal:ClearAllPoints()
    modal:SetPoint("CENTER", self.draftDim, "CENTER")
    self.draftWindow = modal
    local title = Theme:Label(modal, "ARCANE ASCENSION", 24, -19, 742, "GameFontNormalLarge")
    title:SetFont(Theme.Fonts.display, 29, "OUTLINE")
    title:SetTextColor(unpack(Theme.Colors.violet))
    title:SetJustifyH("CENTER")
    local subtitle = Theme:Label(modal, "Choose one power to keep for this run", 24, -57, 742)
    subtitle:SetJustifyH("CENTER")
    self.draftSubtitle = subtitle
    self.draftCards = {}
    for i = 1, 3 do
        local card = Theme:Panel(modal, 236, 293, 21 + (i - 1) * 256, -99)
        card.name = Theme:Label(card, "", 12, -21, 212, "GameFontNormalLarge")
        card.name:SetJustifyH("CENTER")
        card.rarity = Theme:Label(card, "", 12, -54, 212, "GameFontHighlightSmall")
        card.rarity:SetJustifyH("CENTER")
        -- Shared category painting, framed separately so rarity stays visible.
        card.artBorder = Theme:Panel(card, 96, 96, 70, -75)
        card.emblem = Theme:Art(card.artBorder, "icon-gem", 90, 90, 3, -3)
        card.description = Theme:Label(card, "", 14, -174, 208)
        card.description:SetJustifyH("CENTER")
        card.description:SetHeight(56)
        card.stack = Theme:Label(card, "", 14, -232, 208, "GameFontHighlightSmall")
        card.stack:SetJustifyH("CENTER")
        card.button = Theme:NeonButton(card, "CHOOSE", 186, 25, -255, function()
            self:PickUpgrade(i)
        end, 30, true)
        self.draftCards[i] = card
    end
    self.shuffleDraftButton = Theme:NeonButton(modal, "RESHUFFLE ALL GEMS", 330,
        230, -405, function() self:ReshuffleDraft() end, 33, false)
    self.shuffleDraftArtwork = Theme:Art(self.shuffleDraftButton, "upgrade-reshuffle", 27, 27, 9, -3)
    local foot = Theme:Label(modal,
        "Reshuffle grants no upgrade. Energy resets to 50% of max (plus Recovery).",
        22, -450, 746, "GameFontHighlightSmall")
    foot:SetJustifyH("CENTER")
    self.draftDim:Hide()
    self:CreateModePicker()
    self.summaryText:SetFont(Theme.Fonts.body, 14, "")
    self.summaryText:SetHeight(115)
    self:LayoutUI()
    return self.root
end
function D:LayoutUI()
    -- Critically, do not recalculate self.step or reposition self.board here:
    -- the base renderer owns those dimensions, exactly as in plain Bejeweled.
    baseLayoutUI(self)
    if not self.energyFrame then
        return
    end
    local roguelike = self.mode == "roguelike"
    self.energyFrame:SetShown(roguelike)
    self.energyBarFrame:SetShown(roguelike)
    if not roguelike then
        self.statRule:Show()
        Theme:PlaceGame(self.bestPanel.crown, 12, 16, 24, 24)
        Theme:PlaceGame(self.bestPanel.label, 44, 20, 48, 20)
        return
    end
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    local rightW = self.right:GetWidth()
    local leftW, gap = math.floor(w * 0.245), 14
    local available = w - leftW - rightW - 2 * gap
    local size = self.board:GetWidth()
    local boardX = leftW + gap + (available - size) / 2
    local boardY = math.floor((h - size) / 2)
    local rightX = w - rightW
    self.gemDecor:Hide()
    self.statRule:Hide()

    -- Lay out all seven blocks together. The base game's fixed statistic
    -- positions leave insufficient room for both Energy and the power list.
    local energyPanelH = 120
    local powersH = math.max(80, math.min(140, math.floor(h * 0.2)))
    local spacing = 10
    local scoreH, bestH, rowH = 90, 46, 32
    local statsH = scoreH + bestH + 3 * rowH
    spacing = math.max(2, math.min(spacing, (h - 28 - energyPanelH - powersH - statsH) / 6))
    local y = 14
    Theme:PlaceGame(self.scorePanel, 14, y, rightW - 28, scoreH)
    Theme:PlaceGame(self.scoreText, 16, 32, rightW - 60, 52)
    y = y + scoreH + spacing
    Theme:PlaceGame(self.bestPanel, 16, y, rightW - 32, bestH)
    Theme:PlaceGame(self.bestPanel.crown, 12, 11, 24, 24)
    Theme:PlaceGame(self.bestPanel.label, 44, 15, 48, 20)
    Theme:PlaceGame(self.bestText, 96, 6, rightW - 142, 34)
    y = y + bestH + spacing
    for _, row in ipairs({ self.moveRow, self.clearedRow, self.cascadeRow }) do
        Theme:PlaceGame(row, 18, y, rightW - 36, rowH)
        y = y + rowH + spacing
    end
    local energyY = y
    Theme:PlaceGame(self.energyFrame, 14, energyY, rightW - 28, energyPanelH)
    self.energyTitle:SetWidth(rightW - 52)
    self.energyValue:SetWidth(rightW - 52)
    self.energyInfo:SetWidth(rightW - 52)
    self.energyDrain:SetWidth(rightW - 52)
    self.energyHint:SetWidth(rightW - 52)

    Theme:PlaceGame(self.tipPanel, 14, energyY + energyPanelH + spacing, rightW - 28, powersH)
    Theme:PlaceGame(self.statusText, 12, 12, rightW - 52, 20)
    Theme:PlaceGame(self.tipText, 12, 38, rightW - 52, powersH - 50)
    self.statusText:SetHeight(20)
    self.tipText:SetHeight(powersH - 50)
    self.tipText:SetJustifyV("TOP")

    local gapToStats = math.max(20, rightX - (boardX + size))
    local barW = math.max(22, math.min(40, gapToStats - 8))
    local barX = boardX + size + math.max(4, math.floor((gapToStats - barW) / 2))
    Theme:PlaceGame(self.energyBarFrame, barX, boardY, barW, size)
    Theme:PlaceGame(self.energyBarRail, math.max(5, math.floor((barW - 18) / 2)), 8, math.max(12, barW - 12), size - 16)

    if self.draftWindow then
        local modalW = math.min(w - 30, 790)
        local modalH = math.min(h - 20, 480)
        self.draftWindow:SetSize(modalW, modalH)
        local factor = math.min(1, modalW / 790, modalH / 480)
        for i, card in ipairs(self.draftCards) do
            card:SetScale(factor)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", self.draftWindow, "TOPLEFT", (21 + (i - 1) * 256) * factor, -99 * factor)
        end
    end
    if self.shuffleAnimation then
        for index, sprite in ipairs(self.shuffleSprites or {}) do
            sprite:SetSize(self.tileSize, self.tileSize)
            sprite.icon:SetSize(self.tileSize - 10, self.tileSize - 10)
            local y, x = math.floor((index - 1) / 8) + 1, (index - 1) % 8 + 1
            self:PaintSpecial(sprite, self.model.board[y][x])
        end
        self:PositionReshuffleSprites(self.shuffleAnimation.time / self.shuffleAnimation.duration)
    end
    self:RefreshEnergy()
end
