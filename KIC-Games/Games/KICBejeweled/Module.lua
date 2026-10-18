local _, Games = ...
local D = Games.KICBejeweled
Games.Graphics:Register("kic_bejeweled", Games.Graphics.providers.bejeweled)
-- Use only existing audited event categories and the volume-controlled backend.
-- One sound per resolution (highest priority) bounds overlapping chain audio.
D.SoundEvents = {
    bombCreate = "bejeweled_match_4",
    bombActivate = "bejeweled_match_4",
    lightningCreate = "bejeweled_match_4",
    lightningActivate = "bejeweled_match_5_plus",
    orbCreate = "bejeweled_match_5_plus",
    orbActivate = "bejeweled_match_5_plus",
    combination = "bejeweled_match_5_plus",
    majorChain = "bejeweled_match_5_plus",
    boardClear = "bejeweled_match_5_plus",
}
local sounds = {}
for _, event in ipairs(Games.Audio.events) do
    sounds[event] = Games.Audio.games.bejeweled[event]
end
Games.Audio:RegisterGame("kic_bejeweled", sounds)
function D:PlayResolution(resolution, cascade)
    local event = "bejeweled_match_3"
    for _, name in ipairs({
        "boardClear",
        "combination",
        "majorChain",
        "orbActivate",
        "orbCreate",
        "lightningActivate",
        "lightningCreate",
        "bombActivate",
        "bombCreate",
    }) do
        if resolution.events[name] then
            event = self.SoundEvents[name]
            break
        end
    end
    -- Routing resolution audio through the original event owner retains shared
    -- spec mappings, the resolution throttle and stop-previous-sound behavior.
    Games.Audio:Play("bejeweled", event, nil, cascade)
end
Games:RegisterBejeweledModule(D, "kic_bejeweled", "KIC Bejeweled", "KICBEJEWELED")
