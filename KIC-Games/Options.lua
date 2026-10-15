local _, Games = ...
local UI, Theme = Games.UI, Games.Theme
function UI:CreateOptions()
    local f = CreateFrame("Frame", nil, self.content)
    f:SetAllPoints(self.content)
    self.optionsFrame = f
    self.optionsHeading = Theme:Label(f, "OPTIONS", 0, -6, 550, "GameFontNormalLarge")
    self.optionsSubtitle =
        Theme:Label(f, "Make the arcade your own. Settings apply to every game.", 0, -36, 650, "GameFontHighlightSmall")
    self.optionsContent, self.optionsScroll = Theme:Scroll(f, 882, 482, 0, -66)
    self.appearancePanel = Theme:Panel(self.optionsContent, 864, 320, 0, 0)
    Theme:Label(self.appearancePanel, "APPEARANCE", 24, -20, 500, "GameFontNormalLarge")
    Theme:Label(self.appearancePanel, "Class icons / shared by Tetris and Bejeweled", 24, -57, 650)
    self.classButtons = {}
    for _, preset in ipairs(Games.IconPresets.Presets) do
        local token = preset.token
        self.classButtons[token] = Theme:Button(
            self.appearancePanel,
            "|cff" .. preset.color .. preset.name .. "|r",
            216,
            0,
            0,
            function()
                Games:SetClassPreset(token)
            end,
            44
        )
        local b = self.classButtons[token]
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("LEFT", 10, 0)
        b.icon:SetSize(28, 28)
        b.icon:SetTexture(Games.IconPresets.FallbackIcons[token])
        b.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
        b.caption:ClearAllPoints()
        b.caption:SetPoint("LEFT", 50, 0)
        b.caption:SetJustifyH("LEFT")
    end
    self.sizePanel = Theme:Panel(self.optionsContent, 864, 180, 0, -336)
    Theme:Label(self.sizePanel, "WINDOW", 24, -20, 550, "GameFontNormalLarge")
    self.optionsScale = Theme:Label(self.sizePanel, "", 24, -58, 650)
    self.scaleDown = Theme:Button(self.sizePanel, "Smaller UI", 120, 24, -96, function()
        self:SetWindowScale(self.frame:GetScale() - 0.1)
    end, 34)
    self.scaleUp = Theme:Button(self.sizePanel, "Larger UI", 120, 156, -96, function()
        self:SetWindowScale(self.frame:GetScale() + 0.1)
    end, 34)
    self.resetSize = Theme:Button(self.sizePanel, "Reset Size", 140, 288, -96, function()
        self:ResetWindowSize()
    end, 34)
    Theme:Label(
        self.sizePanel,
        "Drag the bottom-right handle to resize and reflow the library.",
        24,
        -148,
        650,
        "GameFontHighlightSmall"
    )
    self.controlsPanel = Theme:Panel(self.optionsContent, 864, 150, 0, -532)
    Theme:Label(self.controlsPanel, "CONTROLS", 24, -20, 550, "GameFontNormalLarge")
    Theme:Label(
        self.controlsPanel,
        "Tetris: arrows, Space, C and P.\nBejeweled: drag to a neighbor or click two icons.\nStop match: leave immediately when your group is ready.",
        24,
        -60,
        650
    )
    self.aboutPanel = Theme:Panel(self.optionsContent, 864, 116, 0, -698)
    Theme:Label(self.aboutPanel, "ABOUT KIC GAMES", 24, -20, 550, "GameFontNormalLarge")
    Theme:Label(
        self.aboutPanel,
        "Version "
            .. Games.VERSION
            .. " / Games today. Raids tomorrow.\nClass selection, window size and records are saved across /reload.",
        24,
        -58,
        650
    )
    f:Hide()
    self:LayoutOptions()
