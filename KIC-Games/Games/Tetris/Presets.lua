-- Fixed client texture IDs: independent of spell availability or cached spell data.
local _, Games = ...
local T = Games.Tetris
T.Presets = {
    {
        token = "WARRIOR",
        name = "Warrior",
        color = "c79c6e",
        icons = {
            132337, -- ability_warrior_charge
            132355, -- ability_warrior_savageblow
            136012, -- spell_nature_bloodlust
            132353, -- ability_warrior_revenge
            132110, -- ability_defend
            132362, -- ability_warrior_shieldwall
            236303, -- ability_warrior_bladestorm
        },
    },
    {
        token = "PALADIN",
        name = "Paladin",
        color = "f58cba",
        icons = {
            135891, -- spell_holy_crusaderstrike
            135959, -- spell_holy_righteousfury
            135874, -- spell_holy_avengersshield
            461860, -- spell_paladin_templarsverdict
            524354, -- spell_holy_divineshield
            135907, -- spell_holy_flashheal
            1360757, -- ability_paladin_bladeofjustice
        },
    },
    {
        token = "HUNTER",
        name = "Hunter",
        color = "abd473",
        icons = {
            132218, -- ability_impalingbolt
            132157, -- ability_hunter_aimedshot
            132176, -- ability_hunter_killcommand
            236174, -- ability_hunter_assassinate2
            132242, -- ability_mount_jungletiger
            135834, -- spell_frost_chainsofice
            132127, -- ability_druid_ferociousbite
        },
    },
    {
        token = "ROGUE",
        name = "Rogue",
        color = "fff569",
        icons = {
            136189, -- spell_shadow_ritualofsacrifice
            132219, -- ability_kick
            136175, -- spell_shadow_mindsteal
            132282, -- ability_rogue_ambush
            132294, -- ability_rogue_feint
            132331, -- ability_vanish
            132090, -- ability_backstab
        },
    },
    {
        token = "PRIEST",
        name = "Priest",
        color = "ffffff",
        icons = {
            135924, -- spell_holy_holysmite
            135940, -- spell_holy_powerwordshield
            135953, -- spell_holy_renew
            136207, -- spell_shadow_shadowwordpain
            136224, -- spell_shadow_unholyfrenzy
            237545, -- spell_holy_penance
            135907, -- spell_holy_flashheal
        },
    },
    {
        token = "SHAMAN",
        name = "Shaman",
        color = "0070de",
        icons = {
            136048, -- spell_nature_lightning
            237582, -- spell_shaman_lavaburst
            136044, -- spell_nature_healingway
            136095, -- spell_nature_spiritwolf
            237579, -- spell_shaman_hex
            252995, -- spell_nature_riptide
            136015, -- spell_nature_chainlightning
        },
    },
    {
        token = "MAGE",
        name = "Mage",
        color = "69ccf0",
        icons = {
            135812, -- spell_fire_flamebolt
            135846, -- spell_frost_frostbolt02
            135735, -- spell_arcane_blast
            135852, -- spell_frost_glacier
            135841, -- spell_frost_frost
            236205, -- ability_mage_arcanebarrage
            135826, -- spell_fire_selfdestruct
        },
    },
    {
        token = "WARLOCK",
        name = "Warlock",
        color = "9482c9",
        icons = {
            136197, -- spell_shadow_shadowbolt
            136118, -- spell_shadow_abominationexplosion
            135817, -- spell_fire_immolation
            136183, -- spell_shadow_possession
            136219, -- spell_shadow_summoninfernal
            135807, -- spell_fire_fireball
            136228, -- spell_shadow_unstableaffliction_3
        },
    },
    {
        token = "DRUID",
        name = "Druid",
        color = "ff7d0a",
        icons = {
            535045, -- spell_nature_wrathv2
            136096, -- spell_nature_starfall
            136081, -- spell_nature_rejuvenation
            132152, -- ability_ghoulfrenzy
            136100, -- spell_nature_stranglevines
            132276, -- ability_racial_bearform
            132115, -- ability_druid_catform
        },
    },
    {
        token = "DEATHKNIGHT",
        name = "Death Knight",
        color = "c41f3b",
        icons = {
            237517, -- spell_deathknight_butcher2
            237520, -- spell_deathknight_empowerruneblade2
            135771, -- spell_deathknight_classicon
            136144, -- spell_shadow_deathanddecay
            136145, -- spell_shadow_deathcoil
            237530, -- spell_deathknight_scourgestrike
            237525, -- spell_deathknight_iceboundfortitude
        },
    },
    {
        token = "MONK",
        name = "Monk",
        color = "00ff96",
        icons = {
            606551, -- ability_monk_tigerpalm
            574575, -- ability_monk_roundhousekick
            642415, -- ability_monk_risingsunkick
            615341, -- ability_monk_fortifyingale_new
            627487, -- ability_monk_renewingmists
            627606, -- monk_ability_fistoffury
            1360980, -- ability_monk_vivify
        },
    },
    {
        token = "DEMONHUNTER",
        name = "Demon Hunter",
        color = "a330c9",
        icons = {
            135561, -- inv_weapon_glave_01
            1305152, -- ability_demonhunter_chaosstrike
            1305149, -- ability_demonhunter_bladedance
            1305156, -- ability_demonhunter_eyebeam
            1247262, -- ability_demonhunter_metamorphasisdps
            1247261, -- ability_demonhunter_felrush
            1344647, -- ability_demonhunter_fierybrand
        },
    },
    {
        token = "EVOKER",
        name = "Evoker",
        color = "33937f",
        icons = {
            4622464, -- ability_evoker_livingflame
            4622447, -- ability_evoker_azurestrike
            4622458, -- ability_evoker_firebreath
            4630444, -- ability_evoker_eternitysurge
            4622457, -- ability_evoker_emeraldblossom
            4622450, -- ability_evoker_deepbreath
            4622471, -- ability_evoker_rescue
        },
    },
}
T.ByToken = {}
T.FallbackIcons = {
    WARRIOR = 626008,
    PALADIN = 626003,
    HUNTER = 626000,
    ROGUE = 626005,
    PRIEST = 626004,
    SHAMAN = 626006,
    MAGE = 626001,
    WARLOCK = 626007,
    DRUID = 625999,
    DEATHKNIGHT = 625998,
    MONK = 626002,
    DEMONHUNTER = 1260827,
    EVOKER = 4574311,
}
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
        icons[kind] = preset.icons[i]
    end
    return icons
end
