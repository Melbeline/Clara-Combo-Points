-- garbage and time, part by part (mock included)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local CLASS = PROF_CLASS or "ROGUE"
S.class = CLASS; S.locale = "enUS"
S.knownSpells = { [1752] = true, [5171] = true, [2098] = true, [2983] = true, [5277] = true, [1784] = true, [1766] = true, [1943] = true }
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.now = 100
local p = ns.sv.profiles[CLASS]
p.rows.above[1] = { 5171, 2983, 5277, 1784 }
p.rows.below[1] = { 1943, 1766, 2098 }
ns:LayoutIcons(); ns:UpdateVisibility()
S.target = { cp = 0, hostile = true, name = "Boar" }
M.Fire("PLAYER_TARGET_CHANGED")
S.inCombat = true; M.Fire("PLAYER_REGEN_DISABLED")
S.auras = { player = { { name = "Slice and Dice", icon = 1, applications = 0, duration = 21, expirationTime = 121, id = 1, spellId = 5171 } },
  target = { { name = "Rupture", icon = 2, applications = 0, duration = 16, expirationTime = 116, harmful = true, id = 2, spellId = 1943, sourceUnit = "player" } } }
S.cooldowns = S.cooldowns or {}
S.cooldowns["Sprint"] = { 100, 300 }
for _ = 1, 5 do M.Frame(0.016) end
local hudUpdate = ns.hud._scripts.OnUpdate
local function measure(label, n, fn)
  collectgarbage("collect"); collectgarbage("stop")
  local k0, t0 = collectgarbage("count"), os.clock()
  for i = 1, n do fn(i) end
  local k1, t1 = collectgarbage("count"), os.clock()
  collectgarbage("restart")
  out(("%-40s %8.2f us  %8.3f KB  per call"):format(label, (t1 - t0) / n * 1e6, (k1 - k0) / n))
end
measure("baseline: empty loop", 5000, function() end)
measure("HUD OnUpdate, nothing changed", 5000, function() hudUpdate(ns.hud, 0.016) end)
measure("HUD OnUpdate, energy changes", 5000, function(i) S.energy = i % 100; hudUpdate(ns.hud, 0.016) end)
measure("UpdateIcons (7 icons)", 2000, function() ns:UpdateIcons() end)
measure("mock GetSpellCooldown alone", 5000, function() C_Spell.GetSpellCooldown("Sprint") end)
measure("mock GetAuraDataBySpellName alone", 5000, function() C_UnitAuras.GetAuraDataBySpellName("player", "Slice and Dice", "HELPFUL") end)
local function fire(ev, ...) local a = { ... } return function() M.Fire(ev, unpack(a)) end end
measure("UNIT_AURA player (event only)", 2000, fire("UNIT_AURA", "player", {}))
measure("SPELL_UPDATE_COOLDOWN (event only)", 2000, fire("SPELL_UPDATE_COOLDOWN"))
measure("UNIT_POWER_FREQUENT", 2000, fire("UNIT_POWER_FREQUENT", "player", "ENERGY"))
measure("UNIT_POWER_UPDATE combo", 2000, function(i) S.playerCP = i % 6; M.Fire("UNIT_POWER_UPDATE", "player", "COMBO_POINTS") end)
measure("UNIT_SPELLCAST_SUCCEEDED", 2000, fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 1752))
measure("PLAYER_TARGET_CHANGED", 500, fire("PLAYER_TARGET_CHANGED"))
measure("UNIT_INVENTORY_CHANGED", 500, fire("UNIT_INVENTORY_CHANGED", "player"))
measure("BAG_UPDATE_DELAYED", 500, fire("BAG_UPDATE_DELAYED"))
measure("UpdateVisibility", 500, function() ns:UpdateVisibility() end)
measure("SyncClickers (out of combat)", 500, function() S.inCombat = false; ns:SyncClickers() end)
S.inCombat = false
local others = {}
for _, f in ipairs(M.frames) do
  if f._scripts and f._scripts.OnUpdate and f:IsVisible() and f ~= ns.hud then others[#others + 1] = f end
end
out("other OnUpdate frames shown: " .. #others)
for _, f in ipairs(others) do
  local info = debug.getinfo(f._scripts.OnUpdate, "S")
  measure("  OnUpdate " .. info.short_src .. ":" .. info.linedefined, 3000, function() f._scripts.OnUpdate(f, 0.016) end)
end
return 0
