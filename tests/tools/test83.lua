-- HUD icons while on, as WoW Forever shows them (the user's screenshots): Shadowmeld's button shows the star, by a file
-- ID Clara is not told, with no checked state; the game's spell icon gives the star and its original; Stealth is a form
-- whose active flag is a 1, not a true. Wanted: Shadowmeld (and the aspects) the star alone; Stealth its own icon with
-- the gold border; Auto Shot (its weapon's icon on its button) never taken for on.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local MELD, STEALTH, AUTO = 20580, 1784, 75
local FACE, MOON, AUTO_ICON, BOW = 132089, 132320, 135493, 135489
local STAR = 999001 -- the star's file ID: unknown to Clara on purpose (the path probe gives nothing)
local STEALTH_ON = 999002 -- the image the stance bar shows for Stealth while on (another than its own)
local game = { meld = false, stealth = false, spellSwap = true, stealthImage = false }
local ACTIONS = { [66] = MELD, [61] = STEALTH, [70] = AUTO }
function GetActionInfo(a) local id = ACTIONS[a] if id then return "spell", id end end
C_ActionBar = C_ActionBar or {}
C_ActionBar.GetActionTexture = function(a)
  local id = ACTIONS[a]
  if id == MELD then return game.meld and STAR or FACE end
  if id == STEALTH then return MOON end
  if id == AUTO then return BOW end
end
C_ActionBar.IsCurrentAction = function(a) return ACTIONS[a] == STEALTH and game.stealth end
C_ActionBar.FindSpellActionButtons = function(id) local t = {} for a, s in pairs(ACTIONS) do if s == id then t[#t + 1] = a end end return t end
local plainTexture = C_Spell.GetSpellTexture
C_Spell.GetSpellTexture = function(spell)
  local id = type(spell) == "number" and spell or ({ Shadowmeld = MELD, Stealth = STEALTH, ["Auto Shot"] = AUTO })[spell]
  if id == MELD then return (game.meld and game.spellSwap) and STAR or FACE, FACE end
  if id == STEALTH then return MOON, MOON end
  if id == AUTO then return BOW, AUTO_ICON end
  return plainTexture(spell)
end
C_Spell.IsCurrentSpell = function() return false end -- (Shadowmeld on: the game says no)
function GetInventoryItemTexture(_, slot) if slot == 18 then return BOW end end
function GetShapeshiftForm() return 0 end
function GetShapeshiftFormInfo(i)
  if i == 1 then return (game.stealth and game.stealthImage) and STEALTH_ON or MOON, game.stealth and 1 or nil, 1, STEALTH end
end
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
local function Changed(...)
  for _, e in ipairs({ ... }) do M.Fire(e, e == "UNIT_AURA" and "player" or nil) end
  M.Frame(0.016); M.Frame(0.016)
end
local meld, stealth, auto = slotOf("Shadowmeld"), slotOf("Stealth"), slotOf("Auto Shot")
check(meld and stealth and auto, "the three icons on the HUD")
check(meld.spellIcon == FACE and meld.icon:GetTexture() == FACE and not meld.isChecked, "Shadowmeld off: its own face, not checked")
check(auto.icon:GetTexture() == AUTO_ICON and not auto.isChecked, "Auto Shot (its button shows the bow): its own icon, not on")

out("== Shadowmeld on: the star (spell and button)")
game.meld = true
Changed("SPELL_UPDATE_ICON", "ACTIONBAR_UPDATE_STATE", "UNIT_AURA")
check(meld.icon:GetTexture() == STAR, "the star, as its button shows it (" .. tostring(meld.icon:GetTexture()) .. ")")
check(not meld.isChecked, "alone: no gold border over it, as its button")
check(meld:GetAlpha() == 1, "lit")
out("== off again: its face back")
game.meld = false
Changed("SPELL_UPDATE_ICON", "ACTIONBAR_UPDATE_STATE", "UNIT_AURA")
check(meld.icon:GetTexture() == FACE and not meld.isChecked, "its face, not checked")

out("== the star only on its button (the spell's icon left as it is)")
game.spellSwap = false; game.meld = true
Changed("ACTIONBAR_UPDATE_STATE")
check(meld.icon:GetTexture() == STAR and not meld.isChecked, "the star all the same (" .. tostring(meld.icon:GetTexture()) .. ")")
game.meld = false; game.spellSwap = true
Changed("ACTIONBAR_UPDATE_STATE")

out("== off the bars: the spell's icon alone tells")
ACTIONS[66] = nil
ns:ActionBarsChanged()
game.meld = true
Changed("SPELL_UPDATE_ICON")
check(meld.icon:GetTexture() == STAR, "the star from the spell's icon (" .. tostring(meld.icon:GetTexture()) .. ")")
game.meld = false
Changed("SPELL_UPDATE_ICON")
ACTIONS[66] = MELD
ns:ActionBarsChanged()

out("== Stealth (a form, the game's flag a 1): its own icon with the gold border")
game.stealth = true
Changed("UPDATE_SHAPESHIFT_FORM", "UNIT_AURA")
check(stealth.icon:GetTexture() == MOON, "its own icon (" .. tostring(stealth.icon:GetTexture()) .. ")")
check(stealth.isChecked, "checked: the gold border")
check(not meld.isChecked and meld.icon:GetTexture() == FACE, "Shadowmeld left as it is")
check(auto.icon:GetTexture() == AUTO_ICON and not auto.isChecked, "Auto Shot still off")
game.stealth = false
Changed("UPDATE_SHAPESHIFT_FORM", "UNIT_AURA")
check(not stealth.isChecked and stealth.icon:GetTexture() == MOON, "out of Stealth: its icon, no border")
out("== Stealth on, the stance bar showing another image for it: that image, with the gold border")
game.stealth, game.stealthImage = true, true
Changed("UPDATE_SHAPESHIFT_FORM", "UNIT_AURA")
check(stealth.icon:GetTexture() == STEALTH_ON and stealth.isChecked, "the stance bar's image (" .. tostring(stealth.icon:GetTexture()) .. "), checked")
game.stealth, game.stealthImage = false, false
Changed("UPDATE_SHAPESHIFT_FORM", "UNIT_AURA")
check(not stealth.isChecked and stealth.icon:GetTexture() == MOON, "off: its own icon back")

out("== the mouse report lists what each icon reads")
local lines = ns:HudIconsReport()
local text = table.concat(lines, "\n")
check(text:find("Shadowmeld (20580): own 132089", 1, true) ~= nil and text:find("buttons 66=132089", 1, true) ~= nil,
  "Shadowmeld's line: its own icon and its button")
out(text)
out(string.format("\n%d failure(s)", fails))
return fails
