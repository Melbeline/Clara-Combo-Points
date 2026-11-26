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

-- (the column header's box, further down: defined before the game's functions are looked for, its box always on the page)
local ApplyHeader = function() end
function ns:WhoHeader() return not (self.sv and self.sv.whoHeader == false) end
function ns:SetWhoHeader(on)
  if self.sv then
    if on then self.sv.whoHeader = nil else self.sv.whoHeader = false end
  end
  ApplyHeader()
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

---------------------------------------------------------------------------
-- The column header, as vanilla's Who window had it: Name, Zone (its menu: Zone, Guild or Race), Lvl, Class, above the
-- group finder's Who list. A click sorts the list: Name A to Z, again Z to A; Lvl the highest first, again the lowest;
-- Class (and Zone, Guild, Race) A to Z, again Z to A, the names A to Z within each; the pick kept for the account. The
-- list sorted here, as the game hands it (its own functions untouched). The game's Filter button hidden (its filters
-- left as they start: none). A box on Clara's page (on by default): off, the game's own as it was.
---------------------------------------------------------------------------
ApplyHeader = function() end

local FIELD = { name = "fullName", level = "level", class = "classStr", zone = "area", guild = "fullGuildName", race = "raceStr" }
local function Sort()
  local s = ns.sv and type(ns.sv.whoSort) == "table" and ns.sv.whoSort or nil
  local key = s and FIELD[s.k] and s.k or nil
  return key, key and s.d == true or false
end
local function Variable()
  local v = ns.sv and ns.sv.whoVariable
  return (v == "guild" or v == "race") and v or "zone"
end
local function Key(text)
  if type(text) ~= "string" or issecretvalue(text) then return "" end
  return ns:SearchKey(text)
end

-- Two rows of the list (their data: { index, info }) in the order picked
local function Before(a, b)
  local key, desc = Sort()
  local ia, ib = type(a) == "table" and a.info or {}, type(b) == "table" and b.info or {}
  local na, nb = Key(ia.fullName), Key(ib.fullName)
  if key == "level" then
    local la, lb = tonumber(ia.level) or 0, tonumber(ib.level) or 0
    if la ~= lb then if desc then return la > lb end return la < lb end
    return na < nb
  elseif key == "name" then
    if na ~= nb then if desc then return na > nb end return na < nb end
    return (tonumber(a.index) or 0) < (tonumber(b.index) or 0)
  end
  local fa, fb = Key(ia[FIELD[key]]), Key(ib[FIELD[key]])
  if fa ~= fb then
    if fa == "" then return false elseif fb == "" then return true end -- (none, no guild: last)
    if desc then return fa > fb end
    return fa < fb
  end
  return na < nb
end
ns.WhoBefore = Before -- (for the tests)

local function SortList(provider)
  if not (ns:WhoHeader() and Sort()) or type(provider) ~= "table" then return end
  if provider.sortComparator == Before and type(provider.Sort) == "function" then
    pcall(provider.Sort, provider)
  elseif type(provider.SetSortComparator) == "function" then
    pcall(provider.SetSortComparator, provider, Before)
  end
end

local header, tabs = nil, {}
local TAB_TEXT = function(key)
  if key == "name" then return NAME or L.WHO_COL_NAME end
  if key == "level" then return LEVEL_ABBR or L.WHO_COL_LEVEL end
  if key == "class" then return CLASS or L.WHO_COL_CLASS end
  if key == "guild" then return GUILD or L.WHO_COL_GUILD end
  if key == "race" then return RACE or L.WHO_COL_RACE end
  return ZONE or L.WHO_COL_ZONE
end

-- The tabs' texts: the one sorted in gold
local function Paint()
  if not header then return end
  local key = Sort()
  for k, tab in pairs(tabs) do
    local on = key == k or (k == "variable" and key == Variable())
    tab.label:SetText(TAB_TEXT(k == "variable" and Variable() or k))
    if on then tab.label:SetTextColor(1, 0.82, 0) else tab.label:SetTextColor(1, 1, 1) end
  end
end

local function Resort(frame)
  Paint()
  local box = frame and frame.ScrollBox
  local provider = type(box) == "table" and type(box.GetDataProvider) == "function" and box:GetDataProvider() or nil
  SortList(provider)
end

-- A click on a tab: that column (again: the other way); a column's first click: Lvl the highest first, the others A to Z
local function Pick(frame, key)
  local now, desc = Sort()
  if now == key then desc = not desc else desc = key == "level" end
  if ns.sv then ns.sv.whoSort = { k = key, d = desc or nil } end
  if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
  Resort(frame)
end
ns.WhoPick = function(key) Pick(_G.LFGWhoListFrame, key) end -- (for the tests)

local function Tab(parent, key)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(24)
  local file = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"
  local left = b:CreateTexture(nil, "BACKGROUND")
  left:SetTexture(file); left:SetTexCoord(0, 0.078125, 0, 0.75); left:SetSize(5, 24); left:SetPoint("TOPLEFT")
  local right = b:CreateTexture(nil, "BACKGROUND")
  right:SetTexture(file); right:SetTexCoord(0.90625, 0.96875, 0, 0.75); right:SetSize(4, 24); right:SetPoint("TOPRIGHT")
  local middle = b:CreateTexture(nil, "BACKGROUND")
  middle:SetTexture(file); middle:SetTexCoord(0.078125, 0.90625, 0, 0.75)
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT"); middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
  glow:SetBlendMode("ADD")
  glow:SetPoint("TOPLEFT", -2, 5); glow:SetPoint("BOTTOMRIGHT", 2, -7)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("LEFT", 8, 0)
  b.label:SetJustifyH("LEFT")
  b.key = key
  tabs[key] = b
  return b
