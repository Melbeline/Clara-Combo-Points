-- Clara Combo Points - options window (/clara or /cl)
-- One tab per class profile (Rogue, Druid), a language picker (flags) and two themes:
--   Classic (default): Blizzard's own frame templates, the look of the game's windows
--     (metal frame with portrait, insets, red buttons, top tabs, checkboxes, sliders).
--   Modern: flat and dark, plain widgets only.
-- Both themes share one layout; each is built the first time it is shown. If a Blizzard
-- template is missing on this client, the Classic window cannot be built and Modern is used.
-- Colours use Blizzard's own colour picker.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local PANEL_W, PANEL_H = 720, 660
local CONTENT_TOP = -38 -- settings start under the title, tab and language row
local LEFT, RIGHT, COL_W = 20, 380, 320
local FONT_ROW_H = 22
local GOLD_R, GOLD_G, GOLD_B = 1, .82, 0
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FLAG_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Flags\\"
local ICONS = { ROGUE = "Interface\\Icons\\Ability_Rogue_Eviscerate", DRUID = "Interface\\Icons\\Ability_Druid_CatForm" }

local CLASS_TABS = { { class = "ROGUE", key = "TAB_ROGUE" }, { class = "DRUID", key = "TAB_DRUID" } }
local COLOR_ROWS = { "cp1", "cp2", "cp3", "cp4", "cp5", "energy", "bg", "text" }
local COLOR_LABELS = { energy = "ENERGY_BAR", bg = "BACKGROUND", text = "ENERGY_TEXT" }
local SCALE_PRESETS = { 50, 75, 100, 125, 150, 200, 300 }
local OUTLINES = { { "NONE", "OUTLINE_NONE" }, { "OUTLINE", "OUTLINE_THIN" }, { "THICKOUTLINE", "OUTLINE_THICK" } }

local panels = {}     -- built windows, by theme
local current         -- the window in use
local editing         -- class profile shown in the window
local keepTab         -- set while switching theme: the new window keeps the open tab
local classicFailed   -- a Blizzard template was missing: no Classic window on this client

local kit             -- widget set of the window being built
local relabels        -- text setters of the window being built (run again on language change)

local function Tr(key) return function() return L[key] end end
local function OnRelabel(fn) relabels[#relabels + 1] = fn; fn() end

local function ClickSound()
  if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

local function SkinWanted()
  return (ns.sv.skin == "CLASSIC" and not classicFailed) and "CLASSIC" or "MODERN"
end

---------------------------------------------------------------------------
-- Shared pieces
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

-- s: plain string, or a function returning the text in the current language
local function SetText(fs, s)
  if type(s) == "function" then
    OnRelabel(function() fs:SetText(s()) end)
  else
    fs:SetText(s)
  end
end

local function Text(parent, s, fontObject)
  local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or kit.labelFont)
  fs:SetJustifyH("LEFT")
  SetText(fs, s)
  return fs
end

local function Hint(parent, s)
  local fs = Text(parent, s, "GameFontHighlightSmall")
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
-- Modern kit: flat widgets
---------------------------------------------------------------------------
local Modern = { labelFont = "GameFontHighlightSmall" }

function Modern.Window()
  local w = CreateFrame("Frame", "ClaraComboPointsOptions", UIParent)
  w:Hide()
  local bg = w:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(.06, .06, .08, .98)
  AddBorder(w, GOLD_R, GOLD_G, GOLD_B, .45)
  local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", LEFT + 2, -18)
  title:SetText("Clara Combo Points")
  local version = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  version:SetPoint("LEFT", title, "RIGHT", 8, -1)
  version:SetTextColor(.6, .6, .65)
  version:SetText("v" .. ns.VERSION)
  local close = Modern.Button(w, "X", 24, 22, function() w:Hide() end)
  close:SetPoint("TOPRIGHT", -16, -14)
  w.closeButton = close
  w.SetIcon = function() end
  return w
end

