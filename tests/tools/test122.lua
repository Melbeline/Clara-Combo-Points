-- Water Shield Tracker's own addon enabled: it runs this session, the built-in one takes over from the next reload
-- (its addon turned off for the character), its settings carried over at logout. A rogue: nothing of it made.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
local loaded, disabled = { WaterShieldTracker = true }, {}
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(name) return loaded[name] == true end
C_AddOns.DoesAddOnExist = function(name) return name == "WaterShieldTracker" end
C_AddOns.GetAddOnEnableState = function(name) return disabled[name] and 0 or 2 end
C_AddOns.IsAddOnLoadable = function(name) return not disabled[name] end
C_AddOns.EnableAddOn = function(name) disabled[name] = nil end
C_AddOns.DisableAddOn = function(name) disabled[name] = true end
C_AddOns.SaveAddOns = function() end
-- (its settings, as its addon saved them)
WaterShieldTrackerDB = { show = true, locked = true, size = 64, scale = 1.25, fontSize = 24, textColor = { r = 0, g = 0.5, b = 1 },
  redMissing = false, flash = true, reminder = false, textAnchor = "BOTTOMRIGHT", clickCast = false, allClasses = false,
  point = "TOPLEFT", x = 300, y = -200 }

local ns = {}
S.class = "SHAMAN"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)

out("== its own addon running")
check(ns:QolState("watershield") == "standalone" and ns:QolTakesOver("watershield"), "it runs this session; the built-in one takes over")
check(disabled.WaterShieldTracker == true, "turned off for the character, from the next reload")
check(ClaraWaterShieldDB == nil and not (ns.WaterShield and ns.WaterShield.frame), "nothing of the built-in one meanwhile")
M.Fire("PLAYER_LOGOUT")
local d = ClaraWaterShieldDB
check(type(d) == "table" and d.locked == true and d.size == 64 and d.scale == 1.25 and d.textAnchor == "BOTTOMRIGHT"
  and d.clickCast == false and d.point == "TOPLEFT" and d.x == 300 and d.textColor.b == 1, "its settings carried over at logout")
WaterShieldTrackerDB.size = 99
M.Fire("PLAYER_LOGOUT")
check(ClaraWaterShieldDB.size == 64, "once only: the built-in one's own kept after that")
out(string.format("\n%d failure(s)", fails))
return fails
