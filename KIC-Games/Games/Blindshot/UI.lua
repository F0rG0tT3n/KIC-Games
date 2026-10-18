local _, Games = ...
local B, R, T = Games.Blindshot, Games.Blindshot.Rules, Games.Theme
local colors = { { 0.78, 0.3, 1 }, { 0.15, 0.8, 1 }, { 1, 0.7, 0.15 }, { 0.3, 1, 0.45 }, { 1, 0.3, 0.45 } }
local circle = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local crops = {
    { 0.17, 0.36, 0.32, 0.54 },
    { 0.38, 0.61, 0.40, 0.65 },
    { 0.43, 0.60, 0.20, 0.39 },
    { 0.67, 0.84, 0.27, 0.46 },
    { 0.35, 0.60, 0.43, 0.70 },
}
local function short(name, limit)
    name = name:match("^[^-]+") or name
    return #name > limit and name:sub(1, limit - 2) .. ".." or name
end
local function tint(index, value)
    local c = colors[index]
    return string.format(
        "|cff%02x%02x%02x%s|r",
        math.floor(c[1] * 255),
        math.floor(c[2] * 255),
        math.floor(c[3] * 255),
        value
    )
end
local function place(f, x, y, w, h)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", x, -y)
    if w then
        f:SetSize(w, h)
    end
end
local function text(parent, value, x, y, width, large)
    return T:Label(parent, value, x, -y, width, large and "GameFontNormalLarge" or "GameFontHighlight")
