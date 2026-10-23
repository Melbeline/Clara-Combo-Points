-- Clara Combo Points - DynamicCam's camera in one click (the portrait's menu, the Improvements
-- tab), in the copy that runs (built in, or the standalone DynamicCam): ticked, its Vertical Pitch
-- and Head Tracking on and its Zoom Increments at 0.2 yards a wheel tick; unticked, both off and
-- 2 yards a tick. Set in its standard settings, and in the situations that set them themselves;
-- the box shows its standard settings (ticked when both are on). DynamicCam itself keeps running.

local ADDON, ns = ...

-- the DynamicCam that runs, built in or standalone
local function Cam()
  local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
  return AceAddon and AceAddon:GetAddon("DynamicCam", true) or nil
end

local FEATURES = { "test_cameraDynamicPitch", "test_cameraHeadMovementStrength" } -- (Vertical Pitch, Head Tracking: 1 on, 0 off)
local INCREMENTS = { [true] = 0.2, [false] = 2 } -- (Zoom Increments, as its slider shows them: kept as that minus 1)

local function Standard(cam)
  local profile = cam and cam.db and cam.db.profile
  local standard = type(profile) == "table" and profile.standardSettings
  if type(standard) == "table" and type(standard.cvars) == "table" then return standard, profile end
end

-- the box's values in a settings table (the standard ones: all; a situation's: those it sets itself)
local function Put(settings, on, all)
  local cvars = type(settings) == "table" and settings.cvars
  if type(cvars) ~= "table" then return end
  for _, cvar in ipairs(FEATURES) do
    if all or cvars[cvar] ~= nil then cvars[cvar] = on and 1 or 0 end
  end
  if all or settings.reactiveZoomAddIncrementsAlways ~= nil then
    settings.reactiveZoomAddIncrementsAlways = INCREMENTS[on] - 1
  end
end

function ns:CameraAvailable() return Standard(Cam()) ~= nil end
function ns:CameraOn()
  local standard = Standard(Cam())
  if not standard then return false end
  for _, cvar in ipairs(FEATURES) do
    if tonumber(standard.cvars[cvar]) ~= 1 then return false end
  end
  return true
end
function ns:SetCameraOn(on)
  local cam = Cam()
  local standard, profile = Standard(cam)
  if not standard then return end
  on = on and true or false
  Put(standard, on, true)
  for _, situation in pairs(type(profile.situations) == "table" and profile.situations or {}) do
    if type(situation) == "table" then Put(situation.situationSettings, on, false) end
  end
  if cam:IsEnabled() and cam.ApplySettings then cam:ApplySettings() end
  local registry = LibStub("AceConfigRegistry-3.0", true) -- (its options, if open: the new values)
  if registry then
    pcall(registry.NotifyChange, registry, "DynamicCam")
    pcall(registry.NotifyChange, registry, "DynamicCam_Detached")
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
