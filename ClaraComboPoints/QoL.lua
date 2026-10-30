-- Clara Combo Points - interface improvements: other addons' features, built in. BuyEmAll,
-- Leatrix Plus (with Cheese's level-up screenshot as one of its options), NodeSight, DynamicCam,
-- DialogKey, XToLevel, MinimapDrawer, idTip, Solo Raid Frame, Enhanced Raid Frames, DoesItDie and
-- Enemy Casts (Clara's own) sit under
-- "Interface improvements" in the game's options (Esc > Options > AddOns), apart from Clara Combo
-- Points; WeaponSwingTimer, tullaRange and Names have their own entries there, What's Training? its
-- window (/wt). Each module runs only in WoW Forever, and only if not turned off here. When its own addon
-- is enabled, that one runs instead (its settings are carried over for the day it is turned off);
-- DialogKey, XToLevel, MinimapDrawer, tullaRange, idTip, Solo Raid Frame, Enhanced Raid Frames,
-- DoesItDie and What's Training? take over from theirs: it
-- runs for that session, then it is turned off for the character, so that the built-in one runs
-- from the next reload (and it is turned back on if the module is turned off here).
-- Saved variables load before the files here (## LoadSavedVariablesFirst), so each module
-- knows at once whether it runs.

local ADDON, ns = ...
local L = ns.L

-- The modules, in the order they are listed. standalone: the addon it comes from; takeOver: the
-- built-in one runs instead of it (from the next reload: it is turned off for the character).
ns.QOL_MODULES = {
  { key = "buyemall", name = "BuyEmAll", standalone = "BuyEmAllClassic" },
  { key = "leatrix", name = "Leatrix Plus", standalone = "Leatrix_Plus" },
  { key = "nodesight", name = "NodeSight", standalone = "NodeSight" },
  { key = "wst", name = "WeaponSwingTimer", standalone = "WeaponSwingTimer" },
  { key = "dynamiccam", name = "DynamicCam", standalone = "DynamicCam" },
  { key = "dialogkey", name = "DialogKey", standalone = "DialogKey_Numy", takeOver = true },
  { key = "xtolevel", name = "XToLevel", standalone = "XToLevel", takeOver = true },
  { key = "minimapdrawer", name = "MinimapDrawer", standalone = "MinimapDrawer", takeOver = true },
  { key = "tullarange", name = "tullaRange", standalone = "tullaRange", takeOver = true },
  { key = "mail", name = "Mail" }, -- (Clara's own: no addon of its own)
  { key = "names", name = "Names" }, -- (Clara's own: its own entry in the game's options)
  { key = "tooltipanchor", name = "Tooltip Anchor" }, -- (Clara's own)
  { key = "idtip", name = "idTip", standalone = "idTip", takeOver = true },
  { key = "soloraidframe", name = "Solo Raid Frame", standalone = "SoloRaidFrameNV", takeOver = true },
  { key = "enhancedraidframes", name = "Enhanced Raid Frames", standalone = "EnhancedRaidFrames", takeOver = true },
  { key = "doesitdie", name = "DoesItDie", standalone = "DoesItDie", takeOver = true },
  { key = "whatstraining", name = "What's Training?", standalone = "WhatsTraining", takeOver = true },
  { key = "enemycasts", name = "Enemy Casts" }, -- (Clara's own)
  -- its own addon running: the text list is that one's, the rest (icons, search, filter) still ours
  { key = "reverseengineering", name = "Reverse Engineering", standalone = "ReverseEngineering" },
}

-- WoW Forever builds are 160xx (the modules' own code is for them; the retail builds Clara's
-- TOC also lists are not)
local toc = GetBuildInfo and select(4, GetBuildInfo()) or 0
ns.FOREVER = type(toc) == "number" and toc >= 16000 and toc < 20000

-- Is the addon enabled for this character, and loaded or about to be? (it is in ## OptionalDeps:
-- enabled, it has loaded before Clara Combo Points)
function ns:StandaloneRuns(name)
  local A = C_AddOns
  if not (A and name) then return false end
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

local modules = {}
for _, m in ipairs(ns.QOL_MODULES) do modules[m.key] = m end

-- Its own addon runs this session, and the built-in one takes over from the next reload?
function ns:QolTakesOver(key)
  return modules[key].takeOver == true and state[key] == "standalone" and Wanted(key)
end

-- A module's own addon turned off (or back on) for this character, from the next reload; the
-- ones turned off here are kept (sv.qolTookOver[key][character]), to be turned back on.
local function Me()
  local name = UnitName and UnitName("player")
  return name, name and (name .. "-" .. tostring(GetRealmName and GetRealmName() or ""))
end
local function TookOver(key)
  local _, me = Me()
  local list = ns.sv and ns.sv.qolTookOver and ns.sv.qolTookOver[key]
  return me ~= nil and list ~= nil and list[me] == true
end
local function StandaloneOn(m, on)
  local A, name, me = C_AddOns, Me()
  if not (A and A.EnableAddOn and A.DisableAddOn and name and ns.sv) then return end
  if on then
    if not TookOver(m.key) then return end -- (turned off by hand: left so)
    A.EnableAddOn(m.standalone, name)
    ns.sv.qolTookOver[m.key][me] = nil
    if next(ns.sv.qolTookOver[m.key]) == nil then ns.sv.qolTookOver[m.key] = nil end
    if next(ns.sv.qolTookOver) == nil then ns.sv.qolTookOver = nil end
  else
    A.DisableAddOn(m.standalone, name)
    ns.sv.qolTookOver = ns.sv.qolTookOver or {}
    ns.sv.qolTookOver[m.key] = ns.sv.qolTookOver[m.key] or {}
    ns.sv.qolTookOver[m.key][me] = true
  end
  if A.SaveAddOns then A.SaveAddOns() end
end

-- At login: the own addons that run this session are turned off for the next ones.
local takeOver = CreateFrame("Frame")
takeOver:RegisterEvent("PLAYER_LOGIN")
takeOver:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  for _, m in ipairs(ns.QOL_MODULES) do
    if ns:QolTakesOver(m.key) then StandaloneOn(m, false) end
  end
end)

-- Turned on or off: from the next session (a module cannot be loaded or unloaded midway). A
-- module that takes over: its own addon turned off with it on (while that one runs), back on
-- with it off.
function ns:QolEnabled(key) return not (self.sv and self.sv.qol and self.sv.qol[key] == false) end
function ns:SetQolEnabled(key, on)
  self.sv.qol = self.sv.qol or {}
  if on then self.sv.qol[key] = nil else self.sv.qol[key] = false end
  if next(self.sv.qol) == nil then self.sv.qol = nil end
  local m = modules[key]
  if m.takeOver and state[key] ~= "unavailable" then
    if not on then
      StandaloneOn(m, true)
    elseif state[key] == "standalone" then
      StandaloneOn(m, false)
    end
  end
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
  if now == "standalone" and wanted and m.takeOver then return L.QOL_TAKEOVER:format(m.name, m.name) end
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
