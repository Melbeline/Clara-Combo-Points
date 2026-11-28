-- Clara Combo Points - copying from the chat. A right click on a player's name in a chat line opens
-- the game's menu, with Copy Chat Message: that very line's message (the game keeps each line's
-- text by its number). Web addresses in the chat are links: a click on one, the same. The game lets
-- no addon write to the clipboard, so the text comes up selected in a small box at the mouse, the
-- whole of it on as many lines as it takes: Ctrl+C copies it and closes the box (Escape, Enter, or a
-- click elsewhere, closes it too).
-- In the menu, Copy Chat Message is last: the game lets an addon add only after its own entries (one put
-- higher moves the game's, which are then refused what they do: Copy Character Name's clipboard). Not in
-- combat: the menu's buttons made for an addon's entries are refused their frame level then.
-- Prat (another chat addon): what it does too is left to it, Clara's own stepping aside (web addresses
-- made links by Prat's UrlCopy; the level by the name by its PlayerNames; the chat put back by its History).

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local LINK = "addon:" .. ADDON .. ":url:"

---------------------------------------------------------------------------
-- Prat, when loaded: one of its modules, on, and its settings (nil when Prat or that module is off)
---------------------------------------------------------------------------
function ns.PratModule(name)
  local P = rawget(_G, "Prat")
  local addon = type(P) == "table" and rawget(P, "Addon")
  if type(addon) ~= "table" or type(addon.GetModule) ~= "function" then return nil end
  local ok, m = pcall(addon.GetModule, addon, name, true)
  if not ok or type(m) ~= "table" then return nil end
  local profile = type(m.db) == "table" and m.db.profile
  if type(profile) ~= "table" or profile.on == false then return nil end
  if type(m.IsEnabled) == "function" then
    local okOn, on = pcall(m.IsEnabled, m)
    if okOn and on == false then return nil end
  end
  return m, profile
end

---------------------------------------------------------------------------
-- The box
---------------------------------------------------------------------------
local WIDTH, PAD, MAX_H = 400, 10, 220
local box
local function Box()
  if box then return box end
  box = CreateFrame("Frame", "ClaraChatCopyBox", UIParent, "TooltipBackdropTemplate")
  box:SetFrameStrata("FULLSCREEN_DIALOG")
  box:SetClampedToScreen(true)
  box:SetSize(WIDTH, 60)
  box:EnableMouse(true)
  box:Hide()
  box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  box.hint:SetPoint("BOTTOMLEFT", PAD, 7)
  box.hint:SetPoint("BOTTOMRIGHT", -PAD, 7)
  box.hint:SetJustifyH("LEFT")
  -- (to measure the text's height on as many lines as it takes, the box's width: drawn unseen, a hidden one is not
  -- measured by the game, its height 0)
  box.measure = box:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
  box.measure:SetWidth(WIDTH - 2 * PAD)
  box.measure:SetJustifyH("LEFT")
  box.measure:SetPoint("TOPLEFT", PAD, -8)
  box.measure:SetAlpha(0)
  -- The text: a width of its own, given (one taken from its anchors only was not known yet as the text was put in, and the
  -- game showed it scrolled out of sight: the box empty), on several lines (a long line whole, not one end of it)
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal or GameFontHighlight)
  edit:SetWidth(WIDTH - 2 * PAD)
  edit:SetHeight(20)
  edit:SetPoint("TOPLEFT", PAD, -8)
  edit:SetScript("OnEscapePressed", function() box:Hide() end)
  edit:SetScript("OnEnterPressed", function() box:Hide() end)
  edit:SetScript("OnEditFocusLost", function() box:Hide() end)
  edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  -- the text stays as it is: a key typed puts it back, selected
  edit:SetScript("OnTextChanged", function(self, user)
    if user and self:GetText() ~= box.text then
      self:SetText(box.text or "")
      self:HighlightText()
    end
  end)
  edit:SetScript("OnKeyDown", function(_, key)
    if key == "C" and IsControlKeyDown() then C_Timer.After(0, function() box:Hide() end) end
  end)
  box:SetScript("OnMouseUp", function() edit:SetFocus() edit:HighlightText() end)
  box:SetScript("OnHide", function() edit:ClearFocus() end)
  box.edit = edit
  return box
end

