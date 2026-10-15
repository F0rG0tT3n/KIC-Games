local _, Games = ...
local B, Theme = Games.Bejeweled, Games.Theme
local function key(x, y)
    return (y - 1) * 8 + x
end
local neighbors = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
-- Clip the last cursor segment against a tile so fast movement cannot skip it.
local function entersTile(x0, y0, x1, y1, left, right, bottom, top)
    local dx, dy = x1 - x0, y1 - y0
    local enter, leave = 0, 1
    if dx == 0 then
        if x0 < left or x0 > right then
            return
        end
    else
        local a, b = (left - x0) / dx, (right - x0) / dx
        enter, leave = math.max(enter, math.min(a, b)), math.min(leave, math.max(a, b))
    end
    if dy == 0 then
        if y0 < bottom or y0 > top then
            return
        end
    else
        local a, b = (bottom - y0) / dy, (top - y0) / dy
        enter, leave = math.max(enter, math.min(a, b)), math.min(leave, math.max(a, b))
    end
    if enter < leave or (enter == leave and x1 >= left and x1 <= right and y1 >= bottom and y1 <= top) then
        return enter
    end
end
-- Inspect intact rows/columns before Step removes pending cells. Separate
-- simultaneous triples and crossing triples remain match-3, regardless of count.
function B:MatchSoundEvent()
    local board, longest = self.model.board, 0
    for i = 1, 8 do
        local horizontal, vertical, lastH, lastV = 0, 0
        for j = 1, 8 do
            local h, v = board[i][j], board[j][i]
            horizontal = h and (h == lastH and horizontal + 1 or 1) or 0
            vertical = v and (v == lastV and vertical + 1 or 1) or 0
            lastH, lastV = h, v
            longest = math.max(longest, horizontal, vertical)
        end
    end
    local tier = math.min(longest, 5)
    return tier == 5 and "bejeweled_match_5_plus" or tier == 4 and "bejeweled_match_4" or "bejeweled_match_3",
        tier,
        longest
