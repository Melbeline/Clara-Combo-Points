-- Clara Combo Points - options window (/clara or /cl)
-- Built from Blizzard's own frame templates, the look of the game's windows: metal frame with
-- portrait, insets, red buttons, tabs, checkboxes and sliders.
--   Top: one tab per class profile, in one row; the language flags in the title bar.
--   Left: the pages (General, Bars, Icons, Visibility, Profiles), each with a line saying what
--   it holds (drag one to change its place), and the preview.
--   Each option is on one page only.
--   Bottom: the commands, and the window's opacity.
--   The window can be dragged anywhere, even off the screen; its bottom right corner sizes it
--   (left button: width and height, the pages laid out again; right button: its scale; a
--   double click: both back to the default). Where it is, its size, scale and opacity are
--   kept (account-wide).
-- Colours use Blizzard's own colour picker.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local NAV_W, BODY_W = 168, 720    -- the list of pages on the left; a page (two columns)
local SCROLL_W = 22               -- right of the pages: their scroll bar, when they are taller than the window
local PANEL_W, PANEL_H = NAV_W + BODY_W + SCROLL_W, 720 -- the window's default size
local TABS_X, FLAG_STEP = 14, 30 -- first tab; flags, one every 30
local TABS_Y = -84               -- bottom of the row of class tabs (each tab is 32 tall)
local HEADER_X, HEADER_Y = 64, -37 -- the position's line, between the title and the tabs
local FOOTER_RIGHT = 28          -- footer, clear of the scale grip
local CONTENT_TOP = -40          -- pages start under the class tabs (their first group at -96)
local VIEW_TOP = -86             -- the pages' view, under the class tabs (it scrolls them)
local NAV_TOP, NAV_ROW_H = -88, 56 -- the list of pages: its top, one page's height
local LEFT, RIGHT, COL_W = 20, 380, 320
local FULL_W = BODY_W - 2 * LEFT
local GOLD_R, GOLD_G, GOLD_B = 1, .82, 0
local FLAG_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Flags\\"
local ICONS = {
  ROGUE   = "Interface\\Icons\\Ability_Rogue_Eviscerate",
  DRUID   = "Interface\\Icons\\Ability_Druid_CatForm",
  WARRIOR = "Interface\\Icons\\Ability_Warrior_BattleShout",
  PRIEST  = "Interface\\Icons\\Spell_Holy_PowerWordShield",
  MAGE    = "Interface\\Icons\\Spell_Frost_FrostBolt02",
  WARLOCK = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
  HUNTER  = "Interface\\Icons\\Ability_Marksmanship",
  SHAMAN  = "Interface\\Icons\\Spell_Nature_BloodLust",
  PALADIN = "Interface\\Icons\\Spell_Holy_HolyBolt",
}

-- the class tabs, in one row
local CLASSES = { "PRIEST", "MAGE", "WARLOCK", "DRUID", "ROGUE", "HUNTER", "SHAMAN", "PALADIN", "WARRIOR" }
-- the pages: name, what they hold
local PAGES = {
  { "PAGE_GENERAL", "NAV_GENERAL" }, { "PAGE_BARS", "NAV_BARS" }, { "PAGE_ICONS", "NAV_ICONS" },
  { "PAGE_VISIBILITY", "NAV_VISIBILITY" }, { "PAGE_PROFILES", "NAV_PROFILES" },
}
local ICONS_PAGE = 3 -- the class spells panel opens beside it
-- the colours of each bar (Bars page); background and value text are on the General page
local BAR_COLORS = { combo = { "cp1", "cp2", "cp3", "cp4", "cp5" }, power = { "energy", "rage", "cost" },
  mana = { "mana", "manaCost" }, health = { "health" } }
local COLOR_LABELS = { energy = "ENERGY_BAR", rage = "RAGE_BAR", mana = "MANA_BAR", health = "HEALTH_BAR", cost = "COST_COLOR",
  manaCost = "MANA_COST_COLOR" }
-- colours a class never uses (warriors have no combo points: their icons wear the button frame;
-- the mana classes have neither combo points nor energy / rage)
local MANA_ONLY = { cp1 = true, cp2 = true, cp3 = true, cp4 = true, cp5 = true, energy = true, rage = true, cost = true }
local NO_COLOR = {
  ROGUE = { rage = true, cost = true, mana = true, manaCost = true },
  WARRIOR = { cp1 = true, cp2 = true, cp3 = true, cp4 = true, cp5 = true, energy = true, mana = true, manaCost = true },
  PRIEST = MANA_ONLY, MAGE = MANA_ONLY, WARLOCK = MANA_ONLY, HUNTER = MANA_ONLY, SHAMAN = MANA_ONLY, PALADIN = MANA_ONLY,
}
local RESOURCE = { ROGUE = "ENERGY", DRUID = "BOTH", WARRIOR = "RAGE", PRIEST = "MANA", MAGE = "MANA",
  WARLOCK = "MANA", HUNTER = "MANA", SHAMAN = "MANA", PALADIN = "MANA" }           -- the value the bar shows
local SCALE_PRESETS = { 50, 75, 100, 125, 150, 200, 300 }
local OUTLINES = { { "NONE", "OUTLINE_NONE" }, { "OUTLINE", "OUTLINE_THIN" }, { "THICKOUTLINE", "OUTLINE_THICK" } }
local ROW_LINES = { { "above", 3 }, { "above", 2 }, { "above", 1 }, false, { "below", 1 }, { "below", 2 }, { "below", 3 } }
local SHAPES = { "FILL", "CELL", "SQUARE" } -- icons: the row fills the bar's width / combo point cells / squares
local FONT_MENU_H = 360 -- the list of fonts scrolls past this height

local panel           -- the window, built the first time it opens
local editing         -- class profile shown in the window
local page = 1        -- page shown
local selSide, selK = "above", 1 -- icon row that "Add" fills
local relabels        -- text setters (run again on language change)

local function Tr(key) return function() return L[key] end end

