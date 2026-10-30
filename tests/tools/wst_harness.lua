-- Harness for the WeaponSwingTimer module of Clara Combo Points (lupa, Lua 5.1), on a permissive
-- mock of the game API (taken from the Leatrix one). ADDON = the ClaraComboPoints folder.
local ADDON = ...
local MOD = ADDON .. "/Modules/WeaponSwingTimer"
local FILES = { "localization.lua", "WeaponSwingTimer_ranged_base_speed.lua", "WeaponSwingTimer_Utils.lua",
  "WeaponSwingTimer_Player.lua", "WeaponSwingTimer_Target.lua", "WeaponSwingTimer_Castbar.lua",
  "WeaponSwingTimer_Hunter.lua", "WeaponSwingTimer_Range.lua", "WeaponSwingTimer_Frames.lua", "WeaponSwingTimer_Config.lua", "WeaponSwingTimer_Core.lua" }
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
  "chat_msg", "off_width", "main_width", "spell_name", "WST_IsSecret", "getglobal" }) do NILS[k] = true end
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
  OpenToCategory = function() end,
})
local compartment = {}
rawset(env, "AddonCompartmentFrame", { RegisterAddon = function(self, data) compartment[#compartment + 1] = data end, registeredAddons = {} })


rawset(env, "setfenv", setfenv); rawset(env, "getfenv", getfenv)
rawset(env, "CopyTable", function(t)
  local function copy(x) if type(x) ~= "table" then return x end local c = {} for k, v in pairs(x) do c[k] = copy(v) end return c end
  return copy(t) end)
rawset(env, "SlashCmdList", {})
rawset(env, "StaticPopupDialogs", {})

-- one session: the libraries, QoL.lua, Env.lua and the module, then its events
local first = 1 -- events go to the frames of the current session only
local function Session(opts)
  first = #frames + 1
  for _, k in ipairs({ "ClaraWSTDB", "WSTProfileDB", "LibStub" }) do rawset(env, k, nil) end
  if opts.saved then rawset(env, "ClaraWSTDB", opts.saved) end
  if opts.standaloneDB then rawset(env, "WSTProfileDB", opts.standaloneDB) end
  rawset(env, "UnitClass", function() return opts.class or "Warrior", opts.class or "WARRIOR", 1 end)
  local loaded = opts.standalone and function(n) return n == "WeaponSwingTimer" end or function() return false end
  rawset(env, "C_AddOns", setmetatable({ IsAddOnLoaded = loaded }, { __index = function() return function() return false end end }))
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
  ns.settingsCategory = { name = "Clara", GetID = function() return "Clara" end } -- (SettingsPage.lua runs first)
  local function run(path, name)
    local fn = chunk(path, name)
    setfenv(fn, env)
    fn("ClaraComboPoints", ns)
  end
  for _, lib in ipairs({ "LibStub/LibStub.lua", "CallbackHandler-1.0/CallbackHandler-1.0.lua", "AceDB-3.0/AceDB-3.0.lua" }) do
    run(ADDON .. "/Libs/" .. lib, lib)
  end
  run(ADDON .. "/QoL.lua", "QoL.lua")
  run(MOD .. "/Env.lua", "Env.lua")
  for _, f in ipairs(FILES) do run(MOD .. "/" .. f, f) end
  return ns
end

local function fire(event, ...)
  for i = first, #frames do local f = frames[i]
    local h = f.__scripts and f.__scripts.OnEvent
    if h then pcall(h, f, event, ...) end
  end
end
local function fireStrict(event, ...)
  for i = first, #frames do local f = frames[i]
    local h = f.__scripts and f.__scripts.OnEvent
    if h then h(f, event, ...) end
  end
end

-- 1. Active, fresh install, a warrior
local before = #frames
local ns = Session({ class = "WARRIOR" })
assert(ns.WST and ns:QolState("wst") == "on", "the module runs")
local E = ns.WST
assert(rawget(env, "SLASH_WEAPONSWINGTIMER_CONFIG3") == "/wst" and env.SlashCmdList.WEAPONSWINGTIMER_CONFIG, "/wst kept, in the real globals")
assert(rawget(env, "character_hunter_settings") == nil, "its settings aliases stay in its own globals")
fireStrict("ADDON_LOADED", "ClaraComboPoints")
local db = rawget(env, "ClaraWSTDB")
assert(type(db) == "table", "saved in ClaraWSTDB")
local d = E.data
local hs = E.env.character_hunter_settings
assert(hs and hs.hunters_only == true and hs.enabled == true, "ranged bar: enabled, hunters only")
assert(E.env.character_player_settings.enabled == false and E.env.character_target_settings.enabled == false, "melee bars off by default")
assert(E.env.character_core_settings.welcome_message == false, "no welcome message")
assert(d.hunter.IsShown() == false, "a warrior: no ranged bar")
hs.hunters_only = false
assert(d.hunter.IsShown() == true, "unticked: every class")
for _, name in ipairs({ "ClaraWSTCoreFrame", "ClaraWSTPlayerFrame", "ClaraWSTHunterAutoshotFrame" }) do
  assert(rawget(env, name), "frame renamed: " .. name)
end
assert(rawget(env, "WeaponSwingTimerCoreFrame") == nil and rawget(env, "MyFrame") == nil, "no frame under the standalone's names")
for _, k in ipairs({ "chat_msg", "off_width", "main_width", "point", "x_offset" }) do
  assert(rawget(env, k) == nil, "no global leak: " .. k)
end
print("active: loaded, ClaraWSTDB, Clara's defaults, hunters only, renamed frames, no leaks")
fireStrict("PLAYER_LOGIN")
fireStrict("PLAYER_ENTERING_WORLD")
print("events: ADDON_LOADED, PLAYER_LOGIN ran")

-- 2. A hunter
ns = Session({ class = "HUNTER" })
fireStrict("ADDON_LOADED", "ClaraComboPoints")
assert(ns.WST.data.hunter.IsShown() == true, "a hunter: the ranged bar")
print("hunter: ranged bar shown")

-- the switches on its page of Clara's options window
local sw = {}
for _, s in ipairs(ns.qolSwitches.wst) do sw[s.label] = s end
assert(sw.WST_SW_HUNTER.get() == true and sw.WST_SW_HUNTERS_ONLY.get() == true, "switches: ranged bar on, hunters only")
assert(sw.WST_SW_PLAYER.get() == false and sw.WST_SW_TARGET.get() == false and sw.WST_SW_LOCKED.get() == true, "switches: no swing bars, locked")
sw.WST_SW_PLAYER.set(true)
assert(ns.WST.env.character_player_settings.enabled == true and sw.WST_SW_PLAYER.get() == true, "your swing bars: on")
sw.WST_SW_LOCKED.set(false)
assert(ns.WST.env.character_hunter_settings.is_locked == false and ns.WST.env.character_castbar_settings.is_locked == false, "every bar unlocked")
sw.WST_SW_LOCKED.set(true); sw.WST_SW_PLAYER.set(false)
print("switches: read and set the character's settings")

-- the distance box on the target and focus frames (UnitBoxes.lua): a hunter's by default, its range bands
-- for any unit, in short, with their colors
assert(sw.WST_SW_RANGE_BOX and sw.WST_SW_RANGE_BOX.get() == true and ns.WST.RangeBoxOn() == true, "a hunter: the distance box on")
local SPELLS = { ["Wing Clip"] = 1, ["Scatter Shot"] = 2, ["Auto Shot"] = 3, ["Hunter's Mark"] = 4, Charge = 5, Intercept = 6 }
local inRange = {} -- [spell][unit] = true/false
rawset(env, "C_SpellBook", { FindSpellBookSlotForSpell = function(name) if SPELLS[name] then return SPELLS[name], 1 end end,
  IsSpellBookItemInRange = function(slot, bank, unit)
    for name, n in pairs(SPELLS) do if n == slot then return (inRange[name] or {})[unit] end end
  end })
rawset(env, "C_Spell", { GetSpellInfo = function(id)
  local info = { [75] = { maxRange = 35 }, Charge = { minRange = 8, maxRange = 25, name = "Charge" },
    Intercept = { minRange = 8, maxRange = 25, name = "Intercept" } }
  return info[id] end, GetSpellName = function() end })
rawset(env, "C_SwingTimer", { IsTargetWithinSwingRange = function() return nil end }) -- (no answer: the spell check)
rawset(env, "UnitExists", function(u) return u == "target" or u == "focus" end)
rawset(env, "UnitIsDead", function() return false end)
rawset(env, "UnitCanAttack", function(_, u) return u ~= "friend" end)
rawset(env, "UnitIsUnit", function(a, b) return a == b end)
rawset(env, "CheckInteractDistance", function() return false end)
inRange = { ["Wing Clip"] = { focus = false }, ["Scatter Shot"] = { focus = true }, ["Auto Shot"] = { focus = true },
  ["Hunter's Mark"] = { focus = true } }
local short, key, r, g, b = ns.WST.RangeBand("focus")
assert(short == "8-15" and key == "close" and r == 0.95 and g == 0.75 and b == 0.10, "the focus, 8-15: " .. tostring(short) .. " " .. tostring(key))
inRange["Wing Clip"].focus = true
assert(ns.WST.RangeBand("focus") == "0-5", "in melee: 0-5")
inRange = { ["Auto Shot"] = { target = true }, ["Scatter Shot"] = { target = false } }
assert(ns.WST.RangeBand("target") == "15-35", "the target, past Scatter Shot: 15-35 (" .. tostring(ns.WST.RangeBand("target")) .. ")")
inRange = { ["Auto Shot"] = { target = false }, ["Hunter's Mark"] = { target = false } }
assert(ns.WST.RangeBand("target") == "100+", "out of Hunter's Mark: 100+")
assert(ns.WST.RangeBand("friend") == nil, "a friend: nothing")
sw.WST_SW_RANGE_BOX.set(false)
assert(ns.WST.RangeBoxOn() == false and ns.WST.env.character_range_settings.frame_box == false, "unticked")
sw.WST_SW_RANGE_BOX.set(true)
print("distance box: on for a hunter, bands for target and focus, in short, colored")
-- the frames tab's settings: the attack speed (a hunter's), its flash, a boss's swing timer
assert(ns.WST.SpeedBoxOn() == true and sw.WST_SW_SPEED_BOX.get() == true, "a hunter: the attack speed box on")
local flashOn, flashTime = ns.WST.SpeedFlash()
assert(flashOn == true and flashTime == 5, "its flash: on, 5 s")
local bossOn, br, bg, bb, ba, front = ns.WST.BossSwing()
assert(bossOn == true and br == 1 and ba == 0.9 and front == true and sw.WST_SW_BOSS_SWING.get() == true, "a boss's swing timer: on, white, 0.9, in front")
local told = 0
ns.WST.OnRangeBoxChanged = function() told = told + 1 end
sw.WST_SW_SPEED_BOX.set(false)
sw.WST_SW_BOSS_SWING.set(false)
assert(ns.WST.SpeedBoxOn() == false and (ns.WST.BossSwing()) == false and told == 2, "unticked, the boxes told")
sw.WST_SW_SPEED_BOX.set(true); sw.WST_SW_BOSS_SWING.set(true)
assert(ns.WST.data.frames.panel ~= nil, "the frames tab built")
print("frames tab: attack speed, flash, boss swing timer settings")

-- 3. The standalone runs: dormant, its settings copied at login
local standaloneDB = { profileKeys = { ["Lola - Forever"] = "Default" }, profiles = { Default = {
  player = { enabled = true, width = 300, x_offset = 120 },  -- enabled = WST default, x_offset changed
  hunter = { width = 250, enabled = true, ooc_alpha = 0 },
  core = { welcome_message = true } } } }
ns = Session({ class = "HUNTER", standalone = true, standaloneDB = standaloneDB })
assert(not ns.WST and ns:QolState("wst") == "standalone", "standalone: dormant")
fireStrict("PLAYER_LOGIN")
local copied = rawget(env, "ClaraWSTDB")
assert(copied and copied.profiles.Default.player.x_offset == 120 and copied.global.wstImportPending, "settings copied at login")
fireStrict("PLAYER_LOGOUT")
print("standalone: dormant, its settings copied")

-- 4. The standalone turned off: the copy is used, WST's own defaults give way to Clara's
ns = Session({ class = "WARRIOR", saved = copied })
fireStrict("ADDON_LOADED", "ClaraComboPoints")
local ps = ns.WST.env.character_player_settings
assert(ps.x_offset == 120 and ps.width == 300, "changed values kept")
assert(ps.enabled == false, "player.enabled was WST's default: Clara's (off)")
assert(ns.WST.env.character_hunter_settings.width == 250, "hunter width kept")
assert(ns.WST.env.character_core_settings.welcome_message == false, "welcome back to Clara's default")
assert(not rawget(env, "ClaraWSTDB").global.wstImportPending, "normalised once")
print("import: changed values kept, untouched ones at Clara's defaults")

-- a warrior: off by default, its probes in short
ns = Session({ class = "WARRIOR" })
fireStrict("ADDON_LOADED", "ClaraComboPoints")
assert(ns.WST.RangeBoxOn() == false and ns.WST.SpeedBoxOn() == false, "a warrior: the distance and attack speed boxes off by default")
inRange = { Charge = { target = true }, Intercept = { target = true } }
assert(ns.WST.RangeBand("target") == "8-25", "a warrior in Charge's range: 8-25 (" .. tostring(ns.WST.RangeBand("target")) .. ")")
inRange = { Charge = { target = false }, Intercept = { target = false } }
assert(ns.WST.RangeBand("target") == "25+", "beyond: 25+")
print("distance box: off for a warrior, its spells' bands")

-- 5. Turned off in Clara
ns = Session({ class = "WARRIOR", saved = { }, })
rawset(env, "ClaraComboPointsDB", { qol = { wst = false } })
ns = Session({ class = "WARRIOR" })
assert(not ns.WST and ns:QolState("wst") == "off", "turned off: dormant")
rawset(env, "ClaraComboPointsDB", nil)
print("off: dormant")
print("ALL OK")
