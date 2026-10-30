-- druid: the mana bar keeps its place on shapeshifting; a HUD icon drag is called off (never
-- a drop) when the options close on another class's tab or the icons are locked mid-drag
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3 -- Cat Form
S.mana, S.manaMax = 1200, 3000
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100

out("== the mana bar stays put on shapeshifting")
local function centreY(f) M.ResetLayout(); local _, b, _, h = M.AbsRect(f); return b + h / 2 end
M.Frame(0.016)
local cat, catH = centreY(ns.manaBar), ns.hud:GetHeight()
check(ns.comboRow:IsShown() and ns.manaBar:IsShown(), "Cat Form: combo points and mana shown")
S.powerType = 0; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)
check(not ns.comboRow:IsShown() and ns.manaBar:IsShown() and ns.hud:IsShown(), "caster form: mana alone")
check(math.abs(centreY(ns.manaBar) - cat) < 0.01, "the mana bar has not moved")
check(math.abs(ns.hud:GetHeight() - catH) < 0.01, "the HUD keeps its size")
S.powerType = 1; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)
check(math.abs(centreY(ns.manaBar) - cat) < 0.01, "Bear Form: still the same place")
S.powerType = 3; M.Fire("UPDATE_SHAPESHIFT_FORM"); M.Frame(0.016)

out("== a drag ended by the options closing on another class's tab")
local druid = ns.sv.profiles.DRUID
druid.rows.above[1] = { 774, 8921, 1126 }
local function list(t) local o = {} for i, e in ipairs(t) do o[i] = tostring(ns:EntrySpell(e)) end return table.concat(o, ",") end
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
for _, f in ipairs(M.frames) do if f.class == "ROGUE" and f.Click then f:Click() end end
check(ns.profileClass == "ROGUE", "the Rogue tab shows on the HUD")
local rogue = ns.sv.profiles.ROGUE
rogue.rows.above[1] = { 1784, 5171 }
ns:SetIconsLocked(false)
local rowsOf = {}
for _, f in ipairs(M.frames) do if f.hit and f.side then rowsOf[f.side .. f.k] = f end end
local slot = rowsOf.above1.slots[2]
M.CursorOn(slot)
M.mouseDown = true
slot._scripts.OnDragStart(slot)
M.cursorX, M.cursorY = 5, 5 -- off the HUD, the button still held
M.Frame(0.016)
local logged = #M.log
panel:Hide() -- Escape: back to the druid's own profile
M.Frame(0.016)
M.mouseDown = false
M.Frame(0.016)
check(ns.profileClass == "DRUID", "the HUD is back on the druid profile")
check(list(druid.rows.above[1]) == "774,8921,1126", "the druid row is untouched (" .. list(druid.rows.above[1]) .. ")")
check(list(rogue.rows.above[1]) == "1784,5171", "the rogue row is untouched (" .. list(rogue.rows.above[1]) .. ")")
check(#M.log == logged, "nothing said removed")

out("== icons locked during a drag")
ns:SetIconsLocked(false)
M.Frame(0.016)
rowsOf = {}
for _, f in ipairs(M.frames) do if f.hit and f.side then rowsOf[f.side .. f.k] = f end end
slot = rowsOf.above1.slots[1]
check(slot and slot:IsShown() and ns:EntrySpell(druid.rows.above[1][1]) == 774, "a druid icon to drag")
M.CursorOn(slot)
M.mouseDown = true
slot._scripts.OnDragStart(slot)
M.cursorX, M.cursorY = 5, 5
M.Frame(0.016)
SlashCmdList.CLARACOMBOPOINTS("lock") -- a key bound to /cl lock, the button still held
M.Frame(0.016)
M.mouseDown = false
M.Frame(0.016)
check(list(druid.rows.above[1]) == "774,8921,1126", "the icon is still there (" .. list(druid.rows.above[1]) .. ")")
check(math.abs(slot:GetAlpha() - .3) > .01, "the icon is no longer dimmed as dragged (" .. slot:GetAlpha() .. ")")

out("== a drag let go off the HUD still removes the icon")
ns:SetIconsLocked(false)
M.Frame(0.016)
rowsOf = {}
for _, f in ipairs(M.frames) do if f.hit and f.side then rowsOf[f.side .. f.k] = f end end
slot = rowsOf.above1.slots[3]
M.CursorOn(slot)
M.mouseDown = true
slot._scripts.OnDragStart(slot)
M.cursorX, M.cursorY = 5, 5
M.Frame(0.016)
M.mouseDown = false
M.Frame(0.016)
check(list(druid.rows.above[1]) == "774,8921", "removed (" .. list(druid.rows.above[1]) .. ")")
ns:SetIconsLocked(true)

out(("\n%d failure(s)"):format(fails))
return fails
