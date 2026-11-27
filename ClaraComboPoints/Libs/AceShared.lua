-- Clara Combo Points - the Ace libraries DynamicCam, DialogKey, XToLevel and Enhanced Raid Frames
-- share (AceAddon, AceGUI, AceConfig, AceDBOptions, AceTimer: the files below in the TOC), loaded
-- once, when one of them runs. Each module carried its own copy of the same files, read up to
-- three times. The newer AceDB of DynamicCam, XToLevel and Clique too, only for them as before
-- (WeaponSwingTimer's characters are keyed by the AceDB that loads). Enhanced Raid Frames also
-- takes DynamicCam's AceConsole, AceEvent, AceLocale and AceSerializer, and DialogKey's AceHook
-- (each loaded once, for whichever of them runs).
local _, ns = ...
ns.AceModulesRun = ns:QolRuns("dynamiccam") or ns:QolRuns("dialogkey") or ns:QolRuns("xtolevel")
ns.AceDBModulesRun = ns:QolRuns("dynamiccam") or ns:QolRuns("xtolevel") or ns:QolRuns("clique") -- (Clique: its AceDB is this one)
