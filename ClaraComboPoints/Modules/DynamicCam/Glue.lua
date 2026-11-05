-- Clara Combo Points - DynamicCam's camera in one click (the portrait's menu, the Improvements
-- tab), in the copy that runs (built in, or the standalone DynamicCam). Ticked: DynamicCam runs,
-- its Vertical Pitch and Head Tracking on, its Pitch (on ground) at 0.99 (as its own Enable box
-- does, and its default). Unticked: DynamicCam turned off altogether at once (no reload: nothing of
-- it at work, the game's own zoom), the camera settings it had changed given back to the game (as
-- they were before it ran, else the game's defaults), the game's camera zooming at 15 out to
-- 50 yards. Kept for the next sessions (an "off" DynamicCam is not started at login). Its Zoom
-- Increments: the player's for each state (kept when the box leaves it, given back when it comes
-- back to it; the first time 0.2 yards a wheel tick ticked, 2 unticked). Set in its standard
-- settings, and in the situations that set them themselves.
-- The max camera distance set in the game's options (or by another addon): DynamicCam takes it as
-- its own Maximum Camera Distance, rather than putting its own back at the next zoom.

local ADDON, ns = ...

-- the DynamicCam that runs, built in or standalone
local function Cam()
  local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
  return AceAddon and AceAddon:GetAddon("DynamicCam", true) or nil
end

local FEATURES = { "test_cameraDynamicPitch", "test_cameraHeadMovementStrength" } -- (Vertical Pitch, Head Tracking: 1 on, 0 off)
-- Zoom Increments, as its slider shows them (kept as that minus 1), the first time ticked and unticked;
-- the player's own for each, kept in Clara's settings (the standard one and the situations' own)
local FIRST_INCREMENTS = { [true] = 0.2 - 1, [false] = 2 - 1 }
local KEPT = { [true] = "cameraZoom", [false] = "cameraZoomOff" }
local PITCH, PITCH_ON = "test_cameraDynamicPitchBaseFovPad", 0.99 -- (Pitch (on ground), once ticked)

local function Standard(cam)
  local profile = cam and cam.db and cam.db.profile
  local standard = type(profile) == "table" and profile.standardSettings
  if type(standard) == "table" and type(standard.cvars) == "table" then return standard, profile end
end

-- the box's values in a settings table (the standard ones: all; a situation's: those it sets itself;
-- increments nil: its Zoom Increments left; pitch: its Pitch (on ground) set, the box just ticked)
local function Put(settings, on, all, increments, pitch)
  local cvars = type(settings) == "table" and settings.cvars
  if type(cvars) ~= "table" then return end
  for _, cvar in ipairs(FEATURES) do
    if all or cvars[cvar] ~= nil then cvars[cvar] = on and 1 or 0 end
  end
  if pitch and (all or cvars[PITCH] ~= nil) then cvars[PITCH] = pitch end
  if increments and (all or settings.reactiveZoomAddIncrementsAlways ~= nil) then
    settings.reactiveZoomAddIncrementsAlways = increments
  end
end

-- The player's Zoom Increments as they are, kept for the box's state it leaves.
local function Keep(sv, on, standard, situations)
  local kept = { standard = tonumber(standard.reactiveZoomAddIncrementsAlways), situations = {} }
  for id, situation in pairs(situations) do
    local own = type(situation) == "table" and situation.situationSettings
    if type(own) == "table" and type(own.reactiveZoomAddIncrementsAlways) == "number" then
      kept.situations[id] = own.reactiveZoomAddIncrementsAlways
    end
  end
  sv[KEPT[on]] = kept
end

-- its options, if open: the new values
local function Notify()
  local registry = LibStub("AceConfigRegistry-3.0", true)
  if registry then
    pcall(registry.NotifyChange, registry, "DynamicCam")
    pcall(registry.NotifyChange, registry, "DynamicCam_Detached")
  end
end

-- The camera settings DynamicCam sets (its standard ones and its situations').
local function CameraCVars(cam)
  local cvars = {}
  local profile = cam and cam.db and cam.db.profile
  if type(profile) ~= "table" then return cvars end
  local standard = profile.standardSettings and profile.standardSettings.cvars
  for cvar in pairs(type(standard) == "table" and standard or {}) do cvars[cvar] = true end
  for _, situation in pairs(type(profile.situations) == "table" and profile.situations or {}) do
    local own = type(situation) == "table" and situation.situationSettings and situation.situationSettings.cvars
    for cvar in pairs(type(own) == "table" and own or {}) do cvars[cvar] = true end
  end
  return cvars
end

-- The game's values of those before DynamicCam runs (kept: sv.cameraWas).
local function RememberGameCamera(cam, sv)
  local was = {}
  for cvar in pairs(CameraCVars(cam)) do
    local ok, value = pcall(GetCVar, cvar)
    if ok and type(value) == "string" then was[cvar] = value end
  end
  sv.cameraWas = was
end

-- DynamicCam off: the game's own camera (the values kept, else the game's defaults), zooming at 15
-- out to 50 yards (its max distance in yards is 15 times the setting).
local OFF_CAMERA = { cameraZoomSpeed = "15", cameraDistanceMaxZoomFactor = tostring(50 / 15) }
local function GameCamera(cam, sv)
  local was = type(sv.cameraWas) == "table" and sv.cameraWas or {}
  for cvar in pairs(CameraCVars(cam)) do
    local value = was[cvar]
    if value == nil and GetCVarDefault then
      local ok, default = pcall(GetCVarDefault, cvar)
      value = ok and default or nil
    end
    if value ~= nil and OFF_CAMERA[cvar] == nil then pcall(SetCVar, cvar, value) end
  end
  for cvar, value in pairs(OFF_CAMERA) do pcall(SetCVar, cvar, value) end
