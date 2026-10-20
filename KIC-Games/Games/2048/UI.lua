local _, Games = ...
local G, Theme = Games.Game2048, Games.Theme
local palette = {
    { 0.07, 0.22, 0.32 },
    { 0.08, 0.32, 0.44 },
    { 0.03, 0.45, 0.58 },
    { 0.12, 0.3, 0.68 },
    { 0.35, 0.19, 0.65 },
    { 0.54, 0.18, 0.64 },
    { 0.69, 0.26, 0.26 },
    { 0.72, 0.38, 0.1 },
    { 0.73, 0.5, 0.08 },
    { 0.76, 0.62, 0.13 },
    { 0.91, 0.75, 0.25 },
}
local keys = { LEFT = "left", RIGHT = "right", UP = "up", DOWN = "down", A = "left", D = "right", W = "up", S = "down" }
local function place(...)
    Theme:PlaceGame(...)
end
local function label(parent, text, size, color)
    return Theme:GameLabel(parent, text, size, color)
end

function G:CancelDrag()
    self.drag = nil
end

function G:StartDrag()
    if not self:CanInput() then
        return false
    end
    local x, y = GetCursorPosition()
    self.drag =
        { x = x, y = y, scale = self.canvas:GetEffectiveScale(), width = self.canvas:GetWidth(), dx = 0, dy = 0 }
    return true
end

function G:StopDrag()
    local drag = self.drag
    if not drag then
        return
    end
    local x, y = GetCursorPosition()
    self:CancelDrag()
    if drag.scale ~= self.canvas:GetEffectiveScale() or drag.width ~= self.canvas:GetWidth() or not self:CanInput() then
        self:Render()
        return
    end
    local dx, dy = (x - drag.x) / drag.scale, (y - drag.y) / drag.scale
    if math.max(math.abs(dx), math.abs(dy)) < math.max(18, self.step * 0.2) then
        self:Render()
        return
    end
    local direction = math.abs(dx) >= math.abs(dy) and (dx > 0 and "right" or "left") or (dy > 0 and "up" or "down")
    self:Move(direction)
end

function G:UpdateDrag()
    local drag = self.drag
    if not drag then
        return
    end
    if
        not self.running
        or not self.root:IsVisible()
        or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        or self.canvas:GetEffectiveScale() ~= drag.scale
        or self.canvas:GetWidth() ~= drag.width
    then
        self:CancelDrag()
        return
    end
    -- Track the held mouse globally, so releasing outside the board still ends
    -- exactly one gesture. Hiding/resizing/typing cancels it instead.
    if not IsMouseButtonDown("LeftButton") then
        self:StopDrag()
        return
    end
    local x, y = GetCursorPosition()
    local limit = self.step * 0.15
    drag.dx = math.max(-limit, math.min(limit, (x - drag.x) / drag.scale))
    drag.dy = math.max(-limit, math.min(limit, -(y - drag.y) / drag.scale))
end

function G:KeyDown(key)
    if
        not self.running
        or not self.root:IsVisible()
        or not keys[key]
        or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        or self.summary:IsShown()
    then
        self.root:SetPropagateKeyboardInput(true)
        return
    end
    self.root:SetPropagateKeyboardInput(false)
    if self.keys[key] then
        return
    end
    self.keys[key] = true
    self:Move(keys[key])
end

function G:Advance(elapsed)
    if not self.running or not self.root:IsVisible() then
        return
    end
    local redraw = self.drag or self.animation or self.pop
    self:UpdateDrag()
    elapsed = math.max(0, math.min(elapsed, 0.25))
    if self.animation then
        self.animation.time = self.animation.time + elapsed
        if self.animation.time >= self.animation.duration then
            self.pop = { time = 0, move = self.animation.move }
            self.animation = nil
        end
    elseif self.pop then
        self.pop.time = self.pop.time + elapsed
        if self.pop.time >= 0.12 then
            self.pop = nil
        end
    end
    if redraw or self.animation or self.pop then
        self:Render()
    end
    if not self.animation and not self.pop and self.model.state ~= "playing" then
        self:Complete()
    end
