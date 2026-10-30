-- rv: Improvements tab and the class pages around it; NodeSight standalone opener
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function shownButton(text)
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f.GetText and f:GetText() == text and f:IsVisible() then return f end
  end
end
local function shownText(text)
  for _, r in ipairs(M.regions) do
    if r._text == text and r:IsVisible() then return r end
  end
end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
-- the standalone NodeSight is enabled and loaded (OptionalDeps: before Clara)
C_AddOns = {
  IsAddOnLoaded = function(name) return name == "NodeSight" end,
  DoesAddOnExist = function(name) return name == "NodeSight" end,
  GetAddOnEnableState = function(name) return name == "NodeSight" and 2 or 0 end,
  IsAddOnLoadable = function(name) return name == "NodeSight" end,
}
ClaraComboPointsDB = { qol = { buyemall = false, leatrix = false, wst = false } }
-- the real game's Settings.OpenToCategory: C_SettingsUtil.OpenSettingsPanel(number?)
local opened = {}
Settings.OpenToCategory = function(id, scroll)
  if id ~= nil and type(id) ~= "number" then error("bad argument #1 to 'OpenSettingsPanel' (Usage: C_SettingsUtil.OpenSettingsPanel([openToCategoryID [, scrollToElementName]]))", 2) end
  opened[#opened + 1] = id
end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
check(ns:QolState("nodesight") == "standalone", "nodesight: standalone (" .. tostring(ns:QolState("nodesight")) .. ")")

SlashCmdList.CLARACOMBOPOINTS("")
local panel = ClaraComboPointsOptions
local tab = panel.qolTab
tab:Click()
local name = shownText("NodeSight")
if name then name:GetParent():Click() end
local full = shownButton("All its options")
check(full and full:IsEnabled(), "NodeSight standalone: All its options enabled")
if full then
  local ok, err = pcall(function() full:Click() end)
  check(ok, "click: no Lua error (" .. tostring(err) .. ")")
end
-- the game's options page: its Options button
local cat = ns.qolCategory
if cat then
  M.ShowSettingsPage(cat)
  local b = ns.qolPage.open_nodesight
  check(b and b:IsEnabled(), "game page: NodeSight's Options button enabled")
  if b then
    local ok, err = pcall(function() b:Click() end)
    check(ok, "game page click: no Lua error (" .. tostring(err) .. ")")
  end
end

out("== every class tab and page after the Improvements tab")
local tabs = panel.Tabs
for i = 1, #tabs - 1 do
  tab:Click()
  check(panel.qolView:IsVisible() and not panel.body:IsVisible(), "improvements again before tab " .. i)
  tabs[i]:Click()
  check(not panel.qolView:IsVisible() and panel.body:IsVisible(), "class tab " .. i .. ": pages back")
end
out("")
out(fails .. " failure(s)")
