-- review fixes, with the game's aura buttons: bar hidden meanwhile, target changes, condition changes, end of combat
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
-- lit: read by the addon, or shown by the game's own aura button over the icon (in combat)
local function auraShown(slot)
  for _, f in ipairs(M.frames) do
    if f._auraButton and f._points and f._points[1] and f._points[1][2] == slot and f:IsVisible() then return f end
  end
end
local function lit(f) return (f:IsShown() and not f.icon._desat and f._alpha == 1) or auraShown(f) ~= nil end
local results = {}
local fails = 0
local function check(name, c) out((c and "  ok   " or "  FAIL ") .. name); if not c then fails = fails + 1 end end

local function boot(class, ptype)
  for k in pairs(S) do S[k] = nil end
  S.class = class; S.locale = "enUS"; S.powerType = ptype; S.energy = 100; S.rage = 50
  S.secret = false; S.playerCP = 0; S.inCombat = false
  local ns = {}
  M.LoadAddon(ADDON_DIR, ns)
  ns.SPELL_CATALOG = {
    { class = "PRIEST", spells = { { "BUFF", 1243, 1244 } } },
    { class = "DRUID", spells = { { "BUFF", 774, 1058 }, { "DEBUFF", 8921, 8924 } } },
    { class = "WARRIOR", spells = { { "DEBUFF", 7386, 11597 }, { "BUFF", 6673 } } },
  }
  M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
  return ns
end
local function slotOf(ns, side, k, i)
  for _, f in ipairs(M.frames) do
    if f.cd and f.spell ~= nil and f:GetParent() and f:GetParent().spells == ns.db.rows[side][k] and f:GetParent().slots[i] == f then return f end
  end
end

-- F1: druid, default settings, caster form (HUD hidden). Natural sequence, nothing poked.
do
  out("F1 case B: buffed before the pull in caster form, combat, shift to cat")
  local ns = boot("DRUID", 0)
  M.now = 100
  ns.db.rows.above[1] = { 774 }
  ns:LayoutIcons(); M.Frame(0.016)
  out("  hud shown in caster: " .. tostring(ns.hud:IsShown()))
  M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 774)
  S.auras = { player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = 112, id = 41, spellId = 774 } } }
  M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
  M.now = 105
  M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true
  M.Frame(0.016)
  M.now = 106
  S.powerType = 3; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016); M.Frame(0.016)
  local slot = slotOf(ns, "above", 1, 1)
  out("  hud shown in cat: " .. tostring(ns.hud:IsShown()))
  check("F1B rejuv lit in cat (buff up 6 s more)", lit(slot))
end
do
  out("F1 case A: in combat in caster form, cast Rejuvenation, shift after GCD (1.6 s)")
  local ns = boot("DRUID", 0)
  M.now = 300
  ns.db.rows.above[1] = { 774 }
  ns:LayoutIcons(); M.Frame(0.016)
  M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true
  M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c", 774)
  M.now = 300.2
  S.auras = { player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = 312.2, id = 61, spellId = 774 } } }
  M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
  M.now = 301.6
  S.powerType = 3; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016); M.Frame(0.016)
  check("F1A rejuv lit in cat", lit(slotOf(ns, "above", 1, 1)))
end

-- F2: warrior tab-sunder
do
  out("F2: Sunder on A, tab to B (only Rend) 0.8 s later, tab back to A")
  local ns = boot("WARRIOR", 1)
  M.now = 500
  ns.db.rows.above[1] = { 7386 }
  ns:LayoutIcons(); M.Frame(0.016)
  local slot = slotOf(ns, "above", 1, 1)
  M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true
  local A = { { name = "Sunder Armor", icon = 132363, duration = 30, expirationTime = 530, harmful = true, id = 10, spellId = 11597 } }
  local B = { { name = "Rend", icon = 132155, duration = 15, expirationTime = 515, harmful = true, id = 20 },
              { name = "Thunder Clap", icon = 1, duration = 10, expirationTime = 510, harmful = true, id = 21 } }
  S.target = { hostile = true, guid = "Creature-A" }; S.auras = { target = {} }
  M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
  M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "c1", 7386)
  M.now = 500.2
  S.auras.target = A
  M.Fire("UNIT_AURA", "target"); M.Frame(0.016)
  check("F2 Sunder lit on A", lit(slot))
  M.now = 501.0
  S.target = { hostile = true, guid = "Creature-B" }; S.auras.target = B
  M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
  check("F2 Sunder gray on B (no Sunder there)", not lit(slot))
  M.now = 504
  S.target = { hostile = true, guid = "Creature-A" }; S.auras.target = A
  M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
  check("F2 Sunder lit again on A (still up)", lit(slot))
end

-- F3: condition changed from the icon menu keeps the old instance
do
  out("F3: Rejuvenation on you (auto), switched to 'Friendly target', friend targeted without it")
  local ns = boot("DRUID", 3)
  M.now = 700
  ns.db.rows.above[1] = { 774 }
  ns:LayoutIcons(); M.Frame(0.016)
  local slot = slotOf(ns, "above", 1, 1)
  S.auras = { player = { { name = "Rejuvenation", icon = 136081, duration = 12, expirationTime = 712, id = 41, spellId = 774 } } }
  M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
  check("F3 lit on you (auto)", lit(slot))
  S.target = { hostile = false, guid = "Player-2" }
  M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
  ns:SetIconCondition("above", 1, 1, "friend"); M.Frame(0.016)
  check("F3 gray: friend has no Rejuvenation (out of combat, auras readable)", not lit(slot))
end

-- F4: combat end does not re-read icons
do
  out("F4: warrior tracks Power Word: Fortitude; a priest buffs you mid-fight; fight ends")
  local ns = boot("WARRIOR", 1)
  M.now = 900
  ns.db.rows.above[1] = { 1243 }
  ns:LayoutIcons(); M.Frame(0.016)
  local slot = slotOf(ns, "above", 1, 1)
  M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true
  S.auras = { player = { { name = "Power Word: Fortitude", icon = 135987, duration = 1800, expirationTime = 2700, id = 88, spellId = 1243 } } }
  M.Fire("UNIT_AURA", "player"); M.Frame(0.016)
  out("    in combat (aura hidden, not your cast): lit " .. tostring(lit(slot)))
  M.now = 920
  S.inCombat = false; S.secretAuras = false
  M.Fire("PLAYER_REGEN_ENABLED"); M.Frame(0.016); M.Frame(0.016)
  M.now = 930; M.Frame(0.016)
  check("F4 lit after combat (aura readable again)", lit(slot))
  M.Fire("SPELL_UPDATE_COOLDOWN"); M.Frame(0.016)
  out("    after an unrelated SPELL_UPDATE_COOLDOWN: lit " .. tostring(lit(slot)))
end

out(string.format("\n%d failure(s)", fails))
return fails
