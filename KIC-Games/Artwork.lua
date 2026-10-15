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
    ["generic-hero"] = { file = false, width = 1024, height = 512, fallback = "module-icon" },
    ["generic-card"] = { file = false, width = 256, height = 256, fallback = "module-icon" },
    ["nav-home"] = { file = false, width = 32, height = 32, glyph = "H" },
    ["nav-singleplayer"] = { file = false, width = 32, height = 32, glyph = "1" },
    ["nav-multiplayer"] = { file = false, width = 32, height = 32, glyph = "M" },
    ["nav-results"] = { file = false, width = 32, height = 32, glyph = "R" },
    ["nav-options"] = { file = false, width = 32, height = 32, glyph = "O" },
}
