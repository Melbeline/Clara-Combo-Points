-- LFG Forever built in (Modules/LFGForever): Clara's changes to its window (window.lua) -- the right panel (filters
-- and whispers) closes with an arrow at the top right of the list, closed until first opened; the window narrower by
-- the panel and its gutter while it is (its left edge kept once moved), the saved width always the open window's; a
-- Search Again button beside the arrow while it is closed; a whisper lights the arrow. Then its words in French, its
-- saved tables, and its place in Clara (QoL, bindings, TOC). window.lua is loaded on its own, its panels stood in for.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local DIR = ADDON_DIR .. "/Modules/LFGForever/"
if not io.open(DIR .. "window.lua", "rb") then -- (the Light version: not built in)
  check(not readfile(ADDON_DIR .. "/ClaraComboPoints.toc"):find("LFGForever", 1, true), "the Light version: not in its TOC")
  out(fails .. " failure(s)")
  return
end

-- the game's templates the window uses, as far as it reads them
local function Stub(f, names) for _, n in ipairs(names) do if not f[n] then f[n] = function() end end end end
M.TEMPLATES.PortraitFrameTemplateNoCloseButton = function(f)
  f.TitleContainer = CreateFrame("Frame", nil, f)
  f.SetTitle = function(self, t) self._title = t end
  f.SetPortraitAtlasRaw = function() end
end
M.TEMPLATES.UIPanelCloseButtonNoScripts = function() end
M.TEMPLATES.InsetFrameTemplate = function() end
M.TEMPLATES.UIPanelSquareButton = function(f) f.icon = f:CreateTexture(); f:SetSize(26, 26) end
M.TEMPLATES.LargeSideTabButtonTemplate = function(f)
  f.Icon = f:CreateTexture()
  Stub(f, { "SetFillToInterior", "SetChecked", "SetCustomOnMouseUpHandler" })
  f:SetSize(44, 44)
end
M.TEMPLATES.PanelDragBarTemplate = function(f) f.Init = function() end end
M.TEMPLATES.PanelResizeButtonTemplate = function(f)
  f.Init = function(self, target, w, h) self.minWidth, self.minHeight = w, h end
  f.SetMinWidth = function(self, w) self.minWidth = w end
  f.SetOnResizeStoppedCallback = function(self, fn) self.stopped = fn end
end
local create = CreateFrame
function CreateFrame(...)
  local f = create(...)
  Stub(f, { "SetResizable", "SetUserPlaced" })
  f.SetResizeBounds = function(self, w, h) self._minW, self._minH = w, h end
  return f
end
function SquareButton_SetIcon(self, name) self._arrow = name end
FrameUtil = { UpdateScaleForFit = function() end }
local callbacks = {}
EventRegistry = { RegisterCallback = function(_, ev, fn, owner) callbacks[ev] = callbacks[ev] or {}; table.insert(callbacks[ev], fn) end,
  TriggerEvent = function(_, ev, ...) for _, fn in ipairs(callbacks[ev] or {}) do fn(nil, ...) end end }
UISpecialFrames = UISpecialFrames or {}

