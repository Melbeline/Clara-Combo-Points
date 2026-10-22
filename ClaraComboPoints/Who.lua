-- Clara Combo Points - /who by first name or surname: after a one-word search (/who lea, the
-- Who window's search line), the Who list shows only the players whose first name or surname
-- (WoW Forever's names: "First Surname") is that word, without case or accents: "lea" finds
-- Lea, Léa and Lëa, not Leah. The game searches names, guilds and zones: when no name is the
-- word (/who stormwind, a guild's name), every result shows as before. A search of several
-- words or with a filter (n-, g-, z-, c-, r-, a level) is left alone. On unless turned off
-- (Esc > Options > AddOns > Clara Combo Points).
-- Any Who list reads its results from the game the same way (the game's own, ClassicUI Forever's,
-- others): the two functions it reads them with give the matching ones only, in their order.

local ADDON, ns = ...

local issecretvalue = issecretvalue or function() return false end

function ns:WhoNames() return not self.sv or self.sv.whoNames ~= false end
function ns:SetWhoNames(on)
  if on then self.sv.whoNames = nil else self.sv.whoNames = false end
end

local F = C_FriendList
if not (F and F.GetNumWhoResults and F.GetWhoInfo and F.SendWho) then return end

-- The word searched: one word of letters (accents, apostrophes and hyphens in it too), quoted
-- or not, or a name filter (n-word); else nothing.
local function Word(text)
  if type(text) ~= "string" or issecretvalue(text) then return end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("^[nN]%-", "")
  text = text:gsub('^"(.*)"$', "%1")
  -- one word: no space, digit or quote, a hyphen only inside it; not one of the game's filters
  if text == "" or text:find('[%s%d"]') or text:find("^%-") or text:find("%-$") or text:find("^%a%-") then return end
  local key = ns:SearchKey(text) -- (lower case, accents off; "Anne-Lea" is two words)
  if key == "" or key:find(" ") then return end
  return key
end

-- Does a name (first name, surname, possibly a realm after a hyphen) have the word as one of
-- its words?
local function NameHas(name, word)
  if type(name) ~= "string" or issecretvalue(name) then return false end
  for part in name:gmatch("[^%s%-]+") do
    if ns:SearchKey(part) == word then return true end
  end
  return false
end

local GetNum, GetInfo = F.GetNumWhoResults, F.GetWhoInfo
local word -- the word of the last search (nil: no name search)
local map  -- the results that match, by their place in the filtered list (nil: all of them)

-- Read again each time a list asks how many there are (its update): the game's results change
-- with each search and each sort.
local function Matches(count)
  map = nil
  if not word or not ns:WhoNames() or type(count) ~= "number" or issecretvalue(count) then return end
  local found = {}
  for i = 1, count do
    local ok, info = pcall(GetInfo, i)
    if ok and type(info) == "table" and NameHas(info.fullName, word) then found[#found + 1] = i end
  end
  if #found > 0 then map = found end -- (no name is the word: a guild, a zone... all shown)
end

F.GetNumWhoResults = function(...)
  local shown, total = GetNum(...)
  Matches(shown)
  if map then return #map, #map end
  return shown, total
end

F.GetWhoInfo = function(index, ...)
  if map then
    local real = type(index) == "number" and map[index]
    if not real then return nil end
    return GetInfo(real, ...)
  end
  return GetInfo(index, ...)
end

hooksecurefunc(F, "SendWho", function(text)
  word = Word(text)
  map = nil
end)

ns.WhoWord = Word -- (for the tests)
