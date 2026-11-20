-- A module's own addon turned off (and back on) for the character the way the game's addon list does it: by the
-- character's GUID, the one StandaloneRuns reads (by its first name alone, a WoW Forever character "First Surname"
-- was not the one turned off: Leatrix Plus's own addon ran again at each login, Clara's never)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false } }
-- (each character's enabled addons, by the GUID as the game keeps them; a name the game does not know changes nothing)
local GUID = "Player-1"
local enabled = { [GUID] = { idTip = true } }
local calls = {}
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(name) return name == "idTip" end
C_AddOns.DoesAddOnExist = function(name) return name == "idTip" end
C_AddOns.GetAddOnEnableState = function(name, who) return (enabled[who] and enabled[who][name]) and 2 or 0 end
C_AddOns.IsAddOnLoadable = function(name, who) return (enabled[who] and enabled[who][name]) and true or false end
C_AddOns.EnableAddOn = function(name, who) calls[#calls + 1] = { "on", name, who }; if enabled[who] then enabled[who][name] = true end end
C_AddOns.DisableAddOn = function(name, who) calls[#calls + 1] = { "off", name, who }; if enabled[who] then enabled[who][name] = nil end end
C_AddOns.SaveAddOns = function() end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")

check(ns:QolState("idtip") == "standalone", "idTip's own addon runs this session")
local last = calls[#calls]
check(last and last[1] == "off" and last[2] == "idTip" and last[3] == GUID, "turned off for the character by its GUID (" .. tostring(last and last[3]) .. ")")
check(C_AddOns.GetAddOnEnableState("idTip", UnitGUID("player")) == 0, "so the next session finds it off: the built-in one runs")

ns:SetQolEnabled("idtip", false)
last = calls[#calls]
check(last and last[1] == "on" and last[3] == GUID and enabled[GUID].idTip, "the built-in one turned off: its own addon back on, by the GUID")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