end

local function FeaturesOn(standard)
  for _, cvar in ipairs(FEATURES) do
    if tonumber(standard.cvars[cvar]) ~= 1 then return false end
  end
  return true
end

function ns:CameraAvailable() return Standard(Cam()) ~= nil end
-- Ticked: DynamicCam running, its Vertical Pitch and Head Tracking on.
function ns:CameraOn()
  local cam = Cam()
  local standard = Standard(cam)
  if not standard or (self.sv and self.sv.cameraDisabled) then return false end
  if cam.IsEnabled and not cam:IsEnabled() then return false end
  return FeaturesOn(standard)
end
function ns:SetCameraOn(on)
  local cam = Cam()
  local standard, profile = Standard(cam)
  if not standard then return end
  on = on and true or false
  local situations = type(profile.situations) == "table" and profile.situations or {}
  local switch = self:CameraOn() ~= on -- (already in that state: the Zoom Increments left as they are)
  if switch and self.sv then Keep(self.sv, not on, standard, situations) end
  local kept = self.sv and type(self.sv[KEPT[on]]) == "table" and self.sv[KEPT[on]] or {}
  local keptSituations = type(kept.situations) == "table" and kept.situations or {}
  local pitch = switch and on and PITCH_ON or nil
  Put(standard, on, true, switch and (tonumber(kept.standard) or FIRST_INCREMENTS[on]) or nil, pitch)
  for id, situation in pairs(situations) do
    if type(situation) == "table" then
      Put(situation.situationSettings, on, false, switch and (tonumber(keptSituations[id]) or FIRST_INCREMENTS[on]) or nil, pitch)
    end
  end
  if self.sv then self.sv.cameraDisabled = not on end
  if on then
    if cam.IsEnabled and not cam:IsEnabled() then
      if self.sv then RememberGameCamera(cam, self.sv) end
      cam:Enable()
    elseif cam.ApplySettings then
      cam:ApplySettings()
    end
  else
    if cam.IsEnabled and cam:IsEnabled() then cam:Disable() end
    GameCamera(cam, self.sv or {})
  end
  Notify()
  if self.RefreshQol then self:RefreshQol() end
end

-- At login: an "off" DynamicCam not started (decided the first time from its own settings: off
-- unless its Vertical Pitch and Head Tracking were both on).
local starter = CreateFrame("Frame")
starter:RegisterEvent("ADDON_LOADED")
starter:RegisterEvent("PLAYER_LOGIN")
starter:SetScript("OnEvent", function(self, event, name)
  local sv = type(ClaraComboPointsDB) == "table" and ClaraComboPointsDB or nil
  local cam = Cam()
  if event == "ADDON_LOADED" then
    if name ~= ADDON then return end
    if cam and sv and sv.cameraDisabled == true and cam.SetEnabledState then cam:SetEnabledState(false) end
    return
  end
  self:UnregisterAllEvents()
  local standard = Standard(cam)
  if not (sv and standard) then return end
  if sv.cameraDisabled == nil then sv.cameraDisabled = not FeaturesOn(standard) end
  if not sv.cameraDisabled then return end
  if cam.IsEnabled and cam:IsEnabled() then
    cam:Disable()
    GameCamera(cam, sv)
  elseif cam.SetEnabledState then
    cam:SetEnabledState(false)
  end
end)

-- the its theme's page: the box, and DynamicCam's own window
ns:SetQolSwitches("dynamiccam", {
  { label = "DC_SW_ON", get = function() return ns:CameraOn() end, set = function(on) ns:SetCameraOn(on) end },
})
ns:SetQolOpener("dynamiccam", function()
  local cam = Cam()
  if cam and cam.OpenMenu then cam:OpenMenu() end
end)

-- The max camera distance changed outside DynamicCam (the game's options, another addon): its
-- Maximum Camera Distance from now on (the current situation's, if it sets its own). DynamicCam's own
-- changes set the value it has, or are a transition or a zoom-based curve of it: left alone.
local MAX_DISTANCE = "cameraDistanceMaxZoomFactor"
local watch = CreateFrame("Frame")
if Cam() then watch:RegisterEvent("CVAR_UPDATE") end -- (a DynamicCam there: built in, or the standalone loaded before)
watch:SetScript("OnEvent", function(_, _, cvar, value)
  if cvar ~= MAX_DISTANCE then return end
  value = tonumber(value)
  local cam = Cam()
  local standard, profile = Standard(cam)
  if not (value and standard and cam:IsEnabled()) then return end
  if cam.IsCvarBeingEased and cam:IsCvarBeingEased(MAX_DISTANCE) then return end
  local sid = cam.currentSituationID
  if cam.IsEffectivelyCvarZoomBased and cam:IsEffectivelyCvarZoomBased(sid, MAX_DISTANCE) then return end
  local situation = sid and type(profile.situations) == "table" and profile.situations[sid]
  local own = type(situation) == "table" and situation.situationSettings
  local settings = (type(own) == "table" and type(own.cvars) == "table" and own.cvars[MAX_DISTANCE] ~= nil) and own or standard
  local now = tonumber(settings.cvars[MAX_DISTANCE])
  if now and math.abs(now - value) < 1e-4 then return end
  settings.cvars[MAX_DISTANCE] = value
  Notify()
end)
