-- Clique built in (Modules/Clique): its files run only when the module does, with their own table (never Clara's);
-- a binding kept off the target frame ("Not on the target frame": nottarget) is set and cleared in the click
-- snippets only on a frame that does not show the target (TargetFrame, or a frame whose unit is "target"), the other
-- bindings everywhere; the global button (Anywhere) never skips. The standalone Clique enabled: the built-in one
-- steps aside and the standalone's bindings (CliqueDB3) are carried into ClaraCliqueDB, the first time whole, then
-- only this character's own part (another character's profile changed with the built-in one is kept).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  classicui = false, tullarange = false, tooltipanchor = false } }
geterrorhandler = geterrorhandler or function() return function(e) error(e) end end
Mixin = Mixin or function(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
strconcat = strconcat or function(...) return table.concat({ ... }) end
GetModifiedClick = function() return "NONE" end
UnitNameUnmodified = UnitNameUnmodified or function(u) return UnitName(u) end
GetCurrentRegionName = GetCurrentRegionName or function() return "EU" end
GetCurrentRegion = GetCurrentRegion or function() return 3 end
IsBindingForGamePad = IsBindingForGamePad or function() return false end
local ns = {}
S.class = "PRIEST"; S.locale = "frFR"
GetLocale = function() return "frFR" end
-- (the libraries the module's XML loads are not needed here: its saved data is not opened)
M.withClique = true
M.LoadAddon(ADDON_DIR, ns)
if ns:QolState("clique") == nil then out("(no Clique in this version)"); out(""); out("0 failure(s)"); return end
local A = ns.CliquePrivate
check(ns.CliqueRuns == true and type(A) == "table" and A ~= ns, "the module runs, with a table of its own")
check(_G.Clique == A and ns.RegisterEvent == nil and type(A.RegisterEvent) == "function", "the global Clique is its table; Clara's own left alone")
check(A.L and A.L["Not on the target frame"] == "Pas sur le portrait de la cible", "the option's text in French: " .. tostring(A.L and A.L["Not on the target frame"]))

out("== the click snippets: the binding kept off the target frame")
A.settings = { stopcastingfix = false }
A.GetActiveTalentSpec = function() return 1 end
A.bindings = {
  { key = "BUTTON3", type = "spell", spell = "Cure Disease", sets = { default = true }, nottarget = true },
  { key = "SHIFT-BUTTON1", type = "spell", spell = "Renew", sets = { default = true } },
}
local setup, remove, toCombat, toOoc = A:GetClickAttributes(false)
check(type(setup) == "string" and setup:find("local isTarget = name == 'TargetFrame' or button:GetAttribute('unit') == 'target'", 1, true) ~= nil,
  "the frame told apart: TargetFrame, or a frame showing the target")
check(setup:find('if not isTarget then button:SetAttribute("type3", "spell") end', 1, true) ~= nil
  and setup:find('if not isTarget then button:SetAttribute("spell3", "Cure Disease") end', 1, true) ~= nil,
  "Cure Disease on the middle button: set only off the target frame")
check(setup:find('button:SetAttribute("shift-spell1", "Renew")', 1, true) ~= nil
  and not setup:find('isTarget then button:SetAttribute("shift-spell1"', 1, true), "Renew (not kept off): everywhere")
check(remove:find('if not isTarget then button:SetAttribute("type3", nil) end', 1, true) ~= nil,
  "taken away the same way: the target frame's own click left alone")
local ok, fn = pcall(loadstring, "local blacklist, control, self = {}, {}, {}\n" .. setup)
check(ok and fn ~= nil, "the setup snippet is Lua that compiles")
out("== the global button (Anywhere): never skipped")
local gsetup = A:GetClickAttributes(true)
check(gsetup:find("isTarget", 1, true) == nil, "no target test on the global button")
out("== the binding saved without the option: as before")
A.bindings[1].nottarget = nil
setup = A:GetClickAttributes(false)
check(setup:find('if not isTarget then', 1, true) == nil and setup:find('button:SetAttribute("spell3", "Cure Disease")', 1, true) ~= nil,
  "Cure Disease everywhere again")

out("")
out(fails .. " failure(s)")
