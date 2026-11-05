-- Clara Combo Points - one's other characters in the friends list. WoW Forever's friends list takes
-- none of the account's own characters; Clara keeps them instead (for the whole account) and shows
-- them in the friends window, above the offline Battle.net friends, in the game's look: online (the
-- character played now, or one heard on the sync between the accounts in the last five minutes) or
-- offline, with its level and class as Clara last saw them (the gold tracker) and when it was last
-- played. Add Alt, between Add Friend and Send Message (the three the same width), adds one by its
-- first name and surname with the suggestions of the mail's To field (the account's characters
-- among them). Over a row: its tooltip; right-click: whisper (online) or remove it from the list.

local ADDON, ns = ...
local L = ns.L

local GAP = 2                -- between the three foot buttons
local LEFT, RIGHT = 4, 6     -- the game's margins for its two (FriendsFrameButtonTemplate_BottomLeft / _BottomRight)
local NAME_MAX = 12 + 1 + 64 -- a first name, a space, a surname (the game's own Add Friend box)
local HEARD = 300            -- seconds: a character heard on the sync this recently is online
local TYPE = "claraAlt"      -- the list entries' button type (the game's: numbers)

local AltFriends = {}
ns.AltFriends = AltFriends
AltFriends.TYPE = TYPE

---------------------------------------------------------------------------
-- The list (ns.sv.altFriends: lower-case whole name -> { name = "First Surname" })
---------------------------------------------------------------------------
local function Normal(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  if name == "" or #name > NAME_MAX then return nil end
  return name
end

local function List()
  local sv = ns.sv
  if not sv then return nil end
  if type(sv.altFriends) ~= "table" then sv.altFriends = {} end
  for key, alt in pairs(sv.altFriends) do
    if type(key) ~= "string" or type(alt) ~= "table" or not Normal(alt.name) then sv.altFriends[key] = nil end
  end
  return sv.altFriends
end
AltFriends.List = List

function AltFriends.Add(name)
  name = Normal(name)
  local list = List()
  if not (name and list) then return false end
  list[name:lower()] = { name = name }
  AltFriends.Refresh()
  return true
end

function AltFriends.Remove(name)
  local list = List()
  if not (list and type(name) == "string") then return false end
  list[name:lower()] = nil
  AltFriends.Refresh()
  return true
end

-- In the list's order: online first, then by name.
local function Sorted()
  local out = {}
  for _, alt in pairs(List() or {}) do out[#out + 1] = alt end
  table.sort(out, function(a, b)
    local oa, ob = AltFriends.Online(a.name), AltFriends.Online(b.name)
    if oa ~= ob then return oa end
    return a.name:lower() < b.name:lower()
  end)
  return out
end
AltFriends.Sorted = Sorted

---------------------------------------------------------------------------
-- What Clara knows of a character: online, level, class, last played
---------------------------------------------------------------------------
local function Realm()
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or (GetRealmName and GetRealmName() or "")
  return (realm or ""):gsub("%s", "")
end

-- Its key in the gold tracker and the sync ("First-Realm": the first name the game gives)
local function KeyOf(name) return (name:match("^(%S+)") or name) .. "-" .. Realm() end

local function IsMe(name)
  local me = ns.FullName and ns:FullName("player")
  return type(me) == "string" and me:lower() == name:lower()
end

function AltFriends.Online(name)
  if IsMe(name) then return true end
  local S = ns.Sync
  if S and S.Online then return S.Online(KeyOf(name)) end
  local seen = S and S.seen and S.seen[KeyOf(name)]
  return type(seen) == "number" and GetTime() - seen < HEARD
end

-- The name the game knows the character by (its first name: the surname is the player's own touch)
local function GameName(name) return name:match("^(%S+)") or name end
AltFriends.GameName = GameName

-- One of the player's characters: in this list, or known to the gold tracker (the account's characters,
-- and the other accounts' through the sync). name: as the game gives it (a first name, maybe a realm).
function AltFriends.IsAlt(name)
  if type(name) ~= "string" or name == "" or (issecretvalue and issecretvalue(name)) then return false end
  local first = (name:match("^([^%-%s]+)") or name):lower()
  if IsMe(name) or first == (UnitName("player") or ""):lower() then return false end
  for _, alt in pairs(List() or {}) do
    if GameName(alt.name):lower() == first then return true end
  end
  local money = ns.Money and ns.Money.db and ns.Money.db.chars
  if type(money) == "table" and money[KeyOf(first:sub(1, 1):upper() .. first:sub(2))] then return true end
  if type(money) == "table" then
    for key in pairs(money) do
      if type(key) == "string" and (key:match("^([^%-]+)") or ""):lower() == first then return true end
    end
  end
  return false
end

function AltFriends.Facts(name)
  local facts = {}
  if IsMe(name) then
    facts.level = UnitLevel and UnitLevel("player")
    facts.class = select(2, UnitClass("player"))
    facts.zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText())
    return facts
  end
  local money = ns.Money and ns.Money.db and ns.Money.db.chars
  local rec = money and money[KeyOf(name)]
  if rec then facts.level, facts.class, facts.at = rec.l, rec.c, rec.at end
  return facts
end

local function ClassName(class)
  return class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function Ago(at)
  if type(at) ~= "number" or at <= 0 or not time then return nil end
  local seconds = math.max(60, time() - at)
  local text = SecondsToTime and SecondsToTime(seconds, false, false, 1) or (math.floor(seconds / 60) .. " min")
  return L.ALT_LAST_SEEN:format(text)
end

---------------------------------------------------------------------------
-- Add Alt: a name typed (first name and surname), with the To field's suggestions
---------------------------------------------------------------------------
local function Box(dialog) return dialog and (dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox) end

local function Dialog()
  if StaticPopupDialogs.CLARA_ADD_ALT then return end
  local choices = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
  StaticPopupDialogs.CLARA_ADD_ALT = {
    text = L.ALT_ADD_ASK,
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    autoCompleteSource = C_AutoComplete and C_AutoComplete.GetAutoCompleteResults or nil,
    autoCompleteArgs = choices and { choices.include, choices.exclude } or nil,
    maxLetters = NAME_MAX,
    OnAccept = function(dialog) local box = Box(dialog) if box then AltFriends.Add(box:GetText()) end end,
    OnShow = function(dialog) local box = Box(dialog) if box then box:SetFocus() end end,
    OnHide = function(dialog) local box = Box(dialog) if box then box:SetText("") end end,
    EditBoxOnEnterPressed = function(editBox)
      AltFriends.Add(editBox:GetText())
      editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0, exclusive = 1, whileDead = 1, hideOnEscape = 1,
  }
end

function AltFriends.Ask()
  Dialog()
  StaticPopup_Show("CLARA_ADD_ALT")
end

---------------------------------------------------------------------------
-- The foot: Add Friend, Add Alt, Send Message, the same width
---------------------------------------------------------------------------
local altButton

local function MakeButton(parent)
  local cui = ns.ClassicUIRuns and ns.ClassicUIPrivate
  local button
  if cui and cui.PanelButton then
    button = cui.PanelButton(parent, L.ALT_ADD_BUTTON, 100) -- (ClassicUI's 1.x button, as the other two there)
  else
    button = CreateFrame("Button", "ClaraAddAltButton", parent, "UIPanelButtonTemplate")
    button:SetText(L.ALT_ADD_BUTTON)
  end
  button:SetScript("OnClick", function() AltFriends.Ask() end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.ALT_ADD_BUTTON, 1, 1, 1)
    GameTooltip:AddLine(L.ALT_ADD_TIP, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return button
end

function AltFriends.LayFoot()
  local add, send = FriendsFrameAddFriendButton, FriendsFrameSendMessageButton
  if not (add and send and FriendsFrame) then return false end
  altButton = altButton or MakeButton(add:GetParent())
  AltFriends.button = altButton
  local width = FriendsFrame:GetWidth() or 0
  if width <= 0 then width = 338 end
  local w = math.floor((width - LEFT - RIGHT - 2 * GAP) / 3)
  add:SetWidth(w)
  send:SetWidth(w)
  altButton:ClearAllPoints()
  altButton:SetPoint("LEFT", add, "RIGHT", GAP, 0)
  altButton:SetPoint("RIGHT", send, "LEFT", -GAP, 0)
  altButton:SetHeight(add:GetHeight() or 21)
  altButton:Show()
  return true
end

---------------------------------------------------------------------------
-- The list: the alts above the offline Battle.net friends
---------------------------------------------------------------------------
local function OfflineBNet(id)
  if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return false end
  local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, id)
  if not ok or type(info) ~= "table" or info.isFavorite then return false end
  local game = info.gameAccountInfo
  return not (game and game.isOnline)
end

-- One the game lists itself (a character friend of another account): left where the game puts it.
local function GameFriend(name)
  if not (C_FriendList and C_FriendList.GetFriendInfo) then return false end
  local ok, info = pcall(C_FriendList.GetFriendInfo, name)
  return ok and type(info) == "table"
end

function AltFriends.AddToList()
  local frame = FriendsListFrame
  local box = frame and frame.ScrollBox
  if not (box and box.GetDataProvider and frame:IsShown()) then return 0 end
  local data = box:GetDataProvider()
  if not data then return 0 end
  local alts = {}
  for _, alt in ipairs(Sorted()) do
    if not GameFriend(alt.name) then alts[#alts + 1] = alt end
  end
  if #alts == 0 then return 0 end
  local BNET, DIVIDER = FRIENDS_BUTTON_TYPE_BNET, FRIENDS_BUTTON_TYPE_DIVIDER
  local size = data:GetSize()
  local at
  for i = 1, size do
    local entry = data:Find(i)
    if entry and entry.buttonType == BNET and OfflineBNet(entry.id) then at = i break end
  end
  local block = {}
  if not at then
    local last = size > 0 and data:Find(size)
    if last and last.buttonType ~= DIVIDER then block[#block + 1] = { buttonType = DIVIDER } end
    at = size + 1
  end
  for i, alt in ipairs(alts) do block[#block + 1] = { id = i, buttonType = TYPE, alt = alt } end
  if at <= size then block[#block + 1] = { buttonType = DIVIDER } end -- (then the offline Battle.net friends)
  for k, entry in ipairs(block) do data:InsertAtIndex(entry, at + k - 1) end
  return #alts
end

function AltFriends.Refresh()
  if FriendsListFrame and FriendsListFrame:IsShown() and FriendsList_Update then FriendsList_Update(true) end
end

---------------------------------------------------------------------------
-- A row: the game's friend row, drawn here; the mouse on a layer of ours (the game's own scripts read
-- its friends only)
---------------------------------------------------------------------------
local function Tip(catcher)
  local alt = catcher.alt
  if not alt then return end
  local facts = AltFriends.Facts(alt.name)
  GameTooltip:SetOwner(catcher, "ANCHOR_RIGHT")
  GameTooltip:SetText(alt.name, 1, 0.82, 0)
  if facts.level and facts.class then
    GameTooltip:AddLine((FRIENDS_LEVEL_TEMPLATE or "Level %d %s"):format(facts.level, ClassName(facts.class)), 1, 1, 1)
  end
  if AltFriends.Online(alt.name) then
    GameTooltip:AddLine(facts.zone or L.ALT_ONLINE, 0.2, 1, 0.2)
  else
    GameTooltip:AddLine(Ago(facts.at) or FRIENDS_LIST_OFFLINE or "Offline", 0.6, 0.6, 0.6)
  end
  GameTooltip:AddLine(L.ALT_ROW_HINT, 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function Menu(catcher)
  local alt = catcher.alt
  if not (alt and MenuUtil and MenuUtil.CreateContextMenu) then return end
  MenuUtil.CreateContextMenu(catcher, function(_, root)
    root:CreateTitle(alt.name)
    if not IsMe(alt.name) then
      root:CreateButton(WHISPER or "Whisper", function()
        local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
        if tell then tell(GameName(alt.name)) end
      end)
      root:CreateButton(PARTY_INVITE or INVITE or "Invite", function()
        local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
        if invite then invite(GameName(alt.name)) end
      end)
    end
    root:CreateButton(L.ALT_REMOVE, function() AltFriends.Remove(alt.name) end)
  end)
end

local function Catcher(button)
  local catcher = button.claraAlt
  if catcher then return catcher end
  catcher = CreateFrame("Button", nil, button)
  catcher:SetAllPoints(button)
  catcher:SetFrameLevel(button:GetFrameLevel() + 10)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  catcher:SetScript("OnEnter", function(self)
    if button.LockHighlight then button:LockHighlight() end
    Tip(self)
  end)
  catcher:SetScript("OnLeave", function()
    if button.UnlockHighlight then button:UnlockHighlight() end
    GameTooltip:Hide()
  end)
  catcher:SetScript("OnClick", function(self, which) if which == "RightButton" then Menu(self) end end)
  button.claraAlt = catcher
  return catcher
end

local function Color(color, alpha)
  if type(color) == "table" and color.GetRGBA then return color:GetRGBA() end
  return 0.588, 0.588, 0.588, alpha or 0.05
end

function AltFriends.DrawRow(button, entry)
  if not button then return end
  local alt = entry and entry.buttonType == TYPE and entry.alt
  if not alt then
    if button.claraAlt then button.claraAlt:Hide(); button.claraAlt.alt = nil end
    return
  end
  local online = AltFriends.Online(alt.name)
  local facts = AltFriends.Facts(alt.name)
  local nameText, info = alt.name, nil
  if online then
    if facts.level and facts.class then
      nameText = alt.name .. ", " .. (FRIENDS_LEVEL_TEMPLATE or "Level %d %s"):format(facts.level, ClassName(facts.class))
    end
    info = facts.zone or L.ALT_ONLINE
  else
    info = Ago(facts.at) or FRIENDS_LIST_OFFLINE or "Offline"
  end
  if button.background then
    button.background:SetColorTexture(Color(online and FRIENDS_WOW_BACKGROUND_COLOR or FRIENDS_OFFLINE_BACKGROUND_COLOR))
  end
  if button.status then
    button.status:SetTexture(online and (FRIENDS_TEXTURE_ONLINE or "Interface\\FriendsFrame\\StatusIcon-Online")
      or (FRIENDS_TEXTURE_OFFLINE or "Interface\\FriendsFrame\\StatusIcon-Offline"))
  end
  if button.name then
    button.name:SetText(nameText)
    local r, g, b = Color(online and FRIENDS_WOW_NAME_COLOR or FRIENDS_GRAY_COLOR)
    if not online and not FRIENDS_GRAY_COLOR then r, g, b = 0.486, 0.518, 0.541 end
    button.name:SetTextColor(r, g, b)
  end
  if button.info then button.info:SetText(info) end
  for _, key in ipairs({ "gameIcon", "travelPassButton", "summonButton", "Favorite" }) do
    if button[key] then button[key]:Hide() end
  end
  button:Show()
  local catcher = Catcher(button)
  catcher.alt = alt
  catcher:Show()
end

---------------------------------------------------------------------------
-- Hooks: the game's own list update and rows, the window shown
---------------------------------------------------------------------------
local hooked = false
local function Hook()
  if hooked or not FriendsFrame then return end
  hooked = true
  if FriendsList_Update then hooksecurefunc("FriendsList_Update", function() AltFriends.AddToList() end) end
  if FriendsFrame_UpdateFriendButton then
    hooksecurefunc("FriendsFrame_UpdateFriendButton", function(button, entry) AltFriends.DrawRow(button, entry) end)
  end
  FriendsFrame:HookScript("OnShow", function() AltFriends.LayFoot() end)
  if FriendsListFrame then FriendsListFrame:HookScript("OnShow", function() AltFriends.LayFoot() end) end
end
AltFriends.Hook = Hook

---------------------------------------------------------------------------
-- Coming and going: said in the chat as the game says it of a friend, the list redrawn
---------------------------------------------------------------------------
local wasOnline = {} -- lower-case whole name -> online when last looked
local settled = false -- (the first moments after login: the ones already online heard, not announced)
local function Announce(alt, online)
  local frame = DEFAULT_CHAT_FRAME
  if not (frame and frame.AddMessage) then return end
  local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
  local r, g, b = info and info.r or 1, info and info.g or 1, info and info.b or 0
  local text
  if online then
    text = (ERR_FRIEND_ONLINE_SS or "|Hplayer:%s|h[%s]|h has come online."):format(GameName(alt.name), alt.name)
  else
    text = (ERR_FRIEND_OFFLINE_S or "%s has gone offline."):format(alt.name)
  end
  frame:AddMessage(text, r, g, b)
end
local function Look(announce)
  local changed = false
  for key, alt in pairs(List() or {}) do
    if not IsMe(alt.name) then
      local on = AltFriends.Online(alt.name) and true or false
      if wasOnline[key] ~= nil and wasOnline[key] ~= on then
        changed = true
        if announce and settled then Announce(alt, on) end
      end
      wasOnline[key] = on
    end
  end
  if changed then AltFriends.Refresh() end
end
AltFriends.Look = Look

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  List()
  Hook()
  Look(false)
  C_Timer.After(20, function() settled = true end)
  if ns.Sync and ns.Sync.OnPresence then ns.Sync.OnPresence(function() Look(true) end) end
  -- (one that left without a word: gone once not heard for a while)
  C_Timer.NewTicker(20, function() Look(true) end)
end)
