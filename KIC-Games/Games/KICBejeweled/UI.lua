local _, Games = ...
local D, Theme = Games.KICBejeweled, Games.Theme
local E = D.Engine
for name, method in pairs(Games.BejeweledUI) do
    D[name] = method
end
D.heroArt, D.cardArt = "kic-bejeweled-hero", "kic-bejeweled-card"
D.displayTitle, D.titleSize = "KIC BEJEWELED", 24
D.taglineText = "MATCH / CASCADE / ASCEND"
D.resultName = "KICGamesKICBejeweledResult"
D.description =
    "Match gems and combine Bombs, Zaps and Orbs. Choose relaxed Normal play or Roguelike survival with Energy and power drafts when starting a run."
D.scoringTip = "Score restores Energy.\n0 energy ends the run."
D.instructionRows = {
    { "icon-gem", "Swap neighbors to match 3+." },
    { "icon-swap", "4: Bomb / 5+: Color Orb" },
    { "icon-cascade", "T or L: Lightning Gem" },
    { "icon-hint", "Swap specials to combine." },
    { "icon-infinity", "Fill Energy to choose new powers." },
}
function D:ExtendPieces()
    -- Copy the shared profile array before extending it; never modify spec data.
    local icons = {}
    for i = 1, 21 do
        local kind = E.Kind(i)
        icons[i] = self.icons[kind]
        self.Gems[i] = { color = Games.IconPresets.Colors[Games.IconPresets.Kinds[kind]] }
    end
    icons[E.Orb] = Games.Artwork["original-gem-5"].file
    self.Gems[E.Orb] = { color = { 0.9, 0.65, 1 } }
    self.icons = icons
end
local hot, cold = { 1, 0.8, 0.25 }, { 0.15, 0.8, 1 }
local circle = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local specialAssets = {
    bomb = Games.Artwork["special-bomb-overlay"].file,
    lightning = Games.Artwork["special-lightning-overlay"].file,
    orb = Games.Artwork["special-orb-overlay"].file,
}
local labelColors = {
    bomb = hot,
    lightning = cold,
    orb = { 0.95, 0.72, 1 },
}
local overlayScales = {
    bomb = 1.02,
    lightning = 1.03,
    orb = 1.08,
}
local overlayAlpha = {
    bomb = 0.96,
    lightning = 0.97,
    orb = 0.93,
}
local glowAlpha = {
    bomb = 0.36,
    lightning = 0.42,
    orb = 0.45,
}

