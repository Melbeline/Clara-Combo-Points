-- Clara Combo Points - the chat searched: a search box in a chat window's tab menu (right-click on its tab), under
-- the menu's first line (Edit Mode, or Lock). What is typed is looked for in every line the window holds (colors,
-- links and icons read as the text they show; capitals, accents and punctuation ignored), and the window scrolled to
-- the newest line holding it, that line in the middle. Its arrows: the match before (up: older) or after (down:
-- newer), round again at either end; Enter: the match before. "3/12" beside them. Emptied: the window back at its
-- bottom. Each window keeps its search while the game runs (the menu opened again shows it).
-- A module of Clara's own (on by default; Esc > Options > AddOns > Clara > Interface: its card and its page). Its place,
-- a box on its card and its page (on by default): a tab of its own after the chat's tabs (the last one, whatever
-- windows are added), drawn as the game draws them (its images, its gold text; a gold border around it while typing
-- in it), for the tab selected; faint (20 %, as the game's tabs not selected) while unused, whole while used (the
-- mouse on it, typing) and as long as the chat window is busy (the mouse on it or its tabs), faint again after 10
-- seconds of quiet. Unticked: in the tab's menu. The words found marked in the lines shown, in the style picked on
-- its page (six, or none).

local ADDON, ns = ...
local L = ns.L

local issecret = issecretvalue or function() return false end

