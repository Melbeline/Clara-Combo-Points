-- Clara Combo Points - Solo Raid Frame NV 2.5 (by Spridan), built in (QoL.lua): the game's raid-style
-- party frame (CompactPartyFrame) kept shown while not in a group, so one's own frame is there solo
-- too. In a group, the game's own rule (it has just run: left alone). Never touched in combat: done
-- as it ends. No setting of its own. Solo Raid Frame's standalone addon is turned off for the
-- character while this one runs.

local ADDON, ns = ...

if not ns:QolRuns("soloraidframe") then return end

local events = CreateFrame("Frame")

local function Keep()
  -- In a group, Blizzard's own visibility logic (which has just run) is correct, so leave it alone.
  if IsInGroup() or IsInRaid() then return end
  -- Don't touch protected frames in combat; retry as soon as combat ends.
  if InCombatLockdown() then
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  CompactPartyFrame:SetShown(true)
end

-- Hooked as the frame is there (at load in WoW Forever; else at login, shown then)
local hooked
local function Hook(late)
  if hooked or not (CompactPartyFrame and CompactPartyFrame.UpdateVisibility) then return end
  hooked = true
  hooksecurefunc(CompactPartyFrame, "UpdateVisibility", Keep)
  if late then Keep() end
end
Hook()

events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    Hook(true)
  else
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if hooked then Keep() end
  end
end)
if not hooked then events:RegisterEvent("PLAYER_LOGIN") end
