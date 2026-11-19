-- The chat searched (ChatSearch.lua): a search box in a chat tab's menu, under its first line; what is typed looked
-- for in every line the window holds (colors, links and icons read as the text they show; capitals and accents
-- ignored), the window scrolled to the newest match (in its middle); up: the match before (older), down: the one
-- after (newer), round again; Enter: the match before; "2/3"; nothing found said; emptied: the window at its bottom;
-- the search kept for the window while the game runs; the menu's frame given back clean. Beside the tabs (its
-- setting, on by default): after the last tab, for the tab selected, faint (20 %) until used, whole while used and
-- while the chat window is busy, faint again after 10 seconds of quiet; bigger arrows with a tooltip's border
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false } }
-- (timers the test runs: the game's C_Timer.NewTimer)
local pending = {}
C_Timer.NewTimer = function(d, fn) local t = { fn = fn }; function t:Cancel() self.cancelled = true end; pending[#pending + 1] = t; return t end
local function Wait() local list = pending; pending = {}; for _, t in ipairs(list) do if not t.cancelled then t.fn() end end end

-- A chat window as the game's (ScrollingMessageFrame: 1 the oldest line; scrolled by messages from its bottom)
local window = { lines = {}, offset = 0 }
function window:AddMessage(t) table.insert(self.lines, t) end
function window:GetNumMessages() return #self.lines end
function window:GetMessageInfo(i) return self.lines[i] end
function window:SetScrollOffset(o) self.offset = o end
function window:GetNumVisibleLines() return 10 end
function window:ScrollToBottom() self.offset = 0 end
for i = 1, 100 do window:AddMessage("|cffffffff[1. General]|r |Hplayer:Lola Moon|h[Lola Moon]|h: chatting " .. i) end
window.lines[20] = "|cffffff00Your skill in Leatherworking has increased to 226.|r"
window.lines[50] = "|cff00ff00You create: |cff1eff00|Hitem:15095::::::::60:::::|h[Nightscape Pants]|h|r.|r"
window.lines[90] = "|cff00ff00You create: |cff1eff00|Hitem:15095::::::::60:::::|h[Nightscape Pants]|h|r.|r"
window.lines[95] = "|cffff80ffÉlodie whispers: les NIGHTSCAPE pants c'est cher|r"
window.lines[60] = "|TInterface\\Icons\\inv_misc_note_01:12|t |cffc79c6eÉclair Chazal|r: l'éclair"
BackdropTemplateMixin = BackdropTemplateMixin or {} -- (the game's: its frames take a backdrop)
FCF_GetChatFrameByID = function(id) if id == 1 then return window end end
-- (the dock of tabs above the chat, as the game's: its windows, each with its tab; the one selected)
local mouseOn = {}
function window:GetName() return "TestChat" end
function window:IsMouseOver() return mouseOn.window == true end
local other = { lines = { "|cffffffffhello merci beaucoup" }, offset = 0 }
for k, v in pairs(window) do if type(v) == "function" then other[k] = v end end
function other:GetName() return "TestOther" end
GENERAL_CHAT_DOCK = CreateFrame("Frame", "GeneralDockManager", UIParent)
GENERAL_CHAT_DOCK:SetSize(430, 24)
GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES = { window, other }
function GENERAL_CHAT_DOCK:IsMouseOver() return mouseOn.dock == true end
local tab1 = CreateFrame("Button", "TestChatTab", GENERAL_CHAT_DOCK); tab1:SetSize(70, 24); tab1:SetPoint("BOTTOMLEFT", GENERAL_CHAT_DOCK, "BOTTOMLEFT", 0, 0); tab1:Show()
local tab2 = CreateFrame("Button", "TestOtherTab", GENERAL_CHAT_DOCK); tab2:SetSize(90, 24); tab2:SetPoint("LEFT", tab1, "RIGHT", 1, 0); tab2:Show()
GENERAL_CHAT_DOCK.selected = window
function FCFDock_GetSelectedWindow(dock) return dock.selected end
function FCFDock_SelectWindow(dock, frame) dock.selected = frame; FCFDock_UpdateTabs(dock) end
function FCFDock_UpdateTabs(dock) end
local tab = { GetID = function() return 1 end }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")

ns.sv.chatSearchDock = false -- (first in the tab's menu: its setting unticked)
out("== in the tab's menu, under its first line")
local root = setmetatable({}, { __index = function() end })
local mods = M.menuModifiers.MENU_FCF_TAB
check(mods and #mods >= 1, "its menu changed (MENU_FCF_TAB)")
local elements = {}
root = { Insert = function(_, d, index) table.insert(elements, index or (#elements + 1), d); return d end }
table.insert(elements, { text = "Edit Mode" }); table.insert(elements, { text = "Make Noninteractive" })
for _, fn in ipairs(mods or {}) do fn(tab, root, {}) end
local element = elements[2]
check(element and element.kind == "frame" and elements[1].text == "Edit Mode" and elements[3].text == "Make Noninteractive", "the box under Edit Mode")
local holder = CreateFrame("Frame", nil, UIParent)
for _, init in ipairs(element.initializers) do init(holder, element, {}) end
local ui = holder.claraChatSearch
check(ui and ui.box and ui.up and ui.down and ui.count and holder:GetWidth() > 150, "its box, its arrows, its count")

local function Type(text) ui.box:SetText(text); ui.box:GetScript("OnTextChanged")(ui.box, true); Wait() end
out("== typed: the newest match in the window's middle")
Type("nightscape")
check(window.offset == 100 - 95 - 5, ("\"nightscape\": the newest line holding it, any capitals (offset %d)"):format(window.offset))
check(ui.count:GetText() == "1/3", "1/3 (" .. tostring(ui.count:GetText()) .. ")")
ui.up:Click()
check(window.offset == 100 - 90 - 5 and ui.count:GetText() == "2/3", "up: the match before (a link read as its text)")
ui.up:Click()
check(window.offset == 0 or window.offset == math.max(0, 100 - 50 - 5), "up again: the oldest")
check(window.offset == 45 and ui.count:GetText() == "3/3", "3/3, line 50")
ui.up:Click()
check(ui.count:GetText() == "1/3" and window.offset == 0, "up at the oldest: round again to the newest")
ui.down:Click()
check(ui.count:GetText() == "3/3" and window.offset == 45, "down at the newest: round again to the oldest")
ui.box:GetScript("OnEnterPressed")(ui.box)
check(ui.count:GetText() == "1/3", "Enter: the match before (round again)")

out("== accents, icons, nothing found, emptied")
Type("eclair")
check(window.offset == 100 - 60 - 5 and ui.count:GetText() == "1/1", "\"eclair\" finds \"Éclair\" and \"l'éclair\" (one line), its icon left out")
Type("increased to 226")
check(window.offset == 100 - 20 - 5, "several words: the line holding them")
Type("zzz nothing")
check((ui.count:GetText() or ""):find("Not found", 1, true) ~= nil, "nothing: said so (" .. tostring(ui.count:GetText()) .. ")")
Type("")
check(window.offset == 0 and ui.count:GetText() == "", "emptied: the window at its bottom")

out("== new lines meanwhile; the menu opened again; let go clean")
Type("nightscape")
window:AddMessage("|cff00ff00You create: |cff1eff00|Hitem:15095|h[Nightscape Pants]|h|r.|r")
check(ns.ChatSearch.Search(window).matches[1] == 95, "shown: line 95")
ui.up:Click()
check(ui.count:GetText() == "3/4" and window.offset == 101 - 90 - 5, "a new match counted (4), the place kept: up goes on to line 90 (" .. tostring(ui.count:GetText()) .. ")")
for _, reset in ipairs(element.resetters) do reset(holder) end
check(not ui:IsShown() and ui.frame == nil, "the menu let go: its frame's box hidden (used for other menus)")
local elements2 = { { text = "Edit Mode" } }
local root2 = { Insert = function(_, d, index) table.insert(elements2, index or (#elements2 + 1), d); return d end }
for _, fn in ipairs(mods) do fn(tab, root2, {}) end
for _, init in ipairs(elements2[2].initializers) do init(holder, elements2[2], {}) end
check(ui:IsShown() and ui.box:GetText() == "nightscape" and ui.count:GetText() == "3/4", "opened again: its search as it was")
check(ns.ChatSearch.Find(window, "")[1] == nil, "nothing typed: nothing looked for")
local before = #M.tickers
check(before >= 1, "its lines read ahead as the menu opens (a part each frame)")
M.Tick()
check(#M.tickers == before - 1, "101 lines: read in one frame, then its ticker stopped")

out("== beside the tabs (its setting, on by default)")
ns:SetChatSearchDock(true)
check(ns.sv.chatSearchDock == nil and ns:ChatSearchDock(), "on by default, nothing kept")
local bar = ns.ChatSearch.Bar()
check(bar and bar:IsShown() and bar._parent == GENERAL_CHAT_DOCK, "its bar on the tabs' dock")
local p, rel, rp, x = bar:GetPoint(1)
check(p == "LEFT" and rel == tab2 and rp == "RIGHT" and x == 8, "after the last tab")
check(bar.ui.frame == window and bar.ui.box:GetText() == "nightscape", "the tab selected's search")
check(math.abs(bar:GetAlpha() - 0.2) < 0.01, "faint while unused (20 %)")
check(bar.ui.up:GetWidth() == 22 and bar.ui.up._backdrop and bar.ui.up._backdrop.edgeFile:find("Tooltip", 1, true), "its arrows: 22, a tooltip's border")
local function Frames(n, dt) for _ = 1, n do M.now = M.now + dt; bar:GetScript("OnUpdate")(bar, dt) end end
M.now = M.now or 0
bar.IsMouseOver = function() return mouseOn.bar == true end
mouseOn.bar = true; Frames(5, 0.1)
check(math.abs(bar:GetAlpha() - 1) < 0.01, "the mouse on it: whole")
mouseOn.bar = nil; mouseOn.window = true; Frames(150, 0.1)
check(math.abs(bar:GetAlpha() - 1) < 0.01, "the chat window busy for 15 s: still whole")
mouseOn.window = nil; Frames(95, 0.1)
check(math.abs(bar:GetAlpha() - 1) < 0.01, "9.5 s of quiet: still whole")
Frames(10, 0.1)
check(math.abs(bar:GetAlpha() - 0.2) < 0.01, "10 s of quiet: faint again (" .. bar:GetAlpha() .. ")")
mouseOn.window = true; Frames(5, 0.1)
check(math.abs(bar:GetAlpha() - 0.2) < 0.01, "faint: the chat window alone does not wake it")
mouseOn.window = nil
FCFDock_SelectWindow(GENERAL_CHAT_DOCK, other)
check(bar.ui.frame == other and bar.ui.box:GetText() == "", "another tab: its own search")
bar.ui.box:SetText("merci"); bar.ui.box:GetScript("OnTextChanged")(bar.ui.box, true); Wait()
check(bar.ui.count:GetText() == "1/1", "searched in that tab")
local elems = { { text = "Edit Mode" } }
local root3 = { Insert = function(_, d, index) table.insert(elems, index or (#elems + 1), d); return d end }
for _, fn in ipairs(mods) do fn(tab, root3, {}) end
check(#elems == 1, "beside the tabs: not in the tab's menu as well")
ns:SetChatSearchDock(false)
check(not bar:IsShown() and ns.sv.chatSearchDock == false, "unticked: the bar gone (back in the menu)")
out(string.format("\n%d failure(s)", fails))
return fails
