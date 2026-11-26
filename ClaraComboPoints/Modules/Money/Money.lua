-- Clara - the gold of all the player's characters, on every WoW account: each character's money, level and
-- class, kept as it logs in and as its money or level changes; the other accounts' come through the sync
-- (Sync.lua: live while both are online, the Windows script between sessions). Each WoW account has an id
-- of its own (its saved data being its own) and a name: the one the Windows script knows it by (its WTF
-- folder: ICKSTU, WANJ; 123456789#1 shown as WoW1), or one the player gives it. Shown by a right click on
-- the money at the bottom of the backpack (MoneyUI.lua). Saved in ClaraMoneyDB, for the account.
local ADDON, ns = ...
local issecretvalue = issecretvalue or function() return false end

local G = {}
ns.Money = nil -- (set below when the module runs: the sync takes the gold only then)

local CHARS = "abcdefghijklmnopqrstuvwxyz0123456789"
local function Random(n)
  local out = {}
  for i = 1, n do
    local k = math.random(1, #CHARS)
    out[i] = CHARS:sub(k, k)
  end
  return table.concat(out)
end

-- Its profession cooldowns (ProfCooldowns.lua): { [key] = { e = when ready (time()), g = 1 for a transmute } }, the
-- key "s<spell>" or "i<item>"
local function CleanTimers(t)
  if type(t) ~= "table" then return nil end
  local out, n = {}, 0
  for key, v in pairs(t) do
    if type(key) == "string" and key:match("^[si]%d+$") and type(v) == "table" and type(v.e) == "number" and n < 40 then
      out[key] = { e = math.max(0, math.floor(v.e)), g = v.g == 1 and 1 or nil }
      n = n + 1
    end
  end
  return n > 0 and out or nil
end
G.CleanTimers = CleanTimers

-- A record as it may be kept (from this account, another's file or a message): only its known fields
local function CleanChar(rec, at)
  if type(rec) ~= "table" then return nil end
  local out = {
    n = type(rec.n) == "string" and rec.n or nil,
    s = type(rec.s) == "string" and rec.s ~= "" and rec.s:sub(1, 48) or nil, -- (its surname: WoW Forever's names)
    r = type(rec.r) == "string" and rec.r or "",
    c = type(rec.c) == "string" and rec.c or nil,
    l = type(rec.l) == "number" and math.floor(rec.l) or 0,
    m = type(rec.m) == "number" and math.max(0, math.floor(rec.m)) or 0,
    a = type(rec.a) == "string" and rec.a or nil,
    t = CleanTimers(rec.t),
    at = type(at) == "number" and at or (type(rec.at) == "number" and rec.at or 0),
  }
  if not (out.n and out.a) then return nil end
  return out
end
G.CleanChar = CleanChar

function G.Clean(db)
  db = type(db) == "table" and db or {}
  local out = { me = type(db.me) == "string" and #db.me >= 4 and db.me or nil, accounts = {}, chars = {}, gone = {},
    order = {}, collapsed = {}, pos = type(db.pos) == "table" and db.pos or nil }
  for id, a in pairs(type(db.accounts) == "table" and db.accounts or {}) do
    if type(id) == "string" and type(a) == "table" and type(a.n) == "string" and a.n ~= "" then
      out.accounts[id] = { n = a.n:sub(1, 24), at = type(a.at) == "number" and a.at or 0 }
    end
  end
  for key, rec in pairs(type(db.chars) == "table" and db.chars or {}) do
    if type(key) == "string" then out.chars[key] = CleanChar(rec) end
  end
  for key, at in pairs(type(db.gone) == "table" and db.gone or {}) do
    if type(key) == "string" and type(at) == "number" and not out.chars[key] then out.gone[key] = at end
  end
  for id, list in pairs(type(db.order) == "table" and db.order or {}) do
    if type(id) == "string" and type(list) == "table" then
      local keep = {}
      for _, key in ipairs(list) do if type(key) == "string" then keep[#keep + 1] = key end end
      out.order[id] = keep
    end
  end
  for id, on in pairs(type(db.collapsed) == "table" and db.collapsed or {}) do
    if type(id) == "string" and on == true then out.collapsed[id] = true end
  end
  return out
end

-- An account's folder name as the player calls it: 123456789#1 is WoW1 (the launcher's own name for it)
function G.PrettyFolder(folder)
  if type(folder) ~= "string" then return nil end
  local n = folder:match("^%d+#(%d+)$")
  if n then return "WoW" .. n end
  return folder
end

-- The name the Windows script gives another account (its folder): kept unless one was given already
function G.FolderName(id, folder)
  local name = G.PrettyFolder(folder)
  if not (G.db and type(id) == "string" and name) then return false end
  if G.db.accounts[id] then return false end
  G.db.accounts[id] = { n = name, at = 1 } -- (the oldest time: a name the player gives wins everywhere)
  if G.Touched then G.Touched("n", id) end
  return true
end

function G.Rename(id, name)
  if not (G.db and type(id) == "string" and type(name) == "string") then return end
  name = name:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 24)
  if name == "" then return end
  G.db.accounts[id] = { n = name, at = time() }
  if G.Touched then G.Touched("n", id) end
  if G.Changed then G.Changed() end
end

function G.AccountName(id)
  local a = G.db and G.db.accounts[id]
  return a and a.n or nil
end

-- A character forgotten (deleted, or one the player no longer plays): gone everywhere, at this time
function G.Forget(key)
  if not (G.db and G.db.chars[key]) then return end
  G.db.chars[key] = nil
  G.db.gone[key] = time()
  if G.Touched then G.Touched("g", key) end
  if G.Changed then G.Changed() end
end

local runs = ns:QolRuns("money")
ns:SetQolOpener("money", function() if G.Toggle then G.Toggle(true) end end)
if not runs then return end
ns.Money = G

-- This character, as it is now
local function Me()
  local name = UnitName("player")
  if type(name) ~= "string" then return nil end
  local realm = GetNormalizedRealmName and GetNormalizedRealmName() or (GetRealmName and GetRealmName() or ""):gsub("%s", "")
  return name .. "-" .. (realm or ""), name, realm or ""
end
G.Me = Me

-- This character's surname (WoW Forever: "First Surname"), or nil
local function Surname()
  if not UnitNameUnmodified then return nil end
  local ok, _, surname = pcall(UnitNameUnmodified, "player")
  if not ok or type(surname) ~= "string" or issecretvalue(surname) or surname == "" then return nil end
  return surname
end

local function Record()
  if not G.db then return end
  local key, name, realm = Me()
  if not key then return end
  local money = GetMoney and GetMoney() or 0
  local level = UnitLevel and UnitLevel("player") or 0
  local _, class = UnitClass("player")
  local surname = Surname()
  local old = G.db.chars[key]
  if old and old.m == money and old.l == level and old.c == class and old.a == G.db.me and old.s == surname then return end
  G.db.chars[key] = { n = name, s = surname, r = realm, c = class, l = level, m = money, a = G.db.me, t = old and old.t or nil,
    at = time() }
  G.db.gone[key] = nil
  if G.Touched then G.Touched("g", key) end
  if G.Changed then G.Changed() end
end
G.Record = Record

-- The characters of an account, in the order shown: the one the player dragged them in (new ones after,
-- by level), else the highest level first (then by name)
function G.List(id)
  local list = {}
  for key, rec in pairs(G.db.chars) do if rec.a == id then list[#list + 1] = key end end
  local function ByLevel(a, b)
    local ra, rb = G.db.chars[a], G.db.chars[b]
    if ra.l ~= rb.l then return ra.l > rb.l end
    return a < b
  end
  table.sort(list, ByLevel)
  local order = G.db.order[id]
  if not order then return list end
  local rank, out, seen = {}, {}, {}
  for i, key in ipairs(order) do rank[key] = i end
  for _, key in ipairs(order) do
    if G.db.chars[key] and G.db.chars[key].a == id and not seen[key] then out[#out + 1] = key; seen[key] = true end
  end
  for _, key in ipairs(list) do if not seen[key] then out[#out + 1] = key end end
  return out
end

-- The accounts with characters (or this one), by name (ICKSTU, WANJ, WoW1...); unnamed ones after
function G.Accounts()
  local seen, list = { [G.db.me] = true }, { G.db.me }
  for _, rec in pairs(G.db.chars) do
    if rec.a and not seen[rec.a] then seen[rec.a] = true; list[#list + 1] = rec.a end
  end
  table.sort(list, function(a, b)
    local na, nb = G.AccountName(a), G.AccountName(b)
    if (na ~= nil) ~= (nb ~= nil) then return na ~= nil end
    if na and nb and na ~= nb then return na < nb end
    return a < b
  end)
  return list
end

-- When an account's characters were last heard of (the newest of their records), or nil
function G.Updated(id)
  local newest
  for _, rec in pairs(G.db.chars) do
    if rec.a == id and type(rec.at) == "number" and rec.at > 1 and (not newest or rec.at > newest) then newest = rec.at end
  end
  return newest
end

-- A character's whole name: "First Surname" (the first name alone for a record made before surnames were kept)
function G.FullName(rec) return rec.s and (rec.n .. " " .. rec.s) or rec.n end

function G.Total(id)
  local sum = 0
  for _, rec in pairs(G.db.chars) do if id == nil or rec.a == id then sum = sum + (rec.m or 0) end end
  return sum
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    ClaraMoneyDB = G.Clean(ClaraMoneyDB)
    G.db = ClaraMoneyDB
    if not G.db.me then G.db.me = Random(8) end
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "PLAYER_LEVEL_UP" }) do self:RegisterEvent(e) end
    if G.Started then G.Started() end
  elseif event == "PLAYER_ENTERING_WORLD" then
    Record() -- (sent only when something changed since the last time)
  elseif event == "PLAYER_LEVEL_UP" then
    C_Timer.After(1, function() Record() end) -- (UnitLevel is the new one a moment later)
  else
    Record()
  end
end)
