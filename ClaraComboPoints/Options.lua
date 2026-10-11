-- Clara Combo Points - options window (/clara or /cl)
-- One tab per class profile (Rogue, Druid), a language picker (flags) and two themes:
-- Classic, the WoW Classic 1.15 look (default), and Modern, flat and dark.
-- Built from plain widgets (BackdropTemplate only for the classic frames), so it does not
-- depend on Blizzard templates that may differ between client builds. Colours use
-- Blizzard's own colour picker.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local PANEL_W, PANEL_H = 720, 640
local CONTENT_TOP = -38 -- settings start under the title, tab and language row
local LEFT, RIGHT, COL_W = 20, 380, 320
local FONT_ROW_H = 22
local GOLD_R, GOLD_G, GOLD_B = 1, .82, 0
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FLAG_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Flags\\"

-- Classic 1.15 art (all still used by the current client)
local PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-"
local BACKDROP_DIALOG = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileEdge = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local BACKDROP_SLIDER = {
  bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
  edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
  tile = true, tileEdge = true, tileSize = 8, edgeSize = 8,
  insets = { left = 3, right = 3, top = 6, bottom = 6 },
}
local BACKDROP_BOX = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileEdge = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local CLASS_TABS = { { class = "ROGUE", key = "TAB_ROGUE" }, { class = "DRUID", key = "TAB_DRUID" } }
local COLOR_ROWS = { "cp1", "cp2", "cp3", "cp4", "cp5", "energy", "bg", "text" }
local COLOR_LABELS = { energy = "ENERGY_BAR", bg = "BACKGROUND", text = "ENERGY_TEXT" }
local SCALE_PRESETS = { 50, 75, 100, 125, 150, 200, 300 }
local OUTLINES = { { "NONE", "OUTLINE_NONE" }, { "OUTLINE", "OUTLINE_THIN" }, { "THICKOUTLINE", "OUTLINE_THICK" } }

local panel
local editing         -- class profile shown in the window
local skinned = {}    -- widgets with a :Skin() method
local relabels = {}   -- functions that set text in the current language

