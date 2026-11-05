-- Clara Combo Points - the general chat's place and size kept apart from Edit Mode. The game places
-- and sizes the general chat window (ChatFrame1) through Edit Mode only (its own saved place is not
-- read for it), so the place it is given here is put back each time Edit Mode lays the chat out;
-- dragged or sized in Edit Mode, it is Edit Mode's again. The chat tabs' right-click menu ends
-- with Reset chat position: the general chat (and the windows docked with it) back where the game
-- first puts it, an undocked window to the middle of the screen, their size kept.

local ADDON, ns = ...
local L = ns.L
local floor = math.floor

local DEFAULT_X = 35 -- (the game's first place: Edit Mode's default layout)

local function Saved() return ns.sv and ns.sv.chatPlace end

local function Apply()
  local place, chat = Saved(), ChatFrame1
  if not (place and chat) then return end
  chat:ClearAllPoints()
  chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", place.x, place.y)
  if place.w and place.h then chat:SetSize(place.w, place.h) end
end
local function ApplySoon() if Saved() then C_Timer.After(0, Apply) end end

ns.ChatPlace = {}

-- The general chat's place and size now kept (after a move or resize outside Edit Mode)
function ns.ChatPlace.Keep()
  local chat = ChatFrame1
  if not (ns.sv and chat) then return end
  local left, bottom = chat:GetLeft(), chat:GetBottom()
  if not (left and bottom) then return C_Timer.After(0, ns.ChatPlace.Keep) end -- (just sized: next frame)
  ns.sv.chatPlace = { x = floor(left + .5), y = floor(bottom + .5),
    w = floor(chat:GetWidth() + .5), h = floor(chat:GetHeight() + .5) }
  Apply()
end

-- Back where the game first puts it
function ns.ChatPlace.Reset(chatFrame)
  if not chatFrame then return end
  if chatFrame == ChatFrame1 or chatFrame.isDocked then
    local chat = ChatFrame1
    if not (ns.sv and chat) then return end
    local x, y = DEFAULT_X, CHAT_FRAME_ANCHOR_OFFSET_Y or 85
    local ok, info = pcall(function()
      return EditModePresetLayoutManager:GetDefaultSystemAnchorInfo(Enum.EditModeSystem.ChatFrame)
    end)
    if ok and type(info) == "table" and info.point == "BOTTOMLEFT" and info.relativePoint == "BOTTOMLEFT"
      and type(info.offsetX) == "number" and type(info.offsetY) == "number" then
      x, y = info.offsetX, info.offsetY
    end
    ns.sv.chatPlace = { x = x, y = y, w = floor(chat:GetWidth() + .5), h = floor(chat:GetHeight() + .5) }
    Apply()
  else
    chatFrame:ClearAllPoints()
    chatFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(chatFrame) end
  end
end

-- Moved or sized in Edit Mode: Edit Mode's again
local function EditModeTakes()
  if ns.sv and EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
    ns.sv.chatPlace = nil
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  local chat = ChatFrame1
  if chat then
    for _, method in ipairs({ "ApplySystemAnchor", "UpdateSystemSettingWidth", "UpdateSystemSettingHeight" }) do
      if type(chat[method]) == "function" then hooksecurefunc(chat, method, ApplySoon) end
    end
    for _, method in ipairs({ "OnDragStop", "EditMode_OnResized" }) do
      if type(chat[method]) == "function" then hooksecurefunc(chat, method, EditModeTakes) end
    end
  end
  ApplySoon()
  -- (after the other addons' entries, Leatrix Plus's made at login: the last one)
  C_Timer.After(0, function()
    if not (Menu and Menu.ModifyMenu) then return end
    Menu.ModifyMenu("MENU_FCF_TAB", function(owner, rootDescription)
      rootDescription:CreateDivider()
      rootDescription:CreateButton(L.CHAT_RESET, function()
        local id = owner and owner.GetID and owner:GetID()
        ns.ChatPlace.Reset(id and FCF_GetChatFrameByID and FCF_GetChatFrameByID(id) or ChatFrame1)
      end)
    end)
  end)
end)

---------------------------------------------------------------------------
-- The chat channels' order and colours, kept by the channel's name (the game keeps them by
-- number, and a custom channel rejoined at login takes the next free number: its place and its
-- colour were lost). The order set by dragging in Chat settings > Channels, and the colour picked
-- for a channel, come back at each login. L2P: 00A9FF until another is picked.
---------------------------------------------------------------------------
local DEFAULT_COLORS = { l2p = { 0, 169 / 255, 1 } }

local function Store()
  local sv = ns.sv
  if not sv then return end
  local c = type(sv.chatChannels) == "table" and sv.chatChannels or {}
  if type(c.order) ~= "table" then c.order = {} end
  if type(c.colors) ~= "table" then c.colors = {} end
  sv.chatChannels = c
  return c
end

-- "General - Elwynn Forest" and "General" are one channel
local function Key(name)
  if type(name) ~= "string" or name == "" then return end
  return (name:gsub("%s+%-%s+.*$", "")):lower()
end

-- The channels joined, by number: { { index = 1, key = "l2p", name = "L2P" }, ... }
local function Joined()
  local list = {}
  if not GetChannelList then return list end
  local raw = { GetChannelList() }
  for i = 1, #raw, 3 do
    local index, name = raw[i], raw[i + 1]
    local key = Key(name)
    if type(index) == "number" and key then list[#list + 1] = { index = index, key = key, name = name } end
  end
  return list
end

local restoring = false
local ORDER_WINDOW, MAX_SWAPS = 180, 20 -- (seconds after login; swaps a session)
local loginAt, swapsDone = nil, 0
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
  for _, ch in ipairs(Joined()) do order[#order + 1] = ch.key end
  -- the ones not joined now keep their place after them
  for _, key in ipairs(c.order) do
    local seen = false
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
    for _, ch in ipairs(joined) do if ch.key == key then wanted[#wanted + 1] = key break end end
  end
  for _, ch in ipairs(joined) do
    local listed = false
    for _, key in ipairs(wanted) do if key == ch.key then listed = true break end end
    if not listed then wanted[#wanted + 1] = ch.key end
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
  -- the colours, on the numbers the channels have now
  if not ChangeChatColor then return end
  for _, ch in ipairs(Joined()) do
    local color = c.colors[ch.key] or DEFAULT_COLORS[ch.key]
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
channelEvents:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGOUT" then -- (the order as it stands at the end of the session, however it was set)
    if #Joined() > 0 then KeepOrder() end
    return
  end
  if event == "PLAYER_ENTERING_WORLD" and not self.hooked then
    self.hooked = true
    loginAt = GetTime()
    -- a colour picked for a channel: kept for its name
    if ChangeChatColor then
      hooksecurefunc("ChangeChatColor", function(chatType, r, g, b)
        if restoring or type(chatType) ~= "string" then return end
        local index = tonumber(chatType:match("^CHANNEL(%d+)$"))
        local c = Store()
        if not (index and c) then return end
        local key
        for _, ch in ipairs(Joined()) do if ch.index == index then key = ch.key end end
        if key and r and g and b then c.colors[key] = { r, g, b } end
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
ns.ChatChannels = { Apply = ApplyChannels, KeepOrder = KeepOrder, Key = Key }
