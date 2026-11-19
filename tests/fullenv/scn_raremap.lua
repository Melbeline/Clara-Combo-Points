-- The rares on the world map (RareMap.lua) in the full harness: dressed once the game's map is loaded, its button made,
-- the map shown and changed without an error, its list opened
local H = ...
local ns = H.ns
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) end
if ns.RareMapDress then ns.RareMapDress() end
check(ns.RareMapButton ~= nil, "its button on the map")
local ok, err = pcall(function()
  if ns.RareMapRefresh then ns.RareMapRefresh() end
  if ns.RareMapTogglePanel then ns.RareMapTogglePanel() end
end)
check(ok, "refreshed, its list opened" .. (ok and "" or (": " .. tostring(err))))