local function IsClassic() return ns.sv.skin == "CLASSIC" end
local function Tr(key) return function() return L[key] end end
local function Skinned(w) skinned[#skinned + 1] = w; return w end
local function OnRelabel(fn) relabels[#relabels + 1] = fn; fn() end

local function ClickSound()
  if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

---------------------------------------------------------------------------
-- Widgets: each draws itself in both themes
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

local function SetBorderShown(frame, shown)
  for _, line in ipairs(frame.borderLines) do line:SetShown(shown) end
end

-- Flat look for Modern, tooltip-style box for Classic (edit box, font list).
local function SkinBox(frame)
  frame.flat = frame:CreateTexture(nil, "BACKGROUND")
  frame.flat:SetAllPoints()
  frame.flat:SetColorTexture(0, 0, 0, .4)
  AddBorder(frame, .35, .35, .4, 1)
  Skinned(frame)
  function frame:Skin()
    local classic = IsClassic()
    self.flat:SetShown(not classic)
    SetBorderShown(self, not classic)
    if classic then
      self:SetBackdrop(BACKDROP_BOX)
      self:SetBackdropColor(0, 0, 0, .85)
      self:SetBackdropBorderColor(.65, .65, .65, 1)
    else
      self:SetBackdrop(nil)
    end
  end
end

-- s: plain string, or a function returning the text in the current language
local function Text(parent, s, fontObject)
  local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlightSmall")
  fs:SetJustifyH("LEFT")
  if type(s) == "function" then
    OnRelabel(function() fs:SetText(s()) end)
  else
    fs:SetText(s)
  end
  return fs
end

local function Hint(parent, s)
  local fs = Text(parent, s)
  fs:SetTextColor(.6, .6, .65)
  return fs
end

local function Section(parent, key, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .25)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  OnRelabel(function()
    fs:SetText(L[key])
    line:SetWidth(max(10, COL_W - fs:GetStringWidth() - 8))
  end)
end

-- Classic: red panel button (grey when it is an option that is not selected).
-- Modern: flat, gold when selected.
local function Button(parent, label, w, h, onClick, isToggle)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h or 22)
  b.isToggle = isToggle
  b.flat = b:CreateTexture(nil, "BACKGROUND")
  b.flat:SetAllPoints()
  AddBorder(b, .32, .32, .38, 1)
  b.left = b:CreateTexture(nil, "BACKGROUND")
  b.left:SetPoint("TOPLEFT")
  b.left:SetPoint("BOTTOMLEFT")
  b.left:SetWidth(12)
  b.right = b:CreateTexture(nil, "BACKGROUND")
  b.right:SetPoint("TOPRIGHT")
  b.right:SetPoint("BOTTOMRIGHT")
  b.right:SetWidth(12)
  b.middle = b:CreateTexture(nil, "BACKGROUND")
  b.middle:SetPoint("TOPLEFT", b.left, "TOPRIGHT")
  b.middle:SetPoint("BOTTOMRIGHT", b.right, "BOTTOMLEFT")
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.hl:SetAllPoints()
  b.text = Text(b, label)
  b.text:SetPoint("CENTER")
  b:SetScript("OnMouseDown", function(self) self.down = true; self:Skin() end)
  b:SetScript("OnMouseUp", function(self) self.down = false; self:Skin() end)
  b:SetScript("OnClick", function(self) ClickSound(); onClick(self) end)

  function b:SetActive(on)
    self.active = on and true or false
    self:Skin()
  end

  function b:Skin()
    local classic = IsClassic()
    self.flat:SetShown(not classic)
    SetBorderShown(self, not classic)
    self.left:SetShown(classic)
    self.middle:SetShown(classic)
    self.right:SetShown(classic)
    if classic then
      local state = (self.isToggle and not self.active) and "Disabled" or (self.down and "Down" or "Up")
      self.left:SetTexture(PANEL_BUTTON .. state)
      self.left:SetTexCoord(0, .09375, 0, .6875)
      self.middle:SetTexture(PANEL_BUTTON .. state)
      self.middle:SetTexCoord(.09375, .53125, 0, .6875)
      self.right:SetTexture(PANEL_BUTTON .. state)
      self.right:SetTexCoord(.53125, .625, 0, .6875)
      self.hl:SetTexture(PANEL_BUTTON .. "Highlight")
      self.hl:SetTexCoord(0, .625, 0, .6875)
      self.hl:SetBlendMode("ADD")
      if self.isToggle and self.active then
        self.text:SetTextColor(1, 1, 1)
      else
        self.text:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
      end
    else
      if self.active then
        self.flat:SetColorTexture(.36, .27, .02, 1)
        SetBorderColor(self, GOLD_R, GOLD_G, GOLD_B, 1)
      else
        self.flat:SetColorTexture(.14, .14, .17, 1)
        SetBorderColor(self, .32, .32, .38, 1)
      end
      self.hl:SetColorTexture(1, 1, 1, .08)
      self.hl:SetTexCoord(0, 1, 0, 1)
      self.hl:SetBlendMode("BLEND")
      self.text:SetTextColor(1, 1, 1)
    end
  end

  Skinned(b)
  return b
end

local function Slider(parent, w, minV, maxV, step, fmt, onChange)
  local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
  s:SetOrientation("HORIZONTAL")
  s:SetWidth(w)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:SetHitRectInsets(0, 0, -6, -6)
  s:EnableMouse(true)
  s:EnableMouseWheel(true)
  s.track = s:CreateTexture(nil, "BACKGROUND")
  s.track:SetColorTexture(.22, .22, .26, 1)
  s.track:SetPoint("LEFT")
  s.track:SetPoint("RIGHT")
  s.track:SetHeight(4)
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

  function s:Skin()
    local classic = IsClassic()
    self.track:SetShown(not classic)
    if classic then
      self:SetHeight(17)
      self:SetBackdrop(BACKDROP_SLIDER)
      self:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
      local thumb = self:GetThumbTexture()
      thumb:SetSize(32, 32)
      thumb:SetVertexColor(1, 1, 1, 1)
    else
      self:SetHeight(14)
      self:SetBackdrop(nil)
      self:SetThumbTexture(WHITE)
      local thumb = self:GetThumbTexture()
      thumb:SetSize(8, 14)
      thumb:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 1)
    end
  end

  Skinned(s)
  return s
end

