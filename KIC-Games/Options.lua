local _, Games = ...
local UI, Theme = Games.UI, Games.Theme
local function place(frame, x, y, w, h)
    Theme:PlaceGame(frame, x, y, w, h)
end
local function label(parent, text, size, color)
    return Theme:GameLabel(parent, text, size or 14, color)
end
local function panel(parent, title, detail)
    local f = Theme:PremiumFrame(parent, 800, 120, 0, 0)
    f.heading = Theme:SectionHeader(f, title, 760, 18, -16, 16)
    f.detail = label(f, detail, 12, Theme.Colors.muted)
    place(f.detail, 18, 46, 760, 34)
    return f
end
local function selector(parent, title, detail, icon, onClick)
    local b = Theme:NeonButton(parent, "", 360, 0, 0, onClick, 88)
    b.icon = Theme:Art(b, icon, 40, 40, 14, -14, 1, "ARTWORK")
    b.title = label(b, title, 16)
    b.detail = label(b, detail, 11, Theme.Colors.muted)
    b:SetScript("OnSizeChanged", function()
        place(b.title, 68, 9, b:GetWidth() - 82, 22)
        place(b.detail, 68, 33, b:GetWidth() - 82, 28)
    end)
    return b
end
local function toggle(parent, title, detail, callback)
    local p = panel(parent, title, detail)
    p.switch = Theme:NeonButton(p, "OFF", 82, 0, 0, callback, 30)
    return p
