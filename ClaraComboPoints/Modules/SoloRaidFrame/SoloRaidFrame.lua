-- Clara Combo Points - Solo Raid Frame NV 2.5 (by Spridan), built in (QoL.lua): the game's raid-style
-- party frame (CompactPartyFrame) kept shown while not in a group, so one's own frame is there solo
-- too. In a group, the game's own rule (left alone). No setting of its own. Solo Raid Frame's standalone
-- addon is turned off for the character while this one runs.
-- Never shown by the addon's own code: a frame an addon shows runs the game's whole set-up of its unit
-- frames in the addon's name (OnShow, then each update after it), and with WoW Forever's secret health
-- every one of those updates fails ("attempt to compare a secret number value, while execution tainted"),
-- many times a second, Edit Mode's party frames too. The game's secure state driver shows it
-- ("visibility": "show" solo, nothing in a group), looking again five times a second and at once as the
-- group changes: a frame the game hides as a group ends is shown again at once, in a fight too.
-- Even that driver is put on the frame by the game's own code: a driver an addon registers is applied at
-- once, from the addon's code (the frame shown in its name). So the addon only arms a secure handler of
-- its own, whose state the game's driver manager sets a fifth of a second later (secure): the handler's
-- restricted code then registers the frame's driver, which shows it, all of it the game's.

local ADDON, ns = ...

if not ns:QolRuns("soloraidframe") then return end

local events = CreateFrame("Frame")
-- In a group: "game", a value the driver leaves alone (only "show" and "hide" move the frame)
local RULE = "[group] game; show"
ns.SoloRaidFrameRule = RULE -- (for the tests)

-- The handler's restricted code: on the manager's "go" once armed, the frame's own driver registered (once)
local ARM = ([[
  if newstate ~= "go" or not self:GetAttribute("armed") or self:GetAttribute("driving") then return end
  local party = self:GetFrameRef("party")
  if not party then return end
  self:SetAttribute("driving", true)
  RegisterStateDriver(party, "visibility", %q)
]]):format(RULE)

local driver
local function Drive()
  local f = CompactPartyFrame
  if driver or not f or not (RegisterStateDriver and SecureHandlerSetFrameRef) then return end
  if InCombatLockdown() then -- (the handler is a protected frame: set up out of combat)
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
  if not ok or not made then return end
  driver = made
  ns.SoloRaidFrameDriver = driver -- (for the tests)
  SecureHandlerSetFrameRef(driver, "party", f)
  driver:SetAttribute("_onstate-arm", ARM)
  -- Registered here, applied at once from this code: not armed yet, so its handler does nothing then
  RegisterStateDriver(driver, "arm", "go")
  driver:SetAttribute("armed", true)
  -- Its state set back by hand (ignored too): the manager finds "go" again at its next look and sets it itself
  driver:SetAttribute("state-arm", "wait")
end

Drive()
if not driver and type(CompactPartyFrame_Generate) == "function" then
  hooksecurefunc("CompactPartyFrame_Generate", Drive)
end

events:SetScript("OnEvent", function(self, event)
  self:UnregisterEvent(event)
  Drive()
end)
if not driver then events:RegisterEvent("PLAYER_LOGIN") end
