local _, Games = ...
local B = { Rules = {} }
Games.Battleships = B
local R = B.Rules
R.Size, R.Total = 10, 17
R.Ships = {
    { name = "Carrier", length = 5 },
    { name = "Battleship", length = 4 },
    { name = "Cruiser", length = 3 },
    { name = "Submarine", length = 3 },
    { name = "Destroyer", length = 2 },
}
R.Errors = {
    invalid = "Invalid action.",
    sequence = "Waiting for the current action to finish.",
    stale = "The board changed. Choose your target again.",
    locked = "Your fleet is already locked.",
    placement = "Place all five ships without overlaps or leaving the board.",
    turn = "Wait for your turn.",
    repeatShot = "You already fired at that square.",
    ended = "This match has ended.",
}
function R.Int(value, low, high)
    return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end
local function array(value, length)
    if type(value) ~= "table" or #value ~= length then
        return false
    end
    for key in pairs(value) do
        if not R.Int(key, 1, length) then
            return false
        end
    end
    for i = 1, length do
        if value[i] == nil then
            return false
        end
    end
    return true
end
local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = copy(item)
    end
    return result
end
local function replace(text, index, value)
    return text:sub(1, index - 1) .. value .. text:sub(index + 1)
end
function R.Index(x, y)
    if R.Int(x, 1, 10) and R.Int(y, 1, 10) then
        return (y - 1) * 10 + x
    end
end
function R.Coordinate(index)
    if not R.Int(index, 1, 100) then
        return "--"
    end
    return string.char(65 + (index - 1) % 10) .. (math.floor((index - 1) / 10) + 1)
