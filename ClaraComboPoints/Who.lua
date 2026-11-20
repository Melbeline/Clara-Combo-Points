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
local L = ns.L

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
local exactWord = false -- (searched with the Exact names box ticked: filtered whatever the quotes' setting)
local function Filtering() return word ~= nil and (exactWord or ns:WhoNames()) end

-- A result kept: no name search, the search off, or the word one of its name's
local function Keep(info)
  if not Filtering() then return true end
  return type(info) == "table" and NameHas(info.fullName, word)
end
ns.WhoKeep = Keep -- (ClassicUI Forever's list reads it)

hooksecurefunc(F, "SendWho", function(text)
  word = Word(text)
  -- (the Exact names box ticked: a name alone sent without its quotes, from anywhere (/who lea, the Who window's
  -- line, another addon), taken as one in quotes: the list shows only the players with that first name or surname)
  if not word and ns.WhoExactWord then word = ns.WhoExactWord(text) end
  exactWord = word ~= nil and ns:WhoExact()
end)

-- The game's list: its rows that do not match taken out once it has made them (its own functions untouched), and
-- its count ("15 People Found") the players left. (RemoveAllByPredicate: the game's RemoveByPredicate takes out the
-- first match only.)
local function Filter(box, provider)
  if not Filtering() or type(provider) ~= "table" then return end
  local function Out(data) return type(data) == "table" and data.info ~= nil and not Keep(data.info) end
  if type(provider.RemoveAllByPredicate) == "function" then
    pcall(provider.RemoveAllByPredicate, provider, Out)
  elseif type(provider.RemoveByPredicate) == "function" and type(provider.GetSize) == "function" then
    for _ = 1, provider:GetSize() do -- (one at a time, until none is left)
      local before = provider:GetSize()
      if not pcall(provider.RemoveByPredicate, provider, Out) or provider:GetSize() == before then break end
    end
  else
    return
  end
  local frame = box and box.GetParent and box:GetParent()
  local totals = type(frame) == "table" and frame.WhoFrameTotals
  if totals and totals.SetText and type(WHO_FRAME_TOTAL_TEMPLATE) == "string" and type(provider.GetSize) == "function" then
    pcall(totals.SetText, totals, WHO_FRAME_TOTAL_TEMPLATE:format(provider:GetSize()))
  end
end
---------------------------------------------------------------------------
-- Exact names: a box left of the Who window's search line (the group finder's Who tab), its line made narrower for
-- it. Ticked, a name typed alone is put in quotes as it is typed ("Charlotte"): the search above, for players with
-- that first name or surname only, not every name with it inside. Kept for the account.
---------------------------------------------------------------------------
function ns:WhoExact() return self.sv and self.sv.whoExact == true or false end
local EXACT_SIZE, EXACT_ROOM = 22, 30 -- (the box; the room it takes from the line's left, the gap included)

-- A name alone (one word: no space, digit, quote or filter's hyphen), in quotes; else nil
local function Quoted(text)
  if type(text) ~= "string" or issecretvalue(text) then return nil end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" or text:find('[%s%d"%-]') then return nil end
  return '"' .. text .. '"'
end
-- A name alone in quotes: the name; else nil
local function Unquoted(text)
  if type(text) ~= "string" or issecretvalue(text) then return nil end
  local inner = text:match('^%s*"([^"]*)"%s*$')
  if inner and Quoted(inner) then return inner end
end
ns.WhoQuoted = Quoted -- (for the tests)
-- The box ticked: a name alone, its word, as if typed in quotes; else nil
function ns.WhoExactWord(text)
  if not ns:WhoExact() then return nil end
  local quoted = Quoted(text)
  return quoted and Word(quoted)
end

local exact -- (the box, once made)
local function Requote(edit, on)
  local text = edit:GetText()
  local now = on and Quoted(text) or (not on and Unquoted(text))
  if now then
    edit:SetText(now)
    if edit.SetCursorPosition then edit:SetCursorPosition(on and #now - 1 or #now) end
  end
end
local function MakeExact(frame)
  local edit = type(frame) == "table" and frame.EditBox
  if exact or type(edit) ~= "table" or not (edit.GetPoint and edit.HookScript and edit.GetText) then return end
  local point, rel, relPoint, x, y = edit:GetPoint(1)
  if not point then return end
  exact = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  exact:SetSize(EXACT_SIZE, EXACT_SIZE)
  -- (the line from further right, as much narrower: its search button and its filter stay where they are)
  edit:ClearAllPoints()
  edit:SetPoint(point, rel, relPoint, (x or 0) + EXACT_ROOM, y or 0)
  edit:SetWidth(math.max(60, (edit:GetWidth() or 0) - EXACT_ROOM))
  exact:SetPoint("RIGHT", edit, "LEFT", -8, 0) -- (where the line began; its frame reaches 5 left of it)
  if edit.GetFrameStrata then exact:SetFrameStrata(edit:GetFrameStrata()) end
  exact:SetChecked(ns:WhoExact())
  exact:SetScript("OnShow", function(self) self:SetChecked(ns:WhoExact()) end)
  exact:SetScript("OnClick", function(self)
    local on = self:GetChecked() and true or false
    if ns.sv then ns.sv.whoExact = on or nil end
    Requote(edit, on)
  end)
  exact:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.WHO_EXACT, 1, 1, 1)
    GameTooltip:AddLine(L.WHO_EXACT_TIP, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  exact:SetScript("OnLeave", GameTooltip_Hide)
  -- (sent in quotes, however it was written: the search button, Enter; the server then looks for that name)
  local search = frame.WhoSearch
  if type(search) == "table" and search.HookScript then
    search:HookScript("PreClick", function() if ns:WhoExact() then Requote(edit, true) end end)
  end
  local enter = edit:GetScript("OnEnterPressed")
  edit:SetScript("OnEnterPressed", function(self, ...)
    if ns:WhoExact() then Requote(self, true) end
    if enter then return enter(self, ...) end
  end)
  -- (typed: put in quotes, the cursor before the closing one; emptied of its letters: empty, "Search" shown again)
  edit:HookScript("OnTextChanged", function(self, user)
    if not user or not ns:WhoExact() then return end
    local text = self:GetText()
    if text == '""' then self:SetText("") return end
    Requote(self, true)
  end)
end
ns.WhoExactBox = function() return exact end -- (for the tests)

-- (/who lea typed in the chat goes as typed: the game's own /who left untouched, so that it runs in the game's name,
-- its Who window opened in a fight too; the list it brings is filtered all the same, above)

---------------------------------------------------------------------------
-- Sort by guild: in the Who tab's Filter menu, its Sort submenu (Name, Class, Level), Guild after Level. The game's
-- own sort ("guild": the one its older Who window had), in the order picked below it (ascending or descending): its
-- sort kept as the game keeps its own, so its order lines sort the guilds too and its other sorts take over again
---------------------------------------------------------------------------
local GUILD_SORT = "guild"
local function AddGuildSort(root)
  local util = _G.LFGWhoListFilterUtil
  if type(root) ~= "table" or not root.EnumerateElementDescriptions or type(util) ~= "table" then return end
  if not (MenuUtil and MenuUtil.CreateRadio and MenuUtil.GetElementText and F.SortWho) then return end
  local sortMenu
  for _, d in root:EnumerateElementDescriptions() do
    if MenuUtil.GetElementText(d) == WHO_SORT_LABEL then sortMenu = d end
  end
  if not (sortMenu and sortMenu.EnumerateElementDescriptions and sortMenu.Insert) then return end
  local after
  for i, d in sortMenu:EnumerateElementDescriptions() do
    if MenuUtil.GetElementText(d) == LEVEL then after = i end
  end
  local radio = MenuUtil.CreateRadio(GUILD or L.WHO_SORT_GUILD,
    function() return util.sortMode == GUILD_SORT end,
    function()
      util.sortMode = GUILD_SORT
      F.SortWho(GUILD_SORT, util.sortOrder ~= 2) -- (2: descending, as the game counts it)
      return MenuResponse and MenuResponse.Refresh
    end, GUILD_SORT)
  sortMenu:Insert(radio, after and after + 1 or nil)
end
ns.WhoAddGuildSort = AddGuildSort -- (for the tests)
local sortHooked = false
local function HookSort()
  local util = _G.LFGWhoListFilterUtil
  if sortHooked or type(util) ~= "table" or type(util.InitSortOptions) ~= "function" then return end
  sortHooked = true
  -- (the menu made again each time it opens: Guild added each time, after the game's own)
  hooksecurefunc(util, "InitSortOptions", function(root) pcall(AddGuildSort, root) end)
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
  MakeExact(_G.LFGWhoListFrame)
  HookSort()
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
