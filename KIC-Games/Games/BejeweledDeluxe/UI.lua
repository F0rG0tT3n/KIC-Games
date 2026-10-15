local _, Games = ...
local D, Theme = Games.BejeweledDeluxe, Games.Theme
local E = D.Engine
for name, method in pairs(Games.BejeweledUI) do
    D[name] = method
end
D.heroArt, D.cardArt = "bejeweled-deluxe-hero", "bejeweled-deluxe-card"
D.displayTitle, D.titleSize = "BEJEWELED DELUXE", 20
D.resultName = "KICGamesBejeweledDeluxeResult"
D.description =
    "Create Bombs with four, Color Orbs with five, and Lightning with T/L matches. Combine specials for huge chains. No time limit."
D.scoringTip = "50 per gem + special bonuses.\nAll points x cascade."
D.instructionRows = {
    { "icon-gem", "Swap neighbors to match 3+." },
    { "icon-swap", "4: Bomb / 5+: Color Orb" },
    { "icon-cascade", "T or L: Lightning Gem" },
    { "icon-hint", "Swap specials to combine." },
    { "icon-infinity", "Orb + gem clears its color." },
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
local rainbow = {
    { 1, 0.18, 0.12 },
    { 1, 0.65, 0.1 },
    { 1, 1, 0.2 },
    { 0.25, 1, 0.4 },
    { 0.2, 0.85, 1 },
    { 0.35, 0.35, 1 },
    { 1, 0.3, 0.9 },
}
-- Thin corner rails and a small badge leave the center of every icon untouched.
-- Anchoring to the icon keeps the marker attached during swaps, falls and drags.
function D:PaintSpecial(frame, piece)
    local special = E.Special(piece)
    local art = frame.deluxeArt
    if not art and not special then
        return
    end
    if not art then
        art = { parts = {} }
        frame.deluxeArt = art
        for i = 1, 8 do
            art.parts[i] = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        end
        art.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        art.label:SetPoint("BOTTOM", frame.icon, "BOTTOM", 0, -4)
        art.label:SetJustifyH("CENTER")
    end
    art.label:SetShown(special ~= nil)
    for _, t in ipairs(art.parts) do
        t:Hide()
    end
    if not special then
        return
    end
    local size = self.tileSize - 10
    local color = special == "bomb" and { 1, 0.48, 0.08 }
        or special == "lightning" and { 0.25, 0.85, 1 }
        or { 0.9, 0.6, 1 }
    art.label:SetFont(Theme.Fonts.display, math.max(7, math.floor(size * 0.20)), "OUTLINE")
    art.label:SetText(special == "bomb" and "BOMB" or special == "lightning" and "ZAP" or "ORB")
    art.label:SetTextColor(color[1], color[2], color[3], 1)
    local alpha = self.drag
            and frame ~= self.dragFrame
            and self.cells[(self.drag.y - 1) * 8 + self.drag.x] == frame
            and 0.2
        or 1
    for i, t in ipairs(art.parts) do
        local corner = math.floor((i - 1) / 2)
        local sx, sy = corner % 2 == 0 and -1 or 1, corner < 2 and 1 or -1
        local horizontal = i % 2 == 1
        local c = special == "orb" and rainbow[(i - 1) % 7 + 1] or color
        t:ClearAllPoints()
        t:SetPoint(
            "CENTER",
            frame.icon,
            "CENTER",
            sx * size * (horizontal and 0.36 or 0.5),
            sy * size * (horizontal and 0.5 or 0.36)
        )
        t:SetSize(horizontal and size * 0.32 or 1.5, horizontal and 1.5 or size * 0.32)
        t:SetColorTexture(c[1], c[2], c[3], 1)
        t:SetAlpha(alpha)
        t:Show()
    end
    art.label:SetAlpha(alpha)
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
