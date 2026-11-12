-- Harness for the ClassicUI Forever module of Clara Combo Points (lupa, Lua 5.1), on a permissive
-- mock of the game API (taken from the DialogKey / XToLevel one). ADDON = the ClaraComboPoints folder.
local ADDON = ...
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local function chunk(path, name) return assert(loadstring(readfile(path), "@" .. name)) end

---------------------------------------------------------------------------
-- A permissive mock of the game API
---------------------------------------------------------------------------
local DOCT = dofile((os.getenv("FULLENV") or "fullenv") .. "/doctypes.lua")(os.getenv("FULLENV") or "fullenv")
local PARENTKEYS = {} -- the children the game's templates name (parentKey), from its XML
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
    if type(k) == "string" and k:match("^GetNum") then return function() return 0 end end
    if type(k) == "string" and not DOCT.methods[k] and k:match("^Get%w*(Size)$") or k == "GetCount" or (type(k) == "string" and k:match("^Get%w+Count$")) then return function() return 0 end end
    if type(k) == "string" and k:match("^Enumerate") then return function() return function() end end end
    if k == "SetScript" then return function(self, ev, fn) self.__scripts[ev] = fn end end
    if k == "GetScript" then return function(self, ev) return self.__scripts[ev] end end
    if k == "HookScript" then return function(self, ev, fn) local o = self.__scripts[ev]; self.__scripts[ev] = function(...) if o then o(...) end return fn(...) end end end
    if k == "GetTexture" then return function() return 0 end end
    if k == "GetAttribute" then return function() return nil end end
    if k == "GetParent" then return function(self) return rawget(self, "__parent") end end -- (no parent: nil, as the game)
    if k == "CreateFontString" or k == "CreateTexture" or k == "CreateAnimationGroup" or k == "CreateAnimation" or k == "CreateMaskTexture" or k == "CreateLine" then
      return function(self) local m = Mock(k); rawset(m, "__parent", self); return m end
    end
    -- a method the game documents: values of the types it returns
    local rets = type(k) == "string" and DOCT.methods[k]
    if rets then return function() return DOCT.Returns(rets, function() return Mock("widget") end) end end
    if type(k) == "string" and PARENTKEYS[k] then local m = Mock(k); rawset(m, "__parent", t); rawset(t, k, m); return m end -- a child the game's templates give
    if type(k) == "string" and k:match("^[%l_]") then return nil end -- fields an addon sets itself
    local m = Mock(k); rawset(m, "__parent", t); rawset(t, k, m); return m -- any other widget method or child: a callable mock (a child's parent: its owner)
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
  "chat_msg", "off_width", "main_width", "spell_name", "WST_IsSecret", "getglobal", "NodeSightDB", "ClaraNodeSightDB", "ClaraNodeSight_ToggleSymbols", "NodeSight_ToggleSymbols", "DynamicCam", "DynamicCamDB", "ClaraDynamicCamDB", "ClaraComboPointsDB", "LibStub", "SLASH_DCNEW1", "returnString", "ludius_UiHideModule", "ludius_FADEFRAMES", "ludius_bars_hooked", "GW2_UI", "Bartender4", "Immersion", "cosFix", "ImmersionFrame", "BT4StatusBarTrackingManager", "ElvUI", "DialogKeyNS", "DialogKeyAPI", "DialogKeyNumyDB", "ClaraDialogKeyDB", "XToLevel", "XToLevelDB", "ClaraXToLevelDB", "console", "rafMessageDisplayed", "sConfig", "sData", "ClaraXToLevel_AverageFrame_Classic", "ClaraXToLevel_AverageFrame_Blocky_PlayerFrame", "ChatThrottleLib", "LibVersionCheck", "C_SettingsUtil", "C_StringUtil", "StripHyperlinks", "GetFrameMetatable", "LibDataBroker", "C_PlayerChoice", "PlayerChoiceFrame", "PlayerSpellsFrame", "ForeverClassicUIDB", "ForeverClassicUICharDB", "ClaraClassicUIDB", "ClaraClassicUICharDB", "ClassicUIForeverAPI", "ForeverClassicUI_OnAddonCompartmentClick", "EasyFind", "FRIEND_TAB_WHO" }) do NILS[k] = true end
-- the game's numeric constants (its UI code, indexed by fullenv/index_framexml.py), and the simple sums it makes of them
local FXNUM, FXEXPR, FXTABLES, FXKNOWN = {}, {}, {}, {}
UNKNOWN_CAPS = {}
do
  local ok, idx = pcall(dofile, (os.getenv("FULLENV") or "fullenv") .. "/framexml_index.lua")
  if ok and idx then
    for k, v in pairs(idx.numbers) do FXNUM[k] = v end
    for k, v in pairs(idx.exprs) do FXEXPR[k] = v end
    FXTABLES = idx.tables
    for k in pairs(idx.parentkeys) do PARENTKEYS[k] = true end
    for _, set in ipairs({ idx.frames, idx.functions, idx.tables, idx.native, idx.fonts }) do for k in pairs(set) do FXKNOWN[k] = true end end
  end