end
function UI:LayoutOptions()
    local width, height = self.content:GetWidth(), self.content:GetHeight()
    local available = width - 18
    self.optionsHeading:SetWidth(width - 176)
    self.optionsSubtitle:SetWidth(width - 18)
    self.optionsScroll:SetSize(width, height - 66)
    self.optionsContent:SetWidth(available)
    local columns = math.max(1, math.floor((available - 34) / 210))
    local buttonWidth = (available - 48 - (columns - 1) * 12) / columns
    for i, preset in ipairs(Games.IconPresets.Presets) do
        local b = self.classButtons[preset.token]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 24 + ((i - 1) % columns) * (buttonWidth + 12), -96 - math.floor((i - 1) / columns) * 52)
        b:SetWidth(buttonWidth)
        b.caption:SetWidth(buttonWidth - 62)
    end
    local appearanceHeight = 116 + math.ceil(#Games.IconPresets.Presets / columns) * 52
    self.appearancePanel:SetSize(available, appearanceHeight)
    local y = appearanceHeight + 16
    for _, section in ipairs({ { self.sizePanel, 180 }, { self.controlsPanel, 150 }, { self.aboutPanel, 116 } }) do
        section[1]:ClearAllPoints()
        section[1]:SetPoint("TOPLEFT", 0, -y)
        section[1]:SetSize(available, section[2])
        y = y + section[2] + 16
    end
    self.optionsContent:SetHeight(y)
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
        string.format(
            "UI scale: %d%% / Window: %d x %d",
            math.floor(self.frame:GetScale() * 100 + 0.5),
            self.frame:GetWidth(),
            self.frame:GetHeight()
        )
    )
end
function UI:ShowOptions()
    self:OpenLauncher("options")
end
function UI:MaxWindowScale()
    return math.max(
        0.5,
        math.min(
            2,
            UIParent:GetWidth() / (self.frame:GetWidth() + 20),
            UIParent:GetHeight() / (self.frame:GetHeight() + 20)
        )
    )
end
function UI:SetWindowScale(scale)
    if type(scale) ~= "number" or scale ~= scale then
        scale = 1
    end
    scale = math.max(math.min(0.75, self:MaxWindowScale()), math.min(scale, self:MaxWindowScale()))
    self.frame:SetScale(scale)
    Games:GetSettings().windowScale = scale
    for _, f in ipairs(self.auxiliaryWindows or {}) do
        f:SetScale(scale)
    end
    self:RefreshOptions()
end
function UI:SetWindowSize(width, height)
    local settings = Games:GetSettings()
    local function valid(n, fallback)
        return type(n) == "number" and n == n and n > 0 and n < math.huge and n or fallback
    end
    local scale = self.frame:GetScale()
    local maxWidth = math.max(762, (UIParent:GetWidth() - 20) / scale)
    local maxHeight = math.max(650, (UIParent:GetHeight() - 20) / scale)
    width = math.floor(math.max(math.min(1000, maxWidth), math.min(valid(width, self.BASE_WIDTH), maxWidth)))
    height = math.floor(math.max(math.min(700, maxHeight), math.min(valid(height, self.BASE_HEIGHT), maxHeight)))
    self.frame:SetSize(width, height)
    settings.windowWidth, settings.windowHeight = width, height
    self:LayoutLauncher()
    self:RefreshOptions()
end
function UI:ResetWindowSize()
    self.frame:SetSize(self.BASE_WIDTH, self.BASE_HEIGHT)
    self:SetWindowScale(1)
    self:SetWindowSize(self.BASE_WIDTH, self.BASE_HEIGHT)
end
function UI:InitializeResize()
    local grip = Theme:Button(self.frame, "Resize", 62, 0, 0, function() end, 20)
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMRIGHT", -12, 10)
    self.resizeGrip = grip
    local function stop()
        self.resizeStart = nil
        self.frame:SetMovable(true)
    end
    self.StopResize = stop
    grip:SetScript("OnMouseDown", function(_, mouse)
        if mouse ~= "LeftButton" then
            return
        end
        local x, y = GetCursorPosition()
        self.resizeStart = {
            x = x,
            y = y,
            width = self.frame:GetWidth(),
            height = self.frame:GetHeight(),
            left = self.frame:GetLeft(),
            top = self.frame:GetTop(),
        }
        self.frame:StopMovingOrSizing()
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.resizeStart.left, self.resizeStart.top)
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
        local scale = self.frame:GetEffectiveScale()
        self:SetWindowSize(start.width + (x - start.x) / scale, start.height + (start.y - y) / scale)
    end)
    local settings = Games:GetSettings()
    -- Apply saved scale first using the base window, then clamp saved dimensions.
    self:SetWindowScale(settings.windowScale or 1)
    self:SetWindowSize(settings.windowWidth, settings.windowHeight)
end
