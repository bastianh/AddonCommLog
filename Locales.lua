-- Addon Comm Log - localization
-- English is the default; other locales override single keys.

local ADDON, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

-- ---------------------------------------------------------------------------
-- English (default)
-- ---------------------------------------------------------------------------
L.SECRET = "<protected>"
L.OBSERVED = "observed"
L.ERR_PREFIX_LENGTH = "Prefix must be 1-16 characters long."
L.ERR_REGISTER_FAILED = "Registration failed (limit reached?)."

-- log lines
L.IN = "IN"
L.OUT = "OUT"
L.ECHO = "ECHO"
L.VIA_LIB = "via lib"

-- detail window
L.DETAIL_TITLE = "Message #%d"
L.DETAIL_TIME = "Time:"
L.DETAIL_DIRECTION = "Direction:"
L.DETAIL_CHANNEL = "Channel:"
L.DETAIL_PREFIX = "Prefix:"
L.DETAIL_SENDER = "Sender:"
L.DETAIL_TARGET = "Target:"
L.DETAIL_ADDON = "Addon:"
L.DETAIL_LENGTH = "Length:"
L.DETAIL_CONTENT = "Content:"
L.DIR_ECHO = "Echo (own message)"
L.DIR_IN = "Incoming"
L.DIR_OUT = "Outgoing"
L.LOGGED = "(logged)"
L.VIA_LIB_LONG = "via ChatThrottleLib/AceComm, not definite"
L.UNKNOWN = "unknown"
L.CHARS = "%d characters"
L.COPY_HINT = "Ctrl+A selects all, Ctrl+C copies."
L.EXPORT_TITLE = "Log export (%d entries)"

-- statistics
L.STATS = "Statistics"
L.STATS_SINCE = "Since:"
L.STATS_IN = "Incoming: %d messages, %s"
L.STATS_OUT = "Outgoing: %d messages, %s"
L.STATS_RATE = "Last 60s: %d in / %d out"
L.STATS_PREFIXES = "Prefixes (in / out, bytes in / out, addon):"
L.STATS_CHANNELS = "Channels (in / out):"
L.STATS_SENDERS = "Senders (incoming):"
L.STATS_REGISTERED = "Registered prefixes in this client (%d) - only these can be received:"

-- main window
L.WINDOW_TITLE = "Addon Comm Log"
L.STATUS = "%d entries  ·  last 60s: %d in / %d out"
L.PAUSED_FLAG = "PAUSED"
L.BTN_FILTER = "Filter"
L.BTN_PAUSE = "Pause"
L.BTN_RESUME = "Resume"
L.BTN_CLEAR = "Clear"
L.BTN_COPY = "Copy"
L.BTN_STATS = "Statistics"
L.FILTER_DIRECTION = "Direction"
L.FILTER_ALL = "All"
L.FILTER_IN = "Incoming only"
L.FILTER_OUT = "Outgoing only"
L.SHOW_ECHOES = "Show own echoes"
L.FILTER_CHANNELS = "Channels"
L.TIP_LEFT = "Left-click: details and copy"
L.TIP_RIGHT = "Right-click: filter by this prefix"

-- slash commands
L.HELP = {
    "/acl – toggle window",
    "/acl pause – pause/resume capture",
    "/acl clear – clear log and statistics",
    "/acl stats – show statistics",
    "/acl prefixes – list registered prefixes",
    "/acl watch <prefix> – listen to a foreign prefix (saved)",
    "/acl unwatch <prefix> – stop listening (takes effect after /reload)",
    "/acl echo – toggle own echoes",
    "/acl keep – toggle keeping the log across /reload",
}
L.MSG_PAUSED = "paused."
L.MSG_RESUMED = "running again."
L.MSG_CLEARED = "cleared."
L.MSG_PREFIX_COUNT = "%d registered prefixes:"
L.MSG_WATCHING = "now listening to %s."
L.MSG_ERROR = "Error: %s"
L.MSG_UNWATCHED = "%s will no longer be registered after /reload."
L.MSG_ECHO_ON = "own echoes shown."
L.MSG_ECHO_OFF = "own echoes hidden."
L.MSG_KEEP = "Keep log across /reload: %s."
L.ON = "on"
L.OFF = "off"

-- Titan Panel
L.TITAN_LABEL = "Comm: "
L.TITAN_TOOLTIP_TITLE = "Addon communication"
L.TITAN_NOTES = "Logs addon communication of all addons in all channels.\n"
    .. "Left-click opens the log window, /acl shows all commands.\n"
L.TITAN_RATE = "Last 60s (in / out):"
L.TITAN_SINCE_IN = "Incoming since %s:"
L.TITAN_SINCE_OUT = "Outgoing since %s:"
L.TITAN_REGISTERED = "Registered prefixes:"
L.TITAN_PAUSED = "Capture paused"
L.TITAN_TOP = "Most active prefixes (in / out):"
L.TITAN_CHANNELS = "Channels (in / out):"
L.TITAN_CLICK_LEFT = "Left-click: log window"
L.TITAN_CLICK_RIGHT = "Right-click: options"
L.TITAN_OPEN = "Open log window"
L.TITAN_SHOW_STATS = "Show statistics"
L.TITAN_PAUSE = "Pause capture"
L.TITAN_ATTRIBUTE = "Detect sender addon"
L.TITAN_KEEP = "Keep log across /reload"
L.TITAN_CLEAR = "Clear log and statistics"

