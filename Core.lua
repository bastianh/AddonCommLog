-- Addon Comm Log - Core
-- Captures addon messages (incoming + outgoing), keeps a ring buffer and statistics.

local ADDON, ns = ...
_G.AddonCommLog = ns

ns.SECRET = "<geschützt>"

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
local DEFAULTS = {
    maxEntries = 2000,   -- ring buffer size in memory
    keepLog = false,     -- keep the last entries across /reload and logout
    keepCount = 500,
    showEcho = false,    -- show own PARTY/RAID/GUILD messages coming back as incoming
    attribute = true,    -- find out which addon sent an outgoing message (debugstack)
    paused = false,
    direction = "all",   -- all | in | out
    hiddenChannels = {}, -- [channel] = true
    watched = {},        -- extra prefixes we register ourselves to see their traffic
    window = {},
}

local db = setmetatable({}, { __index = DEFAULTS })
ns.db = db

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                ApplyDefaults(target[key], value)
            else
                target[key] = value
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local canaccess = _G.canaccessvalue

-- Values can be "secret" on this client (e.g. during encounters). Never touch them.
local function Safe(value)
    if value == nil then return nil end
    if canaccess and not canaccess(value) then return ns.SECRET end
    return value
end

local function SafeString(value)
    value = Safe(value)
    if value == nil then return nil end
    if type(value) ~= "string" then return tostring(value) end
    return value
end

local playerName = UnitName("player")
local playerFull

local function IsSelf(sender)
    if type(sender) ~= "string" or sender == ns.SECRET then return false end
    if not playerFull then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName()
        if realm and realm ~= "" then playerFull = playerName .. "-" .. realm end
    end
    return sender == playerName or (playerFull ~= nil and sender == playerFull)
end

-- Library paths: a message sent through a shared library (ChatThrottleLib/AceComm)
-- runs in the copy of whichever addon loaded the newest version, so the folder name
-- of the library is not the real sender.
local LIB_PATTERNS = { "[/\\][Ll]ibs?[/\\]", "ExternalLibs", "[Vv]endor[/\\]", "ChatThrottleLib", "AceComm", "LibStub", "CallbackHandler" }

local function IsLibPath(path)
    for _, pattern in ipairs(LIB_PATTERNS) do
        if path:find(pattern) then return true end
    end
    return false
end

-- Returns the addon folder that triggered the current call, or nil.
local function Attribute()
    if not db.attribute or type(debugstack) ~= "function" then return nil end
    -- our own frames are skipped below, so starting a bit early is harmless
    local ok, stack = pcall(debugstack, 2, 25, 0)
    if not ok or type(stack) ~= "string" then return nil end
    local viaLib, blizzard
    for line in stack:gmatch("[^\n]+") do
        local folder, rest = line:match("AddOns[/\\]([^/\\]+)[/\\]([^%]:\"]+)")
        if folder then
            if folder ~= ADDON then
                if IsLibPath(rest) then
                    viaLib = true
                else
                    return folder
                end
            end
        elseif line:find("Blizzard_") or line:find("FrameXML") or line:find("SharedXML") then
            blizzard = true
        end
    end
    if viaLib then return nil, true end
    if blizzard then return "Blizzard" end
    return nil
end

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------
local entries = {}
local firstSeq, lastSeq = 1, 0
ns.prefixOwner = {}  -- [prefix] = addon folder that registered it (when seen)
ns.stats = {}

function ns.ResetStats()
    ns.stats = {
        since = time(),
        msgIn = 0, msgOut = 0,
        bytesIn = 0, bytesOut = 0,
        prefixes = {},   -- [prefix] = { msgIn, msgOut, bytesIn, bytesOut, last }
        channels = {},   -- [channel] = { msgIn, msgOut }
        senders = {},    -- [sender] = count (incoming)
    }
end
ns.ResetStats()

-- message rate over the last 60 seconds, one bucket per second
local buckets = {}
local function Bump(direction)
    local second = math.floor(GetTime())
    local slot = second % 60 + 1
    local bucket = buckets[slot]
    if not bucket or bucket.second ~= second then
        bucket = { second = second, msgIn = 0, msgOut = 0 }
        buckets[slot] = bucket
    end
    if direction == "in" then bucket.msgIn = bucket.msgIn + 1 else bucket.msgOut = bucket.msgOut + 1 end
end

function ns.GetRate()
    local now = math.floor(GetTime())
    local msgIn, msgOut = 0, 0
    for _, bucket in pairs(buckets) do
        if now - bucket.second < 60 then
            msgIn, msgOut = msgIn + bucket.msgIn, msgOut + bucket.msgOut
        end
    end
    return msgIn, msgOut
end

local listeners = {}
function ns.RegisterListener(fn)
    listeners[#listeners + 1] = fn
end

local function Fire(entry)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, entry)
        if not ok then geterrorhandler()(err) end
    end
end

