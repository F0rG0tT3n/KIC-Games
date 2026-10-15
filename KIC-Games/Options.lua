local _, Games = ...
local UI, Theme = Games.UI, Games.Theme
function UI:CreateOptions()
    local f = Theme:Panel(UIParent, 500, 430, 0, 0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    Theme:Window(f, true)
    Theme:CloseButton(f)
    _G.KICGamesOptions = f
    UISpecialFrames[#UISpecialFrames + 1] = "KICGamesOptions"
    Theme:Label(f, "Options", 24, -24, 410, "GameFontNormalLarge")
    Theme:Label(f, "Class icons · applies to all games", 24, -64, 450)
    self.classButtons = {}
    for i, preset in ipairs(Games.IconPresets.Presets) do
        local token = preset.token
        local b = Theme:Button(
            f,
            "|cff" .. preset.color .. preset.name .. "|r",
            216,
            24 + ((i - 1) % 2) * 236,
            -102 - math.floor((i - 1) / 2) * 34,
            function()
                Games:SetClassPreset(token)
            end
        )
        self.classButtons[token] = b
    end
    self.optionsScale = Theme:Label(f, "", 24, -355, 290, "GameFontHighlightSmall")
    Theme:Button(f, "Reset size", 120, 352, -350, function()
        self:SetWindowScale(1)
    end)
    Theme:Button(f, "Done", 216, 142, -390, function()
        f:Hide()
    end)
    f:Hide()
    self.optionsFrame = f
    self:RegisterAuxiliaryWindow(f)
end
function UI:RefreshOptions()
    if not self.optionsFrame then
        return
    end
    local token = Games:GetClassPreset()
    for class, b in pairs(self.classButtons) do
        Theme:Select(b, class == token)
    end
    self.optionsScale:SetText(
        string.format("Window size: %d%% · drag bottom-right to resize", math.floor(self.frame:GetScale() * 100 + 0.5))
    )
end
function UI:ShowOptions()
    self:HideAuxiliaryWindows()
    self.resultsFrame:Hide()
    self:RefreshOptions()
    self.optionsFrame:Show()
    self.optionsFrame:Raise()
end
function UI:MaxWindowScale()
    return math.max(0.5, math.min(2, UIParent:GetWidth() / 920, UIParent:GetHeight() / 650))
end
function UI:SetWindowScale(scale)
    if type(scale) ~= "number" or scale ~= scale then
        scale = 1
    end
    scale = math.max(math.min(0.75, self:MaxWindowScale()), math.min(scale, self:MaxWindowScale()))
    self.frame:SetScale(scale)
    Games:GetSettings().windowScale = scale
    if self.resultsFrame then
        self.resultsFrame:SetScale(scale)
    end
    for _, f in ipairs(self.auxiliaryWindows or {}) do
        f:SetScale(scale)
    end
    if self.resizeAnchor then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(
            "TOPLEFT",
            UIParent,
            "BOTTOMLEFT",
            self.resizeAnchor.left / scale,
            self.resizeAnchor.top / scale
        )
    end
    self:RefreshOptions()
end
function UI:InitializeResize()
    local grip = Theme:Button(self.frame, "Resize", 62, 0, 0, function() end, 20)
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMRIGHT", -12, 10)
    self.resizeGrip = grip
    local function stop()
        self.resizeStart, self.resizeAnchor = nil, nil
        self.frame:SetMovable(true)
    end
    self.StopResize = stop
    grip:SetScript("OnMouseDown", function(_, mouse)
        if mouse ~= "LeftButton" then
            return
        end
        local x, y = GetCursorPosition()
        local scale = self.frame:GetScale()
        self.resizeStart = { x = x, y = y, scale = scale }
        self.resizeAnchor = { left = self.frame:GetLeft() * scale, top = self.frame:GetTop() * scale }
        self.frame:StopMovingOrSizing()
        self.frame:SetMovable(false)
    end)
    grip:SetScript("OnMouseUp", stop)
    grip:SetScript("OnUpdate", function()
        local start = self.resizeStart
        if not start then
            return
        end
        if not IsMouseButtonDown("LeftButton") then
            stop()
            return
        end
        local x, y = GetCursorPosition()
        local uiScale = UIParent:GetEffectiveScale()
        local dx, dy = (x - start.x) / 900, (start.y - y) / 630
        local delta = (math.abs(dx) > math.abs(dy) and dx or dy) / uiScale
        self:SetWindowScale(start.scale + delta)
    end)
    self:SetWindowScale(Games:GetSettings().windowScale or 1)
end
