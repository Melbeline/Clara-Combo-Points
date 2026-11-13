-- Clara Combo Points - XP bar text: on the game's experience bar, its own text ("XP: 18970/19400") always shown, with the
-- level's percent after it ("(98%)"), and a hunter's pet's experience to its right ("Pet XP: 1897/1940 (98%)"), text
-- only (no bar of its own), each in a color of its own (the player's white, the pet's a light green: both plain on the
-- bar's purple, on the rested blue and on the rested part still to come), picked with the game's color picker on its
-- page. Kept small: the game's own text and its own setting ("xpBarText", shown always: put on once, then the
-- player's), the text written again after each of the game's updates (a hook after it) and as the pet's experience
-- changes; nothing else of the bar touched. Its page in Esc > Options > AddOns > Clara > Interface > XP bar text, its
-- boxes on its card. Saved with Clara's settings (ClaraComboPointsDB.xpText).

local ADDON, ns = ...
local L = ns.L

local PLAYER_COLOR = { 1, 1, 1 }          -- the game's own white
local PET_COLOR = { 0.55, 1, 0.55 }       -- a light green, plain on the purple and the blue

local runs = ns:QolRuns("xptext")

local function Store()
  local sv = ns.sv
  if not sv then return nil end
  if type(sv.xpText) ~= "table" then sv.xpText = {} end
  return sv.xpText
end
local function Color(key, default)
  local s = Store()
  local c = s and s[key]
  if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then return c end
  return default
end
local function ShowPet()
  local s = Store()
  return not (s and s.noPet)
end
local function Always()
  return GetCVarBool and GetCVarBool("xpBarText") or false
end

local Refresh = function() end
local function SetAlways(on)
  if SetCVar then SetCVar("xpBarText", on and "1" or "0") end -- (the game's own setting: the game shows or hides it)
end
local function SetShowPet(on)
  local s = Store()
  if s then s.noPet = (not on) or nil end
  Refresh()
end

ns:SetQolSwitches("xptext", {
  { label = "XPT_SW_ALWAYS", get = Always, set = SetAlways },
  { label = "XPT_SW_PET", get = ShowPet, set = SetShowPet },
})
ns:SetQolOpener("xptext", function() ns:OpenSettingsTo(ns.xpTextCategory) end)
if not runs then return end

---------------------------------------------------------------------------
-- The text
---------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end
local function Number(v) return type(v) == "number" and not issecret(v) end

-- Rounded (18970/19400: 98 %, as the game's own tooltip gives it), never 100 % before the level is reached
local function Percent(cur, max)
  local p = math.floor(cur / max * 100 + 0.5)
  if p >= 100 and cur < max then p = 99 end
  return p
end

local function Hex(c)
  local function B(v) return math.max(0, math.min(255, math.floor(v * 255 + 0.5))) end
  return ("ff%02x%02x%02x"):format(B(c[1]), B(c[2]), B(c[3]))
end

local function PlayerText()
  local cur, max = UnitXP("player"), UnitXPMax("player")
  if not (Number(cur) and Number(max)) or max <= 0 then return nil end
  return (XP_STATUS_BAR_TEXT or "XP: %s/%s"):format(cur, max) .. L.XPT_PERCENT:format(Percent(cur, max))
end

local function PetText()
  if not ShowPet() or not GetPetExperience then return nil end
  local ok, cur, max = pcall(GetPetExperience)
  if not ok or not (Number(cur) and Number(max)) or max <= 0 then return nil end
  return L.XPT_PET:format(cur, max, Percent(cur, max))
end

local function Compose()
  local player = PlayerText()
  if not player then return nil end
  local text = "|c" .. Hex(Color("player", PLAYER_COLOR)) .. player .. "|r"
  local pet = PetText()
  if pet then text = text .. "   |c" .. Hex(Color("pet", PET_COLOR)) .. pet .. "|r" end
  return text
end
ns.XPTextCompose = Compose -- (for the tests)

---------------------------------------------------------------------------
-- The game's experience bars (one in each of its two bar places): their text written after the game's
---------------------------------------------------------------------------
local bars = {}

local function Write(bar)
  local fs = bar and bar.OverlayFrame and bar.OverlayFrame.Text
  if not (fs and fs.SetText) then return end
  local ok, capped = pcall(function() return bar.IsCapped and bar:IsCapped() end)
  if ok and capped then return end -- (a trial account's banked experience: the game's text)
  local text = Compose()
  if text then fs:SetText(text) end
end

Refresh = function()
  for _, bar in ipairs(bars) do Write(bar) end
end
ns.XPTextRefresh = Refresh -- (for the tests)

local function Hook()
  local info = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum
  local index = info and info.Experience
  if not index then return end
  for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
    local bar = type(container) == "table" and type(container.bars) == "table" and container.bars[index]
    if bar and type(bar.UpdateCurrentText) == "function" then
      bars[#bars + 1] = bar
      hooksecurefunc(bar, "UpdateCurrentText", Write)
    end
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    -- Shown always by default: the game's own setting, put on once (then the player's, on its page or the game's)
    local s = Store()
    if s and not s.alwaysSet then
      s.alwaysSet = true
      SetAlways(true)
    end
    Hook()
    Refresh()
    self:RegisterEvent("UNIT_PET_EXPERIENCE")
    self:RegisterEvent("UNIT_PET")
    self:RegisterEvent("PLAYER_XP_UPDATE")
    self:RegisterEvent("PLAYER_LEVEL_UP")
    return
  end
  if event == "UNIT_PET" and unit ~= "player" then return end
  Refresh()
end)

---------------------------------------------------------------------------
-- Its page: under its theme's page in Clara's options
---------------------------------------------------------------------------
local page = CreateFrame("Frame")
page:Hide()
local built
local updates = {}
local swatches = {}
ns.XPTextPage, ns.XPTextSwatches = page, swatches -- (for the tests)

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end
local function Update() for _, fn in ipairs(updates) do fn() end end

local function Check(label, y, get, set)
  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetPoint("TOPLEFT", 10, y)
  local text = check.Text or check.text
  text:SetFontObject("GameFontHighlight")
  text:SetText(label)
  check:SetScript("OnClick", function(self)
    Click()
    set(self:GetChecked() and true or false)
    Update()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)
  updates[#updates + 1] = function() check:SetChecked(get()) end
end

-- A color: its swatch (a click opens the game's color picker), Cancel puts the one before back
local function Swatch(label, y, key, default)
  local button = CreateFrame("Button", nil, page)
  button:SetSize(22, 22)
  button:SetPoint("TOPLEFT", 14, y)
  local border = button:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints()
  border:SetColorTexture(0.8, 0.8, 0.8, 1)
  local fill = button:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", -2, 2)
  local text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("LEFT", button, "RIGHT", 8, 0)
  text:SetText(label)
  swatches[key] = button
  local function Show()
    local c = Color(key, default)
    fill:SetColorTexture(c[1], c[2], c[3], 1)
  end
  updates[#updates + 1] = Show
  local function Put(r, g, b)
    local s = Store()
    if s then s[key] = { r, g, b } end
    Show()
    Refresh()
  end
  button:SetScript("OnClick", function()
    Click()
    local start = Color(key, default)
    local r0, g0, b0 = start[1], start[2], start[3]
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
  title:SetText(L.QOL_NAV_XPTEXT)
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -62)
  hint:SetPoint("RIGHT", -24, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.6, .6, .65)
  hint:SetText(L.XPT_HINT)

  Check(L.XPT_ALWAYS, -100, Always, SetAlways)
  Check(L.XPT_PET_SHOW, -126, ShowPet, SetShowPet)
  Swatch(L.XPT_COLOR_PLAYER, -164, "player", PLAYER_COLOR)
  Swatch(L.XPT_COLOR_PET, -194, "pet", PET_COLOR)
  local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  reset:SetSize(200, 22)
  reset:SetPoint("TOPLEFT", 14, -232)
  reset:SetText(L.XPT_DEFAULT)
  swatches.reset = reset
  reset:SetScript("OnClick", function()
    Click()
    local s = Store()
    if s then s.player, s.pet = nil, nil end
    Update()
    Refresh()
  end)
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Update()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local ok, category = pcall(function()
    if ns:QolCategory("xptext") and Settings.RegisterCanvasLayoutSubcategory then
      return Settings.RegisterCanvasLayoutSubcategory(ns:QolCategory("xptext"), page, L.QOL_NAV_XPTEXT)
    end
    local c = Settings.RegisterCanvasLayoutCategory(page, L.QOL_NAV_XPTEXT)
    Settings.RegisterAddOnCategory(c)
    return c
  end)
  if ok and category then ns.xpTextCategory = category end
end
