-- Clara Combo Points - options window (/clara or /cl)
-- Built from Blizzard's own frame templates, the look of the game's windows: metal frame with
-- portrait, insets, red buttons, tabs, checkboxes and sliders.
--   Top row: one tab per class profile (Rogue, Druid, Warrior), the three pages (bar, font &
--   advanced, icons), then the language flags.
-- Colours use Blizzard's own colour picker.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

local PANEL_W, PANEL_H = 720, 660
local CONTENT_TOP = -38 -- settings start under the title, tab and language row
local LEFT, RIGHT, COL_W = 20, 380, 320
local FULL_W = PANEL_W - 2 * LEFT
local FONT_ROW_H = 22
local GOLD_R, GOLD_G, GOLD_B = 1, .82, 0
local FLAG_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Flags\\"
local ICONS = {
  ROGUE   = "Interface\\Icons\\Ability_Rogue_Eviscerate",
  DRUID   = "Interface\\Icons\\Ability_Druid_CatForm",
  WARRIOR = "Interface\\Icons\\Ability_Warrior_BattleShout",
}

local CLASS_TABS = { "ROGUE", "DRUID", "WARRIOR" }
local PAGES = { "PAGE_BAR", "PAGE_TEXT", "PAGE_ICONS" }
local COLOR_KEYS = { "cp1", "cp2", "cp3", "cp4", "cp5", "energy", "rage", "cost", "bg", "text" }
local COLOR_LABELS = { energy = "ENERGY_BAR", rage = "RAGE_BAR", cost = "COST_COLOR", bg = "BACKGROUND" }
local NO_COLOR = { ROGUE = { rage = true, cost = true }, WARRIOR = { energy = true } } -- colours a class never uses
local RESOURCE = { ROGUE = "ENERGY", DRUID = "BOTH", WARRIOR = "RAGE" }           -- energy, rage or both
local SCALE_PRESETS = { 50, 75, 100, 125, 150, 200, 300 }
local OUTLINES = { { "NONE", "OUTLINE_NONE" }, { "OUTLINE", "OUTLINE_THIN" }, { "THICKOUTLINE", "OUTLINE_THICK" } }
local ROW_LINES = { { "above", 3 }, { "above", 2 }, { "above", 1 }, false, { "below", 1 }, { "below", 2 }, { "below", 3 } }

local panel           -- the window, built the first time it opens
local editing         -- class profile shown in the window
local page = 1        -- bottom tab
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

local function Section(parent, key, x, y, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, .25)
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  OnRelabel(function()
    fs:SetText(L[key])
    line:SetWidth(max(10, (width or COL_W) - fs:GetStringWidth() - 8))
  end)
end

