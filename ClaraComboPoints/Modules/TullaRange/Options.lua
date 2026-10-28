-- Clara Combo Points - tullaRange's page in the game's options (Esc > Options > AddOns), as its
-- own (tullaRange_Config's color settings): for out of range, out of mana and unusable, a box to
-- turn it on or off, the color and opacity (0 to 100), desaturated or not, an icon of one's
-- spellbook showing it (a click shows another). Its three boxes also on its page of the options
-- window's Improvements tab. Built the first time it is shown.

local ADDON, ns = ...
local L = ns.L

-- Its options: this page, else the standalone tullaRange's while that one runs (found by name)
ns:SetQolOpener("tullarange", function() ns:OpenSettingsTo(ns.tullaRangeCategory or "tullaRange") end)

local TR = ns.TullaRange
if not TR then return end -- (the module does not run)

local floor = math.floor
local CHANNELS = { "TR_RED", "TR_GREEN", "TR_BLUE", "TR_OPACITY" }
local TITLES = { oor = "TR_OOR", oom = "TR_OOM", unusable = "TR_UNUSABLE" }
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function On(state) local db = TR.Settings() return db ~= nil and db[state].on end
local function SetOn(state, on)
  local db = TR.Settings()
  if not db then return end
  db[state].on = on and true or false
  TR.Refresh()
end

ns:SetQolSwitches("tullarange", {
  { label = "TR_SW_OOR", get = function() return On("oor") end, set = function(on) SetOn("oor", on) end },
  { label = "TR_SW_OOM", get = function() return On("oom") end, set = function(on) SetOn("oom", on) end },
  { label = "TR_SW_UNUSABLE", get = function() return On("unusable") end, set = function(on) SetOn("unusable", on) end },
})

-- An icon of the player's spellbook (tullaRange's), else a question mark
local function SpellIcon()
  local SB = C_SpellBook
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemTexture and bank then
    local lines = SB.GetNumSpellBookSkillLines()
    local info = lines and lines > 0 and SB.GetSpellBookSkillLineInfo(lines)
    local last = info and (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
    if last and last > 0 then
      for _ = 1, 5 do
        local texture = SB.GetSpellBookItemTexture(math.random(last), bank)
        if texture then return texture end
      end
    end
  end
  return FALLBACK_ICON
end

local page = CreateFrame("Frame") -- the game's options panel takes it in and sizes it
page:Hide()
local built
local updates = {} -- what the page shows, again on each showing

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

local function Check(parent, onClick)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetScript("OnClick", function(self) Click(); onClick(self:GetChecked() and true or false) end)
  return check
end

-- A slider of tullaRange's (its label above on the left, its value on the right), 0 to 100
local function Slider(parent, label, get, set)
  local slider = CreateFrame("Slider", nil, parent, "UISliderTemplateWithLabels")
  slider:SetHeight(17)
  slider:SetMinMaxValues(0, 100)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:EnableMouseWheel(true)
  slider.Text:SetFontObject("GameFontNormalLeft")
  slider.Text:ClearAllPoints()
  slider.Text:SetPoint("BOTTOMLEFT", slider, "TOPLEFT")
  slider.Text:SetText(L[label])
  slider.Low:SetText("")
  slider.High:SetText("")
  local value = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  value:SetJustifyH("RIGHT")
  value:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT")
  slider:SetScript("OnValueChanged", function(self, v)
    v = floor(v + 0.5)
    value:SetText(v)
    if self.showing then return end
    set(v)
  end)
  slider:SetScript("OnMouseWheel", function(self, delta)
    local low, high = self:GetMinMaxValues()
    self:SetValue(math.max(low, math.min(high, self:GetValue() + delta)))
  end)
  updates[#updates + 1] = function()
    slider.showing = true
    slider:SetValue(get())
    value:SetText(floor(get() + 0.5))
    slider.showing = nil
  end
  return slider
end

-- One state: its box and title, its icon, its four sliders, its desaturation
local function Section(state, y)
  local db = TR.Settings
  local section = CreateFrame("Frame", nil, page)
  section:SetHeight(160)
  section:SetPoint("TOPLEFT", 16, y)
  section:SetPoint("TOPRIGHT", -24, y)
  local body = CreateFrame("Frame", nil, section) -- dimmed while the state is off
  body:SetAllPoints()

  local title = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  local on = Check(section, function(v)
    SetOn(state, v)
    body:SetAlpha(v and 1 or 0.45)
  end)
  on:SetPoint("TOPLEFT", -4, 5)
  title:SetPoint("LEFT", on, "RIGHT", 2, 0)
  title:SetText(L[TITLES[state]])

  local preview = CreateFrame("Button", nil, body)
  preview:SetSize(104, 104)
  preview:SetPoint("LEFT", 0, 0)
  local icon = preview:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
  icon:SetTexture(SpellIcon())
  preview:SetScript("OnClick", function() icon:SetTexture(SpellIcon()) end)
  local function Paint()
    local c = db()[state]
    icon:SetVertexColor(c[1], c[2], c[3], c[4])
    icon:SetDesaturated(c.desaturate)
  end

  local desaturate = Check(body, function(v)
    db()[state].desaturate = v
    Paint()
    TR.Refresh()
  end)
  desaturate:SetPoint("BOTTOMLEFT", -4, -4)
  local desaturateText = desaturate.Text or desaturate.text
  desaturateText:SetFontObject("GameFontNormalSmall")
  desaturateText:SetText(L.TR_DESATURATE)

  local last
  for i, channel in ipairs(CHANNELS) do
    local slider = Slider(body, channel, function() return db()[state][i] * 100 end, function(v)
      db()[state][i] = v / 100
      Paint()
      TR.Refresh()
    end)
    if last then
      slider:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -24)
      slider:SetPoint("RIGHT")
    else
      slider:SetPoint("TOPLEFT", 150, -16)
      slider:SetPoint("RIGHT")
    end
    last = slider
  end

  updates[#updates + 1] = function()
    local c = db()[state]
    on:SetChecked(c.on)
    desaturate:SetChecked(c.desaturate)
    body:SetAlpha(c.on and 1 or 0.45)
    Paint()
  end
end

local function Update()
  if not TR.Settings() then return end
  for _, fn in ipairs(updates) do fn() end
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("tullaRange")
  local subtitle = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetPoint("RIGHT", -170, 0)
  subtitle:SetJustifyH("LEFT")
  subtitle:SetWordWrap(true)
  subtitle:SetText(L.TR_SUBTITLE)
  local defaults = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  defaults:SetSize(140, 22)
  defaults:SetPoint("TOPRIGHT", -24, -14)
  defaults:SetText(L.TR_DEFAULTS)
  defaults:SetScript("OnClick", function()
    Click()
    TR.Reset()
    Update()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)
  for i, state in ipairs(TR.STATES) do Section(state, -64 - (i - 1) * 176) end
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Update()
end)

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, page, "tullaRange")
  if ok and category then
    Settings.RegisterAddOnCategory(category)
    ns.tullaRangeCategory = category
  end
end
ns.tullaRangePage = page
