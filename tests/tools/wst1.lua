-- WaterShieldTracker (standalone): its click-to-cast button (secure) makes its frame protected: in combat the game
-- refuses to show, hide, move or size it. Nothing of that asked in combat (the refresh on each aura change: none
-- blocked), what changed meanwhile done once the fight is over; the charges shown
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70959", "Nov 17 2026", 16001 end

-- (what the mock lacks: animations, a few frame methods; nothing of the addon's own)
local function Stub() local o = {} return setmetatable(o, { __index = function() return function() return o end end }) end
local playing = {}
function M.classes.Region:CreateAnimationGroup()
  local g = Stub()
  g.Play = function(self) playing[self] = true end
  g.Stop = function(self) playing[self] = nil end
  g.IsPlaying = function(self) return playing[self] == true end
  g.CreateAnimation = function() return Stub() end
  g.SetLooping = function() end
  return g
end
for _, n in ipairs({ "SetClampedToScreen", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetNormalTexture",
  "SetHighlightTexture", "SetPushedTexture", "RegisterForClicks", "SetDesaturated", "SetVertexColor", "SetTexCoord" }) do
  if not M.classes.Region[n] then M.classes.Region[n] = function() end end
end
GetCursorPosition = GetCursorPosition or function() return 0, 0 end

S.class = "ROGUE"; S.locale = "frFR"
WaterShieldTrackerDB = nil
local ns = {}
M.LoadAddonAs(ADDON_DIR, "WaterShieldTracker.toc", "WaterShieldTracker", ns)
M.Fire("ADDON_LOADED", "WaterShieldTracker")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
local frame = WaterShieldTrackerFrame
check(frame and frame._protected, "its frame protected (its secure button inside), as in the game")
check(not frame:IsShown(), "a rogue: hidden")

out("== a rogue in combat: the aura changes, no call refused (the 103 errors)")
M.blocked = {}
S.inCombat = true
for _ = 1, 103 do M.Fire("UNIT_AURA", "player") end
check(#M.blocked == 0, ("none refused (%d)%s"):format(#M.blocked, M.blocked[1] and (": " .. M.blocked[1]) or ""))
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")

out("== shown on every class, then the charges")
WaterShieldTrackerDB.allClasses = true
frame:Refresh()
check(frame:IsShown(), "shown out of combat")
S.auras = { player = { { name = "Bouclier d'eau", spellId = 409941, applications = 3 } } }
M.blocked = {}
S.inCombat = true
for _ = 1, 20 do M.Fire("UNIT_AURA", "player") end
check(#M.blocked == 0, "in combat, each aura change: none refused (" .. #M.blocked .. ")")
local three = false
for _, r in ipairs(M.regions) do if r._parent == frame and tostring(r._text) == "3" then three = true end end
check(three, "its 3 charges on the icon")
check(frame:IsShown(), "still shown")

out("== changed in combat: done once the fight is over")
WaterShieldTrackerDB.show = false
frame:Refresh()
WaterShieldTrackerDB.size = 60
frame:ApplyLayout()
SlashCmdList.WATERSHIELDTRACKER("reset")
check(#M.blocked == 0, "hidden, sized, put back: nothing asked in combat (" .. #M.blocked .. ")")
check(frame:IsShown(), "still shown while the fight lasts")
S.inCombat = false
M.Fire("PLAYER_REGEN_ENABLED")
check(not frame:IsShown(), "the fight over: hidden")
check(math.abs((frame:GetWidth() or 0) - 60) < 0.01, "and sized (" .. tostring(frame:GetWidth()) .. ")")
WaterShieldTrackerDB.show = true
frame:Refresh()
check(frame:IsShown(), "shown again")
out(string.format("\n%d failure(s)", fails))
return fails
