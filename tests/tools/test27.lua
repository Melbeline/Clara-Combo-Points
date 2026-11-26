-- clicks on the HUD's icons: a spell that needs a form takes it first (a macro: the spell in
-- its forms, else the form); a druid's two layers (out of Bear Form, in Bear Form) and their
-- drivers; nothing touched in combat. Drops on the HUD while the options are open: a spell
-- held from the spellbook, a spell dragged from the class spells panel, even icons locked.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.05) end

local FC, CLAW, MAUL = 1238122, 1082, 9881
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3 -- Cat Form
S.forms = { 9634, 768 }; S.form = 2
S.knownSpells = { [FC] = true, [CLAW] = true, [MAUL] = true, [774] = true, [9634] = true, [768] = true }
S.tooltips = {
  [FC] = { "Feral Charge", "5 Rage", "Requires Bear Form, Dire Bear Form", "Charge an enemy.", "", "Feral Charge (Cat)",
    "Requires Cat Form", "Leap behind an enemy." },
  [CLAW] = { "Claw", "Requires Cat Form" },
  [MAUL] = { "Maul", "|cffff2020Requires Bear Form, Dire Bear Form|r" },
}
M.KNOWN["Claw"] = CLAW; M.KNOWN["Feral Charge"] = FC; M.KNOWN["Rejuvenation"] = 1058
S.energy = 60; S.rage = 30; S.mana, S.manaMax = 1000, 2000
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
local function driver(n) local d = M.stateDrivers[layers()[n] or false]; return d and d[2] end
local function sync() M.ResetLayout(); ns:SyncClickers() end
local function slotRect(side, k, i)
  local found
  ns:ForEachIcon(function(slot) if slot.side == side and slot.k == k and slot.index == i then found = slot end end)
  if not found then return end
  M.ResetLayout()
  local l, b, w, h = M.AbsRect(found)
  local ui = UIParent:GetEffectiveScale()
  return l / ui, b / ui, w / ui, h / ui
end
local function rect(b)
  local p = b._points and b._points[1]
  return p and p[4], p and p[5], b:GetWidth(), b:GetHeight()
end

