-- Clara Combo Points - Bar scale: one slider for the action bars, the micro menu and the bags, all at
-- once (50 to 200 %). The game's frames keep their own scale (Edit Mode's size) times this one: each
-- scaled from the point it is placed by, so the bars standing together stay together. With ClassicUI's
-- classic bar, its band (bars, micro menu, bags) is sized by it instead (Modules/ClassicUI/Bar/Band.lua).
-- Protected frames: changed out of combat (in a fight, once it ends). Its page in Esc > Options > AddOns >
-- Clara > Interface; /barscale 120 sets it. Saved with Clara's settings (ClaraComboPointsDB.barScale).

local ADDON, ns = ...
local L = ns.L

local MIN, MAX, STEP = 0.5, 2, 0.05
local FRAMES = { "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
  "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "PossessActionBar",
  "MicroMenuContainer", "MicroButtonAndBagsBar", "BagsBar" }

local runs = ns:QolRuns("barscale")
local function Clamp(v) return math.max(MIN, math.min(MAX, v)) end

function ns:BarScale()
  local v = self.sv and tonumber(self.sv.barScale)
  return (runs and v) and Clamp(v) or 1
end
-- (ClassicUI's band reads it: its size times this)
function ns.BarScaleFactor() return ns:BarScale() end

ns:SetQolOpener("barscale", function() ns:OpenSettingsTo(ns.barScaleCategory) end)
if not runs then return end

local function ClassicBar()
  local cui = ns.ClassicUIPrivate
  return cui and cui.ClassicBarActive and cui.ClassicBarActive() and cui or nil
end

-- The game's frames: their own scale remembered, set times ours
local base, hooked = {}, {}
local busy, waiting = false, false
local waiter = CreateFrame("Frame")

local function Blocked(frame)
  return InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected()
end

local function Put(frame)
  local want = (base[frame] or 1) * ((ClassicBar() and 1) or ns:BarScale())
  if math.abs((frame:GetScale() or 1) - want) < .001 then return end
  if Blocked(frame) then
    waiting = true
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  busy = true
  frame:SetScale(want)
  busy = false
end

local function Hook(frame)
  if hooked[frame] or not (frame.SetScale and frame.GetScale) then return end
  hooked[frame] = true
  base[frame] = frame:GetScale() or 1
  hooksecurefunc(frame, "SetScale", function(self, scale)
    if busy then return end
    base[self] = tonumber(scale) or 1 -- (the game's own size: ours goes on top of it)
    Put(self)
  end)
end

function ns:ApplyBarScale()
  local cui = ClassicBar()
  if cui then
    -- ClassicUI's band takes the scale itself; the game's frames left at their own size
    for frame in pairs(hooked) do Put(frame) end
    if cui.band and cui.band.Apply and not (InCombatLockdown and InCombatLockdown()) then pcall(cui.band.Apply) end
    return
  end
  for _, name in ipairs(FRAMES) do
    local frame = _G[name]
    if type(frame) == "table" then
      Hook(frame)
      Put(frame)
    end
  end
end

function ns:SetBarScale(v)
  v = tonumber(v)
  if not v then return end
  v = Clamp(math.floor(v / STEP + .5) * STEP)
  if math.abs(v - 1) < .001 then self.sv.barScale = nil else self.sv.barScale = v end
  self:ApplyBarScale()
end

waiter:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if waiting then
      waiting = false
      ns:ApplyBarScale()
    end
    return
  end
  -- (the game's bars made and placed by then; Edit Mode's layout too)
  if C_Timer and C_Timer.After then C_Timer.After(0, function() ns:ApplyBarScale() end) else ns:ApplyBarScale() end
end)
waiter:RegisterEvent("PLAYER_ENTERING_WORLD")
waiter:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

SLASH_CLARABARSCALE1 = "/barscale"
SlashCmdList.CLARABARSCALE = function(msg)
  local n = tonumber((msg or ""):match("(%d+)"))
  if n then
    ns:SetBarScale(n / 100)
  else
    ns.Print(L.BS_COMMAND:format(math.floor(ns:BarScale() * 100 + .5)))
  end
end

---------------------------------------------------------------------------
-- Its page: the slider (the game's own), and the default size
---------------------------------------------------------------------------
local function Page()
  local parent = ns:QolCategory("barscale")
  if not (parent and Settings and Settings.RegisterVerticalLayoutSubcategory and Settings.RegisterProxySetting
    and Settings.CreateSlider and Settings.CreateSliderOptions) then return end
  local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, L.BS_TITLE)
  ns.barScaleCategory = category
  local setting = Settings.RegisterProxySetting(category, "ClaraBarScale", Settings.VarType.Number, L.BS_SLIDER, 100,
    function() return math.floor(ns:BarScale() * 100 + .5) end,
    function(v) ns:SetBarScale(v / 100) end)
  local options = Settings.CreateSliderOptions(MIN * 100, MAX * 100, STEP * 100)
  local label = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
  if options.SetLabelFormatter and label and label.Right then
    options:SetLabelFormatter(label.Right, function(v) return ("%d %%"):format(math.floor(v + .5)) end)
  end
  Settings.CreateSlider(category, setting, options, L.BS_SLIDER_TIP)
  if CreateSettingsButtonInitializer and layout and layout.AddInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer("", L.BS_DEFAULT, function()
      ns:SetBarScale(1)
      if setting.SetValue then pcall(setting.SetValue, setting, 100) end
    end, L.BS_DEFAULT_TIP, false))
  end
end
local ok = pcall(Page)
if not ok then ns.barScaleCategory = nil end
