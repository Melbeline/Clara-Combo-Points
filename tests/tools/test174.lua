-- Clique built in, its own addon still enabled (the first login with Clara): the built-in one steps aside (none of
-- its files run) and the standalone's bindings (CliqueDB3, from the WTF folder) are carried into ClaraCliqueDB at
-- login and logout: the first time whole; then only this character's own part (its profile, by AceDB's names on WoW
-- Forever, "First Surname", and "First - Realm"; its settings) and the profiles new since; another character's
-- profile changed with the built-in one is kept.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  classicui = false, tullarange = false, tooltipanchor = false } }
-- the standalone Clique enabled and loaded before Clara (## OptionalDeps)
C_AddOns = C_AddOns or {}
local loaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) if name == "Clique" then return true end return loaded and loaded(name) end
function UnitNameUnmodified(u) if u == "player" then return "Lia", "Moon" end end
GetRealmName = function() return "Forever" end
CopyTable = CopyTable or function(t)
  local function copy(x) if type(x) ~= "table" then return x end local o = {} for k, v in pairs(x) do o[k] = copy(v) end return o end
  return copy(t)
end
local bindings = function(spell) return { bindings = { { key = "BUTTON3", type = "spell", spell = spell, sets = { default = true } } } } end
CliqueDB3 = {
  profileKeys = { ["Lia Moon"] = "Lia Moon", ["Elle Woods"] = "Elle Woods" },
  profiles = { ["Lia Moon"] = bindings("Cure Disease"), ["Elle Woods"] = bindings("Renew") },
  char = { ["Lia Moon"] = { blacklist = {} } },
}
ClaraCliqueDB = nil
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.withClique = true
M.LoadAddon(ADDON_DIR, ns)
if ns:QolState("clique") == nil then out("(no Clique in this version)"); out(""); out("0 failure(s)"); return end
check(ns:QolState("clique") == "standalone" and not ns.CliqueRuns and ns.CliquePrivate == nil, "its own addon runs: the built-in one steps aside")
check(_G.Clique == nil, "none of its files ran (no global Clique of ours)")
check(type(ns.CliqueCarry) == "function", "the carrying ready")

out("== the first login: everything carried")
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
check(type(ClaraCliqueDB) == "table" and ClaraCliqueDB ~= CliqueDB3, "a copy, not the same table")
check(ClaraCliqueDB.profiles["Lia Moon"].bindings[1].spell == "Cure Disease" and ClaraCliqueDB.profiles["Elle Woods"].bindings[1].spell == "Renew",
  "every character's bindings carried")

out("== later: this character's own part only")
ClaraCliqueDB.profiles["Elle Woods"].bindings[1].spell = "Flash Heal" -- (changed with the built-in one, on Elle)
CliqueDB3.profiles["Lia Moon"].bindings[1].spell = "Abolish Disease"  -- (changed with the standalone, on Lia)
CliqueDB3.profiles["Elle Woods"].bindings[1].spell = "Renew"
CliqueDB3.profiles["Spare"] = bindings("Dispel Magic")
M.Fire("PLAYER_LOGOUT")
check(ClaraCliqueDB.profiles["Lia Moon"].bindings[1].spell == "Abolish Disease", "Lia's own profile (AceDB's \"First Surname\"): carried again")
check(ClaraCliqueDB.profiles["Elle Woods"].bindings[1].spell == "Flash Heal", "Elle's, changed with the built-in one: kept")
check(ClaraCliqueDB.profiles["Spare"] and ClaraCliqueDB.profiles["Spare"].bindings[1].spell == "Dispel Magic", "a profile new since: carried")

out("")
out(fails .. " failure(s)")
