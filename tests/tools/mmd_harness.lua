-- Harness for the MinimapDrawer module of Clara Combo Points (lupa, Lua 5.1), on a
-- permissive mock of the game API (taken from the DynamicCam one). ADDON = the ClaraComboPoints folder.
local ADDON = ...
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local function chunk(path, name) return assert(loadstring(readfile(path), "@" .. name)) end

---------------------------------------------------------------------------
-- A permissive mock of the game API
---------------------------------------------------------------------------
local mockmeta
local function Mock(name)
  return setmetatable({ __name = name or "mock", __scripts = {} }, mockmeta)
end
local NUM = { GetWidth = 100, GetHeight = 20, GetStringWidth = 50, GetEffectiveScale = 1, GetRight = 500,
  GetLeft = 0, GetTop = 500, GetBottom = 0, GetScale = 1, GetFrameLevel = 1, GetNumPoints = 1,
  GetValue = 0, GetMaxLetters = 10, GetVerticalScroll = 0, GetAlpha = 1, GetNumLines = 0, GetID = 1 }
mockmeta = {
  __index = function(t, k)
    if NUM[k] then return function() return NUM[k] end end
    if k == "GetText" or k == "GetName" then return function(self) return rawget(self, "__text") or "" end end
    if k == "SetText" then return function(self, s) rawset(self, "__text", s) end end
    if k == "GetFont" then return function() return "Fonts\\FRIZQT__.TTF", 12, "" end end
    if k == "GetSize" then return function() return 100, 20 end end
    if k == "GetPoint" then return function() return "TOPLEFT", nil, "TOPLEFT", 0, 0 end end
    if k == "GetObjectType" then return function(self) return rawget(self, "__type") or "Frame" end end
    if k == "IsShown" or k == "IsVisible" or k == "IsMouseOver" or k == "GetChecked" or k == "HasFocus" then return function() return false end end
    if k == "IsEnabled" then return function() return true end end
    if k == "GetChildren" or k == "GetRegions" then return function() end end
    if k == "SetScript" then return function(self, ev, fn) self.__scripts[ev] = fn end end
    if k == "GetScript" then return function(self, ev) return self.__scripts[ev] end end
    if k == "HookScript" then return function(self, ev, fn) local o = self.__scripts[ev]; self.__scripts[ev] = function(...) if o then o(...) end return fn(...) end end end
    if k == "GetTexture" then return function() return 0 end end
    if k == "GetAttribute" then return function() return nil end end
    if k == "GetParent" then return function(self) return rawget(self, "__parent") or Mock("parent") end end
    if k == "CreateFontString" or k == "CreateTexture" or k == "CreateAnimationGroup" or k == "CreateAnimation" or k == "CreateMaskTexture" or k == "CreateLine" then
      return function(self) local m = Mock(k); rawset(m, "__parent", self); return m end
    end
    if type(k) == "string" and k:match("^[%l_]") then return nil end -- fields an addon sets itself
    local m = Mock(k); rawset(t, k, m); return m -- any other widget method or child: a callable mock
  end,
  __call = function() return Mock("call") end,
  __concat = function(a, b) return tostring(type(a) == "table" and (rawget(a, "__text") or "") or a) .. tostring(type(b) == "table" and (rawget(b, "__text") or "") or b) end,
}

