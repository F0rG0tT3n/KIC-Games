local _, Games = ...
local E = {}
Games.Chess = { Engine = E }
local abs, floor = math.abs, math.floor
local letters = { "P", "N", "B", "R", "Q", "K" }
local kinds = { p = 1, n = 2, b = 3, r = 4, q = 5, k = 6 }
local knight = { { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 }, { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 } }
local rays = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
E.START = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
local function xy(s)
    return (s - 1) % 8 + 1, floor((s - 1) / 8) + 1
end
local function square(x, y)
    if x >= 1 and x <= 8 and y >= 1 and y <= 8 then
        return (y - 1) * 8 + x
    end
end
function E.Square(name)
    if type(name) ~= "string" or not name:match("^[a-h][1-8]$") then
        return nil
    end
    return (tonumber(name:sub(2, 2)) - 1) * 8 + name:byte(1) - 96
end
function E.Name(s)
    if type(s) ~= "number" or s % 1 ~= 0 or s < 1 or s > 64 then
        return nil
    end
    local x, y = xy(s)
    return string.char(96 + x) .. y
end
local function copy(t)
    local n = {}
    for k, v in pairs(t) do
        n[k] = v
    end
    return n
end
function E.Attacked(p, s, by)
    local x, y = xy(s)
    for _, dx in ipairs({ -1, 1 }) do
        local a = square(x + dx, y - by)
        if a and p.board[a] == by then
            return true
        end
    end
    for _, d in ipairs(knight) do
        local a = square(x + d[1], y + d[2])
        if a and p.board[a] == 2 * by then
            return true
        end
    end
    for i, d in ipairs(rays) do
        for distance = 1, 7 do
            local a = square(x + d[1] * distance, y + d[2] * distance)
            if not a then
                break
            end
            local piece = p.board[a]
            if piece ~= 0 then
                if piece * by > 0 then
                    local kind = abs(piece)
                    if
                        kind == 5
                        or (i <= 4 and kind == 4)
                        or (i > 4 and kind == 3)
                        or (distance == 1 and kind == 6)
                    then
                        return true
                    end
                end
                break
            end
        end
    end
    return false
end
function E.King(p, side)
    for s = 1, 64 do
        if p.board[s] == 6 * side then
            return s
        end
    end
end
function E.InCheck(p, side)
    local king = E.King(p, side or p.turn)
    return not king or E.Attacked(p, king, -(side or p.turn))
end
local function raw(p, m)
    local n = {
        board = copy(p.board),
        turn = -p.turn,
        rights = p.rights,
        ep = 0,
        halfmove = p.halfmove + 1,
        fullmove = p.fullmove + (p.turn == -1 and 1 or 0),
    }
    local piece = p.board[m.from]
    local captured = p.board[m.to]
    n.board[m.from], n.board[m.to] = 0, piece
    if m.ep then
        captured = n.board[m.to - 8 * p.turn]
        n.board[m.to - 8 * p.turn] = 0
    end
    if m.promotion then
        n.board[m.to] = kinds[m.promotion] * p.turn
    end
    if abs(piece) == 1 or captured ~= 0 then
        n.halfmove = 0
    end
    if abs(piece) == 1 and abs(m.to - m.from) == 16 then
        n.ep = (m.from + m.to) / 2
    end
    if abs(piece) == 6 then
        n.rights = n.rights:gsub(p.turn == 1 and "[KQ]" or "[kq]", "")
        if abs(m.to - m.from) == 2 then
            local rfrom = m.to > m.from and m.from + 3 or m.from - 4
            local rto = m.to > m.from and m.from + 1 or m.from - 1
            n.board[rto], n.board[rfrom] = n.board[rfrom], 0
        end
    end
    for s, r in pairs({ [1] = "Q", [8] = "K", [57] = "q", [64] = "k" }) do
        if m.from == s or m.to == s then
            n.rights = n.rights:gsub(r, "")
        end
    end
    return n, captured
