local _, Games = ...
local Theme = Games.Theme

function Theme:PlaceGame(frame, x, y, width, height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", x, -y)
    if width and height then
        frame:SetSize(width, height)
    elseif width then
        frame:SetWidth(width)
    end
end
function Theme:GameLabel(parent, value, size, color)
    local label = self:Label(parent, value, 0, 0, 200)
    label:SetFont(self.Fonts.display, size or 14, "")
    label:SetTextColor(unpack(color or self.Colors.text))
    return label
end
function Theme:ScoreValue(label, value, maxSize)
    local text = tostring(value)
    local format = text .. ":" .. label:GetWidth() .. ":" .. maxSize
    if label.scoreFormat == format then
        return
    end
    label.scoreFormat = format
    label:SetText(text)
    label:SetFont(self.Fonts.display, maxSize, "")
    local measured = label:GetStringWidth()
    if measured > label:GetWidth() and measured > 0 then
        label:SetFont(self.Fonts.display, math.max(9, math.floor(maxSize * label:GetWidth() / measured)), "")
    end
end
function Theme:GameIcon(parent, key, size, color)
    local icon = self:Art(parent, key, size or 22, size or 22, 0, 0, 1, "ARTWORK")
    icon:SetVertexColor(unpack(color or self.Colors.ice))
    return icon
end
function Theme:GameButton(parent, text, key, callback, primary)
    local b = self:NeonButton(parent, text, 200, 0, 0, callback, 34, primary)
    b.gameIcon = self:GameIcon(b, key, 20)
    return b
end
function Theme:PlaceGameButton(b, x, y, width, height)
    self:PlaceGame(b, x, y, width, height or 34)
    b.caption:ClearAllPoints()
    b.caption:SetPoint("CENTER", 10, 0)
    b.caption:SetWidth(width - 48)
    b.gameIcon:ClearAllPoints()
    b.gameIcon:SetPoint("LEFT", 14, 0)
end
function Theme:TintFrame(frame, color)
    frame:SetBackdropBorderColor(unpack(color))
    for _, group in ipairs({ frame.premium.outer or {}, frame.premium.corners or {} }) do
        for _, t in ipairs(group) do
            t:SetColorTexture(unpack(color))
        end
    end
    frame.premium.custom:SetVertexColor(unpack(color))
end
function Theme:GameBoard(parent)
    local board = self:PremiumFrame(parent, 400, 400, 0, 0, { skin = "game-board-frame" })
    board:SetBackdropColor(0.008, 0.018, 0.037, 1)
    board:SetBackdropBorderColor(unpack(self.Colors.accent))
    board.diamonds = {}
    for _, point in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local icon = self:GameIcon(board, "ornament-diamond", 18, self.Colors.accent)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", board, point, 0, 0)
        board.diamonds[#board.diamonds + 1] = icon
    end
    -- Inset rails and a soft native glow: no screenshot frame or running animation.
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        self:CornerOrnament(board, corner, 7, 25, self.Colors.ice)
    end
    return board
end
function Theme:InstructionRow(parent, key, value)
    local row = CreateFrame("Frame", nil, parent)
    row.icon = self:GameIcon(row, key, 19)
    self:PlaceGame(row.icon, 0, 2)
    row.text = self:GameLabel(row, value, 12)
    row.text:SetMaxLines(2)
    row:SetScript("OnSizeChanged", function()
        self:PlaceGame(row.text, 30, 0, row:GetWidth() - 30, row:GetHeight())
    end)
    return row
end
function Theme:GameStatRow(parent, key, title)
    local row = self:InstructionRow(parent, key, title)
    row.text:SetTextColor(unpack(self.Colors.ice))
    row.text:SetMaxLines(1)
    row.value = self:GameLabel(row, "0", 24)
    row.value:SetJustifyH("RIGHT")
    row.rule = self:Separator(row, 0, 0, 100, self.Colors.border, 0.7)
    row:SetScript("OnSizeChanged", function()
        self:PlaceGame(row.text, 30, 6, row:GetWidth() - 90, 24)
        self:PlaceGame(row.value, row:GetWidth() - 62, 0, 62, 30)
        self:PlaceGame(row.rule, 0, row:GetHeight() - 1, row:GetWidth(), 1)
    end)
    return row
end
function Theme:KeycapRow(parent, key, action)
    local row = CreateFrame("Frame", nil, parent)
    row.key = self:Panel(row, 66, 22, 0, 0)
    row.key:SetBackdropBorderColor(unpack(self.Colors.border))
    row.key.label = self:GameLabel(row.key, key, 12, self.Colors.ice)
    row.key.label:ClearAllPoints()
    row.key.label:SetPoint("CENTER")
    row.key.label:SetWidth(62)
    row.key.label:SetJustifyH("CENTER")
    row.text = self:GameLabel(row, action, 13)
    row.text:SetMaxLines(1)
    row:SetScript("OnSizeChanged", function()
        self:PlaceGame(row.text, 80, 3, row:GetWidth() - 80, 22)
    end)
    return row
end
function Theme:GoldBest(parent)
    local f = self:PremiumFrame(parent, 220, 56, 0, 0, { skin = "stat-frame", compact = true })
    self:TintFrame(f, self.Colors.gold)
    f.crown = self:GameIcon(f, "ornament-crown", 24, self.Colors.gold)
    self:PlaceGame(f.crown, 12, 16)
    f.label = self:GameLabel(f, "BEST", 12, self.Colors.ice)
    self:PlaceGame(f.label, 44, 20, 48)
    f.value = self:GameLabel(f, "0", 26, self.Colors.gold)
    f.value:SetJustifyH("RIGHT")
    f:SetScript("OnSizeChanged", function()
        self:PlaceGame(f.value, 96, 12, f:GetWidth() - 110, 34)
    end)
    return f
end
function Theme:PauseMenu(board, gameID, module)
    local dimmer = CreateFrame("Frame", nil, board)
    dimmer:SetAllPoints(board)
    dimmer:SetFrameLevel(board:GetFrameLevel() + 35)
    dimmer:EnableMouse(true)
    dimmer.fill = dimmer:CreateTexture(nil, "BACKGROUND")
    dimmer.fill:SetAllPoints(dimmer)
    dimmer.fill:SetColorTexture(0.003, 0.008, 0.02, 0.82)
    dimmer:Hide()
    local f = self:PremiumFrame(board, 240, 180, 0, 0)
    f:SetFrameLevel(board:GetFrameLevel() + 40)
    f:EnableMouse(true)
    f:SetBackdropColor(0.018, 0.038, 0.075, 1)
    self:TintFrame(f, self.Colors.accent)
    f.dimmer = dimmer
    f:SetScript("OnShow", function()
        dimmer:Show()
    end)
    f:SetScript("OnHide", function()
        dimmer:Hide()
    end)
    f.title = self:GameLabel(f, "PAUSED", 24, self.Colors.ice)
    f.title:SetJustifyH("CENTER")
    f.rule = self:Separator(f, 16, -48, 208, self.Colors.accent, 0.7)
    f.resume = self:NeonButton(f, "Resume", 180, 0, 0, function()
        module:Pause(false)
    end, 28, true)
    f.restart = self:NeonButton(f, "Restart run", 180, 0, 0, function()
        Games:AbortGame()
        Games:StartSingleplayer(gameID)
    end, 28)
    f.stop = self:NeonButton(f, "Stop match", 180, 0, 0, function()
        Games:AbortGame()
        Games.UI:OpenLauncher("home")
    end, 28)
    f.Layout = function(_, width, x, y)
        local available = width
        width = math.min(width, 320)
        x = x + (available - width) / 2
        self:PlaceGame(f, x, y, width, 180)
        self:PlaceGame(f.title, 12, 16, width - 24, 28)
        f.rule:SetWidth(width - 32)
        for i, b in ipairs({ f.resume, f.restart, f.stop }) do
            self:PlaceGame(b, 20, 52 + (i - 1) * 38, width - 40, 28)
            b.caption:SetWidth(width - 56)
        end
    end
    f:Hide()
    return f
end
