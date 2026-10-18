local _, Games = ...
local D = Games.KICBejeweled
local baseStart, baseUpdate, baseClear = D.StartMatchEffect, D.UpdateMatchEffect, D.ClearMatchEffect
local fire, gold, ice, violet = { 1, 0.22, 0.03 }, { 1, 0.75, 0.2 }, { 0.2, 0.75, 1 }, { 0.7, 0.35, 1 }
local MAX_TEXTURES = 1024

function D:GetClearDuration()
    if Games:GetSettings().effectsLevel == 0 then
        return 0.3
    end
    local events = self.model.plan and self.model.plan.events or {}
    return events.orbActivate and 0.85 or events.lightningActivate and 0.6 or events.bombActivate and 0.65 or 0.3
end

function D:ClearMatchEffect()
    baseClear(self)
    self.specialEffect = nil
    for _, texture in ipairs(self.specialTextures or {}) do
        texture:Hide()
    end
end

-- Recycled native textures, no timers or random calls. Positions are board-cell
-- coordinates and inherit the viewport's scale and clipping, including edges.
function D:EffectStroke(x1, y1, x2, y2, width, color, alpha)
    if alpha <= 0 then
        return
    end
    local dx, dy = (x2 - x1) * self.step, -(y2 - y1) * self.step
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.1 then
        return
    end
    self.specialTextures = self.specialTextures or {}
    for layer = 1, 2 do
        local index = self.specialTextureCount + 1
        if index > MAX_TEXTURES then
            return
        end
        self.specialTextureCount = index
        local t = self.specialTextures[index]
        if not t then
            t = self.effectLayer:CreateTexture(nil, "OVERLAY", nil, 3)
            t:SetBlendMode("ADD")
            self.specialTextures[index] = t
        end
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.viewport, "TOPLEFT", (x1 + x2) * self.step / 2, -(y1 + y2) * self.step / 2)
        t:SetSize(length, math.max(1, width * self.step * (layer == 1 and 3.5 or 1)))
        t:SetRotation(math.atan2(dy, dx))
        if layer == 1 then
            t:SetColorTexture(color[1], color[2], color[3], 1)
        elseif color == fire or color == gold then
            t:SetColorTexture(1, color == fire and 0.55 or 0.9, 0.12, 1)
        else
            t:SetColorTexture(0.8 + color[1] * 0.2, 0.8 + color[2] * 0.2, 0.8 + color[3] * 0.2, 1)
        end
        t:SetAlpha(alpha * (layer == 1 and 0.25 or 0.9))
        t:Show()
    end
end

function D:EffectBolt(x1, y1, x2, y2, seed, reveal, color, alpha, segments)
    local dx, dy = x2 - x1, y2 - y1
    local distance = math.max(0.01, math.sqrt(dx * dx + dy * dy))
    local px, py = x1, y1
    for i = 1, segments do
        local progress = i / segments
        local jitter = i < segments and math.sin(seed * 7.3 + i * 19.1) * math.min(0.24, distance * 0.09) or 0
        local x, y = x1 + dx * progress - dy / distance * jitter, y1 + dy * progress + dx / distance * jitter
        local visible = math.max(0, math.min(1, reveal * segments - (i - 1)))
        if visible > 0 then
            self:EffectStroke(px, py, px + (x - px) * visible, py + (y - py) * visible, 0.035, color, alpha)
        end
        px, py = x, y
    end
end

