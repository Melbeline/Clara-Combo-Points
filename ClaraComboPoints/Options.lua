-- Clara Combo Points - options window (/clara or /cl)
-- Built from plain widgets only, so it does not depend on Blizzard templates that may
-- differ between client builds. Colours use Blizzard's own colour picker.

local _, ns = ...

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local PANEL_W, PANEL_H = 720, 600
local LEFT, RIGHT, COL_W = 20, 380, 320
local FONT_ROW_H = 22
local GOLD_R, GOLD_G, GOLD_B = 1, .82, 0

local COLOR_ROWS = {
  { key = "cp1",    label = "Point de combo 1" },
  { key = "cp2",    label = "Point de combo 2" },
  { key = "cp3",    label = "Point de combo 3" },
  { key = "cp4",    label = "Point de combo 4" },
  { key = "cp5",    label = "Point de combo 5" },
  { key = "energy", label = "Barre d'énergie" },
  { key = "bg",     label = "Fond (cases vides)" },
  { key = "text",   label = "Texte d'énergie" },
}
local SCALE_PRESETS = { 50, 75, 100, 125, 150, 200, 300 }
local OUTLINES = { { "NONE", "Aucun" }, { "OUTLINE", "Fin" }, { "THICKOUTLINE", "Épais" } }

local panel

local function ClickSound()
  if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function AddBorder(frame, r, g, b, a)
  local lines = {}
  for i = 1, 4 do
    lines[i] = frame:CreateTexture(nil, "BORDER")
    lines[i]:SetColorTexture(r, g, b, a)
  end
  lines[1]:SetPoint("TOPLEFT");    lines[1]:SetPoint("TOPRIGHT");    lines[1]:SetHeight(1)
  lines[2]:SetPoint("BOTTOMLEFT"); lines[2]:SetPoint("BOTTOMRIGHT"); lines[2]:SetHeight(1)
  lines[3]:SetPoint("TOPLEFT");    lines[3]:SetPoint("BOTTOMLEFT");  lines[3]:SetWidth(1)
  lines[4]:SetPoint("TOPRIGHT");   lines[4]:SetPoint("BOTTOMRIGHT"); lines[4]:SetWidth(1)
  frame.borderLines = lines
end

local function SetBorderColor(frame, r, g, b, a)
  for _, line in ipairs(frame.borderLines) do line:SetColorTexture(r, g, b, a) end
end

local function Text(parent, s, fontObject)
  local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
  fs:SetJustifyH("LEFT")
  fs:SetText(s)
  return fs
end

