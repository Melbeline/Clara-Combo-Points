-- Clara Combo Points - ClassicUI Forever 0.36.0 (by justawower; LICENSE), built in (QoL.lua): the
-- original Classic look on WoW Forever (the gryphon bar, square buttons, 1.x unit frames, cast bars,
-- minimap, nameplates, quest tracker and windows), each part a toggle in its own options. The first
-- of the module's files: it tells the others whether they run, and gives them their shared table.
-- Its settings are saved in ClaraClassicUIDB (and ClaraClassicUICharDB for each character); its
-- options keep their own entry in the game's options and window (/fcui). While the standalone
-- ClassicUI Forever is enabled, that one runs instead (never both: each would take the same
-- frames), and its settings are copied at login and logout, so turning it off later needs nothing
-- set again.
-- Turned off (the module's box, or the Turn off button of its options window): at the reload, it
-- gives the game's own layout and settings back, so the next session has the game's interface.
-- Changes to ClassicUI Forever: the party portraits' debuff ring sits on the 1.x portrait
-- (Units/PartyPetFrames.lua); in the Who list's menu, Class, Race and Zone sort at once (Race, Zone
-- and Guild also pick the middle column), their filters on hover, no Column submenu
-- (Social/WhoList.lua, UI/Menus.lua).

local ADDON, ns = ...

ns.ClassicUIRuns = ns:QolRuns("classicui")
if ns.ClassicUIRuns then
  ns.ClassicUIPrivate = {} -- (the standalone's own `...` table)
  -- (Clara Combo Points: the game's own world map, Core.lua: ClassicUI's map settings put aside while it is on, so its
  -- map modules stay off; given back as it is turned off. Before ClassicUI reads its settings.)
  ns.ClassicUIPrivate.gameMapOnly = type(ClaraClassicUIDB) == "table" and ClaraClassicUIDB.gameWorldMap == true
  local db = ClaraClassicUIDB
  local MAP_KEYS = { "worldMap", "mapUnlocked", "mapMarkers", "mapFade", "questMapPane", "hideMapQuestButton" }
  if type(db) == "table" and db.gameWorldMap == true and type(db.gameWorldMapKept) ~= "table" then
    db.gameWorldMapKept = {}
    for _, key in ipairs(MAP_KEYS) do
      db.gameWorldMapKept[key] = db[key] == nil and "unset" or db[key]
      db[key] = false
    end
  elseif type(db) == "table" and db.gameWorldMap ~= true and type(db.gameWorldMapKept) == "table" then
    for key, value in pairs(db.gameWorldMapKept) do
      if value == "unset" then db[key] = nil else db[key] = value end
    end
    db.gameWorldMapKept = nil
  end
elseif ns:QolState("classicui") == "standalone" then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if type(_G.ForeverClassicUIDB) == "table" then ClaraClassicUIDB = CopyTable(_G.ForeverClassicUIDB) end
    if type(_G.ForeverClassicUICharDB) == "table" then ClaraClassicUICharDB = CopyTable(_G.ForeverClassicUICharDB) end
  end)
end

-- Being turned off at this reload: its module unticked, or Clara Combo Points itself turned off for
-- this character in the AddOns list (by its GUID, as that list names characters on WoW Forever).
function ns:ClassicUITurningOff()
  if self.sv and self.sv.qol and self.sv.qol.classicui == false then return true end
  local state = C_AddOns and C_AddOns.GetAddOnEnableState
  local me = UnitGUID and UnitGUID("player")
  if not (state and me) then return false end
  local ok, value = pcall(state, ADDON, me)
  return ok and value == 0
end
