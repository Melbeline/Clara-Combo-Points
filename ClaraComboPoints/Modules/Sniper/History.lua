-- Clara Combo Points - the auction house prices over time, for the sniper (Sniper.lua): each item's lowest price
-- of each day, from 24 hours to all time. Every price Auctionator records (its scans, and every search of the
-- auction house, the sniper's too; Auctionator is its own addon, none of its code here: its records are read as it
-- runs) is added; so are the prices the other accounts send (Prices.lua), and at the first run Auctionator's own
-- history of each item. Kept small:
--   the last 24 hours: each price seen (24 at most);
--   the last 30 days: the lowest price of each day;
--   then each week: its days' lowest prices (7 at most), up to a year;
--   then each month (30 days): its total, its number of days and its weeks' medians;
--   all time: the total and the number of days.
-- Saved in ClaraPriceHistoryDB, this account's own (the other accounts' come as prices, not as histories: the
-- Windows script does not carry it, it would be too big).
local ADDON, ns = ...

local DAILY_DAYS, WEEKLY_WEEKS = 30, 52
local RECENT_MAX, DAY = 24, 86400

local H = {}
ns.PriceHistory = nil -- (set when the sniper runs)
if not ns:QolRuns("sniper") then return end
ns.PriceHistory = H

-- The day numbers: Auctionator's (days since 2020-01-01, local time), weeks and months of them
local function Zero()
  local a = _G.Auctionator
  local zero = a and a.Constants and a.Constants.SCAN_DAY_0
  if type(zero) ~= "number" then zero = time({ year = 2020, month = 1, day = 1, hour = 0 }) end
  return zero
end
function H.Day(at) return math.floor(((at or time()) - Zero()) / DAY) end
local function Week(day) return math.floor(day / 7) end
local function Month(day) return math.floor(day / 30) end

---------------------------------------------------------------------------
-- An item's history, as kept (a string) and as used (a table)
---------------------------------------------------------------------------
-- { d = { [day] = price }, w = { [week] = { price, ... } }, m = { [month] = { s, n, { median, ... } } },
--   a = { s, n }, r = { { time, price }, ... } }
local function New() return { d = {}, w = {}, m = {}, a = { 0, 0 }, r = {} } end

