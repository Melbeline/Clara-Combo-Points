-- Clara Combo Points - DoesItDie v0.9.0 (by Joe Greive; MIT, LICENSE), built in (QoL.lua): your DoTs on the
-- target, the damage they still have to deal marked on its health bar (and on the focus's and the
-- nameplates'), and a kill icon on the portrait when they will finish it off. Made for WoW Forever (its
-- secret health is compared by the game's own bars, never read). The first of the module's files: it tells
-- the others whether they run, and gives them their own shared table. Saved in ClaraDoesItDieDB; its page
-- under Interface improvements, its window (/did) also from the Improvements tab.
-- Clara's default look is the game's: a dark red fill in the health bar's own texture (Forever's, or
-- ClassicUI's while it runs; "The health bar's own look", added to its fill styles), a thin dark outline, the
-- game's boss skull as the kill icon, no glow or shine; DoesItDie's own looks stay one choice away.
-- The standalone DoesItDie takes over for the session it is enabled in; its settings are carried over at
-- logout if Clara's copy has none yet, and it is turned off for the character (QoL.lua).

local ADDON, ns = ...

ns.DoesItDieRuns = ns:QolRuns("doesitdie")
if ns.DoesItDieRuns then
  ns.DoesItDiePrivate = {} -- (the standalone's own `...` table)
elseif ns:QolTakesOver("doesitdie") then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if ClaraDoesItDieDB == nil and type(_G.DoesItDieDB) == "table" then
      ClaraDoesItDieDB = CopyTable(_G.DoesItDieDB)
    end
  end)
end

-- Its options: its window (with its live preview), else its page, else the standalone's (found by name)
ns:SetQolOpener("doesitdie", function()
  local private = ns.DoesItDiePrivate
  if private and private.openOptions and not InCombatLockdown() then
    private.openOptions()
  else
    ns:OpenSettingsTo(ns.doesItDieCategory or "DoesItDie")
  end
end)
