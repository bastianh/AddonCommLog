-- Addon Comm Log - log window, copy window and slash commands

local ADDON, ns = ...
local db = ns.db

local MAX_DISPLAY_TEXT = 200
local LINK_TYPE = "addoncommlog"

local window, logFrame, searchBox, statusText, pauseButton
local copyFrame, copyEdit
local dirty = true
local search = ""

-- ---------------------------------------------------------------------------
-- Line formatting
-- ---------------------------------------------------------------------------
local function FormatEntry(entry)
    local stamp = date("%H:%M:%S", entry.time)
    local direction = entry.dir == "in" and "|cff66ccffEIN|r" or "|cffffaa33AUS|r"
    if entry.echo then direction = "|cff888888ECHO|r" end
    local who
    if entry.dir == "in" then
        who = entry.sender and ns.Escape(entry.sender) or "?"
    else
        who = entry.target and ("-> " .. ns.Escape(entry.target)) or ""
    end
    local addon = ""
    if entry.addon then
        addon = " |cff999999(" .. ns.Escape(entry.addon) .. ")|r"
    elseif entry.viaLib then
        addon = " |cff999999(via Lib)|r"
    end
    local text = entry.text
    if #text > MAX_DISPLAY_TEXT then text = text:sub(1, MAX_DISPLAY_TEXT) .. "..." end
    local prefixLink = "|H" .. LINK_TYPE .. ":" .. entry.seq .. "|h|cffffd100[" .. ns.Escape(entry.prefix) .. "]|r|h"
    return string.format("|cff888888%s|r %s %s %s %s%s|cff666666:|r %s",
        stamp, direction, ns.ColorChannel(entry.channel), prefixLink, who, addon, ns.Escape(text))
end

local function PlainEntry(entry)
    return string.format("%s %s %s [%s] %s%s%s: %s",
        date("%Y-%m-%d %H:%M:%S", entry.time),
        entry.echo and "ECHO" or (entry.dir == "in" and "EIN" or "AUS"),
        entry.channel, entry.prefix,
        entry.sender or "",
        entry.target and (" -> " .. entry.target) or "",
        entry.addon and (" (" .. entry.addon .. ")") or "",
        entry.text)
end

