-- Addon Comm Log - LibDataBroker data source
-- Works with Bazooka, ChocolateBar, ElvUI DataTexts, TukUI, Titan Panel (LDB plugins), etc.

local ADDON, ns = ...
local db = ns.db
local L = ns.L

local UPDATE_INTERVAL = 2
local TOP_PREFIXES = 8
local ICON = "Interface\\Icons\\INV_Letter_15"

local function Hex(text, color) return "|cff" .. color .. text .. "|r" end

local function BuildText()
    if db.paused then
        return L.TITAN_LABEL .. Hex(L.BTN_PAUSE, "ff4040")
    end
    local rateIn, rateOut = ns.GetRate()
    return L.TITAN_LABEL .. Hex(rateIn, "40ff40") .. " / " .. rateOut
end

local function FillTooltip(tooltip)
    local stats = ns.stats
    local rateIn, rateOut = ns.GetRate()
    local since = date("%H:%M", stats.since)

    tooltip:AddLine(L.TITAN_TOOLTIP_TITLE, 1, 1, 1)
    tooltip:AddDoubleLine(L.TITAN_RATE, rateIn .. " / " .. rateOut, nil, nil, nil, 1, 1, 1)
    tooltip:AddDoubleLine(L.TITAN_SINCE_IN:format(since),
        stats.msgIn .. " (" .. ns.FormatBytes(stats.bytesIn) .. ")", nil, nil, nil, 1, 1, 1)
    tooltip:AddDoubleLine(L.TITAN_SINCE_OUT:format(since),
        stats.msgOut .. " (" .. ns.FormatBytes(stats.bytesOut) .. ")", nil, nil, nil, 1, 1, 1)
    tooltip:AddDoubleLine(L.TITAN_REGISTERED, #ns.GetRegisteredPrefixes(), nil, nil, nil, 1, 1, 1)
    if db.paused then tooltip:AddLine(L.TITAN_PAUSED, 1, 0.25, 0.25) end

    local prefixes = {}
    for prefix, data in pairs(stats.prefixes) do prefixes[#prefixes + 1] = { prefix = prefix, data = data } end
    table.sort(prefixes, function(a, b)
        return (a.data.msgIn + a.data.msgOut) > (b.data.msgIn + b.data.msgOut)
    end)
    if #prefixes > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(L.TITAN_TOP, 1, 0.82, 0)
        for i = 1, math.min(TOP_PREFIXES, #prefixes) do
            local item = prefixes[i]
            local owner = ns.prefixOwner[item.prefix]
            tooltip:AddDoubleLine(item.prefix .. (owner and (" " .. Hex(owner, "999999")) or ""),
                item.data.msgIn .. " / " .. item.data.msgOut, nil, nil, nil, 1, 1, 1)
        end
    end

    local channels = {}
    for channel, data in pairs(stats.channels) do channels[#channels + 1] = { channel = channel, data = data } end
    table.sort(channels, function(a, b) return a.channel < b.channel end)
    if #channels > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(L.TITAN_CHANNELS, 1, 0.82, 0)
        for _, item in ipairs(channels) do
            tooltip:AddDoubleLine(ns.ColorChannel(item.channel),
                item.data.msgIn .. " / " .. item.data.msgOut, nil, nil, nil, 1, 1, 1)
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(L.TITAN_CLICK_LEFT, 0.25, 1, 0.25)
    tooltip:AddLine(L.TITAN_CLICK_RIGHT, 0.25, 1, 0.25)
end

local function OpenMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton(L.TITAN_OPEN, function() ns.ToggleWindow() end)
        root:CreateButton(L.TITAN_SHOW_STATS, function() ns.ShowStats() end)
        root:CreateDivider()
        root:CreateCheckbox(L.TITAN_PAUSE, function() return db.paused end,
            function() ns.SetPaused(not db.paused) end)
        root:CreateCheckbox(L.SHOW_ECHOES, function() return db.showEcho end,
            function() db.showEcho = not db.showEcho; ns.Rebuild() end)
        root:CreateCheckbox(L.TITAN_ATTRIBUTE, function() return db.attribute end,
            function() db.attribute = not db.attribute end)
        root:CreateCheckbox(L.TITAN_KEEP, function() return db.keepLog end,
            function() db.keepLog = not db.keepLog end)
        root:CreateDivider()
        root:CreateButton(L.TITAN_CLEAR, function() ns.Clear() end)
    end)
end

local function Init()
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    if not ldb then return end

    local object = ldb:NewDataObject(L.WINDOW_TITLE, {
        type = "data source",
        label = L.WINDOW_TITLE,
        text = BuildText(),
        icon = ICON,
        OnClick = function(self, button)
            if button == "RightButton" then
                OpenMenu(self)
            else
                ns.ToggleWindow()
            end
        end,
        OnTooltipShow = FillTooltip,
    })
    if not object then return end

    C_Timer.NewTicker(UPDATE_INTERVAL, function() object.text = BuildText() end)
end

-- Run once all addons are loaded, so a display addon's embedded LibDataBroker exists
-- regardless of load order.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    Init()
end)
