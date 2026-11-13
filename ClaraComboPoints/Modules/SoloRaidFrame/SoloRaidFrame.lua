-- Clara Combo Points - Solo Raid Frame NV 2.5 (by Spridan), built in (QoL.lua): the game's raid-style
-- party frame (CompactPartyFrame) kept shown while not in a group, so one's own frame is there solo
-- too. In a group, the game's own rule (left alone). No setting of its own. Solo Raid Frame's standalone
-- addon is turned off for the character while this one runs.
-- Shown only by the game's secure state driver ("visibility": "show" solo, nothing in a group), never by
-- the addon's own code: a frame shown by an addon runs the game's whole set-up of its unit frames in the
-- addon's name (OnShow, then each update after it), and with WoW Forever's secret health values every one
-- of those updates fails ("attempt to compare a secret number value, while execution tainted"), many
-- times a second, Edit Mode's party frames too. The driver looks again every fifth of a second and at
-- once as the group changes: a frame the game hides as a group ends (through its visibility update, or
-- directly by its raid container) is shown again at once, in a fight too, by the game's own secure code.

local ADDON, ns = ...

if not ns:QolRuns("soloraidframe") then return end

local events = CreateFrame("Frame")
-- In a group: "game", a value the driver leaves alone (only "show" and "hide" move the frame)
local RULE = "[group] game; show"

-- The driver is put on as the frame is there (at load if the game made it already, else as the game makes
-- it, CompactPartyFrame_Generate on WoW Forever, or at login), out of combat (the driver's manager is the
-- game's secure frame)
local driven
local function Drive()
  local f = CompactPartyFrame
  if driven or not f or not RegisterStateDriver then return end
  if InCombatLockdown() then
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  driven = true
  RegisterStateDriver(f, "visibility", RULE)
end
ns.SoloRaidFrameRule = RULE -- (for the tests)

Drive()
if not driven and type(CompactPartyFrame_Generate) == "function" then
  hooksecurefunc("CompactPartyFrame_Generate", Drive)
end

events:SetScript("OnEvent", function(self, event)
  self:UnregisterEvent(event)
  Drive()
end)
if not driven then events:RegisterEvent("PLAYER_LOGIN") end