local function Section(parent, s, x, y)
  local fs = Text(parent, s, "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .25)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  line:SetWidth(max(10, COL_W - fs:GetStringWidth() - 8))
  return fs
end

local function Button(parent, label, w, h, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h or 22)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  AddBorder(b, .32, .32, .38, 1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .08)
  b.text = Text(b, label)
  b.text:SetPoint("CENTER")
  b:SetScript("OnClick", function(self) ClickSound(); onClick(self) end)
  function b:SetActive(on)
    if on then
      self.bg:SetColorTexture(.36, .27, .02, 1)
      SetBorderColor(self, GOLD_R, GOLD_G, GOLD_B, 1)
    else
      self.bg:SetColorTexture(.14, .14, .17, 1)
      SetBorderColor(self, .32, .32, .38, 1)
    end
  end
  b:SetActive(false)
  return b
end

local function Slider(parent, w, minV, maxV, step, fmt, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(w, 14)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  s:EnableMouseWheel(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(.22, .22, .26, 1)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  s:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
  local thumb = s:GetThumbTexture()
  thumb:SetSize(8, 14)
  thumb:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 1)
  s.value = Text(s, "")
  s.value:SetPoint("LEFT", s, "RIGHT", 8, 0)
  s:SetScript("OnValueChanged", function(self, v)
    v = floor(v / step + .5) * step
    self.value:SetText(fmt(v))
    if not self.silent then onChange(v) end
  end)
  s:SetScript("OnMouseWheel", function(self, delta)
    self:SetValue(min(maxV, max(minV, self:GetValue() + delta * step)))
  end)
  function s:Set(v)
    self.silent = true
    self:SetValue(v)
    self.silent = false
    self.value:SetText(fmt(v))
  end
  return s
end

local function Check(parent, label, onToggle)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(14, 14)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(.1, .1, .12, 1)
  AddBorder(b, .45, .45, .5, 1)
  b.mark = b:CreateTexture(nil, "ARTWORK")
  b.mark:SetPoint("TOPLEFT", 3, -3)
  b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
  b.mark:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 1)
  b.text = Text(b, label)
  b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
  b:SetHitRectInsets(0, -(b.text:GetStringWidth() + 6), 0, 0)
  function b:Set(on)
    self.checked = on and true or false
    self.mark:SetShown(self.checked)
  end
  b:SetScript("OnClick", function(self)
    ClickSound()
    self:Set(not self.checked)
    onToggle(self.checked)
  end)
  return b
end

local function NumberBox(parent, w, onEnter)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(w, 22)
  e:SetAutoFocus(false)
  e:SetNumeric(true)
  e:SetMaxLetters(3)
  e:SetFontObject("GameFontHighlight")
  e:SetJustifyH("CENTER")
  e:SetTextInsets(4, 4, 0, 0)
  local bg = e:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, .5)
  AddBorder(e, .45, .45, .5, 1)
  e:SetScript("OnEnterPressed", function(self) onEnter(self:GetText()); self:ClearFocus() end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Refresh() end)
  return e
end

