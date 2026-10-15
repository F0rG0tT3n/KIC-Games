local _, Games = ...
local B, Theme = Games.Bejeweled, Games.Theme
local STEP = 46
local function key(x, y)
    return (y - 1) * 8 + x
end
function B:CancelDrag()
    self.drag, self.dragTarget = nil, nil
    if self.dragFrame then
        self.dragFrame:Hide()
    end
end
function B:CursorCell()
    local px, py = GetCursorPosition()
    local scale = self.board:GetEffectiveScale()
    local rx, ry = px / scale - self.board:GetLeft() - 9, self.board:GetTop() - py / scale - 9
    if rx < 0 or ry < 0 then
        return
    end
    local x, y = math.floor(rx / STEP) + 1, math.floor(ry / STEP) + 1
    if x > 8 or y > 8 or rx % STEP >= 44 or ry % STEP >= 44 then
        return
    end
    return x, y
end
function B:UpdateDrag()
    if not self.drag then
        return
    end
    local px, py = GetCursorPosition()
    local scale = self.board:GetEffectiveScale()
    self.dragFrame:ClearAllPoints()
    self.dragFrame:SetPoint(
        "TOPLEFT",
        self.board,
        "TOPLEFT",
        px / scale - self.board:GetLeft() - 22,
        py / scale - self.board:GetTop() + 22
    )
    local x, y = self:CursorCell()
    self.dragTarget = x and math.abs(x - self.drag.x) + math.abs(y - self.drag.y) == 1 and { x = x, y = y } or nil
end
function B:StartDrag(x, y)
    if self:Blocked() or self.paused or self.drag or self.swap or self.fall or self.model.phase ~= "idle" then
        return false
    end
    self.drag, self.selected, self.hint = { x = x, y = y }, { x = x, y = y }, nil
    local cell = self.cells[key(x, y)]
    cell.suppressClick = true
    if self.dragFrame.icon:SetTexture(self.icons[self.model.board[y][x]]) == false then
        self.dragFrame.icon:SetTexture(self.fallbackIcon)
    end
    self.dragFrame:Show()
    self:UpdateDrag()
    self:Render()
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
    local x, y = self:CursorCell()
    self:CancelDrag()
    self.selected = nil
    if x then
        self.cells[key(x, y)].suppressClick = true
    end
    if x and math.abs(x - drag.x) + math.abs(y - drag.y) == 1 then
        self:TrySwap(drag.x, drag.y, x, y, true)
    else
        self.message = "Drag to a neighboring icon, or click two icons."
    end
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
    if self.paused or self.drag or self.swap or self.fall or self.model.phase ~= "idle" then
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
        self:TrySwap(old.x, old.y, x, y)
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
            cell.selection:SetShown(selected == true)
            cell.marker:SetShown(selected == true)
            local target = self.dragTarget and self.dragTarget.x == x and self.dragTarget.y == y
            if selected then
                cell:SetBackdropColor(0.28, 0.22, 0.045, 1)
                cell:SetBackdropBorderColor(1, 0.88, 0.25, 1)
            elseif target then
                cell:SetBackdropColor(0.08, 0.22, 0.32, 1)
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
                local travel = (a.valid or a.dragged) and (1 - progress)
                    or (progress < 0.5 and progress * 2 or (1 - progress) * 2)
                if x == a.x and y == a.y then
                    dx, dy = (a.tx - a.x) * STEP * travel, -(a.ty - a.y) * STEP * travel
                elseif x == a.tx and y == a.ty and not a.dragged then
                    dx, dy = -(a.tx - a.x) * STEP * travel, (a.ty - a.y) * STEP * travel
                end
            elseif self.fall and self.fall.drops[index] then
                dy = (y - self.fall.drops[index]) * STEP * (1 - math.min(1, self.fall.time / 0.26)) ^ 2
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
    if self.drag then
        if not IsMouseButtonDown("LeftButton") then
            self:StopDrag()
        else
            self:UpdateDrag()
            self:Render()
        end
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
    self.presetLabel = Theme:Label(left, "", 14, -76, 164)
    local help = Theme:Label(
        left,
        "Drag an icon to a neighbor, or click two icons.\n\nMatch 3+ in a row or column.\n\nCascades multiply points.\n\nNo timer. No swaps? Run complete.",
        14,
        -110,
        164
    )
    help:SetFont("Fonts\\ARIALN.TTF", 12, "")
    Theme:Button(left, "Class options", 164, 14, -263, function()
        Games.UI:ShowOptions()
    end)
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
    self.board = board
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
            cell:RegisterForDrag("LeftButton")
            cell:SetScript("OnMouseDown", function(_, mouse)
                cell.suppressClick = false
            end)
            cell:SetScript("OnDragStart", function()
                self:StartDrag(cx, cy)
            end)
            cell:SetScript("OnDragStop", function()
                self:StopDrag()
            end)
            cell:SetScript("OnClick", function(_, mouse)
                if cell.suppressClick then
                    cell.suppressClick = false
                    return
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
            cell.selection = CreateFrame("Frame", nil, cell, "BackdropTemplate")
            cell.selection:SetPoint("TOPLEFT", -2, 2)
            cell.selection:SetPoint("BOTTOMRIGHT", 2, -2)
            cell.selection:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3 })
            cell.selection:SetBackdropBorderColor(1, 0.9, 0.25, 1)
            cell.selection:SetFrameLevel(cell:GetFrameLevel() + 3)
            cell.selection:Hide()
            local strip = cell.selection:CreateTexture(nil, "BACKGROUND")
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
    self.dragFrame:SetBackdropBorderColor(1, 0.9, 0.25, 1)
    self.dragFrame.icon = self.dragFrame:CreateTexture(nil, "ARTWORK")
    self.dragFrame.icon:SetSize(34, 34)
    self.dragFrame.icon:SetPoint("TOPLEFT", 5, -5)
    self.dragFrame.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    self.dragFrame:Hide()
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
