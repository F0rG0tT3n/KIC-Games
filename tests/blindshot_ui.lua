local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = h.client("UIBlindshot", "Realm")
local G, B = owner.games, owner.games.Blindshot
local R, checks = B.Rules, 0
local function check(v, why)
    assert(v, why)
    checks = checks + 1
end
owner.roster = { "Other-Realm", "Third-Realm", "Fourth-Realm", "Fifth-Realm" }
owner.env.SetPortraitTexture = function(texture, unit)
    texture.portraitUnit = unit
end
G.Lobby = {
    id = "ui-blindshot",
    host = owner.name,
    channel = "PARTY",
    revision = 1,
    run = 1,
    epoch = 0,
    startedAt = owner.env.GetServerTime(),
    mode = "multiplayer",
    countdownToken = 0,
    gameID = "blindshot",
    gameVersion = G.Registry.blindshot.version,
    gameTitle = "Blindshot",
    maxPlayers = 5,
    status = "running",
    members = {},
}
for _, name in ipairs({ owner.name, table.unpack(owner.roster) }) do
    G.Lobby.members[#G.Lobby.members + 1] = { name = name, ready = true, version = G.Registry.blindshot.version }
end
check(G:StartModule(), "Blindshot UI constructor failed")
local previousProtocol = G.Copy(G.Lobby)
previousProtocol.gameVersion = "4"
for _, member in ipairs(previousProtocol.members) do
    member.version = "4"
end
check(
    B:SessionValid(G.Lobby) and not B:SessionValid(previousProtocol),
    "Protocol 5 accepted incompatible earlier controls/radius rules"
)
R.BeginAim(B.authority, owner.env.GetServerTime())
B:Publish()
check(B.root:IsVisible() and G.UI.gameContainer:IsVisible(), "Blindshot UI not shown")
check(B.hero.textureValue == G.Artwork["blindshot-hero"].file, "Gameplay hero artwork unused")
check(G.Registry.blindshot.icon == G.Artwork["blindshot-card"].file, "Launcher card artwork unused")
local function mouse(x, y)
    local px, py = B:Project(x, y)
    local scale = B.arena:GetEffectiveScale()
    owner.env.cursorX = (B.arena:GetLeft() + px) * scale
    owner.env.cursorY = (B.arena:GetTop() - py) * scale
end
local function click(x, y, button)
    mouse(x, y)
    owner.env.mouseDown = true
    B.arena.scripts.OnMouseDown(B.arena, button or "LeftButton")
    owner.env.mouseDown = false
    B.arena.scripts.OnMouseUp(B.arena, button or "LeftButton")
end
local held = {}
owner.env.IsMouseButtonDown = function(button)
    return held[button] == true
end
local function press(x, y, button)
    mouse(x, y)
    held[button] = true
    B.arena.scripts.OnMouseDown(B.arena, button)
end
local function release(button)
    held[button] = nil
    B.arena.scripts.OnMouseUp(B.arena, button)
end
local sent = 0
local send = B.context.SendAction
B.context.SendAction = function(...)
    sent = sent + 1
    return send(...)
end
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    G.UI:SetWindowScale(scale)
    check(B.arena:GetWidth() > 450 and B.unit > 150, "Arena too small")
    click(-240, 190)
    check(math.abs(B.draft.x + 240) <= 1 and math.abs(B.draft.y - 190) <= 1, "Scaled positioning offset")
    press(-100, 190, "LeftButton")
    check(B.draft.x == -100, "Press did not move immediately")
    mouse(-240, 190)
    B.arena.scripts.OnUpdate()
    check(B.draft.x == -240 and B.draft.y == 190, "Held movement did not follow cursor")
    release("LeftButton")
    check(not B.arena.scripts.OnUpdate, "Idle mouse tracking remains active")
    click(300, 190, "RightButton")
    check(B.draft.dx == 1000 and math.abs(B.draft.dy) <= 2, "Scaled aim direction incorrect")
    press(-240, 600, "RightButton")
    check(B.draft.dy == 1000 and B.draft.dx == 0, "Right press did not aim immediately")
    mouse(300, 190)
    B.arena.scripts.OnUpdate()
    check(B.draft.x == -240 and B.draft.dx == 1000 and B.draft.dy == 0, "Held aim moved token or failed to rotate")
    release("RightButton")
    check(not B.mouseButtons and not B.arena.scripts.OnUpdate, "Released mouse stayed active")
    click(1000, 1000)
    check(R.Position(B.draft.x, B.draft.y, B.view.radius) and B.draft.x > 670, "Boundary did not clamp token hitbox")
    local visible = 0
    for _, marker in ipairs(B.markers) do
        if marker:IsShown() then
            visible = visible + 1
        end
    end
    check(visible == 1 and B.markers[1]:IsShown(), "Enemy marker visible during AIM")
    check(B.beams.used == 4 and B.lockButton:IsEnabled(), "Own aim line / lock control missing")
    local x0, y0 = B:Project(0, 0)
    local east = B:Project(500, 0)
    local _, north = B:Project(0, 500)
    check(math.abs(east - x0 - (y0 - north)) < 0.001, "Arena projection gives an axis advantage")
    check(B.floor:GetWidth() == B.floor:GetHeight() and B.cy - B.unit >= 116, "Arena is oval or overlaps its header")
    local marker = B.markers[1]
    local mx, my = B:Project(B.draft.x, B.draft.y)
    check(
        math.abs(marker.points[1][2] + 48 - mx) < 0.001 and math.abs(-marker.points[1][3] + 48 - my) < 0.001,
        "Token is offset from its simulation position"
    )
    check(
        math.abs(marker.body:GetWidth() - 2 * R.HIT * B.unit / 1000) < 0.001
            and marker.body:GetWidth() == marker.body:GetHeight(),
        "Visible token body differs from circular hitbox"
    )
    check(-B.backButton.points[1][3] >= -B.lockButton.points[1][3] + B.lockButton:GetHeight() + 6, "Controls overlap")
end
check(sent == 0 and not B.authority.drafts[owner.name], "Mouse movement transmitted a draft")
-- Release outside the arena is detected without permanent cursor polling.
press(0, 0, "LeftButton")
mouse(1400, 0)
B.arena.scripts.OnUpdate()
local releasedX = B.draft.x
held.LeftButton = nil
B.arena.scripts.OnUpdate()
mouse(-1400, 0)
check(
    not B.mouseButtons and not B.arena.scripts.OnUpdate and B.draft.x == releasedX,
    "Off-frame release lost position or kept tracking"
)
-- Timeout, layout and hide terminate an active hold, retaining the latest input.
for _, cancellation in ipairs({ "timeout", "resize", "hide" }) do
    press(0, 0, "LeftButton")
    mouse(100, 100)
    B.arena.scripts.OnUpdate()
    local deadline = B.view.deadline
    if cancellation == "timeout" then
        B.view.deadline = B:Now() - 1
        B.arena.scripts.OnUpdate()
        B.view.deadline = deadline
    elseif cancellation == "resize" then
        G.UI:SetWindowSize(1000, 700)
    else
        B.root:Hide()
        B.root:Show()
    end
    held.LeftButton = nil
    check(
        not B.mouseButtons and not B.arena.scripts.OnUpdate and B.draft.x == 100,
        "Hold cancellation failed: " .. cancellation
    )
end
G.UI:SetWindowSize(1120, 700)
for _, size in ipairs({ { 1000, 700 }, { 1120, 700 }, { 1500, 900 } }) do
    G.UI:SetWindowSize(size[1], size[2])
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        G.UI:SetWindowScale(scale)
        check(B.cx - B.unit >= 0 and B.cx + B.unit <= B.arena:GetWidth(), "Circular arena clipped horizontally")
        check(
            B.cy - B.unit >= 116 and B.cy + B.unit < B.arena:GetHeight() - 38,
            "Circular arena overlaps order/header/footer"
        )
    end
end
G.UI:SetWindowSize(1120, 700)
G.UI:SetWindowScale(1)
-- Exercise cursor conversion through the same animated camera used at shrink.
for _, radius in ipairs({ 558, 314, 150, 1000 }) do
    local oldUnit = B.unit
    B.view.radius = radius
    B:Render()
    check(B.zoomMotion and B.unit == oldUnit, "Zoom jumped instead of animating")
    h.advance(0.225)
    B.arena.scripts.OnUpdate()
    check(B.zoomMotion and B.unit ~= oldUnit, "Camera did not interpolate")
    click(0, 0)
    h.advance(0.23)
    B.arena.scripts.OnUpdate()
    check(not B.zoomMotion and not B.arena.scripts.OnUpdate, "Finished zoom kept an idle update")
    check(math.abs(B.unit * radius / 1000 - B.baseUnit) < 0.001, "Shrink changed visible floor padding")
    for _, scale in ipairs({ 0.75, 1, 1.5 }) do
        G.UI:SetWindowScale(scale)
        click(50, -40)
        click(50, 100, "RightButton")
        check(
            B.draft.x == 50 and B.draft.y == -40 and B.draft.dy == 1000 and B.draft.dx == 0,
            "Zoomed cursor mapping incorrect"
        )
        click(2000, -2000)
        check(R.Position(B.draft.x, B.draft.y, radius), "Zoomed placement escaped circle")
    end
end
G.UI:SetWindowScale(1)
check(sent == 0 and not B.authority.drafts[owner.name], "Camera/input sent unlocked choices")
press(200, 100, "LeftButton")
mouse(300, 100)
B.arena.scripts.OnUpdate()
local old = G.Copy(B.draft)
B.lockButton.scripts.OnClick()
held.LeftButton = nil
check(not B.mouseButtons and not B.arena.scripts.OnUpdate, "Lock did not stop mouse tracking")
check(not B:CanInput() and B.lockButton.text == "Locked In", "Lock button did not lock local choice")
click(0, 0)
click(-300, -300, "RightButton")
check(B.draft.x == old.x and B.draft.y == old.y, "Locked marker moved")
check(B.draft.dx == old.dx and B.draft.dy == old.dy, "Locked aim changed")
for i = 2, 5 do
    B.authority.drafts[owner.roster[i - 1]] = { x = (i - 3) * 160, y = -220, dx = 0, dy = 1000, seq = 1, lock = true }
    B.authority.players[i].locked = true
end
R.Reveal(B.authority, owner.env.GetServerTime())
B:Publish()
for rank, index in ipairs(B.view.order) do
    local label = B.orderLabels[rank]
    local expected = B.view.players[index].name:match("^[^-]+")
    check(
        label:IsShown() and label.text:gsub("\n", ""):find(expected, 1, true),
        "Firing order omitted actual player name"
    )
end
local identities = {
    { name = "Longcharactername-Extremelylongrealmidentityone" },
    { name = "Longcharactername-Extremelylongrealmidentitytwo" },
    { name = "Unique-Realm" },
    { name = "Fourthcharacter-Anotherextremelylongrealmidentity" },
    { name = "Fifthcharacter-Anotherextremelylongrealmidentity" },
}
local names = B:DisplayNames(identities)
check(
    names[1] == identities[1].name and names[2] == identities[2].name and names[3] == "Unique",
    "Ambiguous names lost realm identity"
)
B:LayoutFiringOrder({ order = { 1, 2, 3, 4, 5 }, current = 2 }, names)
for rank = 1, 5 do
    check(
        B.orderLabels[rank].text:gsub("\n", "") == "#" .. rank .. " " .. names[rank],
        "Long firing name was truncated"
    )
end
check(
    B.orderList:GetHeight() > 64 and B.orderGlows[2]:IsShown(),
    "Long names lack adaptive scrolling/current highlight"
)
B:Render()
for _, marker in ipairs(B.markers) do
    check(marker:IsShown(), "Reveal hid a participant")
    check(marker.portrait.maskTexture == marker.mask and marker.portrait.portraitUnit, "Portrait/mask missing")
    check(marker.badge:IsShown() and tonumber(marker.order.text), "Firing number missing")
end
check(B.markers[1].localRing:IsShown() and not B.markers[2].localRing:IsShown(), "Local player indication missing")
check(B.markers[1].tag.text:find("YOU", 1, true), "Local player label unclear")
check(B.beams.used == 20, "Reveal does not draw all five beams and arrowheads")
B.notice = "Locked in. Waiting for the reveal."
R.Resolve(B.authority, owner.env.GetServerTime())
h.advance(1)
B:Publish()
check(B.clock.text == "SEQUENTIAL FIRE", "Simultaneous firing phase unclear")
check(not B.ownState.text:find("hidden", 1, true) and not B.notice, "Firing UI retained hidden/lock hint")
check(B.participants:GetHeight() >= B.participantsFrame:GetHeight(), "Player list lacks scrolling")
local pool = #B.platformPool
local frames = #owner.frames
for _ = 1, 15 do
    B:Render()
end
check(#B.platformPool == pool and #B.beams <= 20, "Rendering leaks textures")
check(
    #owner.frames == frames and B.floor:GetWidth() == B.floor:GetHeight(),
    "Animation reallocates textures or circular floor missing"
)
-- Elimination removes local input and every marker during subsequent hidden aim.
B.authority.players[1].alive, B.authority.players[1].deathRound = false, 1
B.authority.round, B.authority.radius = 2, R.Radius(2)
R.BeginAim(B.authority, owner.env.GetServerTime())
B:Publish()
for _, marker in ipairs(B.markers) do
    check(not marker:IsShown(), "Spectator sees hidden markers")
end
check(not B.lockButton:IsEnabled() and not B:CanInput(), "Eliminated player can act")
B:HostAction({ id = B.authority.id, round = 2, seq = 99, x = 0, y = 0, dx = 1000, dy = 0, lock = true }, owner.name)
check(not B.authority.drafts[owner.name], "Eliminated player forged a round action")
B.backButton.scripts.OnClick()
check(B.running and not B.root:IsVisible(), "Back to Launcher stopped match")
G.UI:LaunchGame("blindshot")
check(B.running and B.root:IsVisible(), "Resume lost game UI")
check(
    not G.Chess.root and not G.Bejeweled.root and not G.KICBejeweled.root and not G.Tetris.root,
    "Blindshot built unrelated UI"
)
print(
    string.format(
        "PASS: %d Blindshot artwork, hidden markers, scaled placement/aim, lock, reveal and resume assertions",
        checks
    )
)
