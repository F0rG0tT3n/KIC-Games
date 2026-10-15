local _, Games = ...
local Theme = {}
Games.Theme = Theme
Theme.Spacing = { tiny = 4, small = 8, gutter = 16, section = 24 }
Theme.Type = { title = 28, heading = 22, body = 14, small = 12, button = 13 }
Theme.Fonts = { body = "Fonts\\ARIALN.TTF", display = "Fonts\\ARIALN.TTF" }
Theme.Colors = {
    background = { 0.012, 0.023, 0.052, 1 },
    card = { 0.023, 0.043, 0.085, 1 },
    border = { 0.11, 0.23, 0.36, 1 },
    text = { 0.91, 0.95, 1, 1 },
    muted = { 0.55, 0.68, 0.83, 1 },
    accent = { 0.08, 0.84, 1, 1 },
    violet = { 0.62, 0.24, 1, 1 },
    selected = { 0.025, 0.17, 0.31, 1 },
    primary = { 0.025, 0.24, 0.46, 1 },
    success = { 0.1, 0.9, 0.55, 1 },
    ice = { 0.64, 0.91, 1, 1 },
}
Theme.Components = { inset = 5, corner = 14, borderAlpha = 0.7, glowAlpha = 0.1 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
function Theme:Art(parent, key, width, height, x, y, alpha, layer, subLevel)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0)
    texture:SetSize(width, height)
    texture:SetPoint("TOPLEFT", x, y)
    self:SetArt(texture, key, width, height, alpha)
    return texture
end
function Theme:SetArt(texture, key, width, height, alpha)
    local asset = Games.Artwork[key]
    local loaded = asset and asset.file and texture:SetTexture(asset.file) ~= false
    if not loaded then
        texture:SetColorTexture(0.025, 0.1, 0.18, 1)
    end
    -- A pooled texture must not retain a disabled tint, additive blend or hidden
    -- state from its previous use. State-specific tint is applied by its owner.
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetBlendMode("BLEND")
    texture:Show()
    texture.artKey, texture.artLoaded = key, loaded == true
    texture:SetAlpha(alpha or 1)
    local ratio = asset and asset.width / asset.height or width / height
    local target = width / height
    if target > ratio then
        local v = (1 - ratio / target) / 2
        texture:SetTexCoord(0, 1, v, 1 - v)
    else
        local u = (1 - target / ratio) / 2
        texture:SetTexCoord(u, 1 - u, 0, 1)
    end
    return loaded
