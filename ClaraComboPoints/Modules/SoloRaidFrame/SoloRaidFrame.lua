-- Clara Combo Points - Solo Raid Frame NV 2.5 (by Spridan), built in (QoL.lua): the game's raid-style
-- party frame (CompactPartyFrame) kept shown while not in a group, so one's own frame is there solo
-- too. In a group, the game's own rule (it has just run: left alone). No setting of its own. Solo Raid
-- Frame's standalone addon is turned off for the character while this one runs.
-- The game hides it when a group ends (someone leaving, an invitation declined either way): through its
-- visibility update, and also directly (its raid container hides the group frames it no longer uses), at
-- times before the game counts the group as gone. So it is looked at again after each, a moment later too.
-- In combat the frame is protected (its unit buttons are the game's secure ones): an addon's code can't
-- show it then, the game's own secure state driver does (a group ending in a fight, a fight started solo:
-- shown again at once, by the game's restricted code, the same way action bars page in combat).

local ADDON, ns = ...

if not ns:QolRuns("soloraidframe") then return end

local events = CreateFrame("Frame")

local function Solo() return not (IsInGroup() or IsInRaid()) end

local function Keep()
  -- In a group, Blizzard's own visibility logic (which has just run) is correct, so leave it alone.
  local f = CompactPartyFrame
  if not f or not Solo() or f:IsShown() then return end
  -- Protected in combat: the state driver below shows it; else as the fight ends.
  if InCombatLockdown() and f:IsProtected() then
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  f:Show()
end
-- now, the next frame and a moment later (the group's end can be told after the game's own update)
local function KeepSoon()
  Keep()
  C_Timer.After(0, Keep)
  C_Timer.After(.5, Keep)
end

-- The game's secure state driver: "solo" (and "fight", solo in combat) shows the frame, in combat too.
local driver
local function MakeDriver()
  local f = CompactPartyFrame
  if driver or not f or InCombatLockdown() or not (RegisterStateDriver and SecureHandlerSetFrameRef) then return end
  local ok, made = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerStateTemplate")
  if not ok or not made then return end
  driver = made
  SecureHandlerSetFrameRef(driver, "party", f)
  driver:SetAttribute("_onstate-solo", [[
    if newstate ~= "grouped" then
      local party = self:GetFrameRef("party")
      -- (a handle reaches an unprotected frame only out of combat: the addon's own code shows that one)
      if party and party:IsProtected() and not party:IsShown() then party:Show() end
    end
  ]])
  RegisterStateDriver(driver, "solo", "[group] grouped; [combat] fight; solo")
end

-- Hooked as the frame is there: at load if the game made it already, else as the game makes it
-- (CompactPartyFrame_Generate, WoW Forever) or at login, shown then
local hooked
local function Hook(late)
  if hooked or not (CompactPartyFrame and CompactPartyFrame.UpdateVisibility) then return end
  hooked = true
  hooksecurefunc(CompactPartyFrame, "UpdateVisibility", KeepSoon)
  CompactPartyFrame:HookScript("OnHide", function() C_Timer.After(0, KeepSoon) end) -- (hidden directly)
  MakeDriver()
  if late then KeepSoon() end
end
Hook()
if not hooked and type(CompactPartyFrame_Generate) == "function" then
  hooksecurefunc("CompactPartyFrame_Generate", function() Hook(true) end)
end

events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    Hook(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    MakeDriver() -- (made late, the frame having come in a fight)
    if hooked then Keep() end
  elseif hooked then -- the group changed, ended, a world entered
    KeepSoon()
  end
end)
if not hooked then events:RegisterEvent("PLAYER_LOGIN") end
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("GROUP_LEFT")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