end
function R.Cells(ship, position)
    local spec = R.Ships[ship]
    if
        not spec
        or type(position) ~= "table"
        or not R.Int(position.x, 1, 10)
        or not R.Int(position.y, 1, 10)
        or type(position.vertical) ~= "boolean"
    then
        return nil
    end
    local cells = {}
    for offset = 0, spec.length - 1 do
        local index =
            R.Index(position.x + (position.vertical and 0 or offset), position.y + (position.vertical and offset or 0))
        if not index then
            return nil
        end
        cells[#cells + 1] = index
    end
    return cells
end
function R.Board(layout)
    local board = {}
    for i = 1, 100 do
        board[i] = 0
    end
    for ship = 1, 5 do
        if layout[ship] then
            local cells = R.Cells(ship, layout[ship])
            if not cells then
                return nil
            end
            for _, index in ipairs(cells) do
                if board[index] ~= 0 then
                    return nil
                end
                board[index] = ship
            end
        end
    end
    return board
end
function R.DraftValid(layout)
    if type(layout) ~= "table" then
        return false
    end
    for key in pairs(layout) do
        if not R.Int(key, 1, 5) then
            return false
        end
    end
    return R.Board(layout) ~= nil
end
function R.CanPlace(layout, ship, x, y, vertical)
    if not R.Int(ship, 1, 5) or not R.DraftValid(layout) then
        return false
    end
    local nextLayout = copy(layout)
    nextLayout[ship] = { x = x, y = y, vertical = vertical }
    return R.Board(nextLayout) ~= nil
end
function R.Place(layout, ship, x, y, vertical)
    if not R.CanPlace(layout, ship, x, y, vertical) then
        return false
    end
    layout[ship] = { x = x, y = y, vertical = vertical }
    return true
end
function R.EncodeFleet(layout)
    if not R.DraftValid(layout) then
        return nil
    end
    local result = {}
    for i = 1, 5 do
        local p = layout[i]
        if not p then
            return nil
        end
        result[i] = (p.x - 1) .. (p.y - 1) .. (p.vertical and "V" or "H")
    end
    return table.concat(result)
end
function R.DecodeFleet(code)
    if type(code) ~= "string" or #code ~= 15 then
        return nil
    end
    local layout = {}
    for ship = 1, 5 do
        local token = code:sub(ship * 3 - 2, ship * 3)
        local x, y, direction = token:match("^(%d)(%d)([HV])$")
        if not x then
            return nil
        end
        layout[ship] = { x = tonumber(x) + 1, y = tonumber(y) + 1, vertical = direction == "V" }
    end
    return R.DraftValid(layout) and layout or nil
end
-- Shuffled candidates plus bounded-depth backtracking also work with a fixed RNG.
function R.RandomFleet(random)
    random = random or math.random
    local layout = {}
    local function placeShip(ship)
        if ship == 6 then
            return true
        end
        local candidates = {}
        for _, vertical in ipairs({ false, true }) do
            for y = 1, 10 do
                for x = 1, 10 do
                    if R.CanPlace(layout, ship, x, y, vertical) then
                        candidates[#candidates + 1] = { x = x, y = y, vertical = vertical }
                    end
                end
            end
        end
        for i = #candidates, 2, -1 do
            local j = random(i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        for _, position in ipairs(candidates) do
            layout[ship] = position
            if placeShip(ship + 1) then
                return true
            end
        end
        layout[ship] = nil
        return false
    end
    assert(placeShip(1), "Could not place the fleet")
    return layout
end
function R.ShotGrid(grid)
    return type(grid) == "string" and #grid == 100 and not grid:find("[^0123]")
end
function R.Hits(grid)
    local _, count = grid:gsub("[23]", "")
    return count
end
function R.Shots(grid)
    local _, count = grid:gsub("[123]", "")
    return count
end
function R.Remaining(grid, code)
    local layout = R.DecodeFleet(code)
    if not layout then
        return 5
    end
    local left = 0
    for ship = 1, 5 do
        local sunk = true
        for _, index in ipairs(R.Cells(ship, layout[ship])) do
            if grid:sub(index, index) ~= "3" then
                sunk = false
            end
        end
        if not sunk then
            left = left + 1
        end
    end
    return left
end
function R.ValidShots(grid, code)
    if not R.ShotGrid(grid) or R.Hits(grid) > 17 then
        return false
    end
    if code == "" then
        return R.Shots(grid) == 0
    end
    local layout = R.DecodeFleet(code)
    if not layout then
        return false
    end
    local board = R.Board(layout)
    for i = 1, 100 do
        local shot = grid:sub(i, i)
        if shot == "1" and board[i] > 0 or (shot == "2" or shot == "3") and board[i] == 0 then
            return false
        end
    end
    for ship = 1, 5 do
        local cells, hits, sunk = R.Cells(ship, layout[ship]), 0, 0
        for _, i in ipairs(cells) do
            local shot = grid:sub(i, i)
            if shot == "2" or shot == "3" then
                hits = hits + 1
            end
            if shot == "3" then
                sunk = sunk + 1
            end
        end
        if hits == #cells and sunk ~= #cells or hits < #cells and sunk > 0 then
            return false
        end
    end
    return true
end
function R.New(starter)
    return {
        rev = 0,
        phase = "setup",
        starter = starter == 2 and 2 or 1,
        turn = starter == 2 and 2 or 1,
        winner = 0,
        reason = "",
        fleets = { "", "" },
        shots = { string.rep("0", 100), string.rep("0", 100) },
        acks = { 0, 0 },
        last = 0,
        lastShooter = 0,
    }
end
function R.Action(data)
    return type(data) == "table"
        and R.Int(data.seq, 1, 102)
        and R.Int(data.rev, 0, 203)
        and (
            data.op == "lock" and R.DecodeFleet(data.fleet) ~= nil
            or data.op == "fire" and R.Int(data.cell, 1, 100)
            or data.op == "resign"
        )
end
function R.Apply(s, seat, data)
    if not R.Int(seat, 1, 2) or not R.Action(data) then
        return false, "invalid"
    end
    if s.phase == "ended" then
        return false, "ended"
    end
    if data.seq ~= s.acks[seat] + 1 then
        return false, "sequence"
    end
    if data.rev > s.rev then
        return false, "stale"
    end
    if data.op == "lock" then
        if s.phase ~= "setup" or s.fleets[seat] ~= "" then
            return false, "locked"
        end
        s.fleets[seat] = data.fleet
        if s.fleets[1] ~= "" and s.fleets[2] ~= "" then
            s.phase = "battle"
        end
    elseif data.op == "fire" then
        if data.rev ~= s.rev then
            return false, "stale"
        end
        if s.phase ~= "battle" or s.turn ~= seat then
            return false, "turn"
        end
        if s.shots[seat]:sub(data.cell, data.cell) ~= "0" then
            return false, "repeatShot"
        end
        local layout = R.DecodeFleet(s.fleets[3 - seat])
        local ship = R.Board(layout)[data.cell]
        s.shots[seat] = replace(s.shots[seat], data.cell, ship > 0 and "2" or "1")
        if ship > 0 then
            local cells, sunk = R.Cells(ship, layout[ship]), true
            for _, i in ipairs(cells) do
                if s.shots[seat]:sub(i, i) == "0" then
                    sunk = false
                end
            end
            if sunk then
                for _, i in ipairs(cells) do
                    s.shots[seat] = replace(s.shots[seat], i, "3")
                end
            end
        end
        s.last, s.lastShooter, s.turn = data.cell, seat, 3 - seat
        if R.Hits(s.shots[seat]) == R.Total then
            s.phase, s.winner, s.reason, s.turn = "ended", seat, "fleet_destroyed", 0
        end
    else
        s.phase, s.winner, s.reason, s.turn = "ended", 3 - seat, "resigned", 0
    end
    s.rev, s.acks[seat] = s.rev + 1, data.seq
    return true
end
function R.ValidAuthority(s)
    if
        type(s) ~= "table"
        or not R.Int(s.rev, 0, 203)
        or not R.Int(s.starter, 1, 2)
        or not array(s.fleets, 2)
        or not array(s.shots, 2)
        or not array(s.acks, 2)
        or not R.Int(s.last, 0, 100)
        or not R.Int(s.lastShooter, 0, 2)
        or not R.Int(s.winner, 0, 2)
        or not R.Int(s.turn, 0, 2)
        or type(s.reason) ~= "string"
    then
        return false
    end
    local locks = 0
    for seat = 1, 2 do
        if s.fleets[seat] ~= "" and not R.DecodeFleet(s.fleets[seat]) then
            return false
        end
        if s.fleets[seat] ~= "" then
            locks = locks + 1
        end
        if not R.ValidShots(s.shots[seat], s.fleets[3 - seat]) or not R.Int(s.acks[seat], 0, 102) then
            return false
        end
    end
    local shots = R.Shots(s.shots[1]) + R.Shots(s.shots[2])
    for seat = 1, 2 do
        local expected = math.floor(shots / 2) + (shots % 2 == 1 and seat == s.starter and 1 or 0)
        if
            R.Shots(s.shots[seat]) ~= expected
            or s.acks[seat]
                ~= expected + (s.fleets[seat] ~= "" and 1 or 0) + (s.reason == "resigned" and seat == 3 - s.winner and 1 or 0)
        then
            return false
        end
    end
    if s.rev ~= locks + shots + (s.reason == "resigned" and 1 or 0) or s.acks[1] + s.acks[2] ~= s.rev then
        return false
    end
    if (shots == 0) ~= (s.last == 0 and s.lastShooter == 0) then
        return false
    end
    if shots > 0 and (s.last == 0 or s.lastShooter ~= (shots % 2 == 1 and s.starter or 3 - s.starter)) then
        return false
    end
    if s.last > 0 and (s.lastShooter == 0 or s.shots[s.lastShooter]:sub(s.last, s.last) == "0") then
        return false
    end
    if s.phase == "setup" then
        return locks < 2 and shots == 0 and s.turn == s.starter and s.winner == 0 and s.reason == ""
    end
    if s.phase == "battle" then
        return locks == 2
            and s.turn == (shots % 2 == 0 and s.starter or 3 - s.starter)
            and s.winner == 0
            and s.reason == ""
            and R.Hits(s.shots[1]) < 17
            and R.Hits(s.shots[2]) < 17
    end
    return s.phase == "ended"
        and R.Int(s.winner, 1, 2)
        and s.turn == 0
        and (
            s.reason == "resigned" and R.Hits(s.shots[1]) < 17 and R.Hits(s.shots[2]) < 17
            or s.reason == "fleet_destroyed"
                and locks == 2
                and s.lastShooter == s.winner
                and R.Hits(s.shots[s.winner]) == 17
                and R.Hits(s.shots[3 - s.winner]) < 17
        )
end
function R.View(s, seat)
    return {
        seat = seat,
        rev = s.rev,
        phase = s.phase,
        turn = s.turn,
        ack = s.acks[seat],
        ownFleet = s.fleets[seat],
        enemyFleet = s.phase == "ended" and s.fleets[3 - seat] or "",
        incoming = s.shots[3 - seat],
        outgoing = s.shots[seat],
        ownReady = s.fleets[seat] ~= "",
        enemyReady = s.fleets[3 - seat] ~= "",
        ownLeft = R.Remaining(s.shots[3 - seat], s.fleets[seat]),
        enemyLeft = R.Remaining(s.shots[seat], s.fleets[3 - seat]),
        winner = s.winner,
        reason = s.reason,
        last = s.last,
        lastShooter = s.lastShooter,
    }
end
function R.ValidView(v, seat)
    if
        type(v) ~= "table"
        or v.seat ~= seat
        or not R.Int(v.rev, 0, 203)
        or not R.Int(v.ack, 0, 102)
        or not R.Int(v.turn, 0, 2)
        or not R.Int(v.winner, 0, 2)
        or not R.Int(v.last, 0, 100)
        or not R.Int(v.lastShooter, 0, 2)
        or not R.Int(v.ownLeft, 0, 5)
        or not R.Int(v.enemyLeft, 0, 5)
        or type(v.ownReady) ~= "boolean"
        or type(v.enemyReady) ~= "boolean"
        or type(v.enemyFleet) ~= "string"
        or (v.ownReady and not R.DecodeFleet(v.ownFleet) or not v.ownReady and v.ownFleet ~= "")
        or not R.ValidShots(v.incoming, v.ownFleet)
        or not R.ShotGrid(v.outgoing)
        or R.Hits(v.outgoing) > 17
        or v.ownLeft ~= R.Remaining(v.incoming, v.ownFleet)
    then
        return false
    end
    if v.phase ~= "ended" and v.enemyFleet ~= "" then
        return false
    end
    if v.phase == "setup" then
        return v.turn > 0
            and v.winner == 0
            and v.reason == ""
            and not (v.ownReady and v.enemyReady)
            and R.Shots(v.incoming) == 0
            and R.Shots(v.outgoing) == 0
            and v.enemyLeft == 5
    elseif v.phase == "battle" then
        return v.turn > 0
            and v.winner == 0
            and v.reason == ""
            and v.ownReady
            and v.enemyReady
            and R.Hits(v.incoming) < 17
            and R.Hits(v.outgoing) < 17
    end
    return v.phase == "ended"
        and v.turn == 0
        and v.winner > 0
        and (v.reason == "resigned" or v.reason == "fleet_destroyed")
        and (v.enemyReady and R.DecodeFleet(v.enemyFleet) ~= nil or not v.enemyReady and v.enemyFleet == "")
        and R.ValidShots(v.outgoing, v.enemyFleet)
        and v.enemyLeft == R.Remaining(v.outgoing, v.enemyFleet)
        and (
            v.reason ~= "fleet_destroyed"
            or v.ownReady and v.enemyReady and R.Hits(v.winner == seat and v.outgoing or v.incoming) == 17
        )
end
local viewFields = {
    "seat",
    "rev",
    "phase",
    "turn",
    "ack",
    "ownFleet",
    "enemyFleet",
    "incoming",
    "outgoing",
    "ownReady",
    "enemyReady",
    "ownLeft",
    "enemyLeft",
    "winner",
    "reason",
    "last",
    "lastShooter",
}
function R.Pack(view)
    local packet = {}
    for i, field in ipairs(viewFields) do
        packet[i] = view[field]
    end
    return packet
end
function R.Unpack(packet, seat)
    if not array(packet, #viewFields) then
        return nil
    end
    local view = {}
    for i, field in ipairs(viewFields) do
        view[field] = packet[i]
    end
    return R.ValidView(view, seat) and view or nil
end
