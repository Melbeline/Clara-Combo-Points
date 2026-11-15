-- Leatrix's friends (its party invites accepted from friends, invited on a whispered word: its FriendCheck) count the
-- player's characters and Clara's list of characters by first name AND surname (WoW Forever's names are unique by both):
-- a reroll known by Clara's list or the gold tracker (its first name and surname kept apart), whatever the realm or
-- case; another character with the same first name and another surname is not one; the character itself is not one
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ClaraComboPointsDB = { qol = setmetatable({}, { __index = function() return false end }),
  altFriends = { ["charlotte moon"] = { name = "Charlotte Moon" }, ["lune stone"] = { name = "Lune Stone" } } }
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " ", CHARACTERNAME_REALMNAME_SEPARATOR = "-" }
function UnitNameUnmodified(u) if u == "player" then return "Clara", "Moon" end end
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
-- the gold tracker: this account's characters and another account's (the sync), first name and surname apart
ns.Money = ns.Money or {}
ns.Money.db = { chars = { ["Melbeline-Forever"] = { n = "Melbeline", s = "Moon" },
  ["Elle-Forever"] = { n = "Elle Woods", s = "Woods" }, ["Solo-Forever"] = { n = "Solo" } } }
local IsAlt = ns.AltFriends.IsAlt
out("== by first name and surname")
check(IsAlt("Charlotte Moon"), "in Clara's list: Charlotte Moon")
check(IsAlt("Charlotte Moon-Forever") and IsAlt("charlotte  moon"), "whatever its realm, case, spacing")
check(IsAlt("Melbeline Moon"), "a reroll the gold tracker knows (first name and surname kept apart)")
check(IsAlt("Elle Woods-Forever"), "its first name already holding its surname: not doubled")
check(not IsAlt("Charlotte Stone"), "the same first name, another surname: not one")
check(not IsAlt("Charlotte"), "a first name alone: not one (a character with a surname)")
check(IsAlt("Solo"), "a character with no surname: by its name alone")
check(not IsAlt("Clara Moon") and not IsAlt("Clara Moon-Forever"), "the character itself: not one")
check(not IsAlt(MOCK.Secret("Charlotte Moon")) and not IsAlt(nil) and not IsAlt(""), "a secret, no name: not one, no error")
check(IsAlt("Lune Stone"), "a friend's character in Clara's list")
out(string.format("\n%d failure(s)", fails))
return fails
