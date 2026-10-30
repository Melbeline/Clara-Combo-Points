-- rv: switching tabs/pages/profiles/language while on the Improvements tab
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, nodesight = false, wst = false } }
local ns = {}
S.class = "DRUID"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
local function nav(i) for _, f in ipairs(M.frames) do if f._kind == "Button" and f.page == i and f.name and f.desc and f:IsVisible() then return f end end end
nav(3):Click()
local side = ClaraComboPointsSpells
check(side:IsShown(), "icons page: spells panel shown")
panel.qolTab:Click()
check(not side:IsShown(), "improvements: spells panel hidden")
-- things that happen while on it
local ok, err = pcall(function()
  ns:SetLanguage("deDE"); ns:SetLanguage("frFR"); ns:SetLanguage("enUS")
  ns:SetActiveProfile("ROGUE")
  ns:SetLocked(false); ns:SetLocked(true)
  ns.sv.window.w, ns.sv.window.h = 700, 560; panel:Resize()
  ns:SetPreview(false); ns:SetPreview(true)
  ns:ResetAddon()
end)
check(ok, "language, profile, lock, size, preview, reset while on it: no error " .. tostring(err))
check(panel.qolView:IsVisible() and not panel.body:IsVisible() and not side:IsShown(), "still the Improvements view")
-- back to a class: its page (icons), the panel again
panel.Tabs[1]:Click()
check(panel.body:IsVisible() and not panel.qolView:IsVisible(), "a class tab: pages back")
nav(3):Click()
check(side:IsShown(), "icons page: spells panel again")
for i = 1, 5 do nav(i):Click(); check(panel.body:IsVisible(), "page " .. i .. " shown") end
-- Improvements, close, reopen
panel.qolTab:Click(); panel:Hide(); SlashCmdList.CLARACOMBOPOINTS("")
check(panel.body:IsVisible() and not panel.qolView:IsVisible(), "reopened: class pages")
check(ns.profileClass == "DRUID", "reopened: the character's profile")
out(fails .. " failure(s)")
