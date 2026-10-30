"""Port DynamicCam 2.21.5 into Clara Combo Points (Modules/DynamicCam).
Usage: dc_port.py <DynamicCam dir> <ClaraComboPoints dir>
Every file of DynamicCam gets a guard (it does nothing unless the module runs: ClaraNS.DynamicCamRuns,
set by Modules/DynamicCam/Bootstrap.lua), its libraries too. Each edit must match the exact count
given, or the script stops. Bootstrap.lua and Glue.lua are Clara's own (not written here)."""
import os, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
out = os.path.join(dst, "Modules", "DynamicCam")

GUARD = ("local _, ClaraNS = ... -- (Clara Combo Points: DynamicCam built in, QoL.lua)\n"
         "if not (type(ClaraNS) == \"table\" and ClaraNS.DynamicCamRuns) then return end\n")
LIB_GUARD = ("local _, ClaraNS = ... -- (Clara Combo Points: loaded only for DynamicCam built in)\n"
             "if type(ClaraNS) == \"table\" and not ClaraNS.DynamicCamRuns then return end\n")
TEX_OLD = '"Interface\\\\AddOns\\\\" .. folderName .. "\\\\Ui\\\\Textures\\\\'
TEX_NEW = '"Interface\\\\AddOns\\\\ClaraComboPoints\\\\Modules\\\\DynamicCam\\\\Ui\\\\Textures\\\\'

def edit(text, old, new, count, where):
    n = text.count(old)
    if n != count:
        sys.exit(f"{where}: expected {count}, found {n}: {old[:80]!r}")
    return text.replace(old, new)

