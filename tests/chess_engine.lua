local G = {}
assert(loadfile("KIC-Games/Games/Chess/Engine.lua"))("KIC-Games", G)
local E, n = G.Chess.Engine, 0
local function check(v, s)
    assert(v, s)
    n = n + 1
end
local function position(fen)
    return assert(E.New(fen))
end
local function legal(p, a, b, c)
    return E.FindMove(p, a, b, c) ~= nil
end
local function play(p, ...)
    for _, uci in ipairs({ ... }) do
        p = assert(E.PlayUCI(p, uci))
    end
    return p
end
local p = position()
for d, count in ipairs({ 20, 400, 8902 }) do
    check(E.Perft(p, d) == count, "Starting perft depth " .. d)
end
local kiwi = position("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
check(E.Perft(kiwi, 1) == 48 and E.Perft(kiwi, 2) == 2039, "Castling/tactical perft")
check(E.Perft(kiwi, 3) == 97862, "Kiwipete depth 3")
check(E.Perft(p, 4) == 197281, "Starting perft depth 4")
check(E.FEN(p) == E.START, "FEN roundtrip")
check(not E.New("8/8/8/8/8/8/8/8 w - - 0 1"), "Missing kings accepted")
check(not E.New("8//8/8/8/8/4k3/4K3/8 w - - 0 1"), "Malformed ranks accepted")
check(legal(p, "e2", "e4") and legal(p, "e2", "e3") and legal(p, "g1", "f3"), "Pawn/knight opening moves")
check(not legal(p, "a1", "a3") and not legal(p, "c1", "g5") and not legal(p, "e1", "e2"), "Blocked pieces moved")
check(not legal(p, "e2", "e5") and not E.PlayUCI(p, "e2e9"), "Invalid move accepted")
check(not E.Play(p, "e2", "e4", "k") and not E.Play(p, "e2", "e4", "q"), "Invalid promotion payload accepted")
local pin = position("4r2k/8/8/8/8/8/4R3/4K3 w - - 0 1")
check(not legal(pin, "e2", "d2") and legal(pin, "e2", "e8"), "Pinned rook escaped pin")
local checked = position("4r2k/8/8/8/8/8/8/4K3 w - - 0 1")
check(
    E.InCheck(checked) and legal(checked, "e1", "d1") and not legal(checked, "e1", "e2"),
    "King escapes/check validation"
)
local adjacent = position("8/8/8/8/8/4k3/8/4K3 w - - 0 1")
check(not legal(adjacent, "e1", "e2"), "King moved beside enemy king")
local noCapture = position("4k3/4R3/8/8/8/8/8/4K3 w - - 0 1")
check(not legal(noCapture, "e7", "e8"), "King capture allowed")
for _, side in ipairs({ "w", "b" }) do
    local castle = position("r3k2r/8/8/8/8/8/8/R3K2R " .. side .. " KQkq - 0 1")
    local rank = side == "w" and "1" or "8"
    check(legal(castle, "e" .. rank, "g" .. rank) and legal(castle, "e" .. rank, "c" .. rank), "Both castles " .. side)
    local q = assert(E.Play(castle, "e" .. rank, "c" .. rank))
    check(q.board[E.Square("d" .. rank)] == (side == "w" and 4 or -4) and q.san[1] == "O-O-O", "Queenside rook/SAN")
end
local through = position("4kr2/8/8/8/8/8/8/R3K2R w KQ - 0 1")
check(not legal(through, "e1", "g1") and legal(through, "e1", "c1"), "Castled through check")
local rookSquare = position("r3k3/8/8/8/8/8/8/R3K3 w Q - 0 1")
check(legal(rookSquare, "e1", "c1"), "Irrelevant attacked rook square prevents castling")
local bSquare = position("1r2k3/8/8/8/8/8/8/R3K3 w Q - 0 1")
check(legal(bSquare, "e1", "c1"), "Irrelevant b-file attack prevents castling")
local inCheck = position("4r2k/8/8/8/8/8/8/R3K2R w KQ - 0 1")
check(not legal(inCheck, "e1", "c1") and not legal(inCheck, "e1", "g1"), "Castled out of check")
local rights = position("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")
rights = play(rights, "h1h2", "e8e7", "h2h1", "e7e8")
check(not legal(rights, "e1", "g1") and legal(rights, "e1", "c1"), "Moved rook regained rights")
local ep = position("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
check(legal(ep, "e5", "d6"), "En passant missing")
local taken = assert(E.Play(ep, "e5", "d6"))
check(taken.board[E.Square("d5")] == 0 and taken.san[1] == "exd6" and taken.halfmove == 0, "En passant application/SAN")
local illegalEP = position("7k/8/8/r4pPK/8/8/8/8 w - f6 0 1")
check(not legal(illegalEP, "g5", "f6"), "En passant exposed king")
local noEP = position("7k/8/8/r4pPK/8/8/8/8 w - - 0 1")
check(E.PositionKey(illegalEP) == E.PositionKey(noEP), "Illegal en passant changed repetition identity")
for _, color in ipairs({ 1, -1 }) do
    local promote = position(color == 1 and "7k/P7/8/8/8/8/8/7K w - - 0 1" or "7k/8/8/8/8/8/p7/7K b - - 0 1")
    local a, b = color == 1 and "a7" or "a2", color == 1 and "a8" or "a1"
    check(not E.Play(promote, a, b), "Promotion auto-selected")
    for _, kind in ipairs({ "q", "r", "b", "n" }) do
        local q = assert(E.Play(promote, a, b, kind))
        check(q.last.promotion == kind and q.san[1]:find("=" .. kind:upper(), 1, true), "Promotion " .. kind)
    end
end
local mate = play(position(), "f2f3", "e7e5", "g2g4", "d8h4")
check(E.Status(mate).winner == -1 and mate.san[4] == "Qh4#", "Checkmate/SAN")
local stale = position("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
check(E.Status(stale).reason == "stalemate", "Stalemate")
local repeatPosition = position()
for cycle = 1, 4 do
    repeatPosition = play(repeatPosition, "g1f3", "g8f6", "f3g1", "f6g8")
    if cycle == 2 then
        check(E.Claim(repeatPosition, "threefold") and not E.Status(repeatPosition).over, "Threefold claim")
    end
end
check(E.Status(repeatPosition).reason == "fivefold repetition", "Automatic fivefold")
check(not E.PlayUCI(repeatPosition, "g1f3"), "Moves allowed after automatic draw")
local fifty = position("4k3/8/8/8/8/8/8/R3K3 w - - 99 50")
check(not E.Claim(fifty, "fifty") and E.Claim(fifty, "fifty", "a1a2"), "Intended fifty-move claim")
fifty = play(fifty, "a1a2")
check(E.Claim(fifty, "fifty") and not E.Status(fifty).over, "Fifty-move claim vs automatic draw")
local auto = position("4k3/8/8/8/8/8/8/R3K3 w - - 150 76")
check(E.Status(auto).reason == "75-move rule", "Automatic 75-move draw")
local mate75 = position("7k/6Q1/6K1/8/8/8/8/8 b - - 150 76")
check(E.Status(mate75).reason == "checkmate", "75-move draw overrode checkmate")
for _, fen in ipairs({
    "4k3/8/8/8/8/8/8/4K3 w - - 0 1",
    "4k3/8/8/8/8/8/8/2B1K3 w - - 0 1",
    "4k3/8/8/8/8/8/8/2N1K3 w - - 0 1",
    "4kb2/8/8/8/8/8/8/2B1K3 w - - 0 1",
}) do
    check(E.Insufficient(position(fen)), "Dead material missed")
end
check(not E.Insufficient(position("4k3/8/8/8/8/8/8/1NN1K3 w - - 0 1")), "Two knights incorrectly declared dead")
check(not E.Insufficient(position("2b1k3/8/8/8/8/8/8/2B1K3 w - - 0 1")), "Opposite bishops incorrectly declared dead")
local disambiguate = position("4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1")
local move = assert(E.Play(disambiguate, "b1", "d2"))
check(move.san[1] == "Nbd2", "SAN file disambiguation")
local packed = E.Serialize(mate)
local unpacked = assert(E.Deserialize(packed))
check(
    E.FEN(unpacked) == E.FEN(mate) and table.concat(unpacked.san, " ") == table.concat(mate.san, " "),
    "Serialized state loses history"
)
packed.fen = E.START
check(not E.Deserialize(packed), "Inconsistent serialized state accepted")
check(E.Digest(mate) == E.Digest(unpacked) and E.Digest(position()) ~= E.Digest(mate), "Deterministic digest")
local changed = assert(E.Deserialize(E.Serialize(mate)))
changed.repetitions[E.PositionKey(changed)] = 4
check(E.Digest(changed) ~= E.Digest(mate), "Digest ignores repetition state")
print(string.format("PASS: %d Chess engine assertions; perft 20 / 400 / 8902 and Kiwipete 48 / 2039", n))
