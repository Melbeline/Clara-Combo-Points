
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
  local file = path:match("ClaraComboPoints/(.*)$") or path
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
rawset(env, "C_AddOns", setmetatable({ IsAddOnLoaded = function(n) return n == "ClaraComboPoints" end,
  GetAddOnEnableState = function(n) return n == "ClaraComboPoints" and 2 or 0 end,
  DoesAddOnExist = function() return false end, IsAddOnLoadable = function() return false, "MISSING" end,
  GetAddOnMetadata = function(_, k) if k == "Version" then return "1.6.0" end end,
  DisableAddOn = function() end, EnableAddOn = function() end, GetNumAddOns = function() return 1 end },
  { __index = function() return function() return false end end }))
rawset(env, "GetBuildInfo", function() return "1.60.1", "70532", "Oct 1 2026", 16001 end)
local ns = { }
local t0 = os.clock()
for line in readfile(ADDON .. "/ClaraComboPoints.toc"):gmatch("[^\r\n]+") do
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
Fire("ADDON_LOADED", "ClaraComboPoints")
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
  Step("scenario", function() fn({ env = env, ns = ns, Fire = Fire, RunTimers = RunTimers, Updates = Updates }) end)
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
for line in readfile(ADDON .. "/ClaraComboPoints.toc"):gmatch("[^\r\n]+") do
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
