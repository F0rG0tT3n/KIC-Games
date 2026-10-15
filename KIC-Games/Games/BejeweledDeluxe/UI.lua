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
-- Overlays anchor to the animated icon, so swaps, drops, hint bounces and the
-- drag ghost all keep their special identity at every interface scale.
function D:PaintSpecial(frame, piece)
    local special = E.Special(piece)
    local art = frame.deluxeArt
    if not art and not special then
        return
    end
    if not art then
        art = { parts = {} }
        frame.deluxeArt = art
        art.glow = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        art.glow:SetAllPoints(frame.icon)
        art.glow:SetBlendMode("ADD")
        for i = 1, 7 do
            art.parts[i] = frame:CreateTexture(nil, "OVERLAY", nil, 2)
        end
        art.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        art.label:SetPoint("BOTTOM", frame.icon, "BOTTOM", 0, 0)
        art.label:SetJustifyH("CENTER")
    end
    art.glow:SetShown(special ~= nil)
    art.label:SetShown(special ~= nil)
    for _, t in ipairs(art.parts) do
        t:Hide()
    end
    if not special then
        return
    end
    local size = self.tileSize - 10
    local color = special == "bomb" and { 1, 0.22, 0.02 }
        or special == "lightning" and { 0.1, 0.7, 1 }
        or { 0.65, 0.3, 1 }
    -- Blizzard's native circular alpha texture gives the energy glow a round
    -- silhouette without adding or regenerating any artwork assets.
    art.glow:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    art.glow:SetVertexColor(color[1], color[2], color[3], 0.4)
    art.label:SetFont(Theme.Fonts.display, math.max(7, math.floor(size * 0.22)), "OUTLINE")
    art.label:SetText(special == "bomb" and "BOMB" or special == "lightning" and "ZAP" or "ORB")
    art.label:SetTextColor(1, 1, 1, 1)
    local function part(i, x, y, w, h, r, g, b, rotation, texture)
        local t = art.parts[i]
        t:ClearAllPoints()
        t:SetPoint("CENTER", frame.icon, "CENTER", x * size, y * size)
        t:SetSize(w * size, h * size)
        if texture then
            t:SetTexture(texture)
            t:SetVertexColor(r, g, b, 1)
        else
            t:SetColorTexture(r, g, b, 1)
            t:SetVertexColor(1, 1, 1, 1)
        end
        t:SetRotation(rotation or 0)
        t:Show()
    end
    if special == "bomb" then
        -- Layered flame diamonds and a bright fuse leave the spell icon visible.
        part(1, 0.29, 0.25, 0.30, 0.38, 1, 0.12, 0.01, 0.4)
        part(2, 0.29, 0.28, 0.17, 0.31, 1, 0.6, 0.02, 0.4)
        part(3, 0.29, 0.3, 0.08, 0.21, 1, 1, 0.65, 0.4)
    elseif special == "lightning" then
        -- A three-stroke electric bolt, readable on every class/spec icon.
        part(1, 0.23, 0.27, 0.10, 0.40, 0.75, 1, 1, -0.6)
        part(2, 0.26, 0.10, 0.28, 0.10, 1, 1, 1, 0)
        part(3, 0.30, -0.07, 0.10, 0.40, 0.75, 1, 1, -0.6)
    else
        -- Seven colored facets form a luminous energy sphere; no normal color.
        for i, c in ipairs(rainbow) do
            local angle = (i - 1) * math.pi * 2 / 7
            part(
                i,
                math.cos(angle) * 0.25,
                math.sin(angle) * 0.25,
                0.47,
                0.47,
                c[1],
                c[2],
                c[3],
                angle,
                Games.Artwork["original-gem-" .. i].file
            )
        end
    end
    local alpha = self.drag
            and frame ~= self.dragFrame
            and self.cells[(self.drag.y - 1) * 8 + self.drag.x] == frame
            and 0.2
        or 1
    art.glow:SetAlpha(alpha)
    art.label:SetAlpha(alpha)
    for _, t in ipairs(art.parts) do
        t:SetAlpha(alpha)
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