end
local effectColors = {
    [3] = { 0.32, 0.88, 1 },
    [4] = { 1, 0.78, 0.28 },
    [5] = { 1, 0.43, 0.95 },
}
local matchTitles = {
    [3] = "MATCH!",
    [4] = "GREAT MATCH!",
    [5] = "EPIC MATCH!",
    [6] = "LEGENDARY MATCH!",
    [7] = "MYTHIC MATCH!",
    [8] = "UNBELIEVABLE!",
}
function B:StartMatchEffect(tier, length, matched, cascade, points)
    if self.matchEffect then
        for i in pairs(self.matchEffect.cells) do
            self.cells[i].spark:SetAlpha(0)
        end
    end
    for _, particle in ipairs(self.effectParticles) do
        particle:Hide()
    end
    local duration = tier == 5 and 1.05 or tier == 4 and 0.75 or 0.45
    local color = effectColors[tier]
    local effect =
        { tier = tier, duration = duration, labelDuration = duration + 0.45, time = 0, cells = {}, particles = {} }
    for _, c in ipairs(matched) do
        local index = key(c.x, c.y)
        effect.cells[index] = true
        self.cells[index].spark:SetColorTexture(color[1], color[2], color[3], 1)
    end
    self.matchEffect = effect
    self.effectBanner:SetText(matchTitles[length])
    self.effectBanner:SetTextColor(color[1], color[2], color[3], 1)
    self.effectBanner:Show()
    local combo = cascade >= 4 and "MEGA COMBO" or cascade == 3 and "SUPER COMBO" or "COMBO"
    self.effectDetail:SetText(
        cascade > 1 and string.format("%s x%d   +%d POINTS", combo, cascade, points)
            or string.format("+%d POINTS", points)
    )
    local detailColor = cascade > 1 and Theme.Colors.gold or color
    self.effectDetail:SetTextColor(detailColor[1], detailColor[2], detailColor[3], 1)
    self.effectDetail:Show()
    self.effectFlash:SetColorTexture(color[1], color[2], color[3], 1)
    local count = tier == 5 and 32 or tier == 4 and 12 or 4
    for i = 1, count do
        local c = matched[(i - 1) % #matched + 1]
        local angle = i * 2.399963 -- Evenly dispersed without changing the game RNG.
        effect.particles[i] = { x = c.x, y = c.y, dx = math.cos(angle), dy = math.sin(angle) }
        local particle = self.effectParticles[i]
        particle:SetColorTexture(color[1], color[2], color[3], 1)
        particle:Show()
    end
    self:UpdateMatchEffect(0)
end
function B:UpdateMatchEffect(dt)
    local effect = self.matchEffect
    if not effect then
        return
    end
    effect.time = math.min(effect.labelDuration, effect.time + dt)
    local progress = math.min(1, effect.time / effect.duration)
    local fade = 1 - progress
    local textFade =
        math.max(0, math.min(1, (effect.labelDuration - effect.time) / (effect.labelDuration - effect.duration * 0.4)))
    for i in pairs(effect.cells) do
        self.cells[i].spark:SetAlpha(fade * (effect.tier == 5 and 0.85 or effect.tier == 4 and 0.7 or 0.55))
    end
    self.effectBanner:SetAlpha(textFade)
    self.effectDetail:SetAlpha(textFade)
    self.effectFlash:SetAlpha(fade * (effect.tier == 5 and 0.32 or effect.tier == 4 and 0.16 or 0.08))
    for i, point in ipairs(effect.particles) do
        local particle = self.effectParticles[i]
        local spread = progress * self.step * (effect.tier == 5 and 1.7 or 0.9)
        particle:ClearAllPoints()
        particle:SetPoint(
            "CENTER",
            self.viewport,
            "TOPLEFT",
            (point.x - 0.5) * self.step + point.dx * spread,
            -(point.y - 0.5) * self.step + point.dy * spread
        )
        particle:SetAlpha(fade)
    end
    if effect.time >= effect.labelDuration then
        self.matchEffect = nil
        self.effectBanner:Hide()
        self.effectDetail:Hide()
        self.effectFlash:SetAlpha(0)
        for _, particle in ipairs(self.effectParticles) do
            particle:Hide()
        end
    end
end
function B:CancelDrag()
    if self.drag then
        self.suppressDragClick = true
    end
    if self.dragTracker then
        self.dragTracker:SetScript("OnUpdate", nil)
    end
    self.drag = nil
    if self.dragFrame then
        self.dragFrame:Hide()
    end
end
function B:UpdateDrag()
    local drag = self.drag
    if not drag then
        return
    end
    if self:Blocked() or self.paused then
        self:CancelDrag()
        self:Render()
        return
    end
    local cell = self.cells[key(drag.x, drag.y)]
    if
        cell:GetEffectiveScale() ~= drag.scale
        or cell:GetWidth() * drag.scale ~= drag.width
        or cell:GetHeight() * drag.scale ~= drag.height
    then
        self:CancelDrag()
        self:Render()
        return
    end
    if not IsMouseButtonDown("LeftButton") then
        self:StopDrag()
        return
    end
    local px, py = GetCursorPosition()
    if px == drag.lastX and py == drag.lastY then
        return
    end
    self.suppressDragClick = true
    self.selected, self.hint = { x = drag.x, y = drag.y }, nil
    local scale = self.board:GetEffectiveScale()
    local left = self.board:GetLeft() + self.boardInset
    local top = self.board:GetTop() - self.boardInset
    local first, targetX, targetY
    -- Hit actual neighboring tile rectangles, excluding the gaps between cells.
    -- Compare in physical cursor coordinates to account for effective UI scale.
    for _, offset in ipairs(neighbors) do
        local tx, ty = drag.x + offset[1], drag.y + offset[2]
        if tx >= 1 and tx <= 8 and ty >= 1 and ty <= 8 then
            local target = self.cells[key(tx, ty)]
            local x, y = left + (tx - 1) * self.step, top - (ty - 1) * self.step
            local entry = entersTile(
                drag.lastX,
                drag.lastY,
                px,
                py,
                x * scale,
                (x + target:GetWidth()) * scale,
                (y - target:GetHeight()) * scale,
                y * scale
            )
            if entry and (not first or entry < first) then
                first, targetX, targetY = entry, tx, ty
            end
        end
    end
    drag.lastX, drag.lastY = px, py
    if first then
        self:CancelDrag()
        self.selected = nil
        self:TrySwap(drag.x, drag.y, targetX, targetY, true)
        return
    end
    if
        px < left * scale
        or px > (left + 7 * self.step + self.tileSize) * scale
        or py > top * scale
        or py < (top - 7 * self.step - self.tileSize) * scale
    then
        self:CancelDrag()
        self.selected = nil
        self:Render()
        return
    end
    self.dragFrame:ClearAllPoints()
    self.dragFrame:SetPoint(
        "TOPLEFT",
        self.board,
        "TOPLEFT",
        px / scale - self.board:GetLeft() - self.tileSize / 2,
        py / scale - self.board:GetTop() + self.tileSize / 2
    )
    self.dragFrame:Show()
    self:Render()
end
function B:StartDrag(x, y)
    if self:Blocked() or self.paused or self.drag or self.swap or self.fall or self.model.phase ~= "idle" then
        return false
    end
    local px, py = GetCursorPosition()
    local cell = self.cells[key(x, y)]
    local scale = cell:GetEffectiveScale()
    self.drag = {
        x = x,
        y = y,
        startX = px,
        startY = py,
        lastX = px,
        lastY = py,
        scale = scale,
        width = cell:GetWidth() * scale,
        height = cell:GetHeight() * scale,
    }
    if self.dragFrame.icon:SetTexture(self.icons[self.model.board[y][x]]) == false then
        self.dragFrame.icon:SetTexture(self.fallbackIcon)
    end
    self.dragTracker:SetScript("OnUpdate", function()
        self:UpdateDrag()
    end)
    return true
end
function B:TrySwap(x, y, tx, ty, dragged)
    if
        self:Blocked()
        or self.paused
        or self.drag
        or self.swap
        or self.fall
        or self.model.phase ~= "idle"
        or math.abs(tx - x) + math.abs(ty - y) ~= 1
    then
        return false
    end
    local valid = self.model:Swap(x, y, tx, ty)
    self.hintNextAt = self.scoreIdleTime + 5
    Games.Audio:Play("bejeweled", "swap")
    self.swap = { x = x, y = y, tx = tx, ty = ty, valid = valid, dragged = dragged, time = 0 }
    self.selected, self.hint, self.phaseTime = nil, nil, 0
    self.message = valid and "Nice match!" or "A swap must make a match."
    self:Render()
    return valid
end
function B:StopDrag()
    local drag = self.drag
    if not drag then
        return
    end
    local px, py = GetCursorPosition()
    local moved = self.suppressDragClick or px ~= drag.startX or py ~= drag.startY
    self:CancelDrag()
    self.suppressDragClick = moved
    if moved then
        self.selected = nil
    end
    -- Releasing never evaluates a swap; a stationary press remains a normal click.
    self:Render()
end
function B:Blocked()
    return not self.running
        or not self.root:IsVisible()
        or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil)
        or Games.UI.resultsFrame:IsShown()
        or (Games.UI.optionsFrame and Games.UI.optionsFrame:IsShown())
