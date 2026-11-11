-- the portrait's menu (opacity slider, show / hide box, Reload UI), the HUD hidden by hand or
-- in some situations, and the game's menus opened by our buttons closing on a second click
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.01) end
local function label(f)
  if f.text and f.text._text then return f.text._text end
  if f._textFS then return f._textFS._text end
end
local function findButton(text)
  for _, f in ipairs(M.frames) do
    if (f._kind == "Button" or f._kind == "CheckButton") and f:IsVisible() and label(f) == text then return f end
  end
end
local function findCheck(text)
  for _, f in ipairs(M.frames) do
    if f._kind == "CheckButton" and f:IsVisible() and f.Text and f.Text._text == text then return f end
  end
end

-- damaged settings from before
ClaraComboPointsDB = { profiles = { ROGUE = { hidden = "yes", hideWhen = { solo = 1, party = true, junk = true } } } }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"; S.powerType = 3
S.target = { cp = 2, hostile = true }; S.energy = 60
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local L = ns.L
M.now = 100
M.Frame(0.016)

out("== saved variables")
local db = ns.db
check(db.hidden == false, "hidden of the wrong kind: shown")
check(db.hideWhen.solo == false and db.hideWhen.party == true and db.hideWhen.junk == nil and db.hideWhen.raid40 == false,
  "hide-when: wrong kinds back to off, unknown keys gone, good ones kept")
db.hideWhen.party = false
ns:UpdateVisibility()
check(ns.hud:IsShown(), "the HUD shows")

out("== the portrait's menu")
local menu = M.OpenUnitMenu("SELF")
local texts = M.UnitMenuTexts()
local order = table.concat(texts, " | ")
check(order:find("Other Options | Edit Mode | Voice Chat | Leave Party | <divider> | Clara Combo Points | Reload UI | <frame> | More...", 1, true) ~= nil
  and order:sub(-7) == "More...",
  "the game's entries as they are (none moved), the addon's section after them: Reload UI, the line, More... (" .. order .. ")")
local lineFrame
for i, d in ipairs(menu.root.elements) do if d.kind == "frame" then lineFrame = menu.frames[i] end end
local line
for _, f in ipairs(M.frames) do if f.slider and f.check and f.label then line = f end end
check(line and line:GetParent() == lineFrame and line:IsVisible(), "the line is in the menu, shown")
check(near(lineFrame:GetWidth(), 128) and near(lineFrame:GetHeight(), 42), "the menu gives it its size, as narrow as the game's entries")
M.ResetLayout()
local _, sb, _, sh = M.AbsRect(line.slider); local _, fb, _, fh = M.AbsRect(lineFrame)
check(sb >= fb - 0.01 and sb + sh <= fb + fh + 0.01, "the slider stays inside the line")
check(line.label._text == "Opacity" and line.value._text == "100 %", "Opacity, the value beside (" .. tostring(line.value._text) .. ")")
check(line.lock and line.lock:GetChecked() == true, "the icons-locked box, ticked")
M.ResetLayout()
local lx, lb, lw = M.AbsRect(line.lock); local cx, cb, cw = M.AbsRect(line.check); local sx, sb2, sw, sh2 = M.AbsRect(line.slider)
local fx, _, fw = M.AbsRect(lineFrame)
check(near(sx, fx) and sx + sw <= lx + 0.01 and lx + lw <= cx + 0.01, "slider, lock box, show box from left to right")
check(cx + cw <= fx + fw + 3.01 and cx + cw >= fx + fw - 0.01, "the show box at the right end")
check(near(lb, cb) and near(sb2 + sh2 / 2, lb + lw / 2), "all three level")
line.lock:Click()
local allOpen = true
for _, profile in pairs(ns.sv.profiles) do if profile.iconsLocked ~= false then allOpen = false end end
check(allOpen and ns:IconsEditable(), "unticked: the icons unlocked, for every class")
line.lock:Click()
local allLocked = true
for _, profile in pairs(ns.sv.profiles) do if profile.iconsLocked ~= true then allLocked = false end end
check(allLocked and not ns:IconsEditable(), "ticked again: locked for every class")
check(line.check:GetChecked() == true, "the box is ticked: the addon is shown")
check(line.slider._template == "MinimalSliderWithSteppersTemplate", "the game's slider with steppers")
line.slider:SetValue(40)
check(near(db.alpha, .4) and near(ns.hud:GetAlpha(), .4), "the slider sets the HUD's opacity (" .. db.alpha .. ")")
check(line.value._text == "40 %", "the value follows")
line.check:Click()
check(db.hidden == true and not ns.hud:IsShown(), "unticking the box hides the whole HUD")
line.check:Click()
check(db.hidden == false and ns.hud:IsShown(), "ticking it shows it again")
M.CloseUnitMenu()
check(not line:IsVisible() and line:GetParent() == UIParent, "the menu closed: the line goes back to the addon")
-- another menu reuses the frames, the line for another element
db.alpha = .65; ns:ApplyAlpha(); db.hidden = true; ns:UpdateVisibility()
menu = M.OpenUnitMenu("SELF")
for i, d in ipairs(menu.root.elements) do if d.kind == "frame" then lineFrame = menu.frames[i] end end
check(line:GetParent() == lineFrame and line:IsVisible(), "opened again: lent to its element again")
check(line.value._text == "65 %" and line.check:GetChecked() == false, "showing the settings of now (" .. tostring(line.value._text) .. ")")
check(near(db.alpha, .65) and db.hidden == true, "filling the line changes nothing")
M.CloseUnitMenu()
db.hidden = false; ns:UpdateVisibility()

