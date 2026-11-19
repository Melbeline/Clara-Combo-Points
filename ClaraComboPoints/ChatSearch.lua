-- Clara Combo Points - the chat searched: a search box in a chat window's tab menu (right-click on its tab), under
-- the menu's first line (Edit Mode, or Lock). What is typed is looked for in every line the window holds (colors,
-- links and icons read as the text they show; capitals, accents and punctuation ignored), and the window scrolled to
-- the newest line holding it, that line in the middle. Its arrows: the match before (up: older) or after (down:
-- newer), round again at either end; Enter: the match before. "3/12" beside them. Emptied: the window back at its
-- bottom. Each window keeps its search while the game runs (the menu opened again shows it).
-- Its place, a box on Clara's settings page (on by default): a tab of its own after the chat's tabs (the last one,
-- whatever windows are added), drawn as the game draws them (its images, its gold text, the selected tab's look
-- while typing in it), for the tab selected; faint (20 %, as the game's tabs not selected) while unused, whole while
-- used (the mouse on it, typing) and as long as the chat window is busy (the mouse on it or its tabs), faint again
-- after 10 seconds of quiet. Unticked: in the tab's menu.

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

-- An arrow: in a small box with a tooltip's border, the arrow filling it
local ARROW, TAB_ARROW, TAB_WIDTH = 22, 18, 280
local EDGE = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } }
local function Fill(texture)
  if not (texture and texture.SetTexCoord) then return end
  texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT", 2, -2)
  texture:SetPoint("BOTTOMRIGHT", -2, 2)
  texture:SetTexCoord(0.2, 0.8, 0.22, 0.78) -- (the arrow without the image's empty edges)
end
local function Arrow(ui, up, size)
  local b = CreateFrame("Button", nil, ui, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetSize(size or ARROW, size or ARROW)
  if b.SetBackdrop then
    b:SetBackdrop(EDGE)
    b:SetBackdropColor(0, 0, 0, 0.8)
    b:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
  end
  local name = up and "Up" or "Down"
  b:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Down")
  b:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-Highlight", "ADD")
  for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
    if b[get] then Fill(b[get](b)) end
  end
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

-- The box's own frame, in the tab: none while it is not typed in (the tab's is around it), gold while it is
local function BoxFramed(ui, on)
  local gold = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
  for _, key in ipairs({ "Left", "Middle", "Right" }) do
    local part = ui.box[key]
    if part and part.SetShown then
      part:SetShown(on)
      if part.SetVertexColor then part:SetVertexColor(gold.r, gold.g, gold.b) end
    end
  end
end

-- Made once on its holder: a frame of the menu's (used again for other menus: hidden when it is let go), or the
-- tab after the chat's tabs (asTab): the box from its left, its count and its arrows inside it at its right end, all
-- lower where the tabs' text lies, the box in the tabs' gold text and without its frame until it is typed in
local function Build(holder, asTab)
  local ui = CreateFrame("Frame", nil, holder)
  ui:SetAllPoints(holder)
  local box = CreateFrame("EditBox", nil, ui, "SearchBoxTemplate")
  box:SetAutoFocus(false)
  ui.box = box
  ui.up = Arrow(ui, true, asTab and TAB_ARROW)
  ui.down = Arrow(ui, false, asTab and TAB_ARROW)
  ui.count = ui:CreateFontString(nil, "ARTWORK", asTab and "GameFontNormalSmall" or "GameFontHighlightSmall")
  if asTab then
    ui.down:SetPoint("RIGHT", ui, "RIGHT", -8, -4)
    ui.up:SetPoint("RIGHT", ui.down, "LEFT", -2, 0)
    ui.count:SetPoint("RIGHT", ui.up, "LEFT", -5, 0)
    box:SetHeight(20)
    box:SetPoint("LEFT", ui, "LEFT", 14, -4)
    box:SetPoint("RIGHT", ui.count, "LEFT", -6, 0)
    if box.SetFontObject then box:SetFontObject("GameFontNormalSmall") end
    -- ("Search" where nothing is typed: in the tabs' gold, as their names)
    if box.Instructions and box.Instructions.SetFontObject then box.Instructions:SetFontObject("GameFontNormalSmall") end
    BoxFramed(ui, false)
  else
    box:SetSize(118, 20)
    box:SetPoint("LEFT", ui, "LEFT", 14, 0)
    ui.up:SetPoint("LEFT", box, "RIGHT", 4, 0)
    ui.down:SetPoint("LEFT", ui.up, "RIGHT", 2, 0)
    ui.count:SetPoint("LEFT", ui.down, "RIGHT", 4, 0)
  end
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

-- Its search shown for a window
local function Attach(ui, frame)
  ui.frame = frame
  if not frame then return end
  Warm(frame)
  local s = Search(frame)
  ui.box:SetText(s.query)
  if ui.box.Instructions then ui.box.Instructions:SetShown(s.query == "") end
  Count(ui, s)
end

local function Element(frame)
  local description = MenuUtil.CreateFrame()
  description:AddInitializer(function(holder)
    holder:SetSize(232, 28)
    local ui = holder.claraChatSearch or Build(holder)
    ui:Show()
    Attach(ui, frame)
  end)
  description:AddResetter(function(holder)
    local ui = holder.claraChatSearch
    if ui then ui.frame = nil; ui.box:ClearFocus(); ui:Hide() end
  end)
  return description
end

---------------------------------------------------------------------------
-- Its place: beside the tabs (on by default), or in the tab's menu
---------------------------------------------------------------------------
function ns:ChatSearchDock() return not self.sv or self.sv.chatSearchDock ~= false end

local bar -- (beside the tabs, once made)
local QUIET, FAINT, FADE = 10, 0.2, 4 -- seconds before faint, faint's opacity, opacity changed a second

if Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.CreateFrame then
  Menu.ModifyMenu("MENU_FCF_TAB", function(tab, root)
    if ns:ChatSearchDock() then return end
    local frame = ChatFrameOf(tab)
    if not (frame and root and root.Insert) then return end
    root:Insert(Element(frame), 2) -- (under its first line)
  end)
end

local function Dock() return rawget(_G, "GENERAL_CHAT_DOCK") end
local function Selected()
  local dock = Dock()
  local frame = dock and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(dock) or DEFAULT_CHAT_FRAME
  if type(frame) == "table" and frame.GetNumMessages and frame.SetScrollOffset then return frame end
end

-- After the last tab shown (the dock places them again as they change)
local function PlaceBar()
  local dock = Dock()
  if not (bar and dock) then return end
  local last, right
  for _, frame in ipairs(dock.DOCKED_CHAT_FRAMES or {}) do
    local tab = frame.GetName and _G[frame:GetName() .. "Tab"]
    if tab and tab:IsShown() then
      local r = tab:GetRight()
      if r and (not right or r > right) then last, right = tab, r end
    end
  end
  bar:ClearAllPoints()
  if last then
    bar:SetPoint("LEFT", last, "RIGHT", 1, 0) -- (as the game puts a tab after another)
  else
    bar:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
  end
end

-- Used (the mouse on it, typing): whole; the chat window busy keeps it so; 10 seconds of quiet: faint
local function Busy()
  local dock, frame = Dock(), bar.ui.frame
  return (frame and frame:IsMouseOver()) or (dock and dock:IsMouseOver()) or false
end
local function Watch(self, elapsed)
  local now = GetTime()
  if self.ui.box:HasFocus() or self:IsMouseOver() then
    self.usedAt = now
  elseif self.usedAt and now - self.usedAt < QUIET and Busy() then
    self.usedAt = now
  end
  local target = (self.usedAt and now - self.usedAt < QUIET) and 1 or FAINT
  local alpha = self:GetAlpha()
  if alpha ~= target then
    local step = (elapsed or 0) * FADE
    if alpha < target then alpha = math.min(target, alpha + step * 2) else alpha = math.max(target, alpha - step) end
    self:SetAlpha(alpha)
  end
end

-- A chat tab's images, as the game's (ChatTabArtTemplate): its back, the selected tab's look, the mouse's light
local TAB = "Interface\\ChatFrame\\ChatFrameTab-"
local function TabArt(tab)
  local function Part(layer, file, point, x, add)
    local t = tab:CreateTexture(nil, layer)
    t:SetTexture(TAB .. file)
    if add and t.SetBlendMode then t:SetBlendMode("ADD") end
    if point then t:SetSize(16, 32); t:SetPoint(point, x, 0) else t:SetHeight(32) end
    return t
  end
  local function Row(layer, prefix, add)
    local left = Part(layer, prefix .. "Left", "BOTTOMLEFT", -2, add)
    local right = Part(layer, prefix .. "Right", "BOTTOMRIGHT", 2, add)
    local mid = Part(layer, prefix .. "Mid", nil, nil, add)
    if mid.SetHorizTile then mid:SetHorizTile(true) end
    mid:SetPoint("LEFT", left, "RIGHT")
    mid:SetPoint("RIGHT", right, "LEFT")
    return { left, mid, right }
  end
  tab.back = Row("BACKGROUND", "BG")
  tab.active = Row("BORDER", "Selected", true)
  tab.light = Row("HIGHLIGHT", "Highlight", true)
  local gold = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
  for _, row in ipairs({ tab.active, tab.light }) do
    for _, t in ipairs(row) do if t.SetVertexColor then t:SetVertexColor(gold.r, gold.g, gold.b) end end
  end
  for _, t in ipairs(tab.active) do t:Hide() end
end
local function TabSelected(tab, on) for _, t in ipairs(tab.active) do t:SetShown(on) end end

local function MakeBar()
  local dock = Dock()
  if bar or not dock then return bar end
  bar = CreateFrame("Button", "ClaraChatSearchBar", dock)
  bar:SetSize(TAB_WIDTH, 32)
  bar:SetFrameStrata("MEDIUM") -- (the game's tabs')
  bar:SetFrameLevel(dock:GetFrameLevel() + 10)
  TabArt(bar)
  bar.ui = Build(bar, true)
  bar:SetAlpha(FAINT)
  bar:SetScript("OnUpdate", Watch)
  bar:SetScript("OnClick", function() bar.ui.box:SetFocus() end) -- (anywhere on the tab: the search)
  -- (typed in: the selected tab's gold look, and the box's frame in gold, around the text, its cross and its arrows)
  bar.ui.box:HookScript("OnEditFocusGained", function()
    bar.usedAt = GetTime(); bar:SetAlpha(1); TabSelected(bar, true); BoxFramed(bar.ui, true)
  end)
  bar.ui.box:HookScript("OnEditFocusLost", function() TabSelected(bar, false); BoxFramed(bar.ui, false) end)
  if hooksecurefunc then
    if FCFDock_UpdateTabs then hooksecurefunc("FCFDock_UpdateTabs", function(d) if d == Dock() then PlaceBar() end end) end
    if FCFDock_SelectWindow then
      hooksecurefunc("FCFDock_SelectWindow", function(d, frame) if d == Dock() and bar:IsShown() then Attach(bar.ui, Selected()) end end)
    end
  end
  return bar
end

local function ShowBar()
  local on = ns:ChatSearchDock()
  if on then MakeBar() end
  if not bar then return end
  bar:SetShown(on)
  if on then
    PlaceBar()
    Attach(bar.ui, Selected())
  else
    bar.ui.box:ClearFocus()
  end
end
ns.ChatSearch.Bar = function() return bar end -- (for the tests)

function ns:SetChatSearchDock(on)
  if self.sv then
    if on then self.sv.chatSearchDock = nil else self.sv.chatSearchDock = false end
  end
  ShowBar()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() ShowBar() end)
