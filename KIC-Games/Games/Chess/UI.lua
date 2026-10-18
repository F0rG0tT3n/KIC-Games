local _, Games = ...
local C, E, Theme = Games.Chess, Games.Chess.Engine, Games.Theme
local pieceNames = { "pawn", "knight", "bishop", "rook", "queen", "king" }
local function pieceArt(piece)
    return "chess-" .. (piece > 0 and "white-" or "black-") .. pieceNames[math.abs(piece)]
end
local function place(f, x, y, w, h)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", x, -y)
    if w and h then
        f:SetSize(w, h)
    elseif w then
        f:SetWidth(w)
    end
end
local function button(parent, label, x, y, width, callback)
    return Theme:NeonButton(parent, label, width, x, -y, function()
        local ok, err = callback()
        if ok == false and err then
            C.notice = err
            C.actionNotice = err
            C:RefreshAll()
        end
    end, 30, true)
end
local function label(parent, text, x, y, width, large)
    local f = Theme:Label(parent, text, x, -y, width, large and "GameFontNormalLarge" or "GameFontHighlight")
    return f
end
function C:LocalSide()
    if self.match and self.match.practice then
        return 1
    end
    return self.match and (self.match.info.white == Games:PlayerName() and 1 or -1) or 1
end
function C:InputSide()
    return self.match and self.match.practice and self.match.state.turn or self:LocalSide()
end
function C:CanInput()
    local m = self.match
    return self.running
        and m
        and not m.finished
        and not m.abandoned
        and not m.ended
        and not m.recovering
        and not self.pending
        and (m.practice or self:Party())
        and m.state.turn == self:InputSide()
end
function C:SubmitMove(from, to, promotion)
    if not self:CanInput() then
        return false
    end
    if self.claiming then
        local uci = E.Name(from) .. E.Name(to) .. (promotion or "")
        local kind = E.Claim(self.match.state, "threefold", uci) and "threefold"
            or E.Claim(self.match.state, "fifty", uci) and "fifty"
        if not kind then
            self.notice = "That move does not make a valid draw claim."
            self.actionNotice = self.notice
            self:Render()
            return false
        end
        self.claiming = nil
        return self:Request(kind .. ":" .. uci)
    end
    return self:Move(from, to, promotion)
