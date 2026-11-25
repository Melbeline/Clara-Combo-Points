-- The chat search's match kept in sight (Modules/ChatSearch: Fit): the window scrolls by messages, a line each (the
-- newest at the bottom), a long one wrapped over several rows. Put in the middle by count, a match with tall lines
-- under it would be above the window's top: once the window has drawn them, it scrolls on until the match sits in
-- its middle by height; lines of one row each: left where it is; a match taller than half the window: at its bottom;
-- the window scrolled meanwhile: left alone.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
C_Timer.NewTimer = C_Timer.NewTimer or function(d, fn) C_Timer.After(d, fn) return { Cancel = function() end } end
GetBuildInfo = function() return "1.60.1", "70938", "Nov 13 2026", 16001 end
GetCurrentRegionName = GetCurrentRegionName or function() return "EU" end
ClaraComboPointsDB = { qol = setmetatable({}, { __index = function(_, k) return k == "chatsearch" end }) }
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
local C = ns.ChatSearch
check(C and C.Fit, "loaded")

-- A window 140 high, rows of 14: 11 lines (as the game makes them: its height over a row, and one); a message's rows
-- by its text ("x3": 3 rows). Drawn a frame later, as the game does.
local ROW, HEIGHT = 14, 140
local window = { messages = {}, offset = 0, callbacks = {}, isDisplayDirty = false }
window.visibleLines = {}
for k = 1, 11 do
  local line = { shown = false }
  function line:GetStringHeight() local m = self.messageInfo and self.messageInfo.message; return ROW * tonumber(m and m:match("x(%d+)") or 1) end
  function line:GetSpacing() return 0 end
  function line:IsShown() return self.shown end
  function line:SetText() end
  window.visibleLines[k] = line
end
function window:GetHeight() return HEIGHT end
function window:GetNumMessages() return #self.messages end
function window:GetMessageInfo(i) return self.messages[i] end
function window:GetScrollOffset() return self.offset end
function window:GetNumVisibleLines() return #self.visibleLines end
function window:GetMaxScrollRange() return math.max(#self.messages - 1, 0) end
function window:AddOnDisplayRefreshedCallback(fn) table.insert(self.callbacks, fn) end
function window:SetScrollOffset(o)
  o = math.max(0, math.min(o, self:GetMaxScrollRange()))
  if o ~= self.offset then self.offset = o; self.isDisplayDirty = true end
end
function window:ScrollToBottom() self:SetScrollOffset(0) end
function window:MarkDisplayDirty() self.isDisplayDirty = true end
function window:Draw() -- (the game's refresh)
  local n = #self.messages
  for k, line in ipairs(self.visibleLines) do
    local msg = self.messages[n - (k + self.offset) + 1]
    line.messageInfo = msg and { message = msg } or nil
    line.shown = msg ~= nil
  end
  self.isDisplayDirty = false
  for _, fn in ipairs(self.callbacks) do fn(self) end
end
local function Frames() for _ = 1, 4 do if window.isDisplayDirty then window:Draw() end end end
-- The match's place: its rows' top, from the window's bottom
local function Top(index)
  local n, y = #window.messages, 0
  for k, line in ipairs(window.visibleLines) do
    local h = line:GetStringHeight()
    if line.messageInfo and n - (k + window.offset) + 1 == index then return y + h end
    y = y + h
  end
end

local function Fill(list)
  window.messages = list; window.offset = 0; window:Draw()
end

out("== lines of one row: the match in the middle, as it was")
local list = {}
for i = 1, 60 do list[i] = ("line %d"):format(i) end
list[30] = "line 30 Murloc"
Fill(list)
C.Typed(window, "murloc"); Frames()
local top = Top(30)
check(top and top <= HEIGHT, "in sight (its top " .. tostring(top) .. " of " .. HEIGHT .. ")")
check(window.offset - (60 - 30 - 5) <= 1, "where the count puts it, a line at most (" .. window.offset .. ")")

out("== tall lines under it")
list = {}
for i = 1, 60 do list[i] = ("line %d x3"):format(i) end
list[30] = "line 30 Murloc"
Fill(list)
C.Typed(window, "murloc"); Frames()
top = Top(30)
check(top and top <= HEIGHT, "in sight (its top " .. tostring(top) .. " of " .. HEIGHT .. ")")
check(top and top >= HEIGHT / 2 - 3 * ROW and top <= HEIGHT / 2 + ROW + 3 * ROW, "about the middle")
C.Step(window, 1); Frames() -- (none older: round again to the same)
top = Top(30)
check(top and top <= HEIGHT, "reached again: in sight")

out("== a match taller than half the window")
list = {}
for i = 1, 60 do list[i] = ("line %d x2"):format(i) end
list[30] = "line 30 Murloc x6"
Fill(list)
C.Typed(window, "murloc"); Frames()
top = Top(30)
check(top and top <= HEIGHT, "in sight (its top " .. tostring(top) .. ")")

out("== scrolled meanwhile")
list = {}
for i = 1, 60 do list[i] = ("line %d x3"):format(i) end
list[30] = "line 30 Murloc"
Fill(list)
C.Typed(window, "murloc")
window.offset = window.offset + 7 -- (the wheel, before the window draws)
local was = window.offset
Frames()
check(window.offset == was, "left where it was scrolled")
out("")
out(fails .. " failure(s)")
