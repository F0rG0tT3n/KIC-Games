local _, Games = ...
local T = Games.Tetris
T.Presets = {
    { token = "WARRIOR", name = "Warrior", color = "c79c6e", spells = { 100, 12294, 23881, 6572, 2565, 871, 46924 } },
    {
        token = "PALADIN",
        name = "Paladin",
        color = "f58cba",
        spells = { 35395, 20271, 31935, 85256, 642, 19750, 184575 },
    },
    {
        token = "HUNTER",
        name = "Hunter",
        color = "abd473",
        spells = { 3044, 19434, 34026, 53351, 186257, 187650, 19574 },
    },
    { token = "ROGUE", name = "Rogue", color = "fff569", spells = { 1752, 1766, 2094, 8676, 1966, 1856, 53 } },
    { token = "PRIEST", name = "Priest", color = "ffffff", spells = { 585, 17, 139, 589, 8092, 47540, 2061 } },
    { token = "SHAMAN", name = "Shaman", color = "0070de", spells = { 403, 51505, 8004, 2645, 51514, 61295, 421 } },
    { token = "MAGE", name = "Mage", color = "69ccf0", spells = { 133, 116, 30451, 120, 45438, 44425, 2120 } },
    { token = "WARLOCK", name = "Warlock", color = "9482c9", spells = { 686, 172, 348, 5782, 1122, 17962, 30108 } },
    { token = "DRUID", name = "Druid", color = "ff7d0a", spells = { 5176, 8921, 774, 1079, 339, 5487, 768 } },
    {
        token = "DEATHKNIGHT",
        name = "Death Knight",
        color = "c41f3b",
        spells = {
            49998,
            49143,
            49020,
            43265,
            47541,
            55090,
            48792,
        },
    },
    {
        token = "MONK",
        name = "Monk",
        color = "00ff96",
        spells = { 100780, 100784, 107428, 115203, 115151, 113656, 116670 },
    },
    {
        token = "DEMONHUNTER",
        name = "Demon Hunter",
        color = "a330c9",
        spells = { 162243, 162794, 188499, 198013, 191427, 195072, 204021 },
    },
    {
        token = "EVOKER",
        name = "Evoker",
        color = "33937f",
        spells = { 361469, 362969, 357208, 359073, 355913, 357210, 360995 },
    },
}
T.ByToken = {}
for _, preset in ipairs(T.Presets) do
    T.ByToken[preset.token] = preset
end
T.Colors = {
    I = { 0.1, 0.9, 1 },
    J = { 0.2, 0.4, 1 },
    L = { 1, 0.55, 0.1 },
    O = { 1, 0.9, 0.15 },
    S = { 0.2, 0.95, 0.35 },
    T = { 0.8, 0.3, 1 },
    Z = { 1, 0.2, 0.3 },
}

function T:GetIcons(token)
    local preset, icons = self.ByToken[token] or self.ByToken.MAGE, {}
    for i, kind in ipairs(self.Engine.Kinds) do
        icons[kind] = (C_Spell and C_Spell.GetSpellTexture(preset.spells[i]))
            or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    return icons
end