local frames = {}
local env = {}
local NILS = {}
for _, k in ipairs({ "LibStub", "ElvUI", "LeaMapsDB", "ZGV", "ZGV_Notification_Entry_Template_Mixin", "TomTom",
  "TitanPlayerSettings", "TRP3_MainTooltip", "TRP3_CharacterTooltip", "TSMDestroyBtn", "LibDBIcon10_WoWtility",
  "LibDBIconTooltip", "LeaPlusDB", "LeaPlusGlobalMiniBtnClickFunc", "RemoveCommentToEnableDebug", "mutedebug",
  "arg", "x", "y", "height", "CheesePrevLevelTime", "StoreFrame", "PixelUtil", "ClaraLeaPlusDB", "GetMinimapShape",
  "ClaraWSTDB", "WSTProfileDB", "ClaraComboPointsDB", "character_hunter_settings", "character_player_settings",
  "character_target_settings", "character_core_settings", "character_castbar_settings", "character_range_settings",
  "chat_msg", "off_width", "main_width", "spell_name", "WST_IsSecret", "getglobal", "NodeSightDB", "ClaraNodeSightDB", "ClaraNodeSight_ToggleSymbols", "NodeSight_ToggleSymbols", "DynamicCam", "DynamicCamDB", "ClaraDynamicCamDB", "ClaraComboPointsDB", "LibStub", "SLASH_DCNEW1", "returnString", "ludius_UiHideModule", "ludius_FADEFRAMES", "ludius_bars_hooked", "GW2_UI", "Bartender4", "Immersion", "cosFix", "ImmersionFrame", "BT4StatusBarTrackingManager", "ElvUI", "DialogKeyNS", "DialogKeyAPI", "DialogKeyNumyDB", "ClaraDialogKeyDB", "XToLevel", "XToLevelDB", "ClaraXToLevelDB", "console", "rafMessageDisplayed", "sConfig", "sData", "ClaraXToLevel_AverageFrame_Classic", "ClaraXToLevel_AverageFrame_Blocky_PlayerFrame", "ChatThrottleLib", "LibVersionCheck", "C_SettingsUtil", "C_StringUtil", "StripHyperlinks", "GetFrameMetatable", "LibDataBroker", "C_PlayerChoice", "PlayerChoiceFrame", "PlayerSpellsFrame", "MinimapDrawerDB", "ClaraMinimapDrawerDB", "MinimapDrawerMenu", "MinimapDrawerHotspot", "MinimapDrawerDelayBox", "MinimapDrawerDelaySlider", "MinimapDrawerMoveOverlay", "SLASH_MINIMAPDRAWERRELOAD1", "SLASH_MINIMAPDRAWER1" }) do NILS[k] = true end