end
function C:ClickSquare(s)
    if not self:CanInput() then
        return
    end
    local p = self.match.state
    if self.selected then
        local candidates = {}
        for _, m in ipairs(E.LegalMoves(p, self.selected)) do
            if m.to == s then
                candidates[#candidates + 1] = m
            end
        end
        if #candidates > 0 then
            local from = self.selected
            if candidates[1].promotion then
                self:ShowPromotion(from, s)
            else
                self:SubmitMove(from, s)
            end
            return
        end
    end
    self.selected = p.board[s] * self:InputSide() > 0 and self.selected ~= s and s or nil
    self:Render()
end
function C:ShowPromotion(from, to)
    self.promotionMove = { from = from, to = to, seq = self.match.seq }
    for i, kind in ipairs({ 5, 4, 3, 2 }) do
        Theme:SetArt(self.promotionButtons[i].piece, pieceArt(kind * self:InputSide()), 58, 58, 1)
    end
    self.promotion:Show()
end
function C:ChoosePromotion(kind)
    local move = self.promotionMove
    self.promotion:Hide()
    self.promotionMove = nil
    if move and move.seq == self.match.seq then
        return self:SubmitMove(move.from, move.to, kind)
    end
end
function C:CreateUI(parent)
    if self.root then
        self:LayoutUI()
        return self.root
    end
    self.root = CreateFrame("Frame", nil, parent)
    self.root:SetAllPoints(parent)
    self.left = Theme:PremiumFrame(self.root, 220, 550, 0, 0)
    self.hero = Theme:Art(self.left, "chess-hero", 190, 95, 14, -14)
    self.title = label(self.left, "CHESS", 16, 124, 190, true)
    self.subtitle = label(self.left, "THINK / MOVE / CHECKMATE", 16, 159, 190)
    self.subtitle:SetFont(Theme.Fonts.body, 11, "")
    self.opponent = label(self.left, "", 16, 194, 190)
    self.opponent:SetHeight(46)
    self.yourColor = label(self.left, "", 16, 245, 190)
    self.matchStatus = label(self.left, "", 16, 277, 190)
    self.matchStatus:SetHeight(84)
    self.drawButton = button(self.left, "Offer draw", 16, 376, 188, function()
        return self:Request(
            self.match
                    and self.match.offer
                    and (self.match.practice or self.match.offer ~= Games:PlayerName())
                    and "accept"
                or "offer"
        )
    end)
    self.declineDraw = button(self.left, "Decline draw", 16, 414, 188, function()
        return self:Request("decline")
    end)
    self.practiceNew = button(self.left, "New test game", 16, 414, 188, function()
        return self:StartPractice(true)
    end)
    self.practiceNew:Hide()
    self.claimDraw = button(self.left, "Claim draw", 16, 452, 188, function()
        if not self:CanInput() then
            return false
        end
        local p = self.match.state
        if E.Claim(p, "threefold") then
            return self:Request("threefold")
        end
        if E.Claim(p, "fifty") then
            return self:Request("fifty")
        end
        self.claiming = not self.claiming
        self.actionNotice = nil
        self.selected = nil
        self:Render()
        return true
    end)
    self.resignButton = button(self.left, "Resign", 16, 490, 188, function()
        return self:Request("resign")
    end)
    self.board = Theme:GameBoard(self.root)
    self.cells, self.fileLabels, self.rankLabels = {}, {}, {}
    for i = 1, 64 do
        local cell = CreateFrame("Button", nil, self.board)
        cell.base = cell:CreateTexture(nil, "BACKGROUND")
        cell.base:SetAllPoints(cell)
        cell.overlays = {}
        for index, key in ipairs({ "last-move", "valid-move", "selected", "check" }) do
            local art = cell:CreateTexture(nil, "ARTWORK", nil, index)
            art:SetAllPoints(cell)
            art:SetTexture(Games.Artwork["chess-square-" .. key].file)
            cell.overlays[key] = art
        end
        cell.piece = cell:CreateTexture(nil, "OVERLAY")
        cell.piece:SetPoint("CENTER", cell, "CENTER")
        cell:SetScript("OnClick", function()
            self:ClickSquare(cell.square)
        end)
        self.cells[i] = cell
    end
    for i = 1, 8 do
        self.fileLabels[i] = label(self.board, "", 0, 0, 24)
        self.rankLabels[i] = label(self.board, "", 0, 0, 16)
        self.fileLabels[i]:SetJustifyH("CENTER")
        self.rankLabels[i]:SetJustifyH("CENTER")
    end
    self.right = Theme:PremiumFrame(self.root, 244, 550, 0, 0)
    self.whiteName = label(self.right, "", 14, 18, 216)
    self.whiteName:SetHeight(36)
    self.blackName = label(self.right, "", 14, 62, 216)
    self.blackName:SetHeight(36)
    self.turnText = label(self.right, "", 14, 108, 216, true)
    self.resultText = label(self.right, "", 14, 139, 216)
    self.resultText:SetHeight(40)
    self.capturedWhiteLabel = label(self.right, "Captured by White", 14, 184, 216)
    self.capturedBlackLabel = label(self.right, "Captured by Black", 14, 256, 216)
    self.captureIcons = {}
    for side = 1, 2 do
        self.captureIcons[side] = {}
        for i = 1, 15 do
            self.captureIcons[side][i] = self.right:CreateTexture(nil, "ARTWORK")
        end
    end
    self.historyTitle = label(self.right, "MOVE HISTORY", 14, 332, 216)
    self.history, self.historyScroll = Theme:Scroll(self.right, 216, 186, 14, -360)
    self.historyText = label(self.history, "", 2, 0, 196)
    self.historyText:SetFont(Theme.Fonts.body, 14, "")
    self.historyText:SetSpacing(4)
    self.promotion = CreateFrame("Frame", nil, self.board, "BackdropTemplate")
    self.promotion:SetAllPoints(self.board)
    self.promotion:SetFrameLevel(self.board:GetFrameLevel() + 40)
    self.promotion:EnableMouse(true)
    self.promotion:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    self.promotion:SetBackdropColor(0.008, 0.018, 0.04, 0.96)
    local chooser = Theme:PremiumFrame(self.promotion, 340, 150, 0, 0)
    chooser:ClearAllPoints()
    chooser:SetPoint("CENTER", self.promotion, "CENTER")
    label(chooser, "CHOOSE PROMOTION", 18, 14, 304, true):SetJustifyH("CENTER")
    self.promotionButtons = {}
    for i, kind in ipairs({ "q", "r", "b", "n" }) do
        local b = Theme:Button(chooser, "", 66, 18 + (i - 1) * 80, -59, function()
            self:ChoosePromotion(kind)
        end, 66)
        -- Piece art must render above the button's opaque backdrop.
        b.piece = Theme:Art(b, "chess-white-queen", 58, 58, 4, -4, 1, "OVERLAY")
        self.promotionButtons[i] = b
    end
    self.promotion:Hide()
    self:LayoutUI()
    return self.root
end
function C:LayoutUI()
    if not self.root then
        return
    end
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    self.root:SetSize(w, h)
    local leftW, rightW, gap = 218, 254, 14
    local cell = math.floor((math.min(w - leftW - rightW - 2 * gap, h) - 32) / 8)
    local size = cell * 8 + 32
    place(self.left, 0, 0, leftW, h)
    place(self.right, w - rightW, 0, rightW, h)
    place(self.board, leftW + gap + (w - leftW - rightW - 2 * gap - size) / 2, math.floor((h - size) / 2), size, size)
    self.cellSize = cell
    for i, c in ipairs(self.cells) do
        place(c, 16 + ((i - 1) % 8) * cell, 16 + math.floor((i - 1) / 8) * cell, cell, cell)
        c.piece:SetSize(cell * 0.9, cell * 0.9)
    end
    for i = 1, 8 do
        place(self.fileLabels[i], 16 + (i - 1) * cell, size - 16, cell, 16)
        place(self.rankLabels[i], 0, 16 + (i - 1) * cell + (cell - 16) / 2, 16, 16)
    end
    self.historyScroll:SetSize(rightW - 28, h - 374)
    self.practiceNew:SetParent(self.right)
    place(self.practiceNew, 14, h - 90, rightW - 28, 30)
    if not self.practiceLeave then
        self.practiceLeave = button(self.right, "Leave test", 14, h - 52, rightW - 28, function()
            return self:StopPractice()
        end)
    end
    place(self.practiceLeave, 14, h - 52, rightW - 28, 30)
    self.history:SetWidth(rightW - 36)
    self.historyText:SetWidth(rightW - 44)
    self:Render()
end
function C:Render()
    local m = self.match
    if not self.root or not m then
        return
    end
    local p = m.state
    local side = self:LocalSide()
    if self.renderedSeq ~= m.seq or self.renderedID ~= m.info.id then
        self.selected, self.claiming = nil, nil
        self.actionNotice = nil
        if self.promotion then
            self.promotion:Hide()
        end
        self.renderedSeq, self.renderedID = m.seq, m.info.id
    end
    local targets = {}
    if self.selected and self:CanInput() then
        for _, move in ipairs(E.LegalMoves(p, self.selected)) do
            targets[move.to] = true
        end
    end
    local checkSquare = E.InCheck(p) and E.King(p, p.turn)
    for i, cell in ipairs(self.cells) do
        local col, row = (i - 1) % 8 + 1, math.floor((i - 1) / 8) + 1
        local file, rank = side == 1 and col or 9 - col, side == 1 and 9 - row or row
        local s = (rank - 1) * 8 + file
        cell.square = s
        cell.base:SetTexture(Games.Artwork["chess-square-" .. ((file + rank) % 2 == 0 and "dark" or "light")].file)
        cell.overlays["last-move"]:SetShown(p.last and (p.last.from == s or p.last.to == s) or false)
        cell.overlays["valid-move"]:SetShown(targets[s] == true)
        cell.overlays.selected:SetShown(self.selected == s)
        cell.overlays.check:SetShown(checkSquare == s)
        if p.board[s] ~= 0 then
            cell.piece:SetTexture(Games.Artwork[pieceArt(p.board[s])].file)
            cell.piece:Show()
        else
            cell.piece:Hide()
        end
    end
    for i = 1, 8 do
        self.fileLabels[i]:SetText(string.char(64 + (side == 1 and i or 9 - i)))
        self.rankLabels[i]:SetText(side == 1 and 9 - i or i)
    end
    local other = side == 1 and m.info.black or m.info.white
    self.title:SetText(m.practice and "CHESS / TEST" or "CHESS")
    self.subtitle:SetText(m.practice and "ONE PLAYER / BOTH SIDES" or "THINK / MOVE / CHECKMATE")
    self.opponent:SetText(m.practice and "Local test\nYou control both sides" or "Opponent\n" .. other)
    self.yourColor:SetText(
        m.practice and "You play White and Black" or "You play " .. (side == 1 and "White" or "Black")
    )
    self.whiteName:SetText("WHITE\n" .. m.info.white)
    self.blackName:SetText("BLACK\n" .. m.info.black)
    self.turnText:SetText(
        m.abandoned and "MATCH INTERRUPTED"
            or (m.ended or m.finished) and "MATCH COMPLETE"
            or (p.turn == 1 and "White to move" or "Black to move")
    )
    local final = m.ended
        and (
            (m.ended.winner == 0 and "Draw" or m.ended.winner == 1 and "White wins" or "Black wins")
            .. "\n"
            .. m.ended.reason
        )
    local status = m.abandoned and "Interrupted; no winner"
        or final
        or m.recovering and "Waiting for opponent / recovery"
        or self.pending and "Waiting for host acknowledgement"
        or self.claiming and "Select an intended move for your draw claim"
        or m.offer and (m.practice and (m.offer == m.info.white and "White offers a draw" or "Black offers a draw") or m.offer == Games:PlayerName() and "Draw offered" or "Opponent offers a draw")
        or (E.InCheck(p) and "CHECK" or "Match in progress")
    self.matchStatus:SetText(self.actionNotice and (self.actionNotice .. "\n" .. status) or status)
    self.resultText:SetText(status)
    local otherOffer = m.offer and (m.practice or m.offer ~= Games:PlayerName())
    self.drawButton:SetText(otherOffer and "Accept draw" or "Offer draw")
    local input = not m.ended and not m.finished and not m.abandoned and not m.recovering and not self.pending
    self.drawButton:SetEnabled(input and (not m.offer or otherOffer))
    self.declineDraw:SetShown(otherOffer ~= nil and otherOffer ~= false)
    self.declineDraw:SetEnabled(input)
    self.practiceNew:SetShown(m.practice == true)
    self.practiceLeave:SetShown(m.practice == true)
    self.historyScroll:SetHeight(self.root:GetHeight() - (m.practice and 454 or 374))
    self.resignButton:SetEnabled(input)
    self.claimDraw:SetText(self.claiming and "Cancel draw claim" or "Claim draw")
    self.claimDraw:SetEnabled(self:CanInput() == true)
    local captured = { {}, {} }
    for _, piece in ipairs(p.captured) do
        local list = piece < 0 and captured[1] or captured[2]
        list[#list + 1] = piece
    end
    for group = 1, 2 do
        for i, icon in ipairs(self.captureIcons[group]) do
            if captured[group][i] then
                icon:SetTexture(Games.Artwork[pieceArt(captured[group][i])].file)
                place(icon, 14 + ((i - 1) % 8) * 28, (group == 1 and 206 or 278) + math.floor((i - 1) / 8) * 24, 22, 22)
                icon:Show()
            else
                icon:Hide()
            end
        end
    end
    if self.historyState ~= p then
        local lines = {}
        for i = 1, #p.san, 2 do
            local first = math.floor((i - 1) / 2) + 1
            lines[#lines + 1] = first .. ". " .. p.san[i] .. "   " .. (p.san[i + 1] or "")
        end
        self.historyText:SetText(table.concat(lines, "\n"))
        local height = math.max(self.historyScroll:GetHeight(), self.historyText:GetStringHeight() + 12)
        self.history:SetHeight(height)
        self.historyScroll:SetVerticalScroll(math.max(0, height - self.historyScroll:GetHeight()))
        self.historyState = p
    end
end
function C:RefreshAll()
    self:Render()
end
function C:ShowResult(result)
    if not self.resultWindow then
        local f = Theme:PremiumFrame(UIParent, 500, 230, 0, 0)
        f:ClearAllPoints()
        f:SetPoint("CENTER", Games.UI.frame, "CENTER")
        Theme:Window(f, true, true)
        self.finalTitle = label(f, "CHESS", 20, 22, 460, true)
        self.finalText = label(f, "", 20, 65, 460)
        self.finalText:SetHeight(90)
        self.resultMainButton = button(f, "Results", 20, 178, 190, function()
            f:Hide()
            if self.resultPractice then
                return self:StartPractice(true)
            end
            Games.UI.resultGameID = "chess"
            Games.UI:OpenLauncher("results")
            return true
        end)
        self.resultSecondaryButton = button(f, "Launcher", 230, 178, 240, function()
            f:Hide()
            if self.resultPractice then
                return self:StopPractice()
            end
            Games.UI:OpenLauncher("multiplayer")
            return true
        end)
        Games.UI:RegisterAuxiliaryWindow(f)
        self.resultWindow = f
    end
    self.resultPractice = result.practice == true
    self.resultMainButton:SetText(self.resultPractice and "New test game" or "Results")
    self.resultSecondaryButton:SetText(self.resultPractice and "Leave test" or "Launcher")
    local outcome = "Interrupted; no winner"
    for _, entry in ipairs(result.entries) do
        if entry.player == Games:PlayerName() and result.status == "completed" then
            outcome = entry.outcome == "draw" and "Draw" or entry.outcome == "win" and "You win" or "You lose"
        end
    end
    self.finalTitle:SetText(self.resultPractice and "CHESS - LOCAL TEST" or "CHESS - " .. outcome)
    self.finalText:SetText(result.summary)
    self.resultWindow:Show()
end
