-- Clara Combo Points
-- HUD for every class of WoW Forever: combo points on the top row (rogues, druids), energy or
-- rage (rogues, druids, warriors), mana and health bars, and up to three rows of icons above
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

-- (the TOC's: the options window's title and the settings page show the build in the game)
local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = meta and meta(ADDON, "Version") or "1.7.0"

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

-- Settings of one profile. Each class has its own profile
-- (account-wide); colours sampled from the reference screenshots.
ns.PROFILES = { "ROGUE", "DRUID", "WARRIOR", "PRIEST", "MAGE", "WARLOCK", "HUNTER", "SHAMAN", "PALADIN" }
-- what each class's HUD has: combo points (rogues, druids), an energy / rage bar (rogues,
-- druids, warriors), a mana bar (druids beside it; the others' own resource)
ns.COMBO_CLASSES = { ROGUE = true, DRUID = true }
ns.POWER_CLASSES = { ROGUE = true, DRUID = true, WARRIOR = true }
ns.MANA_CLASSES = { DRUID = true, PRIEST = true, MAGE = true, WARLOCK = true, HUNTER = true, SHAMAN = true, PALADIN = true }
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
  fadeOOC  = false,    -- out of combat the HUD fades to the two opacities below
  oocPower = .2,       -- energy / rage bar
  oocTop   = .2,       -- combo points and icons
  predict  = true,     -- rage about to be spent (queued Heroic Strike, Maul...) marked on the bar
  predictMana = true,  -- mana the spell being cast will spend, marked on the mana bar
  bearIconsFixed = false, -- druids: icon rows stay above the combo points in Bear Form, even without points
  healthClassColor = false, -- health bar in the class colour rather than its own
  skin     = "FLAT",   -- the bars' style: FLAT, CLASSIC (the game's bars), TOOLTIP (tooltip borders)
  hidden   = false,    -- the whole HUD hidden by hand (portrait menu, options, /cl hide)
  -- parts turned off in the colour list: not drawn at all and taking no room (the mana and
  -- health bars, the rage about to be spent and the value have settings of their own)
  disabled = { cp1 = false, cp2 = false, cp3 = false, cp4 = false, cp5 = false, energy = false, rage = false, bg = false },
  -- hidden when the player is in one of these situations (ns.HIDE_WHEN)
  hideWhen = { solo = false, party = false, raid = false, dungeon = false, raid10 = false, raid20 = false, raid40 = false,
    battleground = false },
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
    size    = 55,      -- row height (and icon width when square), reference pixels
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
    manaCost = { r = 1, g = 1,  b = 1,    a = .45 },
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
  print("|cffffd200Clara|r: " .. msg)
end
ns.Print = Print -- (only for what is asked for: /cl help, /cl debug)

-- A tooltip of the HUD (its icons) where the game puts its own (bottom right of the screen,
-- or by the cursor, as set in the game's options), like an action button's.
function ns:TooltipAt(owner)
  if GameTooltip_SetDefaultAnchor then
    GameTooltip_SetDefaultAnchor(GameTooltip, owner)
  else
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  end
end

-- Why something could not be done (a row full, a spell already there): in the game's red error
-- line at the top of the screen, not in the chat.
function ns:ShowError(msg)
  if type(msg) ~= "string" or msg == "" then return end
  if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(msg, 1, .1, .1, 1) end
end

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
costTex:SetWidth(1)

local textHolder = CreateFrame("Frame", nil, power) -- above the cost marker
textHolder:SetAllPoints()
textHolder:SetFrameLevel(power:GetFrameLevel() + 3)
local powerText = textHolder:CreateFontString(nil, "OVERLAY")
powerText:SetPoint("CENTER")
powerText:SetFont(ns.fonts[1].path, defaults.fontSize, defaults.outline)

-- Mana and health: a bar and its value (above the mana about to be spent)
local function ValueBar()
  local bar = CreateBar(hud, 0, 100)
  bar:SetSize(WIDTH, 12)
  local holder = CreateFrame("Frame", nil, bar)
  holder:SetAllPoints()
  holder:SetFrameLevel(bar:GetFrameLevel() + 3)
  bar.text = holder:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont(ns.fonts[1].path, 10, defaults.outline)
  return bar
end
local manaBar, healthBar = ValueBar(), ValueBar()
ns.manaBar, ns.healthBar = manaBar, healthBar

-- The mana the spell being cast will spend, drawn the same way on the mana bar.
local manaClip = CreateFrame("Frame", nil, manaBar)
manaClip:SetAllPoints()
manaClip:SetClipsChildren(true)
manaClip:Hide()
local manaHolder = CreateFrame("Frame", nil, manaClip)
manaHolder:SetAllPoints()
local manaCostTex = manaHolder:CreateTexture(nil, "ARTWORK")
manaCostTex:SetWidth(1)

-- the markers hang off their bar's fill (again whenever a style changes the fill's texture)
local function AnchorCosts()
  for tex, bar in pairs({ [costTex] = power, [manaCostTex] = manaBar }) do
    tex:ClearAllPoints()
    tex:SetPoint("TOPRIGHT", bar:GetStatusBarTexture(), "TOPRIGHT")
    tex:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
  end