local G = setmetatable(env, { __index = function(t, k)
  if NILS[k] then return nil end
  if type(k) == "string" and #k == 17 and k:match("^F%w+$") then return nil end -- LeaPlusLC:CreateRandomName()
  -- unknown globals: Blizzard frames, constants and functions are mocks
  local m = Mock("G:" .. tostring(k)); rawset(t, k, m); return m
end })
local function CreateFrame(ftype, name, parent, template)
  local f = Mock("frame")
  rawset(f, "__type", ftype); rawset(f, "__parent", parent)
  frames[#frames + 1] = f
  -- (a name already taken keeps its value: XToLevel names its frame as its own table, and runs)
  if type(name) == "string" and rawget(env, name) == nil then rawset(env, name, f) end
  return f
end
for k, v in pairs({
  _G = env, print = print, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, tonumber = tonumber,
  select = select, unpack = unpack, next = next, pcall = pcall, error = error, assert = assert,
  setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
  string = string, table = table, math = math, os = os, coroutine = coroutine,
  strsplit = function(sep, s, n) local out = {}; for p in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = p end; return unpack(out) end,
  strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
  strmatch = string.match, strfind = string.find, strlower = string.lower, strupper = string.upper, strlen = string.len,
  gsub = string.gsub, format = string.format, floor = math.floor, ceil = math.ceil, max = math.max, min = math.min,
  random = math.random, tinsert = table.insert, tremove = table.remove, wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
  tContains = function(t, v) for _, x in pairs(t) do if x == v then return true end end end,
  date = os.date, time = os.time, debugprofilestop = function() return 0 end, collectgarbage = function() return 0 end,
  hooksecurefunc = function() end, securecallfunction = function(f, ...) return f(...) end,
  issecretvalue = function() return false end, canaccessvalue = function() return true end, canaccesstable = function() return true end,
  issecurevariable = function() return true end,
  CreateFrame = CreateFrame, GetLocale = function() return "enUS" end,
  GetBuildInfo = function() return "1.60.1", "1", "Oct 1 2026", 16001 end,
  UnitGUID = function() return "Player-1-00000001" end, UnitName = function() return "Melbeline" end,
  UnitClass = function() return "Rogue", "ROGUE", 4 end, UnitFactionGroup = function() return "Alliance", "Alliance" end,
  UnitLevel = function() return 10 end, UnitRace = function() return "Human", "Human" end,
  InCombatLockdown = function() return false end, UnitAffectingCombat = function() return false end,
  GetScreenWidth = function() return 1920 end, GetScreenHeight = function() return 1080 end,
  GetPhysicalScreenSize = function() return 1920, 1080 end, GetTime = function() return 0 end, GetServerTime = function() return 0 end,
  GetCVar = function() return "0" end, GetCVarBool = function() return false end, SetCVar = function() end,
  GetRealmName = function() return "Realm" end, GetNormalizedRealmName = function() return "Realm" end,
  GetCurrentRegion = function() return 3 end, IsInGuild = function() return false end, IsInGroup = function() return false end,
  IsInRaid = function() return false end, GetNumGroupMembers = function() return 0 end, IsResting = function() return false end,
  GetBindingText = function(k) return k end, GetAddOnMemoryUsage = function() return 0 end, UpdateAddOnMemoryUsage = function() end,
  RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end }),
  UISpecialFrames = {}, StaticPopupDialogs = setmetatable({}, { __index = function(t, k) local d = {}; rawset(t, k, d); return d end }),
  SlashCmdList = {}, WOW_PROJECT_ID = 1, WOW_PROJECT_MAINLINE = 1,
  LE_PARTY_CATEGORY_HOME = 1, LE_PARTY_CATEGORY_INSTANCE = 2,
  ChatTypeInfo = setmetatable({}, { __index = function(t, k) local d = {}; rawset(t, k, d); return d end }),
  CHAT_FONT_HEIGHTS = { 12, 14, 16 },
  C_Timer = { After = function() end, NewTicker = function() return Mock("ticker") end, NewTimer = function() return Mock("timer") end },
  C_CVar = { GetCVar = function() return "png" end, SetCVar = function() end },
  C_AddOns = { IsAddOnLoaded = function() return false end, GetNumAddOns = function() return 0 end,
    DoesAddOnExist = function() return false end, GetAddOnEnableState = function() return 0 end,
    IsAddOnLoadable = function() return false, "MISSING" end, GetAddOnMetadata = function() return nil end,
    EnableAddOn = function(n) error("EnableAddOn(" .. tostring(n) .. ") called") end },
  Enum = setmetatable({ AddOnEnableState = { None = 0, Some = 1, All = 2 } }, { __index = function(t, k)
    local e = setmetatable({}, { __index = function() return 0 end }); rawset(t, k, e); return e end }),
  EventUtil = { ContinueOnAddOnLoaded = function() end, RegisterOnceFrameEventAndCallback = function() end },
  MenuUtil = { CreateRadioMenu = function() end, CreateContextMenu = function() end },
  Menu = { ModifyMenu = function() end },
  TooltipDataProcessor = { AddTooltipPostCall = function() end },
  EventRegistry = { RegisterCallback = function() end },
  DropdownButtonMixin = { Event = { OnMenuClose = "OnMenuClose" } },
  ScrollUtil = Mock("ScrollUtil"), PixelUtil = nil,
}) do rawset(env, k, v) end

