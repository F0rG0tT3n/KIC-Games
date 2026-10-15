local _, Games = ...
local B, Theme = Games.Bejeweled, Games.Theme
local STEP = 46
local function key(x, y)
    return (y - 1) * 8 + x
end
function B:Blocked()
    return not self.running
        or not self.root:IsVisible()
        or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil)
        or Games.UI.resultsFrame:IsShown()
end
function B:Pause(value)
    self.paused = value
    self.selected, self.hint = nil, nil
    if self.model and self.model.phase == "idle" and not self.swap and not self.fall then
        self.message = "Select a gem, then a neighbor."
    end
    self:Render()
end
function B:Hint()
    if self:Blocked() or self.paused or self.swap or self.fall or self.model.phase ~= "idle" then
        return
    end
    self.hint = self.model:FindMove()
    self.selected, self.hintTime = nil, 3
    self.message = "Try the two highlighted gems."
    self:Render()
end
function B:Click(x, y, mouse)
    if self:Blocked() then
        if self.running then
            self:Pause(true)
        end
        return
    end
    if self.paused or self.swap or self.fall or self.model.phase ~= "idle" then
        return
    end
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
        local valid = self.model:Swap(old.x, old.y, x, y)
        self.swap = { x = old.x, y = old.y, tx = x, ty = y, valid = valid, time = 0 }
        self.selected, self.phaseTime = nil, 0
        self.message = valid and "Nice match!" or "A swap must make a match."
    else
        self.selected = { x = x, y = y }
        self.message = "Now select a neighboring gem."
    end
    self:Render()
