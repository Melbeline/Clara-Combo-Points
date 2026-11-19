-- Clara Combo Points - Water Shield Tracker (Melbeline's WaterShieldTracker 1.0.1), built in (QoL.lua): Water
-- Shield's charges (the shaman rune, spell 409941) on the spell's icon; no Water Shield: the icon red, flashing, and
-- "Refresh!" above it; a click on it recasts it; unlocked, it is dragged to move it and its corner's grip resizes it.
-- Only on a shaman, unless shown on every class (nothing of it made otherwise). Its page under its theme's page
-- (/ws opens it; /ws lock, /ws unlock, /ws reset), its two main boxes on its card. Saved in ClaraWaterShieldDB, for
-- the account. Its own addon enabled: that one runs for the session, its settings carried over at logout if this
-- one has none yet, then it is turned off for the character.
-- Its click-to-cast button is a secure button: the icon's frame holding it is protected too, and in combat the game
-- refuses to show, hide, move or size it. Nothing of that is asked in combat: shown or hidden only when that
-- changes, and what changes in a fight (shown or hidden, size, scale, place) is done once it is over.

local ADDON, ns = ...
local L = ns.L

local SPELL_ID = 409941
local FALLBACK_ICON = 132315 -- (Water Shield's icon)

local defaults = {
  show = true,
  locked = false,
  size = 48,
  scale = 1,
  fontSize = 20,
  textColor = { r = 1, g = 1, b = 1 },
  redMissing = true,
  flash = true,
  reminder = true,
  textAnchor = "CENTER", -- CENTER, TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT
  clickCast = true,
  allClasses = false,
  point = "CENTER", x = 0, y = -120,
}

local function CopyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

-- Its settings, made with their defaults when first changed (read: the defaults until then)
local function DB()
  if type(ClaraWaterShieldDB) ~= "table" then ClaraWaterShieldDB = {} end
  return CopyDefaults(defaults, ClaraWaterShieldDB)
end
local function Get(key)
  local d = ClaraWaterShieldDB
  local v = type(d) == "table" and d[key]
  if v == nil then return defaults[key] end
  return v
end

-- The standalone runs this session (the built-in one from the next reload): its settings taken at logout, if
-- the built-in one has none yet
if ns:QolState("watershield") == "standalone" then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    if type(WaterShieldTrackerDB) ~= "table" or type(ClaraWaterShieldDB) == "table" then return end
    local copy = {}
    for k, v in pairs(WaterShieldTrackerDB) do
      if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
        copy[k] = v
      elseif k == "textColor" and type(v) == "table" then
        copy.textColor = { r = tonumber(v.r) or 1, g = tonumber(v.g) or 1, b = tonumber(v.b) or 1 }
      end
    end
    ClaraWaterShieldDB = CopyDefaults(defaults, copy)
  end)
end

local apply = { lock = function() end, secure = function() end, refresh = function() end } -- (once made)

ns:SetQolSwitches("watershield", {
  { label = "WSH_SW_LOCK", get = function() return Get("locked") == true end,
    set = function(on) DB().locked = on and true or false; apply.lock() end },
  { label = "WSH_SW_CLICK", get = function() return Get("clickCast") == true end,
    set = function(on) DB().clickCast = on and true or false; apply.secure() end },
})
ns:SetQolOpener("watershield", function() ns:OpenSettingsTo(ns.waterShieldCategory) end)

if not ns:QolRuns("watershield") then return end

local db = DB()
local IS_SHAMAN = select(2, UnitClass("player")) == "SHAMAN"
local function Wanted() return db.show and (IS_SHAMAN or db.allClasses) end

---------------------------------------------------------------------------
-- The spell, and the aura
---------------------------------------------------------------------------
local function SpellData()
  local name, icon
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(SPELL_ID)
    if info then name, icon = info.name, info.iconID end
  elseif GetSpellInfo then
    local n, _, i = GetSpellInfo(SPELL_ID)
    name, icon = n, i
  end
  return name, icon or FALLBACK_ICON
end
local spellName, spellIcon = SpellData()

local issecret = issecretvalue or function() return false end

-- Is it on, and its charges
local function ScanAura()
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
      if not data then break end
      local id, name = data.spellId, data.name
      if not issecret(id) and not issecret(name) and (id == SPELL_ID or (spellName and name == spellName)) then
        local c = data.applications
        if issecret(c) then return true, 1 end
        return true, (c and c > 0) and c or 1
      end
    end
  elseif UnitBuff then
    for i = 1, 40 do
      local name, _, count, _, _, _, _, _, _, id = UnitBuff("player", i)
      if not name then break end
      if id == SPELL_ID or (spellName and name == spellName) then
        return true, (count and count > 0) and count or 1
      end
    end
  end
  return false, 0
end

local ANCHOR_OFFSETS = {
  CENTER = { 0, 0 }, TOPLEFT = { 3, -3 }, TOPRIGHT = { -3, -3 }, BOTTOMLEFT = { 3, 3 }, BOTTOMRIGHT = { -3, 3 },
}

---------------------------------------------------------------------------
-- The icon: made when it is to show (a shaman, or every class), out of combat
---------------------------------------------------------------------------
local frame, icon, border, edge, moveOverlay, pulse, countText, reminderText, flashAnim, handle, castBtn
local pendingShown, pendingSize, pendingPosition, pendingSecure, pendingMake
ns.WaterShield = {} -- (for the tests: its frame once made)

local function Fade(target, from, to, duration, order)
  local a = target:CreateAnimation("Alpha")
  a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(duration)
  if order then a:SetOrder(order) end
end

-- Shown or hidden, only when that changes; in combat, once the fight is over
local function SetShownSafe(shown)
  if not frame then return end
  if frame:IsShown() == shown then pendingShown = nil return end
  if InCombatLockdown() then pendingShown = shown return end
  pendingShown = nil
  frame:SetShown(shown)
end

local function ApplySecure()
  if not castBtn then return end
  if InCombatLockdown() then pendingSecure = true return end
  pendingSecure = nil
  castBtn:EnableMouse((db.clickCast or not db.locked) and true or false)
  if db.clickCast and spellName then
    castBtn:SetAttribute("type1", "spell")
    castBtn:SetAttribute("spell", spellName)
  else
    castBtn:SetAttribute("type1", nil)
    castBtn:SetAttribute("spell", nil)
  end
end

local function ApplyLayout()
  if not frame then return end
  if InCombatLockdown() then
    pendingSize = true
  else
    pendingSize = nil
    frame:SetSize(db.size, db.size)
    frame:SetScale(db.scale)
  end
  local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  countText:SetFont(font, db.fontSize, "OUTLINE")
  reminderText:SetFont(font, math.max(10, math.floor(db.fontSize * 0.7)), "OUTLINE")
  local c = db.textColor
  countText:SetTextColor(c.r, c.g, c.b)
  local a = ANCHOR_OFFSETS[db.textAnchor] and db.textAnchor or "CENTER"
  local off = ANCHOR_OFFSETS[a]
  countText:ClearAllPoints()
  countText:SetPoint(a, frame, a, off[1], off[2])
end

local function ApplyPosition()
  if not frame then return end
  if InCombatLockdown() then pendingPosition = true return end
  pendingPosition = nil
  frame:ClearAllPoints()
  frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
end

local function ApplyLock()
  if not frame then return end
  if db.locked then
    handle:Hide(); edge:Hide(); moveOverlay:Hide()
    if pulse then pulse:Stop() end
    border:SetColorTexture(0, 0, 0, 0.8)
  else
    handle:Show(); edge:Show(); moveOverlay:Show()
    if pulse then pulse:Play() end
    border:SetColorTexture(0, 0, 0, 0.9)
  end
  ApplySecure()
end

local function Refresh()
  if not frame then return end
  if not Wanted() then
    if flashAnim then flashAnim:Stop() end
    frame:SetAlpha(1)
    SetShownSafe(false)
    return
  end
  SetShownSafe(true)
  icon:SetTexture(spellIcon)
  local present, count = ScanAura()
  countText:SetText(count)
  if db.redMissing and not present then
    icon:SetDesaturated(true)
    icon:SetVertexColor(1, 0.15, 0.15)
  else
    icon:SetDesaturated(false)
    icon:SetVertexColor(1, 1, 1)
  end
  if flashAnim then
    if db.flash and (count <= 0 or not present) then
      if not flashAnim:IsPlaying() then flashAnim:Play() end
    else
      flashAnim:Stop()
      frame:SetAlpha(1)
    end
  end
  if db.reminder and not present then
    reminderText:SetText(L.WSH_REMINDER_TEXT)
    reminderText:Show()
  else
    reminderText:Hide()
  end
end

local UpdateSizeSlider = function() end -- (its page's, once built)

local function Make()
  if frame then return end
  if InCombatLockdown() then pendingMake = true return end
  pendingMake = nil
  frame = CreateFrame("Frame", "ClaraWaterShieldFrame", UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:Hide()
  ns.WaterShield.frame = frame

  icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  border = frame:CreateTexture(nil, "BACKGROUND")
  border:SetPoint("TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", 2, -2)
  border:SetColorTexture(0, 0, 0, 0.8)

  -- Unlocked: a gold border, gently pulsing, and a light gold veil
  edge = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  edge:SetPoint("TOPLEFT", -6, 6)
  edge:SetPoint("BOTTOMRIGHT", 6, -6)
  edge:SetFrameLevel(frame:GetFrameLevel() + 3)
  if edge.SetBackdrop then
    edge:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
    edge:SetBackdropBorderColor(1, 0.82, 0.1, 1)
  end
  edge:Hide()
  moveOverlay = frame:CreateTexture(nil, "OVERLAY", nil, 1)
  moveOverlay:SetAllPoints()
  moveOverlay:SetColorTexture(1, 0.82, 0.1, 0.12)
  moveOverlay:Hide()
  if edge.CreateAnimationGroup then
    pulse = edge:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    Fade(pulse, 1, 0.45, 0.9)
  end

  countText = frame:CreateFontString(nil, "OVERLAY")
  countText:SetPoint("CENTER", frame, "CENTER", 0, 0)
  reminderText = frame:CreateFontString(nil, "OVERLAY")
  reminderText:SetPoint("BOTTOM", frame, "TOP", 0, 4)
  reminderText:SetTextColor(1, 0.2, 0.2)
  reminderText:Hide()
  if frame.CreateAnimationGroup then
    flashAnim = frame:CreateAnimationGroup()
    flashAnim:SetLooping("REPEAT")
    Fade(flashAnim, 1, 0.2, 0.4, 1)
    Fade(flashAnim, 0.2, 1, 0.4, 2)
  end

  -- The grip at the bottom right: resizes it
  handle = CreateFrame("Button", nil, frame)
  handle:SetSize(14, 14)
  handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
  handle:SetFrameLevel(frame:GetFrameLevel() + 5)
  handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  handle:Hide()
  handle:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    local s = frame:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local startX, startY, startSize = cx / s, cy / s, db.size
    self:SetScript("OnUpdate", function()
      local cx2, cy2 = GetCursorPosition()
      cx2, cy2 = cx2 / s, cy2 / s
      local delta = ((cx2 - startX) - (cy2 - startY)) / 2
      local newSize = math.floor(math.max(16, math.min(200, startSize + delta)) + 0.5)
      if newSize ~= db.size then
        db.size = newSize
        ApplyLayout()
        UpdateSizeSlider()
      end
    end)
  end)
  handle:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)

  -- The click recasts Water Shield (a secure button inside: the frame is protected from here on)
  castBtn = CreateFrame("Button", "ClaraWaterShieldCastButton", frame, "SecureActionButtonTemplate")
  castBtn:SetAllPoints(frame)
  castBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
  castBtn:RegisterForClicks("AnyUp")
  castBtn:RegisterForDrag("LeftButton")
  castBtn:EnableMouse(false)
  castBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.QOL_NAV_WATERSHIELD, 1, 0.82, 0.1)
    if db.clickCast then GameTooltip:AddLine(L.WSH_TIP_CLICK, 0.4, 1, 0.4) end
    if not db.locked then
      GameTooltip:AddLine(L.WSH_TIP_MOVE, 1, 1, 1)
      GameTooltip:AddLine(L.WSH_TIP_RESIZE, 1, 1, 1)
      GameTooltip:AddLine(L.WSH_TIP_LOCK, 0.6, 0.6, 0.6)
    elseif not db.clickCast then
      GameTooltip:Hide()
      return
    end
    GameTooltip:Show()
  end)
  castBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  castBtn:SetScript("OnDragStart", function()
    if not db.locked and not InCombatLockdown() then frame.moving = true; frame:StartMoving() end
  end)
  castBtn:SetScript("OnDragStop", function()
    if not frame.moving then return end
    frame.moving = nil
    frame:StopMovingOrSizing()
    local point, _, _, x, y = frame:GetPoint()
    db.point, db.x, db.y = point, x, y
  end)

  ApplyLayout()
  ApplyPosition()
  ApplyLock()
