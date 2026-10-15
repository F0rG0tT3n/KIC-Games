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
}
local WHITE = "Interface\\Buttons\\WHITE8X8"
function Theme:Art(parent, key, width, height, x, y, alpha, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
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
function Theme:Primary(button)
    button.variant = "primary"
    button.neonEdges = self:NeonBorder(button, "button-frame")
    button:RefreshStyle()
end
function Theme:GameCard(parent, width, height)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(width, height)
    self:StyleButton(card)
    card.art = self:Art(card, false, width, height, 0, 0, 0.17)
    card.icon = self:Art(card, false, 80, 80, 16, -16, 1, "ARTWORK")
    card.title = self:Label(card, "", 110, -22, width - 126, "GameFontNormalLarge")
    card.title:SetFont("Fonts\\ARIALN.TTF", 20, "")
    card.title:SetHeight(26)
    card.mode = self:Label(card, "", 110, -57, width - 126, "GameFontHighlightSmall")
    card.mode:SetTextColor(unpack(self.Colors.accent))
    card.detail = self:Label(card, "", 16, -112, width - 32)
    card.detail:SetHeight(44)
    card.play = self:Button(card, "Play", width - 104, 16, -178, function() end, 34)
    card.play.caption:SetFont("Fonts\\ARIALN.TTF", 16, "")
    self:Primary(card.play)
    card.details = self:Button(card, "...", 56, width - 72, -178, function() end, 34)
    return card
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
    local child = CreateFrame("Frame", nil, frame)
    child:SetSize(width, 1)
    frame:SetScrollChild(child)
    local bar = CreateFrame("Slider", nil, frame)
    bar:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
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
function Theme:Window(frame, overlay)
    frame:SetBackdropColor(unpack(self.Colors.background))
    frame:SetFrameStrata(overlay and "FULLSCREEN_DIALOG" or "DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    self:NeonBorder(frame, "window-frame")
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
