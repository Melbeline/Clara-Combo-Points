-- rv: the user's case. A level 16 druid, Bear Form only (5487, stance 1), "Cat and Bear Form
-- only" off: caster form shows the HUD (energy 100, mana). An enemy targeted, 0 points, out of
-- combat. Shift to Bear Form; is there a button of a shown layer under each top-row icon?
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function near(a, b, e) return a and b and math.abs(a - b) < (e or 0.05) end

local FC = 1238122
local NG, DEMO, BASH, GROWL, ENRAGE = 16689, 99, 5211, 6795, 5229
local ROOTS, REJUV, REGROWTH, THORNS, MOTW, WOA = 339, 774, 8936, 467, 1126, 1259416
M.SPELLS[NG] = { "Nature's Grasp", 136063, 0 }; M.SPELLS[DEMO] = { "Demoralizing Roar", 132121, 10 }
M.SPELLS[BASH] = { "Bash", 132114, 10 }; M.SPELLS[GROWL] = { "Growl", 132270, 0 }; M.SPELLS[ENRAGE] = { "Enrage", 132126, 0 }
M.SPELLS[ROOTS] = { "Entangling Roots", 136100, 0 }; M.SPELLS[REGROWTH] = { "Regrowth", 136085, 0 }
M.SPELLS[THORNS] = { "Thorns", 136104, 0 }; M.SPELLS[MOTW] = { "Mark of the Wild", 136078, 0 }
for id, row in pairs(M.SPELLS) do if id == NG or id == DEMO or id == BASH or id == GROWL or id == ENRAGE or id == ROOTS
  or id == REGROWTH or id == THORNS or id == MOTW or id == FC or id == REJUV then M.KNOWN[row[1]] = id end end

local ns
local function boot(class, setup)
  for k in pairs(S) do if k ~= "uiScale" and k ~= "physH" then S[k] = nil end end
  S.class = class; S.locale = "enUS"; S.energy = 100; S.energyMax = 100; S.rage = 0; S.mana, S.manaMax = 1000, 2000
  setup()
  ClaraComboPointsDB = nil
  ns = {}
  M.LoadAddon(ADDON_DIR, ns)
  M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
  M.Frame(0.016)
end
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
  if not found or not found:IsVisible() then return end
  M.ResetLayout()
  local l, b, w, h = M.AbsRect(found)
  local ui = UIParent:GetEffectiveScale()
  return l / ui, b / ui, w / ui, h / ui
end
local function rect(b)
  local p = b._points and b._points[1]
  return p and p[4], p and p[5], b:GetWidth(), b:GetHeight()
end

-- the secure state driver, as the game evaluates it ("[form:1] show; hide", "[form:1] hide; show")
local function driverShows(n)
  local layer = layers()[n]
  if not layer then return false end
  local d = M.stateDrivers[layer]
  if not d then return layer:IsShown() end
  local form = GetShapeshiftForm()
  for clause in d[2]:gmatch("[^;]+") do
    local cond, action = clause:match("^%s*%[([^%]]*)%]%s*(%a+)%s*$")
    if not cond then action = clause:match("^%s*(%a+)%s*$"); return action == "show" end
    local ok = true
    for part in cond:gmatch("[^,]+") do
      local list = part:match("^form:(.+)$")
      if list then
        local any = false
        for n2 in list:gmatch("%d+") do if tonumber(n2) == form then any = true end end
        ok = ok and any
      end
    end
    if ok then return action == "show" end
  end
  return false
end

-- what is under a point (UIParent units): the button of a shown layer, if any
local function hit(x, y)
  for n = 1, 2 do
    if driverShows(n) then
      for _, b in ipairs(shownButtons(n)) do
        local l, bt, w, h = rect(b)
        if x >= l and x <= l + w and y >= bt and y <= bt + h then return b, n end
      end
    end
  end
end

local TOP = { NG, DEMO, BASH, GROWL, FC, ENRAGE }
local BOTTOM = { ROOTS, REJUV, REGROWTH, THORNS, MOTW, WOA }
local function report(tag)
  local all = true
  for side, list in pairs({ above = TOP, below = BOTTOM }) do
    for i, id in ipairs(list) do
      local l, b, w, h = slotRect(side, 1, i)
      if l then
        local btn, n = hit(l + w / 2, b + h / 2)
        local good = btn and btn.spellID == id
        if not good then all = false end
        out(("  %s %s #%d %-18s icon at %.1f,%.1f -> %s"):format(tag, side, i, M.SPELLS[id][1], l, b,
          btn and ("button %d.%s (%s)%s"):format(n, tostring(btn.spellID), tostring(btn:GetAttribute("macrotext") or btn:GetAttribute("spell")),
            good and "" or " WRONG SPELL") or "NOTHING: the click goes to the world"))
      else
        out(("  %s %s #%d %s: icon not shown"):format(tag, side, i, M.SPELLS[id][1]))
      end
    end
  end
  return all
