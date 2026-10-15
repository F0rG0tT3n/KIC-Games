local previous = arg[1]
arg[1] = "--harness"
local harness = assert(loadfile("tests/framework.lua"))()
arg[1] = previous
local count = 0
local function check(condition, message)
    assert(condition, message)
    count = count + 1
end
for _, game in ipairs({
    { "tetris", "Tetris" },
    { "bejeweled", "Bejeweled" },
    { "bejeweled_deluxe", "BejeweledDeluxe" },
}) do
    local owner = harness.client("ShareTester", "Realm")
    local G, module = owner.games, owner.games[game[2]]
    owner.grouped, owner.channel = true, "INSTANCE_CHAT"
    G:StartSingleplayer(game[1])
    module.model.score = 12345
    check(#owner.chatMessages == 0, "Starting a game sent chat")
    module:SaveBest()
    check(#owner.chatMessages == 0, "Saving a score sent chat")
    module:ShareBest()
    local sent = owner.chatMessages[1]
    check(#owner.chatMessages == 1 and sent.channel == "INSTANCE_CHAT", "Share must send exactly once to /i")
    check(
        sent.message:find("12345", 1, true) and not sent.message:find("|", 1, true),
        "Invalid score or pipe in message"
    )
    if game[1] == "bejeweled_deluxe" then
        check(sent.message:find("^KIC Bejeweled best:") ~= nil, "Renamed share title missing or duplicated")
    end
    check(not owner.env.chatDraft and module.paused, "Share opened a draft or failed to pause")
    for _, channel in ipairs({ "PARTY", "RAID", "SOLO" }) do
        owner.grouped, owner.channel = channel ~= "SOLO", channel
        check(module:ShareBest() == false and #owner.chatMessages == 1, "Share leaked to a different channel")
    end
    owner.grouped, owner.channel = true, "INSTANCE_CHAT"
    G:ShareBestToInstance("Score | 123")
    check(owner.chatMessages[2].message == "Score - 123", "Shared sender failed to sanitize pipes")
end
print(string.format("PASS: %d Share Best instance-chat assertions", count))
