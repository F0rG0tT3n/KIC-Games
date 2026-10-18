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
    { "kic_bejeweled", "KICBejeweled" },
}) do
    local owner = harness.client("ShareTester", "Realm")
    local G, module = owner.games, owner.games[game[2]]
    owner.grouped, owner.channel = true, "PARTY"
    G:StartSingleplayer(game[1])
    if module.ChooseMode then
        module:ChooseMode("roguelike")
    end
    module.model.score = 12345
    check(#owner.chatMessages == 0, "Starting a game sent chat")
    module:SaveBest()
    check(#owner.chatMessages == 0, "Saving a score sent chat")
    module.shareButton.scripts.OnClick()
    local sent = owner.chatMessages[1]
    check(#owner.chatMessages == 1 and sent.channel == "PARTY", "Share button must send exactly once to party chat")
    check(
        sent.message:find("12345", 1, true) and not sent.message:find("|", 1, true),
        "Invalid score or pipe in message"
    )
    if game[1] == "kic_bejeweled" then
        check(
            sent.message:find("^KIC Bejeweled %(Roguelike%) best:") ~= nil,
            "Renamed share title missing or duplicated"
        )
    end
    check(not owner.env.chatDraft and not module.paused, "Share opened a draft or paused the game")
    for _, channel in ipairs({ "INSTANCE_CHAT", "RAID", "PARTY" }) do
        owner.channel = channel
        local before = #owner.chatMessages
        check(
            module:ShareBest() == true and #owner.chatMessages == before + 1,
            "Grouped share did not send exactly once"
        )
        check(owner.chatMessages[#owner.chatMessages].channel == channel, "Share used the wrong group channel")
    end
    module:Pause(true)
    check(module:ShareBest() and module.paused, "Share resumed a paused game")
    owner.grouped, owner.channel = false, "SOLO"
    local before = #owner.chatMessages
    check(
        module:ShareBest() == true and #owner.chatMessages == before + 1 and module.paused,
        "Solo share failed or changed pause"
    )
    check(owner.chatMessages[#owner.chatMessages].channel == "SAY", "Solo share did not fall back to /say")
    module:Pause(false)
    module.shareButton.scripts.OnClick()
    check(
        owner.chatMessages[#owner.chatMessages].channel == "SAY" and not module.paused,
        "Solo button paused or used the wrong channel"
    )
    owner.grouped, owner.channel = true, "INSTANCE_CHAT"
    local isRaid = owner.env.IsInRaid
    owner.env.IsInRaid = function()
        return true
    end
    check(
        module:ShareBest() and owner.chatMessages[#owner.chatMessages].channel == "INSTANCE_CHAT",
        "Instance raid used regular raid chat"
    )
    owner.env.IsInRaid = isRaid
    G:ShareBestToGroup("Score | 123")
    check(owner.chatMessages[#owner.chatMessages].message == "Score - 123", "Shared sender failed to sanitize pipes")
    local modernSend = owner.env.C_ChatInfo.SendChatMessage
    owner.env.SendChatMessage = modernSend
    owner.env.C_ChatInfo.SendChatMessage = nil
    owner.channel = "PARTY"
    check(
        G:ShareBestToGroup("Legacy send") and owner.chatMessages[#owner.chatMessages].channel == "PARTY",
        "Legacy sender fallback failed"
    )
end
print(string.format("PASS: %d Share Best group-chat, button and pause-state assertions", count))
