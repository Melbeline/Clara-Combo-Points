-- Clara Combo Points - one's other characters in the friends list. WoW Forever keeps the game's
-- character friends (C_FriendList: the server takes them and tells when they come online) but its
-- friends window shows only the Battle.net friends (the game's character friends list is off there).
-- Add Alt, between Add Friend and Send Message (the three the same width), adds a character by its
-- first name and surname, with the suggestions of the mail's To field (the account's characters
-- among them); the character friends then show in the list as the game draws them (online or not,
-- level, class, zone, tooltip, right-click menu), above the offline Battle.net friends. With the
-- client's own list of them on, the game shows them itself and nothing here runs.

local ADDON, ns = ...
local L = ns.L

local GAP = 2               -- between the three foot buttons
local LEFT, RIGHT = 4, 6    -- the game's margins for its two (FriendsFrameButtonTemplate_BottomLeft / _BottomRight)
local NAME_MAX = 12 + 1 + 64 -- a first name, a space, a surname (the game's own Add Friend box)

local AltFriends = {}
ns.AltFriends = AltFriends

-- The game shows its character friends itself (other clients): nothing to add.
local function GameShowsThem()
  local list = C_FriendList
  if not (list and list.GetNumFriends and list.AddFriend) then return true end
  if list.IsLegacyFriendSystemEnabled then
    local ok, on = pcall(list.IsLegacyFriendSystemEnabled)
    return ok and on == true
  end
  return true
end
AltFriends.GameShowsThem = GameShowsThem

---------------------------------------------------------------------------
-- Add Alt: a name typed (first name and surname), with the To field's suggestions
---------------------------------------------------------------------------
function AltFriends.Add(name)
  if type(name) ~= "string" then return false end
  name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
  if name == "" then return false end
  local ok = pcall(C_FriendList.AddFriend, name)
  return ok
end

local function Box(dialog) return dialog and (dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox) end

local function Dialog()
  if StaticPopupDialogs.CLARA_ADD_ALT then return end
  local list = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
  StaticPopupDialogs.CLARA_ADD_ALT = {
    text = L.ALT_ADD_ASK,
    button1 = ACCEPT or "Accept",
    button2 = CANCEL or "Cancel",
    hasEditBox = 1,
    autoCompleteSource = C_AutoComplete and C_AutoComplete.GetAutoCompleteResults or nil,
    autoCompleteArgs = list and { list.include, list.exclude } or nil,
    maxLetters = NAME_MAX,
    OnAccept = function(dialog) AltFriends.Add(Box(dialog) and Box(dialog):GetText()) end,
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
  if not (add and send and FriendsFrame) or GameShowsThem() then
    if altButton then altButton:Hide() end
    return false
  end
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
-- The list: the character friends above the offline Battle.net friends
---------------------------------------------------------------------------
local function OfflineBNet(id)
  if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo) then return false end
  local ok, info = pcall(C_BattleNet.GetFriendAccountInfo, id)
  if not ok or type(info) ~= "table" or info.isFavorite then return false end
  local game = info.gameAccountInfo
  return not (game and game.isOnline)
end

function AltFriends.AddToList()
  if GameShowsThem() then return 0 end
  local frame = FriendsListFrame
  local box = frame and frame.ScrollBox
  if not (box and box.GetDataProvider and frame:IsShown()) then return 0 end
  local data = box:GetDataProvider()
  if not data then return 0 end
  local ok, total = pcall(C_FriendList.GetNumFriends)
  total = ok and tonumber(total) or 0
  if total <= 0 then return 0 end
  local WOW, BNET, DIVIDER = FRIENDS_BUTTON_TYPE_WOW, FRIENDS_BUTTON_TYPE_BNET, FRIENDS_BUTTON_TYPE_DIVIDER
  -- (the game lists them online first: their ids in that order)
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
  for i = 1, total do block[#block + 1] = { id = i, buttonType = WOW } end
  if at <= size then block[#block + 1] = { buttonType = DIVIDER } end -- (then the offline Battle.net friends)
  for k, entry in ipairs(block) do data:InsertAtIndex(entry, at + k - 1) end
  return total
end

---------------------------------------------------------------------------
-- Hooks: the game's own list update, the window shown
---------------------------------------------------------------------------
local hooked = false
local function Hook()
  if hooked or not FriendsFrame then return end
  hooked = true
  if FriendsList_Update then hooksecurefunc("FriendsList_Update", function() AltFriends.AddToList() end) end
  FriendsFrame:HookScript("OnShow", function() AltFriends.LayFoot() end)
  if FriendsListFrame then FriendsListFrame:HookScript("OnShow", function() AltFriends.LayFoot() end) end
end
AltFriends.Hook = Hook

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  Hook()
end)
