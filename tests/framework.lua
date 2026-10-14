-- Run from the repository root: lua tests/framework.lua
-- Loads the actual bundled libraries and addon in isolated WoW client environments.
local script = (arg[0] or "tests/framework.lua"):gsub("\\", "/")
local root = (script:match("^(.*)/tests/[^/]+$") or ".") .. "/KIC-Games/"
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
        buckets = {},
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
    function methods:GetStringHeight()
        local _, lines = (self.text or ""):gsub("\n", "\n")
        return (lines + 1) * 18
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
        NewTicker = function(period, fn)
            c.tick = fn
            local timer = {
                callback = fn,
                at = now + period,
                period = period,
                Cancel = function(timer)
                    timer.cancelled = true
                end,
            }
            -- Countdown ticks follow the mock clock; module timers are manually controlled.
            if period <= 0.2 then
                c.scheduled = c.scheduled or {}
                c.scheduled[#c.scheduled + 1] = timer
            end
            return timer
        end,
        NewTimer = function(_, fn)
            return {
                callback = fn,
                Cancel = function(timer)
                    timer.cancelled = true
                end,
            }
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
            local bucket = c.buckets[prefix] or { tokens = 10, lastRefill = now }
            c.buckets[prefix] = bucket
            bucket.tokens = math.min(10, bucket.tokens + now - bucket.lastRefill)
            bucket.lastRefill = now
            if bucket.tokens < 1 then
                c.throttleCount = c.throttleCount + 1
                return 3
            end
            bucket.tokens = bucket.tokens - 1
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
            for _, timer in ipairs(c.scheduled or {}) do
                if not timer.cancelled and now >= timer.at then
                    timer.at = now + timer.period
                    timer.callback()
                end
            end
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
pump(80)
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
check(not pcall(function()
    A:RegisterGame({ id = "missing_ui", title = "Missing UI", version = "1", OnStart = function() end })
end), "Module without its own UI factory was accepted")
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

-- API v2: shared results, module isolation, managed resources and urgent interruption.
local e, f = client("Ema", "RealmOne"), client("Ferenc", "RealmTwo")
e.roster, f.roster = { f.name }, { e.name }
register(e, "1")
register(f, "1")
local E, F = e.games, f.games
E:CreateLobby()
pump()
F:JoinLobby(e.name, E.Lobby.id)
pump()
E:SelectGame("fixture")
pump()
local function startRound()
    check(E:Ready(true) and F:Ready(true), "API v2 participants failed to ready")
    pump(15)
    check(E.Lobby.status == "running", "All-ready participants did not start automatically")
    check(E.ActiveGame and F.ActiveGame, "Game module failed to activate")
end
startRound()
local calls = 0
local ticker = e.context:NewTicker(1, function()
    calls = calls + 1
end)
local delayed = f.context:After(10, function()
    calls = calls + 1
end)
ticker.callback()
check(calls == 1, "Managed timer callback did not run")
local resultHooks = 0
E.Registry.fixture.OnResult = function(_, result)
    resultHooks = resultHooks + 1
    check(result.status == "completed" or result.status == "aborted", "Invalid lifecycle result")
end
local messageCount = #e.messages
F:Send("GAME_ACTION", {
    target = e.name,
    id = E.Lobby.id,
    run = E.Lobby.run,
    gameID = "another_game",
    gameVersion = "1",
    event = "move",
    payload = {},
})
pump()
check(#e.messages == messageCount, "Another game's namespace reached this module")
check(not f.context:FinishGame({}), "Guest finalized an authoritative result")
check(
    not e.context:FinishGame({ entries = { keyed = { player = e.name, score = 1 } } }),
    "Non-array result entries were accepted"
)
check(
    not e.context:FinishGame({ entries = { { player = "NotInMatch-Realm", score = 1 } } }),
    "Unknown result player was accepted"
)
check(
    not e.context:FinishGame({ entries = { { player = e.name, score = math.huge } } }),
    "Nonfinite score was accepted"
)
local oldContext = e.context
check(
    e.context:FinishGame({
        summary = "Fixture finished",
        entries = {
            { player = e.name, score = 12, rank = 1, outcome = "win" },
            { player = f.name, score = 7, rank = 2, outcome = "loss" },
        },
    }),
    "Normal module completion failed"
)
check(ticker.cancelled, "Host timers survived completion")
pump(20)
check(delayed.cancelled, "Guest timers survived completion")
ticker.callback()
delayed.callback()
check(calls == 1, "Stale timer callback ran after completion")
check(not oldContext:SendAction("late", {}), "Completed context remained usable")
check(E.LastResult.id == F.LastResult.id and F.LastResult.status == "completed", "Shared result diverged")
check(
    E.LastResult.entries[1].score == 12 and F.LastResult.entries[2].outcome == "loss",
    "Scores/ranks/outcomes were lost"
)
check(E:GetResultStats().wins == 1 and F:GetResultStats().losses == 1, "Completed results were not counted correctly")
check(#E:GetResults("fixture") == 1 and #E:GetResults("other_game") == 0, "Game-specific history filtering failed")
E:PublishLobby()
pump(15)
check(
    #E:GetResults() == 1 and #F:GetResults() == 1 and resultHooks == 1,
    "Result heartbeat duplicated history or hooks"
)
local detached = F:GetResults()
detached[1].summary = "modified"
check(F.LastResult.summary == "Fixture finished", "Result getter leaked mutable framework state")
F:InitializeResults()
check(#F:GetResults() == 1, "Results did not survive saved-variable initialization")

startRound()
local runningSnapshot = E:GetSession()
local guestTimer = f.context:NewTicker(1, function()
    error("Cancelled timer should never run")
end)
F.UI:ShowResults()
local sendControl = F.SendControl
F.SendControl = function()
    error("Simulated local transport failure")
end
f.env.SlashCmdList.KICGAMES("stop")
check(
    not F.ActiveGame and not F.UI.frame:IsShown() and not F.UI.resultsFrame:IsShown(),
    "Guest abort waited for network or left windows open"
)
check(guestTimer.cancelled, "Abort did not cancel a module's timers")
check(E.ActiveGame ~= nil, "Test did not check local stopping before network delivery")
F:AcceptSnapshot(runningSnapshot, e.name)
check(not F.ActiveGame, "A delayed running snapshot reopened the interrupted game")
F.SendControl = sendControl
F:Tick()
pump(20)
check(
    not E.ActiveGame and E.Lobby.status == "waiting" and F.Lobby.status == "waiting",
    "Guest abort did not stop the shared match"
)
check(
    E.LastResult.status == "aborted" and F.LastResult.abortedBy == f.name and not F.LastResult.provisional,
    "Host did not reconcile interruption results"
)
check(E:GetResultStats().losses == 0 and F:GetResultStats().losses == 1, "An interruption was counted as a loss")
for _, entry in ipairs(E.LastResult.entries) do
    check(entry.score == nil and entry.outcome == nil, "Interrupted result retained scores or outcomes")
end
check(not E.Lobby.members[1].ready and not E.Lobby.members[2].ready, "Interrupted round retained readiness")

startRound()
local activeRun = E.Lobby.run
-- A current party member outside the minigame cannot stop it.
e.roster[#e.roster + 1] = stranger.name
stranger.roster = { e.name, f.name }
stranger.games:SendControl("ABORT", { id = E.Lobby.id, run = activeRun })
pump()
check(E.ActiveGame ~= nil, "A nonparticipant interrupted the game")
F:SendControl("ABORT", { id = E.Lobby.id, run = activeRun - 1 })
pump()
check(E.ActiveGame ~= nil, "A previous round's interrupt stopped a new game")
e.roster = { f.name }

-- Queue a large multipart transfer. ALERT interrupt uses a separate prefix/pipe.
local large = { chunks = { string.rep("x", 3900), string.rep("y", 3900) } }
check(e.context:SendState("busy", large), "Could not queue large transfer for interrupt test")
check(E:AbortGame(), "Host quick abort failed")
check(not E.ActiveGame and not E.UI.frame:IsShown(), "Host abort did not stop locally at once")
pump(5)
check(not F.ActiveGame and not F.UI.frame:IsShown(), "Urgent interrupt waited behind normal multipart traffic")
pump(70)
check(
    E.LastResult.id == F.LastResult.id and not F.LastResult.provisional,
    "Backlogged multipart traffic corrupted final reconciliation"
)
check(resultHooks == 3, "Finalization hooks ran an incorrect number of times")

F.UI:ShowResults()
check(
    F.UI.resultsFrame:IsShown() and F.UI.resultText.text:find("Interrupted", 1, true),
    "Shared result UI did not render history"
)
-- Bounded persistent history and invalid persisted values.
local historySeed = E.Copy(E.LastResult)
for i = 1, 25 do
    local item = E.Copy(historySeed)
    item.run = 100 + i
    item.id = item.sessionID .. ":" .. item.run
    E:RecordResult(item)
end
check(#E:GetResults() == 20, "Result history was not bounded")
E.DB.results[#E.DB.results + 1] = { status = "corrupt" }
E:InitializeResults()
check(#E:GetResults() == 20, "Invalid saved results broke initialization")
local notPlayed = E.Copy(historySeed)
notPlayed.entries = { { player = f.name } }
notPlayed.host = f.name
check(not E:RecordResult(notPlayed), "A match without the local player entered history")

-- Tabs, selected-game hosting by any party member, and automatic synchronized countdowns.
local g, h, i = client("Gabi", "RealmOne"), client("Hugo", "RealmTwo"), client("Imre", "RealmThree")
g.roster, h.roster, i.roster = { h.name, i.name }, { g.name, i.name }, { g.name, h.name }
register(g, "1")
register(h, "1")
register(i, "1")
local G, H, I = g.games, h.games, i.games
G.UI.create.scripts.OnClick()
H.UI.create.scripts.OnClick()
pump(15)
check(G.Lobby.gameID == "fixture" and H.Lobby.gameID == "fixture", "Host game did not create the selected game lobby")
check(I.Listings[g.name] and I.Listings[h.name], "Independent party hosts did not appear together")
check(
    I.Listings[g.name].gameTitle == "Test fixture" and I.Listings[g.name].max == 5,
    "Lobby list lost game title or capacity"
)
check(G.UI.listingRows[1].enabled, "Host's own lobby was not shown as joined")
I.UI.listingRows[1].scripts.OnClick()
pump(15)
check(I.Lobby and I.Lobby.host == g.name, "Lobby list click did not join the selected party host")
check(not I:CreateLobby("fixture"), "A joined participant created a second simultaneous local session")

now = math.ceil(now) + 0.05
G:Ready(true)
I:Ready(true)
pump(0.2)
check(G.Lobby.status == "countdown" and I.Lobby.status == "countdown", "All ready did not begin a shared countdown")
check(G:CountdownRemaining() == 3 and I:CountdownRemaining() == 3, "Countdown did not begin at 3")
check(G.UI.countdownText.text == "Game starts in 3..." and not G.ActiveGame, "UI skipped countdown before module start")
pump(1)
check(G:CountdownRemaining() == 2 and I:CountdownRemaining() == 2, "Shared countdown missed 2")
pump(1)
check(G:CountdownRemaining() == 1 and I:CountdownRemaining() == 1, "Shared countdown missed 1")
pump(1)
check(
    G.ActiveGame and I.ActiveGame and g.started == 1 and i.started == 1,
    "Automatic countdown did not launch each module exactly once"
)
check(H.Lobby.status == "waiting" and #H.Lobby.members == 1, "Another host's lobby was affected by the countdown")
G:AbortGame()
pump(15)

now = math.ceil(now) + 0.05
G:Ready(true)
I:Ready(true)
pump(0.2)
local oldCountdown = G:GetSession()
local oldTimer = G.CountdownTimer
I:Ready(false)
pump(0.4)
check(G.Lobby.status == "waiting" and I.Lobby.status == "waiting", "Not ready failed to cancel countdown")
pump(4)
check(not G.ActiveGame and g.started == 1 and not G.CountdownTimer, "A cancelled countdown timer launched a game")
I:AcceptSnapshot(oldCountdown, g.name)
check(I.Lobby.status == "waiting", "Delayed countdown snapshot resurrected cancelled start")
check(I.Listings[g.name].status == "waiting", "Delayed snapshot regressed the public lobby list")

now = math.ceil(now) + 0.05
I:Ready(true)
pump(0.2)
check(G.Lobby.status == "countdown", "Readying again did not restart the countdown")
local newTimer = G.CountdownTimer
oldTimer.callback()
check(G.CountdownTimer == newTimer and not newTimer.cancelled, "Stale timer cancelled the replacement countdown")
G:SelectGame("fixture")
check(
    G.Lobby.status == "countdown" and G.CountdownTimer == newTimer,
    "Selecting the current game unnecessarily reset its countdown"
)
for _, gameFramework in ipairs({ G, I }) do
    local alternate = gameFramework.Copy(gameFramework.Registry.fixture)
    alternate.id, alternate.title = "alternate_fixture", "Alternate fixture"
    gameFramework:RegisterGame(alternate)
end
G:SelectGame("alternate_fixture")
pump(5)
check(
    G.Lobby.status == "waiting" and not G.ActiveGame and not G.Lobby.members[1].ready,
    "Changing the game did not cancel countdown and reset readiness"
)

now = math.ceil(now) + 0.05
G:Ready(true)
I:Ready(true)
pump(0.2)
local historyCount, cancelled = #G:GetResults(), G:GetSession()
H:SendControl("ABORT", { id = G.Lobby.id, run = G.Lobby.run + 1, token = G.Lobby.countdownToken })
pump(0.2)
check(G.Lobby.status == "countdown", "Party member outside this lobby cancelled its countdown")
I:AbortGame()
check(not I.UI.frame:IsShown(), "Countdown stop did not immediately close the guest's window")
I:AcceptSnapshot(cancelled, g.name)
check(not I.UI.frame:IsShown(), "A delayed countdown reopened the stopped UI")
pump(4)
check(
    G.Lobby.status == "waiting" and not G.ActiveGame and not G.UI.frame:IsShown(),
    "Shared quick stop did not cancel countdown"
)
check(#G:GetResults() == historyCount, "A cancelled countdown recorded a match that never started")
I:ReceiveControl("COUNTDOWN", {
    id = cancelled.id,
    run = cancelled.run,
    token = cancelled.countdownToken,
    epoch = cancelled.epoch,
    at = cancelled.countdownAt,
}, g.name)
check(I.Lobby.status == "waiting", "Delayed countdown control packet restarted the lobby")

now = math.ceil(now) + 0.05
G:Ready(true)
I:Ready(true)
pump(0.2)
I:LeaveLobby()
pump(5)
check(
    G.Lobby.status == "waiting" and #G.Lobby.members == 1 and not G.CountdownTimer,
    "Departure during countdown left a running start timer"
)
check(not G:CanStart(), "Multiplayer game ignored its minimum player count")

-- A new participant joining during countdown cancels it before the roster changes.
I:Discover()
pump(5)
check(I:JoinLobby(g.name, G.Lobby.id), "Countdown join scenario could not rejoin its host")
pump(15)
check(I.Lobby ~= nil, "Delayed roster snapshots prevented rejoining the host")
now = math.ceil(now) + 0.05
check(G:Ready(true), "Join-during-countdown host could not ready")
check(I:Ready(true), "Join-during-countdown guest could not ready")
pump(0.2)
check(G.Lobby.status == "countdown", "Join-during-countdown scenario did not begin: " .. G.Lobby.status)
H:LeaveLobby()
pump(0.2)
check(H:JoinLobby(g.name, G.Lobby.id), "A new participant could not request a countdown lobby")
pump(5)
check(
    G.Lobby.status == "waiting" and #G.Lobby.members == 3 and not G.ActiveGame,
    "Joining during countdown did not cancel the pending start"
)
for _, participant in ipairs(G.Lobby.members) do
    check(not participant.ready, "A changed roster retained ready state")
end
H:LeaveLobby()
I:LeaveLobby()
pump(5)

-- Singleplayer modules have their own tab, local transport and shared lifecycle/results.
local j = client("Juli", "RealmSolo")
j.grouped = false
local J, soloContext, soloMessages = j.games, nil, 0
J:RegisterGame({
    id = "solo_fixture",
    title = "Solo fixture",
    version = "1",
    mode = "singleplayer",
    CreateUI = function(_, parent)
        return j.env.CreateFrame("Frame", nil, parent)
    end,
    OnStart = function(ctx, session)
        soloContext = ctx
        check(
            session.mode == "singleplayer" and #session.members == 1,
            "Solo start did not receive a local one-player session"
        )
        ctx:SendState("local_state", {})
    end,
    OnMessage = function()
        soloMessages = soloMessages + 1
    end,
})
J:RegisterGame({
    id = "party_fixture",
    title = "Party fixture",
    version = "1",
    CreateUI = function(_, parent)
        return j.env.CreateFrame("Frame", nil, parent)
    end,
    OnStart = function() end,
})
check(#J:GetGames("singleplayer") == 1 and #J:GetGames("multiplayer") == 1, "Game modes were not separated")
J.UI.singleTab.scripts.OnClick()
check(
    J.UI.tab == "singleplayer" and not J.UI.browserPanel:IsShown() and J.UI.singlePanel:IsShown(),
    "Singleplayer tab kept multiplayer panels visible"
)
check(
    J.UI.gameRows[1].title.text == "Solo fixture" and J.UI.soloPlay.enabled,
    "Singleplayer tab did not show an available offline game"
)
local queued = #packets
J.UI.soloPlay.scripts.OnClick()
check(
    J.ActiveGame and J.Lobby.mode == "singleplayer" and soloMessages == 1,
    "Solo game failed to launch without a group"
)
check(#packets == queued and not J.CountdownTimer, "Solo game advertised or ran a multiplayer countdown")
check(
    soloContext:FinishGame({
        summary = "Solo completed",
        entries = { { player = j.name, score = 10, rank = 1, outcome = "win" } },
    }),
    "Singleplayer result failed to finalize"
)
check(not J.Lobby and J:GetResultStats().wins == 1, "Solo completion blocked the launcher or lost results")
j.grouped, j.roster = true, { g.name }
queued = #packets
check(J:StartSingleplayer("solo_fixture"), "Grouped player could not start a solo game")
J:GroupChanged()
check(J.ActiveGame ~= nil, "Group changes interrupted an independent solo game")
J:AbortGame()
check(
    #packets == queued and not J.ActiveGame and J:GetResultStats().aborted == 1,
    "Solo quick stop broadcast to the party or lost its local result"
)
J.UI:SelectTab("multiplayer")
check(
    J.UI.browserPanel:IsShown() and not J.UI.singlePanel:IsShown() and J.UI.gameRows[1].title.text == "Party fixture",
    "Multiplayer tab did not restore party lobby panels and multiplayer games"
)
check(not pcall(function()
    J:RegisterGame({
        id = "bad_solo",
        title = "Bad solo",
        version = "1",
        mode = "singleplayer",
        maxPlayers = 2,
        CreateUI = function() end,
        OnStart = function() end,
    })
end), "Singleplayer game accepted multiplayer player limits")
print(string.format("PASS: %d assertions; real AceComm/ChatThrottleLib, isolated clients, UI smoke checks.", tests))
