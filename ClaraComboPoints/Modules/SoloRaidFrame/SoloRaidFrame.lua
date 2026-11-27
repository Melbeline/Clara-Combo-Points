-- Clara Combo Points - Solo Raid Frame NV 2.6 (by Spridan), built in (QoL.lua): the game's raid-style
-- party frame (CompactPartyFrame) kept shown while not in a group, so one's own frame is there solo
-- too. In a group, the game's own rule (left alone). No setting of its own. Solo Raid Frame's standalone
-- addon is turned off for the character while this one runs.
--
-- Solo Raid Frame NV shows the frame from its own code after each of the game's visibility updates. Here it is
-- never shown by the addon's own code: a frame an addon shows runs the game's whole set-up of its unit frames
-- in the addon's name (OnShow, then each update after it), and with WoW Forever's secret health every one of
-- those updates fails ("attempt to compare a secret number value, while execution tainted"), many times a
-- second. So the addon arms a secure handler of its own, whose state the game's driver manager sets five times
-- a second (secure; its state set back to "wait" each time); the handler's restricted code then, solo:
--  * shows the frame if it is hidden (the game hides it at each of its visibility updates, at a login too);
--  * places it if it has no place yet. The game places the frame only while it is shown (its parent, PartyFrame,
--    lays out its shown children only): hidden through every layout since the login, shown afterwards, it had
--    no point at all and was not drawn though shown. Placed where the game's layout puts it (the top left of
--    PartyFrame), the game's next layout with it shown places it again itself.
-- In a fight too (the frame is protected: its unit buttons are the game's secure ones).

local ADDON, ns = ...

if not ns:QolRuns("soloraidframe") then return end

local events = CreateFrame("Frame")

-- The handler's restricted code, at each of the manager's passes once armed
local ARM = [[
  if newstate ~= "go" or not self:GetAttribute("armed") then return end
  self:SetAttribute("state-arm", "wait") -- (set to "go" again by the manager at its next pass)
  local party = self:GetFrameRef("party")
  if not party or (PlayerInCombat() and not party:IsProtected()) then return end
  if SecureCmdOptionParse("[group] group; solo") ~= "solo" then return end
  if not party:IsShown() then
    party:Show()
    self:SetAttribute("reshown", (self:GetAttribute("reshown") or 0) + 1)
  end
  if party:GetNumPoints() == 0 then
    party:SetPoint("TOPLEFT", "$parent", "TOPLEFT", self:GetAttribute("x") or 2, 0)
    self:SetAttribute("placed", (self:GetAttribute("placed") or 0) + 1)
  end
]]

local driver
local function Drive()
  local f = CompactPartyFrame
  if driver or not f or not (RegisterStateDriver and SecureHandlerSetFrameRef) then return end
  if InCombatLockdown() then -- (the handler is a protected frame: made out of combat)
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
  if not ok or not made then return end
  driver = made
  ns.SoloRaidFrameDriver = driver -- (for the tests)
  SecureHandlerSetFrameRef(driver, "party", f)
  driver:SetAttribute("_onstate-arm", ARM)
  -- (the game's left margin in PartyFrame for it: 2, or 6 with horizontal groups and a border)
  local x = PartyFrame and PartyFrame.leftPadding
  driver:SetAttribute("x", type(x) == "number" and x or 2)
  -- Registered here, applied at once from this code: not armed yet, so its handler does nothing then
  RegisterStateDriver(driver, "arm", "go")
  driver:SetAttribute("armed", true)
  -- Its state set back by hand: the manager finds "go" again at its next pass and sets it itself (secure)
  driver:SetAttribute("state-arm", "wait")
end

Drive()
if not driver and type(CompactPartyFrame_Generate) == "function" then
  hooksecurefunc("CompactPartyFrame_Generate", Drive)
end

-- (until the handler is made: at login, as the world is entered and as the group changes too, in case the party frame
-- came another way than CompactPartyFrame_Generate's own call; after a fight if it came in one)
local WAIT = { "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }
events:SetScript("OnEvent", function(self)
  Drive()
  if driver then self:UnregisterAllEvents() end
end)
if not driver then for _, e in ipairs(WAIT) do events:RegisterEvent(e) end end

-- Where it stands, for /cl souris: the handler, the frame (shown, drawn, placed), the group, the Edit Mode option
function ns:SoloRaidFrameReport()
  local f = CompactPartyFrame
  local function A(k) return driver and tostring(driver:GetAttribute(k)) or "-" end
  local function Call(obj, method)
    if not (obj and obj[method]) then return "-" end
    local ok, a, b = pcall(obj[method], obj)
    return ok and tostring(a) .. (b ~= nil and (" " .. tostring(b)) or "") or "?"
  end
  local raidStyle = EditModeManagerFrame and EditModeManagerFrame.UseRaidStylePartyFrames
    and select(2, pcall(EditModeManagerFrame.UseRaidStylePartyFrames, EditModeManagerFrame))
  local parent = f and f.GetParent and f:GetParent()
  return ("solo raid frame: handler %s, armed %s, state %s, shown again %s times, placed %s times, party frame %s, shown %s, drawn %s, points %s, protected %s, PartyFrame shown %s, drawn %s, in a group %s, raid-style party frames %s"):format(
    driver and "made" or "not made", A("armed"), A("state-arm"), A("reshown"), A("placed"), f and "there" or "missing",
    Call(f, "IsShown"), Call(f, "IsVisible"), Call(f, "GetNumPoints"), Call(f, "IsProtected"),
    Call(parent, "IsShown"), Call(parent, "IsVisible"), tostring(IsInGroup and IsInGroup()), tostring(raidStyle))
end