-- (keys in order: the same history, the same string)
local function Ordered(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

local function Pack(h)
  local parts = {}
  local list = {}
  for _, day in ipairs(Ordered(h.d)) do list[#list + 1] = day .. "," .. h.d[day] end
  parts[1] = table.concat(list, ";")
  list = {}
  for _, wk in ipairs(Ordered(h.w)) do list[#list + 1] = wk .. "," .. table.concat(h.w[wk], "/") end
  parts[2] = table.concat(list, ";")
  list = {}
  for _, mo in ipairs(Ordered(h.m)) do
    local b = h.m[mo]
    list[#list + 1] = mo .. "," .. b[1] .. "," .. b[2] .. "," .. table.concat(b[3], "/")
  end
  parts[3] = table.concat(list, ";")
  parts[4] = h.a[1] .. "," .. h.a[2]
  list = {}
  for _, o in ipairs(h.r) do list[#list + 1] = o[1] .. "," .. o[2] end
  parts[5] = table.concat(list, ";")
  return table.concat(parts, "|")
end
H.Pack = Pack

local function Numbers(s, sep)
  local out = {}
  for n in tostring(s or ""):gmatch("[^" .. sep .. "]+") do out[#out + 1] = tonumber(n) end
  return out
end

local function Unpack(s)
  local h = New()
  if type(s) ~= "string" then return h end
  local d, w, m, a, r = s:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
  if not d then return h end
  for day, p in d:gmatch("(%-?%d+),(%d+)") do h.d[tonumber(day)] = tonumber(p) end
  for wk, values in w:gmatch("(%-?%d+),([%d/]+)") do h.w[tonumber(wk)] = Numbers(values, "/") end
  for mo, sum, n, meds in m:gmatch("(%-?%d+),(%d+),(%d+),([%d/]*)") do h.m[tonumber(mo)] = { tonumber(sum), tonumber(n), Numbers(meds, "/") } end
  local sum, n = a:match("^(%d+),(%d+)$")
  if sum then h.a = { tonumber(sum), tonumber(n) } end
  for t, p in r:gmatch("(%d+),(%d+)") do h.r[#h.r + 1] = { tonumber(t), tonumber(p) } end
  return h
end
H.Unpack = Unpack

local open, dirty, cache = {}, {}, {}

local function Get(key, create)
  local h = open[key]
  if h then return h end
  local saved = H.db and H.db.items[key]
  if not saved and not create then return nil end
  h = Unpack(saved)
  open[key] = h
  return h
end
H.Get = Get

local function Median(values)
  local n = #values
  if n == 0 then return nil end
  local sorted = {}
  for i, v in ipairs(values) do sorted[i] = v end
  table.sort(sorted)
  if n % 2 == 1 then return sorted[(n + 1) / 2] end
  return math.floor((sorted[n / 2] + sorted[n / 2 + 1]) / 2 + 0.5)
end
H.Median = Median

-- The old days into their weeks, the old weeks into their months (the history as of today)
local function Fold(h, today)
  for day, p in pairs(h.d) do
    if day <= today - DAILY_DAYS then
      local wk = Week(day)
      local values = h.w[wk] or {}
      if #values < 7 then values[#values + 1] = p end
      h.w[wk] = values
      h.d[day] = nil
    end
  end
  local thisWeek = Week(today)
  for wk, values in pairs(h.w) do
    if wk <= thisWeek - WEEKLY_WEEKS then
      local mo = Month(wk * 7)
      local b = h.m[mo] or { 0, 0, {} }
      for _, v in ipairs(values) do b[1] = b[1] + v end
      b[2] = b[2] + #values
      if #b[3] < 6 then b[3][#b[3] + 1] = Median(values) end
      h.m[mo] = b
      h.w[wk] = nil
    end
  end
end

-- A price seen (at a time; its day the lowest of that day's)
function H.Add(key, price, at)
  price = tonumber(price)
  if not (H.db and type(key) == "string" and price and price > 0) then return end
  at = at or time()
  local now, day, today = time(), H.Day(at), H.Day()
  if day <= today - DAILY_DAYS then return H.AddDay(key, day, price) end -- (an old day: into its week)
  local h = Get(key, true)
  do
    local old = h.d[day]
    if not old then
      h.d[day] = price
      h.a[1], h.a[2] = h.a[1] + price, h.a[2] + 1
    elseif price < old then
      h.d[day] = price
      h.a[1] = h.a[1] + price - old
    end
  end
  if now - at < DAY then
    local r = {}
    for _, o in ipairs(h.r) do if now - o[1] < DAY then r[#r + 1] = o end end
    r[#r + 1] = { at, price }
    while #r > RECENT_MAX do table.remove(r, 1) end
    h.r = r
  end
  Fold(h, today)
  dirty[key] = true
  cache[key] = nil
end

-- A day's lowest price from elsewhere (Auctionator's own history): kept if lower, or new
function H.AddDay(key, day, price)
  price = tonumber(price)
  if not (H.db and price and price > 0 and day) then return end
  local today = H.Day()
  if day > today - DAILY_DAYS then
    H.Add(key, price, Zero() + day * DAY + DAY / 2)
    return
  end
  local h = Get(key, true)
  local wk = Week(day)
  if wk > Week(today) - WEEKLY_WEEKS then
    local values = h.w[wk] or {}
    if #values < 7 then
      values[#values + 1] = price
      h.a[1], h.a[2] = h.a[1] + price, h.a[2] + 1
    end
    h.w[wk] = values
  else -- (older than a year: into its month)
    local mo = Month(day)
    local b = h.m[mo] or { 0, 0, {} }
    if b[2] < 31 then
      b[1], b[2] = b[1] + price, b[2] + 1
      if #b[3] < 6 then b[3][#b[3] + 1] = price end
      h.a[1], h.a[2] = h.a[1] + price, h.a[2] + 1
    end
    h.m[mo] = b
  end
  dirty[key], cache[key] = true, nil
end

---------------------------------------------------------------------------
-- An item's usual price over a window (days; 1: the last 24 hours, 0: all time): the median or the mean of
-- its days' lowest prices; with how many prices it rests on
---------------------------------------------------------------------------
H.WINDOWS = { 1, 3, 7, 15, 30, 91, 182, 365, 0 }

local function Values(h, window, today)
  local values, weights = {}, {}
  local function Put(v, w) values[#values + 1] = v; weights[#weights + 1] = w or 1 end
  if window == 1 then
    local now = time()
    for _, o in ipairs(h.r) do if now - o[1] < DAY then Put(o[2]) end end
    return values, weights
  end
  local from = window == 0 and -math.huge or today - window
  for day, p in pairs(h.d) do if day > from then Put(p) end end
  if window == 0 or window > DAILY_DAYS then
    for wk, list in pairs(h.w) do
      if wk * 7 + 6 > from then for _, v in ipairs(list) do Put(v) end end
    end
    for mo, b in pairs(h.m) do
      if mo * 30 + 29 > from and #b[3] > 0 then
        for _, med in ipairs(b[3]) do Put(med, b[2] / #b[3]) end
      end
    end
  end
  return values, weights
end

local function WeightedMedian(values, weights)
  local n = #values
  if n == 0 then return nil end
  local order = {}
  for i = 1, n do order[i] = i end
  table.sort(order, function(a, b) return values[a] < values[b] end)
  local total = 0
  for i = 1, n do total = total + weights[i] end
  local run = 0
  for _, i in ipairs(order) do
    run = run + weights[i]
    if run >= total / 2 then return values[i] end
  end
  return values[order[n]]
end

-- mode: "median" (default) or "mean"
function H.Reference(key, window, mode)
  local h = Get(key)
  if not h then return nil, 0 end
  local slot = window .. (mode or "median")
  local c = cache[key]
  local today = H.Day()
  if c and c[slot] and c[slot][3] == today and window ~= 1 then return c[slot][1], c[slot][2] end
  local values, weights = Values(h, window, today)
  local count, ref = 0, nil
  for _, w in ipairs(weights) do count = count + w end
  if #values > 0 then
    if mode == "mean" then
      if window == 0 and h.a[2] > 0 then
        ref = math.floor(h.a[1] / h.a[2] + 0.5)
        count = h.a[2]
      else
        local sum = 0
        for i, v in ipairs(values) do sum = sum + v * weights[i] end
        ref = math.floor(sum / count + 0.5)
      end
    else
      ref = WeightedMedian(values, weights)
    end
  end
  count = math.floor(count + 0.5)
  c = c or {}
  c[slot] = { ref, count, today }
  cache[key] = c
  return ref, count
end

---------------------------------------------------------------------------
-- Fed by Auctionator's records, and by the other accounts' prices
---------------------------------------------------------------------------
local function A() local a = _G.Auctionator; return type(a) == "table" and a or nil end
local function Realm() local a = A(); return a and a.State and a.State.CurrentRealm end
H.Realm = Realm

local hooked = {}
local function OnSetPrice(_, dbKey, price)
  local realm = Realm()
  if realm and dbKey ~= nil then H.Add(realm .. "/" .. tostring(dbKey), price) end
end

-- Auctionator's own history of each item, once per realm (its records keep 21 days, or as it is set)
function H.Seed()
  local a, realm = A(), Realm()
  local records = a and type(a.Database) == "table" and a.Database.db
  if not (H.db and realm and type(records) == "table") or H.db.seeded[realm] then return 0 end
  H.db.seeded[realm] = H.Day()
  local n = 0
  for dbKey, e in pairs(records) do
    if type(e) == "table" and type(e.h) == "table" then
      local key = realm .. "/" .. tostring(dbKey)
      for day, high in pairs(e.h) do
        local d = tonumber(day)
        local low = type(e.l) == "table" and tonumber(e.l[day]) or nil
        if d then H.AddDay(key, d, low and math.min(low, high) or high); n = n + 1 end
      end
    end
  end
  return n
end

function H.Attach()
  local a = A()
  if not (a and type(a.Database) == "table" and type(a.Database.db) == "table") then return false end
  local mixin, db = a.DatabaseMixin, a.Database
  if type(mixin) == "table" and type(mixin.SetPrice) == "function" and not hooked[mixin] then
    hooked[mixin] = true
    hooksecurefunc(mixin, "SetPrice", OnSetPrice)
  end
  if type(db.SetPrice) == "function" and not hooked[db] and not (mixin and db.SetPrice == mixin.SetPrice) then
    hooked[db] = true
    hooksecurefunc(db, "SetPrice", OnSetPrice)
  end
  H.Seed()
  return true
end

-- Kept: the items changed this session, back into their strings
function H.Save()
  if not H.db then return end
  for key in pairs(dirty) do
    local h = open[key]
    if h then H.db.items[key] = Pack(h) end
  end
  dirty = {}
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    local db = type(ClaraPriceHistoryDB) == "table" and ClaraPriceHistoryDB or {}
    db.items = type(db.items) == "table" and db.items or {}
    db.seeded = type(db.seeded) == "table" and db.seeded or {}
    ClaraPriceHistoryDB = db
    H.db = db
    -- the other accounts' prices, as they come (Prices.lua)
    local Pr = ns.Prices
    if Pr and Pr.Put then
      hooksecurefunc(Pr, "Put", function(key, rec, at)
        if type(rec) == "table" and tonumber(rec.m) then H.Add(key, rec.m, at) end
      end)
    end
    C_Timer.After(5, H.Attach)
    C_Timer.After(30, H.Attach)
    for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "PLAYER_LOGOUT" }) do self:RegisterEvent(e) end
  elseif event == "AUCTION_HOUSE_SHOW" then
    H.Attach()
  elseif event == "PLAYER_LOGOUT" then
    H.Save()
  end
end)
