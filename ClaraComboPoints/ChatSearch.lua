-- Clara Combo Points - the chat searched: a search box in a chat window's tab menu (right-click on its tab), under
-- the menu's first line (Edit Mode, or Lock). What is typed is looked for in every line the window holds (colors,
-- links and icons read as the text they show; capitals, accents and punctuation ignored), and the window scrolled to
-- the newest line holding it, that line in the middle. Its arrows: the match before (up: older) or after (down:
-- newer), round again at either end; Enter: the match before. "3/12" beside them. Emptied: the window back at its
-- bottom. Each window keeps its search while the game runs (the menu opened again shows it).

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end
local WAIT = 0.3 -- seconds after the last key before the window is searched

---------------------------------------------------------------------------
-- The window's lines, as they read
---------------------------------------------------------------------------
-- What a line shows: its colors, links (their text kept), icons and atlases out
local function Shown(text)
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|[TA].-|[ta]", ""))
end

-- A line's search key, kept (the same line read again at once; let go past many lines)
local keys, kept = {}, 0
local function KeyOf(text)
  local key = keys[text]
  if key then return key end
  key = ns:SearchKey(Shown(text))
  if kept >= 120000 then keys, kept = {}, 0 end
  keys[text], kept = key, kept + 1
  return key
end

-- The window's lines read ahead, newest first, a part each frame (as its menu opens: the first search then quick,
-- a window of 50000 lines read in about half a second without a halt)
local PER_FRAME = 1500
local warming = setmetatable({}, { __mode = "k" })
local function Warm(frame)
  if warming[frame] or not (C_Timer and C_Timer.NewTicker) then return end
  local i = frame:GetNumMessages() or 0
  if i <= 0 then return end
  warming[frame] = true
  local ticker
  ticker = C_Timer.NewTicker(0, function()
    local stop = math.max(1, i - PER_FRAME + 1)
    for k = i, stop, -1 do
      local text = frame:GetMessageInfo(k)
      if type(text) == "string" and not issecret(text) then KeyOf(text) end
    end
    i = stop - 1
    if i < 1 then ticker:Cancel(); warming[frame] = nil end
  end)
end

