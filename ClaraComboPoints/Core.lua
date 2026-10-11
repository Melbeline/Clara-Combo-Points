-- Clara Combo Points
-- Rogue and druid (Cat Form) HUD for WoW Forever: combo points on the top row, energy on
-- the bottom bar.
--
-- Combo points are never predicted from a spell table: the game is asked directly
-- (GetComboPoints on the current target), so crits, talents and procs are always right
-- and nothing needs updating when spells change.
-- Forever can hand these numbers back as "secret values" that addon code is not allowed
-- to read. They are only ever passed straight to StatusBar:SetValue / FontString:SetText,
-- which accept them, so the display works whether they are secret or not.

local ADDON, ns = ...
_G.ClaraComboPoints = ns
local L = ns.L

ns.VERSION = "1.2.0"

local NUM_POINTS    = 5
local POWER_ENERGY  = Enum and Enum.PowerType and Enum.PowerType.Energy or 3
local POWER_COMBO   = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local WHITE         = "Interface\\Buttons\\WHITE8X8"
local FONT_DIR      = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Fonts\\"
local issecretvalue = issecretvalue or function() return false end
local UnitIsFeignDeath = UnitIsFeignDeath or function() return false end

-- Geometry is in reference pixels: real screen pixels on the 2560x1440 windowed client the
-- HUD was designed on (1359 px tall render area). The HUD keeps that size relative to the
-- window height whatever the in-game UI scale is; the Scale option multiplies it.
local REF_SCALE = 768 / 1359
local WIDTH, CP_HEIGHT, CP_GAP, ROW_GAP, ENERGY_HEIGHT = 292, 25, 3, 4, 24
local COMBO_REFRESH = 0.1 -- safety refresh of the combo points (events do the real work)

ns.MIN_SCALE, ns.MAX_SCALE = 10, 500 -- percent

ns.fonts = {
  { name = "Arial Narrow",      path = "Fonts\\ARIALN.TTF" },
  { name = "Friz Quadrata",     path = "Fonts\\FRIZQT__.TTF" },
  { name = "Morpheus",          path = "Fonts\\MORPHEUS.TTF" },
  { name = "Skurri",            path = "Fonts\\SKURRI.TTF" },
  { name = "Emily's Candy",     path = FONT_DIR .. "EmilysCandy-Regular.ttf" },
  { name = "Bangers",           path = FONT_DIR .. "Bangers-Regular.ttf" },
  { name = "Luckiest Guy",      path = FONT_DIR .. "LuckiestGuy-Regular.ttf" },
  { name = "Chewy",             path = FONT_DIR .. "Chewy-Regular.ttf" },
  { name = "Permanent Marker",  path = FONT_DIR .. "PermanentMarker-Regular.ttf" },
  { name = "Creepster",         path = FONT_DIR .. "Creepster-Regular.ttf" },
  { name = "Pirata One",        path = FONT_DIR .. "PirataOne-Regular.ttf" },
  { name = "MedievalSharp",     path = FONT_DIR .. "MedievalSharp.ttf" },
  { name = "Cinzel Decorative", path = FONT_DIR .. "CinzelDecorative-Bold.ttf" },
  { name = "Bebas Neue",        path = FONT_DIR .. "BebasNeue-Regular.ttf" },
  { name = "Russo One",         path = FONT_DIR .. "RussoOne-Regular.ttf" },
  { name = "Black Ops One",     path = FONT_DIR .. "BlackOpsOne-Regular.ttf" },
  { name = "Audiowide",         path = FONT_DIR .. "Audiowide-Regular.ttf" },
  { name = "Righteous",         path = FONT_DIR .. "Righteous-Regular.ttf" },
  { name = "Press Start 2P",    path = FONT_DIR .. "PressStart2P-Regular.ttf" },
  { name = "Share Tech Mono",   path = FONT_DIR .. "ShareTechMono-Regular.ttf" },
}

