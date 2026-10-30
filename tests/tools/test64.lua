-- Enhanced Raid Frames' own addon enabled: it runs this session (the built-in one and its libraries do
-- not load), it is turned off for the character, and its settings are carried over at logout
local M, S = MOCK, MOCK.state
local E = dofile(TOOLS_DIR .. "/erf_env.lua")
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { whatstraining = false, doesitdie = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false, idtip = false, soloraidframe = false } }
local disabled = {}
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(name) return name == "EnhancedRaidFrames" end
C_AddOns.DoesAddOnExist = function(name) return name == "EnhancedRaidFrames" end
C_AddOns.GetAddOnEnableState = function(name) return disabled[name] and 0 or 2 end
C_AddOns.IsAddOnLoadable = function(name) return not disabled[name] end
C_AddOns.EnableAddOn = function(name) disabled[name] = nil end
C_AddOns.DisableAddOn = function(name) disabled[name] = true end
C_AddOns.SaveAddOns = function() end
EnhancedRaidFramesDB = { profileKeys = { ["Lola - Forever"] = "Default" }, profiles = { Default = { rangeAlpha = 0.3 } } }

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
E.Load(ADDON_DIR, ns)
if ns:QolState("enhancedraidframes") == nil then out("(no Enhanced Raid Frames in this version)"); out(""); out("0 failure(s)"); return end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); E.loggedIn = true; M.Fire("PLAYER_LOGIN")

check(ns:QolState("enhancedraidframes") == "standalone" and not ns.ERFRuns and ns.ERF == nil, "its own addon runs; the built-in one not loaded")
check(LibStub("AceBucket-3.0", true) == nil and LibStub("LibDeflate", true) == nil, "nor its libraries")
check(disabled.EnhancedRaidFrames, "its own addon turned off for the character, from the next reload")
M.Fire("PLAYER_LOGOUT")
check(ClaraEnhancedRaidFramesDB and ClaraEnhancedRaidFramesDB.profiles.Default.rangeAlpha == 0.3, "its settings carried over")
EnhancedRaidFramesDB.profiles.Default.rangeAlpha = 0.9
M.Fire("PLAYER_LOGOUT")
check(ClaraEnhancedRaidFramesDB.profiles.Default.rangeAlpha == 0.3, "once only (the built-in one's are kept after)")

out("")
out(fails .. " failure(s)")