def read(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8-sig").replace("\r\n", "\n")

def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

# a fresh copy (Clara's own files kept)
keep = {}
for own in ("Bootstrap.lua", "Glue.lua"):
    p = os.path.join(out, own)
    if os.path.exists(p):
        keep[own] = read(p)
if os.path.isdir(out):
    shutil.rmtree(out)
shutil.copytree(src, out, ignore=shutil.ignore_patterns("DynamicCam.toc"))
for own, text in keep.items():
    write(os.path.join(out, own), text)

# the edits each file needs, besides its guard: (old, new, count)
EDITS = {
    "Core.lua": [("local folderName, Addon = ...", 'local folderName, Addon = "DynamicCam", ClaraNS.DynamicCamPrivate', 1),
                 ("DynamicCamDB", "ClaraDynamicCamDB", 5)],
    "UiHideModule.lua": [("local folderName, Addon = ...", 'local folderName, Addon = "DynamicCam", ClaraNS.DynamicCamPrivate', 1)],
    "ZoomBasedSettings.lua": [("local folderName, Addon = ...", 'local folderName, Addon = "DynamicCam", ClaraNS.DynamicCamPrivate', 1),
                              ("DynamicCamDB", "ClaraDynamicCamDB", 2)],
    "ZoomBasedEditor.lua": [("local folderName, Addon = ...", 'local folderName, Addon = "DynamicCam", ClaraNS.DynamicCamPrivate', 1)],
    "DefaultSettings.lua": [("local folderName = ...", 'local folderName = "DynamicCam"', 1)],
    "Sharing.lua": [("DynamicCamDB", "ClaraDynamicCamDB", 2)],
    os.path.join("Options", "Widgets.lua"): [("local folderName = ...", 'local folderName = "DynamicCam"', 1), (TEX_OLD, TEX_NEW, 1)],
    os.path.join("Ui", "Controls.lua"): [("local folderName = ...", 'local folderName = "DynamicCam"', 1), (TEX_OLD, TEX_NEW, 1)],
    os.path.join("Ui", "SituationsPage.lua"): [("local folderName = ...", 'local folderName = "DynamicCam"', 1), (TEX_OLD, TEX_NEW, 2)],
    # its page in the game's options: under Clara's "Interface improvements"
    "Options.lua": [('LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DynamicCam", "DynamicCam")',
                     'LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DynamicCam", "DynamicCam", ClaraNS.qolCategory and ClaraNS.qolCategory:GetID() or nil)', 1)],
}

EXTRA = {
    # Turned off (Clara's camera box: DynamicCam:Disable()), nothing of it stays at work. In
    # DynamicCam, the frame applying the zoom-based settings ran for ever, applying all of its camera
    # settings at each zoom (the game's Max Camera Distance put back at once); its mouse wheel zoom
    # stayed in place; its guards over the game's settings (motion sickness, mouse look speed,
    # camera following style) went on.
    "ZoomBasedSettings.lua": [("""local function CvarUpdateFunction(self, elapsed)
  -- Skip if temporarily disabled""", """local function CvarUpdateFunction(self, elapsed)
  -- (Clara Combo Points: nothing while DynamicCam is off; all applied again once on)
  if not DynamicCam:IsEnabled() then
    lastAppliedZoom = nil
    return
  end
  -- Skip if temporarily disabled""", 1)],
    "MouseZoom.lua": [("""function DynamicCam:ReactiveZoomIsOn()""", """-- (Clara Combo Points: the game's own zoom again, DynamicCam turned off)
function DynamicCam:NativeZoom()
  CameraZoomIn = OldCameraZoomIn
  CameraZoomOut = OldCameraZoomOut
  reactiveZoomTarget = nil
  reactiveZoomTargetCorrectionFrame:SetScript("OnUpdate", nil)
end

function DynamicCam:ReactiveZoomIsOn()""", 1)],
    "Core.lua": [("""  self:ReactiveZoomOff()

  constantlyRunningFrame:SetScript("OnUpdate", nil)""", """  self:ReactiveZoomOff()
  if not self:IsEnabled() then self:NativeZoom() end -- (Clara Combo Points: turned off, not a profile change)

  constantlyRunningFrame:SetScript("OnUpdate", nil)""", 1)],
    os.path.join("Options", "CvarMonitor.lua"): [
        ("""  local foundMouseLookSpeedSlider = false
  local foundMotionSicknessElement = false

  -- ###################### Mouse ######################
  if SettingsPanel.Container.SettingsList.Header.Title:GetText() == CONTROLS_LABEL then""",
         """  local foundMouseLookSpeedSlider = false
  local foundMotionSicknessElement = false
  local on = DynamicCam:IsEnabled() -- (Clara Combo Points: the game's settings left alone while off)

  -- ###################### Mouse ######################
  if on and SettingsPanel.Container.SettingsList.Header.Title:GetText() == CONTROLS_LABEL then""", 1),
        ("""  elseif SettingsPanel.Container.SettingsList.Header.Title:GetText() == ACCESSIBILITY_GENERAL_LABEL then""",
         """  elseif on and SettingsPanel.Container.SettingsList.Header.Title:GetText() == ACCESSIBILITY_GENERAL_LABEL then""", 1),
        # (when undone, the slider was disabled again instead of enabled)
        ("""    if not mouseLookSpeedSlider.Slider:IsEnabled() then
      -- Function name "SetEnabled" introduced in 11.0.0.
      if mouseLookSpeedSlider.SetEnabled then
        mouseLookSpeedSlider:SetEnabled(false)
      else
        mouseLookSpeedSlider:SetEnabled_(false)
      end
    end
    mouseLookSpeedSlider = nil""", """    if not mouseLookSpeedSlider.Slider:IsEnabled() then
      -- Function name "SetEnabled" introduced in 11.0.0.
      if mouseLookSpeedSlider.SetEnabled then
        mouseLookSpeedSlider:SetEnabled(true)
      else
        mouseLookSpeedSlider:SetEnabled_(true)
      end
    end
    mouseLookSpeedSlider = nil""", 1),
        ("""local function ShoulderOffsetInUse()
  if not DynamicCam.db then return false end""", """local function ShoulderOffsetInUse()
  if not DynamicCam.db or not DynamicCam:IsEnabled() then return false end -- (Clara Combo Points: not while off)""", 1),
        ("""local function DynamicPitchInUse()
  return tonumber(GetCVar("test_cameraDynamicPitch")) == 1""", """local function DynamicPitchInUse()
  if not DynamicCam:IsEnabled() then return false end -- (Clara Combo Points: not while off)
  return tonumber(GetCVar("test_cameraDynamicPitch")) == 1""", 1),
        ("""  elseif cvar == "cameraSmoothStyle" and numericValue ~= 0 then""",
         """  elseif cvar == "cameraSmoothStyle" and numericValue ~= 0 and DynamicCam:IsEnabled() then""", 1)],
}
for rel, more in EXTRA.items():
    EDITS[rel] = EDITS.get(rel, []) + more

done = set()
for root, _, files in os.walk(out):
    for name in files:
        if not name.endswith(".lua") or name in ("Bootstrap.lua", "Glue.lua") and root == out:
            continue
        path = os.path.join(root, name)
        rel = os.path.relpath(path, out)
        text = read(path)
        if rel.startswith("Libs" + os.sep):
            text = LIB_GUARD + text
        else:
            for old, new, count in EDITS.get(rel, []):
                text = edit(text, old, new, count, rel)
            if "DynamicCamDB" in text.replace("ClaraDynamicCamDB", ""):
                sys.exit(f"{rel}: DynamicCamDB left")
            text = GUARD + text
            done.add(rel)
        write(path, text)

missing = set(EDITS) - done
if missing:
    sys.exit(f"files not found: {sorted(missing)}")
print("ok", out)
