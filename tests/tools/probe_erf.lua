local M, S = MOCK, MOCK.state
local E = dofile(TOOLS_DIR .. "/erf_env.lua")
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false, idtip = false, soloraidframe = false } }
local ns = {}
S.class = "PRIEST"; S.locale = "frFR"
E.Load(ADDON_DIR, ns)
E.Frame("player"); E.Frame("party1")
M.Fire("ADDON_LOADED", "ClaraComboPoints"); E.loggedIn = true; M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
io.write("ERF runs: ", tostring(ns.ERFRuns), " obj: ", tostring(ns.ERF), "\n")
