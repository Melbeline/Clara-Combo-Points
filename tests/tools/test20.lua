-- a class without the HUD (not in World of Warcraft: Forever): the portrait's menu keeps Reload UI,
-- without the addon's section
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local ns = {}
S.class = "DEATHKNIGHT"; S.locale = "frFR"; S.powerType = 6
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.OpenUnitMenu("SELF")
local order = table.concat(M.UnitMenuTexts(), " | ")
check(order:find("Other Options | Recharger l'interface | Edit Mode", 1, true) ~= nil and not order:find("Clara", 1, true), "Reload UI above Edit Mode, no section (" .. order .. ")")
M.CloseUnitMenu()
check(not ns.hud:IsShown(), "no HUD")
out(("\n%d failure(s)"):format(fails))
return fails