-- Settings of one profile. Rogues and druids each have their own profile (account-wide);
-- colours sampled from the reference screenshot.
ns.PROFILES = { "ROGUE", "DRUID" }
local defaults = {
  locked   = true,
  x        = 0,      -- centre of the HUD, reference pixels from the screen centre
  y        = -204,
  scale    = 1,      -- 1 = 100 %
  alpha    = 1,      -- whole HUD
  font     = "Arial Narrow",
  fontSize = 17,
  outline  = "OUTLINE",
  showText = true,
  druidCatOnly = true, -- druids: HUD only in Cat Form
  cpSource = "TARGET", -- TARGET: GetComboPoints(player, target) / PLAYER: UnitPower(player, combo)
  colors = {
    cp1    = { r = 1, g = 1,    b = 0,    a = 1 },
    cp2    = { r = 1, g = .808, b = 0,    a = 1 },
    cp3    = { r = 1, g = .620, b = 0,    a = 1 },
    cp4    = { r = 1, g = .427, b = 0,    a = 1 },
    cp5    = { r = 1, g = 0,    b = .455, a = 1 },
    energy = { r = 1, g = 1,    b = 0,    a = 1 },
    bg     = { r = 0, g = 0,    b = 0,    a = .6 },
    text   = { r = 1, g = 1,    b = 1,    a = 1 },
  },
}
ns.defaults = defaults

local function CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(v, dst[k])
    elseif type(dst[k]) ~= type(v) then
      dst[k] = v
    end
  end
  return dst
end

local function Print(msg)
  print("|cffffd200Clara Combo Points|r: " .. msg)
end
ns.Print = Print

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
local hud = CreateFrame("Frame", "ClaraComboPointsHUD", UIParent)
hud:SetSize(WIDTH, CP_HEIGHT + ROW_GAP + ENERGY_HEIGHT)
hud:SetClampedToScreen(true)
hud:SetMovable(true)
hud:EnableMouse(false)
hud:RegisterForDrag("LeftButton")
if hud.SetDontSavePosition then hud:SetDontSavePosition(true) end
hud:Hide()
ns.hud = hud

local function CreateBar(minValue, maxValue)
  local bar = CreateFrame("StatusBar", nil, hud)
  bar:SetStatusBarTexture(WHITE)
  bar:SetMinMaxValues(minValue, maxValue)
  bar:SetValue(0)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  return bar
end

-- One status bar per combo point, spanning [i-1, i]: feeding every bar the same combo
-- count fills the first N of them, without ever having to read the number.
local cells = {}
local cellWidth = (WIDTH - (NUM_POINTS - 1) * CP_GAP) / NUM_POINTS
for i = 1, NUM_POINTS do
  local bar = CreateBar(i - 1, i)
  bar:SetPoint("TOPLEFT", (i - 1) * (cellWidth + CP_GAP), 0)
  bar:SetSize(cellWidth, CP_HEIGHT)
  cells[i] = bar
end

local energy = CreateBar(0, 100)
energy:SetPoint("BOTTOMLEFT")
energy:SetPoint("BOTTOMRIGHT")
energy:SetHeight(ENERGY_HEIGHT)

local energyText = energy:CreateFontString(nil, "OVERLAY")
energyText:SetPoint("CENTER")
energyText:SetFont(ns.fonts[1].path, defaults.fontSize, defaults.outline)

-- Shown while unlocked
local mover = CreateFrame("Frame", nil, hud)
mover:SetAllPoints()
mover:SetFrameLevel(hud:GetFrameLevel() + 10)
mover:Hide()
local moverTex = mover:CreateTexture(nil, "OVERLAY")
moverTex:SetAllPoints()
moverTex:SetColorTexture(.25, .6, 1, .35)
local moverText = mover:CreateFontString(nil, "OVERLAY")
moverText:SetFont(ns.fonts[1].path, 14, "OUTLINE")
moverText:SetPoint("BOTTOM", mover, "TOP", 0, 4)
moverText:SetText(L.MOVER)

---------------------------------------------------------------------------
-- Live values
---------------------------------------------------------------------------
local function ReadComboPoints()
  if not UnitExists("target") then return 0 end
  -- A dead target keeps no combo points: drop them the moment the death is known.
  if UnitIsDead("target") and not UnitIsFeignDeath("target") then return 0 end
  local ok, v
  if ns.db.cpSource == "TARGET" and GetComboPoints then
    ok, v = pcall(GetComboPoints, "player", "target")
  end
  if not ok then
    if not UnitCanAttack("player", "target") then return 0 end
    ok, v = pcall(UnitPower, "player", POWER_COMBO)
  end
  if ok and (issecretvalue(v) or type(v) == "number") then return v end
  return 0
end

local lastCombo
local function UpdateCombo()
  if not hud:IsShown() then return end -- re-read on show
  local v = ns.preview and NUM_POINTS or ReadComboPoints()
  if issecretvalue(v) then
    lastCombo = nil
  elseif v == lastCombo then
    return
  else
    lastCombo = v
  end
  for i = 1, NUM_POINTS do cells[i]:SetValue(v) end