end

apply.lock = function() if frame then ApplyLock() end end
apply.secure = function() if frame then ApplySecure() end end
apply.refresh = function()
  if Wanted() then Make() end
  Refresh()
end

-- The fight over: what waited
local function ApplyPending()
  if pendingMake then apply.refresh() end
  if pendingSecure then ApplySecure() end
  if pendingSize then ApplyLayout() end
  if pendingPosition then ApplyPosition() end
  if pendingShown ~= nil then SetShownSafe(pendingShown) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_AURA" then
    if unit == "player" and frame then Refresh() end
    return
  end
  spellName, spellIcon = SpellData()
  if event == "PLAYER_REGEN_ENABLED" then
    ApplyPending()
  elseif frame then
    ApplySecure()
  end
  apply.refresh()
end)
apply.refresh()

---------------------------------------------------------------------------
-- Its page: under its theme's page in Clara's options
---------------------------------------------------------------------------
local page = CreateFrame("Frame")
page:Hide()
local built
local updates = {}
local parts = {}
ns.WaterShieldPage, ns.WaterShieldParts = page, parts -- (for the tests)

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end
local function Update() for _, fn in ipairs(updates) do fn() end end

local function Check(key, label, x, y, onChange)
  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetPoint("TOPLEFT", x, y)
  local text = check.Text or check.text
  if text then
    text:SetFontObject("GameFontHighlight")
    text:SetText(label)
  end
  check:SetScript("OnClick", function(self)
    Click()
    db[key] = self:GetChecked() and true or false
    if onChange then onChange() end
    apply.refresh()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)
  parts[key] = check
  updates[#updates + 1] = function() check:SetChecked(db[key] and true or false) end
end

local function Slider(key, label, x, y, low, high, step)
  local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOPLEFT", x + 2, y)
  text:SetText(label)
  local slider = CreateFrame("Frame", nil, page, "MinimalSliderWithSteppersTemplate")
  slider:SetPoint("TOPLEFT", x, y - 18)
  slider:SetSize(220, 24)
  local value = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  value:SetPoint("LEFT", slider, "RIGHT", 10, 0)
  local function Shown(v) return step < 1 and ("%.2f"):format(v) or tostring(v) end
  local filling = true -- (set up: nothing saved)
  slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
    v = math.floor(v / step + 0.5) * step
    if step < 1 then v = tonumber(("%.2f"):format(v)) end
    value:SetText(Shown(v))
    if filling then return end
    if db[key] ~= v then
      db[key] = v
      ApplyLayout()
    end
  end, page)
  slider:Init(db[key], low, high, math.floor((high - low) / step + 0.5))
  filling = false
  parts[key] = slider
  updates[#updates + 1] = function()
    filling = true
    slider:SetValue(db[key])
    value:SetText(Shown(db[key]))
    filling = false
  end
end

-- The text's color: its swatch (a click opens the game's color picker, Cancel puts the one before back)
local function Swatch(label, x, y)
  local button = CreateFrame("Button", nil, page)
  button:SetSize(22, 22)
  button:SetPoint("TOPLEFT", x, y)
  local back = button:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.8, 0.8, 0.8, 1)
  local fill = button:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", -2, 2)
  local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("LEFT", button, "RIGHT", 8, 0)
  text:SetText(label)
  parts.color = button
  local function Show()
    local c = db.textColor
    fill:SetColorTexture(c.r, c.g, c.b, 1)
  end
  updates[#updates + 1] = Show
  local function Put(r, g, b)
    db.textColor = { r = r, g = g, b = b }
    Show()
    ApplyLayout()
  end
  button:SetScript("OnClick", function()
    if not ColorPickerFrame then return end
    Click()
    local c = db.textColor
    local r0, g0, b0 = c.r, c.g, c.b
    local opening = true -- (the picker calls back while it is set up: ignored)
    ColorPickerFrame:SetupColorPickerAndShow({
      r = r0, g = g0, b = b0, hasOpacity = false,
      swatchFunc = function()
        if opening then return end
        Put(ColorPickerFrame:GetColorRGB())
      end,
      cancelFunc = function() Put(r0, g0, b0) end,
    })
    opening = false
  end)
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText(L.QOL_NAV_WATERSHIELD)
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -62)
  hint:SetPoint("RIGHT", -24, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.6, .6, .65)
  hint:SetText(L.WSH_HINT)

  Check("show", L.WSH_SHOW, 10, -96)
  Check("locked", L.WSH_LOCK, 10, -120, ApplyLock)
  Check("clickCast", L.WSH_CLICKCAST, 10, -144, ApplySecure)
  Check("allClasses", L.WSH_ALLCLASSES, 10, -168)
  Check("redMissing", L.WSH_REDMISSING, 10, -192)
  Check("flash", L.WSH_FLASH, 10, -216)
  Check("reminder", L.WSH_REMINDER, 10, -240)

  Slider("size", L.WSH_SIZE, 14, -276, 16, 200, 1)
  Slider("scale", L.WSH_SCALE, 14, -324, 0.5, 3, 0.05)
  Slider("fontSize", L.WSH_FONTSIZE, 14, -372, 8, 64, 1)
  UpdateSizeSlider = function() if page:IsShown() then Update() end end
  Swatch(L.WSH_TEXTCOLOR, 14, -424)

  -- Where the number sits on the icon
  local posLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  posLabel:SetPoint("TOPLEFT", 16, -458)
  posLabel:SetText(L.WSH_TEXTPOS)
  local radios = {}
  parts.radios = radios
  local anchors = {
    { "CENTER", L.WSH_P_CENTER, 14, -478 }, { "TOPLEFT", L.WSH_P_TL, 134, -478 }, { "TOPRIGHT", L.WSH_P_TR, 254, -478 },
    { "BOTTOMLEFT", L.WSH_P_BL, 14, -502 }, { "BOTTOMRIGHT", L.WSH_P_BR, 134, -502 },
  }
  for _, a in ipairs(anchors) do
    local key, label, x, y = a[1], a[2], a[3], a[4]
    local rb = CreateFrame("CheckButton", nil, page, "UIRadioButtonTemplate")
    rb:SetPoint("TOPLEFT", x, y)
    local t = rb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    t:SetPoint("LEFT", rb, "RIGHT", 2, 0)
    t:SetText(label)
    rb:SetScript("OnClick", function()
      Click()
      db.textAnchor = key
      Update()
      ApplyLayout()
    end)
    radios[key] = rb
  end
  updates[#updates + 1] = function()
    for key, rb in pairs(radios) do rb:SetChecked(key == (db.textAnchor or "CENTER")) end
  end

  local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  reset:SetSize(200, 22)
  reset:SetPoint("TOPLEFT", 14, -536)
  reset:SetText(L.WSH_RESET)
  parts.reset = reset
  reset:SetScript("OnClick", function()
    Click()
    db.point, db.x, db.y = defaults.point, defaults.x, defaults.y
    ApplyPosition()
  end)
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Update()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local ok, category = pcall(function()
    if ns:QolCategory("watershield") and Settings.RegisterCanvasLayoutSubcategory then
      return Settings.RegisterCanvasLayoutSubcategory(ns:QolCategory("watershield"), page, L.QOL_NAV_WATERSHIELD)
    end
    local c = Settings.RegisterCanvasLayoutCategory(page, L.QOL_NAV_WATERSHIELD)
    Settings.RegisterAddOnCategory(c)
    return c
  end)
  if ok and category then ns.waterShieldCategory = category end
end

---------------------------------------------------------------------------
-- /ws: its page; /ws lock, /ws unlock, /ws reset
---------------------------------------------------------------------------
SLASH_CLARAWATERSHIELD1 = "/ws"
SlashCmdList.CLARAWATERSHIELD = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  local say = function(text) print("|cff33ccffWS|r: " .. text) end
  if msg == "lock" then
    db.locked = true; ApplyLock(); say(L.WSH_LOCKED)
  elseif msg == "unlock" then
    db.locked = false; ApplyLock(); say(L.WSH_UNLOCKED)
  elseif msg == "reset" then
    db.point, db.x, db.y = defaults.point, defaults.x, defaults.y
    ApplyPosition()
  elseif msg == "help" or msg == "?" then
    say(L.WSH_HELP)
  else
    ns:OpenSettingsTo(ns.waterShieldCategory)
  end
end