end
local G = setmetatable(env, { __index = function(t, k)
  if NILS[k] then return nil end
  if type(k) == "string" and #k == 17 and k:match("^F%w+$") then return nil end -- LeaPlusLC:CreateRandomName()
  -- the game's constants: a number its code sets, else a global string (its text: its name here)
  if type(k) == "string" and k:match("^[%u_][%u%d_]+$") and #k > 2 then
    local n = FXNUM[k]
    if n == nil and FXEXPR[k] then
      -- a sum of other constants or of the game's Constants tables: worked out as the game does
      local fn = loadstring("return " .. FXEXPR[k])
      if fn then
        setfenv(fn, setmetatable({}, { __index = function(_, name) if name == "Constants" then return DOCT.Constants end return t[name] end }))
        local ok, v = pcall(fn)
        if ok and v ~= nil and not (type(v) == "table" and rawget(v, "__name") == "call") then n = v end
      end
    end
    if n ~= nil then rawset(t, k, n); return n end
    if FXTABLES[k] then -- a table the game makes: a color for its *_COLOR ones
      local v = k:match("_COLORS?$") and (k:match("S$") and setmetatable({}, { __index = function() return DOCT.Color() end }) or DOCT.Color()) or {}
      rawset(t, k, v); return v
    end
    local word = k:match("_(%u+)$")
    if k:match("_COLOR$") or (FXKNOWN[k] and ({ YELLOW = 1, GREEN = 1, RED = 1, GRAY = 1, GREY = 1, WHITE = 1, BLUE = 1, ORANGE = 1, PURPLE = 1 })[word or ""]) then
      local c = DOCT.Color(); rawset(t, k, c); return c -- a color the game gives
    end
    if FXKNOWN[k] then rawset(t, k, k); return k end -- a global string the game's code reads: its text
    UNKNOWN_CAPS[k] = true; return nil
  end
  -- a documented namespace or function: its documented returns (a function it does not document: a mock)
  if type(k) == "string" and DOCT.namespaces[k] then
    local fns = DOCT.namespaces[k]
    local ns = setmetatable({}, { __index = function(nt, fk)
      local rets = fns[fk]
      local f = rets and function() return DOCT.Returns(rets, function() return Mock("widget") end) end or Mock(k .. "." .. tostring(fk))
      rawset(nt, fk, f); return f
    end })
    rawset(t, k, ns); return ns
  end
  if type(k) == "string" and DOCT.globals[k] then
    local rets = DOCT.globals[k]
    local f = function() return DOCT.Returns(rets, function() return Mock("widget") end) end
    rawset(t, k, f); return f
  end
  -- a name neither the game's documentation nor its UI code has: nil, as in the game (a loop over
  -- _G["Name" .. i] stops where the game's frames stop)
  if type(k) == "string" and not FXKNOWN[k] then return nil end
  -- unknown globals: Blizzard frames, constants and functions are mocks
  local m = Mock("G:" .. tostring(k)); rawset(t, k, m); return m
end })
local function CreateFrame(ftype, name, parent, template)
  local f = Mock("frame")
  rawset(f, "__type", ftype); rawset(f, "__parent", parent); rawset(f, "__template", template)
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
do -- the addon compartment: a frame, its list of addons
  local acf = Mock("AddonCompartmentFrame")
  rawset(acf, "RegisterAddon", function(self, data) compartment[#compartment + 1] = data end)
  rawset(acf, "registeredAddons", {})
  rawset(env, "AddonCompartmentFrame", acf)
end


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
local traced = {}
rawset(env, "geterrorhandler", function() return function(e)
  errors[#errors + 1] = tostring(e); print("ERROR: " .. tostring(e))
  if os.getenv("CUI_TRACE") and not traced[tostring(e)] then traced[tostring(e)] = true; print(debug.traceback("", 2):sub(1, 700)) end
  return e
end end)
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

rawset(env, "RunNextFrame", function(f) f() end)
table.wipe = env.wipe
rawset(env, "strlenutf8", function(t) return #t end)
rawset(env, "CreateCounter", function() local n = 0 return function() n = n + 1 return n end end)
rawset(env, "nop", function() end)

-- an instruction budget per file and per handler: a loop over the mock's endless values stops with where it was
local function Budget(fn, ...)
  local args, n = { ... }, select("#", ...)
  debug.sethook(function() debug.sethook(); error("BUDGET " .. debug.traceback("", 2):sub(1, 900), 0) end, "", 2e7)
  local res = { pcall(fn, unpack(args, 1, n)) }
  debug.sethook()
  return unpack(res)
end

local addonCalls = {}
local function Session(opts)
  first = #frames + 1
  for _, k in ipairs({ "ClaraClassicUIDB", "ClaraClassicUICharDB", "ForeverClassicUIDB", "ForeverClassicUICharDB", "ClassicUIForeverAPI",
    "ForeverClassicUI_OnAddonCompartmentClick", "LibStub" }) do rawset(env, k, nil) end
  rawset(env, "ClaraComboPointsDB", opts.clara)
  for k, v in pairs(opts.saved or {}) do rawset(env, k, v) end
  if opts.standalone then
    rawset(env, "ForeverClassicUIDB", opts.standalone.db); rawset(env, "ForeverClassicUICharDB", opts.standalone.char)
    rawset(env, "ForeverClassicUI_OnAddonCompartmentClick", function() addonCalls[#addonCalls + 1] = "standalone options" end)
  end
  for i = #addonCalls, 1, -1 do addonCalls[i] = nil end
  rawset(env, "C_AddOns", setmetatable({ IsAddOnLoaded = function(n) return opts.standalone ~= nil and n == "ClassicUIForever" end,
    GetAddOnEnableState = function(n, who) return opts.claraOff and n == "ClaraComboPoints" and 0 or 2 end,
    DisableAddOn = function(n) addonCalls[#addonCalls + 1] = "disable " .. n end, EnableAddOn = function(n) addonCalls[#addonCalls + 1] = "enable " .. n end },
    { __index = function() return function() return false end end }))
  rawset(env, "GetBuildInfo", function() return "1.60.1", "70532", "Oct 1 2026", 16001 end)
  for i = #registered, 1, -1 do registered[i] = nil end
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
  for _, lib in ipairs({ "LibStub/LibStub.lua", "CallbackHandler-1.0/CallbackHandler-1.0.lua", "AceDB-3.0/AceDB-3.0.lua" }) do
    run(ADDON .. "/Libs/" .. lib, lib, ns)
  end
  run(ADDON .. "/QoL.lua", "QoL.lua", ns)
  local failed = {}
  for line in readfile(ADDON .. "/ClaraComboPoints.toc"):gmatch("[^\r\n]+") do
    local file = line:match("^(Modules\\ClassicUI\\.+)$")
    if file then
      local path = ADDON .. "/" .. file:gsub("\\", "/")
      if os.getenv("CUI_TRACE") then local t0 = os.clock(); io.write("load ", file, " ") io.flush() end
      local t0 = os.clock()
      local ok, err = Budget(run, path, file, ns)
      if os.getenv("CUI_TRACE") then io.write(string.format("%.2fs %s\n", os.clock() - t0, ok and "" or "STOPPED")) io.flush() end
      if not ok then failed[#failed + 1] = tostring(err) end
    end
  end
  ns.sv = rawget(env, "ClaraComboPointsDB") or {}
  rawset(env, "ClaraComboPointsDB", ns.sv)
  return ns, failed
end
local function fire(event, ...)
  local errs = {}
  for i = first, #frames do local f = frames[i]
    local h = f.__scripts and f.__scripts.OnEvent
    if h then local ok, e = Budget(h, f, event, ...) if not ok then errs[#errs + 1] = tostring(e) end end
  end
  return errs
end

-- 1. Built in: every file loads, its settings in Clara's own tables
local ns, failed = Session({})
local cooldownOn -- (Clara's /who cooldown, Modules/WhoCooldown: the Refresh button handed to it as the list is built)
ns.WhoCooldownAttach = function(_, button) cooldownOn = button end
assert(ns.ClassicUIRuns and ns:QolState("classicui") == "on", "the module runs")
print("files that stopped at load: " .. #failed)
for i = 1, math.min(#failed, 8) do print("  " .. failed[i]) end
local C = ns.ClassicUIPrivate
assert(type(C) == "table" and C.social and C.UF, "its own table, filled")
assert(ns.UF == nil and ns.social == nil and ns.db == nil, "Clara's table left alone")
local errs = fire("ADDON_LOADED", "ClaraComboPoints")
print("ADDON_LOADED errors: " .. #errs)
for i = 1, math.min(#errs, 5) do print("  " .. errs[i]) end
assert(C.db and C.db == rawget(env, "ClaraClassicUIDB"), "its settings: ClaraClassicUIDB")
assert(rawget(env, "ForeverClassicUIDB") == nil, "not the standalone's")
errs = fire("PLAYER_LOGIN")
print("PLAYER_LOGIN errors: " .. #errs)
for i = 1, math.min(#errs, 5) do print("  " .. errs[i]) end
assert(type(rawget(env, "ClaraClassicUICharDB")) == "table" and rawget(env, "ForeverClassicUICharDB") == nil, "this character's: ClaraClassicUICharDB")
assert(C.AddonVersion and C.AddonVersion() == "0.36.0", "its own version (" .. tostring(C.AddonVersion and C.AddonVersion()) .. ")")
print("built in: loaded, saved in ClaraClassicUIDB / ClaraClassicUICharDB, version 0.36.0")

-- turned off: its module's box, or Clara turned off for the character -> its hand back at logout
assert(ns:ClassicUITurningOff() == false and C.BeingTurnedOff() == false, "on: not being turned off")
ns:SetQolEnabled("classicui", false)
assert(ns:ClassicUITurningOff() and C.BeingTurnedOff(), "its box unticked: being turned off")
local handedBack = false
local realHandBack = C.HandBack
C.HandBack = function() handedBack = true end
fire("PLAYER_LOGOUT")
assert(handedBack, "at logout: the game's layout and settings handed back")
C.HandBack = realHandBack
ns:SetQolEnabled("classicui", true)
assert(not C.BeingTurnedOff(), "ticked again: kept")
-- its own Turn off button: its module unticked (not the standalone's line in the AddOns list)
for i = #addonCalls, 1, -1 do addonCalls[i] = nil end
pcall(C.TurnOffCleanly)
assert(ns.sv.qol and ns.sv.qol.classicui == false and #addonCalls == 0, "Turn off: its module unticked, no addon turned off (" .. table.concat(addonCalls, ", ") .. ")")
ns:SetQolEnabled("classicui", true)
print("turning off: its box or its Turn off button, its hand back at logout")

-- 2. The party portraits' debuff ring: pinned to the 1.x portrait
local function Region(name) local r = Mock(name); local pts = {}; rawset(r, "points", pts)
  rawset(r, "ClearAllPoints", function() for k in pairs(pts) do pts[k] = nil end end)
  rawset(r, "SetPoint", function(_, p, rel, rp, x, y) pts[p] = { rel, rp, x, y } end)
  rawset(r, "SetPointBase", r.SetPoint); rawset(r, "ClearAllPointsBase", r.ClearAllPoints) -- (the game's originals: the same here)
  return r end
local frame = Mock("party1"); rawset(frame, "unit", "party1")
local portrait, status = Region("Portrait"), Region("Status")
rawset(frame, "Portrait", portrait)
rawset(frame, "PartyMemberOverlay", { Status = status })
rawset(frame, "Texture", Region("Texture")); rawset(frame, "Name", Region("Name"))
local pool = { EnumerateActive = function() local done return function() if not done then done = true return frame end end end, GetNumActive = function() return 1 end }
rawset(env, "PartyFrame", { PartyMemberFramePool = pool })
C.UF.active = true
local ok, e = pcall(C.UF.SkinParty)
local p = status.points.TOPLEFT
assert(p and p[1] == portrait and p[3] == -8 and p[4] == 5, "skinned: the ring pinned to the portrait (-8, 5) " .. tostring(ok) .. " " .. tostring(e))
local pp = portrait.points.TOPLEFT
assert(pp and pp[3] == 7 and pp[4] == -14, "the portrait at 7, -14")
print("party: the debuff ring on the 1.x portrait (its spot from the game's: -1 -1 of the frame for a portrait at 7 -6)")
C.UF.taken.party = true
pcall(C.UF.RestoreParty)
p = status.points.TOPLEFT
assert(p and p[1] == frame and p[3] == -1 and p[4] == -1, "restored: the game's spot again")

-- 3. The Who list's menu: Class, Race, Zone sort at once, their filters on hover; Guild; no Column
local captured
local realTree = C.TreeMenu
C.TreeMenu = function(entries) captured = entries return realTree(entries) end
local okOpen, eOpen = pcall(C.OpenWhoList)
print("who list opened: " .. tostring(okOpen) .. " " .. tostring(eOpen))
local whoPanel = rawget(env, "ClassicUIForeverWhoPanel")
print("who list's Refresh handed to the /who cooldown: " .. tostring(cooldownOn ~= nil and whoPanel ~= nil and cooldownOn == whoPanel.refresh) .. " (" .. tostring(cooldownOn) .. ", panel " .. tostring(whoPanel) .. ")")

-- capital globals ClassicUI read that the game's documentation and UI code never name (nil in the game too)
local caps = {}
for k in pairs(UNKNOWN_CAPS) do caps[#caps + 1] = k end
table.sort(caps)
print("capital globals unknown to the game: " .. #caps .. (#caps > 0 and (" (" .. table.concat(caps, ", ") .. ")") or ""))
