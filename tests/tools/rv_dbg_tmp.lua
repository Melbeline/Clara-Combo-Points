local M, S = MOCK, MOCK.state
local print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end io.write(table.concat(t, " "), "\n") end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
local SA = { NodeSight = true }
C_AddOns = {
  IsAddOnLoaded = function(name) return SA[name] or false end,
  DoesAddOnExist = function(name) return SA[name] or false end,
  GetAddOnEnableState = function(name) return SA[name] and 2 or 0 end,
  IsAddOnLoadable = function(name) return SA[name] or false end,
}
print("CopyTable", CopyTable); ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, wst = false } }
ClaraNodeSightDB = { shape = 3 }
NodeSightDB = { shape = 1 }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
print("state", ns:QolState("nodesight"))
local n = 0 for f in pairs(M.eventFrames) do if f._events and f._events.PLAYER_LOGIN then n = n + 1 end end
print("login frames", n)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local ok, err = pcall(M.Fire, "PLAYER_LOGIN")
print(ok, err, ClaraNodeSightDB.shape)
local ok, err = pcall(M.Fire, "PLAYER_LOGOUT")
print(ok, err, ClaraNodeSightDB.shape)
