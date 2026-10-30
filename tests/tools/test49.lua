-- tullaRange built in (Modules/TullaRange): action and pet button icons colored out of range, out of
-- mana, unusable; each state's box; the game's look back when off; its page in the game's options
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 0.001 end
local function color(icon, r, g, b, a)
  local vc = icon._vc
  return vc ~= nil and near(vc[1], r) and near(vc[2], g) and near(vc[3], b) and near(vc[4], a)
end
local function vc(icon) local v = icon._vc; return v and table.concat(v, ",") or "nil" end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false } }

-- the game's action buttons (ActionBarActionButtonMixin), their slots, the pet bar
local SLOTS = {
  [1] = { usable = true, noMana = false },
  [2] = { usable = false, noMana = true },
  [3] = { usable = false, noMana = false },
}
C_ActionBar = {
  HasAction = function(a) return SLOTS[a] ~= nil end,
  IsUsableAction = function(a) local s = SLOTS[a]; return s.usable, s.noMana end,
  IsActionInRange = function(a) return SLOTS[a].range end,
}
local function GameButton(action)
  local b = CreateFrame("CheckButton", nil, UIParent)
  b.action = action
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.HotKey = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  function b:UpdateUsable()
    local usable, noMana = C_ActionBar.IsUsableAction(self.action)
    if usable then self.icon:SetVertexColor(1, 1, 1)
    elseif noMana then self.icon:SetVertexColor(0.5, 0.5, 1)
    else self.icon:SetVertexColor(0.4, 0.4, 0.4) end
  end
  b:UpdateUsable()
  return b
end
ActionBarButtonEventsFrame = { frames = {} }
function ActionBarButtonEventsFrame:RegisterFrame(f) table.insert(self.frames, f) end
local b1, b2, b3 = GameButton(1), GameButton(2), GameButton(3)
for _, b in ipairs({ b1, b2, b3 }) do ActionBarButtonEventsFrame:RegisterFrame(b) end
function ActionButton_UpdateRangeIndicator(self, checksRange, inRange) self.HotKey._red = checksRange and not inRange end
local function Range(b, inRange) -- ACTION_RANGE_CHECK_UPDATE for its slot
  SLOTS[b.action].range = inRange
  ActionButton_UpdateRangeIndicator(b, inRange ~= nil, inRange == true)
end

NUM_PET_ACTION_SLOTS = 2
local PET = { [1] = { usable = true, range = true }, [2] = { usable = true, range = true } }
function GetPetActionInfo(id) local p = PET[id]; return "Bite", "icon", false, false, false, false, 17253, true, p.range end
function GetPetActionSlotUsable(id) return PET[id].usable end
C_Spell = C_Spell or {}
C_Spell.IsSpellUsable = function() return true, false end
local function PetButton(id)
  local b = CreateFrame("CheckButton", nil, UIParent)
  b:SetID(id)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.HotKey = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  function b:UpdateButtonState() self.icon:SetVertexColor(1, 1, 1) end
  return b
end
PetActionBar = { actionButtons = { PetButton(1), PetButton(2) } }

local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

check(ns:QolRuns("tullarange") and ns.TullaRange ~= nil, "the module runs in WoW Forever")
check(color(b1.icon, 1, 1, 1, 1) and not b1.icon._desat, "usable, in range: the game's look (" .. vc(b1.icon) .. ")")
Range(b1, false)
check(color(b1.icon, 1, 0.3, 0.1, 0.75) and b1.icon._desat == true, "out of range: red, 75 %, desaturated (" .. vc(b1.icon) .. ")")
b1:UpdateUsable()
check(color(b1.icon, 1, 0.3, 0.1, 0.75), "the game paints it again: red again (" .. vc(b1.icon) .. ")")
Range(b1, true)
check(color(b1.icon, 1, 1, 1, 1) and b1.icon._desat == false, "back in range: the game's look, not desaturated (" .. vc(b1.icon) .. ")")
Range(b1, nil)
check(color(b1.icon, 1, 1, 1, 1), "no target: as is")