function Modern.Button(parent, label, w, h, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h or 22)
  b.flat = b:CreateTexture(nil, "BACKGROUND")
  b.flat:SetAllPoints()
  AddBorder(b, .32, .32, .38, 1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .08)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER")
  SetText(b.text, label)
  b:SetScript("OnClick", function(self) ClickSound(); onClick(self) end)
  function b:SetLabel(s) self.text:SetText(s) end
  function b:SetActive(on)
    if on then
      self.flat:SetColorTexture(.36, .27, .02, 1)
      SetBorderColor(self, GOLD_R, GOLD_G, GOLD_B, 1)
    else
      self.flat:SetColorTexture(.14, .14, .17, 1)
      SetBorderColor(self, .32, .32, .38, 1)
    end
  end
  b:SetActive(false)
  return b
end

function Modern.Tab(parent, label, onClick)
  return Modern.Button(parent, label, 110, 24, onClick)
end

function Modern.Check(parent, label, onToggle)
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
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .08)
  b.text = b:CreateFontString(nil, "OVERLAY", Modern.labelFont)
  b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
  SetText(b.text, label)
  OnRelabel(function() b:SetHitRectInsets(0, -(b.text:GetStringWidth() + 6), 0, 0) end)
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

function Modern.Slider(parent, w, minV, maxV, step, fmt, onChange)
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(w, 14)
  s:SetHitRectInsets(0, 0, -6, -6)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(.22, .22, .26, 1)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  s:SetThumbTexture(WHITE)
  local thumb = s:GetThumbTexture()
  thumb:SetSize(8, 14)
  thumb:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 1)
  return s
end

function Modern.NumberBox(parent, w)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(w, 22)
  e:SetFontObject("GameFontHighlight")
  e:SetTextInsets(6, 6, 0, 0)
  local bg = e:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, .4)
  AddBorder(e, .35, .35, .4, 1)
  e.holder = e
  return e
end

function Modern.Box(parent)
  local f = CreateFrame("Frame", nil, parent)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, .35)
  AddBorder(f, .3, .3, .35, 1)
  return f
end

function Modern.SelectRow(tex, on)
  tex:SetColorTexture(.36, .27, .02, on and 1 or 0)
end

---------------------------------------------------------------------------
-- Classic kit: Blizzard's own templates
---------------------------------------------------------------------------
local Classic = { labelFont = "GameFontNormalSmall" }

function Classic.Window()
  local w = CreateFrame("Frame", "ClaraComboPointsOptionsClassic", UIParent, "PortraitFrameTemplate")
  w:Hide()
  local title = (w.TitleContainer and w.TitleContainer.TitleText) or w.TitleText
  if w.SetTitle then w:SetTitle("Clara Combo Points  v" .. ns.VERSION) else title:SetText("Clara Combo Points  v" .. ns.VERSION) end
  local portrait = (w.PortraitContainer and w.PortraitContainer.portrait) or w.portrait
  function w.SetIcon(path)
    if portrait then portrait:SetTexture(path) end
  end
  -- dark insets behind the two columns, like the game's own windows
  local left = CreateFrame("Frame", nil, w, "InsetFrameTemplate")
  left:SetPoint("TOPLEFT", 12, -84)
  left:SetPoint("BOTTOMRIGHT", w, "BOTTOMLEFT", 368, 40)
  local right = CreateFrame("Frame", nil, w, "InsetFrameTemplate")
  right:SetPoint("TOPLEFT", 372, -84)
  right:SetPoint("BOTTOMRIGHT", -10, 40)
  w.closeButton = w.CloseButton
  return w
end

function Classic.Button(parent, label, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h or 22)
  b:SetNormalFontObject(GameFontNormalSmall)
  b:SetHighlightFontObject(GameFontHighlightSmall)
  if type(label) == "function" then
    OnRelabel(function() b:SetText(label()) end)
  else
    b:SetText(label)
  end
  b:SetScript("OnClick", function(self) ClickSound(); onClick(self) end)
  function b:SetLabel(s) self:SetText(s) end
  -- a selected option keeps its highlight lit, with white text
  function b:SetActive(on)
    if on then
      self:LockHighlight()
      self:SetNormalFontObject(GameFontHighlightSmall)
    else
      self:UnlockHighlight()
      self:SetNormalFontObject(GameFontNormalSmall)
    end
  end
  return b
end

