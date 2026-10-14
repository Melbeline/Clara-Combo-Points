-- Clara Combo Points
-- Rogue, druid and warrior HUD for WoW Forever: combo points on the top row (tracked buffs and
-- debuffs for warriors), energy or rage on the bottom bar, and up to three rows of icons above
-- and below.
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

ns.VERSION = "1.5.0"

local NUM_POINTS    = 5
local POWER         = Enum and Enum.PowerType or {}
local POWER_RAGE    = POWER.Rage or 1
local POWER_ENERGY  = POWER.Energy or 3
local POWER_COMBO   = POWER.ComboPoints or 4
local POWER_MANA    = POWER.Mana or 0
local WHITE         = "Interface\\Buttons\\WHITE8X8"
local FONT_DIR      = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Fonts\\"
local issecretvalue = issecretvalue or function() return false end
local UnitIsFeignDeath = UnitIsFeignDeath or function() return false end

-- Geometry is in reference pixels: real screen pixels on the 2560x1440 windowed client the
-- HUD was designed on (1359 px tall render area). The HUD keeps that size relative to the
-- window height whatever the in-game UI scale is; the Scale option multiplies it.
local REF_SCALE = 768 / 1359
local WIDTH, CP_HEIGHT, CP_GAP, ROW_GAP, POWER_HEIGHT = 292, 25, 3, 4, 24
local REFRESH = 0.1 -- safety refresh of the combo points and queued attacks (events do the real work)
ns.WIDTH, ns.CP_HEIGHT, ns.CP_GAP, ns.ROW_GAP = WIDTH, CP_HEIGHT, CP_GAP, ROW_GAP

ns.MIN_SCALE, ns.MAX_SCALE = 10, 500 -- percent
ns.MIN_TIMER, ns.MAX_TIMER = 50, 200 -- countdown numbers on the icons, percent
-- each bar's own size (reference pixels) and scale (percent)
ns.MIN_BAR_W, ns.MAX_BAR_W, ns.MIN_BAR_H, ns.MAX_BAR_H, ns.MIN_BAR_SCALE, ns.MAX_BAR_SCALE = 40, 800, 4, 120, 25, 400
ns.BAR_KEYS = { "combo", "power", "mana", "health" } -- combo points, energy / rage, mana (druids), health
ns.MAX_ICONS, ns.MAX_ROWS = 20, 3     -- icons per row, rows above and below the bar

-- preview: size of the name in the options' font list, for fonts drawn much bigger than the rest
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
  { name = "Cinzel Decorative", path = FONT_DIR .. "CinzelDecorative-Bold.ttf", preview = 9 },
  { name = "Bebas Neue",        path = FONT_DIR .. "BebasNeue-Regular.ttf" },
  { name = "Russo One",         path = FONT_DIR .. "RussoOne-Regular.ttf" },
  { name = "Black Ops One",     path = FONT_DIR .. "BlackOpsOne-Regular.ttf" },
  { name = "Audiowide",         path = FONT_DIR .. "Audiowide-Regular.ttf" },
  { name = "Righteous",         path = FONT_DIR .. "Righteous-Regular.ttf" },
  { name = "Press Start 2P",    path = FONT_DIR .. "PressStart2P-Regular.ttf", preview = 9 },
  { name = "Share Tech Mono",   path = FONT_DIR .. "ShareTechMono-Regular.ttf" },
}

-- Settings of one profile. Rogues, druids and warriors each have their own profile
-- (account-wide); colours sampled from the reference screenshots.
ns.PROFILES = { "ROGUE", "DRUID", "WARRIOR" }
local defaults = {
  locked   = true,
  iconsLocked = true, -- unlocked: the icon rows are edited on the HUD itself (Tracker.lua)
  x        = 0,      -- centre of the HUD, reference pixels from the screen centre
  y        = -204,
  scale    = 1,      -- 1 = 100 %
  alpha    = 1,      -- whole HUD
  font     = "Arial Narrow",
  fontSize = 17,
  outline  = "OUTLINE",
  showText = true,
  druidCatOnly = true, -- druids: HUD only in Cat and Bear Form
  cpSource = "TARGET", -- TARGET: GetComboPoints(player, target) / PLAYER: UnitPower(player, combo)
  fadeOOC  = true,     -- out of combat the HUD fades to the two opacities below
  oocPower = .2,       -- energy / rage bar
  oocTop   = .2,       -- combo points and icons
  predict  = true,     -- rage about to be spent (queued Heroic Strike, Maul...) marked on the bar
  bearIconsFixed = false, -- druids: icon rows stay above the combo points in Bear Form, even without points
  healthClassColor = false, -- health bar in the class colour rather than its own
  -- The bars, top to bottom in this order, each at its own size and scale. Mana: druids only,
  -- in every form; health: hidden until turned on.
  bars = {
    order  = { "combo", "power", "mana", "health" },
    combo  = { width = WIDTH, height = CP_HEIGHT, scale = 1 },
    power  = { width = WIDTH, height = POWER_HEIGHT, scale = 1 },
    mana   = { width = WIDTH, height = 12, scale = 1, show = true },
    health = { width = WIDTH, height = 16, scale = 1, show = false },
  },
  icons = {
    shape   = "SQUARE", -- SQUARE (default) / CELL: rectangles the size of a combo point / FILL: the row shares the bar's width
    size    = 25,      -- row height (and icon width when square), reference pixels
    timers  = true,    -- countdown numbers on the cooldown swipe (auras and spell cooldowns)
    missing = true,    -- missing auras stay in place, grayed out
    reverse = false,   -- buffs / debuffs: reversed swipe (lit when fresh), like Blizzard's aura icons
    timerSize = 100,   -- countdown numbers, percent of the size that fits the icon
  },
  colors = {
    cp1    = { r = 1, g = 1,    b = 0,    a = 1 },
    cp2    = { r = 1, g = .808, b = 0,    a = 1 },
    cp3    = { r = 1, g = .620, b = 0,    a = 1 },
    cp4    = { r = 1, g = .427, b = 0,    a = 1 },
    cp5    = { r = 1, g = 0,    b = .455, a = 1 },
    energy = { r = 1, g = 1,    b = 0,    a = 1 },
    rage   = { r = .663, g = 0, b = 0,    a = 1 },
    mana   = { r = 0, g = 0,    b = 1,    a = 1 }, -- the game's mana blue
    health = { r = 0, g = 1,    b = 0,    a = 1 }, -- the game's health green
    cost   = { r = 1, g = 1,    b = 1,    a = .45 },
    bg     = { r = 0, g = 0,    b = 0,    a = .6 },
    text   = { r = 1, g = 1,    b = 1,    a = 1 },
  },
}
ns.defaults = defaults

-- Warriors have no combo row: their bar sits where the rogue's energy bar is.
local CLASS_DEFAULTS = {
  WARRIOR = { y = -218 },
}