end

function G:CreateUI(parent)
    if self.root then
        self.root:SetParent(parent)
        self:LayoutUI()
        return self.root
    end
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 0, 0)
    self.root, self.keys = root, {}
    self.left = Theme:PremiumFrame(root, 240, 540, 0, 0)
    self.brand = Theme:Art(self.left, "2048-card", 56, 56, 16, -18, 1, "ARTWORK")
    self.title = label(self.left, "2048", 40)
    self.tagline = label(self.left, "SLIDE / MERGE / REACH 2048", 11, Theme.Colors.accent)
    self.intro = label(
        self.left,
        "Bring equal numbers together. Every move slides the whole board; every merge grows your score.",
        14
    )
    self.intro:SetMaxLines(4)
    self.controlsHeading = Theme:SectionHeader(self.left, "CONTROLS", 200, 16, -174, 16)
    self.controls = {}
    for _, entry in ipairs({
        { "Drag", "Hold + swipe" },
        { "Arrows", "Slide tiles" },
        { "W A S D", "Slide tiles" },
    }) do
        self.controls[#self.controls + 1] = Theme:KeycapRow(self.left, entry[1], entry[2])
    end
    self.tipHeading = Theme:SectionHeader(self.left, "HOW TO PLAY", 200, 16, -332, 16)
    self.tip = label(
        self.left,
        "2 + 2 = 4. Each tile merges once per move. Keep space free and build toward 2048.",
        13,
        Theme.Colors.ice
    )
    self.tip:SetMaxLines(4)
    self.restart = Theme:GameButton(self.left, "New game", "icon-swap", function()
        self:NewGame()
    end, true)
    self.share = Theme:GameButton(self.left, "Share best", "icon-share", function()
        self:ShareBest()
    end)

    self.board = Theme:GameBoard(root)
    self.canvas = CreateFrame("Frame", nil, self.board)
    self.canvas:SetPoint("TOPLEFT", 12, -12)
    self.canvas:SetClipsChildren(true)
    self.canvas:EnableMouse(true)
    self.canvas:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:StartDrag()
        end
    end)
    self.canvas:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            self:StopDrag()
        end
    end)
    self.slots, self.tiles = {}, {}
    for i = 1, 16 do
        local slot = self.canvas:CreateTexture(nil, "BACKGROUND")
        slot:SetColorTexture(0.023, 0.065, 0.11, 1)
        self.slots[i] = slot
        local tile = CreateFrame("Frame", nil, self.canvas, "BackdropTemplate")
        tile:EnableMouse(false)
        tile:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        tile.text = label(tile, "", 36)
        tile.text:SetAllPoints(tile)
        tile.text:SetJustifyH("CENTER")
        tile.text:SetJustifyV("MIDDLE")
        tile.glint = tile:CreateTexture(nil, "ARTWORK")
        tile.glint:SetColorTexture(0.7, 0.95, 1, 0.2)
        tile.glint:SetPoint("TOPLEFT", 5, -5)
        tile.glint:SetPoint("TOPRIGHT", -5, -5)
        tile.glint:SetHeight(2)
        self.tiles[i] = tile
    end
    self.boardTitle = label(root, "REACH THE 2048 TILE", 18, Theme.Colors.ice)
    self.boardTitle:SetJustifyH("CENTER")
    self.status = label(root, "", 13, Theme.Colors.muted)
    self.status:SetJustifyH("CENTER")
    self.status:SetMaxLines(2)
    self.right = Theme:PremiumFrame(root, 210, 540, 0, 0, { skin = "game-stats-frame" })
    self.statsHeading = Theme:SectionHeader(self.right, "RUN STATS", 178, 16, -16, 16)
    self.readouts = {}
    for i, title in ipairs({ "SCORE", "BEST SCORE", "HIGHEST TILE", "MOVES" }) do
        local stat = Theme:StatPanel(self.right, title, 178, 80, 16, 0, { plain = true })
        stat.detail:Hide()
        self.readouts[i] = stat
    end
    self.readouts[2].value:SetTextColor(unpack(Theme.Colors.gold))
    self.goalTitle = label(self.right, "ONE TILE. ONE GOAL.", 13, Theme.Colors.gold)
    self.goalText =
        label(self.right, "Reach 2048 to win. A new 2 or 4 appears only after a valid move.", 13, Theme.Colors.ice)
    self.goalText:SetMaxLines(5)
    self:CreateSummary()
    root:SetScript("OnKeyDown", function(_, key)
        self:KeyDown(key)
    end)
    root:SetScript("OnKeyUp", function(_, key)
        self.keys[key] = nil
        root:SetPropagateKeyboardInput(true)
    end)
    root:SetScript("OnUpdate", function(_, elapsed)
        self:Advance(elapsed)
    end)
    root:SetScript("OnHide", function()
        self:CancelDrag()
        self.keys, self.animation, self.pop = {}, nil, nil
        root:SetPropagateKeyboardInput(true)
    end)
    root:SetPropagateKeyboardInput(true)
    root:Hide()
    self:LayoutUI()
    return root
