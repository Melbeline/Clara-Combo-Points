-- What's Training? built in (Modules/WhatsTraining): its own shared table (Clara's untouched), its data built
-- for the class, its window (/wt) and the Improvements tab's button, ClassicUI's side tab finding it
local M, S = MOCK, MOCK.state
local E = dofile(TOOLS_DIR .. "/erf_env.lua")
geterrorhandler = function() return function(e) MOCK.errors = MOCK.errors or {}; table.insert(MOCK.errors, e) end end
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false,
  wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false,
  tullarange = false, names = false, tooltipanchor = false, mail = false, reverseengineering = false, idtip = false,
  soloraidframe = false } }
UnitLevel = function() return 20 end
WOW_PROJECT_CAMELOT, WOW_PROJECT_ID = 18, 18 -- (Forever's project, as the game sets it)
local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
E.Load(ADDON_DIR, ns)
local claraL = ns.L
-- (its window and Forever book tab are built at PLAYER_ENTERING_WORLD from the game's own frames: not in this mock)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); E.loggedIn = true; M.Fire("PLAYER_LOGIN")
for _, e in ipairs(M.errors or {}) do out("ERR " .. tostring(e)) end

local wt = ns.WhatsTrainingPrivate
if not wt then
  local listed = false
  for _, m in ipairs(ns.QOL_MODULES) do if m.key == "whatstraining" then listed = true end end
  if not listed then out("(no What's Training? in this version: skipped)"); out("0 failures"); return end
end
check(ns.WhatsTrainingRuns and wt and wt.gameVersion == "forever", "runs, its own shared table, Forever's data")
check(ns.L == claraL and ns.Recipes == nil and ns.Theme == nil, "Clara's own table untouched")
check(wt.Recipes and wt.Recipes[186], "its profession recipes (Mining)")
check(type(SlashCmdList.WHATSTRAINING) == "function", "/wt (ClassicUI's side tab opens it)")
check(type(WT_IgnoredSpells) == "table" and WT_SpellDisplay == "ledger", "its settings, by their own names (saved with Clara's)")
check(ns:CanOpenQol("whatstraining"), "its window from the Improvements tab")
local opened
local slash = SlashCmdList.WHATSTRAINING
SlashCmdList.WHATSTRAINING = function(msg) opened = msg end
ns:OpenQol("whatstraining")
check(opened == "", "the Improvements tab's button runs /wt")
SlashCmdList.WHATSTRAINING = slash
for _, f in ipairs({ "Forever", "Crafting" }) do
  check(wt[f] ~= nil or (f == "Crafting" and wt.AttachCrafting ~= nil), "its Forever files loaded (" .. f .. ")")
end

out("")
out(fails .. " failure(s)")