end

local ROOM = 6 -- (the list that much lower for the header)
local function MakeHeader(frame)
  local box = type(frame) == "table" and frame.ScrollBox
  if header or type(box) ~= "table" or not box.GetPoint then return end
  header = CreateFrame("Frame", nil, frame)
  header:SetHeight(24)
  header:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -2, 1)
  header:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 2, 1)
  header:SetFrameLevel((frame:GetFrameLevel() or 0) + 5)
  for _, key in ipairs({ "name", "variable", "level", "class" }) do
    local tab = Tab(header, key)
    tab:SetScript("OnClick", function() Pick(frame, key == "variable" and Variable() or key) end)
  end
  -- (Zone's menu: Zone, Guild or Race, sorted by it as it is picked)
  local arrow = CreateFrame("Button", nil, tabs.variable)
  arrow:SetSize(20, 20)
  arrow:SetPoint("RIGHT", -3, 0)
  arrow:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  arrow:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
  arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  arrow:SetScript("OnClick", function(self)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(self, function(_, root)
      for _, v in ipairs({ "zone", "guild", "race" }) do
        root:CreateRadio(TAB_TEXT(v), function() return Variable() == v end, function()
          if ns.sv then ns.sv.whoVariable = v ~= "zone" and v or nil; ns.sv.whoSort = { k = v } end
          Resort(frame)
        end, v)
      end
    end)
  end)
  tabs.variable.arrow = arrow
  ns.WhoVariablePick = function(v) -- (for the tests: the menu's pick)
    if ns.sv then ns.sv.whoVariable = v ~= "zone" and v or nil; ns.sv.whoSort = { k = v } end
    Resort(frame)
  end
  -- (the widths: Name 32%, Zone 36%, Lvl 12%, Class the rest)
  local function Lay()
    local w = header:GetWidth() or 0
    if w <= 0 then return end
    local x = 0
    for _, part in ipairs({ { "name", 0.32 }, { "variable", 0.36 }, { "level", 0.12 }, { "class", 0 } }) do
      local tab = tabs[part[1]]
      local width = part[2] > 0 and math.floor(w * part[2]) or (w - x)
      tab:ClearAllPoints()
      tab:SetPoint("TOPLEFT", header, "TOPLEFT", x, 0)
      tab:SetWidth(width)
      x = x + width
    end
  end
  header:SetScript("OnSizeChanged", Lay)
  header:SetScript("OnShow", function() Lay(); Paint() end)
  Lay()
  Paint()
  -- (the game's Filter button kept hidden while the header shows)
  local filter = frame.FilterDropdown
  if type(filter) == "table" and filter.HookScript then
    filter:HookScript("OnShow", function(self) if ns:WhoHeader() then self:Hide() end end)
  end
  -- the list moved down a little for the header (its first corner), as the game had it otherwise
  header.boxPoints = {}
  for i = 1, 5 do
    local ok, point, rel, relPoint, x, y = pcall(box.GetPoint, box, i)
    if not ok or not point then break end
    header.boxPoints[i] = { point, rel, relPoint, x, y }
  end
  ns.WhoHeaderFrame = header -- (for the tests)
end

ApplyHeader = function()
  local frame = _G.LFGWhoListFrame
  if type(frame) ~= "table" then return end
  if ns:WhoHeader() then MakeHeader(frame) end
  if not header then return end
  local on = ns:WhoHeader()
  header:SetShown(on)
  local filter = frame.FilterDropdown
  if type(filter) == "table" and filter.SetShown then filter:SetShown(not on) end
  local box, points = frame.ScrollBox, header.boxPoints
  if points and points[1] and points[1][1] and box.SetPoint then
    box:ClearAllPoints()
    for i, pt in ipairs(points) do
      if i == 1 then box:SetPoint(pt[1], pt[2], pt[3], pt[4] or 0, (pt[5] or 0) - (on and ROOM or 0))
      else box:SetPoint(unpack(pt)) end
    end
    if frame.BarTop and frame.BarTop.SetShown then frame.BarTop:SetShown(not on) end
  end
  Resort(frame)
end

local hooked = {}
local function Watch(frame)
  local box = frame and frame.ScrollBox
  if type(box) ~= "table" or hooked[box] or type(box.SetDataProvider) ~= "function" then return end
  hooked[box] = true
  hooksecurefunc(box, "SetDataProvider", function(self, provider)
    Filter(self, provider)
    SortList(provider)
  end)
end
local function WatchAll()
  Watch(_G.LFGWhoListFrame) -- (WoW Forever: the Who list is the group finder's third tab)
  MakeExact(_G.LFGWhoListFrame)
  HookSort()
  Watch(_G.WhoFrame)
  if _G.LFGWhoListFrame then ApplyHeader() end
end
WatchAll()
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function() ApplyHeader() end) -- (Clara's settings read by now: the box's pick)
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
  if name == "Blizzard_GroupFinder_VanillaStyle" or name == "Blizzard_FriendsFrame" then WatchAll() end
  if hooked[_G.LFGWhoListFrame and _G.LFGWhoListFrame.ScrollBox or 0] then self:UnregisterEvent("ADDON_LOADED") end
end)

ns.WhoWord = Word -- (for the tests)
