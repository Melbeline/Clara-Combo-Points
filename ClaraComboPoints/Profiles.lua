-- Clara Combo Points - saved profiles
-- Each class tab keeps its own named profiles: a copy of all its settings (position, scale,
-- colours, font, icons...). They are saved, loaded and deleted from the bar page, and passed
-- to another account as a line of text (export / import).

local ADDON, ns = ...
local L = ns.L

local floor = math.floor

local EXPORT_PREFIX = "CCP1:"
local MAX_NAME = 32      -- letters in a profile name
local MAX_IMPORT = 65536 -- characters of an import line
local MAX_DEPTH = 8      -- tables within tables in an import

---------------------------------------------------------------------------
-- Text form of a table, keys sorted (the same table always gives the same text), read back
-- without running any code:  T / F (true / false), N<number>; S<length>:<bytes>, { key value ... }
---------------------------------------------------------------------------
local function KeyLess(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta == "number" end
  return a < b
end

local function Finite(v) return v == v and v > -math.huge and v < math.huge end

local WRITABLE = { boolean = true, number = true, string = true, table = true }

local function Write(v, out)
  local t = type(v)
  if t == "boolean" then
    out[#out + 1] = v and "T" or "F"
  elseif t == "number" then
    local s = string.format("%.14g", v)
    if tonumber(s) ~= v then s = string.format("%.17g", v) end -- exactly the same number
    out[#out + 1] = "N" .. s .. ";"
  elseif t == "string" then
    out[#out + 1] = "S" .. #v .. ":" .. v
  elseif t == "table" then
    local keys = {}
    for k, value in pairs(v) do
      local kt = type(k)
      if (kt == "string" or (kt == "number" and Finite(k))) and WRITABLE[type(value)] then keys[#keys + 1] = k end
    end
    table.sort(keys, KeyLess)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      Write(k, out)
      Write(v[k], out)
    end
    out[#out + 1] = "}"
  end
end

local function Serialize(v)
  local out = {}
  Write(v, out)
  return table.concat(out)
end

-- The value written in s, or nil if s is anything else (cut short, changed, too deep).
local function Deserialize(s)
  local pos, depth = 1, 0
  local Value
  function Value()
    local c = s:sub(pos, pos)
    if c == "T" or c == "F" then
      pos = pos + 1
      return c == "T"
    elseif c == "N" then
      local e = s:find(";", pos + 1, true)
      local text = e and s:sub(pos + 1, e - 1)
      local v = text and text:match("^%-?[%d%.]+[eE]?[%+%-]?%d*$") and tonumber(text)
      if not v or not Finite(v) then return nil end
      pos = e + 1
      return v
    elseif c == "S" then
      local len, colon = s:match("^(%d+)():", pos + 1)
      len = tonumber(len)
      if not len or colon + len - 1 > #s then return nil end
      pos = colon + 1 + len
      return s:sub(colon + 1, colon + len)
    elseif c == "{" then
      depth = depth + 1
      if depth > MAX_DEPTH then return nil end
      pos = pos + 1
      local t = {}
      while s:sub(pos, pos) ~= "}" do
        if pos > #s then return nil end
        local k = Value()
        if type(k) ~= "string" and type(k) ~= "number" then return nil end
        local v = Value()
        if v == nil then return nil end
        t[k] = v
      end
      pos = pos + 1
      depth = depth - 1
      return t
    end
    return nil
  end
  local ok, v = pcall(Value)
  if ok and v ~= nil and pos == #s + 1 then return v end
end

-- Base64, so the line holds only letters, digits, + / and = (nothing the chat box or an edit
-- box would read as a code).
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE = {}
for i = 1, 64 do B64_VALUE[B64:byte(i)] = i - 1 end
local function Digit(n) return B64:sub(n + 1, n + 1) end

local function Encode(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = s:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    out[#out + 1] = Digit(floor(n / 262144)) .. Digit(floor(n / 4096) % 64)
      .. (b and Digit(floor(n / 64) % 64) or "=") .. (c and Digit(n % 64) or "=")
  end
  return table.concat(out)
end

local function Decode(s)
  if #s % 4 ~= 0 then return nil end
  local out = {}
  for i = 1, #s, 4 do
    local last = i + 3 == #s
    local n, pad = 0, 0
    for j = 0, 3 do
      local byte = s:byte(i + j)
      local v = B64_VALUE[byte]
      if byte == 61 and last and j >= 2 then -- "=" closing the last group
        pad, v = pad + 1, 0
      elseif not v or pad > 0 then
        return nil
      end
      n = n * 64 + v
    end
    local a, b, c = floor(n / 65536), floor(n / 256) % 256, n % 256
    out[#out + 1] = pad == 2 and string.char(a) or pad == 1 and string.char(a, b) or string.char(a, b, c)
  end
  return table.concat(out)
end

ns.Serialize, ns.Deserialize, ns.Encode64, ns.Decode64 = Serialize, Deserialize, Encode, Decode

---------------------------------------------------------------------------
-- Profiles of each class: sv.saved[class][name] = settings; sv.active[class] = the profile
-- last saved or loaded on that tab (to warn before its changes are lost).
---------------------------------------------------------------------------
local function DeepCopy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, value in pairs(v) do t[k] = DeepCopy(value) end
  return t
end

local function Same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- What a profile keeps of a tab's settings: everything but the lock (a moment's state).
local function Snapshot(db)
  local copy = DeepCopy(db)
  copy.locked = nil
  return copy
end

-- The first n letters of a text (a letter may take several bytes).
local function Cut(s, n)
  local letters = 0
  return (s:gsub("[%z\1-\127\194-\244][\128-\191]*", function()
    letters = letters + 1
    if letters > n then return "" end
  end))
end

-- A name as it is kept: no colour, texture or link codes (nor any other "|"), no control
-- characters, no spaces around it, at most MAX_NAME letters.
local function CleanName(name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|[TA].-|[ta]", ""):gsub("|H.-|h", ""):gsub("|h", "")
  name = Cut(name:gsub("[|%c]", ""):gsub("^%s+", ""), MAX_NAME):gsub("%s+$", "")
  if name == "" then return nil end
  return name
end
ns.CleanProfileName = CleanName

local function Contains(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

local function Store(class)
  local saved = ns.sv.saved
  saved[class] = saved[class] or {}
  return saved[class]
end

-- Checks the profiles kept in the saved variables (account-wide), when the addon loads.
function ns:InitProfiles(sv)
  if type(sv.saved) ~= "table" then sv.saved = {} end
  if type(sv.active) ~= "table" then sv.active = {} end
  for key in pairs(sv.saved) do
    if not Contains(self.PROFILES, key) then sv.saved[key] = nil end
  end
  for _, class in ipairs(self.PROFILES) do
    local store = sv.saved[class]
    if type(store) ~= "table" then store = {}; sv.saved[class] = store end
    local clean = {}
    for name, data in pairs(store) do
      local kept = CleanName(name)
      if kept and type(data) == "table" and not clean[kept] then clean[kept] = self:CleanProfileData(data, class) end
    end
    sv.saved[class] = clean
    if type(sv.active[class]) ~= "string" or not clean[sv.active[class]] then sv.active[class] = nil end
  end
  for key in pairs(sv.active) do
    if not Contains(self.PROFILES, key) then sv.active[key] = nil end
  end
end

-- The profile names of a class, in alphabetical order.
function ns:ProfileNames(class)
  local names = {}
  for name in pairs(Store(class)) do names[#names + 1] = name end
  table.sort(names, function(a, b)
    local la, lb = self:Fold(a), self:Fold(b)
    if la ~= lb then return la < lb end
    return a < b
  end)
  return names
end

function ns:ActiveProfile(class)
  local name = self.sv.active[class]
  if name and Store(class)[name] then return name end
end

-- Has the tab changed since its profile was last saved or loaded?
function ns:ProfileModified(class)
  local name = self:ActiveProfile(class)
  return name ~= nil and not Same(Snapshot(self.sv.profiles[class]), Store(class)[name])
end

-- Settings that differ from every saved profile of the class (nothing would bring them back).
function ns:SettingsUnsaved(class)
  local now = Snapshot(self.sv.profiles[class])
  for _, data in pairs(Store(class)) do
    if Same(now, data) then return false end
  end
  return true
end

function ns:HasProfile(class, name)
  name = CleanName(name)
  return name ~= nil and Store(class)[name] ~= nil
end

-- Saves the tab's settings under a name (a new profile, or over the one of that name).
function ns:SaveProfile(class, name)
  name = CleanName(name)
  if not name then return false, L.PROFILE_NO_NAME end
  Store(class)[name] = Snapshot(self.sv.profiles[class])
  self.sv.active[class] = name
  self:RefreshOptions()
  return true, L.PROFILE_SAVED:format(name)
end

-- Puts a profile's settings on the tab (its lock aside) and shows them.
function ns:LoadProfile(class, name)
  local data = Store(class)[name]
  if not data then return false, L.PROFILE_MISSING end
  local db = self.sv.profiles[class]
  local locked = db.locked
  self:CleanProfileData(data, class, db) -- a copy: the saved profile stays as it is
  db.locked = locked
  self.sv.active[class] = name
  if db == self.db then self:ApplyAll() end
  self:RefreshOptions()
  return true, L.PROFILE_LOADED:format(name)
end

function ns:DeleteProfile(class, name)
  local store = Store(class)
  if not store[name] then return false, L.PROFILE_MISSING end
  store[name] = nil
  if self.sv.active[class] == name then self.sv.active[class] = nil end
  self:RefreshOptions()
  return true, L.PROFILE_DELETED:format(name)
end

-- One line of text holding a profile, to paste on another account.
function ns:ExportProfile(class, name)
  local data = Store(class)[name]
  if not data then return nil end
  return EXPORT_PREFIX .. Encode(Serialize({ v = 1, class = class, name = name, data = data }))
end

-- A name not used yet on this tab: "Name", else "Name (2)", "Name (3)"...
local function FreeName(store, name)
  if not store[name] then return name end
  for n = 2, 999 do
    local suffix = " (" .. n .. ")"
    local candidate = CleanName(Cut(name, MAX_NAME - #suffix):gsub("%s+$", "") .. suffix)
    if candidate and not store[candidate] then return candidate end
  end
end

-- Reads an exported line into a new profile of this tab (kept under its own name, or a
-- numbered one if taken). Returns true and the name, or false and why.
function ns:ImportProfile(class, text)
  if type(text) ~= "string" then return false, L.IMPORT_BAD end
  text = text:gsub("%s", "")
  if #text > MAX_IMPORT or text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then return false, L.IMPORT_BAD end
  local raw = Decode(text:sub(#EXPORT_PREFIX + 1))
  local t = raw and Deserialize(raw)
  if type(t) ~= "table" or t.v ~= 1 or type(t.data) ~= "table" then return false, L.IMPORT_BAD end
  local store = Store(class)
  local name = FreeName(store, CleanName(t.name) or L.PROFILE_IMPORTED)
  if not name then return false, L.IMPORT_BAD end
  store[name] = self:CleanProfileData(t.data, class)
  self:RefreshOptions()
  return true, name
end
