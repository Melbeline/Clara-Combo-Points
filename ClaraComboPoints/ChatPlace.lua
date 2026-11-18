-- Clara Combo Points - the chat windows: the general chat (and the windows docked with it) is placed and sized
-- in Edit Mode only, as the game does (a place kept apart from it, Leatrix Plus's easy resizing, pulled the chat
-- and Edit Mode each their way: both are gone). A window taken out of the dock: Reset chat position, the last line
-- of its tab's right-click menu, puts it back in the middle of the screen. The chat channels' order and colours: the
-- game's own (below).

local ADDON, ns = ...
local L = ns.L

ns.ChatPlace = {}

-- A window out of the dock: back in the middle of the screen (the general chat: Edit Mode's)
function ns.ChatPlace.Reset(chatFrame)
  if not chatFrame or chatFrame == ChatFrame1 or chatFrame.isDocked then return end
  chatFrame:ClearAllPoints()
  chatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(chatFrame) end
end

-- The Battle.net toast (a friend online, offline): just above the general chat's tabs, rather than in the chat's
-- alert column on its left, where it lay over the chat's lines. Only the toast: the column also holds the friends
-- button, left where it is. Put back there each time the game lays its alerts out, and as it shows.
-- WoW Forever's world refresh warning ("World refresh in 10 Minutes", ShardTransferImminentFrame, its minimize arrow
-- at its left): the game sets it once, at its load, 55 above the chat's alert column, inside the chat window, and its
-- height follows its text (a longer one first, why the refresh comes). Set by its bottom just above the general chat's
-- tabs, so that text grows upward, never over the chat; the Battle.net toast above it while it shows.
local function Shown(frame) return frame and frame.IsShown and frame:IsShown() end
local function PlaceToast()
  local tab = _G.ChatFrame1Tab
  if not tab then return end
  local shard, toast = _G.ShardTransferImminentFrame, _G.BNToastFrame
  if shard and shard.ClearAllPoints then
    shard:ClearAllPoints()
    shard:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", 0, 4)
  end
  if toast and toast.ClearAllPoints then
    toast:ClearAllPoints()
    if Shown(shard) then
      toast:SetPoint("BOTTOMLEFT", shard, "TOPLEFT", 0, 4)
    else
      toast:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", 0, 4)
    end
  end
end
ns.ChatPlace.PlaceToast = PlaceToast
local toastHooked
local function HookToast()
  if toastHooked or not (_G.BNToastFrame or _G.ShardTransferImminentFrame) then return end
  toastHooked = true
  local alerts = _G.ChatAlertFrame
  if alerts and type(alerts.UpdateAnchors) == "function" then hooksecurefunc(alerts, "UpdateAnchors", PlaceToast) end
  if _G.BNToastFrame then _G.BNToastFrame:HookScript("OnShow", PlaceToast) end
  local shard = _G.ShardTransferImminentFrame
  if shard and shard.HookScript then
    shard:HookScript("OnShow", PlaceToast)
    shard:HookScript("OnHide", PlaceToast)
  end
  PlaceToast()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  HookToast()
  if ns.sv then ns.sv.chatPlace = nil end -- (a place kept outside Edit Mode before: Edit Mode's again)
  -- (after the other addons' entries, Leatrix Plus's made at login: the last one; a window out of the dock only)
  C_Timer.After(0, function()
    if not (Menu and Menu.ModifyMenu) then return end
    Menu.ModifyMenu("MENU_FCF_TAB", function(owner, rootDescription)
      local id = owner and owner.GetID and owner:GetID()
      local frame = id and FCF_GetChatFrameByID and FCF_GetChatFrameByID(id)
      if not frame or frame == ChatFrame1 or frame.isDocked then return end
      rootDescription:CreateDivider()
      rootDescription:CreateButton(L.CHAT_RESET, function() ns.ChatPlace.Reset(frame) end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- The chat channels: their order and their colours are the game's own, left to it entirely (nothing of Clara's
-- moves or recolours them). Only the addons' hidden channels (UnitScan Hardcore's ushccomms, Clara Sync's) wait
-- until the game's channels and the ones the server rejoins are in (settled), to take the last numbers rather
-- than one of the player's (UnitScan.lua, Sync.lua).
---------------------------------------------------------------------------
local loginAt -- (GetTime() at login)
local lastChannelChange = 0
local function Settled()
  local now = GetTime()
  if loginAt == nil then return false end
  return now - loginAt >= 60 or (now - loginAt >= 10 and now - lastChannelChange >= 6)
end

local channelEvents = CreateFrame("Frame")
channelEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
channelEvents:RegisterEvent("CHANNEL_UI_UPDATE")
channelEvents:SetScript("OnEvent", function(_, event)
  if event == "CHANNEL_UI_UPDATE" then lastChannelChange = GetTime() return end
  if loginAt then return end
  loginAt = GetTime()
  -- (the order and colours Clara kept by the channels' names until now: forgotten, the game's own stand)
  if ns.sv then ns.sv.chatChannels = nil end
end)
ns.ChatChannels = { Settled = Settled }
