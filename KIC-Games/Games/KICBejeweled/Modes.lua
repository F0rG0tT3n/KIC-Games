local _, Games = ...
local D, Theme = Games.KICBejeweled, Games.Theme
local labels = { normal = "Normal", roguelike = "Roguelike" }
local white = "Interface\\Buttons\\WHITE8X8"

function D:GetMode()
    local saved = Games.DB and Games.DB[self.gameID]
    local mode = self.mode or (type(saved) == "table" and saved.lastMode)
    return labels[mode] and mode or "roguelike"
end
function D:ModeLabel()
    return labels[self:GetMode()]
end
function D:ShareTitle()
    return "KIC Bejeweled (" .. self:ModeLabel() .. ")"
end
function D:OnRunStarted()
    self:StopReshuffleAnimation()
    self.deferredReshuffle, self.mode, self.run = nil, nil, nil
    self.model.roguelite = nil
    self.choosingMode = true
    self.draftDim:Hide()
    self.message = "Choose Normal or Roguelike to start your run."
    self.tagline:SetText("CHOOSE YOUR MODE")
    self.tipText:SetText("Bombs, Zaps and Orbs in both modes.")
    self.instructions[5].text:SetText("Orb + gem clears its color.")
    local saved = Games.DB[self.gameID] or {}
    local normal = type(saved.best) == "table" and saved.best.score or 0
    local rush = type(saved.arcaneRush) == "table" and saved.arcaneRush.best
    self.modeCards.normal.record:SetText("Best: " .. tostring(normal or 0))
    self.modeCards.roguelike.record:SetText("Best: " .. tostring(type(rush) == "table" and rush.score or 0))
    self.modeDim:Show()
    self:LayoutUI()
end
function D:ChooseMode(mode)
    if not labels[mode] or not self.running or not self.choosingMode then return false end
    self.mode, self.choosingMode, self.paused = mode, false, false
    -- Initialize the selected record bucket, keeping the untimed best and
    -- the existing Arcane Rush best in their original SavedVariables fields.
    self:Storage()
    Games.DB[self.gameID].lastMode = mode
    if mode == "roguelike" then
        self.run = self.Roguelite.New()
        self.model.roguelite = self.run
        self.run.trackedMoves = self.model.moves
        self.message = "Score quickly to keep your Energy alive!"
        self.tagline:SetText("ROGUELIKE / MATCH / ASCEND")
        self.instructions[5].text:SetText("Fill Energy to choose new powers.")
    else
        self.run, self.model.roguelite = nil, nil
        self.message = "Normal mode: match gems and combine specials."
        self.tagline:SetText("NORMAL / MATCH / CASCADE")
        self.instructions[5].text:SetText("Orb + gem clears its color.")
        self.tipText:SetText("50 per gem + special bonuses.\nAll points x cascade.")
        self.tipPanel.buildDescription = nil
    end
    self.modeDim:Hide()
    self:LayoutUI()
    self:Render()
    Games.UI:Refresh()
    return true
end
function D:CreateModePicker()
    local dim = CreateFrame("Frame", nil, self.root, "BackdropTemplate")
    dim:SetAllPoints(self.root)
    dim:SetFrameLevel(self.root:GetFrameLevel() + 100)
    dim:EnableMouse(true)
    dim:SetBackdrop({ bgFile = white })
    dim:SetBackdropColor(0, 0.008, 0.024, 0.88)
    self.modeDim = dim
    local modal = Theme:PremiumFrame(dim, 650, 348, 0, 0)
    modal:ClearAllPoints()
    modal:SetPoint("CENTER", dim, "CENTER")
    self.modeWindow = modal
    local heading = Theme:Label(modal, "KIC BEJEWELED", 24, -20, 602, "GameFontNormalLarge")
    heading:SetJustifyH("CENTER")
    local subtitle = Theme:Label(modal, "Choose a mode for this run", 24, -52, 602)
    subtitle:SetJustifyH("CENTER")
    self.modeCards = {}
    for i, mode in ipairs({ "normal", "roguelike" }) do
        local card = Theme:Panel(modal, 288, 190, 26 + (i - 1) * 310, -90)
        local title = Theme:Label(card, string.upper(labels[mode]), 14, -14, 260, "GameFontNormalLarge")
        title:SetJustifyH("CENTER")
        local description = Theme:Label(card, mode == "normal"
            and "Bombs, Zaps and Orbs.\nNo timer, Energy, levels or cards.\nPlay until no moves remain."
            or "Keep Energy alive to survive.\nGain levels and draft powers.\nBuild upgrades for this run.", 14, -50, 260)
        description:SetHeight(64)
        description:SetJustifyH("CENTER")
        card.record = Theme:Label(card, "", 14, -120, 260, "GameFontHighlightSmall")
        card.record:SetJustifyH("CENTER")
        card.button = Theme:NeonButton(card, "PLAY " .. string.upper(labels[mode]), 240, 24, -146,
            function() self:ChooseMode(mode) end, 30, true)
        self.modeCards[mode] = card
    end
    self.modeCancel = Theme:NeonButton(modal, "Back to Launcher", 210, 220, -300, function()
        Games:AbortGame()
        Games.UI:OpenLauncher("home")
    end, 28, false)
    dim:Hide()
end
