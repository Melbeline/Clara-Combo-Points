-- Clara Combo Points - the chat windows: the general chat (and the windows docked with it) is placed and sized
-- in Edit Mode only, as the game does (a place kept apart from it pulled the chat and Edit Mode each their way:
-- gone). A window taken out of the dock: Reset chat position, the last line
-- of its tab's right-click menu, puts it back in the middle of the screen. The chat channels: their order the game's
-- own, their colours kept for each channel (below).

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
-- The chat channels. Their order is the game's own, left to it. Their colours are kept for each channel, whatever
-- its number: the game keeps a colour by number (CHANNEL1, CHANNEL2...), and the number of a channel changes (a
-- channel rejoined at login takes the next free one; dragging channels in Chat settings > Channels swaps the colours
-- for the session only, the numbers keep their old ones for the next): each login gave the channels each other's
-- colours. A channel's colour: the one picked for it (Chat settings, the game's colour picker: kept for the account),
-- else its default: the custom channel l2p 00A9FF, the community L2P 40FF40, any other FFC0C0. Given back to the
-- game under the channel's number now (ChangeChatColor: the game keeps it for the next login too) once the channels
-- have joined, and each time they change (a join, a leave, a swap). The game's Defaults button (Chat settings):
-- the colours picked forgotten, the defaults back.
-- The addons' hidden channels (UnitScan Hardcore's ushccomms, Clara Sync's) wait until the game's channels and the
-- ones the server rejoins are in (settled), to take the last numbers rather than one of the player's (UnitScan.lua,
-- Sync.lua).
---------------------------------------------------------------------------
local loginAt -- (GetTime() at login)
local lastChannelChange = 0
local function Settled()
  local now = GetTime()
  if loginAt == nil then return false end
  return now - loginAt >= 60 or (now - loginAt >= 10 and now - lastChannelChange >= 6)
end

local issecret = issecretvalue or function() return false end
local function Hex(hex) return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 } end
local DEFAULT_OTHER = Hex("FFC0C0")
local DEFAULT_L2P = Hex("00A9FF")       -- (the custom channel l2p)
local DEFAULT_L2P_CLUB = Hex("40FF40")  -- (the community L2P)

-- A channel's identity: a community's channel by its community and stream ("community:12:1", whatever its name);
-- another by its name, lower-case, its zone left out ("General - Elwynn Forest" is "general")
local function Key(name)
  if type(name) ~= "string" or issecret(name) or name == "" then return nil end
  local club, stream = name:match("^[Cc]ommunity:(%d+):(%d+)")
  if club then return "community:" .. club .. ":" .. stream, true end
  return (name:gsub("%s+%-%s+.*$", "")):lower(), false
end

-- The name shown for a community's channel (its community's, and its stream's); nil while the game has not the
-- community yet (right after login)
local function Shown(name)
  local util = ChatFrameUtil
  if not (util and util.ResolveChannelName) then return nil end
  local ok, shown = pcall(util.ResolveChannelName, name)
  if not ok or type(shown) ~= "string" or issecret(shown) or shown == "" or shown == name then return nil end
  return shown
end