out("== the game's options: each part of the menu can be left out")
ns.sv.menu.line = false
M.OpenUnitMenu("SELF")
order = table.concat(M.UnitMenuTexts(), " | ")
check(not order:find("Clara Combo Points", 1, true) and order:find("Reload UI", 1, true), "section off: Reload UI alone (" .. order .. ")")
M.CloseUnitMenu()
ns.sv.menu.line, ns.sv.menu.reload = true, false
M.OpenUnitMenu("SELF")
order = table.concat(M.UnitMenuTexts(), " | ")
check(not order:find("Reload UI", 1, true) and order:find("Clara Combo Points", 1, true), "Reload UI off: the section alone (" .. order .. ")")
M.CloseUnitMenu()
ns.sv.menu.reload = true

out("== /cl hide, /cl show")
SlashCmdList.CLARACOMBOPOINTS("hide")
check(db.hidden and not ns.hud:IsShown(), "/cl hide")
SlashCmdList.CLARACOMBOPOINTS("show")
check(not db.hidden and ns.hud:IsShown(), "/cl show")

out("== hidden in some situations")
local function shown() ns:UpdateVisibility(); return ns.hud:IsShown() end
S.group, S.instance = nil, nil
db.hideWhen.solo = true
check(not shown(), "not in a group, hidden when not in a group")
S.group = "party"; M.Fire("GROUP_ROSTER_UPDATE")
check(ns.hud:IsShown(), "joining a party shows it (the event)")
db.hideWhen.party = true
check(not shown(), "in a party, hidden in a party")
S.group = "raid"; M.Fire("GROUP_ROSTER_UPDATE")
check(ns.hud:IsShown(), "a raid group is not a party")
db.hideWhen.raid = true
check(not shown(), "hidden in a raid group")
db.hideWhen.solo, db.hideWhen.party, db.hideWhen.raid = false, false, false
check(shown(), "nothing ticked: shown")
local function inside(kind, maxPlayers, groupSize)
  S.instance = { kind = kind, maxPlayers = maxPlayers, groupSize = groupSize }
  M.Fire("ZONE_CHANGED_NEW_AREA")
  return ns:Situation()