function D:StartMatchEffect(tier, length, matched, cascade, points)
    baseStart(self, tier, length, matched, cascade, points)
    local p, level = self.model.plan, Games:GetSettings().effectsLevel
    if not p or level == 0 or not self.matchEffect then
        return
    end
    if not (p.events.bombActivate or p.events.lightningActivate or p.events.orbActivate) then
        return
    end
    local effect = {
        time = 0,
        duration = self:GetClearDuration() + 0.2,
        level = level,
        bombs = {},
        rows = {},
        columns = {},
        targets = {},
    }
    -- Stable ordering also makes effects reproducible without touching game RNG.
    for id = 1, 64 do
        if p.orbTargets[id] then
            effect.targets[#effect.targets + 1] =
                { x = (id - 1) % 8 + 0.5, y = math.floor((id - 1) / 8) + 0.5, id = id }
        end
    end
    for _, blast in ipairs(p.blasts) do
        if blast.kind == "bomb" then
            if #effect.bombs < (level == 2 and 6 or 3) then
                effect.bombs[#effect.bombs + 1] = blast
            end
        else
            for offset = -blast.radius, blast.radius do
                local row, column = blast.y + offset, blast.x + offset
                if row >= 1 and row <= 8 then
                    effect.rows[row] = blast.x - 0.5
                end
                if column >= 1 and column <= 8 then
                    effect.columns[column] = blast.y - 0.5
                end
            end
        end
    end
    self.specialEffect = effect
    self:UpdateSpecialEffect(0)
    self.effectFlash:SetAlpha(0)
    for _, c in ipairs(self.cells) do
        c.spark:SetAlpha(0)
    end
    for _, particle in ipairs(self.effectParticles) do
        particle:Hide()
    end
end

function D:UpdateSpecialEffect(dt)
    local e = self.specialEffect
    if not e then
        return
    end
    e.time = e.time + dt
    self.specialTextureCount = 0
    local strength = e.level == 2 and 1 or 0.4
    local fade = math.max(0, 1 - e.time / e.duration)
    -- A descending, branched storm strikes every Orb target, including all 64
    -- cells for Orb + Orb. Bolts land before the clear commits, then leave trails.
    for _, target in ipairs(e.targets) do
        local delay = (target.id * 13 % 17) * 0.004
        local age = math.max(0, e.time - delay)
        local reveal = math.min(1, age / 0.24)
        local flicker = 0.65 + 0.35 * math.abs(math.sin(age * 24 + target.id))
        local origin = math.max(0.1, math.min(7.9, target.x + math.sin(target.id * 4.1) * 0.65))
        self:EffectBolt(
            origin,
            0,
            target.x,
            target.y,
            target.id,
            reveal,
            target.id % 2 == 0 and ice or violet,
            fade * strength * flicker,
            e.level == 2 and 4 or 3
        )
        if reveal == 1 and age < 0.55 then
            local r = 0.09 + (age - 0.24) * 0.5
            self:EffectStroke(target.x - r, target.y, target.x + r, target.y, 0.05, ice, fade * strength)
        end
    end
    -- Electric discharges propagate across the exact rows and columns affected
    -- by Lightning, including the wider crosses from special combinations.
    local reveal = math.min(1, e.time / 0.22)
    local flicker = 0.65 + 0.35 * math.abs(math.sin(e.time * 32))
    for i = 1, 8 do
        if e.rows[i] then
            local x, y = e.rows[i], i - 0.5
            self:EffectBolt(x, y, 0, y, i, reveal, ice, fade * strength * flicker, 4)
            self:EffectBolt(x, y, 8, y, i + 8, reveal, ice, fade * strength * flicker, 4)
        end
        if e.columns[i] then
            local x, y = i - 0.5, e.columns[i]
            self:EffectBolt(x, y, x, 0, i + 16, reveal, ice, fade * strength * flicker, 4)
            self:EffectBolt(x, y, x, 8, i + 24, reveal, ice, fade * strength * flicker, 4)
        end
    end
    -- Expanding orange shockwave plus outward-moving hot debris. No opaque
    -- screen-sized fill: the board remains visible behind every special effect.
    for index, bomb in ipairs(e.bombs) do
        local age = math.max(0, e.time - (index - 1) * 0.025)
        local progress = math.min(1, age / 0.5)
        local radius = (bomb.radius + 0.5) * (0.12 + 0.88 * (1 - (1 - progress) ^ 2))
        local x, y = bomb.x - 0.5, bomb.y - 0.5
        local segments = e.level == 2 and 12 or 8
        for i = 1, segments do
            local a, b = (i - 1) * 2 * math.pi / segments, i * 2 * math.pi / segments
            self:EffectStroke(
                x + math.cos(a) * radius,
                y + math.sin(a) * radius,
                x + math.cos(b) * radius,
                y + math.sin(b) * radius,
                0.06 * (1 - progress) + 0.015,
                fire,
                fade * strength
            )
        end
        for i = 1, 8 do
            local angle = i * math.pi / 4 + index * 0.3
            local inner, outer = radius * 0.65, radius * (0.85 + 0.25 * math.sin(i * 2.3) ^ 2)
            self:EffectStroke(
                x + math.cos(angle) * inner,
                y + math.sin(angle) * inner,
                x + math.cos(angle) * outer,
                y + math.sin(angle) * outer,
                0.035,
                gold,
                fade * strength
            )
        end
    end
    for i = self.specialTextureCount + 1, #(self.specialTextures or {}) do
        self.specialTextures[i]:Hide()
    end
    if e.time >= e.duration then
        self.specialEffect = nil
        for _, t in ipairs(self.specialTextures or {}) do
            t:Hide()
        end
    end
end

function D:UpdateMatchEffect(dt)
    baseUpdate(self, dt)
    self:UpdateSpecialEffect(dt)
    if self.specialEffect then
        -- Let the directional effects carry the impact rather than hiding icons
        -- behind the original full-board flash and opaque pending-cell sparks.
        self.effectFlash:SetAlpha(0)
        for _, c in ipairs(self.cells) do
            c.spark:SetAlpha(0)
        end
        for _, particle in ipairs(self.effectParticles) do
            particle:Hide()
        end
    end
end
