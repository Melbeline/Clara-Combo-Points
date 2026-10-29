-- Clara Combo Points - the general chat's place and size kept apart from Edit Mode. The game places
-- and sizes the general chat window (ChatFrame1) through Edit Mode only (its own saved place is not
-- read for it), so a move or resize outside Edit Mode (Leatrix Plus's easy resizing: its grip in the
-- bottom right corner, its tab dragged) is kept here and put back each time Edit Mode lays the chat
-- out; dragged or sized in Edit Mode, it is Edit Mode's again. The chat tabs' right-click menu ends
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
