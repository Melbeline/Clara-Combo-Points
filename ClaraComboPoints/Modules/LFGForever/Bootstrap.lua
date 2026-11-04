-- Clara Combo Points - LFG Forever v0.29.0 (by Artefius; GPLv3, LICENSE), built in (QoL.lua): the game's group
-- finder as one window, groups and players in one list, filtered by role, class, level and more, with Ask to
-- Join and Invite whispers, a whisper log and saved filters. /lfg, its key (Clara's section of the key
-- bindings), its minimap button, or the tab on the game's group finder. The first of the module's files: it
-- tells the others whether they run, and gives them their own shared table. Saved in ClaraLFGForeverDB (the
-- account) and ClaraLFGForeverCharDB (each character's two whispers); its page under its theme's page of Clara.
-- Clara's changes (each marked "Clara" in the files): the right panel (filters and whispers) closes with an
-- arrow at the top right of the list, closed until first opened, with a Search Again button beside the arrow
-- while it is; French and German words (Locale_Clara.lua); no load greeting; no bug report link (this copy's
-- bugs are Clara's); ClassicUI's old window in the version with ClassicUI.
-- The standalone LFG Forever takes over for the session it is enabled in; its settings are carried over at
-- logout if Clara's copy has none yet, and it is turned off for the character (QoL.lua).

local ADDON, ns = ...

-- Its key (Bindings.xml): named whether it runs or the standalone does (both define LFGForever_ToggleWindow)
BINDING_NAME_CLARA_LFGFOREVER_TOGGLE = ns.L.LFGFOREVER_BINDING

ns.LFGForeverRuns = ns:QolRuns("lfgforever")
if ns.LFGForeverRuns then
  ns.LFGForeverPrivate = {} -- (the standalone's own `...` table)
elseif ns:QolTakesOver("lfgforever") then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if ClaraLFGForeverDB == nil and type(_G.LFGForeverDB) == "table" then
      ClaraLFGForeverDB = CopyTable(_G.LFGForeverDB)
    end
    if ClaraLFGForeverCharDB == nil and type(_G.LFGForeverCharDB) == "table" then
      ClaraLFGForeverCharDB = CopyTable(_G.LFGForeverCharDB)
    end
  end)
end

-- Its options: its page (under its theme's), else the standalone's (found by name)
ns:SetQolOpener("lfgforever", function()
  local private = ns.LFGForeverPrivate
  if private and private.OpenSettings and private.settingsCategory then
    private.OpenSettings()
  else
    ns:OpenSettingsTo("LFG Forever")
  end
end)