end
function B:Pause(value)
    self:CancelDrag()
    self.paused = value
    self.selected, self.hint = nil, nil
    if value then
        self.hintNextAt = self.scoreIdleTime + 5
    end
    if self.model and self.model.phase == "idle" and not self.swap and not self.fall then
        self.message = "Select a gem, then a neighbor."
    end
    self:Render()
end
function B:Hint()
    if self:Blocked() or self.paused or self.drag or self.swap or self.fall or self.model.phase ~= "idle" then
        return
    end
    self.hint = self.model:FindMove()
    if not self.hint then
        return
    end
    self.selected, self.hintPulseTime = nil, 0
    self.message = "Try the two highlighted gems."
    self:Render()
end
function B:UpdateHintPulse()
    local pulse = math.abs(math.sin(self.hintPulseTime * 5))
    for i = 1, 2 do
        local x, y = i == 1 and self.hint.x or self.hint.tx, i == 1 and self.hint.y or self.hint.ty
        local cell = self.cells[key(x, y)]
        cell.icon:ClearAllPoints()
        cell.icon:SetPoint("TOPLEFT", 5, -5 + 6 * pulse)
        cell:SetBackdropBorderColor(1, 0.85, 0.25, 0.5 + 0.5 * pulse)
    end
end
function B:Click(x, y, mouse)
    if self:Blocked() then
        if self.running then
            self:Pause(true)
        end
        return
    end
    if self.paused or self.drag or self.swap or self.fall or self.model.phase ~= "idle" then
        return
    end
    self.hintNextAt = self.scoreIdleTime + 5
    if mouse == "RightButton" then
        self.selected, self.hint = nil, nil
        self.message = "Select a gem, then a neighbor."
        self:Render()
        return
    end
    self.hint = nil
    local old = self.selected
    if old and old.x == x and old.y == y then
        self.selected = nil
        self.message = "Select a gem, then a neighbor."
    elseif old and math.abs(old.x - x) + math.abs(old.y - y) == 1 then
        self:TrySwap(old.x, old.y, x, y)
    else
        self.selected = { x = x, y = y }
        self.message = "Now select a neighboring gem."
        Games.Audio:Play("bejeweled", "select")
    end
    self:Render()
