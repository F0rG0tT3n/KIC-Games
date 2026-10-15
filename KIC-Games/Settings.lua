local _, Games = ...
function Games:GetSettings()
    if type(self.DB.settings) ~= "table" then
        self.DB.settings = {}
    end
    return self.DB.settings
end
function Games:GetClassPreset()
    local settings = self:GetSettings()
    if not self.IconPresets.ByToken[settings.classPreset] then
        local legacy = type(self.DB.tetris) == "table" and self.DB.tetris.preset
        local _, token = UnitClass("player")
        settings.classPreset = self.IconPresets.ByToken[legacy] and legacy
            or self.IconPresets.ByToken[token] and token
            or "MAGE"
    end
    return settings.classPreset
end
function Games:SetClassPreset(token)
    if not self.IconPresets.ByToken[token] then
        return false
    end
    self:GetSettings().classPreset = token
    for _, module in ipairs({ self.Tetris, self.Bejeweled }) do
        if module and module.ApplyPreset then
            module:ApplyPreset(token)
        end
    end
    if self.UI.RefreshOptions then
        self.UI:RefreshOptions()
    end
    return true
end
