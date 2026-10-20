local _, Games = ...
local B, R, T = Games.Battleships, Games.Battleships.Rules, Games.Theme
local colors = {
    water = { 0.025, 0.075, 0.12 },
    ship = { 0.08, 0.4, 0.51 },
    miss = { 0.08, 0.16, 0.22 },
    hit = { 0.64, 0.15, 0.13 },
    sunk = { 0.55, 0.36, 0.08 },
    valid = { 0.1, 0.52, 0.34 },
    invalid = { 0.6, 0.12, 0.16 },
    edge = { 0.13, 0.28, 0.36 },
}
local function label(parent, text, size, color)
    return T:GameLabel(parent, text, size or 13, color)
end
local function place(...)
    T:PlaceGame(...)
end
function B:CanDeploy()
    return self.running
        and self.view
        and self.view.phase == "setup"
        and not self.view.ownReady
        and not self.pending
        and not self.waiting
end
function B:Deploy(index, button)
    if not self:CanDeploy() then
        return
    end
    if button == "RightButton" then
        self:Rotate()
        return
    end
    local x, y = (index - 1) % 10 + 1, math.floor((index - 1) / 10) + 1
    if R.Place(self.draft, self.selected, x, y, self.vertical) then
        self.notice = R.Ships[self.selected].name .. " placed at " .. R.Coordinate(index) .. "."
        for i = 1, 5 do
            if not self.draft[i] then
                self.selected = i
                break
            end
        end
        self:Save()
    else
        self.notice = "That ship does not fit there. Rotate or choose another square."
    end
    self:Render()
end
function B:Rotate()
    if not self:CanDeploy() then
        return
    end
    self.vertical = not self.vertical
    self:Save()
    self:Render()
end
function B:CreateGrid(side)
    local board = T:GameBoard(self.root)
    board.heading = label(board, side == 1 and "YOUR FLEET" or "ENEMY WATERS", 15, T.Colors.ice)
    board.heading:SetJustifyH("CENTER")
    board.cells, board.columns, board.rows = {}, {}, {}
    for i = 1, 10 do
        board.columns[i] = label(board, string.char(64 + i), 11, T.Colors.muted)
        board.columns[i]:SetJustifyH("CENTER")
        board.rows[i] = label(board, tostring(i), 11, T.Colors.muted)
        board.rows[i]:SetJustifyH("CENTER")
    end
    for i = 1, 100 do
        local index = i
        local cell = CreateFrame("Button", nil, board, "BackdropTemplate")
        cell:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        cell.mark = label(cell, "", 16, T.Colors.ice)
        cell.mark:SetAllPoints(cell)
        cell.mark:SetJustifyH("CENTER")
        cell.mark:SetJustifyV("MIDDLE")
        cell:SetScript("OnClick", function(_, button)
            if side == 1 then
                self:Deploy(index, button)
            elseif button == "LeftButton" then
                self:Request("fire", index)
            end
        end)
        cell:SetScript("OnEnter", function()
            self.hover = { side = side, index = index }
            self:Render()
        end)
        cell:SetScript("OnLeave", function()
            self.hover = nil
            self:Render()
        end)
        board.cells[i] = cell
    end
    return board