end
check(inside("party", 5).dungeon, "a dungeon")
db.hideWhen.dungeon = true
inside("party", 5)
check(not ns.hud:IsShown(), "hidden in a dungeon (zoning in)")
check(inside("raid", 10).raid10 and ns.hud:IsShown(), "a 10-player raid is not a dungeon")
check(inside("raid", 20).raid20 and inside("raid", 25).raid20 and inside("raid", 40).raid40, "20, 25 (as 20) and 40-player raids")
check(inside("raid", 0, 40).raid40, "no player count: the group size")
db.hideWhen.raid40 = true
inside("raid", 40)
check(not ns.hud:IsShown(), "hidden in a 40-player raid")
check(inside("raid", 20) and ns.hud:IsShown(), "shown in a 20-player raid")
inside("raid", 40)
ns:SetLocked(false)
check(ns.hud:IsShown(), "unlocked: shown, to be moved")
ns:SetLocked(true)
check(not ns.hud:IsShown(), "locked again: hidden")
SlashCmdList.CLARACOMBOPOINTS("")
check(ns.hud:IsShown(), "options open: shown, to be set up")
local panel = ClaraComboPointsOptions
panel:Hide()
check(not ns.hud:IsShown(), "options closed: hidden again")
S.instance = nil; M.Fire("ZONE_CHANGED_NEW_AREA")
check(ns.hud:IsShown(), "out of the raid: shown")
ns:SetHidden(true)
SlashCmdList.CLARACOMBOPOINTS("")
check(not ns.hud:IsShown(), "hidden by hand: hidden even with the options open")
panel:Hide()
ns:SetHidden(false)

out("== options: Visibility page")
S.group = nil; M.Fire("GROUP_ROSTER_UPDATE")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 4 and f.Click then f:Click() end end -- Visibility, in the list on the left
local showBox = findCheck("Show the addon (also in the portrait's menu)")
check(showBox and showBox:GetChecked() == true, "a Show the addon box, ticked")
showBox:Click()
check(db.hidden and not ns.hud:IsShown(), "unticked: hidden")
showBox:Click()
check(not db.hidden and ns.hud:IsShown(), "ticked: shown")
local all, seen = true, 0
for _, key in ipairs(ns.HIDE_WHEN) do
  local box = findCheck(L["HIDE_" .. key:upper()])
  if box then seen = seen + 1 end
  if not box or box:GetChecked() ~= (db.hideWhen[key] == true) then all = false end
end
check(all and seen == 8, "the eight situations, each as set (" .. seen .. " found)")
local soloBox = findCheck(L.HIDE_SOLO)
soloBox:Click()
check(db.hideWhen.solo == true and ns.hud:IsShown(), "ticking one keeps the HUD shown while the options are open")
panel:Hide()
check(not ns.hud:IsShown(), "and hides it once they close (not in a group)")
db.hideWhen.solo = false; db.hideWhen.dungeon = false; db.hideWhen.raid40 = false
ns:UpdateVisibility()

out("== options: the portrait's menu parts, on the Visibility page")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 4 and f.Click then f:Click() end end
local sectionBox, reloadBox = findCheck(L.MENU_SECTION), findCheck(L.SP_MENU_RELOAD)
check(sectionBox and sectionBox:GetChecked() == true and reloadBox and reloadBox:GetChecked() == true,
  "the menu's section and Reload UI boxes, both ticked")
if sectionBox then sectionBox:Click() end
M.OpenUnitMenu("SELF")
order = table.concat(M.UnitMenuTexts(), " | ")
check(ns.sv.menu.line == false and not order:find("Clara Combo Points", 1, true) and order:find("Reload UI", 1, true),
  "section unticked: left out of the menu (" .. order .. ")")
M.CloseUnitMenu()
if sectionBox then sectionBox:Click() end
if reloadBox then reloadBox:Click() end
M.OpenUnitMenu("SELF")
order = table.concat(M.UnitMenuTexts(), " | ")
check(ns.sv.menu.line == true and ns.sv.menu.reload == false and not order:find("Reload UI", 1, true) and order:find("Clara Combo Points", 1, true),
  "section ticked again, Reload UI unticked: the section alone (" .. order .. ")")
