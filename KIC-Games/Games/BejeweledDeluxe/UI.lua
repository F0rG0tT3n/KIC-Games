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
local warm, hot, cold, white = { 1, 0.38, 0.04 }, { 1, 0.8, 0.25 }, { 0.15, 0.8, 1 }, { 0.9, 1, 1 }
local ink = { 0.025, 0.035, 0.07 }
local circle = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Native, pooled icon-relative geometry: no artwork replacement, input frame,
-- gameplay randomness or timers. Only compact emblems cover the icon center.
function D:PaintSpecial(frame, piece)
    local special, art = E.Special(piece), frame.deluxeArt
    if not art and not special then
        return
    end
    if not art then
        art = { parts = {}, pulseParts = {} }
        frame.deluxeArt = art
        art.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        art.label:SetPoint("BOTTOM", frame.icon, "BOTTOM", 0, -4)
        art.label:SetJustifyH("CENTER")
    end
    art.label:SetShown(special ~= nil)
    art.special = special
    if not special then
        for _, t in ipairs(art.parts) do
            t:Hide()
        end
        return
    end
    local size = self.tileSize - 10
    art.opacity = self.drag
            and frame ~= self.dragFrame
            and self.cells[(self.drag.y - 1) * 8 + self.drag.x] == frame
            and 0.2
        or 1
    -- Geometry is cached until the piece type or tile dimensions change. During
    -- animation the icon anchor moves; only opacity needs updating here.
    if art.builtSpecial ~= special or art.size ~= size then
        art.used, art.pulseParts = 0, {}
        local function shape(x, y, w, h, rotation, color, alpha, texture, pulse)
            art.used = art.used + 1
            local t = art.parts[art.used]
            if not t then
                t = frame:CreateTexture(nil, "OVERLAY", nil, 2)
                art.parts[art.used] = t
            end
            t:ClearAllPoints()
            t:SetPoint("CENTER", frame.icon, "CENTER", x * size, y * size)
            t:SetSize(w * size, h * size)
            t:SetRotation(rotation or 0)
            if texture then
                t:SetTexture(texture)
                t:SetVertexColor(color[1], color[2], color[3], 1)
            else
                t:SetColorTexture(color[1], color[2], color[3], 1)
                t:SetVertexColor(1, 1, 1, 1)
            end
            t:SetBlendMode(pulse and "ADD" or "BLEND")
            t.markerAlpha = alpha or 1
            if pulse then
                art.pulseParts[#art.pulseParts + 1] = t
            end
            return t
        end
        local function line(x1, y1, x2, y2, width, color, glow)
            local dx, dy = x2 - x1, y2 - y1
            local length = math.sqrt(dx * dx + dy * dy)
            local angle = math.atan2(dy, dx)
            if glow then
                shape((x1 + x2) / 2, (y1 + y2) / 2, length, width * 3, angle, color, 0.2, nil, true)
            end
            shape((x1 + x2) / 2, (y1 + y2) / 2, length, width, angle, color)
        end
        local function ring(radius, segments, width, color, glow, ratio)
            for i = 1, segments do
                local a, b = (i - 1) * math.pi * 2 / segments, i * math.pi * 2 / segments
                local c = color or rainbow[math.floor((i - 1) * 7 / segments) + 1]
                line(
                    math.cos(a) * radius,
                    math.sin(a) * radius * (ratio or 1),
                    math.cos(b) * radius,
                    math.sin(b) * radius * (ratio or 1),
                    width,
                    c,
                    glow
                )
            end
        end
        if special == "bomb" then
            -- Heavy clipped-corner armor and inward hazard teeth; warm explosive
            -- silhouette stays different from the Orb's smooth full-size halo.
            local points = {
                { -0.32, 0.51 },
                { 0.32, 0.51 },
                { 0.51, 0.32 },
                { 0.51, -0.32 },
                { 0.32, -0.51 },
                { -0.32, -0.51 },
                { -0.51, -0.32 },
                { -0.51, 0.32 },
            }
            for i, p in ipairs(points) do
                local q = points[i % #points + 1]
                line(p[1], p[2], q[1], q[2], 0.055, i % 2 == 0 and hot or warm, true)
            end
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    line(sx * 0.45, sy * 0.31, sx * 0.31, sy * 0.45, 0.045, hot)
                end
            end
            -- A dark circular bomb body, bright rim and lit diagonal fuse read
            -- against both pale gems and busy spell textures without a word.
            shape(0, 0, 0.28, 0.28, 0, ink, 0.86, circle)
            ring(0.15, 12, 0.035, hot)
            line(0.08, 0.12, 0.15, 0.21, 0.065, ink)
            line(0.08, 0.12, 0.15, 0.21, 0.035, hot, true)
            line(0.12, 0.25, 0.22, 0.25, 0.035, hot, true)
            line(0.17, 0.2, 0.17, 0.3, 0.035, hot)
            shape(-0.04, 0.04, 0.055, 0.055, 0, hot, 0.9, circle)
        elseif special == "lightning" then
            -- Open, razor-sharp brackets plus cardinal terminals suggest a
            -- cross-line clear. The dark keyline separates the white bolt from
            -- bright class icons; the energized core occupies a narrow strip.
            for _, sx in ipairs({ -1, 1 }) do
                for _, sy in ipairs({ -1, 1 }) do
                    line(sx * 0.28, sy * 0.5, sx * 0.5, sy * 0.5, 0.035, cold, true)
                    line(sx * 0.5, sy * 0.5, sx * 0.5, sy * 0.28, 0.035, cold, true)
                end
            end
            for i = 0, 3 do
                local a = i * math.pi / 2
                shape(math.cos(a) * 0.5, math.sin(a) * 0.5, 0.10, 0.10, math.pi / 4, white)
            end
            local bolt = { { 0.08, 0.26 }, { -0.12, -0.01 }, { 0.13, 0.04 }, { -0.08, -0.26 } }
            for i = 1, 3 do
                local a, b = bolt[i], bolt[i + 1]
                line(a[1], a[2], b[1], b[2], 0.13, ink)
            end
            for i = 1, 3 do
                local a, b = bolt[i], bolt[i + 1]
                line(a[1], a[2], b[1], b[2], 0.065, white, true)
            end
        else
            -- Full circular rainbow halo, elliptical orbit and a prismatic
            -- center: visually spherical, unlike either armored Bomb or bolt.
            ring(0.49, 20, 0.045, nil, true)
            ring(0.34, 12, 0.018, nil, false, 0.58)
            shape(0, 0, 0.30, 0.30, 0, { 0.4, 0.2, 0.9 }, 0.3, circle, true)
            shape(0, 0, 0.18, 0.18, math.pi / 4, ink)
            shape(0, 0, 0.12, 0.12, math.pi / 4, white)
            line(-0.11, 0, 0.11, 0, 0.025, white)
            line(0, -0.11, 0, 0.11, 0.025, white)
            shape(-0.27, 0.31, 0.08, 0.08, math.pi / 4, white)
        end
        art.builtSpecial, art.size = special, size
    end
    for i, t in ipairs(art.parts) do
        t:SetShown(i <= art.used)
        t:SetAlpha(t.markerAlpha * art.opacity)
    end
    local color = special == "bomb" and hot or special == "lightning" and cold or { 0.9, 0.6, 1 }
    art.label:SetFont(Theme.Fonts.display, math.max(7, math.floor(size * 0.20)), "OUTLINE")
    art.label:SetText(special == "bomb" and "BOMB" or special == "lightning" and "ZAP" or "ORB")
    art.label:SetTextColor(color[1], color[2], color[3], 1)
    art.label:SetAlpha(art.opacity * 0.8)
end

-- Existing gameplay OnUpdate already stops when paused/hidden. Modulate only
-- glow opacity at 12.5 Hz; silhouette and emblems remain fully readable with
-- effects Off, without motion, or with labels hidden.
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
    local pulse = level == 0 and 1 or 0.85 + (level == 2 and 0.3 or 0.12) * math.sin(self.markerTime * 3)
    for _, cell in ipairs(self.cells or {}) do
        local art = cell.deluxeArt
        if art and art.special then
            for _, t in ipairs(art.pulseParts) do
                t:SetAlpha(t.markerAlpha * art.opacity * pulse)
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
