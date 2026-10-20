local _, Games = ...
local M, Theme = Games.Minesweeper, Games.Theme
local colors = {
    { 0.3, 0.8, 1 },
    { 0.2, 0.95, 0.55 },
    { 1, 0.48, 0.28 },
    { 0.8, 0.55, 1 },
    { 1, 0.75, 0.25 },
    { 0.3, 1, 0.9 },
    { 1, 0.55, 0.8 },
    { 0.95, 0.95, 1 },
}
local function label(parent, text, size, color)
    return Theme:GameLabel(parent, text, size, color)
end

function M:CreateCell(index)
    local cell = CreateFrame("Button", nil, self.board, "BackdropTemplate")
    cell:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell.text = label(cell, "", 16)
    cell.text:SetAllPoints(cell)
    cell.text:SetJustifyH("CENTER")
    cell.text:SetJustifyV("MIDDLE")
    cell.pole = cell:CreateTexture(nil, "ARTWORK")
    cell.pole:SetColorTexture(1, 0.8, 0.4, 1)
    cell.flag = cell:CreateTexture(nil, "ARTWORK")
    cell.flag:SetColorTexture(1, 0.22, 0.25, 1)
    cell.highlight = cell:CreateTexture(nil, "HIGHLIGHT")
    cell.highlight:SetAllPoints(cell)
    cell.highlight:SetColorTexture(0.4, 0.85, 1, 0.18)
    cell:SetScript("OnClick", function(_, button)
        if not self.model then
            return
        end
        self:Click((index - 1) % self.model.width + 1, math.floor((index - 1) / self.model.width) + 1, button)
    end)
    return cell
end

function M:CreateUI(parent)
    if self.root then
        self.root:SetParent(parent)
        self.board:SetParent(self.root)
        self:LayoutUI()
        return self.root
    end
    self.root = CreateFrame("Frame", nil, parent)
    self.root:SetPoint("TOPLEFT")
    self.left = Theme:PremiumFrame(self.root, 220, 520, 0, 0)
    self.title = label(self.left, "MINESWEEPER", 25)
    self.tagline = label(self.left, "REVEAL / FLAG / CLEAR", 11, Theme.Colors.accent)
    self.intro = label(self.left, "Read the numbers. Find the safe path. Reveal every safe tile to win.", 13)
    self.intro:SetMaxLines(3)
    self.controlsHeading = Theme:SectionHeader(self.left, "CONTROLS", 180, 16, -126, 15)
    self.controls = label(
        self.left,
        "Left click: reveal\nRight click: flag > ? > clear\nFirst reveal is always safe.",
        12,
        Theme.Colors.ice
    )
    self.difficultyHeading = Theme:SectionHeader(self.left, "DIFFICULTY", 180, 16, -226, 15)
    self.difficultyHint = label(self.left, "Choose a level to start a fresh run.", 11, Theme.Colors.muted)
    self.difficultyHint:SetMaxLines(2)
    self.difficultyButtons = {}
    for _, difficulty in ipairs(self.Engine.Difficulties) do
        local id = difficulty.id
        self.difficultyButtons[id] = Theme:NeonButton(
            self.left,
            string.format("%s  %dx%d / %d", difficulty.title, difficulty.width, difficulty.height, difficulty.mines),
            188,
            16,
            0,
            function()
                self:NewGame(id)
            end,
            32
        )
    end
    self.restart = Theme:GameButton(self.left, "New game", "icon-swap", function()
        self:NewGame(self.model.difficulty)
    end, true)
    self.right = Theme:PremiumFrame(self.root, 180, 520, 0, 0, { skin = "game-stats-frame" })
    self.statsHeading = Theme:SectionHeader(self.right, "RUN STATS", 148, 16, -16, 16)
    self.readouts = {}
    for i, title in ipairs({ "TIME", "MINES LEFT", "REVEALED", "BEST TIME" }) do
        local readout = Theme:StatPanel(self.right, title, 148, 72, 16, 0, { plain = true })
        readout.value:SetFont(Theme.Fonts.display, 26, "")
        readout.detail:Hide()
        self.readouts[i] = readout
    end
    self.readouts[4].value:SetTextColor(unpack(Theme.Colors.gold))
    self.bestHeading = label(self.right, "BEST BY DIFFICULTY", 11, Theme.Colors.gold)
    self.bestList = label(self.right, "", 12, Theme.Colors.ice)
    self.bestList:SetMaxLines(3)
    self.clockHint =
        label(self.right, "Timer starts on your first reveal and keeps running while away.", 11, Theme.Colors.muted)
    self.clockHint:SetMaxLines(3)
    self.board = Theme:GameBoard(self.root)
    self.cells = {}
    self.boardTitle = label(self.root, "", 18, Theme.Colors.ice)
    self.boardTitle:SetJustifyH("CENTER")
    self.status = label(self.root, "Choose any tile to begin.", 13, Theme.Colors.muted)
    self.status:SetJustifyH("CENTER")
    self.status:SetMaxLines(2)
    self:CreateSummary()
    self.root:SetScript("OnUpdate", function(_, elapsed)
        if not self.running or not self.startedAt then
            return
        end
        self.updateTime = self.updateTime + elapsed
        if self.updateTime >= 0.1 then
            self.updateTime = 0
            Theme:ScoreValue(self.readouts[1].value, self:TimeText(self:Elapsed()), 26)
        end
    end)
    self.root:Hide()
    self:LayoutUI()
    return self.root