-- The window's lines holding the words, newest first (their index: 1 the oldest)
local function Find(frame, query)
  local found = {}
  local key = ns:SearchKey(query or "")
  if key == "" then return found end
  for i = frame:GetNumMessages() or 0, 1, -1 do
    local text = frame:GetMessageInfo(i)
    if type(text) == "string" and not issecret(text) and KeyOf(text):find(key, 1, true) then found[#found + 1] = i end
  end
  return found
end

---------------------------------------------------------------------------
-- A window's search: what was typed, its matches, the one shown
---------------------------------------------------------------------------
local searches = setmetatable({}, { __mode = "k" }) -- chat frame -> { query, matches, at (its place in them), shown }

local function Search(frame)
  local s = searches[frame]
  if not s then s = { query = "", matches = {}, at = 0 }; searches[frame] = s end
  return s
end

-- The line in the middle of the window (scrolled by messages from its bottom)
local function Reach(frame, index)
  local total = frame:GetNumMessages() or 0
  local visible = (frame.GetNumVisibleLines and frame:GetNumVisibleLines()) or 0
  if visible <= 0 then visible = 10 end
  frame:SetScrollOffset(math.max(0, total - index - math.floor(visible / 2)))
end

-- Its matches made again, the one shown kept where it can be
local function Refind(frame)
  local s = Search(frame)
  local shown = s.matches[s.at]
  s.matches = Find(frame, s.query)
  s.at = 0
  for k, index in ipairs(s.matches) do
    if index == shown then s.at = k break end
  end
  return s
end

-- To the match before (older: step 1) or after (newer: step -1), round again at either end
local function Step(frame, step)
  local s = Refind(frame)
  local count = #s.matches
  if count == 0 then return s end
  if s.at == 0 then
    s.at = 1
  else
    s.at = (s.at - 1 + step) % count + 1
  end
  Reach(frame, s.matches[s.at])
  return s
end

-- Searched for what is typed: its newest match shown; nothing typed: the window back at its bottom
local function Typed(frame, query)
  local s = Search(frame)
  s.query = query or ""
  s.matches, s.at = {}, 0
  if ns:SearchKey(s.query) == "" then
    if frame.ScrollToBottom then frame:ScrollToBottom() end
    return s
  end
  return Step(frame, 1)
end

ns.ChatSearch = { Find = Find, Typed = Typed, Step = Step, Search = Search, Warm = Warm } -- (for the tests)

---------------------------------------------------------------------------
-- In the tab's menu: the box, its arrows and its count
---------------------------------------------------------------------------
local function ChatFrameOf(tab)
  local id = tab and tab.GetID and tab:GetID()
  if type(id) ~= "number" then return nil end
  local frame = (FCF_GetChatFrameByID and FCF_GetChatFrameByID(id)) or _G["ChatFrame" .. id]
  if type(frame) == "table" and frame.GetNumMessages and frame.GetMessageInfo and frame.SetScrollOffset then return frame end
end

local function Count(ui, s)
  local count = #s.matches
  if ns:SearchKey(s.query) == "" then
    ui.count:SetText("")
  elseif count == 0 then
    ui.count:SetText("|cffff6060" .. L.CHATSEARCH_NONE .. "|r")
  else
    ui.count:SetText(("%d/%d"):format(math.max(s.at, 1), count))
  end
end

local function Arrow(ui, up)
  local b = CreateFrame("Button", nil, ui)
  b:SetSize(18, 18)
  local name = up and "Up" or "Down"
  b:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Down")
  b:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Highlight", "ADD")
  b:SetScript("OnClick", function()
    local frame = ui.frame
    if not frame then return end
    Count(ui, Step(frame, up and 1 or -1))
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(up and L.CHATSEARCH_UP or L.CHATSEARCH_DOWN)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

-- Made once on a frame of the menu's (its frames are used again for other menus: hidden when it is let go)
local function Build(holder)
  local ui = CreateFrame("Frame", nil, holder)
  ui:SetAllPoints(holder)
  local box = CreateFrame("EditBox", nil, ui, "SearchBoxTemplate")
  box:SetSize(118, 20)
  box:SetPoint("LEFT", ui, "LEFT", 14, 0)
  box:SetAutoFocus(false)
  ui.box = box
  ui.up = Arrow(ui, true)
  ui.up:SetPoint("LEFT", box, "RIGHT", 4, 0)
  ui.down = Arrow(ui, false)
  ui.down:SetPoint("LEFT", ui.up, "RIGHT", 0, 0)
  ui.count = ui:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  ui.count:SetPoint("LEFT", ui.down, "RIGHT", 4, 0)
  local timer
  box:HookScript("OnTextChanged", function(self, user)
    if not user or not ui.frame then return end
    if timer then timer:Cancel() end
    local frame, text = ui.frame, self:GetText() or ""
    timer = C_Timer.NewTimer(WAIT, function()
      timer = nil
      if ui.frame == frame then Count(ui, Typed(frame, text)) end
    end)
  end)
  box:HookScript("OnEnterPressed", function(self)
    local frame = ui.frame
    if not frame then return end
    if timer then timer:Cancel(); timer = nil end
    local s = Search(frame)
    if s.query ~= (self:GetText() or "") then Count(ui, Typed(frame, self:GetText()))
    else Count(ui, Step(frame, 1)) end
  end)
  box:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
  holder.claraChatSearch = ui
  return ui
end

local function Element(frame)
  local description = MenuUtil.CreateFrame()
  description:AddInitializer(function(holder)
    holder:SetSize(214, 26)
    local ui = holder.claraChatSearch or Build(holder)
    ui.frame = frame
    Warm(frame)
    ui:Show()
    local s = Search(frame)
    ui.box:SetText(s.query)
    if ui.box.Instructions then ui.box.Instructions:SetShown(s.query == "") end
    Count(ui, s)
  end)
  description:AddResetter(function(holder)
    local ui = holder.claraChatSearch
    if ui then ui.frame = nil; ui.box:ClearFocus(); ui:Hide() end
  end)
  return description
end

if Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.CreateFrame then
  Menu.ModifyMenu("MENU_FCF_TAB", function(tab, root)
    local frame = ChatFrameOf(tab)
    if not (frame and root and root.Insert) then return end
    root:Insert(Element(frame), 2) -- (under its first line)
  end)
end
