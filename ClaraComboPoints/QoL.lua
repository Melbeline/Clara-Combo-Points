-- Clara Combo Points - interface improvements: other addons' features, built in (and a few of Clara's
-- own). Each runs only in WoW Forever, and only if not turned off here. When its own addon is enabled,
-- that one runs for that session (its settings are carried over), then it is turned off for the
-- character, so that the built-in one runs from the next reload: never both, and the game loads one
-- copy only (it is turned back on if the module is turned off here).
-- Saved variables load before the files here (## LoadSavedVariablesFirst), so each module
-- knows at once whether it runs.

local ADDON, ns = ...
local L = ns.L

-- The modules, in the order they are listed. standalone: the addon it comes from (the built-in one runs
-- instead of it, from the next reload: it is turned off for the character); theme: the page it is on
-- (combat, interface, quests, economy); keep: its own addon is never turned off (newer than the built-in one:
-- while it is enabled, it runs and the built-in one steps aside).
ns.QOL_MODULES = {
  { key = "buyemall", name = "BuyEmAll", standalone = "BuyEmAllClassic", theme = "economy" },
  { key = "wst", name = "WeaponSwingTimer", standalone = "WeaponSwingTimer", theme = "combat" },
  { key = "dialogkey", name = "DialogKey", standalone = "DialogKey_Numy", theme = "quests" },
  { key = "minimapdrawer", name = "MinimapDrawer", standalone = "MinimapDrawer", theme = "interface" },
  { key = "tullarange", name = "tullaRange", standalone = "tullaRange", theme = "combat" },
  { key = "mail", name = "Mail", theme = "economy" }, -- (Clara's own: no addon of its own)
  { key = "money", name = "Gold tracker", theme = "economy" }, -- (Clara's own)
  { key = "tooltipanchor", name = "Tooltip Anchor", theme = "interface" }, -- (Clara's own)
  { key = "barscale", name = "Bar scale", theme = "interface" }, -- (Clara's own: the bars, micro menu and bags at once)
  { key = "idtip", name = "idTip", standalone = "idTip", theme = "interface" },
  { key = "soloraidframe", name = "Solo Raid Frame", standalone = "SoloRaidFrameNV", theme = "combat" },
  { key = "doesitdie", name = "DoesItDie", standalone = "DoesItDie", theme = "combat" },
  { key = "enemycasts", name = "Enemy Casts", theme = "combat" }, -- (Clara's own)
  { key = "fishing", name = "Fishing", standalone = "EasyFishing", title = "Easy Fishing", keep = true, theme = "economy" },
  { key = "unitscan", name = "UnitScan", theme = "quests" }, -- (Clara's own, heard with UnitScan Hardcore)
}
-- Modules no longer built in that took over from their own addon: that one is turned back on for
-- the characters it was turned off for (at their next login; it runs from the next reload).
local RETIRED = { { key = "xtolevel", standalone = "XToLevel" } }

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
  return modules[key].standalone ~= nil and not modules[key].keep and state[key] == "standalone" and Wanted(key)
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
  for _, m in ipairs(RETIRED) do StandaloneOn(m, true) end
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
  if m.standalone and not m.keep and state[key] ~= "unavailable" then
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
-- Fishing: Easy Fishing's page while it runs, else Clara's own page (its fishing mode box); UnitScan: its page
openers.fishing = function()
  if state.fishing == "standalone" then ns:OpenSettingsTo("Easy Fishing") else ns:OpenSettingsTo(ns.settingsCategory) end
end
openers.unitscan = function() if ns.OpenScanPage then ns:OpenScanPage() end end

-- A module's main switches, on its page of its theme's page of Clara Combo Points' options:
-- { { label = locale key, get = function, set = function(on) }, ... }
ns.qolSwitches = {}
function ns:SetQolSwitches(key, list) self.qolSwitches[key] = list end

---------------------------------------------------------------------------
-- The modules in the game's options (Esc > Options > AddOns > Clara Combo Points), one page per
-- theme: each module of the theme, where it stands, its box (on or off from the next reload), what
-- it does, its main switches and a button to its own pages, which are under the theme's page.
---------------------------------------------------------------------------
local THEMES = { "combat", "interface", "quests", "economy" }
ns.qolThemes, ns.qolThemePages = {}, {}
local refreshers = {}

function ns:RefreshQol()
  for _, fn in ipairs(refreshers) do fn() end
end
function ns:OnQolRefresh(fn) refreshers[#refreshers + 1] = fn end -- (the options window's Improvements tab too)

-- The modules whose box waits for a reload (turned on or off, or taking over from their own addon)
if ns.AddReloadCheck then ns:AddReloadCheck(function()
  local names = {}
  for _, m in ipairs(ns.QOL_MODULES or {}) do
    local now, wanted = state[m.key], ns:QolEnabled(m.key)
    if (now == "on" and not wanted) or (now == "off" and wanted) or (now == "standalone" and wanted and not m.keep) then
      names[#names + 1] = m.name
    end
  end
  return names
end) end

-- What a module's state says, in a line.
function ns:QolStatusText(m)
  local now = state[m.key]
  local wanted = self:QolEnabled(m.key)
  if now == "unavailable" then return L.QOL_UNAVAILABLE end
  if now == "standalone" and wanted and not m.keep then return L.QOL_TAKEOVER:format(m.name, m.name) end
  if now == "standalone" then return L.QOL_STANDALONE:format(m.title or m.name) end
  if now == "on" and not wanted then return L.QOL_OFF_NEXT end
  if now == "off" and wanted then return L.QOL_ON_NEXT end
  return now == "on" and L.QOL_ON or L.QOL_OFF
end

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

-- One module on its theme's page; the block's height for where it stands
local function Block(sheet, m, page)
  local check = CreateFrame("CheckButton", nil, sheet, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  local text = check.Text or check.text
  text:SetFontObject("GameFontNormalLarge")
  check:SetScript("OnClick", function(self)
    Click()
    ns:SetQolEnabled(m.key, self:GetChecked())
  end)
  local open = CreateFrame("Button", nil, sheet, "UIPanelButtonTemplate")
  open:SetSize(150, 22)
  open:SetScript("OnClick", function() ns:OpenQol(m.key) end)
  local status = sheet:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  status:SetJustifyH("LEFT")
  status:SetWordWrap(true)
  local about = sheet:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  about:SetJustifyH("LEFT")
  about:SetWordWrap(true)
  about:SetTextColor(.82, .82, .85)
  local switches = {}
  for n, sw in ipairs(ns.qolSwitches[m.key] or {}) do
    local c = CreateFrame("CheckButton", nil, sheet, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    local label = c.Text or c.text
    label:SetFontObject("GameFontHighlightSmall")
    c:SetScript("OnClick", function(self)
      Click()
      sw.set(self:GetChecked() and true or false)
      ns:RefreshQol()
    end)
    switches[n] = { check = c, label = label, sw = sw }
  end
  page["check_" .. m.key], page["open_" .. m.key] = check, open
  return function(y, width) -- (its widgets placed from y down; the next block's y)
    local now = state[m.key]
    text:SetText(L["QOL_NAV_" .. m.key:upper()] or m.name)
    check:SetChecked(ns:QolEnabled(m.key))
    check:SetEnabled(now ~= "unavailable")
    check:ClearAllPoints()
    check:SetPoint("TOPLEFT", sheet, "TOPLEFT", 4, y)
    open:SetText(L.QOL_OPEN)
    open:SetEnabled((now == "on" or now == "standalone") and openers[m.key] ~= nil)
    open:ClearAllPoints()
    open:SetPoint("TOPRIGHT", sheet, "TOPLEFT", width - 4, y - 2)
    status:SetText(ns:QolStatusText(m))
    status:SetTextColor(now == "on" and .25 or 1, now == "on" and .82 or .82, now == "on" and .25 or 0)
    status:SetWidth(width - 34)
    status:ClearAllPoints()
    status:SetPoint("TOPLEFT", sheet, "TOPLEFT", 32, y - 26)
    about:SetText(L["QOL_ABOUT_" .. m.key:upper()] or "")
    about:SetWidth(width - 34)
    about:ClearAllPoints()
    about:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -4)
    y = y - 26 - (status:GetStringHeight() or 12) - 4 - (about:GetStringHeight() or 12) - 4
    for _, s in ipairs(switches) do
      local shown = now == "on"
      s.check:SetShown(shown)
      if shown then
        s.label:SetText(L[s.sw.label] or s.sw.label)
        s.check:SetChecked(s.sw.get() and true or false)
        s.check:ClearAllPoints()
        s.check:SetPoint("TOPLEFT", sheet, "TOPLEFT", 30, y)
        y = y - 22
      end
    end
    return y - 18
  end
end

ns.QolBlock = Block -- (the options window's Improvements tab shows the same, one module a page: Options.lua)

-- A theme's page: its title, a line on the boxes, its modules (they scroll), Reload UI
local function BuildTheme(page, theme)
  page.built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -60)
  hint:SetPoint("RIGHT", -14, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.6, .6, .65)
  local reload = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  reload:SetSize(200, 24)
  reload:SetPoint("BOTTOMLEFT", 14, 8)
  reload:SetScript("OnClick", function() if C_UI and C_UI.Reload then C_UI.Reload() else ReloadUI() end end)
  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -86)
  scroll:SetPoint("BOTTOMRIGHT", -30, 40)
  local sheet = CreateFrame("Frame", nil, scroll)
  sheet:SetSize(1, 1)
  scroll:SetScrollChild(sheet)
  page.scroll, page.sheet = scroll, sheet
  local blocks = {}
  for _, m in ipairs(ns.QOL_MODULES) do
    if m.theme == theme then blocks[#blocks + 1] = Block(sheet, m, page) end
  end
  local function Lay()
    local width = scroll:GetWidth() or 0
    if width <= 0 then width = 600 end
    sheet:SetWidth(width)
    title:SetText(L["QOL_THEME_" .. theme:upper()])
    hint:SetText(L.QOL_HINT)
    reload:SetText(L.RELOAD_UI)
    local y = -4
    for _, lay in ipairs(blocks) do y = lay(y, width) end
    sheet:SetHeight(math.max(1, -y))
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
  end
  refreshers[#refreshers + 1] = function() if page:IsVisible() then Lay() end end
  scroll:SetScript("OnSizeChanged", function() if page:IsVisible() then Lay() end end)
  page.Lay = Lay
end

for _, theme in ipairs(THEMES) do
  local page = CreateFrame("Frame")
  page:Hide()
  function page:OnRefresh()
    if not ns.sv then return end
    if not self.built then BuildTheme(self, theme) end
    self.Lay()
  end
  page:SetScript("OnShow", page.OnRefresh)
  ns.qolThemePages[theme] = page
  if ns.settingsCategory and Settings and Settings.RegisterCanvasLayoutSubcategory then
    local ok, category = pcall(Settings.RegisterCanvasLayoutSubcategory, ns.settingsCategory, page,
      L["QOL_THEME_" .. theme:upper()])
    if ok and category then ns.qolThemes[theme] = category end
  end
end

-- The page a module's own pages go under: its theme's (else Clara Combo Points' own)
function ns:QolCategory(key)
  local m = modules[key]
  return m and self.qolThemes[m.theme] or self.settingsCategory
end
function ns:QolCategoryID(key)
  local category = self:QolCategory(key)
  return category and category:GetID() or nil
end

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