local function Trim()
    local max = math.max(50, tonumber(db.maxEntries) or DEFAULTS.maxEntries)
    while lastSeq - firstSeq + 1 > max do
        entries[firstSeq] = nil
        firstSeq = firstSeq + 1
    end
end

local function Count(entry)
    if entry.echo then return end
    local stats = ns.stats
    local len = type(entry.text) == "string" and #entry.text or 0
    local prefix = stats.prefixes[entry.prefix]
    if not prefix then
        prefix = { msgIn = 0, msgOut = 0, bytesIn = 0, bytesOut = 0 }
        stats.prefixes[entry.prefix] = prefix
    end
    local channel = stats.channels[entry.channel]
    if not channel then
        channel = { msgIn = 0, msgOut = 0 }
        stats.channels[entry.channel] = channel
    end
    prefix.last = entry.time
    if entry.dir == "in" then
        stats.msgIn, stats.bytesIn = stats.msgIn + 1, stats.bytesIn + len
        prefix.msgIn, prefix.bytesIn = prefix.msgIn + 1, prefix.bytesIn + len
        channel.msgIn = channel.msgIn + 1
        if entry.sender then stats.senders[entry.sender] = (stats.senders[entry.sender] or 0) + 1 end
    else
        stats.msgOut, stats.bytesOut = stats.msgOut + 1, stats.bytesOut + len
        prefix.msgOut, prefix.bytesOut = prefix.msgOut + 1, prefix.bytesOut + len
        channel.msgOut = channel.msgOut + 1
    end
    Bump(entry.dir)
end

local function Record(direction, prefix, text, channel, sender, target, extra)
    if db.paused then return end
    local entry = {
        time = time(),
        clock = GetTime(),
        dir = direction,
        prefix = SafeString(prefix) or "?",
        text = SafeString(text) or "",
        channel = (SafeString(channel) or "?"):upper(),
        sender = SafeString(sender),
        target = SafeString(target),
    }
    if extra then
        for key, value in pairs(extra) do entry[key] = value end
    end
    if direction == "in" then
        entry.echo = IsSelf(entry.sender)
        entry.addon = ns.prefixOwner[entry.prefix]
    end
    lastSeq = lastSeq + 1
    entry.seq = lastSeq
    entries[lastSeq] = entry
    Trim()
    Count(entry)
    Fire(entry)
end

function ns.Iterate(fn)
    for seq = firstSeq, lastSeq do
        local entry = entries[seq]
        if entry and fn(entry) == false then return end
    end
end

function ns.GetEntry(seq)
    return entries[seq]
end

function ns.NumEntries()
    return lastSeq - firstSeq + 1
end

function ns.Clear()
    entries = {}
    firstSeq, lastSeq = 1, 0
    ns.ResetStats()
    wipe(buckets)
    Fire(nil)
end

function ns.SetPaused(paused)
    db.paused = paused and true or false
    Fire(nil)
end

-- Same filter for the window and the copy export.
function ns.Matches(entry, search)
    if entry.echo and not db.showEcho then return false end
    if db.direction ~= "all" and entry.dir ~= db.direction then return false end
    if db.hiddenChannels[entry.channel] then return false end
    if search and search ~= "" then
        local haystack = (entry.prefix .. "\1" .. (entry.sender or "") .. "\1" .. (entry.target or "") .. "\1"
            .. (entry.addon or "") .. "\1" .. entry.text):lower()
        if not haystack:find(search, 1, true) then return false end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Prefixes
-- ---------------------------------------------------------------------------
function ns.GetRegisteredPrefixes()
    local list = {}
    if C_ChatInfo and C_ChatInfo.GetRegisteredAddonMessagePrefixes then
        local ok, prefixes = pcall(C_ChatInfo.GetRegisteredAddonMessagePrefixes)
        if ok and type(prefixes) == "table" then
            for _, prefix in ipairs(prefixes) do list[#list + 1] = prefix end
        end
    end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

local watching = false
local function RegisterPrefix(prefix)
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return false end
    watching = true
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)
    watching = false
    if not ok then return false end
    -- older clients return a boolean, newer ones an Enum.RegisterAddonMessagePrefixResult (0 = success)
    return result == true or result == 0 or result == nil
end

function ns.Watch(prefix)
    if type(prefix) ~= "string" or prefix == "" or #prefix > 16 then return false, "Präfix muss 1-16 Zeichen lang sein." end
    db.watched[prefix] = true
    if not ns.prefixOwner[prefix] then ns.prefixOwner[prefix] = ADDON .. " (beobachtet)" end
    if not RegisterPrefix(prefix) then return false, "Registrierung fehlgeschlagen (Limit erreicht?)." end
    return true
end

function ns.Unwatch(prefix)
    db.watched[prefix] = nil
    -- A registered prefix cannot be unregistered; it stays active until /reload.
end

