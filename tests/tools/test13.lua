-- review fixes: hidden target GUID, accented names, list order, unfolded class per tab,
-- narrow screens, the button mask
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b) return math.abs(a - b) < 0.01 end
local function lit(f) return f:IsShown() and not f.icon._desat and f._alpha == 1 end

-- a French client: Moonfire is "Éclat lunaire", Barkskin "Écorce", Thorns "Épines"
M.SPELLS[22812] = { "Écorce", 136097, 0 }
M.SPELLS[467] = { "Épines", 136104, 0 }
M.SPELLS[8921][1], M.SPELLS[8924][1] = "Éclat lunaire", "Éclat lunaire"
M.SPELLS[774][1], M.SPELLS[1058][1] = "Récupération", "Récupération"
M.HARMFUL["Éclat lunaire"] = true; M.HELPFUL["Récupération"] = true
local ns = {}
S.class = "DRUID"; S.locale = "frFR"; S.powerType = 3; S.energy = 100
-- 4:3 screen at UI scale 1
S.uiScale = 1; UIParent._scale = 1; S.physH = 1920
M.LoadAddon(ADDON_DIR, ns)
ns.SPELL_CATALOG = {
  { class = "ROGUE", spells = { { "BUFF", 6774 } } },
  { class = "DRUID", spells = { { "BUFF", 774, 1058 }, { "DEBUFF", 8921, 8924 }, { "BUFF", 22812 }, { "BUFF", 467 } } },
}
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
local function slotsOf(side, k)
  local list = {}
  for _, f in ipairs(M.frames) do
    if f.cd and f.spell ~= nil and f:GetParent() and f:GetParent().spells == ns.db.rows[side][k] then list[#list + 1] = f end
  end
  return list
end

out("== names with accented capitals")
check(ns:Fold("ÉCLAT Lunaire") == "éclat lunaire" and ns:Fold("ÜBERWÄLTIGEN") == "überwältigen", "accented capitals folded")
local ok = ns:AddIcon("above", 1, "éclat lunaire")
check(ok and ns.db.rows.above[1][1] == 8924, "'éclat lunaire' typed in lower case: found")
ok = ns:AddIcon("above", 1, "ÉCORCE")
check(ok and ns.db.rows.above[1][2] == 22812, "'ÉCORCE' found")

out("== hidden target GUID in combat")
local realGUID = UnitGUID
UnitGUID = function(u) local g = realGUID(u); if u == "target" and S.inCombat and g then return M.Secret(g) end return g end
ns.db.rows.above[1] = { 774, 8921 }
ns:LayoutIcons(); M.Frame(0.016)
local moon = slotsOf("above", 1)[2]
M.Fire("PLAYER_REGEN_DISABLED"); S.inCombat = true; S.secretAuras = true
S.target = { hostile = true, guid = "Creature-A" }
S.auras = { target = {} }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 8921)
S.auras.target = { { name = "Éclat lunaire", icon = 136096, duration = 9, expirationTime = M.now + 9, harmful = true, id = 60, spellId = 8921 } }
M.Fire("UNIT_AURA", "target"); M.Frame(0.016)
M.Fire("UNIT_AURA", "target"); M.Frame(0.016)
M.now = M.now + 2
M.Fire("SPELL_UPDATE_COOLDOWN"); M.Frame(0.016)
local function auraShown(slot)
  for _, f in ipairs(M.frames) do
    if f._auraButton and f._points and f._points[1] and f._points[1][2] == slot and f:IsVisible() then return f end
  end
end
check(auraShown(moon) and auraShown(moon)._cd._cd[2] == 9, "Moonfire on a target whose GUID is hidden: shown by the game's aura button")
S.target = { hostile = true, guid = "Creature-B" }
S.auras.target = { { name = "Rend", icon = 1, duration = 21, expirationTime = M.now + 21, harmful = true, id = 70 } }
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)
check(not lit(moon) and not auraShown(moon), "another target (GUID hidden too): not shown")
UnitGUID = realGUID
S.secretAuras = false; S.inCombat = false; M.Fire("PLAYER_REGEN_ENABLED")
S.target = nil; S.auras = nil
M.Fire("PLAYER_TARGET_CHANGED"); M.Frame(0.016)

out("== the button mask")
local slot = slotsOf("above", 1)[1]
local mask = slot.mask
local _, _, w, h = M.Rect(slot)
M.ResetLayout()
local _, _, mw, mh = M.Rect(mask)
check(mask and slot.icon._masks and slot.icon._masks[1] == mask and mask._atlas == "UI-HUD-CoolDownManager-Mask", "icon masked (the game's own icon mask, rounded corners)")
check(near(mw, w) and near(mh, h), "mask over the whole icon: the art fills the button frame (" .. math.floor(mw) .. " x " .. math.floor(mh) .. ")")

out("== class spells panel")
SlashCmdList.CLARACOMBOPOINTS("")
local panel, side = ClaraComboPointsOptions, ClaraComboPointsSpells
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
M.ResetLayout()
local sl, _, sw = M.AbsRect(UIParent)
local cl, _, cw = M.AbsRect(side)
check(panel:GetScale() < 1 and cl + cw <= sl + sw + 0.01, "4:3 screen: the window is scaled down so the panel fits (" .. string.format("%.2f", panel:GetScale()) .. ")")
check(panel._clamped == false, "the window is free to go off the screen")
local druid, rogue
for _, g in ipairs(side.groups) do if g.class == "DRUID" then druid = g elseif g.class == "ROGUE" then rogue = g end end
local names = {}
for _, r in ipairs(druid.rows or {}) do
  for _, region in ipairs(M.regions) do if region._parent == r and region._maxLines == 2 then names[#names + 1] = region._text end end
end
check(table.concat(names, " | ") == "Éclat lunaire | Écorce | Épines | Récupération", "alphabetical order, accents aside: " .. table.concat(names, " | "))
local function open(g) local n = 0; for _, r in ipairs(g.rows or {}) do if r:IsShown() then n = n + 1 end end return n end
check(open(druid) == 4 and open(rogue) == 0, "druid tab: druid spells unfolded")
for _, f in ipairs(M.frames) do if f.class == "ROGUE" then f:Click() end end
check(open(rogue) == 1, "rogue tab: rogue spells unfolded too")
panel:Hide()

out(string.format("\n%d failure(s)", fails))
return fails
