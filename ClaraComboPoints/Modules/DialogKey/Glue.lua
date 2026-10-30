-- Clara Combo Points - DialogKey's options, from its theme's page of Clara Combo Points' options (the built-in copy's, or
-- the standalone's while it runs: both are DialogKeyNS).

local ADDON, ns = ...

ns:SetQolOpener("dialogkey", function()
  local dk = _G.DialogKeyNS
  if type(dk) == "table" and dk.OpenConfig then dk:OpenConfig() end
end)
