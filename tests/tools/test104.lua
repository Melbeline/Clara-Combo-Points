-- Permanent Report Mute turned off on its card: no filter, nobody hidden (the list kept for when it is back on)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({}, { __index = function() return false end }),
  reportMute = { ["Player-1-00000ABC"] = { name = "Grumpy Troll", guid = "Player-1-00000ABC", when = 1 } } }
local filters = {}
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = filters[event] or {}; table.insert(filters[event], fn) end }
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local hidden = false
for _, fn in ipairs(filters.CHAT_MSG_SAY or {}) do
  if fn(nil, "CHAT_MSG_SAY", "hello", "Grumpy Troll", "", "", "", "", 0, 0, "", 0, 7, "Player-1-00000ABC") == true then hidden = true end
end
out("== turned off")
check(not ns:QolRuns("reportmute") and ns:QolState("reportmute") == "off", "off this session")
check(not hidden and ns.ReportMuteFilter == nil, "no filter: their messages shown")
check(ClaraComboPointsDB.reportMute["Player-1-00000ABC"] ~= nil, "the list kept")
out(string.format("\n%d failure(s)", fails))
return fails
