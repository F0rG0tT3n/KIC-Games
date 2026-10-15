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

local function client(name, realm, saved)
    local frames, notices, env = {}, {}, {}
    local c = { sounds = {}, stoppedSounds = {} }
    setmetatable(env, { __index = _G })
    env._G, env.unpack = env, table.unpack
    env.KICGamesDB = saved
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
    env.GetBuildInfo = function()
        return "12.1.5", "test-build", "test-date", env.apiInterface or 120105
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
        return env.cursorX or 0, env.cursorY or 0
    end
    env.IsMouseButtonDown = function()
        return env.mouseDown == true
    end
    local specFixture = assert(loadfile("tests/spec-fixture.lua"))()
    local apiClasses, apiSpecs = {}, {}
    for _, row in ipairs(specFixture) do
        local class = apiClasses[row.classID]
        if not class then
            class = { token = row.token, specs = {} }
            apiClasses[row.classID] = class
        end
        class.specs[#class.specs + 1] = row
        apiSpecs[row.id] = row
    end
    local displayNames = {
        WARRIOR = "Warrior",
        PALADIN = "Paladin",
        HUNTER = "Hunter",
        ROGUE = "Rogue",
        PRIEST = "Priest",
        DEATHKNIGHT = "Death Knight",
        SHAMAN = "Shaman",
        MAGE = "Mage",
        WARLOCK = "Warlock",
        MONK = "Monk",
        DRUID = "Druid",
        DEMONHUNTER = "Demon Hunter",
        EVOKER = "Evoker",
    }
    env.playerClass, env.playerSpec = "MAGE", 62
    env.UnitClass = function()
        return env.playerClass, env.playerClass
    end
    env.GetNumClasses = function()
        return #apiClasses
    end
    env.GetClassInfo = function(index)
        local row = apiClasses[index]
        return displayNames[row.token] or row.token, row.token, index
    end
    env.GetSpecializationInfoForClassID = function(id, index)
        local row = apiClasses[id].specs[index]
        if row then
            return row.id, row.name, "", row.icon, "DAMAGER"
        end
    end
    env.C_SpecializationInfo = {
        GetNumSpecializationsForClassID = function(id)
            return #apiClasses[id].specs
        end,
        GetSpecialization = function()
            return env.playerSpec and 1
        end,
        GetSpecializationInfo = function()
            return env.playerSpec
        end,
    }
    local apiClassFixture, apiSpecFixture = apiClasses, apiSpecs

    env.C_Sound = {
        PlaySound = function(kit, channel, noDuplicates, callback, priority, volume)
            if env.rejectKit == kit then
                return false
            end
            c.sounds[#c.sounds + 1] = {
                kit = kit,
                channel = channel,
                volume = volume,
                method = "PlaySound",
                noDuplicates = noDuplicates,
                callback = callback,
                priority = priority,
            }
            return true, #c.sounds
        end,
        PlaySoundWithOptions = function(params)
            if env.rejectKit == params.soundKitID then
                return false
            end
            c.sounds[#c.sounds + 1] = {
                kit = params.soundKitID,
                channel = params.uiSoundSubType,
                volume = params.volumeOverride,
                method = "PlaySoundWithOptions",
            }
            return true, #c.sounds
        end,
    }
    env.PlaySoundFile = function(file, channel)
        if env.rejectSound == file then
            return false
        end
        c.sounds[#c.sounds + 1] = { file = file, channel = channel }
        return true, #c.sounds
    end
    env.StopSound = function(handle)
        c.stoppedSounds[#c.stoppedSounds + 1] = handle
    end

    env.C_Spell = {
        GetSpellTexture = function(id)
            return id
        end,
    }
    env.GetCurrentKeyBoardFocus = function()
        return env.keyboardFocus
    end
    env.ChatFrameUtil = {
        OpenChat = function(value)
            env.chatDraft = value
        end,
    }
    c.name = name .. "-" .. realm
    c.apiClasses, c.apiSpecs = apiClassFixture, apiSpecFixture
    local clientFields = {
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
    for key, value in pairs(clientFields) do
        c[key] = value
    end
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
        local changed = not self.shown
        self.shown = true
        if changed and self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end
    function methods:Hide()
        local changed = self.shown
        self.shown = false
        if changed and self.scripts.OnHide then
            self.scripts.OnHide(self)
        end
    end
    function methods:IsShown()
        return self.shown
    end
    function methods:IsVisible()
        return self.shown and (not self.parent or self.parent:IsVisible())
    end
    function methods:GetFrameLevel()
        if self.frameLevel then
            return self.frameLevel
        end
        return self.parent
                and self.parent:GetFrameLevel() + ((self.kind == "texture" or self.kind == "font") and 0 or 1)
            or 0
    end
    function methods:EnableKeyboard(value)
        self.keyboardEnabled = value
    end
    function methods:SetPropagateKeyboardInput(value)
        self.propagate = value
    end
    function methods:SetShown(value)
        if value then
            self:Show()
        else
            self:Hide()
        end
    end
    function methods:Enable()
        self.enabled = true
        if self.scripts.OnEnable then
            self.scripts.OnEnable(self)
        end
    end
    function methods:Disable()
        self.enabled = false
        if self.scripts.OnDisable then
            self.scripts.OnDisable(self)
        end
    end
    function methods:IsEnabled()
        return self.enabled
    end
    function methods:SetText(value)
        self.text = value
        if self.caption and self.caption ~= self then
            self.caption.text = value
        end
    end
    function methods:GetStringHeight()
        local _, lines = (self.text or ""):gsub("\n", "\n")
        return (lines + 1) * 18
    end
    function methods:GetStringWidth()
        return #(self.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * (self.fontSize or 14) * 0.5
    end
    function methods:GetCenter()
        return 0, 0
    end
    function methods:GetEffectiveScale()
        return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
    end
    function methods:GetScale()
        return self.scale or 1
    end
    function methods:GetParent()
        return self.parent
    end
    function methods:SetParent(parent)
        self.parent = parent
    end
    function methods:SetScale(value)
        self.scale = value
    end
    function methods:GetWidth()
        return self.width or 0
    end
    function methods:GetLeft()
        return 100 / (self.scale or 1)
    end
    function methods:GetTop()
        return 900 / (self.scale or 1)
    end
    for _, method in ipairs({
        "SetSpacing",
        "SetClampedToScreen",
        "EnableMouse",
        "RegisterForClicks",
        "EnableMouseWheel",
        "SetOrientation",
        "SetValueStep",
        "SetThumbTexture",
        "RegisterForDrag",
        "SetHighlightTexture",
        "SetToplevel",
        "SetFontString",
        "SetOwner",
        "AddLine",
    }) do
        methods[method] = function() end
    end
    function methods:SetPoint(...)
        self.points = self.points or {}
        self.points[#self.points + 1] = { ... }
    end
    function methods:ClearAllPoints()
        self.points = {}
    end
    function methods:SetAllPoints(parent)
        self.allPoints = parent or self.parent
    end
    function methods:SetSize(width, height)
        local changed = self.width ~= width or self.height ~= height
        self.width, self.height = width, height
        if changed and self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, width, height)
        end
    end
    function methods:SetClipsChildren(value)
        self.clipsChildren = value
    end
    function methods:SetScrollChild(child)
        self.scrollChild = child
    end
    function methods:SetVertexColor(...)
        self.vertexColor = { ... }
    end
    function methods:SetBlendMode(mode)
        self.blendMode = mode
    end
    function methods:SetMaxLines(value)
        self.maxLines = value
    end
    function methods:SetHeight(height)
        self.height = height
        if self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self)
        end
    end
    function methods:GetHeight()
        return self.height or 0
    end
    function methods:SetMinMaxValues(minimum, maximum)
        self.minimum, self.maximum = minimum, maximum
    end
    function methods:SetThumbTexture(texture)
        self.thumbTexture = texture
    end
    function methods:SetOrientation(value)
        self.orientation = value
    end
    function methods:SetValue(value)
        self.value = math.max(self.minimum or 0, math.min(value, self.maximum or value))
        if self.scripts.OnValueChanged then
            self.scripts.OnValueChanged(self, self.value)
        end
        if self.thumbTexture then
            local fraction = (self.value - (self.minimum or 0)) / math.max(1, (self.maximum or 1) - (self.minimum or 0))
            self.thumbTexture:ClearAllPoints()
            if self.orientation == "VERTICAL" then
                self.thumbTexture:SetPoint("CENTER", self, "TOP", 0, -self:GetHeight() * fraction)
            else
                self.thumbTexture:SetPoint("CENTER", self, "LEFT", self:GetWidth() * fraction, 0)
            end
        end
    end
    function methods:SetVerticalScroll(value)
        self.verticalScroll = value
        if self.scripts.OnVerticalScroll then
            self.scripts.OnVerticalScroll(self, value)
        end
    end
    function methods:GetVerticalScroll()
        return self.verticalScroll or 0
    end
    function methods:SetWidth(width)
        local changed = self.width ~= width
        self.width = width
        if changed and self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, width, self:GetHeight())
        end
    end
    function methods:SetBackdrop(info)
        self.backdropInfo = info
    end
    function methods:SetFont(_, size)
        self.fontSize = size
    end
    function methods:SetColorTexture(...)
        self.color = { ... }
        self.textureValue = nil
    end
    function methods:SetAlpha(value)
        self.alpha = value
    end
    function methods:SetJustifyH(value)
        self.justify = value
    end
    function methods:SetTexCoord(...)
        self.texCoord = { ... }
    end
    function methods:SetTextColor(...)
        self.textColor = { ... }
    end
    function methods:SetBackdropColor(...)
        self.background = { ... }
    end
    function methods:SetBackdropBorderColor(...)
        self.border = { ... }
    end
    function methods:SetFrameStrata(strata)
        self.strata = strata
    end
    function methods:SetFrameLevel(level)
        self.frameLevel = level
    end
    function methods:SetMovable(value)
        self.movable = value
    end
    function methods:StartMoving()
        self.moving = true
    end
    function methods:StopMovingOrSizing()
        self.moving = false
    end
    function methods:Raise()
        self.raiseCount = (self.raiseCount or 0) + 1
    end
    function methods:SetTexture(value)
        if env.rejectTexture == value then
            return false
        end
        self.textureValue = value
        self.color = nil
        return true
    end
    local function widget(parent)
        local w = setmetatable(
            { scripts = {}, events = {}, shown = true, enabled = true, parent = parent },
            { __index = methods }
        )
        frames[#frames + 1] = w
        return w
    end
    function methods:CreateFontString(_, layer)
        local w = widget(self)
        w.kind = "font"
        w.drawLayer = layer or "ARTWORK"
        return w
    end
    function methods:CreateTexture(_, layer, _, subLevel)
        local w = widget(self)
        w.kind = "texture"
        w.drawLayer, w.subLevel = layer or "ARTWORK", subLevel or 0
        return w
    end
    function methods:SetNormalTexture()
        self.texture = widget(self)
    end
    function methods:GetNormalTexture()
        return self.texture
    end
    env.CreateFrame = function(kind, globalName, parent)
        local w = widget(parent)
        w.kind = kind
        if globalName then
            env[globalName] = w
        end
        return w
    end
    env.UIParent, env.Minimap, env.GameTooltip = widget(), widget(), widget()
    env.UIParent:SetSize(1920, 1080)
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

if arg[1] == "--audit" then
    assert(loadfile("tests/audit_regressions.lua"))()(client, check)
    print(string.format("PASS: %d audit assertions", tests))
    return
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

check(
    #A:GetGames("singleplayer") == 2 and A.Registry.tetris and A.Registry.bejeweled and #A:GetGames("multiplayer") == 0,
    "Bundled games must only appear in singleplayer"
)
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
check(#J:GetGames("singleplayer") == 3 and #J:GetGames("multiplayer") == 1, "Game modes were not separated")
J.UI.singleTab.scripts.OnClick()
check(
    J.UI.tab == "singleplayer" and not J.UI.browserPanel:IsShown() and J.UI.cardScroll:IsShown(),
    "Singleplayer tab kept multiplayer panels visible"
)
check(
    J.UI.launcherCards[2].title.text == "Solo fixture" and J.UI.soloPlay.enabled,
    "Singleplayer tab did not show an available offline game"
)
local queued = #packets
J.UI.launcherCards[2].play.scripts.OnClick()
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
    J.UI.browserPanel:IsShown()
        and not J.UI.singlePanel:IsShown()
        and J.UI.launcherCards[1].title.text == "Party fixture",
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
local t = client("TetrisPlayer", "TestRealm")
t.grouped = false
local G, T = t.games, t.games.Tetris
local before = #packets
check(G:StartSingleplayer("tetris"), "Bundled Tetris could not start")
check(G.UI.frame.strata == "DIALOG", "Main launcher strata changed")
G.UI:ShowResults()
check(G.UI.resultsFrame.parent == G.UI.content and G.UI.launcherPage == "results", "History is not an embedded page")
check(not G.UI.resultsFrame.movable and not G.UI.resultsFrame.strata, "History created an independent popup")
check(not G.UI.gameContainer:IsShown() and G.ActiveGame, "Results lost the active game")
local historyScroll = G.UI.resultList.parent
G.UI.resultList:SetHeight(900)
historyScroll.scripts.OnMouseWheel(historyScroll, -1)
check(
    historyScroll:GetVerticalScroll() > 0 and historyScroll.scrollBar:IsShown(),
    "Custom history scrolling did not move the content"
)
G.UI.resultList:SetHeight(100)
check(
    historyScroll:GetVerticalScroll() == 0 and not historyScroll.scrollBar:IsShown(),
    "Shorter history content retained a stale scroll offset"
)
G.UI:RefreshResults()
T:Advance(0.1)
check(T.paused, "History overlay did not pause Tetris input")
G.UI:ShowGame()
T:Pause(false)
check(T.running and T.root:IsVisible() and T.root.keyboardEnabled, "Tetris UI or keyboard did not start")
check(#T.cells == 200 and #T.Presets == 13, "Missing board cells or class presets")
check(T.board.points[1][2] < T.sidebar.points[1][2], "Tetris board is not to the left of its sidebar")
check(
    T.shareButton.parent == T.left
        and T.optionsButton.parent == T.left
        and T.controlsText.parent == T.left
        and T.nextCells[1][1].bg.parent == T.nextSlots[1]
        and T.holdCells[1].bg.parent == T.holdSlot,
    "Tetris information, controls or preview slots have the wrong parent"
)
-- Spell lookup must be completely unnecessary, even when it returns question marks.
t.env.C_Spell.GetSpellTexture = function()
    error("Tetris must not resolve spell textures")
end
for _, preset in ipairs(T.Presets) do
    T:SelectPreset(preset.token)
    check(T.icons.I == G:GetPieceIcons("tetris")[1], "Preset still depends on spell lookup")
    check(T.nextCells[1][1].icon.textureValue ~= 134400, "Preview displayed a question mark")
end
T:SelectPreset("HUNTER")
t.env.rejectTexture = T.icons.I
T:Paint(T.cells[1], "I")
check(
    T.cells[1].icon.textureValue == T.FallbackIcons.HUNTER,
    "Rejected Hunter texture did not fall back to the class icon"
)
t.env.rejectTexture = nil
T:KeyDown("P")
T:KeyDown("P")
check(T.paused, "Keyboard repeat toggled pause twice")
T.root.scripts.OnKeyUp(T.root, "P")
T:KeyDown("P")
T.root.scripts.OnKeyUp(T.root, "P")
check(not T.paused, "Pause could not resume")
local oldX = T.model.x
T:KeyDown("LEFT")
T:Advance(0.2)
T.root.scripts.OnKeyUp(T.root, "LEFT")
check(T.model.x < oldX - 1, "Held movement did not repeat")
T:KeyDown("ENTER")
check(T.root.propagate, "Non-game keyboard input was captured")
T:SelectPreset("DRUID")
check(G.DB.tetris.preset == "DRUID", "Preset was not saved")
T:KeyDown("SPACE")
T.root.scripts.OnKeyUp(T.root, "SPACE")
check(G.DB.tetris.best.score > 0, "Drop score did not save the best")
local best = G.DB.tetris.best.score
T:ShareBest()
check(t.env.chatDraft:find("/s KIC Tetris best:", 1, true) == 1 and T.paused, "Best share did not draft chat and pause")
T:Pause(false)
t.env.keyboardFocus = {}
T:KeyDown("LEFT")
check(T.paused and T.root.propagate, "Chat typing stole movement input")
t.env.keyboardFocus = nil
T:Pause(false)
G.UI:ShowHome()
local y = T.model.y
T:Advance(0.2)
check(T.paused and T.model.y == y, "Hidden game did not pause")
G.UI:ShowGame()
G:AbortGame()
check(
    not T.running and not T.root.keyboardEnabled and G.DB.tetris.best.score == best,
    "Quick stop lost best or kept input"
)
check(#packets == before, "Singleplayer Tetris emitted multiplayer packets")
local frameCount = #t.frames
check(G:StartSingleplayer("tetris"), "Tetris restart failed")
check(#t.frames == frameCount, "Tetris replay leaked UI frames")
check(G.DB.tetris.preset == "DRUID" and G.DB.tetris.best.score == best, "Restart lost settings or best")
T.model:AddScore(200)
T.model.lines, T.model.level, T.model.gameover = 2, 1, true
T:Advance(0)
check(not G.ActiveGame and not G.Lobby and T.summary:IsShown(), "Game over did not release session and show summary")
check(
    T.summary.parent == t.env.UIParent and T.summary.strata == "FULLSCREEN_DIALOG" and T.summary.movable,
    "Game-over dialog can render underneath the launcher or cannot move"
)
T.summary.scripts.OnDragStart()
check(T.summary.moving and T.summary.raiseCount > 0, "Game-over dialog did not raise and drag")
T.summary.scripts.OnDragStop()
check(not T.summary.moving, "Game-over dialog did not stop moving")
G.UI.frame:Hide()
check(not T.summary:IsShown(), "Closing launcher left the independent game-over dialog behind")
G.UI.frame:Show()
T.summary:Show()
check(G:GetResults()[1].entries[1].score == T.model.score, "Tetris completion lost score")
check(G.DB.tetris.best.lines == 2, "Best record lost line metadata")
G.UI:HideAll()
check(not T.summary:IsShown(), "Quick stop did not hide the game-over dialog")
t.env.SlashCmdList.KICTETRIS("share")
check(t.env.chatDraft:find("Druid icons", 1, true), "Share command did not use saved record")
local saved = G.DB.tetris
local reload = client("Reloaded", "TestRealm")
reload.env.KICGamesDB = { tetris = saved }
reload:event("ADDON_LOADED", "KIC-Games")
check(reload.games.Tetris:Storage().best.score == T.model.score, "Reload lost SavedVariables high score")
G.DB.tetris = { preset = "invalid", best = { score = 0 / 0, lines = -10, level = math.huge } }
check(
    T:Storage().best.score == 0 and T:Storage().best.level == 1 and G.DB.tetris.preset == G:GetClassPreset(),
    "Invalid saved values were not repaired"
)
local jewel = client("Jeweler", "GemRealm")
local Q, Bj = jewel.games, jewel.games.Bejeweled
jewel.grouped = true
local jewelPackets = #packets
check(Q:StartSingleplayer("bejeweled"), "Bejeweled did not start from the registry")
check(Bj.running and Bj.root:IsVisible() and #Bj.cells == 64, "Bejeweled board did not initialize")
check(not Bj.root.keyboardEnabled, "Mouse game unnecessarily captured keyboard input")
local jewelAssets = assert(loadfile(root .. "../tests/tetris-icon-files.lua"))()
for id, path in pairs(assert(loadfile("tests/options-icon-files.lua"))()) do
    jewelAssets[id] = path
end
local seenGems = {}
check(#Bj.Gems == 7, "Bejeweled does not have seven gem kinds")
for i, gem in ipairs(Bj.Gems) do
    check(
        Bj.icons[i] ~= 134400 and jewelAssets[Bj.icons[i]] and not seenGems[Bj.icons[i]],
        "Bejeweled has a missing or duplicate gem icon"
    )
    seenGems[Bj.icons[i]] = true
end
-- Use an exact stable board so UI checks do not depend on random cascades.
local function jewelBoard(playable)
    for y = 1, 8 do
        for x = 1, 8 do
            Bj.model.board[y][x] = (x + 2 * y) % 7 + 1
        end
    end
    if playable then
        Bj.model.board[1][1], Bj.model.board[1][2], Bj.model.board[1][3], Bj.model.board[2][2] = 1, 2, 1, 1
    end
end
jewelBoard(true)
jewel.env.rejectTexture = Bj.icons[1]
Bj:Render()
check(Bj.cells[1].icon.textureValue == Bj.fallbackIcon, "Rejected texture did not use the class fallback")
jewel.env.rejectTexture = nil
local refillIndex = 0
Bj.model.random = function(n)
    refillIndex = refillIndex + 1
    return ({ 2, 1, 2 })[refillIndex] or math.random(n)
end
Bj:Hint()
check(Bj.hint ~= nil and Bj.model.score == 0, "Hint was missing or changed score")
for _ = 1, 31 do
    Bj:Advance(0.1)
end
check(not Bj.hint and Bj.model.moves == 0 and Bj.model.score == 0, "Hint did not expire or played a move automatically")
Bj:Hint()
Bj:Click(2, 1, "LeftButton")
check(Bj.selected and not Bj.hint, "Gem selection did not clear hint")
Bj:Click(2, 1, "RightButton")
check(not Bj.selected, "Right click did not clear selection")
Bj:Click(8, 8, "LeftButton")
Bj:Click(7, 8, "LeftButton")
check(Bj.swap and not Bj.swap.valid, "Invalid swap did not animate back")
for _ = 1, 4 do
    Bj:Advance(0.1)
end
check(not Bj.swap and Bj.model.moves == 0 and Bj.model.score == 0, "Invalid swap awarded points or did not return")
Bj:Click(2, 1, "LeftButton")
Bj:Click(2, 2, "LeftButton")
check(Bj.swap and Bj.swap.valid and Bj.model.moves == 1, "Neighbor clicks did not animate a valid swap")
Bj:Click(7, 7, "LeftButton")
check(not Bj.selected and Bj.model.moves == 1, "Input was accepted while a swap was animating")
local swapTime = Bj.swap.time
Q.UI:ShowHome()
Bj:Advance(0.1)
check(Bj.paused and Bj.swap.time == swapTime, "Hidden Bejeweled did not pause its animation")
Q.UI:ShowGame()
Bj:Pause(false)
jewel.env.keyboardFocus = {}
Bj:Advance(0.1)
check(Bj.paused and Bj.swap.time == swapTime, "Typing in chat advanced a gem swap")
jewel.env.keyboardFocus = nil
Bj:Pause(false)
Q.UI:ShowResults()
Bj:Advance(0.1)
check(Bj.paused, "History did not pause Bejeweled")
Q.UI:ShowGame()
Bj:Pause(false)
for _ = 1, 200 do
    Bj:Advance(0.1)
    if not Bj.swap and not Bj.fall and Bj.model.phase == "idle" then
        break
    end
end
check(Bj.model.score >= 150 and Q.DB.bejeweled.best.score == Bj.model.score, "Resolved clear did not save high score")
check(not Bj.swap and not Bj.fall and Bj.model.phase == "idle", "Animated cascades did not settle")
local jewelBest = Q.DB.bejeweled.best.score
jewel.env.SlashCmdList.KICBEJEWELED("share")
check(
    Bj.paused and jewel.env.chatDraft:find("/p KIC Bejeweled best:", 1, true) == 1,
    "Bejeweled share did not draft party chat"
)
Q:AbortGame()
check(
    not Bj.running and not Q.ActiveGame and not Q.Lobby and Q.DB.bejeweled.best.score == jewelBest,
    "Quick stop lost the Bejeweled best or failed to release the session"
)
check(#packets == jewelPackets, "Bejeweled emitted multiplayer messages")
local jewelFrames = #jewel.frames
check(Q:StartSingleplayer("bejeweled"), "Bejeweled replay did not start")
check(
    #jewel.frames == jewelFrames and Q.DB.bejeweled.best.score == jewelBest,
    "Bejeweled replay leaked UI frames or lost best"
)
jewelBoard(false)
Bj.model.score, Bj.model.moves, Bj.model.cleared, Bj.model.bestCascade = 200, 1, 4, 1
Bj.model:CheckEnd()
Bj:Advance(0)
check(not Q.ActiveGame and not Q.Lobby and Bj.summary:IsShown(), "No moves did not complete Bejeweled and show results")
check(Q:GetResults()[1].entries[1].score == 200, "Bejeweled completed result lost the score")
check(Bj.summary.movable and Bj.summary.strata == "FULLSCREEN_DIALOG", "Bejeweled result lost overlay dragging")
Q.UI.frame:Hide()
check(not Bj.summary:IsShown(), "Closing launcher left Bejeweled results behind")
local jewelSaved = Q.DB.bejeweled
local jewelReload = client("ReloadedJeweler", "GemRealm")
jewelReload.env.KICGamesDB = { bejeweled = jewelSaved }
jewelReload:event("ADDON_LOADED", "KIC-Games")
check(jewelReload.games.Bejeweled:Storage().best.score == jewelSaved.best.score, "Reload lost Bejeweled high score")
Q.DB.bejeweled = { best = { score = 0 / 0, moves = -1, cleared = math.huge } }
check(Bj:Storage().best.score == 0 and Bj:Storage().best.moves == 0, "Malformed Bejeweled save was not repaired")
-- Shared settings, launcher icons, selection visibility and proportional resizing.
local sharedClient = client("SharedOptions", "OptionsRealm")
local S = sharedClient.games
sharedClient.grouped = false
S.UI:SelectTab("singleplayer")
check(
    S.UI.launcherCards[1].icon:IsShown() and S.UI.launcherCards[1].title.text == "Bejeweled",
    "Bejeweled library icon is missing"
)
check(S.UI.launcherCards[2].icon.textureValue == S.Artwork["tetris-card"].file, "Tetris block icon is missing")
check(S:StartSingleplayer("tetris"), "Could not start Tetris for options checks")
local originalModel = S.Tetris.model
S.UI.optionsButton.scripts.OnClick()
S.Tetris:Advance(0.1)
check(S.Tetris.paused and S.UI.optionsFrame:IsShown(), "Options did not pause Tetris")
S.UI.appearancePanel.switch.scripts.OnClick()
S.UI.classDropdown.buttons.SHAMAN.scripts.OnClick()
check(
    S:GetClassPreset() == "SHAMAN" and S.Tetris.icons.I == S:GetPieceIcons("tetris")[1],
    "Class menu did not update Tetris"
)
check(S.Tetris.model == originalModel and not S.Tetris.presetButtons, "Options reset game or left the old class picker")
S.UI:ShowGame()
S:AbortGame()
S:StartSingleplayer("bejeweled")
check(S.Bejeweled.icons[1] == S.Tetris.icons.I, "Shared class was not applied when switching games")
local jewelModel = S.Bejeweled.model
S.Bejeweled:Click(1, 1, "LeftButton")
check(
    S.Bejeweled.cells[1].selection:IsShown() and S.Bejeweled.cells[1].marker:IsShown(),
    "Selected icon lacks a visible frame and marker"
)
S.Bejeweled:Click(1, 1, "RightButton")
check(not S.Bejeweled.cells[1].selection:IsShown(), "Selection frame remained after deselection")
S.UI:ShowOptions()
S.Bejeweled:Advance(0.1)
check(S.Bejeweled.paused, "Options did not pause Bejeweled")
for _, preset in ipairs(S.IconPresets.Presets) do
    S.UI.classDropdown.buttons[preset.token].scripts.OnClick()
    for i, kind in ipairs(S.IconPresets.Kinds) do
        check(
            S.Bejeweled.icons[i] == S.Tetris.icons[kind] and S.Bejeweled.icons[i] == S:GetPieceIcons("bejeweled")[i],
            "Games disagree on shared class icons"
        )
    end
end
check(S.Bejeweled.model == jewelModel, "Live class changes reset the Bejeweled board")
S.UI:SetWindowScale(1.4)
check(
    S.UI.frame:GetScale() == 1.4
        and S.UI.optionsFrame:GetEffectiveScale() == 1.4
        and S.Bejeweled.root:GetEffectiveScale() == 1.4,
    "Window resize did not enlarge games and options"
)
check(
    S.Bejeweled.summary:GetScale() == 1.4 and S.Tetris.summary:GetScale() == 1.4,
    "Result overlays did not follow window scaling"
)
S.UI:ShowGame()
check(
    not S.UI.resizeGrip and not S.UI.scaleUp and not S.UI.scaleDown and not S.UI.resetSize,
    "Obsolete resizing controls remain visible in Options 2.0"
)
S.UI:SetWindowScale(999)
check(S.UI.frame:GetScale() <= S.UI:MaxWindowScale(), "Resize exceeded the visible screen")
S.UI:SetWindowScale(0 / 0)
check(S.UI.frame:GetScale() == 1, "Invalid scale was not normalized")
S.UI:SetWindowScale(1.25)
S:SetClassPreset("HUNTER")
local sharedSaved = S.DB
local restored = client("RestoredSettings", "OptionsRealm")
restored.env.KICGamesDB = sharedSaved
restored:event("ADDON_LOADED", "KIC-Games")
restored.games.UI:SetWindowScale(restored.games:GetSettings().windowScale)
check(
    restored.games:GetClassPreset() == "HUNTER" and restored.games.UI.frame:GetScale() == 1.25,
    "Shared class/size settings did not survive reload"
)
local legacy = client("LegacySettings", "OptionsRealm")
legacy.env.KICGamesDB = { tetris = { preset = "WARLOCK" } }
legacy:event("ADDON_LOADED", "KIC-Games")
check(
    legacy.games:GetSettings().manualClass == "WARLOCK" and legacy.games:GetSettings().followCharacter,
    "Legacy manual choice was lost when initializing the new Follow default"
)
legacy.games:SetOption("followCharacter", false)
check(legacy.games:GetClassPreset() == "WARLOCK", "Legacy Tetris class selection was not migrated")
S:AbortGame()
-- Native drag handlers: scaled hit-testing, animation, cancellation and late clicks.
local dragClient = client("DragPlayer", "DragRealm")
dragClient.grouped = false
local DragGames, Drag = dragClient.games, dragClient.games.Bejeweled
local function dragRound()
    if DragGames.ActiveGame then
        DragGames:AbortGame()
    end
    DragGames:StartSingleplayer("bejeweled")
    for y = 1, 8 do
        for x = 1, 8 do
            Drag.model.board[y][x] = (x + 2 * y) % 7 + 1
        end
    end
    Drag.model.board[1][1], Drag.model.board[1][2], Drag.model.board[1][3], Drag.model.board[2][2] = 1, 2, 1, 1
    Drag:Render()
end
local function cursorOn(x, y)
    local scale = Drag.board:GetEffectiveScale()
    dragClient.env.cursorX = (Drag.board:GetLeft() + Drag.boardInset + (x - 1) * Drag.step + Drag.tileSize / 2) * scale
    dragClient.env.cursorY = (Drag.board:GetTop() - Drag.boardInset - (y - 1) * Drag.step - Drag.tileSize / 2) * scale
end
local dragStartX, dragStartY
local function dragFrom(x, y, offsetX, offsetY)
    cursorOn(x, y)
    local scale = Drag.board:GetEffectiveScale()
    dragClient.env.cursorX = dragClient.env.cursorX + (offsetX or 0) * scale
    dragClient.env.cursorY = dragClient.env.cursorY + (offsetY or 0) * scale
    dragStartX, dragStartY = dragClient.env.cursorX, dragClient.env.cursorY
    dragClient.env.mouseDown = true
    local cell = Drag.cells[(y - 1) * 8 + x]
    cell.scripts.OnMouseDown(cell, "LeftButton")
    return cell
end
local function dragBy(dx, dy)
    local scale = Drag.board:GetEffectiveScale()
    dragClient.env.cursorX = dragStartX + dx * scale
    dragClient.env.cursorY = dragStartY + dy * scale
    local update = Drag.dragTracker.scripts.OnUpdate
    if update then
        update(Drag.dragTracker, 0.01)
    end
end
local function releaseDrag(source)
    dragClient.env.mouseDown = false
    source.scripts.OnMouseUp(source, "LeftButton")
    source.scripts.OnClick(source, "LeftButton")
end
-- Entering any cardinal neighbor triggers immediately, even after a shorter
-- movement than one tile. Gaps and source-cell movement must not trigger.
for _, scale in ipairs({ 0.75, 1, 1.2, 1.35, 1.5 }) do
    for _, direction in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        dragRound()
        DragGames.UI:SetWindowScale(scale)
        local source = dragFrom(4, 4)
        local width, height = source:GetWidth(), source:GetHeight()
        local entry = Drag.step - width / 2
        check(
            Drag.drag
                and Drag.drag.startX == dragStartX
                and Drag.drag.startY == dragStartY
                and Drag.dragTracker.scripts.OnUpdate
                and not source.scripts.OnDragStart,
            "Mouse-down did not capture the drag gesture"
        )
        dragBy(direction[1] * (entry - 0.25), direction[2] * (entry - 0.25))
        check(not Drag.swap and Drag.drag and Drag.dragFrame:IsShown(), "The gap before a neighbor triggered a swap")
        dragBy(direction[1] * (entry + 0.25), direction[2] * (entry + 0.25))
        check(
            entry + 0.25 < width
                and Drag.swap
                and Drag.swap.x == 4
                and Drag.swap.y == 4
                and Drag.swap.tx == 4 + direction[1]
                and Drag.swap.ty == 4 - direction[2]
                and Drag.swap.time == 0
                and not Drag.drag
                and not Drag.dragFrame:IsShown()
                and not Drag.dragTracker.scripts.OnUpdate
                and dragClient.env.mouseDown,
            "Entering a neighboring tile did not immediately swap before a full-tile displacement"
        )
        local swap = Drag.swap
        dragBy(direction[1] * width * 8, direction[2] * height * 8)
        check(Drag.swap == swap, "Held gesture triggered another swap")
        releaseDrag(source)
        check(Drag.swap == swap and not Drag.selected, "Release/late click duplicated the drag action")
    end
end
-- Starting near an edge must need only the remaining distance plus the gap.
for _, sign in ipairs({ -1, 1 }) do
    dragRound()
    local size = Drag.cells[28]:GetWidth()
    local source = dragFrom(4, 4, sign * (size / 2 - 1), 0)
    local entry = Drag.step - size + 1
    dragBy(sign * (entry - 0.25), 0)
    check(not Drag.swap, "Near-edge drag swapped before reaching the next tile")
    dragBy(sign * (entry + 0.25), 0)
    check(Drag.swap and Drag.swap.tx == 4 + sign, "Near-edge drag still required a full tile of movement")
    releaseDrag(source)
end
-- Diagonal tiles and gaps are not adjacent targets. Entering a cardinal tile
-- afterward uses that tile, regardless of the earlier drag direction.
for _, direction in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
    dragRound()
    local source = dragFrom(4, 4)
    cursorOn(4 + direction[1], 4 + direction[2])
    Drag:UpdateDrag()
    check(not Drag.swap and Drag.drag, "A diagonal destination triggered a cardinal swap")
    cursorOn(4 + direction[1], 4)
    Drag:UpdateDrag()
    check(
        Drag.swap and Drag.swap.tx == 4 + direction[1] and Drag.swap.ty == 4,
        "Entering a cardinal neighbor after a diagonal drag did not swap"
    )
    releaseDrag(source)
end
-- Use the destination's actual rectangle, including non-square dimensions.
dragRound()
DragGames.UI:SetWindowScale(1)
local target = Drag.cells[29]
target:SetSize(20, 10)
local source = dragFrom(4, 4)
cursorOn(5, 4)
dragClient.env.cursorX = dragClient.env.cursorX + (10 - Drag.tileSize / 2)
Drag:UpdateDrag()
check(not Drag.swap and Drag.drag, "Cursor outside the actual target rectangle triggered a swap")
dragClient.env.cursorY = dragClient.env.cursorY + (Drag.tileSize / 2 - 5)
Drag:UpdateDrag()
check(Drag.swap and Drag.swap.tx == 5, "Actual non-square destination bounds were ignored")
releaseDrag(source)
-- Distant diagonal tiles do not stand in for a crossed cardinal neighbor.
dragRound()
source = dragFrom(4, 4)
cursorOn(6, 6)
Drag:UpdateDrag()
check(not Drag.swap and Drag.drag, "A non-adjacent destination triggered a swap")
releaseDrag(source)
dragRound()
source = dragFrom(2, 1)
dragBy(0, -source:GetHeight() * 50)
check(
    Drag.swap and Drag.swap.valid and Drag.swap.ty == 2 and Drag.model.moves == 1,
    "Fast off-board movement skipped the first crossed neighbor"
)
releaseDrag(source)
for _, edge in ipairs({ { 1, 4, -1, 0 }, { 8, 4, 1, 0 }, { 4, 1, 0, 1 }, { 4, 8, 0, -1 } }) do
    dragRound()
    source = dragFrom(edge[1], edge[2])
    dragBy(edge[3] * source:GetWidth(), edge[4] * source:GetHeight())
    check(
        not Drag.swap
            and not Drag.drag
            and not Drag.dragTracker.scripts.OnUpdate
            and Drag.model.moves == 0
            and Drag.model.score == 0,
        "Out-of-board destination did not cancel the gesture"
    )
    dragBy(-edge[3] * source:GetWidth(), -edge[4] * source:GetHeight())
    releaseDrag(source)
    check(not Drag.swap and not Drag.selected, "Cancelled edge gesture restarted or leaked a click")
end
-- Normal stationary clicks preserve selection and the existing click-to-swap path.
dragRound()
source = dragFrom(2, 1)
releaseDrag(source)
check(
    Drag.selected and Drag.selected.x == 2 and Drag.selected.y == 1 and not Drag.swap,
    "Stationary click stopped selecting tiles"
)
source = dragFrom(2, 2)
releaseDrag(source)
check(Drag.swap and Drag.swap.valid and Drag.model.moves == 1, "Click-to-swap stopped working")
-- Early release and missed mouse-up events never evaluate a drag swap.
for _, missed in ipairs({ false, true }) do
    dragRound()
    source = dragFrom(2, 1)
    dragBy(0, -source:GetHeight() * 0.25)
    dragClient.env.mouseDown = false
    if missed then
        Drag:UpdateDrag()
    else
        source.scripts.OnMouseUp(source, "LeftButton")
    end
    source.scripts.OnClick(source, "LeftButton")
    check(
        not Drag.drag
            and not Drag.swap
            and not Drag.selected
            and Drag.model.moves == 0
            and not Drag.dragTracker.scripts.OnUpdate,
        "Early release swapped or leaked a click"
    )
end
dragRound()
source = dragFrom(2, 1)
cursorOn(2, 2)
releaseDrag(source)
check(not Drag.swap and Drag.model.moves == 0, "Mouse-up evaluated an untracked neighbor entry")
-- Invalid matches retain rollback timing, even while the button stays held.
dragRound()
local attempts = 0
local swapRule = Drag.model.Swap
Drag.model.Swap = function(model, ...)
    attempts = attempts + 1
    return swapRule(model, ...)
end
for i = 1, 12 do
    source = dragFrom(8, 8)
    dragBy(-source:GetWidth(), 0)
    check(
        Drag.swap and not Drag.swap.valid and attempts == i and Drag.model.moves == 0,
        "Rapid gesture bypassed invalid-match validation or duplicated a swap"
    )
    for _ = 1, 4 do
        Drag:Advance(0.1)
    end
    dragBy(-source:GetWidth() * 6, source:GetHeight() * 6)
    check(
        not Drag.swap and attempts == i and not Drag.dragTracker.scripts.OnUpdate,
        "Held input restarted after rollback completed"
    )
    releaseDrag(source)
    Drag.cells[63].scripts.OnClick(Drag.cells[63], "LeftButton")
    check(not Drag.selected and attempts == i, "Late destination click escaped gesture suppression")
end
-- Pause, navigation, close, resize/rebuild and stop must remove active tracking.
for _, cancel in ipairs({ "pause", "home", "options", "close", "resize", "rebuild", "scale", "stop" }) do
    dragRound()
    source = dragFrom(2, 1)
    dragBy(0, -source:GetHeight() * 0.5)
    if cancel == "pause" then
        Drag:Pause(true)
    elseif cancel == "home" then
        DragGames.UI:ShowHome()
    elseif cancel == "options" then
        DragGames.UI:ShowOptions()
    elseif cancel == "close" then
        DragGames.UI.frame:Hide()
    elseif cancel == "resize" then
        DragGames.UI:SetWindowSize(1500, 900)
    elseif cancel == "rebuild" then
        Drag:CreateUI(Drag.root:GetParent())
    elseif cancel == "scale" then
        DragGames.UI:SetWindowScale(0.75)
        Drag:UpdateDrag()
    else
        DragGames:AbortGame()
    end
    check(
        not Drag.drag
            and not Drag.dragFrame:IsShown()
            and not Drag.dragTracker.scripts.OnUpdate
            and Drag.model.moves == 0,
        "Lifecycle cancellation left gesture tracking active: " .. cancel
    )
    releaseDrag(source)
    check(not Drag.swap and Drag.model.moves == 0, "Cancelled gesture leaked a release swap: " .. cancel)
end
local launcherClient = client("ArcadePlayer", "ArcadeRealm")
launcherClient.grouped = false
local Arcade = launcherClient.games
Arcade.UI:OpenLauncher("home")
do
    -- Native BackdropTemplate draws its opaque Center in BACKGROUND. Hero art
    -- must have a strictly higher draw layer, independent of creation/reparent order.
    for _, size in ipairs({ { 1000, 700 }, { 1120, 700 }, { 1500, 850 } }) do
        Arcade.UI:SetWindowSize(size[1], size[2])
        for _, id in ipairs({ "bejeweled", "tetris" }) do
            for _, page in ipairs({ "options", "results", "home" }) do
                Arcade.UI:OpenLauncher(page)
            end
            Arcade.UI:FeatureGame(id)
            local ui = Arcade.UI
            check(
                ui.hero.backdropInfo and ui.hero.backdropInfo.bgFile == nil and ui.hero.premium.artwork,
                "Featured surface still has an opaque native backdrop fill"
            )
            ui.heroArt:SetVertexColor(0, 0, 0, 1)
            ui.heroArt:SetBlendMode("ADD")
            ui.heroArt:Hide()
            ui:RefreshFeature(ui.content:GetWidth())
            check(
                ui.heroArt.vertexColor[1] == 1 and ui.heroArt.blendMode == "BLEND" and ui.heroArt:IsShown(),
                "Featured refresh retained stale tint, blend or visibility"
            )
            check(
                ui.heroArt:IsVisible()
                    and ui.heroArt.textureValue == Arcade.Artwork[id .. "-hero"].file
                    and ui.heroArt.alpha == 1,
                "Featured artwork disappeared after navigation/resize: " .. id
            )
            check(
                ui.heroArt.drawLayer == "ARTWORK" and ui.heroArt.subLevel == 0,
                "Featured image can be covered by the native BACKGROUND backdrop"
            )
            check(
                ui.heroShade.drawLayer == "ARTWORK"
                    and ui.heroShade.subLevel == 1
                    and ui.heroShade.color[4] < 1
                    and ui.heroShade.width < ui.hero.width,
                "Featured shade must be translucent, text-side only and above the image"
            )
            check(
                ui.heroFallback.drawLayer == "ARTWORK"
                    and ui.heroFallback.subLevel == 2
                    and not ui.heroFallback:IsShown()
                    and ui.soloTitle.drawLayer == "OVERLAY"
                    and ui.soloPlay.parent == ui.hero,
                "Featured art obscures native text/actions or fallback icon"
            )
        end
    end
    Arcade.UI:ResetWindowSize()
end
check(#Arcade:GetGames() == 2 and not Arcade.Registry.pug, "Concept artwork registered a fake game")
check(
    Arcade.UI.noGames:IsShown() and Arcade.UI.browseGames:IsShown() and #Arcade:GetRecentGames() == 0,
    "New Home did not show the recent-games empty state"
)
check(
    Arcade.UI.groupStatus.text == "No group" and Arcade.UI.footer.text:find("2 installed", 1, true),
    "Inaccurate footer or party status"
)
Arcade.UI.browseGames.scripts.OnClick()
check(
    Arcade.UI.launcherPage == "singleplayer"
        and Arcade.UI.launcherCards[1].title.text == "Bejeweled"
        and Arcade.UI.launcherCards[2].title.text == "Tetris",
    "Browse did not show registered games"
)
Arcade.UI.launcherCards[2].details.scripts.OnClick()
check(
    Arcade.UI.launcherPage == "home"
        and Arcade.UI.featuredID == "tetris"
        and Arcade.UI.heroArt.textureValue == Arcade.Artwork["tetris-hero"].file,
    "Game details lost the feature art"
)
local arcadePackets = #packets
Arcade.UI.soloPlay.scripts.OnClick()
check(
    Arcade.ActiveGame and Arcade.ActiveGame.game.id == "tetris" and #packets == arcadePackets,
    "Feature did not launch the game locally"
)
check(Arcade.DB.recentGames[1] == "tetris" and #Arcade.DB.recentGames == 1, "Actual launch did not persist history")
local arcadeModel = Arcade.Tetris.model
Arcade.UI:OpenLauncher("home")
check(Arcade.UI.launcherCards[1].play.text == "Resume", "Recent game has no Resume action")
check(
    Arcade.UI.abortButton:IsShown()
        and Arcade.UI.abortButton.text == "|cffff6060Stop game|r"
        and Arcade.UI.abortButton.points[1][2] + Arcade.UI.abortButton.width <= Arcade.UI.groupPanel.points[1][2],
    "Party status covers quick stop"
)
Arcade.UI.launcherCards[1].play.scripts.OnClick()
check(Arcade.Tetris.model == arcadeModel and #Arcade.DB.recentGames == 1, "Resume restarted or duplicated the game")
Arcade.UI:ShowOptions()
Arcade.Tetris:Advance(0.1)
check(
    Arcade.Tetris.paused and Arcade.UI.optionsFrame.parent == Arcade.UI.content and Arcade.UI.pageBack:IsShown(),
    "Options is not a safe embedded page"
)
Arcade.UI.pageBack.scripts.OnClick()
check(
    Arcade.Tetris.model == arcadeModel and Arcade.UI.gameContainer:IsShown() and not Arcade.UI.optionsFrame:IsShown(),
    "Options Back did not preserve the board or clear input blocker"
)
Arcade.UI:OpenLauncher("singleplayer")
Arcade.UI.abortButton.scripts.OnClick()
check(
    not Arcade.ActiveGame
        and not Arcade.Tetris.running
        and Arcade.UI.frame:IsShown()
        and Arcade.UI.home:IsShown()
        and Arcade.UI.launcherPage == "singleplayer"
        and not Arcade.UI.abortButton:IsShown(),
    "Launcher Stop game must stop Tetris and preserve the visible Launcher page"
)
Arcade:StartSingleplayer("bejeweled")
Arcade.UI:OpenLauncher("home")
Arcade.UI.abortButton.scripts.OnClick()
check(
    not Arcade.ActiveGame
        and not Arcade.Bejeweled.running
        and Arcade.UI.frame:IsShown()
        and Arcade.UI.home:IsShown()
        and Arcade.UI.launcherPage == "home"
        and not Arcade.UI.abortButton:IsShown(),
    "Launcher Stop game must stop Bejeweled and preserve the visible Launcher page"
)
check(
    Arcade.DB.recentGames[1] == "bejeweled" and Arcade.DB.recentGames[2] == "tetris",
    "Recent games are not newest-first"
)
Arcade:StartSingleplayer("tetris")
Arcade:AbortGame()
check(
    #Arcade.DB.recentGames == 2 and Arcade.DB.recentGames[1] == "tetris",
    "Repeated launch did not move one unique game to the front"
)
do
    local malformed = {
        [1] = false,
        [2] = "tetris",
        [3] = {},
        [4] = "removed_module",
        [6] = "bejeweled",
        [8] = "tetris",
        wrong = "bejeweled",
    }
    Arcade.DB.recentGames = malformed
    local recent = Arcade:GetRecentGames()
    check(
        #recent == 2 and recent[1].id == "tetris" and recent[2].id == "bejeweled",
        "Invalid, sparse or duplicate history was not filtered"
    )
    check(
        Arcade.DB.recentGames == malformed and Arcade.DB.recentGames[4] == "removed_module",
        "Browsing corrupted unknown saved history"
    )
    Arcade:RecordGameLaunch("bejeweled")
    check(
        #Arcade.DB.recentGames == 3 and Arcade.DB.recentGames[3] == "removed_module",
        "Recording a launch discarded a temporarily removed module"
    )
    local saved = Arcade.Copy(Arcade.DB)
    local reloaded = client("ArcadeReload", "ArcadeRealm", saved)
    check(
        reloaded.games:GetRecentGames()[1].id == "bejeweled" and #reloaded.games:GetRecentGames() == 2,
        "Reload lost recent-game ordering"
    )
    reloaded.games.UI:OpenLauncher("home")
    check(reloaded.games.UI.launcherCards[1].title.text == "Bejeweled", "Reload did not render saved recent cards")
    reloaded.games:RegisterGame({
        id = "removed_module",
        title = "Recovered module",
        version = "1",
        mode = "singleplayer",
        CreateUI = function(_, parent)
            return reloaded.env.CreateFrame("Frame", nil, parent)
        end,
        OnStart = function() end,
    })
    check(
        reloaded.games:GetRecentGames()[3].id == "removed_module",
        "Reinstalled module lost its saved history position"
    )
    for _, invalid in ipairs({ false, 17, "broken" }) do
        Arcade.DB.recentGames = invalid
        check(#Arcade:GetRecentGames() == 0, "Invalid history container was accepted")
    end
    Arcade.DB.recentGames = saved.recentGames
end
Arcade.UI:OpenLauncher("home")
Arcade.UI.nav.results.scripts.OnClick()
check(
    Arcade.UI.launcherPage == "results"
        and Arcade.UI.resultsFrame.parent == Arcade.UI.content
        and not Arcade.UI.optionsFrame:IsShown(),
    "Results opened outside shared navigation"
)
Arcade.UI.nav.options.scripts.OnClick()
check(Arcade.UI.launcherPage == "options" and not Arcade.UI.resultsFrame:IsShown(), "Options did not replace Results")
Arcade:SetOption("followCharacter", false)
Arcade.UI.classDropdown.buttons.HUNTER.scripts.OnClick()
check(Arcade:GetClassPreset() == "HUNTER", "Embedded class controls did not save settings")
Arcade.UI.optionsScroll.scripts.OnMouseWheel(Arcade.UI.optionsScroll, -1)
check(Arcade.UI.optionsScroll:GetVerticalScroll() == 0, "Compact Options still requires scrolling")
for _, page in ipairs({ "home", "singleplayer", "multiplayer", "results", "options", "home" }) do
    Arcade.UI.nav[page].scripts.OnClick()
    check(
        Arcade.UI.launcherPage == page and Arcade.DB.launcherPage == page and Arcade.UI.nav[page].selected,
        "Unified navigation failed: " .. page
    )
    check(
        Arcade.UI.optionsFrame:IsShown() == (page == "options")
            and Arcade.UI.resultsFrame:IsShown() == (page == "results"),
        "Embedded page visibility is inconsistent"
    )
end
for _, name in ipairs({ "home", "singleplayer", "multiplayer", "results", "options" }) do
    local nav = Arcade.UI.nav[name]
    check(
        nav.navIcon.textureValue == Arcade.Artwork["nav-" .. name].file and nav.navIcon.width == nav.navIcon.height,
        "Missing or stretched navigation texture"
    )
    nav.scripts.OnEnter()
    check(
        nav.navGlow.alpha > 0 and nav.border[2] == Arcade.Theme.Colors.accent[2],
        "Navigation hover did not brighten the icon and border"
    )
    nav.scripts.OnLeave()
    nav:Disable()
    check(nav.navIcon.alpha == 0.35 and nav.navGlow.alpha == 0, "Disabled navigation has wrong styling")
    nav:Enable()
end
Arcade:RegisterGame({
    id = "external_arcade",
    title = "External Arcade",
    version = "1",
    mode = "multiplayer",
    CreateUI = function(_, parent)
        return launcherClient.env.CreateFrame("Frame", nil, parent)
    end,
    OnStart = function() end,
})
Arcade.UI:FeatureGame("external_arcade")
check(
    Arcade.UI.soloPlay.text == "View lobby" and Arcade.UI.heroFallback:IsShown(),
    "External module lost native fallback and lobby action"
)
Arcade.UI.soloPlay.scripts.OnClick()
check(
    Arcade.UI.launcherPage == "multiplayer"
        and Arcade.UI.browserPanel:IsShown()
        and Arcade.UI.lobbyPanel:IsShown()
        and Arcade.UI.cardScroll:IsShown(),
    "Multiplayer lost browsing or lobby controls"
)
check(
    not Arcade.UI.create.enabled and not Arcade:GetRecentGames()[3],
    "Browsing a multiplayer lobby counted as an actual launch"
)
launcherClient.grouped, launcherClient.roster = true, { a.name, b.name }
launcherClient:event("GROUP_ROSTER_UPDATE")
check(
    Arcade.UI.groupStatus.text == "Party connected" and Arcade.UI.groupDetail.text:find("3 members", 1, true),
    "Group status is not roster-backed"
)
check(Arcade.UI.create.enabled, "Eligible party could not host a module")
Arcade.UI.create.scripts.OnClick()
check(Arcade.Lobby and Arcade.Lobby.gameID == "external_arcade", "Host action lost registry selection")
Arcade:LeaveLobby()
Arcade.UI:OpenLauncher("home")
Arcade.UI:FeatureGame("tetris")
launcherClient.env.rejectTexture = Arcade.Artwork["tetris-hero"].file
Arcade.UI:Refresh()
check(
    Arcade.UI.heroArt.color and Arcade.UI.heroFallback:IsShown() and Arcade.UI.soloPlay.enabled,
    "A rejected texture lost its native fallback or broke Play"
)
launcherClient.env.rejectTexture = nil
for _, scale in ipairs({ 1, 1.2 }) do
    Arcade.UI:SetWindowScale(scale)
    check(
        Arcade.UI.hero:GetEffectiveScale() == scale and Arcade.UI.launcherCards[1].icon:GetEffectiveScale() == scale,
        "Artwork scale diverged"
    )
end
Arcade.UI:SetWindowScale(1)
do
    -- Temporary isolated registry: not shipped in runtime code.
    local many = client("LibraryStress", "ArcadeRealm")
    local M = many.games
    local function install(id, mode)
        M:RegisterGame({
            id = id,
            title = id,
            version = "1",
            mode = mode,
            minPlayers = 1,
            maxPlayers = mode == "singleplayer" and 1 or 5,
            CreateUI = function(_, parent)
                return many.env.CreateFrame("Frame", nil, parent)
            end,
            OnStart = function() end,
        })
    end
    for i = 1, 24 do
        install(string.format("Solo %02d", i):gsub(" ", "_"), "singleplayer")
        install(string.format("Party %02d", i):gsub(" ", "_"), "multiplayer")
    end
    M.UI:OpenLauncher("singleplayer")
    check(
        #M:GetGames("singleplayer") == 26 and M.UI.launcherCards[26]:IsShown(),
        "Library capped the installed game count"
    )
    check(
        M.UI.cardScroll.kind == "ScrollFrame"
            and M.UI.cardScroll.clipsChildren
            and M.UI.cardScroll.scrollChild == M.UI.cardList,
        "Library is not a clipped native scroll frame"
    )
    local function wheel(frame)
        frame.scripts.OnMouseWheel(frame, -3)
        check(frame:GetVerticalScroll() > 0 and frame.scrollBar:IsShown(), "Mouse-wheel did not scroll a large library")
    end
    wheel(M.UI.cardScroll)
    local oldColumns = M.UI.cardColumns
    M.UI:SetWindowSize(1000, 740)
    check(M.UI.cardColumns < oldColumns, "Narrow resize did not reflow columns")
    M.UI:SetWindowSize(1500, 900)
    check(
        M.UI.cardColumns > oldColumns and M.UI.cardList.width == M.UI.cardScroll.width - 18,
        "Wide resize did not reflow or reserve scrollbar space"
    )
    for _, card in ipairs(M.UI.launcherCards) do
        if card:IsShown() then
            local point = card.points[1]
            check(
                point[2] >= 0 and point[2] + card.width <= M.UI.cardList.width + 0.01 and card.width >= 250,
                "Card exceeds its layout bounds"
            )
        end
    end
    M.UI:OpenLauncher("multiplayer")
    check(
        M.UI.launcherCards[24]:IsShown() and M.UI.browserPanel:IsShown() and M.UI.lobbyPanel:IsShown(),
        "Large multiplayer library hid lobby controls"
    )
    wheel(M.UI.cardScroll)
    check(
        M.UI.cardScroll.points[1][2] + M.UI.cardScroll.width < M.UI.lobbyPanel.points[1][2],
        "Library overlaps lobby actions"
    )
    M.UI:LaunchGame("Party_01")
    check(#M:GetRecentGames() == 0, "Selecting a party module recorded a launch")
    M:CreateLobby("Party_01")
    M:Ready(true)
    pump(40)
    check(M.ActiveGame and M.DB.recentGames[1] == "Party_01", "Actual multiplayer start did not enter recent games")
    M.UI:ShowOptions()
    check(M.ActiveGame and M.Lobby.status == "running", "Page navigation ended a multiplayer match")
    M.UI.pageBack.scripts.OnClick()
    check(M.ActiveGame and M.UI.gameContainer:IsShown(), "Multiplayer return lost the session")
    M:AbortGame()
    M:LeaveLobby()
    for i = 1, 8 do
        M:StartSingleplayer(string.format("Solo_%02d", i))
        M:AbortGame()
    end
    M.UI:OpenLauncher("home")
    check(
        M.UI.cardColumns == 3 and M.UI.recentIndicator:IsShown() and M.UI.launcherCards[1].title.text == "Solo_08",
        "Recent carousel is not newest-first or capped at three"
    )
    M.UI.recentNext.scripts.OnClick()
    check(M.UI.recentPage == 2 and M.UI.launcherCards[1].title.text == "Solo_05", "Carousel did not advance")
    M.UI.recentPrevious.scripts.OnClick()
    check(M.UI.recentPage == 1 and not M.UI.recentPrevious.enabled, "Carousel previous boundary is wrong")
    M.UI:SetWindowSize(1000, 700)
    check(
        M.UI.cardColumns == 2 and M.UI.launcherCards[3] and not M.UI.launcherCards[3]:IsShown(),
        "Recent visible count did not adapt to narrow width"
    )
    M.UI.recentPage = 999
    M.UI:RefreshLauncher()
    check(not M.UI.recentNext.enabled, "Out-of-range carousel page was not clamped")
    M.UI:ShowResults()
    check(#M.UI.resultGameButtons == 50, "Results selector capped registered games")
    wheel(M.UI.resultGamesScroll)
    M.UI.resultGameID = "tetris"
    M.DB.tetris = { best = { score = 12345, lines = 12, level = 3 } }
    local best = M.Copy(M.DB.tetris.best)
    M.UI:RefreshResults()
    check(
        M.UI.bestScore.text == "12345 points" and M.UI.bestMetadata.text:find("Lines: 12", 1, true),
        "Results did not read existing best metadata"
    )
    check(
        M.DB.tetris.best.score == best.score and M.UI.resultText.text:find("No saved matches", 1, true),
        "Results fabricated matches or mutated scores"
    )
    M.UI.resultGameID = "Party_01"
    M.UI:RefreshResults()
    check(M.UI.resultText.text:find("Interrupted", 1, true), "Results API history disappeared")
    M.UI:ShowOptions()
    M:SetOption("followCharacter", false)
    M.UI.classDropdown.buttons.SHAMAN.scripts.OnClick()
    M.UI:SetWindowSize(1300, 820)
    M.UI:SetWindowScale(1.1)
    local persisted = M.Copy(M.DB)
    local restored = client("LibraryReload", "ArcadeRealm", persisted)
    check(
        restored.games.UI.frame.width == restored.games.UI.BASE_WIDTH
            and restored.games.UI.frame.height == restored.games.UI.BASE_HEIGHT
            and restored.games.UI.frame:GetScale() == 1.1
            and restored.games:GetClassPreset() == "SHAMAN",
        "Reload lost layout or class settings"
    )
    M.UI:ResetWindowSize()
    check(
        M.UI.frame.width == M.UI.BASE_WIDTH and M.UI.frame.height == M.UI.BASE_HEIGHT and M.UI.frame:GetScale() == 1,
        "Reset Size lost base geometry or scale"
    )
    M.UI:OpenLauncher("singleplayer")
    local count = #many.frames
    for _ = 1, 5 do
        for _, page in ipairs({ "home", "singleplayer", "multiplayer", "options", "results" }) do
            M.UI:OpenLauncher(page)
        end
    end
    check(#many.frames == count, "Repeated navigation leaked UI frames")
    local previous = table.concat(M:GetRecentIDs(), ",")
    M:RegisterGame({
        id = "failed_start",
        title = "Failed start test",
        version = "1",
        mode = "singleplayer",
        CreateUI = function(_, parent)
            return many.env.CreateFrame("Frame", nil, parent)
        end,
        OnStart = function()
            error("Expected test startup failure")
        end,
    })
    M:StartSingleplayer("failed_start")
    check(
        not M.ActiveGame and table.concat(M:GetRecentIDs(), ",") == previous,
        "Failed OnStart recorded a recent launch"
    )
    M:AbortGame()
    M:LeaveLobby()
end
local cardFrames = #launcherClient.frames
for _ = 1, 5 do
    Arcade.UI:Refresh()
end
check(#launcherClient.frames == cardFrames, "Launcher refresh leaked decorative/UI frames")
do
    local owner = client("ComponentChecks", "ArcadeRealm")
    local C, ui = owner.games.Theme, owner.games.UI
    local parent = owner.env.CreateFrame("Frame", nil, ui.content)
    local f = C:PremiumFrame(parent, 400, 220, 0, 0)
    check(
        f.component == "PremiumFrame"
            and #f.premium.outer == 4
            and #f.premium.inner == 4
            and #f.premium.corners == 16
            and #f.premium.glow == 8,
        "Premium frame lost its layered native decoration"
    )
    local count = #owner.frames
    C:StylePremiumFrame(f, "window-frame")
    check(#owner.frames == count and not f.scripts.OnUpdate, "Frame decoration is duplicated or continuously updated")
    for _, part in ipairs(f.premium.corners) do
        check(
            part.kind == "texture" and not part.scripts.OnMouseDown and not part.scripts.OnUpdate,
            "Decorative corners intercept input or animate continuously"
        )
    end
    local clicked = 0
    local b = C:NeonButton(parent, "Test action", 180, 0, -230, function()
        clicked = clicked + 1
    end, 34, true)
    check(b.visualState == "normal" and b.component == "NeonButton", "Neon button lacks normal styling")
    local normal = b.sheen.alpha
    b.scripts.OnEnter()
    check(b.visualState == "hover" and b.sheen.alpha > normal, "Neon hover does not brighten")
    C:Select(b, true)
    b.scripts.OnMouseDown()
    check(b.visualState == "pressed" and b.sheen.alpha < normal, "Selected button ignores pressed state")
    b.scripts.OnMouseUp()
    b.scripts.OnLeave()
    check(b.visualState == "selected", "Neon selection was lost after pressing")
    b:Disable()
    check(
        b.visualState == "disabled" and not b.pressed and b.premium.glow[1].alpha == 0,
        "Disabled button retains a pressed appearance or glow"
    )
    b:Enable()
    b.scripts.OnClick()
    check(clicked == 1 and b.visualState == "selected", "Neon styling disconnected the functional action")
    local stat = C:StatPanel(parent, "BEST", 400, 112, 0, 0)
    stat:SetStat(0, "Recorded score")
    check(stat.value.text == "0" and stat.detail.text == "Recorded score", "StatPanel loses zero values")
    stat:SetStat(nil)
    check(stat.value.text == "No record" and stat.detail.text == "", "StatPanel invents a missing statistic")
    stat:SetWidth(300)
    check(stat.value.width == 268, "StatPanel does not resize its contents")
    local status = C:StatusPanel(parent, 264, 54, 0, 0)
    status:SetStatus("No group", "Solo play mode", false)
    check(status.pip.color[1] == C.Colors.muted[1], "Disconnected status uses a live-state indicator")
    status:SetStatus("Party connected", "2 members", true)
    check(
        status.title.text == "Party connected" and status.pip.color[2] == C.Colors.success[2],
        "StatusPanel lost actual connection data"
    )
    local heading = C:SectionHeader(parent, "STATISTICS", 400, 0, 0)
    heading:SetWidth(240)
    heading:SetText("SCORE")
    check(
        heading.text == "SCORE" and heading.line.points[1][2] < 240 and heading.pip.kind == "texture",
        "SectionHeader divider or label did not reflow"
    )
    local card = C:GameCard(parent, 280, 226)
    card:SetGame(owner.games.Registry.tetris, {
        art = "tetris-card",
        enabled = true,
        onPlay = function()
            clicked = clicked + 1
        end,
    })
    local before = #owner.frames
    card:SetSize(360, 226)
    card.play.scripts.OnClick()
    check(
        card.title.text == "Tetris"
            and card.play.text == "Play"
            and card.play.width == 256
            and card.art.width == 360
            and clicked == 2
            and #owner.frames == before,
        "Reusable GameCard lost data/action, resize support or frame reuse"
    )
    check(
        card.art.subLevel < card.shade.subLevel and card.shade.subLevel < card.icon.subLevel,
        "GameCard shading obscures the artwork/icon stack"
    )
    local original = owner.games.Artwork["stat-frame"].file
    owner.games.Artwork["stat-frame"].file = "Interface\\AddOns\\KIC-Games\\Media\\KICUI\\missing-test.tga"
    owner.env.rejectTexture = owner.games.Artwork["stat-frame"].file
    local fallback = C:StatPanel(parent, "Fallback", 300, 112, 0, 0)
    check(
        not fallback.premium.custom:IsShown() and #fallback.premium.corners == 16,
        "Failed skin texture removed the native premium fallback"
    )
    owner.env.rejectTexture = nil
    local replacement = C:StatPanel(parent, "Replacement", 300, 112, 0, 0)
    check(
        replacement.premium.custom:IsShown() and replacement.premium.outer == nil,
        "Artwork registry replacement is not used by the component"
    )
    owner.games.Artwork["stat-frame"].file = original
    check(
        ui.frame.premium
            and ui.sidebar.premium
            and ui.hero.premium
            and ui.lobbyPanel.premium
            and ui.groupPanel.component == "StatusPanel"
            and ui.bestPanel.component == "StatPanel"
            and ui.installedTitle.component == "SectionHeader",
        "Launcher proof of concept does not use the shared components"
    )
    check(
        not owner.games.Tetris.root and not owner.games.Bejeweled.root,
        "Shared component checks constructed individual game screens"
    )
end
-- Gameplay redesign: real constructors, responsive geometry and safe navigation.
do
    local owner = client("GameplayUI", "LayoutRealm")
    owner.grouped = false
    local games, ui = owner.games, owner.games.UI
    local function fits(frame, width, height)
        local point = frame.points[1]
        return point
            and point[2] >= 0
            and point[3] <= 0
            and point[2] + frame.width <= width + 0.01
            and -point[3] + frame.height <= height + 0.01
    end
    for _, id in ipairs({ "bejeweled", "tetris" }) do
        check(games:StartSingleplayer(id), "Gameplay UI fixture did not start")
        local game = id == "tetris" and games.Tetris or games.Bejeweled
        local model, active = game.model, games.ActiveGame
        check(
            ui.homeButton:IsShown()
                and ui.groupPanel:IsShown()
                and ui.closeButton:IsShown()
                and not ui.abortButton:IsShown()
                and not ui.optionsButton:IsShown()
                and not ui.resultsButton:IsShown(),
            "Gameplay header must contain Back, live party status and Close only"
        )
        check(
            ui.homeButton.caption.width == 134 and ui.homeButton.gameIcon.artLoaded,
            "Back caption or navigation artwork did not resize"
        )
        for _, size in ipairs({ { 1000, 700 }, { 1120, 700 }, { 1500, 900 }, { 1000, 1000 } }) do
            ui:SetWindowSize(size[1], size[2])
            local w, h = ui.gameContainer.width, ui.gameContainer.height
            for _, panel in ipairs({ game.left, game.board, game.right }) do
                check(fits(panel, w, h), id .. " panel exceeds responsive content bounds")
            end
            local bp, rp = game.board.points[1], game.right.points[1]
            check(game.left.width < bp[2] and bp[2] + game.board.width < rp[2], id .. " side panels overlap the board")
            check(
                ui.gameContainer.backdropInfo == nil and game.board.premium and #game.board.diamonds == 4,
                "Board lost shared frame or layered ornaments"
            )
            local before = #owner.frames
            game:LayoutUI()
            game:Render(true)
            check(#owner.frames == before and game.model == model, "Resize recreated UI or reset the game")
            if id == "bejeweled" then
                check(
                    #game.cells == 64
                        and game.tileSize == game.step - 2
                        and game.board.width == 8 * game.step + 24
                        and game.board.width == game.board.height,
                    "Bejeweled grid lost square 8x8 proportions"
                )
                check(
                    game.viewport.clipsChildren
                        and game.cells[64].parent == game.viewport
                        and fits(game.cells[64], game.viewport.width, game.viewport.height),
                    "Bejeweled cells or clipped animation viewport exceed board"
                )
                check(
                    game.leftArt.artLoaded
                        and game.leftArt.drawLayer == "ARTWORK"
                        and game.hintButton.points[1][3] > game.pauseButton.points[1][3]
                        and game.pauseButton.points[1][3] > game.shareButton.points[1][3]
                        and game.shareButton.points[1][3] > game.optionsButton.points[1][3],
                    "Bejeweled artwork or required action order changed"
                )
                check(
                    -game.gemDecor.points[1][3] >= -game.cascadeRow.points[1][3] + game.cascadeRow.height,
                    "Decorative gem art overlaps a statistic"
                )
            else
                check(
                    #game.cells == 200
                        and (game.board.width - 24) * 2 == game.board.height - 24
                        and game.cells[1].bg.width == game.cells[1].bg.height,
                    "Tetris cells or 10x20 proportions changed"
                )
                check(
                    #game.nextSlots == 5
                        and #game.nextCells == 5
                        and #game.holdCells == 8
                        and game.controlRows[8].key.label.text == "Chat",
                    "Queue, hold or truthful chat auto-pause instruction missing"
                )
                for _, panel in ipairs({ game.statPanel, game.nextPanel, game.holdPanel, game.pauseButton }) do
                    check(fits(panel, game.right.width, h), "Tetris right-side section exceeds bounds")
                end
                for _, slot in ipairs(game.nextSlots) do
                    check(fits(slot, game.nextPanel.width, game.nextPanel.height), "Next slot exceeds panel")
                end
                check(
                    -game.controlsText.points[1][3] + game.controlsText.height < -game.optionsButton.points[1][3],
                    "Tetris keycaps overlap bottom actions"
                )
            end
        end
        ui:SetWindowSize(1120, 700)
        ui:SetWindowScale(1.2)
        if id == "tetris" then
            game:KeyDown("LEFT")
        end
        local recents = #games.DB.recentGames
        ui:FeatureGame(id == "tetris" and "bejeweled" or "tetris")
        ui.homeButton.scripts.OnClick()
        check(
            game.paused and game.model == model and games.ActiveGame == active and #games.DB.recentGames == recents,
            "Back reset session/history or did not pause immediately"
        )
        check(
            ui.featuredID == id
                and ui.heroArt.artKey == id .. "-hero"
                and ui.soloTitle.text == id:upper()
                and ui.soloOpen:IsShown()
                and not ui.soloPlay:IsShown(),
            "Returning from gameplay left another game featured instead of the active game's artwork/title/resume"
        )
        if id == "tetris" then
            check(next(game.keys) == nil, "Back left held keyboard input active")
        end
        ui:LaunchGame(id)
        check(
            game.model == model
                and game.pauseOverlay:IsShown()
                and game.pauseOverlay.dimmer:IsShown()
                and game.pauseOverlay.dimmer:GetFrameLevel() > game.board:GetFrameLevel() + 25
                and game.pauseOverlay:GetFrameLevel() > game.pauseOverlay.dimmer:GetFrameLevel()
                and game.pauseOverlay.background[4] == 1
                and game.pauseOverlay.width <= 320,
            "Paused session must show an opaque menu above the dimmed board and drag layers"
        )
        game.pauseOverlay.resume.scripts.OnClick()
        check(
            not game.paused and not game.pauseOverlay:IsShown() and not game.pauseOverlay.dimmer:IsShown(),
            "Pause menu Resume failed or left the dimmer visible"
        )
        ui.closeButton.scripts.OnClick()
        check(
            not ui.frame:IsShown() and game.paused and games.ActiveGame == active and game.model == model,
            "Close lost the current run or failed to pause"
        )
        ui:Toggle()
        ui:LaunchGame(id)
        game.pauseOverlay.resume.scripts.OnClick()
        ui:ShowOptions()
        game:Advance(0.01)
        check(
            game.paused and game.model == model and ui.optionsFrame:IsShown() and not ui.gameContainer:IsShown(),
            "Options did not safely block the active game"
        )
        ui.pageBack.scripts.OnClick()
        game.pauseOverlay.resume.scripts.OnClick()
        local before = #owner.frames
        if id == "bejeweled" then
            model.score = model.score + 150
            game:Render()
            check(game.scorePulseLeft == 0.35, "Score increase did not trigger feedback")
            for _ = 1, 5 do
                game:Advance(0.1)
            end
            check(
                game.scorePulseLeft == 0 and game.scorePulse.alpha == 0,
                "Score feedback did not finish on the existing update loop"
            )
        else
            for _ = 1, 40 do
                game:KeyDown("UP")
                game.root.scripts.OnKeyUp(game.root, "UP")
                game:Advance(0.001)
            end
        end
        check(#owner.frames == before, "Gameplay updates allocated UI frames/textures")
        ui:SetWindowSize(1000, 700)
        model.score = 2147483647
        game:SaveBest()
        game:Render(true)
        check(
            game.scoreText.text == "2147483647"
                and game.bestText.text == "2147483647"
                and game.scoreText:GetStringWidth() <= game.scoreText.width
                and game.bestText:GetStringWidth() <= game.bestText.width,
            "Large real score values were truncated or did not fit the compact readouts"
        )
        game:Pause(true)
        game.pauseOverlay.restart.scripts.OnClick()
        check(
            games.ActiveGame
                and game.model ~= model
                and game.model.score == 0
                and #games.DB.recentGames == recents
                and #owner.frames == before,
            "Restart did not reuse UI, create a clean run or preserve history"
        )
        check(game:Storage().best.score == 2147483647, "Restart lost the prior run's saved best")
        game:Pause(true)
        game.pauseOverlay.stop.scripts.OnClick()
        check(
            not games.ActiveGame
                and not game.running
                and not game.root:IsShown()
                and ui.frame:IsShown()
                and ui.home:IsShown()
                and ui.launcherPage == "home"
                and not ui.gameContainer:IsShown(),
            "Pause-menu Stop must end the run and return to the visible Launcher"
        )
    end
    -- Resized drag hit-testing still uses the same engine action and timing.
    dragRound()
    DragGames.UI:SetWindowSize(1500, 900)
    DragGames.UI:SetWindowScale(1.2)
    local source = dragFrom(2, 1)
    dragBy(0, -source:GetHeight())
    check(
        Drag.swap and Drag.swap.valid and Drag.model.moves == 1 and Drag.swap.time == 0,
        "Resized drag changed swap validation/timing"
    )
    Drag:Render()
    check(Drag.cells[2].border[1] == DragGames.Theme.Colors.ice[1], "Valid swap lost visual feedback")
    Drag:Pause(true)
    Drag:Render()
    local before = #dragClient.frames
    DragGames.UI:ShowGame()
    Drag:Pause(false)
    dragClient.env.mouseDown = true
    dragFrom(4, 4)
    DragGames.UI.closeButton.scripts.OnClick()
    check(
        not Drag.drag and Drag.paused and not Drag.dragFrame:IsShown() and #dragClient.frames == before,
        "Closing during drag did not clean up the floating icon"
    )
    DragGames:AbortGame()
end
-- Options 2.0: dynamic Retail catalogs, shared cosmetics/audio, migration and scale.
do
    local owner = client("OptionsTwo", "OptionsRealm", {
        settings = { classPreset = "MAGE", windowScale = 1.2, windowWidth = 1500, windowHeight = 900 },
        tetris = { best = { score = 321, lines = 7, level = 2, preset = "MAGE" } },
        bejeweled = { best = { score = 654, moves = 5, cleared = 9, bestCascade = 2 } },
        recentGames = { "tetris", "bejeweled" },
    })
    owner.grouped = false
    local games, ui = owner.games, owner.games.UI
    local settings = games:GetSettings()
    check(
        settings.schemaVersion == 2
            and settings.soundVolume == 0.6
            and settings.soundsEnabled
            and settings.soundTheme == "class"
            and settings.followCharacter
            and settings.graphicsTheme == "class",
        "Options defaults/migration are incomplete"
    )
    check(
        ui.frame.width == ui.BASE_WIDTH
            and ui.frame.height == ui.BASE_HEIGHT
            and settings.windowWidth == 1500
            and settings.windowHeight == 900,
        "Legacy size controls still apply, or migration destroyed their stored data"
    )
    check(
        games.DB.tetris.best.score == 321
            and games.DB.bejeweled.best.score == 654
            and games.DB.recentGames[1] == "tetris",
        "Migration reset scores or recent games"
    )
    check(
        #games.Profiles.classes == #owner.apiClasses and games.Profiles.bySpec[1480],
        "Retail catalog omitted available classes or Devourer"
    )
    ui:ShowOptions()
    check(
        not ui.classDropdown:IsEnabled()
            and ui.appearancePanel.switch:IsEnabled()
            and ui.audioAppearancePanel.switch:IsEnabled()
            and not ui.audioAppearancePanel.classDropdown:IsEnabled(),
        "New Follow default did not consistently lock both pages' manual selectors"
    )
    ui.appearancePanel.switch.scripts.OnClick()
    check(
        ui.classDropdown.parent == ui.appearancePanel
            and ui.specDropdown.parent == ui.appearancePanel
            and ui.classDropdown.points[1][3] == ui.specDropdown.points[1][3]
            and ui.classDropdown.points[1][2] + ui.classDropdown:GetWidth() < ui.specDropdown.points[1][2],
        "Class/spec dropdowns are not side by side in one panel"
    )
    ui.classDropdown.scripts.OnClick()
    check(
        ui.classDropdown.popup:IsVisible() and ui.classDropdown.popup.parent == ui.optionsFrame,
        "Dropdown did not open outside the clipped settings scroll child"
    )
    ui.classDropdown.scroll.scripts.OnMouseWheel(ui.classDropdown.scroll, -3)
    check(ui.classDropdown.scroll:GetVerticalScroll() > 0, "Long class menu cannot scroll")
    ui.specDropdown.scripts.OnClick()
    check(
        ui.specDropdown.popup:IsShown() and not ui.classDropdown.popup:IsShown(),
        "Opening a second profile dropdown left the first open"
    )
    ui.specDropdown.popup.scripts.OnKeyDown(ui.specDropdown.popup, "ESCAPE")
    check(
        not ui.specDropdown.popup:IsShown() and not ui.specDropdown.popup.propagate and ui.frame:IsShown(),
        "Escape failed to dismiss only the open dropdown"
    )
    ui.classDropdown.scripts.OnClick()
    ui.classDropdown.popup.scripts.OnMouseDown()
    check(not ui.classDropdown.popup:IsShown(), "Outside click did not dismiss the dropdown")
    local frameCount = #owner.frames
    for _ = 1, 5 do
        ui.classDropdown.scripts.OnClick()
        ui.classDropdown.scripts.OnClick()
    end
    check(
        #owner.frames == frameCount and not ui.classDropdown.popup:IsShown(),
        "Repeated dropdown toggling leaked frames or did not close"
    )
    ui.classDropdown.scripts.OnClick()
    ui:SelectOptionsTab("audio")
    check(not ui.classDropdown.popup:IsShown(), "Changing Options tabs left a dropdown open")
    ui:SelectOptionsTab("graphics")
    ui.specDropdown.scripts.OnClick()
    ui:OpenLauncher("home")
    check(not ui.specDropdown.popup:IsShown(), "Leaving Options left a dropdown open")
    ui:ShowOptions()
    local sets = {}
    for _, class in ipairs(games.Profiles.classes) do
        check(
            ui.classDropdown.buttons[class.token] and #class.specs == #owner.apiClasses[class.id].specs,
            "Class selector/spec count differs from the client API"
        )
        ui.classDropdown.scripts.OnClick()
        ui.classDropdown.buttons[class.token].scripts.OnClick()
        check(
            games:GetClassPreset() == class.token
                and ui.specCount == #class.specs
                and ui.classDropdown.text == class.name
                and not ui.classDropdown.popup:IsShown(),
            "Manual class selector did not filter specializations"
        )
        local ownSets = {}
        for _, spec in ipairs(class.specs) do
            ui.specDropdown.scripts.OnClick()
            ui.specDropdown.buttons[spec.id].scripts.OnClick()
            check(
                select(2, games:GetSelectedProfile()) == spec.id
                    and ui.specDropdown.buttons[spec.id].selected
                    and ui.specDropdown.text == spec.name
                    and not ui.specDropdown.popup:IsShown(),
                "Manual specialization control lost its stable ID or selected state"
            )
            local icons = games:GetPieceIcons("bejeweled")
            local seen = {}
            for i = 1, 7 do
                check(
                    type(icons[i]) == "number" and icons[i] ~= 134400 and not seen[icons[i]],
                    "Spec lacks seven distinct visible spell textures"
                )
                seen[icons[i]] = true
            end
            local fingerprint = table.concat(icons, ",")
            check(not ownSets[fingerprint], "Two specializations of one class share the same icon set")
            ownSets[fingerprint] = true
            sets[spec.id] = fingerprint
            check(ui.previewCells[1].icon.textureValue == icons[1], "Live graphics preview did not update")
            for _, event in ipairs(games.Audio.events) do
                local sound = games.Audio:Resolve("bejeweled", event)
                check(sound and (sound.kit or sound.file), "Audio event has no safe visible-profile fallback")
            end
        end
    end
    -- The runtime catalog must accept new specs without a hardcoded count/list.
    owner.apiClasses[11].specs[#owner.apiClasses[11].specs + 1] =
        { id = 90001, name = "Future specialization", icon = 132337 }
    games.Profiles:Refresh()
    games:SetClassPreset("DRUID")
    check(
        ui.specCount == 5 and games:SetManualSpec(90001) and #games:GetPieceIcons("bejeweled") == 7,
        "API-discovered specialization did not get a selector and safe icon fallback"
    )
    games:SetClassPreset("MAGE")
    games:SetManualSpec(63)
    games:SetOption("graphicsTheme", "original")
    ui.appearancePanel.switch.scripts.OnClick()
    ui.classDropdown.buttons.HUNTER.scripts.OnClick()
    check(
        not settings.followCharacter
            and settings.manualClass == "MAGE"
            and settings.manualSpecID == 63
            and ui.appearancePanel.alpha < 1
            and not ui.appearancePanel.switch:IsEnabled()
            and not ui.classDropdown:IsEnabled()
            and not ui.specDropdown:IsEnabled(),
        "Original Graphics did not visibly disable Follow/class/spec or changed the saved profile"
    )
    local audioProfile = ui.audioAppearancePanel
    check(
        audioProfile.switch:IsEnabled() and audioProfile.classDropdown:IsEnabled(),
        "Original graphics incorrectly disabled independent class audio preferences"
    )
    audioProfile.specDropdown.buttons[64].scripts.OnClick()
    check(
        settings.manualSpecID == 64 and ui.specDropdown.text == "Frost",
        "Audio profile selector did not update the shared class/spec preference"
    )
    audioProfile.switch.scripts.OnClick()
    check(
        settings.followCharacter and not audioProfile.specDropdown:IsEnabled(),
        "Audio Follow switch did not control the shared profile"
    )
    games:SetOption("soundTheme", "arcade")
    audioProfile.switch.scripts.OnClick()
    check(
        settings.followCharacter
            and audioProfile.alpha < 1
            and not audioProfile.switch:IsEnabled()
            and not audioProfile.classDropdown:IsEnabled()
            and not audioProfile.specDropdown:IsEnabled(),
        "Arcade audio did not visibly disable its profile controls or overwrote Follow"
    )
    games:SetOption("graphicsTheme", "class")
    ui.appearancePanel.switch.scripts.OnClick()
    check(
        not settings.followCharacter and ui.classDropdown:IsEnabled() and settings.manualSpecID == 64,
        "Re-enabling Class Spells failed to restore the remembered manual profile"
    )
    games:SetOption("soundTheme", "class")
    games:SetManualSpec(63)
    check(not ui.specDropdown.buttons[90001], "Spec dropdown retained another class's options")
    ui.classDropdown.scripts.OnClick()
    games:SetOption("followCharacter", true)
    ui.classDropdown.scripts.OnClick()
    ui.specDropdown.scripts.OnClick()
    check(
        not ui.classDropdown.popup:IsShown()
            and not ui.specDropdown.popup:IsShown()
            and not ui.classDropdown:IsEnabled()
            and not ui.specDropdown:IsEnabled(),
        "Follow mode failed to close and disable the profile dropdowns"
    )
    owner.env.playerSpec = 64
    owner:event("PLAYER_SPECIALIZATION_CHANGED", "player")
    check(
        games:GetClassPreset() == "MAGE"
            and select(2, games:GetSelectedProfile()) == 64
            and settings.manualSpecID == 63
            and not ui.classDropdown.buttons.MAGE:IsEnabled()
            and not ui.specDropdown.rows[1]:IsEnabled(),
        "Follow character overwrote manual choice or failed to lock selectors"
    )
    check(
        not games:SetManualSpec(62) and not games:SetManualClass("WARRIOR"),
        "Manual profile changed while following the character"
    )
    owner.env.playerClass = "DEMONHUNTER"
    owner.env.playerSpec = 1480
    owner:event("PLAYER_SPECIALIZATION_CHANGED", "party1")
    owner:event("PLAYER_SPECIALIZATION_CHANGED", "player")
    check(
        games:GetClassPreset() == "DEMONHUNTER" and select(2, games:GetSelectedProfile()) == 1480,
        "Character class/spec detection did not follow the active profile"
    )
    games:SetOption("followCharacter", false)
    check(
        games:GetClassPreset() == "MAGE"
            and select(2, games:GetSelectedProfile()) == 63
            and ui.classDropdown.buttons.MAGE:IsEnabled(),
        "Disabling follow did not restore manual profile"
    )
    -- Both engines retain their actual model, board, score and queue when themes change.
    for _, id in ipairs({ "tetris", "bejeweled" }) do
        games:StartSingleplayer(id)
        local module = id == "tetris" and games.Tetris or games.Bejeweled
        local model, board, queue = module.model, module.model.board, module.model.queue
        local score = model.score
        games:SetOption("graphicsTheme", "original")
        local original = games:GetPieceIcons(id)
        check(
            type(original[1]) == "string" and original[1]:find("Pieces/", 1, true),
            "Original graphics still use spell icons"
        )
        check(
            module.model == model and model.board == board and model.queue == queue and model.score == score,
            "Original graphics reset an active game"
        )
        if id == "tetris" then
            module:Paint(module.cells[1], "T")
            check(
                module.cells[1].icon.vertexColor[1] == games.IconPresets.Colors.T[1],
                "Classic Tetris block did not receive piece color"
            )
            module.model:Hold()
            module:Render(true)
            for _, cells in ipairs(module.nextCells) do
                for _, cell in ipairs(cells) do
                    if cell.icon:IsShown() then
                        check(cell.icon.textureValue == original[1], "NEXT used spell icons in Original mode")
                    end
                end
            end
            local held = 0
            for _, cell in ipairs(module.holdCells) do
                if cell.icon:IsShown() then
                    held = held + 1
                    check(cell.icon.textureValue == original[1], "HOLD lost original graphics")
                end
            end
            check(held == 4, "HOLD preview lost tetromino geometry")
        else
            check(
                module.cells[1].icon.textureValue == original[model.board[1][1]] and #original == 7,
                "Bejeweled did not render seven original gems"
            )
        end
        games:SetClassPreset("MAGE")
        games:SetManualSpec(62)
        games:SetOption("graphicsTheme", "class")
        check(
            module.model == model and model.board == board and model.queue == queue and model.score == score,
            "Class/spec graphics reset active game state"
        )
        games:SetOption("soundTheme", "class")
        check(module.model == model and module.model.score == score, "Audio preferences changed gameplay")
        for _, scale in ipairs({ 0.75, 1, 1.2, 1.5 }) do
            ui:SetWindowScale(scale)
            check(
                ui.frame:GetScale() == scale
                    and ui.optionsFrame:GetEffectiveScale() == scale
                    and module.root:GetEffectiveScale() == scale
                    and module.summary:GetEffectiveScale() == scale,
                "Interface scale did not consistently reach all UI surfaces"
            )
            check(
                module.model == model and model.board == board and module.board.width > 0,
                "Scale changed the board model"
            )
            if id == "tetris" then
                check((module.board.width - 24) * 2 == module.board.height - 24, "Scaling distorted Tetris proportions")
            else
                check(module.cells[1].width == module.cells[1].height, "Scaling distorted Bejeweled cells")
            end
        end
        games:AbortGame()
    end
    games:StartSingleplayer("tetris")
    games:SetOption("graphicsTheme", "original")
    games.Tetris.model.score = 1024
    games.Tetris:SaveBest()
    games:SetOption("graphicsTheme", "class")
    games.Tetris:ShareBest()
    check(
        owner.env.chatDraft:find("Original blocks", 1, true) and games.DB.tetris.best.graphicsTheme == "original",
        "Original-mode best was incorrectly shared as class spell icons"
    )
    games:AbortGame()
    -- Follow must survive starting a game; starting Tetris must not invoke a manual picker.
    games:SetOption("followCharacter", true)
    games:StartSingleplayer("tetris")
    check(
        settings.followCharacter and games:GetClassPreset() == "DEMONHUNTER",
        "Starting a game disabled Follow My Character"
    )
    games:AbortGame()
    games:SetOption("followCharacter", false)
    games:SetClassPreset("MAGE")
    games:SetManualSpec(62)
    games:SetOption("graphicsTheme", "original")
    games:SetOption("soundTheme", "class")
    local arcane = games.Audio:Resolve("bejeweled", "select")
    check(
        arcane.file and type(games:GetPieceIcons("bejeweled")[1]) == "string",
        "Class audio was incorrectly coupled to class graphics"
    )
    games:SetManualSpec(63)
    local fire = games.Audio:Resolve("bejeweled", "select")
    games:SetManualSpec(64)
    local frost = games.Audio:Resolve("bejeweled", "select")
    check(
        arcane.file ~= fire.file and fire.file ~= frost.file and not games.Audio:VolumeSupported(frost),
        "Mage sound schools are identical, or unsupported file volume is claimed"
    )
    games:SetClassPreset("WARLOCK")
    games:SetManualSpec(265)
    check(
        ui.volumePanel.detail.text:find("Spell effects", 1, true),
        "Partial spell profiles incorrectly claimed independent volume for all effects"
    )
    games:SetClassPreset("MAGE")
    games:SetManualSpec(62)
    games:SetOption("soundTheme", "arcade")
    games:SetOption("soundVolume", 0.25)
    check(
        games.Audio:Play("bejeweled", "clear", true) and owner.sounds[#owner.sounds].volume == 0.25,
        "SoundKit playback did not receive independent volume"
    )
    local played = #owner.sounds
    ui.soundEnabledPanel.switch.scripts.OnClick()
    check(
        not games.Audio:Play("bejeweled", "clear", true) and #owner.sounds == played and #games.Audio.handles == 0,
        "Disabling sounds did not immediately stop/gate addon audio"
    )
    check(
        ui.soundEnabledPanel.switch.text == "ON"
            and ui.soundEnabledPanel.switch.selected
            and not ui.volumeSlider:IsEnabled()
            and ui.volumePanel.alpha < 1,
        "Mute ON did not disable and dim the volume controls"
    )
    for _, button in pairs(ui.soundPreviewButtons) do
        check(not button:IsEnabled(), "Mute ON left a sound preview enabled")
    end
    ui.volumeSlider.scripts.OnValueChanged(ui.volumeSlider, 75)
    check(settings.soundVolume == 0.25, "Muted volume control changed the saved level")
    ui.soundEnabledPanel.switch.scripts.OnClick()
    check(
        ui.soundEnabledPanel.switch.text == "OFF"
            and not ui.soundEnabledPanel.switch.selected
            and ui.volumeSlider:IsEnabled()
            and ui.volumePanel.alpha == 1
            and ui.volumeSlider.current == 25,
        "Mute OFF failed to restore the enabled controls and remembered volume"
    )
    for _, button in pairs(ui.soundPreviewButtons) do
        check(button:IsEnabled(), "Mute OFF did not restore a sound preview")
    end
    games:SetOption("soundVolume", 0)
    check(not games.Audio:Play("bejeweled", "clear", true) and #owner.sounds == played, "Volume zero was not silent")
    check(ui.volumeSlider:IsEnabled(), "Zero volume locked the slider and prevented raising volume again")
    games:SetOption("soundVolume", 0.6)
    ui:ShowOptions()
    ui:SelectOptionsTab("audio")
    ui.soundPreviewButtons.clear.scripts.OnClick()
    check(
        #owner.sounds == played + 1 and owner.sounds[#owner.sounds].kit == 10590,
        "Audio preview is decorative instead of real playback"
    )
    now = now + 0.25
    check(
        games.Audio:Play("tetris", "move") and not games.Audio:Play("tetris", "move"),
        "Rapid movement sound throttling failed"
    )
    check(games.Audio:Play("tetris", "gameOver"), "Game-over sound was blocked by movement throttling")
    games:SetOption("soundTheme", "class")
    games:SetManualSpec(62)
    local entry = games.Audio:Resolve("bejeweled", "clear")
    owner.env.rejectSound = entry.file
    check(
        games.Audio:Play("bejeweled", "clear", true) and owner.sounds[#owner.sounds].kit == 10590,
        "Unavailable spell file did not fall back to a verified kit"
    )
    owner.env.rejectSound = nil
    -- Window contains one scale slider and its optional 100% reset, no size controls.
    ui:SelectOptionsTab("window")
    local sliders, buttons = 0, 0
    for _, frame in ipairs(owner.frames) do
        if frame.parent == ui.windowPanel and frame.kind == "Slider" then
            sliders = sliders + 1
        end
        if frame.parent == ui.windowPanel and frame.kind == "Button" then
            buttons = buttons + 1
        end
    end
    check(
        sliders == 1 and buttons == 1 and not ui.resizeGrip and not ui.scaleUp and not ui.scaleDown,
        "Window page contains extra size controls"
    )
    ui.scaleSlider:SetValue(120)
    check(
        settings.windowScale == 1.2 and ui.scaleSlider.valueLabel.text == "120%",
        "Interface slider failed to apply/save"
    )
    for _ = 1, 6 do
        ui:SetWindowScale(0.75)
        ui:SetWindowScale(1.5)
        ui.resetScale.scripts.OnClick()
    end
    check(ui.frame:GetScale() == 1 and settings.windowScale == 1, "Repeated scaling accumulated transform errors")
    owner.env.UIParent:SetScale(0.8)
    owner.env.UIParent:SetSize(2400, 1350)
    ui:SetWindowScale(1.5)
    check(
        math.abs(ui.frame:GetEffectiveScale() - 1.2) < 0.000001
            and math.abs(ui.optionsFrame:GetEffectiveScale() - ui.frame:GetEffectiveScale()) < 0.000001
            and math.abs(games.Tetris.summary:GetEffectiveScale() - ui.frame:GetEffectiveScale()) < 0.000001
            and settings.windowScale == 1.5,
        "UIParent effective scale was applied twice or lost"
    )
    owner.env.UIParent:SetScale(1)
    owner.env.UIParent:SetSize(1280, 720)
    ui:SetWindowScale(1.5)
    check(
        ui.frame.width * ui.frame:GetScale() <= 1260
            and ui.frame.height * ui.frame:GetScale() <= 700
            and settings.windowScale == 1.5
            and ui.scaleNote.text:find("Screen fit", 1, true),
        "Screen fitting clipped the window or silently lost the requested scale"
    )
    games:SetOption("soundsEnabled", false)
    local saved = games.Copy(games.DB)
    local reload = client("OptionsReload", "OptionsRealm", saved)
    local r = reload.games:GetSettings()
    check(
        r.graphicsTheme == settings.graphicsTheme
            and r.manualClass == settings.manualClass
            and r.followCharacter == settings.followCharacter
            and r.manualSpecID == settings.manualSpecID
            and r.soundTheme == settings.soundTheme
            and r.soundVolume == settings.soundVolume
            and r.soundsEnabled == settings.soundsEnabled
            and r.windowScale == settings.windowScale
            and reload.games.DB.tetris.best.score >= 321
            and reload.games.DB.bejeweled.best.score >= 654,
        "Reload lost Options 2.0 preferences or saved scores"
    )
    games:SetOption("soundsEnabled", true)
    owner.env.UIParent:SetSize(1920, 1080)
    ui:SetWindowSize(1000, 700)
    for _, scale in ipairs({ 0.75, 1, 1.2, 1.5 }) do
        ui:SetWindowScale(scale)
        for _, tab in ipairs({ "graphics", "audio", "window" }) do
            ui:SelectOptionsTab(tab)
            check(
                ui.optionsScroll.width <= ui.content.width
                    and -ui.optionsScroll.points[1][3] + ui.optionsScroll.height <= ui.content.height,
                "Options scroll viewport exceeds content bounds"
            )
            for _, button in pairs(ui.optionTabs) do
                check(
                    button.points[1][2] + button.width <= ui.content.width,
                    "An Options tab extends beyond the content region"
                )
            end
            ui.optionsScroll.scrollBar:SetValue(10000)
            check(
                ui.optionsContent.height <= ui.optionsScroll.height
                    and not ui.optionsScroll.scrollBar:IsShown()
                    and ui.optionsScroll:GetVerticalScroll() == 0,
                "An Options page does not fit without scrolling at the minimum canvas size"
            )
            check(
                ui.optionsScroll:GetVerticalScroll() <= math.max(0, ui.optionsContent.height - ui.optionsScroll.height),
                "Options content cannot be reached through its clipped scrollbar"
            )
        end
    end
    ui:ResetWindowSize()
    -- A client's legacy playback must be reported honestly, with mute still functional.
    local modern = owner.env.C_Sound
    owner.env.C_Sound = nil
    owner.env.PlaySound = function(kit, channel)
        owner.sounds[#owner.sounds + 1] = { kit = kit, channel = channel }
        return true, #owner.sounds
    end
    games:SetOption("soundTheme", "arcade")
    check(
        not games.Audio:VolumeSupported(games.Audio:Resolve("tetris", "move"))
            and games.Audio:Play("tetris", "move", true),
        "Legacy sound playback claimed unsupported volume"
    )
    owner.env.C_Sound = modern
    -- Check actual gameplay event bridges without replacing the engine rules.
    games:SetOption("soundTheme", "arcade")
    local log = {}
    local play = games.Audio.Play
    local contexts = {}
    games.Audio.Play = function(audio, game, event, preview, cascade, arcadeFallback)
        log[#log + 1] = game .. ":" .. event
        contexts[#contexts + 1] = { event = event, cascade = cascade }
        return play(audio, game, event, preview, cascade, arcadeFallback)
    end
    local function heard(event)
        for _, value in ipairs(log) do
            if value == event then
                return true
            end
        end
    end
    games:StartSingleplayer("tetris")
    local t = games.Tetris
    t.model:Move(-1, 0)
    t.model:Hold()
    t.model:HardDrop()
    check(
        heard("tetris:move") and heard("tetris:select") and heard("tetris:land"),
        "Tetris movement/hold/landing sound events are disconnected"
    )
    for count = 0, 4 do
        t.model.board = {}
        for y = 1, 22 do
            t.model.board[y] = {}
        end
        for y = 23 - count, 22 do
            for x = 1, 10 do
                if x ~= 3 then
                    t.model.board[y][x] = "O"
                end
            end
        end
        local before, lines = #log, t.model.lines
        t.model.kind, t.model.rotation, t.model.x, t.model.y = "I", 1, 1, 19
        now = now + 0.2
        t.model:Lock()
        local event = count == 0 and "land" or "tetris_" .. count .. (count == 1 and "_line" or "_lines")
        check(
            #log == before + 1 and log[#log] == "tetris:" .. event and t.model.lines - lines == count,
            "Tetris 0/1/2/3/4-line dispatch changed the actual lock operation"
        )
    end
    t.model.gameover = true
    local silent = #log
    t.model:Lock()
    check(#log == silent, "Already-ended Tetris lock emitted a landing/clear sound")
    t:Advance(0)
    check(heard("tetris:gameOver"), "Tetris game-over sound is disconnected")
    games:AbortGame()
    games:StartSingleplayer("bejeweled")
    local b = games.Bejeweled
    b:Click(1, 1, "LeftButton")
    for y = 1, 8 do
        for x = 1, 8 do
            b.model.board[y][x] = (x + 2 * y) % 7 + 1
        end
    end
    b.model.board[1][1], b.model.board[1][2], b.model.board[1][3], b.model.board[2][2] = 1, 2, 1, 1
    b:TrySwap(2, 1, 2, 2, true)
    for _ = 1, 7 do
        b:Advance(0.1)
    end
    check(
        heard("bejeweled:select") and heard("bejeweled:swap") and heard("bejeweled:bejeweled_match_3"),
        "Bejeweled selection/swap/match sounds are disconnected"
    )
    b.swap, b.fall, b.phaseTime = nil, nil, 0
    b.model.board[1][1], b.model.board[1][2], b.model.board[1][3] = 1, 1, 1
    b.model.gameover = false
    b.model.pending = b.model:Matches()
    b.model.phase = "clearing"
    b.model.cascade = 2
    local event, before = b:MatchSoundEvent(), #log
    for _ = 1, 3 do
        b:Advance(0.1)
    end
    check(
        #log == before + 1 and log[#log] == "bejeweled:" .. event and contexts[#contexts].cascade == 2,
        "Cascade lost its independently measured match tier or emitted duplicate sounds"
    )
    local function matchRound(runs, expected, cascade)
        b.swap, b.fall, b.phaseTime, b.paused = nil, nil, 0, false
        b.model.board = {}
        for y = 1, 8 do
            b.model.board[y] = {}
        end
        for _, run in ipairs(runs) do
            for i = 0, run[3] - 1 do
                local x, y = run[1] + (run[4] and 0 or i), run[2] + (run[4] and i or 0)
                b.model.board[y][x] = run[5] or 7
            end
        end
        b.model.gameover, b.model.cascade, b.model.phase = false, cascade or 1, "clearing"
        b.model.pending = b.model:Matches()
        local count, score, calls = #b.model.pending, b.model.score, #log
        check(b:MatchSoundEvent() == expected, "Match strength used total cleared cells or the wrong axis")
        now = now + 0.2
        for _ = 1, 3 do
            b:Advance(0.1)
        end
        check(
            #log == calls + 1
                and log[#log] == "bejeweled:" .. expected
                and contexts[#contexts].cascade == (cascade or 1),
            "Match resolution emitted duplicate/incorrect audio"
        )
        check(b.model.score - score == count * 50 * (cascade or 1), "Sound classification changed match scoring")
    end
    for _, vertical in ipairs({ false, true }) do
        for count = 3, 8 do
            local expected = count >= 5 and "bejeweled_match_5_plus" or "bejeweled_match_" .. count
            matchRound({ { 1, 1, count, vertical } }, expected)
        end
    end
    matchRound({ { 1, 1, 3 }, { 5, 5, 3 } }, "bejeweled_match_3")
    matchRound({ { 1, 1, 3 }, { 2, 1, 3, true } }, "bejeweled_match_3", 3)
    matchRound({ { 1, 1, 3 }, { 4, 5, 4 } }, "bejeweled_match_4")
    b.model.gameover = true
    b.model.phase = "over"
    b:Advance(0)
    check(heard("bejeweled:gameOver"), "Bejeweled game-over sound is disconnected")
    games:AbortGame()
    games.Audio.Play = play
    local previewEvents = "select,move,swap,land,clear,combo,gameOver,victory"
    games.Audio:RegisterGame("tetris", games.Audio.games.tetris)
    local buttons = 0
    for _ in pairs(ui.soundPreviewButtons) do
        buttons = buttons + 1
    end
    check(
        table.concat(games.Audio.events, ",") == previewEvents and buttons == 8,
        "Internal audio events leaked into the finished Options preview UI"
    )
    for sid, profile in pairs(games.ProfileData) do
        games:SetClassPreset(profile.class)
        games:SetManualSpec(sid)
        games:SetOption("soundTheme", "class")
        for key, game in pairs(games.Audio.internalEvents) do
            local resolved, usedFallback = games.Audio:Resolve(game, key)
            local expected = profile.soundEvents[key]
            local legacy = (key == "tetris_1_line" or key == "bejeweled_match_3") and games.Audio.specs[sid]
            legacy = legacy and legacy.clear
            check(resolved and (resolved.file or resolved.kit), "A specialization/event has no safe sound")
            if expected then
                check(
                    resolved.file == expected and not usedFallback,
                    "Spec/event FileDataID was confused with a kit/spell ID"
                )
            elseif legacy then
                check(resolved.file == legacy.file, "Existing valid low-tier effect was lost")
            else
                check(resolved.kit and usedFallback, "Missing spec tier did not use the arcade fallback")
            end
            games:SetOption("soundTheme", "arcade")
            resolved, usedFallback = games.Audio:Resolve(game, key)
            check(resolved.kit and usedFallback, "Original Audio used a specialization file")
            games:SetOption("soundTheme", "class")
        end
    end
    games:SetClassPreset("MAGE")
    games:SetManualSpec(63)
    games:SetOption("soundTheme", "class")
    games:SetOption("soundVolume", 0.25)
    games:SetOption("soundsEnabled", true)
    local cascadeSound = games.Audio:Resolve("bejeweled", "bejeweled_match_3", 2)
    local five = games.Audio:Resolve("bejeweled", "bejeweled_match_5_plus", 2)
    check(
        cascadeSound.file == 1392377 and five.file == 1390656,
        "Cascade enhancement downgraded an iconic 5+ effect or ignored its own profile"
    )
    for _, test in ipairs({ { "tetris", "tetris_4_lines", 1 }, { "bejeweled", "bejeweled_match_3", 2 } }) do
        local sound = games.Audio:Resolve(test[1], test[2], test[3])
        owner.env.rejectSound = sound.file
        check(
            games.Audio:Play(test[1], test[2], true, test[3])
                and owner.sounds[#owner.sounds].kit == 73279
                and owner.sounds[#owner.sounds].volume == 0.25,
            "New resolution file/cascade failure did not fall back safely with saved volume"
        )
        owner.env.rejectSound = nil
    end
    local filePlayer = owner.env.PlaySoundFile
    owner.env.PlaySoundFile = nil
    local kit, missingFileAPI = games.Audio:Resolve("tetris", "tetris_4_lines")
    check(kit.kit == 73279 and missingFileAPI, "Missing file API did not select an arcade kit")
    owner.env.PlaySoundFile = filePlayer
    games:SetOption("soundTheme", "arcade")
    now = now + 0.2
    games.Audio:Play("tetris", "move")
    check(
        games.Audio:Play("tetris", "tetris_1_line") and not games.Audio:Play("tetris", "tetris_2_lines"),
        "Clear audio was lost behind movement or rapid tiers bypassed the shared cooldown"
    )
    now = now + 0.11
    check(
        games.Audio:Play("tetris", "tetris_4_lines") and #games.Audio.handles == 1,
        "Resolution effects stacked instead of replacing previous effects"
    )
    local count = #owner.sounds
    games:SetOption("soundVolume", 0)
    check(
        not games.Audio:Play("tetris", "tetris_4_lines", true) and #owner.sounds == count,
        "Zero volume failed to mute an internal event"
    )
    games:SetOption("soundVolume", 0.6)
    games:SetOption("soundTheme", "class")
    games:SetOption("soundsEnabled", false)
    check(
        not games.Audio:Play("bejeweled", "bejeweled_match_5_plus", true)
            and #owner.sounds == count
            and #games.Audio.handles == 0,
        "Disabled class audio still played an internal event"
    )
end
-- Master backend contract: verify API arguments, never simulate the native mix equation.
do
    local owner = client("MasterAudio", "AudioRealm")
    owner.grouped = false
    local games, env = owner.games, owner.env
    local audio = games.Audio
    local mix = { master = 1, sfxEnabled = true }
    local reads = 0
    env.GetCVar = function()
        reads = reads + 1
        return "1"
    end
    env.SetCVar = function()
        error("Audio backend must not write WoW CVars")
    end
    env.C_CVar = { SetCVar = env.SetCVar, GetCVar = env.GetCVar }
    games:SetOption("soundTheme", "arcade")
    for _, sfx in ipairs({ false, true }) do
        mix.sfxEnabled = sfx
        for _, master in ipairs({ 0, 0.25, 0.5, 1 }) do
            mix.master = master
            for _, volume in ipairs({ 0, 0.25, 0.5, 1 }) do
                games.UI.volumeSlider:SetValue(volume * 100)
                local before = #owner.sounds
                local played = audio:Play("tetris", "clear", true)
                if volume == 0 then
                    check(
                        not played and #owner.sounds == before and #audio.handles == 0,
                        "Zero slider volume did not stop/gate Master previews"
                    )
                else
                    local sound = owner.sounds[#owner.sounds]
                    check(
                        played
                            and #owner.sounds == before + 1
                            and sound.channel == "Master"
                            and sound.kit == 865
                            and sound.volume == volume
                            and sound.method == "PlaySound",
                        "Master kit playback lost slider gain, explicit channel or preferred API"
                    )
                end
                check(
                    mix.master == master and mix.sfxEnabled == sfx and reads == 0,
                    "Backend used global audio settings to calculate/change addon gain"
                )
            end
        end
    end
    -- The structured alternative must also specify Master explicitly.
    local modern, preferred = env.C_Sound, env.C_Sound.PlaySound
    env.C_Sound.PlaySound = nil
    games.UI.volumeSlider:SetValue(50)
    check(
        audio:Play("bejeweled", "clear", true)
            and owner.sounds[#owner.sounds].method == "PlaySoundWithOptions"
            and owner.sounds[#owner.sounds].channel == "Master"
            and owner.sounds[#owner.sounds].volume == 0.5,
        "Structured SoundKit fallback omitted Master or slider gain"
    )
    modern.PlaySound = preferred
    for file, kit in pairs(audio.fileKits) do
        audio.games.tetris.masterProbe = { file = file }
        check(
            audio:Play("tetris", "masterProbe", true)
                and owner.sounds[#owner.sounds].kit == kit
                and owner.sounds[#owner.sounds].channel == "Master"
                and owner.sounds[#owner.sounds].volume == 0.5
                and audio:VolumeSupported(audio:Resolve("tetris", "masterProbe")),
            "Verified single-file SoundKit did not receive Master/independent gain"
        )
    end
    audio.games.tetris.masterProbe = { file = 568008 }
    env.rejectKit = 22468
    check(
        audio:Play("tetris", "masterProbe", true)
            and owner.sounds[#owner.sounds].file == 568008
            and owner.sounds[#owner.sounds].channel == "Master"
            and not owner.sounds[#owner.sounds].kit,
        "A failed mapped kit did not preserve the original Master spell file"
    )
    env.rejectKit = nil
    local fileAPI = env.PlaySoundFile
    env.PlaySoundFile = nil
    check(
        audio:Play("tetris", "masterProbe", true) and owner.sounds[#owner.sounds].kit == 22468,
        "Verified mapped kit incorrectly required the file playback API"
    )
    env.PlaySoundFile = fileAPI
    env.C_Sound = nil
    env.PlaySound = function(kit, channel)
        owner.sounds[#owner.sounds + 1] = { kit = kit, channel = channel }
        return true, #owner.sounds
    end
    check(
        audio:Play("tetris", "clear", true)
            and owner.sounds[#owner.sounds].channel == "Master"
            and not audio:VolumeSupported(audio:Resolve("tetris", "clear")),
        "Legacy kit fallback incorrectly claimed volume control or used a different channel"
    )
    check(
        audio:Play("tetris", "masterProbe", true)
            and owner.sounds[#owner.sounds].file == 568008
            and not audio:VolumeSupported(audio:Resolve("tetris", "masterProbe")),
        "Mapped files without modern kit support lost their original-file fallback"
    )
    audio.games.tetris.masterProbe = nil
    env.C_Sound = modern
    env.apiInterface = 120000
    check(
        audio:Play("tetris", "clear", true)
            and owner.sounds[#owner.sounds].channel == "Master"
            and owner.sounds[#owner.sounds].volume == nil
            and not audio:VolumeSupported(audio:Resolve("tetris", "clear")),
        "Pre-volumeOverride client incorrectly advertised independent gain or lost Master fallback"
    )
    env.apiInterface = 120105
    games:SetClassPreset("MAGE")
    games:SetManualSpec(63)
    games:SetOption("soundTheme", "class")
    for _, volume in ipairs({ 0, 0.25, 0.5, 1 }) do
        games.UI.volumeSlider:SetValue(volume * 100)
        local before = #owner.sounds
        local played = audio:Play("tetris", "tetris_4_lines", true)
        if volume == 0 then
            check(not played and #owner.sounds == before, "Zero volume played a Master spell file")
        else
            local sound = owner.sounds[#owner.sounds]
            check(
                played
                    and sound.file == 1390656
                    and not sound.kit
                    and sound.channel == "Master"
                    and sound.volume == nil
                    and not audio:VolumeSupported(audio:Resolve("tetris", "tetris_4_lines")),
                "FileDataID became a SoundKitID or unsupported independent file gain was claimed"
            )
        end
    end
    owner.env.rejectSound = 1390656
    check(
        audio:Play("tetris", "tetris_4_lines", true)
            and owner.sounds[#owner.sounds].kit == 73279
            and owner.sounds[#owner.sounds].channel == "Master"
            and owner.sounds[#owner.sounds].volume == 1,
        "Failed Master file did not retain the verified kit/volume fallback"
    )
    owner.env.rejectSound = nil
    local count = #owner.sounds
    games:SetOption("soundsEnabled", false)
    check(
        not audio:Play("tetris", "tetris_4_lines", true) and #owner.sounds == count and #audio.handles == 0,
        "Mute failed to stop/gate Master spell previews"
    )
    games:SetOption("soundTheme", "arcade")
    check(
        not audio:Play("bejeweled", "clear", true) and #owner.sounds == count,
        "Mute failed to gate Master kit previews"
    )
end
assert(loadfile("tests/audit_regressions.lua"))()(client, check)
print(string.format("PASS: %d assertions; real AceComm/ChatThrottleLib, isolated clients, UI smoke checks.", tests))

-- Optional layout snapshots from the actual UI constructors, for offline visual review.
if arg[1] == "--preview" then
    local function json(value)
        if type(value) == "string" then
            return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r") .. '"'
        elseif type(value) == "number" or type(value) == "boolean" then
            return tostring(value)
        elseif type(value) == "table" then
            local out = {}
            for i, item in ipairs(value) do
                out[i] = json(item)
            end
            return "[" .. table.concat(out, ",") .. "]"
        end
        return "null"
    end
    local function snapshot(name, owner)
        local previewFrames = (owner or t).frames
        local ids, rows = {}, {}
        for i, frame in ipairs(previewFrames) do
            ids[frame] = i
        end
        for i, frame in ipairs(previewFrames) do
            local fields = { '"id":' .. i }
            for _, key in ipairs({
                "width",
                "height",
                "fontSize",
                "text",
                "background",
                "border",
                "color",
                "textColor",
                "textureValue",
                "strata",
                "frameLevel",
                "kind",
                "alpha",
                "justify",
                "texCoord",
                "scale",
                "vertexColor",
                "verticalScroll",
                "clipsChildren",
                "drawLayer",
                "subLevel",
                "component",
            }) do
                if frame[key] ~= nil then
                    fields[#fields + 1] = json(key) .. ":" .. json(frame[key])
                end
            end
            fields[#fields + 1] = '"visible":' .. json(frame:IsVisible())
            fields[#fields + 1] = '"backdropFill":'
                .. json(frame.backdropInfo ~= nil and frame.backdropInfo.bgFile ~= nil)
            fields[#fields + 1] = '"parent":' .. json(ids[frame.parent])
            fields[#fields + 1] = '"allPoints":' .. json(ids[frame.allPoints])
            fields[#fields + 1] = '"scrollChild":' .. json(ids[frame.scrollChild])
            local points = {}
            for p, point in ipairs(frame.points or {}) do
                local copy = {}
                for j, value in ipairs(point) do
                    copy[j] = type(value) == "table" and ids[value] or value
                end
                points[p] = copy
            end
            fields[#fields + 1] = '"points":' .. json(points)
            rows[#rows + 1] = "{" .. table.concat(fields, ",") .. "}"
        end
        local file = assert(io.open(arg[2] .. "/" .. name .. ".json", "w"))
        file:write("[" .. table.concat(rows, ",") .. "]")
        file:close()
    end
    local preview = client("PreviewGames", "PreviewRealm")
    preview.grouped = false
    local pg = preview.games
    for _, id in ipairs({ "bejeweled", "tetris" }) do
        pg:StartSingleplayer(id)
        local module = id == "tetris" and pg.Tetris or pg.Bejeweled
        if id == "tetris" then
            module.model:Hold()
            module.model:HardDrop()
        end
        for _, layout in ipairs({
            { "default", 1120, 700, 1 },
            { "120", 1120, 700, 1.2 },
            { "compact", 1000, 700, 1 },
            { "wide", 1500, 900, 1 },
            { "tall", 1000, 1000, 1 },
        }) do
            pg.UI:SetWindowSize(layout[2], layout[3])
            pg.UI:SetWindowScale(layout[4])
            module:Render(true)
            snapshot(id .. "-" .. layout[1], preview)
        end
        module:Pause(true)
        snapshot(id .. "-pause", preview)
        pg:AbortGame()
    end
    local optionPreview = client("OptionsPreview", "PreviewRealm")
    optionPreview.grouped = false
    local op = optionPreview.games
    op:SetClassPreset("MAGE")
    op:SetManualSpec(62)
    op:SetOption("followCharacter", true)
    op.UI:ShowOptions()
    for _, tab in ipairs({ "graphics", "audio", "window" }) do
        op.UI:SelectOptionsTab(tab)
        for _, scale in ipairs({ 0.75, 1, 1.2, 1.5 }) do
            op.UI:SetWindowScale(scale)
            snapshot("options2-" .. tab .. "-" .. math.floor(scale * 100 + 0.5), optionPreview)
        end
    end
    op.UI:SetWindowScale(1)
    op:SetOption("followCharacter", false)
    op.UI:SelectOptionsTab("graphics")
    op.UI.optionsScroll.scrollBar:SetValue(208)
    snapshot("options2-selectors", optionPreview)
    op.UI.classDropdown.scripts.OnClick()
    snapshot("options2-class-dropdown", optionPreview)
    op.UI.specDropdown.scripts.OnClick()
    snapshot("options2-spec-dropdown", optionPreview)
    op.UI:CloseProfileDropdowns()
    op.UI.optionsScroll.scrollBar:SetValue(10000)
    snapshot("options2-class-preview", optionPreview)
    op:SetOption("followCharacter", true)
    op:SetOption("graphicsTheme", "original")
    snapshot("options2-original-gems", optionPreview)
    op.UI.previewGame = "tetris"
    op.UI:RefreshOptions()
    snapshot("options2-original-blocks", optionPreview)
    op:SetOption("soundTheme", "class")
    op.UI:SelectOptionsTab("audio")
    op.UI.optionsScroll.scrollBar:SetValue(208)
    snapshot("options2-spell-audio", optionPreview)
    op.UI:SetWindowSize(1000, 700)
    snapshot("options2-compact-audio", optionPreview)
    op:SetOption("soundTheme", "arcade")
    snapshot("options2-arcade-audio", optionPreview)
    G.UI:SelectTab("singleplayer")
    G:StartSingleplayer("tetris")
    T:SelectPreset("DRUID")
    for _ = 1, 3 do
        T.model:HardDrop()
    end
    T:Advance(0)
    snapshot("tetris")
    G.UI:ShowResults()
    T:Advance(0)
    snapshot("history")
    G.UI:ShowGame()
    T.model.gameover = true
    T:Advance(0)
    snapshot("game-over")
    Q.UI:SelectTab("singleplayer")
    Q:SetClassPreset("MAGE")
    Q:StartSingleplayer("bejeweled")
    Bj:Click(3, 3, "LeftButton")
    snapshot("bejeweled", jewel)
    jewelBoard(false)
    Bj.model.score, Bj.model.moves, Bj.model.cleared, Bj.model.bestCascade = 3200, 12, 50, 3
    Bj.model:CheckEnd()
    Bj:Advance(0)
    snapshot("bejeweled-results", jewel)
    S.UI:SetWindowScale(1)
    S.UI.frame:ClearAllPoints()
    S.UI.frame:SetPoint("CENTER")
    S.UI.frame:Show()
    S.UI:ShowOptions()
    snapshot("options", sharedClient)
    dragRound()
    DragGames.UI:SetWindowScale(1)
    dragFrom(2, 1)
    dragBy(0, -Drag.tileSize * 0.5)
    snapshot("bejeweled-drag", dragClient)
    Arcade.UI:SetWindowScale(1)
    Arcade.UI:OpenLauncher("home")
    Arcade.Registry.external_arcade = nil
    Arcade.UI:FeatureGame("bejeweled")
    snapshot("launcher", launcherClient)
    Arcade.UI:SetWindowScale(1.2)
    snapshot("launcher-120", launcherClient)
    Arcade.UI:FeatureGame("tetris")
    snapshot("launcher-tetris-120", launcherClient)
    Arcade.UI:SetWindowScale(1)
    snapshot("launcher-tetris", launcherClient)
    for _, page in ipairs({ "singleplayer", "multiplayer", "options", "results" }) do
        Arcade.UI:OpenLauncher(page)
        snapshot("page-" .. page, launcherClient)
    end
    Arcade.UI:OpenLauncher("options")
    Arcade.UI.optionsScroll:SetVerticalScroll(300)
    snapshot("page-options-scrolled", launcherClient)
    Arcade.UI:SetWindowScale(1.2)
    snapshot("page-options-120", launcherClient)
    Arcade.UI:SetWindowScale(1)
    for i = 1, 24 do
        Arcade:RegisterGame({
            id = "preview_" .. i,
            title = string.format("Arcade %02d", i),
            mode = "singleplayer",
            version = "1",
            CreateUI = function(_, parent)
                return launcherClient.env.CreateFrame("Frame", nil, parent)
            end,
            OnStart = function() end,
        })
    end
    Arcade.UI:OpenLauncher("singleplayer")
    snapshot("page-library-26", launcherClient)
    Arcade.UI.cardScroll:SetVerticalScroll(360)
    snapshot("page-library-scrolled", launcherClient)
    Arcade.UI:SetWindowSize(1000, 700)
    snapshot("page-library-narrow", launcherClient)
    Arcade.UI:SetWindowSize(1500, 850)
    snapshot("page-library-wide", launcherClient)
end
