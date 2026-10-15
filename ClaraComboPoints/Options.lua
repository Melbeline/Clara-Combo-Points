-- Clara Combo Points - options window (/clara or /cl)
-- Built from Blizzard's own frame templates, the look of the game's windows: metal frame with
-- portrait, insets, red buttons, tabs, checkboxes and sliders.
--   Top: one tab per class profile, in one row; the language flags in the title bar.
--   Left: the pages (General, Bars, Icons, Visibility, Profiles), each with a line saying what
--   it holds (drag one to change its place), and the preview.
--   Each option is on one page only.
--   Bottom: the commands, and the window's opacity.
--   The window can be dragged anywhere, even off the screen, and scaled from its bottom right
--   corner; where it is, its scale and opacity are kept (account-wide).
-- Colours use Blizzard's own colour picker.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local NAV_W, BODY_W = 168, 720    -- the list of pages on the left; a page (two columns)
local PANEL_W, PANEL_H = NAV_W + BODY_W, 720
local TABS_X, FLAG_STEP = 14, 30 -- first tab; flags, one every 30
local TABS_Y = -84               -- bottom of the row of class tabs (each tab is 32 tall)
local FOOTER_RIGHT = 28          -- footer, clear of the scale grip
local CONTENT_TOP = -40          -- pages start under the class tabs (their first group at -96)
local NAV_TOP, NAV_ROW_H = -88, 54 -- the list of pages: its top, one page's height
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
  mana = { "mana" }, health = { "health" } }