end
function B:Render()
    if not self.model or not self.cells then
        return
    end
    local m = self.model
    if self.visualModel ~= m then
        self.visualModel, self.lastVisualScore, self.scorePulseLeft = m, m.score, 0
        self.scorePulse:SetAlpha(0)
    end
    local matches = {}
    if m.pending and not self.swap and not self.fall then
        for _, c in ipairs(m.pending) do
            matches[key(c.x, c.y)] = true
        end
    end
    for y = 1, 8 do
        for x = 1, 8 do
            local index = key(x, y)
            local cell = self.cells[index]
            local kind = m.board[y][x]
            local c = kind and self.Gems[kind].color or { 0.1, 0.12, 0.18 }
            local selected = self.selected and self.selected.x == x and self.selected.y == y
            local hint = self.hint
                and ((self.hint.x == x and self.hint.y == y) or (self.hint.tx == x and self.hint.ty == y))
            cell:SetBackdropColor(c[1] * 0.11 + 0.025, c[2] * 0.11 + 0.025, c[3] * 0.11 + 0.025, 1)
            cell.selection:SetShown(selected == true)
            cell.marker:SetShown(selected == true)
            if selected then
                cell:SetBackdropColor(0.28, 0.22, 0.045, 1)
                cell:SetBackdropBorderColor(1, 0.88, 0.25, 1)
            elseif
                self.swap
                and self.swap.valid
                and ((x == self.swap.x and y == self.swap.y) or (x == self.swap.tx and y == self.swap.ty))
            then
                cell:SetBackdropBorderColor(unpack(Theme.Colors.ice))
            elseif hint then
                cell:SetBackdropBorderColor(
                    1,
                    0.85,
                    0.25,
                    0.5 + 0.5 * math.abs(math.sin((self.hintPulseTime or 0) * 5))
                )
            elseif matches[index] then
                cell:SetBackdropBorderColor(1, 1, 1, 1)
            elseif cell.hovered and not self.paused then
                cell:SetBackdropBorderColor(c[1], c[2], c[3], 1)
            else
                cell:SetBackdropBorderColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 1)
            end
            cell.icon:ClearAllPoints()
            local dx, dy = 0, 0
            if self.swap then
                local a = self.swap
                local progress = math.min(1, a.time / (a.valid and 0.2 or 0.3))
                local travel = (a.valid or a.dragged) and (1 - progress)
                    or (progress < 0.5 and progress * 2 or (1 - progress) * 2)
                if x == a.x and y == a.y then
                    dx, dy = (a.tx - a.x) * self.step * travel, -(a.ty - a.y) * self.step * travel
                elseif x == a.tx and y == a.ty and not a.dragged then
                    dx, dy = -(a.tx - a.x) * self.step * travel, (a.ty - a.y) * self.step * travel
                end
            elseif self.fall and self.fall.drops[index] then
                dy = (y - self.fall.drops[index]) * self.step * (1 - math.min(1, self.fall.time / 0.26)) ^ 2
            elseif hint and not self.paused then
                dy = 6 * math.abs(math.sin((self.hintPulseTime or 0) * 5))
            end
            cell.icon:SetPoint("TOPLEFT", 5 + dx, -5 + dy)
            if kind then
                if cell.icon:SetTexture(self.icons[kind]) == false then
                    cell.icon:SetTexture(self.fallbackIcon)
                end
                cell.icon:SetAlpha(
                    self.drag and self.drag.x == x and self.drag.y == y and 0.2
                        or matches[index] and (0.35 + 0.65 * math.abs(math.cos(self.phaseTime * 12)))
                        or 1
                )
                cell.icon:Show()
            else
                cell.icon:Hide()
            end
        end
    end
    Theme:ScoreValue(self.scoreText, m.score, 56)
    Theme:ScoreValue(self.bestText, self:Storage().best.score, 26)
    Theme:ScoreValue(self.moveRow.value, m.moves, 24)
    Theme:ScoreValue(self.clearedRow.value, m.cleared, 24)
    Theme:ScoreValue(self.cascadeRow.value, "x" .. m.bestCascade, 24)
    if self.lastVisualScore and m.score > self.lastVisualScore then
        self.scorePulseLeft = 0.35
    end
    self.lastVisualScore = m.score
    self.statusText:SetText(
        self.paused and "Paused. Resume when ready."
            or self.swap and self.message
            or self.fall and "Gems falling..."
            or m.phase == "clearing" and (m.cascade > 1 and ("CASCADE x" .. m.cascade) or "MATCH!")
            or self.message
    )
    self.pauseButton:SetText(self.paused and "Resume" or "Pause")
    self.pauseOverlay:SetShown(self.paused == true)
