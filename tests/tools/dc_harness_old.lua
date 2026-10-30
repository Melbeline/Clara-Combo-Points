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
rawset(env, "CameraZoomIn", function() zoomCalls = zoomCalls + 1 end)
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
    local file = line:match("^(Modules\\DynamicCam\\.+)$")
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

-- the one-click box
ns.sv = {}
assert(ns:CameraAvailable() and ns:CameraOn(), "the box: on")
cvars.test_cameraOverShoulder = "1.5"; cvars.cameraDistanceMaxZoomFactor = "2.6"
cam.db.profile.standardSettings.cvars.test_cameraOverShoulder = 1.5
cam.db.profile.standardSettings.cvars.cameraDistanceMaxZoomFactor = 2.6
ns:SetCameraOn(false)
assert(not cam:IsEnabled() and not ns:CameraOn() and ns.sv.cameraOff == true, "off: DynamicCam stopped, kept")
assert(cvars.test_cameraOverShoulder == "0" and cvars.cameraDistanceMaxZoomFactor == "1.9", "off: its camera settings back to the game's defaults ("
  .. tostring(cvars.test_cameraOverShoulder) .. ", " .. tostring(cvars.cameraDistanceMaxZoomFactor) .. ")")
ns:SetCameraOn(true)
assert(cam:IsEnabled() and ns:CameraOn() and ns.sv.cameraOff == nil, "on again")
local sw = ns.qolSwitches.dynamiccam[1]
sw.set(false); assert(sw.get() == false and not cam:IsEnabled(), "the Improvements tab's switch: the same")
sw.set(true)
assert(#errors == 0, "no error: " .. table.concat(errors, " | "))
print("box: off stops it and gives the game's camera back, on starts it again")

-- 2. Turned off in a past session: not started at login
ns = Session({ clara = { cameraOff = true } })
cam = rawget(env, "DynamicCam")
fire("ADDON_LOADED", "ClaraComboPoints"); fire("PLAYER_LOGIN")
assert(not cam:IsEnabled(), "kept off: not started")
ns.sv = { cameraOff = true }
ns:SetCameraOn(true)
assert(cam:IsEnabled(), "turned on: started")
print("kept off: not started at login")

-- 3. The standalone DynamicCam enabled: Clara's copy does nothing, the box drives the standalone
ns = Session({ standalone = true, standaloneDB = { profiles = { Default = { x = 1 } } }, clara = { cameraOff = true } })
cam = rawget(env, "DynamicCam")
assert(not ns.DynamicCamRuns and ns:QolState("dynamiccam") == "standalone", "standalone: Clara's copy dormant")
assert(cam and cam.OpenMenu == nil and cam.Startup == nil, "Clara's DynamicCam files did not touch the standalone's DynamicCam")
assert(cam.enabledState == false, "kept off: the standalone not started either")
fire("ADDON_LOADED", "DynamicCam"); fire("PLAYER_LOGIN")
assert(not cam:IsEnabled() and cam.enabledCalls == 0, "login: the standalone stays off")
fire("PLAYER_LOGOUT")
assert(type(rawget(env, "ClaraDynamicCamDB")) == "table" and rawget(env, "ClaraDynamicCamDB").profiles.Default.x == 1, "its settings copied")
ns.sv = { cameraOff = true }
ns:SetCameraOn(true)
assert(cam:IsEnabled() and cam.enabledCalls >= 1, "the box starts the standalone")
print("standalone: dormant, settings copied, the box drives it")

-- 4. Turned off in Clara, no standalone: nothing at all
ns = Session({ clara = { qol = { dynamiccam = false } } })
assert(not ns.DynamicCamRuns and rawget(env, "DynamicCam") == nil and not ns:CameraAvailable(), "off: no DynamicCam, no box")
print("off: nothing loaded")
-- 5. Turned off by the camera box: nothing of DynamicCam at work any more, the player's camera back
rawset(env, "CameraZoomIn", NativeZoomIn) -- (a new session: the game's zoom, not the past sessions' copies)
ns = Session({})
cam = rawget(env, "DynamicCam")
fire("ADDON_LOADED", "ClaraComboPoints"); fire("PLAYER_LOGIN")
ns.sv = {}
ns:SetCameraOn(false)
cvars.cameraDistanceMaxZoomFactor = "2.6" -- (the player's own, set in the game's options while it is off)
ns:SetCameraOn(true) -- (the game's values kept as they are now)
assert(ns.sv.cameraWas and ns.sv.cameraWas.cameraDistanceMaxZoomFactor == "2.6", "on: the game's camera values kept")
cam.db.profile.standardSettings.cvars.cameraDistanceMaxZoomFactor = 1
cam.db.profile.standardSettings.cvars.test_cameraOverShoulder = 1.5
local function Frames() for i = first, #frames do local f = frames[i]; local u = f.__scripts and f.__scripts.OnUpdate; if u then pcall(u, f, 0.016) end end end
zoom = 10; Frames()
assert(cvars.cameraDistanceMaxZoomFactor == "1", "on, a zoom: DynamicCam's own max distance (" .. tostring(cvars.cameraDistanceMaxZoomFactor) .. ")")
assert(env.CameraZoomIn ~= NativeZoomIn, "on: its mouse wheel zoom")
ns:SetCameraOn(false)
assert(cvars.cameraDistanceMaxZoomFactor == "2.6", "off: the player's max distance back (" .. tostring(cvars.cameraDistanceMaxZoomFactor) .. ")")
assert(env.CameraZoomIn == NativeZoomIn and env.CameraZoomOut ~= nil, "off: the game's own mouse wheel zoom")
-- the player's settings in the game's options, then zooms: left as they are
SetCVar = env.SetCVar
env.SetCVar("cameraDistanceMaxZoomFactor", "2.6")
for z = 1, 5 do zoom = 10 + z * 3; Frames() end
assert(cvars.cameraDistanceMaxZoomFactor == "2.6" and cvars.test_cameraOverShoulder ~= "1.5", "off, zooms: nothing applied (" .. tostring(cvars.cameraDistanceMaxZoomFactor) .. ")")
cvars.CameraKeepCharacterCentered = "0"
env.SetCVar("CameraKeepCharacterCentered", "1")
assert(cvars.CameraKeepCharacterCentered == "1", "off: the game's motion sickness setting left alone")
-- on again: DynamicCam's camera, applied again
ns:SetCameraOn(true)
zoom = 30; Frames()
assert(cam:IsEnabled() and cvars.cameraDistanceMaxZoomFactor == "1", "on again: DynamicCam's camera again")
env.SetCVar("CameraKeepCharacterCentered", "1")
assert(cvars.CameraKeepCharacterCentered == "0" or cvars.CameraKeepCharacterCentered == "false", "on: its motion sickness guard again (" .. tostring(cvars.CameraKeepCharacterCentered) .. ")")
assert(#errors == 0, "no error: " .. table.concat(errors, " | "))
print("box off: nothing applied at zooms, the game's zoom and settings, the player's camera values back; on: DynamicCam again")
print("ALL OK")
