local _, Games = ...

-- Legacy names are confined to this compatibility boundary. All current game
-- registration, storage, UI, artwork and commands use the KIC Bejeweled name.
local previousID, currentID = "bejeweled_deluxe", "kic_bejeweled"
SLASH_KICBEJEWELED2 = "/kicbejeweleddeluxe"

local function score(best)
    local value = type(best) == "table" and best.score
    return type(value) == "number" and value == value and value >= 0 and value <= 2147483647 and value or -1
end
local function merge(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = value
        elseif key == "best" and score(value) > score(target[key]) then
            -- Keep score metadata from the winning record together. Untimed
            -- and Arcane Rush bests are compared only within their own buckets.
            target[key] = value
        elseif key ~= "best" and type(target[key]) == "table" and type(value) == "table" then
            merge(target[key], value)
        end
    end
end
function Games:MigrateGameNames()
    local db = self.DB
    local previous = db[previousID]
    if type(previous) == "table" then
        if type(db[currentID]) ~= "table" then
            db[currentID] = previous
        else
            merge(db[currentID], previous)
        end
        db[previousID] = nil
    end
    if type(db.results) == "table" then
        for _, result in pairs(db.results) do
            if type(result) == "table" and result.gameID == previousID then
                result.gameID = currentID
            end
        end
    end
    if type(db.recentGames) == "table" then
        for key, id in pairs(db.recentGames) do
            if id == previousID then db.recentGames[key] = currentID end
        end
        -- Preserve launch order while removing duplicates of the renamed game.
        db.recentGames = self:GetRecentIDs()
    end
end
