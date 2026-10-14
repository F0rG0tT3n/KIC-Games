local _, Games = ...
local Serializer = LibStub("AceSerializer-3.0")
local MAX_BYTES = 12288

-- Limit module data to small, finite, acyclic Lua values. No code is evaluated.
local function safe(value, depth, seen, budget)
    local kind = type(value)
    if kind == "nil" or kind == "boolean" then
        return true
    end
    if kind == "string" then
        return #value <= 4096
    end
    if kind == "number" then
        return value == value and value ~= math.huge and value ~= -math.huge
    end
    if kind ~= "table" or depth > 8 or seen[value] then
        return false
    end
    seen[value] = true
    for key, item in pairs(value) do
        budget.n = budget.n + 1
        if
            budget.n > 512
            or (type(key) ~= "string" and type(key) ~= "number")
            or not safe(key, depth + 1, seen, budget)
            or not safe(item, depth + 1, seen, budget)
        then
            return false
        end
    end
    seen[value] = nil
    return true
end

function Games:ValidData(data)
    return safe(data, 0, {}, { n = 0 })
end

function Games:InitializeCommunication()
    self.Comm = {}
    LibStub("AceComm-3.0"):Embed(self.Comm)
    self.Comm:RegisterComm(self.PREFIX, function(_, message, channel, sender)
        if type(message) ~= "string" or #message > MAX_BYTES or channel ~= Games:GroupChannel() then
            return
        end
        sender = Games:NormalizeName(sender)
        if not sender or sender == Games:PlayerName() or not Games:Roster()[sender] then
            return
        end
        local ok, protocol, kind, data = Serializer:Deserialize(message)
        if
            not ok
            or protocol ~= Games.API_VERSION
            or type(kind) ~= "string"
            or type(data) ~= "table"
            or not Games:ValidData(data)
        then
            return
        end
        Games:Receive(kind, data, sender)
    end)
end

function Games:Send(kind, data)
    local channel = self:GroupChannel()
    if not self.Comm or not channel then
        return false, "Join a group first."
    end
    if not self:ValidData(data) then
        return false, "Invalid or oversized message data."
    end
    local message = Serializer:Serialize(self.API_VERSION, kind, data)
    if #message > MAX_BYTES then
        return false, "Message is too large."
    end
    self.Comm:SendCommMessage(self.PREFIX, message, channel, nil, "NORMAL")
    return true
end
