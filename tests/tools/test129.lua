-- Sort by guild in the Who tab (Who.lua): Guild in the Filter menu's Sort submenu, after Level, before the order
-- lines; picked: the game's own sort by guild in the order picked, kept as the game keeps its sort (its own radios
-- unticked, its order lines sorting by guild); the game's sorts take over again; added each time the menu opens
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local sorts = {}
C_FriendList = {
  GetNumWhoResults = function() return 0, 0 end,
  GetWhoInfo = function() return nil end,
  SendWho = function() end,
  SortWho = function(mode, asc) sorts[#sorts + 1] = { mode, asc } end,
}
NAME, CLASS, LEVEL, GUILD = "Name", "Class", "Level", "Guild"
WHO_SORT_LABEL, WHO_SORT_ASCENDING_LABEL, WHO_SORT_DESCENDING_LABEL = "Sort", "Ascending", "Descending"
-- the game's Who tab and its filter menu (WhoList.lua), its Sort part as the game makes it
LFGWhoListFrame = CreateFrame("Frame", "LFGWhoListFrame", UIParent)
LFGWhoListFrame.ScrollBox = { SetDataProvider = function() end, GetParent = function() return LFGWhoListFrame end }
LFGWhoListFilterUtil = { sortMode = "name", sortOrder = 1 }
function LFGWhoListFilterUtil.InitSortOptions(root)
  local U = LFGWhoListFilterUtil
  local function IsSort(m) return U.sortMode == m end
  local function SetSort(m) U.sortMode = m; C_FriendList.SortWho(m); return MenuResponse.Refresh end
  local function IsOrder(o) return U.sortOrder == o end
  local function SetOrder(o) U.sortOrder = o; C_FriendList.SortWho(U.sortMode, o == 1); return MenuResponse.Refresh end
  local sub = root:CreateButton(WHO_SORT_LABEL)
  sub:CreateRadio(NAME, IsSort, SetSort, "name")
  sub:CreateRadio(CLASS, IsSort, SetSort, "class")
  sub:CreateRadio(LEVEL, IsSort, SetSort, "level")
  sub:QueueDivider()
  sub:CreateRadio(WHO_SORT_ASCENDING_LABEL, IsOrder, SetOrder, 1)
  sub:CreateRadio(WHO_SORT_DESCENDING_LABEL, IsOrder, SetOrder, 2)
end
function LFGWhoListFilterUtil.SetupFilterMenu(dropdown, root)
  root:CreateButton(CLASS); root:CreateButton("Race"); root:CreateButton("Zone")
  LFGWhoListFilterUtil.InitSortOptions(root)
end

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")

local function Open()
  local root = MenuUtil.CreateFrame()
  LFGWhoListFilterUtil.SetupFilterMenu(nil, root)
  local sub
  for _, d in root:EnumerateElementDescriptions() do if d.text == "Sort" then sub = d end end
  return sub
end
local function Texts(sub) local t = {} for _, d in sub:EnumerateElementDescriptions() do t[#t + 1] = d.text or "-" end return table.concat(t, ",") end
local function Find(sub, text) for _, d in sub:EnumerateElementDescriptions() do if d.text == text then return d end end end

local sub = Open()
check(Texts(sub) == "Name,Class,Level,Guild,-,Ascending,Descending", "Guild after Level, before the order lines: " .. Texts(sub))
local guild = Find(sub, "Guild")
check(guild.kind == "radio" and not guild.isSelected(guild.data), "a radio, not picked while the sort is by name")
check(guild.setSelected(guild.data) == MenuResponse.Refresh, "picked: the menu refreshed")
check(LFGWhoListFilterUtil.sortMode == "guild" and sorts[#sorts][1] == "guild" and sorts[#sorts][2] == true,
  "the game's sort by guild, ascending (as picked below)")
check(guild.isSelected(guild.data) and not Find(sub, "Name").isSelected("name"), "Guild ticked, Name no longer")
local desc = Find(sub, "Descending")
desc.setSelected(2)
check(sorts[#sorts][1] == "guild" and sorts[#sorts][2] == false, "Descending: the guilds in reverse")
local n = #sorts
Find(sub, "Level").setSelected("level")
check(LFGWhoListFilterUtil.sortMode == "level" and sorts[#sorts][1] == "level" and not guild.isSelected(guild.data),
  "Level picked again: the game's sort, Guild unticked")
LFGWhoListFilterUtil.sortOrder = 2
sub = Open()
check(Texts(sub) == "Name,Class,Level,Guild,-,Ascending,Descending", "the menu opened again: Guild once, in its place")
Find(sub, "Guild").setSelected("guild")
check(sorts[#sorts][1] == "guild" and sorts[#sorts][2] == false, "picked while Descending: guilds in reverse")
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
sub = Open()
check(Texts(sub) == "Name,Class,Level,Guild,-,Ascending,Descending", "hooked once: Guild not added twice")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
