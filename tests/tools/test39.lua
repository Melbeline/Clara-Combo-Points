-- The class spells panel shut by hand opens again with a click on the Icons page
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local ns = {}
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3; S.energy = 100
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function goPage(n)
  for _, f in ipairs(M.frames) do
    if f.page == n and f._scripts and f._scripts.OnClick and f:IsVisible() then f._scripts.OnClick(f) return true end
  end
end
ns:ShowOptions(); M.Frame(0.016)
local catalog = _G.ClaraComboPointsSpells
goPage(3); M.Frame(0.016)
check(catalog:IsShown(), "the Icons page: the class spells panel beside the window")
local close
for _, f in ipairs(M.frames) do
  if f._parent == catalog and f._kind == "Button" and f._template == "UIPanelCloseButton" then close = f end
end
if not close then
  for _, f in ipairs(M.frames) do if f._parent == catalog and f._kind == "Button" and f._scripts and f._scripts.OnClick and f._points and f._points[1] and f._points[1][1] == "TOPRIGHT" then close = f end end
end
check(close ~= nil, "its close button")
close._scripts.OnClick(close); M.Frame(0.016)
check(not catalog:IsShown(), "shut by hand: hidden")
ns:RefreshOptions(); M.Frame(0.016)
check(not catalog:IsShown(), "the window refreshed: still shut")
goPage(3); M.Frame(0.016)
check(catalog:IsShown(), "a click on Icons: open again")
close._scripts.OnClick(close); M.Frame(0.016)
goPage(1); M.Frame(0.016)
check(not catalog:IsShown(), "another page: not there")
goPage(3); M.Frame(0.016)
check(catalog:IsShown(), "back on Icons from another page: open again")
out("")
out(fails .. " failure(s)")
