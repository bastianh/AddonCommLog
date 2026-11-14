-- Addon Comm Log - Titan Panel plugin (only when Titan is loaded)

local ADDON, ns = ...
local db = ns.db
local L = ns.L

if not (Titan_G and Titan_G.plugins and Titan_Menu) then return end

local ID = "AddonCommLog"
local BUTTON = "TitanPanel" .. ID .. "Button"
local UPDATE_INTERVAL = 2
local TOP_PREFIXES = 8

local function ButtonText()
    if db.paused then
        return L.TITAN_LABEL, TitanUtils_GetRedText(L.BTN_PAUSE)
    end
    local rateIn, rateOut = ns.GetRate()
    local value = rateIn .. " / " .. rateOut
    if Titan_G.plugins.GetVar(ID, "ShowColoredText") then
        value = TitanUtils_GetGreenText(rateIn) .. " / " .. TitanUtils_GetNormalText(rateOut)
    else
        value = TitanUtils_GetHighlightText(value)
    end
    return L.TITAN_LABEL, value
end

local function TooltipText()
    local stats = ns.stats
    local rateIn, rateOut = ns.GetRate()
    local lines = {
        L.TITAN_RATE .. "\t" .. TitanUtils_GetHighlightText(rateIn .. " / " .. rateOut),
        L.TITAN_SINCE_IN:format(date("%H:%M", stats.since)) .. "\t"
            .. TitanUtils_GetHighlightText(stats.msgIn .. " (" .. ns.FormatBytes(stats.bytesIn) .. ")"),
        L.TITAN_SINCE_OUT:format(date("%H:%M", stats.since)) .. "\t"
            .. TitanUtils_GetHighlightText(stats.msgOut .. " (" .. ns.FormatBytes(stats.bytesOut) .. ")"),
        L.TITAN_REGISTERED .. "\t" .. TitanUtils_GetHighlightText(#ns.GetRegisteredPrefixes()),
    }
    if db.paused then lines[#lines + 1] = TitanUtils_GetRedText(L.TITAN_PAUSED) end

    local prefixes = {}
    for prefix, data in pairs(stats.prefixes) do prefixes[#prefixes + 1] = { prefix = prefix, data = data } end
    table.sort(prefixes, function(a, b)
        return (a.data.msgIn + a.data.msgOut) > (b.data.msgIn + b.data.msgOut)
    end)
    if #prefixes > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = TitanUtils_GetNormalText(L.TITAN_TOP)
        for i = 1, math.min(TOP_PREFIXES, #prefixes) do
            local item = prefixes[i]
            local owner = ns.prefixOwner[item.prefix]
            lines[#lines + 1] = item.prefix .. (owner and (" |cff999999" .. owner .. "|r") or "")
                .. "\t" .. TitanUtils_GetHighlightText(item.data.msgIn .. " / " .. item.data.msgOut)
        end
    end

    local channels = {}
    for channel, data in pairs(stats.channels) do channels[#channels + 1] = { channel = channel, data = data } end
    table.sort(channels, function(a, b) return a.channel < b.channel end)
    if #channels > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = TitanUtils_GetNormalText(L.TITAN_CHANNELS)
        for _, item in ipairs(channels) do
            lines[#lines + 1] = ns.ColorChannel(item.channel) .. "\t"
                .. TitanUtils_GetHighlightText(item.data.msgIn .. " / " .. item.data.msgOut)
        end
    end

    lines[#lines + 1] = " "
    lines[#lines + 1] = TitanUtils_GetGreenText(L.TITAN_CLICK_LEFT)
    lines[#lines + 1] = TitanUtils_GetGreenText(L.TITAN_CLICK_RIGHT)
    return table.concat(lines, "\n")
end

local function Toggle(key)
    return function()
        db[key] = not db[key]
        if key == "showEcho" then ns.Rebuild() end
        Titan_G.plugins.UpdateButton(ID)
    end
end

local function Menu(_, root)
    Titan_Menu.AddCommand(root, ID, L.TITAN_OPEN, function() ns.ToggleWindow() end)
    Titan_Menu.AddCommand(root, ID, L.TITAN_SHOW_STATS, function() ns.ShowStats() end)
    Titan_Menu.AddDivider(root)
    Titan_Menu.AddSelectorGeneric(root, L.TITAN_PAUSE,
        function() return db.paused end,
        function() ns.SetPaused(not db.paused); Titan_G.plugins.UpdateButton(ID) end)
    Titan_Menu.AddSelectorGeneric(root, L.SHOW_ECHOES, function() return db.showEcho end, Toggle("showEcho"))
    Titan_Menu.AddSelectorGeneric(root, L.TITAN_ATTRIBUTE, function() return db.attribute end, Toggle("attribute"))
    Titan_Menu.AddSelectorGeneric(root, L.TITAN_KEEP, function() return db.keepLog end, Toggle("keepLog"))
    Titan_Menu.AddDivider(root)
    Titan_Menu.AddCommand(root, ID, L.TITAN_CLEAR, function()
        ns.Clear()
        Titan_G.plugins.UpdateButton(ID)
    end)
end

local container = CreateFrame("Frame", nil, UIParent)
local button = CreateFrame("Button", BUTTON, container, "TitanPanelComboTemplate")
button:SetFrameStrata("FULLSCREEN")
button.registry = {
    id = ID,
    category = "Information",
    version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "",
    menuText = L.WINDOW_TITLE,
    menuContextFunction = Menu,
    buttonTextFunction = ButtonText,
    tooltipTitle = L.TITAN_TOOLTIP_TITLE,
    tooltipTextFunction = TooltipText,
    icon = "Interface\\Icons\\INV_Letter_15",
    iconWidth = 16,
    notes = L.TITAN_NOTES,
    controlVariables = {
        ShowIcon = true,
        ShowLabelText = true,
        ShowColoredText = true,
        DisplayOnRightSide = true,
    },
    savedVariables = {
        ShowIcon = true,
        ShowLabelText = true,
        ShowColoredText = true,
        DisplayOnRightSide = false,
    },
}

local ticker
button:SetScript("OnShow", function(self)
    Titan_G.plugins.OnShow(self)
    if not ticker then
        ticker = C_Timer.NewTicker(UPDATE_INTERVAL, function() Titan_G.plugins.UpdateButton(ID) end)
    end
end)
button:SetScript("OnHide", function()
    if ticker then ticker:Cancel(); ticker = nil end
end)
button:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "LeftButton" then
        ns.ToggleWindow()
    else
        Titan_G.plugins.OnClick(self, mouseButton)
    end
end)
