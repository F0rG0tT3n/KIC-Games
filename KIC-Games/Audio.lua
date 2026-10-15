local _, Games = ...
local Audio = { games = {}, specs = {}, handles = {}, last = {}, lastAny = -math.huge }
Games.Audio = Audio
Audio.events = { "select", "move", "swap", "land", "clear", "combo", "gameOver", "victory" }
-- Verified Blizzard SharedXML SOUNDKIT constants. These are kits, never SpellIDs.
function Audio:RegisterGame(id, events)
    self.games[id] = events
    for event in pairs(events) do
        local found = false
        for _, existing in ipairs(self.events) do
            if event == existing then
                found = true
            end
        end
        if not found then
            self.events[#self.events + 1] = event
        end
    end
end
function Audio:RegisterSpec(id, events)
    self.specs[id] = events
end
Audio:RegisterGame("bejeweled", {
    select = { kit = 1221 },
    move = { kit = 1204 },
    swap = { kit = 838 },
    land = { kit = 1204 },
    clear = { kit = 10590 },
    combo = { kit = 73279 },
    gameOver = { kit = 846 },
    victory = { kit = 878 },
})
Audio:RegisterGame("tetris", {
    select = { kit = 841 },
    move = { kit = 823 },
    swap = { kit = 838 },
    land = { kit = 1212 },
    clear = { kit = 865 },
    combo = { kit = 73279 },
    gameOver = { kit = 846 },
    victory = { kit = 878 },
})
-- Named archive spell files are genuine client assets. Missing event/profile
-- sounds resolve to the game's arcade kit; see MISSING_ASSETS.md for the audit.
for id, profile in pairs(Games.ProfileData) do
    local a = profile.sounds
    if a and #a > 0 then
        local events = {}
        for _, event in ipairs(Audio.events) do
            if event ~= "gameOver" and event ~= "victory" then
                local index = (event == "clear" or event == "land") and 2 or event == "combo" and 3 or 1
                if a[index] then
                    events[event] = { file = a[index] }
                end
            end
        end
        Audio:RegisterSpec(id, events)
    end
end
function Audio:StopAll()
    if StopSound then
        for _, handle in ipairs(self.handles) do
            pcall(StopSound, handle)
        end
    end
    self.handles = {}
end
function Audio:Resolve(gameID, event)
    local game = self.games[gameID]
    if not game then
        return
    end
    local _, id = Games:GetSelectedProfile()
    local spec = Games:GetSettings().soundTheme == "class" and self.specs[id]
    local entry = spec and spec[event]
    if entry and entry.file and not PlaySoundFile then
        entry = nil
    end
    return entry or game[event], entry == nil
end
function Audio:VolumeSupported(entry)
    return entry and entry.kit and C_Sound and (C_Sound.PlaySoundWithOptions or C_Sound.PlaySound) ~= nil
end
function Audio:Play(gameID, event, preview)
    local s = Games:GetSettings()
    if not s.soundsEnabled or s.soundVolume <= 0 then
        self:StopAll()
        return false
    end
    local entry = self:Resolve(gameID, event)
    if not entry then
        return false
    end
    local time = GetTime()
    local key = gameID .. ":" .. event
    local delay = event == "move" and 0.08 or event == "combo" and 0.18 or 0.1
    local important = event == "gameOver" or event == "victory"
    if
        not preview
        and not important
        and (time - (self.last[key] or -math.huge) < delay or time - self.lastAny < 0.035)
    then
        return false
    end
    if preview or important or #self.handles >= 2 then
        self:StopAll()
    end
    local ok, success, handle
    if self:VolumeSupported(entry) then
        if C_Sound.PlaySoundWithOptions then
            ok, success, handle = pcall(
                C_Sound.PlaySoundWithOptions,
                { soundKitID = entry.kit, volumeOverride = s.soundVolume, forceNoDuplicates = true }
            )
        else
            ok, success, handle = pcall(C_Sound.PlaySound, entry.kit, nil, true, false, nil, s.soundVolume)
        end
    elseif entry.file and PlaySoundFile then
        ok, success, handle = pcall(PlaySoundFile, entry.file, "SFX")
    elseif PlaySound then
        -- Legacy kit playback has no supported independent volume argument.
        ok, success, handle = pcall(PlaySound, entry.kit, "SFX", true)
    end
    if ok and success then
        self.last[key], self.lastAny = time, time
        if handle then
            self.handles[#self.handles + 1] = handle
        end
        return true
    end
    if entry.file and self.games[gameID][event] then
        -- File missing in this build: retry a verified kit, without changing globals.
        local saved = self.specs[select(2, Games:GetSelectedProfile())]
        if saved then
            local old = saved[event]
            saved[event] = nil
            local played = self:Play(gameID, event, preview)
            saved[event] = old
            return played
        end
    end
    return false
end