out("== a druid in Cat Form: what each icon's click casts")
ns.db.rows.above[1] = { FC, CLAW, MAUL }
ns.db.rows.below[1] = { 774 }
ns:LayoutIcons()
sync()
local b1 = shownButtons(1)
check(#b1 == 4, "a button per icon the druid can cast (" .. #b1 .. ")")
local by = {}
for _, b in ipairs(b1) do by[b.spellID] = b end
local fc, claw, maul, rejuv = by[FC], by[CLAW], by[MAUL], by[1058] or by[774]
check(fc and fc:GetAttribute("type1") == "macro" and fc:GetAttribute("macrotext") == "/cast [form:1] Feral Charge; Dire Bear Form",
  "Feral Charge, left click: in Bear Form the charge, else Bear Form first: " .. tostring(fc and fc:GetAttribute("macrotext")))
check(fc and fc:GetAttribute("type2") == "macro" and fc:GetAttribute("macrotext2") == "/cast [form:2] Feral Charge; Cat Form",
  "Feral Charge, right click: in Cat Form the leap, else Cat Form first: " .. tostring(fc and fc:GetAttribute("macrotext2")))
check(claw and claw:GetAttribute("macrotext") == "/cast [form:2] Claw; Cat Form", "Claw: Cat Form first: " .. tostring(claw and claw:GetAttribute("macrotext")))
check(maul and maul:GetAttribute("macrotext") == "/cast [form:1] Maul; Dire Bear Form", "Maul (its requirement in red): Bear Form first")
check(rejuv and rejuv:GetAttribute("type1") == "spell" and rejuv:GetAttribute("macrotext") == nil, "Rejuvenation needs no form: cast as it is")
M.casts = {}
fc:Click("LeftButton")
fc:Click("RightButton")
check(M.casts[1] == "macro:/cast [form:1] Feral Charge; Dire Bear Form" and M.casts[2] == "macro:/cast [form:2] Feral Charge; Cat Form",
  "the left click runs the Bear Form macro, the right click the Cat Form one")
maul:Click("RightButton")
check(#M.casts == 3 and M.casts[3] == "macro:/cast [form:1] Maul; Dire Bear Form", "one form only (Maul): either click takes it")

out("== the tooltip not there yet at login: read again later")
local saved = S.tooltips[CLAW]
S.tooltips[CLAW] = nil
M.Fire("SPELLS_CHANGED") -- (the needs read again)
sync()
local function clawButton() for _, b in ipairs(shownButtons(1)) do if b.spellID == CLAW then return b end end end
check(clawButton() and clawButton():GetAttribute("type1") == "spell", "Claw, no tooltip yet: the spell as it is")
S.tooltips[CLAW] = saved
M.now = M.now + 2; sync()
check(clawButton():GetAttribute("type1") == "spell", "2 s later: not read again yet")
M.now = M.now + 4; sync()
check(clawButton():GetAttribute("macrotext") == "/cast [form:2] Claw; Cat Form", "5 s later: read again, Cat Form first")
local dbg = table.concat(ns:DebugClicks(), "\n")
check(dbg:find("-> /cast [form:1] Feral Charge; Dire Bear Form | right: /cast [form:2] Feral Charge; Cat Form", 1, true)
  and dbg:find("stance bar: 1=Dire Bear Form, 2=Cat Form", 1, true),
  "/cl debug shows what each click casts and the stance bar")

out("== the druid's two layers")
check(driver(1) == "[form:2] show; hide", "the first layer: Cat Form only (Cat and Bear Form only is on): " .. tostring(driver(1)))
check(driver(2) == "[form:1] show; hide", "the second layer: Bear Form: " .. tostring(driver(2)))
local b2 = shownButtons(2)
check(#b2 == 4, "the Bear Form layer: the same icons")
local bearBy = {}
for _, b in ipairs(b2) do bearBy[b.spellID] = b end
local cl, cb = rect(fc)
local bl, bb = rect(bearBy[FC])
local rl, rb = rect(rejuv)
local rl2, rb2 = rect(bearBy[1058] or bearBy[774])
check(near(cl, bl) and bb < cb - 5, ("Bear Form: the rows above lower, on the rage bar (%.1f -> %.1f)"):format(cb, bb))
check(near(rl, rl2) and near(rb, rb2), "the rows below in the same place")
local l, b = slotRect("above", 1, 1)
check(near(l, cl) and near(b, cb), "the Cat Form layer on the HUD's icons as they are")
check(ns.iconsOnBar == false or ns.iconsOnBar == nil, "the HUD itself back as it was after reading the Bear Form places")

out("== Bear Form, in combat: the HUD's icons where the Bear Form layer is")
S.target = { cp = 3, hostile = true } -- points left on the target from Cat Form
S.form = 1; S.powerType = 1
M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.3)
sync()
local outBl, outBb = slotRect("above", 1, 1)
check(not near(outBb, bb), "out of combat, points on the target: the icons stay up (" .. tostring(outBb) .. ")")
S.inCombat = true
M.blocked = {}
M.Fire("PLAYER_REGEN_DISABLED"); M.Frame(0.3); M.Frame(0.3)
local inBl, inBb = slotRect("above", 1, 1)
check(near(inBl, bl) and near(inBb, bb), ("in combat: on the rage bar, where the Bear Form buttons are (%.1f / %.1f)"):format(inBb or -1, bb))
check(#M.blocked == 0, "nothing protected touched in combat (" .. table.concat(M.blocked, ", ") .. ")")
S.form = 2; S.powerType = 3
M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.3)
check(#M.blocked == 0, "a form change in combat: nothing protected touched")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED"); M.Frame(0.3)
S.target = nil
M.Frame(0.3)
sync()

out("== caster form: the HUD hidden, the layers keep their places")
S.form = 0; S.powerType = 0
M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.3)
sync()
check(not ns.iconLayer:IsVisible(), "the icons hidden in caster form")
check(#shownButtons(1) == 4 and #shownButtons(2) == 4 and driver(1) == "[form:2] show; hide",
  "both layers kept, each for its form")
ns.db.y = ns.db.y + 40; ns:ApplyPosition()
sync()
check(#shownButtons(1) == 0 and #shownButtons(2) == 0, "the HUD moved meanwhile: the layers dropped until the next form that shows it")
S.form = 2; S.powerType = 3
M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.3)
sync()
check(#shownButtons(1) == 4 and #shownButtons(2) == 4, "Cat Form again: placed again")
ns.db.druidCatOnly = false; ns:UpdateVisibility(); sync()
check(driver(1) == "[form:1] hide; show", "Cat and Bear Form only off: the first layer in every form but Bear Form: " .. tostring(driver(1)))
ns.db.druidCatOnly = true
ns:SetBearIconsFixed(true); sync()
check(#shownButtons(2) == 0 and driver(1) == "[form:2/1] show; hide",
  "icons kept above in Bear Form: one layer for both forms: " .. tostring(driver(1)))
ns:SetBearIconsFixed(false); sync()

out("== icons unlocked or the bar unlocked: no buttons")
ns:SetIconsLocked(false); sync()
check(#shownButtons(1) == 0 and #shownButtons(2) == 0, "icons unlocked: none")
ns:SetIconsLocked(true); sync()
check(#shownButtons(1) == 4, "locked again: back")

out("== the options open: a spell held from the spellbook opens the rows, even locked")
ns.sv.window.left, ns.sv.window.top = 0, select(2, M.ScreenSize()) -- the window top left, away from the HUD
ns:SetWindowScale(.5)
ns:ShowOptions()
M.Frame(0.016)
local rowsOf = {}
for _, f in ipairs(M.frames) do if f.hit and f.side then rowsOf[f.side .. f.k] = f end end
check(ns.db.iconsLocked and not rowsOf.above2.hit:IsVisible(), "locked, nothing held: no drop areas")
C_Spell.PickupSpell(774)
check(ns.heldDrop and rowsOf.above2.hit:IsVisible(), "a spell picked up: every row opens for it")
check(#shownButtons(1) == 0, "the click buttons out of the way meanwhile")
M.CursorOn(rowsOf.above2.hit)
rowsOf.above2.hit._scripts.OnReceiveDrag(rowsOf.above2.hit)
check(#ns.db.rows.above[2] == 1 and ns:EntrySpell(ns.db.rows.above[2][1]) == 774, "dropped on Top 2: added")
check(M.cursorSpell == nil and not ns.heldDrop and rowsOf.above3.hit:IsVisible(), "the cursor empty: the rows open 5 s more, to move it")
for _ = 1, 30 do if not M.timers or #M.timers == 0 then break end M.RunTimer() end -- (the queue drained: the login's too)
check(not rowsOf.above3.hit:IsVisible(), "then closed again")
C_Spell.PickupSpell(774); ClearCursor()
check(not ns.heldDrop and not rowsOf.above3.hit:IsVisible(), "picked up and put back: closed")

out("== dragged from the class spells panel onto the HUD")
ns:SetActiveProfile("DRUID")
local pages = {}
local panel = _G.ClaraComboPointsOptions
-- the Icons page (the panel beside it)
for _, f in ipairs(M.frames) do
  if f.page == 3 and f._scripts and f._scripts.OnClick and f:GetParent() and f:GetParent():GetParent() == panel then f._scripts.OnClick(f) end
end
M.Frame(0.016)
local catalog = _G.ClaraComboPointsSpells
check(catalog and catalog:IsShown(), "the spells panel open on the Icons page")
local group, row
for _, g in ipairs(catalog and catalog.groups or {}) do if g.class == "DRUID" then group = g end end
for _, r in ipairs(group and group.rows or {}) do if r:IsVisible() then row = r; break end end
check(row ~= nil, "a druid spell in the panel")
if row then
  local before = #ns.db.rows.below[2]
  M.mouseDown = true
  row._scripts.OnDragStart(row)
  check(ns.heldDrop and rowsOf.below2.hit:IsVisible(), "the drag started: the HUD's rows open")
  M.CursorOn(rowsOf.below2.hit); M.Frame(0.016)
  M.mouseDown = false; row._scripts.OnDragStop(row)
  check(#ns.db.rows.below[2] == before + 1, "let go on the HUD's Bottom 2: added (" .. before .. " -> " .. #ns.db.rows.below[2] .. ")")
  check(not ns.heldDrop and not rowsOf.below3.hit:IsVisible(), "the drag over: the rows close")
  -- an icon of the window's rows dragged over the HUD, not on a row: kept
  local n = #ns.db.rows.above[1]
  local icon
  for _, f in ipairs(M.frames) do
    if f.landing and f.entry ~= nil and f:IsVisible() and f.index == 1 and f:GetParent() and f:GetParent():IsVisible() then icon = icon or f end
  end
  if icon then
    M.mouseDown = true
    icon._scripts.OnDragStart(icon)
    M.CursorOn(ns.hud); M.Frame(0.016)
    M.mouseDown = false; icon._scripts.OnDragStop(icon)
    local total = 0
    for _, side in ipairs({ "above", "below" }) do for k = 1, 3 do total = total + #ns.db.rows[side][k] end end
    check(total >= n, "an icon let go on the HUD between its rows: not removed")
  end
end
panel:Hide()
check(not ns.heldDrop, "the options closed: nothing held")

out("== a warrior's stances")
for k in pairs(S) do if k ~= "uiScale" and k ~= "physH" then S[k] = nil end end
S.class = "WARRIOR"; S.locale = "enUS"; S.powerType = 1; S.rage = 40
S.forms = { 2457, 71 }; S.form = 2
S.knownSpells = { [100] = true, [11597] = true, [2457] = true, [71] = true }
S.tooltips = { [100] = { "Charge", "Requires Battle Stance" }, [11597] = { "Sunder Armor" } }
M.KNOWN["Charge"] = 100
ClaraComboPointsDB = nil
ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.016)
ns.db.rows.above[1] = { 100, 11597 }
ns:LayoutIcons(); sync()
local wb = {}
for _, b in ipairs(shownButtons(1)) do wb[b.spellID] = b end
check(wb[100] and wb[100]:GetAttribute("macrotext") == "/cast [form:1] Charge; Battle Stance", "Charge in Defensive Stance: Battle Stance first")
check(wb[11597] and wb[11597]:GetAttribute("type1") == "spell", "Sunder Armor: cast as it is")
check(driver(1) == nil and layers()[1]:IsShown(), "one layer, in every stance")
-- icons shown only while lit ("Show missing auras" off): their buttons hidden in a fight by the game's state driver
ns.db.icons.missing = false
ns:LayoutIcons(); sync()
check(driver(1) == "[combat] hide; show", "icons that may go in a fight: their buttons hidden then ([combat] hide): " .. tostring(driver(1)))
ns.db.icons.missing = true
ns:LayoutIcons(); sync()
check(driver(1) == nil, "always shown again: the buttons in a fight too")
-- the HUD at 0 % opacity: no button over it
ns.db.alpha = 0
ns:LayoutIcons(); sync()
check(#shownButtons(1) == 0, "0 % opacity: no button, the clicks go through")
ns.db.alpha = 1
ns:LayoutIcons(); sync()
check(#shownButtons(1) == 2, "opacity back: the buttons back")

local function boot(class, setup)
  for k in pairs(S) do if k ~= "uiScale" and k ~= "physH" then S[k] = nil end end
  S.class = class; S.locale = "enUS"; S.energy = 100; S.rage = 0; S.mana, S.manaMax = 1000, 2000
  setup()
  ClaraComboPointsDB = nil
  ns = {}
  M.LoadAddon(ADDON_DIR, ns)
  M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
  M.Frame(0.016)
end
local function macros()
  local by = {}
  for _, b in ipairs(shownButtons(1)) do by[b.spellID] = b:GetAttribute("macrotext") or ("spell:" .. tostring(b:GetAttribute("spell"))) end
  return by
end

out("== a French client: Feral Charge's requirement lines in lower case")
M.SPELLS[9634] = { "Forme d'ours redoutable", 132276, 0 }; M.SPELLS[768] = { "Forme de félin", 132115, 0 }
M.SPELLS[FC] = { "Charge farouche", 132183, 5 }; M.SPELLS[5229] = { "Enrager", 132126, 0 }
M.KNOWN["Charge farouche"] = FC; M.KNOWN["Enrager"] = 5229
boot("DRUID", function()
  S.powerType = 3; S.forms = { 9634, 768 }; S.form = 2
  S.knownSpells = { [FC] = true, [5229] = true, [9634] = true, [768] = true }
  S.tooltips = {
    [FC] = { "Charge farouche", "Rage : 5", "Nécessite la forme d'ours ou la forme d'ours redoutable", "Vous chargez...", "",
      "Charge farouche (félin)", "Requiert Forme de félin", "Bondit derrière une cible adverse." },
    [5229] = { "Enrager", "Requiert Forme d'ours, Forme d'ours redoutable" },
  }
end)
ns.db.rows.above[1] = { FC, 5229 }
ns:LayoutIcons(); sync()
local fr = macros()
check(fr[FC] == "/cast [form:1] Charge farouche; Forme d'ours redoutable",
  "Charge farouche, left click: Dire Bear Form first: " .. tostring(fr[FC]))
check(fr[5229] == "/cast [form:1] Enrager; Forme d'ours redoutable", "Enrager: bear form first: " .. tostring(fr[5229]))
M.SPELLS[9634] = { "Dire Bear Form", 132276, 0 }; M.SPELLS[768] = { "Cat Form", 132115, 0 }
M.SPELLS[FC] = { "Feral Charge", 132183, 5 }; M.SPELLS[5229] = nil

out("== stealth first: a rogue's Sap, a druid's Pounce")
M.KNOWN["Sap"] = 6770; M.KNOWN["Pounce"] = 9005
boot("ROGUE", function()
  S.powerType = 3; S.energy = 100
  S.knownSpells = { [6770] = true, [1784] = true }
  S.tooltips = { [6770] = { "Sap", "Melee Range" } } -- no requirement line: an opener all the same
end)
ns.db.rows.above[1] = { 6770 }
ns:LayoutIcons(); sync()
check(macros()[6770] == "/cast [stealth] Sap; Stealth", "Sap out of stealth: Stealth first: " .. tostring(macros()[6770]))
boot("ROGUE", function()
  S.powerType = 3; S.energy = 100; S.forms = { 1784 }
  S.knownSpells = { [6770] = true, [1784] = true }
  S.tooltips = { [6770] = { "Sap", "Requires Stealth" } } -- Stealth on the stance bar too
end)
ns.db.rows.above[1] = { 6770 }
ns:LayoutIcons(); sync()
check(macros()[6770] == "/cast [stealth] Sap; Stealth", "with Stealth on the stance bar: the same: " .. tostring(macros()[6770]))
boot("DRUID", function()
  S.powerType = 3; S.forms = { 9634, 768 }; S.form = 2
  S.knownSpells = { [9005] = true, [5215] = true, [768] = true, [9634] = true }
  S.tooltips = { [9005] = { "Pounce", "Requires Cat Form" } }
end)
ns.db.rows.above[1] = { 9005 }
ns:LayoutIcons(); sync()
check(macros()[9005] == "/cast [form:2,stealth] Pounce; [form:2] Prowl; Cat Form",
  "Pounce: Cat Form, then Prowl, then Pounce: " .. tostring(macros()[9005]))

out("== a low level druid: Bear Form only, in caster form")
boot("DRUID", function()
  S.powerType = 0; S.forms = { 5487 }; S.form = 0
  S.knownSpells = { [FC] = true, [5487] = true }
  S.tooltips = { [FC] = { "Feral Charge", "5 Rage", "Requires Bear Form, Dire Bear Form", "Charge an enemy.", "",
    "Feral Charge (Cat)", "Requires Cat Form", "Leap behind an enemy." } }
end)
ns.db.druidCatOnly = false -- (the bar shown out of the forms too)
ns.db.rows.above[1] = { FC }
ns:ApplyAll(); ns:LayoutIcons(); sync()
local low
for n = 1, 2 do for _, b in ipairs(shownButtons(n)) do if b.spellID == FC then low = b end end end
check(low and low:GetAttribute("macrotext") == "/cast [form:1] Feral Charge; Bear Form" and low:GetAttribute("macrotext2") == nil,
  "Feral Charge, no Cat Form yet: Bear Form first, then the charge: " .. tostring(low and low:GetAttribute("macrotext")))
M.casts = {}
if low then low:Click("RightButton") end
check(M.casts[1] == "macro:/cast [form:1] Feral Charge; Bear Form", "the right click too")

out("== Feral Charge's tooltip giving no requirement (as seen in game): the addon's list")
boot("DRUID", function()
  S.powerType = 0; S.forms = { 5487 }; S.form = 0
  S.knownSpells = { [FC] = true, [5487] = true }
  S.tooltips = { [FC] = { "Feral Charge", "5 Rage", "Charge an enemy." } }
end)
ns.db.druidCatOnly = false
ns.db.rows.above[1] = { FC }
ns:ApplyAll(); ns:LayoutIcons(); sync()
local bare
for n = 1, 2 do for _, b in ipairs(shownButtons(n)) do if b.spellID == FC then bare = b end end end
check(bare and bare:GetAttribute("macrotext") == "/cast [form:1] Feral Charge; Bear Form",
  "Bear Form first all the same: " .. tostring(bare and bare:GetAttribute("macrotext")))
local dbg2 = table.concat(ns:DebugClicks(), "\n")
check(dbg2:find("forms from the addon's list", 1, true) and dbg2:find("stance bar: 1=Bear Form", 1, true), "/cl debug says where the form came from")
S.forms = { 5487, 768 }
M.Fire("UPDATE_SHAPESHIFT_FORMS"); sync()
bare = nil
for n = 1, 2 do for _, b in ipairs(shownButtons(n)) do if b.spellID == FC then bare = b end end end
check(bare and bare:GetAttribute("macrotext") == "/cast [form:1] Feral Charge; Bear Form"
  and bare:GetAttribute("macrotext2") == "/cast [form:2] Feral Charge; Cat Form", "Cat Form learned: the right click takes it")

out("== a low level druid in Bear Form: the second click on Feral Charge")
M.SPELLS[1155001] = { "Bear Form", 132276, 0 } -- (the stance bar's Bear Form under another ID than 5487)
boot("DRUID", function()
  S.powerType = 0; S.forms = { 1155001 }; S.form = 0
  S.knownSpells = { [FC] = true, [5487] = true, [6795] = true }
  S.tooltips = { [FC] = { "Feral Charge", "5 Rage", "Charge an enemy." }, [6795] = { "Growl", "Requires Bear Form, Dire Bear Form" } }
  S.target = { cp = 0, hostile = true }
end)
ns.db.druidCatOnly = false
M.SPELLS[19675] = { "Feral Charge", 132183, 0 } -- (the icon watches the charge's root: 19675, as in game)
ns.db.rows.above[1] = { 6795, 19675 }
ns:ApplyAll(); ns:LayoutIcons(); M.Frame(0.3); sync()
check(driver(2) == "[form:1] show; hide", "Bear Form known by its name: a layer placed for it: " .. tostring(driver(2)))
S.form = 1; S.powerType = 1; S.rage = 0
M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("UNIT_DISPLAYPOWER", "player"); M.Frame(0.3); M.Frame(0.3)
sync()
local il, ib = slotRect("above", 1, 2)
local hit
for _, b in ipairs(shownButtons(2)) do if b.spellID == FC then hit = b end end
local bl2, bb2
if hit then bl2, bb2 = rect(hit) end
check(hit and near(il, bl2) and near(ib, bb2), ("in Bear Form, Feral Charge's button on its icon (%.1f,%.1f / %.1f,%.1f)"):format(il or -1, ib or -1, bl2 or -1, bb2 or -1))
check(hit and hit:GetAttribute("macrotext") == "/cast [form:1] Feral Charge; Bear Form", "its click: the charge in Bear Form")
-- in game: in Bear Form the name gives the Bear Form variant, not known itself
M.SPELLS[1238123] = { "Feral Charge", 132183, 5 }
M.KNOWN["Feral Charge"] = 1238123
C_Spell.GetBaseSpell = function(id) if id == 1238123 then return FC end return id end
M.Frame(0.3); sync()
local function fcIn(n) for _, b in ipairs(shownButtons(n)) do if b.spellID == FC then return b end end end
check(fcIn(2) and fcIn(2):GetAttribute("macrotext") == "/cast [form:1] Feral Charge; Bear Form",
  "the name giving the Bear Form variant: still a button, the known spell's (" .. tostring(fcIn(2) and fcIn(2).spellID) .. ")")
C_Spell.GetBaseSpell = nil -- (a variant the game does not tie to its spell: the ID found before)
M.Fire("SPELLS_CHANGED"); M.Frame(0.3); sync()
check(fcIn(2) ~= nil, "no base spell given: the ID known under that name before")
M.KNOWN["Feral Charge"] = FC
local dbg3 = table.concat(ns:DebugClicks(), "\n")
check(dbg3:find("Bear Form 1; form now 1", 1, true) and dbg3:find("icon above 1.2: 19675 at ", 1, true), "/cl debug: the forms, the buttons' and the icons' places")

out(fails .. " failure(s)")
return fails > 0