end
function B:Render()
    if not self.model or not self.cells then
        return
    end
    local m = self.model
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
            if selected then
                cell:SetBackdropBorderColor(unpack(Theme.Colors.accent))
            elseif hint then
                cell:SetBackdropBorderColor(1, 0.85, 0.25, 1)
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
                local travel = a.valid and (1 - progress) or (progress < 0.5 and progress * 2 or (1 - progress) * 2)
                if x == a.x and y == a.y then
                    dx, dy = (a.tx - a.x) * STEP * travel, -(a.ty - a.y) * STEP * travel
                elseif x == a.tx and y == a.ty then
                    dx, dy = -(a.tx - a.x) * STEP * travel, (a.ty - a.y) * STEP * travel
                end
            elseif self.fall and self.fall.drops[index] then
                dy = (y - self.fall.drops[index]) * STEP * (1 - math.min(1, self.fall.time / 0.26)) ^ 2
            end
            cell.icon:SetPoint("TOPLEFT", 5 + dx, -5 + dy)
            if kind then
                if cell.icon:SetTexture(self.Gems[kind].icon) == false then
                    cell.icon:SetTexture(237189)
                end
                cell.icon:SetAlpha(matches[index] and (0.35 + 0.65 * math.abs(math.cos(self.phaseTime * 12))) or 1)
                cell.icon:Show()
            else
                cell.icon:Hide()
            end
        end
    end
    self.scoreText:SetText(tostring(m.score))
    self.bestText:SetText("BEST  " .. self:Storage().best.score)
    self.statsText:SetText(
        string.format("Moves   %d\n\nGems cleared   %d\n\nBest cascade   x%d", m.moves, m.cleared, m.bestCascade)
    )
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
    dt = math.min(math.max(dt, 0), 0.1)
    local redraw = false
    if self.hint then
        self.hintTime = self.hintTime - dt
        if self.hintTime <= 0 then
            self.hint = nil
            self.message = "Select a gem, then a neighbor."
            redraw = true
        end
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
        self.phaseTime = self.phaseTime + dt
        if self.phaseTime >= 0.3 then
            self.model:Step()
            self:SaveBest()
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
        return self.root
    end
    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    self.root = root
    local left = Theme:Panel(root, 192, 418, 16, -16)
    Theme:Label(left, "BEJEWELED", 14, -18, 168, "GameFontNormalLarge"):SetTextColor(unpack(Theme.Colors.accent))
    Theme:Label(left, "MATCH / CASCADE / REPEAT", 14, -50, 170, "GameFontHighlightSmall")
    local help = Theme:Label(
        left,
        "Click two neighboring gems.\n\nMatch 3+ in a row or column.\n\nCascades multiply points.\n\nNo timer. Take your time.\n\nEnds when no swaps remain.",
        14,
        -82,
        164
    )
    help:SetFont("Fonts\\ARIALN.TTF", 13, "")
    Theme:Button(left, "Hint", 164, 14, -298, function()
        self:Hint()
    end)
    self.pauseButton = Theme:Button(left, "Pause", 164, 14, -334, function()
        self:Pause(not self.paused)
    end)
    Theme:Button(left, "Share best", 164, 14, -370, function()
        self:ShareBest()
    end)
    local board = Theme:Panel(root, 386, 386, 224, -28)
    board:SetClipsChildren(true)
    self.cells = {}
    for y = 1, 8 do
        for x = 1, 8 do
            local cx, cy = x, y
            local cell = CreateFrame("Button", nil, board, "BackdropTemplate")
            cell:SetSize(44, 44)
            cell:SetPoint("TOPLEFT", 9 + (x - 1) * STEP, -9 - (y - 1) * STEP)
            cell:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            cell:SetScript("OnClick", function(_, mouse)
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
            self.cells[key(x, y)] = cell
        end
    end
    self.pauseOverlay = Theme:Panel(board, 368, 112, 9, -137)
    self.pauseOverlay:SetFrameLevel(board:GetFrameLevel() + 10)
    Theme:Label(self.pauseOverlay, "PAUSED", 22, -22, 324, "GameFontNormalLarge"):SetJustifyH("CENTER")
    Theme:Button(self.pauseOverlay, "Resume", 160, 104, -65, function()
        self:Pause(false)
    end)
    local right = Theme:Panel(root, 212, 418, 632, -16)
    Theme:Label(right, "SCORE", 16, -20, 180, "GameFontHighlightSmall")
    self.scoreText = Theme:Label(right, "0", 16, -42, 180, "GameFontNormalLarge")
    self.scoreText:SetFont("Fonts\\ARIALN.TTF", 30, "")
    self.bestText = Theme:Label(right, "", 16, -84, 180)
    self.bestText:SetTextColor(unpack(Theme.Colors.accent))
    self.statsText = Theme:Label(right, "", 16, -132, 180)
    self.statusText = Theme:Label(right, "", 16, -270, 180)
    Theme:Label(
        right,
        "50 points per gem\n× cascade multiplier\n\nRight-click clears selection.",
        16,
        -335,
        180,
        "GameFontHighlightSmall"
    )
    root:SetScript("OnUpdate", function(_, dt)
        self:Advance(dt)
    end)
    root:SetScript("OnHide", function()
        if self.running then
            self:Pause(true)
        end
    end)
    root:Hide()
    self:CreateSummary()
    return root
end
function B:CreateSummary()
    local f = Theme:Panel(UIParent, 440, 284, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Games.UI.frame, "CENTER", 0, 0)
    Theme:Window(f, true)
    Theme:CloseButton(f)
    _G.KICGamesBejeweledResult = f
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesBejeweledResult"
    Theme:Label(f, "NO MOVES LEFT", 24, -26, 350):SetTextColor(unpack(Theme.Colors.accent))
    Theme:Label(f, "Run complete", 24, -54, 380, "GameFontNormalLarge")
    self.summaryText = Theme:Label(f, "", 24, -104, 392)
    self.summaryText:SetFont("Fonts\\ARIALN.TTF", 17, "")
    Theme:Button(f, "Play again", 188, 24, -230, function()
        f:Hide()
        Games:StartSingleplayer("bejeweled")
    end)
    Theme:Button(f, "Share best", 188, 228, -230, function()
        self:ShareBest()
    end)
    f:Hide()
    self.summary = f
    Games.UI:RegisterAuxiliaryWindow(f)
end