-- Icon rows hold spell IDs (any rank: auras are matched by name) or spell names. Warriors
-- start with one row where the combo points would be.
local DEFAULT_ICONS = {
  WARRIOR = { 7386, 1160, 1715, 6673, 2687 }, -- Sunder Armor, Demoralizing Shout, Hamstring, Battle Shout, Bloodrage
}
ns.SIDES = { "above", "below" }

function ns:DefaultRows(class)
  local rows = { above = {}, below = {} }
  for k = 1, self.MAX_ROWS do rows.above[k], rows.below[k] = {}, {} end
  for i, spell in ipairs(DEFAULT_ICONS[class] or {}) do rows.above[1][i] = spell end
  return rows
end

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
-- HUD: the combo row (not for warriors), the energy / rage bar, the mana bar (druids) and the
-- health bar, stacked in the order the profile says (ApplyLayout)
---------------------------------------------------------------------------
local hud = CreateFrame("Frame", "ClaraComboPointsHUD", UIParent)
hud:SetSize(WIDTH, CP_HEIGHT + ROW_GAP + POWER_HEIGHT)
hud:SetClampedToScreen(true)
hud:SetMovable(true)
hud:EnableMouse(false)
hud:RegisterForDrag("LeftButton")
if hud.SetDontSavePosition then hud:SetDontSavePosition(true) end
hud:Hide()
ns.hud = hud

local function CreateBar(parent, minValue, maxValue)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetStatusBarTexture(WHITE)
  bar:SetMinMaxValues(minValue, maxValue)
  bar:SetValue(0)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  return bar
end

local comboRow = CreateFrame("Frame", nil, hud)
comboRow:SetSize(WIDTH, CP_HEIGHT)
ns.comboRow = comboRow

-- One status bar per combo point, spanning [i-1, i]: feeding every bar the same combo
-- count fills the first N of them, without ever having to read the number.
local cells = {}
for i = 1, NUM_POINTS do cells[i] = CreateBar(comboRow, i - 1, i) end

local power = CreateBar(hud, 0, 100)
power:SetSize(WIDTH, POWER_HEIGHT)
ns.powerBar = power

-- Rage about to be spent, drawn over the end of the bar going back from the current value.
-- It hangs off the bar's fill, so the (possibly secret) rage is never read, and the clip frame
-- cuts whatever would go past the start of the bar.
local costClip = CreateFrame("Frame", nil, power)
costClip:SetAllPoints()
costClip:SetClipsChildren(true)
costClip:Hide()
local costHolder = CreateFrame("Frame", nil, costClip)
costHolder:SetAllPoints()
local costTex = costHolder:CreateTexture(nil, "ARTWORK")
costTex:SetPoint("TOPRIGHT", power:GetStatusBarTexture(), "TOPRIGHT")
costTex:SetPoint("BOTTOMRIGHT", power:GetStatusBarTexture(), "BOTTOMRIGHT")
costTex:SetWidth(1)

local textHolder = CreateFrame("Frame", nil, power) -- above the cost marker
textHolder:SetAllPoints()
textHolder:SetFrameLevel(power:GetFrameLevel() + 3)
local powerText = textHolder:CreateFontString(nil, "OVERLAY")
powerText:SetPoint("CENTER")
powerText:SetFont(ns.fonts[1].path, defaults.fontSize, defaults.outline)

-- Mana (druids) and health: a bar and its value
local function ValueBar()
  local bar = CreateBar(hud, 0, 100)
  bar:SetSize(WIDTH, 12)
  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont(ns.fonts[1].path, 10, defaults.outline)
  return bar
end
local manaBar, healthBar = ValueBar(), ValueBar()
ns.manaBar, ns.healthBar = manaBar, healthBar
local elements = { combo = comboRow, power = power, mana = manaBar, health = healthBar }
ns.barFrames = elements

-- Icon rows live here (Tracker.lua), so they fade together with the combo row.
local iconLayer = CreateFrame("Frame", nil, hud)
iconLayer:SetAllPoints()
ns.iconLayer = iconLayer

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

-- the label goes above the highest icon row (Tracker.lua)
function ns:AnchorMoverText(top)
  moverText:ClearAllPoints()
  moverText:SetPoint("BOTTOM", top or mover, "TOP", 0, 4)
end

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

local powerType = POWER_ENERGY -- what the bar shows: energy, or rage for warriors and bears

local lastCombo
local function UpdateCombo()
  if not hud:IsShown() or not comboRow:IsShown() then return end -- re-read on show
  local v = ns.preview and NUM_POINTS or ReadComboPoints()
  -- Bear Form and no combo points on the target: nothing shows on the combo row, so the icon
  -- rows above it come down onto the rage bar (unless the option keeps them in place). An
  -- unreadable (secret) count keeps them in place.
  local onBar = powerType == POWER_RAGE and ns.profileClass == "DRUID" and not ns.db.bearIconsFixed
    and not issecretvalue(v) and v == 0
  if onBar ~= ns.iconsOnBar then
    ns.iconsOnBar = onBar
    ns:LayoutIcons()
  end
  if issecretvalue(v) then
    lastCombo = nil
  elseif v == lastCombo then
    return
  else
    lastCombo = v
  end
  for i = 1, NUM_POINTS do cells[i]:SetValue(v) end
end

local maxPower, lastPower
local function UpdatePower()
  if not power:IsVisible() then return end
  -- the preview fills the rage bar (rage is usually 0 out of combat), so its colours show
  local v = (ns.preview and powerType == POWER_RAGE) and (maxPower or 100) or UnitPower("player", powerType)
  if issecretvalue(v) then
    lastPower = nil
  elseif v == lastPower then
    return
  else
    lastPower = v
  end
  power:SetValue(v)
  powerText:SetText(v)
end

local function UpdatePowerMax()
  if not hud:IsShown() then return end
  local m = UnitPowerMax("player", powerType)
  if issecretvalue(m) or (type(m) == "number" and m > 0) then
    power:SetMinMaxValues(0, m)
    maxPower = m
  end
  lastPower = nil
end

-- Mana and health, read every frame like the energy (unchanged values cost a comparison);
-- their maxima on the safety refresh. Possibly secret: only handed to the bar and the text.
local lastMana, lastHealth
local function UpdateMana()
  if not manaBar:IsVisible() then return end
  local v = UnitPower("player", POWER_MANA)
  if issecretvalue(v) then
    lastMana = nil
  elseif v == lastMana then
    return
  else
    lastMana = v
  end
  manaBar:SetValue(v)
  manaBar.text:SetText(v)
end

local function UpdateHealth()
  if not healthBar:IsVisible() then return end
  local v = UnitHealth("player")
  if issecretvalue(v) then
    lastHealth = nil
  elseif v == lastHealth then
    return
  else
    lastHealth = v
  end
  healthBar:SetValue(v)
  healthBar.text:SetText(v)
end

