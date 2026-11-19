-- Water Shield Tracker, built in, on a rogue: nothing of it made (no frame, no secure button), nothing asked in combat
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
M.TEMPLATES.UIRadioButtonTemplate = M.TEMPLATES.UIRadioButtonTemplate or function(b) end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
check(ns:QolRuns("watershield") and not ns.WaterShield.frame and _G.ClaraWaterShieldCastButton == nil, "a rogue: nothing made")
M.blocked = {}
S.inCombat = true
for _ = 1, 103 do M.Fire("UNIT_AURA", "player") end
check(#M.blocked == 0, "in combat, 103 aura changes: nothing refused (" .. #M.blocked .. ")")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
out("== every class ticked: made, shown")
local page, parts = ns.WaterShieldPage, ns.WaterShieldParts
page:Show()
if page._scripts and page._scripts.OnShow then page._scripts.OnShow(page) end
parts.allClasses:Click()
check(ns.WaterShield.frame and ns.WaterShield.frame:IsShown(), "made and shown")
out(string.format("\n%d failure(s)", fails))
return fails