-- The window's size and the spells panel's (sv.window, sv.catalog: nil = the default). The
-- panel's height is the window's while it is locked beside it.
local SIDE_W = 420
local function WinW() return ns.sv.window.w or PANEL_W end
local function WinH() return ns.sv.window.h or PANEL_H end
local function CatW() return ns.sv.catalog.w or SIDE_W end
local function CatH() return ns.sv.catalog.h or WinH() end
local function OnRelabel(fn) relabels[#relabels + 1] = fn; fn() end

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

-- s: plain string, or a function returning the text in the current language
local function SetText(fs, s)
  if type(s) == "function" then
    OnRelabel(function() fs:SetText(s()) end)
  else
    fs:SetText(s)
  end
end

local function Text(parent, s, fontObject)
  local fs = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontNormalSmall")
  fs:SetJustifyH("LEFT")
  SetText(fs, s)
  return fs
end

local function Hint(parent, s)
  local fs = Text(parent, s, "GameFontHighlightSmall")
  fs:SetTextColor(.6, .6, .65)
  return fs
end

-- A hint as wide as a column, on as many lines as it needs.
local function Wrapped(parent, s, w)
  local fs = Hint(parent, s)
  fs:SetWidth(w or COL_W)
  fs:SetWordWrap(true)
  return fs
end

-- A thin line between the parts of a group.
local function Rule(parent, x, y, w)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(.62, .62, .66, .35)
  t:SetSize(w or COL_W, 1)
  t:SetPoint("TOPLEFT", x, y)
  return t
end

-- A group of settings in a box like the character sheet's panels: bronze border, dark fill,
-- gold title. The box sits on the page's back layer, under the widgets.
-- key: the title's locale key (or nil: box.title:SetText later). bottom: lowest y of the
-- group's content (or later, box:Fit(y)).
local GROUP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local PAD = 9 -- box margin around its content

-- The look of a group (and of the specialisations menu): the bronze border of the character
-- sheet's panels in this client, over a dark fill; without that art, the tooltip border in
-- bronze.
local INSIDE_FRAME = "common-insideframe"
local function GroupLook(box, alpha) -- alpha: the fill's opacity (default .55)
  alpha = alpha or .55
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(INSIDE_FRAME) then
    local border = box:CreateTexture(nil, "BORDER")
    border:SetAtlas(INSIDE_FRAME)
    border:SetPoint("TOPLEFT", 1, 1) -- as the character sheet places it
    border:SetPoint("BOTTOMRIGHT", -4, 2)
    local fill = box:CreateTexture(nil, "BACKGROUND") -- inside the art
    fill:SetPoint("TOPLEFT", border, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(0, 0, 0, alpha)
    box.border, box.fill = border, fill
  else
    box:SetBackdrop(GROUP_BACKDROP)
    box:SetBackdropColor(0, 0, 0, alpha)
    box:SetBackdropBorderColor(.72, .58, .34, 1)
  end
end

local function Section(parent, key, x, y, width, bottom)
  local box = CreateFrame("Frame", nil, parent.back, "BackdropTemplate")
  if parent.boxes then parent.boxes[#parent.boxes + 1] = box end -- (where its column ends: Reflow)
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", x - PAD, y + PAD)
  box:SetWidth((width or COL_W) + 2 * PAD)
  GroupLook(box)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  if key then OnRelabel(function() fs:SetText(L[key]) end) end
  box.title = fs
  function box:Fit(lowest) self:SetHeight(y - lowest + 2 * PAD) end
  box:Fit(bottom or y - 40)
  return box
end

-- A frame of fixed height holding one setting, so settings can be stacked per class.
local function Holder(parent, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(COL_W, h)
  return f
end

-- items: { frame, height, when }; shown ones are placed one under the other from y. The
-- group box around them (if any) follows their height.
local function Stack(parent, x, y, items, box)
  return function()
    local top = y
    for _, item in ipairs(items) do
      local shown = not item.when or item.when()
      item.frame:SetShown(shown)
      if shown then
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, top)
        top = top - item.height
      end
    end
    if box then box:Fit(top) end
  end
end

-- A page's right column (beside the left one, or under it when the window is too narrow for
-- both: Reflow), or its part across both columns, under them. Its widgets keep the page's x
-- and y; its group boxes are on its own back layer.
local function Column(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetSize(BODY_W, 1)
  f:SetPoint("TOPLEFT")
  f.back = CreateFrame("Frame", nil, page.back)
  f.back:SetAllPoints(f)
  f.boxes = {}
  return f
end

local function Button(parent, label, w, h, onClick)
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

local function Tab(parent, label, onClick)
  local t = CreateFrame("Button", nil, parent, "PanelTopTabButtonTemplate")
  OnRelabel(function()
    t:SetText(label())
    PanelTemplates_TabResize(t, 0)
  end)
  t:SetScript("OnClick", function(self) ClickSound(); onClick(self) end)
  local level = t:GetFrameLevel()
  function t:SetActive(on)
    if on then PanelTemplates_SelectTab(self) else PanelTemplates_DeselectTab(self) end
    self:SetFrameLevel(level + (on and 2 or 0)) -- over its neighbours when they overlap (a narrow window)
  end
  return t
end

-- 14x14 holder for layout; the 24px Blizzard box is centred on it
local function Check(parent, label, onToggle)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(14, 14)
  local cb = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("CENTER")
  local text = cb.Text or cb.text
  text:ClearAllPoints()
  text:SetPoint("LEFT", cb, "RIGHT", 1, 0)
  local function Fit() cb:SetHitRectInsets(0, -(text:GetStringWidth() + 4), 0, 0) end
  if label then
    SetText(text, label)
    OnRelabel(Fit)
  end
  cb:SetScript("OnClick", function(self)
    ClickSound()
    onToggle(self:GetChecked() and true or false)
  end)
  holder.check = cb
  function holder:Set(on) self.check:SetChecked(on and true or false) end
  function holder:SetLabel(s) text:SetText(s); Fit() end
  return holder
end

local InputBox -- below

-- A Blizzard slider with a box beside it to type the exact value (Enter applies it).
-- unit: text after the box ("%" or "").
local function Slider(parent, w, minV, maxV, step, unit, onChange, boxW)
  local s = CreateFrame("Slider", nil, parent, "UISliderTemplate")
  s:SetSize(w, 17)
  s:SetHitRectInsets(0, 0, -5, -5) -- the template's -10 would overlap the next colour row (28px apart)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  s:EnableMouse(true)
  s:EnableMouseWheel(true)
  local box = InputBox(parent, boxW or 38)
  box:SetNumeric(true)
  box:SetMaxLetters(3)
  box:SetJustifyH("CENTER")
  box.holder:SetPoint("LEFT", s, "RIGHT", 6, 0)
  s.box = box
  if unit ~= "" then
    s.unit = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.unit:SetPoint("LEFT", box.holder, "RIGHT", 3, 0)
    s.unit:SetText(unit)
  end
  local function Show(v)
    if not box:HasFocus() then box:SetText(tostring(v)) end
  end
  s:SetScript("OnValueChanged", function(self, v)
    v = floor(v / step + .5) * step
    Show(v)
    if not self.silent then onChange(v) end
  end)
  -- the wheel: in a page that scrolls, it scrolls the page (the slider only with Shift held),
  -- so that scrolling past a slider never changes it
  s:SetScript("OnMouseWheel", function(self, delta)
    local page = self:GetParent()
    while page and not page.GetVerticalScroll do page = page:GetParent() end
    if page and not (IsShiftKeyDown and IsShiftKeyDown()) then
      local scroll = page:GetScript("OnMouseWheel")
      if scroll then scroll(page, delta) end
      return
    end
    self:SetValue(min(maxV, max(minV, self:GetValue() + delta * step)))
  end)
  local function Apply(self)
    local v = tonumber(self:GetText())
    self:ClearFocus()
    if v then s:SetValue(min(maxV, max(minV, floor(v / step + .5) * step))) end
    Show(floor(s:GetValue() / step + .5) * step) -- the value really applied
  end
  box:SetScript("OnEnterPressed", Apply)
  box:SetScript("OnEditFocusLost", function(self) Show(floor(s:GetValue() / step + .5) * step) end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  function s:Set(v)
    self.silent = true
    self:SetValue(v)
    self.silent = false
    Show(v)
  end
  return s
end

local Percent = "%"

-- A box being typed in lets go of the keyboard (what was typed is dropped): before another
-- class's settings show, as the game does on a click (not with a modifier key held).
function ns:EndTyping()
  local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  if focus and focus.ClearFocus then focus:ClearFocus() end
end

function InputBox(parent, w)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(w, 22)
  local e = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
  e:SetPoint("TOPLEFT", 6, -1)
  e:SetPoint("BOTTOMRIGHT", 0, 1)
  e:SetFontObject("ChatFontNormal")
  e:SetAutoFocus(false)
  e.holder = holder
  return e
end

local function NumberBox(parent, w, onEnter)
  local e = InputBox(parent, w)
  e:SetNumeric(true)
  e:SetMaxLetters(3)
  e:SetJustifyH("CENTER")
  e:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    self:ClearFocus() -- first, so the refresh can show the clamped value
    onEnter(text)
  end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Refresh() end)
  return e
end

local function Box(parent)
  return CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
end

local function SelectRow(tex, on)
  tex:SetShown(on and true or false) -- (a gradient set before would stay on a plain colour)
  if not on then return end
  tex:SetColorTexture(1, 1, 1, 1)
  if CreateColor and tex.SetGradient then
    tex:SetGradient("HORIZONTAL", CreateColor(1, .82, 0, .45), CreateColor(1, .82, 0, .05))
  else
    tex:SetColorTexture(1, .82, 0, .35)
  end
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

-- One of the game's menus, opened at the cursor by a click on a button of ours. A click on the
-- button while its menu is open closes it: left alone, the game would close the menu on the
-- press and open it again where the cursor is. (The menu frames are reused: still ours?)
local function MenuOpen(owner)
  local menu = owner.menu
  return menu ~= nil and menu:IsShown() and (not menu.GetOwnerRegion or menu:GetOwnerRegion() == owner)
end
local function OwnerHandlesPress(self, _, event)
  return event == "GLOBAL_MOUSE_DOWN" and MenuOpen(self)
end
local function ToggleMenu(owner, generator)
  if MenuOpen(owner) then
    owner.menu:Close()
    owner.menu = nil
    return
  end
  owner.HandlesGlobalMouseEvent = OwnerHandlesPress
  owner.menu = MenuUtil.CreateContextMenu(owner, generator)
end

---------------------------------------------------------------------------
-- Colour picker (Blizzard's: hue wheel, brightness bar, opacity slider)
---------------------------------------------------------------------------
-- The colour is read again at each change (a reset replaces the table) and only while the tab
-- it was opened on is shown; a tab change or the window closing closes the picker
-- (ClosePicker), keeping what was picked.
local pickerApply -- the picker's change handler while it is ours
local function OpenColorPicker(key)
  local profile = ns.db
  local c = profile.colors[key]
  local prev = { r = c.r, g = c.g, b = c.b, a = c.a }
  local function Target()
    if ns.db == profile then return profile.colors[key] end
  end
  local function changed()
    ns:ApplyColors()
    ns:RefreshOptions()
  end
  local function apply()
    -- the picker fires this once while being set up, before it holds this colour's opacity
    if not ColorPickerFrame:IsShown() then return end
    local now = Target()
    if not now then return end
    now.r, now.g, now.b = ColorPickerFrame:GetColorRGB()
    if ColorPickerFrame.GetColorAlpha then now.a = ColorPickerFrame:GetColorAlpha() end
    changed()
  end
  local function cancel()
    local now = Target()
    if not now then return end
    now.r, now.g, now.b, now.a = prev.r, prev.g, prev.b, prev.a
    changed()
  end
  pickerApply = apply
  ColorPickerFrame:SetupColorPickerAndShow({
    r = c.r, g = c.g, b = c.b, opacity = c.a, hasOpacity = true,
    swatchFunc = apply, opacityFunc = apply, cancelFunc = cancel,
  })
end

local function ClosePicker()
  if pickerApply and ColorPickerFrame and ColorPickerFrame:IsShown() and ColorPickerFrame.swatchFunc == pickerApply then
    ColorPickerFrame:Hide()
  end
  pickerApply = nil
end

local function ColorLabel(key)
  local i = key:match("^cp(%d)$")
  if i then return L.CP:format(tonumber(i)) end
  return L[COLOR_LABELS[key]]
end

-- One colour: its box (turned off: the part is not drawn and takes no room, ns:SetElementOn),
-- label, swatch (opens the picker), opacity slider. label(): its text (default: the part's
-- name); boxed(): whether it has a box (default: yes; a bar of a single part is switched in the
-- list of bars). Returns its holder and refresh.
local function ColorRow(parent, key, labelFn, boxed)
  local holder = Holder(parent, 28)
  local on = Check(holder, nil, function(v) ns:SetElementOn(key, v) end)
  on:SetPoint("TOPLEFT", 2, 1)
  local label = Text(holder, "")
  label:SetPoint("TOPLEFT", 20, 0)
  label:SetWidth(114)
  label:SetWordWrap(true)
  label:SetMaxLines(2)

  local swatch = CreateFrame("Button", nil, holder)
  swatch:SetSize(34, 16)
  swatch:SetPoint("TOPLEFT", 136, 2)
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

  local slider = Slider(holder, 80, 0, 100, 1, Percent, function(v)
    local c = ns.db.colors[key]
    c.a = v / 100
    ns:ApplyColors()
    ns:RefreshOptions() -- (the bars' swatches in the Bars list too)
  end)
  slider:SetPoint("LEFT", holder, "TOPLEFT", 178, -6)
  holder.on, holder.swatch, holder.slider, holder.label = on, swatch, slider, label

  return holder, function()
    local c = ns.db.colors[key]
    local shown = ns:ElementOn(key)
    on:SetShown(not boxed or boxed())
    on:Set(shown)
    label:SetText(labelFn and labelFn() or ColorLabel(key))
    if shown then label:SetTextColor(GOLD_R, GOLD_G, GOLD_B) else label:SetTextColor(.5, .5, .5) end
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
    slider:Set(floor(c.a * 100 + .5))
  end
end

---------------------------------------------------------------------------
-- Font: a dropdown, the game's menu listing every font, each name drawn in its own font
---------------------------------------------------------------------------
-- The menu's texts can't take a font file (the game forbids SetFont on them): each font gets a
-- font object of its own, made the first time the list opens.
local fontObjects, fontCount = {}, 0
local function FontObject(f)
  local key = f.path .. "|" .. (f.preview or 13)
  local fo = fontObjects[key]
  if fo == nil then
    fo = false
    if CreateFont then
      fontCount = fontCount + 1
      local made = CreateFont("ClaraComboPointsMenuFont" .. fontCount)
      local ok = made:SetFont(f.path, f.preview or 13, "")
      if ok ~= false and made:GetFont() then fo = made end
    end
    fontObjects[key] = fo
  end
  return fo or nil
end

local function FontChoice(parent, w)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 22)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, .5)
  AddBorder(b, .4, .4, .45, 1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .1)
  local arrow = b:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(18, 18)
  arrow:SetPoint("RIGHT", 1, 0)
  arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", 6, 0)
  b.text:SetPoint("RIGHT", arrow, "LEFT", 0, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  local shown -- the font the button is drawn in
  local function Pick(name)
    ns.db.font = name
    ns:ApplyFont()
    panel:Refresh()
  end
  -- the font chosen, its name drawn in it (a font that fails to load: the game's)
  function b:Refresh()
    local fonts, now = ns:GetFonts(), nil
    for _, f in ipairs(fonts) do if f.name == ns.db.font then now = f end end
    now = now or fonts[1]
    if not now then return end
    if shown ~= now.path then
      shown = now.path
      local ok = self.text:SetFont(now.path, min(14, now.preview or 13), "")
      if ok == false or not self.text:GetFont() then self.text:SetFontObject(GameFontHighlightSmall) end
    end
    self.text:SetText(now.name)
  end
  b:SetScript("OnClick", function(self)
    ClickSound()
    local fonts = ns:GetFonts()
    if not (MenuUtil and MenuUtil.CreateContextMenu) then -- no menus in this client: the next font
      local n = 1
      for i, f in ipairs(fonts) do if f.name == ns.db.font then n = i % #fonts + 1 end end
      if fonts[n] then Pick(fonts[n].name) end
      return
    end
    ToggleMenu(self, function(_, root)
      if root.SetScrollMode then root:SetScrollMode(FONT_MENU_H) end
      for _, f in ipairs(fonts) do
        local radio = root:CreateRadio(f.name, function() return ns.db.font == f.name end, function() Pick(f.name) end)
        local fo = FontObject(f)
        if fo and radio and radio.AddInitializer then
          radio:AddInitializer(function(button)
            if button.fontString then button.fontString:SetFontObject(fo) end
          end)
        end
      end
    end)
  end)
  return b
end

---------------------------------------------------------------------------
-- Icon rows editor: one line per row, icons in their order
---------------------------------------------------------------------------
local ICON_X, ICON_STEP = 90, 24 -- first icon of a line, and spacing
local COUNT_W, LINE_H = 50, 28   -- a line's count of icons, on its right; a line of icons's height
local lines = {}                 -- the six row lines: { side, k, frame, refresh }
local drag                       -- icon being dragged: where from (or a new one), where it would land
local ghost                      -- the dragged icon, following the cursor
local catalog                    -- the class spells panel, beside the window
local FitSidePanel                -- (window, below)

local function OnName(on) return L["ON_" .. on:upper()] end

local function IconTooltip(self)
  if not GameTooltip or drag then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  local spell = self.spell
  local named
  local item = ns:ItemOf(spell)
  if item then -- an item: its own tooltip, then how to remove it
    if not (GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, item)) then
      GameTooltip:SetText(ns:SpellName(spell) or spell)
    end
    GameTooltip:AddLine(L.ICON_TIP, .6, .6, .65, true)
    GameTooltip:Show()
    return
  end
  if type(spell) == "number" and GameTooltip.SetSpellByID then
    named = pcall(GameTooltip.SetSpellByID, GameTooltip, spell)
  end
  if not named then GameTooltip:SetText(ns:SpellName(spell) or tostring(spell)) end
  if type(spell) == "number" then GameTooltip:AddLine("ID " .. spell, .6, .6, .65) end
  local ranks = ns:SpellRanks(spell)
  if ranks then
    local which = L.ALL_RANKS
    if type(self.entry) == "table" and self.entry.exact then
      for _, r in ipairs(ranks) do if r[2] == spell then which = L.RANK:format(r[1]) end end
    end
    GameTooltip:AddLine(which, .6, .6, .65)
  end
  GameTooltip:AddLine(L.WATCHED_ON:format(OnName(ns:EntryOn(self.entry))), GOLD_R, GOLD_G, GOLD_B)
  if ns:EntryMine(self.entry) then GameTooltip:AddLine(L.MINE_ONLY, GOLD_R, GOLD_G, GOLD_B) end
  GameTooltip:AddLine(L.ICON_TIP, .6, .6, .65, true)
  GameTooltip:Show()
end

-- Can the dragged icon go into this row? (a full row, or the same spell already there: no)
local function Accepts(side, k)
  if side == drag.side and k == drag.k then return true end
  local spells = ns.db.rows[side][k]
  return #spells < ns.MAX_ICONS and not ns:IsDuplicate(spells, drag.entry)
end

-- What a line shows: its icons; while dragging, without the dragged icon, and with the
-- dragged icon (faded) where it would land. Returns the list and that position.
local function Shown(side, k)
  local spells = ns.db.rows[side][k]
  if not drag then return spells end
  local list = {}
  for i, entry in ipairs(spells) do
    if not (side == drag.side and k == drag.k and i == drag.i) then list[#list + 1] = entry end
  end
  if drag.toSide == side and drag.toK == k then
    local at = min(drag.toI, #list + 1)
    table.insert(list, at, drag.entry)
    return list, at
  end
  return list
end

local function CursorIn(frame)
  local x, y = GetCursorPosition()
  local scale = frame:GetEffectiveScale()
  x, y = x / scale, y / scale
  local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  if left and x >= left and x <= right and y >= bottom and y <= top then return x - left, top - y end
end

-- The place in a row's line under the cursor (x, y from its top left corner): the icons go on
-- as many lines as its width needs (a narrow window).
local function SlotAt(line, x, y, n)
  local per = line.perLine or ns.MAX_ICONS
  local col = max(0, min(per, floor((x - ICON_X) / ICON_STEP)))
  local row = max(0, floor((y - 3) / ICON_STEP))
  return max(1, min(n + 1, row * per + col + 1))
end

-- The landing place follows the cursor: the icon slot under it, in the line under it. An
-- icon of a row taken out of the window (and of the spells panel) is removed when let go.
local function TrackDrag()
  local toSide, toK, toI
  -- over the spells panel (which may lie on the window, unlocked): no row under it
  local overPanel = catalog and catalog:IsShown() and CursorIn(catalog)
  for _, line in ipairs(lines) do
    local x, y
    if not overPanel and line.frame:IsVisible() then x, y = CursorIn(line.frame) end
    if x and Accepts(line.side, line.k) then
      local n = #ns.db.rows[line.side][line.k]
      if line.side == drag.side and line.k == drag.k then n = n - 1 end
      toSide, toK = line.side, line.k
      toI = SlotAt(line, x, y, n)
      break
    end
  end
  -- out of the window: a row of the HUD under the cursor (Tracker.lua), the place marked there
  local overHud
  if not toSide and not overPanel and not CursorIn(panel) then
    local side, k, at, over = ns:HUDDropAt(drag.side and { side = drag.side, k = drag.k, i = drag.i })
    overHud = over
    if side and Accepts(side, k) then
      toSide, toK, toI = side, k, at
    elseif side then
      ns:HUDDropDone()
    end
  else
    ns:HUDDropDone()
  end
  local out = drag.side ~= nil and not toSide and not CursorIn(panel) and not overPanel and not overHud
  if toSide ~= drag.toSide or toK ~= drag.toK or toI ~= drag.toI or out ~= drag.out then
    drag.toSide, drag.toK, drag.toI, drag.out = toSide, toK, toI, out
    for _, line in ipairs(lines) do line.refresh() end
    ghost.tex:SetVertexColor(1, out and .35 or 1, out and .35 or 1)
    ghost.cross:SetShown(out)
  end
  local x, y = GetCursorPosition()
  local scale = panel:GetEffectiveScale()
  ghost:ClearAllPoints()
  ghost:SetPoint("CENTER", panel, "BOTTOMLEFT", x / scale - panel:GetLeft(), y / scale - panel:GetBottom())
end

-- A spell held on the cursor, picked up in the spellbook (or an action bar).
local function CursorSpell()
  if not GetCursorInfo then return end
  local kind, _, _, spellID = GetCursorInfo()
  if kind == "spell" and type(spellID) == "number" and spellID > 0 then return spellID end
end

-- Position under the cursor in a line (first free slot past the last icon).
local function SlotUnderCursor(line, n)
  local x, y = CursorIn(line.frame)
  if not x then return n + 1 end
  return SlotAt(line, x, y, n)
end

local status -- the icon page's message line
local function ShowStatus(ok, msg)
  status:SetText(msg or "")
  if ok then status:SetTextColor(.4, 1, .4) else status:SetTextColor(1, .45, .35) end
end

-- A spell dropped from the spellbook onto a row: added where it was dropped.
local function DropSpell(line)
  local spellID = CursorSpell()
  if not spellID then return false end
  selSide, selK = line.side, line.k
  local ok, msg = ns:AddIcon(line.side, line.k, spellID, SlotUnderCursor(line, #ns.db.rows[line.side][line.k]))
  if ok and ClearCursor then ClearCursor() end
  ShowStatus(ok, msg)
  panel:Refresh()
  return true
end

local function Remove(side, k, i)
  local entry = ns.db.rows[side][k][i]
  if entry == nil then return end
  local spell = ns:EntrySpell(entry)
  ns:RemoveIcon(side, k, i)
  ShowStatus(true, L.REMOVED:format(ns:SpellName(spell) or tostring(spell), ns:RowName(side, k)))
end

-- Released over a line: the icon moves (or a new one is added) there. Out of the window: an
-- icon of a row is removed. Anywhere else: it goes back.
local function EndDrag()
  if not drag then return end
  TrackDrag()
  local d = drag
  drag = nil
  ghost:Hide()
  ns:HoldForOptions(false) -- the HUD's rows close again
  if d.toSide then
    selSide, selK = d.toSide, d.toK
    if d.side then
      ns:MoveIconTo(d.side, d.k, d.i, d.toSide, d.toK, d.toI)
    else
      ShowStatus(ns:AddIcon(d.toSide, d.toK, d.entry, d.toI))
    end
  elseif d.out then
    Remove(d.side, d.k, d.i)
  end
  panel:Refresh()
end

local function StartDrag(entry, from)
  if GameTooltip then GameTooltip:Hide() end
  drag = { entry = entry }
  if from then drag.side, drag.k, drag.i = from.side, from.k, from.i end
  ghost.tex:SetTexture(ns:EntryIcon(ns:EntrySpell(entry)))
  ghost:Show()
  ns:HoldForOptions(true) -- the HUD's rows open for it, even locked (Tracker.lua)
  TrackDrag()
end

local function DragGhost(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(26, 26)
  f:SetFrameStrata("TOOLTIP")
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
  f.tex:SetTexCoord(.08, .92, .08, .92)
  f.cross = f:CreateTexture(nil, "OVERLAY") -- let go here: removed
  f.cross:SetSize(18, 18)
  f.cross:SetPoint("BOTTOMRIGHT", 6, -6)
  f.cross:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
  f.cross:Hide()
  f:SetAlpha(.85)
  f:Hide()
  -- the drop also ends here if the button that started the drag went away meanwhile
  f:SetScript("OnUpdate", function()
    if not drag then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then EndDrag() else TrackDrag() end
  end)
  return f
end

-- Click on an icon: where it is watched, its rank, remove (the game's menus).
local function IconMenu(b, side, k)
  local i, entry = b.index, b.entry
  local function Current() return ns.db.rows[side][k][i] end
  local function Change(spell, on, exact, mine)
    if Current() == nil then return end
    local ok, msg = ns:SetIconEntry(side, k, i, spell, on, exact, mine)
    if not ok then ShowStatus(false, msg) end
  end
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    -- no menus in this client: each click watches the next way (an item: nothing to change)
    if ns:ItemOf(ns:EntrySpell(entry)) then return end
    local now = ns:EntryOn(entry)
    for n, on in ipairs(ns.CONDITIONS) do
      if on == now then Change(nil, ns.CONDITIONS[n % #ns.CONDITIONS + 1]) break end
    end
    return
  end
  local spell = ns:EntrySpell(entry)
  if ns:ItemOf(spell) then -- an item: nothing to choose, only removed
    ToggleMenu(b, function(_, root)
      root:CreateTitle(ns:SpellName(spell) or tostring(spell))
      root:CreateButton(L.REMOVE, function()
        if Current() ~= nil then Remove(side, k, i) end
        panel:Refresh()
      end)
    end)
    return
  end
  ToggleMenu(b, function(_, root)
    root:CreateTitle(ns:SpellName(spell) or tostring(spell))
    for _, on in ipairs(ns.CONDITIONS) do
      root:CreateRadio(OnName(on), function() return ns:EntryOn(Current()) == on end, function() Change(nil, on) end)
    end
    root:CreateCheckbox(L.MINE_ONLY, function() return ns:EntryMine(Current()) end,
      function() Change(nil, nil, nil, not ns:EntryMine(Current())) end)
    local ranks = ns:SpellRanks(spell)
    if ranks then
      root:CreateDivider()
      local function Exact() local e = Current(); return type(e) == "table" and e.exact end
      root:CreateRadio(L.ALL_RANKS, function() return not Exact() end, function() Change(ranks[#ranks][2], nil, false) end)
      for _, r in ipairs(ranks) do
        root:CreateRadio(L.RANK:format(r[1]), function() return Exact() and ns:EntrySpell(Current()) == r[2] end,
          function() Change(r[2], nil, true) end)
      end
    end
    root:CreateDivider()
    root:CreateButton(L.REMOVE, function()
      if Current() ~= nil then Remove(side, k, i) end
      panel:Refresh()
    end)
  end)
end

local function IconLine(parent, side, k)
  local line = CreateFrame("Button", nil, parent)
  line:SetSize(FULL_W, LINE_H)
  line.bg = line:CreateTexture(nil, "BACKGROUND")
  line.bg:SetAllPoints()
  local hl = line:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .06)
  Text(line, function() return ns:RowName(side, k) end):SetPoint("TOPLEFT", 8, -8)
  local count = Hint(line, "")
  count:SetPoint("TOPRIGHT", -8, -9)
  local entry = { side = side, k = k, frame = line, perLine = ns.MAX_ICONS }
  line:SetScript("OnClick", function()
    ClickSound()
    if DropSpell(entry) then return end
    selSide, selK = side, k
    panel:Refresh()
  end)
  line:SetScript("OnReceiveDrag", function() DropSpell(entry) end)

  local icons = {}
  for i = 1, ns.MAX_ICONS do
    local b = CreateFrame("Button", nil, line)
    b:SetSize(22, 22)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexCoord(.08, .92, .08, .92)
    local hil = b:CreateTexture(nil, "HIGHLIGHT")
    hil:SetAllPoints()
    hil:SetColorTexture(1, 1, 1, .2)
    b.landing = b:CreateTexture(nil, "OVERLAY") -- where the dragged icon would land
    b.landing:SetPoint("TOPLEFT", -2, 2)
    b.landing:SetPoint("BOTTOMRIGHT", 2, -2)
    b.landing:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .35)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnReceiveDrag", function() DropSpell(entry) end)
    b:SetScript("OnClick", function(self, button)
      ClickSound()
      if DropSpell(entry) then return end
      selSide, selK = side, k
      if button == "RightButton" then
        Remove(side, k, self.index)
      else
        IconMenu(self, side, k)
      end
      panel:Refresh()
      if GameTooltip and GameTooltip:IsOwned(self) then
        if self:IsShown() then IconTooltip(self) else GameTooltip:Hide() end
      end
    end)
    b:SetScript("OnDragStart", function(self)
      if self.entry ~= nil then StartDrag(self.entry, { side = side, k = k, i = self.index }) end
    end)
    b:SetScript("OnDragStop", EndDrag)
    b:SetScript("OnEnter", IconTooltip)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    icons[i] = b
  end

  local function refresh()
    local list, landing = Shown(side, k)
    for i, b in ipairs(icons) do
      local e = list[i]
      b:SetShown(e ~= nil)
      if e ~= nil then
        b.index, b.entry, b.spell = i, e, ns:EntrySpell(e)
        b.tex:SetTexture(ns:EntryIcon(b.spell))
        b.tex:SetAlpha(i == landing and .4 or 1)
        b.landing:SetShown(i == landing)
      end
    end
    count:SetText(#ns.db.rows[side][k] .. " / " .. ns.MAX_ICONS)
    SelectRow(line.bg, selSide == side and selK == k)
  end
  entry.refresh = refresh
  -- as wide as the page lets it: the icons on as many lines as they need (all 20 room)
  function line:Wrap(width)
    self:SetWidth(width)
    local per = max(1, min(ns.MAX_ICONS, floor((width - ICON_X - COUNT_W) / ICON_STEP)))
    entry.perLine = per
    for i, b in ipairs(icons) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", ICON_X + ((i - 1) % per) * ICON_STEP, -3 - floor((i - 1) / per) * ICON_STEP)
    end
    self:SetHeight(LINE_H + (ceil(ns.MAX_ICONS / per) - 1) * ICON_STEP)
  end
  line:Wrap(FULL_W)
  lines[#lines + 1] = entry
  return refresh, line
end

---------------------------------------------------------------------------
-- Class spells panel, beside the window on the icons page: every buff and debuff of each
-- class, with its rank and where to watch it, to drag onto a row (or click: add it to the
-- selected row).
---------------------------------------------------------------------------
local SIDE_ROW_H, SIDE_HEAD_H = 26, 24
local CLASS_COLORS = {
  PRIEST = { 1, 1, 1 }, MAGE = { .25, .78, .92 }, WARLOCK = { .53, .53, .93 }, ROGUE = { 1, .96, .41 },
  DRUID = { 1, .49, .04 }, HUNTER = { .67, .83, .45 }, SHAMAN = { 0, .44, .87 }, PALADIN = { .96, .55, .73 },
  WARRIOR = { .78, .61, .43 },
}
local KIND_ON = { BUFF = "self", DEBUFF = "enemy", SELFDEBUFF = "self", SPELL = "self", IMBUE = "self" } -- where to watch by default
-- the lists past the classes: the spellbook's General tab, and the races (Alliance in blue,
-- Horde in red)
local GROUP_COLORS = { GENERAL = { GOLD_R, GOLD_G, GOLD_B } }
for _, race in ipairs({ "HUMAN", "DWARF", "NIGHTELF", "GNOME", "SKYBORNE_ALLIANCE" }) do GROUP_COLORS[race] = { .35, .6, 1 } end
for _, race in ipairs({ "ORC", "UNDEAD", "TAUREN", "TROLL", "SKYBORNE_HORDE" }) do GROUP_COLORS[race] = { 1, .35, .3 } end
local PICK_ON = { "self", "target", "enemy", "friend" }
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"

-- Alphabetical order for names in any language: accented letters sorted with their plain
-- letter (É with E), case aside.
local ACCENTS = {}
for plain, letters in pairs({ a = "àáâãäåÀÁÂÃÄÅ", c = "çÇ", e = "èéêëÈÉÊË", i = "ìíîïÌÍÎÏ", n = "ñÑ", o = "òóôõöøÒÓÔÕÖØ",
  u = "ùúûüÙÚÛÜ", y = "ýÿÝ", ss = "ß" }) do
  for ch in letters:gmatch("[\192-\223][\128-\191]") do ACCENTS[ch] = plain end
end
local sortKeys = {}
local function SortKey(name)
  local key = sortKeys[name]
  if not key then
    key = name:gsub("[\192-\223][\128-\191]", ACCENTS):lower()
    sortKeys[name] = key
  end
  return key
end

-- A small dropdown: the value, and the game's menu of choices on click (without menus, each
-- click shows the next choice). options(): { { value, text }, ... }
local function Choice(parent, w, options, get, set)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 20)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, .5)
  AddBorder(b, .4, .4, .45, 1)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .1)
  local arrow = b:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(18, 18)
  arrow:SetPoint("RIGHT", 1, 0)
  arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", 5, 0)
  b.text:SetPoint("RIGHT", arrow, "LEFT", 0, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  function b:Refresh()
    local now = get()
    self.text:SetText("")
    for _, o in ipairs(options()) do
      if o[1] == now then self.text:SetText(o[2]) end
    end
  end
  local function Pick(v)
    set(v)
    b:Refresh()
  end
  b:SetScript("OnClick", function(self)
    ClickSound()
    local list = options()
    if MenuUtil and MenuUtil.CreateContextMenu then
      ToggleMenu(self, function(_, root)
        for _, o in ipairs(list) do
          root:CreateRadio(o[2], function() return get() == o[1] end, function() Pick(o[1]) end)
        end
      end)
    else
      local now, n = get(), 1
      for i, o in ipairs(list) do if o[1] == now then n = i % #list + 1 end end
      Pick(list[n][1])
    end
  end)
  return b
end

local function Catalog(p)
  local f = CreateFrame("Frame", "ClaraComboPointsSpells", p, "DefaultPanelTemplate")
  f:SetSize(CatW(), WinH())
  f:SetPoint("TOPLEFT", p, "TOPRIGHT", 0, 0)
  f:EnableMouse(true)
  f:Hide()
  if f.Bg then f.Bg:SetVertexColor(.32, .32, .34) end
  OnRelabel(function()
    if f.SetTitle then f:SetTitle(L.CATALOG) else f.TitleContainer.TitleText:SetText(L.CATALOG) end
  end)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 1, 0)
  close:SetScript("OnClick", function()
    ClickSound()
    f.closed = true
    p:Refresh()
  end)

  local Layout, Unfold
  -- only the spells this character has in its spellbook (its race's and the General tab's too)
  local knownOnly = Check(f, Tr("CATALOG_KNOWN_ONLY"), function(on)
    ns.sv.catalog.knownOnly = on or nil
    Unfold()
    f.scrollTo = editing
    Layout()
  end)
  knownOnly:SetPoint("TOPLEFT", 18, -36)
  f.knownOnly = knownOnly

  local hint = Hint(f, Tr("CATALOG_HINT"))
  hint:SetPoint("TOPLEFT", 16, -54)
  hint:SetWidth(CatW() - 32) -- (the panel's width: f:Fit)
  hint:SetWordWrap(true)

  -- Search: a name in the game's language, English, French or German, whole or in part,
  -- accents and case aside; or a spell ID.
  local query = "" -- search key (ns:SearchKey), "" for the whole list
  local search = InputBox(f, CatW() - 32)
  search:SetMaxLetters(60)
  search.holder:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8) -- (under the help, however long)
  local placeholder = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  placeholder:SetPoint("LEFT", 2, 0)
  placeholder:SetPoint("RIGHT", -20, 0)
  placeholder:SetJustifyH("LEFT")
  placeholder:SetWordWrap(false)
  OnRelabel(function() placeholder:SetText(L.CATALOG_SEARCH) end)
  local clear = CreateFrame("Button", nil, search.holder)
  clear:SetSize(16, 16)
  clear:SetPoint("RIGHT", -3, 0)
  local cross = clear:CreateTexture(nil, "ARTWORK")
  cross:SetAllPoints()
  cross:SetTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
  clear:SetScript("OnClick", function()
    search:SetText("")
    search:ClearFocus()
  end)

  local inset = Box(f)
  inset:SetPoint("TOPLEFT", search.holder, "BOTTOMLEFT", -6, -28) -- (room for the column titles)
  inset:SetPoint("BOTTOMRIGHT", -10, 26) -- (its corner grip under it)
  local scroll = CreateFrame("ScrollFrame", "ClaraComboPointsSpellsScroll", inset, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -6)
  scroll:SetPoint("BOTTOMRIGHT", -26, 6)
  local BASE_CHILD_W = SIDE_W - 20 - 4 - 26
  local CHILD_W = BASE_CHILD_W -- (the panel's width: f:Fit)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(CHILD_W, 10)
  scroll:SetScrollChild(child)
  local noMatch = Hint(child, Tr("CATALOG_NONE"))
  noMatch:SetPoint("TOP", 0, -12)

  -- column titles, over the list (a wider panel: the names get the room)
  local RANK_X, ON_X, MINE_X = 140, 236, CHILD_W - 22
  Text(f, Tr("CATALOG_SPELL")):SetPoint("TOPLEFT", inset, "TOPLEFT", 4 + 32, 14)
  local rankTitle = Text(f, Tr("CATALOG_RANK"))
  local onTitle = Text(f, Tr("CATALOG_ON"))
  local mineTitle = Text(f, Tr("CATALOG_MINE"))
  mineTitle:SetJustifyH("RIGHT")
  local function PlaceTitles()
    rankTitle:ClearAllPoints()
    rankTitle:SetPoint("TOPLEFT", inset, "TOPLEFT", 4 + RANK_X, 14)
    onTitle:ClearAllPoints()
    onTitle:SetPoint("TOPLEFT", inset, "TOPLEFT", 4 + ON_X, 14)
    mineTitle:ClearAllPoints()
    mineTitle:SetPoint("TOPRIGHT", inset, "TOPLEFT", 4 + CHILD_W, 14)
  end
  PlaceTitles()

  local groups, expanded, picks, rowOf = {}, {}, {}, {}

  -- what a spell of the list adds: its rank (all by default), watched where chosen, yours only
  -- or anyone's
  local function Entry(rec)
    local pick = picks[rec]
    local id = pick.rank > 0 and rec.ranks[pick.rank][2] or rec.ranks[#rec.ranks][2]
    return { spell = id, on = pick.on, exact = pick.rank > 0 or nil, mine = pick.mine or nil }
  end

  local function SpellRow(rec)
    local row = CreateFrame("Button", nil, child)
    row:SetSize(CHILD_W, SIDE_ROW_H)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, .06)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(.08, .92, .08, .92)
    icon:SetTexture(ns:EntryIcon(rec.ranks[#rec.ranks][2]))
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", 32, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)
    if name.SetMaxLines then name:SetMaxLines(2) end
    picks[rec] = { rank = 0, on = KIND_ON[rec.kind] or "self", mine = false }
    if #rec.ranks > 1 then
      row.rank = Choice(row, ON_X - RANK_X - 6, function()
        local list = { { 0, L.ALL_RANKS } }
        for i, r in ipairs(rec.ranks) do list[#list + 1] = { i, L.RANK:format(r[1]) } end
        return list
      end, function() return picks[rec].rank end, function(v) picks[rec].rank = v end)
    end
    row.on = Choice(row, MINE_X - ON_X - 6, function()
      local list = {}
      for _, on in ipairs(PICK_ON) do list[#list + 1] = { on, OnName(on) } end
      return list
    end, function() return picks[rec].on end, function(v) picks[rec].on = v end)
    -- cast by you only (else anyone's)
    local mine = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    mine:SetSize(22, 22)
    mine:SetScript("OnClick", function(self)
      ClickSound()
      picks[rec].mine = self:GetChecked() and true or false
    end)
    -- its columns where the panel's width puts them
    function row:Place()
      self:SetWidth(CHILD_W)
      name:SetWidth((#rec.ranks > 1 and RANK_X or ON_X) - 32 - 6) -- one rank: the rank column is free
      if self.rank then
        self.rank:ClearAllPoints()
        self.rank:SetPoint("LEFT", RANK_X, 0)
      end
      self.on:ClearAllPoints()
      self.on:SetPoint("LEFT", ON_X, 0)
      mine:ClearAllPoints()
      mine:SetPoint("LEFT", MINE_X, 0)
    end
    mine:SetScript("OnEnter", function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(L.MINE_ONLY)
      GameTooltip:AddLine(L.MINE_TIP, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    mine:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    row.mine = mine
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() StartDrag(Entry(rec)) end)
    row:SetScript("OnDragStop", EndDrag)
    row:SetScript("OnClick", function()
      ClickSound()
      ShowStatus(ns:AddIcon(selSide, selK, Entry(rec)))
      p:Refresh()
    end)
    row:SetScript("OnEnter", function(self)
      if not GameTooltip or drag then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local id = Entry(rec).spell
      if not (GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, id)) then GameTooltip:SetText(ns:CatalogName(rec)) end
      GameTooltip:AddLine(L["KIND_" .. rec.kind] or "", .6, .6, .65)
      GameTooltip:AddLine(L.CATALOG_ADD:format(ns:RowName(selSide, selK)), GOLD_R, GOLD_G, GOLD_B, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    function row:Refresh()
      name:SetText(ns:CatalogName(rec)) -- in the addon's language
      if self.rank then self.rank:Refresh() end
      self.on:Refresh()
      self.mine:SetChecked(picks[rec].mine)
    end
    row:Place()
    return row
  end

  -- A list's head: a click folds or unfolds it.
  local function Head(key, color, labelFn, recs)
    local head = CreateFrame("Button", nil, child)
    head:SetSize(CHILD_W, SIDE_HEAD_H)
    local bg = head:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(color[1], color[2], color[3], .14)
    local hl = head:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, .08)
    head.sign = head:CreateTexture(nil, "ARTWORK")
    head.sign:SetSize(14, 14)
    head.sign:SetPoint("LEFT", 5, 0)
    local label = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 26, 0)
    label:SetTextColor(color[1], color[2], color[3])
    OnRelabel(function() label:SetText(labelFn()) end)
    local count = Hint(head, "")
    count:SetPoint("RIGHT", -8, 0)
    local g = { class = key, head = head, recs = recs, count = count }
    head:SetScript("OnClick", function()
      ClickSound()
      expanded[g.class] = not expanded[g.class]
      Layout()
    end)
    groups[#groups + 1] = g
    return g
  end

  for _, class in ipairs(ns.SPELL_CATALOG or {}) do
    local recs, seen = {}, {}
    for _, spell in ipairs(class.spells) do
      local rec = ns:CatalogEntryRecord(spell) -- spells this client does not know are left out
      if rec and not seen[rec] then seen[rec] = true; recs[#recs + 1] = rec end
    end
    if #recs > 0 then
      local color = CLASS_COLORS[class.class] or GROUP_COLORS[class.class] or { GOLD_R, GOLD_G, GOLD_B }
      Head(class.class, color, function()
        local race = class.class ~= "GENERAL" and L["GROUP_" .. class.class] -- (a race: its racial abilities)
        return L["CLASS_" .. class.class] or (race and L.GROUP_RACIAL:format(race)) or L["GROUP_" .. class.class] or class.class
      end, recs)
    end
  end

  -- The panel's width (sv.catalog.w): the list, the search box and the columns follow it, the
  -- names taking the room past the default width.
  function f:Fit()
    local w = self:GetWidth()
    CHILD_W = max(BASE_CHILD_W - 40, w - 20 - 4 - 26)
    local extra = CHILD_W - BASE_CHILD_W
    RANK_X, ON_X, MINE_X = 140 + extra, 236 + extra, CHILD_W - 22
    child:SetWidth(CHILD_W)
    hint:SetWidth(w - 32)
    search.holder:SetWidth(w - 32)
    PlaceTitles()
    for _, g in ipairs(groups) do g.head:SetWidth(CHILD_W) end
    for _, row in pairs(rowOf) do row:Place() end
  end

  -- alphabetical in the addon's language
  local function ByName(a, b)
    local ka, kb = SortKey(ns:CatalogName(a)), SortKey(ns:CatalogName(b))
    if ka ~= kb then return ka < kb end
    return a.ranks[1][2] < b.ranks[1][2]
  end

  -- Does the character have this spell (a rank of it)?
  local function KnownRec(rec)
    for _, r in ipairs(rec.ranks) do
      for n = 2, 3 do
        local id = r[n]
        if id and ((IsPlayerSpell and IsPlayerSpell(id))
          or (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) == true)) then
          return true
        end
      end
    end
    return false
  end

  -- The spells of a list the character knows (the Skyborne list of the other faction: none,
  -- both knowing Walk on Air).
  local function KnownOf(g)
    local known = {}
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if g.class == (faction == "Alliance" and "SKYBORNE_HORDE" or faction == "Horde" and "SKYBORNE_ALLIANCE") then return known end
    for _, rec in ipairs(g.recs) do if KnownRec(rec) then known[#known + 1] = rec end end
    return known
  end

  -- Which lists are unfolded: the tab's class; known spells only, every list with a known spell.
  function Unfold()
    wipe(expanded)
    if not ns.sv.catalog.knownOnly then
      expanded[editing] = true
      return
    end
    for _, g in ipairs(groups) do
      if #KnownOf(g) > 0 then expanded[g.class] = true end
    end
  end

  -- The classes, each with its spells when unfolded. While searching: only the spells found,
  -- in their classes, all unfolded. Known spells only: every list still there, a list with known
  -- spells showing only those (unfolded by Unfold), the others all their spells (folded).
  function Layout()
    local y = 0
    local searching = query ~= ""
    local only = ns.sv.catalog.knownOnly
    knownOnly:Set(only)
    for _, g in ipairs(groups) do
      local pool = g.recs
      if only then
        local known = KnownOf(g)
        if #known > 0 then pool = known end
      end
      local list, total = {}, #pool
      for _, rec in ipairs(pool) do
        if not searching or ns:CatalogMatches(rec, query) then list[#list + 1] = rec end
      end
      table.sort(list, ByName)
      local visible = #list > 0
      local open = visible and (searching or expanded[g.class])
      g.head:SetShown(visible)
      g.count:SetText(searching and (#list .. " / " .. total) or tostring(total))
      if visible then
        g.head:ClearAllPoints()
        g.head:SetPoint("TOPLEFT", 0, -y)
        g.head.sign:SetTexture(open and MINUS or PLUS)
        if g.class == f.scrollTo then f.scrollY = y end
        y = y + SIDE_HEAD_H + 2
      end
      local shown = {}
      g.rows = {} -- (the group's rows: shown ones first, in their order)
      if open then
        for _, rec in ipairs(list) do
          local row = rowOf[rec] or SpellRow(rec)
          rowOf[rec] = row
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", 0, -y)
          row:Show()
          row:Refresh()
          shown[row] = true
          g.rows[#g.rows + 1] = row
          y = y + SIDE_ROW_H
        end
        y = y + 4
      end
      for _, rec in ipairs(g.recs) do
        local row = rowOf[rec]
        if row and not shown[row] then
          row:Hide()
          g.rows[#g.rows + 1] = row
        end
      end
    end
    noMatch:SetShown(searching and y == 0)
    child:SetHeight(max(y, 40))
    -- a new class on the tab: its spells at the top of the list
    if f.scrollTo and not searching then
      local maxScroll = max(0, y - scroll:GetHeight())
      scroll:SetVerticalScroll(min(f.scrollY or 0, maxScroll))
    end
    f.scrollTo, f.scrollY = nil, nil
  end
  OnRelabel(function() Layout() end)

  local function ShowPlaceholder()
    placeholder:SetShown(search:GetText() == "" and not search:HasFocus())
    clear:SetShown(search:GetText() ~= "")
  end
  search:SetScript("OnTextChanged", function(self)
    local key = ns:SearchKey(self:GetText())
    ShowPlaceholder()
    if key == query then return end
    query = key
    scroll:SetVerticalScroll(0)
    Layout()
  end)
  search:SetScript("OnEditFocusGained", ShowPlaceholder)
  search:SetScript("OnEditFocusLost", ShowPlaceholder)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  ShowPlaceholder()

  -- Shown with the icons page, unless closed. Opens on the tab's class (unfolded, the others
  -- folded, scrolled to it), and moves the window left if the panel would go past the
  -- screen's edge.
  function f:Sync(onPage)
    local want = onPage and not self.closed
    if not want then self.unfolded = nil end -- left the Icons page: back on the tab's class next time
    if want and self.unfolded ~= editing then
      Unfold()
      self.unfolded = editing
      self.scrollTo = editing
      if self:IsShown() then Layout() end
    end
    if want and not self:IsShown() then
      FitSidePanel()
      self:Show()
      Layout()
    elseif not want and self:IsShown() then
      self:Hide()
    end
  end
  -- a spell learned: the known spells again
  f:RegisterEvent("SPELLS_CHANGED")
  f:SetScript("OnEvent", function(self) if self:IsShown() and ns.sv.catalog.knownOnly then Layout() end end)
  f.groups = groups
  f.search = search
  return f
end

---------------------------------------------------------------------------
-- Export / import box: a profile as a line of text, shown selected to copy (Ctrl+C), or an
-- empty box to paste one into (Ctrl+V).
---------------------------------------------------------------------------
local TEXT_W, TEXT_H = 460, 270

local function TextDialog(p)
  local f = CreateFrame("Frame", nil, p, "DefaultPanelTemplate")
  f:SetSize(TEXT_W, TEXT_H)
  f:SetPoint("CENTER")
  f:SetFrameLevel(p:GetFrameLevel() + 60) -- over the pages and their widgets
  f:EnableMouse(true)
  f:Hide()
  if f.Bg then f.Bg:SetVertexColor(.32, .32, .34) end
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 1, 0)

  local hint = Hint(f, "")
  hint:SetPoint("TOPLEFT", 16, -32)
  hint:SetWidth(TEXT_W - 32)
  hint:SetWordWrap(true)

  local inset = Box(f)
  inset:SetPoint("TOPLEFT", 12, -72)
  inset:SetPoint("BOTTOMRIGHT", -12, 64)
  local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -28, 6)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(0)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(TEXT_W - 24 - 34)
  edit:SetHeight(10)
  scroll:SetScrollChild(edit)
  -- the scroll follows the cursor while typing or selecting
  edit:SetScript("OnCursorChanged", function(self, _, y, _, h)
    local top, view = scroll:GetVerticalScroll(), scroll:GetHeight()
    y = -y
    if y < top then
      scroll:SetVerticalScroll(y)
    elseif y + h > top + view then
      scroll:SetVerticalScroll(y + h - view)
    end
  end)
  edit:SetScript("OnEscapePressed", function() f:Hide() end)
  -- a click anywhere in the box puts the cursor in the text
  inset:EnableMouse(true)
  inset:SetScript("OnMouseDown", function() edit:SetFocus() end)

  local status = Text(f, "", "GameFontHighlightSmall")
  status:SetPoint("BOTTOMLEFT", 16, 44)
  status:SetWidth(TEXT_W - 32)

  local action = Button(f, "", 150, 22, function() if f.onAction then f.onAction(edit:GetText()) end end)
  action:SetPoint("BOTTOMLEFT", 16, 14)
  local closeBtn = Button(f, Tr("CLOSE"), 110, 22, function() f:Hide() end)
  closeBtn:SetPoint("BOTTOMRIGHT", -16, 14)

  local readOnly
  edit:SetScript("OnTextChanged", function(self, userInput)
    if readOnly and userInput then -- the export stays as it is: typing selects it again
      self:SetText(readOnly)
      self:HighlightText()
    end
  end)
  edit:SetScript("OnEditFocusGained", function(self) if readOnly then self:HighlightText() end end)
  f:SetScript("OnHide", function()
    edit:ClearFocus()
    readOnly = nil
  end)

  function f:SelectAll()
    edit:SetFocus()
    edit:HighlightText()
  end

  function f:ShowStatus(ok, msg)
    status:SetText(msg or "")
    if ok then status:SetTextColor(.4, 1, .4) else status:SetTextColor(1, .45, .35) end
  end

  -- title, hint, text (nil: an empty box to paste in), action button { label, fn(text) }
  function f:Open(title, hintText, text, actionLabel, onAction)
    if self.SetTitle then self:SetTitle(title) else self.TitleContainer.TitleText:SetText(title) end
    hint:SetText(hintText)
    readOnly = text
    edit:SetText(text or "")
    scroll:SetVerticalScroll(0)
    status:SetText("")
    action:SetText(actionLabel)
    self.onAction = onAction
    self:Show()
    edit:SetFocus()
    if text then edit:HighlightText() end
  end
  return f
end

---------------------------------------------------------------------------
-- Bars page: the bars of the tab's class, top to bottom (drag one to move it, its box shows it
-- or takes it off, a click picks it), and all about the bar picked: its size, its colours, and
-- what only that bar has.
---------------------------------------------------------------------------
local BAR_ROW_H = 30
local DEFAULT_BARS = ns.defaults.bars

local function BarName(key)
  if key == "combo" then return L.BAR_COMBO end
  if key == "power" then return L["BAR_POWER_" .. RESOURCE[editing]] end
  if key == "mana" then return L.BAR_MANA end
  return L.BAR_HEALTH
end

-- The bars this class has, in the profile's order.
local function ClassBars()
  local list = {}
  for _, key in ipairs(ns.db.bars.order) do
    if (key ~= "combo" or ns.COMBO_CLASSES[editing]) and (key ~= "power" or ns.POWER_CLASSES[editing])
      and (key ~= "mana" or ns.MANA_CLASSES[editing]) then list[#list + 1] = key end
  end
  return list
end

-- The class's bars put in a new order; the others (mana for a rogue...) keep their places.
local function SetClassOrder(list)
  local order, i = ns.db.bars.order, 0
  local listed = {}
  for _, key in ipairs(list) do listed[key] = true end
  for n, key in ipairs(order) do
    if listed[key] then
      i = i + 1
      order[n] = list[i]
    end
  end
  ns:ApplyLayout()
end

-- The colours of a bar the class has.
local function BarColorKeys(key)
  local list, never = {}, NO_COLOR[editing] or {}
  for _, k in ipairs(BAR_COLORS[key] or {}) do if not never[k] then list[#list + 1] = k end end
  return list
end

local function DefaultSize(key)
  local b, d = ns.db.bars[key], DEFAULT_BARS[key]
  b.width, b.height, b.scale = d.width, d.height, d.scale
end

-- The colour a bar of the list shows beside its name: the resource it shows, or the class's
-- colour for a health bar wearing it.
local function BarColor(key)
  if key == "health" and ns.db.healthClassColor then
    local r, g, b = ns:ClassColor(editing)
    return r, g, b, ns.db.colors.health.a
  end
  local part = key == "power" and (editing == "WARRIOR" and "rage" or "energy") or key
  local c = ns.db.colors[part]
  return c.r, c.g, c.b, c.a
end

local function BarsPage(p, page, OnRefresh)
  local box = Section(page, "BARS_ORDER", LEFT, -56)
  Wrapped(page, Tr("BARS_HINT")):SetPoint("TOPLEFT", LEFT, -78)
  local LIST_TOP = -114
  local list = CreateFrame("Frame", nil, page)
  list:SetPoint("TOPLEFT", LEFT, LIST_TOP)
  list:SetSize(COL_W, 4 * BAR_ROW_H)
  local picked = "power" -- the bar whose settings are shown
  local dragKey, dropAt  -- while a bar is dragged: it, and where it would go
  local rows = {}
  local Refresh

  -- the order shown: while dragging, the bar where it would land
  local function Shown()
    local keys = ClassBars()
    if not dragKey then return keys end
    local out = {}
    for _, key in ipairs(keys) do if key ~= dragKey then out[#out + 1] = key end end
    table.insert(out, max(1, min(dropAt or 1, #out + 1)), dragKey)
    return out
  end

  local function RowUnderCursor()
    local _, y = GetCursorPosition()
    y = y / list:GetEffectiveScale()
    local top = list:GetTop()
    if not top then return 1 end
    return max(1, min(#ClassBars(), floor((top - y) / BAR_ROW_H) + 1))
  end

  local function Drop()
    if not dragKey then return end
    local order = Shown()
    dragKey, dropAt = nil, nil
    SetClassOrder(order)
    p:Refresh()
  end

  for i = 1, 4 do
    local row = CreateFrame("Button", nil, list)
    row:SetSize(COL_W, BAR_ROW_H - 4)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * BAR_ROW_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, .06)
    -- a grip: three lines
    for g = 1, 3 do
      local line = row:CreateTexture(nil, "ARTWORK")
      line:SetColorTexture(.7, .7, .75, .9)
      line:SetSize(12, 2)
      line:SetPoint("LEFT", 8, 5 - (g - 1) * 5)
    end
    -- shown, or taken off: the other bars close up
    row.show = Check(row, nil, function(on) ns:SetBarOn(row.key, on) end)
    row.show:SetPoint("LEFT", 30, 0)
    row.name = Text(row, "", "GameFontHighlight")
    row.name:SetPoint("LEFT", 52, 0)
    -- its colours, as on the bar (a combo point each)
    row.swatches = {}
    for n = 1, 5 do
      local t = row:CreateTexture(nil, "ARTWORK")
      row.swatches[n] = t
    end
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnClick", function(self)
      ClickSound()
      picked = self.key
      p:Refresh() -- its settings on the right
    end)
    row:SetScript("OnDragStart", function(self)
      dragKey, dropAt = self.key, RowUnderCursor()
      Refresh()
    end)
    row:SetScript("OnDragStop", Drop)
    rows[i] = row
  end
  -- the drop follows the cursor; it also ends if the button that started it went away
  list:SetScript("OnUpdate", function()
    if not dragKey then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then Drop() return end
    local at = RowUnderCursor()
    if at ~= dropAt then
      dropAt = at
      Refresh()
    end
  end)
  page:HookScript("OnHide", function() dragKey, dropAt = nil, nil end)

  -- the bar picked, if the class shown has it, else its energy / rage bar (checked before the
  -- settings read it)
  local function CheckPicked()
    local keys = ClassBars()
    for _, key in ipairs(keys) do if key == picked then return end end
    picked = ns.POWER_CLASSES[editing] and "power" or keys[1] or "health"
  end
  OnRefresh(CheckPicked)

  -- every bar of the class: default sizes and colours, in one click
  local allBars = Button(page, Tr("DEFAULT_ALL_BARS"), 220, 22, function()
    for _, key in ipairs(ClassBars()) do DefaultSize(key) end
    ns:ApplyLayout()
    ns:ResetColors()
  end)
  local allHint = Wrapped(page, Tr("DEFAULT_ALL_HINT"))
  allHint:SetPoint("TOPLEFT", allBars, "BOTTOMLEFT", 0, -6)

  -- The bar picked: its size
  local R = Column(page)
  page.colR = R
  local detail = Section(R, nil, RIGHT, -56)
  local function SizeSlider(label, y, minV, maxV, unit, field, factor)
    Text(R, Tr(label)):SetPoint("TOPLEFT", RIGHT, y)
    local slider = Slider(R, 168, minV, maxV, 1, unit, function(v) -- boxes in line with the colours'
      ns.db.bars[picked][field] = v / factor
      ns:ApplyLayout()
    end)
    slider:SetPoint("LEFT", R, "TOPLEFT", RIGHT + 90, y - 6)
    OnRefresh(function() slider:Set(floor(ns.db.bars[picked][field] * factor + .5)) end)
    return slider
  end
  SizeSlider("BAR_WIDTH", -84, ns.MIN_BAR_W, ns.MAX_BAR_W, "", "width", 1)
  SizeSlider("BAR_HEIGHT", -112, ns.MIN_BAR_H, ns.MAX_BAR_H, "", "height", 1)
  SizeSlider("BAR_SCALE", -140, ns.MIN_BAR_SCALE, ns.MAX_BAR_SCALE, Percent, "scale", 100)
  Rule(R, RIGHT, -166)
  Text(R, Tr("COLORS")):SetPoint("TOPLEFT", RIGHT, -176)

  -- its colours, each part with a box if the bar has more than one (the rage or mana about to
  -- be spent always: it is shown or not)
  local function Boxed(key)
    return key == "cost" or key == "manaCost" or #ns:BarParts(picked, editing) > 1
  end
  local function Has(key)
    for _, k in ipairs(BarColorKeys(picked)) do if k == key then return true end end
    return false
  end
  local items = {}
  for _, bar in ipairs({ "combo", "power", "mana", "health" }) do
    for _, key in ipairs(BAR_COLORS[bar]) do
      local holder, refresh = ColorRow(R, key, nil, function() return Boxed(key) end)
      OnRefresh(refresh)
      items[#items + 1] = { frame = holder, height = 28, when = function() return Has(key) end }
      if key == "cost" then -- the spells that spend it
        local spells = Holder(R, 18)
        local names = Hint(spells, "")
        names:SetPoint("TOPLEFT", 20, -1)
        names:SetWidth(COL_W - 20)
        names:SetWordWrap(false)
        OnRefresh(function()
          local list = {}
          for _, id in ipairs(ns.PREDICTED_SPELLS[editing] or {}) do list[#list + 1] = ns:SpellName(id) end
          names:SetText(table.concat(list, ", "))
        end)
        items[#items + 1] = { frame = spells, height = 18, when = function() return Has("cost") end }
      elseif key == "manaCost" then -- which spells it counts
        local spells = Holder(R, 18)
        local hint = Hint(spells, Tr("MANA_COST_HINT"))
        hint:SetPoint("TOPLEFT", 20, -1)
        hint:SetWidth(COL_W - 20)
        hint:SetWordWrap(false)
        items[#items + 1] = { frame = spells, height = 18, when = function() return Has("manaCost") end }
      elseif key == "health" then -- or the class's colour
        local classColor = Holder(R, 26)
        local check = Check(classColor, Tr("CLASS_COLOR"), function(on)
          ns.db.healthClassColor = on
          ns:ApplyColors()
          p:Refresh()
        end)
        check:SetPoint("TOPLEFT", 2, -4)
        OnRefresh(function() check:Set(ns.db.healthClassColor) end)
        items[#items + 1] = { frame = classColor, height = 26, when = function() return picked == "health" end }
      end
    end
  end

  -- combo points: read on the target or on the player
  local source = Holder(R, 38)
  Text(source, Tr("SOURCE")):SetPoint("TOPLEFT", 0, -12)
  local srcTarget = Button(source, Tr("SOURCE_TARGET"), 124, 22, function() ns:SetComboSource("TARGET") end)
  srcTarget:SetPoint("TOPLEFT", 90, -6)
  local srcPlayer = Button(source, Tr("SOURCE_PLAYER"), 90, 22, function() ns:SetComboSource("PLAYER") end)
  srcPlayer:SetPoint("TOPLEFT", 220, -6)
  OnRefresh(function()
    srcTarget:SetActive(ns.db.cpSource == "TARGET")
    srcPlayer:SetActive(ns.db.cpSource == "PLAYER")
  end)
  items[#items + 1] = { frame = source, height = 38, when = function() return picked == "combo" end }

  -- this bar back to its default size, or colours
  local defaults = Holder(R, 36)
  Button(defaults, Tr("DEFAULT_SIZE"), 150, 22, function()
    DefaultSize(picked)
    ns:ApplyLayout()
    p:Refresh()
  end):SetPoint("TOPLEFT", 0, -10)
  Button(defaults, Tr("DEFAULT_COLORS"), 150, 22, function() ns:ResetColors(BarColorKeys(picked)) end):SetPoint("TOPLEFT", 160, -10)
  items[#items + 1] = { frame = defaults, height = 36 }
  OnRefresh(Stack(R, RIGHT, -196, items, detail))

  function Refresh()
    local keys = Shown()
    CheckPicked()
    for i, row in ipairs(rows) do
      local key = keys[i]
      row:SetShown(key ~= nil)
      if key then
        row.key = key
        row.name:SetText(BarName(key))
        local on = ns:BarOn(key)
        row.name:SetAlpha((key == dragKey) and .5 or (on and 1 or .55))
        row.show:Set(on)
        local combo = key == "combo"
        for n, t in ipairs(row.swatches) do
          t:ClearAllPoints()
          t:SetShown(combo or n == 1)
          if combo then
            local c = ns.db.colors["cp" .. n]
            t:SetSize(7, 10)
            t:SetPoint("RIGHT", -10 - (5 - n) * 8, 0)
            t:SetColorTexture(c.r, c.g, c.b, c.a)
          elseif n == 1 then
            t:SetSize(39, 10)
            t:SetPoint("RIGHT", -10, 0)
            t:SetColorTexture(BarColor(key))
          end
          t:SetAlpha(on and 1 or .3)
        end
        SelectRow(row.bg, key == picked or key == dragKey)
      end
    end
    local below = LIST_TOP - #keys * BAR_ROW_H - 8
    allBars:ClearAllPoints()
    allBars:SetPoint("TOPLEFT", page, "TOPLEFT", LEFT, below)
    box:Fit(below - 22 - 6 - (allHint:GetStringHeight() or 12))
    detail.title:SetText(BarName(picked))
  end
  OnRefresh(function() Refresh() end)
end

---------------------------------------------------------------------------
-- Icons page: their look, editing them on the bar, adding spells, the rows (and the class
-- spells panel beside it)
---------------------------------------------------------------------------
local function IconsPage(p, icons, OnRefresh)
  local lookBox = Section(icons, "ICON_LOOK", LEFT, -56)
  Text(icons, Tr("SHAPE")):SetPoint("TOPLEFT", LEFT, -80)
  local shapeButtons = {}
  for i, shape in ipairs(SHAPES) do
    local b = Button(icons, Tr("SHAPE_" .. shape), 104, 22, function()
      ns.db.icons.shape = shape
      ns:LayoutIcons()
      p:Refresh()
    end)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 108, -94)
    b.shape = shape
    shapeButtons[i] = b
  end
  Text(icons, Tr("ICON_SIZE")):SetPoint("TOPLEFT", LEFT, -130)
  local iconSize = Slider(icons, 160, 12, 64, 1, "", function(v)
    ns.db.icons.size = v
    ns:LayoutIcons()
  end)
  iconSize:SetPoint("LEFT", icons, "TOPLEFT", LEFT + 74, -136)
  local cellSize = Hint(icons, "") -- combo point shape: the size of a combo point, whatever the slider
  cellSize:SetPoint("TOPLEFT", LEFT + 74, -131)
  local timers = Check(icons, Tr("SHOW_TIMERS"), function(on)
    ns.db.icons.timers = on
    ns:SyncAuraButtons() -- the game's aura buttons too
    ns:UpdateIcons()
    p:Refresh()
  end)
  timers:SetPoint("TOPLEFT", LEFT, -160)
  -- countdown numbers on the icons: a percentage of the size that fits each icon
  local timerLabel = Text(icons, Tr("TIMER_SIZE"))
  timerLabel:SetPoint("TOPLEFT", LEFT + 21, -184)
  local timerSize = Slider(icons, 100, ns.MIN_TIMER, ns.MAX_TIMER, 5, Percent, function(v)
    ns.db.icons.timerSize = v
    ns:LayoutIcons()
  end)
  timerSize:SetPoint("LEFT", icons, "TOPLEFT", LEFT + 160, -190)
  local missing = Check(icons, Tr("SHOW_MISSING"), function(on)
    ns.db.icons.missing = on
    ns:UpdateIcons()
  end)
  missing:SetPoint("TOPLEFT", LEFT, -212)
  local reverse = Check(icons, Tr("REVERSE"), function(on)
    ns.db.icons.reverse = on
    ns:SyncAuraButtons() -- the game's aura buttons too
    ns:UpdateIcons()
  end)
  reverse:SetPoint("TOPLEFT", LEFT, -236)
  local bearFixed = Check(icons, Tr("BEAR_FIXED"), function(on) ns:SetBearIconsFixed(on) end)
  bearFixed:SetPoint("TOPLEFT", LEFT, -260)
  OnRefresh(function()
    local shape = ns.db.icons.shape
    for _, b in ipairs(shapeButtons) do b:SetActive(b.shape == shape) end
    local cell = shape == "CELL"
    iconSize:SetShown(not cell)
    iconSize.box.holder:SetShown(not cell)
    cellSize:SetShown(cell)
    local cw, ch = ns:ComboCellSize()
    cellSize:SetText(L.CELL_SIZE:format(floor(cw + .5), floor(ch + .5)))
    bearFixed:SetShown(editing == "DRUID")
    lookBox:Fit(editing == "DRUID" and -274 or -250)
    bearFixed:Set(ns.db.bearIconsFixed)
    reverse:Set(ns.db.icons.reverse)
    iconSize:Set(ns.db.icons.size)
    timers:Set(ns.db.icons.timers)
    timerSize:Set(ns.db.icons.timerSize)
    local on = ns.db.icons.timers -- the countdown's size: only with the countdown
    timerLabel:SetAlpha(on and 1 or .45)
    timerSize:SetAlpha(on and 1 or .45)
    timerSize.box.holder:SetAlpha(on and 1 or .45)
    if timerSize.unit then timerSize.unit:SetAlpha(on and 1 or .45) end
    missing:Set(ns.db.icons.missing)
  end)

  local R = Column(icons)
  icons.colR = R
  Section(R, "ADD_SPELL", RIGHT, -56, nil, -176)
  Hint(R, Tr("ADD_HINT")):SetPoint("TOPLEFT", RIGHT, -78)
  local input = InputBox(R, 180)
  input:SetMaxLetters(80)
  input.holder:SetPoint("TOPLEFT", RIGHT, -94)
  status = Text(R, "", "GameFontHighlightSmall") -- (upvalue shared with the drop handlers)
  status:SetPoint("TOPLEFT", RIGHT, -124)
  status:SetWidth(COL_W)
  OnRelabel(function() status:SetText("") end) -- a message in the old language would stay behind
  local function Add()
    local ok, msg = ns:AddIcon(selSide, selK, input:GetText())
    input:ClearFocus()
    if ok then input:SetText("") end
    ShowStatus(ok, msg)
  end
  input:SetScript("OnEnterPressed", Add)
  input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local addBtn = Button(R, "", 130, 22, Add)
  addBtn:SetPoint("TOPLEFT", RIGHT + 190, -94)
  local clearBtn = Button(R, Tr("CLEAR_ROW"), 150, 22, function() status:SetText(""); ns:ClearRow(selSide, selK) end)
  clearBtn:SetPoint("TOPLEFT", RIGHT, -152)
  local defaultBtn = Button(R, Tr("DEFAULT_ICONS"), 150, 22, function() status:SetText(""); ns:ResetIcons() end)
  defaultBtn:SetPoint("TOPLEFT", RIGHT + 160, -152)
  OnRefresh(function() addBtn:SetLabel(L.ADD .. " > " .. ns:RowName(selSide, selK)) end)

  -- Icons unlocked, for every class: spells dropped on the HUD's rows, icons moved or dragged
  -- off (Tracker.lua)
  local hudBox = Section(R, "ICONS_ON_HUD", RIGHT, -204)
  local onHud = Check(R, Tr("EDIT_ON_HUD"), function(on) ns:SetIconsLocked(not on) end)
  onHud:SetPoint("TOPLEFT", RIGHT, -228)
  local hudHint = Wrapped(R, Tr("ICONS_UNLOCKED_HINT"))
  hudHint:SetPoint("TOPLEFT", RIGHT, -246)
  OnRefresh(function()
    onHud:Set(not ns.db.iconsLocked)
    hudBox:Fit(-246 - (hudHint:GetStringHeight() or 24))
  end)

  -- The rows, across both columns under them (their width follows the window's: Reflow)
  local F = Column(icons)
  icons.colF = F
  local rowsBox = Section(F, "ROWS", LEFT, -324, FULL_W, -590)
  local catalogBtn = Button(F, Tr("CATALOG_OPEN"), 150, 22, function()
    catalog.closed = catalog:IsShown()
    p:Refresh()
  end)
  local rowsHint = Hint(F, Tr("ROWS_HINT"))
  rowsHint:SetPoint("TOPLEFT", LEFT, -344)
  local rowLines = {}
  for i, def in ipairs(ROW_LINES) do
    if def then
      local refresh, line = IconLine(F, def[1], def[2])
      OnRefresh(refresh)
      rowLines[i] = line
    else -- the bar, between the rows above and below it
      local bar = CreateFrame("Frame", nil, F)
      bar:SetSize(FULL_W, LINE_H)
      local barLabel = Hint(bar, Tr("ROW_BAR"))
      barLabel:SetPoint("LEFT", 8, 0)
      local rule = bar:CreateTexture(nil, "ARTWORK")
      rule:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .25)
      rule:SetHeight(1)
      rule:SetPoint("LEFT", barLabel, "RIGHT", 8, 0)
      rule:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
      bar.Wrap = bar.SetWidth
      rowLines[i] = bar
    end
  end
  local tip = Hint(F, Tr("ICON_TIP"))
  -- the rows as wide as width (both columns' width at most), each line as tall as it needs
  function F:Fit(width)
    width = min(FULL_W, width)
    rowsBox:SetWidth(width + 2 * PAD)
    catalogBtn:ClearAllPoints()
    catalogBtn:SetPoint("TOPRIGHT", F, "TOPLEFT", LEFT + width, -319)
    local y = -360
    for _, line in ipairs(rowLines) do
      line:Wrap(width)
      line:ClearAllPoints()
      line:SetPoint("TOPLEFT", F, "TOPLEFT", LEFT, y)
      y = y - line:GetHeight() - 2
    end
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", F, "TOPLEFT", LEFT, y - 6)
    tip:SetWidth(width)
    tip:SetWordWrap(true)
    rowsBox:Fit(y - 6 - max(14, tip:GetStringHeight() or 14))
  end
  F:Fit(FULL_W)
  ghost = DragGhost(p)
  catalog = Catalog(p)
  OnRefresh(function()
    catalog:Sync(page == ICONS_PAGE and not p.qolActive)
    catalogBtn:SetActive(catalog:IsShown())
  end)
end

---------------------------------------------------------------------------
-- Profiles of the tab being edited (Profiles page): named copies of all its settings, saved,
-- loaded, deleted, exported and imported.
---------------------------------------------------------------------------
local function ProfilesSection(p, bar, OnRefresh)
  local box = Section(bar, "PROFILES", LEFT, -56)
  local specCheck -- (below)
  local loaded = Hint(bar, "") -- the profile on the tab, and whether it changed since
  loaded:SetPoint("TOPLEFT", LEFT, -78)
  loaded:SetWidth(COL_W)
  loaded:SetWordWrap(false)
  local picked = {} -- per tab: the profile chosen in the list
  local function Picked()
    local name = picked[editing]
    if name and ns:HasProfile(editing, name) then return name end
    return ns:ActiveProfile(editing) or ns:ProfileNames(editing)[1]
  end
  local list = Choice(bar, 170, function()
    local options = {}
    for _, name in ipairs(ns:ProfileNames(editing)) do options[#options + 1] = { name, name } end
    return options
  end, Picked, function(name) picked[editing] = name; p:Refresh() end)
  list:SetPoint("TOPLEFT", LEFT, -95)
  -- the specialisations with a profile, under Export / Import; then the message, if any
  local specsLine = Hint(bar, "")
  specsLine:SetPoint("TOPLEFT", LEFT, -206)
  specsLine:SetWidth(COL_W)
  specsLine:SetWordWrap(true)
  local profStatus = Text(bar, "", "GameFontHighlightSmall")
  profStatus:SetWidth(COL_W)
  local shift = 0 -- the specialisation box hidden: what is under it moves up
  local function FitBox()
    local y = -202 + shift
    local specs = specsLine:GetText()
    specsLine:ClearAllPoints()
    specsLine:SetPoint("TOPLEFT", bar, "TOPLEFT", LEFT, -206 + shift)
    if specs and specs ~= "" then y = -206 + shift - (specsLine:GetStringHeight() or 12) - 4 end
    profStatus:ClearAllPoints()
    profStatus:SetPoint("TOPLEFT", bar, "TOPLEFT", LEFT, y - 2)
    local msg = profStatus:GetText()
    box:Fit((msg and msg ~= "") and (y - 2 - (profStatus:GetStringHeight() or 12)) or y)
  end
  local function ProfileStatus(ok, msg)
    profStatus:SetText(msg or "")
    if ok then profStatus:SetTextColor(.4, 1, .4) else profStatus:SetTextColor(1, .45, .35) end
    FitBox()
  end
  OnRelabel(function() ProfileStatus(true, "") end)

  local function Load(class, name)
    ProfileStatus(ns:LoadProfile(class, name))
  end
  -- Loading replaces the tab's settings: first a word if changes would be lost.
  local loadBtn = Button(bar, Tr("PROFILE_LOAD"), 72, 22, function()
    local class, name = editing, Picked()
    if not name then return end
    local active = ns:ActiveProfile(class)
    if active and ns:ProfileModified(class) then
      if active == name then
        ns:Ask(L.PROFILE_REVERT_ASK:format(name), false, { L.PROFILE_REVERT, function() Load(class, name) end }, { L.CANCEL })
      else
        ns:Ask(L.PROFILE_UNSAVED_ASK:format(active, name), false,
          { L.PROFILE_SAVE_LOAD, function()
            ns:SaveProfile(class, active)
            Load(class, name)
          end },
          { L.PROFILE_DONT_SAVE, function() Load(class, name) end },
          { L.CANCEL })
      end
    elseif not active and ns:SettingsUnsaved(class) then
      ns:Ask(L.PROFILE_REPLACE_ASK:format(L["TAB_" .. class], name), false,
        { L.PROFILE_LOAD, function() Load(class, name) end }, { L.CANCEL })
    else
      Load(class, name)
    end
  end)
  loadBtn:SetPoint("TOPLEFT", LEFT + 174, -94)
  local deleteBtn = Button(bar, Tr("PROFILE_DELETE"), 70, 22, function()
    local class, name = editing, Picked()
    if not name then return end
    ns:Ask(L.PROFILE_DELETE_ASK:format(name), true, { L.PROFILE_DELETE, function()
      ProfileStatus(ns:DeleteProfile(class, name))
    end }, { L.CANCEL })
  end)
  deleteBtn:SetPoint("TOPLEFT", LEFT + 250, -94)

  -- Save: under the name typed (the loaded profile's name to start with)
  local nameBox = InputBox(bar, 170)
  nameBox:SetMaxLetters(32)
  nameBox.holder:SetPoint("TOPLEFT", LEFT, -122)
  local function Save()
    local class, name = editing, ns.CleanProfileName(nameBox:GetText())
    nameBox:ClearFocus()
    if not name then
      ProfileStatus(false, L.PROFILE_NO_NAME)
      return
    end
    local tie = specCheck:IsShown() and specCheck.check:GetChecked() -- (before the save refreshes the box)
    local function Do()
      local ok, msg = ns:SaveProfile(class, name)
      picked[class] = name
      -- loaded by this specialisation, or no longer
      local spec = class == ns.homeClass and ns:CurrentSpec()
      if ok and spec then
        if tie then
          ns:SetSpecProfile(class, spec, name)
        elseif ns:SpecProfile(class, spec) == name then
          ns:SetSpecProfile(class, spec, nil)
        end
      end
      ProfileStatus(ok, msg)
      p:Refresh()
    end
    if ns:HasProfile(class, name) and name ~= ns:ActiveProfile(class) then
      ns:Ask(L.PROFILE_OVERWRITE_ASK:format(name), false, { L.PROFILE_OVERWRITE, Do }, { L.CANCEL })
    else
      Do()
    end
  end
  nameBox:SetScript("OnEnterPressed", Save)
  nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local saveBtn = Button(bar, Tr("PROFILE_SAVE"), 146, 22, Save)
  saveBtn:SetPoint("TOPLEFT", LEFT + 174, -122)

  -- Loaded in the character's specialisation (its class's tab only): ticked, the profile saved
  -- under the name typed loads when the character is in that specialisation; on a profile
  -- already saved, the tick applies at once.
  specCheck = Check(bar, nil, function(on)
    local class, name = editing, ns.CleanProfileName(nameBox:GetText())
    local spec = ns:CurrentSpec()
    if spec and name and ns:HasProfile(class, name) then
      if on then
        ns:SetSpecProfile(class, spec, name)
        ProfileStatus(true, L.PROFILE_SPEC_SET:format(name, ns:SpecName(spec)))
      elseif ns:SpecProfile(class, spec) == name then
        ns:SetSpecProfile(class, spec, nil)
        ProfileStatus(true, L.PROFILE_SPEC_UNSET:format(name, ns:SpecName(spec)))
      end
      p:Refresh()
    end
  end)
  specCheck:SetPoint("TOPLEFT", LEFT + 4, -156)

  local textBox = TextDialog(p)
  local exportBtn = Button(bar, Tr("PROFILE_EXPORT"), 158, 22, function()
    local name = Picked()
    if not name then return end
    local hint = L.PROFILE_EXPORT_HINT
    if name == ns:ActiveProfile(editing) and ns:ProfileModified(editing) then hint = hint .. " " .. L.PROFILE_EXPORT_UNSAVED end
    textBox:Open(L.PROFILE_EXPORT_TITLE:format(name), hint, ns:ExportProfile(editing, name), L.SELECT_ALL,
      function() textBox:SelectAll() end)
  end)
  exportBtn:SetPoint("TOPLEFT", LEFT, -176)
  local importBtn = Button(bar, Tr("PROFILE_IMPORT"), 158, 22, function()
    local class = editing
    textBox:Open(L.PROFILE_IMPORT_TITLE:format(L["TAB_" .. class]), L.PROFILE_IMPORT_HINT, nil, L.PROFILE_IMPORT, function(text)
      local ok, result = ns:ImportProfile(class, text)
      if not ok then
        textBox:ShowStatus(false, result)
        return
      end
      textBox:Hide()
      picked[class] = result
      ProfileStatus(true, L.PROFILE_IMPORTED_AS:format(result))
      p:Refresh()
    end)
  end)
  importBtn:SetPoint("TOPLEFT", LEFT + 162, -176)
  -- (a tab change or a language change closes the box: it belongs to the tab it opened on)
  OnRelabel(function() textBox:Hide() end)
  function p.ClearProfileMessages()
    ProfileStatus(true, "")
    textBox:Hide()
  end

  local shownName -- the name box follows the loaded profile, unless being typed in
  OnRefresh(function()
    local active, names = ns:ActiveProfile(editing), ns:ProfileNames(editing)
    if active then
      local modified = ns:ProfileModified(editing)
      loaded:SetText(L.PROFILE_ACTIVE:format(active) .. (modified and ("  |cffff9f40" .. L.PROFILE_MODIFIED .. "|r") or ""))
    else
      loaded:SetText(L.PROFILE_NONE_LOADED)
    end
    list:Refresh()
    if #names == 0 then list.text:SetText(L.PROFILE_EMPTY) end
    list.text:SetTextColor(#names == 0 and .5 or 1, #names == 0 and .5 or 1, #names == 0 and .5 or 1)
    local any = Picked() ~= nil
    loadBtn:SetEnabled(any)
    deleteBtn:SetEnabled(any)
    exportBtn:SetEnabled(any)
    if not nameBox:HasFocus() and shownName ~= (active or "") .. editing then
      shownName = (active or "") .. editing
      nameBox:SetText(active or "")
    end
    -- the specialisation box: for the character's own class, once it has a specialisation
    local spec, specName = nil, nil
    if editing == ns.homeClass and ns.enabled then spec, specName = ns:CurrentSpec() end
    specCheck:SetShown(spec ~= nil)
    shift = spec and 0 or 26
    exportBtn:ClearAllPoints()
    exportBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", LEFT, -176 + shift)
    importBtn:ClearAllPoints()
    importBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", LEFT + 162, -176 + shift)
    if spec then
      specCheck:SetLabel(L.PROFILE_SPEC:format(specName))
      local typed = ns.CleanProfileName(nameBox:GetText())
      specCheck:Set(typed ~= nil and ns:SpecProfile(editing, spec) == typed)
    end
    local specs = ns:SpecProfilesText(editing)
    specsLine:SetText(specs ~= "" and L.PROFILE_SPECS:format(specs) or "")
    FitBox()
  end)
  -- the name typed: the box says whether that profile is the specialisation's
  nameBox:HookScript("OnTextChanged", function()
    local spec = specCheck:IsShown() and ns:CurrentSpec()
    local typed = ns.CleanProfileName(nameBox:GetText())
    if spec then specCheck:Set(typed ~= nil and ns:SpecProfile(editing, spec) == typed) end
  end)
end

---------------------------------------------------------------------------
-- Where the window is (sv.window: its top left corner in UIParent units, nil = centred), its
-- size, scale and opacity; the spells panel beside it (on its right or its left), or on its
-- own (sv.catalog). Nothing is held on the screen: /cl reset pos (or the game's AddOns
-- options) brings them back.
---------------------------------------------------------------------------
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

-- Without a scale of its own, the window is as large as fits the screen with the spells
-- panel beside it, up to 100 %.
local function AutoScale()
  local width = UIParent:GetWidth()
  if width and width > 0 then return min(1, width / (WinW() + CatW())) end
  return 1
end

-- The spells panel: locked, beside the window (at its scale, as tall as it, moved and sized
-- with it), on the side it was locked on; or unlocked, where the player put it, at its own
-- scale and size whatever the window's.
local function CatalogFree()
  local c = ns.sv.catalog
  return not c.locked and c.left ~= nil
end

local function PlaceCatalog()
  if not catalog then return end
  local c = ns.sv.catalog
  catalog:ClearAllPoints()
  if CatalogFree() then
    catalog:SetScale(c.scale / panel:GetScale())
    catalog:SetSize(CatW(), CatH())
    catalog:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", c.left / c.scale, c.top / c.scale)
    catalog:SetFrameStrata("DIALOG") -- over the window if put on it
  else
    catalog:SetScale(1)
    catalog:SetWidth(CatW())
    if c.side == "left" then
      catalog:SetPoint("TOPRIGHT", panel, "TOPLEFT", 0, 0)
      catalog:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", 0, 0)
    else
      catalog:SetPoint("TOPLEFT", panel, "TOPRIGHT", 0, 0)
      catalog:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 0, 0)
    end
    catalog:SetFrameStrata(panel:GetFrameStrata())
  end
  catalog:Fit()
end

-- Unlocked: from then on the panel keeps the place, scale and height it has now, on its own.
local function FreeCatalog()
  local c = ns.sv.catalog
  if c.locked or c.left then return end
  local s = panel:GetScale() * catalog:GetScale()
  local left, top = catalog:GetLeft(), catalog:GetTop()
  if not (left and top) then return end
  c.left, c.top, c.scale, c.h = left * s, top * s, s, WinH()
  PlaceCatalog()
end

local function PlaceWindow()
  local w = ns.sv.window
  local s = w.scale or AutoScale()
  panel:SetScale(s)
  panel:ClearAllPoints()
  if w.left then
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", w.left / s, w.top / s)
  else
    panel:SetPoint("CENTER", UIParent, "CENTER")
  end
  panel:Resize() -- its size, the page laid out for it
  PlaceCatalog()
end

-- Remembers where the window is, after a drag or a change of scale.
local function SaveWindowPlace()
  local s = panel:GetScale()
  local left, top = panel:GetLeft(), panel:GetTop()
  if not (left and top) then return end
  ns.sv.window.left, ns.sv.window.top = left * s, top * s
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

-- The spells panel opens beside the window: if it would go past the screen's edge, the window
-- moves away from that edge (unless it is already partly off the screen, where it was put). A
-- panel with a place of its own stays where it was put.
function FitSidePanel()
  if CatalogFree() then return end
  local left, right, top, screen = panel:GetLeft(), panel:GetRight(), panel:GetTop(), UIParent:GetRight()
  if not (left and right and top and screen) then return end
  screen = screen / panel:GetScale() -- in the window's own units
  if left < 0 or right > screen then return end
  local w, place = CatW(), nil
  if ns.sv.catalog.side == "left" then
    if left - w < 0 then place = min(w, screen - (right - left)) end
  elseif right + w > screen then
    place = max(0, left - (right + w - screen))
  end
  if place then
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", place, top)
    SaveWindowPlace()
  end
end

function ns:SetWindowAlpha(alpha)
  alpha = min(1, max(self.MIN_WINDOW_ALPHA, alpha))
  self.sv.window.alpha = alpha
  if panel then panel:SetAlpha(alpha) end
end

-- nil: back to the size that fits the screen. The top left corner stays where it is (a
-- centred window stays centred).
function ns:SetWindowScale(scale)
  if scale then scale = min(self.MAX_WINDOW_SCALE, max(self.MIN_WINDOW_SCALE, scale)) end
  self.sv.window.scale = scale
  if panel then PlaceWindow() end
end

function ns:GetWindowScale()
  return self.sv.window.scale or (panel and panel:GetScale()) or AutoScale()
end

-- The window back to its default size and scale (and the spells panel's width: panelToo); its
-- top left corner stays where it is.
function ns:ResetWindowSize(panelToo)
  local w = self.sv.window
  w.scale, w.w, w.h = nil, nil, nil
  if panelToo then self.sv.catalog.w = nil end
  if panel then
    PlaceWindow()
    if catalog:IsShown() then FitSidePanel() end
  end
end

-- The window back in the middle of the screen, and the spells panel beside it.
function ns:ResetWindowPosition()
  self.sv.window.left, self.sv.window.top = nil, nil
  local c = self.sv.catalog
  c.left, c.top, c.scale, c.h = nil, nil, nil, nil
  if panel then
    PlaceWindow()
    if catalog:IsShown() then FitSidePanel() end
    if not c.locked then FreeCatalog() end -- still on its own, from beside the window
  end
end

-- After a reset of the whole addon: the window as it first opened.
function ns:ResetOptionsWindow()
  if not panel then return end
  PlaceWindow()
  panel:SetAlpha(self.sv.window.alpha)
  panel.PlaceNav() -- the pages in their default order too
  if catalog:IsShown() then FitSidePanel() end
end

-- The spells panel locked beside the window, or unlocked to be moved and sized on its own
-- (its lock, in its title bar). Locked again, it goes back beside the window, on the side it
-- is on: left of the window if its middle is left of the window's.
function ns:SetCatalogLocked(locked)
  local c = self.sv.catalog
  if locked and not c.locked and panel and CatalogFree() then
    local cx, px = catalog:GetCenter(), panel:GetCenter()
    c.side = nil
    if cx and px and cx * catalog:GetEffectiveScale() < px * panel:GetEffectiveScale() then c.side = "left" end
  end
  c.locked = locked and true or false
  if c.locked then c.left, c.top, c.scale, c.h = nil, nil, nil, nil end
  if panel then
    if c.locked then
      PlaceCatalog()
      if catalog:IsShown() then FitSidePanel() end
    else
      FreeCatalog()
    end
  end
  self:RefreshOptions()
end

-- A bottom right corner (the window's, the spells panel's). Held with the right mouse button
-- and dragged: what it sizes gets bigger or smaller (its scale); with the left button: wider or
-- narrower, taller or shorter (its width and height: the window's pages laid out again); a
-- double click: back to the default size and scale. Its top left corner stays put.
-- Target() returns { left, top: the corner that stays (UIParent units); scale; W, H: the
-- unscaled size up to the corner held; SetScale(s); w, h, minW, maxW, minH, maxH; SetSize(w, h);
-- Done(mode, changed); Reset() }.
local DOUBLE_CLICK = .4
local function SizeGrip(host, Target, beside) -- beside: the readout left of the corner
  local grip = CreateFrame("Button", nil, host)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -5, 5)
  grip:SetFrameLevel(host:GetFrameLevel() + 20)
  grip:SetNormalTexture(GRIP .. "Up")
  grip:SetPushedTexture(GRIP .. "Down")
  grip:SetHighlightTexture(GRIP .. "Highlight")
  local readout = grip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if beside then
    readout:SetPoint("RIGHT", grip, "LEFT", -4, 0)
  else
    readout:SetPoint("BOTTOMRIGHT", grip, "TOPRIGHT", 0, 18) -- over the window opacity, not on it
  end
  readout:Hide()
  local held, t, mode, offX, offY, x0, y0, changed
  local lastClick, lastX, lastY -- the last left press (a double click)
  local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
  end
  local function Follow()
    local x, y = Cursor()
    if mode == "scale" then
      -- the scale that puts the corner nearest the cursor (as it was held)
      x, y = x - offX, y - offY
      local s = ((x - t.left) * t.W + (t.top - y) * t.H) / (t.W * t.W + t.H * t.H)
      s = min(ns.MAX_WINDOW_SCALE, max(ns.MIN_WINDOW_SCALE, s))
      if math.abs(s - t.scale) > .0005 then changed = true end
      t.SetScale(s)
      readout:SetText(floor(s * 100 + .5) .. " %")
    else
      local w = floor(min(t.maxW, max(t.minW, t.w + (x - x0) / t.scale)) + .5)
      local h = floor(min(t.maxH, max(t.minH, t.h + (y0 - y) / t.scale)) + .5)
      if w ~= floor(t.w + .5) or h ~= floor(t.h + .5) then changed = true end
      if changed then t.SetSize(w, h) end
      readout:SetText(w .. " x " .. h)
    end
  end
  local function Stop()
    if not held then return end
    held = nil
    readout:Hide()
    grip:SetButtonState("NORMAL")
    t.Done(mode, changed)
  end
  grip:SetScript("OnMouseDown", function(_, button)
    if held then return end
    if GameTooltip then GameTooltip:Hide() end
    local x, y = Cursor()
    if button == "LeftButton" then
      local now = GetTime()
      if lastClick and now - lastClick < DOUBLE_CLICK and math.abs(x - lastX) < 4 and math.abs(y - lastY) < 4 then
        lastClick = nil
        local target = Target()
        if target then target.Reset() end
        return
      end
      lastClick, lastX, lastY = now, x, y
    end
    t = Target()
    if not t then return end
    mode, changed = button == "RightButton" and "scale" or "size", false
    if mode == "scale" then
      offX, offY = x - (t.left + t.W * t.scale), y - (t.top - t.H * t.scale)
    else
      x0, y0 = x, y
    end
    held = button
    grip:SetButtonState("PUSHED", true)
    readout:Show()
    Follow()
  end)
  grip:SetScript("OnMouseUp", Stop)
  grip:SetScript("OnHide", Stop)
  grip:SetScript("OnUpdate", function()
    if not held then return end
    if IsMouseButtonDown and not IsMouseButtonDown(held) then Stop() else Follow() end
  end)
  grip:SetScript("OnEnter", function(self)
    if not GameTooltip or held then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.SCALE_GRIP)
    GameTooltip:AddLine(L.SCALE_GRIP_TIP, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return grip
end

-- After a drag of a corner of the window (or of the panel locked beside it): its scale and
-- place kept (sized only: the scale it had, if it had none of its own).
local function WindowDone(s)
  return function(mode, changed)
    if not changed then return end
    local win = ns.sv.window
    if mode == "scale" then win.scale = panel:GetScale() else win.scale = win.scale or s end
    SaveWindowPlace()
  end
end

-- The window's corner: the window (with the spells panel if it is locked beside it).
local function WindowTarget()
  if not ns.sv.catalog.locked then FreeCatalog() end
  local s = panel:GetScale()
  local l, t = panel:GetLeft(), panel:GetTop()
  if not (l and t) then return end
  local left, top, win = l * s, t * s, ns.sv.window
  local function Pin(scale)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, top / scale)
  end
  return {
    left = left, top = top, scale = s, W = WinW(), H = WinH(),
    SetScale = function(new) panel:SetScale(new); Pin(new); PlaceCatalog() end,
    w = WinW(), h = WinH(), minW = ns.MIN_WINDOW_W, maxW = ns.MAX_WINDOW_W, minH = ns.MIN_WINDOW_H, maxH = ns.MAX_WINDOW_H,
    SetSize = function(w, h) win.w, win.h = w, h; Pin(s); panel:Resize() end,
    Done = WindowDone(s),
    Reset = function() ns:ResetWindowSize() end,
  }
end

-- The spells panel's corner: locked, the window and the panel together (the corner sizes the
-- panel's width and both heights); on its own, the panel alone.
local function CatalogTarget()
  local c = ns.sv.catalog
  if not c.locked then FreeCatalog() end
  if CatalogFree() then
    local left, top = c.left, c.top
    return {
      left = left, top = top, scale = c.scale, W = CatW(), H = CatH(),
      SetScale = function(new) c.left, c.top, c.scale = left, top, new; PlaceCatalog() end,
      w = CatW(), h = CatH(), minW = ns.MIN_SIDE_W, maxW = ns.MAX_SIDE_W, minH = ns.MIN_WINDOW_H, maxH = ns.MAX_WINDOW_H,
      SetSize = function(w, h) c.w, c.h = w, h; PlaceCatalog() end,
      Done = function() end,
      Reset = function() -- its default size, the window's scale; where it is
        c.w, c.h, c.scale = nil, WinH(), panel:GetScale()
        PlaceCatalog()
      end,
    }
  end
  local s = panel:GetScale()
  local l, t = panel:GetLeft(), panel:GetTop()
  if not (l and t) then return end
  local win, cw = ns.sv.window, CatW()
  local onLeft = c.side == "left"
  -- the corner that stays: the window's top left, or the panel's when it is on the left
  local left, top = (onLeft and l - cw or l) * s, t * s
  local function Pin(scale, width)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale + (onLeft and width or 0), top / scale)
  end
  return {
    left = left, top = top, scale = s, W = onLeft and cw or WinW() + cw, H = WinH(),
    SetScale = function(new) panel:SetScale(new); Pin(new, cw); PlaceCatalog() end,
    w = cw, h = WinH(), minW = ns.MIN_SIDE_W, maxW = ns.MAX_SIDE_W, minH = ns.MIN_WINDOW_H, maxH = ns.MAX_WINDOW_H,
    SetSize = function(w, h)
      c.w, win.h = w, h
      Pin(s, w)
      panel:Resize()
      PlaceCatalog()
    end,
    Done = WindowDone(s),
    Reset = function() ns:ResetWindowSize(true) end,
  }
end

-- The spells panel's own controls: its lock in the title bar, moving it by its title (the
-- whole window while it is locked) and its corner.
local LOCK = "Interface\\Buttons\\LockButton-"
local function CatalogControls(p)
  local f = catalog
  f:SetMovable(true)
  f:SetClampedToScreen(false)
  if f.SetDontSavePosition then f:SetDontSavePosition(true) end
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if ns.sv.catalog.locked then
      self.moving = "window"
      p:StartMoving()
    else
      FreeCatalog()
      self.moving = "panel"
      self:StartMoving()
    end
  end)
  local function StopMoving(self)
    local what = self.moving
    self.moving = nil
    if what == "window" then
      p:StopMovingOrSizing()
      SaveWindowPlace()
    elseif what == "panel" then
      self:StopMovingOrSizing()
      local c = ns.sv.catalog
      local s = p:GetScale() * self:GetScale()
      local left, top = self:GetLeft(), self:GetTop()
      if left and top and not c.locked then c.left, c.top = left * s, top * s end
      PlaceCatalog()
    end
  end
  f:SetScript("OnDragStop", StopMoving)
  f:HookScript("OnHide", StopMoving) -- closed mid-drag: it stays where it was let go

  local lock = CreateFrame("Button", nil, f)
  lock:SetSize(26, 26) -- as large as a close button (its art has a margin)
  lock:SetPoint("TOPLEFT", 3, 0)
  local over = f.TitleContainer or f.NineSlice or f -- above the frame's border art
  lock:SetFrameLevel(over:GetFrameLevel() + 2)
  lock:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  local function Art()
    local locked = ns.sv.catalog.locked
    local state = locked and "Locked" or "Unlocked"
    lock:SetNormalTexture(LOCK .. state .. "-Up")
    lock:SetPushedTexture(LOCK .. "Unlocked-Down") -- (the game has no pressed locked art)
    local t = lock:GetNormalTexture()
    -- a client without the old lock button: the game's padlock, dimmed when unlocked
    if t and t.GetTextureFileID and not t:GetTextureFileID() and lock.SetNormalAtlas then
      lock:SetNormalAtlas("QuestSharing-Padlock")
      lock:SetPushedAtlas("QuestSharing-Padlock")
      t = lock:GetNormalTexture()
      t:SetDesaturated(not locked)
      t:SetAlpha(locked and 1 or .6)
    end
  end
  local function Tip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local locked = ns.sv.catalog.locked
    GameTooltip:SetText(locked and L.CATALOG_LOCKED or L.CATALOG_UNLOCKED)
    GameTooltip:AddLine(locked and L.CATALOG_LOCKED_TIP or L.CATALOG_UNLOCKED_TIP, 1, 1, 1, true)
    GameTooltip:Show()
  end
  lock:SetScript("OnClick", function(self)
    ClickSound()
    ns:SetCatalogLocked(not ns.sv.catalog.locked)
    Art()
    if GameTooltip and GameTooltip:IsOwned(self) then Tip(self) end
  end)
  lock:SetScript("OnEnter", Tip)
  lock:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f.lock = lock
  f.grip = SizeGrip(f, CatalogTarget, true) -- (its readout under the list)
  return Art
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local NAV_BUTTON_W = NAV_W - 16 - 8 -- in the list's inset, 4 from each side

-- A page in the list on the left: its name, and below it what it holds.
local function NavButton(parent, i, nameKey, descKey, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(NAV_BUTTON_W, NAV_ROW_H - 4)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .06)
  b.name = Text(b, Tr(nameKey), "GameFontNormal")
  b.name:SetPoint("TOPLEFT", 8, -7)
  b.name:SetWidth(NAV_BUTTON_W - 12)
  b.name:SetWordWrap(false)
  b.desc = Hint(b, Tr(descKey))
  b.desc:SetPoint("TOPLEFT", 8, -24)
  b.desc:SetWidth(NAV_BUTTON_W - 12)
  b.desc:SetWordWrap(true)
  if b.desc.SetMaxLines then b.desc:SetMaxLines(2) end
  b.page = i
  b:SetScript("OnClick", function(self)
    if self.dragged then return end -- let go after a drag: no click
    ClickSound()
    onClick(self)
  end)
  function b:SetActive(on)
    SelectRow(self.bg, on)
    if on then self.name:SetTextColor(1, 1, 1) else self.name:SetTextColor(GOLD_R, GOLD_G, GOLD_B) end
    if on then self.desc:SetTextColor(.92, .92, .92) else self.desc:SetTextColor(.6, .6, .65) end -- readable on the gold
  end
  return b
end

-- A part of a page placed where the parts above it end (its group box moves with it).
local function Part(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetSize(BODY_W, 1)
  f.back = CreateFrame("Frame", nil, page.back)
  f.back:SetAllPoints(f)
  f.boxes = page.boxes -- (in the page's left column)
  function f:Place(y)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
  end
  return f
end

---------------------------------------------------------------------------
-- General page: size, opacity | look of the bars and their text (the position: above the
-- class tabs)
---------------------------------------------------------------------------
local function GeneralPage(p, gen, OnRefresh)
  Section(gen, "SCALE", LEFT, -56, nil, -148)
  local presetButtons = {}
  for i, pct in ipairs(SCALE_PRESETS) do
    local b = Button(gen, pct .. "%", 40, 22, function() ns:SetScalePercent(pct) end)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 44, -80)
    b.percent = pct
    presetButtons[i] = b
  end
  local scaleSlider = Slider(gen, 200, ns.MIN_SCALE, ns.MAX_SCALE, 1, Percent, function(v) ns:SetScalePercent(v) end, 40)
  scaleSlider:SetPoint("LEFT", gen, "TOPLEFT", LEFT, -116)
  Hint(gen, function() return L.SCALE_HINT:format(ns.MIN_SCALE, ns.MAX_SCALE) end):SetPoint("TOPLEFT", LEFT, -132)
  OnRefresh(function()
    local now = ns:GetScalePercent()
    for _, b in ipairs(presetButtons) do b:SetActive(b.percent == now) end
    scaleSlider:Set(now)
  end)

  Section(gen, "OPACITY", LEFT, -176, nil, -304)
  Text(gen, Tr("GLOBAL_OPACITY")):SetPoint("TOPLEFT", LEFT, -200)
  local alphaSlider = Slider(gen, 100, 0, 100, 1, Percent, function(v)
    ns.db.alpha = v / 100
    ns:ApplyAlpha()
  end)
  alphaSlider:SetPoint("LEFT", gen, "TOPLEFT", LEFT + 160, -206)
  local fade = Check(gen, Tr("FADE_OOC"), function(on)
    ns.db.fadeOOC = on
    ns:PreviewFade()
    p:Refresh()
  end)
  fade:SetPoint("TOPLEFT", LEFT, -230)
  Button(gen, Tr("OOC_RESET"), 110, 22, function() ns:ResetFade() end):SetPoint("TOPRIGHT", gen, "TOPLEFT", LEFT + COL_W, -224)
  local oocPowerLabel = Text(gen, "")
  oocPowerLabel:SetPoint("TOPLEFT", LEFT + 21, -256)
  local oocPower = Slider(gen, 100, 0, 100, 1, Percent, function(v)
    ns.db.oocPower = v / 100
    ns:PreviewFade()
  end)
  oocPower:SetPoint("LEFT", gen, "TOPLEFT", LEFT + 160, -262)
  local oocTopLabel = Text(gen, "")
  oocTopLabel:SetPoint("TOPLEFT", LEFT + 21, -282)
  local oocTop = Slider(gen, 100, 0, 100, 1, Percent, function(v)
    ns.db.oocTop = v / 100
    ns:PreviewFade()
  end)
  oocTop:SetPoint("LEFT", gen, "TOPLEFT", LEFT + 160, -288)
  OnRefresh(function()
    alphaSlider:Set(floor(ns.db.alpha * 100 + .5))
    -- the bars of the class: energy and / or rage, or mana / health; combo points and icons,
    -- or icons
    local power = editing == "ROGUE" and L.ENERGY_BAR or editing == "WARRIOR" and L.RAGE_BAR or L.OOC_POWER
    oocPowerLabel:SetText(ns.POWER_CLASSES[editing] and power or L.OOC_MANA)
    oocTopLabel:SetText(ns.COMBO_CLASSES[editing] and L.OOC_TOP or L.OOC_ICONS)
    fade:Set(ns.db.fadeOOC)
    oocPower:Set(floor(ns.db.oocPower * 100 + .5))
    oocTop:Set(floor(ns.db.oocTop * 100 + .5))
    local a = ns.db.fadeOOC and 1 or .45 -- (only used with the fade)
    for _, r in ipairs({ oocPowerLabel, oocTopLabel, oocPower, oocPower.box.holder, oocTop, oocTop.box.holder }) do r:SetAlpha(a) end
  end)

  -- Look: the bars' style, then their values' text, then the background of every bar
  local R = Column(gen)
  gen.colR = R
  local look = Section(R, "LOOK", RIGHT, -56)
  Text(R, Tr("BAR_STYLE")):SetPoint("TOPLEFT", RIGHT, -80)
  local styleButtons = {}
  for i, skin in ipairs(ns.SKINS) do
    local b = Button(R, Tr("SKIN_" .. skin), 100, 22, function()
      ns:SetSkin(skin)
      p:Refresh()
    end)
    b:SetPoint("TOPLEFT", RIGHT + (i - 1) * 108, -96)
    b.skin = skin
    styleButtons[i] = b
  end
  local styleHint = Wrapped(R, Tr("SKIN_HINT"))
  styleHint:SetPoint("TOPLEFT", RIGHT, -124)
  local TEXT_H = 244
  local text = CreateFrame("Frame", nil, R) -- under the hint, however many lines it takes
  text:SetSize(COL_W, TEXT_H)
  text:SetPoint("TOPLEFT", styleHint, "BOTTOMLEFT", 0, -10)
  Rule(text, 0, 0)
  Text(text, Tr("VALUE_TEXT")):SetPoint("TOPLEFT", 0, -10)
  local showText = Check(text, nil, function(on)
    ns.db.showText = on
    ns:ApplyFont()
    p:Refresh()
  end)
  showText:SetPoint("TOPLEFT", 0, -30)
  Text(text, Tr("FONT")):SetPoint("TOPLEFT", 0, -58)
  local font = FontChoice(text, COL_W - 90)
  font:SetPoint("TOPLEFT", 90, -53)
  Text(text, Tr("SIZE")):SetPoint("TOPLEFT", 0, -86)
  local sizeSlider = Slider(text, 150, 6, 40, 1, "", function(v)
    ns.db.fontSize = v
    ns:ApplyFont()
  end)
  sizeSlider:SetPoint("LEFT", text, "TOPLEFT", 90, -92)
  Text(text, Tr("OUTLINE")):SetPoint("TOPLEFT", 0, -114)
  local outlineButtons = {}
  for i, o in ipairs(OUTLINES) do
    local b = Button(text, Tr(o[2]), 70, 22, function()
      ns.db.outline = o[1]
      ns:ApplyFont()
      p:Refresh()
    end)
    b:SetPoint("TOPLEFT", 90 + (i - 1) * 76, -108)
    b.value = o[1]
    outlineButtons[i] = b
  end
  local textColor, textColorRefresh = ColorRow(text, "text", Tr("COLOR"), function() return false end)
  textColor:SetPoint("TOPLEFT", 0, -140)
  OnRefresh(textColorRefresh)
  Rule(text, 0, -174)
  local bg, bgRefresh = ColorRow(text, "bg", Tr("BARS_BG"))
  bg:SetPoint("TOPLEFT", 0, -184)
  OnRefresh(bgRefresh)
  -- the value text's and the background's colours (each bar has its own button: Bars page)
  Button(text, Tr("DEFAULT_TEXT_COLORS"), 250, 22, function() ns:ResetColors({ "text", "bg" }) end):SetPoint("TOPLEFT", 0, -216)
  OnRefresh(function()
    for _, b in ipairs(styleButtons) do b:SetActive(b.skin == ns.db.skin) end
    showText:SetLabel(L["SHOW_" .. RESOURCE[editing]])
    showText:Set(ns.db.showText)
    font:Refresh()
    sizeSlider:Set(ns.db.fontSize)
    for _, b in ipairs(outlineButtons) do b:SetActive(b.value == ns.db.outline) end
    look:Fit(-124 - (styleHint:GetStringHeight() or 36) - 10 - TEXT_H)
  end)
end

---------------------------------------------------------------------------
-- Visibility page: the addon shown or hidden by hand (also in the portrait's menu), druid
-- forms, the portrait's menu | hidden in some situations
---------------------------------------------------------------------------
local function VisibilityPage(p, vis, OnRefresh)
  local shownBox = Section(vis, "DISPLAY", LEFT, -56)
  local showAddon = Check(vis, Tr("SHOW_ADDON"), function(on) ns:SetHidden(not on) end)
  showAddon:SetPoint("TOPLEFT", LEFT, -80)
  local catOnly = Check(vis, Tr("CAT_ONLY"), function(on) ns:SetDruidCatOnly(on) end)
  catOnly:SetPoint("TOPLEFT", LEFT, -104)
  local menuPart = Part(vis) -- under the box above, whatever its height
  Section(menuPart, "SP_MENU", LEFT, 0, nil, -62)
  local menuLine = Check(menuPart, Tr("MENU_SECTION"), function(on) ns:SetMenuOption("line", on) end)
  menuLine:SetPoint("TOPLEFT", LEFT, -24)
  local menuReload = Check(menuPart, Tr("SP_MENU_RELOAD"), function(on) ns:SetMenuOption("reload", on) end)
  menuReload:SetPoint("TOPLEFT", LEFT, -48)
  OnRefresh(function()
    showAddon:Set(ns:ShownByChoice()) -- the character's own choice, as the portrait's box
    local druid = editing == "DRUID"
    catOnly:SetShown(druid)
    catOnly:Set(ns.db.druidCatOnly)
    local bottom = druid and -118 or -94
    shownBox:Fit(bottom)
    menuPart:Place(bottom - 28)
    menuLine:Set(ns.sv.menu.line ~= false)
    menuReload:Set(ns.sv.menu.reload ~= false)
  end)

  local R = Column(vis)
  vis.colR = R
  local hideBox = Section(R, "HIDE_WHEN", RIGHT, -56)
  local COLUMNS = { solo = { 0, 1 }, party = { 0, 2 }, raid = { 0, 3 },
    dungeon = { 1, 1 }, raid10 = { 1, 2 }, raid20 = { 1, 3 }, raid40 = { 1, 4 }, battleground = { 1, 5 } }
  Text(R, Tr("HIDE_GROUP")):SetPoint("TOPLEFT", RIGHT, -80)
  Text(R, Tr("HIDE_ZONE")):SetPoint("TOPLEFT", RIGHT + 160, -80)
  for _, key in ipairs(ns.HIDE_WHEN) do
    local at = COLUMNS[key]
    local check = Check(R, Tr("HIDE_" .. key:upper()), function(on) ns:SetHideWhen(key, on) end)
    check:SetPoint("TOPLEFT", RIGHT + 4 + at[1] * 160, -100 - (at[2] - 1) * 22)
    OnRefresh(function() check:Set(ns.db.hideWhen[key]) end)
  end
  local hideHint = Wrapped(R, Tr("HIDE_HINT"))
  hideHint:SetPoint("TOPLEFT", RIGHT, -218)
  OnRefresh(function() hideBox:Fit(-218 - (hideHint:GetStringHeight() or 24)) end)
end

---------------------------------------------------------------------------
-- Profiles page: the profiles | reset the tab (two clicks). Returns the reset button.
---------------------------------------------------------------------------
local function ProfilesPage(p, prof, OnRefresh)
  ProfilesSection(p, prof, OnRefresh)
  local R = Column(prof)
  prof.colR = R
  local resetBox = Section(R, "RESET_TITLE", RIGHT, -56)
  local resetAll
  resetAll = Button(R, "", 220, 22, function()
    if resetAll.armed then
      resetAll.armed = nil
      ns:ResetAll()
    else
      local token = {} -- each confirmation has its own 3 s, untouched by an earlier one
      resetAll.armed = token
      C_Timer.After(3, function()
        if resetAll.armed ~= token then return end
        resetAll.armed = nil
        if p:IsShown() then p:Refresh() end
      end)
    end
    p:Refresh()
  end)
  resetAll:SetPoint("TOPLEFT", RIGHT, -82)
  local resetHint = Wrapped(R, Tr("RESET_HINT"))
  resetHint:SetPoint("TOPLEFT", RIGHT, -112)
  OnRefresh(function()
    resetAll:SetLabel(resetAll.armed and L.CONFIRM or L.RESET_CLASS:format(L["TAB_" .. editing]))
    resetBox:Fit(-112 - (resetHint:GetStringHeight() or 24))
  end)
  return resetAll
end

-- The portrait's icon: the specialisation picked for the tab's class (a right-click on the
-- portrait), else the class's own.
local function PortraitIcon(class)
  local i, specs = ns.sv.portraits[class], ns.SPECS[class]
  if i and specs and specs[i] then return "Interface\\Icons\\" .. specs[i] end
  return ICONS[class]
end

-- A compact menu of the class's specialisations, each with its icon and name, in the look of
-- the window's groups; the one worn is lit. A click elsewhere closes it.
local SPEC_ROW_H = 26
local function SpecMenu(p, anchor)
  local m = CreateFrame("Frame", nil, p, "BackdropTemplate")
  m:SetFrameStrata("FULLSCREEN_DIALOG") -- over the spells panel too (DIALOG when detached)
  m:EnableMouse(true)
  m:Hide()
  GroupLook(m, .95) -- opaque: it opens over the tabs and the page list
  m.rows = {}
  for i = 1, 4 do
    local r = CreateFrame("Button", nil, m)
    r:SetHeight(SPEC_ROW_H)
    r:SetPoint("TOPLEFT", 7, -8 - (i - 1) * SPEC_ROW_H) -- inside the bronze art
    r:SetPoint("RIGHT", m, "RIGHT", -10, 0)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, .08)
    if i > 1 then -- a thin line between two rows
      local line = r:CreateTexture(nil, "ARTWORK")
      line:SetColorTexture(.62, .62, .66, .3)
      line:SetHeight(1)
      line:SetPoint("TOPLEFT")
      line:SetPoint("TOPRIGHT")
    end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 3, 0)
    r.icon:SetTexCoord(.08, .92, .08, .92)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetJustifyH("LEFT")
    r.index = i
    r:SetScript("OnClick", function(self)
      ClickSound()
      ns.sv.portraits[m.class] = self.index
      m:Hide()
      p:Refresh()
    end)
    m.rows[i] = r
  end
  function m:Open(class)
    self.class = class
    local specs, worn, width = ns.SPECS[class] or {}, PortraitIcon(class), 0
    for i, r in ipairs(self.rows) do
      local icon = specs[i]
      r:SetShown(icon ~= nil)
      if icon then
        local path = "Interface\\Icons\\" .. icon
        r.icon:SetTexture(path)
        r.name:SetText(L["SPEC_" .. class .. "_" .. i])
        width = max(width, r.name:GetStringWidth())
        local lit = path == worn
        SelectRow(r.bg, lit)
        if lit then r.name:SetTextColor(1, 1, 1) else r.name:SetTextColor(GOLD_R, GOLD_G, GOLD_B) end
      end
    end
    self:SetSize(7 + 3 + 20 + 8 + ceil(width) + 12 + 10, 16 + #specs * SPEC_ROW_H)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", anchor, "BOTTOMRIGHT", -12, 8)
    self:Show()
  end
  m:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
  m:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
  m:SetScript("OnEvent", function(self)
    if not self:IsMouseOver() and not anchor:IsMouseOver() then self:Hide() end
  end)
  return m
end

-- The portrait: a right-click picks the tab's icon among its class's specialisations (the
-- window still moves when dragged by it); beside it, the HUD's position. Returns the menu.
local function PortraitControls(p, portrait)
  -- The portrait: a right-click picks the tab's icon among its class's specialisations; the
  -- window still moves when dragged by it.
  local portraitButton = CreateFrame("Button", nil, p)
  portraitButton:SetFrameLevel(((p.PortraitContainer and p.PortraitContainer:GetFrameLevel()) or p:GetFrameLevel()) + 5)
  if portrait then
    portraitButton:SetAllPoints(portrait)
    portraitButton:SetHitRectInsets(2, 2, 0, 4) -- the round portrait, clear of the first class tab
  else
    portraitButton:SetSize(58, 58)
    portraitButton:SetPoint("TOPLEFT", -5, 7)
  end
  portraitButton:RegisterForClicks("RightButtonUp")
  portraitButton:RegisterForDrag("LeftButton")
  portraitButton:SetScript("OnDragStart", function() p:StartMoving() end)
  portraitButton:SetScript("OnDragStop", function()
    p:StopMovingOrSizing()
    SaveWindowPlace()
  end)
  local specMenu = SpecMenu(p, portraitButton)
  portraitButton:SetScript("OnClick", function()
    ClickSound()
    if GameTooltip then GameTooltip:Hide() end
    if specMenu:IsShown() then specMenu:Hide() else specMenu:Open(editing) end
  end)
  portraitButton:SetScript("OnEnter", function(self)
    if not GameTooltip or specMenu:IsShown() then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.PORTRAIT_TIP)
    GameTooltip:Show()
  end)
  portraitButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  p.portraitButton, p.specMenu = portraitButton, specMenu

  -- The HUD's position, above the class tabs: it moves every bar at once (the tab's class)
  local posLabel = Text(p, Tr("POSITION"), "GameFontNormal")
  posLabel:SetPoint("LEFT", p, "TOPLEFT", HEADER_X, HEADER_Y)
  local lockBtn = Button(p, "", 140, 22, function() ns:SetLocked(not ns.db.locked) end)
  lockBtn:SetPoint("LEFT", posLabel, "RIGHT", 10, 0)
  local resetPos = Button(p, Tr("DEFAULT_POS"), 140, 22, function() ns:ResetPosition() end)
  resetPos:SetPoint("LEFT", lockBtn, "RIGHT", 8, 0)
  p.lockButton, p.resetPosButton = lockBtn, resetPos
  function p.RefreshPosition()
    lockBtn:SetLabel(ns.db.locked and L.UNLOCK or L.LOCK)
    lockBtn:SetActive(not ns.db.locked)
  end
  return specMenu
end

---------------------------------------------------------------------------
-- The Improvements tab: the interface improvements built in (QoL.lua), one page each, listed
-- on the left like the pages of a class: where it stands, a box to turn it on or off (from the
-- next reload), its main switches, and a button to its full options.
---------------------------------------------------------------------------
-- its name on its tab, in gold (the class tabs: in their class's colour)
function ns.QolTabLabel()
  return ("|cff%02x%02x%02x%s|r"):format(floor(GOLD_R * 255 + .5), floor(GOLD_G * 255 + .5), floor(GOLD_B * 255 + .5),
    L.QOL_TAB)
end

function ns.BuildQolView(p, OnRefresh)
  local view = CreateFrame("Frame", nil, p)
  view:SetPoint("TOPLEFT", 12, NAV_TOP)
  view:SetPoint("BOTTOMRIGHT", -12, 40)
  view:Hide()
  local list = Box(view)
  list:SetPoint("TOPLEFT")
  list:SetPoint("BOTTOMLEFT")
  list:SetWidth(NAV_W - 16)
  local shown = 1
  local buttons, sheets = {}, {}
  for i, m in ipairs(ns.QOL_MODULES) do
    local b = NavButton(list, i, "QOL_NAV_" .. m.key:upper(), "QOL_NAVDESC_" .. m.key:upper(), function()
      shown = i
      p:Refresh()
    end)
    b.page = nil -- (not one of a class's pages)
    b:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (i - 1) * NAV_ROW_H)
    buttons[i] = b
    -- its page
    local sheet = CreateFrame("Frame", nil, view)
    sheet:SetPoint("TOPLEFT", list, "TOPRIGHT", 14, 0)
    sheet:SetPoint("BOTTOMRIGHT")
    sheet.back = CreateFrame("Frame", nil, sheet) -- its group box, under its widgets
    sheet.back:SetAllPoints()
    sheet.back:SetFrameLevel(sheet:GetFrameLevel())
    sheet:SetFrameLevel(sheet.back:GetFrameLevel() + 4)
    sheets[i] = sheet
    local W = COL_W + 120
    local box = Section(sheet, nil, LEFT, -8, W)
    box.title:SetText(m.name)
    local status = Wrapped(sheet, "", W)
    status:SetPoint("TOPLEFT", LEFT, -32)
    local about = Wrapped(sheet, Tr("QOL_ABOUT_" .. m.key:upper()), W)
    about:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -8)
    local on = Check(sheet, Tr("QOL_BUILT_IN"), function(v) ns:SetQolEnabled(m.key, v) end)
    on:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 2, -12)
    local open = Button(sheet, Tr("QOL_OPEN_FULL"), 220, 22, function() ns:OpenQol(m.key) end)
    open:SetPoint("TOPLEFT", on, "BOTTOMLEFT", -2, -12)
    local reload = Button(sheet, Tr("RELOAD_UI"), 160, 22, function()
      if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end
    end)
    reload:SetPoint("LEFT", open, "RIGHT", 8, 0)
    -- its main switches (the module's own settings, set by the module: ns:SetQolSwitches)
    local switches = {}
    for n, sw in ipairs(ns.qolSwitches and ns.qolSwitches[m.key] or {}) do
      local c = Check(sheet, Tr(sw.label), function(v) sw.set(v) p:Refresh() end)
      c:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 2, -16 - (n - 1) * 24)
      switches[n] = { check = c, sw = sw }
    end
    OnRefresh(function()
      if not p.qolActive then return end
      local state = ns:QolState(m.key)
      status:SetText(ns:QolStatusText(m))
      on:Set(ns:QolEnabled(m.key))
      on.check:SetEnabled(state ~= "unavailable")
      open:SetEnabled((state == "on" or state == "standalone") and ns:CanOpenQol(m.key))
      local pending = (state == "on") ~= ns:QolEnabled(m.key) and state ~= "standalone" and state ~= "unavailable"
      reload:SetShown(pending)
      for _, s in ipairs(switches) do
        s.check:SetShown(state == "on")
        if state == "on" then s.check:Set(s.sw.get()) end
      end
      -- the box down to the lowest widget: the buttons, or the last switch shown
      local lowest = -32 - (status:GetStringHeight() or 14) - 8 - (about:GetStringHeight() or 14) - 12 - 14 - 12 - 22
      if #switches > 0 and state == "on" then lowest = lowest - 16 - (#switches - 1) * 24 - 14 end
      box:Fit(lowest)
    end)
  end
  OnRefresh(function()
    view:SetShown(p.qolActive == true)
    for i, b in ipairs(buttons) do
      b:SetActive(i == shown)
      sheets[i]:SetShown(i == shown)
    end
  end)
  p.qolView = view
  return view
end

local function Build()
  relabels = {}
  local p = CreateFrame("Frame", "ClaraComboPointsOptions", UIParent, "PortraitFrameTemplate")
  p:Hide()
  local title = "Clara Combo Points  v" .. ns.VERSION
  if p.SetTitle then p:SetTitle(title) else ((p.TitleContainer and p.TitleContainer.TitleText) or p.TitleText):SetText(title) end
  local portrait = (p.PortraitContainer and p.PortraitContainer.portrait) or p.portrait
  p:SetSize(WinW(), WinH())
  p:SetPoint("CENTER")
  p:SetFrameStrata("HIGH") -- under the colour picker
  p:SetToplevel(true)
  p:SetClampedToScreen(false) -- free to go off the screen
  if p.SetDontSavePosition then p:SetDontSavePosition(true) end -- kept by the addon (sv.window)
  p:EnableMouse(true)
  p:SetMovable(true)
  p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart", p.StartMoving)
  p:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveWindowPlace()
  end)
  tinsert(UISpecialFrames, p:GetName()) -- Esc closes it
  p.relabels = relabels

  -- the character sheet's palette: near-black background (settings groups in boxes, below)
  if p.Bg then p.Bg:SetVertexColor(.32, .32, .34) end

  local specMenu = PortraitControls(p, portrait)

  local refreshers = {}
  local function OnRefresh(fn) refreshers[#refreshers + 1] = fn end
  local resetAll
  OnRefresh(p.RefreshPosition)

  -- Class tabs, in one row, each name in its class's colour ---------------------------
  local tabs = {}
  for i, class in ipairs(CLASSES) do
    local t = Tab(p, function()
      local c = CLASS_COLORS[class]
      return ("|cff%02x%02x%02x%s|r"):format(floor(c[1] * 255 + .5), floor(c[2] * 255 + .5), floor(c[3] * 255 + .5),
        L["TAB_" .. class])
    end, function()
      ns:EndTyping() -- (a number being typed belongs to the tab it was typed on)
      p.qolActive = nil
      editing = class
      specMenu:Hide()
      ClosePicker()
      resetAll.armed = nil
      status:SetText("")
      p.ClearProfileMessages()
      ns:SetActiveProfile(class)
      p:Refresh()
    end)
    if i == 1 then
      t:SetPoint("BOTTOMLEFT", p, "TOPLEFT", TABS_X, TABS_Y)
    else
      t:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)
    end
    t.class = class
    -- the game's tab sizes itself to its text when shown: back to the common width
    local function Keep(self) if self.fixedWidth then PanelTemplates_TabResize(self, 0, self.fixedWidth) end end
    t:HookScript("OnShow", Keep)
    t:HookScript("OnEvent", Keep)
    tabs[i] = t
  end
  -- last, the Improvements tab (the interface improvements, for every class)
  local qolTab = Tab(p, ns.QolTabLabel, function()
    ns:EndTyping()
    p.qolActive = true
    specMenu:Hide()
    ClosePicker()
    resetAll.armed = nil
    status:SetText("")
    p.ClearProfileMessages() -- (an Export / Import box belongs to the class tab it was opened on)
    p:Refresh()
  end)
  qolTab:SetPoint("LEFT", tabs[#tabs], "RIGHT", 4, 0)
  qolTab.isQol = true
  local function KeepQol(self) if self.fixedWidth then PanelTemplates_TabResize(self, 0, self.fixedWidth) end end
  qolTab:HookScript("OnShow", KeepQol)
  qolTab:HookScript("OnEvent", KeepQol)
  tabs[#tabs + 1] = qolTab
  p.qolTab = qolTab
  -- all as wide as the widest if the row still fits; else each at its own width; if even that
  -- is too wide (a long language, a narrow window), all narrowed alike (the game's tab shortens
  -- its text)
  -- (narrower than the tab's art allows: at their narrowest, the tabs overlap)
  local function FitTabs()
    local n, gap = #tabs, 4
    local room = p:GetWidth() - TABS_X - 14 - (n - 1) * gap
    local widest, total = 0, 0
    for _, t in ipairs(tabs) do
      PanelTemplates_TabResize(t, 0)
      widest = max(widest, t:GetWidth())
      total = total + t:GetWidth()
    end
    local fixed
    if widest * n <= room then fixed = widest elseif total > room then fixed = floor(room / n) end
    local least = tabs[1].Left and tabs[1].Right and tabs[1].Left:GetWidth() + tabs[1].Right:GetWidth() or 0
    if fixed and fixed < least then
      fixed = least
      gap = max(-24, floor((p:GetWidth() - TABS_X - 14 - n * least) / (n - 1)))
    end
    for i, t in ipairs(tabs) do
      t.fixedWidth = fixed
      if fixed then PanelTemplates_TabResize(t, 0, fixed) end
      if i > 1 then
        t:ClearAllPoints()
        t:SetPoint("LEFT", tabs[i - 1], "RIGHT", gap, 0)
      end
    end
  end
  OnRelabel(FitTabs)

  -- Pages, and the list of them on the left in the order the player set by dragging them
  -- (ns.sv.pageOrder) --------------------------------------------------------------
  local nav = Box(p)
  nav:SetPoint("TOPLEFT", 12, NAV_TOP)
  nav:SetPoint("BOTTOMLEFT", 12, 40)
  nav:SetWidth(NAV_W - 16)
  -- the pages, in a view under the class tabs that scrolls them when the window is shorter
  -- than they are (its bar shows then, on the right)
  local body = CreateFrame("ScrollFrame", "ClaraComboPointsOptionsPages", p, "UIPanelScrollFrameTemplate")
  body:SetPoint("TOPLEFT", NAV_W, VIEW_TOP)
  body:SetPoint("BOTTOMRIGHT", -(SCROLL_W + 4), 40)
  body.scrollBarHideable = true
  if body.ScrollBar then body.ScrollBar:Hide() end
  local sheet = CreateFrame("Frame", nil, body)
  sheet:SetSize(BODY_W, 10)
  body:SetScrollChild(sheet)
  p.body, p.sheet = body, sheet
  local pages, navButtons = {}, {}
  for i, def in ipairs(PAGES) do
    local content = CreateFrame("Frame", nil, sheet)
    content:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, CONTENT_TOP - VIEW_TOP) -- (its empty top above the view)
    content:SetSize(BODY_W, PANEL_H + CONTENT_TOP)
    content.back = CreateFrame("Frame", nil, sheet) -- group boxes, under the page's widgets
    content.back:SetAllPoints(content)
    content:SetFrameLevel(content.back:GetFrameLevel() + 4)
    content.boxes = {}
    pages[i] = content
    navButtons[i] = NavButton(nav, i, def[1], def[2], function()
      if page ~= i then body:SetVerticalScroll(0) end -- another page: from its top
      page = i
      p:Refresh()
    end)
  end
  -- a page dragged up or down the list takes the place where it is let go
  local dragNav
  local function Order()
    local order = {}
    for _, i in ipairs(ns.sv.pageOrder) do order[#order + 1] = navButtons[i] end
    return order
  end
  local function PlaceNav()
    for n, b in ipairs(Order()) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", nav, "TOPLEFT", 4, -4 - (n - 1) * NAV_ROW_H)
    end
  end
  local function DropIndex()
    local _, y = GetCursorPosition()
    y = y / p:GetEffectiveScale()
    local at = 1
    for _, b in ipairs(Order()) do
      if b ~= dragNav then
        local bottom, h = b:GetBottom(), b:GetHeight()
        if bottom and y < bottom + h / 2 then at = at + 1 end
      end
    end
    return at
  end
  local function MoveDragged()
    if not dragNav then return end
    local order = {}
    for _, i in ipairs(ns.sv.pageOrder) do if i ~= dragNav.page then order[#order + 1] = i end end
    table.insert(order, max(1, min(DropIndex(), #order + 1)), dragNav.page)
    ns.sv.pageOrder = order
    PlaceNav()
  end
  for _, b in ipairs(navButtons) do
    b:RegisterForDrag("LeftButton")
    b:HookScript("OnMouseDown", function(self) self.dragged = nil end)
    b:SetScript("OnDragStart", function(self)
      dragNav, self.dragged = self, true
      self:SetAlpha(.6)
      self:SetScript("OnUpdate", MoveDragged)
    end)
    b:SetScript("OnDragStop", function(self)
      self:SetScript("OnUpdate", nil)
      self:SetAlpha(1)
      MoveDragged()
      dragNav = nil
    end)
  end
  PlaceNav()
  p.PlaceNav = PlaceNav

  -- under the pages: the preview (everything lit), then which tab this character uses
  local previewBtn = Button(nav, Tr("PREVIEW"), NAV_BUTTON_W, 22, function() ns:SetPreview(not ns.preview) end)
  previewBtn:SetPoint("TOPLEFT", nav, "TOPLEFT", 4, -4 - #PAGES * NAV_ROW_H - 10)
  local previewHint = Hint(nav, Tr("PREVIEW_HINT"))
  previewHint:SetPoint("TOP", previewBtn, "BOTTOM", 0, -4)
  OnRefresh(function() previewBtn:SetActive(ns.preview) end)
  local who
  if ns.enabled then
    who = Hint(nav, function() return L.THIS_CHARACTER:format(L["TAB_" .. ns.homeClass]) end)
  else
    who = Text(nav, Tr("WRONG_CLASS"), "GameFontHighlightSmall")
    who:SetTextColor(1, .4, .3)
  end
  who:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 10, 10)
  who:SetWidth(NAV_BUTTON_W - 8)
  who:SetWordWrap(true)

  -- language flags in the title bar, left of the close button
  local flags = {}
  for i, lang in ipairs(ns.LANGUAGES) do
    local f = Flag(p, lang, function(code) ns:SetLanguage(code) end)
    f:SetPoint("RIGHT", p, "TOPRIGHT", -34 - (#ns.LANGUAGES - i) * FLAG_STEP, -11)
    -- above the frame's border art, which covers the title bar
    local over = p.TitleContainer or p.NineSlice or p
    f:SetFrameLevel(over:GetFrameLevel() + 2)
    f.art:SetFrameLevel(f:GetFrameLevel() + 1)
    flags[i] = f
  end

  -- Footer: the commands; the opacity of the window (and of everything shown with it) by the
  -- scale grip in the corner
  local commands = Hint(p, "/cl lock  ·  /cl unlock  ·  /cl hide  ·  /cl show  ·  /cl reset  ·  /cl reset pos")
  commands:SetPoint("LEFT", p, "BOTTOMLEFT", LEFT, 22)
  local opacity = Slider(p, 90, ns.MIN_WINDOW_ALPHA * 100, 100, 1, Percent, function(v) ns:SetWindowAlpha(v / 100) end, 32)
  opacity:SetPoint("RIGHT", p, "BOTTOMRIGHT", -FOOTER_RIGHT - 52, 22)
  local opacityLabel = Text(p, Tr("WINDOW_OPACITY"))
  opacityLabel:SetPoint("RIGHT", opacity, "LEFT", -8, 0)
  -- a narrow window: the commands cut short before the opacity
  local function FitCommands()
    local room = (p:GetWidth() - FOOTER_RIGHT - 52 - 90 - 8 - (opacityLabel:GetStringWidth() or 0) - 12) - LEFT
    commands:SetWidth(max(40, room))
    commands:SetWordWrap(false)
  end
  OnRelabel(FitCommands)
  p.FitCommands = FitCommands
  OnRefresh(function() opacity:Set(floor(ns.sv.window.alpha * 100 + .5)) end)
  p.grip = SizeGrip(p, WindowTarget)
  OnRefresh(function()
    for _, t in ipairs(tabs) do t:SetActive((t.isQol and p.qolActive) or (not p.qolActive and t.class == editing)) end
    for _, f in ipairs(flags) do f:SetActive(f.lang == ns.lang) end
    if portrait then portrait:SetTexture(PortraitIcon(editing)) end
  end)
  OnRefresh(function()
    local classTab = not p.qolActive -- (the Improvements tab has its own pages)
    nav:SetShown(classTab)
    body:SetShown(classTab)
    for i, content in ipairs(pages) do
      content:SetShown(classTab and i == page)
      content.back:SetShown(classTab and i == page)
    end
    for _, b in ipairs(navButtons) do b:SetActive(b.page == page) end
  end)
  ns.BuildQolView(p, OnRefresh)

  GeneralPage(p, pages[1], OnRefresh)
  BarsPage(p, pages[2], OnRefresh)
  IconsPage(p, pages[3], OnRefresh)
  OnRefresh(CatalogControls(p))

  VisibilityPage(p, pages[4], OnRefresh)

  resetAll = ProfilesPage(p, pages[5], OnRefresh)

  -- The page shown laid out for the view's width: its right column beside the left one, or
  -- under it when both do not fit; the part across both under them, as wide as the view lets
  -- it. The view scrolls what is taller than it.
  local TWO_COLUMNS = RIGHT + COL_W + PAD + 2
  local FIRST_BOX, ROWS_BOX, GROUP_GAP = 56 - PAD, 324 - PAD, 10 -- tops of the first group, of the rows
  local function Depth(boxes, top) -- the lowest bottom of some group boxes, under top
    local low = 0
    for _, box in ipairs(boxes) do
      local b = box:GetBottom()
      if b then low = max(low, top - b) end
    end
    return low
  end
  function p:Reflow()
    local viewW = body:GetWidth()
    sheet:SetWidth(max(1, viewW))
    local content = pages[page]
    local top = content:GetTop()
    if not top then return end
    local two = viewW >= TWO_COLUMNS
    local low = Depth(content.boxes, top)
    local R, F = content.colR, content.colF
    if R then
      R:ClearAllPoints()
      if two then
        R:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
      else
        R:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT - RIGHT, -(low + GROUP_GAP - FIRST_BOX))
      end
      low = max(low, Depth(R.boxes, top))
    end
    if F then
      F:Fit(two and FULL_W or viewW - 2 * LEFT - 4)
      F:ClearAllPoints()
      F:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -max(0, low + GROUP_GAP - ROWS_BOX))
      low = max(low, Depth(F.boxes, top))
    end
    sheet:SetHeight(max(1, low - (CONTENT_TOP - VIEW_TOP) + 12)) -- (the page's top is above the view)
    body:UpdateScrollChildRect()
    local range = max(0, sheet:GetHeight() - body:GetHeight())
    if body:GetVerticalScroll() > range then body:SetVerticalScroll(range) end
  end

  -- The window at its size (sv.window): the class tabs fitted, the page laid out again.
  function p:Resize()
    self:SetSize(WinW(), WinH())
    FitTabs()
    if self.FitCommands then self.FitCommands() end
    self:Reflow()
  end

  function p:Refresh()
    for _, fn in ipairs(refreshers) do fn() end
    self:Reflow()
  end

  -- Opening the options shows this character's tab, with everything lit so colour changes
  -- are visible straight away.
  p:SetScript("OnShow", function(self)
    PlaceWindow()
    self:SetAlpha(ns.sv.window.alpha)
    editing = ns.homeClass or "ROGUE"
    self.qolActive = nil
    resetAll.armed = nil
    status:SetText("")
    self.ClearProfileMessages()
    ns:SetActiveProfile(editing)
    ns:SetOptionsOpen(true)
    if InCombatLockdown() then self:Refresh() else ns:SetPreview(true) end
  end)
  p:SetScript("OnHide", function()
    ns:EndTyping()
    specMenu:Hide()
    ClosePicker()
    drag = nil -- closed mid-drag: the icon stays where it was
    ns:HoldForOptions(false)
    catalog.unfolded = nil -- opened again: on the tab's class
    if dragNav then -- a page of the list too (a hidden frame gets no OnDragStop)
      dragNav:SetScript("OnUpdate", nil)
      dragNav:SetAlpha(1)
      dragNav = nil
    end
    ghost:Hide()
    if ns.preview then ns:SetPreview(false) end
    ns:SetActiveProfile(ns.homeClass or "ROGUE") -- (the lock comes along: Core.lua)
    ns:LockOtherProfiles()
    ns:SetOptionsOpen(false)
  end)

  return p
end

function ns:RelabelOptions()
  if not panel then return end
  for _, fn in ipairs(panel.relabels) do fn() end
  self:RefreshOptions()
end

function ns:RefreshOptions()
  if panel and panel:IsShown() then panel:Refresh() end
end

function ns:ToggleOptions()
  if panel and panel:IsShown() then
    panel:Hide()
  else
    self:ShowOptions()
  end
end

function ns:ShowOptions()
  panel = panel or Build()
  panel:Show()
  panel:Raise()
end
