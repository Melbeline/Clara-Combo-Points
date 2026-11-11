-- HUD icons while on, as WoW Forever shows them (the user's screens): each takes the image the game's own button
-- shows. Shadowmeld on: its button shows the star (a file ID Clara is not told), not checked. Stealth on: its button (a
-- macro here) shows a face, checked (gold border); the stance bar keeps the spell's own image. The game gives the image
-- while on to the spell's icon AND to its "original" icon. Auto Shot's button shows its bow: never taken for on.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local MELD, STEALTH, AUTO = 20580, 1784, 75
local NELF, HOOD, AUTO_ICON, BOW = 132089, 132320, 135493, 135489
local STAR, FACE = 999001, 999002 -- the images the game gives while on: unknown files to Clara
local game = { meld = false, stealth = false }
-- 66: Shadowmeld (a spell); 61: a macro casting Stealth; 70: Auto Shot
local ACTIONS = { [66] = { "spell", MELD }, [61] = { "macro", 5, STEALTH }, [70] = { "spell", AUTO } }
function GetActionInfo(a) local r = ACTIONS[a] if r then return r[1], r[2] end end
function GetMacroSpell(i) if i == 5 then return STEALTH end end
C_ActionBar = C_ActionBar or {}
C_ActionBar.HasAction = function(a) return ACTIONS[a] ~= nil end
C_ActionBar.GetSpell = function(a) local r = ACTIONS[a] return r and (r[3] or r[2]) or 0 end
local function Shown(id)
  if id == MELD then return game.meld and STAR or NELF end
  if id == STEALTH then return game.stealth and FACE or HOOD end
  if id == AUTO then return BOW end
end
C_ActionBar.GetActionTexture = function(a) local r = ACTIONS[a] return r and Shown(r[3] or r[2]) end
C_ActionBar.IsCurrentAction = function(a) local r = ACTIONS[a] return r ~= nil and (r[3] or r[2]) == STEALTH and game.stealth end
C_ActionBar.FindSpellActionButtons = function() return {} end
local plainTexture = C_Spell.GetSpellTexture
C_Spell.GetSpellTexture = function(spell)
  local id = type(spell) == "number" and spell or ({ Shadowmeld = MELD, Stealth = STEALTH, ["Auto Shot"] = AUTO })[spell]
  if id == MELD or id == STEALTH then local t = Shown(id) return t, t end -- the "original" swapped too
  if id == AUTO then return BOW, AUTO_ICON end
  return plainTexture(spell)
end
C_Spell.IsCurrentSpell = function() return false end
function GetInventoryItemTexture(_, slot) if slot == 18 then return BOW end end
function GetShapeshiftForm() return game.stealth and 1 or 0 end
function GetShapeshiftFormInfo(i) if i == 1 then return HOOD, game.stealth and 1 or nil, 1, STEALTH end end
function GetNumShapeshiftForms() return 1 end

S.class = "ROGUE"; S.locale = "enUS"; S.powerType = 3; S.energy = 100
S.knownSpells = { [MELD] = true, [STEALTH] = true, [AUTO] = true }
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
ns.db.rows.above[1] = { MELD, STEALTH, AUTO }
ns:LayoutIcons()
M.Frame(0.016)
local function slotOf(name)
  local found
  ns:ForEachIcon(function(slot) if slot.name == name then found = slot end end)
  return found
end
local function Changed()
  for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_UPDATE_STATE", "SPELL_UPDATE_ICON", "UNIT_AURA" }) do
    M.Fire(e, e == "UNIT_AURA" and "player" or nil)
  end
  M.Frame(0.016); M.Frame(0.016)
end
local meld, stealth, auto = slotOf("Shadowmeld"), slotOf("Stealth"), slotOf("Auto Shot")
check(meld and stealth and auto, "the three icons on the HUD")
check(meld.icon:GetTexture() == NELF and not meld.isChecked, "Shadowmeld off: its own image, no border (screen 1)")
check(stealth.icon:GetTexture() == HOOD and not stealth.isChecked, "Stealth off: its own image, no border (screen 5)")
check(auto.icon:GetTexture() == AUTO_ICON and not auto.isChecked, "Auto Shot (its button shows the bow): its own icon, not on")

out("== Shadowmeld on")
game.meld = true; Changed()
check(meld.icon:GetTexture() == STAR, "the image its button shows (screen 2): " .. tostring(meld.icon:GetTexture()))
check(not meld.isChecked and meld:GetAlpha() == 1, "lit, no gold border, as its button")
game.meld = false; Changed()
check(meld.icon:GetTexture() == NELF and not meld.isChecked, "off: its own image back")

out("== Stealth on (its button a macro, checked by the game; the stance bar keeps the spell's image)")
game.stealth = true; Changed()
check(stealth.icon:GetTexture() == FACE, "the image its button shows (screen 3): " .. tostring(stealth.icon:GetTexture()))
check(stealth.isChecked, "with the gold border, as its checked button")
check(meld.icon:GetTexture() == NELF and auto.icon:GetTexture() == AUTO_ICON and not auto.isChecked, "the others left as they are")
game.stealth = false; Changed()
check(stealth.icon:GetTexture() == HOOD and not stealth.isChecked, "off: its own image, no border (screen 5)")

out("== a reload while stealthed: its image first seen while on")
game.stealth = true
ns:LayoutIcons(); M.Frame(0.016)
stealth = slotOf("Stealth")
Changed()
check(stealth.icon:GetTexture() == FACE and stealth.isChecked, "on: the face, the gold border")
game.stealth = false; Changed()
check(stealth.icon:GetTexture() == HOOD and not stealth.isChecked, "off: its own image learned back, no border (" .. tostring(stealth.icon:GetTexture()) .. ")")
game.stealth = true; Changed()
check(stealth.icon:GetTexture() == FACE and stealth.isChecked, "on again: the face, the gold border")
game.stealth = false; Changed()

out("== the mouse report lists what each icon reads")
local text = table.concat(ns:HudIconsReport(), "\n")
check(text:find("Shadowmeld (20580): own 132089", 1, true) ~= nil and text:find("66:20580=132089", 1, true) ~= nil,
  "Shadowmeld's line: its own image and its button")
check(text:find("61:1784=132320", 1, true) ~= nil, "Stealth's macro button listed")
out(text)
out(string.format("\n%d failure(s)", fails))
return fails