end

function M:LayoutBoard(size, parent, x, y)
    local m = self.model
    if not m then
        return
    end
    self.board:SetParent(parent)
    Theme:PlaceGame(self.board, x, y, m.width * size + 16, m.height * size + 16)
    for i = 1, m.width * m.height do
        local cell = self.cells[i]
        if not cell then
            cell = self:CreateCell(i)
            self.cells[i] = cell
        end
        Theme:PlaceGame(
            cell,
            8 + ((i - 1) % m.width) * size,
            8 + math.floor((i - 1) / m.width) * size,
            size - 1,
            size - 1
        )
        cell.text:SetFont(Theme.Fonts.display, math.max(11, math.floor(size * 0.64)), "OUTLINE")
        Theme:PlaceGame(cell.pole, math.floor(size * 0.32), math.floor(size * 0.2), 2, math.floor(size * 0.63))
        Theme:PlaceGame(
            cell.flag,
            math.floor(size * 0.32) + 2,
            math.floor(size * 0.2),
            math.floor(size * 0.4),
            math.floor(size * 0.3)
        )
        cell:Show()
    end
    for i = m.width * m.height + 1, #self.cells do
        self.cells[i]:Hide()
    end
end

function M:LayoutUI()
    if not self.root then
        return
    end
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    self.root:SetSize(w, h)
    local leftW = math.max(210, math.min(270, math.floor(w * 0.23)))
    local rightW = math.max(176, math.min(230, math.floor(w * 0.18)))
    local centerW, centerX = w - leftW - rightW - 32, leftW + 16
    Theme:PlaceGame(self.left, 0, 0, leftW, h)
    Theme:PlaceGame(self.right, w - rightW, 0, rightW, h)
    Theme:PlaceGame(self.title, 16, 22, leftW - 32, 34)
    self.title:SetFont(Theme.Fonts.display, leftW < 240 and 22 or 26, "")
    Theme:PlaceGame(self.tagline, 16, 60, leftW - 32, 20)
    Theme:PlaceGame(self.intro, 16, 88, leftW - 32, 58)
    Theme:PlaceGame(self.controlsHeading, 16, 156, leftW - 32, 24)
    Theme:PlaceGame(self.controls, 16, 188, leftW - 32, 66)
    Theme:PlaceGame(self.difficultyHeading, 16, 264, leftW - 32, 24)
    for i, difficulty in ipairs(self.Engine.Difficulties) do
        Theme:PlaceGame(self.difficultyButtons[difficulty.id], 16, 300 + (i - 1) * 38, leftW - 32, 32)
    end
    Theme:PlaceGame(self.difficultyHint, 16, 418, leftW - 32, 32)
    Theme:PlaceGameButton(self.restart, 16, h - 52, leftW - 32, 36)
    Theme:PlaceGame(self.statsHeading, 16, 16, rightW - 32, 24)
    local statStep = math.min(80, math.floor((h - 220) / 4))
    for i, readout in ipairs(self.readouts) do
        Theme:PlaceGame(readout, 12, 52 + (i - 1) * statStep, rightW - 24, statStep)
    end
    local bestY = 56 + 4 * statStep
    Theme:PlaceGame(self.bestHeading, 16, bestY, rightW - 32, 20)
    Theme:PlaceGame(self.bestList, 16, bestY + 24, rightW - 32, 64)
    Theme:PlaceGame(self.clockHint, 16, h - 70, rightW - 32, 56)
    Theme:PlaceGame(self.boardTitle, centerX, 14, centerW, 28)
    Theme:PlaceGame(self.status, centerX, h - 50, centerW, 42)
    if self.model then
        local size = math.floor(math.min(40, (centerW - 16) / self.model.width, (h - 112) / self.model.height))
        self.cellSize = math.max(12, size)
        local bw, bh = self.model.width * self.cellSize + 16, self.model.height * self.cellSize + 16
        self:LayoutBoard(
            self.cellSize,
            self.root,
            centerX + math.floor((centerW - bw) / 2),
            48 + math.floor((h - 106 - bh) / 2)
        )
    end
    self:Render()
end

