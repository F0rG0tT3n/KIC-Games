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
    b.icon = Theme:Art(b, icon, 52, 52, 14, -17, 1, "ARTWORK")
    b.title = label(b, title, 17)
    b.detail = label(b, detail, 12, Theme.Colors.muted)
    b:SetScript("OnSizeChanged", function()
        place(b.title, 80, 16, b:GetWidth() - 96, 24)
        place(b.detail, 80, 44, b:GetWidth() - 96, 32)
    end)
    return b
end
local function toggle(parent, title, detail, callback)
    local p = panel(parent, title, detail)
    p.switch = Theme:NeonButton(p, "OFF", 82, 0, 0, callback, 30)
    return p
end
function Theme:SettingsSlider(parent, minimum, maximum, step, callback)
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
        f.valueLabel:SetText(value .. "%")
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
    self.followPanel = toggle(
        g,
        "FOLLOW MY CHARACTER",
        "Use my current class and specialization. Manual choices are remembered.",
        function()
            Games:SetOption("followCharacter", not Games:GetSettings().followCharacter)
        end
    )
    self.appearancePanel = panel(g, "CLASS", "Choose any class for graphics and specialization sounds.")
    self.classButtons = {}
    for _, class in ipairs(Games.Profiles.classes) do
        local token = class.token
        local b = Theme:NeonButton(self.appearancePanel, class.name, 130, 0, 0, function()
            Games:SetManualClass(token)
        end, 54)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(28, 28)
        b.icon:SetPoint("LEFT", 10, 0)
        b.icon:SetTexture(
            Games.IconPresets.FallbackIcons[token]
                or class.specs[1] and class.specs[1].icon
                or Games.IconPresets.FallbackIcons.MAGE
        )
        b.caption:ClearAllPoints()
        b.caption:SetPoint("LEFT", 46, 0)
        b.caption:SetJustifyH("LEFT")
        b.caption:SetFont(Theme.Fonts.body, 12, "")
        b.caption:SetMaxLines(2)
        b.caption:SetHeight(34)
        self.classButtons[token] = b
    end
    self.specPanel = panel(g, "SPECIALIZATION", "")
    self.specButtons = {}
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
    self.soundEnabledPanel = toggle(
        a,
        "ENABLE GAME SOUNDS",
        "Turn off to stop all KIC Games effects immediately.",
        function()
            Games:SetOption("soundsEnabled", not Games:GetSettings().soundsEnabled)
        end
    )
    self.volumePanel = panel(a, "GAME SOUND VOLUME", "")
    self.volumeSlider = Theme:SettingsSlider(self.volumePanel, 0, 100, 1, function(value)
        Games:SetOption("soundVolume", value / 100)
    end)
    self.audioProfilePanel = panel(a, "SOUND PREVIEW", "")
    self.audioProfileLink = Theme:NeonButton(self.audioProfilePanel, "Choose class / spec", 172, 0, 0, function()
        self:SelectOptionsTab("graphics")
    end, 28)
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
    f:Hide()
    self:RefreshOptions()