-- its panels and the rest of its private table, stood in for
local saved = {}
local searches, searchEnabled = 0, true
local LFGF = {
  L = { CLARA_SHOW_FILTERS = "Show filters and whispers", CLARA_HIDE_FILTERS = "Hide filters and whispers", SEARCH_AGAIN = "Search Again",
    TAB_CREATE_LISTING = "a", TAB_GROUP_BROWSER = "b", TAB_WHO_LIST = "c", COMBAT_WINDOW = "x" },
  TITLE = "LFG Forever", ICON_ATLAS = "atlas", EVENT_WHISPER_RECEIVED = "LFGForever.WhisperReceived",
  SavedValue = function(k) return saved[k] end, SaveValue = function(k, v) saved[k] = v end,
  ReadableNumbers = function(...) return ... end,
  IsFiniteNumber = function(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end,
  PlayClick = function() end, RequestGuildRoster = function() end, LoadTalentPoints = function() end,
  SetInviteActivitySource = function() end, Print = function() end,
}
function LFGF.CreateFilterPanel(parent)
  local p = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
  p:SetWidth(600)
  p.SearchButton = CreateFrame("Button", nil, p)
  function p:UpdateSearchState() self.SearchButton:SetEnabled(searchEnabled) end
  function p:RequestSearch() searches = searches + 1 end
  function p:CurrentFilters() return {} end
  function p:SelectedActivityIDs() return {} end
  return p
end
function LFGF.CreateListPanel(parent)
  local p = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
  function p:UseFilters() end
  return p
end
local Clara = { LFGForeverRuns = true, LFGForeverPrivate = LFGF }

local function LoadWindow()
  local fn = assert(loadstring(readfile(DIR .. "window.lua"), "@window.lua"))
  fn("ClaraComboPoints", Clara)
end
LoadWindow()

local function Left(f) local x = M.Rect(f) return x end
local function Width(f) return select(3, M.Rect(f)) end

out("== closed until first opened")
LFGF.OpenWindow()
local win = LFGForeverFrame
local content, filter, list = win.Content, win.Content.FilterPanel, win.Content.ListPanel
check(win:IsShown(), "/lfg: the window")
check(not filter:IsShown(), "the right panel closed")
check(math.abs(Width(win) - (1165 - 609)) < 0.5, "the window the panel and its gutter narrower: " .. tostring(Width(win)))
check(math.abs((select(3, M.Rect(list))) - (Width(win) - 4 - 6)) < 0.5, "the list to the window's right edge")
check(win._minW == 556 and win.ResizeButton.minWidth == 556, "its smallest width: without the panel")
check(win.FiltersToggle._arrow == "RIGHT", "the arrow points right (the way the panel opens)")
check(win.FiltersSearch:IsShown(), "Search Again beside the arrow")
local tx, ty, tw = M.Rect(win.FiltersToggle)
local lx, ly, lw, lh = M.Rect(list)
check(math.abs((tx + tw) - (lx + lw)) < 0.5, "the arrow at the list's right edge")
local sx, _, sw = M.Rect(win.FiltersSearch)
check(sx + sw <= tx, "Search Again left of the arrow")
win.FiltersSearch:GetScript("OnClick")(win.FiltersSearch)
check(searches == 1, "Search Again: the panel's own search, with its filters")

out("== opened")
local leftBefore = Left(win)
win.FiltersToggle:GetScript("OnClick")(win.FiltersToggle)
check(filter:IsShown(), "the arrow: the panel open")
check(math.abs(Width(win) - 1165) < 0.5, "the window its full width")
check(saved.filtersShown == true, "kept open (filtersShown)")
check(win.FiltersToggle._arrow == "LEFT", "the arrow points left (the way it closes)")
check(not win.FiltersSearch:IsShown(), "Search Again hidden: the panel has its own")
local _, _, listW = M.Rect(list)
check(math.abs(listW - (1165 - 4 - 6 - 600 - 9)) < 0.5, "the list to the panel's left edge: " .. tostring(listW))
check(win._minW == 1165, "its smallest width: with the panel")
check(math.abs(Left(win) - (leftBefore - 609 / 2)) < 0.5, "not moved by the player: still centred")

out("== moved, then closed: its left edge kept")
saved.windowX, saved.windowY = -100, 50
win:ClearAllPoints(); win:SetPoint("CENTER", UIParent, "CENTER", -100, 50)
local left = Left(win)
win.FiltersToggle:GetScript("OnClick")(win.FiltersToggle)
check(not filter:IsShown() and saved.filtersShown == false, "closed again, kept closed")
check(math.abs(Left(win) - left) < 0.5, "its left edge where it was")
check(math.abs(saved.windowX - (-100 - 609 / 2)) < 0.5, "its new centre saved")

out("== its size: always the open window's")
win:SetWidth(700)
win.ResizeButton.stopped(win)
check(saved.windowWidth == 700 + 609, "resized while closed: the open width saved (" .. tostring(saved.windowWidth) .. ")")
win.FiltersToggle:GetScript("OnClick")(win.FiltersToggle)
check(math.abs(Width(win) - 1309) < 0.5, "opened: the list keeps its width")
win.FiltersToggle:GetScript("OnClick")(win.FiltersToggle)
LFGF.ResetWindowPosition()
check(saved.windowWidth == nil and math.abs(Width(win) - 556) < 0.5, "reset: the default size, as the panel is")

out("== Search Again follows the panel's button")
searchEnabled = false
filter:UpdateSearchState()
check(not win.FiltersSearch:IsEnabled(), "a search running: Search Again off")
searchEnabled = true
filter:UpdateSearchState()
check(win.FiltersSearch:IsEnabled(), "done: on again")

out("== a whisper while it is closed")
EventRegistry:TriggerEvent(LFGF.EVENT_WHISPER_RECEIVED)
check(win.FiltersToggle._locked, "the arrow lit")
win.FiltersToggle:GetScript("OnClick")(win.FiltersToggle)
check(not win.FiltersToggle._locked, "opened: unlit")
EventRegistry:TriggerEvent(LFGF.EVENT_WHISPER_RECEIVED)
check(not win.FiltersToggle._locked, "open: the Whispers tab says it, not the arrow")

out("== built again open (a reload)")
LFGForeverFrame = nil
saved = { filtersShown = true }
LoadWindow()
LFGF.OpenWindow()
check(LFGForeverFrame.Content.FilterPanel:IsShown() and math.abs(Width(LFGForeverFrame) - 1165) < 0.5, "kept open: open at its full width")

out("== its words in French, checked as a pack's")
local locale = readfile(DIR .. "locale.lua")
check(locale:find("ClaraNS.LFGForeverStrings", 1, true) ~= nil, "locale.lua reads Clara's words before a pack")
local ClaraFR = { LFGForeverRuns = true }
GetLocale = function() return "frFR" end
assert(loadstring(readfile(DIR .. "Locale_Clara.lua"), "@Locale_Clara.lua"))("ClaraComboPoints", ClaraFR)
local fr = ClaraFR.LFGForeverStrings
check(fr and fr.FILTERS_TAB_TITLE == "Filtres" and fr.CLARA_HIDE_FILTERS == "Masquer les filtres et les chuchotements", "French words")
local english = {}
for k, v in locale:gmatch("\n\t([A-Z][A-Z0-9_]+) = (\"[^\n]-\"),\n") do english[k] = loadstring("return " .. v)() end
local function Conv(t) t = t:gsub("%%%%", ""); local l = {} for c in t:gmatch("%%%d*%$?[-+ #0]*%d*%.?%d*(%a)") do l[#l + 1] = c end table.sort(l) return table.concat(l) end
local bad = {}
for _, lang in ipairs({ "frFR", "deDE" }) do
  local C = { LFGForeverRuns = true }
  GetLocale = function() return lang end
  assert(loadstring(readfile(DIR .. "Locale_Clara.lua")))("ClaraComboPoints", C)
  for k, v in pairs(C.LFGForeverStrings) do
    if k:sub(-7) == "_FORMAT" and english[k] and Conv(english[k]) ~= Conv(v) then bad[#bad + 1] = lang .. " " .. k end
  end
end
check(#bad == 0, "every format keeps its conversions " .. table.concat(bad, ", "))
GetLocale = function() return "enUS" end

out("== its place in Clara")
local db = readfile(DIR .. "db.lua")
check(db:find('"ClaraLFGForeverDB"', 1, true) and db:find('"ClaraLFGForeverCharDB"', 1, true), "its own saved tables")
check(db:find('key = "filtersShown", scope = ACCOUNT, type = "boolean", default = false', 1, true) ~= nil, "the panel's state, closed by default")
local toc = readfile(ADDON_DIR .. "/ClaraComboPoints.toc")
check(toc:find("ClaraLFGForeverDB", 1, true) and toc:find("SavedVariablesPerCharacter:[^\n]*ClaraLFGForeverCharDB") and toc:find("OptionalDeps:[^\n]*LFGForever"),
  "the TOC: its tables, the standalone loaded first")
local bootIdx, locIdx = toc:find("Modules\\LFGForever\\Bootstrap.lua", 1, true), toc:find("Modules\\LFGForever\\locale.lua", 1, true)
check(bootIdx and locIdx and bootIdx < locIdx, "its bootstrap first")
check(readfile(ADDON_DIR .. "/Bindings.xml"):find('name="CLARA_LFGFOREVER_TOGGLE"', 1, true) ~= nil, "its key, in Clara's section")
check(readfile(ADDON_DIR .. "/QoL.lua"):find('key = "lfgforever", name = "LFG Forever", standalone = "LFGForever", theme = "quests"', 1, true) ~= nil,
  "a module of Clara's, under Quests")
check(not readfile(DIR .. "settings.lua"):find("\tlayout:AddInitializer(CreateSettingsButtonInitializer(REPORT_BUG_LABEL", 1, true), "no bug report row")
check(not readfile(DIR .. "main.lua"):find('print(L.LOADED_VERSION_FORMAT', 1, true), "no load greeting")
check(readfile(DIR .. "LICENSE"):find("GNU GENERAL PUBLIC LICENSE", 1, true) ~= nil, "its licence with it")

out(fails .. " failure(s)")
