-- Clara's characters (AltFriends.lua): the character's sex, for its class's name as the game says it since TBC ("Prêtresse" for a woman):
-- its own addon says it after its answer ("S|3"), the game tells it of one heard in the chat (its sender's GUID) or seen
-- (the target), one's own characters keep theirs at login; an answer of ours says ours
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function Ours() local t = {} for _, m in ipairs(M.addonSent) do if m[1] == "ClaraFriends" then t[#t + 1] = m end end return t end

LOCALIZED_CLASS_NAMES_MALE = { PRIEST = "Prêtre", MAGE = "Mage", HUNTER = "Chasseur" }
LOCALIZED_CLASS_NAMES_FEMALE = { PRIEST = "Prêtresse", MAGE = "Mage", HUNTER = "Chasseresse" }
FRIENDS_LEVEL_TEMPLATE = "Niveau %d %s"
local sexOf = { player = 3 }
function UnitSex(u) return sexOf[u] end
local unitNames = {}
local realUnitName, realIsPlayer = UnitName, UnitIsPlayer
function UnitName(u) if unitNames[u] then return unitNames[u][1], unitNames[u][2] end return realUnitName(u) end
function UnitIsPlayer(u) if unitNames[u] then return true end return realIsPlayer and realIsPlayer(u) end
local guids = {}
function GetPlayerInfoByGUID(g) local x = guids[g] if x then return "Chasseur", "HUNTER", "Elfe", "NightElf", x end end
FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()
local ns = {}
S.class = "PRIEST"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
ns.sv.altFriends = { ["charlotte moon"] = { name = "Charlotte Moon" }, ["bob twink"] = { name = "Bob Twink" },
  ["lune belle"] = { name = "Lune Belle" } }
local DB = ns.sv
M.Fire("PLAYER_LOGIN")
check(type(DB.sexes) == "table" and next(DB.sexes) ~= nil, "this character's sex kept for the account")

out("== her addon's answer, then her sex")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|26|PRIEST|Darnassus", "WHISPER", "Charlotte Moon")
check(A.Facts("Charlotte Moon").sex == nil, "not yet")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "S|3", "WHISPER", "Charlotte Moon")
local facts = A.Facts("Charlotte Moon")
check(facts.sex == 3 and DB.sexes["charlotte moon"] == 3, "her sex: a woman, kept")
local button = CreateFrame("Button", nil, UIParent)
button.name = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
button.info = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
button.status = button:CreateTexture(nil, "ARTWORK")
A.DrawRow(button, { buttonType = "claraAlt", alt = ns.sv.altFriends["charlotte moon"] })
check(button.name._text and button.name._text:find("Niveau 26 Prêtresse", 1, true) ~= nil, "her row: Prêtresse (" .. tostring(button.name._text) .. ")")

out("== our answer to a hello: ours after it")
M.addonSent = {}
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "?", "WHISPER", "Bob Twink")
local sent = Ours()
check(#sent == 2 and sent[1][2]:find("^I|") and sent[2][2] == "S|3", "I|... then S|3 (" .. #sent .. ")")

out("== heard in the chat: the game's word on its sender")
guids["Player-1-ABC"] = 2
M.Fire("CHAT_MSG_WHISPER", "salut", "Bob Twink", "", "", "", "", 0, 0, "", 0, 0, "Player-1-ABC")
check(A.Facts("Bob Twink").sex == 2, "Bob: a man")
check(A.Facts("Bob Twink").class == "HUNTER", "and his class from the game, without an addon of his (" .. tostring(A.Facts("Bob Twink").class) .. ")")

out("== seen as the target")
unitNames.target = { "Lune", "Belle" }
sexOf.target = 3
Constants = Constants or {}
Constants.CharacterNameSeparatorConsts = Constants.CharacterNameSeparatorConsts or { CHARACTERNAME_SURNAME_SEPARATOR = " " }
local realUnitClass, realUnitLevel = UnitClass, UnitLevel
function UnitClass(u) if u == "target" then return "Mage", "MAGE" end return realUnitClass(u) end
function UnitLevel(u) if u == "target" then return 23 end return realUnitLevel(u) end
M.Fire("PLAYER_TARGET_CHANGED")
check(A.Facts("Lune Belle").sex == 3, "Lune: a woman")
check(A.Facts("Lune Belle").class == "MAGE" and A.Facts("Lune Belle").level == 23, "her class and level from the game")
out(string.format("\n%d failure(s)", fails))
return fails
