-- Runs through framework.lua's isolated WoW clients, also via --audit.
return function(client, check)
    local failures = {}
    local function scenario(name, callback)
        local ok, err = pcall(callback)
        if not ok then
            failures[#failures + 1] = name .. ": " .. tostring(err)
        end
    end
    local function fixture(owner, id, hooks)
        local game = {
            id = id,
            title = id,
            version = "1",
            mode = "singleplayer",
            CreateUI = function(_, parent)
                return owner.env.CreateFrame("Frame", nil, parent)
            end,
            OnStart = function() end,
        }
        for key, value in pairs(hooks or {}) do
            game[key] = value
        end
        owner.games:RegisterGame(game)
        return game
    end
    scenario("waiting membership invalidates readiness", function()
        local owner = client("AuditHost", "Realm")
        local g = owner.games
        owner.roster = { "Guest-Realm", "Third-Realm" }
        fixture(owner, "party", { mode = "multiplayer", minPlayers = 3 })
        g:CreateLobby("party")
        g:Ready(true)
        local epoch = g.Lobby.epoch
        g:Receive("JOIN", { id = g.Lobby.id, request = "first", gameID = "party", version = "1" }, "Guest-Realm")
        check(not g.Lobby.members[1].ready and g.Lobby.epoch > epoch, "Join retained earlier readiness/epoch")
        epoch = g.Lobby.epoch
        g:Ready(true)
        g:RemoveMember("Guest-Realm")
        check(not g.Lobby.members[1].ready and g.Lobby.epoch > epoch, "Leave retained earlier readiness/epoch")
        g:Receive("JOIN", { id = g.Lobby.id, request = "second", gameID = "party", version = "1" }, "Guest-Realm")
        g:Receive(
            "READY",
            { id = g.Lobby.id, gameID = "party", version = "1", ready = true, epoch = epoch },
            "Guest-Realm"
        )
        check(not g.Lobby.members[2].ready, "Old-roster READY packet was accepted")
    end)
    scenario("snapshot members must be a dense array", function()
        local owner = client("AuditSnapshot", "Realm")
        local g = owner.games
        g:CreateLobby()
        local snapshot = g:GetSession()
        snapshot.members.extra = { name = "unvalidated" }
        check(not g:ValidSnapshot(snapshot, owner.name), "Snapshot accepted unvalidated keyed members")
        snapshot.members.extra = nil
        snapshot.members[3] = { name = "unvalidated" }
        check(not g:ValidSnapshot(snapshot, owner.name), "Snapshot accepted sparse members")
    end)
    scenario("join rejection is scoped to its request", function()
        local owner = client("AuditReject", "Realm")
        local g = owner.games
        g.Pending = { host = "Host-Realm", id = "session", request = "new-request" }
        g:Receive("REJECT", { id = "session", request = "old-request", reason = "Full" }, "Host-Realm")
        check(g.Pending ~= nil, "Earlier join rejection cancelled the current request")
        g:Receive("REJECT", { id = "session", request = "new-request", reason = "Full" }, "Host-Realm")
        check(g.Pending == nil, "Matching rejection did not cancel its request")
        g.Pending = { host = "Host-Realm", id = "session", request = "new-request" }
        g:Receive("REJECT", { id = "session", reason = "Legacy host" }, "Host-Realm")
        check(g.Pending == nil, "Legacy v3 rejection became incompatible")
        fixture(owner, "full", { mode = "multiplayer", minPlayers = 1, maxPlayers = 1 })
        g:CreateLobby("full")
        local rejected
        g.Send = function(_, kind, data)
            if kind == "REJECT" then
                rejected = data
            end
            return true
        end
        g:Receive("JOIN", { id = g.Lobby.id, request = "rejected-request" }, "Guest-Realm")
        check(rejected and rejected.request == "rejected-request", "Host rejection omitted join correlation")
    end)
    scenario("reloading participant invalidates countdown", function()
        local owner = client("AuditRejoin", "Realm")
        local g = owner.games
        owner.roster = { "Guest-Realm" }
        fixture(owner, "party", { mode = "multiplayer", minPlayers = 2 })
        g:CreateLobby("party")
        local join = { id = g.Lobby.id, request = "before-reload", gameID = "party", version = "1" }
        g:Receive("JOIN", join, "Guest-Realm")
        g:Ready(true)
        g:Receive(
            "READY",
            { id = g.Lobby.id, gameID = "party", version = "1", ready = true, epoch = g.Lobby.epoch },
            "Guest-Realm"
        )
        check(g.Lobby.status == "countdown", "Rejoin fixture did not count down")
        local timer, epoch = g.CountdownTimer, g.Lobby.epoch
        g:Receive("JOIN", join, "Guest-Realm")
        check(g.Lobby.status == "countdown" and g.Lobby.epoch == epoch, "Duplicate join cancelled readiness")
        join.request, join.version = "after-reload", "2"
        g:Receive("JOIN", join, "Guest-Realm")
        check(g.Lobby.status == "waiting" and timer.cancelled, "Reloaded participant retained pending start")
        check(
            not g.Lobby.members[1].ready and not g.Lobby.members[2].ready and g.Lobby.members[2].version == "2",
            "Reload retained stale compatibility/readiness"
        )
    end)
    scenario("failed startup reports failure", function()
        local owner = client("AuditStart", "Realm")
        local g = owner.games
        fixture(owner, "broken", {
            OnStart = function()
                error("expected startup failure")
            end,
        })
        local ok, err = g:StartSingleplayer("broken")
        check(ok == false and type(err) == "string", "Failed startup reported success")
        check(
            not g.ActiveGame and not g.Lobby and g.LastResult.reason == "error",
            "Failed startup leaked the solo session"
        )
        check(#g:GetRecentIDs() == 0, "Failed startup entered recent games")
    end)
    scenario("CreateUI replacement survives old callback error", function()
        local owner = client("AuditFactory", "Realm")
        local g = owner.games
        fixture(owner, "replace", {
            CreateUI = function(ctx)
                ctx:FinishGame({})
                g:StartSingleplayer("tetris")
                error("old factory failed after replacing itself")
            end,
        })
        g:StartSingleplayer("replace")
        check(
            g.ActiveGame and g.ActiveGame.game.id == "tetris" and g.Tetris.running,
            "Old CreateUI error stopped its replacement"
        )
        g:AbortGame()
    end)
    scenario("result callback may leave its lobby", function()
        local owner = client("AuditResult", "Realm")
        local g = owner.games
        fixture(owner, "leave_on_result", {
            OnResult = function()
                g:LeaveLobby()
            end,
        })
        g:StartSingleplayer("leave_on_result")
        check(g:FinishGame({}), "Result hook could not leave safely")
        check(
            not g.ActiveGame and not g.Lobby and #g:GetResults() == 1,
            "Result teardown lost completion or retained state"
        )
    end)
    scenario("result callback replacement remains active", function()
        local owner = client("AuditReplaceResult", "Realm")
        local g = owner.games
        fixture(owner, "replace_on_result", {
            OnResult = function()
                g:StartSingleplayer("tetris")
            end,
        })
        g:StartSingleplayer("replace_on_result")
        check(g:FinishGame({}), "Result callback replacement failed")
        check(
            g.ActiveGame and g.ActiveGame.game.id == "tetris" and g.Lobby.status == "running",
            "Completion stopped the replacement game"
        )
        g:AbortGame()
    end)
    scenario("guest result callback may leave", function()
        local owner = client("AuditGuest", "Realm")
        local g = owner.games
        owner.roster = { "Host-Realm" }
        fixture(owner, "guest_result", {
            mode = "multiplayer",
            OnResult = function()
                g:LeaveLobby()
            end,
        })
        g:CreateLobby("guest_result")
        g.Lobby.host = "Host-Realm"
        g.Lobby.members =
            { { name = "Host-Realm", ready = true, version = "1" }, { name = owner.name, ready = true, version = "1" } }
        g.Lobby.status, g.Lobby.run, g.Lobby.startedAt = "running", 1, owner.env.GetServerTime()
        g:StartModule(false)
        local snapshot = g:GetSession()
        snapshot.status, snapshot.revision = "waiting", snapshot.revision + 1
        snapshot.result = g:BuildResult("completed", "finished")
        g:AcceptSnapshot(snapshot, "Host-Realm")
        check(
            not g.Lobby and not g.ActiveGame and g.LastResult.status == "completed",
            "Guest result hook could not leave safely"
        )
    end)
    scenario("departing member callback may close lobby", function()
        local owner = client("AuditDeparture", "Realm")
        local g = owner.games
        owner.roster = { "Guest-Realm" }
        fixture(owner, "departure", {
            mode = "multiplayer",
            OnResult = function()
                g:LeaveLobby()
            end,
        })
        g:CreateLobby("departure")
        g.Lobby.members[2] = { name = "Guest-Realm", ready = true, version = "1" }
        g.Lobby.members[1].ready = true
        g:LaunchGame()
        g:RemoveMember("Guest-Realm")
        check(not g.Lobby and not g.ActiveGame, "Departure hook retained state")
    end)
    scenario("Tetris focus and idle work is bounded", function()
        local owner = client("AuditIdle", "Realm")
        local g, t = owner.games, owner.games.Tetris
        g:StartSingleplayer("tetris")
        t:Pause(false)
        t:Advance(0)
        local render, save = t.Render, t.SaveBest
        local renders, saves = 0, 0
        t.Render = function(self, ...)
            renders = renders + 1
            return render(self, ...)
        end
        t.SaveBest = function(self, ...)
            saves = saves + 1
            return save(self, ...)
        end
        for _ = 1, 20 do
            t:Advance(0)
        end
        check(saves == 0, "Idle Tetris repeatedly sanitized SavedVariables")
        owner.env.keyboardFocus = {}
        t:Advance(0)
        local pausedRenders = renders
        for _ = 1, 20 do
            t:Advance(0)
        end
        check(t.paused and renders == pausedRenders, "Chat focus repainted the paused game every frame")
        owner.env.keyboardFocus = nil
        t:Pause(false)
        t.model:HardDrop()
        t:Advance(0)
        check(saves == 1 and t:Storage().best.score == t.model.score, "Score change no longer saved promptly")
        g:AbortGame()
    end)
    scenario("Tetris redraw cannot consume a pending save", function()
        local owner = client("AuditRedraw", "Realm")
        local g, t = owner.games, owner.games.Tetris
        g:StartSingleplayer("tetris")
        t:Pause(false)
        t.model:HardDrop()
        t:ApplyPreset(g:GetClassPreset())
        t:Advance(0)
        check(t:Storage().best.score == t.model.score, "Cosmetic redraw prevented saving the changed score")
        g:AbortGame()
    end)
    scenario("routine refresh preserves open dropdown", function()
        local owner = client("AuditDropdown", "Realm")
        local g, ui = owner.games, owner.games.UI
        g:SetOption("followCharacter", false)
        ui:ShowOptions()
        ui.classDropdown.scripts.OnClick()
        check(ui.classDropdown.popup:IsShown(), "Dropdown did not open")
        local count = #owner.frames
        ui:Refresh()
        check(ui.classDropdown.popup:IsShown(), "Routine refresh closed the dropdown")
        check(#owner.frames == count, "Routine refresh allocated more frames")
        g:SetOption("followCharacter", true)
        check(
            not ui.classDropdown.popup:IsShown() and not ui.classDropdown:IsEnabled(),
            "Changed settings retained a stale menu"
        )
    end)
    scenario("account history survives switching characters", function()
        local first = client("AuditHistoryOne", "Realm")
        local g = first.games
        g:StartSingleplayer("tetris")
        g:FinishGame({ summary = "First character's result" })
        local id = g.LastResult.id
        local second = client("AuditHistoryTwo", "Realm", g.Copy(g.DB))
        check(#second.games.DB.results == 1, "Logging another character deleted account SavedVariables history")
        check(
            #second.games:GetResults() == 0 and not second.games.LastResult,
            "Another character's result appeared as a personal result"
        )
        second.games:StartSingleplayer("bejeweled")
        second.games:FinishGame({})
        local restored = client("AuditHistoryOne", "Realm", g.Copy(second.games.DB))
        check(
            #restored.games.DB.results == 2 and restored.games.LastResult.id == id,
            "Relog lost either character's result"
        )
        check(#restored.games:GetResults() == 1, "Personal history included another character")
    end)
    scenario("nonfinite saved minimap position", function()
        for i, angle in ipairs({ math.huge, -math.huge, 0 / 0 }) do
            local owner = client("AuditMinimap" .. i, "Realm", { minimapAngle = angle })
            local value = owner.games.DB.minimapAngle
            check(
                value == value and value > -math.huge and value < math.huge,
                "Nonfinite minimap angle survived initialization"
            )
        end
    end)
    scenario("hidden minimap releases drag tracking", function()
        local owner = client("AuditMapDrag", "Realm")
        local map = owner.games.UI.minimap
        map.scripts.OnDragStart()
        check(map.scripts.OnUpdate ~= nil, "Minimap drag did not track")
        map:Hide()
        check(map.scripts.OnUpdate == nil, "Hidden minimap retained its drag handler")
    end)
    assert(#failures == 0, table.concat(failures, "\n"))
end
