-- Clara Combo Points - its page in the game's options (Esc > Options > AddOns): the options
-- window brought back on the screen, everything locked, the window's size, a full reset, and
-- how the addon works. Built the first time it is shown.

local ADDON, ns = ...
local L = ns.L

local floor = math.floor

local page = CreateFrame("Frame") -- the game's options panel takes it in and sizes it
page:Hide()
local built
local labels, updates = {}, {} -- texts (again on a language change), states shown

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

local function Button(key, w, onClick)
  local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  b:SetSize(w, 24)
  if key then labels[#labels + 1] = function() b:SetText(L[key]) end end
  b:SetScript("OnClick", function(self) Click(); onClick(self) end)
  return b
end

local function Text(fontObject, key)
  local fs = page:CreateFontString(nil, "ARTWORK", fontObject)
  fs:SetJustifyH("LEFT")
  if key then labels[#labels + 1] = function() fs:SetText(L[key]) end end
  return fs
end

local function Update()
  for _, fn in ipairs(labels) do fn() end
  for _, fn in ipairs(updates) do fn() end
end

-- The options window (the game's options closed first, out of combat: they would cover it).
local function OpenOptions()
  if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then SettingsPanel:Close(true) end
  ns:ShowOptions()
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText("Clara Combo Points")
  local version = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
  version:SetText("v" .. ns.VERSION)
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)

  -- First: the options window back in the middle of the screen, if it was left off it.
  local resetPos = Button("SP_RESET_POS", 270, function()
    ns:ResetWindowPosition()
  end)
  resetPos:SetPoint("TOPLEFT", 10, -66)
  Button("SP_OPEN", 220, OpenOptions):SetPoint("LEFT", resetPos, "RIGHT", 12, 0)

  local lock = Button(nil, 270, function()
    if ns:AllLocked() then ns:SetLocked(false) else ns:LockAll() end
    Update()
  end)
  lock:SetPoint("TOPLEFT", 10, -98)
  updates[#updates + 1] = function() lock:SetText(ns:AllLocked() and L.SP_UNLOCK or L.SP_LOCK_ALL) end
  Button("SP_RESET_ADDON", 220, function() ns:AskResetAddon() end):SetPoint("LEFT", lock, "RIGHT", 12, 0)

  -- The options window's size, as its bottom right corner sets it
  local sizeLabel = Text("GameFontNormal", "SP_WINDOW_SIZE")
  sizeLabel:SetPoint("TOPLEFT", 14, -142)
  local slider = CreateFrame("Slider", nil, page, "UISliderTemplate")
  slider:SetSize(200, 17)
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(ns.MIN_WINDOW_SCALE * 100, ns.MAX_WINDOW_SCALE * 100)
  slider:SetValueStep(5)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetPoint("LEFT", page, "TOPLEFT", 250, -149)
  local value = Text("GameFontHighlightSmall")
  value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  slider:SetScript("OnValueChanged", function(self, v)
    v = floor(v / 5 + .5) * 5
    value:SetText(v .. " %")
    if not self.silent then ns:SetWindowScale(v / 100) end
  end)
  local defaultSize = Button("SP_DEFAULT_SIZE", 150, function()
    ns:SetWindowScale(nil)
    Update()
  end)
  defaultSize:SetPoint("LEFT", slider, "RIGHT", 60, 0)
  updates[#updates + 1] = function()
    local v = floor(ns:GetWindowScale() * 100 + .5)
    slider.silent = true
    slider:SetValue(v)
    slider.silent = false
    value:SetText(v .. " %")
  end
  local hint = Text("GameFontHighlightSmall", "SP_HINT")
  hint:SetPoint("TOPLEFT", 14, -166)
  hint:SetPoint("RIGHT", -14, 0)
  hint:SetTextColor(.6, .6, .65)
  hint:SetWordWrap(true)

  -- What the addon adds to the portrait's right-click menu, each part shown or not
  Text("GameFontNormal", "SP_MENU"):SetPoint("TOPLEFT", 14, -196)
  local function MenuCheck(key, field, y)
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", 10, y)
    local text = check.Text or check.text
    labels[#labels + 1] = function() text:SetText(L[key]) end
    check:SetScript("OnClick", function(self)
      Click()
      ns:SetMenuOption(field, self:GetChecked()) -- (the options window's Visibility page too)
    end)
    updates[#updates + 1] = function() check:SetChecked(ns.sv.menu[field] ~= false) end
  end
  MenuCheck("SP_MENU_LINE", "line", -214)
  MenuCheck("SP_MENU_RELOAD", "reload", -238)

  -- The chat quiet while logging in: the addons' messages of the first 10 seconds taken out
  local quiet = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  quiet:SetSize(26, 26)
  quiet:SetPoint("TOPLEFT", 10, -262)
  local quietText = quiet.Text or quiet.text
  labels[#labels + 1] = function() quietText:SetText(L.SP_QUIET_LOGIN) end
  quiet:SetScript("OnClick", function(self)
    Click()
    ns:SetQuietLogin(self:GetChecked())
  end)
  updates[#updates + 1] = function() quiet:SetChecked(ns:QuietLogin()) end
  page.quietLogin = quiet

  -- /who by first name or surname (Who.lua)
  local who = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  who:SetSize(26, 26)
  who:SetPoint("TOPLEFT", 10, -286)
  local whoText = who.Text or who.text
  labels[#labels + 1] = function() whoText:SetText(L.SP_WHO_NAMES) end
  who:SetScript("OnClick", function(self)
    Click()
    ns:SetWhoNames(self:GetChecked())
  end)
  updates[#updates + 1] = function() who:SetChecked(ns:WhoNames()) end
  page.whoNames = who

  -- The game's icon in the taskbar not flashing (GameFixes.lua)
  local blink = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  blink:SetSize(26, 26)
  blink:SetPoint("TOPLEFT", 10, -310)
  local blinkText = blink.Text or blink.text
  labels[#labels + 1] = function() blinkText:SetText(L.SP_NO_BLINK) end
  blink:SetScript("OnClick", function(self)
    Click()
    ns:SetNoBlink(self:GetChecked())
  end)
  updates[#updates + 1] = function() blink:SetChecked(ns:NoBlink()) end
  page.noBlink = blink

  -- The threat percent over the game's target and focus frames (UnitBoxes.lua)
  local threat = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  threat:SetSize(26, 26)
  threat:SetPoint("TOPLEFT", 10, -334)
  local threatText = threat.Text or threat.text
  labels[#labels + 1] = function() threatText:SetText(L.SP_THREAT_BOX) end
  threat:SetScript("OnClick", function(self)
    Click()
    ns:SetThreatBox(self:GetChecked())
  end)
  updates[#updates + 1] = function() threat:SetChecked(ns:ThreatBox()) end
  page.threatBox = threat

  -- How the addon works
  local how = Text("GameFontNormalLarge", "SP_HOW")
  how:SetPoint("TOPLEFT", 14, -372)
  local box = CreateFrame("Frame", nil, page, "InsetFrameTemplate")
  box:SetPoint("TOPLEFT", 10, -394)
  box:SetPoint("BOTTOMRIGHT", -10, 10)
  local scroll = CreateFrame("ScrollFrame", "ClaraComboPointsReadmeScroll", box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -8)
  scroll:SetPoint("BOTTOMRIGHT", -30, 8)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(600, 10)
  scroll:SetScrollChild(child)
  local readme = child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  readme:SetPoint("TOPLEFT")
  readme:SetJustifyH("LEFT")
  if readme.SetJustifyV then readme:SetJustifyV("TOP") end
  if readme.SetSpacing then readme:SetSpacing(3) end
  readme:SetWordWrap(true)
  -- the text follows the page's width (set by the game's panel), and the scroll its height
  local function Fit()
    local w = scroll:GetWidth()
    if not w or w <= 0 then w = 600 end
    child:SetWidth(w)
    readme:SetWidth(w - 4)
    readme:SetText(L.SP_README)
    child:SetHeight(readme:GetStringHeight() + 12)
  end
  updates[#updates + 1] = Fit
  scroll:SetScript("OnSizeChanged", Fit)
end

-- Shown by the game's options panel (each time it opens, and when the page is picked).
function page:OnRefresh()
  if not ns.sv then return end
  if not built then Build() end
  Update()
end

function ns:RefreshSettingsPage()
  if built and page:IsVisible() then Update() end
end

-- Registered as the addon loads, so the AddOns tab lists it from the first opening on.
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, page, "Clara Combo Points")
  if ok and category then
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
  end
end