local function UpdateMaxima()
  if manaBar:IsVisible() then
    local m = UnitPowerMax("player", POWER_MANA)
    if issecretvalue(m) or (type(m) == "number" and m > 0) then manaBar:SetMinMaxValues(0, m) end
  end
  if healthBar:IsVisible() then
    local m = UnitHealthMax("player")
    if issecretvalue(m) or (type(m) == "number" and m > 0) then healthBar:SetMinMaxValues(0, m) end
  end
end

---------------------------------------------------------------------------
-- Rage about to be spent: an attack waiting for the next swing (Heroic Strike, Cleave, Maul),
-- a cast in progress (Slam) and Frenzied Regeneration (up to 10 rage a second). Instant
-- attacks spend their rage at once, so there is nothing to show for them.
---------------------------------------------------------------------------
local NEXT_SWING = {
  78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, -- Heroic Strike
  845, 7369, 11608, 11609, 20569,                        -- Cleave
  6807, 6808, 6809, 8972, 9745, 9880, 9881,              -- Maul
}
local FRENZIED_REGENERATION = 22842
local REGEN_PER_SECOND = 10
local REGEN_DURATION = 10 -- seconds
ns.PREDICTED_SPELLS = { WARRIOR = { 78, 845, 1464 }, DRUID = { 6807, FRENZIED_REGENERATION } }

