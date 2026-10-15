local _, Games = ...
local T = Games.Tetris
local Theme = Games.Theme
local function text(parent, value, x, y, width, large)
    return Theme:Label(parent, value, x, y, width, large and "GameFontNormalLarge" or nil)
end
local function button(parent, value, x, y, width, callback)
    return Theme:NeonButton(parent, value, width, x, y, callback, 28)
end
local function panel(parent, width, height, x, y)
    return Theme:Panel(parent, width, height, x, y)
end
local function cell(parent, x, y, size)
    local bg = parent:CreateTexture(nil, "ARTWORK", nil, -2)
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
        cell.bg:SetColorTexture(0.035, 0.06, 0.1, cell.preview and 0 or 1)
        cell.icon:Hide()
    else
        local c = self.Colors[kind]
        cell.bg:SetColorTexture(c[1], c[2], c[3], ghost and 0.3 or 1)
        if cell.icon:SetTexture(self.icons[kind]) == false then
            cell.icon:SetTexture(self.fallbackIcon)
        end
        if self.originalGraphics then
            cell.icon:SetVertexColor(c[1], c[2], c[3])
        else
            cell.icon:SetVertexColor(1, 1, 1)
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
        if c.preview and c.size then
            local offset = kind and (4 - self.Engine.Shapes[kind].size) * c.size / 2 or 0
            Theme:PlaceGame(c.bg, c.baseX + offset, c.baseY)
            Theme:PlaceGame(c.icon, c.baseX + offset + 2, c.baseY + 2)
        end
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
        Theme:ScoreValue(self.scoreText, m.score, 26)
        Theme:ScoreValue(self.bestText, self:Storage().best.score, 26)
        Theme:ScoreValue(self.linesText, m.lines, 26)
        Theme:ScoreValue(self.levelText, m.level, 26)
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
    return Games:SetClassPreset(token)
end
function T:ApplyPreset(token)
    local icons = Games:GetPieceIcons("tetris")
    self.icons = {}
    for i, kind in ipairs(Games.IconPresets.Kinds) do
        self.icons[kind] = icons[i]
    end
    self.originalGraphics = Games:GetSettings().graphicsTheme == "original"
    self.fallbackIcon = self.FallbackIcons[token] or self.FallbackIcons.MAGE
    self:Render(true)
end
local captured =
    { LEFT = true, RIGHT = true, DOWN = true, UP = true, X = true, Z = true, SPACE = true, C = true, P = true }
function T:HasFocus()
    return (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() ~= nil)
        or (Games.UI.resultsFrame and Games.UI.resultsFrame:IsShown())
        or (Games.UI.optionsFrame and Games.UI.optionsFrame:IsShown())
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
local clearColors = {
    { 0.35, 0.85, 1 },
    { 0.45, 1, 0.68 },
    { 1, 0.75, 0.28 },
    { 1, 0.42, 0.9 },
}
local clearTitles = { "LINE CLEAR!", "DOUBLE CLEAR!", "TRIPLE CLEAR!", "TETRIS!" }
function T:ClearLineEffect()
    self.lineEffect = nil
    if not self.lineFlash then
        return
    end
    self.lineFlash:SetAlpha(0)
    self.lineTitle:Hide()
    for _, strip in ipairs(self.lineStrips) do
        strip:Hide()
    end
    for _, spark in ipairs(self.lineSparks) do
        spark:Hide()
    end
end
function T:ShowLineEffect(lines)
    self:ClearLineEffect()
    local level = Games:GetSettings().effectsLevel
    if not self.lineFlash or level == 0 or lines < 1 or lines > 4 then
        return
    end
    self.lineEffect = { lines = lines, level = level, time = 0, duration = 0.45 + lines * 0.11 }
    local color = clearColors[lines]
    self.lineFlash:SetColorTexture(color[1], color[2], color[3], 1)
    self.lineTitle:SetText(clearTitles[lines])
    self.lineTitle:SetTextColor(color[1], color[2], color[3], 1)
    self.lineTitle:Show()
    for i, strip in ipairs(self.lineStrips) do
        strip:SetShown(i <= lines)
        strip:SetColorTexture(color[1], color[2], color[3], 1)
    end
    local count = level == 2 and lines * 4 or lines * 2
    for i, spark in ipairs(self.lineSparks) do
        spark:SetShown(i <= count)
        if i <= count then
            spark:SetColorTexture(color[1], color[2], color[3], 1)
            local size = level == 2 and 8 or 5
            spark:SetSize(size, size)
        end
    end
    self:UpdateLineEffect(0)
