-- The whole of Clara (lupa, Lua 5.1): every file of its TOC, every module on, a session played; on the mock of
-- the ClassicUI harness, typed from the game's API documentation. ADDON = the ClaraComboPoints folder. Run by full_run.py.
-- Made by make_full.py: edit full_tail.lua or tools/cui_harness.lua, not this file.
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
FXTEMPLATES = {}
UNKNOWN_CAPS = {}
do
  local ok, idx = pcall(dofile, (os.getenv("FULLENV") or "fullenv") .. "/framexml_index.lua")
  if ok and idx then
    for k, v in pairs(idx.numbers) do FXNUM[k] = v end
    for k, v in pairs(idx.exprs) do FXEXPR[k] = v end
    FXTABLES = idx.tables
    for k in pairs(idx.parentkeys) do PARENTKEYS[k] = true end
    for k in pairs(idx.templates) do FXTEMPLATES[k] = true end
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
    UNKNOWN_CAPS[k] = true; rawset(t, k, k); return k
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
  fn("ClassicQuestLog", ns)
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

BLIZZ_ADDONS = { "Blizzard_Professions", "Blizzard_ProfessionsBook", "Blizzard_PlayerSpells", "Blizzard_TrainerUI", "Blizzard_Settings",
  "Blizzard_WorldMap", "Blizzard_Collections", "Blizzard_InspectUI", "Blizzard_AuctionHouseUI", "Blizzard_Communities",
  "Blizzard_GroupFinder_VanillaStyle", "Blizzard_TimeManager", "Blizzard_MacroUI", "Blizzard_EncounterJournal", "Blizzard_AchievementUI",
  "Blizzard_Calendar", "Blizzard_GuildBankUI", "Blizzard_ItemSocketingUI", "Blizzard_LegacySystem", "Blizzard_ClickBindingUI",
  "Blizzard_PlayerChoice", "Blizzard_DeathRecap" }
-- WoW's Lua: getfenv(0) is _G; strings have split, join, trim
rawset(env, "getfenv", function(f) if f == 0 or f == nil then return env end if type(f) == "number" then return getfenv(f + 1) end return getfenv(f) end)
-- loadstring's chunks run in _G, as in the game
rawset(env, "loadstring", function(src, name) local f, e = loadstring(src, name); if f then setfenv(f, env) end return f, e end)
string.split = function(sep, s, n) return env.strsplit(sep, s, n) end -- (""):split(s) is strsplit("", s)
string.trim = function(s) return env.strtrim(s) end
string.join = function(sep, ...) return env.strjoin(sep, ...) end
-- names the cui harness keeps nil for its own checks: here as the game has them
for k in pairs(NILS) do
  if FXKNOWN[k] or DOCT.namespaces[k] or DOCT.globals[k] then NILS[k] = nil end
end
-- legacy C functions the documentation leaves out (assumed present, as in every client since 8.2)
for _, k in ipairs({ "MuteSoundFile", "UnmuteSoundFile" }) do FXKNOWN[k] = true end
for _, d in ipairs({ "In", "Out", "Left", "Right", "Up", "Down" }) do FXKNOWN["MoveView" .. d .. "Start"] = true; FXKNOWN["MoveView" .. d .. "Stop"] = true end