-- ---------------------------------------------------------------------------
-- German
-- ---------------------------------------------------------------------------
if GetLocale() == "deDE" then
    L.SECRET = "<geschützt>"
    L.OBSERVED = "beobachtet"
    L.ERR_PREFIX_LENGTH = "Präfix muss 1-16 Zeichen lang sein."
    L.ERR_REGISTER_FAILED = "Registrierung fehlgeschlagen (Limit erreicht?)."

    L.IN = "EIN"
    L.OUT = "AUS"
    L.VIA_LIB = "via Lib"

    L.DETAIL_TITLE = "Nachricht #%d"
    L.DETAIL_TIME = "Zeit:"
    L.DETAIL_DIRECTION = "Richtung:"
    L.DETAIL_CHANNEL = "Kanal:"
    L.DETAIL_PREFIX = "Präfix:"
    L.DETAIL_SENDER = "Absender:"
    L.DETAIL_TARGET = "Ziel:"
    L.DETAIL_LENGTH = "Länge:"
    L.DETAIL_CONTENT = "Inhalt:"
    L.DIR_ECHO = "Echo (eigene Nachricht)"
    L.DIR_IN = "Eingehend"
    L.DIR_OUT = "Ausgehend"
    L.LOGGED = "(Logged)"
    L.VIA_LIB_LONG = "über ChatThrottleLib/AceComm, nicht eindeutig"
    L.UNKNOWN = "unbekannt"
    L.CHARS = "%d Zeichen"
    L.COPY_HINT = "Strg+A markiert alles, Strg+C kopiert."
    L.EXPORT_TITLE = "Log-Export (%d Einträge)"

    L.STATS = "Statistik"
    L.STATS_SINCE = "Seit:"
    L.STATS_IN = "Eingehend: %d Nachrichten, %s"
    L.STATS_OUT = "Ausgehend: %d Nachrichten, %s"
    L.STATS_RATE = "Letzte 60s: %d ein / %d aus"
    L.STATS_PREFIXES = "Präfixe (ein / aus, Bytes ein / aus, Addon):"
    L.STATS_CHANNELS = "Kanäle (ein / aus):"
    L.STATS_SENDERS = "Absender (eingehend):"
    L.STATS_REGISTERED = "Registrierte Präfixe in diesem Client (%d) – nur diese sind empfangbar:"

    L.STATUS = "%d Einträge  ·  letzte 60s: %d ein / %d aus"
    L.PAUSED_FLAG = "PAUSIERT"
    L.BTN_RESUME = "Weiter"
    L.BTN_CLEAR = "Leeren"
    L.BTN_COPY = "Kopieren"
    L.BTN_STATS = "Statistik"
    L.FILTER_DIRECTION = "Richtung"
    L.FILTER_ALL = "Alle"
    L.FILTER_IN = "Nur eingehend"
    L.FILTER_OUT = "Nur ausgehend"
    L.SHOW_ECHOES = "Eigene Echos zeigen"
    L.FILTER_CHANNELS = "Kanäle"
    L.TIP_LEFT = "Linksklick: Details und Kopieren"
    L.TIP_RIGHT = "Rechtsklick: nach diesem Präfix filtern"

    L.HELP = {
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
    L.MSG_PAUSED = "pausiert."
    L.MSG_RESUMED = "läuft wieder."
    L.MSG_CLEARED = "geleert."
    L.MSG_PREFIX_COUNT = "%d registrierte Präfixe:"
    L.MSG_WATCHING = "höre jetzt %s mit."
    L.MSG_ERROR = "Fehler: %s"
    L.MSG_UNWATCHED = "%s wird nach /reload nicht mehr registriert."
    L.MSG_ECHO_ON = "eigene Echos sichtbar."
    L.MSG_ECHO_OFF = "eigene Echos ausgeblendet."
    L.MSG_KEEP = "Log über /reload behalten: %s."
    L.ON = "an"
    L.OFF = "aus"

    L.TITAN_TOOLTIP_TITLE = "Addon-Kommunikation"
    L.TITAN_NOTES = "Protokolliert die Addon-Kommunikation aller Addons in allen Kanälen.\n"
        .. "Linksklick öffnet das Log-Fenster, /acl zeigt alle Befehle.\n"
    L.TITAN_RATE = "Letzte 60s (ein / aus):"
    L.TITAN_SINCE_IN = "Seit %s eingehend:"
    L.TITAN_SINCE_OUT = "Seit %s ausgehend:"
    L.TITAN_REGISTERED = "Registrierte Präfixe:"
    L.TITAN_PAUSED = "Mitschnitt pausiert"
    L.TITAN_TOP = "Aktivste Präfixe (ein / aus):"
    L.TITAN_CHANNELS = "Kanäle (ein / aus):"
    L.TITAN_CLICK_LEFT = "Linksklick: Log-Fenster"
    L.TITAN_CLICK_RIGHT = "Rechtsklick: Optionen"
    L.TITAN_OPEN = "Log-Fenster öffnen"
    L.TITAN_SHOW_STATS = "Statistik anzeigen"
    L.TITAN_PAUSE = "Mitschnitt pausieren"
    L.TITAN_ATTRIBUTE = "Absender-Addon ermitteln"
    L.TITAN_KEEP = "Log über /reload behalten"
    L.TITAN_CLEAR = "Log und Statistik leeren"
end
