local _, Games = ...
local Audio = { games = {}, specs = {}, handles = {}, last = {}, lastAny = -math.huge }
Games.Audio = Audio
Audio.events = { "select", "move", "swap", "land", "clear", "combo", "gameOver", "victory" }
-- Verified simple, single-file kits; profiles retain their original FileDataIDs.
-- SoundKit/SoundKitEntry 12.1.0.69933 evidence: tests/master-sound-kits.json.
Audio.fileKits = {
    [568008] = 22468,
    [568075] = 47725,
    [568080] = 10020,
    [568516] = 1490,
    [568678] = 11769,
    [569021] = 47726,
    [569157] = 13103,
    [569315] = 20591,
    [569378] = 86009,
    [569384] = 24161,
    [569403] = 12349,
    [569471] = 10136,
    [569555] = 20599,
    [569658] = 10139,
}
local function soundKit(entry)
    return entry and (entry.kit or Audio.fileKits[entry.file])
end
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
        if not found and not (self.internalEvents and self.internalEvents[event]) then
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
-- Internal resolution events deliberately bypass RegisterGame's public preview list.
Audio.internalEvents = {
    tetris_1_line = "tetris",
    tetris_2_lines = "tetris",
    tetris_3_lines = "tetris",
    tetris_4_lines = "tetris",
    bejeweled_match_3 = "bejeweled",
    bejeweled_match_4 = "bejeweled",
    bejeweled_match_5_plus = "bejeweled",
}
Audio.games.tetris.tetris_1_line = { kit = 865 }
Audio.games.tetris.tetris_2_lines = { kit = 1204 }
Audio.games.tetris.tetris_3_lines = { kit = 10590 }
Audio.games.tetris.tetris_4_lines = { kit = 73279 }
Audio.games.bejeweled.bejeweled_match_3 = { kit = 1204 }
Audio.games.bejeweled.bejeweled_match_4 = { kit = 10590 }
Audio.games.bejeweled.bejeweled_match_5_plus = { kit = 73279 }
-- Named archive files retain verified mappings and existing legacy effects.
-- Missing tiers use arcade kits; see design/SOUND_AUDIT_REPORT.md for limits.
for id, profile in pairs(Games.ProfileData) do
    local a = profile.sounds
    local events = {}
    if a and #a > 0 then
        for _, event in ipairs(Audio.events) do
            if event ~= "gameOver" and event ~= "victory" then
                local index = (event == "clear" or event == "land") and 2 or event == "combo" and 3 or 1
                if a[index] then
                    events[event] = { file = a[index] }
                end
            end
        end
    end
    for event, file in pairs(profile.soundEvents or {}) do
        events[event] = { file = file }
    end
    -- Keep existing previews meaningful (and their file-volume limitation visible)
    -- for profiles which previously had no generic spell effects.
    events.clear = events.clear
        or events.bejeweled_match_3
        or events.tetris_1_line
        or events.tetris_2_lines
        or events.tetris_3_lines
        or events.tetris_4_lines
    events.combo = events.combo or events.bejeweled_match_5_plus or events.bejeweled_cascade
    if next(events) then
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
local function fallback(game, event, cascade)
    if cascade and cascade > 1 and Audio.internalEvents[event] == "bejeweled" then
        return game.combo
    end
    return game[event]
end
function Audio:Resolve(gameID, event, cascade)
    local game = self.games[gameID]
    if not game then
        return
    end
    local _, id = Games:GetSelectedProfile()
    local spec = Games:GetSettings().soundTheme == "class" and self.specs[id] or nil
    local entry = spec and spec[event]
    if spec and not entry and (event == "tetris_1_line" or event == "bejeweled_match_3") then
        entry = spec.clear -- Preserve a working legacy low-tier effect, without fabricating higher tiers.
    end
    if
        spec
        and cascade
        and cascade > 1
        and event ~= "bejeweled_match_5_plus"
        and self.internalEvents[event] == "bejeweled"
    then
        entry = spec.bejeweled_cascade or spec.combo or entry
    end
    if entry and entry.file and not PlaySoundFile and not self:VolumeSupported(entry) then
        entry = nil
    end
    return entry or fallback(game, event, cascade), entry == nil
end
function Audio:VolumeSupported(entry)
    -- Older namespaces exist without volumeOverride; do not silently claim gain.
    if not GetBuildInfo then
        return false
    end
    local _, _, _, interface = GetBuildInfo()
    return type(interface) == "number"
        and interface >= 120100
        and soundKit(entry)
        and C_Sound
        and (C_Sound.PlaySound or C_Sound.PlaySoundWithOptions) ~= nil
end
function Audio:Play(gameID, event, preview, cascade, arcadeFallback)
    local s = Games:GetSettings()
    if not s.soundsEnabled or s.soundVolume <= 0 then
        self:StopAll()
        return false
    end
    local entry = arcadeFallback and self.games[gameID] and fallback(self.games[gameID], event, cascade)
        or self:Resolve(gameID, event, cascade)
    if not entry then
        return false
    end
    local time = GetTime()
    local resolution = self.internalEvents[event] == gameID
    local key = gameID .. ":" .. (resolution and "resolution" or event)
    local delay = event == "move" and 0.08 or event == "combo" and 0.18 or 0.1
    local important = event == "gameOver" or event == "victory"
    if
        not preview
        and not important
        and (time - (self.last[key] or -math.huge) < delay or not resolution and time - self.lastAny < 0.035)
    then
        return false
    end
    if preview or important or resolution or #self.handles >= 2 then
        self:StopAll()
    end
    local ok, success, handle
    local kit = soundKit(entry)
    local controlled = self:VolumeSupported(entry)
    if controlled then
        if C_Sound.PlaySound then
            ok, success, handle = pcall(C_Sound.PlaySound, kit, "Master", true, false, nil, s.soundVolume)
        else
            ok, success, handle = pcall(C_Sound.PlaySoundWithOptions, {
                soundKitID = kit,
                uiSoundSubType = "Master",
                volumeOverride = s.soundVolume,
                forceNoDuplicates = true,
            })
        end
    elseif entry.file and PlaySoundFile then
        -- No independent gain exists for this API; nonzero levels follow Master.
        ok, success, handle = pcall(PlaySoundFile, entry.file, "Master")
    elseif PlaySound then
        -- Legacy kit playback has no supported independent volume argument.
        ok, success, handle = pcall(PlaySound, entry.kit, "Master", true)
    end
    if controlled and entry.file and not (ok and success) and PlaySoundFile then
        -- A missing/unsupported mapped kit must preserve the selected spell file.
        ok, success, handle = pcall(PlaySoundFile, entry.file, "Master")
    end
    if ok and success then
        self.last[key], self.lastAny = time, time
        if handle then
            self.handles[#self.handles + 1] = handle
        end
        return true
    end
    if entry.file and not arcadeFallback and self.games[gameID][event] then
        -- File missing in this build: retry a verified kit, without changing globals.
        return self:Play(gameID, event, preview, cascade, true)
    end
    return false
end
