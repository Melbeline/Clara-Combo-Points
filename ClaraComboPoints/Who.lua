-- Clara Combo Points - /who by first name or surname: after a search of one word in quotes
-- (/who "lea", or n-"lea"; in the Who window's search line too), the Who list shows only the
-- players whose first name or surname (WoW Forever's names: "First Surname") is that word, without
-- case or accents: "lea" finds Lea, Léa and Lëa, not Leah nor Leafrunner. Without the quotes (/who
-- lea), the search is the game's own: every name with lea in it. A search of several words or
-- with a filter (g-, z-, c-, r-, a level) is left alone. On unless turned off (Esc > Options >
-- AddOns > Clara Combo Points).
-- The game's own functions are left as they are: the lists shown are filtered (the game's Who list in the group
-- finder window, ClassicUI Forever's), after the game has made them.

local ADDON, ns = ...

local issecretvalue = issecretvalue or function() return false end

function ns:WhoNames() return not self.sv or self.sv.whoNames ~= false end
function ns:SetWhoNames(on)
  if on then self.sv.whoNames = nil else self.sv.whoNames = false end
end

local F = C_FriendList
if not (F and F.GetNumWhoResults and F.GetWhoInfo and F.SendWho) then return end

-- The word searched: one word of letters (accents, apostrophes and hyphens in it too) in quotes,
-- possibly as a name filter (n-"word"); else nothing (the game's own search).
local function Word(text)
  if type(text) ~= "string" or issecretvalue(text) then return end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("^[nN]%-", "")
  text = text:match('^"(.*)"$')
  -- one word: no space, digit or quote, a hyphen only inside it
  if not text or text == "" or text:find('[%s%d"]') or text:find("^%-") or text:find("%-$") then return end
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

local word -- the word of the last search (nil: no name search)

-- A result kept: no name search, the search off, or the word one of its name's
local function Keep(info)
  if not word or not ns:WhoNames() then return true end
  return type(info) == "table" and NameHas(info.fullName, word)
end
ns.WhoKeep = Keep -- (ClassicUI Forever's list reads it)

hooksecurefunc(F, "SendWho", function(text)
  word = Word(text)
end)

-- The game's list: its rows that do not match taken out once it has made them (its own functions untouched)
local function Filter(box, provider)
  if not word or not ns:WhoNames() or type(provider) ~= "table" or type(provider.RemoveByPredicate) ~= "function" then return end
  pcall(provider.RemoveByPredicate, provider, function(data)
    return type(data) == "table" and data.info ~= nil and not Keep(data.info)
  end)
end
local hooked = {}
local function Watch(frame)
  local box = frame and frame.ScrollBox
  if type(box) ~= "table" or hooked[box] or type(box.SetDataProvider) ~= "function" then return end
  hooked[box] = true
  hooksecurefunc(box, "SetDataProvider", Filter)
end
local function WatchAll()
  Watch(_G.LFGWhoListFrame) -- (WoW Forever: the Who list is the group finder's third tab)
  Watch(_G.WhoFrame)
end
WatchAll()
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
  if name == "Blizzard_GroupFinder_VanillaStyle" or name == "Blizzard_FriendsFrame" then WatchAll() end
  if hooked[_G.LFGWhoListFrame and _G.LFGWhoListFrame.ScrollBox or 0] then self:UnregisterEvent("ADDON_LOADED") end
end)

ns.WhoWord = Word -- (for the tests)