end
function B:Advance(dt)
    if not self.running then
        return
    end
    if self:Blocked() then
        if not self.paused then
            self:Pause(true)
        end
        return
    end
    if self.paused then
        return
    end
    if self.drag then
        return
    end
    local idleDt = math.max(dt, 0)
    dt = math.min(idleDt, 0.1)
    if self.scorePulseLeft and self.scorePulseLeft > 0 then
        self.scorePulseLeft = math.max(0, self.scorePulseLeft - dt)
        self.scorePulse:SetAlpha(0.13 * self.scorePulseLeft / 0.35)
    end
    self.scoreIdleTime = self.scoreIdleTime + idleDt
    self:UpdateMatchEffect(dt)
    local redraw = false
    if self.hint then
        self.hintPulseTime = self.hintPulseTime + dt
        self:UpdateHintPulse()
    elseif self.scoreIdleTime >= self.hintNextAt and self.model.phase == "idle" and not self.swap and not self.fall then
        self:Hint()
    end
    if self.swap then
        redraw = true
        self.swap.time = self.swap.time + dt
        if self.swap.time >= (self.swap.valid and 0.2 or 0.3) then
            self.swap = nil
            self.phaseTime = 0
        end
    elseif self.fall then
        redraw = true
        self.fall.time = self.fall.time + dt
        if self.fall.time >= 0.26 then
            self.fall = nil
            self.phaseTime = 0
        end
    elseif self.model.phase == "clearing" then
        redraw = true
        if self.effectPending ~= self.model.pending then
            local _, tier, length = self:MatchSoundEvent()
            local cascade, matched = self.model.cascade, self.model.pending
            self:StartMatchEffect(tier, length, matched, cascade, #matched * 50 * cascade)
            self.effectPending = matched
        end
        self.phaseTime = self.phaseTime + dt
        if self.phaseTime >= 0.3 then
            local event, cascade = self:MatchSoundEvent(), self.model.cascade
            self.model:Step()
            self.scoreIdleTime = 0
            self.hintNextAt = 5
            self.hint = nil
            self.effectPending = nil
            self:SaveBest()
            Games.Audio:Play("bejeweled", event, nil, cascade)
            self.phaseTime = 0
            self.message = "+" .. self.model.lastGain .. " points"
        end
    elseif self.model.phase == "falling" then
        redraw = true
        local drops = self.model:Step()
        self.fall = { drops = drops, time = 0 }
    end
    if redraw then
        self:Render()
    end
    if self.model.gameover and not self.swap and not self.fall then
        self:Complete()
    end
end
function B:CreateUI(parent)
    if self.root then
        self:LayoutUI()
        return self.root
    end
    self.root = CreateFrame("Frame", nil, parent)
    self.root:SetPoint("TOPLEFT", 0, 0)
    self.left = Theme:PremiumFrame(self.root, 250, 550, 0, 0)
    self.leftArt = Theme:Art(self.left, "bejeweled-hero", 220, 130, 14, -14, 1, "ARTWORK")
    self.title = Theme:GameLabel(self.left, "BEJEWELED", 28)
    self.tagline = Theme:GameLabel(self.left, "MATCH / CASCADE / REPEAT", 12, Theme.Colors.accent)
    self.titleRule = Theme:Separator(self.left, 14, -200, 220)
    self.instructions = {}
    for _, row in ipairs({
        { "icon-gem", "Swap neighboring icons\nto match three or more." },
        { "icon-swap", "Match 3+ in a row or column." },
        { "icon-cascade", "Cascades multiply points." },
        { "icon-clock", "No timer. Take your time." },
        { "icon-infinity", "No moves left? Run complete." },
    }) do
        self.instructions[#self.instructions + 1] = Theme:InstructionRow(self.left, row[1], row[2])
    end
    self.pauseButton = Theme:GameButton(self.left, "Pause", "icon-pause", function()
        self:Pause(not self.paused)
    end, true)
    self.shareButton = Theme:GameButton(self.left, "Share Best", "icon-share", function()
        self:ShareBest()
    end)
    self.optionsButton = Theme:GameButton(self.left, "Options", "nav-options", function()
        Games.UI:ShowOptions()
    end)
    local board = Theme:GameBoard(self.root)
    self.board = board
    self.viewport = CreateFrame("Frame", nil, board)
    self.viewport:SetClipsChildren(true)
    self.cells = {}
    for y = 1, 8 do
        for x = 1, 8 do
            local cx, cy = x, y
            local cell = CreateFrame("Button", nil, self.viewport, "BackdropTemplate")
            cell:SetSize(44, 44)
            cell:SetPoint("TOPLEFT", 0, 0)
            cell:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cell:SetScript("OnMouseDown", function(_, mouse)
                if mouse == "LeftButton" then
                    self:CancelDrag()
                    self.suppressDragClick = false
                    self:StartDrag(cx, cy)
                end
            end)
            cell:SetScript("OnMouseUp", function(_, mouse)
                if mouse == "LeftButton" then
                    self:StopDrag()
                end
            end)
            cell:SetScript("OnClick", function(_, mouse)
                if mouse == "LeftButton" then
                    self:StopDrag()
                    if self.suppressDragClick then
                        return
                    end
                end
                self:Click(cx, cy, mouse)
            end)
            cell:SetScript("OnEnter", function()
                cell.hovered = true
                self:Render()
            end)
            cell:SetScript("OnLeave", function()
                cell.hovered = false
                self:Render()
            end)
            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetSize(34, 34)
            cell.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
            cell.spark = cell:CreateTexture(nil, "OVERLAY")
            cell.spark:SetAllPoints(cell)
            cell.spark:SetColorTexture(1, 1, 1, 1)
            cell.spark:SetBlendMode("ADD")
            cell.spark:SetAlpha(0)
            cell.selection = CreateFrame("Frame", nil, cell, "BackdropTemplate")
            cell.selection:SetPoint("TOPLEFT", -2, 2)
            cell.selection:SetPoint("BOTTOMRIGHT", 2, -2)
            cell.selection:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 })
            cell.selection:SetBackdropBorderColor(1, 0.9, 0.25, 1)
            cell.selection:SetFrameLevel(cell:GetFrameLevel() + 3)
            cell.selection:Hide()
            local strip = cell.selection:CreateTexture(nil, "BACKGROUND")
            cell.strip = strip
            strip:SetSize(44, 11)
            strip:SetPoint("BOTTOM", 0, 2)
            strip:SetColorTexture(0.12, 0.09, 0.01, 1)
            cell.marker = Theme:Label(cell.selection, "SELECTED", 0, 0, 44, "GameFontHighlightSmall")
            cell.marker:ClearAllPoints()
            cell.marker:SetPoint("BOTTOM", 0, 2)
            cell.marker:SetFont("Fonts\\ARIALN.TTF", 8, "")
            cell.marker:SetJustifyH("CENTER")
            cell.marker:SetTextColor(1, 1, 0.65, 1)
            self.cells[key(x, y)] = cell
        end
    end
    self.dragFrame = Theme:Panel(board, 44, 44, 0, 0)
    self.dragFrame:SetFrameLevel(board:GetFrameLevel() + 25)
    self.dragFrame:SetBackdropBorderColor(unpack(Theme.Colors.gold))
    self.dragFrame.icon = self.dragFrame:CreateTexture(nil, "ARTWORK")
    self.dragFrame.icon:SetPoint("TOPLEFT", 5, -5)
    self.dragFrame.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    self.dragFrame:Hide()
    self.dragTracker = CreateFrame("Frame", nil, board)
    self.dragTracker:SetScript("OnHide", function()
        self:CancelDrag()
    end)
    self.effectLayer = CreateFrame("Frame", nil, self.viewport)
    self.effectLayer:SetAllPoints(self.viewport)
    self.effectLayer:SetFrameLevel(self.viewport:GetFrameLevel() + 10)
    self.effectLayer:EnableMouse(false)
    self.effectFlash = self.effectLayer:CreateTexture(nil, "OVERLAY")
    self.effectFlash:SetAllPoints(self.viewport)
    self.effectFlash:SetColorTexture(1, 0.55, 0.95, 1)
    self.effectFlash:SetBlendMode("ADD")
    self.effectFlash:SetAlpha(0)
    self.effectParticles = {}
    for i = 1, 32 do
        local particle = self.effectLayer:CreateTexture(nil, "OVERLAY")
        particle:SetTexture("Interface\\Buttons\\WHITE8X8")
        particle:SetSize(i % 3 == 0 and 12 or 8, i % 3 == 0 and 12 or 8)
        particle:SetBlendMode("ADD")
        particle:Hide()
        self.effectParticles[i] = particle
    end
    self.effectBanner = Theme:GameLabel(self.root, "", 24, Theme.Colors.gold)
    self.effectBanner:SetHeight(26)
    self.effectBanner:SetJustifyH("CENTER")
    self.effectBanner:Hide()
    self.effectDetail = Theme:GameLabel(self.root, "", 13, Theme.Colors.gold)
    self.effectDetail:SetHeight(16)
    self.effectDetail:SetJustifyH("CENTER")
    self.effectDetail:Hide()
    self.pauseOverlay = Theme:PauseMenu(board, "bejeweled", self)
    self.right = Theme:PremiumFrame(self.root, 250, 550, 0, 0, { skin = "game-stats-frame" })
    self.crest = Theme:Art(self.right, "crest", 160, 160, 80, -18, 0.07, "ARTWORK")
    self.crown = Theme:GameIcon(self.right, "ornament-crown", 34, Theme.Colors.gold)
    self.scorePanel = Theme:StatPanel(self.right, "SCORE", 220, 120, 14, -24, { plain = true })
    self.scorePanel.label:SetFont(Theme.Fonts.display, 18, "")
    self.scorePanel.value:SetFont(Theme.Fonts.display, 56, "")
    self.scorePanel.detail:Hide()
    self.scoreText = self.scorePanel.value
    self.scorePulse = Theme:Highlight(self.scorePanel, 0, 0, 1, 1, Theme.Colors.accent, 0)
    self.scorePulse:SetAllPoints(self.scorePanel)
    self.bestPanel = Theme:GoldBest(self.right)
    self.bestText = self.bestPanel.value
    self.moveRow = Theme:GameStatRow(self.right, "icon-swap", "MOVES")
    self.clearedRow = Theme:GameStatRow(self.right, "icon-gem", "GEMS CLEARED")
    self.cascadeRow = Theme:GameStatRow(self.right, "icon-cascade", "BEST CASCADE")
    self.statRule = Theme:SectionHeader(self.right, "", 200, 18, -380)
    self.gemDecor = Theme:Art(self.right, "bejeweled-card", 130, 70, 40, -370, 0.16, "ARTWORK")
    self.tipPanel = Theme:PremiumFrame(self.right, 220, 104, 14, -430, { compact = true })
    self.statusText = Theme:GameLabel(self.tipPanel, "", 13)
    self.statusText:SetMaxLines(2)
    self.tipText = Theme:GameLabel(
        self.tipPanel,
        "50 points per gem x cascade.\nRight-click clears selection.",
        12,
        Theme.Colors.muted
    )
    self.root:SetScript("OnUpdate", function(_, dt)
        self:Advance(dt)
    end)
    self.root:SetScript("OnHide", function()
        if self.running then
            self:Pause(true)
        end
    end)
    self.root:Hide()
    self:LayoutUI()
    self:CreateSummary()
    return self.root