function Classic.Tab(parent, label, onClick)
  local t = CreateFrame("Button", nil, parent, "PanelTopTabButtonTemplate")
  OnRelabel(function()
    t:SetText(label())
    PanelTemplates_TabResize(t, 0)
  end)
  t:SetScript("OnClick", function(self) ClickSound(); onClick(self) end)
  function t:SetActive(on)
    if on then PanelTemplates_SelectTab(self) else PanelTemplates_DeselectTab(self) end
  end
  return t
end

-- 14x14 holder so both themes share the layout; the 24px Blizzard box is centred on it
function Classic.Check(parent, label, onToggle)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(14, 14)
  local cb = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("CENTER")
  local text = cb.Text or cb.text
  text:ClearAllPoints()
  text:SetPoint("LEFT", cb, "RIGHT", 1, 0)
  SetText(text, label)
  OnRelabel(function() cb:SetHitRectInsets(0, -(text:GetStringWidth() + 4), 0, 0) end)
  cb:SetScript("OnClick", function(self)
    ClickSound()
    onToggle(self:GetChecked() and true or false)
  end)
  holder.check = cb
  function holder:Set(on) self.check:SetChecked(on and true or false) end
  return holder
end

function Classic.Slider(parent, w, minV, maxV, step, fmt, onChange)
  local s = CreateFrame("Slider", nil, parent, "UISliderTemplate")
  s:SetSize(w, 17)
  s:SetHitRectInsets(0, 0, -5, -5) -- the template's -10 would overlap the next colour row (28px apart)
  return s
end

function Classic.NumberBox(parent, w)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(w, 22)
  local e = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
  e:SetPoint("TOPLEFT", 6, -1)
  e:SetPoint("BOTTOMRIGHT", 0, 1)
  e:SetFontObject("ChatFontNormal")
  e.holder = holder
  return e
end

function Classic.Box(parent)
  return CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
end

function Classic.SelectRow(tex, on)
  tex:SetColorTexture(1, 1, 1, 1)
  if on and CreateColor and tex.SetGradient then
    tex:SetGradient("HORIZONTAL", CreateColor(1, .82, 0, .45), CreateColor(1, .82, 0, .05))
  else
    tex:SetColorTexture(1, .82, 0, on and .35 or 0)
  end
end

---------------------------------------------------------------------------
-- Widgets built from the kit
---------------------------------------------------------------------------
local function Slider(parent, w, minV, maxV, step, fmt, onChange)
  local s = kit.Slider(parent, w, minV, maxV, step, fmt, onChange)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  s:EnableMouseWheel(true)
  s.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

local function NumberBox(parent, w, onEnter)
  local e = kit.NumberBox(parent, w)
  e:SetAutoFocus(false)
  e:SetNumeric(true)
  e:SetMaxLetters(3)
  e:SetJustifyH("CENTER")
  e:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    self:ClearFocus() -- first, so the refresh can show the clamped value
    onEnter(text)
  end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); current:Refresh() end)
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
    ns:RefreshOptions()
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
  slider:SetPoint("LEFT", parent, "TOPLEFT", LEFT + 168, y - 6)

  return function()
    local c = ns.db.colors[key]
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
    slider:Set(floor(c.a * 100 + .5))
  end
end