end
function B:CreateUI(parent)
    if self.root then
        self.root:SetParent(parent)
        self:LayoutUI()
        return self.root
    end
    self.root = CreateFrame("Frame", nil, parent)
    self.root:SetPoint("TOPLEFT", 0, 0)
    self.left = T:PremiumFrame(self.root, 210, 540, 0, 0)
    self.brand = T:Art(self.left, "battleships-card", 44, 44, 16, -16, 1, "ARTWORK")
    if not self.brand.artLoaded then
        self.brand:SetTexture(237284)
    end
    self.title = label(self.left, "BATTLESHIPS", 22)
    self.tagline = label(self.left, "TWO PLAYERS / ONE OCEAN", 10, T.Colors.accent)
    self.intro = label(self.left, "Hide your fleet. Find theirs. Sink all five enemy ships to win.", 13)
    self.fleetHeading = T:SectionHeader(self.left, "DEPLOY FLEET", 180, 16, -146, 14)
    self.shipButtons = {}
    for ship, spec in ipairs(R.Ships) do
        local id = ship
        self.shipButtons[ship] = T:NeonButton(self.left, spec.name .. "  " .. spec.length, 180, 16, -180, function()
            if self:CanDeploy() then
                self.selected = id
                self:Save()
                self:Render()
            end
        end, 29)
    end
    self.rotate = T:NeonButton(self.left, "Rotate (R)", 180, 16, -350, function()
        self:Rotate()
    end, 30)
    self.auto = T:NeonButton(self.left, "Auto-place", 86, 16, -390, function()
        if self:CanDeploy() then
            self.draft = R.RandomFleet()
            self.notice = nil
            self:Save()
            self:Render()
        end
    end, 30)
    self.clear = T:NeonButton(self.left, "Clear", 86, 110, -390, function()
        if self:CanDeploy() then
            self.draft, self.selected, self.notice = {}, 1, nil
            self:Save()
            self:Render()
        end
    end, 30)
    self.help = label(
        self.left,
        "Click: place / fire\nRight-click or R: rotate\nShips may touch; never overlap.",
        12,
        T.Colors.muted
    )
    self.lock = T:GameButton(self.left, "Lock fleet", "icon-pause", function()
        self:Request("lock")
    end, true)
    self.phaseTitle = label(self.root, "DEPLOY YOUR FLEET", 23, T.Colors.ice)
    self.phaseTitle:SetJustifyH("CENTER")
    self.subtitle = label(self.root, "", 13, T.Colors.muted)
    self.subtitle:SetJustifyH("CENTER")
    self.boards = { self:CreateGrid(1), self:CreateGrid(2) }
    self.legend = label(self.root, "SHIP  /  . MISS  /  X HIT  /  # SUNK", 12, T.Colors.ice)
    self.legend:SetJustifyH("CENTER")
    self.status = label(self.root, "", 14, T.Colors.ice)
    self.status:SetJustifyH("CENTER")
    self.status:SetMaxLines(3)
    self.right = T:PremiumFrame(self.root, 180, 540, 0, 0, { skin = "game-stats-frame" })
    self.statsHeading = T:SectionHeader(self.right, "REPORT", 148, 16, -16, 14)
    self.opponent = label(self.right, "", 13, T.Colors.ice)
    self.opponent:SetMaxLines(3)
    self.readouts = {}
    for i, title in ipairs({ "YOUR SHIPS", "ENEMY SHIPS", "HITS / SHOTS" }) do
        self.readouts[i] = T:StatPanel(self.right, title, 148, 76, 16, 0, { plain = true })
        self.readouts[i].detail:Hide()
    end
    self.record = label(self.right, "", 13, T.Colors.gold)
    self.record:SetMaxLines(3)
    self.resign = T:GameButton(self.right, "Resign", "icon-back", function()
        self:Request("resign")
    end)
    self:CreateSummary()
    self.root:SetPropagateKeyboardInput(true)
    self.root:SetScript("OnKeyDown", function(root, key)
        if key == "R" and self:CanDeploy() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then
            root:SetPropagateKeyboardInput(false)
            if not self.rotateHeld then
                self.rotateHeld = true
                self:Rotate()
            end
        else
            root:SetPropagateKeyboardInput(true)
        end
    end)
    self.root:SetScript("OnKeyUp", function(root, key)
        if key == "R" then
            self.rotateHeld = false
        end
        root:SetPropagateKeyboardInput(true)
    end)
    self.root:SetScript("OnHide", function(root)
        self.hover, self.rotateHeld = nil, false
        root:SetPropagateKeyboardInput(true)
    end)
    self.root:Hide()
    self:LayoutUI()
    return self.root
