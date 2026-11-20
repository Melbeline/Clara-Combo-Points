-- The tooltip's zone with the harness's frames: the game's tooltip for the player itself and a party token, Clara's
-- zone code run through the game's own post calls: no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local A = ns.AltFriends
check(A and A.UnitZone and A.GroupToken and A.MapZone, "its zone code loaded")
if A and A.UnitZone then
  for _, unit in ipairs({ "player", "party1", "target", "mouseover" }) do
    local ok, zone = pcall(A.UnitZone, unit)
    check(ok, unit .. ": " .. tostring(zone))
  end
end
local tip = rawget(env, "GameTooltip")
if tip and tip.SetUnit then
  local ok, e = pcall(function() tip:SetOwner(env.UIParent, "ANCHOR_NONE"); tip:SetUnit("player") end)
  check(ok, "the game's tooltip for the player, the post calls run " .. tostring(e or ""))
end
print("scenario: zone failures " .. fails)