local COLOR_LABELS = { energy = "ENERGY_BAR", rage = "RAGE_BAR", mana = "MANA_BAR", health = "HEALTH_BAR", cost = "COST_COLOR" }
-- colours a class never uses (warriors have no combo points: their icons wear the button frame;
-- the mana classes have neither combo points nor energy / rage)
local MANA_ONLY = { cp1 = true, cp2 = true, cp3 = true, cp4 = true, cp5 = true, energy = true, rage = true, cost = true }
local NO_COLOR = {
  ROGUE = { rage = true, cost = true, mana = true },
  WARRIOR = { cp1 = true, cp2 = true, cp3 = true, cp4 = true, cp5 = true, energy = true, mana = true },
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

-- A group of settings in a box like the character sheet's stat groups: rounded silver
-- border, dark fill, gold title. The box sits on the page's back layer, under the widgets.
-- key: the title's locale key (or nil: box.title:SetText later). bottom: lowest y of the
-- group's content (or later, box:Fit(y)).
local GROUP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local PAD = 9 -- box margin around its content

local function Section(parent, key, x, y, width, bottom)
  local box = CreateFrame("Frame", nil, parent.back, "BackdropTemplate")
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", x - PAD, y + PAD)
  box:SetWidth((width or COL_W) + 2 * PAD)
  box:SetBackdrop(GROUP_BACKDROP)
  box:SetBackdropColor(0, 0, 0, .55)
  box:SetBackdropBorderColor(.62, .62, .66, 1)
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
  function t:SetActive(on)
    if on then PanelTemplates_SelectTab(self) else PanelTemplates_DeselectTab(self) end
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
  s:SetScript("OnMouseWheel", function(self, delta)
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
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
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
  if left and x >= left and x <= right and y >= bottom and y <= top then return x - left end
end

-- The landing place follows the cursor: the icon slot under it, in the line under it. An
-- icon of a row taken out of the window (and of the spells panel) is removed when let go.
local function TrackDrag()
  local toSide, toK, toI
  for _, line in ipairs(lines) do
    local x = line.frame:IsVisible() and CursorIn(line.frame)
    if x and Accepts(line.side, line.k) then
      local n = #ns.db.rows[line.side][line.k]
      if line.side == drag.side and line.k == drag.k then n = n - 1 end
      toSide, toK = line.side, line.k
      toI = max(1, min(n + 1, floor((x - ICON_X) / ICON_STEP) + 1))
      break
    end
  end
  local out = drag.side ~= nil and not toSide and not CursorIn(panel)
    and not (catalog and catalog:IsShown() and CursorIn(catalog))
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
  local x = CursorIn(line.frame)
  if not x then return n + 1 end
  return max(1, min(n + 1, floor((x - ICON_X) / ICON_STEP) + 1))
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
    -- no menus in this client: each click watches the next way
    local now = ns:EntryOn(entry)
    for n, on in ipairs(ns.CONDITIONS) do
      if on == now then Change(nil, ns.CONDITIONS[n % #ns.CONDITIONS + 1]) break end
    end
    return
  end
  local spell = ns:EntrySpell(entry)
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

local function IconLine(parent, side, k, y)
  local line = CreateFrame("Button", nil, parent)
  line:SetSize(FULL_W, 28)
  line:SetPoint("TOPLEFT", LEFT, y)
  line.bg = line:CreateTexture(nil, "BACKGROUND")
  line.bg:SetAllPoints()
  local hl = line:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .06)
  Text(line, function() return ns:RowName(side, k) end):SetPoint("LEFT", 8, 0)
  local count = Hint(line, "")
  count:SetPoint("RIGHT", -8, 0)
  local entry = { side = side, k = k, frame = line }
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
    b:SetPoint("LEFT", ICON_X + (i - 1) * ICON_STEP, 0)
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
  lines[#lines + 1] = entry
  return refresh
end

---------------------------------------------------------------------------
-- Class spells panel, beside the window on the icons page: every buff and debuff of each
-- class, with its rank and where to watch it, to drag onto a row (or click: add it to the
-- selected row).
---------------------------------------------------------------------------
local SIDE_W = 420
local SIDE_ROW_H, SIDE_HEAD_H = 26, 24
local CLASS_COLORS = {
  PRIEST = { 1, 1, 1 }, MAGE = { .25, .78, .92 }, WARLOCK = { .53, .53, .93 }, ROGUE = { 1, .96, .41 },
  DRUID = { 1, .49, .04 }, HUNTER = { .67, .83, .45 }, SHAMAN = { 0, .44, .87 }, PALADIN = { .96, .55, .73 },
  WARRIOR = { .78, .61, .43 },
}
local KIND_ON = { BUFF = "self", DEBUFF = "enemy", SELFDEBUFF = "self" } -- where to watch by default
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
  f:SetSize(SIDE_W, PANEL_H)
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

  local hint = Hint(f, Tr("CATALOG_HINT"))
  hint:SetPoint("TOPLEFT", 16, -32)
  hint:SetWidth(SIDE_W - 32)
  hint:SetWordWrap(true)

  -- Search: a name in the game's language, English, French or German, whole or in part,
  -- accents and case aside; or a spell ID.
  local query = "" -- search key (ns:SearchKey), "" for the whole list
  local search = InputBox(f, SIDE_W - 32)
  search:SetMaxLetters(60)
  search.holder:SetPoint("TOPLEFT", 16, -78)
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
  inset:SetPoint("TOPLEFT", 10, -128)
  inset:SetPoint("BOTTOMRIGHT", -10, 12)
  local scroll = CreateFrame("ScrollFrame", "ClaraComboPointsSpellsScroll", inset, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -6)
  scroll:SetPoint("BOTTOMRIGHT", -26, 6)
  local CHILD_W = SIDE_W - 20 - 4 - 26
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(CHILD_W, 10)
  scroll:SetScrollChild(child)
  local noMatch = Hint(child, Tr("CATALOG_NONE"))
  noMatch:SetPoint("TOP", 0, -12)

  -- column titles, over the list
  local RANK_X, ON_X, MINE_X = 140, 236, CHILD_W - 22
  Text(f, Tr("CATALOG_SPELL")):SetPoint("TOPLEFT", inset, "TOPLEFT", 4 + 32, 14)
  Text(f, Tr("CATALOG_RANK")):SetPoint("TOPLEFT", inset, "TOPLEFT", 4 + RANK_X, 14)
  Text(f, Tr("CATALOG_ON")):SetPoint("TOPLEFT", inset, "TOPLEFT", 4 + ON_X, 14)
  local mineTitle = Text(f, Tr("CATALOG_MINE"))
  mineTitle:SetPoint("TOPRIGHT", inset, "TOPLEFT", 4 + CHILD_W, 14)
  mineTitle:SetJustifyH("RIGHT")

  local groups, expanded, picks, rowOf = {}, {}, {}, {}
  local Layout

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
    name:SetWidth((#rec.ranks > 1 and RANK_X or ON_X) - 32 - 6) -- one rank: the rank column is free
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
      row.rank:SetPoint("LEFT", RANK_X, 0)
    end
    row.on = Choice(row, MINE_X - ON_X - 6, function()
      local list = {}
      for _, on in ipairs(PICK_ON) do list[#list + 1] = { on, OnName(on) } end
      return list
    end, function() return picks[rec].on end, function(v) picks[rec].on = v end)
    row.on:SetPoint("LEFT", ON_X, 0)
    -- cast by you only (else anyone's)
    local mine = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    mine:SetSize(22, 22)
    mine:SetPoint("LEFT", MINE_X, 0)
    mine:SetScript("OnClick", function(self)
      ClickSound()
      picks[rec].mine = self:GetChecked() and true or false
    end)
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
    return row
  end

  for _, class in ipairs(ns.SPELL_CATALOG or {}) do
    local recs, seen = {}, {}
    for _, spell in ipairs(class.spells) do
      for r = 2, #spell do
        local rec = ns:CatalogRecord(spell[r]) -- spells this client does not know are left out
        if rec then
          if not seen[rec] then seen[rec] = true; recs[#recs + 1] = rec end
          break
        end
      end
    end
    if #recs > 0 then
      local color = CLASS_COLORS[class.class] or { GOLD_R, GOLD_G, GOLD_B }
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
      OnRelabel(function() label:SetText(L["CLASS_" .. class.class] or class.class) end)
      local count = Hint(head, "")
      count:SetPoint("RIGHT", -8, 0)
      local g = { class = class.class, head = head, recs = recs, count = count }
      head:SetScript("OnClick", function()
        ClickSound()
        expanded[g.class] = not expanded[g.class]
        Layout()
      end)
      groups[#groups + 1] = g
    end
  end

  -- alphabetical in the addon's language
  local function ByName(a, b)
    local ka, kb = SortKey(ns:CatalogName(a)), SortKey(ns:CatalogName(b))
    if ka ~= kb then return ka < kb end
    return a.ranks[1][2] < b.ranks[1][2]
  end

  -- The classes, each with its spells when unfolded. While searching: only the spells found,
  -- in their classes, all unfolded.
  function Layout()
    local y = 0
    local searching = query ~= ""
    for _, g in ipairs(groups) do
      local list = {}
      for _, rec in ipairs(g.recs) do
        if not searching or ns:CatalogMatches(rec, query) then list[#list + 1] = rec end
      end
      table.sort(list, ByName)
      local visible = #list > 0
      local open = visible and (searching or expanded[g.class])
      g.head:SetShown(visible)
      g.count:SetText(searching and (#list .. " / " .. #g.recs) or tostring(#g.recs))
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
      wipe(expanded)
      expanded[editing] = true
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
  local detail = Section(page, nil, RIGHT, -56)
  local function SizeSlider(label, y, minV, maxV, unit, field, factor)
    Text(page, Tr(label)):SetPoint("TOPLEFT", RIGHT, y)
    local slider = Slider(page, 150, minV, maxV, 1, unit, function(v)
      ns.db.bars[picked][field] = v / factor
      ns:ApplyLayout()
    end)
    slider:SetPoint("LEFT", page, "TOPLEFT", RIGHT + 90, y - 6)
    OnRefresh(function() slider:Set(floor(ns.db.bars[picked][field] * factor + .5)) end)
    return slider
  end
  SizeSlider("BAR_WIDTH", -84, ns.MIN_BAR_W, ns.MAX_BAR_W, "", "width", 1)
  SizeSlider("BAR_HEIGHT", -112, ns.MIN_BAR_H, ns.MAX_BAR_H, "", "height", 1)
  SizeSlider("BAR_SCALE", -140, ns.MIN_BAR_SCALE, ns.MAX_BAR_SCALE, Percent, "scale", 100)
  Rule(page, RIGHT, -166)
  Text(page, Tr("COLORS")):SetPoint("TOPLEFT", RIGHT, -176)

  -- its colours, each part with a box if the bar has more than one (the rage about to be spent
  -- always: it is shown or not)
  local function Boxed(key)
    return key == "cost" or #ns:BarParts(picked, editing) > 1
  end
  local function Has(key)
    for _, k in ipairs(BarColorKeys(picked)) do if k == key then return true end end
    return false
  end
  local items = {}
  for _, bar in ipairs({ "combo", "power", "mana", "health" }) do
    for _, key in ipairs(BAR_COLORS[bar]) do
      local holder, refresh = ColorRow(page, key, nil, function() return Boxed(key) end)
      OnRefresh(refresh)
      items[#items + 1] = { frame = holder, height = 28, when = function() return Has(key) end }
      if key == "cost" then -- the spells that spend it
        local spells = Holder(page, 18)
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
      elseif key == "health" then -- or the class's colour
        local classColor = Holder(page, 26)
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
  local source = Holder(page, 38)
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
  local defaults = Holder(page, 36)
  Button(defaults, Tr("DEFAULT_SIZE"), 150, 22, function()
    DefaultSize(picked)
    ns:ApplyLayout()
    p:Refresh()
  end):SetPoint("TOPLEFT", 0, -10)
  Button(defaults, Tr("DEFAULT_COLORS"), 150, 22, function() ns:ResetColors(BarColorKeys(picked)) end):SetPoint("TOPLEFT", 160, -10)
  items[#items + 1] = { frame = defaults, height = 36 }
  OnRefresh(Stack(page, RIGHT, -196, items, detail))

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
    lookBox:Fit(editing == "DRUID" and -272 or -248)
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

  Section(icons, "ADD_SPELL", RIGHT, -56, nil, -176)
  Hint(icons, Tr("ADD_HINT")):SetPoint("TOPLEFT", RIGHT, -78)
  local input = InputBox(icons, 180)
  input:SetMaxLetters(80)
  input.holder:SetPoint("TOPLEFT", RIGHT, -94)
  status = Text(icons, "", "GameFontHighlightSmall") -- (upvalue shared with the drop handlers)
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
  local addBtn = Button(icons, "", 130, 22, Add)
  addBtn:SetPoint("TOPLEFT", RIGHT + 190, -94)
  local clearBtn = Button(icons, Tr("CLEAR_ROW"), 150, 22, function() status:SetText(""); ns:ClearRow(selSide, selK) end)
  clearBtn:SetPoint("TOPLEFT", RIGHT, -152)
  local defaultBtn = Button(icons, Tr("DEFAULT_ICONS"), 150, 22, function() status:SetText(""); ns:ResetIcons() end)
  defaultBtn:SetPoint("TOPLEFT", RIGHT + 160, -152)
  OnRefresh(function() addBtn:SetLabel(L.ADD .. " > " .. ns:RowName(selSide, selK)) end)

  -- Icons unlocked, for every class: spells dropped on the HUD's rows, icons moved or dragged
  -- off (Tracker.lua)
  local hudBox = Section(icons, "ICONS_ON_HUD", RIGHT, -204)
  local onHud = Check(icons, Tr("EDIT_ON_HUD"), function(on) ns:SetIconsLocked(not on) end)
  onHud:SetPoint("TOPLEFT", RIGHT, -228)
  local hudHint = Wrapped(icons, Tr("ICONS_UNLOCKED_HINT"))
  hudHint:SetPoint("TOPLEFT", RIGHT, -246)
  OnRefresh(function()
    onHud:Set(not ns.db.iconsLocked)
    hudBox:Fit(-246 - (hudHint:GetStringHeight() or 24))
  end)

  Section(icons, "ROWS", LEFT, -300, FULL_W, -566)
  local catalogBtn = Button(icons, Tr("CATALOG_OPEN"), 150, 22, function()
    catalog.closed = catalog:IsShown()
    p:Refresh()
  end)
  catalogBtn:SetPoint("TOPRIGHT", icons, "TOPLEFT", LEFT + FULL_W, -295)
  Hint(icons, Tr("ROWS_HINT")):SetPoint("TOPLEFT", LEFT, -320)
  for i, def in ipairs(ROW_LINES) do
    local y = -336 - (i - 1) * 30
    if def then
      OnRefresh(IconLine(icons, def[1], def[2], y))
    else -- the bar, between the rows above and below it
      local barLabel = Hint(icons, Tr("ROW_BAR"))
      barLabel:SetPoint("TOPLEFT", LEFT + 8, y - 9)
      local rule = icons:CreateTexture(nil, "ARTWORK")
      rule:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .25)
      rule:SetHeight(1)
      rule:SetPoint("LEFT", barLabel, "RIGHT", 8, 0)
      rule:SetPoint("RIGHT", icons, "TOPLEFT", LEFT + FULL_W, y - 14)
    end
  end
  Hint(icons, Tr("ICON_TIP")):SetPoint("TOPLEFT", LEFT, -552)
  ghost = DragGhost(p)
  catalog = Catalog(p)
  OnRefresh(function()
    catalog:Sync(page == ICONS_PAGE)
    catalogBtn:SetActive(catalog:IsShown())
  end)
end

---------------------------------------------------------------------------
-- Profiles of the tab being edited (Profiles page): named copies of all its settings, saved,
-- loaded, deleted, exported and imported.
---------------------------------------------------------------------------
local function ProfilesSection(p, bar, OnRefresh)
  Section(bar, "PROFILES", LEFT, -56, nil, -198)
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
  local profStatus = Text(bar, "", "GameFontHighlightSmall")
  profStatus:SetPoint("TOPLEFT", LEFT, -180)
  profStatus:SetWidth(COL_W)
  local function ProfileStatus(ok, msg)
    profStatus:SetText(msg or "")
    if ok then profStatus:SetTextColor(.4, 1, .4) else profStatus:SetTextColor(1, .45, .35) end
  end
  OnRelabel(function() profStatus:SetText("") end)

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
  local deleteBtn = Button(bar, Tr("PROFILE_DELETE"), 74, 22, function()
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
    local function Do()
      local ok, msg = ns:SaveProfile(class, name)
      picked[class] = name
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
  local saveBtn = Button(bar, Tr("PROFILE_SAVE"), 150, 22, Save)
  saveBtn:SetPoint("TOPLEFT", LEFT + 174, -122)

  local textBox = TextDialog(p)
  local exportBtn = Button(bar, Tr("PROFILE_EXPORT"), 158, 22, function()
    local name = Picked()
    if not name then return end
    local hint = L.PROFILE_EXPORT_HINT
    if name == ns:ActiveProfile(editing) and ns:ProfileModified(editing) then hint = hint .. " " .. L.PROFILE_EXPORT_UNSAVED end
    textBox:Open(L.PROFILE_EXPORT_TITLE:format(name), hint, ns:ExportProfile(editing, name), L.SELECT_ALL,
      function() textBox:SelectAll() end)
  end)
  exportBtn:SetPoint("TOPLEFT", LEFT, -150)
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
  importBtn:SetPoint("TOPLEFT", LEFT + 162, -150)
  -- (a tab change or a language change closes the box: it belongs to the tab it opened on)
  OnRelabel(function() textBox:Hide() end)
  function p.ClearProfileMessages()
    profStatus:SetText("")
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
  end)
end

---------------------------------------------------------------------------
-- Where the window is (sv.window: its top left corner in UIParent units, nil = centred), its
-- scale and opacity. It is not held on the screen: /cl reset pos (or the game's AddOns
-- options) brings it back.
---------------------------------------------------------------------------
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

-- Without a scale of its own, the window is as large as fits the screen with the spells
-- panel beside it, up to 100 %.
local function AutoScale()
  local width = UIParent:GetWidth()
  if width and width > 0 then return min(1, width / (PANEL_W + SIDE_W)) end
  return 1
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

-- The spells panel opens on the right of the window: if it would go past the screen's edge,
-- the window moves left (unless it is already partly off the screen, where it was put).
function FitSidePanel()
  local left, right, top, screen = panel:GetLeft(), panel:GetRight(), panel:GetTop(), UIParent:GetRight()
  if not (left and right and top and screen) then return end
  screen = screen / panel:GetScale() -- in the window's own units
  if left >= 0 and right <= screen and right + SIDE_W > screen then
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", max(0, left - (right + SIDE_W - screen)), top)
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

function ns:ResetWindowPosition()
  self.sv.window.left, self.sv.window.top = nil, nil
  if panel then
    PlaceWindow()
    if catalog:IsShown() then FitSidePanel() end
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

-- Bottom right corner: hold the left or right mouse button on it and drag, to make the whole
-- window bigger or smaller (its top left corner stays put).
local function ScaleGrip(p)
  local grip = CreateFrame("Button", nil, p)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -5, 5)
  grip:SetFrameLevel(p:GetFrameLevel() + 20)
  grip:SetNormalTexture(GRIP .. "Up")
  grip:SetPushedTexture(GRIP .. "Down")
  grip:SetHighlightTexture(GRIP .. "Highlight")
  local percent = grip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  percent:SetPoint("BOTTOMRIGHT", grip, "TOPLEFT", 0, 2)
  percent:Hide()
  local held, left, top, offX, offY
  local function Cursor()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
  end
  -- the scale that puts the corner nearest the cursor (as it was held)
  local function Follow()
    local x, y = Cursor()
    x, y = x - offX, y - offY
    local s = ((x - left) * PANEL_W + (top - y) * PANEL_H) / (PANEL_W * PANEL_W + PANEL_H * PANEL_H)
    s = min(ns.MAX_WINDOW_SCALE, max(ns.MIN_WINDOW_SCALE, s))
    p:SetScale(s)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, top / s)
    percent:SetText(floor(s * 100 + .5) .. " %")
  end
  local function Stop()
    if not held then return end
    held = nil
    percent:Hide()
    grip:SetButtonState("NORMAL")
    ns.sv.window.scale = p:GetScale()
    SaveWindowPlace()
  end
  grip:SetScript("OnMouseDown", function(_, button)
    if held then return end
    if GameTooltip then GameTooltip:Hide() end
    local s = p:GetScale()
    left, top = p:GetLeft() * s, p:GetTop() * s
    local x, y = Cursor()
    offX, offY = x - (left + PANEL_W * s), y - (top - PANEL_H * s)
    held = button
    grip:SetButtonState("PUSHED", true)
    percent:Show()
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
  end
  return b
end

-- A part of a page placed where the parts above it end (its group box moves with it).
local function Part(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetSize(BODY_W, 1)
  f.back = CreateFrame("Frame", nil, page.back)
  f.back:SetAllPoints(f)
  function f:Place(y)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
  end
  return f
end

local function Build()
  relabels = {}
  local p = CreateFrame("Frame", "ClaraComboPointsOptions", UIParent, "PortraitFrameTemplate")
  p:Hide()
  local title = "Clara Combo Points  v" .. ns.VERSION
  if p.SetTitle then p:SetTitle(title) else ((p.TitleContainer and p.TitleContainer.TitleText) or p.TitleText):SetText(title) end
  local portrait = (p.PortraitContainer and p.PortraitContainer.portrait) or p.portrait
  p:SetSize(PANEL_W, PANEL_H)
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

  local refreshers = {}
  local function OnRefresh(fn) refreshers[#refreshers + 1] = fn end
  local resetAll

  -- Class tabs, in one row, each name in its class's colour ---------------------------
  local tabs = {}
  for i, class in ipairs(CLASSES) do
    local t = Tab(p, function()
      local c = CLASS_COLORS[class]
      return ("|cff%02x%02x%02x%s|r"):format(floor(c[1] * 255 + .5), floor(c[2] * 255 + .5), floor(c[3] * 255 + .5),
        L["TAB_" .. class])
    end, function()
      editing = class
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
  -- all as wide as the widest if the row still fits; else each at its own width; if even that
  -- is too wide (a long language), all narrowed alike (the game's tab shortens its text)
  OnRelabel(function()
    local room = PANEL_W - TABS_X - 14 - (#tabs - 1) * 4
    local widest, total = 0, 0
    for _, t in ipairs(tabs) do
      PanelTemplates_TabResize(t, 0)
      widest = max(widest, t:GetWidth())
      total = total + t:GetWidth()
    end
    local fixed
    if widest * #tabs <= room then fixed = widest elseif total > room then fixed = floor(room / #tabs) end
    for _, t in ipairs(tabs) do
      t.fixedWidth = fixed
      if fixed then PanelTemplates_TabResize(t, 0, fixed) end
    end
  end)

  -- Pages, and the list of them on the left in the order the player set by dragging them
  -- (ns.sv.pageOrder) --------------------------------------------------------------
  local nav = Box(p)
  nav:SetPoint("TOPLEFT", 12, NAV_TOP)
  nav:SetPoint("BOTTOMLEFT", 12, 40)
  nav:SetWidth(NAV_W - 16)
  local pages, navButtons = {}, {}
  for i, def in ipairs(PAGES) do
    local content = CreateFrame("Frame", nil, p)
    content:SetPoint("TOPLEFT", NAV_W, CONTENT_TOP)
    content:SetSize(BODY_W, PANEL_H + CONTENT_TOP)
    content.back = CreateFrame("Frame", nil, p) -- group boxes, under the page's widgets
    content.back:SetAllPoints(content)
    content:SetFrameLevel(content.back:GetFrameLevel() + 4)
    pages[i] = content
    navButtons[i] = NavButton(nav, i, def[1], def[2], function()
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
  Hint(p, "/cl lock  ·  /cl unlock  ·  /cl hide  ·  /cl show  ·  /cl reset  ·  /cl reset pos"):SetPoint("LEFT", p, "BOTTOMLEFT", LEFT, 22)
  local opacity = Slider(p, 90, ns.MIN_WINDOW_ALPHA * 100, 100, 1, Percent, function(v) ns:SetWindowAlpha(v / 100) end, 32)
  opacity:SetPoint("RIGHT", p, "BOTTOMRIGHT", -FOOTER_RIGHT - 52, 22)
  local opacityLabel = Text(p, Tr("WINDOW_OPACITY"))
  opacityLabel:SetPoint("RIGHT", opacity, "LEFT", -8, 0)
  OnRefresh(function() opacity:Set(floor(ns.sv.window.alpha * 100 + .5)) end)
  ScaleGrip(p)
  OnRefresh(function()
    for _, t in ipairs(tabs) do t:SetActive(t.class == editing) end
    for _, f in ipairs(flags) do f:SetActive(f.lang == ns.lang) end
    if portrait then portrait:SetTexture(ICONS[editing]) end
  end)
  OnRefresh(function()
    for i, content in ipairs(pages) do
      content:SetShown(i == page)
      content.back:SetShown(i == page)
    end
    for _, b in ipairs(navButtons) do b:SetActive(b.page == page) end
  end)

  -- General: position, size, opacity | look of the bars and their text -------------------
  local gen = pages[1]
  Section(gen, "POSITION", LEFT, -56, nil, -110)
  local lockBtn = Button(gen, "", 150, 22, function() ns:SetLocked(not ns.db.locked) end)
  lockBtn:SetPoint("TOPLEFT", LEFT, -80)
  Button(gen, Tr("DEFAULT_POS"), 150, 22, function() ns:ResetPosition() end):SetPoint("TOPLEFT", LEFT + 160, -80)
  OnRefresh(function()
    lockBtn:SetLabel(ns.db.locked and L.UNLOCK or L.LOCK)
    lockBtn:SetActive(not ns.db.locked)
  end)

  Section(gen, "SCALE", LEFT, -138, nil, -230)
  local presetButtons = {}
  for i, pct in ipairs(SCALE_PRESETS) do
    local b = Button(gen, pct .. "%", 40, 22, function() ns:SetScalePercent(pct) end)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 44, -162)
    b.percent = pct
    presetButtons[i] = b
  end
  local scaleSlider = Slider(gen, 200, ns.MIN_SCALE, ns.MAX_SCALE, 1, Percent, function(v) ns:SetScalePercent(v) end, 40)
  scaleSlider:SetPoint("LEFT", gen, "TOPLEFT", LEFT, -198)
  Hint(gen, function() return L.SCALE_HINT:format(ns.MIN_SCALE, ns.MAX_SCALE) end):SetPoint("TOPLEFT", LEFT, -214)
  OnRefresh(function()
    local now = ns:GetScalePercent()
    for _, b in ipairs(presetButtons) do b:SetActive(b.percent == now) end
    scaleSlider:Set(now)
  end)

  Section(gen, "OPACITY", LEFT, -258, nil, -386)
  Text(gen, Tr("GLOBAL_OPACITY")):SetPoint("TOPLEFT", LEFT, -282)
  local alphaSlider = Slider(gen, 100, 0, 100, 1, Percent, function(v)
    ns.db.alpha = v / 100
    ns:ApplyAlpha()
  end)
  alphaSlider:SetPoint("LEFT", gen, "TOPLEFT", LEFT + 168, -288)
  local fade = Check(gen, Tr("FADE_OOC"), function(on)
    ns.db.fadeOOC = on
    ns:PreviewFade()
    p:Refresh()
  end)
  fade:SetPoint("TOPLEFT", LEFT, -312)
  Button(gen, Tr("OOC_RESET"), 110, 22, function() ns:ResetFade() end):SetPoint("TOPRIGHT", gen, "TOPLEFT", LEFT + COL_W, -306)
  local oocPowerLabel = Text(gen, "")
  oocPowerLabel:SetPoint("TOPLEFT", LEFT + 21, -338)
  local oocPower = Slider(gen, 100, 0, 100, 1, Percent, function(v)
    ns.db.oocPower = v / 100
    ns:PreviewFade()
  end)
  oocPower:SetPoint("LEFT", gen, "TOPLEFT", LEFT + 168, -344)
  local oocTopLabel = Text(gen, "")
  oocTopLabel:SetPoint("TOPLEFT", LEFT + 21, -364)
  local oocTop = Slider(gen, 100, 0, 100, 1, Percent, function(v)
    ns.db.oocTop = v / 100
    ns:PreviewFade()
  end)
  oocTop:SetPoint("LEFT", gen, "TOPLEFT", LEFT + 168, -370)
  OnRefresh(function()
    alphaSlider:Set(floor(ns.db.alpha * 100 + .5))
    -- the bars of the class: energy / rage, or mana / health; combo points and icons, or icons
    oocPowerLabel:SetText(ns.POWER_CLASSES[editing] and L.OOC_POWER or L.OOC_MANA)
    oocTopLabel:SetText(ns.COMBO_CLASSES[editing] and L.OOC_TOP or L.OOC_ICONS)
    fade:Set(ns.db.fadeOOC)
    oocPower:Set(floor(ns.db.oocPower * 100 + .5))
    oocTop:Set(floor(ns.db.oocTop * 100 + .5))
    local a = ns.db.fadeOOC and 1 or .45 -- (only used with the fade)
    for _, r in ipairs({ oocPowerLabel, oocTopLabel, oocPower, oocPower.box.holder, oocTop, oocTop.box.holder }) do r:SetAlpha(a) end
  end)

  -- Look: the bars' style, then their values' text, then the background of every bar
  local look = Section(gen, "LOOK", RIGHT, -56)
  Text(gen, Tr("BAR_STYLE")):SetPoint("TOPLEFT", RIGHT, -80)
  local styleButtons = {}
  for i, skin in ipairs(ns.SKINS) do
    local b = Button(gen, Tr("SKIN_" .. skin), 100, 22, function()
      ns:SetSkin(skin)
      p:Refresh()
    end)
    b:SetPoint("TOPLEFT", RIGHT + (i - 1) * 108, -96)
    b.skin = skin
    styleButtons[i] = b
  end
  local styleHint = Wrapped(gen, Tr("SKIN_HINT"))
  styleHint:SetPoint("TOPLEFT", RIGHT, -124)
  local TEXT_H = 212
  local text = CreateFrame("Frame", nil, gen) -- under the hint, however many lines it takes
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
  OnRefresh(function()
    for _, b in ipairs(styleButtons) do b:SetActive(b.skin == ns.db.skin) end
    showText:SetLabel(L["SHOW_" .. RESOURCE[editing]])
    showText:Set(ns.db.showText)
    font:Refresh()
    sizeSlider:Set(ns.db.fontSize)
    for _, b in ipairs(outlineButtons) do b:SetActive(b.value == ns.db.outline) end
    look:Fit(-124 - (styleHint:GetStringHeight() or 36) - 10 - TEXT_H)
  end)

  BarsPage(p, pages[2], OnRefresh)
  IconsPage(p, pages[3], OnRefresh)

  -- Visibility: the addon shown or hidden by hand (also in the portrait's menu), druid forms,
  -- the portrait's menu | hidden in some situations -----------------------------------
  local vis = pages[4]
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
    local bottom = druid and -116 or -92
    shownBox:Fit(bottom)
    menuPart:Place(bottom - 28)
    menuLine:Set(ns.sv.menu.line ~= false)
    menuReload:Set(ns.sv.menu.reload ~= false)
  end)

  local hideBox = Section(vis, "HIDE_WHEN", RIGHT, -56)
  local COLUMNS = { solo = { 0, 1 }, party = { 0, 2 }, raid = { 0, 3 },
    dungeon = { 1, 1 }, raid10 = { 1, 2 }, raid20 = { 1, 3 }, raid40 = { 1, 4 } }
  Text(vis, Tr("HIDE_GROUP")):SetPoint("TOPLEFT", RIGHT, -80)
  Text(vis, Tr("HIDE_ZONE")):SetPoint("TOPLEFT", RIGHT + 160, -80)
  for _, key in ipairs(ns.HIDE_WHEN) do
    local at = COLUMNS[key]
    local check = Check(vis, Tr("HIDE_" .. key:upper()), function(on) ns:SetHideWhen(key, on) end)
    check:SetPoint("TOPLEFT", RIGHT + 4 + at[1] * 160, -100 - (at[2] - 1) * 22)
    OnRefresh(function() check:Set(ns.db.hideWhen[key]) end)
  end
  local hideHint = Wrapped(vis, Tr("HIDE_HINT"))
  hideHint:SetPoint("TOPLEFT", RIGHT, -196)
  OnRefresh(function() hideBox:Fit(-196 - (hideHint:GetStringHeight() or 24)) end)

  -- Profiles | reset the tab ----------------------------------------------------------
  local prof = pages[5]
  ProfilesSection(p, prof, OnRefresh)
  local resetBox = Section(prof, "RESET_TITLE", RIGHT, -56)
  resetAll = Button(prof, "", 220, 22, function()
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
  local resetHint = Wrapped(prof, Tr("RESET_HINT"))
  resetHint:SetPoint("TOPLEFT", RIGHT, -112)
  OnRefresh(function()
    resetAll:SetLabel(resetAll.armed and L.CONFIRM or L.RESET_CLASS:format(L["TAB_" .. editing]))
    resetBox:Fit(-112 - (resetHint:GetStringHeight() or 24))
  end)

  function p:Refresh()
    for _, fn in ipairs(refreshers) do fn() end
  end

  -- Opening the options shows this character's tab, with everything lit so colour changes
  -- are visible straight away.
  p:SetScript("OnShow", function(self)
    PlaceWindow()
    self:SetAlpha(ns.sv.window.alpha)
    editing = ns.homeClass or "ROGUE"
    resetAll.armed = nil
    status:SetText("")
    self.ClearProfileMessages()
    ns:SetActiveProfile(editing)
    ns:SetOptionsOpen(true)
    if InCombatLockdown() then self:Refresh() else ns:SetPreview(true) end
  end)
  p:SetScript("OnHide", function()
    drag = nil -- closed mid-drag: the icon stays where it was
    catalog.unfolded = nil -- opened again: on the tab's class
    if dragNav then -- a page of the list too (a hidden frame gets no OnDragStop)
      dragNav:SetScript("OnUpdate", nil)
      dragNav:SetAlpha(1)
      dragNav = nil
    end
    ghost:Hide()
    if ns.preview then ns:SetPreview(false) end
    ns:LockOtherProfiles()
    ns:SetActiveProfile(ns.homeClass or "ROGUE")
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
