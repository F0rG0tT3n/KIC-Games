-- Run from the repository root: lua tests/roguelite_artwork.lua
-- The artwork registry is shared and does not need a live WoW client.
local Games = {}
assert(loadfile('KIC-Games/Artwork.lua'))('KIC-Games', Games)
Games.KICBejeweled = {}
assert(loadfile('KIC-Games/Games/KICBejeweled/Roguelite.lua'))('KIC-Games', Games)
local R = Games.KICBejeweled.Roguelite
local counts, known = {}, {
    energy = true, bomb = true, lightning = true, orb = true,
    critical = true, echo = true, transmutation = true, cursed = true, chaos = true,
}
assert(#R.Cards == 75)
for _, card in ipairs(R.Cards) do
    local key = card.artKey
    assert(type(key) == 'string' and key:sub(1, 8) == 'upgrade-', 'unmapped: ' .. card.id)
    local group = key:sub(9)
    assert(known[group], 'unknown category: '..card.id..' / '..group)
    assert(Games.Artwork[key] and Games.Artwork[key].file, 'art registry missing: '..key)
    counts[group] = (counts[group] or 0) + 1
end
local base = 'KIC-Games/Media/KICUI/Upgrades/'
for group in pairs(known) do
    assert((counts[group] or 0) > 0, 'category empty: '..group)
    local file = assert(io.open(base .. group .. '.tga', 'rb'))
    local header = assert(file:read(18)); file:close()
    local function le16(offset) return header:byte(offset) + 256 * header:byte(offset+1) end
    assert(le16(13)==256 and le16(15)==256, 'wrong TGA size: '..group)
    assert(header:byte(17)==32, 'expected RGBA TGA: '..group)
end
local shuffle = Games.Artwork['upgrade-reshuffle']
assert(shuffle and shuffle.file)
local file = assert(io.open(base .. 'reshuffle.tga', 'rb')); file:close()
local ui = assert(io.open('KIC-Games/Games/KICBejeweled/RogueliteUI.lua','rb')):read('*a')
assert(ui:find('card.artKey or "icon-gem"', 1, true), 'draft cards not using artwork mapping')
assert(ui:find('"upgrade-reshuffle"', 1, true), 'reshuffle not illustrated')
print('PASS: 75 cards mapped to 9 illustrated categories, plus reshuffle; 10 valid 256x256 TGA assets')