-- A frame of fixed height holding one setting, so settings can be stacked per class.
local function Holder(parent, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(COL_W, h)
  return f
end

-- items: { frame, height, when }; shown ones are placed one under the other from y.
local function Stack(parent, x, y, items)
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

local function Slider(parent, w, minV, maxV, step, fmt, onChange)
  local s = CreateFrame("Slider", nil, parent, "UISliderTemplate")
  s:SetSize(w, 17)
  s:SetHitRectInsets(0, 0, -5, -5) -- the template's -10 would overlap the next colour row (28px apart)
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

local function Percent(v) return v .. " %" end

local function InputBox(parent, w)
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
  tex:SetColorTexture(1, 1, 1, 1)
  if on and CreateColor and tex.SetGradient then
    tex:SetGradient("HORIZONTAL", CreateColor(1, .82, 0, .45), CreateColor(1, .82, 0, .05))
  else
    tex:SetColorTexture(1, .82, 0, on and .35 or 0)
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
  if i then return (editing == "WARRIOR" and L.ICON_COLOR or L.CP):format(tonumber(i)) end
  if key == "text" then return L["VALUE_" .. RESOURCE[editing]] end
  return L[COLOR_LABELS[key]]
end

-- One colour: label, swatch (opens the picker), opacity slider. Returns its holder and refresh.
local function ColorRow(parent, key)
  local holder = Holder(parent, 28)
  local label = Text(holder, "")
  label:SetPoint("TOPLEFT")
  label:SetWidth(118)
  label:SetWordWrap(false)

  local swatch = CreateFrame("Button", nil, holder)
  swatch:SetSize(34, 16)
  swatch:SetPoint("TOPLEFT", 122, 2)
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

  local slider = Slider(holder, 100, 0, 100, 1, Percent, function(v)
    local c = ns.db.colors[key]
    c.a = v / 100
    ns:ApplyColors()
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
  end)
  slider:SetPoint("LEFT", holder, "TOPLEFT", 168, -6)

  return holder, function()
    local c = ns.db.colors[key]
    label:SetText(ColorLabel(key))
    swatch.color:SetColorTexture(c.r, c.g, c.b, c.a)
    slider:Set(floor(c.a * 100 + .5))
  end
end

---------------------------------------------------------------------------
-- Font list: every font name is drawn in its own font, at a size that fits the list
---------------------------------------------------------------------------
local function FontList(parent, x, y, w, h)
  local box = Box(parent)
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
          panel:Refresh()
        end)
        rows[i] = row
      end
      -- Fonts drawn much bigger than the rest have their own size. Any other font is
      -- measured every time (a font still loading can measure wrong) and shrunk to fit.
      if row.fontName ~= f.name or not f.preview then
        row.fontName = f.name
        local size = f.preview or 13
        local ok = row.text:SetFont(f.path, size, "")
        if ok == false or not row.text:GetFont() then row.text:SetFontObject(GameFontHighlightSmall) end
        row.text:SetText(f.name)
        local measure = row.text.GetUnboundedStringWidth or row.text.GetStringWidth
        local width = measure(row.text)
        local path = row.text:GetFont()
        if path and not f.preview and width > textW then
          row.text:SetFont(path, max(7, floor(size * textW / width)), "")
        end
      end
      local selected = (f.name == ns.db.font)
      SelectRow(row.bg, selected)
      row.text:SetTextColor(selected and GOLD_R or 1, selected and GOLD_G or 1, selected and GOLD_B or 1)
    end
    child:SetHeight(max(h - 8, 4 + ceil(#fonts / 2) * FONT_ROW_H))
    hint:SetShown(child:GetHeight() > h - 8)
  end
end

---------------------------------------------------------------------------
-- Icon rows editor: one line per row, icons in their order
---------------------------------------------------------------------------
local ICON_X, ICON_STEP = 90, 24 -- first icon of a line, and spacing
local lines = {}                 -- the six row lines: { side, k, frame, refresh }
local drag                       -- icon being dragged: where from, the spell, where it would land
local ghost                      -- the dragged icon, following the cursor

local function IconTooltip(self)
  if not GameTooltip or drag then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  local named
  if type(self.spell) == "number" and GameTooltip.SetSpellByID then
    named = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spell)
  end
  if not named then GameTooltip:SetText(ns:SpellName(self.spell) or tostring(self.spell)) end
  if type(self.spell) == "number" then GameTooltip:AddLine("ID " .. self.spell, .6, .6, .65) end
  GameTooltip:AddLine(L.ICON_TIP, .6, .6, .65, true)
  GameTooltip:Show()
end

-- Can the dragged icon go into this row? (a full row, or the same spell already there: no)
local function Accepts(side, k)
  if side == drag.side and k == drag.k then return true end
  local spells = ns.db.rows[side][k]
  if #spells >= ns.MAX_ICONS then return false end
  local name = ns:SpellName(drag.spell)
  for _, other in ipairs(spells) do
    if other == drag.spell or (name and ns:SpellName(other) == name) then return false end
  end
  return true
end

-- What a line shows: its spells; while dragging, without the dragged icon, and with the
-- dragged icon (faded) where it would land. Returns the list and that position.
local function Shown(side, k)
  local spells = ns.db.rows[side][k]
  if not drag then return spells end
  local list = {}
  for i, spell in ipairs(spells) do
    if not (side == drag.side and k == drag.k and i == drag.i) then list[#list + 1] = spell end
  end
  if drag.toSide == side and drag.toK == k then
    local at = min(drag.toI, #list + 1)
    table.insert(list, at, drag.spell)
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

-- The landing place follows the cursor: the icon slot under it, in the line under it.
local function TrackDrag()
  local toSide, toK, toI
  for _, line in ipairs(lines) do
    local x = CursorIn(line.frame)
    if x and Accepts(line.side, line.k) then
      local n = #ns.db.rows[line.side][line.k]
      if line.side == drag.side and line.k == drag.k then n = n - 1 end
      toSide, toK = line.side, line.k
      toI = max(1, min(n + 1, floor((x - ICON_X) / ICON_STEP) + 1))
      break
    end
  end
  if toSide ~= drag.toSide or toK ~= drag.toK or toI ~= drag.toI then
    drag.toSide, drag.toK, drag.toI = toSide, toK, toI
    for _, line in ipairs(lines) do line.refresh() end
  end
  local x, y = GetCursorPosition()
  local scale = panel:GetEffectiveScale()
  ghost:ClearAllPoints()
  ghost:SetPoint("CENTER", panel, "BOTTOMLEFT", x / scale - panel:GetLeft(), y / scale - panel:GetBottom())
end

-- Released over a line: the icon moves there. Anywhere else: it goes back.
local function EndDrag()
  if not drag then return end
  TrackDrag()
  local d = drag
  drag = nil
  ghost:Hide()
  if d.toSide then
    selSide, selK = d.toSide, d.toK
    ns:MoveIconTo(d.side, d.k, d.i, d.toSide, d.toK, d.toI)
  end
  panel:Refresh()
end

local function StartDrag(button, side, k)
  if not button.spell then return end
  if GameTooltip then GameTooltip:Hide() end
  drag = { side = side, k = k, i = button.index, spell = button.spell }
  ghost.tex:SetTexture(ns:SpellIcon(button.spell))
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
  f:SetAlpha(.85)
  f:Hide()
  -- the drop also ends here if the button that started the drag went away meanwhile
  f:SetScript("OnUpdate", function()
    if not drag then return end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then EndDrag() else TrackDrag() end
  end)
  return f
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
  line:SetScript("OnClick", function()
    ClickSound()
    selSide, selK = side, k
    panel:Refresh()
  end)

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
    b:RegisterForClicks("RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(self)
      ClickSound()
      selSide, selK = side, k
      ns:RemoveIcon(side, k, self.index)
      panel:Refresh()
      if GameTooltip and GameTooltip:IsOwned(self) then
        if self:IsShown() then IconTooltip(self) else GameTooltip:Hide() end
      end
    end)
    b:SetScript("OnDragStart", function(self) StartDrag(self, side, k) end)
    b:SetScript("OnDragStop", EndDrag)
    b:SetScript("OnEnter", IconTooltip)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    icons[i] = b
  end

  local function refresh()
    local spells, landing = Shown(side, k)
    for i, b in ipairs(icons) do
      local spell = spells[i]
      b:SetShown(spell ~= nil)
      if spell ~= nil then
        b.index, b.spell = i, spell
        b.tex:SetTexture(ns:SpellIcon(spell))
        b.tex:SetAlpha(i == landing and .4 or 1)
        b.landing:SetShown(i == landing)
      end
    end
    count:SetText(#ns.db.rows[side][k] .. " / " .. ns.MAX_ICONS)
    SelectRow(line.bg, selSide == side and selK == k)
  end
  lines[#lines + 1] = { side = side, k = k, frame = line, refresh = refresh }
  return refresh
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
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
  p:SetClampedToScreen(true)
  p:EnableMouse(true)
  p:SetMovable(true)
  p:RegisterForDrag("LeftButton")
  p:SetScript("OnDragStart", p.StartMoving)
  p:SetScript("OnDragStop", p.StopMovingOrSizing)
  tinsert(UISpecialFrames, p:GetName()) -- Esc closes it
  p.relabels = relabels

  -- dark insets behind the two columns (one wide inset on the icons page)
  local insetLeft = Box(p)
  insetLeft:SetPoint("TOPLEFT", 12, -84)
  insetLeft:SetPoint("BOTTOMRIGHT", p, "BOTTOMLEFT", 368, 40)
  local insetRight = Box(p)
  insetRight:SetPoint("TOPLEFT", 372, -84)
  insetRight:SetPoint("BOTTOMRIGHT", -10, 40)
  local insetFull = Box(p)
  insetFull:SetPoint("TOPLEFT", 12, -84)
  insetFull:SetPoint("BOTTOMRIGHT", -10, 40)

  local refreshers = {}
  local function OnRefresh(fn) refreshers[#refreshers + 1] = fn end
  local resetAll, status

  -- Class tabs, language flags --------------------------------------------------
  local tabs = {}
  for i, class in ipairs(CLASS_TABS) do
    local t = Tab(p, Tr("TAB_" .. class), function()
      editing = class
      resetAll.armed = nil
      status:SetText("")
      ns:SetActiveProfile(class)
      p:Refresh()
    end)
    if i == 1 then
      t:SetPoint("BOTTOMLEFT", p, "TOPLEFT", 66, -86) -- standing on the insets, right of the portrait
    else
      t:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)
    end
    t.class = class
    tabs[i] = t
  end
  -- Pages and their tabs, after the class tabs ---------------------------------
  local pages, pageTabs = {}, {}
  for i, key in ipairs(PAGES) do
    local content = CreateFrame("Frame", nil, p)
    content:SetPoint("TOPLEFT", 0, CONTENT_TOP)
    content:SetSize(PANEL_W, PANEL_H + CONTENT_TOP)
    pages[i] = content
    local t = Tab(p, Tr(key), function()
      page = i
      p:Refresh()
    end)
    t:SetPoint("LEFT", i == 1 and tabs[#tabs] or pageTabs[i - 1], "RIGHT", i == 1 and 14 or 4, 0)
    t.page = i
    pageTabs[i] = t
  end

  local flags = {}
  for i, lang in ipairs(ns.LANGUAGES) do
    local f = Flag(p, lang, function(code) ns:SetLanguage(code) end)
    f:SetPoint("LEFT", pageTabs[#pageTabs], "RIGHT", 14 + (i - 1) * 30, -4)
    flags[i] = f
  end
  OnRefresh(function()
    for _, t in ipairs(tabs) do t:SetActive(t.class == editing) end
    for _, f in ipairs(flags) do f:SetActive(f.lang == ns.lang) end
    if portrait then portrait:SetTexture(ICONS[editing]) end
  end)
  OnRefresh(function()
    for i, content in ipairs(pages) do content:SetShown(i == page) end
    for _, t in ipairs(pageTabs) do t:SetActive(t.page == page) end
    insetFull:SetShown(page == 3)
    insetLeft:SetShown(page ~= 3)
    insetRight:SetShown(page ~= 3)
  end)

  -- Page 1: position, scale, opacity | colours -----------------------------------
  local bar = pages[1]
  Section(bar, "POSITION", LEFT, -56)
  local lockBtn = Button(bar, "", 150, 22, function() ns:SetLocked(not ns.db.locked) end)
  lockBtn:SetPoint("TOPLEFT", LEFT, -80)
  local centerBtn = Button(bar, Tr("DEFAULT_POS"), 150, 22, function() ns:ResetPosition() end)
  centerBtn:SetPoint("TOPLEFT", LEFT + 160, -80)
  OnRefresh(function()
    lockBtn:SetLabel(ns.db.locked and L.UNLOCK or L.LOCK)
    lockBtn:SetActive(not ns.db.locked)
  end)

  Section(bar, "SCALE", LEFT, -118)
  local presetButtons = {}
  for i, pct in ipairs(SCALE_PRESETS) do
    local b = Button(bar, pct .. "%", 40, 22, function() ns:SetScalePercent(pct) end)
    b:SetPoint("TOPLEFT", LEFT + (i - 1) * 44, -142)
    b.percent = pct
    presetButtons[i] = b
  end
  local scaleBox = NumberBox(bar, 50, function(text) ns:SetScalePercent(text) end)
  scaleBox.holder:SetPoint("TOPLEFT", LEFT, -172)
  Text(bar, "%"):SetPoint("LEFT", scaleBox.holder, "RIGHT", 4, 0)
  local applyScale = Button(bar, Tr("APPLY"), 90, 22, function()
    scaleBox:ClearFocus()
    ns:SetScalePercent(scaleBox:GetText())
  end)
  applyScale:SetPoint("TOPLEFT", LEFT + 72, -172)
  Hint(bar, function() return L.SCALE_HINT:format(ns.MIN_SCALE, ns.MAX_SCALE) end):SetPoint("LEFT", applyScale, "RIGHT", 10, 0)
  OnRefresh(function()
    local now = ns:GetScalePercent()
    for _, b in ipairs(presetButtons) do b:SetActive(b.percent == now) end
    if not scaleBox:HasFocus() then scaleBox:SetText(tostring(now)) end
  end)

  Section(bar, "GLOBAL_OPACITY", LEFT, -212)
  local alphaSlider = Slider(bar, 250, 0, 100, 1, Percent, function(v)
    ns.db.alpha = v / 100
    ns:ApplyAlpha()
  end)
  alphaSlider:SetPoint("LEFT", bar, "TOPLEFT", LEFT, -245)
  OnRefresh(function() alphaSlider:Set(floor(ns.db.alpha * 100 + .5)) end)

  Section(bar, "OOC", LEFT, -272)
  local fade = Check(bar, Tr("FADE_OOC"), function(on)
    ns.db.fadeOOC = on
    ns:PreviewFade()
  end)
  fade:SetPoint("TOPLEFT", LEFT, -298)
  Text(bar, Tr("OOC_POWER")):SetPoint("TOPLEFT", LEFT, -326)
  local oocPower = Slider(bar, 100, 0, 100, 1, Percent, function(v)
    ns.db.oocPower = v / 100
    ns:PreviewFade()
  end)
  oocPower:SetPoint("LEFT", bar, "TOPLEFT", LEFT + 168, -332)
  Text(bar, Tr("OOC_TOP")):SetPoint("TOPLEFT", LEFT, -354)
  local oocTop = Slider(bar, 100, 0, 100, 1, Percent, function(v)
    ns.db.oocTop = v / 100
    ns:PreviewFade()
  end)
  oocTop:SetPoint("LEFT", bar, "TOPLEFT", LEFT + 168, -360)
  OnRefresh(function()
    fade:Set(ns.db.fadeOOC)
    oocPower:Set(floor(ns.db.oocPower * 100 + .5))
    oocTop:Set(floor(ns.db.oocTop * 100 + .5))
  end)

  Section(bar, "COLORS", RIGHT, -56)
  Hint(bar, Tr("COLORS_HINT")):SetPoint("TOPLEFT", RIGHT, -76)
  local colorItems = {}
  for _, key in ipairs(COLOR_KEYS) do
    local holder, refresh = ColorRow(bar, key)
    OnRefresh(refresh)
    colorItems[#colorItems + 1] = { frame = holder, height = 28, when = function() return not (NO_COLOR[editing] or {})[key] end }
  end
  local resetColors = Holder(bar, 30)
  Button(resetColors, Tr("DEFAULT_COLORS"), 150, 22, function() ns:ResetColors() end):SetPoint("TOPLEFT", 0, -6)
  colorItems[#colorItems + 1] = { frame = resetColors, height = 30 }
  OnRefresh(Stack(bar, RIGHT, -98, colorItems))

  -- Page 2: font | advanced ----------------------------------------------------
  local text = pages[2]
  Section(text, "FONT", LEFT, -56)
  OnRefresh(FontList(text, LEFT, -80, COL_W, 230))

  Text(text, Tr("SIZE")):SetPoint("TOPLEFT", LEFT, -332)
  local sizeSlider = Slider(text, 200, 6, 40, 1, tostring, function(v)
    ns.db.fontSize = v
    ns:ApplyFont()
  end)
  sizeSlider:SetPoint("LEFT", text, "TOPLEFT", LEFT + 70, -338)
  OnRefresh(function() sizeSlider:Set(ns.db.fontSize) end)

  Text(text, Tr("OUTLINE")):SetPoint("TOPLEFT", LEFT, -362)
  local outlineButtons = {}
  for i, o in ipairs(OUTLINES) do
    local b = Button(text, Tr(o[2]), 70, 22, function()
      ns.db.outline = o[1]
      ns:ApplyFont()
      p:Refresh()
    end)
    b:SetPoint("TOPLEFT", LEFT + 70 + (i - 1) * 76, -356)
    b.value = o[1]
    outlineButtons[i] = b
  end
  OnRefresh(function()
    for _, b in ipairs(outlineButtons) do b:SetActive(b.value == ns.db.outline) end
  end)

  local showText = Check(text, nil, function(on)
    ns.db.showText = on
    ns:ApplyFont()
  end)
  showText:SetPoint("TOPLEFT", LEFT, -392)
  OnRefresh(function()
    showText:SetLabel(L["SHOW_" .. RESOURCE[editing]])
    showText:Set(ns.db.showText)
  end)

  Section(text, "ADVANCED", RIGHT, -56)
  local source = Holder(text, 34)
  Text(source, Tr("SOURCE")):SetPoint("TOPLEFT", 0, -6)
  local srcTarget = Button(source, Tr("SOURCE_TARGET"), 124, 22, function() ns:SetComboSource("TARGET") end)
  srcTarget:SetPoint("TOPLEFT", 90, 0)
  local srcPlayer = Button(source, Tr("SOURCE_PLAYER"), 90, 22, function() ns:SetComboSource("PLAYER") end)
  srcPlayer:SetPoint("TOPLEFT", 220, 0)
  OnRefresh(function()
    srcTarget:SetActive(ns.db.cpSource == "TARGET")
    srcPlayer:SetActive(ns.db.cpSource == "PLAYER")
  end)

  local forms = Holder(text, 26)
  local catOnly = Check(forms, Tr("CAT_ONLY"), function(on) ns:SetDruidCatOnly(on) end)
  catOnly:SetPoint("TOPLEFT")
  OnRefresh(function() catOnly:Set(ns.db.druidCatOnly) end)

  local predict = Holder(text, 46)
  local predictCheck = Check(predict, Tr("PREDICT"), function(on) ns:SetPredict(on) end)
  predictCheck:SetPoint("TOPLEFT")
  local predictSpells = Hint(predict, "")
  predictSpells:SetPoint("TOPLEFT", 21, -18)
  predictSpells:SetWidth(COL_W - 21)
  OnRefresh(function()
    predictCheck:Set(ns.db.predict)
    local names = {}
    for _, id in ipairs(ns.PREDICTED_SPELLS[editing] or {}) do names[#names + 1] = ns:SpellName(id) end
    predictSpells:SetText(table.concat(names, ", "))
  end)

  local preview = Holder(text, 34)
  local previewBtn = Button(preview, Tr("PREVIEW"), 150, 22, function() ns:SetPreview(not ns.preview) end)
  previewBtn:SetPoint("TOPLEFT")
  Hint(preview, Tr("PREVIEW_HINT")):SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)
  OnRefresh(function() previewBtn:SetActive(ns.preview) end)

  local reset = Holder(text, 30)
  resetAll = Button(reset, "", 150, 22, function()
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
  resetAll:SetPoint("TOPLEFT")
  OnRefresh(function() resetAll:SetLabel(resetAll.armed and L.CONFIRM or L.RESET_ALL) end)

  OnRefresh(Stack(text, RIGHT, -84, {
    { frame = source,  height = 34, when = function() return editing ~= "WARRIOR" end },
    { frame = forms,   height = 26, when = function() return editing == "DRUID" end },
    { frame = predict, height = 46, when = function() return editing ~= "ROGUE" end },
    { frame = preview, height = 34 },
    { frame = reset,   height = 30 },
  }))

  -- Page 3: icon look, adding spells, the rows ------------------------------------
  local icons = pages[3]
  Section(icons, "ICON_LOOK", LEFT, -56)
  local square = Check(icons, Tr("SQUARE"), function(on)
    ns.db.icons.square = on
    ns:LayoutIcons()
  end)
  square:SetPoint("TOPLEFT", LEFT, -84)
  Text(icons, Tr("ICON_SIZE")):SetPoint("TOPLEFT", LEFT, -108)
  local iconSize = Slider(icons, 160, 12, 64, 1, tostring, function(v)
    ns.db.icons.size = v
    ns:LayoutIcons()
  end)
  iconSize:SetPoint("LEFT", icons, "TOPLEFT", LEFT + 70, -114)
  local timers = Check(icons, Tr("SHOW_TIMERS"), function(on)
    ns.db.icons.timers = on
    ns:UpdateIcons()
  end)
  timers:SetPoint("TOPLEFT", LEFT, -138)
  local missing = Check(icons, Tr("SHOW_MISSING"), function(on)
    ns.db.icons.missing = on
    ns:UpdateIcons()
  end)
  missing:SetPoint("TOPLEFT", LEFT, -162)
  local bearFixed = Check(icons, Tr("BEAR_FIXED"), function(on) ns:SetBearIconsFixed(on) end)
  bearFixed:SetPoint("TOPLEFT", LEFT, -186)
  OnRefresh(function()
    bearFixed:SetShown(editing == "DRUID")
    bearFixed:Set(ns.db.bearIconsFixed)
    square:Set(ns.db.icons.square)
    iconSize:Set(ns.db.icons.size)
    timers:Set(ns.db.icons.timers)
    missing:Set(ns.db.icons.missing)
  end)

  Section(icons, "ADD_SPELL", RIGHT, -56)
  Hint(icons, Tr("ADD_HINT")):SetPoint("TOPLEFT", RIGHT, -78)
  local input = InputBox(icons, 180)
  input:SetMaxLetters(80)
  input.holder:SetPoint("TOPLEFT", RIGHT, -94)
  status = Text(icons, "", "GameFontHighlightSmall")
  status:SetPoint("TOPLEFT", RIGHT, -124)
  status:SetWidth(COL_W)
  OnRelabel(function() status:SetText("") end) -- a message in the old language would stay behind
  local function Add()
    local ok, msg = ns:AddIcon(selSide, selK, input:GetText())
    input:ClearFocus()
    if ok then input:SetText("") end
    status:SetText(msg or "")
    if ok then status:SetTextColor(.4, 1, .4) else status:SetTextColor(1, .45, .35) end
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

  Section(icons, "ROWS", LEFT, -200, FULL_W)
  Hint(icons, Tr("ROWS_HINT")):SetPoint("TOPLEFT", LEFT, -220)
  for i, def in ipairs(ROW_LINES) do
    local y = -240 - (i - 1) * 30
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
  Hint(icons, Tr("ICON_TIP")):SetPoint("TOPLEFT", LEFT, -456)
  ghost = DragGhost(p)

  -- Footer: commands, and which profile this character uses ------------------------
  Hint(p, "/cl lock  ·  /cl unlock  ·  /cl scale 120  ·  /cl reset"):SetPoint("BOTTOMLEFT", LEFT, 16)
  if ns.enabled then
    Hint(p, function() return L.THIS_CHARACTER:format(L["TAB_" .. ns.homeClass]) end):SetPoint("BOTTOMRIGHT", -LEFT, 16)
  else
    local warn = Text(p, Tr("WRONG_CLASS"), "GameFontHighlightSmall")
    warn:SetPoint("BOTTOMRIGHT", -LEFT, 16)
    warn:SetTextColor(1, .4, .3)
  end

  function p:Refresh()
    for _, fn in ipairs(refreshers) do fn() end
  end

  -- Opening the options shows this character's tab, with everything lit so colour changes
  -- are visible straight away.
  p:SetScript("OnShow", function(self)
    editing = ns.homeClass or "ROGUE"
    resetAll.armed = nil
    status:SetText("")
    ns:SetActiveProfile(editing)
    ns:SetOptionsOpen(true)
    if InCombatLockdown() then self:Refresh() else ns:SetPreview(true) end
  end)
  p:SetScript("OnHide", function()
    drag = nil -- closed mid-drag: the icon stays where it was
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
    panel = panel or Build()
    panel:Show()
  end
end