-- One line's height in the box's font, with room to spare
local function LineHeight()
  local font = ChatFontNormal
  local size = 14
  if font and font.GetFont then
    local _, s = font:GetFont()
    if type(s) == "number" and s > 0 then size = s end
  end
  return math.ceil(size * 1.3) + 2
end

-- The text's room: never less than a whole line with room to spare (a line that doesn't fit whole in its box is not
-- drawn at all: the box looked empty, a measure of 0 leaving it 16 high for a font of about that)
local function Fit(b, text)
  local line = LineHeight()
  b.measure:SetText(text)
  local measured = tonumber(b.measure:GetStringHeight()) or 0
  local h = math.min(MAX_H, math.max(line + 6, math.ceil(measured) + 10))
  b.edit:SetHeight(h)
  b:SetHeight(h + 34)
end
ns.CopyBoxFit = Fit -- (for the tests)

-- Only whole UTF-8 characters (a name cut in the middle of one: a text box shows nothing of a text holding it)
local function WholeCharacters(s)
  if not s:find("[\128-\255]") then return s end
  local out, i, n = {}, 1, #s
  while i <= n do
    local c = s:byte(i)
    local len = c < 0x80 and 1 or (c >= 0xC2 and c <= 0xDF) and 2 or (c >= 0xE0 and c <= 0xEF) and 3
      or (c >= 0xF0 and c <= 0xF4) and 4 or 0
    local whole = len > 0 and i + len - 1 <= n
    if whole then
      for k = i + 1, i + len - 1 do
        local b = s:byte(k)
        if b < 0x80 or b > 0xBF then whole = false break end
      end
    end
    if whole then out[#out + 1] = s:sub(i, i + len - 1) i = i + len else i = i + 1 end
  end
  return table.concat(out)
end

-- A text the box can show, as it reads: the game's markup left out (colors, the newer named colors, links, icons, a
-- protected Battle.net name: the game's text boxes show nothing at all of a text holding one), control characters as
-- spaces, a bar kept as the text box writes it
local function Readable(text)
  text = text:gsub("||", "\001")
  text = text:gsub("|K.-|k", "?")
  text = text:gsub("|c[nN][^:|]*:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub(" ?|T.-|t", ""):gsub(" ?|A.-|a", "")
  text = text:gsub("|n", " "):gsub("|.", ""):gsub("|", "")
  text = text:gsub("[%z\002-\031\127]", " ")
  text = WholeCharacters(text):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return (text:gsub("\001", "||"))
end
ns.CopyReadable = Readable -- (for the tests)

function ns.ShowCopyBox(text, line)
  if type(text) ~= "string" or text == "" or issecret(text) then return end
  local given = text
  text = Readable(text)
  if text == "" then return end
  -- (kept for /cl chat: what was asked, what the box was given, what it holds)
  ns.lastCopy = { line = type(line) == "string" and not issecret(line) and line or nil, given = given, shown = text }
  local b = Box()
  b.text = text
  b.hint:SetText(L.COPY_HINT)
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale - 20, y / scale + 8)
  b:Show()
  Fit(b, text)
  b.edit:SetText(text)
  b.edit:SetCursorPosition(0)
  b.edit:SetFocus()
  b.edit:HighlightText()
  -- once more as the box is drawn: its place, its size and the text's measure known
  C_Timer.After(0, function()
    if b:IsShown() and b.text == text then
      Fit(b, text)
      b.edit:SetText(text)
      b.edit:SetCursorPosition(0)
      b.edit:SetFocus()
      b.edit:HighlightText()
      if ns.lastCopy and ns.lastCopy.shown == text then
        local ok, now = pcall(b.edit.GetText, b.edit)
        ns.lastCopy.boxText = ok and now or nil
        ns.lastCopy.boxHeight = b.edit:GetHeight()
      end
    end
  end)
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

local function AddCopyLine(_, root, contextData)
  if InCombatLockdown() then return end
  local lineID = contextData and contextData.lineID
  if not lineID or issecret(lineID) or not (C_ChatInfo and C_ChatInfo.GetChatLineText) then return end
  root:CreateButton(L.COPY_CHAT_MESSAGE, function()
    local ok, text = pcall(C_ChatInfo.GetChatLineText, lineID)
    if ok and type(text) == "string" and not issecret(text) then ns.ShowCopyBox(Plain(text)) end
  end)
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
  if ns.PratModule("UrlCopy") then return false end -- (Prat makes them links)
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