local function Check(parent, label, onToggle)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(14, 14)
  b.flat = b:CreateTexture(nil, "BACKGROUND")
  b.flat:SetAllPoints()
  b.flat:SetColorTexture(.1, .1, .12, 1)
  AddBorder(b, .45, .45, .5, 1)
  b.mark = b:CreateTexture(nil, "ARTWORK")
  b.box = b:CreateTexture(nil, "BACKGROUND")
  b.box:SetPoint("CENTER")
  b.box:SetSize(24, 24)
  b.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
  b.hl = b:CreateTexture(nil, "HIGHLIGHT")
  b.text = Text(b, label)
  OnRelabel(function()
    b:SetHitRectInsets(-5, -(b.text:GetStringWidth() + 12), -5, -5)
  end)

  function b:Set(on)
    self.checked = on and true or false
    self.mark:SetShown(self.checked)
  end

  function b:Skin()
    local classic = IsClassic()
    self.flat:SetShown(not classic)
    SetBorderShown(self, not classic)
    self.box:SetShown(classic)
    self.mark:ClearAllPoints()
    self.hl:ClearAllPoints()
    self.text:ClearAllPoints()
    if classic then
      self.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
      self.mark:SetTexCoord(0, 1, 0, 1)
      self.mark:SetPoint("CENTER")
      self.mark:SetSize(24, 24)
      self.hl:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
      self.hl:SetBlendMode("ADD")
      self.hl:SetPoint("CENTER")
      self.hl:SetSize(24, 24)
      self.text:SetPoint("LEFT", self, "RIGHT", 10, 0)
    else
      self.mark:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 1)
      self.mark:SetPoint("TOPLEFT", 3, -3)
      self.mark:SetPoint("BOTTOMRIGHT", -3, 3)
      self.hl:SetColorTexture(1, 1, 1, .08)
      self.hl:SetBlendMode("BLEND")
      self.hl:SetAllPoints()
      self.text:SetPoint("LEFT", self, "RIGHT", 6, 0)
    end
  end

  b:SetScript("OnClick", function(self)
    ClickSound()
    self:Set(not self.checked)
    onToggle(self.checked)
  end)
  Skinned(b)
  return b
end

local function NumberBox(parent, w, onEnter)
  local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  e:SetSize(w, 22)
  e:SetAutoFocus(false)
  e:SetNumeric(true)
  e:SetMaxLetters(3)
  e:SetFontObject("GameFontHighlight")
  e:SetJustifyH("CENTER")
  e:SetTextInsets(6, 6, 0, 0)
  SkinBox(e)
  e:SetScript("OnEnterPressed", function(self) onEnter(self:GetText()); self:ClearFocus() end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Refresh() end)
  return e
end

