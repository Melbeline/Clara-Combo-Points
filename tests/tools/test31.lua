-- 1.60: icons still at 1.5's default size (25) move up to 55, once
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
ClaraComboPointsDB = { profiles = { ROGUE = { icons = { size = 25 } }, PRIEST = { icons = { size = 30 } }, HUNTER = { icons = { size = 25 } } },
  saved = { PRIEST = { Raid = { icons = { size = 25 } } } } }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local sv = ns.sv
check(sv.profiles.ROGUE.icons.size == 55 and sv.profiles.HUNTER.icons.size == 55, "25 (the old default): 55 now")
check(sv.profiles.PRIEST.icons.size == 30, "a size chosen by hand stays")
check(sv.saved.PRIEST.Raid.icons.size == 55, "saved profiles too")
check(sv.profiles.MAGE.icons.size == 55, "a class never set: 55")
check(sv.iconsVersion == 2, "done once")
out(fails .. " failure(s)")
