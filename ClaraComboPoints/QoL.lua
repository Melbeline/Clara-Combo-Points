-- Clara Combo Points - interface improvements: other addons' features, built in. BuyEmAll,
-- Leatrix Plus (with Cheese's level-up screenshot as one of its options) and NodeSight sit
-- under "Interface improvements" in the game's options (Esc > Options > AddOns), apart from
-- Clara Combo Points; WeaponSwingTimer has its own entry there. Each module runs only in WoW
-- Forever, only when its own addon is not enabled (that one runs instead, and its settings are
-- carried over for the day it is turned off), and only if not turned off here.
-- Saved variables load before the files here (## LoadSavedVariablesFirst), so each module
-- knows at once whether it runs.

local ADDON, ns = ...
local L = ns.L

-- The modules, in the order they are listed. standalone: the addon it comes from.
ns.QOL_MODULES = {
  { key = "buyemall", name = "BuyEmAll", standalone = "BuyEmAllClassic" },
  { key = "leatrix", name = "Leatrix Plus", standalone = "Leatrix_Plus" },
  { key = "nodesight", name = "NodeSight", standalone = "NodeSight" },
  { key = "wst", name = "WeaponSwingTimer", standalone = "WeaponSwingTimer" },
}

-- WoW Forever builds are 160xx (the modules' own code is for them; the retail builds Clara's
-- TOC also lists are not)
local toc = GetBuildInfo and select(4, GetBuildInfo()) or 0
ns.FOREVER = type(toc) == "number" and toc >= 16000 and toc < 20000

-- Is the addon enabled for this character, and loaded or about to be? (it is in ## OptionalDeps:
-- enabled, it has loaded before Clara Combo Points)
function ns:StandaloneRuns(name)
  local A = C_AddOns
  if not A then return false end
  if A.IsAddOnLoaded and A.IsAddOnLoaded(name) then return true end
  if A.DoesAddOnExist and not A.DoesAddOnExist(name) then return false end
  if not (A.GetAddOnEnableState and A.IsAddOnLoadable) then return false end
  local who = UnitGUID and UnitGUID("player") or UnitName("player")
  local none = Enum and Enum.AddOnEnableState and Enum.AddOnEnableState.None or 0
  if A.GetAddOnEnableState(name, who) == none then return false end
  return A.IsAddOnLoadable(name, who) == true
end

-- Turned off by hand? (the switches are saved with Clara's settings: sv.qol[key] == false)
local function Wanted(key)
  local sv = type(ClaraComboPointsDB) == "table" and ClaraComboPointsDB or nil
  local qol = sv and type(sv.qol) == "table" and sv.qol or nil
  return not (qol and qol[key] == false)
end

-- Where each module stands this session: "on" (built in, running), "standalone" (its addon runs
-- instead), "off" (turned off), "unavailable" (not WoW Forever). Decided once, as the files load.
local state = {}
for _, m in ipairs(ns.QOL_MODULES) do
  if not ns.FOREVER then
    state[m.key] = "unavailable"
  elseif ns:StandaloneRuns(m.standalone) then
    state[m.key] = "standalone"
  elseif not Wanted(m.key) then
    state[m.key] = "off"
  else
    state[m.key] = "on"
  end
end

function ns:QolState(key) return state[key] end
function ns:QolRuns(key) return state[key] == "on" end

-- Turned on or off: from the next session (a module cannot be loaded or unloaded midway).
function ns:QolEnabled(key) return not (self.sv and self.sv.qol and self.sv.qol[key] == false) end
function ns:SetQolEnabled(key, on)
  self.sv.qol = self.sv.qol or {}
  if on then self.sv.qol[key] = nil else self.sv.qol[key] = false end
  if next(self.sv.qol) == nil then self.sv.qol = nil end
  self:RefreshQol()
end

-- A module's options: its own panel (set by the module), else its page in the game's options.
local openers = {}
function ns:SetQolOpener(key, fn) openers[key] = fn end
function ns:OpenQol(key)
  if openers[key] then return openers[key]() end
end
function ns:CanOpenQol(key) return openers[key] ~= nil end

-- A module's main switches, on its page of the options window's Improvements tab:
-- { { label = locale key, get = function, set = function(on) }, ... }
ns.qolSwitches = {}
function ns:SetQolSwitches(key, list) self.qolSwitches[key] = list end

---------------------------------------------------------------------------
-- "Interface improvements" in the game's options: the modules, where each stands, a box to
-- turn each on or off, its options. The modules' own pages are under it (WeaponSwingTimer: its
-- own entry).
---------------------------------------------------------------------------
local page = CreateFrame("Frame")
page:Hide()
local built
local refreshers = {}

function ns:RefreshQol()
  for _, fn in ipairs(refreshers) do fn() end
  if self.RefreshOptions then self:RefreshOptions() end -- (the options window's Improvements tab)
end

-- What a module's state says, in a line.
function ns:QolStatusText(m)
  local now = state[m.key]
  local wanted = self:QolEnabled(m.key)
  if now == "unavailable" then return L.QOL_UNAVAILABLE end
  if now == "standalone" then return L.QOL_STANDALONE:format(m.name) end
  if now == "on" and not wanted then return L.QOL_OFF_NEXT end
  if now == "off" and wanted then return L.QOL_ON_NEXT end
  return now == "on" and L.QOL_ON or L.QOL_OFF
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  refreshers[#refreshers + 1] = function() title:SetText(L.QOL_TITLE) end
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -62)
  hint:SetPoint("RIGHT", -14, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.6, .6, .65)
  refreshers[#refreshers + 1] = function() hint:SetText(L.QOL_HINT) end
  local y = -100
  for _, m in ipairs(ns.QOL_MODULES) do
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", 10, y)
    local text = check.Text or check.text
    text:SetFontObject("GameFontNormal")
    text:SetText(m.name)
    check:SetScript("OnClick", function(self)
      if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
      ns:SetQolEnabled(m.key, self:GetChecked())
    end)
    local status = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 40, y - 26)
    status:SetPoint("RIGHT", -170, 0)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(true)
    local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    open:SetSize(150, 22)
    open:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, y - 2)
    open:SetScript("OnClick", function() ns:OpenQol(m.key) end)
    refreshers[#refreshers + 1] = function()
      check:SetChecked(ns:QolEnabled(m.key))
      check:SetEnabled(state[m.key] ~= "unavailable")
      status:SetText(ns:QolStatusText(m))
      open:SetText(L.QOL_OPEN)
      open:SetEnabled((state[m.key] == "on" or state[m.key] == "standalone") and openers[m.key] ~= nil)
    end
    page["check_" .. m.key], page["open_" .. m.key] = check, open
    y = y - 64
  end
  local reload = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  reload:SetSize(200, 24)
  reload:SetPoint("TOPLEFT", 14, y - 6)
  reload:SetScript("OnClick", function() if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end end)
  refreshers[#refreshers + 1] = function() reload:SetText(L.RELOAD_UI) end
end

function page:OnRefresh()
  if not ns.sv then return end
  if not built then Build() end
  ns:RefreshQol()
end

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, page, L.QOL_TITLE)
  if ok and category then
    Settings.RegisterAddOnCategory(category)
    ns.qolCategory = category
  end
end
ns.qolPage = page

-- The game's options opened on a page (from a click: not in combat). category: the page, or the
-- name of another addon's page (found among the game's options; none found: nothing opens).
function ns:OpenSettingsTo(category)
  if type(category) == "string" then
    category = SettingsPanel and SettingsPanel.GetCategory and SettingsPanel:GetCategory(category)
  end
  if not category or InCombatLockdown() or not (Settings and Settings.OpenToCategory) then return end
  local id = category.GetID and category:GetID() or category
  Settings.OpenToCategory(id)
end
