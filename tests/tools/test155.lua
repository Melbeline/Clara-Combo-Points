-- Shift+Space sits, the very first login with it (SitKey.lua): the box ticked (even unticked before, by an older
-- version that let a binding of the player's win) and the key taken even when bound (a spell): that binding removed and
-- saved, a line in the chat naming it; the bindings the game loads later in that login taken too; 10 seconds after the
-- world shows, the first time over: a binding of the player's wins again (the box unticked), kept so after a reload.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local binds, overrides, saved = { ["SHIFT-SPACE"] = "SPELL Fireball" }, {}, 0
function GetBindingAction(key, checkOverride)
  if checkOverride and overrides[key] then return overrides[key].action end
  return binds[key] or ""
end
function SetBinding(key, action) binds[key] = action; return true end
function GetCurrentBindingSet() return 1 end
function SaveBindings() saved = saved + 1; M.Fire("UPDATE_BINDINGS") end
function SetOverrideBinding(owner, prio, key, action) overrides[key] = { owner = owner, action = action } end
function ClearOverrideBindings(owner) for k, o in pairs(overrides) do if o.owner == owner then overrides[k] = nil end end end
local said = {}
DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or CreateFrame("Frame")
DEFAULT_CHAT_FRAME.AddMessage = function(_, t) said[#said + 1] = t end

-- an older version's saved state: unticked, a binding of the player's having won
ClaraComboPointsDB = { sitKey = false }
local ns = {}
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.SitKey then out("(no sit key in this version)"); out(""); out("0 failure(s)"); return end

out("== the very first login")
check(ns:SitKey(), "the box ticked")
check(binds["SHIFT-SPACE"] == nil and saved == 1, "the spell's binding of Shift+Space removed, saved")
check(GetBindingAction("SHIFT-SPACE", true) == "SITORSTAND", "Shift+Space: Sit/Stand")
check(#said == 1 and said[1]:find("Fireball", 1, true), "a line in the chat names it (" .. tostring(said[1]) .. ")")
binds["SHIFT-SPACE"] = "MACRO Mount"; M.Fire("UPDATE_BINDINGS") -- (the game loading the character's bindings later)
check(binds["SHIFT-SPACE"] == nil and ns:SitKey() and #said == 2 and said[2]:find("Mount", 1, true), "bindings loaded later in that login: taken too")
out("== 10 seconds after the world shows: the first time over")
M.Fire("PLAYER_ENTERING_WORLD")
for _ = 1, 50 do if not (M.timers and #M.timers > 0) then break end M.RunTimer() end
check(ClaraComboPointsDB.sitKeyInit == true, "kept: not again after a reload")
binds["SHIFT-SPACE"] = "TOGGLEAUTORUN"; M.Fire("UPDATE_BINDINGS")
check(not ns:SitKey() and binds["SHIFT-SPACE"] == "TOGGLEAUTORUN", "the player binding it now: theirs wins, the box unticked")
check(#said == 2, "nothing more said")
out("")
out(fails .. " failure(s)")
