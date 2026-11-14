-- Permanent Report Mute after a reload or a login: the list saved before (ClaraComboPointsDB.reportMute) hides their
-- messages again at once; its page lists them
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({ reportmute = true }, { __index = function() return false end }),
  reportMute = { ["Player-1-00000ABC"] = { name = "Grumpy Troll-Forever", guid = "Player-1-00000ABC", when = 1763000000 },
    ["name:loud human"] = { name = "Loud Human", when = 1763000000 } } }
function date() return "2026-11-13" end
local filters = {}
ChatFrameUtil = { AddMessageEventFilter = function(event, fn) filters[event] = filters[event] or {}; table.insert(filters[event], fn) end }
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Hidden(event, author, guid)
  for _, fn in ipairs(filters[event] or {}) do
    if fn(nil, event, "hello", author, "", "", "", "", 0, 0, "", 0, 7, guid) == true then return true end
  end
  return false
end
out("== after a reload: still muted")
check(Hidden("CHAT_MSG_WHISPER", "Grumpy Troll", "Player-1-00000ABC"), "by its GUID")
check(Hidden("CHAT_MSG_CHANNEL", "Loud Human-Forever", nil), "by its name")
check(not Hidden("CHAT_MSG_SAY", "Kind Gnome", "Player-1-00000999"), "the others shown")
local page = ns.ReportMutePage
page:GetScript("OnShow")(page)
check(page.count._text == "Muted for good: 2", "its page lists them")
out(string.format("\n%d failure(s)", fails))
return fails