end
function T:UpdateLineEffect(dt)
    local effect = self.lineEffect
    if not effect then
        return
    end
    effect.time = effect.time + dt
    local progress = math.min(1, effect.time / effect.duration)
    local fade = 1 - progress
    local strength = effect.level == 2 and 1 or 0.35
    self.lineFlash:SetAlpha(fade * strength * (0.06 + effect.lines * 0.045))
    self.lineTitle:SetAlpha(fade * (effect.level == 2 and 1 or 0.7))
    for i, strip in ipairs(self.lineStrips) do
        if i <= effect.lines then
            strip:SetAlpha(fade * strength * 0.5)
        end
    end
    local width, height = self.cellSize * 10, self.cellSize * 20
    local count = effect.level == 2 and effect.lines * 4 or effect.lines * 2
    for i = 1, count do
        local spark = self.lineSparks[i]
        local angle = i * 2.399963
        spark:ClearAllPoints()
        spark:SetPoint(
            "CENTER",
            self.lineLayer,
            "TOPLEFT",
            12 + width / 2 + math.cos(angle) * progress * width * 0.42,
            -(12 + height / 2 + math.sin(angle) * progress * height * 0.32)
        )
        spark:SetAlpha(fade * strength)
    end
    if progress >= 1 then
        self:ClearLineEffect()
    end
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
        if not self.paused then
            self:Pause(true)
        end
        return
    end
    if not self.paused then
        dt = math.min(dt, 0.25)
        self:UpdateLineEffect(dt)
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
        if self.lastSavedScore ~= self.model.score then
            self:SaveBest()
        end
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
        self:LayoutUI()
        return self.root
    end
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 0, 0)
    self.root, self.keys = root, {}
    self.left = Theme:PremiumFrame(root, 320, 550, 0, 0)
    self.brandIcon = Theme:Art(self.left, "tetris-card", 64, 64, 18, -18, 1, "ARTWORK")
    self.title = Theme:GameLabel(self.left, "TETRIS", 36)
    self.tagline = Theme:GameLabel(self.left, "STACK / CLEAR / BEAT YOUR BEST", 12, Theme.Colors.accent)
    self.intro = Theme:GameLabel(
        self.left,
        "Stack, clear lines, and keep the pieces falling. Simple to learn, endlessly replayable.",
        14
    )
    self.intro:SetMaxLines(3)
    self.controlsHeading = Theme:SectionHeader(self.left, "CONTROLS", 270, 16, -202, 16)
    self.controlsText = Theme:PremiumFrame(self.left, 270, 226, 16, -234, { compact = true })
    self.controlRows = {}
    for _, row in ipairs({
        { "L / R", "Move left / right" },
        { "Up / X", "Rotate clockwise" },
        { "Z", "Rotate reverse" },
        { "Down", "Soft drop" },
        { "Space", "Hard drop" },
        { "C", "Hold piece" },
        { "P", "Pause / resume" },
        { "Chat", "Typing auto-pauses" },
    }) do
        self.controlRows[#self.controlRows + 1] = Theme:KeycapRow(self.controlsText, row[1], row[2])
    end
    self.optionsButton = Theme:GameButton(self.left, "Options", "nav-options", function()
        Games.UI:ShowOptions()
    end)
    self.shareButton = Theme:GameButton(self.left, "Share Best to Chat", "icon-share", function()
        self:ShareBest()
    end)
    local board = Theme:GameBoard(root)
    self.board = board
    self.cells = {}
    for y = 1, 20 do
        for x = 1, 10 do
            self.cells[#self.cells + 1] = cell(board, 0, 0, 20)
        end
    end
    self.lineLayer = CreateFrame("Frame", nil, board)
    self.lineLayer:SetAllPoints(board)
    self.lineLayer:SetFrameLevel(board:GetFrameLevel() + 8)
    self.lineLayer:EnableMouse(false)
    self.lineFlash = self.lineLayer:CreateTexture(nil, "OVERLAY")
    self.lineFlash:SetBlendMode("ADD")
    self.lineFlash:SetAlpha(0)
    self.lineStrips = {}
    for i = 1, 4 do
        local strip = self.lineLayer:CreateTexture(nil, "OVERLAY")
        strip:SetBlendMode("ADD")
        strip:Hide()
        self.lineStrips[i] = strip
    end
    self.lineSparks = {}
    for i = 1, 16 do
        local spark = self.lineLayer:CreateTexture(nil, "OVERLAY")
        spark:SetTexture("Interface\\Buttons\\WHITE8X8")
        spark:SetBlendMode("ADD")
        spark:Hide()
        self.lineSparks[i] = spark
    end
    self.lineTitle = Theme:GameLabel(root, "", 22, Theme.Colors.gold)
    self.lineTitle:SetJustifyH("CENTER")
    self.lineTitle:Hide()
    self.pauseOverlay = Theme:PauseMenu(board, "tetris", self)
    self.pauseText = self.pauseOverlay.title
    self.right = CreateFrame("Frame", nil, root)
    self.sidebar = self.right
    self.statPanel = Theme:PremiumFrame(self.right, 340, 180, 0, 0, { skin = "game-stats-frame" })
    self.statHeading = Theme:SectionHeader(self.statPanel, "STATS", 300, 16, -12, 16)
    self.readouts = {}
    for _, name in ipairs({ "SCORE", "BEST", "LINES", "LEVEL" }) do
        local readout = Theme:StatPanel(self.statPanel, name, 150, 68, 0, 0, { plain = true })
        readout.value:SetFont(Theme.Fonts.display, 26, "")
        readout.detail:Hide()
        self.readouts[#self.readouts + 1] = readout
    end
    self.scoreText, self.bestText = self.readouts[1].value, self.readouts[2].value
    self.linesText, self.levelText = self.readouts[3].value, self.readouts[4].value
    self.bestText:SetTextColor(unpack(Theme.Colors.gold))
    self.crown = Theme:GameIcon(self.readouts[2], "ornament-crown", 20, Theme.Colors.gold)
    self.statDivider = Theme:Separator(self.statPanel, 16, -100, 300)
    self.nextPanel = Theme:PremiumFrame(self.right, 340, 126, 0, 0)
    self.nextHeading = Theme:SectionHeader(self.nextPanel, "NEXT", 300, 16, -12, 16)
    self.nextSlots, self.nextCells = {}, {}
    for i = 1, 5 do
        local slot = Theme:PremiumFrame(self.nextPanel, 60, 64, 0, 0, { compact = true })
        self.nextSlots[i] = slot
        self.nextCells[i] = preview(slot, 0, 0, 16)
        for _, c in ipairs(self.nextCells[i]) do
            c.preview = true
        end
    end
    self.holdPanel = Theme:PremiumFrame(self.right, 340, 150, 0, 0)
    Theme:TintFrame(self.holdPanel, Theme.Colors.violet)
    self.holdHeading = Theme:SectionHeader(self.holdPanel, "HOLD", 140, 16, -12, 16)
    self.holdHeading.title:SetTextColor(unpack(Theme.Colors.violet))
    self.holdSlot = Theme:PremiumFrame(self.holdPanel, 120, 70, 16, -42, { compact = true })
    self.holdCells = preview(self.holdSlot, 0, 0, 20)
    for _, c in ipairs(self.holdCells) do
        c.preview = true
    end
    self.crest = Theme:Art(self.holdPanel, "crest", 140, 140, 180, -4, 0.07, "ARTWORK")
    self.pauseButton = Theme:GameButton(self.right, "Pause (P)", "icon-pause", function()
        self:Pause(not self.paused)
    end, true)
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
    self:LayoutUI()
    self:CreateSummary()
    return root
end
local function positionCell(c, x, y, size)
    c.baseX, c.baseY, c.size = x, y, size
    Theme:PlaceGame(c.bg, x, y, size - 1, size - 1)
    Theme:PlaceGame(c.icon, x + 2, y + 2, size - 5, size - 5)
end
function T:LayoutUI()
    if not self.root then
        return
    end
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    self.root:SetSize(w, h)
    self.cellSize = math.floor(math.min((h - 40) / 20, (w - 616) / 10))
    local bw, bh = 10 * self.cellSize + 24, 20 * self.cellSize + 24
    local leftW = math.max(280, math.floor((w - bw - 32) * 0.48))
    local rightX, rightW = leftW + bw + 32, w - leftW - bw - 32
    Theme:PlaceGame(self.left, 0, 0, leftW, h)
    Theme:PlaceGame(self.board, leftW + 16, math.floor((h - bh) / 2), bw, bh)
    Theme:PlaceGame(self.right, rightX, 0, rightW, h)
    Theme:PlaceGame(self.brandIcon, 18, 18, 64, 64)
    Theme:PlaceGame(self.title, 92, 22, leftW - 108, 46)
    Theme:PlaceGame(self.tagline, 18, 86, leftW - 36, 26)
    Theme:PlaceGame(self.intro, 18, 126, leftW - 36, 64)
    local compact = h < 550
    local controlsY = compact and 192 or 206
    local step = compact and 23 or math.max(26, math.min(34, math.floor(h / 22)))
    Theme:PlaceGame(self.controlsHeading, 18, controlsY, leftW - 36, 26)
    Theme:PlaceGame(self.controlsText, 16, controlsY + 30, leftW - 32, step * 8 + 18)
    for i, row in ipairs(self.controlRows) do
        Theme:PlaceGame(row, 10, 9 + (i - 1) * step, leftW - 52, 22)
    end
    Theme:PlaceGameButton(self.optionsButton, 18, h - 86, leftW - 36, 34)
    Theme:PlaceGameButton(self.shareButton, 18, h - 46, leftW - 36, 34)
    for i, c in ipairs(self.cells) do
        positionCell(
            c,
            12 + ((i - 1) % 10) * self.cellSize,
            12 + math.floor((i - 1) / 10) * self.cellSize,
            self.cellSize
        )
    end
    Theme:PlaceGame(self.lineFlash, 12, 12, self.cellSize * 10, self.cellSize * 20)
    self.lineTitle:ClearAllPoints()
    self.lineTitle:SetPoint("BOTTOM", self.board, "TOP", 0, 8)
    self.lineTitle:SetSize(bw, 28)
    for i, strip in ipairs(self.lineStrips) do
        Theme:PlaceGame(strip, 12, 12 + self.cellSize * (4 * i - 1), self.cellSize * 10, math.max(3, self.cellSize / 4))
    end
    self.pauseOverlay:Layout(bw - 20, 10, (bh - 180) / 2)
    local statsH = math.max(176, math.min(250, math.floor(h * 0.32)))
    Theme:PlaceGame(self.statPanel, 0, 0, rightW, statsH)
    self.statHeading:SetWidth(rightW - 32)
    for i, readout in ipairs(self.readouts) do
        Theme:PlaceGame(
            readout,
            2 + ((i - 1) % 2) * (rightW - 4) / 2,
            30 + math.floor((i - 1) / 2) * 68,
            (rightW - 4) / 2,
            68
        )
    end
    Theme:PlaceGame(self.crown, (rightW - 4) / 2 - 38, 10)
    Theme:PlaceGame(self.statDivider, 16, 101, rightW - 32, 1)
    local columns = rightW >= 350 and 5 or 3
    local slotW = (rightW - 32 - (columns - 1) * 6) / columns
    local slotH = columns == 5 and math.max(66, math.min(100, math.floor(h * 0.11))) or 54
    local nextH = 44 + math.ceil(5 / columns) * (slotH + 6)
    Theme:PlaceGame(self.nextPanel, 0, statsH + 12, rightW, nextH)
    self.nextHeading:SetWidth(rightW - 32)
    for i, slot in ipairs(self.nextSlots) do
        Theme:PlaceGame(
            slot,
            16 + ((i - 1) % columns) * (slotW + 6),
            40 + math.floor((i - 1) / columns) * (slotH + 6),
            slotW,
            slotH
        )
        local size = math.floor(math.min((slotW - 8) / 4, (slotH - 8) / 2))
        for j, c in ipairs(self.nextCells[i]) do
            positionCell(
                c,
                (slotW - 4 * size) / 2 + ((j - 1) % 4) * size,
                (slotH - 2 * size) / 2 + math.floor((j - 1) / 4) * size,
                size
            )
        end
    end
    local holdY = statsH + nextH + 24
    local holdH = h - holdY - 58
    Theme:PlaceGame(self.holdPanel, 0, holdY, rightW, holdH)
    Theme:PlaceGame(self.holdSlot, 16, 38, 120, math.min(70, holdH - 46))
    local holdSize = math.floor(math.min(24, (holdH - 52) / 2))
    for i, c in ipairs(self.holdCells) do
        positionCell(
            c,
            (120 - 4 * holdSize) / 2 + ((i - 1) % 4) * holdSize,
            6 + math.floor((i - 1) / 4) * holdSize,
            holdSize
        )
    end
    local emblem = math.min(140, holdH - 16)
    Theme:PlaceGame(self.crest, rightW - emblem - 18, 8, emblem, emblem)
    Theme:PlaceGameButton(self.pauseButton, 0, h - 42, rightW, 38)
    self:Render(true)
end
function T:CreateSummary()
    local f = panel(UIParent, 440, 284, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Games.UI.frame, "CENTER", 0, 0)
    Theme:Window(f, true, true)
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
