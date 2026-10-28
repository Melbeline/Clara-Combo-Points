-- Clara Combo Points - MinimapDrawer 1.10.0, built in (QoL.lua): the addons' minimap buttons in a
-- drawer that opens from the player frame's level circle. The first of the module's files: it
-- tells the other whether it runs. Its settings are saved in ClaraMinimapDrawerDB.
-- The built-in one takes over from the standalone MinimapDrawer: while that one is enabled it runs
-- for the session (only one of them may: each would take the same buttons), its settings are
-- carried over at logout if Clara's copy has none yet, and it is turned off for the character
-- (QoL.lua), so that the built-in one runs from the next reload.

local ADDON, ns = ...

ns.MinimapDrawerRuns = ns:QolRuns("minimapdrawer")
if not ns.MinimapDrawerRuns and ns:QolTakesOver("minimapdrawer") then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if ClaraMinimapDrawerDB == nil and type(_G.MinimapDrawerDB) == "table" then
      ClaraMinimapDrawerDB = CopyTable(_G.MinimapDrawerDB)
    end
  end)
end
