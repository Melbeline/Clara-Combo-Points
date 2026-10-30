-- Clara Combo Points - UnitScan's page in the game's options (Esc > Options > AddOns > Clara Combo
-- Points > UnitScan): what it looks for, how it alerts, what is heard and sent, the names looked for and
-- the hunted mob. Built the first time it is shown. /cl scan opens it.

local ADDON, ns = ...
local L = ns.L

local page = CreateFrame("Frame")
page:Hide()
local built
local labels, updates = {}, {}

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

local function Update()
  for _, fn in ipairs(labels) do fn() end
  for _, fn in ipairs(updates) do fn() end
end

local function Text(fontObject, key, x, y, width)
  local fs = page:CreateFontString(nil, "ARTWORK", fontObject)
  fs:SetJustifyH("LEFT")
  fs:SetPoint("TOPLEFT", x, y)
  if width then fs:SetWidth(width) fs:SetWordWrap(true) end
  if key then labels[#labels + 1] = function() fs:SetText(L[key]) end end
  return fs
end

local function Check(key, option, y, words)
  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetPoint("TOPLEFT", 10, y)
  local text = check.Text or check.text
  labels[#labels + 1] = function() text:SetText(words and words() or L[key]) end
  check:SetScript("OnClick", function(self)
    Click()
    ns:SetScanOption(option, self:GetChecked() and true or false)
  end)
  updates[#updates + 1] = function() check:SetChecked(ns:ScanOption(option)) end
  page[option] = check
  return check
end

local function Edit(x, y, width)
  local edit = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  edit:SetSize(width, 22)
  edit:SetPoint("TOPLEFT", x, y)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  return edit
end

local function Button(key, width, onClick)
  local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  labels[#labels + 1] = function() b:SetText(L[key]) end
  b:SetScript("OnClick", function(self) Click() onClick(self) end)
  return b
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText("UnitScan")
  local intro = Text("GameFontHighlightSmall", "SCAN_INTRO", 14, -52, 600)
  intro:SetTextColor(.7, .7, .75)

  local count = 0
  for _ in pairs(ns.RARES or {}) do count = count + 1 end
  Check("SCAN_OPT_RARES", "rares", -86, function() return L.SCAN_OPT_RARES:format(count) end)
  Check("SCAN_OPT_PLAYERS", "players", -110)
  Check("SCAN_OPT_SOUND", "sound", -134)
  Check("SCAN_OPT_FLASH", "flash", -158)
  Check("SCAN_OPT_TASKBAR", "taskbar", -182)
  Check("SCAN_OPT_PLATES", "plates", -206)

  -- Other players' sightings
  Text("GameFontNormal", "SCAN_SHARING", 14, -240)
  local receive = Text("GameFontHighlightSmall", "SCAN_RECEIVE", 14, -258, 600)
  receive:SetTextColor(.7, .7, .75)
  Check("SCAN_OPT_FAR", "far", -290)
  Check("SCAN_OPT_SEND", "send", -314)

  -- The names looked for: one typed again comes off the list
  Text("GameFontNormal", "SCAN_NAMES", 14, -350)
  local nameEdit = Edit(20, -368, 220)
  local function AddName()
    local name = nameEdit:GetText()
    if name and name:match("%S") then ns:ToggleScanName(name) end
    nameEdit:SetText("")
    nameEdit:ClearFocus()
    Update()
  end
  nameEdit:SetScript("OnEnterPressed", AddName)
  Button("SCAN_ADD", 140, AddName):SetPoint("LEFT", nameEdit, "RIGHT", 10, 0)
  local list = Text("GameFontHighlightSmall", nil, 20, -396, 590)
  updates[#updates + 1] = function()
    local names = ns:ScanNames()
    list:SetText(#names > 0 and table.concat(names, "  ·  ") or L.SCAN_NAMES_NONE)
  end

  -- The hunted mob and its key
  Text("GameFontNormal", "SCAN_HUNT", 14, -432)
  local huntEdit = Edit(20, -450, 220)
  local function SetHunt()
    ns:SetScanHunt(huntEdit:GetText())
    huntEdit:ClearFocus()
    Update()
  end
  huntEdit:SetScript("OnEnterPressed", SetHunt)
  Button("SCAN_SET", 140, SetHunt):SetPoint("LEFT", huntEdit, "RIGHT", 10, 0)
  updates[#updates + 1] = function() huntEdit:SetText(ns:ScanHunt() or "") end
  local key = Text("GameFontHighlightSmall", nil, 20, -478, 590)
  updates[#updates + 1] = function()
    local bound = GetBindingKey and GetBindingKey("CLICK ClaraScanHunt:LeftButton")
    key:SetText(L.SCAN_HUNT_KEY:format(bound and GetBindingText(bound) or L.SCAN_NO_KEY))
  end

  Button("SCAN_TEST", 180, function()
    ns.ScanFound(L.SCAN_TEST_NAME, "#test" .. GetTime(), L.SCAN_RARE, false, false)
  end):SetPoint("TOPLEFT", 14, -512)
end

function page:OnRefresh()
  if not ns.sv then return end
  if not built then Build() end
  Update()
end
page:SetScript("OnShow", function(self) self:OnRefresh() end)

-- Under the Quests and progress page of Clara Combo Points (QoL.lua registers it first)
local parent = ns.qolThemes and ns.qolThemes.quests or ns.settingsCategory
if parent and Settings and Settings.RegisterCanvasLayoutSubcategory then
  local ok, sub = pcall(Settings.RegisterCanvasLayoutSubcategory, parent, page, "UnitScan")
  if ok and sub then ns.scanCategory = sub end
end

function ns:OpenScanPage()
  if not (ns.scanCategory and Settings and Settings.OpenToCategory) then return end
  if InCombatLockdown() then return end
  Settings.OpenToCategory(ns.scanCategory:GetID())
end