end
function B:LayoutUI()
    if not self.root then
        return
    end
    self.hover = nil
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    self.root:SetSize(w, h)
    local lw, rw, gap =
        math.max(200, math.min(240, math.floor(w * 0.202))), math.max(160, math.min(210, math.floor(w * 0.167))), 12
    local cx, cw = lw + gap, w - lw - rw - gap * 2
    place(self.left, 0, 0, lw, h)
    place(self.right, w - rw, 0, rw, h)
    place(self.title, 16, 76, lw - 32, 28)
    place(self.tagline, 16, 58, lw - 32, 18)
    place(self.intro, 16, 111, lw - 32, 50)
    place(self.fleetHeading, 16, 167, lw - 32, 24)
    for i, button in ipairs(self.shipButtons) do
        place(button, 16, 202 + (i - 1) * 33, lw - 32, 29)
    end
    place(self.rotate, 16, 375, lw - 32, 30)
    local half = (lw - 40) / 2
    place(self.auto, 16, 413, half, 30)
    place(self.clear, 24 + half, 413, half, 30)
    place(self.help, 16, 455, lw - 32, h - 515)
    T:PlaceGameButton(self.lock, 16, h - 50, lw - 32, 34)
    place(self.phaseTitle, cx, 16, cw, 32)
    place(self.subtitle, cx + 8, 56, cw - 16, 38)
    self.step = math.max(18, math.min(32, math.floor((cw - gap - 72) / 20), math.floor((h - 280) / 10)))
    local bw, bh = self.step * 10 + 36, self.step * 10 + 66
    local bx, by = cx + (cw - bw * 2 - gap) / 2, 108 + math.max(0, (h - 214 - bh) / 2)
    for side, board in ipairs(self.boards) do
        place(board, bx + (side - 1) * (bw + gap), by, bw, bh)
        place(board.heading, 6, 9, bw - 12, 22)
        for i = 1, 10 do
            place(board.columns[i], 28 + (i - 1) * self.step, 35, self.step, 16)
            place(board.rows[i], 4, 54 + (i - 1) * self.step, 21, self.step - 2)
        end
        for i, cell in ipairs(board.cells) do
            place(
                cell,
                28 + (i - 1) % 10 * self.step,
                54 + math.floor((i - 1) / 10) * self.step,
                self.step - 2,
                self.step - 2
            )
        end
    end
    place(self.legend, cx, by + bh + 14, cw, 22)
    place(self.status, cx + 12, h - 67, cw - 24, 60)
    place(self.statsHeading, 16, 16, rw - 32, 24)
    place(self.opponent, 16, 58, rw - 32, 64)
    for i, stat in ipairs(self.readouts) do
        place(stat, 0, 140 + (i - 1) * 88, rw, 80)
    end
    place(self.record, 16, h - 120, rw - 32, 55)
    T:PlaceGameButton(self.resign, 16, h - 50, rw - 32, 34)
    self:Render()
end
function B:Render()
    if not self.root or not self.view then
        return
    end
    local v, deploy = self.view, self:CanDeploy()
    local own = R.Board(v.ownReady and R.DecodeFleet(v.ownFleet) or self.draft) or {}
    local enemy = v.enemyFleet ~= "" and R.Board(R.DecodeFleet(v.enemyFleet)) or {}
    local preview, fits = {}, true
    if deploy and self.hover and self.hover.side == 1 then
        local x, y = (self.hover.index - 1) % 10 + 1, math.floor((self.hover.index - 1) / 10) + 1
        fits = R.CanPlace(self.draft, self.selected, x, y, self.vertical)
        for offset = 0, R.Ships[self.selected].length - 1 do
            local index = R.Index(x + (self.vertical and 0 or offset), y + (self.vertical and offset or 0))
            if index then
                preview[index] = true
            end
        end
    end
    for side, board in ipairs(self.boards) do
        local grid, fleet = side == 1 and v.incoming or v.outgoing, side == 1 and own or enemy
        for index, cell in ipairs(board.cells) do
            local shot = grid:sub(index, index)
            local color, mark = colors.water, ""
            if (fleet[index] or 0) > 0 then
                color = colors.ship
            end
            if shot == "1" then
                color, mark = colors.miss, "."
            elseif shot == "2" then
                color, mark = colors.hit, "X"
            elseif shot == "3" then
                color, mark = colors.sunk, "#"
            end
            if side == 1 and preview[index] then
                color = fits and colors.valid or colors.invalid
            end
            cell:SetBackdropColor(color[1], color[2], color[3], 1)
            local highlighted = self.hover and self.hover.side == side and self.hover.index == index
                or v.last == index and v.lastShooter == (side == 1 and 3 - self.seat or self.seat)
            cell:SetBackdropBorderColor(unpack(highlighted and T.Colors.gold or colors.edge))
            cell.mark:SetText(mark)
        end
    end
    for i, button in ipairs(self.shipButtons) do
        local sunk = v.ownReady and true or false
        if sunk then
            for _, index in ipairs(R.Cells(i, self.draft[i])) do
                if v.incoming:sub(index, index) ~= "3" then
                    sunk = false
                end
            end
        end
        button:SetText(
            R.Ships[i].name .. "  " .. R.Ships[i].length .. (sunk and "  SUNK" or self.draft[i] and "  OK" or "")
        )
        button:SetEnabled(deploy)
        T:Select(button, deploy and self.selected == i)
    end
    self.rotate:SetText(self.vertical and "Vertical  /  R to rotate" or "Horizontal  /  R to rotate")
    self.fleetHeading:SetText(v.phase == "setup" and "DEPLOY FLEET" or "YOUR FLEET")
    for _, button in ipairs({ self.rotate, self.auto, self.clear }) do
        button:SetEnabled(deploy)
    end
    self.lock:SetEnabled(deploy and R.EncodeFleet(self.draft) ~= nil)
    self.lock:SetText(v.ownReady and "Fleet locked" or self.pending and "Sending..." or "Lock fleet")
    self.resign:SetEnabled(self.running and v.phase ~= "ended" and not self.pending and not self.waiting)
    local ended = v.phase == "ended" or self.result and self.result.status == "completed"
    local won = v.winner == self.seat
    if self.result then
        for _, entry in ipairs(self.result.entries) do
            if entry.player == self.context.player then
                won = entry.outcome == "win"
            end
        end
    end
    self.phaseTitle:SetText(
        ended and (won and "VICTORY" or "DEFEAT")
            or v.phase == "setup" and "DEPLOY YOUR FLEET"
            or v.turn == self.seat and "YOUR TURN"
            or "ENEMY TURN"
    )
    self.subtitle:SetText(
        ended
                and (v.phase == "ended" and "The battle is over. Both fleets are revealed." or "Battle over. Showing the last confirmed board.")
            or v.phase == "setup" and (v.ownReady and "Fleet locked. Waiting for your opponent." or "Select a ship, place it on your grid, then lock your fleet.")
            or "One shot per turn. Click an unmarked square in enemy waters."
    )
    self.opponent:SetText(
        "OPPONENT\n"
            .. self.session.members[3 - self.seat].name
            .. "\n"
            .. (v.enemyReady and "Fleet locked" or "Deploying fleet")
    )
    local values = { v.ownLeft .. " / 5", v.enemyLeft .. " / 5", R.Hits(v.outgoing) .. " / " .. R.Shots(v.outgoing) }
    for i, value in ipairs(values) do
        self.readouts[i].value:SetText(value)
        self.readouts[i].value:SetFont(T.Fonts.display, 28, "")
    end
    local s = self:Storage().stats
    self.record:SetText("YOUR RECORD\n" .. s.wins .. " wins / " .. s.losses .. " losses")
    local status = self.notice
    if not status and v.last > 0 then
        local grid = v.lastShooter == self.seat and v.outgoing or v.incoming
        local shot = grid:sub(v.last, v.last)
        status = (v.lastShooter == self.seat and "Your shot: " or "Enemy shot: ")
            .. R.Coordinate(v.last)
            .. (shot == "1" and " - Miss" or shot == "3" and " - Ship sunk!" or " - Hit!")
    end
    self.status:SetText(
        self.waiting and "Connection interrupted. Waiting for your opponent..."
            or self.pending and "Waiting for confirmation..."
            or status
            or (deploy and "Position all five ships. Auto-place is available for a quick start." or "")
    )
