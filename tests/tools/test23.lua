-- the warrior's rage bar turned off: the icon rows stay, on the HUD itself
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local ns = {}
S.class = "WARRIOR"; S.locale = "deDE"; S.powerType = 1; S.rage = 40
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.now = 100
M.Frame(0.016)
check(#ns.db.rows.above[1] > 0 and ns.powerBar:IsShown(), "a rage bar and the warrior's icons")
ns:SetElementOn("rage", false)
check(not ns.powerBar:IsShown() and ns.hud:IsShown() and ns.iconLayer:IsVisible(), "rage bar off: the icons still show")
local row
for _, f in ipairs(M.frames) do if f.slots and f.side == "above" and f.k == 1 then row = f end end
check(row and row:IsVisible(), "the first row is shown")
ns:SetElementOn("rage", true)
check(ns.powerBar:IsShown(), "back on")
out(("\n%d failure(s)"):format(fails))
return fails
