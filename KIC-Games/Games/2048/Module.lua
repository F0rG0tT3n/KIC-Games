local _, Games = ...
local G = Games.Game2048

local function number(value)
    return type(value) == "number" and value == value and value >= 0 and value <= 2147483647 and math.floor(value) or 0
end

function G:Storage()
    if type(Games.DB.game2048) ~= "table" then
        Games.DB.game2048 = {}
    end
    local storage = Games.DB.game2048
    if type(storage.best) ~= "table" then
        storage.best = {}
    end
    for _, key in ipairs({ "score", "highest", "moves" }) do
        storage.best[key] = number(storage.best[key])
    end
    return storage
end

function G:SaveBest()
    local m, storage = self.model, self:Storage()
    if m and (m.score > storage.best.score or m.score == storage.best.score and m:Highest() > storage.best.highest) then
        storage.best = { score = m.score, highest = m:Highest(), moves = m.moves }
    end
end

function G:ShareBest()
    self:SaveBest()
    local best = self:Storage().best
    return Games:ShareBestToGroup(
        string.format("KIC 2048 best: %d points - Highest tile: %d - %d moves", best.score, best.highest, best.moves)
    )
end

function G:NewGame()
    if Games.ActiveGame then
        if Games.ActiveGame.game.id ~= "2048" then
            return false
        end
        Games:AbortGame()
    end
    Games.UI:ClearCompletedGame()
    local ok, err = Games:StartSingleplayer("2048")
    if ok == false and err then
        Games:Notify(err)
    end
    return ok
end

function G:CanInput()
    return self.running
        and self.context
        and self.context:GetSession()
        and self.root:IsVisible()
        and self.model.state == "playing"
        and not self.animation
        and not self.pop
        and not self.drag
        and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        and not self.summary:IsShown()
end

function G:Move(direction)
    if not self:CanInput() then
        return false
    end
    if not self.model:Move(direction) then
        self.message = "That direction is blocked. Try another."
        self:Render()
        return false
    end
    self.animation = { time = 0, duration = 0.14, move = self.model.lastMove }
    self.message = self.model.lastMove.gain > 0 and ("+" .. self.model.lastMove.gain .. " points")
        or "Keep the board open."
    self:SaveBest()
    self:Render()
    return true
end

function G:Complete()
    if not self.running or not self.context then
        return
    end
    self:SaveBest()
    local m, context = self.model, self.context
    local won = m.state == "won"
    local ok, err = context:FinishGame({
        summary = string.format(
            "%s - %d points - Highest tile %d - %d moves",
            won and "2048 reached!" or "No moves left",
            m.score,
            m:Highest(),
            m.moves
        ),
        entries = { { player = context.player, score = m.score, outcome = won and "win" or "loss" } },
    })
    if ok then
        Games.UI.completedGame = { game = Games.Registry["2048"], frame = self.root }
        Games.UI:ShowGame()
        self:Render()
        self.summary.heading:SetText(won and "2048 REACHED!" or "NO MOVES LEFT")
        self.summary.heading:SetTextColor(unpack(won and Games.Theme.Colors.success or { 1, 0.38, 0.3 }))
        self.summary.details:SetText(
            string.format(
                "Score: %d\nBest: %d\nHighest tile: %d\nMoves: %d",
                m.score,
                self:Storage().best.score,
                m:Highest(),
                m.moves
            )
        )
        self.summary:Show()
    elseif err then
        Games:Notify(err)
    end
end

Games:RegisterGame({
    id = "2048",
    title = "2048",
    version = "1",
    mode = "singleplayer",
    minPlayers = 1,
    maxPlayers = 1,
    icon = Games.Artwork["2048-card"].file,
    description = "Slide and merge equal tiles to reach 2048. Drag the board with your mouse, or use the arrow keys / WASD. Save your best score.",
    CreateUI = function(_, parent)
        return G:CreateUI(parent)
    end,
    OnStart = function(context)
        G.context, G.model = context, G.Engine.New()
        G.running, G.keys, G.animation, G.pop = true, {}, nil, nil
        G.message = "Drag in any direction to slide the tiles."
        G:CancelDrag()
        G.summary:Hide()
        G:LayoutUI()
        G:SaveBest()
        G.root:EnableKeyboard(true)
        G.root:Show()
        G:Render()
    end,
    OnStop = function()
        G:SaveBest()
        G:CancelDrag()
        G.running, G.context, G.animation, G.pop, G.keys = false, nil, nil, nil, {}
        G.root:EnableKeyboard(false)
        G.summary:Hide()
    end,
})

SLASH_KIC20481 = "/kic2048"
SlashCmdList.KIC2048 = function()
    if Games.ActiveGame and Games.ActiveGame.game.id == "2048" then
        Games.UI:ShowGame()
    else
        local ok, err = Games:StartSingleplayer("2048")
        if ok == false and err then
            Games:Notify(err)
        end
    end
end
