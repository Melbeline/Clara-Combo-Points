-- The game's Battle.net friends put back (AltFriends.lua) when its own friend search gave none (the game refuses it when
-- the list is built in an addon's name): the player has some, no search typed, no filter: its two sections as the game
-- makes them (counts, folds, cards), ours arranged around them; its search gave nil: the same, from the scroll box; a
-- search typed or a filter ticked, or no Battle.net friend: nothing put in; each time kept for Clara's report
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- The game's tree list (TreeListDataProvider, the parts used)
local function Node(data, parent)
  local n = { data = data, nodes = {}, parent = parent }
  function n:GetData() return self.data end
  function n:GetNodes() return self.nodes end
  function n:Insert(d) local c = Node(d, self) table.insert(self.nodes, c) return c end
  function n:InsertNodeAtIndex(d, i) local c = Node(d, self) table.insert(self.nodes, i, c) return c end
  function n:Remove(node) for i, k in ipairs(self.nodes) do if k == node then table.remove(self.nodes, i) return node end end end
  function n:SetCollapsed(c) self.collapsed = c end
  return n
end
local function Provider()
  local p = { root = Node(nil) }
  function p:GetRootNode() return self.root end
  function p:Insert(d) return self.root:Insert(d) end
  return p
end
local function Flat(p)
  local list = {}
  local function walk(n) for _, k in ipairs(n.nodes) do list[#list + 1] = k; walk(k) end end
  walk(p.root)
  return list
end
local function Names(p)
  local t = {}
  for _, n in ipairs(Flat(p)) do
    local d = n.data
    if d.claraAlt then t[#t + 1] = "*" .. d.claraAlt.name
    elseif d.accountInfo then t[#t + 1] = d.accountInfo.accountName
    elseif d.headerText then t[#t + 1] = "[" .. d.headerText .. "]" end
  end
  return table.concat(t, ", ")
end
ScrollBoxListMixin = { Event = { OnInitializedFrame = "OnInitializedFrame", OnReleasedFrame = "OnReleasedFrame" } }
Enum.BattleNetFriendLevel = { Title = 2 }
Enum.RafLinkType = { None = 0 }
BNET_CLIENT_WOW = "WoW"; WOW_PROJECT_ID = 2
RAID_CLASS_COLORS.MAGE = { r = 0.25, g = 0.78, b = 0.92 }

-- The game's friends page: it builds its list (its Battle.net friends) and lays it out
local bnet = { { "Ekiss", true }, { "Nadkov", true }, { "Akabounet", false }, { "Rorg", false } }
SocialUIFrame = CreateFrame("Frame", "SocialUIFrame", UIParent)
local view = CreateFrame("Frame", nil, SocialUIFrame)
SocialUIFrame.FriendsList = view
local box = CreateFrame("Frame", nil, view)
view.ScrollBox = box
view.FilterBar = { SearchBar = CreateFrame("EditBox", nil, view) }
-- The game's card-size cache, as the game uses it: filled as it lays the list out, a pass that reads every line first
-- (a size put in after reading one of ours is the addon's); emptied at each refresh just before its friend search,
-- which the game refuses when a size of the addon's is found there then (the list empty)
view.TemplateExtentCache = {}
local layoutOurs, refused, refreshes = false, 0, 0
function view:GetTemplateExtent(name)
  if not self.TemplateExtentCache[name] then self.TemplateExtentCache[name] = { 70, layoutOurs } end
  return self.TemplateExtentCache[name][1]
end
local searchRefused = false
function view:InsertFriendsIntoDataProvider(provider, friendsData)
  if #bnet == 0 or #friendsData == 0 then return end
  local section = provider:Insert({ headerType = 2, headerText = "Friends List" })
  section:Insert({ isSpacer = true })
  for i, f in ipairs(bnet) do section:Insert({ friendIndex = i, accountInfo = { accountName = f[1], gameAccountInfo = { isOnline = f[2] } } }) end
end
-- (its search: every friend, or none when refused; nil: InsertFriendsIntoDataProvider not called at all)
local searchNil = false
function view:GenerateDataProvider()
  local p = Provider()
  if searchNil then return p end
  local data = {}
  if not searchRefused then for i = 1, #bnet do data[i] = i end end
  self:InsertFriendsIntoDataProvider(p, data)
  return p
end
view.collapsedHeaders = {}
function view:IsHeaderCollapsed(t) return self.collapsedHeaders[t] == true end
BNGetNumFriends = function() return #bnet end
C_BattleNet = C_BattleNet or {}
C_BattleNet.GetFriendAccountInfo = function(i)
  local f = bnet[i]
  return f and { accountName = f[1], isFavorite = f[3] == true, gameAccountInfo = { isOnline = f[2] } }
end
SOCIAL_UI_FAVORITE_FRIENDS_LIST_HEADER = "Favorites (%d/%d)"
SOCIAL_UI_FRIENDS_LIST_HEADER = "Friends List (%d/%d)"
local function Layout(p)
  layoutOurs = false
  for _, n in ipairs(Flat(p)) do if n.data.classicFriend then layoutOurs = true end end -- (its pass over the lines' kinds)
  for _, n in ipairs(Flat(p)) do
    local d = n.data
    view:GetTemplateExtent(d.isSpacer and "spacer" or (d.headerText and "header") or "card")
  end
  layoutOurs = false
end
local provider = nil
local registered = 0
function box:RegisterCallback() registered = registered + 1 end
FriendsListSocialCardMixin = { Initialize = function(f, n)
  f.drawn = n:GetData().accountInfo
  f.FriendName:SetText(f.drawn.accountName)
end }
function box:GetDataProvider() return provider end
function box:SetDataProvider(p) provider = p end
function view:Refresh()
  refreshes = refreshes + 1
  local ours = false
  for _, v in pairs(self.TemplateExtentCache) do if v[2] then ours = true end end
  wipe(self.TemplateExtentCache)
  if ours then refused = refused + 1; provider = Provider() else box:SetDataProvider(self:GenerateDataProvider()) end
  Layout(provider)
end
local function Card(node, frame)
  frame = frame or CreateFrame("Button", nil, box)
  frame.PartyButton = frame.PartyButton or CreateFrame("Button", nil, frame)
  frame.PartyButton:Show()
  frame.FriendName = frame.FriendName or frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  FriendsListSocialCardMixin.Initialize(frame, node) -- (the game's card drawing, our hook after it)
  return frame
end

FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local A = ns.AltFriends
ns.sv.altFriends = { ["elle woods"] = { name = "Elle Woods" } }
M.Fire("PLAYER_LOGIN")
bnet[1][3] = true -- (Ekiss: a favorite)

out("== the game's search gives its friends: the game's list as it is")
view:Refresh()
check(Names(provider):find("Ekiss", 1, true) and Names(provider):find("Rorg", 1, true), "its friends there: " .. Names(provider))
check(A.bnetBack.count == 0, "nothing put back")

out("== its search refused (the list built in an addon's name): its friends put back as the game puts them")
searchRefused = true
view:Refresh()
local names = Names(provider)
check(names:find("[Favorites (1/1)]", 1, true) and names:find("[Friends List (1/3)]", 1, true), "its two sections, their counts: " .. names)
check(names:find("Ekiss", 1, true) and names:find("Nadkov", 1, true) and names:find("Akabounet", 1, true) and names:find("Rorg", 1, true),
  "every friend's card")
check(names:find("*Elle Woods", 1, true) ~= nil, "our characters with them, arranged")
check(names:find("Favorites", 1, true) < names:find("Ekiss", 1, true) and names:find("Friends List", 1, true) < names:find("Nadkov", 1, true),
  "each in its section (the favorite in Favorites)")
check(A.bnetBack.count == 1, "kept for the report")
local report = table.concat(A.BnetReport(), "\n")
check(report:find("1 time", 1, true) and report:find("put back", 1, true), "the report says so")

out("== its search gave nil: put back from the scroll box")
searchNil = true
view:Refresh()
names = Names(provider)
check(names:find("Ekiss", 1, true) and names:find("*Elle Woods", 1, true), "its friends and ours: " .. names)
searchNil = false

out("== a search typed: none found may be right, nothing put back")
view.FilterBar.SearchBar:SetText("zzz")
local before = A.bnetBack.count
view:Refresh()
check(not Names(provider):find("Ekiss", 1, true) and A.bnetBack.count == before, "nothing put back")
view.FilterBar.SearchBar:SetText("")

out("== a filter ticked: nothing put back")
view.selectedSearchFilterOptions = { [{}] = true }
view:Refresh()
check(not Names(provider):find("Ekiss", 1, true), "nothing put back")
view.selectedSearchFilterOptions = nil

out("== a folded section stays folded")
view.collapsedHeaders[2] = true
local folded
view:Refresh()
for _, n in ipairs(provider:GetRootNode():GetNodes()) do
  if n.data.headerType == 2 then folded = n.collapsed end
end
check(folded == true, "the Friends section folded as the game keeps it")
view.collapsedHeaders[2] = nil

out("== no Battle.net friend: nothing put in")
local saved = bnet
bnet = {}
view:Refresh()
check(not Names(provider):find("Friends List", 1, true), "no section of theirs")
bnet = saved
searchRefused = false
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