end
-- Popups live outside the clipped settings scroll child and inherit the window scale.
function Theme:SettingsDropdown(parent, popupParent, root, title, callback)
    local b = self:NeonButton(parent, "", 320, 0, 0, function() end, 44)
    b.label = label(parent, title, 12, self.Colors.muted)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("LEFT", 12, 0)
    b.icon:SetSize(26, 26)
    b.caption:ClearAllPoints()
    b.caption:SetPoint("LEFT", 48, 0)
    b.caption:SetJustifyH("LEFT")
    b.caption:SetMaxLines(1)
    b.arrow = label(b, "v", 14, self.Colors.accent)
    b.arrow:ClearAllPoints()
    b.arrow:SetPoint("RIGHT", -12, 0)
    b.arrow:SetSize(16, 24)
    b.rows, b.buttons = {}, {}
    b.popup = CreateFrame("Frame", nil, popupParent)
    b.popup:SetAllPoints(root)
    b.popup:SetFrameStrata("DIALOG")
    b.popup:SetFrameLevel(root:GetFrameLevel() + 100)
    b.popup:EnableMouse(true)
    b.popup:EnableKeyboard(true)
    b.popup:SetScript("OnMouseDown", function()
        b.popup:Hide()
    end)
    b.popup:SetScript("OnKeyDown", function(_, key)
        b.popup:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then
            b.popup:Hide()
        end
    end)
    b.popup:SetScript("OnHide", function()
        self:Select(b, false)
        b.arrow:SetText("v")
    end)
    b.menu = self:PremiumFrame(b.popup, 320, 220, 0, 0, { compact = true })
    b.menu:EnableMouse(true)
    b.menu:SetClampedToScreen(true)
    b.menu:SetBackdropColor(unpack(self.Colors.background))
    b.items, b.scroll = self:Scroll(b.menu, 304, 204, 8, -8)
    b.Close = function()
        b.popup:Hide()
    end
    b.Layout = function(_, x, y, width)
        place(b.label, x, y, width, 20)
        place(b, x, y + 26, width, 36)
        b.caption:SetWidth(width - 82)
        b.menu:SetWidth(width)
        b.scroll:SetWidth(width - 16)
        b.items:SetWidth(width - 24)
        for _, row in ipairs(b.rows) do
            row:SetWidth(width - 24)
            row.caption:SetWidth(width - 78)
        end
    end
    b.SetOptions = function(_, entries, selected, enabled)
        local same = b.optionEntries
            and #b.optionEntries == #entries
            and b.optionSelected == selected
            and b.optionEnabled == enabled
        if same then
            for i, entry in ipairs(entries) do
                local old = b.optionEntries[i]
                if old.key ~= entry.key or old.name ~= entry.name or old.icon ~= entry.icon then
                    same = false
                    break
                end
            end
        end
        if same then
            return
        end
        b.optionEntries, b.optionSelected, b.optionEnabled = entries, selected, enabled
        b.selectedIndex = nil
        b:Close()
        b.buttons = {}
        local chosen
        for i, entry in ipairs(entries) do
            local row = b.rows[i]
            if not row then
                row = self:NeonButton(b.items, "", 296, 0, 0, function() end, 36)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetPoint("LEFT", 8, 0)
                row.icon:SetSize(24, 24)
                row.caption:ClearAllPoints()
                row.caption:SetPoint("LEFT", 42, 0)
                row.caption:SetJustifyH("LEFT")
                row.caption:SetMaxLines(1)
                b.rows[i] = row
            end
            row:SetText(entry.name)
            local fallback = Games.IconPresets.FallbackIcons.MAGE
            if row.icon:SetTexture(entry.icon or fallback) == false then
                row.icon:SetTexture(fallback)
            end
            place(row, 0, (i - 1) * 38)
            self:Select(row, entry.key == selected)
            row:SetScript("OnClick", function()
                b:Close()
                if b:IsEnabled() then
                    callback(entry.key)
                end
            end)
            row:SetShown(true)
            if enabled then
                row:Enable()
            else
                row:Disable()
            end
            b.buttons[entry.key] = row
            if entry.key == selected then
                chosen, b.selectedIndex = entry, i
            end
        end
        for i = #entries + 1, #b.rows do
            b.rows[i]:Hide()
        end
        b:SetText(chosen and chosen.name or "No specialization available")
        local fallback = Games.IconPresets.FallbackIcons.MAGE
        if b.icon:SetTexture(chosen and chosen.icon or fallback) == false then
            b.icon:SetTexture(fallback)
        end
        b.icon:SetAlpha(enabled and 1 or 0.4)
        b.label:SetAlpha(enabled and 1 or 0.5)
        b.arrow:SetTextColor(unpack(enabled and self.Colors.accent or self.Colors.muted))
        b.items:SetHeight(math.max(1, #entries * 38 - 2))
        b.scroll:SetHeight(math.min(226, b.items:GetHeight()))
        b.menu:SetHeight(b.scroll:GetHeight() + 16)
        if enabled and #entries > 0 then
            b:Enable()
        else
            b:Disable()
        end
    end
    b:SetScript("OnClick", function()
        if not b:IsEnabled() then
            return
        end
        if b.popup:IsShown() then
            b:Close()
            return
        end
        UI:CloseProfileDropdowns()
        b.menu:ClearAllPoints()
        local bottom = b:GetTop() - b:GetHeight()
        local rootBottom = root:GetTop() - root:GetHeight()
        if bottom - rootBottom >= b.menu:GetHeight() + 4 then
            b.menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4)
        else
            b.menu:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 4)
        end
        b.scroll.scrollBar:SetValue(math.max(0, ((b.selectedIndex or 1) - 1) * 38 - 76))
        b.popup:SetPropagateKeyboardInput(true)
        b.popup:Show()
        self:Select(b, true)
        b.arrow:SetText("^")
    end)
    b:SetScript("OnHide", b.Close)
    b.popup:Hide()
    return b
end
function UI:CloseProfileDropdowns()
    for _, p in ipairs(self.profilePanels or {}) do
        p.classDropdown:Close()
        p.specDropdown:Close()
    end
end
local function profilePanel(parent, popupParent, root, mode)
    local p = panel(parent, "CLASS & SPECIALIZATION", "")
    p.mode = mode
    p.followLabel = label(p, "Follow my character", 12, Theme.Colors.muted)
    p.switch = Theme:NeonButton(p, "ON", 60, 0, 0, function()
        if p.switch:IsEnabled() then
            Games:SetOption("followCharacter", not Games:GetSettings().followCharacter)
        end
    end, 26)
    p.classDropdown = Theme:SettingsDropdown(p, popupParent, root, "CLASS", function(token)
        Games:SetManualClass(token)
    end)
    p.specDropdown = Theme:SettingsDropdown(p, popupParent, root, "SPECIALIZATION", function(id)
        Games:SetManualSpec(id)
    end)
    p.detail:Hide()
    return p