---------------------------------------------------------------------------
-- The whole addon (full_harness.lua): every file of its TOC with every module turned on
---------------------------------------------------------------------------
local FXI = dofile((os.getenv("FULLENV") or "fullenv") .. "/framexml_index.lua")
local REPORT = { load = {}, handlers = {}, unknownApi = {}, unknownGlobal = {}, unknownTemplate = {}, xmlFunc = {} }
local seenErr = {}
local function Err(kind, where, e, trace)
  local key = tostring(e)
  local r = seenErr[key]
  if r then r.n = r.n + 1; return end
  r = { kind = kind, where = where, e = key, n = 1, trace = trace }
  seenErr[key] = r
  REPORT.handlers[#REPORT.handlers + 1] = r
end
-- errors the addon's own handlers hand the game (xpcall, geterrorhandler)
rawset(env, "geterrorhandler", function() return function(e) Err("handler", "errorhandler", e, debug.traceback("", 2):sub(1, 900)) return e end end)

-- the addon's own files: which ones read a global (for the report: only reads from its files)
local function Caller(level)
  local info = debug.getinfo(level or 3, "Sl")
  return info and (info.short_src .. ":" .. tostring(info.currentline)) or "?"
end
local function FromAddon(src) return src and not src:find("^harness") and not src:find("Libs[/\\]") end

-- C_ functions the game does not document: recorded where they are read (still a mock, so the run goes on)
do
  local G = getmetatable(env).__index
  getmetatable(env).__index = function(t, k)
    local v = G(t, k)
    if type(k) == "string" and DOCT.namespaces[k] and type(v) == "table" and not rawget(v, "__claraWatch") then
      local fns = DOCT.namespaces[k]
      local mt = getmetatable(v)
      local inner = mt.__index
      mt.__index = function(nt, fk)
        if type(fk) == "string" and not fns[fk] and not FXI.cfuncs[k .. "." .. fk] then
          local src = Caller(3)
          if FromAddon(src) then REPORT.unknownApi[k .. "." .. fk] = REPORT.unknownApi[k .. "." .. fk] or src end
        end
        return inner(nt, fk)
      end
      rawset(v, "__claraWatch", true)
    end
    if type(v) == "table" and rawget(v, "__name") == ("G:" .. tostring(k)) and not FXI.frames[k] and not FXI.fonts[k] then
      local f
      if k:match("Num%u") or k:match("Count$") then f = function() return 0 end
      elseif k:match("^Is%u") or k:match("^Has%u") or k:match("^Can%u") or k:match("^Should%u") or k:match("^Was%u") or k:match("^Does%u") then f = function() return false end
      elseif k == "GetChannelName" then f = function() return 0, nil, 0 end
      elseif k:match("Get%w*Offset$") or k:match("Get%w*Range$") or k:match("Get%w*Index$") then f = function() return 0 end
      elseif k:match("^Get%w*Link$") then f = function() return nil end
      elseif k:match("Durability$") then f = function() return nil end
      elseif k == "GetChannelList" or k:match("^Get%w*List$") then f = function() end
      end
      if f then rawset(t, k, f); v = f end
    end
    if v == nil and type(k) == "string" then
      local src = Caller(3)
      if FromAddon(src) then REPORT.unknownGlobal[k] = REPORT.unknownGlobal[k] or src end
    end
    return v
  end
end

-- timers: run when the harness lets time pass
local timers = {}
local function Timer(delay, fn, times)
  local t = { fn = fn, left = times or 1, cancelled = false }
  function t:Cancel() self.cancelled = true end
  function t:IsCancelled() return self.cancelled end
  timers[#timers + 1] = t
  return t
end
rawset(env, "C_Timer", { After = function(d, fn) Timer(d, fn, 1) end, NewTimer = function(d, fn) return Timer(d, fn, 1) end,
  NewTicker = function(d, fn, n) return Timer(d, fn, math.min(n or 3, 3)) end })
local function RunTimers(rounds)
  for _ = 1, rounds or 3 do
    local list = timers
    timers = {}
    for _, t in ipairs(list) do
      if not t.cancelled and t.left > 0 then
        t.left = t.left - 1
        local ok, e = Budget(t.fn, t)
        if not ok then Err("timer", "C_Timer", e) end
        if t.left > 0 then timers[#timers + 1] = t end
      end
    end
  end
end

-- a nil key reads nil (as any Lua table); the children the game's templates name hang on the game's frames only
local function IsGame(t)
  local p, n = t, 0
  while type(p) == "table" and n < 12 do
    local name = tostring(rawget(p, "__name") or "")
    if name:find("^G:") or name:find("^tpl:") then return true end
    p = rawget(p, "__parent"); n = n + 1
  end
  return false
end
mockmeta.__index = (function(inner)
  return function(t, k)
    if k == nil then return nil end
    if type(k) == "string" and k:match("^[%l_]") and PARENTKEYS[k] and not IsGame(t) then return nil end
    return inner(t, k)
  end
end)(mockmeta.__index)

-- events: a frame gets the ones it registered (RegisterEvent, RegisterUnitEvent, RegisterAllEvents)
mockmeta.__index = (function(inner)
  local function Events(self) local e = rawget(self, "__events"); if not e then e = {}; rawset(self, "__events", e) end return e end
  return function(t, k)
    if k == "RegisterEvent" or k == "RegisterUnitEvent" then return function(self, e) Events(self)[e] = true; return true end end
    if k == "UnregisterEvent" then return function(self, e) Events(self)[e] = nil end end
    if k == "UnregisterAllEvents" then return function(self) rawset(self, "__events", {}); rawset(self, "__allEvents", nil) end end
    if k == "RegisterAllEvents" then return function(self) rawset(self, "__allEvents", true) end end
    if k == "IsEventRegistered" then return function(self, e) return rawget(self, "__allEvents") or Events(self)[e] == true end end
    if k == "IsObjectType" or k == "IsForbidden" then return function(_, ty) return k == "IsObjectType" end end
    if k == "GetName" or k == "GetDebugName" then return function(self) return rawget(self, "__gname") end end
    if k == "HasScript" then return function() return true end end
    -- a table the game's own Lua gives its frames (self.bars = {} in a mixin's OnLoad...): empty, on the game's frames
    if type(k) == "string" and FXI.selftables[k] and rawget(t, "__name") and tostring(rawget(t, "__name")):find("^G:") then
      local v = {}; rawset(t, k, v); return v
    end
    -- a getter of a measure the game's Lua mixins add (ScrollBox...): a number
    if type(k) == "string" and not DOCT.methods[k] and (k:match("^Get%w*Range$") or k:match("^Get%w*Percentage$") or k:match("^Get%w*Extent$") or k:match("^Get%w*Offset$") or k:match("^Get%w*Spacing$") or k:match("^Get%w*Padding$")) then
      return function() return 0 end
    end
    return inner(t, k)
  end
end)(mockmeta.__index)

-- shown and hidden as the game: OnShow / OnHide when that changes
local function Visible(f)
  local p = f
  while p do
    if rawget(p, "__hidden") then return false end
    p = rawget(p, "__parent")
  end
  return true
end
local function Script(f, name, ...)
  local h = rawget(f, "__scripts") and f.__scripts[name]
  if h then local ok, e = Budget(h, f, ...); if not ok then Err("script", name, e) end end
end
mockmeta.__index = (function(inner)
  return function(t, k)
    if k == "IsShown" then return function(self) return not rawget(self, "__hidden") end end
    if k == "IsVisible" then return function(self) return Visible(self) end end
    if k == "Show" then return function(self)
      if rawget(self, "__hidden") then rawset(self, "__hidden", nil); if Visible(self) then Script(self, "OnShow") end end
    end end
    if k == "Hide" then return function(self)
      if not rawget(self, "__hidden") then local was = Visible(self); rawset(self, "__hidden", true); if was then Script(self, "OnHide") end end
    end end
    if k == "SetShown" then return function(self, on) if on then self:Show() else self:Hide() end end end
    if k == "SetParent" then return function(self, p) rawset(self, "__parent", p) end end
    return inner(t, k)
  end
end)(mockmeta.__index)

-- XML: Script and Include in order; frames (with their templates, keys, layers, children and scripts) made
local XMLTEMPLATES = {}
local FRAME_TAGS = {}
for _, k in ipairs({ "Frame", "Button", "CheckButton", "ScrollFrame", "EditBox", "StatusBar", "Slider", "Cooldown", "GameTooltip",
  "Model", "PlayerModel", "DressUpModel", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "ColorSelect", "EventFrame",
  "DropdownButton", "ModelScene", "Browser", "MovieFrame", "OffScreenFrame", "ScrollChild" }) do FRAME_TAGS[k] = true end
local PARAMS = { OnEvent = "self, event, ...", OnUpdate = "self, elapsed", OnClick = "self, button, down", OnEnter = "self, motion",
  OnLeave = "self, motion", OnValueChanged = "self, value, userInput", OnMouseDown = "self, button", OnMouseUp = "self, button",
  OnDragStart = "self, button", OnDragStop = "self", OnTextChanged = "self, userInput", OnSizeChanged = "self, width, height",
  OnMouseWheel = "self, delta", OnCursorChanged = "self, x, y, w, h", OnAttributeChanged = "self, name, value",
  OnChar = "self, text", OnKeyDown = "self, key", OnKeyUp = "self, key" }
local function Compile(body, handler, file)
  local fn, e = loadstring("return function(" .. (PARAMS[handler] or "self, ...") .. ")\n" .. body .. "\nend", "@" .. file .. ":" .. handler)
  if not fn then Err("xml", file, e) return nil end
  setfenv(fn, env)
  return fn()
end
local Build
local function GameTemplate(f, name, depth)
  if (depth or 0) > 8 then return end
  local t = FXI.templates[name]
  if t and t[2] ~= "" then for inh in t[2]:gmatch("[^,%s]+") do GameTemplate(f, inh, (depth or 0) + 1) end end
  local kids = FXI.tchildren[name]
  if not kids then return end
  local gname = rawget(f, "__gname")
  for _, c in ipairs(kids) do
    local cname, key, kind, inherits = c[1], c[2], c[3], c[4]
    local child = (key ~= "" and rawget(f, key)) or nil
    if not child then
      child = Mock("tpl:" .. (key ~= "" and key or cname))
      rawset(child, "__parent", f)
      rawset(child, "__type", kind)
      if kind == "Frame" then frames[#frames + 1] = child end
      if key ~= "" then rawset(f, key, child) end
      if cname ~= "" and gname then
        local n = cname:gsub("%$[Pp]arent", gname)
        rawset(child, "__gname", n)
        if rawget(env, n) == nil then rawset(env, n, child) end
      end
      if kind == "Frame" and inherits ~= "" then for inh in inherits:gmatch("[^,%s]+") do GameTemplate(child, inh, (depth or 0) + 1) end end
    end
  end
end
local function ApplyTemplate(f, names, file)
  for name in tostring(names):gmatch("[^,%s]+") do
    local el = XMLTEMPLATES[name]
    if el then
      if el.attrs.inherits then ApplyTemplate(f, el.attrs.inherits, file) end
      Build(el, f, file, true)
    elseif FXTEMPLATES[name] then
      GameTemplate(f, name)
    elseif name ~= "BackdropTemplate" then
      REPORT.unknownTemplate[name] = REPORT.unknownTemplate[name] or file
    end
  end
end
local function KeyValue(kv)
  local v, ty = kv.attrs.value, kv.attrs.type
  if ty == "number" then return tonumber(v) end
  if ty == "boolean" then return v == "true" end
  if ty == "global" then return env[v] end
  return v
end
local function NameOf(name, parent)
  if not name then return nil end
  local pname = parent and rawget(parent, "__gname") or ""
  return (name:gsub("%$[Pp]arent", pname))
end
local loads = {}
-- el: the element; f: the frame it describes (made already); into: true when a template is applied to f
function Build(el, f, file, into)
  for _, ch in ipairs(el) do
    local tag = ch.tag
    if tag == "KeyValues" then
      for _, kv in ipairs(ch) do rawset(f, kv.attrs.key, KeyValue(kv)) end
    elseif tag == "Scripts" then
      for _, s in ipairs(ch) do
        local handler, fn = s.tag, nil
        if s.attrs["function"] then
          fn = env[s.attrs["function"]]
          if fn == nil then REPORT.xmlFunc[s.attrs["function"]] = file end
        elseif s.attrs.method then
          local m = s.attrs.method
          fn = function(self, ...) return self[m](self, ...) end
        elseif s.text and s.text:find("%S") then
          fn = Compile(s.text, handler, file)
        end
        if fn then
          if handler == "OnLoad" then loads[#loads + 1] = { f, fn } else
            local old = f.__scripts[handler]
            if old and s.attrs.inherit == "prepend" then f.__scripts[handler] = function(...) fn(...) return old(...) end
            elseif old and s.attrs.inherit == "append" then f.__scripts[handler] = function(...) old(...) return fn(...) end
            else f.__scripts[handler] = fn end
          end
        end
      end
    elseif tag == "Layers" then
      for _, layer in ipairs(ch) do
        for _, r in ipairs(layer) do
          local made = (r.tag == "FontString") and f:CreateFontString(NameOf(r.attrs.name, f)) or f:CreateTexture(NameOf(r.attrs.name, f))
          local n = NameOf(r.attrs.name, f)
          if n then rawset(made, "__gname", n); rawset(env, n, made) end
          if r.attrs.parentKey then rawset(f, r.attrs.parentKey, made) end
        end
      end
    elseif tag == "Frames" then
      for _, c in ipairs(ch) do
        if FRAME_TAGS[c.tag] then Build(c, nil, file, false, f) end
      end
    elseif tag == "ScrollChild" then
      for _, c in ipairs(ch) do if FRAME_TAGS[c.tag] then Build(c, nil, file, false, f) end end
    end
  end
  return f
end
-- a frame element: the frame made, its template(s) applied, then the element itself
local BuildFrame = Build
Build = function(el, f, file, into, parent)
  if f then return BuildFrame(el, f, file, into) end
  local a = el.attrs
  if a.virtual == "true" then XMLTEMPLATES[a.name] = el return nil end
  local name = NameOf(a.name, parent)
  local frame = Mock("xml:" .. tostring(name or a.parentKey or el.tag))
  rawset(frame, "__type", el.tag == "ScrollChild" and "Frame" or el.tag)
  rawset(frame, "__parent", parent)
  if a.hidden == "true" then rawset(frame, "__hidden", true) end
  if name then rawset(frame, "__gname", name); rawset(env, name, frame) end
  if parent and a.parentKey then rawset(parent, a.parentKey, frame) end
  frames[#frames + 1] = frame
  if a.inherits then ApplyTemplate(frame, a.inherits, file) end
  if a.mixin then for m in a.mixin:gmatch("[^,%s]+") do local mx = env[m]; if type(mx) == "table" then for k, v in pairs(mx) do rawset(frame, k, v) end end end end
  BuildFrame(el, frame, file, false)
  return frame
end
local function XML(path, ns)
  local dir = path:match("^(.*)/[^/]*$")
  local root = XMLPARSE(path)
  if type(root) ~= "table" then REPORT.load[#REPORT.load + 1] = path .. ": " .. tostring(root) return end
  local file = path:match("ClassicQuestLog/(.*)$") or path
  for _, el in ipairs(root) do
    local p = el.attrs.file and (dir .. "/" .. el.attrs.file:gsub("\\", "/"))
    if el.tag == "Script" and p then
      local ok, e = Budget(run, p, el.attrs.file, ns)
      if not ok then REPORT.load[#REPORT.load + 1] = el.attrs.file .. ": " .. tostring(e) end
    elseif el.tag == "Include" and p then XML(p, ns)
    elseif el.tag == "Script" and el.text:find("%S") then
      local fn = loadstring(el.text, "@" .. file); if fn then setfenv(fn, env); Budget(fn) end
    elseif FRAME_TAGS[el.tag] then
      Build(el, nil, file, false, nil)
    end
  end
  -- OnLoad: after the file's frames are made, children first (as the game)
  local list = loads
  loads = {}
  for i = 1, #list do local f, fn = list[i][1], list[i][2]; local ok, e = Budget(fn, f); if not ok then Err("OnLoad", file, e) end end
end
-- CreateFrame: a template from the addon's XML is applied; one the game has not is reported
local MockCreateFrame = env.CreateFrame
rawset(env, "CreateFrame", function(ftype, name, parent, template, id)
  local f = MockCreateFrame(ftype, name, parent, template)
  if type(name) == "string" then rawset(f, "__gname", name) end
  if template then
    ApplyTemplate(f, template, Caller(2))
    local list = loads; loads = {}
    for i = 1, #list do local ok, e = Budget(list[i][2], list[i][1]); if not ok then Err("OnLoad", "template", e) end end
  end
  return f
end)

-- events to the frames that registered them (RegisterEvent on the mock records nothing: every OnEvent gets each)
local function Fire(event, ...)
  for i = 1, #frames do
    local f = frames[i]
    local ev = rawget(f, "__events")
    local h = (rawget(f, "__allEvents") or (ev and ev[event])) and rawget(f, "__scripts") and f.__scripts.OnEvent
    if h then local ok, e = Budget(h, f, event, ...); if not ok then Err("event", event, e) end end
  end
end
local function Updates(n)
  for _ = 1, n or 2 do
    for i = 1, #frames do
      local f = frames[i]
      local h = rawget(f, "__scripts") and f.__scripts.OnUpdate
      if h and Visible(f) then local ok, e = Budget(h, f, 0.2); if not ok then Err("OnUpdate", "OnUpdate", e) end end
    end
  end
end

---------------------------------------------------------------------------
-- The session
---------------------------------------------------------------------------
-- the game's Constants tables, as documented (one it does not document: empty)
rawset(env, "Constants", setmetatable(DOCT.Constants, { __index = function(t, k) local v = {}; rawset(t, k, v); return v end }))
-- the game's class order on WoW Forever (Blizzard_FrameXMLBase/Camelot/Constants.lua: the nine of 1.x)
rawset(env, "CLASS_SORT_ORDER", { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" })
rawset(env, "MAX_CLASSES", 9)
-- the game's own dialogs (StaticPopupDialogs["DELETE_ITEM"]...): there, as tables an addon may extend
rawset(env, "StaticPopupDialogs", setmetatable({}, { __index = function(t, k)
  if FXI.dialogs[k] then local d = { text = k }; rawset(t, k, d); return d end
end }))
rawset(env, "C_AddOns", setmetatable({ IsAddOnLoaded = function(n) return n == "ClassicQuestLog" end,
  GetAddOnEnableState = function(n) return n == "ClassicQuestLog" and 2 or 0 end,
  DoesAddOnExist = function() return false end, IsAddOnLoadable = function() return false, "MISSING" end,
  GetAddOnMetadata = function(_, k) if k == "Version" then return "1.6.0" end end,
  DisableAddOn = function() end, EnableAddOn = function() end, GetNumAddOns = function() return 1 end },
  { __index = function() return function() return false end end }))
rawset(env, "GetBuildInfo", function() return "1.60.1", "70532", "Oct 1 2026", 16001 end)
local ns = { }
local t0 = os.clock()
for line in readfile(ADDON .. "/ClassicQuestLog.toc"):gmatch("[^\r\n]+") do
  if not line:match("^##") and line:match("%S") then
    local file = line:gsub("%s+$", "")
    local path = ADDON .. "/" .. file:gsub("\\", "/")
    if file:match("%.lua$") then
      local ok, e = Budget(run, path, file, ns)
      if not ok then REPORT.load[#REPORT.load + 1] = file .. ": " .. tostring(e) end
    elseif file:match("%.xml$") then
      XML(path, ns)
    end
  end
end
print(string.format("loaded the TOC in %.1fs", os.clock() - t0))

local function Step(name, fn) local ok, e = Budget(fn); if not ok then Err("step", name, e) end end
Fire("ADDON_LOADED", "ClassicQuestLog")
for _, a in ipairs(BLIZZ_ADDONS) do Fire("ADDON_LOADED", a) end
Fire("VARIABLES_LOADED")
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD", true, false)
Fire("SPELLS_CHANGED"); Fire("UPDATE_SHAPESHIFT_FORM"); Fire("GROUP_ROSTER_UPDATE"); Fire("ZONE_CHANGED_NEW_AREA")
RunTimers(3); Updates(2)
-- a little play: a target, combat, auras, power, a group, the windows the game opens
for _, ev in ipairs({
  { "PLAYER_TARGET_CHANGED" }, { "UNIT_AURA", "player" }, { "UNIT_AURA", "target" }, { "UNIT_POWER_UPDATE", "player", "ENERGY" },
  { "UNIT_POWER_FREQUENT", "player", "ENERGY" }, { "UNIT_HEALTH", "target" }, { "PLAYER_REGEN_DISABLED" },
  { "UNIT_SPELLCAST_START", "player", "Cast-1", 1752 }, { "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 1752 },
  { "SPELL_UPDATE_COOLDOWN" }, { "PLAYER_REGEN_ENABLED" }, { "NAME_PLATE_UNIT_ADDED", "nameplate1" },
  { "UPDATE_MOUSEOVER_UNIT" }, { "PLAYER_FOCUS_CHANGED" }, { "BAG_UPDATE_DELAYED" }, { "PLAYER_EQUIPMENT_CHANGED", 16 },
  { "MERCHANT_SHOW" }, { "MERCHANT_CLOSED" }, { "MAIL_SHOW" }, { "MAIL_INBOX_UPDATE" }, { "MAIL_CLOSED" },
  { "BANKFRAME_OPENED" }, { "BANKFRAME_CLOSED" }, { "TRAINER_SHOW" }, { "TRAINER_CLOSED" },
  { "TRADE_SKILL_SHOW" }, { "TRADE_SKILL_LIST_UPDATE" }, { "TRADE_SKILL_CLOSE" }, { "GOSSIP_SHOW" }, { "GOSSIP_CLOSED" },
  { "QUEST_DETAIL" }, { "QUEST_FINISHED" }, { "QUEST_LOG_UPDATE" }, { "LOOT_OPENED" }, { "LOOT_CLOSED" },
  { "CHAT_MSG_ADDON", "ClaraSync", "x", "WHISPER", "Other-Realm" }, { "PLAYER_XP_UPDATE", "player" }, { "PLAYER_LEVEL_UP", 11 },
  { "UNIT_SPELLCAST_CHANNEL_START", "target", "Cast-2", 5143 }, { "UNIT_SPELLCAST_STOP", "target", "Cast-2", 5143 },
  { "ENCOUNTER_START", 1, "Boss", 1, 5 }, { "ENCOUNTER_END", 1, "Boss", 1, 5, 1 }, { "PLAYER_DEAD" }, { "PLAYER_ALIVE" },
  { "UPDATE_BINDINGS" }, { "CVAR_UPDATE", "uiScale" }, { "UI_SCALE_CHANGED" }, { "DISPLAY_SIZE_CHANGED" },
}) do Fire(unpack(ev)) end
RunTimers(3); Updates(3)

-- the game's options: every page and subpage of every category shown once (their OnShow / OnRefresh)
local pages = 0
for _, c in pairs(cats) do
  local f = c.frame
  if type(f) == "table" then
    pages = pages + 1
    Step("settings " .. tostring(c.name), function()
      rawset(f, "__hidden", true); f:Show()
      if type(f.OnRefresh) == "function" then f:OnRefresh() end
      f:Hide()
    end)
  end
end
print("settings pages shown: " .. pages)
-- every slash command, without arguments (its window or its help)
local cmds = {}
for k in pairs(env.SlashCmdList) do cmds[#cmds + 1] = k end
table.sort(cmds)
for _, k in ipairs(cmds) do Step("/" .. k, function() env.SlashCmdList[k]("") end) end
print("slash commands run: " .. #cmds)
-- every module's options (its opener) and the bar's own options window
if ns.QOL_MODULES then
  for _, m in ipairs(ns.QOL_MODULES) do Step("open " .. m.key, function() if ns.CanOpenQol and ns:CanOpenQol(m.key) then ns:OpenQol(m.key) end end) end
end
RunTimers(3); Updates(2)
if os.getenv("FULL_DEBUG_DC") then
  local DC = env.DynamicCam
  local n = 0
  for id, sit in pairs(DC.db.profile.situations or {}) do
    n = n + 1
    if id == "004" or id == "001" then
      print("sit", id, sit.name, sit.enabled, sit.errorEncountered, sit.condition)
      print("  run", pcall(DC.RunScript, DC, id, "condition"))
    end
  end
  print("DC situations", n, "current", DC.currentSituationID)
end
-- a scenario of its own (FULL_SCENARIO=<file.lua>): called with the addon's globals, its table and the harness's steps
if os.getenv("FULL_SCENARIO") then
  local fn = assert(loadfile(os.getenv("FULL_SCENARIO")))
  Step("scenario", function() fn({ env = env, ns = ns, Fire = Fire, RunTimers = RunTimers, Updates = Updates, frames = frames }) end)
end
Fire("PLAYER_LOGOUT")

---------------------------------------------------------------------------
-- The report
---------------------------------------------------------------------------
local function Sorted(set) local out = {} for k, v in pairs(set) do out[#out + 1] = k .. "  (" .. tostring(v) .. ")" end table.sort(out) return out end
print("\n== files that stopped at load: " .. #REPORT.load)
for _, l in ipairs(REPORT.load) do print("  " .. l:sub(1, 300)) end
print("\n== errors in handlers, events, pages, commands: " .. #REPORT.handlers)
for _, r in ipairs(REPORT.handlers) do
  print(string.format("  [%s %s] x%d %s", r.kind, tostring(r.where), r.n, r.e:sub(1, 300)))
  if r.trace and os.getenv("FULL_TRACE") then print(r.trace) end
end
local api = Sorted(REPORT.unknownApi)
print("\n== C_ functions neither the game's documentation nor its UI code has, read by the addon: " .. #api)
for _, l in ipairs(api) do print("  " .. l) end
local tpl = Sorted(REPORT.unknownTemplate)
print("\n== templates neither the game nor the addon defines: " .. #tpl)
for _, l in ipairs(tpl) do print("  " .. l) end
local xf = Sorted(REPORT.xmlFunc)
print("\n== XML script functions not found: " .. #xf)
for _, l in ipairs(xf) do print("  " .. l) end
-- not reported: the addon's saved variables (nil on a first login), Leatrix's random frame names
local saved = {}
for line in readfile(ADDON .. "/ClassicQuestLog.toc"):gmatch("[^\r\n]+") do
  local list = line:match("^## SavedVariables%w*:%s*(.+)$")
  if list then for n in list:gmatch("[%w_]+") do saved[n] = true end end
end
for k in pairs(REPORT.unknownGlobal) do
  if saved[k] or k:match("^F%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w$") or k:match("^WT_") then REPORT.unknownGlobal[k] = nil end
end
local caps = {}
for k in pairs(UNKNOWN_CAPS) do caps[#caps + 1] = k end
table.sort(caps)
print("\n== capital globals the game's code never names (taken as global strings): " .. #caps)
if #caps > 0 then print("  " .. table.concat(caps, ", ")) end
local gl = Sorted(REPORT.unknownGlobal)
print("\n== globals the addon reads that neither the game nor the addon has (nil): " .. #gl)
for _, l in ipairs(gl) do print("  " .. l) end