end
function E.LegalMoves(p, from)
    local moves = {}
    local function add(a, b, ep)
        if not b or p.board[b] * p.turn > 0 or abs(p.board[b]) == 6 then
            return
        end
        local _, y = xy(b)
        local function candidate(promotion)
            local m = { from = a, to = b, promotion = promotion, ep = ep }
            if not E.InCheck(raw(p, m), p.turn) then
                moves[#moves + 1] = m
            end
        end
        if abs(p.board[a]) == 1 and (y == 1 or y == 8) then
            for _, k in ipairs({ "q", "r", "b", "n" }) do
                candidate(k)
            end
        else
            candidate()
        end
    end
    for a = 1, 64 do
        local piece = p.board[a]
        if (not from or from == a) and piece * p.turn > 0 then
            local kind = abs(piece)
            local x, y = xy(a)
            if kind == 1 then
                local one = square(x, y + p.turn)
                if one and p.board[one] == 0 then
                    add(a, one)
                    local two = square(x, y + 2 * p.turn)
                    if y == (p.turn == 1 and 2 or 7) and p.board[two] == 0 then
                        add(a, two)
                    end
                end
                for _, dx in ipairs({ -1, 1 }) do
                    local b = square(x + dx, y + p.turn)
                    if b and p.board[b] * p.turn < 0 then
                        add(a, b)
                    elseif b and b == p.ep and p.board[b] == 0 and p.board[b - 8 * p.turn] == -p.turn then
                        add(a, b, true)
                    end
                end
            elseif kind == 2 then
                for _, d in ipairs(knight) do
                    add(a, square(x + d[1], y + d[2]))
                end
            else
                for i, d in ipairs(rays) do
                    if kind == 5 or kind == 6 or kind == 3 and i > 4 or kind == 4 and i <= 4 then
                        for distance = 1, (kind == 6 and 1 or 7) do
                            local b = square(x + d[1] * distance, y + d[2] * distance)
                            if not b then
                                break
                            end
                            add(a, b)
                            if p.board[b] ~= 0 then
                                break
                            end
                        end
                    end
                end
                local home = p.turn == 1 and 5 or 61
                if kind == 6 and a == home and not E.InCheck(p, p.turn) then
                    for _, castle in ipairs({ { 2, 3, 1, "K", "k" }, { -2, -4, -1, "Q", "q" } }) do
                        local direction = castle[3]
                        if
                            p.rights:find(p.turn == 1 and castle[4] or castle[5], 1, true)
                            and p.board[home + castle[2]] == 4 * p.turn
                            and p.board[home + direction] == 0
                            and p.board[home + 2 * direction] == 0
                            and (direction == 1 or p.board[home - 3] == 0)
                            and not E.Attacked(p, home + direction, -p.turn)
                            and not E.Attacked(p, home + 2 * direction, -p.turn)
                        then
                            add(a, home + castle[1])
                        end
                    end
                end
            end
        end
    end
    return moves
end
function E.FEN(p)
    local rows = {}
    for y = 8, 1, -1 do
        local row, empty = "", 0
        for x = 1, 8 do
            local v = p.board[(y - 1) * 8 + x]
            if v == 0 then
                empty = empty + 1
            else
                if empty > 0 then
                    row = row .. empty
                    empty = 0
                end
                local c = letters[abs(v)]
                row = row .. (v < 0 and c:lower() or c)
            end
        end
        if empty > 0 then
            row = row .. empty
        end
        rows[#rows + 1] = row
    end
    return table.concat(rows, "/")
        .. (p.turn == 1 and " w " or " b ")
        .. (p.rights ~= "" and p.rights or "-")
        .. " "
        .. (p.ep ~= 0 and E.Name(p.ep) or "-")
        .. " "
        .. p.halfmove
        .. " "
        .. p.fullmove
end
function E.PositionKey(p)
    -- An en-passant target affects repetition only if a legal capture exists.
    local ep = "-"
    if p.ep ~= 0 then
        for _, m in ipairs(E.LegalMoves(p)) do
            if m.ep then
                ep = E.Name(p.ep)
                break
            end
        end
    end
    return E.FEN(p):match("^(%S+ %S+ %S+)") .. " " .. ep
end
function E.New(fen)
    fen = fen or E.START
    if type(fen) ~= "string" or #fen > 160 then
        return nil, "Invalid FEN"
    end
    local board, side, rights, ep, half, full = fen:match("^(%S+) ([wb]) (%S+) (%S+) (%d+) (%d+)$")
    if
        not board
        or not rights:match("^[KQkq%-]+$")
        or tonumber(half) > 1000000
        or tonumber(full) < 1
        or tonumber(full) > 1000000
    then
        return nil, "Invalid FEN fields"
    end
    if board:find("//", 1, true) or board:sub(1, 1) == "/" or board:sub(-1) == "/" then
        return nil, "Invalid ranks"
    end
    local p = {
        board = {},
        turn = side == "w" and 1 or -1,
        rights = rights == "-" and "" or rights,
        ep = ep == "-" and 0 or E.Square(ep),
        halfmove = tonumber(half),
        fullmove = tonumber(full),
        moves = {},
        san = {},
        captured = {},
        repetitions = {},
    }
    if not p.ep or p.ep ~= 0 and (floor((p.ep - 1) / 8) + 1 ~= (side == "w" and 6 or 3)) then
        return nil, "Invalid en passant target"
    end
    local rank = 8
    for row in board:gmatch("[^/]+") do
        if rank < 1 then
            return nil, "Too many ranks"
        end
        local file = 1
        for c in row:gmatch(".") do
            local digit = tonumber(c)
            if digit and digit >= 1 and digit <= 8 then
                for _ = 1, digit do
                    p.board[square(file, rank) or 0] = 0
                    file = file + 1
                end
            elseif kinds[c:lower()] then
                p.board[square(file, rank) or 0] = kinds[c:lower()] * (c == c:upper() and 1 or -1)
                file = file + 1
            else
                return nil, "Invalid piece"
            end
        end
        if file ~= 9 then
            return nil, "Invalid rank"
        end
        rank = rank - 1
    end
    if rank ~= 0 then
        return nil, "Missing ranks"
    end
    p.board[0] = nil
    local white, black = 0, 0
    for s = 1, 64 do
        if p.board[s] == 6 then
            white = white + 1
        elseif p.board[s] == -6 then
            black = black + 1
        end
    end
    if white ~= 1 or black ~= 1 then
        return nil, "Each side needs one king"
    end
    local canonical = ""
    for _, r in ipairs({ "K", "Q", "k", "q" }) do
        local _, count = p.rights:gsub(r, "")
        if count > 1 then
            return nil, "Duplicate rights"
        end
        if count == 1 then
            canonical = canonical .. r
        end
    end
    if p.rights:find("-", 1, true) then
        return nil, "Invalid rights"
    end
    p.rights = canonical
    p.initial = E.FEN(p)
    p.repetitions[E.PositionKey(p)] = 1
    return p
end
function E.UCI(m)
    return E.Name(m.from) .. E.Name(m.to) .. (m.promotion or "")
end
function E.FindMove(p, from, to, promotion)
    if type(from) == "string" then
        from = E.Square(from)
    end
    if type(to) == "string" then
        to = E.Square(to)
    end
    if
        not E.Name(from)
        or not E.Name(to)
        or promotion ~= nil and not ({ q = true, r = true, b = true, n = true })[promotion]
    then
        return nil
    end
    for _, m in ipairs(E.LegalMoves(p, from)) do
        if m.to == to and m.promotion == promotion then
            return m
        end
    end
end
function E.Insufficient(p)
    local count, knights, bishops, complex = 0, 0, 0, nil
    for s = 1, 64 do
        local k = abs(p.board[s])
        if k ~= 0 and k ~= 6 then
            count = count + 1
            if k == 2 then
                knights = knights + 1
            elseif k == 3 then
                bishops = bishops + 1
                local x, y = xy(s)
                local c = (x + y) % 2
                if complex == nil then
                    complex = c
                elseif complex ~= c then
                    complex = -1
                end
            else
                return false
            end
        end
    end
    -- Two knights vs king and opposite-complex bishops are NOT dead: legal
    -- mating positions exist even though a mate may not be forced.
    return count <= 1 or knights == 0 and bishops == count and complex ~= -1
end
function E.Status(p)
    local check = E.InCheck(p)
    if #E.LegalMoves(p) == 0 then
        return {
            over = true,
            winner = check and -p.turn or 0,
            reason = check and "checkmate" or "stalemate",
            check = check,
        }
    end
    if E.Insufficient(p) then
        return { over = true, winner = 0, reason = "insufficient material", check = check }
    end
    if p.halfmove >= 150 then
        return { over = true, winner = 0, reason = "75-move rule", check = check }
    end
    if (p.repetitions[E.PositionKey(p)] or 0) >= 5 then
        return { over = true, winner = 0, reason = "fivefold repetition", check = check }
    end
    return {
        over = false,
        check = check,
        claim50 = p.halfmove >= 100,
        claim3 = (p.repetitions[E.PositionKey(p)] or 0) >= 3,
    }
end
function E.SAN(p, m, n, legal)
    local piece = p.board[m.from]
    local kind = abs(piece)
    local capture = m.ep or p.board[m.to] ~= 0
    local notation
    if kind == 6 and abs(m.to - m.from) == 2 then
        notation = m.to > m.from and "O-O" or "O-O-O"
    else
        notation = kind == 1 and "" or letters[kind]
        local x, y = xy(m.from)
        if kind ~= 1 then
            local other, sameFile, sameRank = false, false, false
            for _, candidate in ipairs(legal or E.LegalMoves(p)) do
                if candidate.from ~= m.from and candidate.to == m.to and p.board[candidate.from] == piece then
                    other = true
                    local cx, cy = xy(candidate.from)
                    sameFile = sameFile or cx == x
                    sameRank = sameRank or cy == y
                end
            end
            if other then
                notation = notation
                    .. (not sameFile and string.char(96 + x) or not sameRank and tostring(y) or E.Name(m.from))
            end
        elseif capture then
            notation = string.char(96 + x)
        end
        notation = notation
            .. (capture and "x" or "")
            .. E.Name(m.to)
            .. (m.promotion and "=" .. m.promotion:upper() or "")
    end
    if E.InCheck(n) then
        notation = notation .. (#E.LegalMoves(n) == 0 and "#" or "+")
    end
    return notation
end
function E.Play(p, from, to, promotion)
    if E.Status(p).over then
        return nil, "Game already ended"
    end
    local m = E.FindMove(p, from, to, promotion)
    if not m then
        return nil, "Illegal move"
    end
    local n, captured = raw(p, m)
    n.initial = p.initial
    n.moves = copy(p.moves)
    n.san = copy(p.san)
    n.captured = copy(p.captured)
    n.repetitions = n.halfmove == 0 and {} or copy(p.repetitions)
    local key = E.PositionKey(n)
    n.repetitions[key] = (n.repetitions[key] or 0) + 1
    n.moves[#n.moves + 1] = E.UCI(m)
    n.san[#n.san + 1] = E.SAN(p, m, n)
    if captured ~= 0 then
        n.captured[#n.captured + 1] = captured
    end
    n.last = { from = m.from, to = m.to, promotion = m.promotion }
    return n, n.san[#n.san]
end
function E.PlayUCI(p, uci)
    if type(uci) ~= "string" or not uci:match("^[a-h][1-8][a-h][1-8][qrnb]?$") then
        return nil, "Invalid UCI"
    end
    return E.Play(p, uci:sub(1, 2), uci:sub(3, 4), #uci == 5 and uci:sub(5, 5) or nil)
end
function E.Claim(p, kind, intended)
    local n = p
    if intended then
        n = E.PlayUCI(p, intended)
        if not n then
            return false
        end
    end
    return kind == "fifty" and n.halfmove >= 100
        or kind == "threefold" and (n.repetitions[E.PositionKey(n)] or 0) >= 3
        or false
end
function E.Serialize(p)
    return { initial = p.initial, moves = table.concat(p.moves, " "), fen = E.FEN(p) }
end
function E.Deserialize(data)
    if type(data) ~= "table" or type(data.moves) ~= "string" or #data.moves > 200000 then
        return nil, "Invalid state"
    end
    local p, err = E.New(data.initial)
    if not p then
        return nil, err
    end
    for uci in data.moves:gmatch("%S+") do
        p, err = E.PlayUCI(p, uci)
        if not p then
            return nil, err
        end
    end
    if data.fen ~= E.FEN(p) then
        return nil, "State mismatch"
    end
    return p
end
function E.Checksum(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + data:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return string.format("%08x", b * 65536 + a)
end
function E.Digest(p)
    local keys, parts = {}, { E.FEN(p), table.concat(p.captured, ",") }
    for key in pairs(p.repetitions) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = key .. ":" .. p.repetitions[key]
    end
    return E.Checksum(table.concat(parts, "|"))
end
function E.Perft(p, depth)
    if depth == 0 then
        return 1
    end
    local count = 0
    for _, m in ipairs(E.LegalMoves(p)) do
        count = count + E.Perft(raw(p, m), depth - 1)
    end
    return count
end