-- ---------------------------------------------------------------------------
-- Hooks (outgoing)
-- ---------------------------------------------------------------------------
local function OnSend(logged)
    return function(prefix, text, chatType, target)
        local addon, viaLib = Attribute()
        local safePrefix = SafeString(prefix) or "?"
        if not addon then addon = ns.prefixOwner[safePrefix] end
        local channel = SafeString(chatType) or "?"
        local targetText = SafeString(target)
        if channel:upper() == "CHANNEL" and type(target) ~= "nil" and targetText ~= ns.SECRET then
            local _, name = GetChannelName(target)
            if name then targetText = targetText .. " " .. name end
        end
        Record("out", prefix, text, channel, nil, targetText, { addon = addon, viaLib = viaLib, logged = logged })
    end
end

if C_ChatInfo then
    if C_ChatInfo.SendAddonMessage then
        hooksecurefunc(C_ChatInfo, "SendAddonMessage", OnSend(false))
    end
    if C_ChatInfo.SendAddonMessageLogged then
        hooksecurefunc(C_ChatInfo, "SendAddonMessageLogged", OnSend(true))
    end
    if C_ChatInfo.RegisterAddonMessagePrefix then
        hooksecurefunc(C_ChatInfo, "RegisterAddonMessagePrefix", function(prefix)
            prefix = SafeString(prefix)
            if not prefix or watching then return end
            local addon = Attribute()
            if addon and not ns.prefixOwner[prefix] then ns.prefixOwner[prefix] = addon end
        end)
    end
end

if type(BNSendGameData) == "function" then
    hooksecurefunc("BNSendGameData", function(gameAccountID, prefix, text)
        local addon, viaLib = Attribute()
        Record("out", prefix, text, "BN", nil, SafeString(gameAccountID),
            { addon = addon or ns.prefixOwner[SafeString(prefix) or ""], viaLib = viaLib })
    end)
end

-- ---------------------------------------------------------------------------
-- Events (incoming)
-- ---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_ADDON_LOGGED")
pcall(frame.RegisterEvent, frame, "BN_CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        local prefix, text, channel, sender, target, _, _, channelName = ...
        local targetText = SafeString(target)
        local name = SafeString(channelName)
        if name and name ~= "" then targetText = name end
        Record("in", prefix, text, channel, sender, targetText, { logged = event == "CHAT_MSG_ADDON_LOGGED" })
    elseif event == "BN_CHAT_MSG_ADDON" then
        local prefix, text, _, senderID = ...
        Record("in", prefix, text, "BN", "BN:" .. (SafeString(senderID) or "?"), nil)
    elseif event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        AddonCommLogDB = AddonCommLogDB or {}
        ApplyDefaults(AddonCommLogDB, DEFAULTS)
        local saved = AddonCommLogDB
        setmetatable(db, { __index = saved, __newindex = saved })
        -- restore the log kept from the last session
        if saved.keepLog and type(saved.log) == "table" then
            for _, entry in ipairs(saved.log) do
                if type(entry) == "table" and entry.prefix and entry.dir then
                    entry.restored = true
                    lastSeq = lastSeq + 1
                    entry.seq = lastSeq
                    entries[lastSeq] = entry
                end
            end
            Trim()
        end
        saved.log = nil
        for prefix in pairs(saved.watched) do RegisterPrefix(prefix) end
        Fire(nil)
    elseif event == "PLAYER_LOGOUT" then
        if AddonCommLogDB and AddonCommLogDB.keepLog then
            local keep = math.max(0, tonumber(AddonCommLogDB.keepCount) or DEFAULTS.keepCount)
            local log = {}
            for seq = math.max(firstSeq, lastSeq - keep + 1), lastSeq do
                local entry = entries[seq]
                if entry then
                    log[#log + 1] = {
                        time = entry.time, dir = entry.dir, prefix = entry.prefix, text = entry.text,
                        channel = entry.channel, sender = entry.sender, target = entry.target,
                        addon = entry.addon, echo = entry.echo, logged = entry.logged,
                    }
                end
            end
            AddonCommLogDB.log = log
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Formatting shared by UI and Titan
-- ---------------------------------------------------------------------------
ns.CHANNEL_COLORS = {
    PARTY = "aaaaff", RAID = "ff7f00", INSTANCE_CHAT = "ff7f00", GUILD = "40ff40", OFFICER = "40c040",
    WHISPER = "ff80ff", CHANNEL = "ffc0c0", SAY = "ffffff", YELL = "ff4040", BN = "00ccff",
}
ns.CHANNELS = { "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER", "WHISPER", "CHANNEL", "SAY", "YELL", "BN" }

function ns.ColorChannel(channel)
    return "|cff" .. (ns.CHANNEL_COLORS[channel] or "cccccc") .. channel .. "|r"
end

function ns.FormatBytes(bytes)
    if bytes >= 1048576 then return string.format("%.1f MB", bytes / 1048576) end
    if bytes >= 1024 then return string.format("%.1f KB", bytes / 1024) end
    return bytes .. " B"
end

-- Escape UI codes so payloads are shown literally.
function ns.Escape(text)
    return (text:gsub("|", "||"))
end
