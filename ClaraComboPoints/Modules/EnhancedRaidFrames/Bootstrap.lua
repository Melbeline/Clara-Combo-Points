-- Clara Combo Points - Enhanced Raid Frames 3.16.17 (by Britt W. Yazel; MIT, LICENSE), built in
-- (QoL.lua), converted from its Classic version for WoW Forever. On the game's raid frames: up to
-- nine indicators per frame (the auras each watches, by name, spell ID or debuff type), the raid
-- target markers, the frames' scale, background opacity and out-of-range opacity. The first of the
-- module's files: ns.ERFRuns (Libs/AceShared.lua, before its libraries) says whether it runs.
-- What changed for Forever, file by file:
--   GameAuras.lua (new): in combat Forever hides auras from addons; each indicator also gets one
--     of the game's aura slots, which the game fills itself, in combat too: buffs by spell ID (a
--     name: every rank of it, and the IDs it was seen under), debuffs by type (Magic, Curse,
--     Poison, Disease, and "Dispel": the ones you can remove). Debuffs named one by one, and
--     "missing only" indicators, are the addon's own reading: shown out of combat.
--   Overrides.lua: the range fade takes Forever's secret in-range value (SetAlphaFromBoolean);
--     the game's own buffs and debuffs on the frames are its secure display: shown or hidden in
--     the game's raid profile options, not here; no custom distance (Forever hides distances).
--   AuraListeners.lua: no aura read while they are secret; your dispel types from Forever's
--     spells (no LibDispel, no LibClassicDurations: Forever gives durations).
--   TargetMarkers.lua: secret marker indices drawn by the game's sprite sheet.
--   EnhancedRaidFrames.lua: saved in ClaraEnhancedRaidFramesDB; its pages under Interface
--     improvements; no LibDualSpec (Forever's specializations are not the ones it knows).
-- The standalone Enhanced Raid Frames takes over for the session it is enabled in (both would draw
-- on the same frames); its settings are carried over at logout if Clara's copy has none yet, and it
-- is turned off for the character (QoL.lua), so that the built-in one runs from the next reload.

local ADDON, ns = ...

if not ns.ERFRuns and ns:QolTakesOver("enhancedraidframes") then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if ClaraEnhancedRaidFramesDB == nil and type(_G.EnhancedRaidFramesDB) == "table" then
      ClaraEnhancedRaidFramesDB = CopyTable(_G.EnhancedRaidFramesDB)
    end
  end)
end

-- Its options: its page, else the standalone's while that one runs (found by name)
ns:SetQolOpener("enhancedraidframes", function() ns:OpenSettingsTo(ns.erfCategory or "Enhanced Raid Frames") end)
