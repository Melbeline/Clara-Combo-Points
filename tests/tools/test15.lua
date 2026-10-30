-- profiles (save, load, delete, export, import, unsaved-changes questions), the options window
-- (scale grip, off the screen, opacity, reset pos), countdown size, full reset, and the page
-- in the game's options
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
local function findText(pattern)
  for _, r in ipairs(M.regions) do
    if r._kind == "FontString" and r._text and r._parent:IsVisible() and tostring(r._text):find(pattern, 1, true) then return r end
  end
end
-- a page of the list on the left (1 General, 2 Bars, 3 Icons, 4 Visibility, 5 Profiles)
local function goPage(n)
  for _, f in ipairs(M.frames) do if f.page == n then f:Click() end end
end
local function Same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- saved variables from before, some of them damaged
ClaraComboPointsDB = {
  saved = {
    DRUID = {
      Raid = { fontSize = 30, junk = 5, colors = { cp1 = { r = 9, g = 0, b = 0, a = 1 } },
        rows = { above = { { 774, "Renew", { spell = -3 }, { spell = 8921, on = "enemy" } } } } },
      [42] = { fontSize = 20 },
      ["  |cffff0000Bad|r  "] = { scale = 2 },
      Broken = "not a table",
    },
    DEATHKNIGHT = { X = {} },
  },
  active = { DRUID = "Raid", ROGUE = "Nope", DEATHKNIGHT = "X" },
  window = { left = "x", top = 3, scale = 9, alpha = 0, extra = true },
}

local ns = {}
S.class = "DRUID"; S.locale = "frFR"; S.powerType = 3
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local sv = ClaraComboPointsDB
local L = ns.L

out("== text form of a table")
local t = { a = 1, b = "x|y\n", c = { 1, 2, { d = true, e = false } }, [5] = .808, f = -1e-7, g = 2 ^ 40, h = "", i = 1 / 3 }
local text = ns.Serialize(t)
local back = ns.Deserialize(text)
check(Same(back, t), "read back exactly (numbers, strings with | and newlines, nested tables, booleans)")
check(ns.Serialize(back) == text, "the same table always gives the same text")
check(ns.Deserialize(text:sub(1, -2)) == nil and ns.Deserialize(text .. "T") == nil, "cut short or with more after it: refused")
check(ns.Deserialize("N1e999;") == nil and ns.Deserialize("Nnan;") == nil and ns.Deserialize("Ninf;") == nil and ns.Deserialize("N0x10;") == nil,
  "infinite, not-a-number and hexadecimal numbers refused")
check(ns.Deserialize("S5:abc") == nil and ns.Deserialize("{S1:aT") == nil and ns.Deserialize("{TT}") == nil and ns.Deserialize("") == nil
  and ns.Deserialize("X") == nil, "broken strings, tables and keys refused")
check(ns.Deserialize(("{S1:a"):rep(9) .. "T" .. ("}"):rep(9)) == nil and ns.Deserialize(("{S1:a"):rep(8) .. "T" .. ("}"):rep(8)) ~= nil,
  "no more than 8 tables within each other")