---------------------------------------------------------------------------
-- Colour picker (Blizzard's: hue wheel, brightness bar, opacity slider)
---------------------------------------------------------------------------
local function OpenColorPicker(key)
  local c = ns.db.colors[key]
  local prev = { r = c.r, g = c.g, b = c.b, a = c.a }
  local function changed()
    ns:ApplyColors()
    panel:Refresh()
  end
  local function apply()
    -- the picker fires this once while being set up, before it holds this colour's opacity
    if not ColorPickerFrame:IsShown() then return end
    c.r, c.g, c.b = ColorPickerFrame:GetColorRGB()
    if ColorPickerFrame.GetColorAlpha then c.a = ColorPickerFrame:GetColorAlpha() end
    changed()
  end
  local function cancel()
    c.r, c.g, c.b, c.a = prev.r, prev.g, prev.b, prev.a
    changed()
  end
  ColorPickerFrame:SetupColorPickerAndShow({
    r = c.r, g = c.g, b = c.b, opacity = c.a, hasOpacity = true,
    swatchFunc = apply, opacityFunc = apply, cancelFunc = cancel,
  })
end

local function ColorRow(parent, row, y)
  local label = Text(parent, row.label)
  label:SetPoint("TOPLEFT", LEFT, y)

  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(34, 16)
  swatch:SetPoint("TOPLEFT", LEFT + 122, y + 2)
  local checker = swatch:CreateTexture(nil, "BACKGROUND")
  checker:SetPoint("TOPLEFT")
  checker:SetPoint("BOTTOMRIGHT", swatch, "BOTTOM")
  checker:SetColorTexture(.85, .85, .85, 1)
  local checker2 = swatch:CreateTexture(nil, "BACKGROUND")
  checker2:SetPoint("TOPLEFT", swatch, "TOP")
  checker2:SetPoint("BOTTOMRIGHT")
  checker2:SetColorTexture(.25, .25, .25, 1)
  swatch.color = swatch:CreateTexture(nil, "ARTWORK")
  swatch.color:SetAllPoints()
  AddBorder(swatch, .6, .6, .65, 1)
  swatch:SetScript("OnClick", function() ClickSound(); OpenColorPicker(row.key) end)

  local slider = Slider(parent, 100, 0, 100, 1, function(v) return v .. " %" end, function(v)
    ns.db.colors[row.key].a = v / 100
    ns:ApplyColors()
    local c = ns.db.colors[row.key]
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
  end)
  slider:SetPoint("TOPLEFT", LEFT + 168, y + 1)

  return function()
    local c = ns.db.colors[row.key]
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
    slider:Set(floor(c.a * 100 + .5))
  end
end

---------------------------------------------------------------------------
-- Font list: every font name is drawn in its own font
---------------------------------------------------------------------------
local function FontList(parent, x, y, w, h)
  local box = CreateFrame("Frame", nil, parent)
  box:SetPoint("TOPLEFT", x, y)
  box:SetSize(w, h)
  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, .35)
  AddBorder(box, .3, .3, .35, 1)

  local scroll = CreateFrame("ScrollFrame", nil, box)
  scroll:SetPoint("TOPLEFT", 1, -1)
  scroll:SetPoint("BOTTOMRIGHT", -1, 1)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(w - 2, h - 2)
  scroll:SetScrollChild(child)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(min(maxScroll, max(0, self:GetVerticalScroll() - delta * FONT_ROW_H * 2)))
  end)

  local hint = Text(parent, "molette : plus de polices")
  hint:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -3)
  hint:SetTextColor(.6, .6, .65)

  local rows = {}
  local colW = (w - 2 - 12) / 2
  return function()
    local fonts = ns:GetFonts()
    for i, f in ipairs(fonts) do
      local row = rows[i]
      if not row then
        row = CreateFrame("Button", nil, child)
        row:SetSize(colW, FONT_ROW_H - 2)
        row:SetPoint("TOPLEFT", 4 + ((i - 1) % 2) * (colW + 4), -4 - floor((i - 1) / 2) * FONT_ROW_H)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, .08)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetPoint("LEFT", 6, 0)
        row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
          ClickSound()
          ns.db.font = self.fontName
          ns:ApplyFont()
          panel:Refresh()
        end)
        rows[i] = row
      end
      if row.fontName ~= f.name then
        row.fontName = f.name
        local ok = row.text:SetFont(f.path, 13, "")
        if ok == false or not row.text:GetFont() then row.text:SetFontObject("GameFontHighlightSmall") end
        row.text:SetText(f.name)
      end
      local selected = (f.name == ns.db.font)
      row.bg:SetColorTexture(selected and .36 or 0, selected and .27 or 0, selected and .02 or 0, selected and 1 or 0)
      row.text:SetTextColor(selected and GOLD_R or 1, selected and GOLD_G or 1, selected and GOLD_B or 1)
    end
    child:SetHeight(max(h - 2, 8 + ceil(#fonts / 2) * FONT_ROW_H))
    hint:SetShown(child:GetHeight() > h - 2)
  end
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function Build()
  panel = CreateFrame("Frame", "ClaraComboPointsOptions", UIParent)
  panel:SetSize(PANEL_W, PANEL_H)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("HIGH") -- under the colour picker
  panel:SetToplevel(true)
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:Hide()
  tinsert(UISpecialFrames, "ClaraComboPointsOptions") -- Esc closes it

  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(.06, .06, .08, .98)
  AddBorder(panel, GOLD_R, GOLD_G, GOLD_B, .45)

  local title = Text(panel, "Clara Combo Points", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", LEFT, -16)
  local version = Text(panel, "v" .. ns.VERSION)
  version:SetPoint("LEFT", title, "RIGHT", 8, -1)
  version:SetTextColor(.6, .6, .65)

  local close = Button(panel, "X", 22, 22, function() panel:Hide() end)
  close:SetPoint("TOPRIGHT", -12, -12)

  local refreshers = {}
  local function OnRefresh(fn) refreshers[#refreshers + 1] = fn end

  -- Position --------------------------------------------------------------
  Section(panel, "POSITION", LEFT, -56)
  local lockBtn = Button(panel, "", 150, 22, function() ns:SetLocked(not ns.db.locked) end)
  lockBtn:SetPoint("TOPLEFT", LEFT, -80)
  local centerBtn = Button(panel, "Position par défaut", 150, 22, function() ns:ResetPosition() end)
  centerBtn:SetPoint("TOPLEFT", LEFT + 160, -80)
  OnRefresh(function()
    lockBtn.text:SetText(ns.db.locked and "Déverrouiller" or "Verrouiller")
    lockBtn:SetActive(not ns.db.locked)
  end)

  -- Scale -------------------------------------------------------------------
  Section(panel, "ÉCHELLE", LEFT, -118)
  local presetButtons = {}
  for i, p in ipairs(SCALE_PRESETS) do
    local b = Button(panel, p .. "%", 40, 22, function() ns:SetScalePercent(p) end)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 44, -142)
    b.percent = p
    presetButtons[i] = b
  end
  local scaleBox = NumberBox(panel, 50, function(text) ns:SetScalePercent(text) end)
  scaleBox:SetPoint("TOPLEFT", LEFT, -172)
  local pct = Text(panel, "%")
  pct:SetPoint("LEFT", scaleBox, "RIGHT", 4, 0)
  local applyScale = Button(panel, "Appliquer", 80, 22, function() ns:SetScalePercent(scaleBox:GetText()); scaleBox:ClearFocus() end)
  applyScale:SetPoint("TOPLEFT", LEFT + 72, -172)
  local scaleHint = Text(panel, "de " .. ns.MIN_SCALE .. " à " .. ns.MAX_SCALE .. " %, 100 % par défaut")
  scaleHint:SetPoint("LEFT", applyScale, "RIGHT", 10, 0)
  scaleHint:SetTextColor(.6, .6, .65)
  OnRefresh(function()
    local current = ns:GetScalePercent()
    for _, b in ipairs(presetButtons) do b:SetActive(b.percent == current) end
    if not scaleBox:HasFocus() then scaleBox:SetText(tostring(current)) end
  end)

  -- Global opacity ----------------------------------------------------------
  Section(panel, "OPACITÉ GLOBALE", LEFT, -212)
  local alphaSlider = Slider(panel, 250, 0, 100, 1, function(v) return v .. " %" end, function(v)
    ns.db.alpha = v / 100
    ns:ApplyAlpha()
  end)
  alphaSlider:SetPoint("TOPLEFT", LEFT, -238)
  OnRefresh(function() alphaSlider:Set(floor(ns.db.alpha * 100 + .5)) end)

  -- Colours -----------------------------------------------------------------
  Section(panel, "COULEURS ET OPACITÉ", LEFT, -272)
  local colorHint = Text(panel, "clic sur la couleur : roue, luminosité et opacité")
  colorHint:SetPoint("TOPLEFT", LEFT, -292)
  colorHint:SetTextColor(.6, .6, .65)
  for i, row in ipairs(COLOR_ROWS) do
    OnRefresh(ColorRow(panel, row, -314 - (i - 1) * 28))
  end
  local resetColors = Button(panel, "Couleurs par défaut", 150, 22, function() ns:ResetColors() end)
  resetColors:SetPoint("TOPLEFT", LEFT, -540)

  -- Font --------------------------------------------------------------------
  Section(panel, "POLICE", RIGHT, -56)
  OnRefresh(FontList(panel, RIGHT, -80, COL_W, 230))

  local sizeLabel = Text(panel, "Taille")
  sizeLabel:SetPoint("TOPLEFT", RIGHT, -332)
  local sizeSlider = Slider(panel, 200, 6, 40, 1, tostring, function(v)
    ns.db.fontSize = v
    ns:ApplyFont()
  end)
  sizeSlider:SetPoint("TOPLEFT", RIGHT + 70, -332)
  OnRefresh(function() sizeSlider:Set(ns.db.fontSize) end)

  local outlineLabel = Text(panel, "Contour")
  outlineLabel:SetPoint("TOPLEFT", RIGHT, -362)
  local outlineButtons = {}
  for i, o in ipairs(OUTLINES) do
    local b = Button(panel, o[2], 70, 22, function()
      ns.db.outline = o[1]
      ns:ApplyFont()
      panel:Refresh()
    end)
    b:SetPoint("TOPLEFT", RIGHT + 70 + (i - 1) * 76, -356)
    b.value = o[1]
    outlineButtons[i] = b
  end
  OnRefresh(function()
    for _, b in ipairs(outlineButtons) do b:SetActive(b.value == ns.db.outline) end
  end)

  local showText = Check(panel, "Afficher le nombre d'énergie", function(on)
    ns.db.showText = on
    ns:ApplyFont()
  end)
  showText:SetPoint("TOPLEFT", RIGHT, -392)
  OnRefresh(function() showText:Set(ns.db.showText) end)

  -- Advanced ----------------------------------------------------------------
  Section(panel, "AVANCÉ", RIGHT, -428)
  local sourceLabel = Text(panel, "Points lus sur")
  sourceLabel:SetPoint("TOPLEFT", RIGHT, -458)
  local srcTarget = Button(panel, "la cible (conseillé)", 120, 22, function() ns:SetComboSource("TARGET") end)
  srcTarget:SetPoint("TOPLEFT", RIGHT + 90, -452)
  local srcPlayer = Button(panel, "le joueur", 90, 22, function() ns:SetComboSource("PLAYER") end)
  srcPlayer:SetPoint("TOPLEFT", RIGHT + 216, -452)
  OnRefresh(function()
    srcTarget:SetActive(ns.db.cpSource == "TARGET")
    srcPlayer:SetActive(ns.db.cpSource == "PLAYER")
  end)

  local previewBtn = Button(panel, "Aperçu : 5 points", 150, 22, function() ns:SetPreview(not ns.preview) end)
  previewBtn:SetPoint("TOPLEFT", RIGHT, -488)
  local previewHint = Text(panel, "se coupe en combat")
  previewHint:SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)
  previewHint:SetTextColor(.6, .6, .65)
  OnRefresh(function() previewBtn:SetActive(ns.preview) end)

  local resetAll
  resetAll = Button(panel, "Tout réinitialiser", 150, 22, function()
    if resetAll.armed then
      resetAll.armed = nil
      ns:ResetAll()
    else
      resetAll.armed = true
      resetAll.text:SetText("Confirmer ?")
      C_Timer.After(3, function()
        resetAll.armed = nil
        resetAll.text:SetText("Tout réinitialiser")
      end)
    end
  end)
  resetAll:SetPoint("TOPLEFT", RIGHT, -540)

  local footer = Text(panel, "/cl lock  ·  /cl unlock  ·  /cl scale 120  ·  /cl reset")
  footer:SetPoint("BOTTOMLEFT", LEFT, 14)
  footer:SetTextColor(.6, .6, .65)
  if not ns.isRogue then
    local warn = Text(panel, "La barre ne s'affiche que sur un voleur.")
    warn:SetPoint("BOTTOMRIGHT", -20, 14)
    warn:SetTextColor(1, .4, .3)
  end

  function panel:Refresh()
    for _, fn in ipairs(refreshers) do fn() end
  end

  -- Opening the options shows all five points so colour changes are visible straight away.
  panel:SetScript("OnShow", function(self)
    if InCombatLockdown() then self:Refresh() else ns:SetPreview(true) end
  end)
  panel:SetScript("OnHide", function()
    if ns.preview then ns:SetPreview(false) end
  end)
end

function ns:RefreshOptions()
  if panel and panel:IsShown() then panel:Refresh() end
end

function ns:ToggleOptions()
  if not panel then Build() end
  panel:SetShown(not panel:IsShown())
end
