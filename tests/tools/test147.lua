-- The sync kept to the player's own WoW accounts (Modules/Sync): this one and those the Windows script brings from this
-- computer (their ids kept); their characters (played there, or on those accounts in the gold tracker) the only ones
-- heard. Once, a new key; and what came from a friend's account once trusted (its WoW1) dropped: its characters out of
-- the gold tracker (forgotten), the gold window, the mail module's own list and Reverse Engineering's stock; the
-- player's own kept. A friend's character, its messages signed with the old key or the new: nothing taken.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false } }
local now = 5000
GetServerTime = function() return now end
time = function() return now end
-- this account (ICKSTU): its gold tracker knew a friend's WoW1 (trusted once), its characters everywhere
ClaraMoneyDB = { me = "acc1", accounts = { acc1 = { n = "ICKSTU", at = 1 }, friend1 = { n = "WoW1", at = 10 } },
  chars = { ["Lola-Forever"] = { n = "Lola", s = "Moon", r = "Forever", c = "ROGUE", l = 30, m = 100, a = "acc1", at = 100 },
    ["Friendy-Forever"] = { n = "Friendy", s = "Pal", r = "Forever", c = "MAGE", l = 40, m = 999, a = "friend1", at = 100 } } }
ClaraMailDB = { recipients = { friendy = { name = "Friendy", last = 10, cats = {} } }, own = { lola = true, friendy = true, ["friendy pal"] = true } }
ClaraCraftDB = { chars = { ["Friendy-Forever"] = { bags = { [106] = 7 }, bank = {}, mail = {}, at = 200, class = "MAGE" } } }
ClaraSyncDB = { key = "oldkeyknown0000a", trusted = { ["Friendy-Forever"] = true } }
-- WANJ, brought by the script: one of the player's (its gold tracker's own characters, those played there)
ClaraSyncIncoming = { ["WANJ"] = {
  ClaraMoneyDB = { me = "acc2", accounts = {}, chars = { ["Frank-Forever"] = { n = "Frank", r = "Forever", c = "MAGE", l = 20, m = 5, a = "acc2", at = 300 } } },
  ClaraSyncDB = { key = "zzzzzzzzzzzzzzzz", mine = { ["Gus-Forever"] = true } },
} }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
if not (ns.Sync and ns.Money) then out("(no sync or gold tracker in this version)"); out(""); out("0 failure(s)"); return end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
for _ = 1, 20 do if ClaraSyncDB and ClaraSyncDB.gen then break end M.RunTimer() end
local Sync, Gd = ns.Sync, ns.Money

out("== the player's accounts, their characters")
check(ClaraSyncDB.own.acc2 and Sync.OwnAccount("acc2") and Sync.OwnAccount("acc1"), "this one and WANJ (brought from this computer)")
check(not Sync.OwnAccount("friend1"), "the friend's WoW1: not one of them")
check(Sync.Trusted("Frank-Forever") and Sync.Trusted("Gus-Forever"), "WANJ's characters (its gold tracker's own, those played there)")
check(Sync.Trusted("Lola-Forever"), "this account's")
check(not Sync.Trusted("Friendy-Forever"), "the friend's: not")
check(ClaraSyncDB.gen == 1 and ClaraSyncDB.key ~= "oldkeyknown0000a" and next(ClaraSyncDB.trusted) == nil,
  "a new key, the trusted list of before let go")

out("== the friend's account dropped")
check(Gd.db.chars["Friendy-Forever"] == nil and Gd.db.gone["Friendy-Forever"], "its characters forgotten in the gold tracker")
check(Gd.db.accounts.friend1 == nil and Gd.db.accounts.acc1, "its account out of the gold window, ours kept")
check(Gd.db.chars["Lola-Forever"] and Gd.db.chars["Frank-Forever"], "the player's characters kept")
check(ClaraMailDB.own.friendy == nil and ClaraMailDB.own["friendy pal"] == nil and ClaraMailDB.own.lola, "out of the mail module's own list")
check(ClaraMailDB.recipients.friendy ~= nil, "still a recipient (a friend one sends mail to)")
check(ClaraCraftDB.chars["Friendy-Forever"] == nil, "its stock out of Reverse Engineering")

out("== its messages")
local function Deliver(msg, sender, key)
  local payload = ns.Encode64(ns.Serialize(msg))
  local text = ("%06x"):format(Sync.Hash(key .. payload)) .. payload
  Sync.OnAddon("ClaraSync", "ab11/1:" .. text, "CHANNEL", sender)
end
Deliver({ t = "B", k = "r", e = { { "ivy", 9999, { n = "Ivy", l = 1, c = {} } } } }, "Friendy", "oldkeyknown0000a")
check(ClaraMailDB.recipients.ivy == nil, "signed with the old key: nothing taken")
Deliver({ t = "B", k = "r", e = { { "ivy", 9999, { n = "Ivy", l = 1, c = {} } } } }, "Friendy", ClaraSyncDB.key)
check(ClaraMailDB.recipients.ivy == nil, "even with the new one: nothing taken")
Deliver({ t = "B", k = "r", e = { { "jay", 9999, { n = "Jay", l = 1, c = {} } } } }, "Frank", ClaraSyncDB.key)
check(ClaraMailDB.recipients.jay ~= nil, "the player's own character: taken")
out("")
out(fails .. " failure(s)")
