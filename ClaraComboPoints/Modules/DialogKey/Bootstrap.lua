-- Clara Combo Points - DialogKey (Numy Edition) v1.2.62 (by Numy, after Foxthorn, N01ch and
-- FuriousProgrammer; LICENSE), built in (QoL.lua): a key (Space) clicks the first button of a
-- dialog, accepts and completes quests, number keys pick gossip options and quest rewards. The
-- first of the module's files: it tells the others (and their libraries) whether they run, and
-- gives them their shared table. Its settings are saved in ClaraDialogKeyDB; its page in the
-- game's options sits under Interface improvements. Its version check (LibVersionCheck, which
-- tells other players' clients the version that runs) is left out.
-- The built-in one takes over from the standalone DialogKey: while that one is enabled it runs
-- for the session (only one of them may: each would take the same keys), its settings are
-- carried over at logout if Clara's copy has none yet, and it is turned off for the character
-- (QoL.lua), so that the built-in one runs from the next reload.

local ADDON, ns = ...

ns.DialogKeyRuns = ns:QolRuns("dialogkey")
if ns.DialogKeyRuns then
  ns.DialogKeyPrivate = {} -- (the standalone's own `...` table)
elseif ns:QolTakesOver("dialogkey") then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if ClaraDialogKeyDB == nil and type(_G.DialogKeyNumyDB) == "table" then
      ClaraDialogKeyDB = CopyTable(_G.DialogKeyNumyDB)
    end
  end)
end
