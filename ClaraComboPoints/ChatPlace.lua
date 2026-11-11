-- Clara Combo Points - the chat windows: the general chat (and the windows docked with it) is placed and sized
-- in Edit Mode only, as the game does (a place kept apart from it pulled the chat and Edit Mode each their way:
-- gone). A window taken out of the dock: Reset chat position, the last line
-- of its tab's right-click menu, puts it back in the middle of the screen. And the chat channels (below).

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
local function PlaceToast()
  local toast, tab = _G.BNToastFrame, _G.ChatFrame1Tab
  if not (toast and tab and toast.ClearAllPoints) then return end
  toast:ClearAllPoints()
  toast:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", 0, 4)
end
ns.ChatPlace.PlaceToast = PlaceToast
local toastHooked
local function HookToast()
  if toastHooked or not _G.BNToastFrame then return end
  toastHooked = true
  local alerts = _G.ChatAlertFrame
  if alerts and type(alerts.UpdateAnchors) == "function" then hooksecurefunc(alerts, "UpdateAnchors", PlaceToast) end
  _G.BNToastFrame:HookScript("OnShow", PlaceToast)
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
-- The chat channels' order and colours, kept by the channel's name (the game keeps them by
-- number, and a custom channel rejoined at login takes the next free number: its place and its
-- colour were lost). The order set by dragging in Chat settings > Channels, and the colour picked
-- for a channel, come back at each login, as in 1.15.9: a channel keeps its place and the colour picked for it.
-- No colour of Clara's: a channel never given one keeps the game's.
---------------------------------------------------------------------------
local loginAt -- (GetTime() at login)