end
function Theme:SettingsSlider(parent, minimum, maximum, step, callback, formatValue)
    local f = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    f:SetOrientation("HORIZONTAL")
    f:SetMinMaxValues(minimum, maximum)
    f:SetValueStep(step)
    if f.SetObeyStepOnDrag then
        f:SetObeyStepOnDrag(true)
    end
    f:SetSize(500, 18)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.025, 0.07, 0.13, 1)
    f:SetBackdropBorderColor(unpack(self.Colors.border))
    f.fill = f:CreateTexture(nil, "ARTWORK")
    f.fill:SetPoint("LEFT", 2, 0)
    f.fill:SetHeight(4)
    f.fill:SetColorTexture(unpack(self.Colors.accent))
    f.thumb = f:CreateTexture(nil, "OVERLAY")
    f.thumb:SetSize(14, 26)
    f.thumb:SetColorTexture(unpack(self.Colors.ice))
    f:SetThumbTexture(f.thumb)
    f.low = label(parent, minimum .. "%", 12, Theme.Colors.muted)
    f.high = label(parent, maximum .. "%", 12, Theme.Colors.muted)
    f.valueLabel = label(parent, "", 18, Theme.Colors.ice)
    f.valueLabel:SetJustifyH("RIGHT")
    f:SetScript("OnValueChanged", function(_, value)
        value = math.max(minimum, math.min(maximum, math.floor(value / step + 0.5) * step))
        f.current = value
        f.valueLabel:SetText(formatValue and formatValue(value) or value .. "%")
        f.fill:SetWidth(math.max(1, (f:GetWidth() - 4) * (value - minimum) / (maximum - minimum)))
        if not UI.optionsSync then
            callback(value)
        end
    end)
    f.Layout = function(_, x, y, width)
        place(f, x, y, width, 18)
        place(f.low, x, y + 28, 80, 20)
        place(f.high, x + width - 80, y + 28, 80, 20)
        f.high:SetJustifyH("RIGHT")
        place(f.valueLabel, x + width - 90, y - 38, 90, 26)
        f.fill:SetWidth(math.max(1, (width - 4) * ((f.current or minimum) - minimum) / (maximum - minimum)))
    end
    return f
