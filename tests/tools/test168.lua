-- The Who list's column header (Who.lua), as vanilla had it: Name, Zone (its menu: Zone, Guild, Race), Lvl, Class
-- above the group finder's Who list, the list a little lower for it, the game's Filter button hidden. A click sorts:
-- Name A-Z then Z-A; Lvl the highest first then the lowest; Class A-Z then Z-A, the names A-Z within; Zone's menu
-- picks the column sorted (Guild: those without one last); the sorted tab in gold; kept for the account; a new list
-- sorted the same as it comes; the box off: the game's own as it was.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
C_FriendList = { GetNumWhoResults = function() return 0, 0 end, GetWhoInfo = function() return nil end, SendWho = function() end,
  SortWho = function() end }
LFGWhoListFrame = CreateFrame("Frame", "LFGWhoListFrame", UIParent)
LFGWhoListFrame:SetSize(338, 424)
LFGWhoListFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50)
local edit = CreateFrame("EditBox", "WhoFrameEditBox", LFGWhoListFrame, "SearchBoxTemplate")
edit:SetSize(255, 20); edit:SetPoint("TOPLEFT", LFGWhoListFrame, "TOPLEFT", 56, -40)
LFGWhoListFrame.EditBox = edit
LFGWhoListFrame.WhoSearch = CreateFrame("Button", nil, LFGWhoListFrame)
local filter = CreateFrame("Button", nil, LFGWhoListFrame)
LFGWhoListFrame.FilterDropdown = filter
local box = CreateFrame("Frame", nil, LFGWhoListFrame)
box:SetPoint("TOPLEFT", LFGWhoListFrame, "TOPLEFT", 16, -106)
box:SetPoint("BOTTOMRIGHT", LFGWhoListFrame, "BOTTOMRIGHT", -32, 48)
local current
function box:SetDataProvider(p) current = p end
function box:GetDataProvider() return current end
LFGWhoListFrame.ScrollBox = box
LFGWhoListFrame.BarTop = LFGWhoListFrame:CreateTexture()

local function Provider(rows)
  local p = { data = {} }
  for i, r in ipairs(rows) do p.data[i] = { index = i, info = r } end
  function p:SetSortComparator(cmp) self.sortComparator = cmp; table.sort(self.data, cmp) end
  function p:Sort() table.sort(self.data, self.sortComparator) end
  function p:GetSize() return #self.data end
  return p
end
local ROWS = {
  { fullName = "Zoé Lune", level = 37, classStr = "Druid", area = "Ironforge", fullGuildName = "", raceStr = "Night Elf" },
  { fullName = "Bizon Lefûterre", level = 37, classStr = "Druid", area = "Darnassus", fullGuildName = "Rassemblement", raceStr = "Night Elf" },
  { fullName = "Jurinaza Sarmadov", level = 40, classStr = "Hunter", area = "Ironforge", fullGuildName = "Les Lunes", raceStr = "Human" },
  { fullName = "Éric Ombre", level = 39, classStr = "Mage", area = "Stormwind", fullGuildName = "Apex", raceStr = "Gnome" },
  { fullName = "Anna Clair", level = 39, classStr = "Druid", area = "Ironforge", fullGuildName = "Apex", raceStr = "Tauren" },
}
local function Names() local t = {} for _, d in ipairs(current.data) do t[#t + 1] = d.info.fullName:match("^(%S+)") end return table.concat(t, ",") end

S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
local header = ns.WhoHeaderFrame
if not header then out("(no Who header in this version)"); out(""); out("0 failure(s)"); return end
out("== the header above the list, the list lower, the Filter button hidden")
check(header:IsShown() and ns:WhoHeader(), "shown, on by default")
local p, rel, rp, x, y = box:GetPoint(1)
check(p == "TOPLEFT" and y == -112, "the list 6 lower: " .. tostring(y))
local p2, _, _, x2, y2 = box:GetPoint(2)
check(p2 == "BOTTOMRIGHT" and x2 == -32 and y2 == 48, "its other corner as the game had it")
check(not filter:IsShown(), "the Filter button hidden")
filter:Show()
check(not filter:IsShown(), "shown again by the game: hidden again")
out("== the list as the game gives it, before any click: left in its order")
box:SetDataProvider(Provider(ROWS))
check(Names() == "Zoé,Bizon,Jurinaza,Éric,Anna", Names())
out("== Name: A to Z (accents aside), then Z to A")
ns.WhoPick("name")
check(Names() == "Anna,Bizon,Éric,Jurinaza,Zoé", "A-Z: " .. Names())
ns.WhoPick("name")
check(Names() == "Zoé,Jurinaza,Éric,Bizon,Anna", "Z-A: " .. Names())
out("== Lvl: the highest first, then the lowest; the names A-Z within")
ns.WhoPick("level")
check(Names() == "Jurinaza,Anna,Éric,Bizon,Zoé", "highest first: " .. Names())
ns.WhoPick("level")
check(Names() == "Bizon,Zoé,Anna,Éric,Jurinaza", "lowest first: " .. Names())
out("== Class: A to Z, then Z to A, the names A-Z within each")
ns.WhoPick("class")
check(Names() == "Anna,Bizon,Zoé,Jurinaza,Éric", "Druid, Hunter, Mage: " .. Names())
ns.WhoPick("class")
check(Names() == "Éric,Jurinaza,Anna,Bizon,Zoé", "Mage, Hunter, Druid (names still A-Z): " .. Names())
out("== Zone's menu: Guild picked, sorted by it (none last)")
ns.WhoVariablePick("guild")
check(Names() == "Anna,Éric,Jurinaza,Bizon,Zoé", "Apex, Les Lunes, Rassemblement, none: " .. Names())
local tabs = {}
for _, f in ipairs(M.frames) do if f._parent == header and f.label then tabs[#tabs + 1] = f end end
local guildTab
for _, t in ipairs(tabs) do if t.label._text == (GUILD or "Guild") then guildTab = t end end
check(guildTab ~= nil, "the tab named Guild now")
local r, g = guildTab.label:GetTextColor()
check(r == 1 and g > 0.8 and g < 0.9, "the sorted tab in gold")
ns.WhoVariablePick("zone")
check(Names() == "Bizon,Anna,Jurinaza,Zoé,Éric", "Zone: Darnassus, Ironforge (names A-Z), Stormwind: " .. Names())
out("== a click on the tab itself; a new list sorted as it comes; kept for the account")
for _, t in ipairs(tabs) do if t.key == "name" then t:Click() end end
check(Names() == "Anna,Bizon,Éric,Jurinaza,Zoé", "a click on Name: " .. Names())
box:SetDataProvider(Provider(ROWS))
check(Names() == "Anna,Bizon,Éric,Jurinaza,Zoé", "a new list: sorted the same")
check(ns.sv.whoSort.k == "name" and not ns.sv.whoSort.d, "kept for the account")
out("== the box off: the game's own")
ns:SetWhoHeader(false)
check(not header:IsShown() and filter:IsShown(), "the header hidden, the Filter button back")
local _, _, _, _, yy = box:GetPoint(1)
check(yy == -106, "the list where the game had it: " .. tostring(yy))
box:SetDataProvider(Provider(ROWS))
check(Names() == "Zoé,Bizon,Jurinaza,Éric,Anna", "not sorted: the game's order")
ns:SetWhoHeader(true)
check(header:IsShown() and not filter:IsShown(), "on again")
out("")
out(fails .. " failure(s)")
