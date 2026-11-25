-- Shift+Space sits (SitKey.lua): on by default, the game's Sit/Stand on Shift+Space through an override binding of the
-- addon's, the player's bindings untouched; a key the player binds to Shift+Space themselves: the override let go, the
-- box unticked (at login too, a binding already there); ticked again: the key taken back, the player's binding of it
-- removed and saved; in a fight nothing done until it ends; untick: the override gone.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local binds, overrides, saved = {}, {}, 0
function GetBindingAction(key, checkOverride)
  if checkOverride and overrides[key] then return overrides[key].action end
  return binds[key] or ""
end
function SetBinding(key, action) assert(not S.inCombat, "SetBinding in combat"); binds[key] = action; return true end
function GetCurrentBindingSet() return 1 end
function SaveBindings() assert(not S.inCombat, "SaveBindings in combat"); saved = saved + 1; M.Fire("UPDATE_BINDINGS") end
function SetOverrideBinding(owner, prio, key, action)
  assert(not S.inCombat, "override binding in combat"); overrides[key] = { owner = owner, action = action }
end
function ClearOverrideBindings(owner)
  assert(not S.inCombat, "override binding in combat")
  for k, o in pairs(overrides) do if o.owner == owner then overrides[k] = nil end end
end
local function Player(key, action) binds[key] = action; M.Fire("UPDATE_BINDINGS") end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.SitKey then out("(no sit key in this version)"); out(""); out("0 failure(s)"); return end

out("== on by default")
check(ns:SitKey(), "the box ticked")
check(GetBindingAction("SHIFT-SPACE", true) == "SITORSTAND", "Shift+Space: the game's Sit/Stand")
check(binds["SHIFT-SPACE"] == nil and saved == 0, "the player's bindings untouched")
Player("SPACE", "JUMP")
check(ns:SitKey() and ns:SitKeyBound(), "another key bound: nothing changes")
Player("SHIFT-SPACE", "SITORSTAND")
check(ns:SitKey() and ns:SitKeyBound(), "the player's Shift+Space on Sit/Stand too: kept")
Player("SHIFT-SPACE", nil)

out("== the player binds Shift+Space")
Player("SHIFT-SPACE", "TOGGLEAUTORUN")
check(not ns:SitKey() and ClaraComboPointsDB.sitKey == false, "the box unticked")
check(GetBindingAction("SHIFT-SPACE", true) == "TOGGLEAUTORUN", "their key works: the override gone")
check(binds["SHIFT-SPACE"] == "TOGGLEAUTORUN" and saved == 0, "their binding kept")

out("== ticked again")
ns:SetSitKey(true)
check(ns:SitKey(), "the box ticked")
check(binds["SHIFT-SPACE"] == nil and saved == 1, "their binding of Shift+Space removed, saved")
check(GetBindingAction("SHIFT-SPACE", true) == "SITORSTAND", "Sit/Stand on the key again")
check(ns:SitKey() and ns:SitKeyBound(), "still ticked after the game's update")

out("== in a fight")
S.inCombat = true
M.Fire("PLAYER_REGEN_DISABLED")
local ok = pcall(Player, "SHIFT-SPACE", "TOGGLEAUTORUN")
check(ok, "a binding changed in a fight: no blocked call")
check(ns:SitKeyBound(), "nothing done yet")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(not ns:SitKey() and not ns:SitKeyBound(), "the fight over: let go, unticked")
S.inCombat = true
ok = pcall(ns.SetSitKey, ns, true)
check(ok and ns:SitKey() and not ns:SitKeyBound() and binds["SHIFT-SPACE"] == "TOGGLEAUTORUN", "ticked in a fight: waits")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(ns:SitKey() and ns:SitKeyBound() and binds["SHIFT-SPACE"] == nil, "the fight over: the key taken back")

out("== unticked")
ns:SetSitKey(false)
check(GetBindingAction("SHIFT-SPACE", true) == "" and not ns:SitKeyBound(), "the override gone")
check(binds["SHIFT-SPACE"] == nil, "nothing bound in its place")

out("== a binding there before the first login")
binds = { ["SHIFT-SPACE"] = "MOVEBACKWARD" }
ClaraComboPointsDB.sitKey = nil
M.Fire("UPDATE_BINDINGS")
check(not ns:SitKey() and binds["SHIFT-SPACE"] == "MOVEBACKWARD" and not ns:SitKeyBound(), "the player's: kept, the box unticked")
out("")
out(fails .. " failure(s)")
