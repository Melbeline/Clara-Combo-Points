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

-- The handler's restricted code: on the manager's "go" once armed, the frame's own driver registered (once); then,
-- at each of the manager's looks (five times a second: its state set back to "wait", the manager sets "go" again),
-- solo and the frame hidden, it is shown again, by this secure code. (The driver acts only as its rule's answer
-- changes: solo, always "show"; a frame the game hides after it, as at a login, stayed hidden until the group changed.)
local ARM = ([[
  if newstate ~= "go" or not self:GetAttribute("armed") then return end
  local party = self:GetFrameRef("party")
  if not party then return end
  if not self:GetAttribute("driving") then
    self:SetAttribute("driving", true)
    RegisterStateDriver(party, "visibility", %q)
  end
  if SecureCmdOptionParse("[group] group; solo") == "solo" and not party:IsShown() then
    party:Show()
    self:SetAttribute("reshown", (self:GetAttribute("reshown") or 0) + 1)
  end
  self:SetAttribute("state-arm", "wait")
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

-- (until the handler is made: at login, as the world is entered and as the group changes too, in case the party frame
-- came another way than CompactPartyFrame_Generate's own call)
local WAIT = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }
events:SetScript("OnEvent", function(self, event)
  Drive()
  if driver then self:UnregisterAllEvents() end
end)
if not driver then for _, e in ipairs(WAIT) do if e ~= "PLAYER_REGEN_ENABLED" then events:RegisterEvent(e) end end end

-- Where it stands, for /cl souris: the handler made, armed, the party frame's driver put on, the frame shown, the group
function ns:SoloRaidFrameReport()
  local f = CompactPartyFrame
  local function A(k) return driver and tostring(driver:GetAttribute(k)) or "-" end
  local shown = f and f.IsShown and f:IsShown()
  local inGroup = IsInGroup and IsInGroup()
  local raidStyle = EditModeManagerFrame and EditModeManagerFrame.UseRaidStylePartyFrames
    and select(2, pcall(EditModeManagerFrame.UseRaidStylePartyFrames, EditModeManagerFrame))
  return ("solo raid frame: handler %s, armed %s, state %s, the party frame's driver %s, shown again %s times, party frame %s, shown %s, in a group %s, raid-style party frames %s"):format(
    driver and "made" or "not made", A("armed"), A("state-arm"), A("driving"), A("reshown"), f and "there" or "missing",
    tostring(shown), tostring(inGroup), tostring(raidStyle))
end
