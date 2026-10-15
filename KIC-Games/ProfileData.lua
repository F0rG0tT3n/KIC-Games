-- Current spell tooltip + archive texture audit; runtime catalog uses Retail APIs.
local _, Games = ...
Games.ProfileData = {
    [71] = {
        class = "WARRIOR",
        icons = {
            132355, -- Mortal Strike
            132223, -- Overpower
            132340, -- Slam
            2065633, -- Colossus Smash
            236303, -- Bladestorm
            135358, -- Execute
            132337, -- Charge
        },
        sounds = {
            1267929, -- sound/spells/spell_wr_mortalstrike_revamp_cast_01.ogg
            1267930, -- sound/spells/spell_wr_mortalstrike_revamp_cast_02.ogg
            1267931, -- sound/spells/spell_wr_mortalstrike_revamp_cast_03.ogg
        },
    },
    [72] = {
        class = "WARRIOR",
        icons = {
            136012, -- Bloodthirst
            589119, -- Raging Blow
            132352, -- Rampage
            132345, -- Enraged Regeneration
            458972, -- Recklessness
            132369, -- Whirlwind
            1278409, -- Odyn's Fury
        },
        sounds = {
            1276021, -- sound/spells/spell_wr_bloodthirst_revamp_impact_01.ogg
            1276022, -- sound/spells/spell_wr_bloodthirst_revamp_impact_02.ogg
            1276023, -- sound/spells/spell_wr_bloodthirst_revamp_impact_03.ogg
        },
    },
    [73] = {
        class = "WARRIOR",
        icons = {
            134951, -- Shield Slam
            132110, -- Shield Block
            132353, -- Revenge
            132362, -- Shield Wall
            135871, -- Last Stand
            136105, -- Thunder Clap
            236312, -- Shockwave
        },
        sounds = {},
    },
    [65] = {
        class = "PALADIN",
        icons = {
            135972, -- Holy Shock
            461859, -- Light of Dawn
            236247, -- Beacon of Light
            135981, -- Holy Light
            135907, -- Flash of Light
            135875, -- Avenging Wrath
            135891, -- interface/icons/spell_holy_crusaderstrike.blp
        },
        sounds = {},
    },
    [66] = {
        class = "PALADIN",
        icons = {
            135874, -- Avenger's Shield
            236265, -- Shield of the Righteous
            135919, -- Guardian of Ancient Kings
            135870, -- Ardent Defender
            135926, -- Consecration
            535595, -- Blessed Hammer
            135959, -- Judgment
        },
        sounds = {
            1360126, -- sound/spells/spell_pa_avengersshield_impact_revamp_01.ogg
            1360127, -- sound/spells/spell_pa_avengersshield_impact_revamp_02.ogg
            1360128, -- sound/spells/spell_pa_avengersshield_impact_revamp_03.ogg
        },
    },
    [70] = {
        class = "PALADIN",
        icons = {
            461860, -- Templar's Verdict
            236250, -- Divine Storm
            1360757, -- Blade of Justice
            135891, -- Crusader Strike
            1112939, -- Wake of Ashes
            613954, -- Execution Sentence
            7439209, -- Hammer of Wrath
        },
        sounds = {
            638272, -- sound/spells/spell_pa_templarsverdict_impact01.ogg
            638274, -- sound/spells/spell_pa_templarsverdict_impact02.ogg
            638276, -- sound/spells/spell_pa_templarsverdict_impact03.ogg
        },
    },
    [253] = {
        class = "HUNTER",
        icons = {
            132176, -- Kill Command
            2058007, -- Barbed Shot
            132127, -- Bestial Wrath
            236186, -- Dire Beast
            461121, -- Beast Cleave
            136074, -- Aspect of the Wild
            132163, -- Revive Pet
        },
        sounds = {
            569021, -- sound/spells/spell_hu_killcommand_impact.ogg
            1303796, -- sound/spells/spell_hu_killcommand_cast.ogg
            568075, -- sound/spells/killcommand.ogg
        },
    },
    [254] = {
        class = "HUNTER",
        icons = {
            461115, -- Rapid Fire
            132329, -- Trueshot
            132330, -- Multi-Shot
            132218, -- Arcane Shot
            236178, -- Explosive Shot
            132157, -- interface/icons/ability_hunter_aimedshot.blp
            236179, -- Marksmanship fallback: Focused Aim
        },
        sounds = {
            1313130, -- sound/spells/spell_hu_aimedshot_impact.ogg
            1590095, -- sound/spells/spell_hu_aimedshot_cast_01.ogg
            1590096, -- sound/spells/spell_hu_aimedshot_cast_02.ogg
        },
    },
    [255] = {
        class = "HUNTER",
        icons = {
            1376046, -- Raptor Strike
            1376044, -- Mongoose Bite
            2065634, -- Wildfire Bomb
            1376039, -- Carve
            1376040, -- Harpoon
            236184, -- Flanking Strike
            2032587, -- Coordinated Assault
        },
        sounds = {
            1302244, -- sound/spells/spell_hu_raptorstrike_cast01.ogg
            1302245, -- sound/spells/spell_hu_raptorstrike_cast02.ogg
            1302246, -- sound/spells/spell_hu_raptorstrike_cast03.ogg
        },
    },
    [259] = {
        class = "ROGUE",
        icons = {
            132287, -- Envenom
            132304, -- Mutilate
            132297, -- Garrote
            132302, -- Rupture
            4667421, -- Deathmark
            1259291, -- Kingsbane
            135428, -- Shiv
        },
        sounds = {
            568080, -- sound/spells/mutilate_impact_chest.ogg
            1301172, -- sound/spells/spell_ro_mutilate_impact_01.ogg
            1301173, -- sound/spells/spell_ro_mutilate_impact_02.ogg
        },
    },
    [260] = {
        class = "ROGUE",
        icons = {
            136189, -- Sinister Strike
            236286, -- Dispatch
            135610, -- Between the Eyes
            1373910, -- Roll the Bones
            132350, -- Blade Flurry
            136206, -- Adrenaline Rush
            1373908, -- Pistol Shot
        },
        sounds = {
            1360714, -- sound/spells/spell_ro_pistolshot_cast_01.ogg
            1360715, -- sound/spells/spell_ro_pistolshot_cast_02.ogg
            1360716, -- sound/spells/spell_ro_pistolshot_cast_03.ogg
        },
    },
    [261] = {
        class = "ROGUE",
        icons = {
            1373912, -- Shadowstrike
            132292, -- Eviscerate
            236279, -- Shadow Dance
            252272, -- Symbols of Death
            376022, -- Shadow Blades
            132305, -- Secret Technique
            132090, -- Backstab
        },
        sounds = {
            569471, -- sound/spells/shadowstrike_impact_chest.ogg
            569384, -- sound/spells/spell_shadowstrike_cast.ogg
            1305797, -- sound/spells/spell_ro_shadowstrike_cast_revamp_01.ogg
        },
    },
    [256] = {
        class = "PRIEST",
        icons = {
            237545, -- Penance
            458720, -- Atonement
            135940, -- Power Word: Shield
            135936, -- Pain Suppression
            237548, -- Rapture
            236216, -- Purge the Wicked
            135924, -- interface/icons/spell_holy_holysmite.blp
        },
        sounds = {
            1708153, -- sound/spells/spell_pr_revamp_penance_impact_01.ogg
            1708154, -- sound/spells/spell_pr_revamp_penance_impact_02.ogg
            1708155, -- sound/spells/spell_pr_revamp_penance_impact_03.ogg
        },
    },
    [257] = {
        class = "PRIEST",
        icons = {
            135937, -- Holy Word: Serenity
            237541, -- Holy Word: Sanctify
            135944, -- Prayer of Mending
            237542, -- Guardian Spirit
            135972, -- Holy Fire
            237540, -- Divine Hymn
            135887, -- Circle of Healing
        },
        sounds = {},
    },
    [258] = {
        class = "PRIEST",
        icons = {
            136224, -- Mind Blast
            136208, -- Mind Flay
            136207, -- Shadow Word: Pain
            135978, -- Vampiric Touch
            7569529, -- Shadow Word: Madness
            136199, -- Shadowfiend
            462324, -- interface/icons/spell_shadow_mindflay.blp
        },
        sounds = {
            629052, -- sound/spells/spell_pr_mindblast_impact.ogg
            1714480, -- sound/spells/spell_pr_revamp_shadow_mindblast_impact_01.ogg
            1714481, -- sound/spells/spell_pr_revamp_shadow_mindblast_impact_02.ogg
        },
    },
    [250] = {
        class = "DEATHKNIGHT",
        icons = {
            237517, -- Death Strike
            135675, -- Heart Strike
            237513, -- Blood Boil
            1376745, -- Marrowrend
            136168, -- Vampiric Blood
            342917, -- Bonestorm
            135277, -- Dancing Rune Weapon
        },
        sounds = {
            1272242, -- sound/spells/spell_dk_deathstrike_cast01.ogg
            1272243, -- sound/spells/spell_dk_deathstrike_cast02.ogg
            1272244, -- sound/spells/spell_dk_deathstrike_cast03.ogg
        },
    },
    [251] = {
        class = "DEATHKNIGHT",
        icons = {
            135771, -- Obliterate
            237520, -- Frost Strike
            135833, -- Howling Blast
            458718, -- Pillar of Frost
            538770, -- Remorseless Winter
            7439190, -- Frostscythe
            1029007, -- Breath of Sindragosa
        },
        sounds = {
            986405, -- sound/spells/spell_dk_obliterate_cast_01.ogg
            986407, -- sound/spells/spell_dk_obliterate_cast_02.ogg
            986409, -- sound/spells/spell_dk_obliterate_cast_03.ogg
        },
    },
    [252] = {
        class = "DEATHKNIGHT",
        icons = {
            879926, -- Festering Strike
            237530, -- Scourge Strike
            136145, -- Death Coil
            1392565, -- Apocalypse
            237511, -- Army of the Dead
            342913, -- Dark Transformation
            136132, -- Unholy Blight
        },
        sounds = {
            1273702, -- sound/spells/spell_dk_scourgestrike_cast01.ogg
            1273703, -- sound/spells/spell_dk_scourgestrike_cast02.ogg
            1273704, -- sound/spells/spell_dk_scourgestrike_cast03.ogg
        },
    },
    [262] = {
        class = "SHAMAN",
        icons = {
            237582, -- Lava Burst
            136048, -- Lightning Bolt
            136026, -- Earth Shock
            451165, -- Earthquake
            839977, -- Stormkeeper
            135813, -- Flame Shock
            651244, -- Elemental Blast
        },
        sounds = {
            569666, -- sound/spells/shaman_lavaburstimpact1.ogg
            569147, -- sound/spells/shaman_lavaburstimpact2.ogg
            568527, -- sound/spells/shaman_lavaburstimpact3.ogg
        },
    },
    [263] = {
        class = "SHAMAN",
        icons = {
            132314, -- Stormstrike
            236289, -- Lava Lash
            237577, -- Feral Spirit
            1370984, -- Crash Lightning
            524794, -- Sundering
            135845, -- Ice Strike
            136114, -- interface/icons/spell_nature_windfury.blp
        },
        sounds = {
            1369112, -- sound/spells/spell_sh_stormstrike_revamp_cast01.ogg
            1369113, -- sound/spells/spell_sh_stormstrike_revamp_cast02.ogg
            1369114, -- sound/spells/spell_sh_stormstrike_revamp_cast03.ogg
        },
    },
    [264] = {
        class = "SHAMAN",
        icons = {
            252995, -- Riptide
            6712961, -- Chain Heal
            136037, -- Healing Rain
            237586, -- Spirit Link Totem
            538569, -- Healing Tide Totem
            136089, -- Earth Shield
            136043, -- Healing Wave
        },
        sounds = {
            1937576, -- sound/spells/spell_sh_resto_chainheal_impact01.ogg
            1937577, -- sound/spells/spell_sh_resto_chainheal_impact02.ogg
            1937578, -- sound/spells/spell_sh_resto_chainheal_impact03.ogg
        },
    },
    [62] = {
        class = "MAGE",
        icons = {
            135735, -- Arcane Blast
            136096, -- Arcane Missiles
            236205, -- Arcane Barrage
            4667417, -- Arcane Surge
            136116, -- Arcane Explosion
            6035311, -- Touch of the Magi
            136031, -- Presence of Mind
        },
        sounds = {
            568341, -- sound/spells/alert_ma_arcanemissles.ogg
            568149, -- sound/spells/mage_arcanebarrage_impact1.ogg
            568678, -- sound/spells/arcaneexplosion.ogg
        },
    },
    [63] = {
        class = "MAGE",
        icons = {
            135812, -- Fireball
            135808, -- Pyroblast
            135807, -- Fire Blast
            135826, -- Flamestrike
            135824, -- Combustion
            1392549, -- Phoenix Flames
            134153, -- Dragon's Breath
        },
        sounds = {
            1686527, -- sound/spells/spell_ma_revamp_fireblast_cast_01.ogg
            568461, -- sound/spells/fireballimpacta.ogg
            1392377, -- sound/spells/spell_ma_pyroblast_impact_01.ogg
        },
    },
    [64] = {
        class = "MAGE",
        icons = {
            135846, -- Frostbolt
            135844, -- Ice Lance
            1390940, -- Flurry
            629077, -- Frozen Orb
            135857, -- Blizzard
            135838, -- Icy Veins
            1698700, -- Ray of Frost
        },
        sounds = {
            1631379, -- sound/spells/spell_ma_revamp_frostbolt_cast_01.ogg
            1631383, -- sound/spells/spell_ma_revamp_frostbolt_impact_01.ogg
            569378, -- sound/spells/frostnova.ogg
        },
    },
    [265] = {
        class = "WARLOCK",
        icons = {
            136118, -- Corruption
            136139, -- Agony
            136228, -- Unstable Affliction
            136193, -- Seed of Corruption
            236296, -- Malefic Rapture
            236298, -- Haunt
            136188, -- Siphon Life
        },
        sounds = {
            569658, -- sound/spells/unstableaffliction_impact_chest.ogg
        },
    },
    [266] = {
        class = "WARLOCK",
        icons = {
            535592, -- Hand of Gul'dan
            1378282, -- Call Dreadstalkers
            2032588, -- Demonbolt
            2065588, -- Implosion
            2065628, -- Summon Demonic Tyrant
            237562, -- Grimoire: Felguard
            1616211, -- Summon Vilefiend
        },
        sounds = {
            999327, -- sound/spells/spell_wl_demonbolt_impact_01.ogg
            999328, -- sound/spells/spell_wl_demonbolt_impact_02.ogg
            999329, -- sound/spells/spell_wl_demonbolt_impact_03.ogg
        },
    },
    [267] = {
        class = "WARLOCK",
        icons = {
            236291, -- Chaos Bolt
            135789, -- Incinerate
            135807, -- Conflagrate
            136186, -- Rain of Fire
            135817, -- Immolate
            136191, -- Shadowburn
            840407, -- Channel Demonfire
        },
        sounds = {
            2068263, -- sound/spells/spell_wl_revamp_chaosbolt_impact_01.ogg
            2068264, -- sound/spells/spell_wl_revamp_chaosbolt_impact_02.ogg
            2068265, -- sound/spells/spell_wl_revamp_chaosbolt_impact_03.ogg
        },
    },
    [268] = {
        class = "MONK",
        icons = {
            594274, -- Keg Smash
            615339, -- Breath of Fire
            574575, -- Blackout Kick
            133701, -- Purifying Brew
            1360979, -- Celestial Brew
            615341, -- Fortifying Brew
            606549, -- Rushing Jade Wind
        },
        sounds = {
            612300, -- sound/spells/spell_mk_kegsmash_01.ogg
            612302, -- sound/spells/spell_mk_kegsmash_02.ogg
            612304, -- sound/spells/spell_mk_kegsmash_03.ogg
        },
    },
    [270] = {
        class = "MONK",
        icons = {
            775461, -- Enveloping Mist
            627487, -- Renewing Mist
            1360980, -- Vivify
            1020466, -- Revival
            627485, -- Life Cocoon
            606550, -- Soothing Mist
            1360978, -- interface/icons/ability_monk_essencefont.blp
        },
        sounds = {},
    },
    [269] = {
        class = "MONK",
        icons = {
            642415, -- Rising Sun Kick
            627606, -- Fists of Fury
            606543, -- Spinning Crane Kick
            988194, -- Whirling Dragon Punch
            606552, -- Touch of Death
            136038, -- Storm, Earth, and Fire
            1282595, -- Strike of the Windlord
        },
        sounds = {},
    },
    [102] = {
        class = "DRUID",
        icons = {
            535045, -- Wrath
            135753, -- Starfire
            135730, -- Starsurge
            236168, -- Starfall
            136096, -- Moonfire
            236216, -- Sunfire
            136060, -- Celestial Alignment
        },
        sounds = {
            1597457, -- sound/spells/spell_dr_revamp_starsurge_impact_01.ogg
            1597458, -- sound/spells/spell_dr_revamp_starsurge_impact_02.ogg
            1597459, -- sound/spells/spell_dr_revamp_starsurge_impact_03.ogg
        },
    },
    [103] = {
        class = "DRUID",
        icons = {
            132122, -- Rake
            132152, -- Rip
            132127, -- Ferocious Bite
            136231, -- Shred
            451161, -- Thrash
            132242, -- Tiger's Fury
            1392547, -- Primal Wrath
        },
        sounds = {
            3055167, -- sound/spells/spell_dr_ferociousbite_revamp_impact.ogg
            3151159, -- sound/spells/spell_dr_ferociousbite_revamp_cast.ogg
        },
    },
    [104] = {
        class = "DRUID",
        icons = {
            132135, -- Mangle
            1378702, -- Ironfur
            132091, -- Frenzied Regeneration
            132136, -- Maul
            136097, -- Barkskin
            236169, -- Survival Instincts
            571586, -- Incarnation: Guardian of Ursoc
        },
        sounds = {
            569315, -- sound/spells/mangle_impact.ogg
            568496, -- sound/spells/spell_mangle_cast_01.ogg
            568676, -- sound/spells/spell_mangle_cast_02.ogg
        },
    },
    [105] = {
        class = "DRUID",
        icons = {
            136081, -- Rejuvenation
            136085, -- Regrowth
            134206, -- Lifebloom
            236153, -- Wild Growth
            134914, -- Swiftmend
            136107, -- Tranquility
            538743, -- Flourish
        },
        sounds = {
            1687852, -- sound/spells/spell_dr_revamp_rejuvenation_impact01.ogg
            1687853, -- sound/spells/spell_dr_revamp_rejuvenation_impact02.ogg
            1687854, -- sound/spells/spell_dr_revamp_rejuvenation_impact03.ogg
        },
    },
    [577] = {
        class = "DEMONHUNTER",
        icons = {
            1305152, -- Chaos Strike
            1305156, -- Eye Beam
            1305149, -- Blade Dance
            1247261, -- Fel Rush
            1247262, -- Metamorphosis
            1344649, -- Immolation Aura
            136189, -- Essence Break
        },
        sounds = {},
    },
    [581] = {
        class = "DEMONHUNTER",
        icons = {
            1344647, -- Fiery Brand
            1344653, -- Soul Cleave
            1097742, -- Spirit Bomb
            1344645, -- Demon Spikes
            1247263, -- Metamorphosis
            1344652, -- Sigil of Flame
            1344650, -- Infernal Strike
        },
        sounds = {},
    },
    [1480] = {
        class = "DEMONHUNTER",
        icons = {
            7554200, -- interface/icons/inv_12_dh_void_ability_consume.blp
            7554220, -- interface/icons/inv_12_dh_void_ability_voidray.blp
            7554199, -- interface/icons/inv_12_dh_void_ability_collapsingstar.blp
            7554201, -- interface/icons/inv_12_dh_void_ability_devourerbite.blp
            7554202, -- interface/icons/inv_12_dh_void_ability_empoweredreap.blp
            7554221, -- interface/icons/inv_12_dh_void_ability_voidreaper.blp
            7554211, -- interface/icons/inv_12_dh_void_ability_reapersslice.blp
        },
        sounds = {},
    },
    [1467] = {
        class = "EVOKER",
        icons = {
            4622451, -- Disintegrate
            4622458, -- Fire Breath
            4630444, -- Eternity Surge
            4622468, -- Pyre
            4622452, -- Dragonrage
            4622464, -- Living Flame
            4622447, -- Azure Strike
        },
        sounds = {},
    },
    [1468] = {
        class = "EVOKER",
        icons = {
            4622454, -- Dream Breath
            4622476, -- Spiritbloom
            4622456, -- Echo
            4622457, -- Emerald Blossom
            4622474, -- Rewind
            4630480, -- Temporal Anomaly
            4630467, -- Reversion
        },
        sounds = {},
    },
    [1473] = {
        class = "EVOKER",
        icons = {
            5199630, -- Eruption
            5061347, -- Ebon Might
            5199639, -- Prescience
            5199647, -- Upheaval
            5199622, -- Breath of Eons
            5199621, -- Blistering Scales
            4630412, -- Source of Magic
        },
        sounds = {},
    },
}