function M:Render()
    local m = self.model
    if not m then
        return
    end
    local finished = m.state == "won" or m.state == "lost"
    for i, data in ipairs(m.cells) do
        local cell = self.cells[i]
        if cell then
            local flag = data.mark == 1 or (m.state == "won" and data.mine)
            local text, color = "", Theme.Colors.ice
            local bg, border = Theme.Colors.selected, Theme.Colors.border
            if data.revealed then
                bg, border = { 0.08, 0.115, 0.17, 1 }, { 0.14, 0.21, 0.29, 1 }
                if data.count > 0 then
                    text, color = tostring(data.count), colors[data.count]
                end
            elseif data.mark == 2 then
                text, color = "?", Theme.Colors.gold
            end
            if finished and data.mine and not flag then
                text, color = "*", { 1, 0.42, 0.3 }
                bg = i == m.detonated and { 0.55, 0.055, 0.05, 1 } or { 0.18, 0.055, 0.08, 1 }
                border = { 0.9, 0.23, 0.2, 1 }
            elseif finished and flag and not data.mine then
                flag, text, color = false, "X", { 1, 0.4, 0.35 }
            end
            cell:SetBackdropColor(unpack(bg))
            cell:SetBackdropBorderColor(unpack(border))
            cell.text:SetText(text)
            cell.text:SetTextColor(unpack(color))
            cell.flag:SetShown(flag)
            cell.pole:SetShown(flag)
            cell:SetEnabled(self.running and not finished and not data.revealed)
        end
    end
    local storage, difficulty = self:Storage(), self.Engine.ByID[m.difficulty]
    local result = m.state == "won" and "WIN  /  " or m.state == "lost" and "LOSS  /  " or ""
    self.boardTitle:SetText(string.format("%s%s  /  %d x %d", result, difficulty.title:upper(), m.width, m.height))
    self.boardTitle:SetTextColor(
        unpack(m.state == "won" and Theme.Colors.success or m.state == "lost" and { 1, 0.38, 0.3 } or Theme.Colors.ice)
    )
    self.restart:SetText(finished and "Play again" or "New game")
    self.status:SetText(
        m.state == "ready" and "Choose any tile to begin. Your first reveal is safe."
            or m.state == "won" and (self.newBest and "NEW BEST TIME! Every safe tile revealed." or "Every safe tile revealed. Well played!")
            or m.state == "lost" and "Mines shown. X marks an incorrect flag. Play again for a fresh board."
            or "Numbers count mines in the eight surrounding tiles."
    )
    Theme:ScoreValue(self.readouts[1].value, self:TimeText(self:Elapsed()), 26)
    Theme:ScoreValue(self.readouts[2].value, m.state == "won" and 0 or m.mines - m.flagged, 26)
    Theme:ScoreValue(self.readouts[3].value, m.revealed .. " / " .. (#m.cells - m.mines), 26)
    Theme:ScoreValue(self.readouts[4].value, self:TimeText(storage.best[m.difficulty]), 26)
    local lines = {}
    for _, preset in ipairs(self.Engine.Difficulties) do
        Theme:Select(self.difficultyButtons[preset.id], m.difficulty == preset.id)
        lines[#lines + 1] = preset.title .. ": " .. self:TimeText(storage.best[preset.id])
    end
    self.bestList:SetText(table.concat(lines, "\n"))
end

function M:CreateSummary()
    local f = Theme:Panel(UIParent, 440, 284, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Games.UI.frame, "CENTER", 0, 0)
    Theme:Window(f, true, true)
    Theme:CloseButton(f)
    _G.KICGamesMinesweeperResult = f
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesMinesweeperResult"
    f.heading = Theme:Label(f, "GAME OVER", 24, -26, 350)
    Theme:Label(f, "Run complete", 24, -54, 380, "GameFontNormalLarge")
    f.details = Theme:Label(f, "", 24, -104, 392)
    f.details:SetFont(Theme.Fonts.display, 17, "")
    f.again = Theme:NeonButton(f, "Play again", 188, 24, -230, function()
        self:NewGame(self.model.difficulty)
    end)
    f.menu = Theme:NeonButton(f, "Back to menu", 188, 228, -230, function()
        Games.UI:OpenLauncher("home")
    end)
    f:Hide()
    self.summary = f
    Games.UI:RegisterAuxiliaryWindow(f)
end

-- FinishGame releases the session; keep its final board in the normal game view.
function M:ShowResult()
    Games.UI.completedGame = { game = Games.Registry.minesweeper, frame = self.root }
    Games.UI:ShowGame()
    local m, f = self.model, self.summary
    local won = m.state == "won"
    f.heading:SetText(
        won and (self.newBest and "WIN - NEW BEST TIME!" or "WIN - FIELD CLEARED!") or "GAME OVER - MINE REVEALED"
    )
    f.heading:SetTextColor(unpack(won and Theme.Colors.success or { 1, 0.38, 0.3 }))
    f.details:SetText(
        string.format(
            "Score: %d (safe tiles)\nTime: %s\nBest time: %s\nDifficulty: %s\nRevealed: %d / %d",
            m.revealed,
            self:TimeText(self.finishedTime),
            self:TimeText(self:Storage().best[m.difficulty]),
            self.Engine.ByID[m.difficulty].title,
            m.revealed,
            #m.cells - m.mines
        )
    )
    f:Show()
end