check(color(b2.icon, 0.5, 0.5, 1, 1) and not b2.icon._desat, "out of mana, off by default: the game's blue (" .. vc(b2.icon) .. ")")
Range(b2, false)
check(color(b2.icon, 1, 0.3, 0.1, 0.75), "out of mana and out of range: red (" .. vc(b2.icon) .. ")")
local switches = ns.qolSwitches.tullarange
check(switches and #switches == 3, "three boxes on its page of the Improvements tab")
check(switches[1].get() == true and switches[2].get() == false and switches[3].get() == true, "out of range and unusable on, out of mana off")
switches[2].set(true)
check(color(b2.icon, 0.1, 0.3, 1, 1) and b2.icon._desat == true, "out of mana turned on: tullaRange's blue (" .. vc(b2.icon) .. ")")
switches[2].set(false)
check(color(b2.icon, 1, 0.3, 0.1, 0.75), "off again: out of range shows (" .. vc(b2.icon) .. ")")
Range(b2, true)
check(color(b2.icon, 0.5, 0.5, 1, 1) and b2.icon._desat == false, "in range: the game's blue back (" .. vc(b2.icon) .. ")")

check(color(b3.icon, 0.4, 0.4, 0.4, 1), "unusable: grey")
ClaraTullaRangeDB.unusable[1] = 0.8
ns.TullaRange.Refresh()
check(color(b3.icon, 0.8, 0.4, 0.4, 1), "its color changed: painted again (" .. vc(b3.icon) .. ")")
switches[3].set(false)
check(color(b3.icon, 0.4, 0.4, 0.4, 1), "unusable off: the game's grey (" .. vc(b3.icon) .. ")")
switches[3].set(true)

Range(b1, false)
switches[1].set(false)
check(color(b1.icon, 1, 1, 1, 1) and b1.icon._desat == false, "out of range off: the game's look (" .. vc(b1.icon) .. ")")
switches[1].set(true)
check(color(b1.icon, 1, 0.3, 0.1, 0.75), "on again: red (" .. vc(b1.icon) .. ")")

-- an action button the game adds later
SLOTS[4] = { usable = true, noMana = false, range = false }
local b4 = GameButton(4)
ActionBarButtonEventsFrame:RegisterFrame(b4)
check(color(b4.icon, 1, 0.3, 0.1, 0.75), "a button added later: watched (" .. vc(b4.icon) .. ")")

-- the pet bar (the game checks its range every 0.2 s)
local pet = PetActionBar.actionButtons[1]
PET[1].range = false
ActionButton_UpdateRangeIndicator(pet, true, false)
check(color(pet.icon, 1, 0.3, 0.1, 0.75), "a pet action out of range: red (" .. vc(pet.icon) .. ")")
pet:UpdateButtonState()
check(color(pet.icon, 1, 0.3, 0.1, 0.75), "the pet bar painted again: red again")
PET[1].range = true
ActionButton_UpdateRangeIndicator(pet, true, true)
check(color(pet.icon, 1, 1, 1, 1), "in range: white")

-- its page in the game's options
local category
for _, c in ipairs(M.settingsCategories) do if c.name == "tullaRange" then category = c end end
check(category ~= nil and category == ns.tullaRangeCategory, "its own entry in Esc > Options > AddOns: tullaRange")
M.ShowSettingsPage(category)
local page = category.frame
local sliders, checks = {}, {}
local function Walk(f)
  for _, c in ipairs(M.frames) do
    if c._parent == f then
      if c._kind == "Slider" then sliders[#sliders + 1] = c end
      if c._kind == "CheckButton" then checks[#checks + 1] = c end
      Walk(c)
    end
  end
end
Walk(page)
check(#sliders == 12 and #checks == 6, "three states: four sliders each, a box and Desaturate (" .. #sliders .. ", " .. #checks .. ")")
check(math.floor(sliders[4]:GetValue() + .5) == 75 and sliders[1].Text:GetText() == "Red" and sliders[4].Text:GetText() == "Opacity",
  "out of range's opacity: 75 (" .. tostring(sliders[4]:GetValue()) .. ")")
sliders[4]:SetValue(50)
check(near(ClaraTullaRangeDB.oor[4], 0.5) and color(b1.icon, 1, 0.3, 0.1, 0.5), "opacity 50: saved, the buttons at once (" .. vc(b1.icon) .. ")")
local oomBox
for _, c in ipairs(checks) do if c:GetChecked() == false and c.Text == nil then oomBox = oomBox or c end end
local onBoxes = {}
for _, c in ipairs(checks) do
  local _, rel = c:GetPoint(1)
  if rel == c._parent and select(4, c:GetPoint(1)) == -4 and select(5, c:GetPoint(1)) == 5 then onBoxes[#onBoxes + 1] = c end
end
check(#onBoxes == 3 and onBoxes[1]:GetChecked() and not onBoxes[2]:GetChecked() and onBoxes[3]:GetChecked(), "its boxes: on, off, on")
onBoxes[2]:SetChecked(true); onBoxes[2]:GetScript("OnClick")(onBoxes[2])
check(ClaraTullaRangeDB.oom.on == true and switches[2].get() == true, "out of mana ticked on the page: on")
local defaults
for _, c in ipairs(M.frames) do if c._parent == page and c._kind == "Button" and c:GetText() == "Defaults" then defaults = c end end
defaults:GetScript("OnClick")(defaults)
check(near(ClaraTullaRangeDB.oor[4], 0.75) and ClaraTullaRangeDB.oom.on == false and math.floor(sliders[4]:GetValue() + .5) == 75,
  "Defaults: 75 % again, out of mana off")
check(color(b1.icon, 1, 0.3, 0.1, 0.75), "the buttons too (" .. vc(b1.icon) .. ")")
ns:OpenQol("tullarange")
check(M.openedCategory == category:GetID(), "its options from the Improvements tab: this page")
out("")
out(fails .. " failure(s)")