-- (nil: a community's channel whose name is not known yet: left until it is)
local function Default(key, club, name)
  if club then
    local shown = Shown(name)
    if not shown then return nil end
    if shown:lower():find("^l2p") then return DEFAULT_L2P_CLUB end
    return DEFAULT_OTHER
  end
  if key == "l2p" then return DEFAULT_L2P end
  return DEFAULT_OTHER
end

local function Picks()
  local sv = ns.sv
  if not sv then return nil end
  if type(sv.channelColors) ~= "table" then sv.channelColors = {} end
  return sv.channelColors
end

-- The channels joined, by number: { { index = 1, key = "l2p", club = false, name = "l2p" }, ... }
local function Joined()
  local list = {}
  if not GetChannelList then return list end
  local ok, raw = pcall(function() return { GetChannelList() } end)
  if not ok then return list end
  for i = 1, #raw, 3 do
    local index, name = raw[i], raw[i + 1]
    local key, club = Key(name)
    if type(index) == "number" and not issecret(index) and key then
      list[#list + 1] = { index = index, key = key, club = club, name = name }
    end
  end
  return list
end

-- The colour a channel should have: the one picked for it, else its default
local function Wanted(ch)
  local picks = Picks()
  local pick = picks and picks[ch.key]
  if type(pick) == "table" and type(pick[1]) == "number" then return pick end
  return Default(ch.key, ch.club, ch.name)
end

local applying = false
local function Differs(info, c)
  if not info then return true end
  return math.abs((info.r or 0) - c[1]) > .004 or math.abs((info.g or 0) - c[2]) > .004 or math.abs((info.b or 0) - c[3]) > .004
end
-- Each channel's colour given to the game under its number now; all of them again with force (after a swap: the
-- game moved its colours for the session only). True when one could not be told yet (a community not loaded).
local function ApplyColors(force)
  if not ChangeChatColor then return false end
  local later = false
  for _, ch in ipairs(Joined()) do
    local c = Wanted(ch)
    local chatType = "CHANNEL" .. ch.index
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if not c then
      later = true
    elseif force or Differs(info, c) then
      applying = true
      pcall(ChangeChatColor, chatType, c[1], c[2], c[3])
      applying = false
    end
  end
  return later
end

local pendingColors, pendingForce
local retries = 0
local ColorsSoon
function ColorsSoon(force, delay)
  if force then pendingForce = true end
  if pendingColors then return end
  pendingColors = true
  C_Timer.After(delay or 1, function()
    pendingColors = nil
    local f = pendingForce
    pendingForce = nil
    -- (a community's channel not known yet: again a few seconds on, a minute at most)
    if ApplyColors(f) and retries < 12 then
      retries = retries + 1
      ColorsSoon(false, 5)
    end
  end)
end

-- A colour picked by the player (Chat settings or the game's colour picker open): kept for that channel
local function Picking()
  local config, picker = _G.ChatConfigFrame, _G.ColorPickerFrame
  return (config and config.IsShown and config:IsShown()) or (picker and picker.IsShown and picker:IsShown()) or false
end
local function KeepPick(chatType, r, g, b)
  if applying or not Picking() then return end
  local index = type(chatType) == "string" and not issecret(chatType) and tonumber(chatType:match("^CHANNEL(%d+)$"))
  local picks = Picks()
  if not (index and picks and type(r) == "number" and type(g) == "number" and type(b) == "number") then return end
  for _, ch in ipairs(Joined()) do
    if ch.index == index then picks[ch.key] = { r, g, b } end
  end
end

local hooked = false
local function Hook()
  if hooked then return end
  hooked = true
  if ChangeChatColor then hooksecurefunc("ChangeChatColor", KeepPick) end
  -- the channels dragged in Chat settings: the game swaps their colours for the session only; given to it again
  if C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex then
    hooksecurefunc(C_ChatInfo, "SwapChatChannelsByChannelIndex", function() ColorsSoon(true, 0.5) end)
  end
  -- the game's Defaults (Chat settings): the colours picked forgotten, the defaults back
  if ResetChatColors then
    hooksecurefunc("ResetChatColors", function()
      if ns.sv then ns.sv.channelColors = {} end
      ColorsSoon(true, 0.5)
    end)
  end
end

local channelEvents = CreateFrame("Frame")
channelEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
channelEvents:RegisterEvent("CHANNEL_UI_UPDATE")
for _, e in ipairs({ "CLUB_STREAMS_LOADED", "CLUB_ADDED", "INITIAL_CLUBS_LOADED" }) do pcall(channelEvents.RegisterEvent, channelEvents, e) end
channelEvents:SetScript("OnEvent", function(_, event)
  if event == "CHANNEL_UI_UPDATE" then
    lastChannelChange = GetTime()
    if loginAt then ColorsSoon(false, 1) end
    return
  end
  if event ~= "PLAYER_ENTERING_WORLD" then -- (the communities loaded: their channels' names known now)
    if loginAt then ColorsSoon(false, 1) end
    return
  end
  if loginAt then return end
  loginAt = GetTime()
  -- (the order and colours an earlier Clara kept by the channels' names: forgotten)
  if ns.sv then ns.sv.chatChannels = nil end
  Hook()
  ColorsSoon(false, 2)
end)
ns.ChatChannels = { Settled = Settled, Key = Key, Wanted = Wanted, ApplyColors = ApplyColors, Joined = Joined }