local IsCurrentSpell = (C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell
local GetSpellPowerCost = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
local GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(spell) return (GetSpellInfo(spell)) end
local GetAuraDataBySpellName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName

-- Localized name of a spell ID, or nil if this client does not know it.
function ns:SpellName(spell)
  if type(spell) ~= "number" then return spell end
  local ok, name = pcall(GetSpellName, spell)
  if ok and type(name) == "string" and not issecretvalue(name) and name ~= "" then return name end
end

-- Aura data by spell name (every rank), or nil if absent or hidden from addons.
function ns:FindAura(unit, name, filter)
  if not GetAuraDataBySpellName or not name then return end
  local ok, aura = pcall(GetAuraDataBySpellName, unit, name, filter)
  if ok and not issecretvalue(aura) and type(aura) == "table" then return aura end
end

local function Plain(v) -- a readable number, or nil
  if not issecretvalue(v) and type(v) == "number" then return v end
end

local function RageCost(spell)
  if not GetSpellPowerCost then return 0 end
  local ok, costs = pcall(GetSpellPowerCost, spell)
  if not ok or issecretvalue(costs) or type(costs) ~= "table" then return 0 end
  for _, info in ipairs(costs) do
    if type(info) == "table" and Plain(info.type) == POWER_RAGE then return Plain(info.cost) or 0 end
  end
  return 0
end

local swingSpells = {} -- names first (whatever rank is known), then every rank by ID
local regenName
function ns:ResolveSpells()
  wipe(swingSpells)
  for _, id in ipairs({ 78, 845, 6807 }) do
    local name = self:SpellName(id)
    if name then swingSpells[#swingSpells + 1] = name end
  end
  for _, id in ipairs(NEXT_SWING) do swingSpells[#swingSpells + 1] = id end
  regenName = self.isDruid and self:SpellName(FRENZIED_REGENERATION) or nil
end

local predicting                   -- rage on the bar and prediction wanted
local queuedCost, castCost = 0, 0  -- next-swing attack, cast in progress
local regenEnds, regenDirty        -- Frenzied Regeneration expiration time, aura changed
local regenCast                    -- when you last cast it (its aura is hidden from addons in combat)
local costShown                    -- rage currently marked

local function UpdateQueued()
  queuedCost = 0
  if not predicting or not IsCurrentSpell then return end
  for _, spell in ipairs(swingSpells) do
    local ok, current = pcall(IsCurrentSpell, spell)
    if ok and current == true then
      queuedCost = RageCost(spell)
      return
    end
  end
end

local function UpdateCast()
  castCost = 0
  if not predicting or not UnitCastingInfo then return end
  local ok, name, _, _, _, _, _, _, _, spellID = pcall(UnitCastingInfo, "player")
  if ok and not issecretvalue(name) and name and Plain(spellID) then castCost = RageCost(spellID) end
end

local function AurasSecret()
  if C_Secrets and C_Secrets.ShouldAurasBeSecret then
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    if ok and secret == true then return true end
  end
  return InCombatLockdown() == true
end

local function UpdateRegen()
  regenEnds, regenDirty = nil, false
  if not predicting or not regenName then return end
  local aura = ns:FindAura("player", regenName, "HELPFUL")
  local ends = aura and Plain(aura.expirationTime)
  if ends and ends > 0 then
    regenEnds = ends
  elseif not aura and regenCast and AurasSecret() and GetTime() < regenCast + REGEN_DURATION then
    regenEnds = regenCast + REGEN_DURATION -- hidden in combat: counted from your cast
  end
end

local function UpdateCost()
  local rage = 0
  if predicting then
    rage = queuedCost + castCost
    if regenEnds then
      local left = regenEnds - GetTime()
      if left > 0 then rage = rage + REGEN_PER_SECOND * math.ceil(left) else regenEnds = nil end
    end
    if ns.preview and rage == 0 then rage = 15 end -- a sample, to see the color
  end
  if rage == costShown then return end
  costShown = rage
  if rage > 0 then
    local max = Plain(maxPower)
    if not max or max <= 0 then max = 100 end
    local width = ns.db.bars.power.width -- in the bar's own units
    costTex:SetWidth(math.min(width, rage / max * width))
    costClip:Show()
  else
    costClip:Hide()
  end
end

local function RefreshCost()
  UpdateQueued()
  UpdateCast()
  UpdateRegen()
  costShown = nil
  UpdateCost()
end

local function RefreshValues()
  lastCombo, lastPower, lastMana, lastHealth = nil, nil, nil, nil
  UpdatePowerMax()
  UpdatePower()
  UpdateMaxima()
  UpdateMana()
  UpdateHealth()
  UpdateCombo()
  RefreshCost()
  ns:MarkIconsDirty() -- read on the next frame, once
end

-- Updates are skipped while the HUD is hidden, so catch up on everything when it comes back.
hud:SetScript("OnShow", RefreshValues)

-- Combo points, energy / rage and the icons: druids see them in Cat Form (energy) and Bear
-- Form (rage), unless "Cat and Bear Form only" is off; while unlocked or while the options
-- are open, in any form, so they can be moved and coloured. Rogues and warriors always.
local function FormShown()
  if not ns.isDruid then return true end
  if not ns.db.druidCatOnly or not ns.db.locked or not ns.db.iconsLocked or ns.optionsOpen then return true end
  local pt = UnitPowerType("player")
  return issecretvalue(pt) or pt == POWER_ENERGY or pt == POWER_RAGE
end

-- Which bars show: the mana bar (druids) in every form, the health bar when turned on.
local function BarShown(key)
  if key == "combo" then return ns.profileClass ~= "WARRIOR" and FormShown() end
  if key == "power" then return FormShown() end
  if key == "mana" then return ns.profileClass == "DRUID" and ns.db.bars.mana.show end
  return ns.db.bars.health.show
end

local function ShownKey()
  local key = ""
  for _, k in ipairs(ns.BAR_KEYS) do key = key .. (BarShown(k) and "1" or "0") end
  return key
end

local function ShouldShow()
  if not (ns.isRogue or ns.isWarrior or ns.isDruid) then return false end
  return ShownKey():find("1") ~= nil
end

local shownKey -- the bars laid out (ApplyLayout)
function ns:UpdateVisibility()
  iconLayer:SetShown(FormShown())
  if ShownKey() ~= shownKey then self:ApplyLayout() end
  hud:SetShown(ShouldShow())
end

-- Energy regenerates continuously, so the bar is read every frame: each point shows up on
-- the very frame the client has it. Unchanged values cost a single comparison.
local sinceRefresh = 0
hud:SetScript("OnUpdate", function(_, elapsed)
  UpdatePower()
  UpdateMana()
  UpdateHealth()
  ns:UpdateIconsIfDirty()
  if regenDirty then
    UpdateRegen()
    UpdateCost()
  end
  sinceRefresh = sinceRefresh + elapsed
  if sinceRefresh >= REFRESH then
    sinceRefresh = 0
    UpdateCombo()
    UpdateMaxima()
    if predicting then
      UpdateQueued()
      UpdateCost()
    end
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

-- Sets a font, falling back to the default one if this client cannot load it.
function ns:SetFont(fs, size, flags)
  local ok = fs:SetFont(self:GetFontPath(self.db.font), size, flags)
  if ok == false or not fs:GetFont() then fs:SetFont(fontPaths[defaults.font], size, flags) end
end

function ns:GetOutline()
  return self.db.outline ~= "NONE" and self.db.outline or ""
end

-- The mana and health values: the font size, or less on a thin bar.
local function ValueFonts()
  local db = ns.db
  for key, bar in pairs({ mana = manaBar, health = healthBar }) do
    ns:SetFont(bar.text, math.max(6, math.min(db.fontSize, db.bars[key].height - 2)), ns:GetOutline())
    bar.text:SetShown(db.showText)
  end
end

function ns:ApplyFont()
  self:SetFont(powerText, self.db.fontSize, self:GetOutline())
  powerText:SetShown(self.db.showText)
  ValueFonts()
  self:LayoutIcons()
end

function ns:ApplyColors()
  local c = self.db.colors
  local bg = c.bg
  for i = 1, NUM_POINTS do
    local k = c["cp" .. i]
    cells[i]:SetStatusBarColor(k.r, k.g, k.b, k.a)
    cells[i].bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
  end
  local bar = c[powerType == POWER_RAGE and "rage" or "energy"]
  power:SetStatusBarColor(bar.r, bar.g, bar.b, bar.a)
  power.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
  costTex:SetColorTexture(c.cost.r, c.cost.g, c.cost.b, c.cost.a)
  powerText:SetTextColor(c.text.r, c.text.g, c.text.b, c.text.a)
  manaBar:SetStatusBarColor(c.mana.r, c.mana.g, c.mana.b, c.mana.a)
  local h = c.health
  local r, g, b = h.r, h.g, h.b
  if self.db.healthClassColor then r, g, b = self:ClassColor(self.profileClass) end
  healthBar:SetStatusBarColor(r, g, b, h.a)
  for _, bar in ipairs({ manaBar, healthBar }) do
    bar.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
    bar.text:SetTextColor(c.text.r, c.text.g, c.text.b, c.text.a)
  end
end

-- A class's colour, as the game shows it (raid frames, names).
local CLASS_FALLBACK = { ROGUE = { 1, .96, .41 }, DRUID = { 1, .49, .04 }, WARRIOR = { .78, .61, .43 } }
function ns:ClassColor(class)
  local c
  if C_ClassColor and C_ClassColor.GetClassColor then
    local ok, color = pcall(C_ClassColor.GetClassColor, class)
    if ok then c = color end
  end
  c = c or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
  if c and type(c.r) == "number" then return c.r, c.g, c.b end
  c = CLASS_FALLBACK[class] or { 1, 1, 1 }
  return c[1], c[2], c[3]
end

-- Rage for warriors and for druids in Bear Form, energy otherwise. In Bear Form the empty
-- combo cells are not drawn: the row only shows points the target actually has, and is back
-- in full the moment the druid shifts to Cat Form.
local function WantedPowerType()
  if ns.profileClass == "WARRIOR" then return POWER_RAGE end
  if ns.profileClass == "DRUID" and ns.isDruid then
    local pt = UnitPowerType("player")
    if not issecretvalue(pt) and pt == POWER_RAGE then return POWER_RAGE end
  end
  return POWER_ENERGY
end

function ns:UpdatePowerMode()
  local wanted = WantedPowerType()
  powerType = wanted
  local bear = self.profileClass == "DRUID" and wanted == POWER_RAGE
  for i = 1, NUM_POINTS do cells[i].bg:SetShown(not bear) end
  predicting = wanted == POWER_RAGE and self.db.predict
  self:ApplyColors()
  RefreshValues()
end

function ns:GetPowerType()
  return powerType
end

function ns:ApplyAlpha()
  hud:SetAlpha(self.db.alpha)
end

-- Out of combat the bar and the combo points / icons fade to their own opacity. Not while
-- unlocked or while the options are open (so colours can be judged), except for a moment
-- after an out-of-combat setting changes, to show the result.
local inCombat = false
function ns:ApplyFade()
  local db = self.db
  local fade = db.fadeOOC and not inCombat and db.locked and db.iconsLocked and (not self.optionsOpen or self.fadePreview ~= nil)
  local top = fade and db.oocTop or 1
  comboRow:SetAlpha(top)
  iconLayer:SetAlpha(top)
  local bars = fade and db.oocPower or 1
  power:SetAlpha(bars)
  manaBar:SetAlpha(bars)
  healthBar:SetAlpha(bars)
end

function ns:PreviewFade()
  local token = {}
  self.fadePreview = token
  self:ApplyFade()
  C_Timer.After(2, function()
    if self.fadePreview ~= token then return end
    self.fadePreview = nil
    self:ApplyFade()
  end)
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

-- The bars shown, top to bottom in the profile's order, each centred at its own size and
-- scale, 4 apart; the HUD is as large as all of them. (Warriors have no combo row: the first
-- icon row sits on the bar.)
function ns:ApplyLayout()
  local bars = self.db.bars
  local y, wide = 0, 1
  for _, key in ipairs(bars.order) do
    local frame, on = elements[key], BarShown(key)
    frame:SetShown(on)
    if on then
      local b = bars[key]
      frame:SetScale(b.scale)
      frame:SetSize(b.width, b.height)
      frame:ClearAllPoints()
      frame:SetPoint("TOP", hud, "TOP", 0, -y / b.scale)
      y = y + b.height * b.scale + ROW_GAP
      wide = math.max(wide, b.width * b.scale)
    end
  end
  hud:SetSize(wide, math.max(1, y - ROW_GAP))
  shownKey = ShownKey()
  -- the combo cells share the row's width
  local cb = bars.combo
  local cellWidth = (cb.width - (NUM_POINTS - 1) * CP_GAP) / NUM_POINTS
  for i = 1, NUM_POINTS do
    cells[i]:ClearAllPoints()
    cells[i]:SetPoint("TOPLEFT", (i - 1) * (cellWidth + CP_GAP), 0)
    cells[i]:SetSize(cellWidth, cb.height)
  end
  ValueFonts()
  self:LayoutIcons()
  RefreshValues()
end

-- A combo point cell's size on the HUD (icons of the Rectangular shape take it).
function ns:ComboCellSize()
  local cb = self.db.bars.combo
  return (cb.width - (NUM_POINTS - 1) * CP_GAP) / NUM_POINTS * cb.scale, cb.height * cb.scale
end

-- The bars the icon rows sit on, with their widths on the HUD: the top one for the rows
-- above, the bottom one for the rows below. (In Bear Form without combo points the empty
-- combo row is passed over.)
function ns:IconAnchors()
  local bars = self.db.bars
  local top, bottom = "power", "power"
  local found
  for _, key in ipairs(bars.order) do
    if elements[key]:IsShown() and not (key == "combo" and self.iconsOnBar) then
      if not found then top, found = key, true end
      bottom = key
    end
  end
  return elements[top], elements[bottom], bars[top].width * bars[top].scale, bars[bottom].width * bars[bottom].scale
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
  local class = CLASS_DEFAULTS[self.profileClass] or {}
  self.db.x, self.db.y = class.x or defaults.x, class.y or defaults.y
  self:ApplyPosition()
end

function ns:SetLocked(locked)
  self.db.locked = locked and true or false
  hud:EnableMouse(not self.db.locked)
  mover:SetShown(not self.db.locked)
  self:UpdateVisibility()
  self:ApplyFade()
  self:RefreshOptions()
  self:RefreshSettingsPage()
end

-- A drag belongs to the profile it started in (the options can switch profile mid-drag).
hud:SetScript("OnDragStart", function(self)
  if not ns.db.locked then
    self.dragProfile = ns.db
    self:StartMoving()
  end
end)
hud:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  if self.dragProfile == ns.db then ns:SavePosition() else ns:ApplyPosition() end
  self.dragProfile = nil
end)

-- Preview: everything lit (all five points, every icon) to judge colours, until turned off
-- or combat starts.
function ns:SetPreview(on)
  self.preview = on and true or false
  lastCombo, lastPower = nil, nil
  UpdateCombo()
  UpdatePower()
  costShown = nil
  UpdateCost()
  self:UpdateIcons()
  self:RefreshOptions()
end

function ns:SetOptionsOpen(open)
  self.optionsOpen = open and true or false
  self:WatchLogout(self.optionsOpen)
  self:UpdateVisibility()
  self:ApplyFade()
end

function ns:SetDruidCatOnly(on)
  self.db.druidCatOnly = on and true or false
  self:UpdateVisibility()
  self:RefreshOptions()
end

function ns:SetPredict(on)
  self.db.predict = on and true or false
  self:UpdatePowerMode()
  self:RefreshOptions()
end

function ns:SetBearIconsFixed(on)
  self.db.bearIconsFixed = on and true or false
  lastCombo = nil
  UpdateCombo()
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
  self:ApplyLayout()
  self:ApplyFont()
  self:UpdatePowerMode() -- colours and values too
  self:ApplyAlpha()
  self:SetLocked(self.db.locked)
end

-- Out of combat section back to its defaults (fade on, 20 % / 20 %).
function ns:ResetFade()
  self.db.fadeOOC, self.db.oocPower, self.db.oocTop = defaults.fadeOOC, defaults.oocPower, defaults.oocTop
  self:PreviewFade()
  self:RefreshOptions()
end

function ns:ResetColors()
  self.db.colors = CopyDefaults(defaults.colors, {})
  self:ApplyColors()
  self:RefreshOptions()
end

-- Fills a profile with the defaults for its class. Icon rows are lists the player edits:
-- they are only set when missing, never merged with the defaults.
local function FillProfile(db, class)
  for k, v in pairs(CLASS_DEFAULTS[class] or {}) do
    if db[k] == nil then db[k] = v end
  end
  CopyDefaults(defaults, db)
  if type(db.rows) ~= "table" then db.rows = ns:DefaultRows(class) end
  return db
end

-- Resets the profile in use (the options tab being edited, or this character's class).
function ns:ResetAll()
  wipe(self.db)
  FillProfile(self.db, self.profileClass)
  self:ApplyAll()
  self:RefreshOptions()
end

function ns:ResetIcons()
  self.db.rows = self:DefaultRows(self.profileClass)
  self:LayoutIcons()
  self:RefreshOptions()
end

-- Every class's bar and icons locked (the ones shown, and the others for when they are shown).
function ns:LockAll()
  for _, profile in pairs(self.sv.profiles) do profile.locked, profile.iconsLocked = true, true end
  self:SetIconsLocked(true)
  self:SetLocked(true)
end

function ns:AllLocked()
  for _, profile in pairs(self.sv.profiles) do
    if not profile.locked or not profile.iconsLocked then return false end
  end
  return true
end

-- Icons unlocked: every row shows on the HUD (the empty ones too) to drop spells from the
-- spellbook on, move icons around, or drag them off to remove them (Tracker.lua).
function ns:SetIconsLocked(locked)
  self.db.iconsLocked = locked and true or false
  self:UpdateVisibility()
  self:LayoutIcons()
  self:ApplyFade()
  self:RefreshOptions()
  self:RefreshSettingsPage()
end

-- Everything back to the defaults: the three class tabs (bar, colours, font, icons) and the
-- options window. The saved profiles, the interface language and what the addon learned
-- about auras stay.
function ns:ResetAddon()
  if hud.dragProfile then
    hud:StopMovingOrSizing()
    hud.dragProfile = nil
  end
  for _, class in ipairs(self.PROFILES) do
    local profile = self.sv.profiles[class]
    wipe(profile)
    FillProfile(profile, class)
  end
  wipe(self.sv.window)
  self.sv.window.alpha = 1 -- centred, at the scale that fits the screen, opaque
  wipe(self.sv.active)
  self:ApplyAll()
  self:ResetOptionsWindow() -- Options.lua
  self:RefreshOptions()
  self:RefreshSettingsPage()
end

function ns:GetProfileName()
  return L["TAB_" .. (self.profileClass or "ROGUE")]
end

-- An unlock made on another class's options tab must not stay behind in that profile:
-- relocked when the options close, and on logout / reload in case they were still open.
function ns:LockOtherProfiles()
  local home = self.homeClass or "ROGUE"
  for class, profile in pairs(self.sv.profiles) do
    if class ~= home then profile.locked, profile.iconsLocked = true, true end
  end
end

-- The HUD draws the profile of this character's class; while the options are open it draws
-- the profile of the selected tab, so another class can be set up and seen from here.
function ns:SetActiveProfile(class)
  local profile = self.sv.profiles[class]
  if not profile or profile == self.db then return end
  if hud.dragProfile then
    hud:StopMovingOrSizing()
    hud.dragProfile = nil
  end
  self.db = profile
  self.profileClass = class
  self:ApplyAll()
  self:RefreshOptions()
end

function ns:SetLanguage(code)
  if not self:IsLanguage(code) then return end
  self.sv.language = code
  self.lang = code
  moverText:SetText(L.MOVER)
  self:RelabelOptions()
  self:RefreshSettingsPage()
end

-- Options.lua and Tracker.lua replace these
function ns:RefreshOptions() end
function ns:RelabelOptions() end
function ns:ToggleOptions() end
function ns:ShowOptions() end
function ns:ResetOptionsWindow() end
function ns:ResetWindowPosition() end
function ns:RefreshSettingsPage() end -- SettingsPage.lua
function ns:LayoutIcons() end
function ns:UpdateIcons() end
function ns:UpdateIconsIfDirty() end

local CONDITION = { auto = true, self = true, target = true, enemy = true, friend = true }
local function ValidSpell(spell)
  return (type(spell) == "number" and spell > 0 and spell < 2 ^ 31 and spell == math.floor(spell))
    or (type(spell) == "string" and spell ~= "" and #spell <= 80)
end
local function CleanEntry(entry)
  if ValidSpell(entry) then return entry end
  if type(entry) == "table" and ValidSpell(entry.spell) then
    return { spell = entry.spell, on = CONDITION[entry.on] and entry.on or "auto", exact = entry.exact == true or nil,
      mine = entry.mine == true or nil }
  end
end

local function CleanRows(db, class)
  local rows = db.rows
  for _, side in ipairs(ns.SIDES) do
    if type(rows[side]) ~= "table" then rows[side] = {} end
    local clean = {}
    for k = 1, ns.MAX_ROWS do
      local row = {}
      for _, entry in ipairs(type(rows[side][k]) == "table" and rows[side][k] or {}) do
        if #row >= ns.MAX_ICONS then break end
        row[#row + 1] = CleanEntry(entry)
      end
      clean[k] = row
    end
    rows[side] = clean
  end
end

local function CleanProfile(db, class)
  if type(db.icons) == "table" and db.icons.shape == nil and db.icons.square ~= nil then
    db.icons.shape = db.icons.square and "SQUARE" or "FILL" -- 1.4 had a square on/off option
  end
  if type(db.icons) == "table" then db.icons.square = nil end
  FillProfile(db, class)
  if db.icons.shape ~= "FILL" and db.icons.shape ~= "CELL" and db.icons.shape ~= "SQUARE" then db.icons.shape = defaults.icons.shape end
  if db.scale * 100 < ns.MIN_SCALE or db.scale * 100 > ns.MAX_SCALE then db.scale = defaults.scale end
  if db.alpha < 0 or db.alpha > 1 then db.alpha = defaults.alpha end
  if db.oocPower < 0 or db.oocPower > 1 then db.oocPower = defaults.oocPower end
  if db.oocTop < 0 or db.oocTop > 1 then db.oocTop = defaults.oocTop end
  if db.fontSize < 6 or db.fontSize > 64 then db.fontSize = defaults.fontSize end
  if db.icons.size < 12 or db.icons.size > 64 then db.icons.size = defaults.icons.size end
  if not (db.icons.timerSize >= ns.MIN_TIMER and db.icons.timerSize <= ns.MAX_TIMER) then db.icons.timerSize = defaults.icons.timerSize end
  if not (math.abs(db.x) <= 4000 and math.abs(db.y) <= 4000) then db.x, db.y = defaults.x, defaults.y end
  -- the bars: each once in the order, sizes in range
  local order, seen = {}, {}
  for _, key in ipairs(db.bars.order) do
    if defaults.bars[key] and key ~= "order" and not seen[key] then
      seen[key] = true
      order[#order + 1] = key
    end
  end
  for _, key in ipairs(ns.BAR_KEYS) do
    if not seen[key] then order[#order + 1] = key end
  end
  db.bars.order = order
  for _, key in ipairs(ns.BAR_KEYS) do
    local b, d = db.bars[key], defaults.bars[key]
    if not (b.width >= ns.MIN_BAR_W and b.width <= ns.MAX_BAR_W) then b.width = d.width end
    if not (b.height >= ns.MIN_BAR_H and b.height <= ns.MAX_BAR_H) then b.height = d.height end
    if not (b.scale * 100 >= ns.MIN_BAR_SCALE and b.scale * 100 <= ns.MAX_BAR_SCALE) then b.scale = d.scale end
  end
  for key, c in pairs(db.colors) do
    local default = defaults.colors[key]
    if default then
      for _, ch in ipairs({ "r", "g", "b", "a" }) do
        if not (c[ch] >= 0 and c[ch] <= 1) then c[ch] = default[ch] end
      end
    else
      db.colors[key] = nil
    end
  end
  if db.outline ~= "NONE" and db.outline ~= "OUTLINE" and db.outline ~= "THICKOUTLINE" then db.outline = defaults.outline end
  if db.cpSource ~= "TARGET" and db.cpSource ~= "PLAYER" then db.cpSource = defaults.cpSource end
  CleanRows(db, class)
end

-- A profile from outside (saved, or imported from another account): only the settings this
-- addon knows, of the right kind, checked like the saved variables, without the lock (not
-- part of a profile). Returns a new table, or fills `into` (which may be data itself).
local function Finite(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end
local function CopyKnown(src, model, dst)
  for k, v in pairs(model) do
    local value = src[k]
    if type(v) == "table" then
      dst[k] = CopyKnown(type(value) == "table" and value or {}, v, {})
    elseif type(value) == type(v) and (type(v) ~= "number" or Finite(value)) and (type(v) ~= "string" or #value <= 64) then
      dst[k] = value
    end
  end
  return dst
end
local function CopyRows(rows)
  local copy = {}
  for _, side in ipairs(ns.SIDES) do
    copy[side] = {}
    for k = 1, ns.MAX_ROWS do
      local row = type(rows) == "table" and type(rows[side]) == "table" and rows[side][k]
      copy[side][k] = {}
      for i, entry in ipairs(type(row) == "table" and row or {}) do
        if i > ns.MAX_ICONS then break end
        local clean = CleanEntry(entry)
        if clean ~= nil then table.insert(copy[side][k], clean) end
      end
    end
  end
  return copy
end
function ns:CleanProfileData(data, class, into)
  local clean = CopyKnown(data, defaults, {})
  clean.rows = CopyRows(data.rows)
  CleanProfile(clean, class)
  clean.locked, clean.iconsLocked = nil, nil
  if not into then return clean end
  wipe(into)
  for k, v in pairs(clean) do into[k] = v end
  return into
end

-- Options window (account-wide): where it is (top left corner, UIParent units; nil = centred),
-- its scale (nil = as large as fits the screen, up to 100 %) and opacity.
ns.MIN_WINDOW_SCALE, ns.MAX_WINDOW_SCALE = .4, 2
ns.MIN_WINDOW_ALPHA = .2
local function CleanWindow(sv)
  local w = type(sv.window) == "table" and sv.window or {}
  sv.window = w
  if not (Finite(w.left) and Finite(w.top)) then w.left, w.top = nil, nil end
  if not (Finite(w.scale) and w.scale >= ns.MIN_WINDOW_SCALE and w.scale <= ns.MAX_WINDOW_SCALE) then w.scale = nil end
  if not (Finite(w.alpha) and w.alpha >= ns.MIN_WINDOW_ALPHA and w.alpha <= 1) then w.alpha = 1 end
  for k in pairs(w) do
    if k ~= "left" and k ~= "top" and k ~= "scale" and k ~= "alpha" then w[k] = nil end
  end
end

local function InitDB()
  local sv = type(ClaraComboPointsDB) == "table" and ClaraComboPointsDB or {}
  if type(sv.profiles) ~= "table" then
    -- 1.0 and 1.1 kept a single set of settings: it becomes the start of the rogue and druid
    -- profiles (warriors came later)
    local old = {}
    for k in pairs(defaults) do old[k], sv[k] = sv[k], nil end
    sv.profiles = { ROGUE = CopyDefaults(old, {}), DRUID = CopyDefaults(old, {}) }
  end
  for _, class in ipairs(ns.PROFILES) do
    if type(sv.profiles[class]) ~= "table" then sv.profiles[class] = {} end
    CleanProfile(sv.profiles[class], class)
  end
  -- account-wide: interface language (nil = follow the client)
  if not ns:IsLanguage(sv.language) then sv.language = nil end
  if sv.language then ns.lang = sv.language end
  sv.skin = nil -- 1.3 had a second options theme
  -- icons of spells tracked by name, learned when their aura is first seen
  if type(sv.seenIcons) ~= "table" then sv.seenIcons = {} end
  for name, icon in pairs(sv.seenIcons) do
    if type(name) ~= "string" or (type(icon) ~= "number" and type(icon) ~= "string") then sv.seenIcons[name] = nil end
  end
  -- spells seen with a cooldown of their own: their icon stays lit when they are ready
  if type(sv.cooldownSpells) ~= "table" then sv.cooldownSpells = {} end
  for name, on in pairs(sv.cooldownSpells) do
    if type(name) ~= "string" or on ~= true then sv.cooldownSpells[name] = nil end
  end
  -- spell IDs each aura was seen under, by spell name (the game's aura buttons match IDs)
  if type(sv.auraIDs) ~= "table" then sv.auraIDs = {} end
  for name, ids in pairs(sv.auraIDs) do
    if type(name) ~= "string" or type(ids) ~= "table" then
      sv.auraIDs[name] = nil
    else
      for id, on in pairs(ids) do
        if type(id) ~= "number" or on ~= true then ids[id] = nil end
      end
    end
  end
  CleanWindow(sv)
  ns:InitProfiles(sv) -- Profiles.lua: the profiles saved on each class tab
  moverText:SetText(L.MOVER)
  ClaraComboPointsDB = sv
  ns.sv = sv
  ns.db = sv.profiles.ROGUE
  ns.profileClass = "ROGUE"
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
  self.isWarrior = (class == "WARRIOR")
  self.enabled = self.isRogue or self.isDruid or self.isWarrior
  self.homeClass = self.isDruid and "DRUID" or self.isWarrior and "WARRIOR" or "ROGUE"
  self.profileClass = self.homeClass
  self.db = self.sv.profiles[self.homeClass]
  local fighting = UnitAffectingCombat and UnitAffectingCombat("player")
  inCombat = (not issecretvalue(fighting) and fighting) and true or false
  self:ResolveSpells()
  self:ApplyAll()
  if not self.enabled then return end -- dormant on other classes: no events, no updates

  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  pcall(events.RegisterEvent, events, "ADDON_RESTRICTION_STATE_CHANGED") -- auras secret beyond combat (encounters, PvP)
  events:RegisterEvent("UI_SCALE_CHANGED")
  events:RegisterEvent("DISPLAY_SIZE_CHANGED")
  events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
  events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
  events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  events:RegisterUnitEvent("UNIT_AURA", "player", "target")
  events:RegisterEvent("SPELL_UPDATE_COOLDOWN") -- spell cooldowns and charges on the icons
  events:RegisterEvent("SPELL_UPDATE_CHARGES")
  if not self.isWarrior then -- combo points
    events:RegisterUnitEvent("UNIT_HEALTH", "target")
    events:RegisterUnitEvent("UNIT_FLAGS", "target")
    pcall(events.RegisterEvent, events, "UNIT_DIED") -- not in every client build
  end
  if self.isDruid then
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player") -- power type changes with the form
    events:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  end
  if self.isDruid or self.isWarrior then -- rage about to be spent
    events:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
    for _, e in ipairs({ "START", "STOP", "FAILED", "INTERRUPTED", "DELAYED", "SUCCEEDED" }) do
      events:RegisterUnitEvent("UNIT_SPELLCAST_" .. e, "player")
    end
  end
  self:UpdateVisibility()
end

-- A /reload or logout with the options still open saves without closing them first.
function ns:WatchLogout(on)
  if on then events:RegisterEvent("PLAYER_LOGOUT") else events:UnregisterEvent("PLAYER_LOGOUT") end
end

function ns:PLAYER_LOGOUT()
  self:LockOtherProfiles()
end

function ns:PLAYER_ENTERING_WORLD()
  self:ApplyScale()
  self:UpdateVisibility()
  self:UpdatePowerMode()
  self:AurasReadable()
end

-- A shift only redraws the bar when it changes what the bar shows (energy / rage).
function ns:UNIT_DISPLAYPOWER()
  self:UpdateVisibility()
  if WantedPowerType() ~= powerType then
    self:UpdatePowerMode()
  else
    UpdatePowerMax()
    UpdatePower()
  end
end
ns.UPDATE_SHAPESHIFT_FORM = ns.UNIT_DISPLAYPOWER

function ns:PLAYER_TARGET_CHANGED()
  UpdateCombo()
  self:TargetChanged() -- Tracker.lua: the icons look again
end

function ns:UNIT_POWER_FREQUENT(_, token)
  if issecretvalue(token) then
    UpdatePower()
    UpdateCombo()
  elseif token == "COMBO_POINTS" then
    UpdateCombo()
  elseif token == "ENERGY" or token == "RAGE" then
    UpdatePower()
  end
end
ns.UNIT_POWER_UPDATE = ns.UNIT_POWER_FREQUENT

function ns:UNIT_MAXPOWER()
  UpdatePowerMax()
  UpdatePower()
  costShown = nil
  UpdateCost()
end

-- Target death: UNIT_HEALTH arrives with the killing blow, UNIT_FLAGS / UNIT_DIED as backup.
function ns:UNIT_HEALTH()
  UpdateCombo()
end
ns.UNIT_FLAGS = ns.UNIT_HEALTH
ns.UNIT_DIED = ns.UNIT_HEALTH

-- Aura events can come in bursts: the icons and Frenzied Regeneration are read again once,
-- on the next frame.
function ns:UNIT_AURA(unit)
  -- (in combat the event's unit can be a secret value: never compared then)
  if predicting and regenName and not issecretvalue(unit) and unit == "player" then regenDirty = true end
  self:MarkIconsDirty()
end

function ns:SPELL_UPDATE_COOLDOWN()
  self:MarkIconsDirty()
end
ns.SPELL_UPDATE_CHARGES = ns.SPELL_UPDATE_COOLDOWN

function ns:CURRENT_SPELL_CAST_CHANGED()
  UpdateQueued()
  UpdateCost()
end

function ns:UNIT_SPELLCAST_START()
  UpdateCast()
  UpdateCost()
end
for _, e in ipairs({ "STOP", "FAILED", "INTERRUPTED", "DELAYED" }) do
  ns["UNIT_SPELLCAST_" .. e] = ns.UNIT_SPELLCAST_START
end

function ns:UNIT_SPELLCAST_SUCCEEDED(_, _, spellID)
  if regenName and Plain(spellID) and self:SpellName(spellID) == regenName then
    regenCast = GetTime()
    regenDirty = true
  end
  UpdateCast()
  UpdateCost()
end

function ns:PLAYER_REGEN_DISABLED()
  inCombat = true
  if self.preview then self:SetPreview(false) end
  self:ApplyFade()
end

function ns:PLAYER_REGEN_ENABLED()
  inCombat = false
  self:ApplyFade()
  self:AurasReadable() -- Tracker.lua: the auras can be read again
end

-- An addon restriction lifted (combat, encounter, PvP match): the auras may be readable again.
function ns:ADDON_RESTRICTION_STATE_CHANGED(_, state)
  local inactive = Enum.AddOnRestrictionState and Enum.AddOnRestrictionState.Inactive or 0
  if not issecretvalue(state) and state == inactive then self:AurasReadable() end
end

function ns:UI_SCALE_CHANGED()
  self:ApplyScale()
end
ns.DISPLAY_SIZE_CHANGED = ns.UI_SCALE_CHANGED

function ns:MarkIconsDirty() end -- Tracker.lua
function ns:TargetChanged() end
function ns:AurasReadable() end
function ns:SyncAuraButtons() end
function ns:DebugIcons() return {} end

---------------------------------------------------------------------------
-- Questions in the game's own dialog box: ns:Ask(text, alert, { label, fn }, ...), up to three
-- buttons from left to right (the last one usually Cancel, without fn). Escape closes it
-- without an answer.
---------------------------------------------------------------------------
local ASK = "CLARACOMBOPOINTS_ASK"

local function Answer(buttons, i)
  local fn = buttons and buttons[i] and buttons[i][2]
  if fn then fn() end
end

function ns:Ask(text, alert, ...)
  if not (StaticPopupDialogs and StaticPopup_Show) then return false end
  local buttons = { ... }
  local info = StaticPopupDialogs[ASK] or {
    text = "%s", -- the question comes whole, as the first argument
    timeout = 0, whileDead = true, hideOnEscape = true, noCancelOnEscape = true,
    selectCallbackByIndex = true, -- each button its own answer, Escape none of them
    OnButton1 = function(_, data) Answer(data, 1) end,
    OnButton2 = function(_, data) Answer(data, 2) end,
    OnButton3 = function(_, data) Answer(data, 3) end,
    OnEscape = function() end,
  }
  info.button1 = buttons[1] and buttons[1][1]
  info.button2 = buttons[2] and buttons[2][1]
  info.button3 = buttons[3] and buttons[3][1]
  info.showAlert = alert and true or nil
  StaticPopupDialogs[ASK] = info
  return StaticPopup_Show(ASK, text, nil, buttons) ~= nil
end

-- /cl reset, and the game's AddOns options: everything back to the defaults, once confirmed.
function ns:AskResetAddon()
  self:Ask(L.RESET_ADDON_ASK, true, { L.RESET_ADDON, function()
    self:ResetAddon()
    Print(L.RESET_ADDON_DONE)
  end }, { L.CANCEL })
end

---------------------------------------------------------------------------
-- Portrait right-click menu: "Reload UI" in Other Options, just above Edit Mode
---------------------------------------------------------------------------
local function ReloadInterface()
  if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
end

local function AddReloadEntry(_, root)
  local editModeIndex
  for index, description in root:EnumerateElementDescriptions() do
    if HUD_EDIT_MODE_MENU and MenuUtil.GetElementText(description) == HUD_EDIT_MODE_MENU then
      editModeIndex = index
      break
    end
  end
  if editModeIndex then
    root:Insert(MenuUtil.CreateButton(L.RELOAD_UI, ReloadInterface), editModeIndex)
  else
    root:CreateButton(L.RELOAD_UI, ReloadInterface) -- no Edit Mode entry: at the end
  end
end

if Menu and Menu.ModifyMenu and MenuUtil then
  Menu.ModifyMenu("MENU_UNIT_SELF", AddReloadEntry)
end

---------------------------------------------------------------------------
-- Slash commands: /clara, /cl, /ccp, /cp
---------------------------------------------------------------------------
SLASH_CLARACOMBOPOINTS1 = "/clara"
SLASH_CLARACOMBOPOINTS2 = "/cl"
SLASH_CLARACOMBOPOINTS3 = "/ccp"
SLASH_CLARACOMBOPOINTS4 = "/cp"
SlashCmdList.CLARACOMBOPOINTS = function(msg)
  if not ns.db then return end
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  if cmd == "lock" then
    ns:SetIconsLocked(true)
    ns:SetLocked(true)
    Print(L.LOCKED)
  elseif cmd == "unlock" then
    ns:SetLocked(false)
    Print(L.UNLOCKED)
  elseif cmd == "scale" and tonumber(arg) then
    ns:SetScalePercent(arg)
    Print(L.SCALE_SET:format(ns:GetScalePercent()))
  elseif cmd == "reset" and (arg == "pos" or arg == "position") then
    ns:ResetWindowPosition()
    Print(L.WINDOW_POS_RESET)
  elseif cmd == "reset" then
    ns:AskResetAddon()
  elseif cmd == "help" then
    Print(L.HELP)
  elseif cmd == "debug" then
    for _, line in ipairs(ns:DebugIcons()) do Print(line) end
  else
    ns:ToggleOptions()
  end
end
