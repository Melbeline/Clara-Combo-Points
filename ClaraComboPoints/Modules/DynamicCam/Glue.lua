-- Clara Combo Points - DynamicCam's camera in one click (the portrait's menu, the Improvements
-- tab): on, the copy that runs (built in, or the standalone DynamicCam) changes the camera as set
-- in it; off, it is stopped and what it sets goes back to the game's own camera (the game's
-- default values). Kept for the next sessions: an "off" camera is not started at all at login.

local ADDON, ns = ...

-- the DynamicCam that runs, built in or standalone
local function Cam()
  local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
  return AceAddon and AceAddon:GetAddon("DynamicCam", true) or nil
end

local function SavedOff()
  local sv = type(ClaraComboPointsDB) == "table" and ClaraComboPointsDB or nil
  return sv ~= nil and sv.cameraOff == true
end

-- turned off in a past session: not started (before the game's login enables the addons)
do
  local cam = Cam()
  if cam and SavedOff() and cam.SetEnabledState then cam:SetEnabledState(false) end
end

-- The camera settings DynamicCam sets (its standard ones and its situations'), back to the
-- game's defaults.
local function GameCamera(cam)
  local profile = cam.db and cam.db.profile
  if type(profile) ~= "table" or not GetCVarDefault then return end
  local cvars = {}
  local standard = profile.standardSettings and profile.standardSettings.cvars
  for cvar in pairs(type(standard) == "table" and standard or {}) do cvars[cvar] = true end
  for _, situation in pairs(type(profile.situations) == "table" and profile.situations or {}) do
    local own = type(situation) == "table" and situation.situationSettings and situation.situationSettings.cvars
    for cvar in pairs(type(own) == "table" and own or {}) do cvars[cvar] = true end
  end
  for cvar in pairs(cvars) do
    local ok, value = pcall(GetCVarDefault, cvar)
    if ok and value ~= nil then pcall(SetCVar, cvar, value) end
  end
end

function ns:CameraAvailable() return Cam() ~= nil end
function ns:CameraOn()
  local cam = Cam()
  return cam ~= nil and cam:IsEnabled() and true or false
end
function ns:SetCameraOn(on)
  local cam = Cam()
  if not cam or not self.sv then return end
  self.sv.cameraOff = (not on) or nil
  if on then
    cam:Enable()
  else
    cam:Disable()
    GameCamera(cam)
  end
  if self.RefreshQol then self:RefreshQol() end
end

-- the Improvements tab: the box, and DynamicCam's own window
ns:SetQolSwitches("dynamiccam", {
  { label = "DC_SW_ON", get = function() return ns:CameraOn() end, set = function(on) ns:SetCameraOn(on) end },
})
ns:SetQolOpener("dynamiccam", function()
  local cam = Cam()
  if cam and cam.OpenMenu then cam:OpenMenu() end
end)