end

function G:LayoutUI()
    if not self.root then
        return
    end
    self:CancelDrag()
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    self.root:SetSize(w, h)
    local leftW = math.max(230, math.min(290, math.floor(w * 0.24)))
    local rightW = math.max(190, math.min(260, math.floor(w * 0.2)))
    local centerW, centerX = w - leftW - rightW - 32, leftW + 16
    place(self.left, 0, 0, leftW, h)
    place(self.right, w - rightW, 0, rightW, h)
    place(self.title, 84, 20, leftW - 100, 50)
    place(self.tagline, 16, 82, leftW - 32, 22)
    place(self.intro, 16, 114, leftW - 32, 80)
    place(self.controlsHeading, 16, 204, leftW - 32, 24)
    for i, row in ipairs(self.controls) do
        place(row, 16, 240 + (i - 1) * 34, leftW - 32, 28)
    end
    place(self.tipHeading, 16, 350, leftW - 32, 24)
    place(self.tip, 16, 384, leftW - 32, 80)
    Theme:PlaceGameButton(self.restart, 16, h - 92, leftW - 32, 34)
    Theme:PlaceGameButton(self.share, 16, h - 50, leftW - 32, 34)
    local available = math.min(centerW, h - 102)
    self.step = math.max(40, math.floor((available - 24) / 4))
    self.tileSize = self.step - 8
    local size = self.step * 4 + 24
    place(self.board, centerX + math.floor((centerW - size) / 2), 48 + math.floor((h - 100 - size) / 2), size, size)
    self.canvas:SetSize(self.step * 4, self.step * 4)
    for i, slot in ipairs(self.slots) do
        local x, y = self:TilePoint(i)
        place(slot, x, y, self.tileSize, self.tileSize)
    end
    place(self.boardTitle, centerX, 12, centerW, 28)
    place(self.status, centerX, h - 40, centerW, 34)
    place(self.statsHeading, 16, 16, rightW - 32, 24)
    local step = math.min(90, math.floor((h - 175) / 4))
    for i, stat in ipairs(self.readouts) do
        place(stat, 0, 52 + (i - 1) * step, rightW, step)
    end
    place(self.goalTitle, 16, h - 112, rightW - 32, 24)
    place(self.goalText, 16, h - 80, rightW - 32, 68)
    self:Render()
end

function G:TilePoint(index)
    return 4 + ((index - 1) % 4) * self.step, 4 + math.floor((index - 1) / 4) * self.step
end

