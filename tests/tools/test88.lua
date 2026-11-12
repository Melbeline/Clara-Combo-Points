-- The group role the player picks kept for each character (GameFixes.lua): kept from the game's Set Role menu,
-- the group finder's role and a role check; "No Role" forgets it; set again 2 seconds after joining a group and
-- after a login or reload in a group, out of combat, when the game allows it and the class can take it
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

Enum = Enum or {}
Enum.LFGRole = { Tank = 0, Healer = 1, Damage = 2 }
local role, sets, canPick, available = "NONE", {}, true, { true, true, true }
function UnitGroupRolesAssigned(unit) return unit == "player" and role or "NONE" end
function UnitSetRole(unit, r) sets[#sets + 1] = r if unit == "player" then role = r or "NONE" end return true end
local NAMES = { [0] = "TANK", [1] = "HEALER", [2] = "DAMAGER" }
function UnitSetRoleEnum(unit, r) if unit == "player" then role = NAMES[r] or "NONE" end return true end
function UnitGetAvailableRoles() return available[1], available[2], available[3] end
function AreClassRolesSoftSuggestions() return false end
function CanShowSetRoleButton() return canPick end

local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 50 do M.RunTimer() n = n + 1 end end
local function Kept() local _, r = next(ClaraComboPointsDB.groupRoles or {}) return r end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
check(#sets == 0, "nothing kept, not in a group: nothing set")

out("== Healer picked on the player's own frame (the game's Set Role menu)")
S.group = "party"
UnitSetRoleEnum("player", Enum.LFGRole.Healer)
check(Kept() == "HEALER", "kept for this character")
UnitSetRoleEnum("party1", Enum.LFGRole.Tank)
check(Kept() == "HEALER", "a role the leader gives another member: not the player's")

out("== a new group")
S.group = nil; role = "NONE"; sets = {}
M.Fire("GROUP_LEFT")
S.group = "party"
M.Fire("GROUP_JOINED"); Run()
check(role == "HEALER" and #sets == 1, "set again 2 seconds after joining")
check(Kept() == "HEALER", "Clara's own call keeps it as it was")

out("== a reload in the group, the role already there")
sets = {}
M.Fire("PLAYER_ENTERING_WORLD", false, true); Run()
check(#sets == 0, "the same role: nothing called")

out("== a relog: the game forgot it")
role = "NONE"
M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
check(role == "HEALER" and #sets == 1, "set again after the login")

out("== a zone change")
role, sets = "NONE", {}
M.Fire("PLAYER_ENTERING_WORLD", false, false); Run()
check(#sets == 0, "a zone change: nothing")

out("== joining in a fight")
S.inCombat = true
M.Fire("GROUP_JOINED"); Run()
check(#sets == 0, "in combat: not yet")
S.inCombat = false; M.Fire("PLAYER_REGEN_ENABLED"); Run()
check(role == "HEALER" and #sets == 1, "the fight over: set")

out("== a group finder group (the game's menu has no Set Role)")
role, sets, canPick = "NONE", {}, false
M.Fire("GROUP_JOINED"); Run()
check(#sets == 0, "not allowed by the game: nothing")
canPick = true

out("== a role the class cannot take")
available = { true, false, true }
M.Fire("GROUP_JOINED"); Run()
check(#sets == 0, "healer not offered to the class: nothing")
available = { true, true, true }

out("== the group finder's role (another call of the game)")
UnitSetRole("player", "DAMAGER")
check(Kept() == "DAMAGER", "kept")

out("== No Role picked")
UnitSetRoleEnum("player", nil)
check(ClaraComboPointsDB.groupRoles == nil, "forgotten")
role, sets = "NONE", {}
M.Fire("GROUP_JOINED"); Run()
check(#sets == 0, "nothing set in the next group")

out("== not in a group")
UnitSetRoleEnum("player", Enum.LFGRole.Tank)
S.group = nil; role, sets = "NONE", {}
M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
check(#sets == 0, "alone: nothing")
out(string.format("\n%d failure(s)", fails))
return fails