end
function UI:SelectOptionsTab(key)
    if not self.optionsPages[key] then
        return
    end
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
    place(self.optionsSubtitle, 0, 38, width - 8, 20)
    local tabW = math.min(180, (available - 16) / 3)
    for i, key in ipairs({ "graphics", "audio", "window" }) do
        place(self.optionTabs[key], (i - 1) * (tabW + 8), 68, tabW, 34)
    end
    place(self.optionsScroll, 0, 116, width, height - 116)
    self.optionsContent:SetWidth(available)
    for _, page in pairs(self.optionsPages) do
        page:SetSize(available, 1)
        place(page, 0, 0)
    end
    local function section(f, y, h)
        place(f, 0, y, available, h)
        f.heading:SetWidth(available - 36)
        place(f.detail, 18, 46, available - 36, 34)
    end
    local half = (available - 12) / 2
    place(self.graphicsChoices.original, 0, 0, half, 94)
    place(self.graphicsChoices.class, half + 12, 0, half, 94)
    section(self.followPanel, 108, 86)
    place(self.followPanel.switch, available - 104, 16, 86, 30)
    self.followPanel.heading:SetWidth(available - 140)
    local columns = math.max(2, math.floor((available - 36) / 132))
    local cw = (available - 36 - (columns - 1) * 8) / columns
    local classH = 90 + math.ceil(#Games.Profiles.classes / columns) * 62
    section(self.appearancePanel, 208, classH)
    for i, class in ipairs(Games.Profiles.classes) do
        local b = self.classButtons[class.token]
        place(b, 18 + ((i - 1) % columns) * (cw + 8), 80 + math.floor((i - 1) / columns) * 62, cw, 54)
        b.caption:SetWidth(cw - 54)
    end
    local specY = 208 + classH + 14
    local specColumns = math.max(1, math.floor((available - 36) / 180))
    local sw = (available - 36 - (specColumns - 1) * 8) / specColumns
    local specH = 90 + math.ceil((self.specCount or 0) / specColumns) * 60
    section(self.specPanel, specY, specH)
    for i, b in ipairs(self.specButtons) do
        place(b, 18 + ((i - 1) % specColumns) * (sw + 8), 80 + math.floor((i - 1) / specColumns) * 60, sw, 52)
        b.caption:SetWidth(sw - 54)
    end
    local previewY = specY + specH + 14
    section(self.graphicsPreview, previewY, 220)
    for i, b in ipairs(self.previewGameButtons) do
        place(b, 18 + (i - 1) * 130, 86, 120, 28)
    end
    local cellSize = math.min(64, math.floor((available - 36 - 5 * 10) / 6))
    for i, cell in ipairs(self.previewCells) do
        place(cell, 18 + (i - 1) * (cellSize + 10), 136, cellSize, cellSize)
        cell.icon:SetSize(cellSize - 10, cellSize - 10)
    end
    self.optionsPages.graphics:SetHeight(previewY + 220)
    place(self.audioChoices.arcade, 0, 0, half, 94)
    place(self.audioChoices.class, half + 12, 0, half, 94)
    section(self.soundEnabledPanel, 108, 86)
    place(self.soundEnabledPanel.switch, available - 104, 16, 86, 30)
    self.soundEnabledPanel.heading:SetWidth(available - 140)
    section(self.volumePanel, 208, 200)
    place(self.volumePanel.detail, 18, 132, available - 36, 52)
    self.volumeSlider:Layout(24, 88, available - 48)
    section(self.audioProfilePanel, 422, 300)
    place(self.audioProfilePanel.detail, 18, 48, available - 36, 42)
    place(self.audioProfileLink, available - 190, 12, 172, 28)
    self.audioProfilePanel.heading:SetWidth(available - 226)
    for i, b in ipairs(self.audioGameButtons) do
        place(b, 18 + (i - 1) * 130, 100, 120, 28)
    end
    local audioCols = math.max(2, math.floor((available - 36) / 150))
    local aw = (available - 36 - (audioCols - 1) * 8) / audioCols
    for i, event in ipairs(Games.Audio.events) do
        place(
            self.soundPreviewButtons[event],
            18 + ((i - 1) % audioCols) * (aw + 8),
            146 + math.floor((i - 1) / audioCols) * 42,
            aw,
            32
        )
    end
    local previewBottom = 146 + math.ceil(#Games.Audio.events / audioCols) * 42
    place(self.audioPreviewStatus, 18, previewBottom + 12, available - 36, 32)
    self.audioProfilePanel:SetHeight(previewBottom + 56)
    self.optionsPages.audio:SetHeight(422 + previewBottom + 56)
    section(self.windowPanel, 0, 284)
    place(self.scaleTitle, 24, 88, available - 150, 28)
    self.scaleSlider:Layout(24, 146, available - 48)
    place(self.resetScale, 24, 218, 150, 32)
    place(self.scaleNote, 192, 218, available - 216, 48)
    self.optionsPages.window:SetHeight(284)
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
    self.followPanel.switch:SetText(s.followCharacter and "ON" or "OFF")
    Theme:Select(self.followPanel.switch, s.followCharacter)
    self.followPanel.detail:SetText(
        s.followCharacter and ("Following " .. profileName .. ". Manual selection is disabled.")
            or "Choose any class/spec. Your manual selection is saved when following your character."
    )
    for key, b in pairs(self.classButtons) do
        Theme:Select(b, key == token)
        b.icon:SetAlpha(s.followCharacter and 0.4 or 1)
        if s.followCharacter then
            b:Disable()
        else
            b:Enable()
        end
    end
    local specs = class and class.specs or {}
    self.specCount = #specs
    self.specPanel.detail:SetText(profileName)
    for i, entry in ipairs(specs) do
        local b = self.specButtons[i]
        if not b then
            b = Theme:NeonButton(self.specPanel, "", 180, 0, 0, function() end, 52)
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("LEFT", 10, 0)
            b.icon:SetSize(28, 28)
            b.caption:ClearAllPoints()
            b.caption:SetPoint("LEFT", 46, 0)
            b.caption:SetJustifyH("LEFT")
            b.caption:SetFont(Theme.Fonts.body, 12, "")
            b.caption:SetMaxLines(2)
            b.caption:SetHeight(34)
            self.specButtons[i] = b
        end
        local sid = entry.id
        b.specID = sid
        b:SetText(entry.name)
        local fallbackIcon = Games.IconPresets.FallbackIcons[token] or Games.IconPresets.FallbackIcons.MAGE
        if b.icon:SetTexture(entry.icon or fallbackIcon) == false then
            b.icon:SetTexture(fallbackIcon)
        end
        b:SetScript("OnClick", function()
            Games:SetManualSpec(sid)
        end)
        b:Show()
        b.icon:SetAlpha(s.followCharacter and 0.4 or 1)
        Theme:Select(b, sid == id)
        if s.followCharacter then
            b:Disable()
        else
            b:Enable()
        end
    end
    for i = #specs + 1, #self.specButtons do
        self.specButtons[i]:Hide()
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
    self.soundEnabledPanel.switch:SetText(s.soundsEnabled and "ON" or "OFF")
    Theme:Select(self.soundEnabledPanel.switch, s.soundsEnabled)
    self.volumeSlider:SetValue(math.floor(s.soundVolume * 100 + 0.5))
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
                    and "Spell effects follow WoW SFX volume. This slider controls arcade effects; use 0% or Off to mute everything."
                or "This client controls effects through WoW SFX volume. Use 0% or Off to mute all KIC Games effects."
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
