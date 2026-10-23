-- Clara Combo Points - DynamicCam's camera in one click (the portrait's menu, the Improvements
-- tab), in the copy that runs (built in, or the standalone DynamicCam): ticked, its Vertical Pitch
-- and Head Tracking on; unticked, both off. Its Zoom Increments: the player's for each (kept when
-- the box leaves it, given back when it comes back to it; the first time 0.2 yards a wheel tick
-- ticked, 2 unticked). Set in its standard settings, and in the situations that set them
-- themselves; the box shows its standard settings (ticked when both are on). DynamicCam itself
-- keeps running.

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

local function Standard(cam)
  local profile = cam and cam.db and cam.db.profile
  local standard = type(profile) == "table" and profile.standardSettings
  if type(standard) == "table" and type(standard.cvars) == "table" then return standard, profile end
end

-- the box's values in a settings table (the standard ones: all; a situation's: those it sets itself;
-- increments nil: its Zoom Increments left)
local function Put(settings, on, all, increments)
  local cvars = type(settings) == "table" and settings.cvars
  if type(cvars) ~= "table" then return end
  for _, cvar in ipairs(FEATURES) do
    if all or cvars[cvar] ~= nil then cvars[cvar] = on and 1 or 0 end
  end
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
  local situations = type(profile.situations) == "table" and profile.situations or {}
  local switch = self:CameraOn() ~= on -- (already in that state: the Zoom Increments left as they are)
  if switch and self.sv then Keep(self.sv, not on, standard, situations) end
  local kept = self.sv and type(self.sv[KEPT[on]]) == "table" and self.sv[KEPT[on]] or {}
  local keptSituations = type(kept.situations) == "table" and kept.situations or {}
  Put(standard, on, true, switch and (tonumber(kept.standard) or FIRST_INCREMENTS[on]) or nil)
  for id, situation in pairs(situations) do
    if type(situation) == "table" then
      Put(situation.situationSettings, on, false, switch and (tonumber(keptSituations[id]) or FIRST_INCREMENTS[on]) or nil)
    end
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