end
function B:LayoutUI()
    if not self.root then
        return
    end
    self:CancelDrag()
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    self.root:SetSize(w, h)
    local leftW, rightW, gap = math.floor(w * 0.245), math.floor(w * 0.24), 14
    local available = w - leftW - rightW - 2 * gap
    self.boardInset = 12
    self.step = math.floor((math.min(available, h - 16) - 24) / 8)
    self.tileSize = self.step - 2
    local size = self.step * 8 + 24
    Theme:PlaceGame(self.left, 0, 0, leftW, h)
    Theme:PlaceGame(self.board, leftW + gap + (available - size) / 2, math.floor((h - size) / 2), size, size)
    self.effectBanner:ClearAllPoints()
    self.effectBanner:SetPoint("BOTTOM", self.board, "TOP", 0, 20)
    self.effectBanner:SetWidth(math.min(size, 420))
    self.effectDetail:ClearAllPoints()
    self.effectDetail:SetPoint("BOTTOM", self.board, "TOP", 0, 2)
    self.effectDetail:SetWidth(math.min(size, 420))
    Theme:PlaceGame(self.viewport, 12, 12, size - 24, size - 24)
    Theme:PlaceGame(self.right, w - rightW, 0, rightW, h)
    local artH = math.min(178, math.floor(h * (h < 550 and 0.21 or 0.24)))
    Theme:PlaceGame(self.leftArt, 14, 14, leftW - 28, artH)
    Theme:SetArt(self.leftArt, "bejeweled-hero", leftW - 28, artH, 1)
    Theme:PlaceGame(self.title, 14, artH + 24, leftW - 28, 36)
    Theme:PlaceGame(self.tagline, 14, artH + 65, leftW - 28, 24)
    Theme:PlaceGame(self.titleRule, 14, artH + 91, leftW - 28, 1)
    for i, row in ipairs(self.instructions) do
        Theme:PlaceGame(row, 16, artH + 104 + (i - 1) * (h < 550 and 26 or 31), leftW - 32, h < 550 and 25 or 29)
    end
    for i, b in ipairs({ self.pauseButton, self.shareButton, self.optionsButton }) do
        Theme:PlaceGameButton(b, 18, h - 160 + (i - 1) * 38, leftW - 36, 32)
    end
    for i, cell in ipairs(self.cells) do
        Theme:PlaceGame(
            cell,
            ((i - 1) % 8) * self.step,
            math.floor((i - 1) / 8) * self.step,
            self.tileSize,
            self.tileSize
        )
        cell.icon:SetSize(self.tileSize - 10, self.tileSize - 10)
        cell.strip:SetWidth(self.tileSize)
        cell.marker:SetWidth(self.tileSize)
    end
    self.dragFrame:SetSize(self.tileSize, self.tileSize)
    self.dragFrame.icon:SetSize(self.tileSize - 10, self.tileSize - 10)
    self.pauseOverlay:Layout(size - 40, 20, (size - 180) / 2)
    Theme:PlaceGame(self.crown, (rightW - 34) / 2, -5)
    Theme:PlaceGame(self.crest, rightW - 172, 18)
    Theme:PlaceGame(self.scorePanel, 14, 26, rightW - 28, 118)
    Theme:PlaceGame(self.scoreText, 16, 42, rightW - 60, 68)
    Theme:PlaceGame(self.bestPanel, 16, 154, rightW - 32, 56)
    for i, row in ipairs({ self.moveRow, self.clearedRow, self.cascadeRow }) do
        Theme:PlaceGame(row, 18, 232 + (i - 1) * 48, rightW - 36, 42)
    end
    Theme:PlaceGame(self.statRule, 18, math.min(392, h - 134), rightW - 36, 24)
    local decorY = math.min(392, h - 134) + 22
    local decorH = math.max(0, math.min(80, h - 118 - decorY))
    decorY = h - 118 - decorH
    local cluster = Games.Artwork["gem-cluster"]
    Theme:PlaceGame(self.gemDecor, (rightW - 130) / 2, decorY, 130, math.max(1, decorH))
    Theme:SetArt(self.gemDecor, cluster.file and "gem-cluster" or cluster.fallback, 130, math.max(1, decorH), 0.16)
    self.gemDecor:SetShown(decorH >= 12)
    Theme:PlaceGame(self.tipPanel, 14, h - 118, rightW - 28, 104)
    Theme:PlaceGame(self.statusText, 12, 12, rightW - 52, 38)
    Theme:PlaceGame(self.tipText, 12, 58, rightW - 52, 36)
    self:Render()
end
function B:CreateSummary()
    local f = Theme:Panel(UIParent, 440, 284, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Games.UI.frame, "CENTER", 0, 0)
    Theme:Window(f, true, true)
    Theme:CloseButton(f)
    _G.KICGamesBejeweledResult = f
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesBejeweledResult"
    Theme:Label(f, "NO MOVES LEFT", 24, -26, 350):SetTextColor(unpack(Theme.Colors.accent))
    Theme:Label(f, "Run complete", 24, -54, 380, "GameFontNormalLarge")
    self.summaryText = Theme:Label(f, "", 24, -104, 392)
    self.summaryText:SetFont("Fonts\\ARIALN.TTF", 17, "")
    Theme:NeonButton(f, "Play again", 188, 24, -230, function()
        f:Hide()
        Games:StartSingleplayer("bejeweled")
    end)
    Theme:NeonButton(f, "Share best", 188, 228, -230, function()
        self:ShareBest()
    end)
    f:Hide()
    self.summary = f
    Games.UI:RegisterAuxiliaryWindow(f)
end
