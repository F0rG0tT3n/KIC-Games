local addonName, Games = ...
local base = "Interface\\AddOns\\" .. addonName .. "\\Media\\KICUI\\"
Games.Artwork = {
    logo = { file = base .. "logo-d20.tga", width = 256, height = 256 },
    crest = { file = base .. "crest-lion.tga", width = 256, height = 256 },
    sidebar = { file = base .. "sidebar-decor.tga", width = 512, height = 1024 },
    hall = { file = base .. "background-hall.tga", width = 1024, height = 512 },
    ["bejeweled-hero"] = { file = base .. "bejeweled-hero.tga", width = 1024, height = 512, textSide = "right" },
    ["bejeweled-card"] = { file = base .. "bejeweled-card.tga", width = 256, height = 256 },
    ["tetris-hero"] = { file = base .. "tetris-hero.tga", width = 1024, height = 512, textSide = "left" },
    ["tetris-card"] = { file = base .. "tetris-card.tga", width = 256, height = 256 },
    -- Replace file=false with final TGA paths. All fallback geometry stays native.
    ["window-frame"] = { file = false, width = 1120, height = 700, fallback = "border" },
    ["button-frame"] = { file = false, width = 256, height = 64, fallback = "border" },
    ["stat-frame"] = { file = false, width = 512, height = 128, fallback = "premium-border" },
    ["card-frame"] = { file = false, width = 512, height = 512, fallback = "premium-border" },
    ["status-frame"] = { file = false, width = 512, height = 128, fallback = "premium-border" },
    ["generic-hero"] = { file = false, width = 1024, height = 512, fallback = "module-icon" },
    ["generic-card"] = { file = false, width = 256, height = 256, fallback = "module-icon" },
    ["nav-home"] = { file = base .. "Navigation/nav-home.tga", width = 64, height = 64 },
    ["nav-singleplayer"] = { file = base .. "Navigation/nav-singleplayer.tga", width = 64, height = 64 },
    ["nav-multiplayer"] = { file = base .. "Navigation/nav-multiplayer.tga", width = 64, height = 64 },
    ["nav-results"] = { file = base .. "Navigation/nav-results.tga", width = 64, height = 64 },
    ["nav-options"] = { file = base .. "Navigation/nav-options.tga", width = 64, height = 64 },
}
