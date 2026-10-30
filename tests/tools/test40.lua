-- The game's settings kept for alts (AltSetup.lua) and the options window's header
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game: its console variables (account, character, computer), its Options window's settings,
-- the action bars 2 to 8, Edit Mode's layouts
local CV = {
  autoLootDefault = { value = "1", default = "0", account = true },
  raidFramesDisplayClassColor = { value = "1", default = "0", char = true },
  lockActionBars = { value = "1", default = "0", char = true },
  countdownForCooldowns = { value = "1", default = "0", char = true },
  secureThing = { value = "1", default = "0", char = true, secure = true },
  graphicsQuality = { value = "7", default = "3" },
  notInOptions = { value = "1", default = "0", char = true },
  someAddonVar = { value = "1", default = "0", char = true },
}
local sets = {}
C_CVar = {
  GetCVarInfo = function(name)
    local c = CV[name]
    if not c then return nil end
    return c.value, c.default, c.account or false, c.char or false, false, c.secure or false, false
  end,
  SetCVar = function(name, value) CV[name].value = tostring(value); sets[#sets + 1] = name end,
}
Settings.CategorySet = { Game = 1, AddOns = 2 }
local function Category(set) return { GetCategorySet = function() return set end } end
local game, addons = Category(1), Category(2)
local function Setting(var) return { GetVariable = function() return var end } end
SettingsPanel.settings = {
  [Setting("autoLootDefault")] = game, [Setting("raidFramesDisplayClassColor")] = game,
  [Setting("lockActionBars")] = game, [Setting("countdownForCooldowns")] = game, [Setting("secureThing")] = game,
  [Setting("graphicsQuality")] = game, [Setting("PROXY_SHOW_ACTIONBAR_2")] = game, [Setting("someAddonVar")] = addons,
}
local BARS = { true, true, false, false, false, false, false }
local barCalls = 0
function GetActionBarToggles() return unpack(BARS, 1, 7) end
function SetActionBarToggles(...) BARS = { ... }; barCalls = barCalls + 1 end
Enum.EditModeLayoutType = { Preset = 0, Account = 1, Character = 2, Server = 3 }
local function Layouts(active, withClara)
  local l = { { layoutType = 0, layoutName = "Modern" }, { layoutType = 0, layoutName = "Classic" } }
  if withClara ~= false then l[3] = { layoutType = 1, layoutName = "Clara" } end
  return { layouts = l, activeLayout = active }
end
EditModeManagerFrame = { layoutInfo = Layouts(3) }
C_EditMode = { SetActiveLayout = function(i) EditModeManagerFrame.layoutInfo.activeLayout = i end }
local LEVEL, GUID = 40, "Player-1"
function UnitLevel(u) return LEVEL end
function UnitGUID(u) if u == "player" then return GUID end end
local printed = {}
local realPrint = print
print = function(s) printed[#printed + 1] = tostring(s) end

local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3; S.energy = 100
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local L = ns.L
local alts = ns.sv.alts
check(type(alts) == "table" and next(alts.profiles) == nil and alts.default == nil, "no profile yet")
check(M.popup == nil and next(alts.done) == nil, "a login without a profile: nothing asked, nothing done")

-- the header
ns:ShowOptions(); M.Frame(0.016)
local p = _G.ClaraComboPointsOptions
local save, picker, box = p.altsSaveButton, p.altsPicker, p.altsText
check(save and picker and box, "the header: the button, the profiles list, the text box")
check(picker.text:GetText() == "None", "the list: None yet (" .. tostring(picker.text:GetText()) .. ")")
local function Geometry(width)
  local pos, grp = p.headerGroups[1], p.headerGroups[2]
  local top = p:GetTop()
  local ok = pos:GetRight() <= grp:GetLeft() and grp:GetRight() <= p:GetRight() - 8 and pos:GetLeft() >= p:GetLeft() + 56
  for _, f in ipairs({ p.lockButton, p.resetPosButton }) do
    ok = ok and f:GetLeft() >= pos:GetLeft() and f:GetRight() <= pos:GetRight()
  end
  for _, f in ipairs({ save, picker }) do
    ok = ok and f:GetLeft() >= grp:GetLeft() and f:GetRight() <= grp:GetRight()
    ok = ok and f:GetTop() <= grp:GetTop() and f:GetBottom() >= grp:GetBottom()
  end
  ok = ok and top - grp:GetTop() >= 22 and top - grp:GetBottom() <= 52
  return ok, ("%d..%d | %d..%d of %d"):format(pos:GetLeft() - p:GetLeft(), pos:GetRight() - p:GetLeft(),
    grp:GetLeft() - p:GetLeft(), grp:GetRight() - p:GetLeft(), p:GetWidth())
end
local ok, where = Geometry()
check(ok, "two framed groups side by side, their buttons inside, between the title and the tabs (" .. where .. ")")
check(save:GetWidth() >= save:GetFontString():GetStringWidth() + 16, "the button wide enough for its label")

-- saving this character's settings
save:Click(); M.Frame(0.016)
check(M.popup and M.popup.text:find("\"Default\"", 1, true) and M.popup.text:find("level 5", 1, true), "asked first, naming the profile")
M.PopupClick(1)
local d = alts.profiles.Default
check(d ~= nil and alts.default == "Default", "saved as Default, the alts' profile")
check(d.cvars.raidFramesDisplayClassColor == "1" and d.cvars.lockActionBars == "1" and d.cvars.countdownForCooldowns == "1",
  "the character's own options kept")
check(d.cvars.autoLootDefault == nil and d.cvars.graphicsQuality == nil, "the account's and the computer's left out (every character's already)")
check(d.cvars.secureThing == nil and d.cvars.notInOptions == nil and d.cvars.someAddonVar == nil and d.cvars.PROXY_SHOW_ACTIONBAR_2 == nil,
  "nor protected ones, ones outside the game's options, an addon's")
check(#d.bars == 7 and d.bars[1] and d.bars[2] and not d.bars[3], "the action bars shown")
check(d.layout and d.layout.kind == 1 and d.layout.name == "Clara", "the Edit Mode layout")
check(d.from == "Lola - Forever" and alts.done["Player-1"], "where from; this character done")
check(printed[#printed] and printed[#printed]:find("2 of 7 action bars shown, 3 game options", 1, true), "what it holds, in the chat: " .. tostring(printed[#printed]))
ns:RefreshOptions()
check(picker.text:GetText() == "Default", "the list shows it")

-- the list's menu
M.Press(picker); M.Frame(0.016)
local function Items()
  local t = {}
  for _, it in ipairs(M.menu and M.menu.items or {}) do t[#t + 1] = it.text or ("<" .. it.kind .. ">") end
  return table.concat(t, " | ")
end
check(Items() == 'Profile for new characters | Default | None | <divider> | New profile from this character... | Apply "Default" to this character | Export "Default"... | Import a profile... | Delete "Default"...',
  "its menu: " .. Items())

-- export and import
M.MenuPick('Export "Default"...')
local text = ns:ExportAltProfile("Default")
check(box:IsShown() and text and text:sub(1, 6) == "CCPA1:", "export: the text box, a line of text")
local ok2, name = ns:ImportAltProfile("  " .. text .. "\n")
check(ok2 and name == "Default (2)" and alts.default == "Default (2)", "imported under a free name, the alts' one now (" .. tostring(name) .. ")")
local i = alts.profiles["Default (2)"]
check(i and i.cvars.lockActionBars == "1" and i.bars[2] == true and i.layout.name == "Clara" and i.from == d.from, "the same settings")
check(not ns:ImportAltProfile("CCP1:abc") and select(2, ns:ImportAltProfile("nonsense")) == L.ALTS_IMPORT_BAD, "other text: refused")
check(not ns:ImportAltProfile(ns:ExportProfile("DRUID", next(ns.sv.saved.DRUID or {}) or "x") or "CCP1:x"), "a class tab's profile: refused")
M.Press(picker); M.Frame(0.016)
M.MenuPick("Import a profile...")
check(box:IsShown() and box.onAction, "import: the text box")
box.onAction(text)
check(not box:IsShown() and alts.profiles["Default (3)"] and alts.default == "Default (3)", "pasted and imported from the box")
M.Press(picker); M.Frame(0.016)
M.MenuPick('Delete "Default (3)"...')
M.PopupClick(1)
M.Press(picker); M.Frame(0.016)
M.MenuPick("Default (2)")
M.Press(picker); M.Frame(0.016)
M.MenuPick('Delete "Default (2)"...')
check(M.popup and M.popup.text:find("Default (2)", 1, true), "deleting asks first")
M.PopupClick(1)
check(alts.profiles["Default (2)"] == nil and alts.default == nil, "deleted; no alts' profile then")
ns:RefreshOptions()
check(picker.text:GetText() == "None", "the list: None")
M.Press(picker); M.Frame(0.016)
M.MenuPick("Default")
check(alts.default == "Default", "picked again from the list")

-- a new character: its first login
local function Fresh(guid, level)
  GUID, LEVEL = guid, level
  for _, c in pairs(CV) do c.value = c.default end
  BARS = { false, false, false, false, false, false, false }
  EditModeManagerFrame.layoutInfo.activeLayout = 1
  M.timers = {}
  M.popup = nil
end
Fresh("Player-2", 1)
CV.autoLootDefault.value = "0" -- (turned off on the account since the profile was saved)
ns:AltsAtLogin()
check(#M.timers == 1, "a new character: its settings a moment after login")
M.RunTimer()
check(CV.raidFramesDisplayClassColor.value == "1" and CV.lockActionBars.value == "1" and CV.countdownForCooldowns.value == "1",
  "its options set")
check(CV.autoLootDefault.value == "0", "the account's own left as it is now")
check(BARS[1] and BARS[2] and not BARS[3] and barCalls == 1, "its action bars")
check(EditModeManagerFrame.layoutInfo.activeLayout == 3, "its Edit Mode layout")
check(alts.done["Player-2"], "done")
M.RunTimer()
check(M.popup and M.popup.text:find("new character", 1, true) and M.popup.buttons[1] == "Reload UI" and M.popup.buttons[2] == "Later",
  "then: reload the interface?")
M.PopupClick(2)
Fresh("Player-2", 1)
ns:AltsAtLogin()
check(#M.timers == 0, "its next login: nothing again")
Fresh("Player-3", 30)
ns:AltsAtLogin()
check(#M.timers == 0 and not alts.done["Player-3"], "an older character: left alone")

-- in combat at login: once out of it
Fresh("Player-4", 1)
S.inCombat = true
ns:AltsAtLogin(); M.RunTimer()
check(CV.lockActionBars.value == "0" and not alts.done["Player-4"], "in combat: waiting")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED"); M.RunTimer()
check(CV.lockActionBars.value == "1" and alts.done["Player-4"], "out of combat: set")

-- Edit Mode not ready yet: once it is
Fresh("Player-5", 1)
local layouts = EditModeManagerFrame.layoutInfo
EditModeManagerFrame.layoutInfo = nil
ns:AltsAtLogin(); M.RunTimer()
check(CV.lockActionBars.value == "0", "Edit Mode not ready: waiting")
EditModeManagerFrame.layoutInfo = layouts
M.Fire("EDIT_MODE_LAYOUTS_UPDATED"); M.RunTimer()
check(CV.lockActionBars.value == "1" and EditModeManagerFrame.layoutInfo.activeLayout == 3, "ready: set, layout too")

-- a layout this character has not got
Fresh("Player-6", 1)
EditModeManagerFrame.layoutInfo = Layouts(1, false)
ns:AltsAtLogin(); M.RunTimer(); M.RunTimer()
check(EditModeManagerFrame.layoutInfo.activeLayout == 1 and M.popup and M.popup.text:find('"Clara" is not on this character', 1, true),
  "a layout not there: kept as it is, and said")
M.PopupClick(2)
EditModeManagerFrame.layoutInfo = Layouts(3)

-- applied by hand, from the list
Fresh("Player-7", 50)
M.Press(picker); M.Frame(0.016)
M.MenuPick('Apply "Default" to this character')
check(M.popup and M.popup.text:find("Apply the profile", 1, true), "applying asks first")
M.PopupClick(1); M.RunTimer()
check(CV.lockActionBars.value == "1" and alts.done["Player-7"] and M.popup and M.popup.text:find("was applied", 1, true), "applied, then reload?")
M.PopupClick(2)

-- a new profile from the list, named
GUID = "Player-1"
M.Press(picker); M.Frame(0.016)
M.MenuPick("New profile from this character...")
check(M.popup and M.popup.info.hasEditBox, "a name asked")
M.popup.editBox = { GetText = function() return "  Raid setup  " end }
M.PopupClick(1)
check(alts.profiles["Raid setup"] and alts.default == "Raid setup", "made, the alts' one")
M.Press(picker); M.Frame(0.016)
M.MenuPick("New profile from this character...")
M.popup.editBox = { GetText = function() return "Raid setup" end }
M.PopupClick(1); M.RunTimer()
check(M.popup and M.popup.text:find("already exists", 1, true), "a name taken: replace it?")
M.PopupClick(1)
check(ns:AltProfileName(("é"):rep(40)) == ("é"):rep(32) and ns:AltProfileName("   ") == nil, "names: 32 letters at most, accents whole; blank: none")

-- saved data checked
local sv = { alts = { profiles = { ok = { cvars = { a = "1", b = 2 }, bars = { true, "x" }, layout = { kind = "1" } }, [5] = {} },
  done = { x = true, y = 1 }, default = "gone" } }
ns:InitAlts(sv)
local c = sv.alts.profiles.ok
check(c and c.cvars.a == "1" and c.cvars.b == nil and #c.bars == 1 and c.layout == nil and sv.alts.profiles[5] == nil
  and sv.alts.done.x and sv.alts.done.y == nil and sv.alts.default == nil, "broken saved data cleaned")

-- a narrow window, and the other languages
ns.sv.window.w = 640; p:Resize()
ok, where = Geometry()
check(ok, "a narrow window: the header still fits (" .. where .. ")")
ns.sv.window.w = nil; p:Resize()
for _, lang in ipairs({ "frFR", "deDE" }) do
  ns:SetLanguage(lang); M.Frame(0.016)
  ok, where = Geometry()
  check(ok and save:GetWidth() >= save:GetFontString():GetStringWidth() + 16, lang .. ": fits, its label whole (" .. where .. ")")
end
print = realPrint
out("")
out(fails .. " failure(s)")
