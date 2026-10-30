-- ClassicUI Forever built in: when it runs, the standalone's settings copied while that one runs,
-- being turned off (lupa, Lua 5.1; QoL.lua and the module's Bootstrap.lua and Glue.lua over stand-ins).
local ADDON = ...
local function readfile(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local fails = 0
local function check(c, m) print((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local function Session(opts)
  local frames = {}
  local env = {}
  local function Frame()
    local f = { scripts = {}, events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:Hide() end
    frames[#frames + 1] = f
    return f
  end
  for k, v in pairs({ pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, next = next, pcall = pcall, select = select,
    setmetatable = setmetatable, string = string, table = table, math = math,
    CreateFrame = Frame, GetBuildInfo = function() return "1.60.1", "70532", "", 16001 end,
    UnitName = function() return "Lea" end, UnitGUID = function() return "Player-1-0001" end, GetRealmName = function() return "Realm" end,
    CopyTable = function(t) local function c(x) if type(x) ~= "table" then return x end local o = {} for k2, v2 in pairs(x) do o[k2] = c(v2) end return o end return c(t) end,
    C_AddOns = { IsAddOnLoaded = function(n) return opts.standalone and n == "ClassicUIForever" or false end,
      DoesAddOnExist = function() return false end,
      GetAddOnEnableState = function(n) return (opts.claraOff and n == "ClaraComboPoints") and 0 or 2 end },
    Enum = { AddOnEnableState = { None = 0 } },
    Settings = nil, ClaraComboPointsDB = opts.clara,
    ForeverClassicUIDB = opts.db, ForeverClassicUICharDB = opts.char,
    ForeverClassicUI_OnAddonCompartmentClick = opts.standalone and function() env.opened = "standalone" end or nil,
  }) do env[k] = v end
  env._G = env
  local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
  for _, file in ipairs({ "QoL.lua", "Modules/ClassicUI/Bootstrap.lua", "Modules/ClassicUI/Glue.lua" }) do
    local fn = assert(loadstring(readfile(ADDON .. "/" .. file), "@" .. file))
    setfenv(fn, env)
    fn("ClaraComboPoints", ns)
  end
  ns.sv = env.ClaraComboPointsDB or {}
  env.ClaraComboPointsDB = ns.sv
  local function fire(e) for _, f in ipairs(frames) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e) end end end
  return ns, env, fire
end

print("== built in")
local ns, env, fire = Session({})
check(ns.ClassicUIRuns == true and type(ns.ClassicUIPrivate) == "table", "it runs, with its own table")
check(ns:ClassicUITurningOff() == false, "not being turned off")
ns:SetQolEnabled("classicui", false)
check(ns:ClassicUITurningOff() == true, "its box unticked: being turned off at the reload (its hand back)")
ns:SetQolEnabled("classicui", true)
check(ns:ClassicUITurningOff() == false, "ticked again")
ns, env = Session({ claraOff = true })
check(ns:ClassicUITurningOff() == true, "Clara Combo Points turned off for the character: being turned off too")

print("== the standalone enabled")
ns, env, fire = Session({ standalone = true, db = { themeDark = true }, char = { profile = "Default" } })
check(not ns.ClassicUIRuns and ns.ClassicUIPrivate == nil and ns:QolState("classicui") == "standalone", "Clara's copy does nothing")
fire("PLAYER_LOGIN")
check(env.ClaraClassicUIDB and env.ClaraClassicUIDB.themeDark == true and env.ClaraClassicUIDB ~= env.ForeverClassicUIDB, "its settings copied at login")
env.ForeverClassicUIDB.themeDark = false
env.ForeverClassicUICharDB.profile = "Mine"
fire("PLAYER_LOGOUT")
check(env.ClaraClassicUIDB.themeDark == false and env.ClaraClassicUICharDB.profile == "Mine", "and at logout (this character's too)")
ns:OpenQol("classicui")
check(env.opened == "standalone", "its options: the standalone's")

print("== turned off")
ns, env = Session({ clara = { qol = { classicui = false } } })
check(not ns.ClassicUIRuns and ns.ClassicUIPrivate == nil, "nothing runs")

print("")
print(fails .. " failure(s)")
