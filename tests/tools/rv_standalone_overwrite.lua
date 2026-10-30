-- rv: the built-in copies' own settings when the standalone is enabled again
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
function CopyTable(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
local SA = { NodeSight = true, WeaponSwingTimer = true, Leatrix_Plus = true }
C_AddOns = {
  IsAddOnLoaded = function(name) return SA[name] or false end,
  DoesAddOnExist = function(name) return SA[name] or false end,
  GetAddOnEnableState = function(name) return SA[name] and 2 or 0 end,
  IsAddOnLoadable = function(name) return SA[name] or false end,
}
ClaraComboPointsDB = { qol = { buyemall = false } }
-- the built-in copies were used before (their own settings), the standalones are fresh installs
ClaraNodeSightDB = { scan = true, mapIcons = false, herbs = false, ore = false, arrow = false, shape = 3 }
NodeSightDB = { scan = true, mapIcons = true, herbs = true, ore = true, arrow = true, shape = 1 }
ClaraWSTDB = { profiles = { ["Default"] = { player = { enabled = true, width = 400 } } }, profileKeys = { ["Clara - Realm"] = "Default" } }
WSTProfileDB = { profiles = { ["Default"] = {} }, profileKeys = { ["Clara - Realm"] = "Default" } }
ClaraLeaPlusDB = { __source = "embedded", AutoRepairGear = "On" }
LeaPlusDB = { AutoRepairGear = "Off" }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); local ok, err = pcall(M.Fire, "PLAYER_LOGIN"); out("login: " .. tostring(ok) .. " " .. tostring(err))
pcall(M.Fire, "PLAYER_LOGOUT")
out("states: " .. ns:QolState("nodesight") .. " " .. ns:QolState("wst") .. " " .. ns:QolState("leatrix"))
check(ClaraLeaPlusDB.AutoRepairGear == "On", "Leatrix: the built-in copy's own settings kept")
check(ClaraNodeSightDB.mapIcons == false and ClaraNodeSightDB.shape == 3, "NodeSight: the built-in copy's own settings kept (mapIcons " .. tostring(ClaraNodeSightDB.mapIcons) .. ", shape " .. tostring(ClaraNodeSightDB.shape) .. ")")
local p = ClaraWSTDB.profiles.Default
check(p.player and p.player.width == 400, "WST: the built-in copy's own settings kept (" .. tostring(p.player and p.player.width) .. ")")
out(fails .. " failure(s)")