-- Settings API: records what is registered
local registered = {}
rawset(env, "Settings", {
  RegisterCanvasLayoutCategory = function(frame, name) local c = { name = name, ID = name, frame = frame, GetID = function(self) return self.name end }; registered[#registered + 1] = "category " .. name; return c end,
  RegisterCanvasLayoutSubcategory = function(parent, frame, name) local c = { name = name, ID = name, parent = parent, GetID = function(self) return self.name end }; registered[#registered + 1] = "subcategory " .. name .. " of " .. parent.name; return c end,
  RegisterAddOnCategory = function(c) registered[#registered + 1] = "addon category " .. c.name end,
  OpenToCategory = function(id) registered[#registered + 1] = "open " .. tostring(id) end,
  RegisterVerticalLayoutCategory = function(name) local c = { name = name, GetID = function(self) return self.name end }; registered[#registered + 1] = "vertical " .. name; return c, Mock("layout") end,
  RegisterVerticalLayoutSubcategory = function(parent, name) local c = { name = name, parent = parent, GetID = function(self) return self.name end }; registered[#registered + 1] = "vertical " .. name .. " of " .. parent.name; return c, Mock("layout") end,
  RegisterAddOnSetting = function(cat, variable, key, tbl, kind, name, default)
    local s = Mock("setting"); rawset(s, "tbl", tbl); rawset(s, "key", key); return s end,
  CreateCheckbox = function() end, CreateSlider = function() end, CreateDropdown = function() end, CreateColorSwatch = function() end,
  CreateSliderOptions = function() return Mock("options") end, CreateControlTextContainer = function() return Mock("container") end,
})
local compartment = {}
rawset(env, "AddonCompartmentFrame", { RegisterAddon = function(self, data) compartment[#compartment + 1] = data end, registeredAddons = {} })


rawset(env, "setfenv", setfenv); rawset(env, "getfenv", getfenv)
rawset(env, "CopyTable", function(t)
  local function copy(x) if type(x) ~= "table" then return x end local c = {} for k, v in pairs(x) do c[k] = copy(v) end return c end
  return copy(t) end)
rawset(env, "SlashCmdList", {})
rawset(env, "StaticPopupDialogs", {})



-- the CVars: what is set, and the game's defaults
local cvars, defaults = {}, { test_cameraOverShoulder = "0", cameraDistanceMaxZoomFactor = "1.9", test_cameraDynamicPitch = "0" }
rawset(env, "GetCVar", function(k) return cvars[k] or defaults[k] or "0" end)
rawset(env, "SetCVar", function(k, v) cvars[k] = tostring(v) end)
rawset(env, "GetCVarDefault", function(k) return defaults[k] or "0" end)
rawset(env, "GetCVarBool", function(k) return (cvars[k] or "0") == "1" end)
rawset(env, "C_CVar", { GetCVar = env.GetCVar, SetCVar = env.SetCVar, GetCVarDefault = env.GetCVarDefault, GetCVarBool = env.GetCVarBool })

-- game tables DynamicCam reads at load
local alert = Mock("AlertFrame"); rawset(alert, "alertFrameSubSystems", {})
rawset(env, "AlertFrame", alert)
for k, v in pairs({ GetFramerate = 60, GetCameraZoom = 15, GetNumAvailableQuests = 0, GetNumActiveQuests = 0 }) do
  rawset(env, k, function() return v end)
end
for _, k in ipairs({ "IsMounted", "IsFlying", "IsResting", "IsInInstance", "UnitOnTaxi", "IsEncounterInProgress", "IsIndoors",
  "IsSwimming", "IsStealthed", "UnitIsDeadOrGhost", "IsFalling", "UnitHasVehicleUI", "UnitInVehicle", "IsInRaid", "IsInGroup" }) do
  rawset(env, k, function() return false end)
end
rawset(env, "xpcall", function(f, h, ...) local n, a = select("#", ...), { ... } return xpcall(function() return f(unpack(a, 1, n)) end, h) end); rawset(env, "loadstring", loadstring); rawset(env, "strsub", string.sub); rawset(env, "strrep", string.rep)
rawset(env, "strjoin", function(sep, ...) return table.concat({ ... }, sep) end); rawset(env, "abs", math.abs); rawset(env, "mod", math.fmod)
rawset(env, "bit", { band = function(a, b) return 0 end, bor = function(a, b) return a end })
-- the game's options: categories found by ID; the mount journal: empty
local cats = {}
local reg = env.Settings.RegisterCanvasLayoutCategory
env.Settings.RegisterCanvasLayoutCategory = function(frame, name) local c = reg(frame, name); cats[c:GetID()] = c; return c end
env.Settings.GetCategory = function(id) return cats[id] end
local regSub = env.Settings.RegisterCanvasLayoutSubcategory
env.Settings.RegisterCanvasLayoutSubcategory = function(parent, frame, name) local c = regSub(parent, frame, name); cats[c:GetID()] = c; return c end
local function Zero() return setmetatable({}, { __index = function() return function() return 0 end end }) end
rawset(env, "C_MountJournal", Zero()); rawset(env, "C_PetJournal", Zero())
local errors = {}
rawset(env, "geterrorhandler", function() return function(e) errors[#errors + 1] = tostring(e); print("ERROR: " .. tostring(e)); return e end end)
-- a file listed by an XML file (Script and Include, in order, relative to it)
local function run(path, name, ns)
  local fn = chunk(path, name)
  setfenv(fn, env)
  fn("ClaraComboPoints", ns)
end
local function xml(path, ns)
  local dir = path:match("^(.*)/[^/]*$")
  for tag, file in (readfile(path):gsub("<!%-%-.-%-%->", "")):gmatch('<(%a+)%s+file="([^"]+)"') do
    local p = dir .. "/" .. file:gsub("\\", "/")
    if tag == "Script" then run(p, file, ns) elseif tag == "Include" then xml(p, ns) end
  end
end

-- numbers XToLevel reads
for k, v in pairs({ GetMaxPlayerLevel = 60, UnitXP = 1200, UnitXPMax = 4000, GetXPExhaustion = 0, GetExpansionLevel = 0,
  GetNumQuestLogEntries = 0, GetAccountExpansionLevel = 0, GetTimePreference = 0, GetGuildLevel = 0, GetNumSavedInstances = 0,
  UnitHealthMax = 100, GetNumQuestChoices = 0, GetQuestLogRewardXP = 0 }) do
  rawset(env, k, function() return v end)
end
rawset(env, "RunNextFrame", function(f) f() end)
rawset(env, "UnitNameUnmodified", function() return "Melbeline" end)
rawset(env, "strlenutf8", function(t) return #t end)
rawset(env, "GetCurrentRegionName", function() return "EU" end)
rawset(env, "RegionalUniqueNamesEnabled", function() return false end)
table.wipe = env.wipe
rawset(env, "strtrim", function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end)
rawset(env, "CreateCounter", function() local n = 0 return function() n = n + 1 return n end end)
rawset(env, "nop", function() end)
rawset(env, "GetFrameMetatable", function() return { __index = {} } end)
rawset(env, "RequestTimePlayed", function() end)

-- one session: QoL.lua, then the module's files as Clara's TOC lists them. opts.standalone: the
-- standalone MinimapDrawer loaded before Clara (its saved settings); opts.clara: ClaraComboPointsDB;
-- opts.saved: the built-in one's settings.
local addonCalls, printed = {}, {}
rawset(env, "print", function(...) printed[#printed + 1] = table.concat({ ... }, " ") end)
local function Session(opts)
  first = #frames + 1
  for _, k in ipairs({ "ClaraMinimapDrawerDB", "MinimapDrawerDB", "MinimapDrawerMenu", "MinimapDrawerHotspot",
    "MinimapDrawerDelayBox", "MinimapDrawerDelaySlider", "MinimapDrawerMoveOverlay", "SLASH_MINIMAPDRAWER1" }) do rawset(env, k, nil) end
  rawset(env, "SlashCmdList", {})
  rawset(env, "ClaraComboPointsDB", opts.clara)
  rawset(env, "ClaraMinimapDrawerDB", opts.saved)
  if opts.standalone then rawset(env, "MinimapDrawerDB", opts.standalone) end
  for i = #addonCalls, 1, -1 do addonCalls[i] = nil end
  for i = #printed, 1, -1 do printed[i] = nil end
  rawset(env, "C_AddOns", setmetatable({ IsAddOnLoaded = function(n) return opts.standalone ~= nil and n == "MinimapDrawer" end,
    DisableAddOn = function(n, who) addonCalls[#addonCalls + 1] = "disable " .. n .. " " .. tostring(who) end,
    EnableAddOn = function(n, who) addonCalls[#addonCalls + 1] = "enable " .. n .. " " .. tostring(who) end,
    SaveAddOns = function() addonCalls[#addonCalls + 1] = "save" end },
    { __index = function() return function() return false end end }))
  if opts.notForever then rawset(env, "GetBuildInfo", function() return "12.0.1", "1", "", 120001 end)
  else rawset(env, "GetBuildInfo", function() return "1.60.1", "1", "Oct 1 2026", 16001 end) end
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), qolSwitches = {} }
  run(ADDON .. "/QoL.lua", "QoL.lua", ns)
  for line in readfile(ADDON .. "/ClaraComboPoints.toc"):gmatch("[^\r\n]+") do
    local file = line:match("^(Modules\\MinimapDrawer\\.+)$")
    if file then run(ADDON .. "/" .. file:gsub("\\", "/"), file, ns) end
  end
  ns.sv = rawget(env, "ClaraComboPointsDB") or {} -- (Core.lua, at ADDON_LOADED)
  rawset(env, "ClaraComboPointsDB", ns.sv)
  return ns
end
local function fire(event, ...)
  for i = first, #frames do local f = frames[i]
    local h = f.__scripts and f.__scripts.OnEvent
    if h then h(f, event, ...) end
  end
end
-- where a frame is put: its SetPoint calls recorded
local function Record(f)
  local points = {}
  rawset(f, "ClearAllPoints", function() for i = #points, 1, -1 do points[i] = nil end end)
  rawset(f, "SetPoint", function(_, ...) points[#points + 1] = { ... } end)
  return points
end

-- 1. Built in, fresh install: it runs, its settings in Clara's own table
local ns = Session({})
assert(ns.MinimapDrawerRuns and ns:QolState("minimapdrawer") == "on", "MinimapDrawer runs")
local hotspot, menu = rawget(env, "MinimapDrawerHotspot"), rawget(env, "MinimapDrawerMenu")
assert(hotspot and menu, "its circle and drawer made")
local hotPoints, menuPoints = Record(hotspot), Record(menu)
fire("ADDON_LOADED", "ClaraComboPoints")
local db = rawget(env, "ClaraMinimapDrawerDB")
assert(type(db) == "table" and db.autoopen == true and db.portraitReload == true and db.delay == 1, "its settings, with their defaults")
assert(rawget(env, "MinimapDrawerDB") == nil, "the standalone's table not used")
fire("PLAYER_LOGIN")
local level = env.PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelText
local p = hotPoints[#hotPoints]
assert(p and p[1] == "CENTER" and p[2] == level and p[3] == "CENTER", "its circle on the level text itself (the game's, or ClassicUI's)")
local m = menuPoints[#menuPoints]
assert(m and m[1] == "BOTTOMRIGHT" and m[2] == hotspot and m[4] == 232 and m[5] == 66, "its drawer beside the circle")
assert(db.hotspot == nil and db.menuPos == nil, "nothing frozen: both follow the level text")
for _, line in ipairs(printed) do assert(not line:find("MinimapDrawer", 1, true), "no chat line the first time: " .. line) end
assert(env.SlashCmdList.MINIMAPDRAWERRELOAD == nil and env.SlashCmdList.MINIMAPDRAWER ~= nil, "/mmd; /rl left to Clara")
-- the Improvements tab: its two switches and its drawer
local sw = ns.qolSwitches.minimapdrawer
assert(sw and #sw == 2 and sw[1].label == "MMD_SW_HOVER" and sw[2].label == "MMD_SW_PORTRAIT", "two switches")
assert(sw[1].get() and sw[2].get(), "both on by default")
sw[1].set(false); sw[2].set(false)
assert(db.autoopen == false and db.portraitReload == false and not sw[1].get() and not sw[2].get(), "both turned off")
sw[1].set(true); sw[2].set(true)
assert(ns:CanOpenQol("minimapdrawer"), "its drawer opens from the tab")
ns:OpenQol("minimapdrawer")
assert(#addonCalls == 0, "no addon turned off or on")
print("built in: runs, its circle on the level text, its drawer beside it, quiet, its switches")

-- 2. Placed by hand earlier: kept where it was put
ns = Session({ saved = { hotspot = { x = 300, y = 400, size = 40 }, menuPos = { x = 700, y = 500 } } })
hotspot, menu = rawget(env, "MinimapDrawerHotspot"), rawget(env, "MinimapDrawerMenu")
hotPoints, menuPoints = Record(hotspot), Record(menu)
fire("ADDON_LOADED", "ClaraComboPoints"); fire("PLAYER_LOGIN")
p, m = hotPoints[#hotPoints], menuPoints[#menuPoints]
assert(p[1] == "CENTER" and p[2] == env.UIParent and p[4] == 300 and p[5] == 400, "its circle where it was put")
assert(m[1] == "BOTTOMRIGHT" and m[2] == env.UIParent and m[4] == 700 and m[5] == 500, "its drawer where it was put")
print("placed by hand: kept")

-- 3. The standalone enabled: it runs this session, turned off for this character, settings carried over
local own = { delay = 2.5, columns = 6, free = { LibDBIcon10_X = { 10, 20 } } }
ns = Session({ standalone = own })
assert(not ns.MinimapDrawerRuns and ns:QolState("minimapdrawer") == "standalone" and ns:QolTakesOver("minimapdrawer"), "the standalone runs this session")
assert(rawget(env, "MinimapDrawerHotspot") == nil, "nothing of Clara's copy made")
fire("PLAYER_LOGIN")
assert(addonCalls[1] == "disable MinimapDrawer Melbeline", "turned off for this character: " .. tostring(addonCalls[1]))
fire("PLAYER_LOGOUT")
local carried = rawget(env, "ClaraMinimapDrawerDB")
assert(type(carried) == "table" and carried.delay == 2.5 and carried.columns == 6 and carried.free.LibDBIcon10_X[2] == 20 and carried ~= own,
  "its settings carried over at logout")
ns = Session({ saved = carried })
fire("ADDON_LOADED", "ClaraComboPoints")
assert(ns.MinimapDrawerRuns and rawget(env, "ClaraMinimapDrawerDB").delay == 2.5, "next session: Clara's copy runs, with them")
print("standalone enabled: it runs this session, turned off for this character, settings carried over")

-- 4. Turned off, and not WoW Forever: nothing
ns = Session({ clara = { qol = { minimapdrawer = false } } })
assert(ns:QolState("minimapdrawer") == "off" and rawget(env, "MinimapDrawerHotspot") == nil, "off: nothing loaded")
ns = Session({ notForever = true })
assert(ns:QolState("minimapdrawer") == "unavailable" and rawget(env, "MinimapDrawerHotspot") == nil, "not Forever: unavailable")
print("off, not Forever: nothing loaded")
assert(#errors == 0, "no error: " .. table.concat(errors, " | "))
print("ALL OK")