-- ---------------------------------------------------------------------------
-- Copy / detail window
-- ---------------------------------------------------------------------------
local function CreateCopyFrame()
    copyFrame = CreateFrame("Frame", "AddonCommLogCopyFrame", UIParent, "BasicFrameTemplateWithInset")
    copyFrame:SetSize(640, 420)
    copyFrame:SetPoint("CENTER", 40, -40)
    copyFrame:SetFrameStrata("DIALOG")
    copyFrame:SetMovable(true)
    copyFrame:EnableMouse(true)
    copyFrame:RegisterForDrag("LeftButton")
    copyFrame:SetScript("OnDragStart", copyFrame.StartMoving)
    copyFrame:SetScript("OnDragStop", copyFrame.StopMovingOrSizing)
    copyFrame:SetClampedToScreen(true)
    copyFrame.title = copyFrame.TitleText or copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not copyFrame.TitleText then copyFrame.title:SetPoint("TOP", 0, -5) end

    local hint = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 10)
    hint:SetText("Strg+A markiert alles, Strg+C kopiert.")

    local scroll = CreateFrame("ScrollFrame", nil, copyFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", -32, 28)

    copyEdit = CreateFrame("EditBox", nil, scroll)
    copyEdit:SetMultiLine(true)
    copyEdit:SetAutoFocus(false)
    copyEdit:SetFontObject(ChatFontNormal)
    copyEdit:SetWidth(580)
    copyEdit:SetScript("OnEscapePressed", function() copyFrame:Hide() end)
    scroll:SetScrollChild(copyEdit)
    scroll:SetScript("OnSizeChanged", function(self, width) copyEdit:SetWidth(math.max(50, width)) end)

    tinsert(UISpecialFrames, "AddonCommLogCopyFrame")
    copyFrame:Hide()
end

function ns.ShowText(title, text)
    if not copyFrame then CreateCopyFrame() end
    copyFrame.title:SetText(title)
    copyEdit:SetText(text)
    copyFrame:Show()
    copyEdit:SetFocus()
    copyEdit:SetCursorPosition(0)
    copyEdit:HighlightText()
end

local function ShowDetail(entry)
    local lines = {
        "Zeit:      " .. date("%Y-%m-%d %H:%M:%S", entry.time),
        "Richtung:  " .. (entry.echo and "Echo (eigene Nachricht)" or (entry.dir == "in" and "Eingehend" or "Ausgehend")),
        "Kanal:     " .. entry.channel .. (entry.logged and " (Logged)" or ""),
        "Präfix:    " .. entry.prefix,
        "Absender:  " .. (entry.sender or "-"),
        "Ziel:      " .. (entry.target or "-"),
        "Addon:     " .. (entry.addon or (entry.viaLib and "über ChatThrottleLib/AceComm, nicht eindeutig") or "unbekannt"),
        "Länge:     " .. #entry.text .. " Zeichen",
        "",
        "Inhalt:",
        entry.text,
    }
    ns.ShowText("Nachricht #" .. entry.seq, table.concat(lines, "\n"))
end

function ns.ExportLog()
    local lines = {}
    ns.Iterate(function(entry)
        if ns.Matches(entry, search) then lines[#lines + 1] = PlainEntry(entry) end
    end)
    ns.ShowText(("Log-Export (%d Einträge)"):format(#lines), table.concat(lines, "\n"))
end

function ns.StatsText()
    local stats = ns.stats
    local rateIn, rateOut = ns.GetRate()
    local lines = {
        "Seit:       " .. date("%Y-%m-%d %H:%M:%S", stats.since),
        ("Eingehend:  %d Nachrichten, %s"):format(stats.msgIn, ns.FormatBytes(stats.bytesIn)),
        ("Ausgehend:  %d Nachrichten, %s"):format(stats.msgOut, ns.FormatBytes(stats.bytesOut)),
        ("Letzte 60s: %d ein / %d aus"):format(rateIn, rateOut),
        "",
        "Präfixe (ein / aus, Bytes ein / aus, Addon):",
    }
    local prefixes = {}
    for prefix, data in pairs(stats.prefixes) do prefixes[#prefixes + 1] = { prefix = prefix, data = data } end
    table.sort(prefixes, function(a, b)
        return (a.data.msgIn + a.data.msgOut) > (b.data.msgIn + b.data.msgOut)
    end)
    for _, item in ipairs(prefixes) do
        local data = item.data
        lines[#lines + 1] = ("  %-18s %6d / %-6d %9s / %-9s %s"):format(item.prefix, data.msgIn, data.msgOut,
            ns.FormatBytes(data.bytesIn), ns.FormatBytes(data.bytesOut), ns.prefixOwner[item.prefix] or "")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Kanäle (ein / aus):"
    for channel, data in pairs(stats.channels) do
        lines[#lines + 1] = ("  %-14s %6d / %d"):format(channel, data.msgIn, data.msgOut)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Absender (eingehend):"
    local senders = {}
    for sender, count in pairs(stats.senders) do senders[#senders + 1] = { sender = sender, count = count } end
    table.sort(senders, function(a, b) return a.count > b.count end)
    for i = 1, math.min(25, #senders) do
        lines[#lines + 1] = ("  %-30s %d"):format(senders[i].sender, senders[i].count)
    end
    lines[#lines + 1] = ""
    local registered = ns.GetRegisteredPrefixes()
    lines[#lines + 1] = ("Registrierte Präfixe in diesem Client (%d) – nur diese sind empfangbar:"):format(#registered)
    for _, prefix in ipairs(registered) do
        lines[#lines + 1] = "  " .. prefix .. (ns.prefixOwner[prefix] and ("  (" .. ns.prefixOwner[prefix] .. ")") or "")
    end
    return table.concat(lines, "\n")
end

function ns.ShowStats()
    ns.ShowText("Statistik", ns.StatsText())
end

-- ---------------------------------------------------------------------------
-- Main window
-- ---------------------------------------------------------------------------
local function UpdateStatus()
    if not window then return end
    local rateIn, rateOut = ns.GetRate()
    statusText:SetText(("%d Einträge  ·  letzte 60s: %d ein / %d aus%s"):format(
        ns.NumEntries(), rateIn, rateOut, db.paused and "  ·  |cffff4040PAUSIERT|r" or ""))
    pauseButton:SetText(db.paused and "Weiter" or "Pause")
end

local function Rebuild()
    if not window then return end
    dirty = false
    logFrame:Clear()
    logFrame:SetMaxLines(math.max(50, db.maxEntries))
    ns.Iterate(function(entry)
        if ns.Matches(entry, search) then logFrame:AddMessage(FormatEntry(entry)) end
    end)
    logFrame:ScrollToBottom()
    UpdateStatus()
end
ns.Rebuild = function()
    if window and window:IsShown() then Rebuild() else dirty = true end
end

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    db.window.point, db.window.relativePoint, db.window.x, db.window.y = point, relativePoint, x, y
    db.window.width, db.window.height = window:GetSize()
end

local function OpenFilterMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Richtung")
        for _, option in ipairs({ { "Alle", "all" }, { "Nur eingehend", "in" }, { "Nur ausgehend", "out" } }) do
            root:CreateRadio(option[1], function() return db.direction == option[2] end,
                function() db.direction = option[2]; Rebuild() end)
        end
        root:CreateDivider()
        root:CreateCheckbox("Eigene Echos zeigen", function() return db.showEcho end,
            function() db.showEcho = not db.showEcho; Rebuild() end)
        root:CreateDivider()
        root:CreateTitle("Kanäle")
        for _, channel in ipairs(ns.CHANNELS) do
            root:CreateCheckbox(ns.ColorChannel(channel), function() return not db.hiddenChannels[channel] end,
                function()
                    db.hiddenChannels[channel] = not db.hiddenChannels[channel] or nil
                    Rebuild()
                end)
        end
    end)
end

local function CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateWindow()
    window = CreateFrame("Frame", "AddonCommLogFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetFrameStrata("HIGH")
    window:SetSize(db.window.width or 780, db.window.height or 420)
    if db.window.point then
        window:SetPoint(db.window.point, UIParent, db.window.relativePoint, db.window.x, db.window.y)
    else
        window:SetPoint("CENTER")
    end
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    if window.SetResizeBounds then
        window:SetResizeBounds(520, 220)
    elseif window.SetMinResize then
        window:SetMinResize(520, 220)
    end
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    local title = window.TitleText or window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not window.TitleText then title:SetPoint("TOP", 0, -5) end
    title:SetText("Addon Comm Log")

    -- toolbar
    searchBox = CreateFrame("EditBox", nil, window, "SearchBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("TOPLEFT", 16, -30)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
        search = (self:GetText() or ""):lower()
        Rebuild()
    end)

    local filterButton = CreateButton(window, "Filter", 70, function(self) OpenFilterMenu(self) end)
    filterButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    pauseButton = CreateButton(window, "Pause", 70, function() ns.SetPaused(not db.paused) end)
    pauseButton:SetPoint("LEFT", filterButton, "RIGHT", 4, 0)
    local clearButton = CreateButton(window, "Leeren", 70, function() ns.Clear() end)
    clearButton:SetPoint("LEFT", pauseButton, "RIGHT", 4, 0)
    local exportButton = CreateButton(window, "Kopieren", 80, function() ns.ExportLog() end)
    exportButton:SetPoint("LEFT", clearButton, "RIGHT", 4, 0)
    local statsButton = CreateButton(window, "Statistik", 80, function() ns.ShowStats() end)
    statsButton:SetPoint("LEFT", exportButton, "RIGHT", 4, 0)

    -- log
    logFrame = CreateFrame("ScrollingMessageFrame", nil, window)
    logFrame:SetPoint("TOPLEFT", 14, -58)
    logFrame:SetPoint("BOTTOMRIGHT", -14, 30)
    logFrame:SetFontObject(ChatFontNormal)
    logFrame:SetJustifyH("LEFT")
    logFrame:SetFading(false)
    logFrame:SetMaxLines(math.max(50, db.maxEntries))
    logFrame:SetHyperlinksEnabled(true)
    logFrame:EnableMouseWheel(true)
    logFrame:SetScript("OnMouseWheel", function(self, delta)
        if IsShiftKeyDown() then
            if delta > 0 then self:ScrollToTop() else self:ScrollToBottom() end
        elseif delta > 0 then
            self:ScrollUp(); self:ScrollUp(); self:ScrollUp()
        else
            self:ScrollDown(); self:ScrollDown(); self:ScrollDown()
        end
    end)
    logFrame:SetScript("OnHyperlinkClick", function(_, link, _, button)
        local linkType, seq = strsplit(":", link)
        if linkType ~= LINK_TYPE then return end
        local entry = ns.GetEntry(tonumber(seq))
        if not entry then return end
        if button == "RightButton" then
            searchBox:SetText(entry.prefix)
        else
            ShowDetail(entry)
        end
    end)
    logFrame:SetScript("OnHyperlinkEnter", function(self, link)
        local _, seq = strsplit(":", link)
        local entry = ns.GetEntry(tonumber(seq))
        if not entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine(entry.prefix, 1, 0.82, 0)
        if entry.addon then GameTooltip:AddLine("Addon: " .. entry.addon, 1, 1, 1) end
        GameTooltip:AddLine("Linksklick: Details und Kopieren", 0.5, 1, 0.5)
        GameTooltip:AddLine("Rechtsklick: nach diesem Präfix filtern", 0.5, 1, 0.5)
        GameTooltip:Show()
    end)
    logFrame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

    -- status + resize grip
    statusText = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("BOTTOMLEFT", 16, 10)

    local grip = CreateFrame("Button", nil, window)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() window:StopMovingOrSizing(); SavePosition() end)

    window:SetScript("OnShow", function() if dirty then Rebuild() else UpdateStatus() end end)
    local elapsedTotal = 0
    window:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= 1 then elapsedTotal = 0; UpdateStatus() end
    end)

    tinsert(UISpecialFrames, "AddonCommLogFrame")
    window:Hide()
end

function ns.ToggleWindow()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
end

ns.RegisterListener(function(entry)
    if not window or not window:IsShown() then
        dirty = true
        return
    end
    if not entry then
        Rebuild()
    elseif ns.Matches(entry, search) then
        logFrame:AddMessage(FormatEntry(entry))
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
local function Print(message)
    print("|cffffd100Addon Comm Log:|r " .. message)
end

local HELP = {
    "/acl – Fenster ein/aus",
    "/acl pause – Mitschnitt pausieren/fortsetzen",
    "/acl clear – Log und Statistik leeren",
    "/acl stats – Statistik anzeigen",
    "/acl prefixes – registrierte Präfixe auflisten",
    "/acl watch <Präfix> – fremdes Präfix mithören (bleibt gespeichert)",
    "/acl unwatch <Präfix> – nicht mehr mithören (wirkt nach /reload)",
    "/acl echo – eigene Echos ein/aus",
    "/acl keep – Log über /reload behalten ein/aus",
}

SLASH_ADDONCOMMLOG1 = "/acl"
SLASH_ADDONCOMMLOG2 = "/commlog"
SlashCmdList.ADDONCOMMLOG = function(input)
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    if command == "" then
        ns.ToggleWindow()
    elseif command == "pause" then
        ns.SetPaused(not db.paused)
        Print(db.paused and "pausiert." or "läuft wieder.")
    elseif command == "clear" then
        ns.Clear()
        Print("geleert.")
    elseif command == "stats" then
        ns.ShowStats()
    elseif command == "prefixes" then
        local list = ns.GetRegisteredPrefixes()
        Print(("%d registrierte Präfixe:"):format(#list))
        for _, prefix in ipairs(list) do
            print("  " .. prefix .. (ns.prefixOwner[prefix] and (" |cff999999(" .. ns.prefixOwner[prefix] .. ")|r") or ""))
        end
    elseif command == "watch" then
        local ok, err = ns.Watch(argument)
        Print(ok and ("höre jetzt " .. argument .. " mit.") or ("Fehler: " .. tostring(err)))
    elseif command == "unwatch" then
        ns.Unwatch(argument)
        Print(argument .. " wird nach /reload nicht mehr registriert.")
    elseif command == "echo" then
        db.showEcho = not db.showEcho
        ns.Rebuild()
        Print("eigene Echos " .. (db.showEcho and "sichtbar." or "ausgeblendet."))
    elseif command == "keep" then
        db.keepLog = not db.keepLog
        Print("Log über /reload behalten: " .. (db.keepLog and "an" or "aus") .. ".")
    else
        for _, line in ipairs(HELP) do print(line) end
    end
end