local function Store()
  local sv = ns.sv
  if not sv then return end
  local c = type(sv.chatChannels) == "table" and sv.chatChannels or {}
  if type(c.order) ~= "table" then c.order = {} end
  if type(c.colors) ~= "table" then c.colors = {} end
  -- (the colours kept before each channel had its own: some were taken from the number a channel had at
  -- login, another's; forgotten once)
  if c.v ~= 2 then c.colors, c.v = {}, 2 end
  sv.chatChannels = c
  return c
end

-- "General - Elwynn Forest" and "General" are one channel
local function Key(name)
  if type(name) ~= "string" or name == "" then return end
  return (name:gsub("%s+%-%s+.*$", "")):lower()
end

-- The addons' hidden channels (UnitScan Hardcore's ushccomms, Clara Sync's): never among the player's own, always
-- after them (joined last: UnitScan.lua, Sync.lua)
local function Hidden(key) return key == "ushccomms" or key:find("^clarasync") ~= nil end

-- The channels joined, by number: { { index = 1, key = "l2p", name = "L2P" }, ... }
local function Joined()
  local list = {}
  if not GetChannelList then return list end
  local raw = { GetChannelList() }
  for i = 1, #raw, 3 do
    local index, name = raw[i], raw[i + 1]
    local key = Key(name)
    if type(index) == "number" and key then list[#list + 1] = { index = index, key = key, name = name, hidden = Hidden(key) } end
  end
  return list
end

-- The channels settled after login (the game's and the ones the server rejoins come one by one for a few seconds):
-- an addon's hidden channel is joined only then, to take the last number
local lastChannelChange = 0
local function Settled()
  local now = GetTime()
  if loginAt == nil then return false end
  return now - loginAt >= 60 or (now - loginAt >= 10 and now - lastChannelChange >= 6)
end

local restoring = false
local ORDER_WINDOW, MAX_SWAPS = 180, 20 -- (seconds after login; swaps a session)
local swapsDone = 0
local function Swap(a, b)
  local swap = C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex
  if not swap or a == b then return false end
  restoring = true
  local ok = pcall(swap, a, b)
  restoring = false
  return ok
end

-- The order kept: the channels joined now, in their numbers' order
local function KeepOrder()
  local c = Store()
  if not c then return end
  local order = {}
  for _, ch in ipairs(Joined()) do if not ch.hidden then order[#order + 1] = ch.key end end
  -- the ones not joined now keep their place after them
  for _, key in ipairs(c.order) do
    local seen = Hidden(key)
    for _, k in ipairs(order) do if k == key then seen = true break end end
    if not seen then order[#order + 1] = key end
  end
  c.order = order
end

local function ApplyChannels()
  local c = Store()
  if not c then return end
  if InCombatLockdown() then C_Timer.After(5, ApplyChannels) return end -- (after the fight)
  -- the order: each kept channel to its place among the ones joined, the others after them as they are
  local joined = Joined()
  local wanted = {}
  for _, key in ipairs(c.order) do
    for _, ch in ipairs(joined) do if ch.key == key and not ch.hidden then wanted[#wanted + 1] = key break end end
  end
  for pass = 1, 2 do -- (the player's own channels, then the hidden ones, last)
    for _, ch in ipairs(joined) do
      local listed = false
      for _, key in ipairs(wanted) do if key == ch.key then listed = true break end end
      if not listed and (pass == 1) ~= ch.hidden then wanted[#wanted + 1] = ch.key end
    end
  end
  -- One swap a pass: the game's list changes only once the server has done it (CHANNEL_UI_UPDATE brings the next
  -- pass); only in the minutes after login (later moves are the player's own), a handful at most.
  if GetTime() - (loginAt or 0) < ORDER_WINDOW and swapsDone < MAX_SWAPS then
    local now = Joined()
    for pos, key in ipairs(wanted) do
      local here = now[pos]
      if here and here.key ~= key then
        for _, ch in ipairs(now) do
          if ch.key == key then
            if Swap(ch.index, here.index) then swapsDone = swapsDone + 1 end
            break
          end
        end
        break
      end
    end
  end
  -- the colours picked, on the numbers the channels have now (a number keeps the colour of the channel it had
  -- before); a channel never given one, and the communities' channels, left to the game
  if not ChangeChatColor then return end
  for _, ch in ipairs(Joined()) do
    local color = not ch.key:find("^community:") and not ch.hidden and c.colors[ch.key]
    local info = ChatTypeInfo and ChatTypeInfo["CHANNEL" .. ch.index]
    if type(color) == "table" and info
      and (math.abs((info.r or 0) - color[1]) > .004 or math.abs((info.g or 0) - color[2]) > .004 or math.abs((info.b or 0) - color[3]) > .004) then
      restoring = true
      pcall(ChangeChatColor, "CHANNEL" .. ch.index, color[1], color[2], color[3])
      restoring = false
    end
  end
end

-- Channels join one by one for a few seconds after login: put back once they are settled
local pending
local function ChannelsSoon()
  if pending then return end
  pending = true
  C_Timer.After(2, function()
    pending = nil
    ApplyChannels()
  end)
end

local channelEvents = CreateFrame("Frame")
channelEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
channelEvents:RegisterEvent("CHANNEL_UI_UPDATE")
channelEvents:RegisterEvent("PLAYER_LOGOUT")
channelEvents:RegisterEvent("UPDATE_CHAT_COLOR")
-- A colour picked by the player: the chat settings or the colour picker open
local function Picking()
  local config, picker = _G.ChatConfigFrame, _G.ColorPickerFrame
  return (config and config.IsShown and config:IsShown()) or (picker and picker.IsShown and picker:IsShown()) or false
end
local function KeepColor(chatType, r, g, b)
  local index = type(chatType) == "string" and tonumber(chatType:match("^CHANNEL(%d+)$"))
  local c = Store()
  if not (index and c and r and g and b) then return end
  for _, ch in ipairs(Joined()) do
    if ch.index == index and not ch.hidden then c.colors[ch.key] = { r, g, b } end
  end
end
local recolorAt = 0
channelEvents:SetScript("OnEvent", function(self, event, arg1, r, g, b)
  if event == "PLAYER_LOGOUT" then -- (the order as it stands at the end of the session, however it was set)
    if #Joined() > 0 then KeepOrder() end
    return
  end
  if event == "UPDATE_CHAT_COLOR" then
    if restoring or type(arg1) ~= "string" or not arg1:find("^CHANNEL%d") then return end
    if Picking() then KeepColor(arg1, r, g, b) return end -- (the player's: kept for the channel's name)
    -- the game (or another addon) put a number's colour back on a channel given one: its own again, a moment later
    if GetTime() - recolorAt < 1 then return end
    recolorAt = GetTime()
    C_Timer.After(.5, function() if not InCombatLockdown() then ApplyChannels() end end)
    return
  end
  if event == "CHANNEL_UI_UPDATE" then lastChannelChange = GetTime() end
  if event == "PLAYER_ENTERING_WORLD" and not self.hooked then
    self.hooked = true
    loginAt = GetTime()
    -- a colour picked for a channel (in Chat settings, the game's colour picker): kept for its name
    if ChangeChatColor then
      hooksecurefunc("ChangeChatColor", function(chatType, r, g, b)
        if restoring or not Picking() then return end
        KeepColor(chatType, r, g, b)
      end)
    end
    -- the order changed by dragging: kept
    if C_ChatInfo and C_ChatInfo.SwapChatChannelsByChannelIndex then
      hooksecurefunc(C_ChatInfo, "SwapChatChannelsByChannelIndex", function()
        if restoring then return end
        C_Timer.After(0.5, KeepOrder)
      end)
    end
  end
  ChannelsSoon()
end)
ns.ChatChannels = { Apply = ApplyChannels, KeepOrder = KeepOrder, Key = Key, Settled = Settled, Hidden = Hidden }
