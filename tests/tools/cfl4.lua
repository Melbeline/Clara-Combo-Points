-- ClassicFriendsList in the game's new social window (Forever's default friends window): the characters in its friends
-- list, as the game builds it (before it lays it out), after the Battle.net friends online and before those offline;
-- after the first card when none is online; nothing without a Battle.net card; the game's size cache never ours; our
-- mouse layer on our cards, the party button hidden (back on a Battle.net card); the search box; a change drawn in place
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
    if d.classicFriend then t[#t + 1] = "*" .. d.classicFriend.name
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
view.TemplateExtentCache = {}
local cacheWrites = 0
setmetatable(view.TemplateExtentCache, { __newindex = function(t, k, v) cacheWrites = cacheWrites + 1 rawset(t, k, v) end })
function view:InsertFriendsIntoDataProvider(provider)
  if #bnet == 0 then return end
  local section = provider:Insert({ headerType = 2, headerText = "Friends List" })
  section:Insert({ isSpacer = true })
  for i, f in ipairs(bnet) do section:Insert({ friendIndex = i, accountInfo = { accountName = f[1], gameAccountInfo = { isOnline = f[2] } } }) end
end
function view:GenerateDataProvider() local p = Provider() self:InsertFriendsIntoDataProvider(p, {}) return p end
local callbacks, provider = {}, nil
function box:RegisterCallback(event, fn, owner) callbacks[event] = { fn, owner } end
function box:GetDataProvider() return provider end
function view:Refresh() provider = self:GenerateDataProvider() end
local function Card(node, frame)
  frame = frame or CreateFrame("Button", nil, box)
  frame.PartyButton = frame.PartyButton or CreateFrame("Button", nil, frame)
  frame.PartyButton:Show()
  frame.FriendName = frame.FriendName or frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  frame.Initialize = frame.Initialize or function(f, n) f.drawn = n:GetData().accountInfo f.FriendName:SetText(f.drawn.accountName) end
  frame:Initialize(node)
  local cb = callbacks.OnInitializedFrame
  if cb then cb[1](cb[2], frame, node) end
  return frame
end

FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:Hide()
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function() return false end
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddonAs(ADDON_DIR, "ClassicFriendsList.toc", "ClassicFriendsList", ns)
M.Fire("ADDON_LOADED", "ClassicFriendsList")
local A = ns.CFL
ClassicFriendsListDB.friends = { ["elle woods"] = { name = "Elle Woods" }, ["rose thorn"] = { name = "Rose Thorn", seen = 1000 } }
M.Fire("PLAYER_LOGIN")
check(callbacks.OnInitializedFrame ~= nil, "hooked into the social window's list")
check(A.panel == nil and _G.ClassicFriendsListPanel == nil, "no window of ours")

out("== the list as the game builds it: Battle.net online, ours, Battle.net offline")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|42|MAGE|Stranglethorn Vale", "WHISPER", "Elle Woods")
SocialUIFrame:Show()
view:Refresh()
check(Names(provider) == "[Friends List], Ekiss, Nadkov, *Elle Woods, *Rose Thorn, Akabounet, Rorg", Names(provider))
local elle
for _, n in ipairs(Flat(provider)) do if n.data.classicFriend and n.data.classicFriend.name == "Elle Woods" then elle = n end end
local info = elle.data.accountInfo
check(info.gameAccountInfo.isOnline and info.gameAccountInfo.characterLevel == 42 and info.gameAccountInfo.areaName == "Stranglethorn Vale",
  "Elle's card: online, level 42, her zone")
check(info.accountName == "|cff40c7ebElle Woods|r, Level 42 MAGE", "all on the top line, her name in her class's color (" .. tostring(info.accountName) .. ")")
check(info.gameAccountInfo.characterName == nil, "no character line (the name not twice)")
local rose
for _, n in ipairs(Flat(provider)) do if n.data.classicFriend and n.data.classicFriend.name == "Rose Thorn" then rose = n end end
check(rose.data.accountInfo.accountName == "Rose Thorn" and rose.data.accountInfo.gameAccountInfo.characterName == nil,
  "Rose, offline, nothing known: her name once, grey, no character line")
check(cacheWrites == 0, "the game's size cache never written by us")

out("== nobody online: after the first Battle.net card; no Battle.net friend: none")
bnet = { { "Akabounet", false }, { "Rorg", false } }
view:Refresh()
check(Names(provider) == "[Friends List], Akabounet, *Elle Woods, *Rose Thorn, Rorg", Names(provider))
bnet = {}
view:Refresh()
check(Names(provider) == "", "no Battle.net card: not put in (" .. Names(provider) .. ")")
bnet = { { "Ekiss", true }, { "Nadkov", true }, { "Akabounet", false }, { "Rorg", false } }

out("== a card of ours drawn: the mouse layer, the party button hidden; a Battle.net card again: as the game's")
view:Refresh()
for _, n in ipairs(Flat(provider)) do if n.data.classicFriend and n.data.classicFriend.name == "Elle Woods" then elle = n end end
local frame = Card(elle)
check(frame.classicFriend and frame.classicFriend:IsShown() and frame.classicFriend.alt.name == "Elle Woods", "the tooltip and menu layer")
check(not frame.PartyButton:IsShown(), "the party button hidden")
check(frame.FriendName._text == "|cff40c7ebElle Woods|r, Level 42 MAGE", "online: one line, her name in her class's color (" .. tostring(frame.FriendName._text) .. ")")
local akabounet
for _, n in ipairs(Flat(provider)) do if n.data.accountInfo and n.data.accountInfo.accountName == "Akabounet" then akabounet = n end end
local other = Card(akabounet, CreateFrame("Button", nil, box))
Card(elle, other)
Card(akabounet, other)
check(not other.classicFriend:IsShown() and other.PartyButton:IsShown(), "the same card for a Battle.net friend: as the game made it")

out("== a change: drawn again in place; a character added: put in again")
frame = Card(elle)
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "!", "WHISPER", "Elle Woods")
A.SocialRefresh()
check(Names(provider) == "[Friends List], Ekiss, Nadkov, *Elle Woods, *Rose Thorn, Akabounet, Rorg", "the same list (in place)")
check(frame.drawn and frame.drawn.gameAccountInfo.isOnline == false, "Elle's card drawn again: offline")
check(frame.FriendName._text == "Elle Woods", "offline: the game's grey, no class color")
A.Add("Lune Belle")
check(Names(provider) == "[Friends List], Ekiss, Nadkov, *Elle Woods, *Lune Belle, *Rose Thorn, Akabounet, Rorg", Names(provider))

out("== the search box")
view.FilterBar.SearchBar:SetText("rose")
view:Refresh()
check(Names(provider) == "[Friends List], Ekiss, Nadkov, *Rose Thorn, Akabounet, Rorg", Names(provider))
view.FilterBar.SearchBar:SetText("")
check(cacheWrites == 0, "the game's size cache still never ours")
out(string.format("\n%d failure(s)", fails))
return fails
