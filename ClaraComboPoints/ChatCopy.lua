-- Clara Combo Points - copying from the chat. A right click on a player's name in a chat line opens
-- the game's menu, with Copy Chat Message: that very line's message (the game keeps each line's
-- text by its number). Web addresses in the chat are links: a click on one, the same. The game lets
-- no addon write to the clipboard, so the text comes up selected in a small box at the mouse:
-- Ctrl+C copies it and closes the box (Escape, or a click elsewhere, closes it too).
-- In the menu, Copy Chat Message stands before Copy Character Name when its name is the shorter of
-- the two, last otherwise.

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local LINK = "addon:" .. ADDON .. ":url:"

---------------------------------------------------------------------------
-- The box
---------------------------------------------------------------------------
local box
local function Box()
  if box then return box end
  box = CreateFrame("Frame", "ClaraChatCopyBox", UIParent, "TooltipBackdropTemplate")
  box:SetFrameStrata("FULLSCREEN_DIALOG")
  box:SetClampedToScreen(true)
  box:SetSize(360, 52)
  box:Hide()
  box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  box.hint:SetPoint("BOTTOMLEFT", 10, 7)
  box.hint:SetPoint("BOTTOMRIGHT", -10, 7)
  box.hint:SetJustifyH("LEFT")
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetPoint("TOPLEFT", 10, -8)
  edit:SetPoint("TOPRIGHT", -10, -8)
  edit:SetHeight(20)
  edit:SetFontObject("ChatFontNormal")
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", function() box:Hide() end)
  edit:SetScript("OnEditFocusLost", function() box:Hide() end)
  -- the text stays as it is: a key typed puts it back, selected
  edit:SetScript("OnTextChanged", function(self, user)
    if user and self:GetText() ~= box.text then
      self:SetText(box.text)
      self:HighlightText()
    end
  end)
  edit:SetScript("OnKeyDown", function(_, key)
    if key == "C" and IsControlKeyDown() then C_Timer.After(0, function() box:Hide() end) end
  end)
  box.edit = edit
  return box
end

function ns.ShowCopyBox(text)
  if type(text) ~= "string" or text == "" or issecret(text) then return end
  local b = Box()
  b.text = text
  b.hint:SetText(L.COPY_HINT)
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale - 20, y / scale + 8)
  b:Show()
  b.edit:SetText(text)
  b.edit:SetCursorPosition(0)
  b.edit:SetFocus()
  b.edit:HighlightText()
end

---------------------------------------------------------------------------
-- Copy Chat Message, in the menu of a name in the chat
---------------------------------------------------------------------------
-- A chat line's message as written, without the game's markup
local function Plain(text)
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
  return text
end

local measure
local function Width(text)
  if not measure then
    measure = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    measure:Hide()
  end
  measure:SetText(text)
  local w = measure:GetStringWidth()
  if not w or w <= 0 then return strlenutf8 and strlenutf8(text) or #text end
  return w
end

local function AddCopyLine(_, root, contextData)
  local lineID = contextData and contextData.lineID
  if not lineID or issecret(lineID) or not (C_ChatInfo and C_ChatInfo.GetChatLineText) then return end
  local button = MenuUtil.CreateButton(L.COPY_CHAT_MESSAGE, function()
    local ok, text = pcall(C_ChatInfo.GetChatLineText, lineID)
    if ok and type(text) == "string" and not issecret(text) then ns.ShowCopyBox(Plain(text)) end
  end)
  -- before Copy Character Name if shorter, last otherwise
  local at
  if COPY_CHARACTER_NAME and Width(L.COPY_CHAT_MESSAGE) < Width(COPY_CHARACTER_NAME) then
    for index, description in root:EnumerateElementDescriptions() do
      if MenuUtil.GetElementText(description) == COPY_CHARACTER_NAME then at = index break end
    end
  end
  if at then root:Insert(button, at) else root:Insert(button) end
end

if Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.CreateButton then
  for _, which in ipairs({ "FRIEND", "BN_FRIEND" }) do Menu.ModifyMenu("MENU_UNIT_" .. which, AddCopyLine) end
end

---------------------------------------------------------------------------
-- Web addresses: links
---------------------------------------------------------------------------
local STARTS = { "https?://", "www%.", "discord%.gg/" }

local function Address(word)
  local s
  for _, start in ipairs(STARTS) do
    local found = word:find(start)
    if found and (not s or found < s) then s = found end
  end
  if not s then return end
  local before, rest = word:sub(1, s - 1), word:sub(s)
  local after = rest:match("[%.,;:!%?%)%]\"']+$") or ""
  local url = rest:sub(1, #rest - #after)
  if #url < 6 then return end
  return before .. "|cff3fa9f5|H" .. LINK .. url .. "|h[" .. url .. "]|h|r" .. after
end

-- The words outside the links already there
local function Linked(text)
  local out, pos = {}, 1
  while true do
    local s, e = text:find("|H.-|h.-|h", pos)
    local plain = text:sub(pos, s and s - 1 or nil)
    out[#out + 1] = plain:gsub("%S+", function(word) return Address(word) end)
    if not s then break end
    out[#out + 1] = text:sub(s, e)
    pos = e + 1
  end
  return table.concat(out)
end
ns.ChatLinked = Linked

local EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
  "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_COMMUNITIES_CHANNEL", "CHAT_MSG_SYSTEM" }

local function Filter(_, _, message, ...)
  if type(message) ~= "string" or issecret(message) then return false end
  if not (message:find("://", 1, true) or message:find("www.", 1, true) or message:find("discord.gg/", 1, true)) then return false end
  local linked = Linked(message)
  if linked == message then return false end
  return false, linked, ...
end

local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if AddFilter then
  for _, event in ipairs(EVENTS) do AddFilter(event, Filter) end
end

-- A click on one: the box
if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    if type(link) == "string" and link:sub(1, #LINK) == LINK then ns.ShowCopyBox(link:sub(#LINK + 1)) end
  end, ns)
end
