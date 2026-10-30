-- Harness for the NodeSight module of Clara Combo Points (lupa, Lua 5.1), on a permissive mock of
-- the game API (taken from the WeaponSwingTimer one). ADDON = the ClaraComboPoints folder.
local ADDON = ...
local MOD = ADDON .. "/Modules/NodeSight"
local FILES = { "Bootstrap.lua", "Names.lua", "NodeSight.lua", "Sparkles.lua", "FarSparkles.lua", "WhatsNew.lua", "Settings.lua" }
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
  "chat_msg", "off_width", "main_width", "spell_name", "WST_IsSecret", "getglobal", "NodeSightDB", "ClaraNodeSightDB", "ClaraNodeSight_ToggleSymbols", "NodeSight_ToggleSymbols" }) do NILS[k] = true end
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


-- one session: QoL.lua, then the module's files, then its events
local first = 1 -- events go to the frames of the current session only
local function Session(opts)
  first = #frames + 1
  for _, k in ipairs({ "ClaraNodeSightDB", "NodeSightDB" }) do rawset(env, k, nil) end
  if opts.saved then rawset(env, "ClaraNodeSightDB", opts.saved) end
  if opts.standaloneDB then rawset(env, "NodeSightDB", opts.standaloneDB) end
  local loaded = opts.standalone and function(n) return n == "NodeSight" end or function() return false end
  rawset(env, "C_AddOns", setmetatable({ IsAddOnLoaded = loaded }, { __index = function() return function() return false end end }))
  for i = #registered, 1, -1 do registered[i] = nil end
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
  ns.settingsCategory = { name = "Clara", GetID = function() return "Clara" end } -- (SettingsPage.lua runs first)
  local function run(path, name)
    local fn = chunk(path, name)
    setfenv(fn, env)
    fn("ClaraComboPoints", ns)
  end
  run(ADDON .. "/QoL.lua", "QoL.lua")
  for _, f in ipairs(FILES) do run(MOD .. "/" .. f, f) end
  return ns
end
local function fireStrict(event, ...)
  for i = first, #frames do local f = frames[i]
    local h = f.__scripts and f.__scripts.OnEvent
    if h then h(f, event, ...) end
  end
end
local function has(line) for _, l in ipairs(registered) do if l == line then return true end end end

-- 1. Built in, fresh install
local ns = Session({})
assert(ns.NodeSight and ns:QolState("nodesight") == "on", "the module runs")
assert(rawget(env, "ClaraNodeSight_ToggleSymbols") and rawget(env, "NodeSight_ToggleSymbols") == nil, "its binding's function, under Clara's name")
assert(rawget(env, "BINDING_NAME_CLARA_NODESIGHT_SYMBOLS"), "the binding named")
fireStrict("ADDON_LOADED", "SomethingElse")
assert(rawget(env, "ClaraNodeSightDB") == nil, "another addon loading: nothing yet")
fireStrict("ADDON_LOADED", "ClaraComboPoints")
local db = rawget(env, "ClaraNodeSightDB")
assert(type(db) == "table" and db.scan == true and db.mapIcons == true and db.arrow == false, "saved in ClaraNodeSightDB, at NodeSight's defaults")
assert(rawget(env, "NodeSightDB") == nil, "the standalone's table left alone")
assert(has("vertical NodeSight of QOL_THEME_QUESTS") and not has("addon category NodeSight"), "its settings under Quests and progress: " .. table.concat(registered, "; "))
for _, page in ipairs({ "Arrow", "Symbols", "Sparkles", "Beta" }) do
  assert(has("vertical " .. page .. " of NodeSight"), "its page " .. page)
end
print("active: loaded, ClaraNodeSightDB, its pages under their theme")
fireStrict("PLAYER_ENTERING_WORLD")
print("events: PLAYER_ENTERING_WORLD ran")

-- the switches on its page of Clara's options window
local sw = {}
for _, s in ipairs(ns.qolSwitches.nodesight) do sw[s.label] = s end
assert(sw.NS_SW_SCAN.get() == true and sw.NS_SW_ARROW.get() == false and sw.NS_SW_HERBS.get() == false, "switches read its settings")
sw.NS_SW_ARROW.set(true)
assert(db.arrow == true and sw.NS_SW_ARROW.get() == true, "the arrow: on")
sw.NS_SW_HERBS.set(true)
assert(db.herbs == true, "sparkles on herbs: on")
sw.NS_SW_HERBS.set(false); sw.NS_SW_ARROW.set(false)
env.ClaraNodeSight_ToggleSymbols()
assert(db.mapIcons == false, "the binding toggles the symbols")
ns:OpenQol("nodesight")
assert(has("open NodeSight"), "its options: its page in the game's options")
print("switches, binding and options button")

-- 2. The standalone runs: dormant, its settings copied
local standaloneDB = { arrow = true, iconSize = 14, learned = { [123] = true } }
ns = Session({ standalone = true, standaloneDB = standaloneDB })
assert(not ns.NodeSight and ns:QolState("nodesight") == "standalone", "standalone: dormant")
fireStrict("PLAYER_LOGOUT") -- (this mock sends every event to every frame)
local copied = rawget(env, "ClaraNodeSightDB")
assert(copied and copied.arrow == true and copied.iconSize == 14 and copied ~= standaloneDB, "its settings copied")
print("standalone: dormant, its settings copied")

-- 3. The standalone turned off: the copy is used
ns = Session({ saved = copied })
fireStrict("ADDON_LOADED", "ClaraComboPoints")
assert(rawget(env, "ClaraNodeSightDB").arrow == true and rawget(env, "ClaraNodeSightDB").iconSize == 14, "its settings kept")
print("switch back: its settings kept")

-- 4. Turned off in Clara
rawset(env, "ClaraComboPointsDB", { qol = { nodesight = false } })
ns = Session({})
assert(not ns.NodeSight and ns:QolState("nodesight") == "off" and rawget(env, "ClaraNodeSight_ToggleSymbols") ~= nil, "turned off: dormant")
rawset(env, "ClaraComboPointsDB", nil)
print("off: dormant")
print("ALL OK")
