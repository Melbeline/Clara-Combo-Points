-- Clara Combo Points - the Ace libraries DynamicCam, DialogKey and XToLevel share (AceAddon,
-- AceGUI, AceConfig, AceDBOptions, AceTimer: the files below in the TOC), loaded once, when one
-- of them runs. Each module carried its own copy of the same files, read up to three times. The
-- newer AceDB of DynamicCam and XToLevel too, only for them as before (WeaponSwingTimer's
-- characters are keyed by the AceDB that loads).
local _, ns = ...
ns.AceModulesRun = ns:QolRuns("dynamiccam") or ns:QolRuns("dialogkey") or ns:QolRuns("xtolevel")
ns.AceDBModulesRun = ns:QolRuns("dynamiccam") or ns:QolRuns("xtolevel")