end
function UI:CreateOptions()
    local f = CreateFrame("Frame", nil, self.content)
    f:SetAllPoints(self.content)
    self.optionsFrame, self.optionsTab, self.previewGame = f, "graphics", "bejeweled"
    self.optionsHeading = label(f, "OPTIONS", 24)
    self.optionsSubtitle =
        label(f, "Your arcade. Your style. Settings apply instantly across games.", 12, Theme.Colors.muted)
    self.optionTabs = {}
    for i, key in ipairs({ "graphics", "audio", "window" }) do
        self.optionTabs[key] = Theme:NeonButton(f, key:sub(1, 1):upper() .. key:sub(2), 150, 0, 0, function()
            self:SelectOptionsTab(key)
        end, 34)
    end
    self.optionsContent, self.optionsScroll = Theme:Scroll(f, 882, 420, 0, -110)
    self.optionsPages = {}
    for _, key in ipairs({ "graphics", "audio", "window" }) do
        self.optionsPages[key] = CreateFrame("Frame", nil, self.optionsContent)
    end
    local g = self.optionsPages.graphics
    self.graphicsChoices = {
        original = selector(
            g,
            "Original Graphics",
            "Classic gems and colored tetromino blocks.",
            "original-gem-6",
            function()
                Games:SetOption("graphicsTheme", "original")
            end
        ),
        class = selector(
            g,
            "Class Spells",
            "Spell pieces from your selected specialization.",
            "nav-singleplayer",
            function()
                Games:SetOption("graphicsTheme", "class")
            end
        ),
    }
    self.appearancePanel = profilePanel(g, f, self.frame, "graphicsTheme")
    self.profilePanels = { self.appearancePanel }
    self.classDropdown, self.specDropdown = self.appearancePanel.classDropdown, self.appearancePanel.specDropdown
    f:SetScript("OnHide", function()
        self:CloseProfileDropdowns()
    end)
    self.graphicsPreview = panel(g, "LIVE PREVIEW", "Read-only pieces. Your active board and score stay intact.")
    self.previewGameButtons = {}
    for _, game in ipairs(Games:GetGames()) do
        if Games.Graphics.providers[game.id] then
            local id = game.id
            self.previewGameButtons[#self.previewGameButtons + 1] = Theme:NeonButton(
                self.graphicsPreview,
                game.title,
                120,
                0,
                0,
                function()
                    self.previewGame = id
                    self:RefreshOptions()
                end,
                28
            )
            self.previewGameButtons[#self.previewGameButtons].gameID = id
        end
    end
    self.previewCells = {}
    for i = 1, 6 do
        local cell = Theme:PremiumFrame(self.graphicsPreview, 58, 58, 0, 0, { compact = true })
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetPoint("TOPLEFT", 5, -5)
        cell.icon:SetSize(48, 48)
        self.previewCells[i] = cell
    end
    local a = self.optionsPages.audio
    self.audioChoices = {
        arcade = selector(
            a,
            "Original / Arcade Sounds",
            "Game-specific clicks, landings, clears and combos.",
            "icon-cascade",
            function()
                Games:SetOption("soundTheme", "arcade")
            end
        ),
        class = selector(
            a,
            "Class & Specialization",
            "Spell sounds from the selected class and spec.",
            "nav-singleplayer",
            function()
                Games:SetOption("soundTheme", "class")
            end
        ),
    }
    self.audioAppearancePanel = profilePanel(a, f, self.frame, "soundTheme")
    self.profilePanels[#self.profilePanels + 1] = self.audioAppearancePanel
    self.soundEnabledPanel = toggle(a, "MUTE SOUNDS", "Mute all game effects.", function()
        Games:SetOption("soundsEnabled", not Games:GetSettings().soundsEnabled)
    end)
    self.volumePanel = panel(a, "GAME SOUND VOLUME", "")
    self.volumeSlider = Theme:SettingsSlider(self.volumePanel, 0, 100, 1, function(value)
        if Games:GetSettings().soundsEnabled then
            Games:SetOption("soundVolume", value / 100)
        end
    end)
    self.volumePanel.detail:SetFont(Theme.Fonts.body, 11, "")
    self.volumeSlider.low:Hide()
    self.volumeSlider.high:Hide()
    self.audioProfilePanel = panel(a, "SOUND PREVIEW", "")
    self.audioProfilePanel.detail:SetFont(Theme.Fonts.body, 11, "")
    self.audioGameButtons = {}
    for _, game in ipairs(Games:GetGames()) do
        if Games.Audio.games[game.id] then
            local id = game.id
            local b = Theme:NeonButton(self.audioProfilePanel, game.title, 120, 0, 0, function()
                self.previewGame = id
                self:RefreshOptions()
            end, 28)
            b.gameID = id
            self.audioGameButtons[#self.audioGameButtons + 1] = b
        end
    end
    self.soundPreviewButtons = {}
    for _, event in ipairs(Games.Audio.events) do
        local display = event == "gameOver" and "Game Over" or event:sub(1, 1):upper() .. event:sub(2)
        local b = Theme:NeonButton(self.audioProfilePanel, event, 140, 0, 0, function()
            local played = Games.Audio:Play(self.previewGame, event, true)
            self.audioPreviewStatus:SetText(
                played and ("Playing: " .. display) or "Sound is muted or unavailable in this client."
            )
        end, 32)
        b:SetText(display)
        self.soundPreviewButtons[event] = b
    end
    self.audioPreviewStatus = label(self.audioProfilePanel, "", 12, Theme.Colors.muted)
    local w = self.optionsPages.window
    self.windowPanel = panel(w, "WINDOW & DISPLAY", "Interface Scale adjusts the entire arcade consistently.")
    self.scaleTitle = label(self.windowPanel, "Interface Scale", 16)
    self.scaleSlider = Theme:SettingsSlider(self.windowPanel, 75, 150, 5, function(value)
        self:SetWindowScale(value / 100)
    end)
    self.resetScale = Theme:NeonButton(self.windowPanel, "Reset to 100%", 150, 0, 0, function()
        self:SetWindowScale(1)
    end, 32)
    self.scaleNote = label(self.windowPanel, "", 12, Theme.Colors.muted)
    self.effectsPanel = panel(w, "EFFECTS", "Match and line-clear visuals in both games. Sound is unchanged.")
    self.effectsSlider = Theme:SettingsSlider(self.effectsPanel, 0, 2, 1, function(value)
        Games:SetOption("effectsLevel", value)
    end, function(value)
        return ({ "Off", "Subtle", "Full" })[value + 1]
    end)
    self.effectsSlider.low:SetText("Off")
    self.effectsSlider.high:SetText("Full")
    f:Hide()
    self:RefreshOptions()
end
function UI:SelectOptionsTab(key)
    if not self.optionsPages[key] then
        return
    end
    self:CloseProfileDropdowns()
    self.optionsTab = key
    self.optionsScroll:SetVerticalScroll(0)
    self:RefreshOptions()
end
function UI:LayoutOptions()
    if not self.optionsFrame or not self.windowPanel then
        return
    end
    local width, height = self.content:GetWidth(), self.content:GetHeight()
    local available = width - 18
    place(self.optionsHeading, 0, 2, width - 176, 30)
    place(self.optionsSubtitle, 0, 30, width - 8, 18)
    local tabW = math.min(180, (available - 16) / 3)
    for i, key in ipairs({ "graphics", "audio", "window" }) do
        place(self.optionTabs[key], (i - 1) * (tabW + 8), 52, tabW, 30)
    end
    place(self.optionsScroll, 0, 92, width, height - 92)
    self.optionsContent:SetWidth(available)
    for _, page in pairs(self.optionsPages) do
        page:SetSize(available, 1)
        place(page, 0, 0)
    end
    local function section(f, y, h, x, w)
        w = w or available
        place(f, x or 0, y, w, h)
        place(f.heading, 18, 10, w - 36, 26)
        f.heading.title:SetFont(Theme.Fonts.display, 14, "")
        f.heading:SetText(f.heading.text)
        place(f.detail, 18, 36, w - 36, 28)
    end
    local half = (available - 12) / 2
    local dropdownWidth = (available - 48) / 2
    for _, p in ipairs(self.profilePanels) do
        section(p, 76, 112)
        p.heading:SetWidth(available - 288)
        place(p.followLabel, available - 256, 12, 160, 24)
        place(p.switch, available - 78, 10, 60, 26)
        p.classDropdown:Layout(18, 38, dropdownWidth)
        p.specDropdown:Layout(30 + dropdownWidth, 38, dropdownWidth)
    end
    place(self.graphicsChoices.original, 0, 0, half, 68)
    place(self.graphicsChoices.class, half + 12, 0, half, 68)
    section(self.graphicsPreview, 196, 208)
    self.graphicsPreview.heading:SetWidth(available - 36 - #self.previewGameButtons * 112)
    for i, b in ipairs(self.previewGameButtons) do
        place(b, available - 18 - (#self.previewGameButtons - i + 1) * 112, 10, 104, 26)
    end
    local cellSize = math.min(64, math.floor((available - 36 - 5 * 10) / 6))
    for i, cell in ipairs(self.previewCells) do
        place(cell, 18 + (i - 1) * (cellSize + 10), 88, cellSize, cellSize)
        cell.icon:SetSize(cellSize - 10, cellSize - 10)
    end
    self.optionsPages.graphics:SetHeight(404)
    place(self.audioChoices.arcade, 0, 0, half, 68)
    place(self.audioChoices.class, half + 12, 0, half, 68)
    local enableWidth = math.max(200, math.floor(available * 0.26))
    local volumeWidth = available - enableWidth - 12
    section(self.soundEnabledPanel, 196, 104, 0, enableWidth)
    place(self.soundEnabledPanel.switch, 18, 66, 72, 26)
    section(self.volumePanel, 196, 104, enableWidth + 12, volumeWidth)
    self.volumePanel.heading:SetWidth(volumeWidth - 108)
    place(self.volumePanel.detail, 18, 68, volumeWidth - 36, 28)
    self.volumeSlider:Layout(18, 44, volumeWidth - 36)
    section(self.audioProfilePanel, 308, 148)
    place(self.audioProfilePanel.detail, 18, 36, available - 36, 26)
    self.audioProfilePanel.heading:SetWidth(available - 36 - #self.audioGameButtons * 112)
    for i, b in ipairs(self.audioGameButtons) do
        place(b, available - 18 - (#self.audioGameButtons - i + 1) * 112, 10, 104, 26)
    end
    local audioCols = math.max(4, math.floor((available - 36) / 140))
    local aw = (available - 36 - (audioCols - 1) * 8) / audioCols
    for i, event in ipairs(Games.Audio.events) do
        place(
            self.soundPreviewButtons[event],
            18 + ((i - 1) % audioCols) * (aw + 8),
            66 + math.floor((i - 1) / audioCols) * 30,
            aw,
            26
        )
    end
    local previewBottom = 66 + math.ceil(#Games.Audio.events / audioCols) * 30
    place(self.audioPreviewStatus, 18, previewBottom, available - 36, 16)
    self.audioProfilePanel:SetHeight(previewBottom + 22)
    self.optionsPages.audio:SetHeight(308 + previewBottom + 22)
    section(self.windowPanel, 0, 284)
    place(self.scaleTitle, 24, 88, available - 150, 28)
    self.scaleSlider:Layout(24, 146, available - 48)
    place(self.resetScale, 24, 218, 150, 32)
    place(self.scaleNote, 192, 218, available - 216, 48)
    section(self.effectsPanel, 292, 112)
    self.effectsSlider:Layout(18, 66, available - 36)
    self.optionsPages.window:SetHeight(404)
    for key, page in pairs(self.optionsPages) do
        page:SetShown(key == self.optionsTab)
    end
    self.optionsContent:SetHeight(self.optionsPages[self.optionsTab]:GetHeight())
end
function UI:RefreshOptions()
    if not self.windowPanel or self.refreshingOptions then
        return
    end
    self.refreshingOptions, self.optionsSync = true, true
    local s = Games:GetSettings()
    local token, id = Games:GetSelectedProfile()
    local class = Games.Profiles.byClass[token]
    local spec = Games.Profiles.bySpec[id]
    local profileName = (class and class.name or token) .. " / " .. (spec and spec.name or "No specialization yet")
    local profileIcon = spec and spec.icon or Games.IconPresets.FallbackIcons[token]
    if profileIcon then
        for _, b in ipairs({ self.graphicsChoices.class, self.audioChoices.class }) do
            if b.icon:SetTexture(profileIcon) == false then
                b.icon:SetTexture(Games.IconPresets.FallbackIcons[token] or Games.IconPresets.FallbackIcons.MAGE)
            end
            b.icon:SetVertexColor(1, 1, 1)
        end
    end
    for key, b in pairs(self.optionTabs) do
        Theme:Select(b, key == self.optionsTab)
    end
    for key, b in pairs(self.graphicsChoices) do
        Theme:Select(b, key == s.graphicsTheme)
    end
    for key, b in pairs(self.audioChoices) do
        Theme:Select(b, key == s.soundTheme)
    end
    local classes = {}
    for _, entry in ipairs(Games.Profiles.classes) do
        classes[#classes + 1] = {
            key = entry.token,
            name = entry.name,
            icon = Games.IconPresets.FallbackIcons[entry.token] or entry.specs[1] and entry.specs[1].icon,
        }
    end
    local specs = class and class.specs or {}
    self.specCount = #specs
    local choices = {}
    for i, entry in ipairs(specs) do
        choices[i] = { key = entry.id, name = entry.name, icon = entry.icon or Games.IconPresets.FallbackIcons[token] }
    end
    for _, p in ipairs(self.profilePanels) do
        local available = s[p.mode] == "class"
        local manual = available and not s.followCharacter
        p:SetAlpha(available and 1 or 0.42)
        p.heading.title:SetTextColor(unpack(available and Theme.Colors.accent or Theme.Colors.muted))
        p.followLabel:SetTextColor(unpack(available and Theme.Colors.text or Theme.Colors.muted))
        p.switch:SetText(s.followCharacter and "ON" or "OFF")
        Theme:Select(p.switch, s.followCharacter)
        if available then
            p.switch:Enable()
        else
            p.switch:Disable()
        end
        p.classDropdown:SetOptions(classes, token, manual)
        p.specDropdown:SetOptions(choices, id, manual)
    end
    for _, b in ipairs(self.previewGameButtons) do
        Theme:Select(b, b.gameID == self.previewGame)
    end
    for _, b in ipairs(self.audioGameButtons) do
        Theme:Select(b, b.gameID == self.previewGame)
    end
    for i, cell in ipairs(self.previewCells) do
        Games.Graphics:Paint(cell.icon, self.previewGame, i, Games.IconPresets.Colors[Games.IconPresets.Kinds[i]])
    end
    self.soundEnabledPanel.switch:SetText(s.soundsEnabled and "OFF" or "ON")
    Theme:Select(self.soundEnabledPanel.switch, not s.soundsEnabled)
    self.volumePanel:SetAlpha(s.soundsEnabled and 1 or 0.42)
    if s.soundsEnabled then
        self.volumeSlider:Enable()
    else
        self.volumeSlider:Disable()
    end
    self.volumeSlider:SetValue(math.floor(s.soundVolume * 100 + 0.5))
    self.effectsSlider:SetValue(s.effectsLevel)
    local entry, hasFiles
    for _, event in ipairs(Games.Audio.events) do
        local sound = Games.Audio:Resolve(self.previewGame, event)
        entry = entry or sound
        if sound and sound.file then
            hasFiles = true
        end
    end
    local supported = not hasFiles and Games.Audio:VolumeSupported(entry)
    self.volumePanel.detail:SetText(
        supported and "Independent game volume. WoW audio settings are unchanged. 0% silences every KIC Games effect."
            or (
                hasFiles
                    and "Spell effects use WoW Master volume. This slider controls supported SoundKits; use 0% or Mute to silence everything."
                or "Effects use WoW Master volume on this client. Use 0% or Mute to silence all KIC Games effects."
            )
    )
    self.audioProfilePanel.detail:SetText(
        (s.soundTheme == "class" and profileName or "Game-specific arcade effects")
            .. (
                s.soundTheme == "class"
                    and (Games.Audio.specs[id] and " / End sounds and unmapped events use arcade effects." or " / Spell audio pending: using game-specific arcade effects.")
                or ""
            )
    )
    for event, b in pairs(self.soundPreviewButtons) do
        if s.soundsEnabled and s.soundVolume > 0 and Games.Audio:Resolve(self.previewGame, event) then
            b:Enable()
        else
            b:Disable()
        end
    end
    self.scaleSlider:SetValue(math.floor(s.windowScale * 100 + 0.5))
    local actual = self.frame:GetScale()
    self.scaleNote:SetText(
        actual + 0.001 < s.windowScale
                and string.format(
                    "Screen fit: %d%% applied. Your %d%% preference is saved.",
                    math.floor(actual * 100 + 0.5),
                    math.floor(s.windowScale * 100 + 0.5)
                )
            or "100% is the default. Settings survive reload and relog."
    )
    self.optionsSync = false
    self:LayoutOptions()
    self.refreshingOptions = false
end
function UI:ShowOptions()
    self:OpenLauncher("options")
end
function UI:MaxWindowScale()
    return math.max(
        0.1,
        math.min(
            1.5,
            (UIParent:GetWidth() - 20) / self.frame:GetWidth(),
            (UIParent:GetHeight() - 20) / self.frame:GetHeight()
        )
    )
end
function UI:SetWindowScale(scale)
    if type(scale) ~= "number" or scale ~= scale then
        scale = 1
    end
    scale = math.max(0.75, math.min(1.5, math.floor(scale * 20 + 0.5) / 20))
    Games:GetSettings().windowScale = scale
    local applied = math.min(scale, self:MaxWindowScale())
    if Games.Bejeweled and Games.Bejeweled.drag then
        Games.Bejeweled:CancelDrag()
    end
    self.frame:SetScale(applied)
    self.frame:SetClampedToScreen(true)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    for _, f in ipairs(self.auxiliaryWindows or {}) do
        f:SetScale(applied)
    end
    self:RefreshOptions()
end
-- Internal responsive-layout hook retained for modules/tests, not a user setting.
function UI:SetWindowSize(width, height)
    width = type(width) == "number" and width == width and width or self.BASE_WIDTH
    height = type(height) == "number" and height == height and height or self.BASE_HEIGHT
    self.frame:SetSize(math.max(1000, math.min(1600, width)), math.max(700, math.min(1000, height)))
    self:LayoutLauncher()
end
function UI:ResetWindowSize()
    self.frame:SetSize(self.BASE_WIDTH, self.BASE_HEIGHT)
    self:SetWindowScale(1)
end
function UI:InitializeResize()
    -- Obsolete persisted dimensions are kept as data, not applied. No resize grip.
    self.frame:SetSize(self.BASE_WIDTH, self.BASE_HEIGHT)
    self:SetWindowScale(Games:GetSettings().windowScale)
    local events = CreateFrame("Frame")
    events:RegisterEvent("DISPLAY_SIZE_CHANGED")
    events:RegisterEvent("UI_SCALE_CHANGED")
    events:SetScript("OnEvent", function()
        self:SetWindowScale(Games:GetSettings().windowScale)
    end)
end