end
AnchorCosts()
local elements = { combo = comboRow, power = power, mana = manaBar, health = healthBar }
ns.barFrames = elements
---------------------------------------------------------------------------
-- Bar styles. FLAT: plain colours, no frame. CLASSIC: the game's shaded bars in a thin grey
-- frame, as on the player's portrait. TOOLTIP: the shaded bars in the game's tooltip border.
-- The frame of each bar sits under it, around it (SKIN_ROOM, in the bar's units): bars, combo
-- cells and icon rows keep that much more room between them.
---------------------------------------------------------------------------
ns.SKINS = { "FLAT", "CLASSIC", "TOOLTIP" }
local SHADED = "Interface\\TargetingFrame\\UI-StatusBar"
local SKIN_ROOM = { FLAT = 0, CLASSIC = 2, TOOLTIP = 5 }
-- the game's bar colours, which the framed styles start with
ns.GAME_COLORS = {
  energy = { r = 1, g = 1, b = 0 }, rage = { r = 1, g = 0, b = 0 },
  mana = { r = 0, g = 0, b = 1 }, health = { r = 0, g = 1, b = 0 },
}

function ns:SkinRoom()
  return SKIN_ROOM[self.db and self.db.skin] or 0
end

-- The colour a style starts a part with (its default).
function ns:SkinColor(skin, key)
  local c = skin ~= "FLAT" and self.GAME_COLORS[key] or defaults.colors[key]
  return c and { r = c.r, g = c.g, b = c.b, a = defaults.colors[key].a }
end

local function TooltipColors()
  local bg, edge = TOOLTIP_DEFAULT_BACKGROUND_COLOR, TOOLTIP_DEFAULT_COLOR
  local br, bgG, bb = .09, .09, .19
  if bg and bg.GetRGB then br, bgG, bb = bg:GetRGB() end
  local er, eg, eb = 1, 1, 1
  if edge and edge.GetRGB then er, eg, eb = edge:GetRGB() end
  return br, bgG, bb, er, eg, eb
end

-- A bar's frame for a style, made the first time: a child of the bar, drawn under it.
local function SkinFrame(bar, skin)
  bar.skins = bar.skins or {}
  local f = bar.skins[skin]
  if f then return f end
  f = CreateFrame("Frame", nil, bar, "BackdropTemplate")
  local room = SKIN_ROOM[skin]
  f:SetPoint("TOPLEFT", -room, room)
  f:SetPoint("BOTTOMRIGHT", room, -room)
  if skin == "CLASSIC" then
    -- a grey line, a dark line, then the bar (measured on the portrait's bars)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    f:SetBackdropColor(.06, .06, .06, 1)
    f:SetBackdropBorderColor(.42, .42, .42, 1)
  else
    local br, bgG, bb, er, eg, eb = TooltipColors()
    local layout = NineSliceUtil and NineSliceUtil.GetLayout and NineSliceUtil.GetLayout("TooltipDefaultLayout")
    if layout then -- the game's own tooltip border
      NineSliceUtil.ApplyLayout(f, layout)
      if f.Center then f.Center:SetVertexColor(br, bgG, bb, .9) end
    else
      f:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
      f:SetBackdropColor(br, bgG, bb, .9)
      f:SetBackdropBorderColor(er, eg, eb, 1)
    end
  end
  bar.skins[skin] = f
  return f
end

local function StyledBars()
  local list = { power, manaBar, healthBar }
  for i = 1, NUM_POINTS do list[#list + 1] = cells[i] end
  return list
end

function ns:ApplySkin()
  local skin = self.db.skin
  for _, bar in ipairs(StyledBars()) do
    bar:SetStatusBarTexture(skin == "FLAT" and WHITE or SHADED)
    for name, f in pairs(bar.skins or {}) do f:SetShown(name == skin) end
    if skin ~= "FLAT" then
      local f = SkinFrame(bar, skin)
      f:Show()
      f:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1)) -- under the bar
    end
  end
  AnchorCosts()
end

-- A new style: its room around the bars, and its colours for the parts still at the old
-- style's (colours the player chose stay).
function ns:SetSkin(skin)
  local old = self.db.skin
  if skin == old or not SKIN_ROOM[skin] then return end
  for key in pairs(self.GAME_COLORS) do
    local c, was = self.db.colors[key], self:SkinColor(old, key)
    if c and was and c.r == was.r and c.g == was.g and c.b == was.b then
      local new = self:SkinColor(skin, key)
      c.r, c.g, c.b = new.r, new.g, new.b
    end
  end
  self.db.skin = skin
  self:ApplyAll()
  self:RefreshOptions()
end

-- where the icon rows sit when every bar is turned off: a line at the top of the HUD
local noBar = CreateFrame("Frame", nil, hud)
noBar:SetPoint("TOP")
noBar:SetSize(WIDTH, 1)

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
  -- unreadable (secret) count keeps them in place. In combat they always come down in Bear Form:
  -- the click buttons over the icons, placed before the fight, are there (Clicks.lua).
  local fighting = InCombatLockdown()
  local onBar = powerType == POWER_RAGE and ns.profileClass == "DRUID" and not ns.db.bearIconsFixed
    and (fighting or not issecretvalue(v))
  if onBar and not fighting then -- points on cells turned off show nothing either
    for i = 1, math.min(v, NUM_POINTS) do
      if not ns.db.disabled["cp" .. i] then onBar = false break end
    end
  end
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

-- Localized name of a spell ID, or nil if this client does not know it (an item: its name).
function ns:SpellName(spell)
  if type(spell) ~= "number" then
    local item = self.ItemOf and self:ItemOf(spell) -- an item ("item:ID"): its name
    if item then return self:ItemName(item) end
    return spell
  end
  local ok, name = pcall(GetSpellName, spell)
  if ok and type(name) == "string" and not issecretvalue(name) and name ~= "" then return name end
end

-- A character's whole name: "First Surname" on WoW Forever, whatever the name settings show
-- (UnitName follows them: one's own surname hidden, it gives the first name alone). Elsewhere the
-- name alone (there the second value is a realm).
function ns:FullName(unit)
  unit = unit or "player"
  local name, surname
  if UnitNameUnmodified then
    local ok, a, b = pcall(UnitNameUnmodified, unit)
    if ok then name, surname = a, b end
  end
  if issecretvalue(name) or type(name) ~= "string" or name == "" then
    name, surname = UnitName(unit)
    if issecretvalue(name) or type(name) ~= "string" or name == "" then return nil end
  end
  local consts = Constants and Constants.CharacterNameSeparatorConsts
  local sep = consts and consts.CHARACTERNAME_SURNAME_SEPARATOR
  if type(sep) == "string" and not issecretvalue(surname) and type(surname) == "string" and surname ~= ""
    and not name:find(sep, 1, true) then
    return name .. sep .. surname
  end
  return name
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

local function PowerCost(spell, kind)
  if not GetSpellPowerCost then return 0 end
  local ok, costs = pcall(GetSpellPowerCost, spell)
  if not ok or issecretvalue(costs) or type(costs) ~= "table" then return 0 end
  for _, info in ipairs(costs) do
    if type(info) == "table" and Plain(info.type) == kind then return Plain(info.cost) or 0 end
  end
  return 0
end

local function RageCost(spell)
  return PowerCost(spell, POWER_RAGE)
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

local manaPredicting  -- the mana bar shown and its prediction wanted
local manaCast = 0    -- mana the cast in progress will spend
local manaShown       -- mana currently marked

-- The spell being cast (nil if none, or hidden from addons). Instant spells and channels
-- spend at once, so only casts are counted.
local function CastSpell()
  if not UnitCastingInfo then return end
  local ok, name, _, _, _, _, _, _, _, spellID = pcall(UnitCastingInfo, "player")
  if ok and not issecretvalue(name) and name then return Plain(spellID) end
end

local function UpdateCast()
  castCost, manaCast = 0, 0
  if not predicting and not manaPredicting then return end
  local spell = CastSpell()
  if not spell then return end
  if predicting then castCost = RageCost(spell) end
  if manaPredicting then manaCast = PowerCost(spell, POWER_MANA) end
end

local function UpdateManaCost()
  local mana = manaPredicting and manaCast or 0
  if manaPredicting and ns.preview and mana == 0 then mana = -1 end -- a sample, to see the color
  if mana == manaShown then return end
  manaShown = mana
  if mana ~= 0 then
    local width = ns.db.bars.mana.width
    local max = Plain(UnitPowerMax("player", POWER_MANA))
    manaCostTex:SetWidth(mana < 0 and width * .15 or (max and max > 0) and math.min(width, mana / max * width) or 1)
    manaClip:Show()
  else
    manaClip:Hide()
  end
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
  UpdateManaCost()
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
  costShown, manaShown = nil, nil
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

-- Rage for warriors and for druids in Bear Form, energy otherwise.
local function WantedPowerType()
  if ns.profileClass == "WARRIOR" then return POWER_RAGE end
  if ns.profileClass == "DRUID" and ns.isDruid then
    local pt = UnitPowerType("player")
    if not issecretvalue(pt) and pt == POWER_RAGE then return POWER_RAGE end
  end
  return POWER_ENERGY
end

-- Combo points, energy / rage and the icons: druids see them in Cat Form (energy) and Bear
-- Form (rage), unless "Cat and Bear Form only" is off; while unlocked or while the options
-- are open, in any form, so they can be moved and coloured. Rogues and warriors always.
-- The icon rows are being edited on the HUD: unlocked, or open for a spell taken from the chat
-- (LearnedSpells.lua) until it is placed, or, the options open, for a spell held or dragged
-- (Tracker.lua: ns.heldDrop).
function ns:EditingIcons()
  return self.db ~= nil and (self.db.iconsLocked == false or self.chatDrop ~= nil or self.heldDrop ~= nil)
end

local function FormShown()
  if not ns.isDruid then return true end
  if not ns.db.druidCatOnly or not ns.db.locked or ns:EditingIcons() or ns.optionsOpen then return true end
  local pt = UnitPowerType("player")
  return issecretvalue(pt) or pt == POWER_ENERGY or pt == POWER_RAGE
end

-- The combo cells turned on, in order.
local function CellsOn()
  local on = {}
  for i = 1, NUM_POINTS do
    if not ns.db.disabled["cp" .. i] then on[#on + 1] = i end
  end
  return on
end

local function AnyCellOn() -- (#CellsOn() > 0, without making a list: read often)
  for i = 1, NUM_POINTS do
    if not ns.db.disabled["cp" .. i] then return true end
  end
  return false
end

-- The bars of the class shown, unless turned off: the combo row (some cell on), the bar of the
-- resource it shows now (energy or rage), the mana bar, the health bar. A bar turned off takes
-- no room: the others close up.
local function BarUsed(key)
  local class = ns.profileClass
  if key == "combo" then return ns.COMBO_CLASSES[class] and AnyCellOn() end
  if key == "power" then
    return ns.POWER_CLASSES[class] and not ns.db.disabled[WantedPowerType() == POWER_RAGE and "rage" or "energy"]
  end
  if key == "mana" then return ns.MANA_CLASSES[class] and ns.db.bars.mana.show end
  return ns.db.bars.health.show
end

-- Which bars show: combo points and energy / rage as the form allows, the others always.
local function BarShown(key)
  if key == "combo" or key == "power" then return BarUsed(key) and FormShown() end
  return BarUsed(key)
end

local function ShownKey()
  local key = ""
  for _, k in ipairs(ns.BAR_KEYS) do key = key .. (BarShown(k) and "1" or "0") end
  return key
end

-- What the layout depends on: the bars shown and the bars taking room (a druid's form can
-- change the second alone: caster form to Bear Form with the rage bar turned off).
local function LayoutKey()
  local key = ShownKey()
  for _, k in ipairs(ns.BAR_KEYS) do key = key .. (BarUsed(k) and "1" or "0") end
  return key
end

-- Situations the HUD can be hidden in: the group (none, a party, a raid group) and the
-- instance (a dungeon, a raid of 10, 20 or 40 players - 25 counts as 20 -, a battleground).
ns.HIDE_WHEN = { "solo", "party", "raid", "dungeon", "raid10", "raid20", "raid40", "battleground" }
function ns:Situation(into) -- (into: a table to fill, instead of a new one)
  local now = into or {}
  if into then wipe(into) end
  if IsInRaid and IsInRaid() then
    now.raid = true
  elseif IsInGroup and IsInGroup() then
    now.party = true
  else
    now.solo = true
  end
  local inside, kind = false, nil
  if IsInInstance then inside, kind = IsInInstance() end
  if inside and kind == "party" then now.dungeon = true end
  if inside and kind == "pvp" then now.battleground = true end
  if inside and kind == "raid" then
    local size = 40
    if GetInstanceInfo then
      local _, _, _, _, maxPlayers, _, _, _, groupSize = GetInstanceInfo()
      size = (type(maxPlayers) == "number" and maxPlayers > 0 and maxPlayers)
        or (type(groupSize) == "number" and groupSize > 0 and groupSize) or 40
    end
    now[size <= 10 and "raid10" or size <= 25 and "raid20" or "raid40"] = true
  end
  return now
end

-- Hidden by hand is this character's choice: kept in its class's profile, whatever tab the
-- options show.
local function OwnProfile()
  return ns.homeClass and ns.sv.profiles[ns.homeClass] or ns.db
end

-- Does a situation ticked in the options hide the HUD now? Also the situation as a key: the
-- HUD shown by hand against the rule stays shown until the situation changes.
local situation, situationKey = {}, {} -- (filled again each time: read often)
local function RuleHides()
  local now, hit, key = ns:Situation(situation), false, situationKey
  wipe(key)
  local rules = OwnProfile().hideWhen -- this character's class, whatever tab the options show
  for _, k in ipairs(ns.HIDE_WHEN) do
    if now[k] then
      key[#key + 1] = k
      if rules[k] then hit = true end
    end
  end
  return hit, table.concat(key, ",")
end

-- Hidden by hand, or by a situation ticked in the options (those wait while the HUD is being
-- set up: options open, bar or icons unlocked).
function ns:HiddenNow()
  if OwnProfile().hidden then return true end
  local db = self.db
  if self.optionsOpen or not db.locked or self:EditingIcons() then return false end
  local hit, key = RuleHides()
  return hit and self.shownAnyway ~= key
end

-- What the Show boxes say: shown, unless hidden by hand or by a situation (and not shown
-- anyway since).
function ns:ShownByChoice()
  if OwnProfile().hidden then return false end
  local hit, key = RuleHides()
  return not hit or self.shownAnyway == key
end

-- Every bar turned off: the icon rows still show, if they have spells (or are being edited).
local function IconsAlone()
  if not FormShown() then return false end
  if ns:EditingIcons() then return true end
  for _, side in ipairs(ns.SIDES) do
    for _, row in pairs(ns.db.rows[side]) do
      if #row > 0 then return true end
    end
  end
  return false
end

local function ShouldShow()
  if not ns.enabled then return false end
  if ns:HiddenNow() then return false end
  return ShownKey():find("1") ~= nil or IconsAlone()
end

-- Would the HUD show in a form that shows it (a druid out of Cat and Bear Form)? Its click
-- buttons keep their places meanwhile (Clicks.lua).
function ns:ShownOutOfForm()
  if not self.enabled or self:HiddenNow() then return false end
  for _, k in ipairs(self.BAR_KEYS) do if BarUsed(k) then return true end end
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(self.db.rows[side]) do
      if #row > 0 then return true end
    end
  end
  return false
end

local shownKey -- the bars laid out (ApplyLayout: LayoutKey)
function ns:UpdateVisibility()
  iconLayer:SetShown(FormShown())
  if LayoutKey() ~= shownKey then self:ApplyLayout() end
  hud:SetShown(ShouldShow())
  if self.SyncClickers then self:SyncClickers() end -- the click buttons over the icons (Clicks.lua)
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
  if self.db.disabled.bg then bg = { r = 0, g = 0, b = 0, a = 0 } end -- turned off: nothing drawn
  for i = 1, NUM_POINTS do
    local k = c["cp" .. i]
    cells[i]:SetStatusBarColor(k.r, k.g, k.b, k.a)
    cells[i].bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
  end
  local bar = c[powerType == POWER_RAGE and "rage" or "energy"]
  power:SetStatusBarColor(bar.r, bar.g, bar.b, bar.a)
  power.bg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
  costTex:SetColorTexture(c.cost.r, c.cost.g, c.cost.b, c.cost.a)
  manaCostTex:SetColorTexture(c.manaCost.r, c.manaCost.g, c.manaCost.b, c.manaCost.a)
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

-- In Bear Form the empty combo cells are not drawn: the row only shows points the target
-- actually has, and is back in full the moment the druid shifts to Cat Form.
function ns:UpdatePowerMode()
  local wanted = WantedPowerType()
  powerType = wanted
  local bear = self.profileClass == "DRUID" and wanted == POWER_RAGE
  for i = 1, NUM_POINTS do
    cells[i].bg:SetShown(not bear)
    for name, f in pairs(cells[i].skins or {}) do f:SetShown(not bear and name == self.db.skin) end -- its frame too
  end
  predicting = wanted == POWER_RAGE and self.db.predict
  manaPredicting = self.MANA_CLASSES[self.profileClass] and self.db.bars.mana.show and self.db.predictMana or false
  self:ApplyColors()
  RefreshValues()
end

function ns:GetPowerType()
  return powerType
end

function ns:ApplyAlpha()
  hud:SetAlpha(self.db.alpha)
end

-- The whole HUD's opacity, 0 to 1 (options, portrait menu).
function ns:SetAlpha(alpha)
  self.db.alpha = math.min(1, math.max(0, alpha))
  self:ApplyAlpha()
  self:RefreshOptions()
end

-- The whole HUD hidden or shown again by hand.
function ns:SetHidden(hidden)
  OwnProfile().hidden = hidden and true or false
  self.shownAnyway = nil
  if not hidden then -- shown against a situation's rule: until the situation changes
    local hit, key = RuleHides()
    if hit then self.shownAnyway = key end
  end
  self:UpdateVisibility()
  self:RefreshOptions()
  self:RefreshMenuLine()
end

function ns:SetHideWhen(key, on)
  self.db.hideWhen[key] = on and true or false
  self:UpdateVisibility()
  self:RefreshOptions()
end

-- Out of combat the bar and the combo points / icons fade to their own opacity. Not while
-- unlocked or while the options are open (so colours can be judged), except for a moment
-- after an out-of-combat setting changes, to show the result.
local inCombat = false
function ns:ApplyFade()
  local db = self.db
  local fade = db.fadeOOC and not inCombat and db.locked and not self:EditingIcons() and (not self.optionsOpen or self.fadePreview ~= nil)
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

-- The class's bars, top to bottom in the profile's order, each centred at its own size and
-- scale, 4 apart; the HUD is as large as all of them. A bar the form hides keeps its place, so
-- the druid's mana bar stays put on shapeshifting. (Warriors have no combo row: the first
-- icon row sits on the bar.)
function ns:ApplyLayout()
  local bars = self.db.bars
  local room = self:SkinRoom() -- each bar's frame, around it
  local y, wide = 0, 1
  for _, key in ipairs(bars.order) do
    local frame = elements[key]
    frame:SetShown(BarShown(key))
    if BarUsed(key) then
      local b = bars[key]
      local around = room * b.scale
      y = y + around
      frame:SetScale(b.scale)
      frame:SetSize(b.width, b.height)
      frame:ClearAllPoints()
      frame:SetPoint("TOP", hud, "TOP", 0, -y / b.scale)
      y = y + b.height * b.scale + around + ROW_GAP
      wide = math.max(wide, (b.width + 2 * room) * b.scale)
    end
  end
  if y == 0 then
    -- every bar off (icons alone): the HUD keeps the energy / rage bar's room, to be grabbed
    -- while unlocked; the icon rows meet on its top line, so no hole shows
    local p = bars.power
    hud:SetSize(p.width * p.scale, p.height * p.scale)
  else
    hud:SetSize(wide, y - ROW_GAP)
  end
  noBar:SetWidth(bars.power.width * bars.power.scale)
  shownKey = LayoutKey()
  -- the combo cells turned on share the row's width (a cell keeps its point: cell 3 lights up
  -- at 3 points, wherever it sits)
  local cb = bars.combo
  local on = CellsOn()
  local n = math.max(1, #on)
  local gap = self:CellGap()
  local cellWidth = (cb.width - (n - 1) * gap) / n
  for i = 1, NUM_POINTS do cells[i]:Hide() end
  for place, i in ipairs(on) do
    cells[i]:ClearAllPoints()
    cells[i]:SetPoint("TOPLEFT", (place - 1) * (cellWidth + gap), 0)
    cells[i]:SetSize(cellWidth, cb.height)
    cells[i]:Show()
  end
  ValueFonts()
  self:LayoutIcons()
  RefreshValues()
end

-- A combo point cell's size on the HUD, and the gap between cells (icons of the Rectangular
-- shape take them).
function ns:ComboCellSize()
  local cb = self.db.bars.combo
  local n = #CellsOn()
  if n == 0 or not self.COMBO_CLASSES[self.profileClass] then n = NUM_POINTS end -- no combo row: five cells' size
  local gap = self:CellGap()
  return (cb.width - (n - 1) * gap) / n * cb.scale, cb.height * cb.scale, gap * cb.scale
end

-- Between two combo cells: their frames, and a little room.
function ns:CellGap()
  local room = self:SkinRoom()
  return room > 0 and math.max(CP_GAP, 2 * room + 2) or CP_GAP
end

-- The bars the icon rows sit on, with their widths on the HUD: the top one for the rows
-- above, the bottom one for the rows below. (In Bear Form without combo points the empty
-- combo row is passed over; with every bar turned off, the rows meet at the top of the HUD.)
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
  if not found then
    local w = bars.power.width * bars.power.scale
    return noBar, noBar, w, w, 0, 0
  end
  local room = self:SkinRoom()
  return elements[top], elements[bottom], bars[top].width * bars[top].scale, bars[bottom].width * bars[bottom].scale,
    room * bars[top].scale, room * bars[bottom].scale
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

-- One lock: unlocked, the bar moves (the one shown) and its icon rows are edited on it (every
-- class's icons); locked again, every class's bar and icons are.
function ns:SetLocked(locked)
  locked = locked and true or false
  self.db.locked = locked
  for _, profile in pairs(self.sv.profiles) do
    profile.iconsLocked = locked
    if locked then profile.locked = true end
  end
  self:ApplyLock()
end
ns.SetIconsLocked = ns.SetLocked
function ns:LockAll() self:SetLocked(true) end

-- The lock of the profile shown, on the HUD and in the options.
function ns:ApplyLock()
  hud:EnableMouse(not self.db.locked)
  mover:SetShown(not self.db.locked)
  self:UpdateVisibility()
  self:LayoutIcons()
  self:ApplyFade()
  self:RefreshOptions()
  self:RefreshSettingsPage()
  self:RefreshMenuLine()
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
  costShown, manaShown = nil, nil
  UpdateCost()
  self:UpdateIcons()
  self:RefreshOptions()
end

function ns:SetOptionsOpen(open)
  self.optionsOpen = open and true or false
  self:WatchLogout(self.optionsOpen)
  self:WatchHeldSpell(self.optionsOpen) -- (Tracker.lua)
  self:UpdateVisibility()
  self:ApplyFade()
end

function ns:SetDruidCatOnly(on)
  self.db.druidCatOnly = on and true or false
  self:UpdateVisibility()
  self:RefreshOptions()
end

-- Each part turned on or off (the boxes of the options' colour lines). Mana and health are
-- their bars' boxes, the rage about to be spent and the value have their own options; the
-- others (combo cells, energy bar, rage bar, background) are switched here only.
function ns:ElementOn(key)
  local db = self.db
  if key == "mana" or key == "health" then return db.bars[key].show end
  if key == "cost" then return db.predict end
  if key == "manaCost" then return db.predictMana end
  if key == "text" then return db.showText end
  return not db.disabled[key]
end

function ns:SetElementOn(key, on)
  on = on and true or false
  local db = self.db
  if key == "mana" or key == "health" then
    db.bars[key].show = on
  elseif key == "cost" then
    db.predict = on
  elseif key == "manaCost" then
    db.predictMana = on
  elseif key == "text" then
    db.showText = on
  elseif db.disabled[key] ~= nil then
    db.disabled[key] = not on
  else
    return
  end
  self:ApplyAll()
  self:UpdateVisibility()
  self:RefreshOptions()
end

-- The parts a bar of a class is made of: the five combo cells, the resources its energy /
-- rage bar shows, the mana bar, the health bar.
function ns:BarParts(key, class)
  class = class or self.profileClass
  if key == "combo" then return { "cp1", "cp2", "cp3", "cp4", "cp5" } end
  if key == "power" then
    if class == "ROGUE" then return { "energy" } end
    if class == "WARRIOR" then return { "rage" } end
    return { "energy", "rage" }
  end
  return { key }
end

-- A bar is on while any of its parts is (the options' list of bars).
function ns:BarOn(key)
  for _, part in ipairs(self:BarParts(key)) do
    if self:ElementOn(part) then return true end
  end
  return false
end

-- A whole bar turned on or off: all its parts, then the HUD once.
function ns:SetBarOn(key, on)
  on = on and true or false
  local db = self.db
  for _, part in ipairs(self:BarParts(key)) do
    if part == "mana" or part == "health" then db.bars[part].show = on else db.disabled[part] = not on end
  end
  self:ApplyAll()
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
  self:ApplySkin()
  self:ApplyLayout()
  self:ApplyFont()
  self:UpdatePowerMode() -- colours and values too
  self:ApplyAlpha()
  self:ApplyLock()
end

-- Out-of-combat fade (General > Opacity) back to its defaults (off, 20 % / 20 %).
function ns:ResetFade()
  self.db.fadeOOC, self.db.oocPower, self.db.oocTop = defaults.fadeOOC, defaults.oocPower, defaults.oocTop
  self:PreviewFade()
  self:RefreshOptions()
end

-- Colours back to their defaults (the style's own for the bars it colours): all of them, or
-- the keys listed (one bar's).
function ns:ResetColors(keys)
  if keys then
    for _, key in ipairs(keys) do self.db.colors[key] = self:SkinColor(self.db.skin, key) end
  else
    self.db.colors = CopyDefaults(defaults.colors, {})
    for key in pairs(self.GAME_COLORS) do -- the style's own colours
      local c = self:SkinColor(self.db.skin, key)
      self.db.colors[key].r, self.db.colors[key].g, self.db.colors[key].b = c.r, c.g, c.b
    end
  end
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
  local iconsLocked, hidden = self.db.iconsLocked, self.db.hidden -- not settings of the tab
  wipe(self.db)
  FillProfile(self.db, self.profileClass)
  self.db.iconsLocked, self.db.hidden = iconsLocked, hidden
  self:ApplyAll()
  self:RefreshOptions()
end

function ns:ResetIcons()
  self.db.rows = self:DefaultRows(self.profileClass)
  self:LayoutIcons()
  self:UpdateVisibility()
  self:RefreshOptions()
end

function ns:AllLocked()
  for _, profile in pairs(self.sv.profiles) do
    if not profile.locked or not profile.iconsLocked then return false end
  end
  return true
end


-- The options window's pages: General, Bars, Icons, Visibility, Profiles (Options.lua).
ns.PAGE_COUNT = 5
local function DefaultPageOrder()
  local order = {}
  for i = 1, ns.PAGE_COUNT do order[i] = i end
  return order
end

-- What the portrait's menu shows (account-wide): the addon's section, "Reload UI". Set here or
-- in the game's AddOns options, each shows the other's change.
function ns:SetMenuOption(field, on)
  self.sv.menu[field] = on and true or false
  self:RefreshOptions()
  self:RefreshSettingsPage()
end

-- Everything back to the defaults: every class profile, the options window, its page order,
-- the spells panel and the portrait icons. The saved profiles, the interface language and what the addon learned
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
  self.sv.menu = { line = true, reload = true }
  self.sv.pageOrder = DefaultPageOrder()
  self.sv.catalog = { locked = true }
  self.sv.portraits = {}
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

-- A bar unlocked on another class's options tab must not stay behind in that profile:
-- relocked when the options close, and on logout / reload in case they were still open. (The
-- icons' lock is one for every class.)
function ns:LockOtherProfiles()
  local home = self.homeClass or "ROGUE"
  for class, profile in pairs(self.sv.profiles) do
    if class ~= home then profile.locked = true end
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
  profile.locked = self.db.locked -- (one lock: an unlocked bar stays unlocked on the next tab)
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
  if not SKIN_ROOM[db.skin] then db.skin = defaults.skin end
  for _, group in ipairs({ "hideWhen", "disabled" }) do
    for key in pairs(db[group]) do
      if defaults[group][key] == nil then db[group][key] = nil end
    end
  end
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
  clean.locked, clean.iconsLocked, clean.hidden = nil, nil, nil
  if not into then return clean end
  wipe(into)
  for k, v in pairs(clean) do into[k] = v end
  return into
end

-- Options window (account-wide): where it is (top left corner, UIParent units; nil = centred),
-- its scale (nil = as large as fits the screen, up to 100 %), its size (unscaled; nil = the
-- default) and opacity.
ns.MIN_WINDOW_SCALE, ns.MAX_WINDOW_SCALE = .4, 2
ns.MIN_WINDOW_ALPHA = .2
ns.MIN_WINDOW_W, ns.MAX_WINDOW_W = 640, 1800
ns.MIN_WINDOW_H, ns.MAX_WINDOW_H = 540, 1400
ns.MIN_SIDE_W, ns.MAX_SIDE_W = 380, 900 -- the spells panel's width
local function CleanWindow(sv)
  local w = type(sv.window) == "table" and sv.window or {}
  sv.window = w
  if not (Finite(w.left) and Finite(w.top)) then w.left, w.top = nil, nil end
  if not (Finite(w.scale) and w.scale >= ns.MIN_WINDOW_SCALE and w.scale <= ns.MAX_WINDOW_SCALE) then w.scale = nil end
  if not (Finite(w.alpha) and w.alpha >= ns.MIN_WINDOW_ALPHA and w.alpha <= 1) then w.alpha = 1 end
  if not (Finite(w.w) and w.w >= ns.MIN_WINDOW_W and w.w <= ns.MAX_WINDOW_W) then w.w = nil end
  if not (Finite(w.h) and w.h >= ns.MIN_WINDOW_H and w.h <= ns.MAX_WINDOW_H) then w.h = nil end
  -- the tab and the page shown last (Options.lua: opened again on them); QOL: the Improvements
  -- tab, on the module of qol
  local TABS = { PRIEST = true, MAGE = true, WARLOCK = true, DRUID = true, ROGUE = true, HUNTER = true, SHAMAN = true,
    PALADIN = true, WARRIOR = true, QOL = true }
  if not TABS[w.tab] then w.tab = nil end
  if not (Finite(w.page) and w.page >= 1 and w.page <= 10 and w.page == math.floor(w.page)) then w.page = nil end
  if type(w.qol) ~= "string" or #w.qol > 40 then w.qol = nil end
  for k in pairs(w) do
    if k ~= "left" and k ~= "top" and k ~= "scale" and k ~= "alpha" and k ~= "w" and k ~= "h" and k ~= "tab" and k ~= "page"
      and k ~= "qol" then w[k] = nil end
  end
end

-- The options' spells panel: locked beside the window, on its right or its left (moved and
-- scaled with it, as tall as it), or on its own with its place (top left corner in UIParent
-- units), scale and height; its width (nil: the default); its known spells only box.
local function CleanCatalog(sv)
  local c = type(sv.catalog) == "table" and sv.catalog or {}
  local clean = { locked = c.locked ~= false, knownOnly = c.knownOnly == true or nil, side = c.side == "left" and "left" or nil }
  if not clean.locked and Finite(c.left) and Finite(c.top) and Finite(c.scale)
    and c.scale >= ns.MIN_WINDOW_SCALE and c.scale <= ns.MAX_WINDOW_SCALE then
    clean.left, clean.top, clean.scale = c.left, c.top, c.scale
  end
  if Finite(c.w) and c.w >= ns.MIN_SIDE_W and c.w <= ns.MAX_SIDE_W then clean.w = math.floor(c.w + .5) end
  if Finite(c.h) and c.h >= ns.MIN_WINDOW_H and c.h <= ns.MAX_WINDOW_H then clean.h = math.floor(c.h + .5) end
  sv.catalog = clean
end

-- The icon each class tab wears in the options' portrait: one of its specialisations
-- (ns.SPECS), or the default.
ns.SPECS = {
  PRIEST  = { "Spell_Holy_PowerWordShield", "Spell_Holy_GuardianSpirit", "Spell_Shadow_ShadowWordPain" },
  MAGE    = { "Spell_Holy_MagicalSentry", "Spell_Fire_FireBolt02", "Spell_Frost_FrostBolt02" },
  WARLOCK = { "Spell_Shadow_DeathCoil", "Spell_Shadow_Metamorphosis", "Spell_Shadow_RainOfFire" },
  DRUID   = { "Spell_Nature_StarFall", "Ability_Druid_CatForm", "Ability_Racial_BearForm", "Spell_Nature_HealingTouch" },
  ROGUE   = { "Ability_Rogue_Eviscerate", "Ability_BackStab", "Ability_Stealth" },
  HUNTER  = { "Ability_Hunter_BestialDiscipline", "Ability_Hunter_FocusedAim", "Ability_Hunter_Camouflage" },
  SHAMAN  = { "Spell_Nature_Lightning", "Spell_Shaman_ImprovedStormstrike", "Spell_Nature_MagicImmunity" },
  PALADIN = { "Spell_Holy_HolyBolt", "Ability_Paladin_ShieldoftheTemplar", "Spell_Holy_AuraOfLight" },
  WARRIOR = { "Ability_Warrior_SavageBlow", "Ability_Warrior_InnerRage", "Ability_Warrior_DefensiveStance" },
}
local PORTRAITS_VERSION = 2 -- 2: the picks of the test builds forgotten (the first specialisation by default)
local function CleanPortraits(sv)
  local old = type(sv.portraits) == "table" and sv.portraits or {}
  if sv.portraitsVersion ~= PORTRAITS_VERSION then old = {} end
  sv.portraitsVersion = PORTRAITS_VERSION
  sv.portraits = {}
  for class, specs in pairs(ns.SPECS) do
    local i = old[class]
    if type(i) == "number" and i >= 1 and i <= #specs and i == math.floor(i) then sv.portraits[class] = i end
  end
end

-- What this addon adds to the portrait's menu (account-wide): its section, "Reload UI". And
-- the order of the options window's pages (each page once; another count: the default).
local function CleanMenu(sv)
  local m = type(sv.menu) == "table" and sv.menu or {}
  sv.menu = { line = m.line ~= false, reload = m.reload ~= false }
  local order, seen = {}, {}
  for _, i in ipairs(type(sv.pageOrder) == "table" and sv.pageOrder or {}) do
    if type(i) == "number" and i >= 1 and i <= ns.PAGE_COUNT and i == math.floor(i) and not seen[i] then
      seen[i] = true
      order[#order + 1] = i
    end
  end
  if #order ~= ns.PAGE_COUNT then order = DefaultPageOrder() end
  sv.pageOrder = order
end

local ICONS_VERSION, OLD_ICON_SIZE = 2, 25
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
  -- weapon enchantments: the imbue each was learned for, the longest time left seen, and the
  -- items seen to enchant a weapon
  local LEARNED = { enchantKeys = "string", enchantTimes = "number", enchantItems = "boolean" }
  for key, kind in pairs(LEARNED) do
    if type(sv[key]) ~= "table" then sv[key] = {} end
    for id, v in pairs(sv[key]) do
      if type(id) ~= "number" or type(v) ~= kind then sv[key][id] = nil end
    end
  end
  if sv.quietLogin ~= false then sv.quietLogin = nil end -- (on unless turned off: QuietLogin.lua)
  if sv.whoNames ~= false then sv.whoNames = nil end -- (on unless turned off: Who.lua)
  if sv.noBlink ~= false then sv.noBlink = nil end -- (on unless turned off: GameFixes.lua)
  -- the game's options Clara sets once (GameFixes.lua): for the account, and each character's
  if type(sv.gameDefaults) ~= "number" then sv.gameDefaults = nil end
  -- the action bars', micro menu's and bags' scale (Modules/BarScale): 0.5 to 2, nil the game's
  if type(sv.barScale) ~= "number" or sv.barScale ~= sv.barScale or sv.barScale < 0.5 or sv.barScale > 2 then sv.barScale = nil end
  if type(sv.gameDefaultsChars) == "table" then
    for who, v in pairs(sv.gameDefaultsChars) do
      if type(who) ~= "string" or type(v) ~= "number" then sv.gameDefaultsChars[who] = nil end
    end
  else
    sv.gameDefaultsChars = nil
  end
  if sv.buyemallConfirm ~= false then sv.buyemallConfirm = nil end -- (BuyEmAll asks first unless turned off)
  sv.cameraOff = nil -- (an earlier DynamicCam box's, no longer used: Modules/DynamicCam/Glue.lua)
  if type(sv.cameraDisabled) ~= "boolean" then sv.cameraDisabled = nil end -- (DynamicCam off from the box: Glue.lua)
  if type(sv.cameraWas) == "table" then -- (the game's camera before DynamicCam ran: Glue.lua)
    for k, v in pairs(sv.cameraWas) do if type(k) ~= "string" or type(v) ~= "string" then sv.cameraWas[k] = nil end end
  else
    sv.cameraWas = nil
  end
  -- the player's DynamicCam Zoom Increments with the Dynamic camera box ticked, and unticked (the same)
  for _, key in ipairs({ "cameraZoom", "cameraZoomOff" }) do
    local kept = sv[key]
    if type(kept) == "table" then
      if type(kept.standard) ~= "number" then kept.standard = nil end
      if type(kept.situations) == "table" then
        for id, v in pairs(kept.situations) do if type(v) ~= "number" then kept.situations[id] = nil end end
      else
        kept.situations = nil
      end
    else
      sv[key] = nil
    end
  end
  -- the interface improvements turned off (QoL.lua): only "false" is kept
  if type(sv.qol) == "table" then
    for key, v in pairs(sv.qol) do if v ~= false or type(key) ~= "string" then sv.qol[key] = nil end end
    if next(sv.qol) == nil then sv.qol = nil end
  else
    sv.qol = nil
  end
  -- the modules' own addons turned off for a character when the module took over (QoL.lua)
  if type(sv.qolTookOver) == "table" then
    for key, chars in pairs(sv.qolTookOver) do
      if type(key) ~= "string" or type(chars) ~= "table" then
        sv.qolTookOver[key] = nil
      else
        for who, v in pairs(chars) do if type(who) ~= "string" or v ~= true then chars[who] = nil end end
        if next(chars) == nil then sv.qolTookOver[key] = nil end
      end
    end
    if next(sv.qolTookOver) == nil then sv.qolTookOver = nil end
  else
    sv.qolTookOver = nil
  end
  CleanWindow(sv)
  CleanCatalog(sv)
  CleanPortraits(sv)
  CleanMenu(sv)
  ns:InitProfiles(sv) -- Profiles.lua: the profiles saved on each class tab
  ns:InitAlts(sv) -- AltSetup.lua: the game's settings kept for alts
  -- 1.6 made the icons 55 tall by default (25 before): the profiles still at the old default
  -- (each class's, and those saved) move up to it, once
  if sv.iconsVersion ~= ICONS_VERSION then
    for _, profile in pairs(sv.profiles) do
      if profile.icons.size == OLD_ICON_SIZE then profile.icons.size = defaults.icons.size end
    end
    for _, store in pairs(sv.saved) do
      for _, data in pairs(store) do
        if data.icons and data.icons.size == OLD_ICON_SIZE then data.icons.size = defaults.icons.size end
      end
    end
    sv.iconsVersion = ICONS_VERSION
  end
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

-- What the other files start once the addon is on for this character (its events, its hooks):
-- nothing at all on a class without a tab.
ns.onEnable = {}

function ns:PLAYER_LOGIN()
  events:UnregisterEvent("PLAYER_LOGIN")
  local _, class = UnitClass("player")
  self.isRogue = (class == "ROGUE")
  self.isDruid = (class == "DRUID")
  self.isWarrior = (class == "WARRIOR")
  self.enabled = self.sv.profiles[class] ~= nil -- the classes of World of Warcraft: Forever
  self.homeClass = self.enabled and class or "ROGUE"
  self.profileClass = self.homeClass
  self.db = self.sv.profiles[self.homeClass]
  -- one lock for the bar and the icons (they were apart before 1.6: locked unless both were not)
  local locked = self.db.locked or self.db.iconsLocked
  for _, profile in pairs(self.sv.profiles) do
    profile.iconsLocked = locked
    if locked then profile.locked = true end
  end
  local fighting = UnitAffectingCombat and UnitAffectingCombat("player")
  inCombat = (not issecretvalue(fighting) and fighting) and true or false
  self:ResolveSpells()
  self:ApplyAll()
  self:AltsAtLogin() -- AltSetup.lua: a new character gets the alts' game settings
  if not self.enabled then return end -- dormant on a class it has no tab for: no events, no updates

  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  pcall(events.RegisterEvent, events, "ADDON_RESTRICTION_STATE_CHANGED") -- auras secret beyond combat (encounters, PvP)
  events:RegisterEvent("UI_SCALE_CHANGED")
  events:RegisterEvent("DISPLAY_SIZE_CHANGED")
  events:RegisterEvent("GROUP_ROSTER_UPDATE") -- hidden in some situations (ns:HiddenNow)
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
  events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
  events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
  events:RegisterUnitEvent("UNIT_AURA", "player", "target")
  events:RegisterEvent("SPELL_UPDATE_COOLDOWN") -- spell cooldowns and charges on the icons
  events:RegisterEvent("SPELL_UPDATE_CHARGES")
  -- a form, stance or stealth on, a spell queued or repeating: its icon checked (Tracker.lua)
  for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_UPDATE_STATE", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL" }) do
    pcall(events.RegisterEvent, events, e) -- (not every event in every client build)
  end
  if self.isRogue or self.isDruid then -- combo points
    events:RegisterUnitEvent("UNIT_HEALTH", "target")
    events:RegisterUnitEvent("UNIT_FLAGS", "target")
    pcall(events.RegisterEvent, events, "UNIT_DIED") -- not in every client build
  end
  if self.isDruid then
    events:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player") -- power type changes with the form
  end
  if self.isDruid or self.isWarrior then -- rage about to be spent
    events:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
  end
  -- rage or mana about to be spent; imbues cast (their enchantment learned)
  for _, e in ipairs({ "START", "STOP", "FAILED", "INTERRUPTED", "DELAYED", "SUCCEEDED" }) do
    events:RegisterUnitEvent("UNIT_SPELLCAST_" .. e, "player")
  end
  -- weapon enchantments (imbues, poisons, oils, stones) on the icons; items: how many, their
  -- cooldown, their name and icon once the game has them
  events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
  for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(events.RegisterEvent, events, e) -- (not every event in every client build)
  end
  pcall(events.RegisterEvent, events, "WEAPON_ENCHANT_CHANGED") -- not in every client build
  if class == "SHAMAN" then pcall(events.RegisterEvent, events, "PLAYER_SWING") end -- Windfury's extra attacks (Forever)
  for _, start in ipairs(self.onEnable) do start() end -- (Clicks.lua, LearnedSpells.lua)
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

-- A new situation: the HUD shown by hand against a rule follows the rules again.
function ns:GROUP_ROSTER_UPDATE()
  local _, key = RuleHides()
  if self.shownAnyway ~= key then self.shownAnyway = nil end
  self:UpdateVisibility()
  self:RefreshMenuLine()
end
ns.ZONE_CHANGED_NEW_AREA = ns.GROUP_ROSTER_UPDATE

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
function ns:UPDATE_SHAPESHIFT_FORM()
  if self.isDruid then self:UNIT_DISPLAYPOWER() end -- (the form's power on the bar)
  self:CheckIcons() -- the form's icon checked (Tracker.lua)
end

function ns:ACTIONBAR_UPDATE_STATE()
  self:CheckIcons()
end
ns.START_AUTOREPEAT_SPELL = ns.ACTIONBAR_UPDATE_STATE
ns.STOP_AUTOREPEAT_SPELL = ns.ACTIONBAR_UPDATE_STATE

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
  costShown, manaShown = nil, nil
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
  self:CheckIcons() -- a queued spell's icon checked
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
  if Plain(spellID) then self:SpellDone(spellID) end -- imbues, Windfury (Tracker.lua)
  UpdateCast()
  UpdateCost()
end

function ns:UNIT_INVENTORY_CHANGED()
  self:CheckPendingImbue() -- (Tracker.lua)
end
ns.WEAPON_ENCHANT_CHANGED = ns.UNIT_INVENTORY_CHANGED

function ns:BAG_UPDATE_DELAYED()
  self:MarkIconsDirty()
end
ns.BAG_UPDATE_COOLDOWN = ns.BAG_UPDATE_DELAYED

-- An item's data arrived (Items.lua asked for it): its name and icon on the rows and options.
function ns:GET_ITEM_INFO_RECEIVED(id)
  if not issecretvalue(id) and self:ItemArrived(id) then
    self:LayoutIcons()
    self:RefreshOptions()
  end
end

function ns:PLAYER_SWING(duration, swingType)
  self:Swing(duration, swingType) -- (Tracker.lua)
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
function ns:CheckIcons() end
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

-- What still waits for a reload of the interface to take effect, by name (each part of the addon tells
-- it: a module turned on or off, Leatrix Plus's options marked *, a profile just put on).
local reloadChecks = {}
function ns:AddReloadCheck(fn) reloadChecks[#reloadChecks + 1] = fn end
function ns:ReloadPending()
  local names = {}
  for _, fn in ipairs(reloadChecks) do
    local ok, got = pcall(fn)
    if ok and type(got) == "string" then
      names[#names + 1] = got
    elseif ok and type(got) == "table" then
      for _, n in ipairs(got) do if type(n) == "string" then names[#names + 1] = n end end
    end
  end
  return names
end

-- A question with a line to type (a name) in the game's dialog box: fn(text) on its first button
-- or Enter; Cancel and Escape close it.
local ASK_TEXT = "CLARACOMBOPOINTS_ASK_TEXT"

local function TypedBox(dialog)
  return dialog and (dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox()))
end

function ns:AskText(text, typed, okLabel, fn)
  if not (StaticPopupDialogs and StaticPopup_Show) then return false end
  local info = StaticPopupDialogs[ASK_TEXT] or {
    text = "%s", hasEditBox = true, maxLetters = 32,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnShow = function(self, data)
      local box = TypedBox(self)
      if not box then return end
      box:SetText(data and data.typed or "")
      box:HighlightText()
      box:SetFocus()
    end,
    OnAccept = function(self, data)
      local box = TypedBox(self)
      if data and data.fn then data.fn(box and box:GetText() or "") end
    end,
    EditBoxOnEnterPressed = function(box, data)
      local dialog = box:GetParent()
      if data and data.fn then data.fn(box:GetText() or "") end
      if dialog then dialog:Hide() end
    end,
    EditBoxOnEscapePressed = function(box)
      local dialog = box:GetParent()
      if dialog then dialog:Hide() end
    end,
  }
  info.button1, info.button2 = okLabel, L.CANCEL
  StaticPopupDialogs[ASK_TEXT] = info
  return StaticPopup_Show(ASK_TEXT, text, nil, { typed = typed, fn = fn }) ~= nil
end

-- /cl reset, and the game's AddOns options: everything back to the defaults, once confirmed.
function ns:AskResetAddon()
  self:Ask(L.RESET_ADDON_ASK, true, { L.RESET_ADDON, function()
    self:ResetAddon()
  end }, { L.CANCEL })
end

---------------------------------------------------------------------------
-- Portrait right-click menu: "Reload UI" in Other Options just above Edit Mode, and at the
-- end a Clara Combo Points section: the HUD's opacity (a slider like the game's "Overall
-- opacity"), then a box to lock the HUD and, at the right end, a box to show / hide it all; then
-- a box to show or hide the game's damage meter
---------------------------------------------------------------------------
local function ReloadInterface()
  if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
end

-- The line is one frame of this addon's, lent to the menu while it is open (a frame of the
-- menu's own pool could be handed to another menu afterwards, with this slider's callback).
-- It is as narrow as the menu's own entries, so the menu keeps its width.
local MENU_LINE_W, MENU_LINE_H = 128, 42
local menuLine

local function BoxTip(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.tipTitle)
  if self.tipText then GameTooltip:AddLine(self.tipText, 1, 1, 1, true) end
  GameTooltip:Show()
end

local function MenuBox(f, onClick)
  local box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  box:SetSize(22, 22)
  box:SetScript("OnClick", function(self)
    if PlaySound and SOUNDKIT then
      PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end
    onClick(self:GetChecked() and true or false)
    if GameTooltip and GameTooltip:IsOwned(self) then BoxTip(self) end
  end)
  box:SetScript("OnEnter", BoxTip)
  box:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return box
end

local function MenuLine()
  if menuLine then return menuLine end
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetSize(MENU_LINE_W, MENU_LINE_H)
  f:Hide()
  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.label:SetPoint("TOPLEFT", 0, -2)
  f.label:SetJustifyH("LEFT")
  f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.value:SetPoint("TOPRIGHT", 0, -3)
  -- the opacity, then icons locked, then shown / hidden at the right end
  f.check = MenuBox(f, function(on) ns:SetHidden(not on) end)
  f.check:SetPoint("BOTTOMRIGHT", 3, 1)
  f.lock = MenuBox(f, function(on) ns:SetIconsLocked(on) end)
  f.lock:SetPoint("RIGHT", f.check, "LEFT", 0, 0)
  local slider = CreateFrame("Frame", nil, f, "MinimalSliderWithSteppersTemplate")
  slider:SetPoint("LEFT", f, "BOTTOMLEFT", 0, 12) -- (level with the boxes' middle)
  slider:SetPoint("RIGHT", f.lock, "LEFT", 0, 0)
  slider:SetHeight(24) -- the template's 40 would reach over the entry below
  if slider.Slider then -- the arrows closer in, for a longer track
    slider.Slider:ClearAllPoints()
    slider.Slider:SetPoint("TOPLEFT", 13, 0)
    slider.Slider:SetPoint("BOTTOMRIGHT", -13, 0)
  end
  slider:Init(100, 0, 100, 20) -- 5 % a step
  slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    if f.filling then return end
    ns:SetAlpha(value / 100)
    f.value:SetText(("%d %%"):format(math.floor(value + .5)))
  end, f)
  f.slider = slider
  menuLine = f
  return f
end

local function FillMenuLine(f)
  f.filling = true
  f.label:SetText(L.MENU_OPACITY)
  local percent = math.floor(ns.db.alpha * 100 + .5)
  f.slider:SetValue(percent)
  f.value:SetText(("%d %%"):format(percent))
  f.check:SetChecked(ns:ShownByChoice())
  f.check.tipTitle = L.MENU_SHOW_TIP
  f.lock:SetChecked(ns.db.iconsLocked)
  f.lock.tipTitle, f.lock.tipText = L.MENU_LOCK_TIP, L.MENU_LOCK_TEXT
  f.filling = nil
end

-- The line shows what was changed elsewhere meanwhile (slash command, options).
function ns:RefreshMenuLine()
  if menuLine and menuLine:IsVisible() then FillMenuLine(menuLine) end
end

local function MenuLineDescription()
  local description = MenuUtil.CreateFrame()
  description:AddInitializer(function(frame)
    local f = MenuLine()
    f:SetParent(frame)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    f:SetFrameLevel(frame:GetFrameLevel() + 2)
    FillMenuLine(f)
    f:Show()
    return MENU_LINE_W, MENU_LINE_H
  end)
  description:AddResetter(function(frame)
    if not menuLine or menuLine:GetParent() ~= frame then return end -- already lent again
    menuLine:Hide()
    menuLine:ClearAllPoints()
    menuLine:SetParent(UIParent)
  end)
  return description
end

-- The game's own damage meter (12.x clients): shown or hidden by its setting.
local METER_CVAR = "damageMeterEnabled"
local function MeterSetting()
  local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
  if not Get then return end
  local ok, value = pcall(Get, METER_CVAR)
  if ok then return value end
end
function ns:DamageMeterShown() return MeterSetting() == "1" end
function ns:SetDamageMeterShown(on)
  local Set = (C_CVar and C_CVar.SetCVar) or SetCVar
  if Set then pcall(Set, METER_CVAR, on and "1" or "0") end
end

-- What this addon puts in the portrait's menu, each part turned off in the game's options
-- (Esc > Options > AddOns): "Reload UI" just above Edit Mode, and its own section just above the
-- game's "Other Options" (which stays last, Leave Party at the very bottom; no such part: at the
-- end).
local function AddMenuEntries(_, root)
  if ns.TipResetInstances then ns.TipResetInstances(root) end -- (its tooltip: the instances entered, Layers.lua)
  local menu = ns.sv and ns.sv.menu or {}
  if menu.reload ~= false then
    local editModeIndex
    for index, description in root:EnumerateElementDescriptions() do
      if HUD_EDIT_MODE_MENU and MenuUtil.GetElementText(description) == HUD_EDIT_MODE_MENU then
        editModeIndex = index
        break
      end
    end
    if editModeIndex then
      root:Insert(MenuUtil.CreateButton(L.RELOAD_UI, ReloadInterface), editModeIndex)
    else -- no Edit Mode entry: at the end
      root:CreateButton(L.RELOAD_UI, ReloadInterface)
    end
  end
  -- the section: the classes the HUD is for, in clients with the game's slider
  if menu.line ~= false and ns.enabled and ns.db and MinimalSliderWithSteppersMixin and MenuUtil.CreateFrame
    and MenuUtil.CreateDivider and MenuUtil.CreateTitle and MenuUtil.CreateCheckbox then
    local section = { MenuUtil.CreateDivider(), MenuUtil.CreateTitle("Clara Combo Points"), MenuLineDescription() }
    -- the rest, used now and then, under More...: its own menu
    local more = MenuUtil.CreateButton(L.MENU_MORE)
    if MeterSetting() ~= nil then -- the game's damage meter
      more:CreateCheckbox(L.MENU_DAMAGE_METER, function() return ns:DamageMeterShown() end,
        function() ns:SetDamageMeterShown(not ns:DamageMeterShown()) end)
    end
    if ns.CameraAvailable and ns:CameraAvailable() then -- DynamicCam's camera (built in or standalone)
      more:CreateCheckbox(L.MENU_CAMERA, function() return ns:CameraOn() end,
        function() ns:SetCameraOn(not ns:CameraOn()) end)
    end
    if ns.FishingModeOffered and ns:FishingModeOffered() then -- (FishingMode.lua)
      local fishing = more:CreateCheckbox(L.MENU_FISHING_MODE, function() return ns:FishingMode() end,
        function() ns:SetFishingMode(not ns:FishingMode()) end)
      if fishing.SetTooltip then
        fishing:SetTooltip(function(tooltip)
          GameTooltip_SetTitle(tooltip, L.MENU_FISHING_MODE)
          GameTooltip_AddNormalLine(tooltip, L.FISHING_MODE_TIP:format(ns:FishingBoost()))
        end)
      end
    end
    more:CreateButton(L.MENU_OPTIONS, function() ns:OpenOptions() end)
    section[#section + 1] = more
    local at, previous
    local other = UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_OTHER
    for index, description in root:EnumerateElementDescriptions() do
      if other and MenuUtil.GetElementText(description) == other then
        at = previous and MenuUtil.GetElementText(previous) == nil and index - 1 or index -- (its divider first)
        break
      end
      previous = description
    end
    for i, description in ipairs(section) do
      if at then root:Insert(description, at + i - 1) else root:Insert(description) end
    end
  end
end

if Menu and Menu.ModifyMenu and MenuUtil then
  Menu.ModifyMenu("MENU_UNIT_SELF", AddMenuEntries)
end

---------------------------------------------------------------------------
-- Slash commands: /clara, /cl, /ccp, /cp
---------------------------------------------------------------------------
-- /rl: the interface reloaded (as /reload).
SLASH_CLARARELOAD1 = "/rl"
SlashCmdList.CLARARELOAD = function()
  if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
end

-- /cl lock, unlock, hide, show, scale and reset pos act without a word in the chat (what they do
-- shows); only help and debug write there, asked for, and scan and hunt (a name added or set).
SLASH_CLARACOMBOPOINTS1 = "/clara"
SLASH_CLARACOMBOPOINTS2 = "/cl"
SLASH_CLARACOMBOPOINTS3 = "/ccp"
SLASH_CLARACOMBOPOINTS4 = "/cp"
SlashCmdList.CLARACOMBOPOINTS = function(msg)
  if not ns.db then return end
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  local raw = (msg or ""):match("^%s*%S*%s*(.-)%s*$") or "" -- (a name, as typed)
  if cmd == "lock" then
    ns:SetIconsLocked(true)
    ns:SetLocked(true)
  elseif cmd == "unlock" then
    ns:SetLocked(false)
  elseif cmd == "hide" or cmd == "show" then
    ns:SetHidden(cmd == "hide")
  elseif cmd == "scale" and tonumber(arg) then
    ns:SetScalePercent(arg)
  elseif cmd == "reset" and (arg == "pos" or arg == "position") then
    ns:ResetWindowPosition()
  elseif cmd == "reset" then
    ns:AskResetAddon()
  elseif cmd == "scan" and raw ~= "" then
    Print((ns:ToggleScanName(raw) and L.SCAN_ADDED or L.SCAN_REMOVED):format(raw))
  elseif cmd == "scan" then
    ns:OpenScanPage()
  elseif cmd == "hunt" then
    ns:SetScanHunt(raw)
    Print(raw ~= "" and L.SCAN_HUNT_SET:format(raw) or L.SCAN_HUNT_CLEARED)
  elseif cmd == "sync" and ns.Sync and ns.Sync.db then
    local s = ns.Sync.Status()
    Print(L.SYNC_STATUS:format(s.online, s.trusted, s.channel and L.SYNC_CHANNEL_YES or L.SYNC_CHANNEL_NO))
  elseif cmd == "help" then
    Print(L.HELP)
  elseif cmd == "debug" then
    for _, line in ipairs(ns:DebugIcons()) do Print(line) end
    for _, line in ipairs(ns.DebugClicks and ns:DebugClicks() or {}) do Print(line) end
  else
    ns:ToggleOptions()
  end
end
