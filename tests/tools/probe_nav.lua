local M, S = MOCK, MOCK.state
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false } }
local ns = {}
S.class = "ROGUE"; S.locale = "frFR"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
panel.qolTab:Click()
local view = panel.qolView
io.write("window h", panel:GetHeight(), "view top", view:GetTop(), "view bottom", view:GetBottom(), "modules", #ns.QOL_MODULES, "\n")
local low
for _, r in ipairs(M.regions) do
  for _, m in ipairs(ns.QOL_MODULES) do
    if r._text == ns.L["QOL_NAV_" .. m.key:upper()] and r:IsVisible() then
      local b = r:GetParent(); io.write(m.key, " ", tostring(b:GetTop()), " ", tostring(b:GetBottom()), "\n")
    end
  end
end
