-- Scratch harness for the Leatrix Plus port prototype (run through lupa, Lua 5.1).
-- MOD = path of Modules/LeatrixPlus (set by the runner)
local MOD = ...
local FILES = { "Leatrix_Plus_Library.lua", "Leatrix_Plus_Locale.lua", "Leatrix_Plus_Media.lua",
  "Leatrix_Plus_Flight_Alliance.lua", "Leatrix_Plus_Flight_Horde.lua", "Leatrix_Plus_Mute.lua",
  "Leatrix_Plus_Minimap.lua", "Leatrix_Plus.lua" }

local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local chunks = {}
for _, name in ipairs({ "Bootstrap.lua", unpack(FILES) }) do
  local fn, err = loadstring(readfile(MOD .. "/" .. name), "@" .. name)
  assert(fn, err)
  chunks[name] = fn
end
print("compile: all " .. (#FILES + 1) .. " files ok")

---------------------------------------------------------------------------
-- 1. Dormant: every embedded file must return before touching any global
---------------------------------------------------------------------------
for _, name in ipairs(FILES) do
  local touched = {}
  local strict = setmetatable({}, {
    __index = function(_, k) touched[#touched + 1] = "read " .. tostring(k); return nil end,
    __newindex = function(_, k) touched[#touched + 1] = "write " .. tostring(k) end })
  local fn = chunks[name]
  setfenv(fn, strict)
  local ok, err = pcall(fn, "ClaraComboPoints", {}) -- Clara's ns without LeatrixPlus
  assert(ok, name .. ": " .. tostring(err))
  assert(#touched == 0, name .. " touched globals while dormant: " .. table.concat(touched, ", "))
end
print("dormant: all embedded files return at once, no global touched")

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
  "arg", "x", "y", "height", "CheesePrevLevelTime", "StoreFrame", "PixelUtil", "ClaraLeaPlusDB", "GetMinimapShape" }) do NILS[k] = true end
local CONSTANTS_AS_TEXT
local G = setmetatable(env, { __index = function(t, k)
  if NILS[k] then return nil end
  if type(k) == "string" and #k == 17 and k:match("^F%w+$") then return nil end -- LeaPlusLC:CreateRandomName()
  if CONSTANTS_AS_TEXT and type(k) == "string" and k:match("^%u[%u%d]*_[%u%d_]+$") then return k .. " %s" end -- (the game's strings)
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
  RegisterCanvasLayoutCategory = function(frame, name) local c = { name = name, frame = frame }; registered[#registered + 1] = "category " .. name; return c end,
  RegisterCanvasLayoutSubcategory = function(parent, frame, name) local c = { name = name, parent = parent }; registered[#registered + 1] = "subcategory " .. name .. " of " .. parent.name; return c end,
  RegisterAddOnCategory = function(c) registered[#registered + 1] = "addon category " .. c.name end,
  OpenToCategory = function() end,
})
local compartment = {}
do
  local acf = Mock("AddonCompartmentFrame")
  rawset(acf, "RegisterAddon", function(self, data) compartment[#compartment + 1] = data end)
  rawset(acf, "registeredAddons", {})
  rawset(env, "AddonCompartmentFrame", acf)
end

---------------------------------------------------------------------------
-- 2. Bootstrap scenarios
---------------------------------------------------------------------------
local qolChunk = assert(loadstring(readfile(MOD .. "/../../QoL.lua"), "@QoL.lua"))
local function RunBootstrap(state, saved)
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
  local e = setmetatable({}, { __index = env })
  e.C_AddOns = setmetatable(state, { __index = env.C_AddOns })
  e.GetBuildInfo = state.GetBuildInfo or env.GetBuildInfo
  e.ClaraComboPointsDB = saved
  setfenv(qolChunk, e)
  qolChunk("ClaraComboPoints", ns)
  setfenv(chunks["Bootstrap.lua"], e)
  chunks["Bootstrap.lua"]("ClaraComboPoints", ns)
  return ns, e
end
do
  local ns = RunBootstrap({})
  assert(ns.LeatrixPlus and ns:QolState("leatrix") == "on", "missing standalone -> embedded must run")
  local nframes = #frames
  local ns2, e2 = RunBootstrap({ IsAddOnLoaded = function(n) return n == "Leatrix_Plus" end })
  assert(not ns2.LeatrixPlus and ns2:QolState("leatrix") == "standalone", "standalone loaded -> dormant")
  local login
  for i = nframes + 1, #frames do if frames[i].__scripts.OnEvent then login = frames[i] end end
  e2.LeaPlusDB = { AutomateQuests = "On" }
  login.__scripts.OnEvent(login, "PLAYER_LOGIN")
  assert(e2.ClaraLeaPlusDB == e2.LeaPlusDB and e2.LeaPlusDB.__source == "standalone", "standalone settings mirrored")
  nframes = #frames
  local ns3, e3 = RunBootstrap({ IsAddOnLoaded = function(n) return n == "Leatrix_Plus" end })
  for i = nframes + 1, #frames do if frames[i].__scripts.OnEvent then login = frames[i] end end
  e3.LeaPlusDB = { AutomateQuests = "On" }
  e3.ClaraLeaPlusDB = { AutomateQuests = "Off", __source = "embedded" }
  login.__scripts.OnEvent(login, "PLAYER_LOGIN")
  assert(e3.ClaraLeaPlusDB.AutomateQuests == "Off", "embedded settings kept when the standalone comes back")
  ns = RunBootstrap({ DoesAddOnExist = function() return true end, GetAddOnEnableState = function() return 2 end,
    IsAddOnLoadable = function() return true end })
  assert(not ns.LeatrixPlus, "standalone enabled + loadable (not yet loaded) -> dormant")
  ns = RunBootstrap({ DoesAddOnExist = function() return true end, GetAddOnEnableState = function() return 0 end })
  assert(ns.LeatrixPlus, "standalone disabled -> embedded runs")
  ns = RunBootstrap({ GetBuildInfo = function() return "12.1", "1", "x", 120100 end })
  assert(not ns.LeatrixPlus and ns:QolState("leatrix") == "unavailable", "retail client -> dormant, silently")
  ns = RunBootstrap({}, { qol = { leatrix = false } })
  assert(not ns.LeatrixPlus and ns:QolState("leatrix") == "off", "turned off in Clara -> dormant")
  local _, e4 = RunBootstrap({}, nil)
  assert(e4.ClaraLeaPlusDB and e4.ClaraLeaPlusDB.FirstRunMessageSeen == true, "no first-run chat line")
  print("bootstrap: 7 scenarios ok, standalone settings mirrored (unless the embedded copy was used)")
end

---------------------------------------------------------------------------
-- 3. Active: the whole module loads with Clara's ns (frFR chosen in the saved language)
---------------------------------------------------------------------------
local claraL = { CLARA = "Clara", LEA_OWNED = "Done by %s" }
local ns = { L = claraL, qolCategory = { name = "Interface" }, QolRuns = function(_, key) return key == "minimapdrawer" end }
function ns:QolCategory(key) return key == "leatrix" and self.qolCategory or nil end
ns.LeatrixPlus = {}
do -- Clara's one look (Look.lua), loaded before the modules as the TOC has it
  local look = assert(loadstring(readfile(MOD .. "/../../Look.lua"), "@Look.lua"))
  setfenv(look, env)
  look("ClaraComboPoints", ns)
end
rawset(env, "ClaraLeaPlusDB", { AddonLanguage = 6, FirstRunMessageSeen = true }) -- 6 = Francais
for _, name in ipairs(FILES) do
  local fn = chunks[name]
  setfenv(fn, env)
  local ok, err = pcall(fn, "ClaraComboPoints", ns)
  assert(ok, name .. ": " .. tostring(err))
end
assert(ns.L == claraL, "Clara's ns.L was replaced")
assert(ns.LeatrixPlus.L["Level up screenshot"] == "Capture d'écran au niveau supérieur", "frFR Cheese string")
assert(rawget(env, "LeaPlusDB") == nil, "LeaPlusDB global created")
assert(env.SlashCmdList["Leatrix_Plus"] and env.SLASH_Leatrix_Plus1 == "/ltp", "/ltp")
assert(env.SlashCmdList["LEATRIX_PLUS_RL"] == nil, "/rl not Leatrix's")
assert(type(ns.LeatrixPlus.Open) == "function", "Open API")
print("active load: all files ran; Clara ns.L intact; L is frFR; no LeaPlusDB global; /ltp; Open()")

-- the event frame (LpEvt) is the frame whose OnEvent is eventHandler: fire ADDON_LOADED for another addon, then for Clara
local handler
for _, f in ipairs(frames) do
  local s = f.__scripts.OnEvent
  if s then
    local info = debug.getinfo(s, "S")
    if info.source == "@Leatrix_Plus.lua" and info.linedefined > 13000 and info.linedefined < 14100 then handler = s end
  end
end
assert(handler, "eventHandler found")
handler(nil, "ADDON_LOADED", "Leatrix_Plus")
assert(env.ClaraLeaPlusDB.AutomateQuests == nil, "ADDON_LOADED of another name ignored")
handler(nil, "ADDON_LOADED", "ClaraComboPoints")
local db = env.ClaraLeaPlusDB
assert(db.AutomateQuests == "On" and db.UseEasyChatResizing == "On" and db.MaxCameraZoom == "On" and db.LevelUpScreenshot == "Off", "defaults in ClaraLeaPlusDB")
assert(db.InvKey == "+" and db.ClaraDefaults == 1, "Clara's defaults: the invite keyword, once")
db.AutomateQuests = "Off"; db.InvKey = "inv"
handler(nil, "ADDON_LOADED", "ClaraComboPoints")
assert(db.AutomateQuests == "Off" and db.InvKey == "inv", "Clara's defaults set once only: the player's choice kept")
print("ADDON_LOADED: defaults written to ClaraLeaPlusDB (Clara's on, LevelUpScreenshot = Off), once")

-- (the features on by Clara's defaults run at login: what the permissive mock cannot answer)
CONSTANTS_AS_TEXT = true
for k, v in pairs({ GetQuestLink = function() return nil end, DELETE_GOOD_ITEM = "Delete %s?\n\nType DELETE into the field to confirm." }) do rawset(env, k, v) end
local ok, err = xpcall(function() return handler(nil, "PLAYER_LOGIN") end, function(e) return tostring(e) .. "\n" .. debug.traceback("", 2):sub(1, 900) end)
print("PLAYER_LOGIN (Player()):", ok and "ran to the end" or ("stopped: " .. tostring(err)))
for _, r in ipairs(registered) do print("  settings: " .. r) end
for _, c in ipairs(compartment) do print("  compartment: " .. c.text) end

-- logout: the values are saved in ClaraLeaPlusDB, Cheese's standalone time carried over
rawset(env, "CheesePrevLevelTime", 12345)
handler(nil, "PLAYER_LOGOUT")
assert(env.ClaraLeaPlusDB.LevelUpScreenshot == "Off")
assert(env.ClaraLeaPlusDB.CheeseLevelTimes and env.ClaraLeaPlusDB.CheeseLevelTimes["Player-1-00000001"] == 12345, "Cheese time imported")
print("PLAYER_LOGOUT: saved to ClaraLeaPlusDB, CheesePrevLevelTime imported per character")
