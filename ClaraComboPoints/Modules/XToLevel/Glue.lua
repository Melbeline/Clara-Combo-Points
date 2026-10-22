-- Clara Combo Points - XToLevel's windows (templates in its XML files), made only while the
-- module runs, with the names its code reads; its options from the Improvements tab (the
-- built-in copy's, or the standalone's while it runs: both are XToLevel).

local ADDON, ns = ...

if ns.XToLevelRuns then
  CreateFrame("Frame", "ClaraXToLevel_AverageFrame_Classic", UIParent, "ClaraXToLevel_AverageFrame_Classic_Template")
  CreateFrame("Frame", "ClaraXToLevel_AverageFrame_Blocky_PlayerFrame", UIParent,
    "ClaraXToLevel_AverageFrame_Blocky_PlayerFrame_Template")
end

ns:SetQolOpener("xtolevel", function()
  local x = _G.XToLevel
  if type(x) == "table" and x.Config and x.Config.Open then x.Config:Open("Information") end
end)