---------------------------------------------------------------------------
-- Font list: every font name is drawn in its own font, shrunk if it would not fit
---------------------------------------------------------------------------
local function FontList(parent, x, y, w, h)
  local box = kit.Box(parent)
  box:SetPoint("TOPLEFT", x, y)
  box:SetSize(w, h)

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

  local selectRow = kit.SelectRow
  local rows = {}
  local colW = (w - 8 - 8) / 2
  local textW = colW - 10
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
          current:Refresh()
        end)
        rows[i] = row
      end
      if row.fontName ~= f.name then
        row.fontName = f.name
        local ok = row.text:SetFont(f.path, 13, "")
        if ok == false or not row.text:GetFont() then row.text:SetFontObject(GameFontHighlightSmall) end
        row.text:SetText(f.name)
        local measure = row.text.GetUnboundedStringWidth or row.text.GetStringWidth
        local width = measure(row.text)
        local path, size = row.text:GetFont()
        if path and width > textW then
          row.text:SetFont(path, max(7, floor(size * textW / width)), "")
        end
      end
      local selected = (f.name == ns.db.font)
      selectRow(row.bg, selected)
      row.text:SetTextColor(selected and GOLD_R or 1, selected and GOLD_G or 1, selected and GOLD_B or 1)
    end
    child:SetHeight(max(h - 8, 4 + ceil(#fonts / 2) * FONT_ROW_H))
    hint:SetShown(child:GetHeight() > h - 8)
  end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Build(skin)
  kit = (skin == "CLASSIC") and Classic or Modern
  relabels = {}
  local panel = kit.Window()
  panel.skin = skin
  panel.relabels = relabels
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
  tinsert(UISpecialFrames, panel:GetName()) -- Esc closes it

  local refreshers = {}
  local function OnRefresh(fn) refreshers[#refreshers + 1] = fn end
  local resetAll

  -- Theme buttons, tabs, language flags ----------------------------------------
  local themeModern = kit.Button(panel, Tr("THEME_MODERN"), 84, 22, function() ns:SetSkin("MODERN") end)
  local themeClassic = kit.Button(panel, Tr("THEME_CLASSIC"), 84, 22, function() ns:SetSkin("CLASSIC") end)
  if skin == "CLASSIC" then
    themeModern:SetPoint("TOPRIGHT", -14, -56)
  else
    themeModern:SetPoint("RIGHT", panel.closeButton, "LEFT", -12, 0)
  end
  themeClassic:SetPoint("RIGHT", themeModern, "LEFT", -4, 0)
  OnRefresh(function()
    themeClassic:SetActive(skin == "CLASSIC")
    themeModern:SetActive(skin == "MODERN")
  end)

  local tabs = {}
  for i, tab in ipairs(CLASS_TABS) do
    local t = kit.Tab(panel, Tr(tab.key), function()
      editing = tab.class
      resetAll.armed = nil
      ns:SetActiveProfile(tab.class)
      panel:Refresh()
    end)
    if i > 1 then
      t:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)
    elseif skin == "CLASSIC" then
      t:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 66, -86) -- standing on the insets, right of the portrait
    else
      t:SetPoint("TOPLEFT", LEFT, -46)
    end
    t.class = tab.class
    tabs[i] = t
  end
  local flags = {}
  for i, lang in ipairs(ns.LANGUAGES) do
    local f = Flag(panel, lang, function(code) ns:SetLanguage(code) end)
    f:SetPoint("LEFT", tabs[#tabs], "RIGHT", 16 + (i - 1) * 30, skin == "CLASSIC" and -4 or 0)
    flags[i] = f
  end
  if skin == "MODERN" then
    local tabLine = panel:CreateTexture(nil, "ARTWORK")
    tabLine:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .3)
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT", LEFT, -74)
    tabLine:SetPoint("TOPRIGHT", -LEFT, -74)
  end
  OnRefresh(function()
    for _, t in ipairs(tabs) do t:SetActive(t.class == editing) end
    for _, f in ipairs(flags) do f:SetActive(f.lang == ns.lang) end
    panel.SetIcon(ICONS[editing])
  end)

  -- Settings of the selected profile -----------------------------------------
  local content = CreateFrame("Frame", nil, panel)
  content:SetPoint("TOPLEFT", 0, CONTENT_TOP)
  content:SetSize(PANEL_W, PANEL_H + CONTENT_TOP)

  -- Position
  Section(content, "POSITION", LEFT, -56)
  local lockBtn = kit.Button(content, "", 150, 22, function() ns:SetLocked(not ns.db.locked) end)
  lockBtn:SetPoint("TOPLEFT", LEFT, -80)
  local centerBtn = kit.Button(content, Tr("DEFAULT_POS"), 150, 22, function() ns:ResetPosition() end)
  centerBtn:SetPoint("TOPLEFT", LEFT + 160, -80)
  OnRefresh(function()
    lockBtn:SetLabel(ns.db.locked and L.UNLOCK or L.LOCK)
    lockBtn:SetActive(not ns.db.locked)
  end)

  -- Scale
  Section(content, "SCALE", LEFT, -118)
  local presetButtons = {}
  for i, p in ipairs(SCALE_PRESETS) do
    local b = kit.Button(content, p .. "%", 40, 22, function() ns:SetScalePercent(p) end)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 44, -142)
    b.percent = p
    presetButtons[i] = b
  end
  local scaleBox = NumberBox(content, 50, function(text) ns:SetScalePercent(text) end)
  scaleBox.holder:SetPoint("TOPLEFT", LEFT, -172)
  local pct = Text(content, "%")
  pct:SetPoint("LEFT", scaleBox.holder, "RIGHT", 4, 0)
  local applyScale = kit.Button(content, Tr("APPLY"), 90, 22, function()
    scaleBox:ClearFocus()
    ns:SetScalePercent(scaleBox:GetText())
  end)
  applyScale:SetPoint("TOPLEFT", LEFT + 72, -172)
  local scaleHint = Hint(content, function() return L.SCALE_HINT:format(ns.MIN_SCALE, ns.MAX_SCALE) end)
  scaleHint:SetPoint("LEFT", applyScale, "RIGHT", 10, 0)
  OnRefresh(function()
    local now = ns:GetScalePercent()
    for _, b in ipairs(presetButtons) do b:SetActive(b.percent == now) end
    if not scaleBox:HasFocus() then scaleBox:SetText(tostring(now)) end
  end)

  -- Global opacity
  Section(content, "GLOBAL_OPACITY", LEFT, -212)
  local alphaSlider = Slider(content, 250, 0, 100, 1, function(v) return v .. " %" end, function(v)
    ns.db.alpha = v / 100
    ns:ApplyAlpha()
  end)
  alphaSlider:SetPoint("LEFT", content, "TOPLEFT", LEFT, -245)
  OnRefresh(function() alphaSlider:Set(floor(ns.db.alpha * 100 + .5)) end)

  -- Colours
  Section(content, "COLORS", LEFT, -272)
  Hint(content, Tr("COLORS_HINT")):SetPoint("TOPLEFT", LEFT, -292)
  for i, key in ipairs(COLOR_ROWS) do
    OnRefresh(ColorRow(content, i, key, -314 - (i - 1) * 28))
  end
  local resetColors = kit.Button(content, Tr("DEFAULT_COLORS"), 150, 22, function() ns:ResetColors() end)
  resetColors:SetPoint("TOPLEFT", LEFT, -540)

  -- Font
  Section(content, "FONT", RIGHT, -56)
  OnRefresh(FontList(content, RIGHT, -80, COL_W, 230))

  Text(content, Tr("SIZE")):SetPoint("TOPLEFT", RIGHT, -332)
  local sizeSlider = Slider(content, 200, 6, 40, 1, tostring, function(v)
    ns.db.fontSize = v
    ns:ApplyFont()
  end)
  sizeSlider:SetPoint("LEFT", content, "TOPLEFT", RIGHT + 70, -338)
  OnRefresh(function() sizeSlider:Set(ns.db.fontSize) end)

  Text(content, Tr("OUTLINE")):SetPoint("TOPLEFT", RIGHT, -362)
  local outlineButtons = {}
  for i, o in ipairs(OUTLINES) do
    local b = kit.Button(content, Tr(o[2]), 70, 22, function()
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

  local showText = kit.Check(content, Tr("SHOW_TEXT"), function(on)
    ns.db.showText = on
    ns:ApplyFont()
  end)
  showText:SetPoint("TOPLEFT", RIGHT, -392)
  OnRefresh(function() showText:Set(ns.db.showText) end)

  -- Advanced
  Section(content, "ADVANCED", RIGHT, -420)
  Text(content, Tr("SOURCE")):SetPoint("TOPLEFT", RIGHT, -450)
  local srcTarget = kit.Button(content, Tr("SOURCE_TARGET"), 124, 22, function() ns:SetComboSource("TARGET") end)
  srcTarget:SetPoint("TOPLEFT", RIGHT + 90, -444)
  local srcPlayer = kit.Button(content, Tr("SOURCE_PLAYER"), 90, 22, function() ns:SetComboSource("PLAYER") end)
  srcPlayer:SetPoint("TOPLEFT", RIGHT + 220, -444)
  OnRefresh(function()
    srcTarget:SetActive(ns.db.cpSource == "TARGET")
    srcPlayer:SetActive(ns.db.cpSource == "PLAYER")
  end)

  local catOnly = kit.Check(content, Tr("CAT_ONLY"), function(on) ns:SetDruidCatOnly(on) end)
  catOnly:SetPoint("TOPLEFT", RIGHT, -478)
  OnRefresh(function()
    catOnly:SetShown(editing == "DRUID")
    catOnly:Set(ns.db.druidCatOnly)
  end)

  local previewBtn = kit.Button(content, Tr("PREVIEW"), 150, 22, function() ns:SetPreview(not ns.preview) end)
  previewBtn:SetPoint("TOPLEFT", RIGHT, -504)
  Hint(content, Tr("PREVIEW_HINT")):SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)
  OnRefresh(function() previewBtn:SetActive(ns.preview) end)

  resetAll = kit.Button(content, "", 150, 22, function()
    if resetAll.armed then
      resetAll.armed = nil
      ns:ResetAll()
    else
      local token = {} -- each confirmation has its own 3 s, untouched by an earlier one
      resetAll.armed = token
      C_Timer.After(3, function()
        if resetAll.armed ~= token then return end
        resetAll.armed = nil
        if panel:IsShown() then panel:Refresh() end
      end)
    end
    panel:Refresh()
  end)
  resetAll:SetPoint("TOPLEFT", RIGHT, -540)
  OnRefresh(function() resetAll:SetLabel(resetAll.armed and L.CONFIRM or L.RESET_ALL) end)

  -- Footer: commands, and which profile this character uses
  Hint(panel, "/cl lock  ·  /cl unlock  ·  /cl scale 120  ·  /cl reset"):SetPoint("BOTTOMLEFT", LEFT, 16)
  if ns.enabled then
    Hint(panel, function()
      return L.THIS_CHARACTER:format(ns.isDruid and L.TAB_DRUID or L.TAB_ROGUE)
    end):SetPoint("BOTTOMRIGHT", -LEFT, 16)
  else
    local warn = Text(panel, Tr("WRONG_CLASS"), "GameFontHighlightSmall")
    warn:SetPoint("BOTTOMRIGHT", -LEFT, 16)
    warn:SetTextColor(1, .4, .3)
  end

  function panel:Refresh()
    for _, fn in ipairs(refreshers) do fn() end
  end

  -- Opening the options shows this character's tab, with all five points lit so colour
  -- changes are visible straight away.
  panel:SetScript("OnShow", function(self)
    current = self
    if not keepTab then editing = ns.homeClass or "ROGUE" end
    resetAll.armed = nil
    ns:SetActiveProfile(editing)
    ns:SetOptionsOpen(true)
    if InCombatLockdown() then self:Refresh() else ns:SetPreview(true) end
  end)
  panel:SetScript("OnHide", function()
    if ns.preview then ns:SetPreview(false) end
    if not keepTab then ns:LockOtherProfiles() end
    ns:SetActiveProfile(ns.homeClass or "ROGUE")
    ns:SetOptionsOpen(false)
  end)

  return panel
end

local function GetPanel(skin)
  if skin == "CLASSIC" and not panels.CLASSIC and not classicFailed then
    local ok, result = pcall(Build, "CLASSIC")
    if ok then
      panels.CLASSIC = result
    else
      classicFailed = true
      ns.Print(L.CLASSIC_UNAVAILABLE)
    end
  end
  if skin == "CLASSIC" and panels.CLASSIC then return panels.CLASSIC end
  if not panels.MODERN then panels.MODERN = Build("MODERN") end
  return panels.MODERN
end

local function Open()
  local panel = GetPanel(SkinWanted())
  panel:Show()
end

function ns:SetSkin(skin)
  self.sv.skin = skin
  if current and current:IsShown() and current.skin ~= SkinWanted() then
    local point, _, relPoint, x, y = current:GetPoint(1)
    keepTab = true
    current:Hide()
    local panel = GetPanel(SkinWanted())
    panel:ClearAllPoints()
    panel:SetPoint(point, UIParent, relPoint, x, y)
    panel:Show()
    keepTab = false
  end
end

function ns:RelabelOptions()
  for _, panel in pairs(panels) do
    for _, fn in ipairs(panel.relabels) do fn() end
  end
  self:RefreshOptions()
end

function ns:RefreshOptions()
  if current and current:IsShown() then current:Refresh() end
end

function ns:ToggleOptions()
  if current and current:IsShown() then
    current:Hide()
  else
    Open()
  end
end