end
function B:CreateSummary()
    local f = T:Panel(UIParent, 440, 306, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", Games.UI.frame, "CENTER", 0, 0)
    T:Window(f, true, true)
    T:CloseButton(f)
    _G.KICGamesBattleshipsResult = f
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesBattleshipsResult"
    f.heading = T:Label(f, "BATTLE OVER", 24, -26, 350)
    T:Label(f, "BATTLESHIPS", 24, -56, 380, "GameFontNormalLarge")
    f.details = T:Label(f, "", 24, -96, 392)
    f.details:SetFont(T.Fonts.display, 16, "")
    f.again = T:NeonButton(f, "Rematch", 188, 24, -252, function()
        self:Rematch()
    end)
    f.menu = T:NeonButton(f, "Back to menu", 188, 228, -252, function()
        Games.UI:OpenLauncher("home")
    end)
    f:Hide()
    self.summary = f
    Games.UI:RegisterAuxiliaryWindow(f)
end
function B:ShowResult()
    local v = self.view
    local won, score = v.winner == self.seat, R.Hits(v.outgoing)
    for _, entry in ipairs(self.result.entries) do
        if entry.player == self.context.player then
            won, score = entry.outcome == "win", entry.score
        end
    end
    self.summary.heading:SetText(won and "VICTORY!" or "DEFEAT")
    self.summary.heading:SetTextColor(unpack(won and T.Colors.success or { 1, 0.38, 0.3 }))
    self.summary.details:SetText(
        string.format(
            "%s\nScore: %d / 17 hits\nShots fired: %d\nYour ships remaining: %d\nRematch: both players must ready up.",
            v.reason == "resigned" and "The battle ended by resignation." or "The enemy fleet was destroyed.",
            score,
            R.Shots(v.outgoing),
            v.ownLeft
        )
    )
    if not won and v.reason ~= "resigned" then
        self.summary.details:SetText(self.summary.details:GetText():gsub("The enemy fleet", "Your fleet"))
    end
    if v.phase ~= "ended" then
        self.summary.details:SetText(
            string.format(
                "Match complete.\nScore: %d / 17 hits\nFinal board unavailable.\nRematch: both players must ready up.",
                score
            )
        )
    end
    self.summary:Show()
end
