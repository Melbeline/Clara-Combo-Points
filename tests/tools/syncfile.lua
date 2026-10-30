-- A file as the Windows script leaves it (Synchro/ClaraSync.ps1, its steps tested by syn/mirror_test.py):
-- this account's own saved variables and the other accounts' under ClaraSyncIncoming, taken at login
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
time = function() return 9000 end
local file = os.getenv("CLARA_SV")
if not file then out("CLARA_SV not set"); return true end
assert(loadfile(file))()
check(type(ClaraSyncIncoming) == "table" and ClaraSyncIncoming.WANJ, "the file read as WoW reads it")
ClaraComboPointsDB.qol = { whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false }
MailFrame = CreateFrame("Frame", "MailFrame", UIParent)
SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
SendMailNameEditBox = CreateFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
function SendMail() end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.RunTimer()
local mdb = ClaraMailDB
check(ClaraSyncIncoming == nil, "taken, then dropped")
check(mdb.recipients.dave and mdb.recipients.dave.cats.friend, "this account's own entry kept")
check(mdb.recipients.frank and mdb.recipients.frank.cats.mainalt and mdb.own.frank, "WANJ's character here")
check(mdb.recipients.hal, "and its later change")
check(mdb.recipients.gus, "101896528#1's entry here")
check(ns.Craft.db.chars["Frank-Forever"] and ns.Craft.db.chars["Frank-Forever"].bags[106] == 7, "WANJ's stock")
check(ClaraSyncDB.key == "0000aaaa0000aaaa" and ClaraSyncDB.trusted["Frank-Forever"], "the smaller key and its trusted")
check(ClaraLeaPlusDB and ClaraLeaPlusDB.AutoSell == "On" and ClaraComboPointsDB.note:find("evil", 1, true), "this account's other saved variables as they were")
out("")
out(fails .. " failure(s)")
