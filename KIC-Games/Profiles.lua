local _, Games = ...
local Profiles = { classes = {}, byClass = {}, bySpec = {} }
Games.Profiles = Profiles

function Profiles:Register(specID, profile)
    assert(type(specID) == "number" and type(profile) == "table")
    Games.ProfileData[specID] = profile
end

function Profiles:Refresh()
    self.classes, self.byClass, self.bySpec = {}, {}, {}
    local count = GetNumClasses and GetNumClasses() or #Games.IconPresets.Presets
    for index = 1, count do
        local name, token, id
        if GetClassInfo then
            name, token, id = GetClassInfo(index)
        else
            local old = Games.IconPresets.Presets[index]
            name, token, id = old.name, old.token, index
        end
        if token then
            local class = { name = name, token = token, id = id, specs = {} }
            self.classes[#self.classes + 1], self.byClass[token] = class, class
            local api = C_SpecializationInfo
            local num = api and api.GetNumSpecializationsForClassID and api.GetNumSpecializationsForClassID(id) or 0
            for specIndex = 1, num do
                local specID, specName, _, icon, role = GetSpecializationInfoForClassID(id, specIndex)
                if specID and specID > 0 then
                    local spec = { id = specID, name = specName, icon = icon, role = role, class = token }
                    class.specs[#class.specs + 1], self.bySpec[specID] = spec, spec
                end
            end
        end
    end
end

function Profiles:Character()
    local _, token = UnitClass("player")
    local api = C_SpecializationInfo
    local index = api and api.GetSpecialization and api.GetSpecialization() or GetSpecialization and GetSpecialization()
    local getter = api and api.GetSpecializationInfo or GetSpecializationInfo
    local specID = index and getter and getter(index) or nil
    return token, self.bySpec[specID] and specID or nil
end

function Profiles:Icons(token, specID)
    local curated = Games.ProfileData[specID]
    local class = Games.IconPresets.ByToken[token] or Games.IconPresets.ByToken.MAGE
    local source = curated and curated.class == token and curated.icons or class.icons
    local icons, seen = {}, {}
    local spec = self.bySpec[specID]
    -- Newly discovered specs remain usable before their curated profile arrives.
    if not curated and spec and spec.icon then
        icons[1], seen[spec.icon] = spec.icon, true
    end
    for _, icon in ipairs(source) do
        if not seen[icon] and #icons < 7 then
            icons[#icons + 1], seen[icon] = icon, true
        end
    end
    return icons, not curated
end