---------------------------------------------------------------------------
-- Its settings (Clara's): its place, beside the tabs or in a tab's menu (sv.chatSearchDock), and how the words found
-- are marked (sv.chatSearch.style: "none", or A to F as its page tells them; E by default). Its switch on its card,
-- its page under Interface.
---------------------------------------------------------------------------
local STYLES = { "none", "A", "B", "C", "D", "E", "F" }
local DEFAULT_STYLE = "E"
ns.CHATSEARCH_STYLES = STYLES

function ns:ChatSearchDock() return not self.sv or self.sv.chatSearchDock ~= false end
function ns:SetChatSearchDock(on)
  if self.sv then
    if on then self.sv.chatSearchDock = nil else self.sv.chatSearchDock = false end
  end
  if self.ChatSearchPlaced then self.ChatSearchPlaced() end
end
function ns:ChatSearchStyle()
  local store = self.sv and self.sv.chatSearch
  local style = type(store) == "table" and store.style or nil
  for _, key in ipairs(STYLES) do if key == style then return style end end
  return DEFAULT_STYLE
end
function ns:SetChatSearchStyle(style)
  if not self.sv then return end
  local store = type(self.sv.chatSearch) == "table" and self.sv.chatSearch or {}
  store.style = style ~= DEFAULT_STYLE and style or nil
  self.sv.chatSearch = next(store) and store or nil
  if self.ChatSearchRestyled then self.ChatSearchRestyled() end
end

ns:SetQolSwitches("chatsearch", {
  { label = "SP_CHATSEARCH_DOCK", get = function() return ns:ChatSearchDock() end, set = function(on) ns:SetChatSearchDock(on) end },
})
ns:SetQolOpener("chatsearch", function() ns:OpenSettingsTo(ns.chatSearchCategory) end)
if not ns:QolRuns("chatsearch") then return end

local Marks = {} -- (the words found marked: below)
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
  if count == 0 then pcall(Marks.Show, frame) return s end
  if s.at == 0 then
    s.at = 1
  else
    s.at = (s.at - 1 + step) % count + 1
  end
  Reach(frame, s.matches[s.at])
  Marks.Jumped(frame)
  return s
end

-- Searched for what is typed: its newest match shown; nothing typed: the window back at its bottom
local function Typed(frame, query)
  local s = Search(frame)
  s.query = query or ""
  s.matches, s.at = {}, 0
  Marks.Watch(frame)
  if ns:SearchKey(s.query) == "" then
    if frame.ScrollToBottom then frame:ScrollToBottom() end
    Marks.Redraw(frame) -- (the marks taken off)
    return s
  end
  return Step(frame, 1)
end

ns.ChatSearch = { Find = Find, Typed = Typed, Step = Step, Search = Search, Warm = Warm } -- (for the tests)

---------------------------------------------------------------------------
-- The words found marked in the lines the window shows, in the style picked on its page: each time the window draws
-- its lines again (the game's own callback for it: a new line, a scroll), and as the search changes. The marks are
-- textures behind the words, where the game's own text selection puts its own (FontString:
-- CalculateScreenAreaFromCharacterSpan); or the words' text colored (A, and the others where that is missing).
-- Nothing kept in the window's lines: the next drawing puts them back as they were.
---------------------------------------------------------------------------
local GOLD = { 1, 0.78, 0.24 }
local LOOK = {
  A = { color = true },
  B = { back = { 1, 0.84, 0, 0.22 }, backNow = { 1, 0.59, 0, 0.5 } },
  C = { under = { 1, 0.82, 0.31, 0.55 }, underNow = { 1, 0.82, 0.29, 1 } },
  D = { band = 0.22, bar = true },
  E = { back = { 1, 0.84, 0, 0.16 }, backNow = { 1, 0.75, 0.16, 0.36 }, bar = true },
  F = { backNow = { 1, 0.75, 0.16, 0.3 }, flash = 0.28 },
}
local OTHER_COLOR, NOW_COLOR = "|cfffff2c8", "|cffffffff" -- (A: the other matches, the current one)
local FLASH = 1.5 -- seconds the current match's line stays lit as it is reached (F)

-- The characters a line shows, each with its place in the line's text (its bytes): colors, links' codes, icons and
-- the game's hidden names left out, as Shown reads them
local function Chars(text)
  local chars, i, n = {}, 1, #text
  while i <= n do
    local b = text:byte(i)
    if b == 124 then -- "|"
      local nx = text:sub(i + 1, i + 1)
      if nx == "c" and text:sub(i + 2, i + 9):match("^%x%x%x%x%x%x%x%x$") then i = i + 10
      elseif nx == "r" or nx == "h" then i = i + 2
      elseif nx == "H" then local close = text:find("|h", i + 2, true); i = close and close + 2 or n + 1
      elseif nx == "T" or nx == "A" or nx == "K" then
        local close = text:find("|" .. nx:lower(), i + 2, true); i = close and close + 2 or n + 1
      elseif nx == "|" then chars[#chars + 1] = { i, i + 1, "|" }; i = i + 2
      else chars[#chars + 1] = { i, i, "|" }; i = i + 1 end
    else
      local len = b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1
      chars[#chars + 1] = { i, i + len - 1, text:sub(i, i + len - 1) }
      i = i + len
    end
  end
  return chars
end

-- A character as the search reads it (as ns:SearchKey: apostrophes out, punctuation and spaces one space, capitals
-- and accents off)
local function Fold(ch)
  if ch == "'" or ch == "\226\128\153" then return "" end
  if #ch == 1 and ch:match("[%p%s]") then return " " end
  return ns:SearchKey(ch)
end

-- Where the words are in a line's text: { first byte, last byte } each
local function Spans(text, key)
  local chars = Chars(text)
  local parts, owner, len, last = {}, {}, 0, " "
  for index, c in ipairs(chars) do
    local f = Fold(c[3])
    if f == " " and last == " " then f = "" end -- (spaces run together, none first)
    if f ~= "" then
      parts[#parts + 1] = f
      for k = 1, #f do owner[len + k] = index end
      len = len + #f
      last = f:sub(-1)
    end
  end
  local folded, spans, from = table.concat(parts), {}, 1
  while key ~= "" do
    local a, z = folded:find(key, from, true)
    if not a then break end
    spans[#spans + 1] = { chars[owner[a]][1], chars[owner[z]][2] }
    from = z + 1
  end
  return spans
end
ns.ChatSearch.Spans = Spans -- (for the tests)

-- A line's text, its words colored (A): the color around them taken up again after them
local function Colored(text, spans, now)
  local out, pos = {}, 1
  for _, sp in ipairs(spans) do
    local before, open, closed = text:sub(1, sp[1] - 1), nil, 0
    for at, code in before:gmatch("()(|c%x%x%x%x%x%x%x%x)") do open = { at, code } end
    for at in before:gmatch("()|r") do closed = at end
    out[#out + 1] = text:sub(pos, sp[1] - 1)
    out[#out + 1] = now and NOW_COLOR or OTHER_COLOR
    out[#out + 1] = text:sub(sp[1], sp[2])
    out[#out + 1] = "|r" .. ((open and open[1] > closed) and open[2] or "")
    pos = sp[2] + 1
  end
  out[#out + 1] = text:sub(pos)
  return table.concat(out)
end

-- Each window's textures, used again from one drawing to the next
local pools = setmetatable({}, { __mode = "k" })
local function Pool(frame)
  local pool = pools[frame]
  if not pool then
    pool = { textures = {}, used = 0, parent = frame.FontStringContainer or frame }
    pools[frame] = pool
  end
  return pool
end
local function Texture(pool)
  pool.used = pool.used + 1
  local t = pool.textures[pool.used]
  if not t then
    t = pool.parent:CreateTexture(nil, "BACKGROUND", nil, 1) -- (where the game's text selection draws: under the text)
    pool.textures[pool.used] = t
  end
  t:ClearAllPoints()
  t:SetAlpha(1)
  t:Show()
  return t
end
local function Release(pool)
  for _, t in ipairs(pool.textures) do t:Hide() end
  pool.used, pool.band = 0, nil
end

local function Areas(line, from, to)
  if type(line.CalculateScreenAreaFromCharacterSpan) ~= "function" then return nil end
  local ok, areas = pcall(line.CalculateScreenAreaFromCharacterSpan, line, from, to)
  if ok and type(areas) == "table" and type(areas[1]) == "table" then return areas end
  return nil
end
local function Back(pool, line, area, c)
  local t = Texture(pool)
  t:SetColorTexture(c[1], c[2], c[3], c[4])
  t:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", area.left, area.bottom)
  t:SetPoint("TOPRIGHT", line, "BOTTOMLEFT", area.left + area.width, area.bottom + area.height)
end
local function Under(pool, line, area, c, thick)
  local t = Texture(pool)
  t:SetColorTexture(c[1], c[2], c[3], c[4])
  t:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", area.left, area.bottom)
  t:SetSize(area.width, thick)
end
local function Bar(pool, line) -- (in the margin, left of the line)
  local t = Texture(pool)
  t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  t:SetPoint("TOPRIGHT", line, "TOPLEFT", -3, 0)
  t:SetPoint("BOTTOMRIGHT", line, "BOTTOMLEFT", -3, 0)
  t:SetWidth(3)
end
local function Band(pool, line, alpha) -- (behind the whole line, fading to the right)
  local t = Texture(pool)
  t:SetPoint("TOPLEFT", line, "TOPLEFT", -2, 1)
  t:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 2, -1)
  if t.SetGradient and CreateColor then
    t:SetColorTexture(1, 1, 1, 1)
    t:SetGradient("HORIZONTAL", CreateColor(GOLD[1], GOLD[2], GOLD[3], alpha), CreateColor(GOLD[1], GOLD[2], GOLD[3], alpha * 0.27))
  else
    t:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], alpha)
  end
  return t
end

-- F: the current match's line lit as it is reached, fading out
local flashes = setmetatable({}, { __mode = "k" }) -- window -> when its current match was reached
local flasher = CreateFrame("Frame")
flasher:Hide()
flasher:SetScript("OnUpdate", function(self)
  local any = false
  for frame, at in pairs(flashes) do
    local left, pool = FLASH - (GetTime() - at), pools[frame]
    if left <= 0 then
      flashes[frame] = nil
      if pool and pool.band then pool.band:Hide(); pool.band = nil end
    else
      any = true
      if pool and pool.band then pool.band:SetAlpha(left / FLASH) end
    end
  end
  if not any then self:Hide() end
end)

function Marks.Show(frame)
  local pool = pools[frame]
  if pool then Release(pool) end
  local style = ns:ChatSearchStyle()
  local look = LOOK[style]
  local s = searches[frame]
  local key = s and ns:SearchKey(s.query or "") or ""
  local lines = type(frame) == "table" and frame.visibleLines
  if not look or key == "" or #s.matches == 0 or type(lines) ~= "table" then return end
  pool = Pool(frame)
  local total = frame:GetNumMessages() or 0
  local offset = frame.GetScrollOffset and frame:GetScrollOffset() or 0
  local current = s.matches[s.at]
  for index, line in ipairs(lines) do
    local info = line.messageInfo
    local text = type(info) == "table" and info.message or nil
    if type(text) == "string" and not issecret(text) and line:IsShown() then
      local spans = Spans(text, key)
      if #spans > 0 then
        local now = current ~= nil and total - (index + offset) + 1 == current
        local colored = look.color
        for _, sp in ipairs(spans) do
          local c, u = now and look.backNow or not now and look.back, now and look.underNow or not now and look.under
          if not colored and (c or u) then
            local areas = Areas(line, sp[1], sp[2])
            if not areas then colored = true break end -- (where the game cannot tell: the words colored)
            for _, area in ipairs(areas) do
              if c then Back(pool, line, area, c) end
              if u then Under(pool, line, area, u, now and 2 or 1) end
            end
          end
        end
        if colored then line:SetText(Colored(text, spans, now)) end
        if now and look.bar then Bar(pool, line) end
        if now and look.band then Band(pool, line, look.band) end
        if now and look.flash and flashes[frame] then
          local left = FLASH - (GetTime() - flashes[frame])
          if left > 0 then
            pool.band = Band(pool, line, look.flash)
            pool.band:SetAlpha(left / FLASH)
            flasher:Show()
          end
        end
      end
    end
  end
end

-- A match reached: its line lit a moment (F), the marks drawn again
function Marks.Jumped(frame)
  if ns:ChatSearchStyle() == "F" then flashes[frame] = GetTime() end
  Marks.Watch(frame)
  pcall(Marks.Show, frame)
end

-- The window's own drawing followed (its callback, else its function), once
local watched = setmetatable({}, { __mode = "k" })
function Marks.Watch(frame)
  if type(frame) ~= "table" or watched[frame] then return end
  watched[frame] = true
  if type(frame.AddOnDisplayRefreshedCallback) == "function" then
    frame:AddOnDisplayRefreshedCallback(function(f) pcall(Marks.Show, f) end)
  elseif hooksecurefunc and type(frame.RefreshDisplay) == "function" then
    hooksecurefunc(frame, "RefreshDisplay", function(f) pcall(Marks.Show, f) end)
  end
end

-- The marks taken off, and the words' colors (A): the window draws its lines again
function Marks.Redraw(frame)
  pcall(Marks.Show, frame)
  if type(frame) == "table" and type(frame.MarkDisplayDirty) == "function" then frame:MarkDisplayDirty() end
end

-- Another style picked: every window searched drawn again
ns.ChatSearchRestyled = function()
  for frame in pairs(searches) do Marks.Redraw(frame) end
end
ns.ChatSearch.Marks = Marks -- (for the tests)

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
    ui.down:SetPoint("RIGHT", ui, "RIGHT", -8, -3)
    ui.up:SetPoint("RIGHT", ui.down, "LEFT", -2, 0)
    ui.count:SetPoint("RIGHT", ui.up, "LEFT", -5, 0)
    box:SetHeight(20)
    box:SetPoint("LEFT", ui, "LEFT", 14, -3)
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
  Marks.Watch(frame)
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
-- Its arrows (and its count) only while it is typed in or a search is on: minimized, the tab its line alone
local function Arrows(ui)
  local on = ui.box:HasFocus() or (ui.frame ~= nil and ns:SearchKey(Search(ui.frame).query or "") ~= "")
  if ui.up:IsShown() ~= on then
    ui.up:SetShown(on)
    ui.down:SetShown(on)
    ui.count:SetShown(on)
  end
end

local function Watch(self, elapsed)
  local now = GetTime()
  Arrows(self.ui)
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

-- Typed in: one gold border around the whole tab, its line, its count and its arrows, none of them under it (the
-- selected tab's own look, its edge across the arrows, left off); the tab's neighbour on its left never under it
local RING = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
local function Ring(tab)
  local ring = CreateFrame("Frame", nil, tab, BackdropTemplateMixin and "BackdropTemplate" or nil)
  -- (the tab's own height, 2 lower: its line and arrows a few pixels inside it, above and below)
  ring:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -2)
  ring:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 2, -2)
  ring:SetFrameLevel(tab:GetFrameLevel() + 1) -- (above the tab's images, below its line and arrows)
  if ring.SetBackdrop then
    ring:SetBackdrop(RING)
    ring:SetBackdropColor(0, 0, 0, 0.6)
    local gold = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
    ring:SetBackdropBorderColor(gold.r, gold.g, gold.b, 1)
  end
  ring:Hide()
  return ring
end

local function MakeBar()
  local dock = Dock()
  if bar or not dock then return bar end
  bar = CreateFrame("Button", "ClaraChatSearchBar", dock)
  bar:SetSize(TAB_WIDTH, 32)
  bar:SetFrameStrata("MEDIUM") -- (the game's tabs')
  bar:SetFrameLevel(dock:GetFrameLevel() + 10)
  TabArt(bar)
  bar.ring = Ring(bar)
  bar.ui = Build(bar, true)
  bar.ui:SetFrameLevel(bar:GetFrameLevel() + 3)
  bar:SetAlpha(FAINT)
  bar:SetScript("OnUpdate", Watch)
  bar:SetScript("OnClick", function() bar.ui.box:SetFocus() end) -- (anywhere on the tab: the search)
  -- (typed in: the gold border around the whole tab, and the box's frame in gold around its text and its cross)
  bar.ui.box:HookScript("OnEditFocusGained", function()
    bar.usedAt = GetTime(); bar:SetAlpha(1); bar.ring:Show(); BoxFramed(bar.ui, true); Arrows(bar.ui)
  end)
  bar.ui.box:HookScript("OnEditFocusLost", function() bar.ring:Hide(); BoxFramed(bar.ui, false); Arrows(bar.ui) end)
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

ns.ChatSearchPlaced = ShowBar -- (its box ticked or unticked: in its place at once)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() ShowBar() end)

---------------------------------------------------------------------------
-- Its page: under its theme's page in Clara's options (Esc > Options > AddOns > Clara > Interface > Chat search):
-- its place, and the style the words found are marked in (one picked at a time)
---------------------------------------------------------------------------
local page = CreateFrame("Frame")
page:Hide()
local built
local updates, parts = {}, {}
ns.ChatSearchPage, ns.ChatSearchParts = page, parts -- (for the tests)

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end
local function Refresh() for _, fn in ipairs(updates) do fn() end end

local function Box(key, label, y, get, set)
  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetPoint("TOPLEFT", 10, y)
  local text = check.Text or check.text
  if text then
    text:SetFontObject("GameFontHighlight")
    text:SetText(label)
  end
  check:SetScript("OnClick", function(self)
    Click()
    set(self:GetChecked() and true or false)
    Refresh()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)
  parts[key] = check
  updates[#updates + 1] = function() check:SetChecked(get()) end
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText(L.QOL_NAV_CHATSEARCH)
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -62)
  hint:SetPoint("RIGHT", -24, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.6, .6, .65)
  hint:SetText(L.CHATSEARCH_HINT)

  Box("dock", L.SP_CHATSEARCH_DOCK, -100, function() return ns:ChatSearchDock() end, function(on) ns:SetChatSearchDock(on) end)

  local head = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  head:SetPoint("TOPLEFT", 14, -142)
  head:SetText(L.CHATSEARCH_STYLE)
  -- (one at a time: ticked, it is the one; the one ticked clicked again stays so)
  for i, style in ipairs(STYLES) do
    Box("style" .. style, L["CHATSEARCH_STYLE_" .. style:upper()], -162 - (i - 1) * 28,
      function() return ns:ChatSearchStyle() == style end, function() ns:SetChatSearchStyle(style) end)
  end
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Refresh()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local ok, category = pcall(function()
    if ns:QolCategory("chatsearch") and Settings.RegisterCanvasLayoutSubcategory then
      return Settings.RegisterCanvasLayoutSubcategory(ns:QolCategory("chatsearch"), page, L.QOL_NAV_CHATSEARCH)
    end
    local c = Settings.RegisterCanvasLayoutCategory(page, L.QOL_NAV_CHATSEARCH)
    Settings.RegisterAddOnCategory(c)
    return c
  end)
  if ok and category then ns.chatSearchCategory = category end
end
