-- Addon Comm Log - Titan Panel plugin (only when Titan is loaded)

local ADDON, ns = ...
local db = ns.db

if not (Titan_G and Titan_G.plugins and Titan_Menu) then return end

local ID = "AddonCommLog"
local BUTTON = "TitanPanel" .. ID .. "Button"
local UPDATE_INTERVAL = 2
local TOP_PREFIXES = 8

local function ButtonText()
    if db.paused then
        return "Comm: ", TitanUtils_GetRedText("Pause")
    end
    local rateIn, rateOut = ns.GetRate()
    local value = rateIn .. " / " .. rateOut
    if Titan_G.plugins.GetVar(ID, "ShowColoredText") then
        value = TitanUtils_GetGreenText(rateIn) .. " / " .. TitanUtils_GetNormalText(rateOut)
    else
        value = TitanUtils_GetHighlightText(value)
    end
    return "Comm: ", value
end

local function TooltipText()
    local stats = ns.stats
    local rateIn, rateOut = ns.GetRate()
    local lines = {
        "Letzte 60s (ein / aus):\t" .. TitanUtils_GetHighlightText(rateIn .. " / " .. rateOut),
        "Seit " .. date("%H:%M", stats.since) .. " eingehend:\t"
            .. TitanUtils_GetHighlightText(stats.msgIn .. " (" .. ns.FormatBytes(stats.bytesIn) .. ")"),
        "Seit " .. date("%H:%M", stats.since) .. " ausgehend:\t"
            .. TitanUtils_GetHighlightText(stats.msgOut .. " (" .. ns.FormatBytes(stats.bytesOut) .. ")"),
        "Registrierte Präfixe:\t" .. TitanUtils_GetHighlightText(#ns.GetRegisteredPrefixes()),
    }
    if db.paused then lines[#lines + 1] = TitanUtils_GetRedText("Mitschnitt pausiert") end

    local prefixes = {}
    for prefix, data in pairs(stats.prefixes) do prefixes[#prefixes + 1] = { prefix = prefix, data = data } end
    table.sort(prefixes, function(a, b)
        return (a.data.msgIn + a.data.msgOut) > (b.data.msgIn + b.data.msgOut)
    end)
    if #prefixes > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = TitanUtils_GetNormalText("Aktivste Präfixe (ein / aus):")
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
        lines[#lines + 1] = TitanUtils_GetNormalText("Kanäle (ein / aus):")
        for _, item in ipairs(channels) do
            lines[#lines + 1] = ns.ColorChannel(item.channel) .. "\t"
                .. TitanUtils_GetHighlightText(item.data.msgIn .. " / " .. item.data.msgOut)
        end
    end

    lines[#lines + 1] = " "
    lines[#lines + 1] = TitanUtils_GetGreenText("Linksklick: Log-Fenster")
    lines[#lines + 1] = TitanUtils_GetGreenText("Rechtsklick: Optionen")
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
    Titan_Menu.AddCommand(root, ID, "Log-Fenster öffnen", function() ns.ToggleWindow() end)
    Titan_Menu.AddCommand(root, ID, "Statistik anzeigen", function() ns.ShowStats() end)
    Titan_Menu.AddDivider(root)
    Titan_Menu.AddSelectorGeneric(root, "Mitschnitt pausieren",
        function() return db.paused end,
        function() ns.SetPaused(not db.paused); Titan_G.plugins.UpdateButton(ID) end)
    Titan_Menu.AddSelectorGeneric(root, "Eigene Echos zeigen", function() return db.showEcho end, Toggle("showEcho"))
    Titan_Menu.AddSelectorGeneric(root, "Absender-Addon ermitteln", function() return db.attribute end, Toggle("attribute"))
    Titan_Menu.AddSelectorGeneric(root, "Log über /reload behalten", function() return db.keepLog end, Toggle("keepLog"))
    Titan_Menu.AddDivider(root)
    Titan_Menu.AddCommand(root, ID, "Log und Statistik leeren", function()
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
    menuText = "Addon Comm Log",
    menuContextFunction = Menu,
    buttonTextFunction = ButtonText,
    tooltipTitle = "Addon-Kommunikation",
    tooltipTextFunction = TooltipText,
    icon = "Interface\\Icons\\INV_Letter_15",
    iconWidth = 16,
    notes = "Protokolliert die Addon-Kommunikation aller Addons in allen Kanälen.\n"
        .. "Linksklick öffnet das Log-Fenster, /acl zeigt alle Befehle.\n",
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
