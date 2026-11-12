-- HUD icons while on, as WoW Forever answers (the user's /cl souris reports, real file IDs): Shadowmeld on, its button
-- (54) shows the star 136116, not checked; Stealth on, its button shows 136047 (a face) and is checked, its form too
-- (the stance bar gives 136047); the spells' own icons do not change. Their buffs are up: the game's aura button over
-- each icon shows the buff's icon (the night elf face, the hood) and covered Clara's image before. Wanted: the star
-- alone, the face with the gold border, both above the game's aura button. Auto Shot's bow never counts.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local MELD, STEALTH, AUTO, HAWK = 20580, 1784, 75, 13165
local HAWK_ICON = 136076
M.SPELLS[HAWK] = M.SPELLS[HAWK] or { "Aspect of the Hawk", HAWK_ICON, 0 }
local NELF, HOOD, AUTO_ICON, BOW = 132089, 132320, 135493, 135489
local STAR, FACE = 136116, 136047
local game = { meld = false, stealth = false, hawk = false, stealthPlain = false }
local ACTIONS = { [54] = { "spell", MELD }, [61] = { "macro", 5, STEALTH }, [70] = { "spell", AUTO }, [80] = { "spell", HAWK } }
function GetActionInfo(a) local r = ACTIONS[a] if r then return r[1], r[2] end end
function GetMacroSpell(i) if i == 5 then return STEALTH end end
C_ActionBar = C_ActionBar or {}
C_ActionBar.HasAction = function(a) return ACTIONS[a] ~= nil end
C_ActionBar.GetSpell = function(a) local r = ACTIONS[a] return r and (r[3] or r[2]) or 0 end
C_ActionBar.GetActionTexture = function(a)
  local r = ACTIONS[a]
  local id = r and (r[3] or r[2])
  if id == MELD then return game.meld and STAR or NELF end
  if id == STEALTH then return (game.stealth and not game.stealthPlain) and FACE or HOOD end
  if id == AUTO then return BOW end
  if id == HAWK then return game.hawk and STAR or HAWK_ICON end
end
C_ActionBar.IsCurrentAction = function(a) local r = ACTIONS[a] return r ~= nil and (r[3] or r[2]) == STEALTH and game.stealth end
C_ActionBar.FindSpellActionButtons = function() return {} end
-- (Shadowmeld and Stealth cannot be cast again while on: their buttons unusable, grey 0.4 as the game draws them)
C_ActionBar.IsUsableAction = function(a)
  local r = ACTIONS[a]
  local id = r and (r[3] or r[2])
  if id == MELD then return not game.meld, false end
  if id == STEALTH then return not game.stealth, false end
  return true, false
end
local plainTexture = C_Spell.GetSpellTexture
C_Spell.GetSpellTexture = function(spell)
  local id = type(spell) == "number" and spell or ({ Shadowmeld = MELD, Stealth = STEALTH, ["Auto Shot"] = AUTO })[spell]
  if id == MELD then return NELF, NELF end -- (the spells' own icons never change: report "game 132089/132089")
  if id == STEALTH then return HOOD, HOOD end
  if id == AUTO then return BOW, AUTO_ICON end
  if id == HAWK then return HAWK_ICON, HAWK_ICON end
  return plainTexture(spell)
end
C_Spell.IsCurrentSpell = function() return false end
function GetInventoryItemTexture(_, slot) if slot == 18 then return BOW end end
function GetShapeshiftForm() return game.stealth and 1 or 0 end
function GetShapeshiftFormInfo(i) if i == 1 then return (game.stealth and not game.stealthPlain) and FACE or HOOD, game.stealth and 1 or nil, 1, STEALTH end end
function GetNumShapeshiftForms() return 1 end
local function Buffs()
  local list = {}
  if game.meld then list[#list + 1] = { name = "Shadowmeld", icon = NELF, spellId = MELD, duration = 0, expirationTime = 0, source = "player", sourceUnit = "player" } end
  if game.stealth then list[#list + 1] = { name = "Stealth", icon = HOOD, spellId = STEALTH, duration = 0, expirationTime = 0, source = "player", sourceUnit = "player" } end
  if game.hawk then list[#list + 1] = { name = "Aspect of the Hawk", icon = HAWK_ICON, spellId = HAWK, duration = 0, expirationTime = 0, source = "player", sourceUnit = "player" } end
  S.auras = S.auras or {}
  S.auras.player = list
end

S.class = "ROGUE"; S.locale = "enUS"; S.powerType = 3; S.energy = 100
S.knownSpells = { [MELD] = true, [STEALTH] = true, [AUTO] = true, [HAWK] = true }
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
ns.db.rows.above[1] = { MELD, STEALTH, AUTO, HAWK }
ns:LayoutIcons()
M.Frame(0.016)
local function slotOf(name)
  local found
  ns:ForEachIcon(function(slot) if slot.name == name then found = slot end end)
  return found
end
local function Changed()
  Buffs()
  for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_UPDATE_STATE", "SPELL_UPDATE_ICON", "UNIT_AURA" }) do
    M.Fire(e, e == "UNIT_AURA" and "player" or nil)
  end
  M.Frame(0.016); M.Frame(0.016)
end
-- the level the game gives a frame: its own, else its parent's + 1
local function Level(f) if f._level then return f._level end local p = f._parent return p and Level(p) + 1 or 0 end
-- the game's aura button laid over this icon (the containers as the game runs them), and its icon texture
local function GameButton(slot)
  for _, c in ipairs(M.containers or {}) do
    for _, s in pairs(c._slots) do
      local b = s.button
      local p = b._points and b._points[1]
      if b:IsShown() and p and p[2] == slot then return b, { icon = b._icon } end
    end
  end
end
-- what is seen on the icon: the image above the game's aura button when Clara shows one, else the aura button's,
-- else the icon's own
local function Seen(slot)
  local button, rec = GameButton(slot)
  if slot.active and slot.active:IsShown() and (not button or Level(slot.over) > Level(button)) then return slot.active:GetTexture() end
  if button then return rec.icon:GetTexture() end
  return slot.icon:GetTexture()
end
local meld, stealth, auto = slotOf("Shadowmeld"), slotOf("Stealth"), slotOf("Auto Shot")
check(meld and stealth and auto, "the three icons on the HUD")
check(Seen(meld) == NELF and not meld.isChecked, "Shadowmeld off: its own image, no border (screen 1)")
check(Seen(stealth) == HOOD and not stealth.isChecked, "Stealth off: its own image, no border")
check(Seen(auto) == AUTO_ICON and not auto.isChecked, "Auto Shot (its button shows the bow): its own icon, not on")

out("== Shadowmeld on: its buff up, the game's aura button showing the face over the icon")
game.meld = true; Changed()
local button = GameButton(meld)
check(button ~= nil, "the game's aura button shows the buff (as in game)")
check(Seen(meld) == STAR, "seen: the star (screen 3), above the game's aura button: " .. tostring(Seen(meld)))
check(not meld.isChecked and meld:GetAlpha() == 1, "lit, no gold border")
local vc = meld.active._vc or {}
check(vc[1] == .4 and vc[2] == .4 and vc[3] == .4, "as dull as the game's button (unusable while on: grey 0.4, the user's screen): " .. tostring(vc[1]))
game.meld = false; Changed()
check(Seen(meld) == NELF and not (meld.active and meld.active:IsShown()) and not meld.isChecked, "off: its own image back")

out("== Stealth on: its buff up too")
game.stealth = true; Changed()
check(Seen(stealth) == FACE, "seen: the face (screen 4), above the game's aura button: " .. tostring(Seen(stealth)))
check(stealth.isChecked, "with the gold border")
vc = stealth.active._vc or {}
check(vc[1] == .4 and vc[2] == .4 and vc[3] == .4, "as dull as its button too (grey 0.4)")
check(Level(stealth.checked) > Level(stealth.over), "the border above the image")
check(Seen(meld) == NELF and Seen(auto) == AUTO_ICON and not auto.isChecked, "the others left as they are")
game.stealth = false; Changed()
check(Seen(stealth) == HOOD and not stealth.isChecked and not (stealth.active and stealth.active:IsShown()), "off: its own image, no border")

out("== an aspect on: its button usable, the star dull all the same (the user: aspects stayed bright)")
local hawk = slotOf("Aspect of the Hawk")
game.hawk = true; Changed()
vc = hawk.active._vc or {}
check(Seen(hawk) == STAR and not hawk.isChecked, "the star, alone")
check(vc[1] == .4 and vc[2] == .4 and vc[3] == .4, "dull, grey 0.4: " .. tostring(vc[1]))
game.hawk = false; Changed()
check(Seen(hawk) == HAWK_ICON and not (hawk.active and hawk.active:IsShown()), "off: its own image, bright")

out("== a form on whose image does not change (a druid form): its own image, dull, the gold border")
game.stealth, game.stealthPlain = true, true; Changed()
vc = stealth.active._vc or {}
check(Seen(stealth) == HOOD and stealth.active:IsShown() and stealth.isChecked, "its own image above the game's aura button, the gold border")
check(vc[1] == .4, "dull: " .. tostring(vc[1]))
game.stealth, game.stealthPlain = false, false; Changed()
check(not stealth.active:IsShown() and not stealth.isChecked, "off: bright, no border")

out("== Shadowmeld cast: its button checked an instant, then the star while the game no longer checks it")
C_ActionBar.IsCurrentAction = function(a) local r = ACTIONS[a] local id = r and (r[3] or r[2]) return (id == STEALTH and game.stealth) or (id == MELD and game.casting) end
game.casting = true; Changed()
game.casting = false; game.meld = true; Changed()
check(Seen(meld) == STAR, "the star all the same (its rest image not taken from its button): " .. tostring(Seen(meld)))
game.meld = false; Changed()
check(Seen(meld) == NELF, "off: its face")

out("== the mouse report")
game.meld = true; Changed()
local text = table.concat(ns:HudIconsReport(), "\n")
check(text:find("above the game's aura button 136116", 1, true) ~= nil and text:find("game aura button shown (132089)", 1, true) ~= nil,
  "it shows the image above and the game's aura button under it")
out(text)
out(string.format("\n%d failure(s)", fails))
return fails
