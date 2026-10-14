local _, Games = ...
local Theme = {}
Games.Theme = Theme
Theme.Colors = {
    background = { 0.035, 0.043, 0.065, 1 },
    card = { 0.06, 0.072, 0.105, 1 },
    border = { 0.14, 0.17, 0.24, 1 },
    text = { 0.9, 0.93, 1, 1 },
    muted = { 0.52, 0.6, 0.72, 1 },
    accent = { 0.38, 0.76, 1, 1 },
    selected = { 0.13, 0.24, 0.35, 1 },
}
local WHITE = "Interface\\Buttons\\WHITE8X8"
function Theme:Label(parent, value, x, y, width, template)
    local font = parent:CreateFontString(nil, "OVERLAY")
    local small = template and template:find("Small")
    local large = template and template:find("Large")
    font:SetFont("Fonts\\ARIALN.TTF", large and 22 or small and 12 or 14, "")
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
        local bg = selected and self.Colors.selected
            or button.hovered and enabled and { 0.12, 0.17, 0.24, 1 }
            or self.Colors.card
        button:SetBackdropColor(unpack(bg))
        button:SetBackdropBorderColor(unpack(selected and self.Colors.accent or self.Colors.border))
        if button.caption then
            button.caption:SetTextColor(unpack(enabled and self.Colors.text or self.Colors.muted))
        end
    end
    button.RefreshStyle = paint
    button:SetScript("OnEnter", function()
        button.hovered = true
        paint()
    end)
    button:SetScript("OnLeave", function()
        button.hovered = false
        paint()
    end)
    button:SetScript("OnEnable", paint)
    button:SetScript("OnDisable", paint)
    paint()
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
    button.caption:SetFont("Fonts\\ARIALN.TTF", 13, "")
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
