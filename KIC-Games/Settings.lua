local _, Games = ...
-- Keep unknown module IDs: temporarily uninstalled games can return later.
function Games:GetRecentIDs()
    local history = type(self.DB.recentGames) == "table" and self.DB.recentGames or {}
    local keys, ids, seen = {}, {}, {}
    for key in pairs(history) do
        if type(key) == "number" and key >= 1 and key < math.huge and key % 1 == 0 then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local id = history[key]
        if type(id) == "string" and #id <= 32 and id:match("^[%w_%-]+$") and not seen[id] then
            ids[#ids + 1], seen[id] = id, true
        end
    end
    return ids
end
function Games:GetRecentGames()
    local games = {}
    for _, id in ipairs(self:GetRecentIDs()) do
        if self.Registry[id] then
            games[#games + 1] = self.Registry[id]
        end
    end
    return games
end
function Games:RecordGameLaunch(id)
    if not self.Registry[id] then
        return
    end
    local history = { id }
    for _, previous in ipairs(self:GetRecentIDs()) do
        if previous ~= id then
            history[#history + 1] = previous
        end
    end
    self.DB.recentGames = history
end
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
