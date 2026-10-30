-- the reworked options window: 888 wide, one row of class tabs in their colours, the list of
-- pages on the left (dragged to reorder, a 4-page order of an older version reset), each option
-- on one page only, the Bars page bar by bar (its box, its colours, its defaults), the font
-- dropdown, the portrait menu's boxes shared with the game's AddOns page, the reset of one tab,
-- and every widget inside its group box for a druid, a rogue, a warrior and a priest in the
-- three languages
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.01) end

-- The game's tabs as the client draws them. Two things the mock does not do (see mock_needs):
-- PanelTemplates_TabResize(tab, padding, absoluteSize) makes the tab absoluteSize wide, and a
-- text's width does not count its colour escapes (|cffrrggbb ... |r), which are not drawn.
local rawMeasure = MEASURE
MEASURE = function(path, size, text)
  text = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return rawMeasure(path, size, text)
end
function PanelTemplates_TabResize(tab, padding, absoluteSize)
  if absoluteSize then tab:SetWidth(math.max(40, absoluteSize)) return end
  tab:SetWidth(math.max(70, tab.Text:GetStringWidth() + 20 + (padding or 0)))
end

-- saved by a version with four pages
ClaraComboPointsDB = { profiles = {}, pageOrder = { 1, 2, 3, 4 } }
local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3 -- Cat Form
S.mana, S.manaMax, S.health, S.healthMax = 1200, 3000, 900, 1500
S.target = { cp = 2, hostile = true }; S.energy = 60; S.rage = 30
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
local L, sv = ns.L, ns.sv

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function label(f)
  if f.text and f.text._text then return f.text._text end
  if f._textFS then return f._textFS._text end
end
local function descends(r, root)
  local f = r
  while f do
    if f == root then return true end
    f = f._parent
  end
  return false
end
local panel
local function findButton(text, root)
  for _, f in ipairs(M.frames) do
    if (f._kind == "Button" or f._kind == "CheckButton") and f:IsVisible() and label(f) == text and (not root or descends(f, root)) then return f end
  end
end
local function findCheck(text, root)
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == text and (not root or descends(f, root)) then return f end
  end
end
local function shownText(text, root)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text == text and r:IsVisible() and (not root or descends(r, root)) then return r end
  end
end
-- left, bottom, right, top in the window's units
local function rr(r)
  local l, b, w, h = M.AbsRect(r)
  local s = panel and panel:GetEffectiveScale() or 1
  return l / s, b / s, (l + w) / s, (b + h) / s
end
local function R(r) M.ResetLayout(); return rr(r) end
-- lines a text takes in its width, word by word, as the game wraps it
local function wrapLines(fs, width)
  local path, size = fs._font[1], fs._font[2]
  local lines, line = 1, ""
  for word in strip(fs._text):gmatch("%S+") do
    local try = line == "" and word or (line .. " " .. word)
    if line ~= "" and MEASURE(path, size, try) > width then
      lines, line = lines + 1, word
    else
      line = try
    end
  end
  return lines
end

out("== saved variables")
check(ns.PAGE_COUNT == 5 and table.concat(sv.pageOrder, ",") == "1,2,3,4,5",
  "a four-page order from an older version: back to the five pages in order (" .. table.concat(sv.pageOrder, ",") .. ")")
check(ns.homeClass == "DRUID" and ns.profileClass == "DRUID", "a druid")

---------------------------------------------------------------------------
out("== the window: 888 wide, one row of class tabs in their colours")
SlashCmdList.CLARACOMBOPOINTS("")
panel = ClaraComboPointsOptions
check(panel and panel:IsShown() and near(panel:GetWidth(), 910) and near(panel:GetHeight(), 720),
  "the window is 910 x 720 (" .. panel:GetWidth() .. " x " .. panel:GetHeight() .. ")")
local CLASSES = { "PRIEST", "MAGE", "WARLOCK", "DRUID", "ROGUE", "HUNTER", "SHAMAN", "PALADIN", "WARRIOR" }
local HEX = { PRIEST = "ffffff", MAGE = "40c7eb", WARLOCK = "8787ed", DRUID = "ff7d0a", ROGUE = "fff569",
  HUNTER = "abd473", SHAMAN = "0070de", PALADIN = "f58cba", WARRIOR = "c79c6e" }