-- Special gems keep the underlying class/spec icon. We layer a high-contrast
-- transparent overlay on top so Bomb, Zap and Orb stay readable regardless of
-- which spell icon is underneath.
function D:PaintSpecial(frame, piece)
    local special, art = E.Special(piece), frame.specialArt
    if not art and not special then
        return
    end
    if not art then
        art = {}
        frame.specialArt = art
        art.backdrop = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        art.backdrop:SetTexture(circle)
        art.backdrop:SetBlendMode("BLEND")
        art.glow = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        art.glow:SetBlendMode("ADD")
        art.overlay = frame:CreateTexture(nil, "OVERLAY", nil, 3)
        art.overlay:SetBlendMode("BLEND")
        art.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        art.label:SetPoint("BOTTOM", frame.icon, "BOTTOM", 0, -4)
        art.label:SetJustifyH("CENTER")
    end
    art.label:SetShown(special ~= nil)
    art.special = special
    if not special then
        art.backdrop:Hide()
        art.glow:Hide()
        art.overlay:Hide()
        return
    end

    local size = self.tileSize - 6
    art.opacity = self.drag
            and frame ~= self.dragFrame
            and self.cells[(self.drag.y - 1) * 8 + self.drag.x] == frame
            and 0.2
        or 1

    if art.builtSpecial ~= special or art.size ~= size then
        local texture = specialAssets[special]
        local scale = overlayScales[special] or 1
        local overlaySize = size * scale

        art.backdrop:ClearAllPoints()
        art.backdrop:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
        art.backdrop:SetSize(size * 0.78, size * 0.78)
        art.backdrop:SetVertexColor(0.01, 0.02, 0.05, 0.55)

        art.glow:ClearAllPoints()
        art.glow:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
        art.glow:SetSize(overlaySize, overlaySize)
        art.glow:SetTexture(texture)
        art.glow:SetVertexColor(1, 1, 1, 1)

        art.overlay:ClearAllPoints()
        art.overlay:SetPoint("CENTER", frame.icon, "CENTER", 0, 0)
        art.overlay:SetSize(overlaySize, overlaySize)
        art.overlay:SetTexture(texture)
        art.overlay:SetVertexColor(1, 1, 1, 1)

        art.builtSpecial, art.size = special, size
    end

    local color = labelColors[special]
    art.backdrop:Show()
    art.glow:Show()
    art.overlay:Show()
    art.backdrop:SetAlpha((special == "orb" and 0.10 or 0.16) * art.opacity)
    art.glow:SetAlpha((glowAlpha[special] or 0.4) * art.opacity * (art.pulse or 1))
    art.overlay:SetAlpha((overlayAlpha[special] or 0.95) * art.opacity)

    art.label:SetFont(Theme.Fonts.display, math.max(7, math.floor(size * 0.20)), "OUTLINE")
    art.label:SetText(special == "bomb" and "BOMB" or special == "lightning" and "ZAP" or "ORB")
    art.label:SetTextColor(color[1], color[2], color[3], 1)
    art.label:SetAlpha(art.opacity * 0.82)
end

-- Existing gameplay OnUpdate already stops when paused/hidden. Modulate only
-- the additive glow, so the special remains readable even with effects low/off.
local baseUpdate = D.UpdateMatchEffect
function D:UpdateMatchEffect(dt)
    baseUpdate(self, dt)
    self.markerTime = (self.markerTime or 0) + dt
    self.markerTick = (self.markerTick or 0) + dt
    if self.markerTick < 0.08 then
        return
    end
    self.markerTick = 0
    local level = Games:GetSettings().effectsLevel
    local pulse = level == 0 and 1 or 0.87 + (level == 2 and 0.30 or 0.12) * math.sin(self.markerTime * 3)
    for _, cell in ipairs(self.cells or {}) do
        local art = cell.specialArt
        if art and art.special then
            art.pulse = pulse
            if art.glow then
                art.glow:SetAlpha((glowAlpha[art.special] or 0.4) * art.opacity * pulse)
            end
        end
    end
end
function D:MatchSoundEvent()
    local p = self.model.plan
    local length = p and math.min(8, p.longest) or 3
    local tier = p and (p.events.orbCreate or p.events.orbActivate or p.events.combination or p.events.majorChain) and 5
        or p and (p.events.bombCreate or p.events.bombActivate or p.events.lightningCreate or p.events.lightningActivate) and 4
        or math.min(5, length)
    return "bejeweled_match_3", tier, math.max(tier, length)
end
local baseEffect = D.StartMatchEffect
function D:StartMatchEffect(tier, length, matched, cascade, points)
    baseEffect(self, tier, length, matched, cascade, points)
    if not self.matchEffect then
        return
    end
    local p = self.model.plan
    local e = p and p.events or {}
    local label = e.boardClear and "BOARD CLEAR!"
        or e.combination and "SPECIAL COMBO!"
        or e.majorChain and "CHAIN REACTION!"
        or e.orbCreate and "COLOR ORB!"
        or e.lightningCreate and "LIGHTNING!"
        or e.bombCreate and "BOMB!"
        or e.orbActivate and "COLOR SURGE!"
        or e.lightningActivate and "LIGHTNING STRIKE!"
        or e.bombActivate and "BOOM!"
    if label then
        self.effectBanner:SetText(label)
    end
end
