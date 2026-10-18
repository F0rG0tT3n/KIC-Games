local previous = arg[1]
arg[1] = "--harness"
local h = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local owner = h.client("AnnounceHost", "Realm")
local G, U = owner.games, owner.games.UI
owner.roster = { "AnnounceGuest-Realm", "Third-Realm", "Fourth-Realm", "Fifth-Realm" }
local checks = 0
local function check(value, why)
    assert(value, why)
    checks = checks + 1
end
check(not G:AnnounceLobby() and #owner.chatMessages == 0, "Announced without a lobby")
check(G:CreateLobby("chess"), "Could not host Chess")
U:OpenLauncher("multiplayer")
check(#owner.chatMessages == 0, "Hosting automatically announced")
check(U.announceLobby:IsVisible() and U.announceLobby:IsEnabled(), "Host announce button missing/disabled")
U.announceLobby.scripts.OnClick()
local sent = owner.chatMessages[1]
check(#owner.chatMessages == 1 and sent.channel == "PARTY", "Button did not send exactly once to party chat")
check(sent.message == "KIC-Games: I created a lobby: Chess (1/2 players).", "Wrong Chess title or occupancy")
check(not G.Lobby.members[1].ready and G.Lobby.status == "waiting", "Announce changed readiness or started the game")
G.Lobby.members[2] = { name = owner.roster[1], ready = false, version = G.Registry.chess.version }
U:Refresh()
check(#owner.chatMessages == 1, "Refresh/join automatically announced")
check(
    G:AnnounceLobby() and owner.chatMessages[2].message:find("Chess (2/2", 1, true),
    "Announce used stale joined count"
)
local guest = h.client("AnnounceGuest", "Realm")
guest.roster = { owner.name }
guest.games.Lobby = G.Copy(G.Lobby)
guest.games.UI:OpenLauncher("multiplayer")
check(not guest.games.UI.announceLobby:IsShown(), "Guest sees host-only announcement action")
check(not guest.games:AnnounceLobby() and #guest.chatMessages == 0, "Guest could announce through the handler")
guest.games.UI.announceLobby.scripts.OnClick()
check(#guest.chatMessages == 0 and #guest.notices > 0, "Stale/forged guest click sent chat")
check(G:SelectGame("blindshot"), "Could not switch to Blindshot")
check(
    G:AnnounceLobby() and owner.chatMessages[3].message:find("Blindshot (2/5", 1, true),
    "Game change retained old name/capacity"
)
for i = 3, 5 do
    G.Lobby.members[i] = { name = owner.roster[i - 1], ready = false, version = G.Registry.blindshot.version }
end
check(G:AnnounceLobby() and owner.chatMessages[4].message:find("Blindshot (5/5", 1, true), "Full lobby count wrong")
G.Lobby.members[5] = nil
check(
    G:AnnounceLobby() and owner.chatMessages[5].message:find("Blindshot (4/5", 1, true),
    "Departed player still counted"
)
for _, scale in ipairs({ 0.75, 1, 1.5 }) do
    U:SetWindowScale(scale)
    U:Refresh()
    local b = U.announceLobby
    check(b:IsVisible() and b:GetWidth() >= 160, "Announce button disappeared or is too narrow")
    local x, y = b.points[1][2], -b.points[1][3]
    local leaveX, readyX = U.leave.points[1][2], U.ready.points[1][2]
    check(x >= leaveX + U.leave:GetWidth() + 8 and x + b:GetWidth() <= readyX - 8, "Announce overlaps lobby controls")
    check(y + b:GetHeight() <= U.lobbyPanel:GetHeight() - 8, "Announce extends outside lobby")
end
local before = #owner.chatMessages
G.Lobby.countdownAt = owner.env.GetServerTime() + 3
for _, status in ipairs({ "countdown", "running" }) do
    G.Lobby.status = status
    U:Refresh()
    check(not U.announceLobby:IsShown() and not G:AnnounceLobby(), "Announced a starting/running game")
end
G.Lobby.status = "waiting"
for _, channel in ipairs({ "RAID", "INSTANCE_CHAT" }) do
    owner.channel = channel
    check(not G:AnnounceLobby(), "Announcement escaped to a different group")
end
owner.grouped = false
check(not G:AnnounceLobby() and #owner.chatMessages == before, "Ungrouped host sent chat")
owner.grouped, owner.channel = true, "PARTY"
-- Future modules reuse the group channel already chosen by their lobby.
G:RegisterGame({
    id = "announce_fixture",
    title = "Other | Game",
    version = "1",
    mode = "multiplayer",
    minPlayers = 2,
    maxPlayers = 5,
    OnStart = function() end,
    CreateUI = function() end,
})
G.Lobby.gameID = "announce_fixture"
for _, channel in ipairs({ "RAID", "INSTANCE_CHAT" }) do
    owner.channel, G.Lobby.channel = channel, channel
    check(
        G:AnnounceLobby() and owner.chatMessages[#owner.chatMessages].channel == channel,
        "Generic lobby ignored its group channel"
    )
    check(not owner.chatMessages[#owner.chatMessages].message:find("|", 1, true), "Unsafe pipe in announced title")
end
owner.channel, G.Lobby.channel, G.Lobby.gameID = "PARTY", "PARTY", ""
U:Refresh()
check(not U.announceLobby:IsEnabled() and not G:AnnounceLobby(), "No-game lobby could announce")
G:LeaveLobby()
U:Refresh()
check(not U.announceLobby:IsShown() and not G:AnnounceLobby(), "Closed lobby retained announcement action")
print(string.format("PASS: %d host-only lobby announce, chat, occupancy, state and layout assertions", checks))