end

local lastEnergy
local function UpdateEnergy()
  if not hud:IsShown() then return end
  local v = UnitPower("player", POWER_ENERGY)
  if issecretvalue(v) then
    lastEnergy = nil
  elseif v == lastEnergy then
    return
  else
    lastEnergy = v
  end
  energy:SetValue(v)
  energyText:SetText(v)
end

local function UpdateEnergyMax()
  if not hud:IsShown() then return end
  local m = UnitPowerMax("player", POWER_ENERGY)
  if issecretvalue(m) or (type(m) == "number" and m > 0) then
    energy:SetMinMaxValues(0, m)
  end
  lastEnergy = nil
end

local function RefreshValues()
  lastCombo, lastEnergy = nil, nil
  UpdateEnergyMax()
  UpdateEnergy()
  UpdateCombo()
end

-- Updates are skipped while the HUD is hidden, so catch up on everything when it comes back.
hud:SetScript("OnShow", RefreshValues)

-- Rogues always see the HUD. Druids see it while their power is energy, i.e. in Cat Form
-- (the test Blizzard's own druid combo bar uses), unless "Cat Form only" is off. While
-- unlocked or while the options are open it shows in any form, so it can be moved and
-- coloured.
local function ShouldShow()
  if ns.isRogue then return true end
  if not ns.isDruid then return false end
  if not ns.db.druidCatOnly or not ns.db.locked or ns.optionsOpen then return true end
  local powerType = UnitPowerType("player")
  return issecretvalue(powerType) or powerType == POWER_ENERGY
end

function ns:UpdateVisibility()
  hud:SetShown(ShouldShow())
end

-- Energy regenerates continuously, so it is read every frame: each point shows up on the
-- very frame the client has it. Unchanged values cost a single comparison.
local sinceCombo = 0
hud:SetScript("OnUpdate", function(_, elapsed)
  UpdateEnergy()
  sinceCombo = sinceCombo + elapsed
  if sinceCombo >= COMBO_REFRESH then
    sinceCombo = 0
    UpdateCombo()
  end
end)

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local fontPaths = {}
for _, f in ipairs(ns.fonts) do fontPaths[f.name] = f.path end

-- Built-in list plus any font shared through LibSharedMedia by other addons.
function ns:GetFonts()
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  if LSM then
    for _, name in ipairs(LSM:List("font")) do
      if not fontPaths[name] then
        local path = LSM:Fetch("font", name, true)
        if path then
          fontPaths[name] = path
          self.fonts[#self.fonts + 1] = { name = name, path = path }
        end
      end
    end
  end
  return self.fonts
end

function ns:GetFontPath(name)
  if not fontPaths[name] then self:GetFonts() end
  return fontPaths[name] or fontPaths[defaults.font]
end

function ns:ApplyFont()
  local db = self.db
  local flags = db.outline ~= "NONE" and db.outline or ""
  local ok = energyText:SetFont(self:GetFontPath(db.font), db.fontSize, flags)
  if ok == false or not energyText:GetFont() then
    energyText:SetFont(fontPaths[defaults.font], db.fontSize, flags)
  end
  energyText:SetShown(db.showText)
end

function ns:ApplyColors()
  local c = self.db.colors
  local bg = c.bg
  for i = 1, NUM_POINTS do
    local k = c["cp" .. i]
    cells[i]:SetStatusBarColor(k.r, k.g, k.b, k.a)
    cells[i].bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
  end
  energy:SetStatusBarColor(c.energy.r, c.energy.g, c.energy.b, c.energy.a)
  energy.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
  energyText:SetTextColor(c.text.r, c.text.g, c.text.b, c.text.a)
end

function ns:ApplyAlpha()
  hud:SetAlpha(self.db.alpha)
end

function ns:ApplyPosition()
  local db = self.db
  hud:ClearAllPoints()
  -- one HUD unit is `scale` reference pixels
  hud:SetPoint("CENTER", UIParent, "CENTER", db.x / db.scale, db.y / db.scale)
end

function ns:ApplyScale()
  hud:SetScale(REF_SCALE * self.db.scale / UIParent:GetEffectiveScale())
  self:ApplyPosition()
end

function ns:SetScalePercent(percent)
  percent = tonumber(percent)
  if not percent then self:RefreshOptions() return end
  percent = math.floor(math.min(self.MAX_SCALE, math.max(self.MIN_SCALE, percent)) + .5)
  self.db.scale = percent / 100
  self:ApplyScale()
  self:RefreshOptions()
end

function ns:GetScalePercent()
  return math.floor(self.db.scale * 100 + .5)
end

function ns:SavePosition()
  local cx, cy = hud:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if cx and ux and not issecretvalue(cx) and not issecretvalue(cy) then
    -- both centres in absolute units, then converted to reference pixels
    local hs, us = hud:GetEffectiveScale(), UIParent:GetEffectiveScale()
    self.db.x = math.floor((cx * hs - ux * us) / REF_SCALE + .5)
    self.db.y = math.floor((cy * hs - uy * us) / REF_SCALE + .5)
  end
  self:ApplyPosition()
end

function ns:ResetPosition()
  self.db.x, self.db.y = defaults.x, defaults.y
  self:ApplyPosition()
end

function ns:SetLocked(locked)
  self.db.locked = locked and true or false
  hud:EnableMouse(not self.db.locked)
  mover:SetShown(not self.db.locked)
  self:UpdateVisibility()
  self:RefreshOptions()
end

hud:SetScript("OnDragStart", function(self)
  if not ns.db.locked then self:StartMoving() end
end)
hud:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  ns:SavePosition()
end)

-- Preview: shows all five points (to judge colours) until turned off or combat starts.
function ns:SetPreview(on)
  self.preview = on and true or false
  lastCombo = nil
  UpdateCombo()
  self:RefreshOptions()
end

function ns:SetOptionsOpen(open)
  self.optionsOpen = open and true or false
  self:UpdateVisibility()
end

function ns:SetDruidCatOnly(on)
  self.db.druidCatOnly = on and true or false
  self:UpdateVisibility()
  self:RefreshOptions()
end

function ns:SetComboSource(source)
  self.db.cpSource = source
  lastCombo = nil
  UpdateCombo()
  self:RefreshOptions()
end

function ns:ApplyAll()
  self:ApplyScale()
  self:ApplyColors()
  self:ApplyFont()
  self:ApplyAlpha()
  self:SetLocked(self.db.locked)
  RefreshValues()
end

function ns:ResetColors()
  self.db.colors = CopyDefaults(defaults.colors, {})
  self:ApplyColors()
  self:RefreshOptions()
end

-- Resets the profile in use (the options tab being edited, or this character's class).
function ns:ResetAll()
  wipe(self.db)
  CopyDefaults(defaults, self.db)
  self:ApplyAll()
  self:RefreshOptions()
end

-- The HUD draws the profile of this character's class; while the options are open it draws
-- the profile of the selected tab, so the other class can be set up and seen from here.
function ns:SetActiveProfile(class)
  local profile = self.sv.profiles[class]
  if not profile or profile == self.db then return end
  self.db = profile
  self:ApplyAll()
  self:RefreshOptions()
end

function ns:SetLanguage(code)
  if not self:IsLanguage(code) then return end
  self.sv.language = code
  self.lang = code
  moverText:SetText(L.MOVER)
  self:RelabelOptions()
end

-- Options.lua replaces these
function ns:RefreshOptions() end
function ns:RelabelOptions() end
function ns:ToggleOptions() end

local function CleanProfile(db)
  CopyDefaults(defaults, db)
  if db.scale * 100 < ns.MIN_SCALE or db.scale * 100 > ns.MAX_SCALE then db.scale = defaults.scale end
  if db.alpha < 0 or db.alpha > 1 then db.alpha = defaults.alpha end
  if db.fontSize < 6 or db.fontSize > 64 then db.fontSize = defaults.fontSize end
  if db.outline ~= "NONE" and db.outline ~= "OUTLINE" and db.outline ~= "THICKOUTLINE" then db.outline = defaults.outline end
  if db.cpSource ~= "TARGET" and db.cpSource ~= "PLAYER" then db.cpSource = defaults.cpSource end
end

local function InitDB()
  local sv = type(ClaraComboPointsDB) == "table" and ClaraComboPointsDB or {}
  if type(sv.profiles) ~= "table" then
    -- 1.0 and 1.1 kept a single set of settings: it becomes the start of both profiles
    local old = {}
    for k, v in pairs(sv) do old[k], sv[k] = v, nil end
    sv.profiles = {}
    for _, class in ipairs(ns.PROFILES) do sv.profiles[class] = CopyDefaults(old, {}) end
  end
  for _, class in ipairs(ns.PROFILES) do
    if type(sv.profiles[class]) ~= "table" then sv.profiles[class] = {} end
    CleanProfile(sv.profiles[class])
  end
  -- account-wide: interface language (nil = follow the client) and options window theme
  if not ns:IsLanguage(sv.language) then sv.language = nil end
  if sv.language then ns.lang = sv.language end
  if sv.skin ~= "CLASSIC" and sv.skin ~= "MODERN" then sv.skin = "CLASSIC" end
  moverText:SetText(L.MOVER)
  ClaraComboPointsDB = sv
  ns.sv = sv
  ns.db = sv.profiles.ROGUE
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...) ns[event](ns, ...) end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

function ns:ADDON_LOADED(name)
  if name ~= ADDON then return end
  events:UnregisterEvent("ADDON_LOADED")
  InitDB()
end

function ns:PLAYER_LOGIN()
  events:UnregisterEvent("PLAYER_LOGIN")
  local _, class = UnitClass("player")
  self.isRogue = (class == "ROGUE")
  self.isDruid = (class == "DRUID")
  self.enabled = self.isRogue or self.isDruid
  self.homeClass = self.isDruid and "DRUID" or "ROGUE"
  self.db = self.sv.profiles[self.homeClass]
  self:ApplyAll()
  if not self.enabled then return end -- dormant on other classes: no events, no updates

  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("UI_SCALE_CHANGED")
  events:RegisterEvent("DISPLAY_SIZE_CHANGED")
  events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
  events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
  events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  events:RegisterUnitEvent("UNIT_HEALTH", "target")
  events:RegisterUnitEvent("UNIT_FLAGS", "target")
  pcall(events.RegisterEvent, events, "UNIT_DIED") -- not in every client build
  if self.isDruid then
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player") -- power type changes with the form
    events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  end
  self:UpdateVisibility()
end

function ns:PLAYER_ENTERING_WORLD()
  self:ApplyScale()
  self:UpdateVisibility()
  RefreshValues()
end

function ns:UNIT_DISPLAYPOWER()
  self:UpdateVisibility()
  UpdateEnergyMax()
  UpdateEnergy()
end
ns.UPDATE_SHAPESHIFT_FORM = ns.UNIT_DISPLAYPOWER

function ns:PLAYER_TARGET_CHANGED()
  UpdateCombo()
end

function ns:UNIT_POWER_FREQUENT(_, powerType)
  if issecretvalue(powerType) then
    UpdateEnergy()
    UpdateCombo()
  elseif powerType == "COMBO_POINTS" then
    UpdateCombo()
  elseif powerType == "ENERGY" then
    UpdateEnergy()
  end
end
ns.UNIT_POWER_UPDATE = ns.UNIT_POWER_FREQUENT

function ns:UNIT_MAXPOWER()
  UpdateEnergyMax()
  UpdateEnergy()
end

-- Target death: UNIT_HEALTH arrives with the killing blow, UNIT_FLAGS / UNIT_DIED as backup.
function ns:UNIT_HEALTH()
  UpdateCombo()
end
ns.UNIT_FLAGS = ns.UNIT_HEALTH
ns.UNIT_DIED = ns.UNIT_HEALTH

function ns:PLAYER_REGEN_DISABLED()
  if self.preview then self:SetPreview(false) end
end

function ns:UI_SCALE_CHANGED()
  self:ApplyScale()
end
ns.DISPLAY_SIZE_CHANGED = ns.UI_SCALE_CHANGED

---------------------------------------------------------------------------
-- Slash commands: /clara, /cl
---------------------------------------------------------------------------
SLASH_CLARACOMBOPOINTS1 = "/clara"
SLASH_CLARACOMBOPOINTS2 = "/cl"
SlashCmdList.CLARACOMBOPOINTS = function(msg)
  if not ns.db then return end
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "lock" then
    ns:SetLocked(true)
    Print(L.LOCKED)
  elseif cmd == "unlock" then
    ns:SetLocked(false)
    Print(L.UNLOCKED)
  elseif cmd == "scale" and tonumber(arg) then
    ns:SetScalePercent(arg)
    Print(L.SCALE_SET:format(ns:GetScalePercent()))
  elseif cmd == "reset" then
    ns:ResetAll()
    Print(L.RESET_DONE)
  elseif cmd == "help" then
    Print(L.HELP)
  else
    ns:ToggleOptions()
  end
end