local bytes = {}
for i = 0, 255 do bytes[#bytes + 1] = string.char(i) end
local all = table.concat(bytes)
local okB64 = true
for n = 0, 6 do if ns.Decode64(ns.Encode64(all:sub(1, #all - n))) ~= all:sub(1, #all - n) then okB64 = false end end
check(okB64, "base64: every byte, every length, read back")
check(ns.Encode64("Man") == "TWFu" and ns.Encode64("Ma") == "TWE=" and ns.Encode64("M") == "TQ==", "base64: the standard alphabet and padding")
check(ns.Decode64("TWF") == nil and ns.Decode64("TW=u") == nil and ns.Decode64("T@Fu") == nil and ns.Decode64("TQ==TWFu") == nil,
  "base64: wrong length, padding inside, foreign characters refused")

out("== profiles kept in the saved variables")
check(sv.saved.DEATHKNIGHT == nil and sv.active.DEATHKNIGHT == nil, "no profiles for a class the addon does not have")
local raid = sv.saved.DRUID.Raid
check(raid and raid.fontSize == 30 and raid.junk == nil and raid.locked == nil, "a profile keeps its settings, nothing unknown, no lock")
check(raid.colors.cp1.r == 1 and raid.colors.cp2 and raid.icons and raid.icons.timerSize == 100, "colours checked, missing settings filled in")
check(Same(raid.rows.above[1], { 774, "Renew", { spell = 8921, on = "enemy" } }) and #raid.rows.below == 3, "icon rows checked")
check(sv.saved.DRUID.Bad and sv.saved.DRUID[42] == nil and sv.saved.DRUID.Broken == nil, "names cleaned of colour codes; broken entries dropped")
check(sv.active.DRUID == "Raid" and sv.active.ROGUE == nil, "the loaded profile is kept only if it still exists")
check(sv.window.left == nil and sv.window.top == nil and sv.window.scale == nil and sv.window.alpha == 1 and sv.window.extra == nil,
  "window settings checked (bad place, scale and opacity back to the defaults)")

out("== save, load, delete")
local names = ns:ProfileNames("DRUID")
check(#names == 2 and names[1] == "Bad" and names[2] == "Raid", "list in alphabetical order")
check(ns:ActiveProfile("DRUID") == "Raid" and ns:ProfileModified("DRUID"), "Raid loaded on the tab, settings changed since")
local ok, msg = ns:SaveProfile("DRUID", "  Solo  ")
check(ok and msg == "Profil « Solo » enregistré." and ns:ActiveProfile("DRUID") == "Solo" and not ns:ProfileModified("DRUID"), "saved under a name: loaded, not changed")
ns:SetLocked(false)
check(not ns:ProfileModified("DRUID"), "the lock is not part of a profile")
ns:SetLocked(true)
ns.db.fontSize = 21
check(ns:ProfileModified("DRUID"), "a setting changed: the profile is marked as changed")
local db = ns.db
ns:SetLocked(false)
ok = ns:LoadProfile("DRUID", "Raid")
check(ok and ns.db == db and sv.profiles.DRUID == db and db.fontSize == 30 and not db.locked, "loaded in place (same table), its lock kept")
check(ns:ActiveProfile("DRUID") == "Raid" and not ns:ProfileModified("DRUID"), "Raid now loaded, unchanged")
db.colors.cp1.r = .5
check(sv.saved.DRUID.Raid.colors.cp1.r == 1, "the saved profile is a copy: a change on the tab does not touch it")
ns:SetLocked(true)
ok, msg = ns:DeleteProfile("DRUID", "Raid")
check(ok and sv.saved.DRUID.Raid == nil and ns:ActiveProfile("DRUID") == nil, "deleted: gone, no profile loaded")
check(ns:SaveProfile("DRUID", "") == false and ns:SaveProfile("DRUID", "|cff00ff00|r") == false, "no name, no profile")
local long = ("É"):rep(40)
ns:SaveProfile("DRUID", long)
local kept = ns:ActiveProfile("DRUID")
check(kept == ("É"):rep(32), "names cut at 32 letters, whole letters only")

out("== export, import")
local exported = ns:ExportProfile("DRUID", "Solo")
check(exported:sub(1, 5) == "CCP1:" and not exported:sub(6):find("[^%w%+/=]"), "one line of letters, digits, + / =")
out("     export length: " .. #exported)
ok, msg = ns:ImportProfile("ROGUE", exported)
check(ok and msg == "Solo" and Same(sv.saved.ROGUE.Solo, sv.saved.DRUID.Solo), "imported on another tab, the same settings")
ok, msg = ns:ImportProfile("ROGUE", "  " .. exported:sub(1, 40) .. "\n" .. exported:sub(41) .. "\n")
check(ok and msg == "Solo (2)", "pasted with spaces and line breaks; the name taken: numbered")
check(select(2, ns:ImportProfile("ROGUE", "hello")) == L.IMPORT_BAD and ns:ImportProfile("ROGUE", exported:sub(1, -5)) == false
  and ns:ImportProfile("ROGUE", "CCP1:" .. ns.Encode64("{S1:vN2;}")) == false and ns:ImportProfile("ROGUE", nil) == false,
  "not a profile, cut short, wrong version, nothing: refused")
-- a crafted line: wrong kinds, huge numbers, too many icons, code-looking text
local rows = {}
for i = 1, 50 do rows[i] = 774 end
local crafted = "CCP1:" .. ns.Encode64(ns.Serialize({ v = 1, name = "|TInterface\\Icons\\X:0|tEvil" .. ("x"):rep(50), data = {
  fontSize = "big", scale = 1e9, alpha = -3, x = 1e12, font = ("f"):rep(200), outline = "os.exit()",
  colors = { cp1 = { r = -1, g = 2, b = "x", a = .5 }, hack = { r = 1 } }, icons = { size = 1000, shape = "ROUND", timerSize = 5 },
  rows = { above = { rows, "x", { { spell = 1e300 }, { spell = "Renew", on = "nowhere", exact = "yes" } } } },
  locked = false, preview = true,
} }))
ok, msg = ns:ImportProfile("ROGUE", crafted)
local c = ok and sv.saved.ROGUE[msg]
check(ok and msg == "Evil" .. ("x"):rep(28), "a crafted line imports, its name cleaned and cut")
check(c and c.fontSize == 17 and c.scale == 1 and c.alpha == 1 and c.x == 0 and c.font == "Arial Narrow" and c.outline == "OUTLINE",
  "wrong kinds and out-of-range values back to the defaults")
check(c and c.colors.cp1.r == 1 and c.colors.cp1.g == 1 and c.colors.cp1.a == .5 and c.colors.hack == nil, "colours checked one by one")
check(c and c.icons.size == 55 and c.icons.shape == "SQUARE" and c.icons.timerSize == 100, "icon look checked")
check(c and #c.rows.above[1] == 20 and #c.rows.above[2] == 0 and Same(c.rows.above[3], { { spell = "Renew", on = "auto" } }),
  "rows: at most 20 icons, broken entries dropped")
check(c and c.locked == nil and c.preview == nil, "no lock, nothing unknown")

out("== profiles page")
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
check(panel:IsShown() and not findButton("Charger"), "opened on the General page: the profile buttons not shown")
local profNav
for _, f in ipairs(M.frames) do if f.page == 5 then profNav = f end end
check(profNav and profNav:IsVisible() and profNav.name._text == "Profils", "Profils in the list of pages")
goPage(5)
check(panel:IsShown() and findButton("Charger") and findButton("Supprimer") and findButton("Enregistrer") and findButton("Exporter") and findButton("Importer"),
  "Load, Delete, Save, Export and Import on the Profiles page")
local nameBox
for _, f in ipairs(M.frames) do if f._kind == "EditBox" and f._maxLetters == 32 and f:IsVisible() then nameBox = f end end
check(nameBox and nameBox:GetText() == kept, "the name box shows the loaded profile")
check(findText("Profil chargé : " .. kept), "the loaded profile is named")
nameBox:SetText("Test")
findButton("Enregistrer"):Click()
check(sv.saved.DRUID.Test and ns:ActiveProfile("DRUID") == "Test" and findText("Profil « Test » enregistré."), "typed a name, Save: saved and loaded")
local list = findButton("Test")
check(list, "the list shows it")
list:Click(); M.MenuPick("Solo")
check(findButton("Solo"), "another profile picked in the list")
ns.db.fontSize = 22; ns:RefreshOptions()
check(findText("(modifié, non enregistré)"), "a change: marked as not saved")
findButton("Charger"):Click()
check(M.popup and M.popup.text == "Le profil « Test » a des modifications non enregistrées. Les enregistrer avant de charger « Solo » ?"
  and M.popup.buttons[1] == "Enregistrer" and M.popup.buttons[2] == "Ne pas enregistrer" and M.popup.buttons[3] == "Annuler",
  "Load with changes not saved: asks first (Save / Don't save / Cancel)")
M.PopupClick(3)
check(ns.db.fontSize == 22 and ns:ActiveProfile("DRUID") == "Test", "Cancel: nothing changes")
findButton("Charger"):Click(); M.PopupEscape()
check(ns.db.fontSize == 22 and ns:ActiveProfile("DRUID") == "Test", "Escape: nothing changes")
findButton("Charger"):Click(); M.PopupClick(2)
check(ns.db.fontSize == sv.saved.DRUID.Solo.fontSize and ns:ActiveProfile("DRUID") == "Solo" and sv.saved.DRUID.Test.fontSize ~= 22,
  "Don't save: Solo loaded, Test as it was saved")
ns.db.fontSize = 23; ns:RefreshOptions()
findButton("Solo"):Click(); M.MenuPick("Test")
findButton("Charger"):Click(); M.PopupClick(1)
check(sv.saved.DRUID.Solo.fontSize == 23 and ns:ActiveProfile("DRUID") == "Test" and ns.db.fontSize == sv.saved.DRUID.Test.fontSize,
  "Save: Solo saved with the change, then Test loaded")
ns.db.fontSize = 24; ns:RefreshOptions()
findButton("Charger"):Click()
check(M.popup and M.popup.buttons[1] == "Recharger" and M.popup.buttons[2] == "Annuler" and M.popup.buttons[3] == nil,
  "Load the same profile with changes: asks to go back to the saved version")
M.PopupClick(1)
check(ns.db.fontSize ~= 24 and not ns:ProfileModified("DRUID"), "back to the saved version")
findButton("Supprimer"):Click()
check(M.popup and M.popup.text == "Supprimer le profil « Test » ? C'est définitif." and M.popup.info.showAlert, "Delete asks first, with a warning")
M.PopupClick(1)
check(sv.saved.DRUID.Test == nil and ns:ActiveProfile("DRUID") == nil and findText("Profil « Test » supprimé."), "deleted")
ns.db.fontSize = 25; ns:RefreshOptions()
check(findText("Aucun profil chargé sur cet onglet."), "no profile loaded")
findButton("Bad"):Click(); M.MenuPick("Solo")
findButton("Charger"):Click()
check(M.popup and M.popup.text:find("ne sont enregistrés dans aucun profil", 1, true) and M.popup.buttons[1] == "Charger",
  "settings in no profile: a word before they are replaced")
M.PopupClick(2)
check(ns.db.fontSize == 25, "cancelled: kept")
nameBox:SetText("Solo")
findButton("Enregistrer"):Click()
check(M.popup and M.popup.text == "Un profil « Solo » existe déjà. Le remplacer par les réglages actuels ?", "saving over another profile asks first")
M.PopupClick(1)
check(sv.saved.DRUID.Solo.fontSize == 25 and ns:ActiveProfile("DRUID") == "Solo", "replaced")

out("== export / import box")
findButton("Exporter"):Click()
local edit
for _, f in ipairs(M.frames) do if f._kind == "EditBox" and f._multi and f:IsVisible() then edit = f end end
check(edit and edit:GetText() == ns:ExportProfile("DRUID", "Solo") and edit._highlighted and edit:HasFocus(), "export shown, selected, ready for Ctrl+C")
check(findText("Exporter : Solo"), "titled with the profile's name")
M.Type(edit, "oops")
check(edit:GetText() == ns:ExportProfile("DRUID", "Solo"), "the export cannot be typed over")
findButton("Fermer"):Click()
check(not edit:IsVisible(), "closed")
findButton("Importer"):Click()
check(edit:IsVisible() and edit:GetText() == "" and findText("Importer un profil (Druide)"), "import: an empty box for this tab")
M.Type(edit, "pas un profil")
local importBtn -- the box's own Import button (not the Profiles page's)
for _, f in ipairs(M.frames) do
  if f._kind == "Button" and f:IsVisible() and label(f) == "Importer" and f:GetParent() and f:GetParent()._template == "DefaultPanelTemplate" then importBtn = f end
end
importBtn:Click()
check(edit:IsVisible() and findText(L.IMPORT_BAD), "a wrong text: said in the box, the box stays")
M.Type(edit, ns:ExportProfile("ROGUE", "Solo"))
importBtn:Click()
check(not edit:IsVisible() and sv.saved.DRUID["Solo (2)"] and findText("Profil « Solo (2) » importé"), "imported: added to this tab's list, picked")
check(findButton("Solo (2)"), "the list shows the imported profile")
findButton("Importer"):Click()
for _, f in ipairs(M.frames) do if f.class == "WARRIOR" then f:Click() end end
check(not edit:IsVisible(), "another tab: the box closes")
check(findText("Aucun profil") and not findButton("Charger"):IsEnabled() and not findButton("Exporter"):IsEnabled(),
  "a tab without profiles: an empty list, nothing to load or export")
for _, f in ipairs(M.frames) do if f.class == "DRUID" then f:Click() end end

out("== window opacity, scale grip, off the screen")
local opacity
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f:GetParent() == panel then opacity = f end end
check(findText("Opacité des fenêtres") and opacity, "a window opacity slider, with its label")
local function absBox(r) M.ResetLayout(); local l, b, w, h = M.AbsRect(r); return l, b, l + w, b + h end
do
  local pl, pb, pr = absBox(panel)
  local es = panel:GetEffectiveScale()
  local ol, ob, orr, ot = absBox(opacity)
  local _, _, rightmost = absBox(opacity.unit or opacity.box.holder)
  local ll, _, lr = absBox(findText("Opacité des fenêtres"))
  local _, _, cr = absBox(findText("/cl reset pos"))
  local gripF
  for _, f in ipairs(M.frames) do if f._normalTex and tostring(f._normalTex):find("SizeGrabber%-Up") and f:GetParent() == ClaraComboPointsOptions then gripF = f end end
  local gl = absBox(gripF)
  check(ob - pb < 40 * es and ol > (pl + pr) / 2 and lr <= ol and ll > cr and rightmost <= pr,
    "window opacity in the footer, bottom right: its label left of it, after the commands")
  check(rightmost < gl, string.format("the slider, its box and %% clear of the scale grip (%.0f < %.0f)", rightmost, gl))
end
opacity:SetValue(60)
check(near(panel._alpha, .6) and near(sv.window.alpha, .6), "opacity 60 %: the window (and all in it)")
panel:Hide(); SlashCmdList.CLARACOMBOPOINTS("")
check(near(panel._alpha, .6), "kept when the window opens again")
local grip
for _, f in ipairs(M.frames) do if f._normalTex and tostring(f._normalTex):find("SizeGrabber%-Up") and f:GetParent() == ClaraComboPointsOptions then grip = f end end
check(grip and grip:IsVisible(), "a size grip in the bottom right corner")
local function corner()
  M.ResetLayout()
  local s = panel:GetScale()
  return panel:GetLeft() * s, panel:GetTop() * s, s
end
local left0, top0, s0 = corner()
local ui = UIParent:GetEffectiveScale()
M.CursorOn(grip)
M.mouseDown = true
grip._scripts.OnMouseDown(grip, "RightButton")
check(near(panel:GetScale(), s0), "held: no jump")
-- drag the corner to make the window 25 % bigger (the window is 888 x 720)
local pw, ph = panel:GetWidth(), panel:GetHeight()
check(near(pw, 910) and near(ph, 720), "the window: 910 x 720 (" .. pw .. " x " .. ph .. ")")
M.cursorX = M.cursorX + pw * s0 * .25 * ui
M.cursorY = M.cursorY - ph * s0 * .25 * ui
M.Frame(0.016)
local left1, top1, s1 = corner()
check(near(s1, s0 * 1.25, .005) and near(left1, left0, .5) and near(top1, top0, .5), "dragged: 25 % bigger, the top left corner in place ("
  .. string.format("%.3f -> %.3f", s0, s1) .. ")")
check(findText(math.floor(s1 * 100 + .5) .. " %"), "the size shown while dragging")
M.cursorX = M.cursorX + 100000
M.Frame(0.016)
check(near(panel:GetScale(), 2), "at most 200 %")
M.cursorX, M.cursorY = -100000, 100000
M.Frame(0.016)
check(near(panel:GetScale(), .4), "at least 40 %")
M.CursorOn(grip)
M.cursorX = M.cursorX + 1
M.Frame(0.016)
M.mouseDown = false
M.Frame(0.016)
local left2, top2, s2 = corner()
check(near(sv.window.scale, s2) and near(sv.window.left, left2, .5) and near(sv.window.top, top2, .5), "let go: scale and place kept")
panel:Hide(); SlashCmdList.CLARACOMBOPOINTS("")
local left3, top3, s3 = corner()
check(near(s3, s2) and near(left3, left2, .5) and near(top3, top2, .5), "the window opens again where it was, at its size")
check(panel._clamped == false, "not held on the screen")
-- dragged off the screen
panel._scripts.OnDragStart(panel)
panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -5000, 100)
panel._scripts.OnDragStop(panel)
check(near(sv.window.left, -5000 * panel:GetScale(), 1), "dragged off the screen: kept there")
goPage(3)
M.ResetLayout()
check(near(panel:GetLeft() * panel:GetScale(), -5000 * panel:GetScale(), 1), "the spells panel does not pull it back")
goPage(1)
local logged = #M.log
SlashCmdList.CLARACOMBOPOINTS("RESET  POS")
check(#M.log == logged and sv.window.left == nil, "/cl reset pos (nothing in the chat)")
M.ResetLayout()
local cx, cy = panel:GetCenter()
local ux, uy = UIParent:GetCenter()
local ps = panel:GetScale()
check(near(cx * ps, ux, 1) and near(cy * ps, uy, 1), "the window back in the middle of the screen")

out("== countdown size on the icons")
goPage(3)
check(findText("Temps sur les icônes") and findText("Apparence des icônes"), "on the Icons page, in the icon look group")
ns.db.rows.above[1] = { 774 }
ns:LayoutIcons(); M.Frame(0.016)
local slot
for _, f in ipairs(M.frames) do if f.cd and f.spell == 774 then slot = f end end
local timer
for _, f in ipairs(M.frames) do
  if f._kind == "Slider" and f:IsVisible() and f._min == 50 and f._max == 200 then timer = f end
end
local function cdSize(cd) return select(2, cd:GetCountdownFontString():GetFont()) end
local base = cdSize(slot.cd)
timer:SetValue(150)
local aura
for _, f in ipairs(M.frames) do if f._auraButton and f._points and f._points[1] and f._points[1][2] == slot then aura = f end end
check(ns.db.icons.timerSize == 150 and cdSize(slot.cd) == math.floor(base * 1.5), "150 %: the icon's countdown (" .. base .. " -> " .. cdSize(slot.cd) .. ")")
check(aura and cdSize(aura._cd) == cdSize(slot.cd), "the game's aura button too")
timer:SetValue(50)
check(cdSize(slot.cd) == math.max(6, math.floor(base * .5)), "50 %")
timer:SetValue(100)
check(cdSize(slot.cd) == base, "100 %: as before")

out("== /cl reset: everything, once confirmed")
ns.sv.profiles.WARRIOR.fontSize = 33
ns.db.colors.cp1.r = .1
SlashCmdList.CLARACOMBOPOINTS("reset")
check(M.popup and M.popup.info.showAlert and M.popup.text:find("Tous tes réglages seront supprimés", 1, true)
  and M.popup.buttons[1] == "Réinitialiser" and M.popup.buttons[2] == "Annuler", "asks first, warning that all settings go")
M.PopupEscape()
check(ns.sv.profiles.WARRIOR.fontSize == 33, "Escape: nothing reset")
SlashCmdList.CLARACOMBOPOINTS("reset"); M.PopupClick(2)
check(ns.sv.profiles.WARRIOR.fontSize == 33, "Cancel: nothing reset")
local savedBefore = ns.Serialize(sv.saved)
db = ns.db
SlashCmdList.CLARACOMBOPOINTS("reset"); M.PopupClick(1)
check(ns.sv.profiles.WARRIOR.fontSize == 17 and ns.db.colors.cp1.r == 1 and ns.db == db and #ns.sv.profiles.WARRIOR.rows.above[1] == 5,
  "every tab back to its defaults (warrior icons too)")
check(ns.Serialize(sv.saved) == savedBefore and next(sv.active) == nil, "saved profiles kept; none loaded any more")
check(sv.window.alpha == 1 and sv.window.scale == nil and near(panel._alpha, 1), "window opaque, at the size that fits")
check(not (M.log[#M.log] or ""):find("tous les réglages sont revenus par défaut", 1, true), "nothing said in the chat")

out("== lock everything")
ns.sv.profiles.WARRIOR.locked = false
ns:SetLocked(false)
check(not ns:AllLocked(), "two bars unlocked")
ns:LockAll()
check(ns:AllLocked() and ns.db.locked, "all locked")

out("== page in the game's options")
panel:Hide()
local cat = M.settingsCategories[1]
check(cat and cat.name == " Clara", "registered in the AddOns list (a space first: first of the list)")
M.ShowSettingsPage(cat)
check(findButton("Replacer la fenêtre d'options") and findButton("Ouvrir les options (/cl)") and findButton("Déverrouiller la barre")
  and findButton("Réinitialiser l'addon..."), "buttons: window back, open, unlock (all locked), reset")
check(findText("Comment ça marche") and findText("Ce que fait l'addon"), "how the addon works")
sv.window.left, sv.window.top = -9000, 50
findButton("Replacer la fenêtre d'options"):Click()
check(sv.window.left == nil and not (M.log[#M.log] or ""):find("replacée au milieu", 1, true), "window back in the middle (nothing in the chat)")
ns:SetLocked(false); ns:RefreshSettingsPage()
findButton("Tout verrouiller"):Click()
check(ns:AllLocked() and findButton("Déverrouiller la barre"), "lock everything, then the button unlocks")
findButton("Déverrouiller la barre"):Click()
check(not ns.db.locked and findButton("Tout verrouiller"), "unlocked")
local size
for _, f in ipairs(M.frames) do if f._kind == "Slider" and f:IsVisible() and f._min == 40 and f._max == 200 then size = f end end
size:SetValue(150)
check(near(sv.window.scale, 1.5), "window size 150 %")
SlashCmdList.CLARACOMBOPOINTS("")
check(near(panel:GetScale(), 1.5), "the window opens at that size")
panel:Hide()
findButton("Taille par défaut"):Click()
check(sv.window.scale == nil, "default size: fits the screen again")
findButton("Réinitialiser l'addon..."):Click()
check(M.popup and M.popup.text:find("Tous tes réglages", 1, true), "reset asks first")
M.PopupClick(2)
findButton("Ouvrir les options (/cl)"):Click()
check(not SettingsPanel:IsShown() and SettingsPanel._closedWithSkip == true and panel:IsShown(), "open the options: the game's options close, the window opens")
panel:Hide()
M.ShowSettingsPage(cat)
S.inCombat = true
findButton("Ouvrir les options (/cl)"):Click()
check(SettingsPanel:IsShown() and panel:IsShown(), "in combat the game's options stay (the game would refuse), the window opens anyway")
S.inCombat = false
panel:Hide(); SettingsPanel:Hide()
ns:SetLanguage("enUS")
M.ShowSettingsPage(cat)
check(findButton("Bring the options window back") and findText("What the addon does"), "in the addon's language")

out(string.format("\n%d failure(s)", fails))
return fails
