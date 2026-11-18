-- A character added to the friends list (AltFriends.lua, and ClassicFriendsList's same function): each word's first
-- letter in capital, an accented one whole ("miss émilia" -> "Miss Émilia"), never broken. The game's capitals read
-- UTF-8: a lone lead byte comes back broken (U+FFFD), a whole "é" comes back "É" (imitated here).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
ERR_FRIEND_ADDED_S = "%s added to friends."
function UnitNameUnmodified(u) if u == "player" then return "Lola", "Moon" end end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }

local plainUpper = string.upper
local CAPS = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë", ["à"] = "À", ["â"] = "Â", ["ç"] = "Ç", ["î"] = "Î", ["ô"] = "Ô",
  ["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü", ["ö"] = "Ö", ["ä"] = "Ä" }
local function GameUpper(s)
  local out = {}
  local i = 1
  while i <= #s do
    local b = s:byte(i)
    local len = b < 0x80 and 1 or b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
    local ch = s:sub(i, i + len - 1)
    if #ch < len or (b >= 0x80 and b < 0xC0) then out[#out + 1] = "\239\191\189" -- (a broken sequence)
    elseif len == 1 then out[#out + 1] = plainUpper(ch)
    else out[#out + 1] = CAPS[ch] or ch end
    i = i + len
  end
  return table.concat(out)
end

local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
local function Said(text) for _, line in ipairs(M.chat or {}) do if line:find(text, 1, true) then return true end end return false end
local BROKEN = "\239\191\189"

local function Cases(add, label)
  out("== " .. label)
  for _, case in ipairs({ { "miss émilia", "Miss Émilia" }, { "élodie dupré", "Élodie Dupré" }, { "Émilia", "Émilia" },
    { "çava ölga", "Çava Ölga" }, { "elle woods", "Elle Woods" }, { "lea", "Lea" } }) do
    local got = add(case[1])
    check(got == case[2] and not got:find(BROKEN, 1, true), ("%q: %q (%s)"):format(case[1], case[2], tostring(got)))
  end
end

string.upper = GameUpper
M.chat = {}
Cases(function(typed)
  A.Add(typed)
  for _, alt in pairs(A.List()) do if alt.name:lower():gsub("[^%a]", "") == typed:lower():gsub("[^%a]", "") then return alt.name end end
end, "Clara: added to its list")
check(Said("Miss Émilia added to friends."), "said in the chat whole: \"Miss Émilia added to friends.\"")

-- ClassicFriendsList's own function, as it is in its file
local f = io.open(ADDON_DIR .. "/../../classicfriendslist/ClassicFriendsList/ClassicFriendsList.lua", "rb")
if f then
  local src = f:read("*a"); f:close()
  local s = src:find("local function Normal(name)", 1, true)
  local e = select(2, src:find("\nend\n", s, true))
  local chunk = assert(loadstring("local NAME_MAX, issecret = 77, function() return false end\n" .. src:sub(s, e) .. "\nreturn Normal"))
  local Normal = chunk()
  Cases(Normal, "ClassicFriendsList: its name made")
else
  out("  (ClassicFriendsList's file not found next to Clara's: not checked)")
end
string.upper = plainUpper
out(string.format("\n%d failure(s)", fails))
return fails
