local _, Games = ...
local Graphics = { providers = {} }
Games.Graphics = Graphics
function Graphics:Register(gameID, provider)
    assert(type(gameID) == "string" and type(provider.original) == "table")
    self.providers[gameID] = provider
end
function Games:GetPieceIcons(gameID)
    local token, spec = self:GetSelectedProfile()
    local provider = self.Graphics.providers[gameID]
    if self:GetSettings().graphicsTheme == "original" and provider then
        return provider.original
    end
    return self.Profiles:Icons(token, spec)
end
function Graphics:Label(gameID, record)
    local token, specID = Games:GetSelectedProfile()
    local mode = Games:GetSettings().graphicsTheme
    if record then
        token, specID, mode = record.preset, record.specID, record.graphicsTheme or "class"
    end
    if mode == "original" then
        local provider = self.providers[gameID]
        return provider and provider.label or "Original graphics"
    end
    local class = Games.Profiles.byClass[token] or Games.IconPresets.ByToken[token]
    local spec = Games.Profiles.bySpec[specID]
    return (spec and spec.class == token and (spec.name .. " ") or "")
        .. (class and class.name or token or "Class")
        .. " icons"
end
function Graphics:Paint(texture, gameID, index, color, alpha)
    local icons = Games:GetPieceIcons(gameID)
    local token = Games:GetClassPreset()
    local fallback = Games.IconPresets.FallbackIcons[token] or Games.IconPresets.FallbackIcons.MAGE
    if texture:SetTexture(icons[index] or fallback) == false then
        texture:SetTexture(fallback)
    end
    if Games:GetSettings().graphicsTheme == "original" and self.providers[gameID] and self.providers[gameID].tint then
        texture:SetVertexColor(unpack(color or { 1, 1, 1 }))
    else
        texture:SetVertexColor(1, 1, 1)
    end
    texture:SetAlpha(alpha or 1)
end
local gems, blocks = {}, {}
for i = 1, 7 do
    gems[i] = Games.Artwork["original-gem-" .. i].file
    blocks[i] = Games.Artwork["original-block"].file
end
Graphics:Register("bejeweled", { original = gems, label = "Original gems" })
Graphics:Register("tetris", { original = blocks, tint = true, label = "Original blocks" })
