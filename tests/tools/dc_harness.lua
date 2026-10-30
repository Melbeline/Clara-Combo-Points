-- Harness for the DynamicCam module of Clara Combo Points (lupa, Lua 5.1), on a permissive mock of
-- the game API (taken from the WeaponSwingTimer one). ADDON = the ClaraComboPoints folder.
local ADDON = ...
local MOD = ADDON .. "/Modules/DynamicCam"
local EXT = select(2, ...) or "/tmp/claude-0/-home-user-Clara-Combo-Points/a40ebf08-b1d3-5823-a679-3c8357a6d5fa/scratchpad/ext/dynamiccam/DynamicCam"
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
  "chat_msg", "off_width", "main_width", "spell_name", "WST_IsSecret", "getglobal", "NodeSightDB", "ClaraNodeSightDB", "ClaraNodeSight_ToggleSymbols", "NodeSight_ToggleSymbols", "DynamicCam", "DynamicCamDB", "ClaraDynamicCamDB", "ClaraComboPointsDB", "LibStub", "SLASH_DCNEW1", "returnString", "ludius_UiHideModule", "ludius_FADEFRAMES", "ludius_bars_hooked", "GW2_UI", "Bartender4", "Immersion", "cosFix", "ImmersionFrame", "BT4StatusBarTrackingManager", "ElvUI" }) do NILS[k] = true end
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
  if type(name) == "string" then rawset(env, name, f) end
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
  RegisterCanvasLayoutCategory = function(frame, name) local c = { name = name, frame = frame, GetID = function(self) return self.name end }; registered[#registered + 1] = "category " .. name; return c end,
  RegisterCanvasLayoutSubcategory = function(parent, frame, name) local c = { name = name, parent = parent, GetID = function(self) return self.name end }; registered[#registered + 1] = "subcategory " .. name .. " of " .. parent.name; return c end,
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
local cvars, defaults = {}, { test_cameraOverShoulder = "0", cameraDistanceMaxZoomFactor = "1.9", test_cameraDynamicPitch = "0", cameraView = "1" }
rawset(env, "GetCVar", function(k) return cvars[k] or defaults[k] or "0" end)
rawset(env, "SetCVar", function(k, v) cvars[k] = tostring(v) end)
rawset(env, "GetCVarDefault", function(k) return defaults[k] or "0" end)
rawset(env, "GetCVarBool", function(k) return (cvars[k] or "0") == "1" end)
rawset(env, "C_CVar", { GetCVar = env.GetCVar, SetCVar = env.SetCVar, GetCVarDefault = env.GetCVarDefault, GetCVarBool = env.GetCVarBool })

-- game tables DynamicCam reads at load
local alert = Mock("AlertFrame"); rawset(alert, "alertFrameSubSystems", {})
rawset(env, "AlertFrame", alert)
rawset(env, "hooksecurefunc", function(a, b, c)
  local t, name, fn = env, a, b
  if type(a) == "table" then t, name, fn = a, b, c end
  local old = rawget(t, name)
  if type(old) ~= "function" then return end
  rawset(t, name, function(...) local r = { old(...) }; fn(...); return unpack(r) end)
end)
local zoom = 15
rawset(env, "GetCameraZoom", function() return zoom end)
local zoomCalls = 0
local lastIncrements
rawset(env, "CameraZoomIn", function(n) zoomCalls = zoomCalls + 1; lastIncrements = n end)
rawset(env, "CameraZoomOut", function() zoomCalls = zoomCalls + 1 end)
local NativeZoomIn = env.CameraZoomIn
for k, v in pairs({ GetFramerate = 60, GetNumAvailableQuests = 0, GetNumActiveQuests = 0 }) do
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
local regSub = env.Settings.RegisterCanvasLayoutSubcategory -- (the game finds subcategories too)
env.Settings.RegisterCanvasLayoutSubcategory = function(parent, frame, name) local c = regSub(parent, frame, name); cats[c:GetID()] = c; return c end
env.Settings.GetCategory = function(id) return cats[id] end
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

-- one session: Clara's libraries and QoL.lua, then the module's files as Clara's TOC lists them
local first = 1
local function Session(opts)
  first = #frames + 1
  for _, k in ipairs({ "ClaraDynamicCamDB", "DynamicCamDB", "DynamicCam", "LibStub" }) do rawset(env, k, nil) end
  rawset(env, "ClaraComboPointsDB", opts.clara)
  if opts.saved then rawset(env, "ClaraDynamicCamDB", opts.saved) end
  if opts.standaloneDB then rawset(env, "DynamicCamDB", opts.standaloneDB) end
  local loaded = opts.standalone and function(n) return n == "DynamicCam" end or function() return false end
  rawset(env, "C_AddOns", setmetatable({ IsAddOnLoaded = loaded }, { __index = function() return function() return false end end }))
  for i = #registered, 1, -1 do registered[i] = nil end
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
  ns.settingsCategory = { name = "Clara", GetID = function() return "Clara" end } -- (SettingsPage.lua runs first)
  for _, lib in ipairs({ "LibStub/LibStub.lua", "CallbackHandler-1.0/CallbackHandler-1.0.lua", "AceDB-3.0/AceDB-3.0.lua" }) do
    run(ADDON .. "/Libs/" .. lib, lib, ns)
  end
  run(ADDON .. "/QoL.lua", "QoL.lua", ns)
  if opts.standalone then -- (the standalone's own DynamicCam, already loaded with its libraries: a stand-in)
    run(EXT .. "/Libs/AceAddon-3.0/AceAddon-3.0.lua", "AceAddon-3.0.lua", {})
    local AceAddon = env.LibStub("AceAddon-3.0", true)
    if AceAddon then
      local cam = AceAddon:NewAddon("DynamicCam")
      cam.enabledCalls = 0
      function cam:OnEnable() self.enabledCalls = self.enabledCalls + 1 end
      cam.db = { profile = { standardSettings = { cvars = { test_cameraOverShoulder = 1.5 } }, situations = {} } }
      rawset(env, "DynamicCam", cam)
    end
  end
  for line in readfile(ADDON .. "/ClaraComboPoints.toc"):gmatch("[^\r\n]+") do
    local file = line:match("^(Libs\\AceShared%.lua)$") or line:match("^(Libs\\AceDB%-3%.0%-39\\AceDB%-3%.0%.lua)$") or line:match("^(Libs\\Ace[^\\]+\\[^\\]+%.xml)$") or line:match("^(Modules\\DynamicCam\\.+)$")
    if file then
      local path = ADDON .. "/" .. file:gsub("\\", "/")
      if file:match("%.xml$") then xml(path, ns) else run(path, file, ns) end
    end
  end
  return ns
end
local function fire(event, ...)
  for i = first, #frames do local f = frames[i]
    local h = f.__scripts and f.__scripts.OnEvent
    if h then h(f, event, ...) end
  end
end

-- 1. Built in, fresh install
local ns = Session({})
assert(ns.DynamicCamRuns and ns:QolState("dynamiccam") == "on", "the module runs")
local cam = rawget(env, "DynamicCam")
assert(cam and cam.OpenMenu, "DynamicCam loaded, its functions there")
fire("ADDON_LOADED", "ClaraComboPoints")
assert(type(rawget(env, "ClaraDynamicCamDB")) == "table" and rawget(env, "DynamicCamDB") == nil, "saved in ClaraDynamicCamDB")
assert(cam.db and cam.db.profile and cam.db.profile.standardSettings, "its settings, with their defaults")
print("active: loaded, initialized, saved in ClaraDynamicCamDB")
local sub
for _, r in ipairs(registered) do if r:find("^subcategory DynamicCam of ") then sub = r end end
print("settings: " .. table.concat(registered, "; "))
fire("PLAYER_LOGIN")
assert(cam:IsEnabled(), "started at login")
local slashes = 0
for k in pairs(env.SlashCmdList) do if tostring(k):find("DYNAMICCAM") or tostring(k):find("ACECONSOLE_DC") then slashes = slashes + 1 end end
assert(slashes >= 2, "its commands (/dynamiccam, /dc)")
print("login: started, /dc there")
for _, r in ipairs(registered) do if r:find("^subcategory DynamicCam of ") then sub = r end end
assert(sub == "subcategory DynamicCam of QOL_THEME_INTERFACE", "its page under Interface: " .. table.concat(registered, "; "))
print("its page: under Interface")

-- the one-click box: Vertical Pitch and Head Tracking on or off, Zoom Increments 0.2 or 2
local std = cam.db.profile.standardSettings
ns.sv = {}
local function Shown() return cam:GetSettingsValue(nil, "reactiveZoomAddIncrementsAlways") + 1 end -- (as its slider shows it)
local function Near(a, b) return math.abs(a - b) < 1e-9 end
assert(ns:CameraAvailable() and not ns:CameraOn(), "the box: unticked (pitch and head tracking off by default)")
-- a situation with its own pitch and its own increments; another with none of them
local sits = cam.db.profile.situations
local withOwn, without
for id, sit in pairs(sits) do
  if not withOwn then withOwn = id; sit.situationSettings.cvars.test_cameraDynamicPitch = 0; sit.situationSettings.reactiveZoomAddIncrementsAlways = 3
  elseif not without then without = id; sit.situationSettings.cvars.test_cameraDynamicPitch = nil; sit.situationSettings.cvars.test_cameraHeadMovementStrength = nil
    sit.situationSettings.reactiveZoomAddIncrementsAlways = nil end
end
assert(withOwn and without, "two situations to test with")
ns:SetCameraOn(true)
assert(ns:CameraOn() and std.cvars.test_cameraDynamicPitch == 1 and std.cvars.test_cameraHeadMovementStrength == 1, "ticked: Vertical Pitch and Head Tracking on")
assert(Near(Shown(), 0.2), "ticked: Zoom Increments 0.2 (" .. Shown() .. ")")
assert(cvars.test_cameraDynamicPitch == "1" and cvars.test_cameraHeadMovementStrength == "1", "applied at once (" .. tostring(cvars.test_cameraDynamicPitch) .. ")")
assert(cam:IsEnabled(), "DynamicCam still runs")
local own = sits[withOwn].situationSettings
assert(own.cvars.test_cameraDynamicPitch == 1 and Near(own.reactiveZoomAddIncrementsAlways + 1, 0.2), "a situation that sets them itself: pitch the same, 0.2 the first time")
local none = sits[without].situationSettings
assert(none.cvars.test_cameraDynamicPitch == nil and none.reactiveZoomAddIncrementsAlways == nil, "a situation that does not: left to the standard settings")
-- what the options show (the same getters as its options)
assert(cam:GetSettingsValue(nil, "cvars", "test_cameraDynamicPitch") == 1 and cam:GetSettingsValue(nil, "cvars", "test_cameraHeadMovementStrength") == 1, "its options: Enable ticked")
ns:SetCameraOn(false)
assert(not ns:CameraOn() and std.cvars.test_cameraDynamicPitch == 0 and std.cvars.test_cameraHeadMovementStrength == 0, "unticked: both off")
assert(Near(Shown(), 2), "unticked: Zoom Increments 2 (" .. Shown() .. ")")
assert(cvars.test_cameraDynamicPitch == "0" and cvars.test_cameraHeadMovementStrength == "0", "applied at once")
assert(own.cvars.test_cameraDynamicPitch == 0 and Near(own.reactiveZoomAddIncrementsAlways + 1, 4), "the situation's own: pitch off, its own unticked increments back (4)")
assert(ns.sv.cameraZoom and Near(ns.sv.cameraZoom.standard + 1, 0.2) and Near(ns.sv.cameraZoom.situations[withOwn] + 1, 0.2), "the ticked increments kept")
assert(ns.sv.cameraZoomOff and Near(ns.sv.cameraZoomOff.standard + 1, 2) and Near(ns.sv.cameraZoomOff.situations[withOwn] + 1, 4), "the unticked ones too")
assert(cam:IsEnabled(), "DynamicCam still runs")
-- a wheel tick: the increments DynamicCam gives the game
std.reactiveZoomEnabled = false; cam:ApplySettings() -- (its plain zoom: the increments go to the game's)
lastIncrements = nil; pcall(env.CameraZoomIn, 1)
assert(lastIncrements and Near(lastIncrements, 2), "unticked: a wheel tick, 2 yards (" .. tostring(lastIncrements) .. ")")
ns:SetCameraOn(true)
lastIncrements = nil; pcall(env.CameraZoomIn, 1)
assert(lastIncrements and Near(lastIncrements, 0.2), "ticked: a wheel tick, 0.2 yards (" .. tostring(lastIncrements) .. ")")
assert(Near(own.reactiveZoomAddIncrementsAlways + 1, 0.2), "ticked again: the situation's own ticked increments back (0.2)")
-- the player's own Zoom Increments, set in its options while ticked: 2 unticked, theirs back ticked
for _, mine in ipairs({ 0.5, 0.7, 10, 0.05 }) do
  std.reactiveZoomAddIncrementsAlways = mine - 1 -- (as its slider sets it)
  ns:SetCameraOn(false)
  assert(Near(Shown(), 2), "unticked: 2 (" .. Shown() .. ")")
  ns:SetCameraOn(true)
  assert(Near(Shown(), mine), "ticked again: " .. mine .. " back (" .. Shown() .. ")")
end
-- the player's own, set in its options while unticked: theirs back unticked, the ticked one ticked
for _, mine in ipairs({ 3, 2.5, 7, 0.3 }) do
  ns:SetCameraOn(false)
  std.reactiveZoomAddIncrementsAlways = mine - 1
  ns:SetCameraOn(true)
  assert(Near(Shown(), 0.05), "ticked: the ticked one back, 0.05 (" .. Shown() .. ")")
  ns:SetCameraOn(false)
  assert(Near(Shown(), mine), "unticked again: " .. mine .. " back (" .. Shown() .. ")")
  ns:SetCameraOn(true)
end
-- unticked from the Improvements tab twice in a row: the kept value not lost
std.reactiveZoomAddIncrementsAlways = 0.6 - 1
ns:SetCameraOn(false)
assert(Near(Shown(), 0.3), "unticked: 0.3 back")
std.reactiveZoomAddIncrementsAlways = 4 - 1
ns:SetCameraOn(false)
assert(Near(Shown(), 4), "unticked again while unticked: the player's 4 left (" .. Shown() .. ")")
ns:SetCameraOn(true)
assert(Near(Shown(), 0.6), "ticked: 0.6 still back (" .. Shown() .. ")")
ns:SetCameraOn(false)
assert(Near(Shown(), 4), "unticked: 4 back (" .. Shown() .. ")")
ns:SetCameraOn(true)
-- by hand in its options: one of the two off: the box unticked; a click turns both on
std.cvars.test_cameraHeadMovementStrength = 0
assert(not ns:CameraOn(), "Head Tracking turned off in its options: unticked")
ns:SetCameraOn(true)
assert(ns:CameraOn(), "a click: both on")
local sw = ns.qolSwitches.dynamiccam[1]
sw.set(false); assert(sw.get() == false and std.cvars.test_cameraDynamicPitch == 0, "the Improvements tab's switch: the same")
sw.set(true); assert(sw.get() == true and Near(Shown(), 0.6), "and back, with the kept increments (" .. Shown() .. ")")
assert(#errors == 0, "no error: " .. table.concat(errors, " | "))
print("box: Vertical Pitch and Head Tracking on or off, Zoom Increments 0.2 or 2, DynamicCam running")

-- 2. An earlier version's "off" saved: DynamicCam started anyway; the increments kept in a past session
ns = Session({ clara = { cameraOff = true } })
cam = rawget(env, "DynamicCam")
fire("ADDON_LOADED", "ClaraComboPoints"); fire("PLAYER_LOGIN")
assert(cam:IsEnabled(), "started")
ns.sv = { cameraZoom = { standard = 0.7 - 1, situations = {} } } -- (Core.lua: ClaraComboPointsDB)
ns:SetCameraOn(true)
assert(Near(cam:GetSettingsValue(nil, "reactiveZoomAddIncrementsAlways") + 1, 0.7), "kept in a past session: 0.7 back")
ns.sv.cameraZoomOff = { standard = 5 - 1, situations = {} }
ns:SetCameraOn(false)
assert(Near(cam:GetSettingsValue(nil, "reactiveZoomAddIncrementsAlways") + 1, 5), "unticked: 5 kept in a past session back")
print("earlier saved off: started; increments kept from a past session given back")

-- 3. The standalone DynamicCam enabled: Clara's copy does nothing, the box sets the standalone's options
ns = Session({ standalone = true, standaloneDB = { profiles = { Default = { x = 1 } } } })
cam = rawget(env, "DynamicCam")
assert(not ns.DynamicCamRuns and ns:QolState("dynamiccam") == "standalone", "standalone: Clara's copy dormant")
assert(cam and cam.OpenMenu == nil and cam.Startup == nil, "Clara's DynamicCam files did not touch the standalone's DynamicCam")
fire("ADDON_LOADED", "DynamicCam"); fire("PLAYER_LOGIN")
fire("PLAYER_LOGOUT")
assert(type(rawget(env, "ClaraDynamicCamDB")) == "table" and rawget(env, "ClaraDynamicCamDB").profiles.Default.x == 1, "its settings copied")
local applied = 0
cam.ApplySettings = function() applied = applied + 1 end
cam.enabledState = true; cam.IsEnabled = function() return true end
ns:SetCameraOn(true)
local s3 = cam.db.profile.standardSettings
assert(ns:CameraOn() and s3.cvars.test_cameraDynamicPitch == 1 and Near(s3.reactiveZoomAddIncrementsAlways + 1, 0.2) and applied == 1, "the box sets the standalone's options, applied")
ns:SetCameraOn(false)
assert(not ns:CameraOn() and s3.cvars.test_cameraHeadMovementStrength == 0 and Near(s3.reactiveZoomAddIncrementsAlways + 1, 2), "and off")
assert(s3.cvars.test_cameraOverShoulder == 1.5, "its other settings left alone")
print("standalone: dormant, settings copied, the box sets its options")

-- 4. Turned off in Clara, no standalone: nothing at all
ns = Session({ clara = { qol = { dynamiccam = false } } })
assert(not ns.DynamicCamRuns and rawget(env, "DynamicCam") == nil and not ns:CameraAvailable(), "off: no DynamicCam, no box")
ns:SetCameraOn(true)
print("off: nothing loaded, the box does nothing")

-- 5. The max camera distance set in the game's options: DynamicCam keeps it at the next zooms
rawset(env, "CameraZoomIn", NativeZoomIn)
ns = Session({})
cam = rawget(env, "DynamicCam")
fire("ADDON_LOADED", "ClaraComboPoints"); fire("PLAYER_LOGIN")
ns.sv = {}
local hooked = env.SetCVar -- (the game: a CVAR_UPDATE for each change)
rawset(env, "SetCVar", function(k, v, ...) local r = hooked(k, v, ...); fire("CVAR_UPDATE", k, tostring(v)); return r end)
local std5 = cam.db.profile.standardSettings
std5.cvars.cameraDistanceMaxZoomFactor = 1
cam:ApplySettings()
assert(cvars.cameraDistanceMaxZoomFactor == "1" and std5.cvars.cameraDistanceMaxZoomFactor == 1, "DynamicCam's own applied: its setting unchanged")
local function Frames5() for i = first, #frames do local f = frames[i]; local u = f.__scripts and f.__scripts.OnUpdate; if u then pcall(u, f, 0.016) end end end
env.SetCVar("cameraDistanceMaxZoomFactor", "1.8") -- (the game's slider)
assert(std5.cvars.cameraDistanceMaxZoomFactor == 1.8, "the game's slider: DynamicCam's Maximum Camera Distance follows (" .. tostring(std5.cvars.cameraDistanceMaxZoomFactor) .. ")")
for z = 1, 6 do zoom = 5 + z * 4; Frames5() end
assert(cvars.cameraDistanceMaxZoomFactor == "1.8", "zooms: 1.8 kept (" .. tostring(cvars.cameraDistanceMaxZoomFactor) .. ")")
ns:SetCameraOn(true); ns:SetCameraOn(false)
assert(cvars.cameraDistanceMaxZoomFactor == "1.8", "the Dynamic camera box: 1.8 kept")
assert(math.abs(cam:GetSettingsValue(nil, "cvars", "cameraDistanceMaxZoomFactor") * 15 - 27) < 1e-6, "its options' slider: 27 yards")
-- a transition of DynamicCam's own: left alone
local realEased = cam.IsCvarBeingEased
cam.IsCvarBeingEased = function(_, c) return c == "cameraDistanceMaxZoomFactor" end
env.SetCVar("cameraDistanceMaxZoomFactor", "1.4")
assert(std5.cvars.cameraDistanceMaxZoomFactor == 1.8, "during its own transition: its setting unchanged")
cam.IsCvarBeingEased = realEased
env.SetCVar("cameraDistanceMaxZoomFactor", "1.8")
-- in a situation that sets its own max distance: that one follows
local sid5
for id, sit in pairs(cam.db.profile.situations) do sid5 = sid5 or id end
cam.db.profile.situations[sid5].situationSettings.cvars.cameraDistanceMaxZoomFactor = 1.2
cam.currentSituationID = sid5
cam:ApplySettings()
assert(cvars.cameraDistanceMaxZoomFactor == "1.2" and std5.cvars.cameraDistanceMaxZoomFactor == 1.8, "its situation's own applied: nothing changed")
env.SetCVar("cameraDistanceMaxZoomFactor", "2")
assert(cam.db.profile.situations[sid5].situationSettings.cvars.cameraDistanceMaxZoomFactor == 2 and std5.cvars.cameraDistanceMaxZoomFactor == 1.8,
  "in that situation: its own follows, the standard one kept")
cam.currentSituationID = nil
cam:ApplySettings()
assert(cvars.cameraDistanceMaxZoomFactor == "1.8", "out of it: the standard one again")
rawset(env, "SetCVar", hooked)
assert(#errors == 0, "no error: " .. table.concat(errors, " | "))
print("max distance from the game's options: DynamicCam follows it, kept at zooms")
print("ALL OK")
