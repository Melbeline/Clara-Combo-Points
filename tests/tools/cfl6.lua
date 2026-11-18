-- The friends window's sections, ClassicFriendsList's (Clara's same code: test116): the characters in two sections of
-- their own (online, offline), after the Battle.net favorites and friends by default; a padlock beside the window's X:
-- its right-click menu puts the characters online, or offline, above the Battle.net friends (or back after them), and
-- the first order back; unlocked, a grip on each header in sight; a header dragged goes where it is let go (a line
-- shows where), the list scrolling by itself pushed against its top or bottom (faster further past); the order kept
-- (the game building its list again keeps it); our sections' fold kept; locked again as the window closes; a kept
-- order made whole again
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- The game's tree list (TreeListDataProvider: the parts used), a list shown laid out again at each change
local invalidations, Layout = 0, nil
local NodeMT = {}
NodeMT.__index = NodeMT
local function TreeNode(provider, parent, data) return setmetatable({ nodes = {}, dataProvider = provider, parent = parent, data = data }, NodeMT) end
function NodeMT:GetData() return self.data end
function NodeMT:GetNodes() return self.nodes end
function NodeMT:GetParent() return self.parent end
function NodeMT:Insert(d) local n = TreeNode(self.dataProvider, self, d); table.insert(self.nodes, n); self.dataProvider:Invalidate(); return n end
function NodeMT:Remove(node, skip)
  for i, k in ipairs(self.nodes) do if k == node then table.remove(self.nodes, i); if not skip then self.dataProvider:Invalidate() end; return node end end
end
function NodeMT:SetCollapsed(c, _, skip) self.collapsed = c; if not skip then self.dataProvider:Invalidate() end end
function NodeMT:IsCollapsed() return self.collapsed end
function CreateTreeDataProvider()
  local p = {}
  p.node = TreeNode(p, nil, nil)
  function p:GetRootNode() return self.node end
  function p:Insert(d) return self.node:Insert(d) end
  function p:Invalidate() if self.attached then invalidations = invalidations + 1; Layout() end end
  return p
end
local provider
local function Names()
  local t = {}
  local function walk(n)
    for _, k in ipairs(n.nodes) do
      local d = k.data
      if d.classicFriend then t[#t + 1] = "*" .. d.classicFriend.name
      elseif d.accountInfo then t[#t + 1] = d.accountInfo.accountName
      elseif d.headerText then t[#t + 1] = "[" .. d.headerText .. "]" end
      walk(k)
    end
  end
  walk(provider.node)
  return table.concat(t, ", ")
end
local function Sections()
  local t = {}
  for _, k in ipairs(provider.node.nodes) do if k.data.headerText then t[#t + 1] = k.data.headerText:match("^(%S+ ?%S*)") end end
  return table.concat(t, " | ")
end
Enum.BattleNetFriendLevel = { Title = 2 }
Enum.RafLinkType = { None = 0 }
BNET_CLIENT_WOW = "WoW"; WOW_PROJECT_ID = 2

-- The game's friends page, its list in a box 300 high (top 700, bottom 400): headers 24, cards 40, spacers 2
local bnet = { { "Fav", true, true }, { "Ekiss", true }, { "Akabounet", false } }
SocialUIFrame = CreateFrame("Frame", "SocialUIFrame", UIParent)
SocialUIFrame.CloseButton = CreateFrame("Button", nil, SocialUIFrame)
SocialUIFrame.CloseButton:SetSize(24, 24)
local view = CreateFrame("Frame", nil, SocialUIFrame)
SocialUIFrame.FriendsList = view
local box = CreateFrame("Frame", nil, view)
view.ScrollBox = box
view.FilterBar = { SearchBar = CreateFrame("EditBox", nil, view) }
view.collapsedHeaders = {}
function view:SaveHeaderCollapsedState(t, c) self.collapsedHeaders[t] = c end
function view:InsertFriendsIntoDataProvider(p)
  local favs, others = {}, {}
  for i, f in ipairs(bnet) do if f[3] then favs[#favs + 1] = i else others[#others + 1] = i end end
  local function Sub(kind, text, list)
    if #list == 0 then return end
    local sub = p:Insert({ headerType = kind, headerText = text })
    sub:SetCollapsed(self.collapsedHeaders[kind], nil, true)
    sub:Insert({ isSpacer = true })
    for _, i in ipairs(list) do sub:Insert({ friendIndex = i, accountInfo = { accountName = bnet[i][1], gameAccountInfo = { isOnline = bnet[i][2] } } }) end
  end
  Sub(1, "Favorites", favs)
  if #favs > 0 and #others > 0 then p:Insert({ isSpacer = true }) end
  Sub(2, "Friends List", others)
end
local offset = 0
local shownFrames, pools = {}, { header = {}, other = {} }
local function Lines()
  local t = {}
  local function walk(n) for _, k in ipairs(n.nodes) do t[#t + 1] = k; if not k.collapsed then walk(k) end end end
  walk(provider.node)
  return t
end
local function Extent(n) return n.data.isSpacer and 2 or n.data.headerText and 24 or 40 end
local function Range() local total = 0 for _, n in ipairs(Lines()) do total = total + Extent(n) end return math.max(0, total - 300) end
local function MakeFrame(kind)
  local f = CreateFrame("Button", nil, box)
  f.GetTop = function(self) return self._top end
  f.GetBottom = function(self) return self._bottom end
  f.GetEffectiveScale = function() return 1 end
  f.GetWidth = function() return 300 end
  f.GetHeight = function(self) return self._top - self._bottom end
  f.GetElementData = function(self) return self.node end
  if kind == "header" then
    f.ButtonText = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.CollapseButton = CreateFrame("Button", nil, f)
  end
  return f
end
Layout = function()
  for _, pool in pairs(pools) do for _, f in ipairs(pool) do f:Hide(); f.node = nil end end
  shownFrames = {}
  local used, y = { header = 0, other = 0 }, 0
  for _, n in ipairs(Lines()) do
    local h = Extent(n)
    local top = 700 - (y - offset)
    local bottom = top - h
    if bottom < 700 and top > 400 then
      local kind = n.data.headerText and "header" or "other"
      used[kind] = used[kind] + 1
      local f = pools[kind][used[kind]] or MakeFrame(kind)
      pools[kind][used[kind]] = f
      f.node, f._top, f._bottom = n, top, bottom
      if f.ButtonText then f.ButtonText:SetText(n.data.headerText) end
      f:Show()
      shownFrames[#shownFrames + 1] = f
    end
    y = y + h
  end
end
function view:Refresh()
  local p = CreateTreeDataProvider()
  self:InsertFriendsIntoDataProvider(p, {})
  if provider then provider.attached = false end
  provider = p
  p.attached = true
  offset = math.min(offset, Range())
  Layout()
end
function box:GetDataProvider() return provider end
function box:ForEachFrame(fn) for _, f in ipairs(shownFrames) do local r = fn(f, f.node) if r then return r end end end
function box:GetDerivedScrollRange() return Range() end
function box:GetDerivedScrollOffset() return offset end
function box:ScrollToOffset(o) offset = math.max(0, math.min(Range(), o)); Layout() end
box.GetTop = function() return 700 end
box.GetBottom = function() return 400 end
box.GetLeft = function() return 100 end
box.GetRight = function() return 400 end
box.GetEffectiveScale = function() return 1 end
FriendsListSocialCardMixin = { Initialize = function() end }
local function HeaderFrame(key)
  for _, f in ipairs(shownFrames) do
    local d = f.node and f.node.data
    if d and d.headerText and (d.cflSection == key or (key == "favorites" and d.headerType == 1) or (key == "friends" and d.headerType == 2)) then return f end
  end
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
M.Fire("CHAT_MSG_ADDON", "ClaraFriends", "I|42|MAGE|Stranglethorn Vale", "WHISPER", "Elle Woods")
SocialUIFrame:Show()
view:Refresh()

out("== by default: the Battle.net favorites and friends, then the characters online, then those offline")
check(Names() == "[Favorites], Fav, [Friends List], Ekiss, Akabounet, [Characters online (1)], *Elle Woods, [Characters offline (1)], *Rose Thorn", Names())

out("== the padlock beside the window's X, locked")
local lock = A.lockButton
check(lock ~= nil and lock:IsVisible(), "shown with the friends page")
local point, rel, relPoint = lock:GetPoint(1)
check(point == "RIGHT" and rel == SocialUIFrame.CloseButton and relPoint == "LEFT", "just left of the X")
check(lock and lock._normalTex == "Interface\\Buttons\\LockButton-Locked-Up", "locked (" .. tostring(lock and lock._normalTex) .. ")")

out("== its right-click menu: online above, offline above, back after, the first order")
lock:Click("RightButton")
local items = M.menu and M.menu.items or {}
local onlineTop, offlineTop, reset
for _, it in ipairs(items) do
  if it.text == "Characters online above the Battle.net friends" then onlineTop = it end
  if it.text == "Characters offline above the Battle.net friends" then offlineTop = it end
  if it.text == "Default order" then reset = it end
end
check(onlineTop and offlineTop and reset and onlineTop.kind == "checkbox", "its two boxes and its button")
check(onlineTop and not onlineTop.isSelected(), "online: not above by default")
local before = invalidations
onlineTop.setSelected()
check(Sections() == "Characters online | Favorites | Friends List | Characters offline", Sections())
check(onlineTop.isSelected() and invalidations == before + 1, "checked; the list laid out again once (" .. (invalidations - before) .. ")")
offlineTop.setSelected()
check(Sections() == "Characters online | Characters offline | Favorites | Friends List", Sections())
onlineTop.setSelected()
check(Sections() == "Characters offline | Favorites | Friends List | Characters online", "online back after the Battle.net friends: " .. Sections())
offlineTop.setSelected()
check(Sections() == "Favorites | Friends List | Characters online | Characters offline", "offline back after them, after online: " .. Sections())
onlineTop.setSelected()
view:Refresh()
check(Sections() == "Characters online | Favorites | Friends List | Characters offline", "kept as the game builds its list again: " .. Sections())
check(ClassicFriendsListDB.friendSections and ClassicFriendsListDB.friendSections.order[1] == "online", "kept with the addon's settings")
reset.callback()
check(Sections() == "Favorites | Friends List | Characters online | Characters offline", "the first order back: " .. Sections())

out("== unlocked: a grip on each header in sight, none on the cards")
lock:Click("LeftButton")
check(A.SectionsUnlocked() and lock._normalTex == "Interface\\Buttons\\LockButton-Unlocked-Up", "unlocked")
M.Frame(0.06)
local onHeaders, onCards = 0, 0
for _, f in ipairs(pools.header) do local g = A.SectionGrip(f) if g and g:IsShown() and f:IsShown() then onHeaders = onHeaders + 1 end end
for _, f in ipairs(pools.other) do local g = A.SectionGrip(f) if g and g:IsShown() then onCards = onCards + 1 end end
check(onHeaders == 4 and onCards == 0, "4 headers gripped, no card (" .. onHeaders .. ", " .. onCards .. ")")

out("== a header dragged above the favorites: the line where it goes, then let go there")
local online = HeaderFrame("online")
local grip = A.SectionGrip(online)
M.cursorX, M.cursorY = 200, online._top - 12
M.mouseDown = true
grip._scripts.OnMouseDown(grip, "LeftButton")
local fav = HeaderFrame("favorites")
M.cursorY = fav._top - 6 -- (above the favorites header's middle)
M.Frame(0.016)
local marked = false
for _, f in ipairs(M.frames) do if f._parent == UIParent and f:GetHeight() == 3 and f:IsShown() then marked = true end end
check(marked, "the line shown")
check(A.SectionSlot(M.cursorY) == 0, "before the first section")
M.mouseDown = false
M.Frame(0.016)
check(Sections() == "Characters online | Favorites | Friends List | Characters offline", "let go there: " .. Sections())
check(ClassicFriendsListDB.friendSections.order[1] == "online", "kept")

out("== the list scrolled by itself as it is pushed against its top, faster further past")
reset.callback()
for i = 1, 12 do A.Add("Extra Name" .. string.char(96 + i)) end
A.SocialRefresh()
check(Range() > 300, "a list longer than its box (" .. Range() .. ")")
-- (scrolled down to where the offline header shows near the top, the favorites out of sight above)
box:ScrollToOffset(200)
M.Frame(0.06)
local dragFrame = HeaderFrame("offline")
check(dragFrame ~= nil and HeaderFrame("favorites") == nil, "the offline header in sight, the favorites' above")
local key = "offline"
M.mouseDown = true
A.SectionGrip(dragFrame)._scripts.OnMouseDown(A.SectionGrip(dragFrame), "LeftButton")
local start = offset
M.cursorY = 690 -- (in the zone near the top)
M.Frame(0.1)
local near = start - offset
local mid = offset
M.cursorY = 790 -- (pushed far past the top)
M.Frame(0.1)
local far = mid - offset
check(near > 0 and far > near * 2, ("scrolled up: %.0f near the top, %.0f pushed far past"):format(near, far))
for _ = 1, 40 do M.Frame(0.1) end
check(offset == 0, "up to the top")
check(A.SectionSlot(M.cursorY) == 0, "dropped above everything now")
M.mouseDown = false
M.Frame(0.016)
check(Sections():find("^Characters " .. (key == "online" and "online" or "offline")) ~= nil, "let go at the top: " .. Sections())
M.cursorY = 410
reset.callback()
box:ScrollToOffset(0)
M.mouseDown = true
local friendsHeader = HeaderFrame("friends")
A.SectionGrip(friendsHeader)._scripts.OnMouseDown(A.SectionGrip(friendsHeader), "LeftButton")
M.cursorY = 380 -- (pushed past the bottom)
M.Frame(0.1)
check(offset > 0, "pushed against its bottom: scrolled down (" .. offset .. ")")
M.mouseDown = false
M.Frame(0.016)

out("== our sections' fold kept; the window shut: locked again")
reset.callback()
view:SaveHeaderCollapsedState("cflOffline", true)
view:Refresh()
local offlineNode
for _, k in ipairs(provider.node.nodes) do if k.data.cflSection == "offline" then offlineNode = k end end
check(offlineNode and offlineNode.collapsed == true, "the offline section folded as the game builds its list again")
check(ClassicFriendsListDB.friendSections.folded.offline == true, "kept with the settings")
view:SaveHeaderCollapsedState("cflOffline", false)
view:Hide()
check(not A.SectionsUnlocked(), "locked again as the window closes")
view:Show()

out("== a kept order made whole again")
ClassicFriendsListDB.friendSections.order = { "bogus", "offline", "offline", "friends" }
local store = A.SectionStore()
local seen, n = {}, 0
for _, k in ipairs(store.order) do if not seen[k] then seen[k] = true; n = n + 1 end end
check(#store.order == 4 and n == 4 and seen.favorites and seen.friends and seen.online and seen.offline, table.concat(store.order, ", "))
out(string.format("\n%d failure(s)", fails))
return fails