end

local function setupDruid()
  S.powerType = 0; S.forms = { 5487 }; S.form = 0
  S.knownSpells = { [FC] = true, [5487] = true, [NG] = true, [DEMO] = true, [BASH] = true, [GROWL] = true, [ENRAGE] = true,
    [ROOTS] = true, [REJUV] = true, [REGROWTH] = true, [THORNS] = true, [MOTW] = true, [WOA] = true }
  S.tooltips = {
    [FC] = { "Feral Charge", "5 Rage", "Charge an enemy." },
    [DEMO] = { "Demoralizing Roar", "10 Rage", "Requires Bear Form" },
    [BASH] = { "Bash", "10 Rage", "Requires Bear Form" },
    [GROWL] = { "Growl", "Requires Bear Form" },
    [ENRAGE] = { "Enrage", "Requires Bear Form" },
  }
  S.target = { cp = 0, hostile = true }
end

local function shift(form, power, order)
  S.form = form; S.powerType = power
  for _, e in ipairs(order) do
    if e == "UNIT_DISPLAYPOWER" then M.Fire(e, "player") elseif e == "frame" then M.Frame(0.3) else M.Fire(e) end
  end
end

local function caseRun(title, opts)
  out("== " .. title)
  boot("DRUID", function() setupDruid(); if opts.setup then opts.setup() end end)
  ns.db.druidCatOnly = false
  ns.db.rows.above[1] = { NG, DEMO, BASH, GROWL, FC, ENRAGE }
  ns.db.rows.below[1] = { ROOTS, REJUV, REGROWTH, THORNS, MOTW, WOA }
  ns:ApplyAll(); ns:LayoutIcons(); M.Frame(0.3); M.Frame(0.3)
  sync()
  out(("  caster: power bar %s, iconsOnBar %s, drivers 1=%s 2=%s"):format(tostring(ns:GetPowerType()), tostring(ns.iconsOnBar),
    tostring(driver(1)), tostring(driver(2))))
  check(report("caster"), "caster form: every icon has its own button under it")
  local predicted = {}
  for _, b in ipairs(shownButtons(2)) do local l, bt = rect(b); predicted[b.spellID] = { l, bt } end
  opts.shift()
  for _ = 1, 8 do M.Frame(0.3) end -- 2.4 s: the hud's refresh, the clicks' ticker (every 0.25 s)
  out(("  bear: form %d, UnitPowerType %d, power bar %s, iconsOnBar %s, drivers 1=%s 2=%s"):format(GetShapeshiftForm(), S.powerType,
    tostring(ns:GetPowerType()), tostring(ns.iconsOnBar), tostring(driver(1)), tostring(driver(2))))
  local l, b = slotRect("above", 1, 5)
  local p = predicted[FC]
  local now
  for _, bt in ipairs(shownButtons(2)) do if bt.spellID == FC then now = { rect(bt) } end end
  out(("  Feral Charge icon in Bear Form at %.1f,%.1f; layer 2 button predicted in caster form at %.1f,%.1f, now at %.1f,%.1f"):format(
    l or -1, b or -1, p and p[1] or -1, p and p[2] or -1, now and now[1] or -1, now and now[2] or -1))
  check(report("bear"), "Bear Form: every icon has its own button under it")
end

caseRun("A. the user's case as described: 0 points, form + power events", { shift = function()
  S.form = 1; S.powerType = 1
  M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("UNIT_DISPLAYPOWER", "player"); M.Fire("UPDATE_SHAPESHIFT_FORMS")
end })
caseRun("A2. 0 points, UNIT_DISPLAYPOWER before the form event, SPELLS_CHANGED too", { shift = function()
  S.form = 1; S.powerType = 1
  M.Fire("UNIT_DISPLAYPOWER", "player"); M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("SPELLS_CHANGED")
end })
caseRun("B. points left on the enemy (1), out of combat", { setup = function() S.target = { cp = 1, hostile = true } end, shift = function()
  S.form = 1; S.powerType = 1
  M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("UNIT_DISPLAYPOWER", "player")
end })
caseRun("C. the combo count secret (unreadable), out of combat", { setup = function() S.secret = true end, shift = function()
  S.form = 1; S.powerType = 1
  M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("UNIT_DISPLAYPOWER", "player")
end })
caseRun("D. the form events before the power type changes, no UNIT_DISPLAYPOWER after", { shift = function()
  S.form = 1
  M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Fire("UPDATE_SHAPESHIFT_FORMS")
  S.powerType = 1 -- (changed with no event after it)
end })

out(fails .. " failure(s)")
return fails > 0