end
function B:Stroke(layer, pool, x1, y1, x2, y2, width, color, alpha, drawLayer)
    local dx, dy = x2 - x1, y1 - y2
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.01 then
        return
    end
    pool.used = pool.used + 1
    local t = pool[pool.used]
    if not t then
        t = layer:CreateTexture(nil, drawLayer or "ARTWORK")
        pool[pool.used] = t
    end
    t:ClearAllPoints()
    t:SetPoint("CENTER", layer, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
    t:SetSize(length, width)
    t:SetRotation(math.atan2(dy, dx))
    t:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    t:Show()
end
local function trim(pool)
    for i = pool.used + 1, #pool do
        pool[i]:Hide()
    end
end
function B:Project(x, y)
    return self.cx + x / 1000 * self.unit, self.cy - y / 1000 * self.unit
end
function B:Cursor()
    local x, y = GetCursorPosition()
    local scale = self.arena:GetEffectiveScale()
    local px, py = x / scale - self.arena:GetLeft(), self.arena:GetTop() - y / scale
    return math.floor((px - self.cx) / self.unit * 1000 + 0.5), math.floor((self.cy - py) / self.unit * 1000 + 0.5)
end
function B:UpdateArenaTicker()
    if self.arena then
        local active = self.zoomMotion or self.mouseButtons and next(self.mouseButtons)
        self.arena:SetScript("OnUpdate", active and self.arenaUpdater or nil)
    end
end
function B:CancelMouseInput()
    self.mouseButtons, self.mouseRound = nil, nil
    self:UpdateArenaTicker()
end
function B:ApplyCursorInput()
    if
        not self:CanInput()
        or not self.mouseButtons
        or not next(self.mouseButtons)
        or self.mouseRound ~= self.view.round
    then
        self:CancelMouseInput()
        return false
    end
    local x, y = self:Cursor()
    local changed = false
    if self.mouseButtons.LeftButton then
        local px, py = R.ClampPosition(x, y, self.view.radius)
        if px and (px ~= self.draft.x or py ~= self.draft.y) then
            self.draft.x, self.draft.y, changed = px, py, true
        end
    end
    if self.mouseButtons.RightButton then
        local dx, dy = R.Direction(x - self.draft.x, y - self.draft.y)
        if dx and (dx ~= self.draft.dx or dy ~= self.draft.dy) then
            self.draft.dx, self.draft.dy, changed = dx, dy, true
        end
    end
    if changed then
        self.dirty, self.notice = true, nil
    end
    return changed
end
function B:MouseDown(button)
    if (button ~= "LeftButton" and button ~= "RightButton") or not self:CanInput() then
        return
    end
    self.mouseButtons = self.mouseButtons or {}
    self.mouseButtons[button], self.mouseRound = true, self.view.round
    self:ApplyCursorInput()
    self:UpdateArenaTicker()
    self:Render()
end
function B:MouseUp(button)
    if not self.mouseButtons or not self.mouseButtons[button] then
        return
    end
    self:ApplyCursorInput()
    if self.mouseButtons then
        self.mouseButtons[button] = nil
    end
    if self.mouseButtons and not next(self.mouseButtons) then
        self.mouseButtons, self.mouseRound = nil, nil
    end
    self:UpdateArenaTicker()
    self:Save()
    self:Render()
end
function B:UpdateZoom(radius)
    local target = self.baseUnit * 1000 / radius
    if self.zoomRadius ~= radius then
        self.zoomRadius = radius
        if not self.unit or not self.root:IsVisible() then
            self.unit, self.zoomMotion = target, nil
        elseif math.abs(self.unit - target) > 0.001 then
            self.zoomMotion = { start = GetTime(), from = self.unit, target = target }
        end
        self:UpdateArenaTicker()
    end
end
function B:AdvanceArena()
    local changed = false
    if self.zoomMotion then
        local motion = self.zoomMotion
        local t = math.max(0, math.min(1, (GetTime() - motion.start) / 0.45))
        local ease = t * t * (3 - 2 * t)
        self.unit, changed = motion.from + (motion.target - motion.from) * ease, true
        if t >= 1 then
            self.zoomMotion = nil
        end
    end
    if self.mouseButtons then
        for button in pairs(self.mouseButtons) do
            if not IsMouseButtonDown(button) then
                self.mouseButtons[button] = nil
            end
        end
        changed = self:ApplyCursorInput() or changed
    end
    if changed then
        self:Render()
    end
    self:UpdateArenaTicker()
end
function B:DisplayNames(players)
    local counts, names = {}, {}
    for _, p in ipairs(players) do
        local name = p.name:match("^[^-]+") or p.name
        counts[name:lower()] = (counts[name:lower()] or 0) + 1
    end
    for i, p in ipairs(players) do
        local name = p.name:match("^[^-]+") or p.name
        names[i] = counts[name:lower()] == 1 and name or p.name
    end
    return names
end
function B:WrapOrderName(value, width)
    local lines, line = {}, ""
    -- Iterate complete UTF-8 glyphs; long realm identities must remain readable.
    for glyph in value:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        self.nameMeasure:SetText(line .. glyph)
        if line ~= "" and self.nameMeasure:GetStringWidth() > width then
            lines[#lines + 1], line = line, glyph
        else
            line = line .. glyph
        end
    end
    lines[#lines + 1] = line
    return table.concat(lines, "\n"), #lines * 16
end
function B:LayoutFiringOrder(v, names)
    local order = v.order or {}
    self.orderScroll:SetShown(#order > 0)
    if #order == 0 then
        return
    end
    local width = self.arena:GetWidth() - 42
    local values, longest = {}, 0
    for rank, index in ipairs(order) do
        values[rank] = "#" .. rank .. " " .. names[index]
        self.nameMeasure:SetText(values[rank])
        longest = math.max(longest, self.nameMeasure:GetStringWidth())
    end
    local key = width .. ":" .. table.concat(values, "|")
    if key ~= self.orderKey then
        self.orderKey = key
        local columns = math.max(1, math.min(#order, math.floor((width + 12) / (longest + 28))))
        local cellWidth = (width - (columns - 1) * 12) / columns
        local y = 0
        for first = 1, #order, columns do
            local height = 0
            for rank = first, math.min(#order, first + columns - 1) do
                local label = self.orderLabels[rank]
                local wrapped, h = self:WrapOrderName(values[rank], cellWidth - 8)
                place(label, ((rank - 1) % columns) * (cellWidth + 12) + 4, y, cellWidth - 8, h)
                label:SetText(wrapped)
                height = math.max(height, h)
            end
            for rank = first, math.min(#order, first + columns - 1) do
                place(self.orderGlows[rank], ((rank - 1) % columns) * (cellWidth + 12), y, cellWidth, height)
            end
            y = y + height + 4
        end
        self.orderList:SetHeight(math.max(1, y))
    end
    for rank, label in ipairs(self.orderLabels) do
        local index = order[rank]
        label:SetShown(index ~= nil)
        self.orderGlows[rank]:SetShown(index ~= nil and index == v.current)
        if index then
            label:SetTextColor(unpack(colors[index]))
            label:SetAlpha(index == v.current and 1 or 0.85)
        end
    end
end
function B:CreateUI(parent)
    if self.root then
        self:LayoutUI()
        return self.root
    end
    self.root = CreateFrame("Frame", nil, parent)
    self.root:SetAllPoints(parent)
    self.root:SetScript("OnHide", function()
        if self.zoomMotion then
            self.unit = self.zoomMotion.target
        end
        self.zoomMotion = nil
        self:CancelMouseInput()
    end)
    self.left = T:PremiumFrame(self.root, 218, 560, 0, 0)
    self.hero = T:Art(self.left, "blindshot-hero", 190, 95, 14, -14, 1, "ARTWORK")
    text(self.left, "KIC BLINDSHOT", 16, 122, 190, true)
    text(self.left, "HIDE / AIM / FIRE", 16, 155, 190):SetTextColor(unpack(T.Colors.accent))
    self.rulesText = text(
        self.left,
        "1  LEFT CLICK / HOLD - Move\n2  RIGHT CLICK / HOLD - Aim\n3  LOCK IN - Confirm\n\nAdjust until locked.\nOnly locked choices are sent.\nOverlaps settle at reveal.\nOne target per shot.\nLast survivor wins.",
        16,
        196,
        188
    )
    self.rulesText:SetHeight(150)
    self.rulesText:SetFont(T.Fonts.body, 12, "")
    self.phaseHint = text(self.left, "", 16, 367, 188)
    self.phaseHint:SetHeight(72)
    self.lockButton = T:NeonButton(self.left, "Lock In", 188, 16, -452, function()
        self:SendDraft(true)
    end, 34, true)
    self.backButton = T:NeonButton(self.left, "Back to Launcher", 188, 16, -496, function()
        if self.practice then
            self:StartPractice(true)
            return
        end
        Games.UI:OpenLauncher("multiplayer")
    end, 30)
    self.leaveButton = T:NeonButton(self.left, "Leave Match", 188, 16, -534, function()
        if self.practice then
            self:StopPractice()
            return
        end
        Games:LeaveLobby()
        Games.UI:OpenLauncher("multiplayer")
    end, 30)
    self.arena = CreateFrame("Button", nil, self.root, "BackdropTemplate")
    self.arena:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    self.arena:SetBackdropColor(0.006, 0.015, 0.04, 0.9)
    self.arena:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    self.arena:SetScript("OnMouseDown", function(_, button)
        self:MouseDown(button)
    end)
    self.arena:SetScript("OnMouseUp", function(_, button)
        self:MouseUp(button)
    end)
    self.arenaUpdater = function()
        self:AdvanceArena()
    end
    self.platform = CreateFrame("Frame", nil, self.arena)
    self.platform:SetAllPoints(self.arena)
    self.platform:SetFrameLevel(self.arena:GetFrameLevel() + 1)
    self.lines = CreateFrame("Frame", nil, self.arena)
    self.lines:SetAllPoints(self.arena)
    self.lines:SetFrameLevel(self.arena:GetFrameLevel() + 3)
    self.platformPool, self.beams, self.markers = { used = 0 }, { used = 0 }, {}
    self.floorShadow = self.platform:CreateTexture(nil, "BACKGROUND", nil, -1)
    self.floorShadow:SetTexture(circle)
    self.floorShadow:SetVertexColor(0, 0, 0, 0.65)
    self.floor = self.platform:CreateTexture(nil, "BACKGROUND")
    self.floor:SetTexture(circle)
    self.floor:SetVertexColor(0.075, 0.095, 0.13, 1)
    for i = 1, 5 do
        local marker = CreateFrame("Frame", nil, self.arena)
        marker:SetSize(96, 100)
        marker:EnableMouse(false)
        marker:SetFrameLevel(self.arena:GetFrameLevel() + 5)
        marker.shadow = marker:CreateTexture(nil, "BACKGROUND")
        marker.shadow:SetTexture(circle)
        place(marker.shadow, 29, 29, 38, 38)
        marker.shadow:SetVertexColor(0, 0, 0, 0.75)
        marker.ground = marker:CreateTexture(nil, "BORDER")
        marker.ground:SetTexture(circle)
        place(marker.ground, 27, 27, 42, 42)
        marker.body = marker:CreateTexture(nil, "ARTWORK", nil, -2)
        marker.body:SetTexture(circle)
        place(marker.body, 26, 29, 44, 44)
        marker.localRing = marker:CreateTexture(nil, "ARTWORK", nil, -3)
        marker.localRing:SetTexture(circle)
        marker.localRing:SetVertexColor(1, 1, 1, 0.8)
        place(marker.localRing, 24, 27, 48, 48)
        marker.portrait = marker:CreateTexture(nil, "ARTWORK", nil, -1)
        place(marker.portrait, 30, 33, 36, 36)
        marker.mask = marker:CreateMaskTexture()
        marker.mask:SetTexture(circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        marker.mask:SetAllPoints(marker.portrait)
        marker.portrait:AddMaskTexture(marker.mask)
        marker.badge = CreateFrame("Frame", nil, marker)
        marker.badge:SetFrameLevel(marker:GetFrameLevel() + 2)
        place(marker.badge, 62, 18, 30, 30)
        marker.badgeBack = marker.badge:CreateTexture(nil, "BACKGROUND")
        marker.badgeBack:SetAllPoints(marker.badge)
        marker.badgeBack:SetTexture(circle)
        marker.badgeBack:SetVertexColor(0.008, 0.015, 0.03, 0.95)
        marker.order = text(marker.badge, "", 0, 0, 30, true)
        marker.order:SetFont(T.Fonts.body, 24, "OUTLINE")
        marker.order:SetJustifyH("CENTER")
        marker.tag = text(marker, "P" .. i, 0, 81, 96)
        marker.tag:SetFont(T.Fonts.body, 10, "OUTLINE")
        marker.tag:SetJustifyH("CENTER")
        marker.death = text(marker, "X", 0, 39, 96, true)
        marker.death:SetFont(T.Fonts.body, 28, "OUTLINE")
        marker.death:SetJustifyH("CENTER")
        marker.death:SetTextColor(1, 0.18, 0.18)
        marker.impact = marker:CreateTexture(nil, "OVERLAY")
        marker.impact:SetTexture(circle)
        marker.impact:SetVertexColor(1, 0.85, 0.5, 0.85)
        place(marker.impact, 19, 22, 58, 58)
        self.markers[i] = marker
    end
    self.roundBanner = text(self.arena, "", 12, 16, 400, true)
    self.roundBanner:SetJustifyH("CENTER")
    self.clock = text(self.arena, "", 12, 52, 400, true)
    self.clock:SetJustifyH("CENTER")
    self.hiddenText = text(self.arena, "", 12, 90, 400)
    self.hiddenText:SetJustifyH("CENTER")
    self.hiddenText:SetHeight(32)
    self.hiddenText:SetMaxLines(2)
    self.orderList, self.orderScroll = T:Scroll(self.arena, 400, 64, 12, -100)
    self.orderScroll:SetFrameLevel(self.arena:GetFrameLevel() + 8)
    self.nameMeasure = text(self.arena, "", 0, 0, 10000)
    self.nameMeasure:SetFont(T.Fonts.body, 12, "")
    self.nameMeasure:Hide()
    self.orderLabels, self.orderGlows = {}, {}
    for i = 1, 5 do
        self.orderGlows[i] = T:Highlight(self.orderList, 0, 0, 1, 1, colors[i], 0.2)
        self.orderLabels[i] = text(self.orderList, "", 4, 0, 200)
        self.orderLabels[i]:SetFont(T.Fonts.body, 12, "")
    end
    self.shrinkText = text(self.arena, "", 12, 520, 400)
    self.shrinkText:SetJustifyH("CENTER")
    self.right = T:PremiumFrame(self.root, 244, 560, 0, 0)
    self.aliveText = text(self.right, "", 16, 20, 212, true)
    self.ownState = text(self.right, "", 16, 65, 212)
    self.ownState:SetHeight(45)
    self.participants, self.participantsFrame = T:Scroll(self.right, 212, 180, 16, -132)
    self.participantText = text(self.participants, "", 0, 0, 194)
    self.participantText:SetFont(T.Fonts.body, 12, "")
    self.participantText:SetSpacing(3)
    text(self.right, "COMBAT LOG", 16, 332, 212, true)
    self.eventScroll, self.eventFrame = T:Scroll(self.right, 212, 170, 16, -370)
    self.eventText = text(self.eventScroll, "", 0, 0, 194)
    self.eventText:SetSpacing(4)
    self:LayoutUI()
    return self.root
end
function B:LayoutUI()
    if not self.root then
        return
    end
    self:CancelMouseInput()
    local parent = self.root:GetParent()
    local w, h = parent:GetWidth(), parent:GetHeight()
    self.root:SetSize(w, h)
    local left, right, gap = 218, 244, 14
    place(self.left, 0, 0, left, h)
    place(self.right, w - right, 0, right, h)
    place(self.arena, left + gap, 0, w - left - right - 2 * gap, h)
    local width = self.arena:GetWidth()
    self.arenaTop = 176
    self.baseUnit = math.min((width - 48) / 2, (h - 52 - self.arenaTop) / 2)
    self.cx, self.cy = width / 2, (self.arenaTop + h - 52) / 2
    self.zoomMotion, self.zoomRadius = nil, self.view and self.view.radius or 1000
    self.unit = self.baseUnit * 1000 / self.zoomRadius
    self:UpdateArenaTicker()
    self.roundBanner:SetWidth(width - 24)
    self.clock:SetWidth(width - 24)
    place(self.clock, 12, 46)
    self.orderScroll:SetSize(width - 24, 64)
    self.orderList:SetWidth(width - 42)
    self.hiddenText:SetWidth(width - 24)
    place(self.hiddenText, 12, 82)
    self.shrinkText:SetWidth(width - 24)
    place(self.shrinkText, 12, h - 34)
    place(self.lockButton, 16, h - 134, 188, 34)
    place(self.backButton, 16, h - 90, 188, 30)
    place(self.leaveButton, 16, h - 52, 188, 30)
    place(self.phaseHint, 16, h - 215)
    self.eventFrame:SetSize(right - 32, h - 386)
    self:Render()
end
function B:DrawPlatform(radius)
    -- True top-down native stone disc. Its cyan boundary is the simulation
    -- radius; ornamental glow/shadow never changes collision coordinates.
    local pr = radius / 1000 * self.unit
    place(self.floor, self.cx - pr, self.cy - pr, 2 * pr, 2 * pr)
    place(self.floorShadow, self.cx - pr - 7, self.cy - pr - 7, 2 * pr + 14, 2 * pr + 14)
    self.platformPool.used = 0
    local function line(x1, y1, x2, y2, w, c, alpha, layer)
        self:Stroke(self.platform, self.platformPool, x1, y1, x2, y2, w, c, alpha, layer)
    end
    local function arc(factor, start, finish, width, color, alpha)
        local steps = math.max(1, math.ceil((finish - start) * 32 / math.pi))
        for i = 1, steps do
            local a, b = start + (finish - start) * (i - 1) / steps, start + (finish - start) * i / steps
            local x1, y1 = self:Project(math.cos(a) * radius * factor, math.sin(a) * radius * factor)
            local x2, y2 = self:Project(math.cos(b) * radius * factor, math.sin(b) * radius * factor)
            line(x1, y1, x2, y2, width, color, alpha)
        end
    end
    -- Staggered masonry courses, with bevel highlights and short chipped veins.
    for course = 1, 5 do
        local f = course * 0.18
        arc(f, 0, 2 * math.pi, 3, { 0.018, 0.026, 0.04 }, 0.95)
        arc(f - 0.008, 0, 2 * math.pi, 1, { 0.22, 0.28, 0.33 }, 0.45)
        for tile = 1, 12 do
            local a = tile * math.pi / 6 + (course % 2) * math.pi / 12
            local x1, y1 = self:Project(math.cos(a) * radius * (f - 0.18), math.sin(a) * radius * (f - 0.18))
            local x2, y2 = self:Project(math.cos(a) * radius * f, math.sin(a) * radius * f)
            line(x1, y1, x2, y2, 2, { 0.013, 0.023, 0.035 }, 0.9)
            line(x1 + 2, y1, x2 + 2, y2, 1, { 0.19, 0.24, 0.29 }, 0.35)
            local x, y =
                self:Project(math.cos(a + 0.08) * radius * (f - 0.06), math.sin(a + 0.08) * radius * (f - 0.06))
            line(x, y, x + 5, y - 2, 1, { 0.34, 0.40, 0.44 }, 0.25)
        end
    end
    -- Etched central seal and softly glowing concentric inscriptions.
    for _, f in ipairs({ 0.13, 0.17, 0.73, 0.78, 0.96 }) do
        arc(f, 0, 2 * math.pi, f > 0.9 and 2 or 1, { 0.08, 0.66, 0.85 }, f > 0.9 and 0.7 or 0.26)
    end
    for i = 1, 8 do
        local a, b = i * math.pi / 4, (i + 3) * math.pi / 4
        local x1, y1 = self:Project(math.cos(a) * radius * 0.13, math.sin(a) * radius * 0.13)
        local x2, y2 = self:Project(math.cos(b) * radius * 0.13, math.sin(b) * radius * 0.13)
        line(x1, y1, x2, y2, 1, { 0.16, 0.65, 0.83 }, 0.5)
    end
    arc(1, 0, 2 * math.pi, 15, { 0.02, 0.42, 0.8 }, 0.07)
    arc(1, 0, 2 * math.pi, 8, { 0.02, 0.6, 1 }, 0.18)
    arc(1, 0, 2 * math.pi, 3, { 0.2, 0.85, 1 }, 0.95)
    arc(0.993, 0, 2 * math.pi, 1, { 0.7, 0.98, 1 }, 0.9)
    for i = 1, 16 do
        local a = i * math.pi / 8
        local x1, y1 = self:Project(math.cos(a) * radius * 0.81, math.sin(a) * radius * 0.81)
        local x2, y2 = self:Project(math.cos(a) * radius * 0.89, math.sin(a) * radius * 0.89)
        line(x1, y1, x2, y2, 3, { 0.18, 0.73, 0.94 }, 0.55)
        line(x2 - 3, y2 - 2, x2 + 3, y2 + 2, 1, { 0.65, 0.9, 1 }, 0.8)
    end
    trim(self.platformPool)
end
function B:UpdateClock()
    if not self.root or not self.view then
        return
    end
    local phase = R.PlaybackPhase(self.view, self:Now())
    self.clock:SetText(
        self.waiting and "Waiting for host..."
            or phase == "FIRING" and "SEQUENTIAL FIRE"
            or phase == "REVEAL" and "FIND YOUR NUMBER"
            or phase == "ROUND_END" and "ROUND COMPLETE"
            or phase == "MATCH_END" and "MATCH COMPLETE"
            or phase == "PREPARE" and "SYNCHRONIZING ARENA"
            or math.max(0, math.ceil(self.view.deadline - self:Now())) .. "s"
    )
end
function B:PaintPortrait(marker, name, index)
    if marker.portraitName == name then
        return
    end
    marker.portraitName = name
    marker.portrait:SetTexture(Games.Artwork["blindshot-card"].file)
    marker.portrait:SetTexCoord(unpack(crops[index]))
    if SetPortraitTexture then
        local unit = name == Games:PlayerName() and "player" or nil
        if not unit and not self.practice then
            for n = 1, 4 do
                local first, realm = UnitFullName("party" .. n)
                if first and Games:NormalizeName(first .. (realm and realm ~= "" and "-" .. realm or "")) == name then
                    unit = "party" .. n
                    break
                end
            end
        end
        if unit then
            marker.portrait:SetTexCoord(0, 1, 0, 1)
            SetPortraitTexture(marker.portrait, unit)
        end
    end
end
function B:Render()
    if not self.root then
        return
    end
    local source = self.view
    if not source then
        self.phaseHint:SetText("Waiting for the host to synchronize the match.")
        self.lockButton:Disable()
        for _, marker in ipairs(self.markers) do
            marker:Hide()
        end
        return
    end
    self:EnsureDraft()
    if self.mouseButtons and (not self:CanInput() or self.mouseRound ~= source.round) then
        self:CancelMouseInput()
    end
    self:UpdateZoom(source.radius)
    local v = R.Presentation(source, self:Now())
    -- Static scenery is regenerated only for a layout or platform change.
    local key = v.radius .. ":" .. self.unit .. ":" .. self.cx .. ":" .. self.cy
    if self.platformKey ~= key then
        self:DrawPlatform(v.radius)
        self.platformKey = key
    end
    self.roundBanner:SetText(
        (self.practice and "TEST / " or "")
            .. "ROUND "
            .. v.round
            .. "  /  "
            .. (
                v.phase == "AIM" and "PLAN"
                or v.phase == "FIRING" and "FIRE"
                or v.phase == "ROUND_END" and "RESOLVE"
                or v.phase:gsub("_", " ")
            )
    )
    self.backButton:SetText(self.practice and "New test game" or "Back to Launcher")
    self.leaveButton:SetText(self.practice and "Leave test" or "Leave Match")
    self.rulesText:SetText(
        "1  LEFT CLICK / HOLD - Move\n2  RIGHT CLICK / HOLD - Aim\n3  LOCK IN - Confirm\n\nAdjust until locked.\nOnly locked choices are sent.\nOverlaps settle at reveal.\nOne target per shot.\nLast survivor wins."
            .. (self.practice and "\nTest players lock automatically." or "")
    )
    local names, positions = self:DisplayNames(v.players), {}
    for rank, index in ipairs(v.order or {}) do
        positions[index] = rank
    end
    self:LayoutFiringOrder(v, names)
    self.hiddenText:SetText(
        v.phase == "AIM" and "SECRET PLAN / LEFT: MOVE / RIGHT: AIM" or v.order and "FIRING ORDER" or "THE ARENA AWAITS"
    )
    self.shrinkText:SetText(
        "ARENA "
            .. math.floor(v.radius / 10)
            .. "%  /  "
            .. (v.phase == "AIM" and "LEFT: MOVE / RIGHT: AIM" or "POSITIONS AND DIRECTIONS LOCKED")
    )
    self.aliveText:SetText("SURVIVORS  " .. R.Alive(v) .. " / " .. #v.players)
    local own = R.Player(v, Games:PlayerName())
    self.ownState:SetText(
        v.phase == "MATCH_END" and (v.winner and "|cff7fffb0WINNER: " .. short(v.winner, 20) .. "|r" or "Match drawn")
            or not own.alive and "|cffff6677Eliminated / spectating|r"
            or v.phase == "AIM" and ((own.locked or self.lockConfirmed == v.round) and "Locked in / hidden" or "YOUR TURN TO AIM")
            or v.phase == "PREPARE" and "Prepare for the next round"
            or v.phase == "REVEAL" and "All choices revealed / order set"
            or v.current and tint(v.current, names[v.current] .. " IS FIRING")
            or "Round complete"
    )
    local names = {}
    for i, p in ipairs(v.players) do
        local state = not p.alive and "|cffff6677ELIMINATED|r"
            or v.current == i and "|cffffffaaFIRING NOW|r"
            or v.phase == "AIM" and (p.locked and "LOCKED" or "CHOOSING")
            or v.phase == "PREPARE" and "PREPARING"
            or "ALIVE"
        names[#names + 1] = tint(i, "P" .. i)
            .. "  "
            .. short(p.name, 18)
            .. (p.name == own.name and " (YOU)" or "")
            .. "\n"
            .. state
            .. (positions[i] and "  /  #" .. positions[i] or "")
    end
    self.participantText:SetText(table.concat(names, "\n"))
    self.participants:SetHeight(
        math.max(self.participantsFrame:GetHeight(), self.participantText:GetStringHeight() + 12)
    )
    local log = {}
    for _, line in ipairs(v.events) do
        log[#log + 1] = line:find("ELIMINATED", 1, true) and "|cffffbb66" .. line .. "|r" or line
    end
    if v.winner then
        log[#log + 1] = "|cff7fffb0" .. short(v.winner, 18) .. " WINS|r"
    end
    self.eventText:SetText(#log > 0 and table.concat(log, "\n") or "Awaiting the first shot.")
    self.eventScroll:SetHeight(math.max(self.eventFrame:GetHeight(), self.eventText:GetStringHeight() + 12))
    self.beams.used = 0
    for _, marker in ipairs(self.markers) do
        marker:Hide()
    end
    local shots = v.shots or {}
    if v.phase == "AIM" and own.alive then
        local aim = self.draft
        shots = { { name = own.name, x = self.draft.x, y = self.draft.y, dx = aim.dx, dy = aim.dy } }
    end
    local labels = {}
    for _, shot in ipairs(shots) do
        local player, index = R.Player(v, shot.name)
        local c, marker = colors[index], self.markers[index]
        local x, y = self:Project(shot.x, shot.y)
        local diameter = 2 * R.HIT * self.unit / 1000
        local radius = diameter / 2
        -- The portrait's colored body is the physical hit circle, centered on
        -- Project(shot.x, shot.y). Halos and labels are decorative only.
        place(marker, x - 48, y - 48)
        place(marker.body, 48 - radius, 48 - radius, diameter, diameter)
        place(marker.portrait, 50 - radius, 50 - radius, diameter - 4, diameter - 4)
        place(marker.shadow, 45 - radius, 45 - radius, diameter + 6, diameter + 6)
        place(marker.ground, 43 - radius, 43 - radius, diameter + 10, diameter + 10)
        place(marker.localRing, 46 - radius, 46 - radius, diameter + 4, diameter + 4)
        place(marker.impact, 40 - radius, 40 - radius, diameter + 16, diameter + 16)
        place(marker.badge, 36, 20 - radius, 24, 24)
        marker.order:SetWidth(24)
        marker.order:SetFont(T.Fonts.body, 18, "OUTLINE")
        place(marker.death, 0, 34, 96, 30)
        self:PaintPortrait(marker, shot.name, index)
        marker.body:SetVertexColor(c[1], c[2], c[3], 1)
        marker.ground:SetVertexColor(c[1], c[2], c[3], v.current == index and 0.8 or 0.35)
        marker:SetAlpha(player.alive and 1 or 0.4)
        marker.death:SetShown(not player.alive)
        marker.order:SetText(positions[index] and tostring(positions[index]) or "")
        marker.badge:SetShown(positions[index] ~= nil)
        marker.localRing:SetShown(shot.name == own.name)
        marker.order:SetTextColor(unpack(c))
        marker.tag:SetText(
            tint(index, "P" .. index .. " " .. short(shot.name, shot.name == own.name and 7 or 11))
                .. (shot.name == own.name and " (YOU)" or "")
        )
        -- Keep names in bounds and stagger nearby labels without moving hitboxes.
        local lx, ly = x - 48, y - radius - 46
        for _, candidate in ipairs({
            { x - 48, y - radius - 46 },
            { x - 112, y - 20 },
            { x + 16, y - 20 },
            { x - 48, y + radius + 10 },
            { x - 112, y + 10 },
            { x + 16, y + 10 },
        }) do
            lx = math.max(2, math.min(self.arena:GetWidth() - 98, candidate[1]))
            ly = math.max(self.arenaTop, math.min(self.arena:GetHeight() - 46, candidate[2]))
            local overlaps = false
            for _, other in ipairs(shots) do
                if other.name ~= shot.name then
                    local ox, oy = self:Project(other.x, other.y)
                    if
                        lx < ox + radius + 3
                        and lx + 96 > ox - radius - 3
                        and ly < oy + radius + 3
                        and ly + 13 > oy - radius - 28
                    then
                        overlaps = true
                    end
                end
            end
            for _, label in ipairs(labels) do
                if math.abs(label.x - lx) < 96 and math.abs(label.y - ly) < 14 then
                    overlaps = true
                end
            end
            if not overlaps then
                break
            end
        end
        labels[#labels + 1] = { x = lx, y = ly }
        place(marker.tag, lx - (x - 48), ly - (y - 48))
        local impact = v.impacts and v.impacts[index]
        marker.impact:SetShown(impact ~= nil)
        if impact then
            marker.impact:SetAlpha(impact)
        end
        if v.current == index then
            local pulse = 1 + 0.09 * math.sin((v.shotAge or 0) * 12)
            local halo = (diameter + 16) * pulse
            place(marker.ground, 48 - halo / 2, 48 - halo / 2, halo, halo)
        end
        marker:Show()
        local ex, ey = R.RayEnd(shot, v.radius)
        if v.phase == "FIRING" and v.current == index then
            ex, ey = R.FiringEnd(v, shot)
        end
        ex, ey = self:Project(ex, ey)
        local firing = v.current == index
        if player.alive or firing then
            if v.phase == "AIM" or v.phase == "REVEAL" then
                self:Stroke(self.lines, self.beams, x, y, ex, ey, v.phase == "AIM" and 7 or 3, c, 0.17)
                self:Stroke(self.lines, self.beams, x, y, ex, ey, v.phase == "AIM" and 2 or 1, c, 0.8)
                do
                    local dx, dy = ex - x, ey - y
                    local length = math.sqrt(dx * dx + dy * dy)
                    if length > 1 then
                        dx, dy = dx / length, dy / length
                        local ax, ay = ex, ey
                        if v.phase == "REVEAL" then
                            ax, ay = x + dx * math.min(length, 32), y + dy * math.min(length, 32)
                        end
                        self:Stroke(
                            self.lines,
                            self.beams,
                            ax,
                            ay,
                            ax - dx * 12 - dy * 6,
                            ay - dy * 12 + dx * 6,
                            3,
                            c,
                            1
                        )
                        self:Stroke(
                            self.lines,
                            self.beams,
                            ax,
                            ay,
                            ax - dx * 12 + dy * 6,
                            ay - dy * 12 - dx * 6,
                            3,
                            c,
                            1
                        )
                    end
                end
            elseif firing then
                local t = math.min(1, (v.shotAge or 0) / R.IMPACT_TIME)
                local fx, fy = x + (ex - x) * t, y + (ey - y) * t
                local alpha = math.max(0.05, 1 - (v.shotAge or 0) / R.SHOT_TIME)
                self:Stroke(self.lines, self.beams, x, y, fx, fy, 12, c, 0.24 * alpha)
                self:Stroke(self.lines, self.beams, x, y, fx, fy, 4, c, alpha)
                self:Stroke(self.lines, self.beams, x, y, fx, fy, 1, { 1, 1, 1 }, alpha)
            end
        end
    end
    trim(self.beams)
    local hint = v.phase == "PREPARE" and "PREPARE\nWaiting for surviving players' boards. Planning starts together."
        or v.phase == "AIM" and "SECRET PLAN\nLeft click / hold to move.\nRight click / hold to aim.\nLock In when ready."
        or v.phase == "REVEAL" and "REVEAL\nFind your number.\nYour position and direction are fixed."
        or v.phase == "FIRING" and "FIRING\nWatch the highlighted shooter.\nEliminated players lose their turn."
        or v.phase == "ROUND_END" and "ROUND COMPLETE\nSurvivors enter a smaller arena."
        or (v.winner and short(v.winner, 20) .. " wins!" or "Match drawn.")
    if v.phase == "REVEAL" then
        for _, shot in ipairs(v.shots or {}) do
            if shot.name == own.name and shot.shifted then
                hint = "REVEAL\nPosition adjusted for minimum spacing. Your aim is unchanged."
            end
        end
    end
    self.phaseHint:SetText(
        self.notice or (not own.alive and v.phase == "AIM" and "SPECTATING\nWatch the next reveal." or hint)
    )
    self.lockButton:SetText(
        (own.locked or self.lockConfirmed == v.round) and "Locked In" or self.pending and "Confirming..." or "Lock In"
    )
    self.lockButton:SetEnabled(self:CanInput() == true)
    self:UpdateClock()
end
function B:ShowResult(result)
    if not self.resultWindow then
        local f = T:PremiumFrame(UIParent, 490, 240, 0, 0)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER")
        T:Window(f, true, true)
        text(f, "KIC BLINDSHOT", 20, 22, 450, true)
        self.resultText = text(f, "", 20, 67, 450)
        self.resultText:SetHeight(94)
        self.resultMainButton = T:NeonButton(f, "Lobby / rematch", 214, 20, -184, function()
            f:Hide()
            if self.resultPractice then
                self:StartPractice(true)
                return
            end
            Games.UI:OpenLauncher("multiplayer")
        end, 32, true)
        self.resultSecondaryButton = T:NeonButton(f, "Results", 214, 252, -184, function()
            f:Hide()
            if self.resultPractice then
                self:StopPractice()
                return
            end
            Games.UI.resultGameID = "blindshot"
            Games.UI:OpenLauncher("results")
        end, 32)
        Games.UI:RegisterAuxiliaryWindow(f)
        self.resultWindow = f
    end
    self.resultPractice = result.practice == true
    self.resultMainButton:SetText(self.resultPractice and "New test game" or "Lobby / rematch")
    self.resultSecondaryButton:SetText(self.resultPractice and "Exit test" or "Results")
    local own
    for _, entry in ipairs(result.entries) do
        if entry.player == Games:PlayerName() then
            own = entry
        end
    end
    self.resultText:SetText(
        result.status == "aborted" and "Match interrupted. No winner awarded."
            or result.summary
                .. "\n"
                .. (
                    own
                        and own.stats
                        and ("Rounds: " .. own.stats.rounds .. " / Eliminations: " .. own.stats.eliminations)
                    or ""
                )
    )
    self.resultWindow:Show()
end