M.CloseUnitMenu()
if reloadBox then reloadBox:Click() end
check(ns.sv.menu.reload == true and reloadBox:GetChecked() == true, "Reload UI ticked again")
-- the same two boxes on the game's AddOns page follow, and the other way round
M.ShowSettingsPage(ns.settingsCategory)
local spLine = findCheck(L.SP_MENU_LINE)
check(spLine and spLine:GetChecked() == true, "the AddOns page's section box, ticked")
if sectionBox then sectionBox:Click() end
check(spLine and spLine:GetChecked() == false, "unticked in the options: unticked on the AddOns page too")
if spLine then spLine:Click() end
check(ns.sv.menu.line == true and sectionBox and sectionBox:GetChecked() == true, "ticked on the AddOns page: ticked in the options too")
SettingsPanel:Hide()
panel:Hide()

out("== the portrait's menu follows the options and back")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 1 and f.Click then f:Click() end end -- General: the overall opacity
-- the overall opacity slider of the General page: the one showing the HUD's opacity now
local optionsSlider
for _, f in ipairs(M.frames) do
  if f._kind == "Slider" and f:IsVisible() and f ~= line.slider.Slider and f._max == 100 and f._min == 0
    and math.floor(f:GetValue() + .5) == math.floor(db.alpha * 100 + .5) then optionsSlider = f end
end
check(optionsSlider ~= nil, "the General page shows the overall opacity (" .. math.floor(db.alpha * 100 + .5) .. ")")
menu = M.OpenUnitMenu("SELF")
line.slider:SetValue(30)
check(optionsSlider and math.floor(optionsSlider:GetValue() + .5) == 30, "the options' opacity slider shows the new value ("
  .. tostring(optionsSlider and optionsSlider:GetValue()) .. ")")
M.CloseUnitMenu()
panel:Hide()

out("== profiles: the hidden state is not a setting, the situations are")
ns:SaveProfile("ROGUE", "Solo")
ns:SetHidden(true)
check(not ns:ProfileModified("ROGUE"), "hiding the HUD does not change the profile")
local exported = ns:ExportProfile("ROGUE", "Solo")
ns:SetHidden(false)
ns:SetHideWhen("raid", true)
check(ns:ProfileModified("ROGUE"), "a situation ticked changes it")
ns:SetHidden(true)
ns:LoadProfile("ROGUE", "Solo")
check(db.hidden == true and db.hideWhen.raid == false, "loading keeps the HUD hidden, the situations come from the profile")
ns:SetHidden(false)
local decoded = type(exported) == "string" and ns.Deserialize(ns.Decode64(exported:sub(6)))
check(type(decoded) == "table" and type(decoded.data) == "table" and decoded.data.hidden == nil and decoded.data.hideWhen ~= nil,
  "an export has the situations, not the hidden state")

out("== a click on a list while its menu is open closes it")
ns:SaveProfile("ROGUE", "Raid")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 5 and f.Click then f:Click() end end -- Profiles
local list
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f.Refresh and f.text and f:IsVisible() and (f.text._text == "Raid" or f.text._text == "Solo") then list = f end
end
check(list ~= nil, "the profile list")
local opened = M.menusOpened or 0
M.Press(list)
check(M.menu and M.menu:IsShown() and M.menusOpened == opened + 1, "a click opens it")
local first = M.menu
M.Press(list)
check(not first:IsShown() and M.menu == nil and M.menusOpened == opened + 1, "a second click closes it, without opening it again")
M.Press(list)
check(M.menu and M.menu:IsShown() and M.menusOpened == opened + 2, "a third opens it again")
M.Press(panel)
check(M.menu == nil, "a click elsewhere closes it")
M.Press(list)
M.MenuPick("Solo")
check(M.menu == nil, "a pick closes it")
M.Press(list)
check(M.menu and M.menu:IsShown(), "and the next click opens it")
M.menu:Close()
panel:Hide()

out(("\n%d failure(s)"):format(fails))
return fails
