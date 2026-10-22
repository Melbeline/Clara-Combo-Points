-- Clara Combo Points - ClassicUI Forever's options window, from the Improvements tab (the built-in
-- copy's, or the standalone's while it runs: both answer the addon compartment's call).

local ADDON, ns = ...

ns:SetQolOpener("classicui", function()
  if type(_G.ForeverClassicUI_OnAddonCompartmentClick) == "function" then _G.ForeverClassicUI_OnAddonCompartmentClick() end
end)
