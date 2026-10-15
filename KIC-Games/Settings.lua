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
local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
function Games:GetSettings()
    if type(self.DB.settings) ~= "table" then
        self.DB.settings = {}
    end
    local s = self.DB.settings
    if
        s.schemaVersion == 2
        and (
            type(s.manualSpecs) ~= "table"
            or type(s.manualClass) ~= "string"
            or (s.graphicsTheme ~= "original" and s.graphicsTheme ~= "class")
            or (s.soundTheme ~= "arcade" and s.soundTheme ~= "class")
            or not finite(s.soundVolume)
            or not finite(s.windowScale)
        )
    then
        s.schemaVersion = nil
    end
    if s.schemaVersion ~= 2 then
        if #self.Profiles.classes == 0 then
            self.Profiles:Refresh()
        end
        local _, player = UnitClass("player")
        local legacy = type(self.DB.tetris) == "table" and self.DB.tetris.preset
        local token = s.manualClass or s.classPreset or legacy or player or "MAGE"
        if not self.Profiles.byClass[token] then
            token = player or "MAGE"
        end
        s.manualClass = token
        s.manualSpecs = type(s.manualSpecs) == "table" and s.manualSpecs or {}
        local class = self.Profiles.byClass[token]
        local spec = self.Profiles.bySpec[s.manualSpecID]
        s.manualSpecID = spec and spec.class == token and spec.id or class and class.specs[1] and class.specs[1].id
        s.manualSpecs[token] = s.manualSpecID
        s.graphicsTheme = s.graphicsTheme == "original" and "original" or "class"
        s.followCharacter = s.followCharacter ~= false
        s.soundTheme = s.soundTheme == "arcade" and "arcade" or "class"
        s.soundsEnabled = s.soundsEnabled ~= false
        s.soundVolume = finite(s.soundVolume) and math.max(0, math.min(1, s.soundVolume)) or 0.6
        s.windowScale = finite(s.windowScale)
                and math.max(0.75, math.min(1.5, math.floor(s.windowScale * 20 + 0.5) / 20))
            or 1
        -- Legacy dimensions remain in SavedVariables for lossless migration, but
        -- Options 2.0 never applies them or exposes another sizing control.
        s.schemaVersion = 2
    end
    s.soundVolume = math.max(0, math.min(1, s.soundVolume))
    s.windowScale = math.max(0.75, math.min(1.5, math.floor(s.windowScale * 20 + 0.5) / 20))
    s.followCharacter = s.followCharacter ~= false
    s.soundsEnabled = s.soundsEnabled ~= false
    return s
end
function Games:GetSelectedProfile()
    local s = self:GetSettings()
    if s.followCharacter then
        local token, spec = self.Profiles:Character()
        if self.Profiles.byClass[token] then
            return token, spec
        end
    end
    local token = s.manualClass
    if not self.Profiles.byClass[token] then
        local _, player = UnitClass("player")
        token = self.Profiles.byClass[player] and player or "MAGE"
    end
    local class, spec = self.Profiles.byClass[token], self.Profiles.bySpec[s.manualSpecID]
    return token, spec and spec.class == token and spec.id or class and class.specs[1] and class.specs[1].id
end
function Games:GetClassPreset()
    local token = self:GetSelectedProfile()
    return token
end
function Games:ApplyCosmetics()
    local token = self:GetClassPreset()
    for _, module in ipairs({ self.Tetris, self.Bejeweled }) do
        if module and module.ApplyPreset then
            module:ApplyPreset(token)
        end
    end
    if self.Audio then
        self.Audio:StopAll()
    end
    if self.UI and self.UI.RefreshOptions then
        self.UI:RefreshOptions()
    end
end
function Games:SetManualClass(token)
    local s, class = self:GetSettings(), self.Profiles.byClass[token]
    if not class or s.followCharacter then
        return false
    end
    s.manualClass, s.classPreset = token, token
    local remembered = self.Profiles.bySpec[s.manualSpecs[token]]
    s.manualSpecID = remembered and remembered.class == token and remembered.id or class.specs[1] and class.specs[1].id
    s.manualSpecs[token] = s.manualSpecID
    self:ApplyCosmetics()
    return true
end
function Games:SetClassPreset(token)
    if not self.Profiles.byClass[token] then
        return false
    end
    self:GetSettings().followCharacter = false
    return self:SetManualClass(token)
end
function Games:SetManualSpec(id)
    local s, spec = self:GetSettings(), self.Profiles.bySpec[id]
    if s.followCharacter or not spec or spec.class ~= s.manualClass then
        return false
    end
    s.manualSpecID, s.manualSpecs[s.manualClass] = id, id
    self:ApplyCosmetics()
    return true
end
function Games:SetOption(key, value)
    local s = self:GetSettings()
    if key == "graphicsTheme" then
        if value ~= "original" and value ~= "class" then
            return false
        end
    elseif key == "soundTheme" then
        if value ~= "arcade" and value ~= "class" then
            return false
        end
    elseif key == "followCharacter" or key == "soundsEnabled" then
        value = value == true
    elseif key == "soundVolume" then
        if not finite(value) then
            return false
        end
        value = math.max(0, math.min(1, value))
    else
        return false
    end
    s[key] = value
    if key == "graphicsTheme" or key == "followCharacter" then
        self:ApplyCosmetics()
    else
        if self.Audio then
            self.Audio:StopAll()
        end
        if self.UI and self.UI.RefreshOptions then
            self.UI:RefreshOptions()
        end
    end
    return true
end
local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, unit)
    if not Games.DB or event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return
    end
    Games.Profiles:Refresh()
    if Games:GetSettings().followCharacter then
        Games:ApplyCosmetics()
    elseif Games.UI and Games.UI.RefreshOptions then
        Games.UI:RefreshOptions()
    end
end)
