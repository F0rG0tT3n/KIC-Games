local _, Games = ...
local T, Shared = Games.Tetris, Games.IconPresets
T.Presets, T.ByToken, T.FallbackIcons, T.Colors = Shared.Presets, Shared.ByToken, Shared.FallbackIcons, Shared.Colors
function T:GetIcons(token)
    return Shared:GetIcons(token)
end
