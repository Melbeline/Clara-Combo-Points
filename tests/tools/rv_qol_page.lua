-- rv: the Interface improvements page in the game's options: the hint over the first module?
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, nodesight = false, wst = false } }
local ns = {}
S.class = "ROGUE"; S.locale = os.getenv("RV_LOCALE") or "deDE"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.ShowSettingsPage(ns.qolCategory)
local page = ns.qolPage
local hint
for _, r in ipairs(M.regions) do if r._parent == page and r._text == ns.L.QOL_HINT then hint = r end end
local hl, hb, hw, hh = M.Rect(hint)
out(("hint string width %.0f over %.0f px: %.1f lines"):format(hint:GetStringWidth(), hw, hint:GetStringWidth() / hw))
local cl, cb, cw, ch = M.Rect(page.check_buyemall)
out(("hint bottom %.1f (h %.1f, %d lines?), first box top %.1f"):format(hb, hh, hh / 12, cb + ch))
check(hb >= cb + ch - 1, "the hint ends above the first module's box")
-- status lines vs next module
for i, m in ipairs(ns.QOL_MODULES) do
  local nextm = ns.QOL_MODULES[i + 1]
  ns.QolState = function() return "standalone" end
  ns:RefreshQol()
end
out(fails .. " failure(s)")