function G:PaintTile(tile, value, x, y, scale)
    if value == 0 then
        tile:Hide()
        return
    end
    local tier, power = 1, value
    while power > 2 do
        tier, power = tier + 1, power / 2
    end
    local color = palette[math.min(tier, #palette)]
    tile:SetBackdropColor(color[1], color[2], color[3], 1)
    tile:SetBackdropBorderColor(unpack(value >= 128 and Theme.Colors.gold or Theme.Colors.ice))
    local size = self.tileSize * (scale or 1)
    place(tile, x + (self.tileSize - size) / 2, y + (self.tileSize - size) / 2, size, size)
    local digits = #tostring(value)
    tile.text:SetFont(
        Theme.Fonts.display,
        math.max(18, math.floor(math.min(48, size * (digits >= 4 and 0.3 or digits == 3 and 0.37 or 0.45)))),
        "OUTLINE"
    )
    tile.text:SetText(tostring(value))
    tile.text:SetTextColor(unpack(value >= 1024 and { 0.09, 0.08, 0.035 } or Theme.Colors.text))
    tile:Show()
end

function G:Render()
    local m = self.model
    if not m then
        return
    end
    local animation = self.animation
    if animation then
        local t = math.min(1, animation.time / animation.duration)
        t = t * t * (3 - 2 * t)
        for i, track in ipairs(animation.move.tracks) do
            local x0, y0 = self:TilePoint(track.from)
            local x1, y1 = self:TilePoint(track.to)
            self:PaintTile(self.tiles[i], track.value, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
        end
        for i = #animation.move.tracks + 1, 16 do
            self.tiles[i]:Hide()
        end
    else
        for i, value in ipairs(m.board) do
            local x, y = self:TilePoint(i)
            local scale = 1
            if self.pop then
                local t = math.min(1, self.pop.time / 0.12)
                if self.pop.move.merged[i] then
                    scale = 1 + math.sin(t * math.pi) * 0.12
                elseif self.pop.move.spawned == i then
                    scale = 0.55 + 0.45 * t
                end
            end
            self:PaintTile(
                self.tiles[i],
                value,
                x + (self.drag and self.drag.dx or 0),
                y + (self.drag and self.drag.dy or 0),
                scale
            )
        end
    end
    local finished = not self.running and m.state ~= "playing"
    self.boardTitle:SetText(
        m.state == "won" and "2048 REACHED!" or m.state == "lost" and "NO MOVES LEFT" or "REACH THE 2048 TILE"
    )
    self.boardTitle:SetTextColor(unpack(m.state == "won" and Theme.Colors.gold or Theme.Colors.ice))
    self.restart:SetText(finished and "Play again" or "New game")
    self.status:SetText(finished and "Run complete. Play again or return to the launcher." or self.message or "")
    for i, value in ipairs({ m.score, self:Storage().best.score, m:Highest(), m.moves }) do
        Theme:ScoreValue(self.readouts[i].value, value, 30)
    end
end

function G:CreateSummary()
    local f = Theme:Panel(UIParent, 440, 284, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Games.UI.frame, "CENTER", 0, 0)
    Theme:Window(f, true, true)
    Theme:CloseButton(f)
    _G.KICGames2048Result = f
    UISpecialFrames[#UISpecialFrames + 1] = "KICGames2048Result"
    f.heading = Theme:Label(f, "RUN COMPLETE", 24, -26, 350)
    Theme:Label(f, "2048", 24, -54, 380, "GameFontNormalLarge")
    f.details = Theme:Label(f, "", 24, -104, 392)
    f.details:SetFont(Theme.Fonts.display, 17, "")
    f.again = Theme:NeonButton(f, "Play again", 188, 24, -230, function()
        self:NewGame()
    end)
    f.menu = Theme:NeonButton(f, "Back to menu", 188, 228, -230, function()
        Games.UI:OpenLauncher("home")
    end)
    f:Hide()
    self.summary = f
    Games.UI:RegisterAuxiliaryWindow(f)
end
