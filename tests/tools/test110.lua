-- Leatrix's friend check (FriendCheck: its party invites accepted from friends, invited on a whispered word) counts the
-- player's characters on another WoW account of the same Battle.net account, by their GUID: the game's own test
-- (C_AccountInfo.IsGUIDRelatedToLocalAccount), else their Battle.net account (C_BattleNet.GetAccountInfoByGUID) against
-- the player's (BNGetInfo); a friend's or a stranger's character is not one; secrets and errors are passed over.
-- Its two callers hand it the GUID: the whisper's (12th argument), the invite's (PARTY_INVITE_REQUEST's inviterGUID).
local out = function(s) io.write(tostring(s), "\n") end
do local f = io.open(ADDON_DIR .. "/Modules/LeatrixPlus/Leatrix_Plus.lua", "rb")
  if not f then out("  ok   not in this version (Leatrix Plus: not in Light)"); out("0 failure(s)"); return 0 end
  f:close() end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local f = assert(io.open(ADDON_DIR .. "/Modules/LeatrixPlus/Leatrix_Plus.lua", "rb"))
local src = f:read("*a"); f:close()
local function Extract(head)
  local s = src:find(head, 1, true)
  assert(s, "not found: " .. head)
  local e = select(2, src:find("\n\tend\n", s, true))
  return src:sub(s, e)
end
local body = Extract("function LeaPlusLC:InviterGUID(...)") .. Extract("function LeaPlusLC:FriendCheck(name, guid)")

-- the secret values: a table the test marks
local SECRET = setmetatable({}, { __mode = "k" })
local function Secret(v) local t = { v = v }; SECRET[t] = true; return t end

local api = {}
local env = setmetatable({}, { __index = function(_, k) if api[k] ~= nil then return api[k] end return _G[k] end })
api.issecretvalue = function(v) return type(v) == "table" and SECRET[v] == true end
api.strsplit = function(sep, s, n)
  local a, b = s:find(sep, 1, true)
  if not a then return s end
  return s:sub(1, a - 1), s:sub(b + 1)
end
api.LeaPlusLC = { FriendlyGuild = "Off", FriendlyCommunities = "Off" }
local alts = {}
api.ClaraNS = { AltFriends = { IsAlt = function(n) return alts[n] == true end } }
local friends, bnFriends = {}, {}
api.C_FriendList = { ShowFriends = function() end, GetNumFriends = function() return #friends end,
  GetFriendInfoByIndex = function(i) return friends[i] end }
api.BNGetNumFriends = function() return #bnFriends end
local related, accounts, me = nil, {}, { 7, "Mel#1234" }
api.C_AccountInfo = { IsGUIDRelatedToLocalAccount = function(g) return related and related(g) end }
api.C_BattleNet = {
  GetFriendNumGameAccounts = function(i) return #bnFriends[i] end,
  GetFriendGameAccountInfo = function(i, j) return bnFriends[i][j] end,
  GetAccountInfoByGUID = function(g) return accounts[g] end,
}
api.BNGetInfo = function() return me[1], me[2] end
local chunk = assert(loadstring(body, "=FriendCheck"))
setfenv(chunk, env)
chunk()
local LC = api.LeaPlusLC
local function Check(name, guid) local ok, r = pcall(LC.FriendCheck, LC, name, guid); return ok, r end

local REROLL, FRIEND, STRANGER = "Player-4398-0A1B2C3D", "Player-4398-0F0F0F0F", "Player-4398-01234567"
local LOCAL = { [REROLL] = true }

out("== the game's own test: the same Battle.net account")
related = function(g) return LOCAL[g] == true end
local ok, r = Check("Lune Nova", REROLL)
check(ok and r == true, "a reroll on the other WoW account: a friend")
ok, r = Check("Lune Nova-Forever", REROLL)
check(ok and r == true, "whatever its realm")
ok, r = Check("Bob Stone", STRANGER)
check(ok and not r, "a stranger: not one")

out("== its Battle.net account against the player's (the game's test gone or saying no)")
api.C_AccountInfo.IsGUIDRelatedToLocalAccount = nil
accounts[REROLL] = { bnetAccountID = 7, battleTag = "Mel#1234" }
accounts[FRIEND] = { bnetAccountID = 9, battleTag = "Bob#4321", isFriend = true }
ok, r = Check("Lune Nova", REROLL)
check(ok and r == true, "the same account ID: a friend")
accounts[REROLL] = { battleTag = "Mel#1234" }
ok, r = Check("Lune Nova", REROLL)
check(ok and r == true, "no account ID, the same BattleTag: a friend")
ok, r = Check("Bob Stone", FRIEND)
check(ok and not r, "a Battle.net friend's character, not in the friends lists: not one by its account")
bnFriends = { { { characterName = "Bob Stone", clientProgram = "WoW" } } }
ok, r = Check("Bob Stone", FRIEND)
check(ok and r == true, "the same, as a Battle.net friend's character in game: one (Leatrix's own check, kept)")
bnFriends = {}
me = { nil, nil }
accounts[REROLL] = { bnetAccountID = 7, battleTag = "Mel#1234" }
ok, r = Check("Lune Nova", REROLL)
check(ok and not r, "Battle.net offline (no account of the player's): not one, no error")
me = { 7, "Mel#1234" }

out("== secrets and errors passed over")
ok, r = Check("Lune Nova", Secret(REROLL))
check(ok and not r, "a secret GUID: not used, no error")
accounts[REROLL] = { bnetAccountID = Secret(7), battleTag = Secret("Mel#1234") }
ok, r = Check("Lune Nova", REROLL)
check(ok and not r, "a secret account ID and BattleTag: not one, no error")
api.C_AccountInfo.IsGUIDRelatedToLocalAccount = function() error("bad GUID") end
api.C_BattleNet.GetAccountInfoByGUID = function() error("bad GUID") end
ok, r = Check("Lune Nova", REROLL)
check(ok and not r, "the game's calls failing: not one, no error")
api.C_AccountInfo.IsGUIDRelatedToLocalAccount = function() return Secret(true) end
ok, r = Check("Lune Nova", REROLL)
check(ok and not r, "a secret answer: not one, no error")
ok, r = Check("Lune Nova", "Creature-0-1-2-3")
check(ok and not r, "not a player's GUID: not asked")
api.C_AccountInfo.IsGUIDRelatedToLocalAccount = function() return true end
ok, r = Check(nil, REROLL)
check(ok and r == nil, "no name (the Battle.net app's whisper): nothing, as before")

out("== by first name and surname, with no GUID (Clara's list, the gold tracker)")
alts["Charlotte Moon"] = true
ok, r = Check("Charlotte Moon", nil)
check(ok and r == true, "a reroll in Clara's list, no GUID: a friend")

out("== the invite's GUID")
local guid = LC:InviterGUID(false, false, true, true, false, false, REROLL, false)
check(guid == REROLL, "PARTY_INVITE_REQUEST: its inviterGUID found")
check(LC:InviterGUID(false, Secret(REROLL)) == nil, "a secret one: not taken")
out(string.format("\n%d failure(s)", fails))
return fails