-- Flags: France and Germany are drawn with stripes, the Union Jack is a texture.
local FLAG_STRIPES = {
  frFR = { vertical = true, { 0, .333, .643 }, { 1, 1, 1 }, { .937, .255, .208 } },
  deDE = { vertical = false, { 0, 0, 0 }, { .867, 0, 0 }, { 1, .808, 0 } },
}
local function Flag(parent, lang, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(26, 16)
  AddBorder(b, .35, .35, .4, 1)
  local art = CreateFrame("Frame", nil, b)
  art:SetPoint("TOPLEFT", 2, -2)
  art:SetPoint("BOTTOMRIGHT", -2, 2)
  local stripes = FLAG_STRIPES[lang.code]
  if stripes then
    local fw, fh = 22, 12
    for i = 1, 3 do
      local t = art:CreateTexture(nil, "ARTWORK")
      t:SetColorTexture(stripes[i][1], stripes[i][2], stripes[i][3], 1)
      if stripes.vertical then
        t:SetPoint("TOPLEFT", (i - 1) * fw / 3, 0)
        t:SetSize(fw / 3, fh)
      else
        t:SetPoint("TOPLEFT", 0, -(i - 1) * fh / 3)
        t:SetSize(fw, fh / 3)
      end
    end
  else
    local t = art:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(FLAG_DIR .. "GB")
    t:SetTexCoord(0, 1, 0, 1)
  end
  b.art = art
  b.lang = lang.code
  b:SetScript("OnClick", function() ClickSound(); onClick(lang.code) end)
  b:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(lang.name)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  function b:SetActive(on)
    self.art:SetAlpha(on and 1 or .45)
    SetBorderColor(self, on and GOLD_R or .35, on and GOLD_G or .35, on and GOLD_B or .4, 1)
  end
  return b
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

local function ColorRow(parent, i, key, y)
  local label = Text(parent, function()
    return COLOR_LABELS[key] and L[COLOR_LABELS[key]] or L.CP:format(i)
  end)
  label:SetPoint("TOPLEFT", LEFT, y)
  label:SetWidth(118)
  label:SetWordWrap(false)

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
  swatch:SetScript("OnClick", function() ClickSound(); OpenColorPicker(key) end)

  local slider = Slider(parent, 100, 0, 100, 1, function(v) return v .. " %" end, function(v)
    local c = ns.db.colors[key]
    c.a = v / 100
    ns:ApplyColors()
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
  end)
  slider:SetPoint("TOPLEFT", LEFT + 168, y + 1)

  return function()
    local c = ns.db.colors[key]
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
    slider:Set(floor(c.a * 100 + .5))
  end
end

---------------------------------------------------------------------------
-- Font list: every font name is drawn in its own font
---------------------------------------------------------------------------
local function FontList(parent, x, y, w, h)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetPoint("TOPLEFT", x, y)
  box:SetSize(w, h)
  SkinBox(box)

  local scroll = CreateFrame("ScrollFrame", nil, box)
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -4, 4)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(w - 8, h - 8)
  scroll:SetScrollChild(child)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = max(0, child:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(min(maxScroll, max(0, self:GetVerticalScroll() - delta * FONT_ROW_H * 2)))
  end)

  local hint = Hint(parent, Tr("MORE_FONTS"))
  hint:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -3)

  local rows = {}
  local colW = (w - 8 - 8) / 2
  return function()
    local fonts = ns:GetFonts()
    for i, f in ipairs(fonts) do
      local row = rows[i]
      if not row then
        row = CreateFrame("Button", nil, child)
        row:SetSize(colW, FONT_ROW_H - 2)
        row:SetPoint("TOPLEFT", 2 + ((i - 1) % 2) * (colW + 4), -2 - floor((i - 1) / 2) * FONT_ROW_H)
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
    child:SetHeight(max(h - 8, 4 + ceil(#fonts / 2) * FONT_ROW_H))
    hint:SetShown(child:GetHeight() > h - 8)
  end
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function Build()
  panel = CreateFrame("Frame", "ClaraComboPointsOptions", UIParent, "BackdropTemplate")
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

  panel.flat = panel:CreateTexture(nil, "BACKGROUND")
  panel.flat:SetAllPoints()
  panel.flat:SetColorTexture(.06, .06, .08, .98)
  AddBorder(panel, GOLD_R, GOLD_G, GOLD_B, .45)
  Skinned(panel)
  function panel:Skin()
    local classic = IsClassic()
    self.flat:SetShown(not classic)
    SetBorderShown(self, not classic)
    self:SetBackdrop(classic and BACKDROP_DIALOG or nil)
  end

  local refreshers = {}
  local function OnRefresh(fn) refreshers[#refreshers + 1] = fn end

  -- Title row: name, theme, close ------------------------------------------
  local title = Text(panel, "Clara Combo Points", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", LEFT + 2, -18)
  local version = Hint(panel, "v" .. ns.VERSION)
  version:SetPoint("LEFT", title, "RIGHT", 8, -1)

  local close = Button(panel, "X", 24, 22, function() panel:Hide() end)
  close:SetPoint("TOPRIGHT", -16, -14)
  local themeModern = Button(panel, Tr("THEME_MODERN"), 84, 22, function() ns:SetSkin("MODERN") end, true)
  themeModern:SetPoint("RIGHT", close, "LEFT", -12, 0)
  local themeClassic = Button(panel, Tr("THEME_CLASSIC"), 84, 22, function() ns:SetSkin("CLASSIC") end, true)
  themeClassic:SetPoint("RIGHT", themeModern, "LEFT", -4, 0)
  OnRefresh(function()
    themeClassic:SetActive(IsClassic())
    themeModern:SetActive(not IsClassic())
  end)

  -- Tabs, language flags, which profile this character uses -----------------
  local tabs = {}
  for i, tab in ipairs(CLASS_TABS) do
    local b = Button(panel, Tr(tab.key), 110, 24, function()
      editing = tab.class
      ns:SetActiveProfile(tab.class)
      panel:Refresh()
    end, true)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 114, -46)
    b.class = tab.class
    tabs[i] = b
  end
  local flags = {}
  for i, lang in ipairs(ns.LANGUAGES) do
    local f = Flag(panel, lang, function(code) ns:SetLanguage(code) end)
    f:SetPoint("LEFT", tabs[#CLASS_TABS], "RIGHT", 16 + (i - 1) * 30, 0)
    flags[i] = f
  end
  local whose = Hint(panel, function()
    return L.THIS_CHARACTER:format(ns.isDruid and L.TAB_DRUID or L.TAB_ROGUE)
  end)
  whose:SetPoint("TOPRIGHT", -24, -52)
  whose:SetShown(ns.enabled and true or false)
  local tabLine = panel:CreateTexture(nil, "ARTWORK")
  tabLine:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .3)
  tabLine:SetHeight(1)
  tabLine:SetPoint("TOPLEFT", LEFT, -74)
  tabLine:SetPoint("TOPRIGHT", -LEFT, -74)
  OnRefresh(function()
    for _, b in ipairs(tabs) do b:SetActive(b.class == editing) end
    for _, f in ipairs(flags) do f:SetActive(f.lang == ns.lang) end
  end)

  -- Settings of the selected profile -----------------------------------------
  local content = CreateFrame("Frame", nil, panel)
  content:SetPoint("TOPLEFT", 0, CONTENT_TOP)
  content:SetSize(PANEL_W, PANEL_H + CONTENT_TOP)

  -- Position
  Section(content, "POSITION", LEFT, -56)
  local lockBtn = Button(content, "", 150, 22, function() ns:SetLocked(not ns.db.locked) end)
  lockBtn:SetPoint("TOPLEFT", LEFT, -80)
  local centerBtn = Button(content, Tr("DEFAULT_POS"), 150, 22, function() ns:ResetPosition() end)
  centerBtn:SetPoint("TOPLEFT", LEFT + 160, -80)
  OnRefresh(function()
    lockBtn.text:SetText(ns.db.locked and L.UNLOCK or L.LOCK)
    lockBtn:SetActive(not ns.db.locked)
  end)

  -- Scale
  Section(content, "SCALE", LEFT, -118)
  local presetButtons = {}
  for i, p in ipairs(SCALE_PRESETS) do
    local b = Button(content, p .. "%", 40, 22, function() ns:SetScalePercent(p) end, true)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 44, -142)
    b.percent = p
    presetButtons[i] = b
  end
  local scaleBox = NumberBox(content, 50, function(text) ns:SetScalePercent(text) end)
  scaleBox:SetPoint("TOPLEFT", LEFT, -172)
  local pct = Text(content, "%")
  pct:SetPoint("LEFT", scaleBox, "RIGHT", 4, 0)
  local applyScale = Button(content, Tr("APPLY"), 90, 22, function()
    ns:SetScalePercent(scaleBox:GetText())
    scaleBox:ClearFocus()
  end)
  applyScale:SetPoint("TOPLEFT", LEFT + 72, -172)
  local scaleHint = Hint(content, function() return L.SCALE_HINT:format(ns.MIN_SCALE, ns.MAX_SCALE) end)
  scaleHint:SetPoint("LEFT", applyScale, "RIGHT", 10, 0)
  OnRefresh(function()
    local current = ns:GetScalePercent()
    for _, b in ipairs(presetButtons) do b:SetActive(b.percent == current) end
    if not scaleBox:HasFocus() then scaleBox:SetText(tostring(current)) end
  end)

  -- Global opacity
  Section(content, "GLOBAL_OPACITY", LEFT, -212)
  local alphaSlider = Slider(content, 250, 0, 100, 1, function(v) return v .. " %" end, function(v)
    ns.db.alpha = v / 100
    ns:ApplyAlpha()
  end)
  alphaSlider:SetPoint("TOPLEFT", LEFT, -238)
  OnRefresh(function() alphaSlider:Set(floor(ns.db.alpha * 100 + .5)) end)

  -- Colours
  Section(content, "COLORS", LEFT, -272)
  Hint(content, Tr("COLORS_HINT")):SetPoint("TOPLEFT", LEFT, -292)
  for i, key in ipairs(COLOR_ROWS) do
    OnRefresh(ColorRow(content, i, key, -314 - (i - 1) * 28))
  end
  local resetColors = Button(content, Tr("DEFAULT_COLORS"), 150, 22, function() ns:ResetColors() end)
  resetColors:SetPoint("TOPLEFT", LEFT, -540)

  -- Font
  Section(content, "FONT", RIGHT, -56)
  OnRefresh(FontList(content, RIGHT, -80, COL_W, 230))

  Text(content, Tr("SIZE")):SetPoint("TOPLEFT", RIGHT, -332)
  local sizeSlider = Slider(content, 200, 6, 40, 1, tostring, function(v)
    ns.db.fontSize = v
    ns:ApplyFont()
  end)
  sizeSlider:SetPoint("TOPLEFT", RIGHT + 70, -332)
  OnRefresh(function() sizeSlider:Set(ns.db.fontSize) end)

  Text(content, Tr("OUTLINE")):SetPoint("TOPLEFT", RIGHT, -362)
  local outlineButtons = {}
  for i, o in ipairs(OUTLINES) do
    local b = Button(content, Tr(o[2]), 70, 22, function()
      ns.db.outline = o[1]
      ns:ApplyFont()
      panel:Refresh()
    end, true)
    b:SetPoint("TOPLEFT", RIGHT + 70 + (i - 1) * 76, -356)
    b.value = o[1]
    outlineButtons[i] = b
  end
  OnRefresh(function()
    for _, b in ipairs(outlineButtons) do b:SetActive(b.value == ns.db.outline) end
  end)

  local showText = Check(content, Tr("SHOW_TEXT"), function(on)
    ns.db.showText = on
    ns:ApplyFont()
  end)
  showText:SetPoint("TOPLEFT", RIGHT, -392)
  OnRefresh(function() showText:Set(ns.db.showText) end)

  -- Advanced
  Section(content, "ADVANCED", RIGHT, -420)
  Text(content, Tr("SOURCE")):SetPoint("TOPLEFT", RIGHT, -450)
  local srcTarget = Button(content, Tr("SOURCE_TARGET"), 124, 22, function() ns:SetComboSource("TARGET") end, true)
  srcTarget:SetPoint("TOPLEFT", RIGHT + 90, -444)
  local srcPlayer = Button(content, Tr("SOURCE_PLAYER"), 90, 22, function() ns:SetComboSource("PLAYER") end, true)
  srcPlayer:SetPoint("TOPLEFT", RIGHT + 220, -444)
  OnRefresh(function()
    srcTarget:SetActive(ns.db.cpSource == "TARGET")
    srcPlayer:SetActive(ns.db.cpSource == "PLAYER")
  end)

  local catOnly = Check(content, Tr("CAT_ONLY"), function(on) ns:SetDruidCatOnly(on) end)
  catOnly:SetPoint("TOPLEFT", RIGHT, -478)
  OnRefresh(function()
    catOnly:SetShown(editing == "DRUID")
    catOnly:Set(ns.db.druidCatOnly)
  end)

  local previewBtn = Button(content, Tr("PREVIEW"), 150, 22, function() ns:SetPreview(not ns.preview) end, true)
  previewBtn:SetPoint("TOPLEFT", RIGHT, -504)
  Hint(content, Tr("PREVIEW_HINT")):SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)
  OnRefresh(function() previewBtn:SetActive(ns.preview) end)

  local resetAll
  resetAll = Button(content, "", 150, 22, function()
    if resetAll.armed then
      resetAll.armed = nil
      ns:ResetAll()
    else
      resetAll.armed = true
      C_Timer.After(3, function()
        resetAll.armed = nil
        if panel:IsShown() then panel:Refresh() end
      end)
    end
    panel:Refresh()
  end)
  resetAll:SetPoint("TOPLEFT", RIGHT, -540)
  OnRefresh(function() resetAll.text:SetText(resetAll.armed and L.CONFIRM or L.RESET_ALL) end)

  Hint(content, "/cl lock  ·  /cl unlock  ·  /cl scale 120  ·  /cl reset"):SetPoint("BOTTOMLEFT", LEFT, 18)
  if not ns.enabled then
    local warn = Text(content, Tr("WRONG_CLASS"))
    warn:SetPoint("BOTTOMRIGHT", -24, 18)
    warn:SetTextColor(1, .4, .3)
  end

  function panel:Refresh()
    for _, fn in ipairs(refreshers) do fn() end
  end

  -- Opening the options shows this character's tab, with all five points lit so colour
  -- changes are visible straight away.
  panel:SetScript("OnShow", function(self)
    editing = ns.homeClass or "ROGUE"
    ns:SetActiveProfile(editing)
    ns:SetOptionsOpen(true)
    if InCombatLockdown() then self:Refresh() else ns:SetPreview(true) end
  end)
  panel:SetScript("OnHide", function()
    if ns.preview then ns:SetPreview(false) end
    ns:SetActiveProfile(ns.homeClass or "ROGUE")
    ns:SetOptionsOpen(false)
  end)
end

local function ApplySkin()
  for _, w in ipairs(skinned) do w:Skin() end
end

function ns:SetSkin(skin)
  self.sv.skin = skin
  if panel then
    ApplySkin()
    panel:Refresh()
  end
end

function ns:RelabelOptions()
  if not panel then return end
  for _, fn in ipairs(relabels) do fn() end
  panel:Refresh()
end

function ns:RefreshOptions()
  if panel and panel:IsShown() then panel:Refresh() end
end

function ns:ToggleOptions()
  if not panel then
    Build()
    ApplySkin()
  end
  panel:SetShown(not panel:IsShown())
end
