-- ClassicFriendsList in the game's new social window (Forever's default friends window): the characters in its friends
-- list, as the game builds it (before it lays it out), in two sections of their own (online on top, offline after
-- the Battle.net friends), without Battle.net friends too; the game's size cache never ours; our mouse layer on our cards,
-- the party button hidden (back on a Battle.net card); the search box; a change drawn in place, a character online
-- or added in its section at once
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
-- The game's card-size cache, as the game uses it: filled as it lays the list out, a pass that reads every line first
-- (a size put in after reading one of ours is the addon's); emptied at each refresh just before its friend search,
-- which the game refuses when a size of the addon's is found there then (the list empty)
view.TemplateExtentCache = {}
local layoutOurs, refused, refreshes = false, 0, 0
function view:GetTemplateExtent(name)
  if not self.TemplateExtentCache[name] then self.TemplateExtentCache[name] = { 70, layoutOurs } end
  return self.TemplateExtentCache[name][1]
end
function view:InsertFriendsIntoDataProvider(provider)
  if #bnet == 0 then return end
  local section = provider:Insert({ headerType = 2, headerText = "Friends List" })
  section:Insert({ isSpacer = true })
  for i, f in ipairs(bnet) do section:Insert({ friendIndex = i, accountInfo = { accountName = f[1], gameAccountInfo = { isOnline = f[2] } } }) end
end
function view:GenerateDataProvider() local p = Provider() self:InsertFriendsIntoDataProvider(p, {}) return p end
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
function view:Refresh()
  refreshes = refreshes + 1
  local ours = false
  for _, v in pairs(self.TemplateExtentCache) do if v[2] then ours = true end end
  wipe(self.TemplateExtentCache)
  if ours then refused = refused + 1; provider = Provider() else provider = self:GenerateDataProvider() end
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
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function() return false end
M.LoadAddonAs(ADDON_DIR, "ClassicFriendsList.toc", "ClassicFriendsList", ns)
M.Fire("ADDON_LOADED", "ClassicFriendsList")
local A = ns.CFL
ClassicFriendsListDB.friends = { ["elle woods"] = { name = "Elle Woods" }, ["rose thorn"] = { name = "Rose Thorn", seen = 1000 } }
M.Fire("PLAYER_LOGIN")
check(registered == 0, "nothing registered on the game's list (its card drawing hooked instead)")
check(A.panel == nil and _G.ClassicFriendsListPanel == nil, "no window of ours")

out("== the list as the game builds it: ours online on top, the Battle.net friends, then ours offline")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|42|MAGE|Stranglethorn Vale", "WHISPER", "Elle Woods")
SocialUIFrame:Show()
view:Refresh()
check(Names(provider) == "[Characters online (1)], *Elle Woods, [Friends List], Ekiss, Nadkov, Akabounet, Rorg, [Characters offline (1)], *Rose Thorn", Names(provider))
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
check(refused == 0, "the game's friend search never refused (" .. refused .. " of " .. refreshes .. ")")

out("== no Battle.net friend online; none at all: ours shown all the same")
bnet = { { "Akabounet", false }, { "Rorg", false } }
view:Refresh()
check(Names(provider) == "[Characters online (1)], *Elle Woods, [Friends List], Akabounet, Rorg, [Characters offline (1)], *Rose Thorn", Names(provider))
bnet = {}
view:Refresh()
check(Names(provider) == "[Characters online (1)], *Elle Woods, [Characters offline (1)], *Rose Thorn", "no Battle.net friend: ours alone (" .. Names(provider) .. ")")
bnet = { { "Ekiss", true }, { "Nadkov", true }, { "Akabounet", false }, { "Rorg", false } }

out("== a card of ours drawn: the mouse layer, the party button hidden; a Battle.net card again: as the game's")
view:Refresh()
for _, n in ipairs(Flat(provider)) do if n.data.classicFriend and n.data.classicFriend.name == "Elle Woods" then elle = n end end
local frame = Card(elle)
check(frame.classicFriend and frame.classicFriend:IsShown() and frame.classicFriend.alt.name == "Elle Woods", "the tooltip and menu layer")
check(not frame.PartyButton:IsShown(), "the party button hidden")
frame.classicFriend:Click("RightButton")
local menuItems = {}
for _, it in ipairs(M.menu and M.menu.items or {}) do if it.kind == "button" then menuItems[#menuItems + 1] = it.text end end
check(menuItems[1] == (PARTY_INVITE or INVITE or "Invite") and menuItems[2] == (WHISPER or "Whisper"),
  "its right-click menu: Invite first, then Whisper (" .. table.concat(menuItems, ", ") .. ")")
if M.menu then M.menu:Close() end
-- in a group led by another, without being its assistant: Suggest Invite (the same invite: the server hands it to the
-- leader); the group full: said so, none sent; the leader or an assistant: Invite
S.group = "party"
local leader, assistant, full = false, false, false
UnitIsGroupLeader = function() return leader end
UnitIsGroupAssistant = function() return assistant end
SUGGEST_INVITE, ERR_GROUP_FULL = "Suggest Invite", "Your party is full."
local invited, said = {}, {}
C_PartyInfo = C_PartyInfo or {}
C_PartyInfo.InviteUnit = function(n) invited[#invited + 1] = n end
C_PartyInfo.IsPartyFull = function() return full end
ChatFrameUtil = ChatFrameUtil or {}
ChatFrameUtil.DisplaySystemMessageInPrimary = function(t) said[#said + 1] = t end
local function FirstButton()
  frame.classicFriend:Click("RightButton")
  for _, it in ipairs(M.menu and M.menu.items or {}) do if it.kind == "button" then return it end end
end
local first = FirstButton()
check(first and first.text == "Suggest Invite", "in a group led by another: Suggest Invite (" .. tostring(first and first.text) .. ")")
first.callback()
check(invited[1] == "Elle Woods", "sent (the server hands it to the leader)")
full = true
first.callback()
check(#invited == 1 and said[1] == "Your party is full.", "the group full: said, none sent")
M.menu:Close()
assistant = true
first = FirstButton()
check(first and first.text == (PARTY_INVITE or INVITE or "Invite"), "an assistant: Invite")
M.menu:Close()
assistant, leader = false, true
first = FirstButton()
check(first and first.text == (PARTY_INVITE or INVITE or "Invite"), "the leader: Invite")
M.menu:Close()
S.group = nil
check(frame.FriendName._text == "|cff40c7ebElle Woods|r, Level 42 MAGE", "online: one line, her name in her class's color (" .. tostring(frame.FriendName._text) .. ")")
local akabounet
for _, n in ipairs(Flat(provider)) do if n.data.accountInfo and n.data.accountInfo.accountName == "Akabounet" then akabounet = n end end
local other = Card(akabounet, CreateFrame("Button", nil, box))
Card(elle, other)
Card(akabounet, other)
check(not other.classicFriend:IsShown() and other.PartyButton:IsShown(), "the same card for a Battle.net friend: as the game made it")

out("== a change: the same ones online, drawn again in place; one gone offline or added: in its section at once")
frame = Card(elle)
local before = provider
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|43|MAGE|Duskwood", "WHISPER", "Elle Woods")
A.SocialRefresh()
check(provider == before and Names(provider) == "[Characters online (1)], *Elle Woods, [Friends List], Ekiss, Nadkov, Akabounet, Rorg, [Characters offline (1)], *Rose Thorn", "the same list (in place)")
check(frame.FriendName._text == "|cff40c7ebElle Woods|r, Level 43 MAGE", "her card's text drawn again in place (" .. tostring(frame.FriendName._text) .. ")")
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "!", "WHISPER", "Elle Woods")
A.SocialRefresh()
check(Names(provider) == "[Friends List], Ekiss, Nadkov, Akabounet, Rorg, [Characters offline (2)], *Elle Woods, *Rose Thorn", "gone offline: in the offline section at once (" .. Names(provider) .. ")")
A.Add("Lune Belle")
A.SocialRefresh()
check(Names(provider) == "[Friends List], Ekiss, Nadkov, Akabounet, Rorg, [Characters offline (3)], *Elle Woods, *Lune Belle, *Rose Thorn", "added: in it at once (" .. Names(provider) .. ")")
view:Refresh()
check(Names(provider) == "[Friends List], Ekiss, Nadkov, Akabounet, Rorg, [Characters offline (3)], *Elle Woods, *Lune Belle, *Rose Thorn", "the game's next build: the same (" .. Names(provider) .. ")")

out("== the search box")
view.FilterBar.SearchBar:SetText("rose")
view:Refresh()
check(Names(provider) == "[Friends List], Ekiss, Nadkov, Akabounet, Rorg, [Characters offline (1)], *Rose Thorn", Names(provider))
view.FilterBar.SearchBar:SetText("")

out("== the window opened and shut again and again, a Battle.net friend's news: never empty")
local empty = 0
for _ = 1, 6 do
  view:Refresh()
  if not Names(provider):find("Elle Woods", 1, true) then empty = empty + 1 end
end
check(empty == 0 and refused == 0, "each time the whole list, ours in it (" .. empty .. " empty, " .. refused .. " refused)")
local left = 0
for _, v in pairs(view.TemplateExtentCache) do if v[2] then left = left + 1 end end
check(left == 0, "no size of the addon's left in the game's cache")
out(string.format("\n%d failure(s)", fails))
return fails
