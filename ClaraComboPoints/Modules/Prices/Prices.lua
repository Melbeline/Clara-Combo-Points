-- Clara Combo Points - the auction house prices, shared between the player's WoW accounts. A layer of its own, on
-- no scanner of its own: it takes every price a scan sees (Auctionator's, as it records it; Auctionator is its own
-- addon, "All Rights Reserved": none of its code is here, its price records are read and written as it runs), keeps
-- the latest of each item (ClaraPricesDB: price, the scan's day, how many were up, when), and gives the others':
--   * live, while two of the player's characters are online on two accounts: the sync (Sync.lua) sends the new
--     prices of the items one of the player's characters holds (bags, bank, mail: Reverse Engineering's stock,
--     else this character's bags), every 20 seconds at most; never the whole scan (it would flood the server);
--   * between sessions: the Windows script brings the other accounts' ClaraPricesDB (all of it) at login.
-- A price from elsewhere, newer than this account's, goes into Auctionator's own records (its price for the
-- item, its history for that day), so Auctionator's tooltips and LootOptimizer Forever (which reads Auctionator)
-- have it. Without Auctionator: the prices are still kept and passed on. Prices older than 30 days are dropped.
local ADDON, ns = ...

local KEEP_DAYS = 30
local Pr = {}
ns.Prices = nil -- (set when the module runs: the sync shares the prices only then)

-- A price as it may be kept (from this account, another's file or a message): only its known fields
local function CleanRec(rec, at)
  if type(rec) ~= "table" then return nil end
  local m, d = tonumber(rec.m), tonumber(rec.d)
  if not (m and d and m >= 0) then return nil end
  local a = tonumber(rec.a)
  return { m = math.floor(m), d = math.floor(d), a = a and math.max(0, math.floor(a)) or nil,
    t = type(at) == "number" and at or tonumber(rec.t) or 0 }
end
Pr.CleanRec = CleanRec

function Pr.Clean(db)
  db = type(db) == "table" and db or {}
  local out, oldest = { items = {} }, (time and time() or 0) - KEEP_DAYS * 86400
  for key, rec in pairs(type(db.items) == "table" and db.items or {}) do
    local clean = type(key) == "string" and key:find("/", 1, true) and CleanRec(rec)
    if clean and clean.t >= oldest then out.items[key] = clean end
  end
  return out
end

if not ns:QolRuns("prices") then return end
ns.Prices = Pr

---------------------------------------------------------------------------
-- Auctionator: its records for this realm, its day numbers
---------------------------------------------------------------------------
local function A() local a = _G.Auctionator; return type(a) == "table" and a or nil end
local function Realm() local a = A(); return a and a.State and a.State.CurrentRealm end
local function Records()
  local a = A()
  local db = a and type(a.Database) == "table" and a.Database.db
  return type(db) == "table" and db or nil
end
function Pr.Day(at)
  local a = A()
  local zero = a and a.Constants and a.Constants.SCAN_DAY_0
  if type(zero) ~= "number" then zero = time({ year = 2020, month = 1, day = 1, hour = 0 }) end
  return math.floor(((at or time()) - zero) / 86400)
end

-- The item an Auctionator record is for (its keys: "1234", "g:1234:60", "gr:1234:of the Bear", "p:42")
local function ItemID(dbKey) return tonumber(tostring(dbKey):match("^%a*:?(%d+)")) end
Pr.ItemID = ItemID

-- Held by one of the player's characters (the live sync sends only those)
local function Held(id)
  if not id then return false end
  local C = ns.Craft
  if C and C.Have and C.Others then
    if (C.Have(id, true) or 0) > 0 then return true end
    local others = C.Others(id)
    return type(others) == "table" and #others > 0
  end
  local count = C_Item and C_Item.GetItemCount or GetItemCount
  return count ~= nil and (count(id, true) or 0) > 0
end
Pr.Held = Held

-- The latest day of an Auctionator record's history
local function LatestDay(e)
  local latest
  for _, part in ipairs({ e.h, e.l }) do
    for day in pairs(type(part) == "table" and part or {}) do
      local n = tonumber(day)
      if n and (not latest or n > latest) then latest = n end
    end
  end
  return latest
end

-- A price into Auctionator's records: that day's history (its highest and lowest low, the most up), and its
-- current price when that day is later than its latest (or the same day, for a price newer than this account's)
function Pr.WriteAuctionator(dbKey, rec, sameDayWins)
  local records = Records()
  if not (records and rec) then return false end
  local e = records[dbKey]
  if type(e) ~= "table" then
    e = { l = {}, h = {}, a = {}, m = 0 }
    records[dbKey] = e
  end
  e.h, e.l = type(e.h) == "table" and e.h or {}, type(e.l) == "table" and e.l or {}
  local latest = LatestDay(e)
  local day = tostring(rec.d)
  local high = math.max(e.h[day] or rec.m, rec.m)
  local low = math.min(e.l[day] or e.h[day] or rec.m, rec.m)
  e.h[day] = high
  e.l[day] = low < high and low or nil
  if rec.a then
    e.a = type(e.a) == "table" and e.a or {}
    e.a[day] = math.max(e.a[day] or 0, rec.a)
  end
  if not latest or rec.d > latest or (rec.d == latest and sameDayWins) then e.m = rec.m end
  return true
end

---------------------------------------------------------------------------
-- The prices kept
---------------------------------------------------------------------------
-- A price seen here (a scan): kept, and sent live when one of the player's characters holds the item
function Pr.Record(dbKey, price, available, realm)
  realm = realm or Realm()
  if not (Pr.db and realm and dbKey ~= nil and tonumber(price)) then return end
  local key = realm .. "/" .. tostring(dbKey)
  local day = Pr.Day()
  local old = Pr.db.items[key]
  price = math.floor(tonumber(price))
  if old and old.m == price and old.d == day and (old.a or 0) >= (tonumber(available) or 0) then return end
  Pr.db.items[key] = { m = price, d = day, a = tonumber(available), t = time() }
  if Pr.Touched and Held(ItemID(dbKey)) then Pr.Touched("v", key) end
end

-- A price from another account (newer than this one's, the sync says): kept, and into Auctionator's records
function Pr.Put(key, rec, at)
  local clean = type(key) == "string" and CleanRec(rec, at)
  if not (clean and Pr.db) then return end
  Pr.db.items[key] = clean
  local realm, dbKey = key:match("^(.-)/(.+)$")
  if realm and realm == Realm() then Pr.WriteAuctionator(dbKey, clean, true) end
end

-- Every price kept for this realm into Auctionator's records (at login, once its records are there)
function Pr.PushAll()
  local realm, records = Realm(), Records()
  if not (Pr.db and realm and records) then return 0 end
  local prefix, n = realm .. "/", 0
  for key, rec in pairs(Pr.db.items) do
    if key:sub(1, #prefix) == prefix then
      local dbKey = key:sub(#prefix + 1)
      local e = records[dbKey]
      local latest = type(e) == "table" and LatestDay(e)
      if not latest or rec.d >= latest then
        Pr.WriteAuctionator(dbKey, rec, false) -- (the same day: its own price kept, the day's history completed)
        n = n + 1
      end
    end
  end
  return n
end

---------------------------------------------------------------------------
-- Auctionator's scans: each price it records, recorded here too
---------------------------------------------------------------------------
local hooked = {}
local function OnSetPrice(_, dbKey, price, available) Pr.Record(dbKey, price, available) end

function Pr.Attach()
  local a = A()
  if not (a and Records()) then return false end
  local mixin, db = a.DatabaseMixin, a.Database
  if type(mixin) == "table" and type(mixin.SetPrice) == "function" and not hooked[mixin] then
    hooked[mixin] = true
    hooksecurefunc(mixin, "SetPrice", OnSetPrice)
  end
  -- its records made before (they carry their own copy of the function)
  if type(db.SetPrice) == "function" and not hooked[db] and not (mixin and db.SetPrice == mixin.SetPrice) then
    hooked[db] = true
    hooksecurefunc(db, "SetPrice", OnSetPrice)
  end
  if not hooked["push:" .. tostring(db)] then
    hooked["push:" .. tostring(db)] = true
    Pr.PushAll()
  end
  return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    ClaraPricesDB = Pr.Clean(ClaraPricesDB)
    Pr.db = ClaraPricesDB
    -- Auctionator's records come a moment after login: looked for again then, and as the auction house opens
    C_Timer.After(5, Pr.Attach)
    C_Timer.After(30, Pr.Attach)
    for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "PLAYER_LOGOUT" }) do self:RegisterEvent(e) end
  elseif event == "AUCTION_HOUSE_SHOW" then
    Pr.Attach()
  elseif event == "PLAYER_LOGOUT" then
    ClaraPricesDB = Pr.Clean(Pr.db) -- (the oldest dropped)
  end
end)