end
function Theme:NeonBorder(frame, key)
    local art = frame:CreateTexture(nil, "BORDER")
    art:SetAllPoints(frame)
    local asset = Games.Artwork[key]
    if asset and asset.file and art:SetTexture(asset.file) ~= false then
        return { art }
    end
    art:Hide()
    local edges = {}
    -- Static corner accents: replaceable by the optional frame texture above.
    for _, side in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local c = key ~= "button-frame" and side:find("RIGHT") and self.Colors.violet or self.Colors.accent
        local horizontal = frame:CreateTexture(nil, "BORDER")
        horizontal:SetColorTexture(unpack(c))
        horizontal:SetSize(22, 2)
        horizontal:SetPoint(side, side:find("LEFT") and 1 or -1, side:find("TOP") and -1 or 1)
        edges[#edges + 1] = horizontal
    end
    return edges
end
function Theme:Label(parent, value, x, y, width, template)
    local font = parent:CreateFontString(nil, "OVERLAY")
    local small = template and template:find("Small")
    local large = template and template:find("Large")
    font:SetFont(
        large and self.Fonts.display or self.Fonts.body,
        large and self.Type.heading or small and self.Type.small or self.Type.body,
        ""
    )
    font:SetPoint("TOPLEFT", x, y)
    font:SetWidth(width)
    font:SetJustifyH("LEFT")
    font:SetTextColor(unpack(small and self.Colors.muted or self.Colors.text))
    font:SetText(value)
    return font
end
function Theme:Panel(parent, width, height, x, y)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(unpack(self.Colors.card))
    frame:SetBackdropBorderColor(unpack(self.Colors.border))
    return frame
end
function Theme:StyleButton(button)
    button:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    local function paint()
        local enabled = button:IsEnabled()
        local selected = button.selected
        local bg = not enabled and self.Colors.background
            or selected and self.Colors.selected
            or button.pressed and { 0.015, 0.12, 0.23, 1 }
            or button.hovered and enabled and { 0.12, 0.17, 0.24, 1 }
            or (button.variant == "primary" and self.Colors.primary or self.Colors.card)
        button:SetBackdropColor(unpack(bg))
        button:SetBackdropBorderColor(
            unpack(
                (selected or button.hovered or button.variant == "primary") and enabled and self.Colors.accent
                    or self.Colors.border
            )
        )
        if button.caption then
            button.caption:SetTextColor(unpack(enabled and self.Colors.text or self.Colors.muted))
        end
        for _, edge in ipairs(button.neonEdges or {}) do
            edge:SetAlpha(enabled and 1 or 0.2)
        end
        if button.navIcon then
            local color = not enabled and self.Colors.muted
                or (selected or button.hovered) and self.Colors.accent
                or self.Colors.muted
            button.navIcon:SetVertexColor(unpack(color))
            button.navIcon:SetAlpha(enabled and 1 or 0.35)
            button.navGlow:SetVertexColor(unpack(self.Colors.accent))
            button.navGlow:SetAlpha(enabled and (selected and 0.3 or button.hovered and 0.18 or 0) or 0)
        end
        if button.component == "NeonButton" then
            self:PaintNeonButton(button)
        end
    end
    button.RefreshStyle = paint
    button:SetScript("OnEnter", function()
        button.hovered = true
        paint()
    end)
    button:SetScript("OnLeave", function()
        button.hovered = false
        button.pressed = false
        paint()
    end)
    button:SetScript("OnEnable", paint)
    button:SetScript("OnDisable", paint)
    button:SetScript("OnMouseDown", function()
        button.pressed = true
        paint()
    end)
    button:SetScript("OnMouseUp", function()
        button.pressed = false
        paint()
    end)
    paint()
end
function Theme:NavigationButton(parent, key, text, x, y, callback, existing)
    local button = existing or self:Button(parent, text, 172, x, y, callback, 46)
    button:SetParent(parent)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(172, 46)
    button:SetScript("OnClick", callback)
    button.caption:ClearAllPoints()
    button.caption:SetPoint("LEFT", 46, 0)
    button.caption:SetWidth(120)
    button.caption:SetJustifyH("LEFT")
    button.navGlow = self:Art(button, key, 30, 30, 9, -8, 0, "ARTWORK")
    button.navGlow:SetBlendMode("ADD")
    button.navIcon = self:Art(button, key, 24, 24, 12, -11, 1, "ARTWORK")
    self:StyleNeonButton(button)
    button:RefreshStyle()
    return button
end
function Theme:Primary(button)
    self:StyleNeonButton(button, true)
end
function Theme:GameCard(parent, width, height)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    self:StyleButton(card)
    self:StylePremiumFrame(card, "card-frame", { compact = true })
    card.component = "GameCard"
    card.art = self:Art(card, false, width, height, 0, 0, 0.17, "ARTWORK", -2)
    card.shade = card:CreateTexture(nil, "ARTWORK", nil, -1)
    card.shade:SetAllPoints(card)
    card.shade:SetColorTexture(0.008, 0.018, 0.04, 0.25)
    card.icon = self:Art(card, false, 80, 80, 16, -16, 1, "ARTWORK")
    card.title = self:Label(card, "", 110, -22, width - 126, "GameFontNormalLarge")
    card.title:SetFont("Fonts\\ARIALN.TTF", 20, "")
    card.title:SetHeight(26)
    card.title:SetMaxLines(2)
    card.mode = self:Label(card, "", 110, -57, width - 126, "GameFontHighlightSmall")
    card.mode:SetTextColor(unpack(self.Colors.accent))
    card.detail = self:Label(card, "", 16, -112, width - 32)
    card.detail:SetHeight(44)
    card.detail:SetMaxLines(2)
    card.modeRule = self:Separator(card, 110, -99, width - 126, self.Colors.accent, 0.4)
    card.play = self:NeonButton(card, "Play", width - 104, 16, -178, function() end, 34, true)
    card.play.caption:SetFont("Fonts\\ARIALN.TTF", 16, "")
    card.details = self:NeonButton(card, "...", 56, width - 72, -178, function() end, 34)
    card.SetGame = function(_, game, options)
        self:UpdateGameCard(card, game, options)
    end
    card:SetScript("OnSizeChanged", function()
        if card.game then
            self:UpdateGameCard(card, card.game, card.presentation)
        end
    end)
    return card
end
function Theme:UpdateGameCard(card, game, options)
    options = options or {}
    card.game, card.presentation = game, options
    local width, height = card:GetWidth(), card:GetHeight()
    card.art:SetSize(width, height)
    self:SetArt(card.art, options.art or "generic-card", width, height, 0.22)
    self:SetArt(card.icon, options.art or "generic-card", 80, 80, 1)
    if not options.art then
        card.icon:SetTexture(game.icon or "Interface\\Icons\\INV_Misc_Dice_01")
    end
    card.title:SetWidth(width - 126)
    card.title:SetHeight(48)
    card.title:SetText(game.title)
    card.mode:ClearAllPoints()
    card.mode:SetPoint("TOPLEFT", 110, -77)
    card.mode:SetWidth(width - 126)
    card.mode:SetText(
        game.mode == "singleplayer" and "SOLO" or string.format("PARTY / %d-%d", game.minPlayers, game.maxPlayers)
    )
    card.modeRule:SetWidth(width - 126)
    card.detail:SetWidth(width - 32)
    card.detail:SetText(options.description or game.description or "")
    card.play:SetWidth(width - 104)
    card.play.caption:SetWidth(width - 120)
    card.play:SetText(options.resume and "Resume" or game.mode == "singleplayer" and "Play" or "View lobby")
    card.play:SetScript("OnClick", options.onPlay)
    if options.enabled == false or type(options.onPlay) ~= "function" then
        card.play:Disable()
    else
        card.play:Enable()
    end
    card.details:ClearAllPoints()
    card.details:SetPoint("TOPLEFT", width - 72, -178)
    card.details:SetScript("OnClick", options.onDetails)
    if type(options.onDetails) == "function" then
        card.details:Enable()
    else
        card.details:Disable()
    end
    card:SetScript("OnClick", options.onSelect)
    self:Select(card, options.selected)
end

-- Opt-in component library. Legacy Panel/Button callers keep their existing
-- presentation; decorations are textures, never input-catching child frames.
function Theme:Highlight(parent, x, y, width, height, color, alpha)
    local texture = parent:CreateTexture(nil, "OVERLAY", nil, -3)
    texture:SetColorTexture(unpack(color or self.Colors.accent))
    texture:SetAlpha(alpha or 1)
    texture:SetPoint("TOPLEFT", x, y)
    texture:SetSize(width, height)
    return texture
end
function Theme:Separator(parent, x, y, width, color, alpha)
    return self:Highlight(parent, x, y, width, 1, color or self.Colors.border, alpha)
end
function Theme:AccentPip(parent, x, y, size, color)
    return self:Highlight(parent, x, y, size or 3, size or 3, color or self.Colors.accent)
end
function Theme:CornerOrnament(parent, corner, inset, length, color)
    local left, top = corner:find("LEFT"), corner:find("TOP")
    local x, y = left and inset or -inset, top and -inset or inset
    local pieces = {}
    for _, glow in ipairs({ true, false }) do
        for _, horizontal in ipairs({ true, false }) do
            local t = self:Highlight(
                parent,
                0,
                0,
                horizontal and length or (glow and 5 or 1),
                horizontal and (glow and 5 or 1) or length,
                color,
                glow and self.Components.glowAlpha or 0.9
            )
            t:ClearAllPoints()
            t:SetPoint(corner, x, y)
            pieces[#pieces + 1] = t
        end
    end
    return pieces
end
local function outline(theme, parent, inset, color, alpha)
    local textures = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local horizontal = side == "TOP" or side == "BOTTOM"
        local t = theme:Highlight(parent, 0, 0, 1, 1, color, alpha)
        t:ClearAllPoints()
        if horizontal then
            t:SetPoint(side .. "LEFT", inset, side == "TOP" and -inset or inset)
            t:SetPoint(side .. "RIGHT", -inset, side == "TOP" and -inset or inset)
            t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side, side == "LEFT" and inset or -inset, -inset)
            t:SetPoint("BOTTOM" .. side, side == "LEFT" and inset or -inset, inset)
            t:SetWidth(1)
        end
        textures[#textures + 1] = t
    end
    return textures
end
function Theme:StylePremiumFrame(frame, key, options)
    if frame.premium then
        return frame
    end
    options = options or {}
    frame:SetBackdrop({ bgFile = not options.artwork and WHITE or nil, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(unpack(self.Colors.card))
    frame:SetBackdropBorderColor(unpack(self.Colors.border))
    local decoration = { key = key or "window-frame", artwork = options.artwork == true, corners = {}, glow = {} }
    frame.premium, frame.component = decoration, "PremiumFrame"
    local custom = frame:CreateTexture(nil, "OVERLAY", nil, -2)
    custom:SetAllPoints(frame)
    decoration.custom = custom
    local asset = Games.Artwork[decoration.key]
    if asset and asset.file and custom:SetTexture(asset.file) ~= false then
        return frame
    end
    custom:Hide()
    decoration.outer = outline(self, frame, 1, self.Colors.border, self.Components.borderAlpha)
    decoration.inner = outline(self, frame, options.compact and 3 or self.Components.inset, self.Colors.ice, 0.1)
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local color = corner == "BOTTOMRIGHT" and self.Colors.violet or self.Colors.accent
        local parts = self:CornerOrnament(frame, corner, 2, options.compact and 8 or self.Components.corner, color)
        for i, texture in ipairs(parts) do
            decoration.corners[#decoration.corners + 1] = texture
            if i <= 2 then
                decoration.glow[#decoration.glow + 1] = texture
            end
        end
    end
    return frame
end
function Theme:PremiumFrame(parent, width, height, x, y, options)
    local frame = self:Panel(parent, width, height, x, y)
    return self:StylePremiumFrame(frame, options and options.skin or "window-frame", options)
end
function Theme:StyleNeonButton(button, primary)
    if primary then
        button.variant = "primary"
    end
    self:StylePremiumFrame(button, "button-frame", { compact = true })
    button.component = "NeonButton"
    if not button.sheen then
        button.sheen = self:Highlight(button, 5, -4, 1, 1, self.Colors.ice, 0.2)
        button.sheen:SetPoint("TOPRIGHT", -5, -4)
    end
    button:RefreshStyle()
    return button
end
function Theme:PaintNeonButton(button)
    local enabled = button:IsEnabled()
    if not enabled then
        button.pressed = false
    end
    local state = not enabled and "disabled"
        or button.pressed and "pressed"
        or button.hovered and "hover"
        or button.selected and "selected"
        or "normal"
    button.visualState = state
    local active = state == "hover" or state == "selected"
    local color = state == "disabled" and self.Colors.background
        or state == "pressed" and { 0.018, 0.11, 0.22, 1 }
        or active and self.Colors.selected
        or button.variant == "primary" and self.Colors.primary
        or self.Colors.card
    button:SetBackdropColor(unpack(color))
    button:SetBackdropBorderColor(
        unpack(enabled and (active or button.variant == "primary") and self.Colors.accent or self.Colors.border)
    )
    button.sheen:SetAlpha(state == "disabled" and 0.025 or state == "pressed" and 0.05 or active and 0.4 or 0.16)
    button.premium.custom:SetAlpha(not enabled and 0.15 or active and 1 or 0.65)
    for _, texture in ipairs(button.premium.corners or {}) do
        texture:SetAlpha(not enabled and 0.08 or active and 1 or 0.45)
    end
    for _, glow in ipairs(button.premium.glow or {}) do
        glow:SetAlpha(not enabled and 0 or active and 0.16 or 0.04)
    end
end
function Theme:NeonButton(parent, text, width, x, y, callback, height, primary)
    return self:StyleNeonButton(self:Button(parent, text, width, x, y, callback, height), primary)
end
function Theme:SectionHeader(parent, title, width, x, y, fontSize)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", x, y)
    header:SetSize(width, 26)
    header.component = "SectionHeader"
    header.title = self:Label(header, "", 0, 0, width - 30)
    header.title:SetFont(self.Fonts.display, fontSize or 18, "")
    header.title:SetTextColor(unpack(self.Colors.accent))
    header.title:SetMaxLines(1)
    header.line = self:Separator(header, 0, -12, 1, self.Colors.border, 0.85)
    header.cap = self:Separator(header, 0, -12, 24, self.Colors.accent, 0.7)
    header.pip = self:AccentPip(header, 0, -11, 3, self.Colors.ice)
    local function layout()
        local w = header:GetWidth()
        header.title:SetWidth(math.max(1, w - 44))
        local textWidth = math.min(math.ceil(header.title:GetStringWidth()), math.max(1, w - 44))
        header.line:ClearAllPoints()
        header.line:SetPoint("TOPLEFT", textWidth + 16, -12)
        header.line:SetPoint("TOPRIGHT", -8, -12)
        header.cap:ClearAllPoints()
        header.cap:SetPoint("TOPLEFT", textWidth + 16, -12)
        header.cap:SetWidth(math.min(24, math.max(1, w - textWidth - 24)))
        header.pip:ClearAllPoints()
        header.pip:SetPoint("TOPRIGHT", -1, -11)
    end
    header.SetText = function(_, text)
        header.text = text
        header.title:SetText(text)
        layout()
    end
    header:SetScript("OnSizeChanged", layout)
    header:SetText(title)
    return header
end
function Theme:StatPanel(parent, title, width, height, x, y)
    local frame = self:PremiumFrame(parent, width, height, x, y, { skin = "stat-frame", compact = true })
    frame.component = "StatPanel"
    frame.label = self:Label(frame, title, 16, -12, width - 32, "GameFontHighlightSmall")
    frame.label:SetTextColor(unpack(self.Colors.accent))
    frame.value = self:Label(frame, "No record", 16, -36, width - 32, "GameFontNormalLarge")
    frame.value:SetFont(self.Fonts.display, 26, "")
    frame.value:SetMaxLines(1)
    frame.detail = self:Label(frame, "", 16, -76, width - 32, "GameFontHighlightSmall")
    frame.detail:SetMaxLines(1)
    frame.SetStat = function(_, value, detail)
        frame.value:SetText(value == nil and "No record" or tostring(value))
        frame.detail:SetText(detail or "")
    end
    frame:SetScript("OnSizeChanged", function()
        for _, text in ipairs({ frame.label, frame.value, frame.detail }) do
            text:SetWidth(math.max(1, frame:GetWidth() - 32))
        end
    end)
    return frame
end
function Theme:StatusPanel(parent, width, height, x, y)
    local frame = self:PremiumFrame(parent, width, height, x, y, { skin = "status-frame", compact = true })
    frame.component = "StatusPanel"
    frame.icon = self:Art(frame, "nav-multiplayer", 24, 24, 14, -14, 1, "ARTWORK")
    frame.pip = self:AccentPip(frame, 34, -12, 4)
    frame.title = self:Label(frame, "", 50, -8, width - 64)
    frame.detail = self:Label(frame, "", 50, -31, width - 64, "GameFontHighlightSmall")
    frame.title:SetMaxLines(1)
    frame.detail:SetMaxLines(1)
    frame.SetStatus = function(_, title, detail, connected)
        frame.title:SetText(title or "")
        frame.detail:SetText(detail or "")
        local color = connected and self.Colors.success or self.Colors.muted
        frame.pip:SetColorTexture(unpack(color))
        frame.icon:SetVertexColor(unpack(connected and self.Colors.ice or self.Colors.muted))
    end
    frame:SetScript("OnSizeChanged", function()
        frame.title:SetWidth(math.max(1, frame:GetWidth() - 64))
        frame.detail:SetWidth(math.max(1, frame:GetWidth() - 64))
    end)
    return frame
end
function Theme:Select(button, selected)
    button.selected = selected == true
    button:RefreshStyle()
end
function Theme:Button(parent, value, width, x, y, callback, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height or 28)
    button:SetPoint("TOPLEFT", x, y)
    button.caption = self:Label(button, "", 0, 0, width)
    button.caption:ClearAllPoints()
    button.caption:SetPoint("CENTER")
    button.caption:SetJustifyH("CENTER")
    button.caption:SetFont(self.Fonts.body, self.Type.button, "")
    button:SetFontString(button.caption)
    button:SetText(value)
    button:SetScript("OnClick", callback)
    self:StyleButton(button)
    return button
end
function Theme:CloseButton(frame)
    local close = self:Button(frame, "×", 28, 0, 0, function()
        frame:Hide()
    end)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", -14, -14)
    return close
end
function Theme:Scroll(parent, width, height, x, y)
    local frame = CreateFrame("ScrollFrame", nil, parent)
    frame:SetSize(width, height)
    frame:SetPoint("TOPLEFT", x, y)
    frame:SetClipsChildren(true)
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(width, 1)
    frame:SetScrollChild(child)
    local bar = CreateFrame("Slider", nil, frame)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    bar:SetSize(6, height)
    bar:SetOrientation("VERTICAL")
    bar:SetValueStep(1)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(6, 30)
    thumb:SetColorTexture(unpack(self.Colors.accent))
    bar:SetThumbTexture(thumb)
    frame.scrollBar = bar
    local syncing = false
    local function range()
        return math.max(0, child:GetHeight() - frame:GetHeight())
    end
    local function update()
        bar:SetHeight(frame:GetHeight())
        bar:SetMinMaxValues(0, math.max(1, range()))
        bar:SetShown(range() > 0)
        bar:SetValue(math.min(frame:GetVerticalScroll(), range()))
        frame:SetVerticalScroll(math.max(0, math.min(frame:GetVerticalScroll(), range())))
    end
    bar:SetScript("OnValueChanged", function(_, value)
        if not syncing then
            frame:SetVerticalScroll(math.max(0, math.min(value, range())))
        end
    end)
    frame:SetScript("OnVerticalScroll", function(_, value)
        if not syncing then
            syncing = true
            bar:SetValue(value)
            syncing = false
        end
    end)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(math.max(0, math.min(frame:GetVerticalScroll() - delta * 36, range())))
    end)
    child:SetScript("OnSizeChanged", update)
    frame:SetScript("OnSizeChanged", update)
    update()
    return child, frame
end
function Theme:Window(frame, overlay, premium)
    frame:SetBackdropColor(unpack(self.Colors.background))
    frame:SetFrameStrata(overlay and "FULLSCREEN_DIALOG" or "DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if premium then
        self:StylePremiumFrame(frame, "window-frame")
        frame:SetBackdropColor(unpack(self.Colors.background))
    else
        self:NeonBorder(frame, "window-frame")
    end
    frame:SetScript("OnDragStart", function()
        frame:Raise()
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame:SetScript("OnShow", function()
        frame:Raise()
    end)
    frame:SetScript("OnHide", function()
        frame:StopMovingOrSizing()
    end)
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(unpack(self.Colors.accent))
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
end
