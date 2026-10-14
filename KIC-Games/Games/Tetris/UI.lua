local _, Games = ...
local T = Games.Tetris
local Theme = Games.Theme
local function text(parent, value, x, y, width, large)
    return Theme:Label(parent, value, x, y, width, large and "GameFontNormalLarge" or nil)
end
local function button(parent, value, x, y, width, callback)
    return Theme:Button(parent, value, width, x, y, callback, 24)
end
local function panel(parent, width, height, x, y)
    return Theme:Panel(parent, width, height, x, y)
end
local function cell(parent, x, y, size)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(size - 1, size - 1)
    bg:SetPoint("TOPLEFT", x, y)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size - 5, size - 5)
    icon:SetPoint("TOPLEFT", x + 2, y - 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return { bg = bg, icon = icon }
end
function T:Paint(cell, kind, ghost)
    if not kind then
        cell.bg:SetColorTexture(0.07, 0.085, 0.12, 1)
        cell.icon:Hide()
    else
        local c = self.Colors[kind]
        cell.bg:SetColorTexture(c[1], c[2], c[3], ghost and 0.3 or 1)
        if cell.icon:SetTexture(self.icons[kind]) == false then
            cell.icon:SetTexture(self.fallbackIcon)
        end
        cell.icon:SetAlpha(ghost and 0.18 or 1)
        cell.icon:Show()
    end
end
function T:Preview(cells, kind)
    local map = {}
    if kind then
        for _, c in ipairs(self.Engine:Cells(kind, 0, 1, 1)) do
            map[(c[2] - 1) * 4 + c[1]] = kind
        end
    end
    for i, c in ipairs(cells) do
        self:Paint(c, map[i])
    end
end
function T:Render(force)
    local m = self.model
    if not m or not self.root then
        return
    end
    if force or self.drawRevision ~= m.revision then
        local ghost, active = {}, {}
        if not m.gameover then
            for _, c in ipairs(m:Cells(m.kind, m.rotation, m.x, m:Ghost())) do
                ghost[(c[2] - 3) * 10 + c[1]] = m.kind
            end
            for _, c in ipairs(m:Cells(m.kind, m.rotation, m.x, m.y)) do
                active[(c[2] - 3) * 10 + c[1]] = m.kind
            end
        end
        for y = 3, 22 do
            for x = 1, 10 do
                local i = (y - 3) * 10 + x
                local kind = m.board[y][x] or active[i] or ghost[i]
                self:Paint(self.cells[i], kind, not m.board[y][x] and not active[i] and ghost[i] ~= nil)
            end
        end
        self.scoreText:SetText(
            string.format(
                "Score: %d\nBest: %d\nLines: %d    Level: %d",
                m.score,
                self:Storage().best.score,
                m.lines,
                m.level
            )
        )
        for i, cells in ipairs(self.nextCells) do
            self:Preview(cells, m.queue[i])
        end
        self:Preview(self.holdCells, m.hold)
        self.drawRevision = m.revision
    end
    self.pauseOverlay:SetShown(self.paused == true)
    self.pauseButton:SetText(self.paused and "Resume (P)" or "Pause (P)")
end
function T:SelectPreset(token)
    if not self.ByToken[token] then
        return
    end
    self:Storage().preset = token
    self.icons = self:GetIcons(token)
    self.fallbackIcon = self.FallbackIcons[token]
    for _, preset in ipairs(self.Presets) do
        Theme:Select(self.presetButtons[preset.token], token == preset.token)
        self.presetButtons[preset.token]:SetText(
            (token == preset.token and "> " or "") .. "|cff" .. preset.color .. preset.name .. "|r"
        )
    end
    self:Render(true)
end
local captured =
    { LEFT = true, RIGHT = true, DOWN = true, UP = true, X = true, Z = true, SPACE = true, C = true, P = true }
function T:HasFocus()
    return (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil)
        or (Games.UI.resultsFrame and Games.UI.resultsFrame:IsShown())
end
function T:ReleaseKeys()
    self.keys = {}
    if self.root then
        self.root:SetPropagateKeyboardInput(true)
    end
end
function T:Pause(value)
    self.paused = value
    self:ReleaseKeys()
    self:Render()
end
function T:KeyDown(key)
    if not self.running or not self.root:IsVisible() or self:HasFocus() or not captured[key] then
        self.root:SetPropagateKeyboardInput(true)
        if self:HasFocus() then
            self:Pause(true)
        end
        return
    end
    self.root:SetPropagateKeyboardInput(false)
    if self.keys[key] then
        return
    end
    self.keys[key] = { elapsed = 0, next = key == "DOWN" and 0.035 or 0.16 }
    if key == "P" then
        self:Pause(not self.paused)
        self.keys.P = { elapsed = 0, next = 0 }
        self.root:SetPropagateKeyboardInput(false)
        return
    end
    if self.paused then
        return
    end
    local m = self.model
    if key == "LEFT" then
        m:Move(-1, 0)
    elseif key == "RIGHT" then
        m:Move(1, 0)
    elseif key == "DOWN" then
        m:SoftDrop()
    elseif key == "UP" or key == "X" then
        m:Rotate(1)
    elseif key == "Z" then
        m:Rotate(-1)
    elseif key == "SPACE" then
        m:HardDrop()
    elseif key == "C" then
        m:Hold()
    end
    self:Advance(0)
end
function T:Advance(dt)
    if not self.running then
        return
    end
    if not self.root:IsVisible() or self:HasFocus() then
        self:Pause(true)
        return
    end
    if not self.paused then
        dt = math.min(dt, 0.25)
        for _, key in ipairs({ "LEFT", "RIGHT", "DOWN" }) do
            local held = self.keys[key]
            if held then
                held.elapsed = held.elapsed + dt
                while held.elapsed >= held.next do
                    held.next = held.next + (key == "DOWN" and 0.035 or 0.05)
                    if key == "DOWN" then
                        self.model:SoftDrop()
                    else
                        self.model:Move(key == "LEFT" and -1 or 1, 0)
                    end
                end
            end
        end
        self.model:Update(dt)
        self:SaveBest()
    end
    self:Render()
    if self.model.gameover then
        self:Complete()
    end
end
local function preview(parent, x, y, size)
    local cells = {}
    for row = 1, 2 do
        for col = 1, 4 do
            cells[#cells + 1] = cell(parent, x + (col - 1) * size, y - (row - 1) * size, size)
        end
    end
    return cells
end
function T:CreateUI(parent)
    if self.root then
        return self.root
    end
    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    self.root, self.keys = root, {}
    text(root, "TETRIS", 20, -12, 260, true):SetTextColor(unpack(Theme.Colors.accent))
    text(root, "ICON COLLECTION / CLASS", 20, -46, 260):SetTextColor(unpack(Theme.Colors.muted))
    self.presetButtons = {}
    for i, preset in ipairs(self.Presets) do
        local token = preset.token
        self.presetButtons[token] = button(
            root,
            preset.name,
            20 + ((i - 1) % 2) * 134,
            -70 - math.floor((i - 1) / 2) * 27,
            130,
            function()
                self:SelectPreset(token)
            end
        )
    end
    button(root, "Share best to chat", 20, -274, 264, function()
        self:ShareBest()
    end)
    text(
        root,
        "Left / Right: move\nUp / X: rotate   Z: reverse\nDown: soft drop\nSpace: hard drop\nC: hold   P: pause\nHidden window / chat: auto-pause",
        20,
        -314,
        275
    )
    local board = panel(root, 202, 402, 312, -20)
    board:SetBackdropColor(0.025, 0.03, 0.05, 1)
    board:SetBackdropBorderColor(unpack(Theme.Colors.accent))
    self.cells = {}
    for y = 1, 20 do
        for x = 1, 10 do
            self.cells[#self.cells + 1] = cell(board, 1 + (x - 1) * 20, -1 - (y - 1) * 20, 20)
        end
    end
    self.pauseOverlay = panel(board, 200, 108, 1, -147)
    self.pauseOverlay:SetFrameLevel(board:GetFrameLevel() + 5)
    self.pauseOverlay:SetBackdropColor(0.035, 0.043, 0.065, 0.97)
    self.pauseText = text(self.pauseOverlay, "PAUSED", 18, -24, 164, true)
    self.pauseText:SetJustifyH("CENTER")
    text(self.pauseOverlay, "Press P to resume", 18, -60, 164):SetJustifyH("CENTER")
    self.scoreText = text(root, "", 548, -22, 290, true)
    self.scoreText:SetFont("Fonts\\ARIALN.TTF", 18, "")
    text(root, "UP NEXT", 548, -115, 290):SetTextColor(unpack(Theme.Colors.muted))
    self.nextCells = {}
    for i = 1, 5 do
        self.nextCells[i] = preview(root, 548 + (i % 2 == 0 and 104 or 0), -140 - math.floor((i - 1) / 2) * 48, 20)
    end
    text(root, "HOLD / C", 548, -290, 290):SetTextColor(unpack(Theme.Colors.muted))
    self.holdCells = preview(root, 548, -315, 20)
    self.pauseButton = button(root, "Pause (P)", 548, -376, 230, function()
        self:Pause(not self.paused)
    end)
    root:SetScript("OnKeyDown", function(_, key)
        self:KeyDown(key)
    end)
    root:SetScript("OnKeyUp", function(_, key)
        self.keys[key] = nil
        root:SetPropagateKeyboardInput(true)
    end)
    root:SetScript("OnHide", function()
        if self.running then
            self:Pause(true)
        end
    end)
    root:SetScript("OnUpdate", function(_, dt)
        self:Advance(dt)
    end)
    root:SetPropagateKeyboardInput(true)
    root:Hide()
    self:CreateSummary()
    return root
end
function T:CreateSummary()
    local f = panel(UIParent, 440, 284, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Games.UI.frame, "CENTER", 0, 0)
    Theme:Window(f, true)
    _G.KICGamesTetrisResult = f
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesTetrisResult"
    Theme:CloseButton(f)
    text(f, "RUN COMPLETE", 24, -26, 350):SetTextColor(unpack(Theme.Colors.accent))
    text(f, "Game over", 24, -54, 380, true)
    self.summaryText = text(f, "", 24, -104, 392)
    self.summaryText:SetFont("Fonts\\ARIALN.TTF", 17, "")
    button(f, "Play again", 24, -230, 188, function()
        f:Hide()
        Games:StartSingleplayer("tetris")
    end)
    Theme:Select(
        button(f, "Share best", 228, -230, 188, function()
            self:ShareBest()
        end),
        true
    )
    f:Hide()
    self.summary = f
    Games.UI:RegisterAuxiliaryWindow(f)
end