local tabs, tabList = {}, {}
for _, f in ipairs(M.frames) do
  if f.class and f.isTopTab then tabs[f.class] = f; tabList[#tabList + 1] = f end
end
local order = {}
for i, t in ipairs(tabList) do order[i] = t.class end
check(#tabList == 9 and table.concat(order, " ") == table.concat(CLASSES, " "), "nine class tabs (" .. table.concat(order, " ") .. ")")
local tabsBottom
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  M.ResetLayout()
  local pl, pb, pr, pt = rr(panel)
  local inside, oneRow, coloured, named = true, true, true, true
  local _, firstBottom = rr(tabList[1])
  local prevRight
  local spare = math.huge
  for _, t in ipairs(tabList) do
    local l, b, r, top = rr(t)
    if l < pl - 0.5 or r > pr - 0.5 or top > pt + 0.5 then inside = false end
    spare = math.min(spare, pr - r)
    if not near(b, firstBottom, 0.5) or (prevRight and l < prevRight - 0.5) then oneRow = false end
    prevRight = r
    local hex, text = tostring(t.Text._text):match("^|cff(%x%x%x%x%x%x)(.-)|r$")
    if not hex or hex:lower() ~= HEX[t.class] then coloured = false; out("    " .. t.class .. ": " .. tostring(t.Text._text)) end
    if text ~= L["TAB_" .. t.class] then named = false end
  end
  tabsBottom = firstBottom
  check(oneRow and inside, lang .. ": the nine tabs on one row, inside the window (" .. math.floor(spare) .. " px to spare on the right)")
  check(coloured and named, lang .. ": each tab's name in its class colour")
end
ns:SetLanguage("enUS")
tabs.ROGUE:Click()
check(ns.profileClass == "ROGUE" and ns.db == sv.profiles.ROGUE and tabs.ROGUE._selected == true and tabs.DRUID._selected == false,
  "a click on the Rogue tab: the rogue's profile, its tab selected")
tabs.PRIEST:Click()
check(ns.profileClass == "PRIEST" and ns.db == sv.profiles.PRIEST and tabs.PRIEST._selected and not tabs.ROGUE._selected, "the Priest tab")
tabs.DRUID:Click()
check(ns.profileClass == "DRUID" and ns.db == sv.profiles.DRUID, "back on the druid")

---------------------------------------------------------------------------
out("== the list of pages")
local navs = {}
for _, f in ipairs(M.frames) do if f._kind == "Button" and f.page and f.name and f.desc then navs[f.page] = f end end
local pages = {}
for _, f in ipairs(M.frames) do if f._parent == panel.sheet and f._kind == "Frame" and f.back then pages[#pages + 1] = f end end
local function press(b) -- a real click: the press, then the click
  if b._scripts and b._scripts.OnMouseDown then b._scripts.OnMouseDown(b, "LeftButton") end
  b:Click()
end
local function goPage(n) press(navs[n]) end
local PAGE_KEYS = { { "PAGE_GENERAL", "NAV_GENERAL" }, { "PAGE_BARS", "NAV_BARS" }, { "PAGE_ICONS", "NAV_ICONS" },
  { "PAGE_VISIBILITY", "NAV_VISIBILITY" }, { "PAGE_PROFILES", "NAV_PROFILES" } }
check(#navs == 5 and #pages == 5, "five page buttons, five pages (" .. #navs .. ", " .. #pages .. ")")
local navBox = navs[1]:GetParent()
check(navBox._template == "InsetFrameTemplate", "the page buttons in an inset on the left")
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  local texts, ok, fits = {}, true, true
  for i = 1, 5 do
    local b = navs[i]
    texts[i] = tostring(b.name._text)
    if b.name._text ~= L[PAGE_KEYS[i][1]] or b.desc._text ~= L[PAGE_KEYS[i][2]] or not b.name:IsVisible() or not b.desc:IsVisible() then ok = false end
    -- the name on one line, what the page holds on at most two (more would be cut), in the button
    local nameW = MEASURE(b.name._font[1], b.name._font[2], b.name._text)
    local lines = wrapLines(b.desc, b.desc._w)
    local _, bb, _, bt = R(b)
    local _, _, _, dt = R(b.desc)
    if nameW > b.name._w or lines > 2 or dt - lines * b.desc._font[2] < bb - 0.5 then
      fits = false; out(("    %s: %s (%.0f / %.0f px), %s (%d lines)"):format(lang, b.name._text, nameW, b.name._w, b.desc._text, lines))
    end
  end
  check(ok, lang .. ": each page with its name and a line saying what it holds (" .. table.concat(texts, ", ") .. ")")
  check(fits, lang .. ": names on one line, descriptions on two at most, inside their buttons")
end
ns:SetLanguage("enUS")
local TITLES = { "SCALE", "BARS_ORDER", "ICON_LOOK", "DISPLAY", "PROFILES" }
local side = ClaraComboPointsSpells
for n = 1, 5 do
  goPage(n)
  local count, which, backs = 0, nil, true
  for i, pg in ipairs(pages) do
    if pg:IsShown() then count, which = count + 1, i end
    if pg.back:IsShown() ~= pg:IsShown() then backs = false end
  end
  local actives = true
  for i, b in ipairs(navs) do
    local white = b.name._tc and b.name._tc[1] == 1 and b.name._tc[3] == 1
    if (i == n) ~= (white == true) then actives = false end
  end
  check(count == 1 and which == n and backs and shownText(L[TITLES[n]], pages[n]) ~= nil and actives,
    "page " .. n .. " (" .. L[PAGE_KEYS[n][1]] .. "): it alone shown, with its groups; its button lit")
  check(side:IsShown() == (n == 3), "page " .. n .. ": the class spells panel " .. (n == 3 and "opens beside it" or "closed"))
end
goPage(1)

out("== a page dragged up or down the list")
local function top(f) local _, _, _, t = R(f); return t end
local function dragNav(b, onto, below)
  b._scripts.OnDragStart(b)
  M.CursorOn(onto)
  M.cursorY = M.cursorY + (below and -8 or 8) * panel:GetEffectiveScale()
  M.Frame(0.016)
  b._scripts.OnDragStop(b)
end
dragNav(navs[3], navs[4], true) -- Icons let go on the lower half of Visibility
check(table.concat(sv.pageOrder, ",") == "1,2,4,3,5", "Icons let go under Visibility's middle: after it (" .. table.concat(sv.pageOrder, ",") .. ")")
check(top(navs[4]) > top(navs[3]) and top(navs[2]) > top(navs[4]) and top(navs[3]) > top(navs[5]), "drawn in that order, top to bottom")
local before = nil
for i, pg in ipairs(pages) do if pg:IsShown() then before = i end end
navs[3]:Click() -- the release of the drag is no click
check(pages[before]:IsShown() and not pages[3]:IsShown(), "letting go after a drag does not open the page")
goPage(3)
check(pages[3]:IsShown() and side:IsShown(), "a click after that opens it, with the class spells panel beside it (moved in the list)")
dragNav(navs[5], navs[1], false) -- Profiles let go on the upper half of General
check(table.concat(sv.pageOrder, ",") == "5,1,2,4,3", "Profiles let go above General's middle: first (" .. table.concat(sv.pageOrder, ",") .. ")")
check(top(navs[5]) > top(navs[1]), "drawn first")
panel:Hide()
SlashCmdList.CLARACOMBOPOINTS("")
check(table.concat(sv.pageOrder, ",") == "5,1,2,4,3" and top(navs[5]) > top(navs[1]) and top(navs[4]) > top(navs[3]), "closed and opened again: the order kept")
local previewBtn = findButton(L.PREVIEW)
local _, _, _, lastBottom = nil, nil, nil, nil
do
  local lowest = math.huge
  for _, b in ipairs(navs) do local _, b2 = R(b); lowest = math.min(lowest, b2) end
  local _, _, _, pt2 = R(previewBtn)
  check(previewBtn and previewBtn:GetParent() == navBox and pt2 <= lowest, "the preview button stays under the last page, whatever the order")
end
-- the window made bigger: the cursor read in its scale
ns:SetWindowScale(1.5)
dragNav(navs[1], navs[2], true) -- General let go on the lower half of Bars
check(near(panel:GetScale(), 1.5) and table.concat(sv.pageOrder, ",") == "5,2,1,4,3",
  "at 150 %: General let go under Bars' middle, after it (" .. table.concat(sv.pageOrder, ",") .. ")")
ns:SetWindowScale(nil)
-- closed in the middle of a drag: the button back to normal, the order as it was
navs[4]._scripts.OnDragStart(navs[4])
panel:Hide()
check(navs[4]:GetAlpha() == 1 and navs[4]:GetScript("OnUpdate") == nil and table.concat(sv.pageOrder, ",") == "5,2,1,4,3",
  "closed during a drag: the page button no longer follows the cursor")
SlashCmdList.CLARACOMBOPOINTS("")
ns:ResetAddon()
check(table.concat(sv.pageOrder, ",") == "1,2,3,4,5", "ns:ResetAddon(): the pages back in their order (" .. table.concat(sv.pageOrder, ",") .. ")")
local ordered = true
for i = 2, 5 do if not (top(navs[i - 1]) > top(navs[i])) then ordered = false end end
check(ordered, "and drawn in that order")
goPage(1)

---------------------------------------------------------------------------
out("== every option on one page only")
local function barRow(key)
  for _, f in ipairs(M.frames) do if f.swatches and f.show and f.key == key and f:IsVisible() then return f end end
end
local function pick(key) local r = barRow(key); if r then r:Click() end; return r end
local function classBars()
  local list = {}
  for _, key in ipairs(ns.db.bars.order) do if barRow(key) then list[#list + 1] = key end end
  return list
end
-- where something shows: each page (the Bars page with each of the class's bars picked)
local function places(find)
  local list = {}
  for n = 1, 5 do
    goPage(n)
    if n == 2 then
      for _, key in ipairs(classBars()) do
        pick(key)
        if find() then list[#list + 1] = "2:" .. key end
      end
    elseif find() then
      list[#list + 1] = tostring(n)
    end
  end
  goPage(1)
  return table.concat(list, " ")
end
local ALLBARS = "2:combo 2:power 2:mana 2:health"
local function onPage(text) return function() return shownText(text) end end
local function boxOn(text) return function() return findCheck(text) end end
local where = places(boxOn(L.SHOW_ADDON))
check(where == "4", "Show the addon: Visibility (" .. where .. ")")
where = places(boxOn(L.CAT_ONLY))
check(where == "4", "Cat and Bear Form only: Visibility, druid tab (" .. where .. ")")
where = places(boxOn(L.MENU_SECTION))
local where2 = places(boxOn(L.SP_MENU_RELOAD))
check(where == "4" and where2 == "4", "the portrait menu's section and Reload UI: Visibility (" .. where .. " / " .. where2 .. ")")
where = places(onPage(L.SOURCE))
where2 = places(function() return findButton(L.SOURCE_TARGET) and findButton(L.SOURCE_PLAYER) end)
check(where == "2:combo" and where2 == "2:combo", "combo points read on: Bars, combo points picked (" .. where .. " / " .. where2 .. ")")
where = places(onPage(L.TIMER_SIZE))
check(where == "3", "the countdown's size: Icons (" .. where .. ")")
where = places(boxOn(L.EDIT_ON_HUD))
check(where == "3", "edit the icons on the bar: Icons (" .. where .. ")")
where = places(boxOn(L.FADE_OOC))
check(where == "1", "fade out of combat: General (" .. where .. ")")
where = places(onPage(L.FONT))
check(where == "1", "the font: General (" .. where .. ")")
where = places(boxOn(L.CLASS_COLOR))
check(where == "2:health", "health in the class colour: Bars, health picked (" .. where .. ")")
where = places(function() return findButton(L.DEFAULT_ALL_BARS) end)
check(where == ALLBARS, "all bars to default: Bars (" .. where .. ")")
where = places(function() return findButton(L.RESET_CLASS:format(L.TAB_DRUID)) end)
check(where == "5", "the tab's reset: Profiles (" .. where .. ")")
local inNoPage = true
where = places(function()
  local b = findButton(L.PREVIEW)
  for _, pg in ipairs(pages) do if b and descends(b, pg) then inNoPage = false end end
  return b and b:GetParent() == navBox
end)
check(where == "1 " .. ALLBARS .. " 3 4 5" and inNoPage, "the preview: under the list of pages, on every page (" .. where .. ")")
where = places(function()
  local fs = shownText(L.WINDOW_OPACITY)
  return fs and fs:GetParent() == panel
end)
check(where == "1 " .. ALLBARS .. " 3 4 5", "the window's opacity: in the footer, on every page (" .. where .. ")")
-- no button or box on two pages
local seen = {}
for n = 1, 5 do
  goPage(n)
  local picks = n == 2 and classBars() or { false }
  for _, key in ipairs(picks) do
    if key then pick(key) end
    for _, f in ipairs(M.frames) do
      if f:IsVisible() and descends(f, pages[n]) then
        local text = f._kind == "CheckButton" and f.Text and f.Text._text or (f._template == "UIPanelButtonTemplate" and label(f))
        if text and text ~= "" then
          seen[text] = seen[text] or {}
          seen[text][n] = true
        end
      end
    end
  end
end
local twice = {}
for text, on in pairs(seen) do
  local n = 0
  for _ in pairs(on) do n = n + 1 end
  if n > 1 then twice[#twice + 1] = text end
end
local labelCount = 0
for _ in pairs(seen) do labelCount = labelCount + 1 end
check(#twice == 0 and labelCount > 40, "no button or box on two pages (" .. labelCount .. " of them" .. (#twice > 0 and (": " .. table.concat(twice, ", ")) or "") .. ")")
goPage(1)
local gone = {}
for _, key in ipairs({ "PAGE_BAR", "PAGE_TEXT", "PAGE_LAYOUT", "APPLY", "OOC", "COLORS_HINT", "BAR_BG", "BACKGROUND", "VALUE_ENERGY",
  "VALUE_RAGE", "VALUE_BOTH", "VALUE_MANA", "MORE_FONTS", "ADVANCED", "PREDICT", "RESET_ALL", "HIDE_SECTION", "UNLOCK_ICONS",
  "LOCK_ICONS", "ICONS_UNLOCKED_SHORT", "SHOW", "BAR_SIZE", "DEFAULT_SIZE_ALL", "COLORS_ON_BAR_PAGE" }) do
  if L[key] ~= nil then gone[#gone + 1] = key end
end
local missing = {}
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  for _, key in ipairs({ "PAGE_GENERAL", "PAGE_BARS", "PAGE_VISIBILITY", "PAGE_PROFILES", "NAV_GENERAL", "NAV_BARS", "NAV_ICONS",
    "NAV_VISIBILITY", "NAV_PROFILES", "OPACITY", "LOOK", "VALUE_TEXT", "COLOR", "BARS_BG", "DEFAULT_ALL_BARS", "DEFAULT_ALL_HINT",
    "ICONS_ON_HUD", "EDIT_ON_HUD", "DISPLAY", "MENU_SECTION", "HIDE_GROUP", "HIDE_ZONE", "RESET_TITLE", "RESET_CLASS", "RESET_HINT" }) do
    if type(L[key]) ~= "string" or L[key] == "" then missing[#missing + 1] = lang .. ":" .. key end
  end
  if L.HIDE_WHEN:find(":%s*$") then missing[#missing + 1] = lang .. ":HIDE_WHEN with a colon" end
end
ns:SetLanguage("enUS")
check(#gone == 0 and #missing == 0, "the old texts gone, the new ones in every language (" .. table.concat(gone, " ") .. table.concat(missing, " ") .. ")")
local pageTabs = 0
for _, f in ipairs(M.frames) do if f.isTopTab and f.page then pageTabs = pageTabs + 1 end end
check(pageTabs == 0 and #panel.Tabs == 9,
  "no page tabs any more: the nine class tabs are the window's only tabs")
check(findButton("Apply") == nil and shownText("More fonts") == nil and findButton(L.UNLOCK_ICONS or "Unlock icons") == nil,
  "no Apply button, no font list, no Unlock icons button any more")

out("== what each class's tab shows")
local function tabClick(class) tabs[class]:Click() end
local WANT = {
  DRUID = { show = "SHOW_BOTH", power = "OOC_POWER", top = "OOC_TOP", cat = "4", bear = "3", source = "2:combo" },
  ROGUE = { show = "SHOW_ENERGY", power = "ENERGY_BAR", top = "OOC_TOP", cat = "", bear = "", source = "2:combo" },
  WARRIOR = { show = "SHOW_RAGE", power = "RAGE_BAR", top = "OOC_ICONS", cat = "", bear = "", source = "" },
  PRIEST = { show = "SHOW_MANA", power = "OOC_MANA", top = "OOC_ICONS", cat = "", bear = "", source = "" },
}
for _, class in ipairs({ "DRUID", "ROGUE", "WARRIOR", "PRIEST" }) do
  tabClick(class)
  local w = WANT[class]
  goPage(1)
  local labelsOk = findCheck(L[w.show], pages[1]) ~= nil and shownText(L[w.power], pages[1]) ~= nil and shownText(L[w.top], pages[1]) ~= nil
  local cat, bear, source = places(boxOn(L.CAT_ONLY)), places(boxOn(L.BEAR_FIXED)), places(onPage(L.SOURCE))
  check(labelsOk and cat == w.cat and bear == w.bear and source == w.source,
    class .. ": " .. L[w.show] .. ", out of combat: " .. L[w.power] .. " / " .. L[w.top] .. "; cat form only [" .. cat
    .. "], bear form icons [" .. bear .. "], combo points read on [" .. source .. "]")
end
tabClick("DRUID")

out("== Icons page: the countdown's size, editing the icons on the bar")
goPage(3)
local timers = findCheck(L.SHOW_TIMERS, pages[3])
local timerSlider
for _, f in ipairs(M.frames) do
  if f._kind == "Slider" and f:IsVisible() and descends(f, pages[3]) and f._min == ns.MIN_TIMER and f._max == ns.MAX_TIMER then timerSlider = f end
end
check(timers and timerSlider and timerSlider:GetValue() == ns.db.icons.timerSize, "the countdown's size under Show time left")
timerSlider:SetValue(150)
check(ns.db.icons.timerSize == 150, "the slider sets it")
if timers:GetChecked() then timers:Click() end
check(ns.db.icons.timers == false and timerSlider:GetAlpha() < 1 and shownText(L.TIMER_SIZE, pages[3]):GetAlpha() < 1, "without the countdown: its size dimmed")
timers:Click()
check(ns.db.icons.timers == true and timerSlider:GetAlpha() == 1, "with it: lit")
timerSlider:SetValue(ns.defaults.icons.timerSize)
local onHud = findCheck(L.EDIT_ON_HUD, pages[3])
check(onHud and onHud:GetChecked() == false and ns.db.iconsLocked == true, "Edit icons right on the bar: unticked, the icons locked")
onHud:Click()
local allOpen = true
for _, profile in pairs(sv.profiles) do if profile.iconsLocked ~= false then allOpen = false end end
check(allOpen and onHud:GetChecked() == true, "ticked: the icons unlocked for every class")
tabClick("PRIEST")
check(findCheck(L.EDIT_ON_HUD, pages[3]):GetChecked() == true, "the Priest tab shows them unlocked too")
findCheck(L.EDIT_ON_HUD, pages[3]):Click()
local allLocked = true
for _, profile in pairs(sv.profiles) do if profile.iconsLocked ~= true then allLocked = false end end
check(allLocked, "unticked there: locked for every class")
tabClick("DRUID")
goPage(1)

---------------------------------------------------------------------------
out("== Bars page: each class's bars")
local function tab(class) tabs[class]:Click() end
local function colorRows()
  local list = {}
  for _, f in ipairs(M.frames) do
    if f.on and f.swatch and f.slider and f.label and f:IsVisible() and descends(f, pages[2]) then
      list[#list + 1] = f.label._text .. (f.on:IsVisible() and " [box]" or "")
    end
  end
  return table.concat(list, ", ")
end
local function colorRow(text, root)
  for _, f in ipairs(M.frames) do
    if f.on and f.swatch and f.slider and f.label and f.label._text == text and f:IsVisible() and (not root or descends(f, root)) then
      return f, (f.on:IsVisible() and f.on.check or nil)
    end
  end
end
local BARS = { DRUID = "combo power mana health", ROGUE = "combo power health", WARRIOR = "power health" }
local POWER_NAME = { DRUID = "Energy / rage", ROGUE = "Energy", WARRIOR = "Rage" }
goPage(2)
for _, class in ipairs(CLASSES) do
  tab(class)
  local want = BARS[class] or "mana health"
  local keys = {}
  for _, key in ipairs({ "combo", "power", "mana", "health" }) do if barRow(key) then keys[#keys + 1] = key end end
  local names = {}
  for _, key in ipairs(classBars()) do names[#names + 1] = barRow(key).name._text end
  local powerOk = not barRow("power") or barRow("power").name._text == POWER_NAME[class]
  check(table.concat(keys, " ") == want and powerOk, class .. ": " .. table.concat(names, ", "))
end
tab("DRUID")

out("== the box of a bar in the list: the whole bar")
local db = ns.db
local function hudTop(f) local _, b, _, h = M.AbsRect(f); return b + h end
local function hudBottom(f) local _, b = M.AbsRect(f); return b end
local box = barRow("combo").show.check
box:Click()
local allOff = true
for i = 1, 5 do if db.disabled["cp" .. i] ~= true then allOff = false end end
M.ResetLayout()
check(allOff and not ns:BarOn("combo") and not ns.comboRow:IsShown() and near(hudTop(ns.powerBar), hudTop(ns.hud), 0.5),
  "combo points unticked: the five cells off, the energy bar up to the top")
check(box:GetChecked() == false and barRow("combo").name:GetAlpha() < 1, "the row shows it off")
box:Click()
local allOn = true
for i = 1, 5 do if db.disabled["cp" .. i] ~= false then allOn = false end end
check(allOn and ns:BarOn("combo") and ns.comboRow:IsShown(), "ticked: the five cells back")
box = barRow("power").show.check
box:Click()
M.ResetLayout()
check(db.disabled.energy and db.disabled.rage and not ns:BarOn("power") and not ns.powerBar:IsShown()
  and near(hudTop(ns.manaBar), hudBottom(ns.comboRow) - ns.ROW_GAP * ns.hud:GetEffectiveScale(), 0.5),
  "the druid's energy / rage unticked: energy and rage off, the mana bar under the combo points")
box:Click()
check(not db.disabled.energy and not db.disabled.rage and ns.powerBar:IsShown(), "ticked: both back")
box = barRow("mana").show.check
box:Click()
check(db.bars.mana.show == false and not ns:BarOn("mana") and not ns.manaBar:IsShown(), "mana unticked: no mana bar")
box:Click()
check(db.bars.mana.show == true and ns.manaBar:IsShown(), "back")
local healthWas = db.bars.health.show
box = barRow("health").show.check
box:Click()
check(db.bars.health.show == not healthWas and ns.healthBar:IsShown() == db.bars.health.show and ns:BarOn("health") == db.bars.health.show,
  "health ticked: the health bar")
box:Click()
check(db.bars.health.show == healthWas, "and back")

out("== the bar picked: its own colours")
local function hintHas(names)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r:IsVisible() and descends(r, pages[2]) and type(r._text) == "string" then
      local all = true
      for _, n in ipairs(names) do if not r._text:find(n, 1, true) then all = false end end
      if all then return true end
    end
  end
end
pick("combo")
local rows = colorRows()
check(rows == "Combo point 1 [box], Combo point 2 [box], Combo point 3 [box], Combo point 4 [box], Combo point 5 [box]",
  "druid, combo points: the five cells, each with its box (" .. rows .. ")")
pick("power")
rows = colorRows()
check(rows == "Energy bar [box], Rage bar [box], Rage about to be spent [box]" and hintHas({ "Maul", "Frenzied Regeneration" }),
  "druid, energy / rage: energy, rage, rage about to be spent, each with its box, and the spells that spend it (" .. rows .. ")")
local _, costBox = colorRow("Rage about to be spent")
local predict = db.predict
costBox:Click()
check(db.predict == not predict, "the box of the rage about to be spent is the prediction switch")
costBox:Click()
pick("mana")
rows = colorRows()
check(rows == "Mana bar, Mana about to be spent [box]", "druid, mana: the mana bar, no box (the list's box switches it), the mana about to be spent with its box (" .. rows .. ")")
pick("health")
rows = colorRows()
check(rows == "Health bar" and findCheck(L.CLASS_COLOR, pages[2]) ~= nil, "druid, health: the health bar and the class colour box (" .. rows .. ")")
tab("ROGUE")
pick("power")
rows = colorRows()
check(rows == "Energy bar", "rogue, energy: the energy bar alone, no box (" .. rows .. ")")
tab("WARRIOR")
pick("power")
rows = colorRows()
check(rows == "Rage bar, Rage about to be spent [box]" and hintHas({ "Heroic Strike", "Cleave", "Slam" }),
  "warrior, rage: the rage bar without box, the rage about to be spent with its box and its spells (" .. rows .. ")")
local function groupTitles()
  local list = {}
  for _, f in ipairs(M.frames) do
    if M.IsGroupBox(f) and f:IsVisible() and descends(f, pages[2].back) then list[#list + 1] = strip(f.title and f.title._text) end
  end
  table.sort(list)
  return table.concat(list, " | ")
end
check(groupTitles() == "Bars, top to bottom | Rage", "the right-hand group named after the bar picked (" .. groupTitles() .. ")")
tab("PRIEST")
check(groupTitles() == "Bars, top to bottom | Mana" and colorRows() == "Mana bar, Mana about to be spent [box]",
  "the Priest tab, which has no rage bar: its first bar picked instead (" .. groupTitles() .. ")")
pick("mana")
rows = colorRows()
check(rows == "Mana bar, Mana about to be spent [box]", "priest, mana: the mana bar and the mana about to be spent (" .. rows .. ")")
pick("health")
rows = colorRows()
check(rows == "Health bar" and findCheck(L.CLASS_COLOR, pages[2]) ~= nil, "priest, health: the health bar and the class colour box (" .. rows .. ")")
tab("DRUID")
db = ns.db

out("== default colours: the bar picked only; every bar: all")
local function same(c, d) return near(c.r, d.r) and near(c.g, d.g) and near(c.b, d.b) and near(c.a, d.a) end
local function custom() return { r = .11, g = .22, b = .33, a = .44 } end
local function isCustom(c) return near(c.r, .11) and near(c.g, .22) and near(c.b, .33) end
for _, key in ipairs({ "cp2", "energy", "rage", "cost", "mana", "health", "text", "bg" }) do db.colors[key] = custom() end
ns:ApplyColors()
pick("combo")
findButton(L.DEFAULT_COLORS):Click()
check(same(db.colors.cp2, ns:SkinColor(db.skin, "cp2")), "combo points picked: cell 2 back to its colour")
check(isCustom(db.colors.energy) and isCustom(db.colors.mana) and isCustom(db.colors.text) and isCustom(db.colors.bg),
  "the other bars' colours, the text and the background stay")
pick("power")
findButton(L.DEFAULT_COLORS):Click()
check(same(db.colors.energy, ns:SkinColor(db.skin, "energy")) and same(db.colors.rage, ns:SkinColor(db.skin, "rage"))
  and same(db.colors.cost, ns:SkinColor(db.skin, "cost")), "energy / rage picked: energy, rage and the rage about to be spent back")
check(isCustom(db.colors.mana) and isCustom(db.colors.health) and isCustom(db.colors.text), "mana, health and the text stay")
local _, _, _, swatchAlpha = nil
local energyRow = colorRow("Energy bar")
check(energyRow and energyRow.swatch.color._color and near(energyRow.swatch.color._color[1], db.colors.energy.r)
  and near(energyRow.swatch.color._color[4], db.colors.energy.a), "its colour row shows it")
db.colors.energy = custom()
for _, key in ipairs({ "combo", "power", "mana", "health" }) do
  db.bars[key].width, db.bars[key].height, db.bars[key].scale = 111, 21, 1.5
end
ns:ApplyLayout()
pick("combo")
findButton(L.DEFAULT_SIZE, pages[2]):Click()
local d = ns.defaults.bars
check(db.bars.combo.width == d.combo.width and db.bars.combo.height == d.combo.height and db.bars.combo.scale == d.combo.scale
  and db.bars.power.width == 111 and db.bars.mana.height == 21, "Default size: the combo points only")
db.bars.combo.width, db.bars.combo.height, db.bars.combo.scale = 111, 21, 1.5
ns:ApplyLayout()
pick("mana")
findButton(L.DEFAULT_ALL_BARS):Click()
local sizes = true
for _, key in ipairs({ "combo", "power", "mana", "health" }) do
  local b, d = db.bars[key], ns.defaults.bars[key]
  if not (b.width == d.width and b.height == d.height and b.scale == d.scale) then sizes = false; out("    " .. key .. " " .. b.width .. " x " .. b.height) end
end
check(sizes, "all bars to default: every bar of the druid at its size and scale")
local colours = true
for key, c in pairs(db.colors) do
  local d = ns:SkinColor(db.skin, key)
  if d and not same(c, d) then colours = false; out("    " .. key) end
end
check(colours, "and every colour back (the text and the background too)")
local widthSlider
for _, f in ipairs(M.frames) do
  if f._kind == "Slider" and f:IsVisible() and descends(f, pages[2]) and f._min == ns.MIN_BAR_W and f._max == ns.MAX_BAR_W then widthSlider = f end
end
check(widthSlider and widthSlider:GetValue() == ns.defaults.bars.mana.width and widthSlider.box:GetText() == tostring(ns.defaults.bars.mana.width),
  "the width slider of the bar picked shows it")
-- another class's bars are not this tab's
local rogueW = sv.profiles.ROGUE.bars.combo.width
sv.profiles.ROGUE.bars.combo.width = 222
findButton(L.DEFAULT_ALL_BARS):Click()
check(sv.profiles.ROGUE.bars.combo.width == 222, "the rogue's bars are not touched from the druid's tab")
sv.profiles.ROGUE.bars.combo.width = rogueW

---------------------------------------------------------------------------
out("== General page: the font, a dropdown of the game's menus")
goPage(1)
local fonts = ns:GetFonts()
local fontBtn
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f.Refresh and f.text and f:IsVisible() and descends(f, pages[1]) then fontBtn = f end
end
check(fontBtn and fontBtn.text._text == db.font, "a dropdown showing the font in use (" .. tostring(fontBtn and fontBtn.text._text) .. ")")
local opened = M.menusOpened or 0
M.Press(fontBtn)
local menu = M.menu
local radios = {}
for _, item in ipairs(menu and menu.items or {}) do if item.kind == "radio" then radios[#radios + 1] = item end end
local names, sameOrder = {}, #radios == #fonts
for i, item in ipairs(radios) do
  names[i] = item.text
  if not fonts[i] or item.text ~= fonts[i].name then sameOrder = false end
end
check(menu and menu:IsShown() and M.menusOpened == opened + 1 and sameOrder, "a click opens the game's menu: one choice per font (" .. #radios .. " / " .. #fonts .. ")")
-- (the game's menu entries are about 20 tall: a list of every font scrolls past that height)
check(menu and type(menu.scrollExtent) == "number" and menu.scrollExtent > 0 and menu.scrollExtent < #fonts * 20,
  "the menu in scroll mode, shorter than the whole list (" .. tostring(menu and menu.scrollExtent) .. " / " .. #fonts * 20 .. ")")
local drawn, selected = true, true
for i, item in ipairs(radios) do
  local f = fonts[i]
  local fake = { fontString = UIParent:CreateFontString(nil, "OVERLAY") }
  for _, init in ipairs(item.initializers) do init(fake) end
  local path, size = fake.fontString:GetFont()
  if #item.initializers == 0 or path ~= f.path or size ~= (f.preview or 13) then drawn = false; out("    " .. f.name .. ": " .. tostring(path) .. " " .. tostring(size)) end
  if item.isSelected() ~= (f.name == db.font) then selected = false end
end
check(drawn, "each name drawn in its own font (a font object of its own)")
check(selected, "the font in use ticked")
local made = 0
for _ in pairs(M.madeFonts or {}) do made = made + 1 end
M.Press(fontBtn)
check(M.menu == nil and not menu:IsShown() and M.menusOpened == opened + 1, "a second click closes it, without opening it again")
M.Press(fontBtn)
local made2 = 0
for _ in pairs(M.madeFonts or {}) do made2 = made2 + 1 end
check(M.menu and M.menu:IsShown() and made2 == made and made > 0, "a third opens it again; the font objects are made once (" .. made .. ", " .. made2 .. ")")
local bangers
for _, f in ipairs(fonts) do if f.name == "Bangers" then bangers = f end end
M.MenuPick("Bangers")
check(db.font == "Bangers" and M.menu == nil, "picking one: the font set, the menu closed")
check(fontBtn.text._text == "Bangers" and fontBtn.text:GetFont() == bangers.path, "the dropdown shows its name, drawn in it")
local hudText = false
for _, r in ipairs(M.regions) do
  if r._kind == "FontString" and descends(r, ns.hud) and r._font and r._font[1] == bangers.path then hudText = true end
end
check(hudText, "the bar's value in that font")
M.Press(fontBtn)
M.Press(panel)
check(M.menu == nil, "a click elsewhere closes it")
db.font = ns.defaults.font; ns:ApplyFont(); panel:Refresh()

out("== the position, above the class tabs")
local lockBtn = panel.lockButton
M.ResetLayout()
local _, lb, _, lh = M.Rect(lockBtn)
local _, tb, _, th = M.Rect(tabs.DRUID)
local _, pb2, _, ph2 = M.Rect(panel)
check(label(lockBtn) == (ns.db.locked and L.UNLOCK or L.LOCK) and lb >= tb + th - 0.5 and lb + lh <= pb2 + ph2 - 20,
  "its two buttons between the title and the class tabs")
check(label(panel.resetPosButton) == L.DEFAULT_POS and shownText(L.POSITION) ~= nil, "Position, Unlock, Default position")
local wasLocked = ns.db.locked
lockBtn:Click()
check(ns.db.locked == not wasLocked and label(lockBtn) == (ns.db.locked and L.UNLOCK or L.LOCK), "the bar unlocked and locked by one button, its label following")
lockBtn:Click()
check(ns.db.locked == wasLocked, "back")

out("== General page: the value's colour, the background's box")
local textRow, textBox = colorRow(L.COLOR, pages[1])
check(textRow and not textBox, "the text's colour row has no box (the Show the value box switches it)")
check(findCheck(L.SHOW_BOTH, pages[1]) ~= nil, "the druid's Show energy / rage value box")
local bgRow, bgBox = colorRow(L.BARS_BG, pages[1])
check(bgRow and bgBox and bgBox:GetChecked() == true, "the background's row with its box, ticked")
bgBox:Click()
check(db.disabled.bg == true and bgBox:GetChecked() == false and ns.powerBar.bg._color[4] == 0, "unticked: no background drawn")
bgBox:Click()
check(db.disabled.bg == false and ns.powerBar.bg._color[4] > 0, "ticked: back")
local scaleSlider
for _, f in ipairs(M.frames) do
  if f._kind == "Slider" and f:IsVisible() and descends(f, pages[1]) and f._min == ns.MIN_SCALE and f._max == ns.MAX_SCALE then scaleSlider = f end
end
check(scaleSlider ~= nil, "the scale: a slider from " .. ns.MIN_SCALE .. " to " .. ns.MAX_SCALE .. " %")
if scaleSlider then
  scaleSlider.box:SetFocus(); scaleSlider.box:SetText("140")
  scaleSlider.box._scripts.OnEnterPressed(scaleSlider.box)
  check(ns:GetScalePercent() == 140 and findButton("150%").SetActive and scaleSlider:GetValue() == 140, "a value typed in its box, Enter: applied (" .. ns:GetScalePercent() .. ")")
  findButton("100%"):Click()
  check(ns:GetScalePercent() == 100 and scaleSlider:GetValue() == 100 and scaleSlider.box:GetText() == "100", "a preset: the slider follows")
end

---------------------------------------------------------------------------
out("== Visibility page: the portrait menu's boxes, here and on the game's AddOns page")
goPage(4)
local sectionBox = findCheck(L.MENU_SECTION, panel)
local reloadBox = findCheck(L.SP_MENU_RELOAD, panel)
check(sectionBox and reloadBox and sectionBox:GetChecked() and reloadBox:GetChecked() and sv.menu.line and sv.menu.reload,
  "the menu's section and Reload UI, both ticked")
sectionBox:Click()
check(sv.menu.line == false and sectionBox:GetChecked() == false, "the section unticked: off")
M.ShowSettingsPage(ns.settingsCategory)
local spLine = findCheck(L.SP_MENU_LINE)
local spReload
for _, f in ipairs(M.frames) do
  if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == L.SP_MENU_RELOAD and not descends(f, panel) then spReload = f end
end
check(spLine and spLine:GetChecked() == false and spReload and spReload:GetChecked() == true, "the AddOns page shows the same: section off, Reload UI on")
sectionBox:Click()
check(sv.menu.line == true and spLine:GetChecked() == true, "ticked in the options window: ticked on the AddOns page at once")
spLine:Click()
check(sv.menu.line == false and sectionBox:GetChecked() == false, "unticked on the AddOns page: unticked in the options window")
spLine:Click()
spReload:Click()
check(sv.menu.reload == false and reloadBox:GetChecked() == false, "Reload UI unticked there: here too")
reloadBox:Click()
check(sv.menu.reload == true and spReload:GetChecked() == true, "ticked here: there too")
SettingsPanel:Hide()
check(sv.menu.line == true and sectionBox:GetChecked() == true, "both on again")
local groupX, zoneX
do
  local g, z = shownText(L.HIDE_GROUP, pages[4]), shownText(L.HIDE_ZONE, pages[4])
  groupX, zoneX = g and R(g), z and R(z)
end
local columns = groupX and zoneX and zoneX > groupX + 100
for _, key in ipairs({ "solo", "party", "raid" }) do
  local c = findCheck(L["HIDE_" .. key:upper()], pages[4]); local l = c and R(c)
  if not (l and l < zoneX - 20) then columns = false end
end
for _, key in ipairs({ "dungeon", "raid10", "raid20", "raid40" }) do
  local c = findCheck(L["HIDE_" .. key:upper()], pages[4]); local l = c and R(c)
  if not (l and l > zoneX - 20) then columns = false end
end
check(columns, "Hide it when: group situations in one column, zones in the other")

---------------------------------------------------------------------------
out("== Profiles page: the reset of the tab")
goPage(5)
for _, class in ipairs({ "DRUID", "ROGUE", "WARRIOR" }) do sv.profiles[class].fontSize = 23 end
ns:SaveProfile("DRUID", "Mine")
sv.profiles.DRUID.fontSize = 24
local labels = {}
for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
  ns:SetLanguage(lang)
  labels[#labels + 1] = tostring(findButton(L.RESET_CLASS:format(L.TAB_DRUID), pages[5]) and L.RESET_CLASS:format(L.TAB_DRUID))
end
ns:SetLanguage("enUS")
check(#labels == 3 and labels[1] == "Reset: Druid" and labels[2] == "Réinitialiser : Druide" and labels[3] == "Druide zurücksetzen",
  "the button names the tab (" .. table.concat(labels, " / ") .. ")")
tab("ROGUE")
check(findButton("Reset: Rogue", pages[5]) ~= nil, "on the Rogue tab: Reset: Rogue")
tab("DRUID")
local reset = findButton("Reset: Druid", pages[5])
reset:Click()
check(label(reset) == L.CONFIRM and sv.profiles.DRUID.fontSize == 24, "a first click asks to confirm, nothing reset yet")
M.RunTimer(#M.timers)
check(label(reset) == "Reset: Druid", "3 s later without a click: back to Reset: Druid")
reset:Click()
tab("ROGUE"); tab("DRUID")
check(label(reset) == "Reset: Druid" and sv.profiles.DRUID.fontSize == 24, "a tab change disarms it")
reset:Click(); reset:Click()
check(sv.profiles.DRUID.fontSize == ns.defaults.fontSize and ns.db == sv.profiles.DRUID, "two clicks: the druid's settings back to the defaults")
check(sv.profiles.ROGUE.fontSize == 23 and sv.profiles.WARRIOR.fontSize == 23, "the other tabs untouched")
check(ns:HasProfile("DRUID", "Mine"), "the saved profiles stay")
ns:LoadProfile("DRUID", "Mine")
check(sv.profiles.DRUID.fontSize == 23, "and still hold what was saved")
sv.profiles.ROGUE.fontSize, sv.profiles.WARRIOR.fontSize = ns.defaults.fontSize, ns.defaults.fontSize
ns:ResetAll()
goPage(1)

---------------------------------------------------------------------------
out("== footer: the commands, the window's opacity at the bottom right")
do
  local opacityLabel = shownText(L.WINDOW_OPACITY, panel)
  local slider
  for _, f in ipairs(M.frames) do if f._kind == "Slider" and f._parent == panel then slider = f end end
  local grip
  for _, f in ipairs(M.frames) do if f._parent == panel and f._normalTex and tostring(f._normalTex):find("SizeGrabber") then grip = f end end
  local commands
  for _, r in ipairs(M.regions) do if r._kind == "FontString" and r._parent == panel and tostring(r._text):find("/cl lock", 1, true) then commands = r end end
  local fine = true
  for _, lang in ipairs({ "enUS", "frFR", "deDE" }) do
    ns:SetLanguage(lang)
    M.ResetLayout()
    local pl, pb, pr = rr(panel)
    local ll, lb, lr = rr(opacityLabel)
    local sl, sb, sr = rr(slider)
    local bl, _, br = rr(slider.box)
    local ul, _, ur = rr(slider.unit)
    local gl = rr(grip)
    local _, _, cr = rr(commands)
    if not (ll > (pl + pr) / 2 and lr <= sl and sb < pb + 40 and ur <= gl and cr < ll - 4) then
      fine = false
      out(("    %s: label %.0f-%.0f, slider %.0f-%.0f, box %.0f-%.0f, %% %.0f-%.0f, grip %.0f, commands to %.0f"):format(lang, ll, lr, sl, sr, bl, br, ul, ur, gl, cr))
    end
  end
  ns:SetLanguage("enUS")
  check(opacityLabel and slider and near(slider:GetWidth(), 90) and near(slider.box.holder:GetWidth(), 32) and fine,
    "the window's opacity (slider 90, box 32) bottom right, clear of the scale grip and of the commands, in the three languages")
  slider:SetValue(60)
  check(near(sv.window.alpha, .6) and near(panel:GetAlpha(), .6), "it sets the window's opacity")
  slider:SetValue(100)
end

---------------------------------------------------------------------------
out("== every widget inside its group box, nothing out of its page")
-- A text with a width and no height is as tall as its lines in the game (the mock gives it no
-- height, see mock_needs): each such text of the window gets the height it reads, at most its
-- maximum lines.
local autoH = {}
local function fitTexts()
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and (autoH[r] or (r._w and not r._h)) and descends(r, panel) then
      local size = r._font and r._font[2] or 10
      local h = r:GetStringHeight()
      if r._maxLines then h = math.min(h, r._maxLines * size) end
      r._h = h
      autoH[r] = true
    end
  end
end
local footerTop
do
  M.ResetLayout()
  footerTop = -math.huge
  for _, f in ipairs(M.frames) do
    if f._parent == panel and (f._kind == "Slider" or f._kind == "Button") and not f.class and f.lang == nil and f:IsVisible() then
      local _, _, _, t = rr(f)
      local _, pb = rr(panel)
      if t < pb + 60 then footerTop = math.max(footerTop, t) end
    end
  end
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._parent == panel and r:IsVisible() and strip(r._text) ~= "" then
      local _, _, _, t = rr(r)
      local _, pb = rr(panel)
      if t < pb + 60 then footerTop = math.max(footerTop, t) end
    end
  end
end
local function what(r)
  local text = r._kind == "FontString" and r._text or (r.Text and r.Text._text) or label(r) or (r._parent and r._parent.Text and r._parent.Text._text)
  return r._kind .. (text and (" '" .. strip(text) .. "'") or "")
end
local E = 0.5
local function view(n, tag, problems)
  local pg = pages[n]
  fitTexts()
  M.ResetLayout()
  local boxes, items = {}, {}
  for _, f in ipairs(M.frames) do
    if f:IsVisible() then
      if M.IsGroupBox(f) and descends(f, pg.back) then
        boxes[#boxes + 1] = f
      elseif f ~= pg and descends(f, pg) and (f._kind == "Button" or f._kind == "CheckButton" or f._kind == "Slider" or f._kind == "EditBox") then
        items[#items + 1] = f
      end
    end
  end
  for _, r in ipairs(M.regions) do
    if r:IsVisible() and descends(r, pg) then
      if (r._kind == "FontString" and strip(r._text) ~= "") or (r._kind == "Texture" and r._points and #r._points > 0) then items[#items + 1] = r end
    end
  end
  local function problem(s) problems[#problems + 1] = tag .. ": " .. s end
  local pl, pb, pr, pt = rr(pg)
  local navL, _, navR = rr(navBox)
  local rect = {}
  for _, b in ipairs(boxes) do
    local l, bo, r, t = rr(b)
    rect[b] = { l, bo, r, t }
    local title = strip(b.title and b.title._text)
    if l < pl - E or r > pr + E or bo < pb - E or t > pt + E then problem("group '" .. title .. "' out of the page") end
    if t > tabsBottom + E then problem("group '" .. title .. "' over the class tabs") end
    if bo < footerTop + E then problem(("group '%s' down to the footer (%.0f < %.0f)"):format(title, bo, footerTop)) end
    if l < navR + E then problem("group '" .. title .. "' over the list of pages") end
  end
  for i = 1, #boxes do
    for j = i + 1, #boxes do
      local a, c = rect[boxes[i]], rect[boxes[j]]
      if a[1] < c[3] - E and c[1] < a[3] - E and a[2] < c[4] - E and c[2] < a[4] - E then
        problem("groups '" .. strip(boxes[i].title._text) .. "' and '" .. strip(boxes[j].title._text) .. "' overlap")
      end
    end
  end
  local ir = {}
  for _, it in ipairs(items) do
    local l, b, r, t = rr(it)
    ir[it] = { l, b, r, t }
    local inAny = false
    for _, bx in ipairs(boxes) do
      local x = rect[bx]
      local over = l < x[3] - E and r > x[1] + E and b < x[4] - E and t > x[2] + E
      local within = l >= x[1] - E and r <= x[3] + E and b >= x[2] - E and t <= x[4] + E
      if within then inAny = true elseif over then problem(("%s sticks out of '%s' (%.0f-%.0f x %.0f-%.0f in %.0f-%.0f x %.0f-%.0f)"):format(
        what(it), strip(bx.title._text), l - pl, r - pl, pt - t, pt - b, x[1] - pl, x[3] - pl, pt - x[4], pt - x[2])) end
    end
    if not inAny then problem(("%s outside every group (%.0f-%.0f x %.0f-%.0f)"):format(what(it), l - pl, r - pl, pt - t, pt - b)) end
    if l < pl - E or r > pr + E or b < pb - E or t > pt + E then problem(what(it) .. " out of the page") end
  end
  -- a text over another widget (not its own button or box)
  for _, a in ipairs(items) do
    if a._kind == "FontString" then
      local x = ir[a]
      for _, c in ipairs(items) do
        if c ~= a and c._kind ~= "Texture" and not descends(a, c) and not descends(c, a._parent) then
          local y = ir[c]
          if x[1] < y[3] - E and y[1] < x[3] - E and x[2] < y[4] - E and y[2] < x[4] - E then
            problem(what(a) .. " over " .. what(c))
          end
        end
      end
      -- a button's label inside its button
      local p = a._parent
      if p and p._template == "UIPanelButtonTemplate" and a == p._textFS then
        local y = ir[p] or { rr(p) }
        if x[1] < y[1] + 2 - E or x[3] > y[3] - 2 + E then problem(("%s wider than its button (%.0f / %.0f)"):format(what(a), x[3] - x[1], y[3] - y[1])) end
      end
    end
  end
end
local LANGS = { "enUS", "frFR", "deDE" }
for _, class in ipairs({ "DRUID", "ROGUE", "WARRIOR", "PRIEST" }) do
  tab(class)
  for _, lang in ipairs(LANGS) do
    ns:SetLanguage(lang)
    local problems = {}
    for n = 1, 5 do
      goPage(n)
      if n == 2 then
        for _, key in ipairs(classBars()) do
          pick(key)
          view(n, "Bars/" .. key, problems)
        end
      elseif n == 3 then -- the icons' shapes: square (a size slider), combo point cells (the cells' size)
        view(n, L[PAGE_KEYS[n][1]], problems)
        findButton(L.SHAPE_CELL, pages[3]):Click()
        view(n, L[PAGE_KEYS[n][1]] .. "/" .. L.SHAPE_CELL, problems)
        findButton(L.SHAPE_SQUARE, pages[3]):Click()
      else
        view(n, L[PAGE_KEYS[n][1]], problems)
      end
    end
    for i = 1, math.min(#problems, 12) do out("    " .. problems[i]) end
    if #problems > 12 then out("    ... " .. (#problems - 12) .. " more") end
    check(#problems == 0, class .. ", " .. lang .. ": every widget in its group, groups apart, in the page (" .. #problems .. " problems)")
  end
end
ns:SetLanguage("enUS")
tab("DRUID")
goPage(1)

out("== the list of pages: preview and the character's class under it")
do
  local hint = shownText(L.PREVIEW_HINT, navBox)
  local who = shownText(L.THIS_CHARACTER:format(L.TAB_DRUID), navBox)
  fitTexts(); M.ResetLayout()
  local nl, nb, nr = rr(navBox)
  local lowest = math.huge
  for _, b in ipairs(navs) do local _, b2 = rr(b); lowest = math.min(lowest, b2) end
  local vl, vb, vr, vt = rr(previewBtn)
  local hl, hb, hr, ht = rr(hint)
  local wl, wb, wr, wt = rr(who)
  check(vt <= lowest and vl >= nl and vr <= nr and ht <= vb and hl >= nl and hr <= nr, "the preview button and its hint under the pages, in the list")
  check(who and wb >= nb and wl >= nl and wr <= nr + E and wt < hb, "'This character uses: Druid' at the bottom of the list")
  previewBtn:Click()
  check(not ns.preview, "the preview off by a click")
  previewBtn:Click()
  check(ns.preview, "and on again")
end
panel:Hide()

out(("\n%d failure(s)"):format(fails))
return fails
