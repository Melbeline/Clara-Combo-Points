-- Enemy Casts (Modules/EnemyCasts): an enemy's casts and instant spells beside its nameplate, each
-- plate's unit listened to on its own, secret spells drawn without being read
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false, idtip = false, soloraidframe = false } }

-- animation groups that play out with the mock's clock
local groups = {}
function M.classes.Frame:CreateAnimationGroup()
  local g = { anims = {}, scripts = {}, playing = false }
  function g:CreateAnimation()
    local a = { delay = 0, duration = 0 }
    function a:SetFromAlpha() end
    function a:SetToAlpha() end
    function a:SetDuration(d) self.duration = d end
    function a:SetStartDelay(d) self.delay = d end
    self.anims[#self.anims + 1] = a
    return a
  end
  function g:SetScript(name, fn) self.scripts[name] = fn end
  function g:Play() self.playing, self.started = true, GetTime() end
  function g:Stop() self.playing = false end
  function g:IsPlaying() return self.playing end
  groups[#groups + 1] = g
  return g
end
local function Tick(dt)
  M.now = (M.now or 0) + dt
  for _, g in ipairs(groups) do
    local a = g.anims[1]
    if g.playing and GetTime() - g.started >= a.delay + a.duration then
      g.playing = false
      if g.scripts.OnFinished then g.scripts.OnFinished(g) end
    end
  end
end

-- the nameplates, their health bars; spells; units
local plates = {}
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end }
local function Plate(unit)
  local p = CreateFrame("Frame", nil, UIParent)
  p.UnitFrame = CreateFrame("Frame", nil, p)
  p.UnitFrame.healthBar = CreateFrame("Frame", nil, p.UnitFrame)
  plates[unit] = p
  return p
end
M.SPELLS[133] = { "Fireball", 135812 }
M.SPELLS[2139] = { "Counterspell", 135856 }
M.SPELLS[1953] = { "Blink", 135736 }
M.SPELLS[10] = { "Blizzard", 135857 }
M.SPELLS[75] = { "Auto Shot", 132369 }
M.SPELLS[6660] = { "Shoot", 132222 }
local getTexture, getName = C_Spell.GetSpellTexture, C_Spell.GetSpellName
C_Spell.GetSpellTexture = function(s)
  if issecretvalue(s) then return M.Secret(getTexture(M.reveal(s))) end
  return getTexture(s)
end
C_Spell.GetSpellName = function(s)
  if issecretvalue(s) then return M.Secret(getName(M.reveal(s))) end
  return getName(s)
end
S.units = { nameplate1 = { attackable = true }, nameplate2 = { attackable = false }, nameplate3 = { attackable = true } }

-- the game's dropdowns and sliders on its option pages
local made = {}
Settings.CreateDropdown = function(c, setting, options)
  made[setting.variable] = options(); return {} end
Settings.CreateControlTextContainer = Settings.CreateControlTextContainer or function()
  local data = {}
  return { Add = function(_, value, label) data[#data + 1] = { value = value, label = label } end, GetData = function() return data end }
end
Settings.CreateSliderOptions = function(low, high, step)
  return { low = low, high = high, step = step, SetLabelFormatter = function(self, _, fn) self.format = fn end }
end
Settings.CreateSlider = function(c, setting, options) made[setting.variable] = options; return {} end
MinimalSliderWithSteppersMixin.Label = MinimalSliderWithSteppersMixin.Label or { Right = 1 }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
local EC = ns.EnemyCasts

out("== its place")
check(ns:QolRuns("enemycasts") and EC ~= nil, "runs by default")
local page = M.subcategories and M.subcategories["Enemy Casts"]
check(page and page.parent == ns.qolThemes.combat and ns.enemyCastsCategory == page, "its page under Combat")
local names = {}
for _, s in ipairs(page and page.settings or {}) do names[#names + 1] = s.variable:gsub("ClaraEnemyCasts_", "") end
check(table.concat(names, ",") == "casts,instants,names,enemiesOnly,position,size,count,hold", "its settings: " .. table.concat(names, ","))
local where = made.ClaraEnemyCasts_position or {}
check(#where == 3 and where[1].value == "left" and where[3].label == "Above the nameplate", "its three positions")
local hold = made.ClaraEnemyCasts_hold
check(hold and hold.low == 1 and hold.high == 8 and hold.format(2.5) == "2.5 s", "how long an instant stays: 1 to 8 s")
check(#(ns.qolSwitches.enemycasts or {}) == 2, "two boxes in the Improvements tab")
check(ns:CanOpenQol("enemycasts"), "its page opens from the Improvements tab")

out("== a cast")
local p1 = Plate("nameplate1")
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(EC.listeners.nameplate1 ~= nil, "the plate's unit listened to")
M.Fire("UNIT_SPELLCAST_START", "nameplate1", "Cast-1", 133)
local row = EC.rows.nameplate1
local icon = row and row[1]
check(icon and icon:IsShown() and icon.texture:GetTexture() == 135812 and icon.name:GetText() == "Fireball", "its icon and name")
local point, rel, relPoint = icon:GetPoint(1)
check(point == "RIGHT" and rel == p1.UnitFrame.healthBar and relPoint == "LEFT", "left of the plate's health bar")
check(icon:GetParent() == p1.UnitFrame.healthBar and not icon.fade:IsPlaying(), "held while it is cast")
M.Fire("UNIT_SPELLCAST_STOP", "nameplate1", "Cast-1", 133)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-1", 133)
check(#row == 1 and icon.fade:IsPlaying() and icon.fadeOut.delay == 1.5, "ended: it fades, no second icon for its success")
Tick(2.1)
check(#row == 0 and not icon:IsShown(), "faded out: gone")

out("== instants, in a row")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-2", 2139)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-3", 1953)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-4", 75)
check(#row == 2 and row[1].name:GetText() == "Blink" and row[2].name:GetText() == "Counterspell", "two instants, the newest first (no auto shot)")
check(row[1].fade:IsPlaying() and row[1].fadeOut.delay == 3, "each fades after 3 s")
check(row[1].name:IsShown() and not row[2].name:IsShown(), "the newest's name only")
local _, rel2, relPoint2 = row[2]:GetPoint(1)
check(rel2 == row[1] and relPoint2 == "LEFT", "the older one left of it")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-5", 133)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-6", 2139)
check(#row == 3 and row[1].name:GetText() == "Counterspell" and row[3].name:GetText() == "Blink", "three at most: the oldest goes")
Tick(4)
check(#row == 0, "all faded out")

out("== secret, interrupted")
M.Fire("UNIT_SPELLCAST_START", "nameplate1", M.Secret("Cast-7"), M.Secret(133))
icon = row[1]
check(icon and issecretvalue(icon.texture:GetTexture()) and issecretvalue(icon.name:GetText()), "a secret spell drawn as the game gives it")
check(M.reveal(icon.texture:GetTexture()) == 135812, "(its icon)")
M.Fire("UNIT_SPELLCAST_STOP", "nameplate1", M.Secret("Cast-7"), M.Secret(133))
M.Fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate1", M.Secret("Cast-7"), M.Secret(133), M.Secret("Player-1"))
check(icon.frame._color and icon.frame._color[1] > 0.5 and icon.frame._color[2] < 0.2, "interrupted after its stop: red")
check(icon.fade:IsPlaying(), "and fading")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", M.Secret("Cast-7"), M.Secret(133))
check(#row == 1, "its success just after: no new icon")
Tick(3)
M.Fire("UNIT_SPELLCAST_START", "nameplate1", "Cast-8", 133)
icon = row[1]
M.Fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate1", "Cast-8", 133, "Player-1")
M.Fire("UNIT_SPELLCAST_STOP", "nameplate1", "Cast-8", 133)
check(icon.frame._color[1] > 0.5 and icon.fade:IsPlaying(), "interrupted before its stop: red too")
check(#row == 1 and EC.listeners.nameplate1.casting == nil, "one icon, the cast over")
Tick(3)

out("== a channel")
M.Fire("UNIT_SPELLCAST_CHANNEL_START", "nameplate1", "Cast-9", 10)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-9", 10)
icon = row[1]
check(#row == 1 and not icon.fade:IsPlaying(), "held through its own success")
M.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "nameplate1", "Cast-9", 10)
check(icon.fade:IsPlaying() and icon.frame._color[1] == 0, "fades as it stops")
Tick(3)

out("== a channel whose success comes first")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-9b", 10)
M.Fire("UNIT_SPELLCAST_CHANNEL_START", "nameplate1", "Cast-9b", 10)
icon = row[1]
check(#row == 1 and not icon.fade:IsPlaying() and icon:GetAlpha() == 1, "one icon, held")
Tick(5)
check(#row == 1 and icon:IsShown(), "still there while it channels")
M.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "nameplate1", "Cast-9b", 10)
check(icon.fade:IsPlaying(), "fades as it stops")
Tick(3)

out("== a cast whose end was missed")
M.Fire("UNIT_SPELLCAST_START", "nameplate1", "Cast-9c", 133)
local first = row[1]
M.Fire("UNIT_SPELLCAST_START", "nameplate1", "Cast-9d", 133)
check(#row == 2 and first.fade:IsPlaying() and not row[1].fade:IsPlaying(), "the old one fades, the new one is held")
M.Fire("UNIT_SPELLCAST_STOP", "nameplate1", "Cast-9d", 133)
Tick(3)
M.Fire("UNIT_SPELLCAST_START", "nameplate1", "Cast-9e", 6660)
check(#row == 0, "a creature's shot: not shown")
M.Fire("UNIT_SPELLCAST_STOP", "nameplate1", "Cast-9e", 6660)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-9e", 6660)
check(#row == 0, "nor its end")

out("== an instant during a cast")
M.Fire("UNIT_SPELLCAST_START", "nameplate1", "Cast-10", 133)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-11", 1953)
check(#row == 2 and row[1].name:GetText() == "Blink" and not row[2].fade:IsPlaying(), "shown in front, the cast still held")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-10", 133)
check(row[2].fade:IsPlaying(), "the cast's own success: it fades")
Tick(4)

out("== friends, other plates")
Plate("nameplate2")
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate2", "Cast-12", 1953)
check(EC.rows.nameplate2 == nil or #EC.rows.nameplate2 == 0, "a friend: nothing")
check(#row == 0, "nor on the other plate")
ns.EnemyCastsSet("enemiesOnly", false)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate2", "Cast-13", 1953)
check(EC.rows.nameplate2 and #EC.rows.nameplate2 == 1, "everyone: shown")
check(ClaraComboPointsDB.enemyCasts and ClaraComboPointsDB.enemyCasts.enemiesOnly == false, "saved, only what differs")
ns.EnemyCastsSet("enemiesOnly", true)
check(ClaraComboPointsDB.enemyCasts == nil, "back to the default: nothing saved")

out("== its look")
ns.EnemyCastsSet("position", "right")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-14", 1953)
point, rel, relPoint = row[1]:GetPoint(1)
check(point == "LEFT" and relPoint == "RIGHT", "right of the plate")
ns.EnemyCastsSet("position", "above")
point, rel, relPoint = row[1]:GetPoint(1)
check(point == "BOTTOM" and relPoint == "TOP", "above it, moved at once")
local npoint = row[1].name:GetPoint(1)
check(npoint == "BOTTOM", "its name above the icon")
ns.EnemyCastsSet("size", 40)
check(row[1]:GetWidth() == 40, "its size")
ns.EnemyCastsSet("names", false)
check(not row[1].name:IsShown(), "no name")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-14b", 1953)
ns.EnemyCastsSet("count", 1)
check(#row == 1, "one icon kept, at once")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-15", 2139)
check(#row == 1, "and after")
ns.EnemyCastsSet("casts", false)
M.Fire("UNIT_SPELLCAST_START", "nameplate1", "Cast-16", 133)
check(#row == 1 and row[1].name:GetText() == "Counterspell", "casts off: not shown")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-16", 133)
check(#row == 1 and row[1].name:GetText() == "Counterspell", "nor its success as an instant")
for _, k in ipairs({ "position", "size", "names", "count", "casts" }) do ns.EnemyCastsSet(k, nil) end
ns.EnemyCastsSet("position", "left"); ns.EnemyCastsSet("size", 30); ns.EnemyCastsSet("names", true)
ns.EnemyCastsSet("count", 3); ns.EnemyCastsSet("casts", true)
check(ClaraComboPointsDB.enemyCasts == nil, "defaults again")

out("== the plate goes")
local pooled = row[1]
M.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(EC.listeners.nameplate1 == nil and EC.rows.nameplate1 == nil and not pooled:IsShown(), "listener and icons put away")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-17", 1953)
check(EC.rows.nameplate1 == nil, "its unit not heard any more")
local p3 = Plate("nameplate3")
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate3", "Cast-18", 1953)
check(EC.rows.nameplate3[1] == pooled and pooled:GetParent() == p3.UnitFrame.healthBar, "its icon used again on another plate")
plates.nameplate1 = nil
M.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-19", 1953)
check(EC.rows.nameplate1 == nil, "a plate the game won't give: nothing")
p3.IsForbidden = function() return true end
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "nameplate3", "Cast-20", 2139)
check(#EC.rows.nameplate3 == 1, "a forbidden plate: nothing more on it")

out("== its name on its theme's page")
local lang = ns.lang
ns.lang = "frFR"
M.ShowSettingsPage(ns.qolThemes.combat)
local box = ns.qolThemePages.combat.check_enemycasts
check(box and (box.Text or box.text):GetText() == "Actions ennemies", "in French: " .. tostring(box and (box.Text or box.text):GetText()))
M.ShowSettingsPage(ns.qolThemes.economy)
check((ns.qolThemePages.economy.check_mail.Text or ns.qolThemePages.economy.check_mail.text):GetText() == "Courrier", "(Mail: Courrier)")
ns.lang = lang

out("== turned off")
local ns2 = {}
ClaraComboPointsDB = { qol = { lfgforever = false, enemycasts = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false, idtip = false, soloraidframe = false } }
M.LoadAddon(ADDON_DIR, ns2)
check(ns2.EnemyCasts == nil and ns2:CanOpenQol("enemycasts"), "nothing runs (its opener still set)")

out(fails .. " failures")
