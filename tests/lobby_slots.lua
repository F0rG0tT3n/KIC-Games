local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = h.client("SlotHost", "Realm")
local G, U = owner.games, owner.games.UI
owner.roster = { "Guest-Realm", "Third-Realm", "Fourth-Realm", "Fifth-Realm" }
local checks = 0
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
local function visible()
    local count = 0
    for _, slot in ipairs(U.lobbySlots) do
        if slot:IsShown() then
            count = count + 1
        end
    end
    return count
end
check(G:CreateLobby("chess"), "Could not host Chess")
U:OpenLauncher("multiplayer")
check(visible() == 2 and U.lobbySlotCount == 2, "Chess did not show exactly two slots")
check(U.lobbySlots[1].name.text == owner.name and U.lobbySlots[1].role.text == "HOST", "Host name/indicator missing")
check(
    U.lobbySlots[2].name.text == "Open Slot" and U.lobbySlots[2].role.text == "WAITING FOR PLAYER",
    "Empty slot not labeled"
)
check(not U.players:IsShown(), "Old roster text overlaps slots")
G.Lobby.members[2] = { name = owner.roster[1], ready = false, version = G.Registry.chess.version }
U:Refresh()
check(
    U.lobbySlots[2].name.text == owner.roster[1] and U.lobbySlots[2].state.text == "Not ready",
    "Joined player did not fill slot"
)
G.Lobby.members[2].ready = true
U:Refresh()
check(U.lobbySlots[2].state.text == "Ready", "Ready state not shown")
G.Lobby.status = "countdown"
G.Lobby.countdownAt = owner.env.GetServerTime() + 3
U:Refresh()
check(visible() == 2 and U.lobbySlots[2].state.text == "Ready", "Countdown changed slot capacity")
G.Lobby.status = "waiting"
check(G:SelectGame("blindshot"), "Could not change selected game")
U:Refresh()
check(visible() == 5 and U.lobbySlotCount == 5, "Blindshot did not show five slots")
check(
    U.lobbySlots[3].name.text == "Open Slot" and U.lobbySlots[5].name.text == "Open Slot",
    "Party members filled slots without joining"
)
for i = 2, 5 do
    G.Lobby.members[i] = { name = owner.roster[i - 1], ready = true, version = G.Registry.blindshot.version }
end
U:Refresh()
for i = 1, 5 do
    check(U.lobbySlots[i].name.text ~= "Open Slot", "Full lobby has an empty slot")
end
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    U:SetWindowScale(scale)
    U:Refresh()
    local boxes = {}
    for i, slot in ipairs(U.lobbySlots) do
        local x = slot.points[1][2]
        local y = -slot.points[1][3]
        check(x >= 0 and x + slot:GetWidth() <= U.slotArea:GetWidth() + 0.01, "Slot overflows lobby area")
        for _, box in ipairs(boxes) do
            check(
                x >= box.x + box.w
                    or x + slot:GetWidth() <= box.x
                    or y >= box.y + box.h
                    or y + slot:GetHeight() <= box.y,
                "Slot cards overlap"
            )
        end
        boxes[#boxes + 1] = { x = x, y = y, w = slot:GetWidth(), h = slot:GetHeight() }
    end
    check(
        -U.slotScroll.points[1][3] + U.slotScroll:GetHeight() <= -U.countdownText.points[1][3] - 8,
        "Slots overlap countdown"
    )
    check(-U.hint.points[1][3] + U.hint:GetHeight() <= -U.ready.points[1][3] - 4, "Hint overlaps controls")
end
U:SetWindowSize(1000, 700)
check(
    U.slotArea:GetHeight() <= U.slotScroll:GetHeight() + 0.01,
    "Five slots unnecessarily scroll at minimum supported window size"
)
G.Lobby.status = "running"
U:Refresh()
check(U.lobbySlots[3].state.text == "Playing", "Live player state missing")
G.Lobby.status = "waiting"
G.Lobby.members[5] = nil
U:Refresh()
check(
    U.lobbySlots[5].name.text == "Open Slot" and U.lobbySlots[5].role.text == "WAITING FOR PLAYER",
    "Departed player left stale name"
)
G.Lobby.members[4], G.Lobby.members[3] = nil, nil
check(G:SelectGame("chess"), "Could not switch capacity back to Chess")
U:Refresh()
check(
    visible() == 2 and not U.lobbySlots[3]:IsShown() and not U.lobbySlots[5]:IsShown(),
    "Extra slots survived capacity reduction"
)
G:LeaveLobby()
U:Refresh()
check(
    visible() == 0 and U.browserPanel:IsVisible() and not U.lobbyPanel:IsVisible(),
    "Leaving lobby did not return to browser"
)
for _, notice in ipairs(owner.notices) do
    check(not notice:find(" / CreateUI:", 1, true), notice)
end
print(
    string.format("PASS: %d lobby capacity, open/join/leave slots, player states and scaled layout assertions", checks)
)
