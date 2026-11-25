-- Clara Combo Points - a middle click on the world map puts the game's own map pin there (its user
-- waypoint, as Ctrl + click does) and tracks it: its marker and distance show on the screen, the
-- way to go. A middle click on the pin takes it off. With the game's map as with ClassicUI's (the
-- same map, restyled).
-- In a fight the game refuses the pin to an addon (drawing it on the open map sets its mouse pass-through, a protected
-- call then: ADDON_ACTION_BLOCKED): the pin asked for is kept and put there as the fight ends, a line saying so.

local ADDON, ns = ...
local L = ns.L
local pending -- { mapID, x, y }: a pin asked for in a fight

local PIN = "WaypointLocationPinTemplate"

local function PinUnderMouse(map)
  if not map.EnumeratePinsByTemplate then return end
  for pin in map:EnumeratePinsByTemplate(PIN) do
    if pin:IsMouseOver() then return pin end
  end
end

local function Place(mapID, x, y)
  C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  if SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK then PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK) end
end

local function Drop(map)
  if PinUnderMouse(map) then
    pending = nil
    C_Map.ClearUserWaypoint()
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(false) end
    if SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_REMOVE then PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_REMOVE) end
    return
  end
  local mapID = map:GetMapID()
  if not (mapID and C_Map.CanSetUserWaypointOnMap(mapID)) then
    if UIErrorsFrame and MAP_PIN_INVALID_MAP then UIErrorsFrame:AddMessage(MAP_PIN_INVALID_MAP, RED_FONT_COLOR:GetRGBA()) end
    return
  end
  local canvas = map.ScrollContainer
  local x, y = canvas:NormalizeUIPosition(canvas:GetCursorPosition())
  if not (x and y) or x < 0 or x > 1 or y < 0 or y > 1 then return end
  if InCombatLockdown and InCombatLockdown() then
    pending = { mapID, x, y }
    if UIErrorsFrame and L.MAP_PIN_AFTER_FIGHT then UIErrorsFrame:AddMessage(L.MAP_PIN_AFTER_FIGHT, 1, 0.82, 0) end
    return
  end
  pending = nil
  Place(mapID, x, y)
end
ns.DropMapPin = Drop

-- The fight over: the pin asked for in it
local after = CreateFrame("Frame")
after:RegisterEvent("PLAYER_REGEN_ENABLED")
after:SetScript("OnEvent", function()
  if not pending then return end
  local p = pending
  pending = nil
  Place(p[1], p[2], p[3])
end)

local function Dress()
  if ns.GameMapOnly() then return end -- (the game's own world map: nothing on it, Core.lua)
  local map = WorldMapFrame
  if not (map and map.ScrollContainer and C_Map and C_Map.SetUserWaypoint and UiMapPoint) or map.claraMapPin then return end
  map.claraMapPin = true
  -- on the map itself
  map.ScrollContainer:HookScript("OnMouseUp", function(_, button)
    if button == "MiddleButton" then Drop(map) end
  end)
  -- on a pin (a quest, a town...): the same, there; on the map pin itself: off
  if map.AddGlobalPinMouseActionHandler then
    map:AddGlobalPinMouseActionHandler(function(_, action, button)
      if button ~= "MiddleButton" then return false end
      if action == MapCanvasMixin.MouseAction.Up then Drop(map) end
      return true
    end, 100)
  end
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Dress)
end
