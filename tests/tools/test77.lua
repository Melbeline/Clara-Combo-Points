-- A fight: every /cl command and the options window's settings, in combat. Prints what the game (the mock: its
-- protected frames) refused, and what did not take effect.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function Run() local n = 0 while M.timers and #M.timers > 0 and n < 200 do M.RunTimer() n = n + 1 end end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false); Run()
for _ = 1, 5 do M.Frame(0.1) end

S.inCombat = true; M.Fire("PLAYER_REGEN_DISABLED"); Run()
local function Blocked(from) local t = {} for i = from + 1, #M.blocked do t[#t + 1] = M.blocked[i] end return table.concat(t, "; ") end
local function Try(label, fn, effect)
  local before = #M.blocked
  local ok, err = pcall(fn)
  Run(); M.Frame(0.1)
  local refused = Blocked(before)
  check(ok and refused == "" and (effect == nil or effect()), label .. (ok and "" or (": error " .. tostring(err))) .. (refused ~= "" and (": refused " .. refused) or ""))
end
local cl = SlashCmdList.CLARACOMBOPOINTS
out("== /cl in a fight")
Try("/cl hide", function() cl("hide") end, function() return not ns.hud:IsShown() end)
Try("/cl show", function() cl("show") end, function() return ns.hud:IsShown() end)
Try("/cl unlock", function() cl("unlock") end, function() return ns.db.locked == false end)
Try("/cl lock", function() cl("lock") end, function() return ns.db.locked == true end)
Try("/cl scale 150", function() cl("scale 150") end)
Try("/cl scale 100", function() cl("scale 100") end)
Try("/cl (the options window)", function() cl("") end, function() return ClaraComboPointsOptions == nil or ClaraComboPointsOptions:IsShown() end)
Try("/cl reset pos", function() cl("reset pos") end)
out("== the options' settings in a fight")
if ns.SetOpacity then Try("opacity 50 %", function() ns:SetOpacity(50) end) end
if ns.SetOpacity then Try("opacity 100 %", function() ns:SetOpacity(100) end) end
S.inCombat = false; M.Fire("PLAYER_REGEN_ENABLED"); Run()
out(string.format("\n%d failure(s)", fails))
return fails
