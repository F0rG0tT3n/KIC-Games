-- Run from D:\WowAddons: lua KIC-Games/tests/framework.lua
-- Loads the actual bundled libraries and addon in isolated WoW client environments.
local root = "KIC-Games/KIC-Games/"
local now, clients, packets = 100, {}, {}
local tests = 0
local function check(condition, message)
    assert(condition, message)
    tests = tests + 1
end

local function client(name, realm)
    local frames, notices, env = {}, {}, {}
    setmetatable(env, { __index = _G })
    env._G, env.unpack = env, table.unpack
    env.table = setmetatable({
        wipe = function(t)
            for k in pairs(t) do
                t[k] = nil
            end
            return t
        end,
    }, { __index = table })
    env.math = setmetatable({
        atan2 = function(y, x)
            return math.atan(y, x)
        end,
    }, { __index = math })
    env.SlashCmdList, env.UISpecialFrames = {}, {}
    env.LE_PARTY_CATEGORY_INSTANCE = 2
    env.Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, NotInGroup = 5 } }
    env.GetTime = function()
        return now
    end
    env.GetServerTime = function()
        return 1800000000 + math.floor(now)
    end
    env.GetFramerate = function()
        return 60
    end
    env.GetNormalizedRealmName = function()
        return realm
    end
    env.Ambiguate = function(value)
        return value
    end
    env.securecallfunction = function(fn, ...)
        return fn(...)
    end
    env.geterrorhandler = function()
        return function(err)
            error(err)
        end
    end
    env.hooksecurefunc = function() end
    env.GetCursorPosition = function()
        return 0, 0
    end
    local c = {
        name = name .. "-" .. realm,
        frames = frames,
        env = env,
        notices = notices,
        roster = {},
        grouped = true,
        channel = "PARTY",
        tokens = 10,
        lastRefill = now,
        throttleCount = 0,
    }
    clients[#clients + 1] = c
    env.IsInGroup = function(category)
        return c.grouped and (not category or c.channel == "INSTANCE_CHAT")
    end
    env.IsInRaid = function()
        return c.grouped and c.channel == "RAID"
    end
    env.GetNumSubgroupMembers = function()
        return c.grouped and #c.roster or 0
    end
    env.GetNumGroupMembers = function()
        return #c.roster + 1
    end
    env.UnitGUID = function()
        return "Player-1-" .. name
    end
    env.UnitFullName = function(unit)
        if unit == "player" then
            return name, realm
        end
        local index = tonumber(unit:match("%d+"))
        local full = c.roster[index]
        if full then
            return full:match("^(.-)%-(.*)$")
        end
    end
    local methods = {}
    function methods:SetScript(kind, fn)
        self.scripts[kind] = fn
    end
    function methods:RegisterEvent(kind)
        self.events[kind] = true
    end
    function methods:UnregisterAllEvents()
        self.events = {}
    end
    function methods:Show()
        self.shown = true
    end
    function methods:Hide()
        self.shown = false
    end
    function methods:IsShown()
        return self.shown
    end
    function methods:SetShown(value)
        self.shown = not not value
    end
    function methods:Enable()
        self.enabled = true
    end
    function methods:Disable()
        self.enabled = false
    end
    function methods:SetText(value)
        self.text = value
    end
    function methods:GetCenter()
        return 0, 0
    end
    function methods:GetEffectiveScale()
        return 1
    end
    for _, method in ipairs({
        "SetPoint",
        "ClearAllPoints",
        "SetSize",
        "SetHeight",
        "SetWidth",
        "SetJustifyH",
        "SetTextColor",
        "SetSpacing",
        "SetBackdrop",
        "SetBackdropColor",
        "SetBackdropBorderColor",
        "SetAllPoints",
        "SetFrameStrata",
        "SetClampedToScreen",
        "SetMovable",
        "EnableMouse",
        "RegisterForDrag",
        "SetScrollChild",
        "SetHighlightTexture",
        "SetTexture",
        "SetTexCoord",
        "StartMoving",
        "StopMovingOrSizing",
        "SetOwner",
        "AddLine",
    }) do
        methods[method] = function() end
    end
    local function widget(parent)
        local w = setmetatable(
            { scripts = {}, events = {}, shown = true, enabled = true, parent = parent },
            { __index = methods }
        )
        frames[#frames + 1] = w
        return w
    end
    function methods:CreateFontString()
        return widget(self)
    end
    function methods:CreateTexture()
        return widget(self)
    end
    function methods:SetNormalTexture()
        self.texture = widget(self)
    end
    function methods:GetNormalTexture()
        return self.texture
    end
    env.CreateFrame = function(_, globalName, parent)
        local w = widget(parent)
        if globalName then
            env[globalName] = w
        end
        return w
    end
    env.UIParent, env.Minimap, env.GameTooltip = widget(), widget(), widget()
    env.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, value)
            notices[#notices + 1] = value
        end,
    }
    env.C_Timer = {
        NewTicker = function(_, fn)
            c.tick = fn
            return {}
        end,
    }
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function()
            return 0
        end,
        SendChatMessage = function() end,
        SendAddonMessageLogged = function()
            return 0
        end,
        SendAddonMessage = function(prefix, body, channel)
            check(#body <= 255, "Transport exceeded WoW's 255-byte limit")
            c.tokens = math.min(10, c.tokens + now - c.lastRefill)
            c.lastRefill = now
            if c.tokens < 1 then
                c.throttleCount = c.throttleCount + 1
                return 3
            end
            c.tokens = c.tokens - 1
            packets[#packets + 1] = { prefix = prefix, body = body, channel = channel, sender = c.name }
            return 0
        end,
    }
    function c:event(kind, ...)
        for _, frame in ipairs(frames) do
            if frame.events[kind] and frame.scripts.OnEvent then
                frame.scripts.OnEvent(frame, kind, ...)
            end
        end
    end
    local namespace = {}
    for line in io.lines(root .. "KIC-Games.toc") do
        if line:match("%.lua$") then
            assert(loadfile(root .. line:gsub("\\", "/"), "t", env))("KIC-Games", namespace)
        end
    end
    c.games = namespace
    c:event("ADDON_LOADED", "KIC-Games")
    c:event("PLAYER_LOGIN")
    return c
end

local function pump(seconds)
    for _ = 1, math.ceil((seconds or 8) * 10) do
        now = now + 0.1
        for _, c in ipairs(clients) do
            for _, frame in ipairs(c.frames) do
                if frame.shown and frame.scripts.OnUpdate then
                    frame.scripts.OnUpdate(frame, 0.1)
                end
            end
        end
        local delivery = packets
        packets = {}
        for _, packet in ipairs(delivery) do
            for _, c in ipairs(clients) do
                c:event("CHAT_MSG_ADDON", packet.prefix, packet.body, packet.channel, packet.sender)
            end
        end
    end
end

local a, b, stranger = client("Anna", "RealmOne"), client("Bela", "RealmTwo"), client("Outside", "Elsewhere")
a.roster, b.roster = { b.name }, { a.name }
local A, B = a.games, b.games
local function register(c, version)
    c.started, c.stopped, c.messages, c.synced = 0, 0, {}, 0
    c.games:RegisterGame({
        id = "fixture",
        title = "Test fixture",
        description = "Test-only module",
        version = version,
        minPlayers = 2,
        maxPlayers = 5,
        CreateUI = function(_, parent)
            return c.env.CreateFrame("Frame", nil, parent)
        end,
        OnStart = function(ctx, session, restored)
            c.started = c.started + 1
            c.context, c.restored = ctx, restored
            check(#session.members == 2, "Start snapshot lost participants")
        end,
        OnStop = function()
            c.stopped = c.stopped + 1
        end,
        OnMessage = function(_, event, data, sender, mode)
            c.messages[#c.messages + 1] = { event = event, data = data, sender = sender, mode = mode }
        end,
        OnSyncRequested = function(ctx, sender)
            c.synced = c.synced + 1
            ctx:SendState("restore", { value = 7 }, sender)
        end,
    })
end

check(#A:GetGames() == 0 and A.UI.emptyGames:IsShown(), "Empty library must not include a fake game")
A.UI:Toggle()
check(A.UI.frame:IsShown(), "Slash/minimap launcher failed to open")
a.env.SlashCmdList.KICGAMES("")
check(not A.UI.frame:IsShown(), "Slash command failed to close")
a.grouped = false
check(not A:CreateLobby(), "Solo player must not create a multiplayer lobby")
a.grouped = true
check(A:CreateLobby(), "Host failed to create an empty lobby")
pump()
check(B.Listings[a.name] ~= nil, "Cross-realm party member did not discover lobby")
check(stranger.games.Listings[a.name] == nil, "Outside-group sender was trusted")
check(B:JoinLobby(a.name, A.Lobby.id), "Guest join request failed")
pump()
check(B.Lobby and #A.Lobby.members == 2 and #B.Lobby.members == 2, "Join did not synchronize members")
check(not A:StartGame(), "Empty framework must not start a game")
register(a, "1")
register(b, "2")
check(A:SelectGame("fixture"), "Host game selection failed")
pump()
check(not B:Ready(true), "Incompatible game version was allowed to ready")
check(not B:SelectGame("fixture"), "Guest changed the selected game")
check(A.Lobby.members[2].version == "2", "Game compatibility handshake failed")
B.Registry.fixture.version = "1"
check(B:Ready(true), "Compatible guest could not ready")
pump()
check(A:Ready(true) and A:CanStart(), "Host/guest readiness was not shared")
check(A:StartGame(), "Ready game failed to start")
pump()
check(
    a.started == 1 and b.started == 1 and A.ActiveGame and B.ActiveGame,
    "Module lifecycle did not start exactly once"
)
check(a.synced == 1 and b.messages[#b.messages].event == "restore", "Initial game state was not requested from host")
check(a.context:SendAction("move", { x = 3 }), "Host action failed")
check(b.context:SendAction("move", { x = 4 }), "Guest action failed")
pump()
check(
    a.messages[#a.messages].sender == b.name and a.messages[#a.messages].mode == "action",
    "Action did not reach the authoritative host"
)
local payload = { text = string.rep("abc^~\n", 400), number = 12.5 }
check(a.context:SendState("large", payload), "Multipart state failed to queue")
pump(30)
check(
    b.messages[#b.messages].event == "large" and b.messages[#b.messages].data.text == payload.text,
    "Multipart/escaped payload was corrupted"
)
check(a.context:SendState("only-host", {}, a.name), "Targeted state failed")
pump()
check(b.messages[#b.messages].event == "large", "Targeted state leaked to another player")
check(not b.context:SendState("cheat", {}), "Guest was allowed to publish host state")
local stateCount = #a.messages
B:Send("GAME_STATE", { id = A.Lobby.id, run = A.Lobby.run, event = "forged", payload = {} })
pump()
check(#a.messages == stateCount, "Forged guest state was delivered as authoritative")
B:Send("GAME_ACTION", { target = a.name, id = A.Lobby.id, run = A.Lobby.run - 1, event = "late", payload = {} })
pump()
check(#a.messages == stateCount, "A previous round's action mutated the current round")
local cyclic = {}
cyclic.self = cyclic
check(not a.context:SendState("cycle", cyclic), "Cyclic payload was accepted")
check(not a.context:SendState("huge", { text = string.rep("x", 5000) }), "Oversized payload was accepted")
local before = A.Lobby.revision
local stale = A:GetSession()
stale.revision = before - 1
stale.status = "waiting"
B:Receive("SNAPSHOT", stale, a.name)
check(B.Lobby.status == "running", "Stale snapshot rewound the match")
local oldGuestContext = b.context
check(A:ReturnToLobby(), "Host failed to end game")
pump()
check(not A.ActiveGame and not B.ActiveGame and b.stopped == 1, "Modules were not stopped")
check(not oldGuestContext:SendAction("late", {}), "Ended game context remained usable")
check(not A.Lobby.members[1].ready and not A.Lobby.members[2].ready, "Readiness was not reset")
B:Send(
    "READY",
    { target = a.name, id = A.Lobby.id, gameID = "fixture", version = "1", epoch = A.Lobby.epoch - 1, ready = true }
)
pump()
check(not A.Lobby.members[2].ready, "Delayed readiness from an ended round was accepted")

-- Exercise the real throttle retry path with a burst larger than its allowance.
local previousThrottles = a.throttleCount
for _ = 1, 18 do
    A:PublishLobby()
end
pump(30)
check(a.throttleCount > previousThrottles, "Throttle retry path was not exercised")
check(B.Lobby.revision == A.Lobby.revision, "Throttled snapshots were dropped")

-- Reload recovery uses a fresh join to an existing participant slot, even mid-game.
A:Ready(true)
B:Ready(true)
pump()
A:StartGame()
pump()
B:ResetLobby("reload")
check(B:JoinLobby(a.name, A.Lobby.id), "Running game's existing player could not rejoin")
pump()
check(
    B.Lobby.status == "running" and b.restored and #A.Lobby.members == 2,
    "Rejoin duplicated a participant or failed restoration"
)
B:LeaveLobby()
pump()
check(#A.Lobby.members == 1 and A.Lobby.status == "waiting", "Departing player did not end the round")
B:Discover()
pump()
B:JoinLobby(a.name, A.Lobby.id)
pump()
A:LeaveLobby()
pump()
check(not B.Lobby and not B.Listings[a.name], "Host close did not reach guests")

A:CreateLobby()
pump()
B:JoinLobby(a.name, A.Lobby.id)
pump()
a.roster, b.roster, b.grouped = {}, {}, false
a:event("GROUP_ROSTER_UPDATE")
b:event("GROUP_ROSTER_UPDATE")
check(#A.Lobby.members == 1 and not B.Lobby, "Group membership changes were not reconciled")
A:LeaveLobby()
a.channel, b.channel, b.grouped = "INSTANCE_CHAT", "INSTANCE_CHAT", true
a.roster, b.roster = { b.name }, { a.name }
A:CreateLobby()
pump()
B:JoinLobby(a.name, A.Lobby.id)
pump()
check(B.Lobby and B.Lobby.channel == "INSTANCE_CHAT", "Instance group channel was not used")
a.channel, b.channel = "RAID", "RAID"
a:event("GROUP_ROSTER_UPDATE")
b:event("GROUP_ROSTER_UPDATE")
check(not A.Lobby and not B.Lobby, "Channel changes retained an obsolete lobby")

-- Requests that never receive a reply are cancelled; silent hosts expire.
a.channel, b.channel = "PARTY", "PARTY"
A:CreateLobby()
pump()
B:JoinLobby(a.name, A.Lobby.id)
packets = {}
a.env.ChatThrottleLib.Frame:Hide()
b.env.ChatThrottleLib.Frame:Hide()
now = now + 25
B:Tick()
check(not B.Pending, "Unanswered join request never expired")
check(not pcall(function()
    A:RegisterGame(A.Registry.fixture)
end), "Duplicate game registration was accepted")
local silentHost, timedGuest = client("Carla", "RealmOne"), client("Dori", "RealmTwo")
silentHost.roster, timedGuest.roster = { timedGuest.name }, { silentHost.name }
silentHost.games:CreateLobby()
pump()
timedGuest.games:JoinLobby(silentHost.name, silentHost.games.Lobby.id)
pump()
check(timedGuest.games.Lobby ~= nil, "Timeout scenario did not join")
now = now + 96
timedGuest.games:Tick()
check(not timedGuest.games.Lobby, "Nonresponsive host did not expire")
check(not timedGuest.games.Listings[silentHost.name], "Stale discovery entry did not expire")
print(string.format("PASS: %d assertions; real AceComm/ChatThrottleLib, isolated clients, UI smoke checks.", tests))
