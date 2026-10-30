-- The click buttons' check, out of combat (four times a second): nothing is read again while
-- nothing they depend on changed; any change is still followed at the next check. A spell's
-- tooltip that gave no form is read again every 5 s, for a minute (then on a new spell or form).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.05) end

local CLAW, MAUL, REJUV = 1082, 9881, 774
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3 -- Cat Form
S.forms = { 9634, 768 }; S.form = 2
S.knownSpells = { [CLAW] = true, [MAUL] = true, [REJUV] = true, [9634] = true, [768] = true }
S.tooltips = { [CLAW] = { "Claw", "Requires Cat Form" }, [MAUL] = { "Maul", "Requires Bear Form, Dire Bear Form" } }
M.KNOWN["Claw"] = CLAW; M.KNOWN["Rejuvenation"] = 1058
S.energy = 60; S.rage = 30; S.mana, S.manaMax = 1000, 2000
local reads = 0
local rawTooltip = C_TooltipInfo.GetSpellByID
C_TooltipInfo.GetSpellByID = function(id) reads = reads + 1 return rawTooltip(id) end
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
local function layers() local _, _, all = ns:ClickButtons(); return all end
local function shownButtons(n)
  local list = {}
  local layer = layers()[n]
  for _, b in ipairs(layer and layer.buttons or {}) do if b:IsShown() then list[#list + 1] = b end end
  return list
end
local function rect(b) local p = b._points and b._points[1]; return p and p[4], p and p[5] end
local function button(n, id) for _, b in ipairs(shownButtons(n)) do if b.spellID == id then return b end end end
-- the check as the game runs it: a quarter of a second later each time
local function tick(seconds)
  for _ = 1, math.floor((seconds or .25) / .25 + .5) do
    M.ResetLayout()
    M.Frame(.25) -- (the time goes on by as much)
  end
end
ns.db.rows.above[1] = { CLAW, MAUL }
ns.db.rows.below[1] = { REJUV }
ns:LayoutIcons()
tick()
check(#shownButtons(1) == 3 and #shownButtons(2) == 3, "a druid in Cat Form: both layers placed (3 + 3)")
local claw = button(1, CLAW)
check(claw and claw:GetAttribute("macrotext") == "/cast [form:2] Claw; Cat Form", "Claw: Cat Form first")

out("== nothing changed: nothing read again")
tick(2)
reads = 0
local before = { rect(claw) }
local setAttr = 0
for _, layer in pairs(layers()) do
  for _, b in ipairs(layer.buttons) do
    local raw = b.SetAttribute
    b.SetAttribute = function(...) setAttr = setAttr + 1 return raw(...) end
  end
end
M.now = M.now + 120 -- (past the minute a tooltip's "nothing" is read again)
tick(10)
check(reads == 0, "10 s of checks: no tooltip read (" .. reads .. ")")
check(setAttr == 0, "no button set again (" .. setAttr .. ")")

out("== the HUD moved: the buttons follow at the next check")
ns.db.x = ns.db.x + 50; ns:ApplyPosition()
tick()
local l1, b1 = rect(claw)
check(l1 and before[1] and l1 > before[1] + 10, ("moved right: %.1f -> %.1f"):format(before[1] or -1, l1 or -1))

out("== a setting for Bear Form changed in Cat Form: its layer follows")
check(#shownButtons(2) == 3, "the Bear Form layer: 3 buttons")
ns:SetBearIconsFixed(true)
tick()
local bearMaul = button(2, MAUL)
local catMaul = button(1, MAUL)
local _, bb = rect(bearMaul or {}); local _, cb = rect(catMaul or {})
check((#shownButtons(2) == 0) or (bb and cb and near(bb, cb)), "icons kept in place in Bear Form: the Bear Form layer as the Cat Form one")
ns:SetBearIconsFixed(false)
tick()
local _, bb2 = rect(button(2, MAUL) or {})
check(bb2 and cb and bb2 < cb - 5, ("back: the Bear Form layer lower again (%.1f < %.1f)"):format(bb2 or -1, cb or -1))

out("== an icon added: its button at the next check")
ns.db.rows.below[1] = { REJUV, CLAW }
ns:LayoutIcons()
tick()
check(#shownButtons(1) == 4, "4 buttons (" .. #shownButtons(1) .. ")")
ns.db.rows.below[1] = { REJUV }
ns:LayoutIcons()
tick()
check(#shownButtons(1) == 3, "removed: 3 again")

out("== caster form, then a party with the HUD hidden in a party: the layers go")
S.form = 0; S.powerType = 0
M.Fire("UPDATE_SHAPESHIFT_FORM"); tick()
check(#shownButtons(1) == 3 and #shownButtons(2) == 3, "caster form: both layers kept, each for its form")
ns.sv.profiles.DRUID.hideWhen.party = true
S.group = "party"
tick() -- (no event: found by the check alone)
check(#shownButtons(1) == 0 and #shownButtons(2) == 0, "hidden in a party: no button left")
S.group = nil
M.Fire("GROUP_ROSTER_UPDATE"); tick()
ns.sv.profiles.DRUID.hideWhen.party = nil
S.form = 2; S.powerType = 3
M.Fire("UPDATE_SHAPESHIFT_FORM"); tick()
check(#shownButtons(1) == 3, "Cat Form again, solo: the buttons back")

out("== a tooltip not there yet: read again every 5 s, for a minute")
S.tooltips[CLAW] = nil
M.Fire("SPELLS_CHANGED")
tick()
check(button(1, CLAW) and button(1, CLAW):GetAttribute("type1") == "spell", "no tooltip: Claw as it is")
reads = 0
tick(4.5)
check(reads == 0, "not read again before 5 s")
tick(1)
check(reads > 0, "read again after 5 s (" .. reads .. ")")
tick(60)
reads = 0
tick(20)
check(reads == 0, "a minute later: not read again (" .. reads .. ")")
S.tooltips[CLAW] = { "Claw", "Requires Cat Form" }
M.Fire("SPELLS_CHANGED")
tick()
check(button(1, CLAW):GetAttribute("macrotext") == "/cast [form:2] Claw; Cat Form", "a new spell (SPELLS_CHANGED): read again, Cat Form first")

out("")
out(fails .. " failure(s)")
