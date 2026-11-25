-- The auction house prices shared between the WoW accounts (Modules/Prices, through Modules/Sync): every price an
-- Auctionator scan records is kept here too (its newest per item); live, only the items the player's characters
-- hold go out (in messages of 150 at most); from another account (live or its file), a newer price goes into
-- Auctionator's own records (its price, that day's history), an older one is left; another realm's is kept apart;
-- at login all of this realm's go into Auctionator's records once they are there. Auctionator stood in for: its
-- public tables (Auctionator.Database with its records, DatabaseMixin.SetPrice, State, Constants) as in 341.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
if not io.open(ADDON_DIR .. "/Modules/Prices/Prices.lua", "rb") then -- (the Light version: not built in)
  out("  ok   the Light version: not in it"); out("0 failure(s)"); return
end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false, money = false, lofplus = false } }
local now = 1800000000
time = function(t) if t then return 1577836800 end return now end -- (2020-01-01: Auctionator's day 0)
local DAY = math.floor((now - 1577836800) / 86400)
local held = { [2589] = 4 } -- (Linen Cloth in the bags)
C_Item = C_Item or {}
C_Item.GetItemCount = function(id) return held[id] or 0 end

-- Auctionator, as its public side is: its records for this realm, made from its mixin (the function copied)
Auctionator = { State = { CurrentRealm = "Forever" }, Constants = { SCAN_DAY_0 = 1577836800 }, DatabaseMixin = {} }
function Auctionator.DatabaseMixin:SetPrice(dbKey, price, available)
  local e = self.db[dbKey] or { l = {}, h = {}, a = {}, m = 0 }
  self.db[dbKey] = e
  e.m = price
  e.h[tostring(DAY)] = math.max(e.h[tostring(DAY)] or 0, price)
end
-- (its records come a moment after login)
local function MakeDatabase(records)
  Auctionator.Database = { db = records, SetPrice = Auctionator.DatabaseMixin.SetPrice }
end
-- another account's file, brought by the script: one price newer than none here, one of another realm
ClaraSyncIncoming = { ["WANJ"] = { ClaraPricesDB = { items = {
  ["Forever/4306"] = { m = 900, d = DAY - 1, a = 3, t = now - 86400 },
  ["Other/4306"] = { m = 5, d = DAY, t = now - 10 },
  ["Forever/2592"] = { m = 77, d = DAY - 40, t = now - 40 * 86400 }, -- (older than 30 days: dropped)
} }, ClaraSyncDB = { key = "0000aaaa0000aaaa", mine = { ["Frank-Forever"] = true } } } } -- (Frank: played on WANJ, one of the player's)

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local Pr, Sync = ns.Prices, ns.Sync
for _ = 1, 10 do if ClaraSyncDB then break end M.RunTimer() end -- (the sync starts a frame after login)
-- (its hidden channel, there to be joined)
if Sync then S.channels = { "General", "ClaraSync" .. ("%06x"):format(Sync.Hash(ClaraSyncDB.key)) } end
M.Fire("PLAYER_ENTERING_WORLD")
for _ = 1, 30 do if not (M.timers and #M.timers > 0) then break end M.RunTimer() end

out("== another account's file, at login")
check(Pr and Sync and Pr.db.items["Forever/4306"] and Pr.db.items["Forever/4306"].m == 900, "its price kept here")
check(Pr.db.items["Other/4306"] and Pr.db.items["Other/4306"].m == 5, "another realm's: kept apart")
check(Pr.db.items["Forever/2592"] == nil, "older than 30 days: dropped")
local records = { ["4306"] = { l = {}, h = { [tostring(DAY - 5)] = 1200 }, a = {}, m = 1200 } }
MakeDatabase(records)
Pr.Attach()
check(records["4306"].m == 900 and records["4306"].h[tostring(DAY - 1)] == 900, "Auctionator's records there: the newer price in them, with its day")
check(records["4306"].h[tostring(DAY - 5)] == 1200, "its own history kept")

out("== a scan here")
local mark = #M.addonSent + 1
Auctionator.Database:SetPrice("2589", 120, 50)
Auctionator.Database:SetPrice("g:2589:5", 300, 1)
Auctionator.Database:SetPrice("12345", 4000, 2) -- (no character holds it)
check(Pr.db.items["Forever/2589"] and Pr.db.items["Forever/2589"].m == 120 and Pr.db.items["Forever/2589"].d == DAY, "each price Auctionator records, kept here (its day)")
check(Pr.db.items["Forever/12345"] and Pr.db.items["Forever/12345"].m == 4000, "every item, held or not")
check(records["2589"].m == 120, "Auctionator's own records as it made them")
local function Run() for _ = 1, 5000 do if not (M.timers and #M.timers > 0) then break end M.RunTimer() end end
Run()
local sentKeys = {}
for i = mark, #M.addonSent do
  local p = M.addonSent[i]
  if p[1] == "ClaraSync" then sentKeys[#sentKeys + 1] = p[2] end
end
local wire = table.concat(sentKeys)
local function Has(key) return wire ~= "" end
-- (read back as test59 does)
local whole, msgs = {}, {}
for i = mark, #M.addonSent do
  local p = M.addonSent[i]
  if p[1] == "ClaraSync" then
    local id, k, n, body = p[2]:match("^(%w%w%d)(%d+)/(%d+):(.*)$")
    local slot = p[3] .. id
    whole[slot] = whole[slot] or {}
    whole[slot][tonumber(k)] = body
    if #whole[slot] == tonumber(n) then
      msgs[#msgs + 1] = ns.Deserialize(ns.Decode64(table.concat(whole[slot]):sub(7)))
      whole[slot] = nil
    end
  end
end
local sent = {}
for _, msg in ipairs(msgs) do
  if msg.t == "B" and msg.k == "v" then for _, e in ipairs(msg.e) do sent[e[1]] = e end end
end
check(sent["Forever/2589"] and sent["Forever/2589"][3].m == 120 and sent["Forever/g:2589:5"], "live: the items a character holds (any of their Auctionator keys)")
check(sent["Forever/12345"] == nil, "not the others (the files bring them)")

out("== from another account, live")
local function Entries(list)
  local payload = ns.Encode64(ns.Serialize({ t = "B", k = "v", e = list }))
  local text = ("%06x"):format(Sync.Hash(ClaraSyncDB.key .. payload)) .. payload
  local n = math.ceil(#text / 100)
  for i = 1, n do Sync.OnAddon("ClaraSync", "ab1" .. i .. "/" .. n .. ":" .. text:sub((i - 1) * 100 + 1, i * 100), "CHANNEL", "Frank") end
end
now = now + 60
Entries({ { "Forever/2589", now, { m = 95, d = DAY, a = 60 } }, { "Forever/2770", now, { m = 50, d = DAY, a = 2 } } })
check(Pr.db.items["Forever/2589"].m == 95, "a newer price: kept here")
check(records["2589"].m == 95 and records["2589"].h[tostring(DAY)] == 120 and records["2589"].l[tostring(DAY)] == 95,
  "into Auctionator's records: its price, the day's highest and lowest")
check(records["2770"] and records["2770"].m == 50, "an item Auctionator had not seen: there now")
Entries({ { "Forever/2589", now - 3000, { m = 10, d = DAY, a = 1 } } })
check(Pr.db.items["Forever/2589"].m == 95 and records["2589"].m == 95, "an older one: left")
Entries({ { "Other/2589", now, { m = 1, d = DAY } } })
check(records["2589"].m == 95 and Pr.db.items["Other/2589"], "another realm's: kept apart, not in this realm's records")

out("== a whole scan's held items: several messages")
for id = 30000, 30399 do held[id] = 1 end
mark = #M.addonSent + 1
for id = 30000, 30399 do Auctionator.Database:SetPrice(tostring(id), id, 1) end
Run()
whole, msgs = {}, {}
for i = mark, #M.addonSent do
  local p = M.addonSent[i]
  if p[1] == "ClaraSync" and p[3] == "CHANNEL" then
    local id, k, n, body = p[2]:match("^(%w%w%d)(%d+)/(%d+):(.*)$")
    whole[id] = whole[id] or {}
    whole[id][tonumber(k)] = body
    if #whole[id] == tonumber(n) then
      msgs[#msgs + 1] = { n = tonumber(n), msg = ns.Deserialize(ns.Decode64(table.concat(whole[id]):sub(7))) }
      whole[id] = nil
    end
  end
end
local total, biggest, parts = 0, 0, 0
for _, m in ipairs(msgs) do
  if m.msg.k == "v" then total = total + #m.msg.e; biggest = math.max(biggest, #m.msg.e); parts = math.max(parts, m.n) end
end
check(total == 400 and biggest <= 150 and #msgs >= 3, "400 prices: in " .. #msgs .. " messages of 150 at most")
check(parts <= 400, "each within what a receiver takes (" .. parts .. " parts)")

out("== the same price seen again: not sent again")
mark = #M.addonSent + 1
Auctionator.Database:SetPrice("2589", 95, 60)
Run()
check(#M.addonSent < mark, "nothing new: nothing sent")

out("== kept at logout, the oldest dropped")
M.Fire("PLAYER_LOGOUT")
check(ClaraPricesDB and ClaraPricesDB.items["Forever/2589"] and ClaraPricesDB.items["Forever/2589"].m == 95, "in ClaraPricesDB")

out(fails .. " failure(s)")
