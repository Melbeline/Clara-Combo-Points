-- The sniper's full scan (Modules/Sniper): its button at the tab's top right, the whole auction house at once (the
-- game's ReplicateItems: once every 15 minutes), read a batch a frame; each item's lowest unit price (buyouts only,
-- battle pet cages left out) kept in the prices' history, among the prices shared with the other accounts and in
-- Auctionator's records, and judged as the passes judge it (a deal listed, a sound);
-- a chat line at the end; the button then waits out the game's 15 minutes (its minutes shown); nothing sent back:
-- said; the auction house closed: stopped.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
if not io.open(ADDON_DIR .. "/Modules/Sniper/Sniper.lua", "rb") then -- (the Light version: not built in)
  out("  ok   the Light version: not in it"); out("0 failure(s)"); return
end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  mail = false, classicui = false, tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false,
  enemycasts = false, reverseengineering = false, money = false, lofplus = false, prices = true } }
local ZERO = 1577836800
local now = ZERO + 2000 * 86400 + 43200 -- (day 2000, noon)
time = function(t) if t then return ZERO end return now end
local function DayAt(day) return ZERO + day * 86400 + 43200 end

-- Auctionator, as its public side is
local registered
Auctionator = { State = { CurrentRealm = "Forever" }, Constants = { SCAN_DAY_0 = ZERO }, DatabaseMixin = {},
  Tabs = { Register = function(details) registered = details end }, AH = {}, Utilities = {} }
function Auctionator.DatabaseMixin:SetPrice(dbKey, price) self.db[dbKey] = self.db[dbKey] or { l = {}, h = {}, a = {}, m = 0 }; self.db[dbKey].m = price end
function Auctionator.Utilities.DBKeyFromBrowseResult(r) return { tostring(r.itemKey.itemID) } end
-- (its records, with a history of its own: 10 days of Linen Cloth at 100)
local records = { ["2589"] = { l = {}, h = {}, a = {}, m = 100 } }
for d = 1991, 2000 do records["2589"].h[tostring(d)] = 100 end
Auctionator.Database = { db = records, SetPrice = Auctionator.DatabaseMixin.SetPrice }
-- the auction house: a browse, two pages
local pages, page, sent, more = {}, 0, 0, 0
local fullAfter = 2
C_AuctionHouse = C_AuctionHouse or {}
function Auctionator.AH.SendBrowseQuery() sent = sent + 1; page = 1 end
function Auctionator.AH.RequestMoreBrowseResults() more = more + 1; page = page + 1 end
function Auctionator.AH.HasFullBrowseResults() return page >= fullAfter end
C_AuctionHouse.GetBrowseResults = function() return pages[1] or {} end
C_AuctionHouse.GetItemKeyInfo = function(k) return { itemName = "Item " .. k.itemID, quality = 1, iconFileID = 1 } end
local selected
AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
function AuctionHouseFrame:SelectBrowseResult(r) selected = r end
local played = 0
PlaySound = function() played = played + 1 end
SOUNDKIT = SOUNDKIT or {}; SOUNDKIT.AUCTION_WINDOW_OPEN = SOUNDKIT.AUCTION_WINDOW_OPEN or 1

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local function Run() for _ = 1, 200 do if not (M.timers and #M.timers > 0) then break end M.RunTimer() end end
local H, Sn = ns.PriceHistory, ns.Sniper


local replicated, REP = 0, {}
C_AuctionHouse.ReplicateItems = function() replicated = replicated + 1 end
C_AuctionHouse.GetNumReplicateItems = function() return #REP end
C_AuctionHouse.GetReplicateItemInfo = function(i)
  local a = REP[i + 1] -- (0-based, as the game's)
  if not a then return end
  return "x", 1, a.count, 1, true, 1, "", 0, 0, a.buyout, 0, nil, nil, "Seller", "Seller", 0, a.id, true
end
local function Auction(id, count, buyout) REP[#REP + 1] = { id = id, count = count, buyout = buyout } end
Auction(2589, 20, 1000)   -- Linen Cloth: 50 a unit (half its usual 100)
Auction(2589, 5, 400)     -- 80 a unit
Auction(9999, 1, 500)     -- a new item: no history yet
Auction(82800, 1, 99999)  -- a battle pet's cage: left out
Auction(2590, 4, 0)       -- bids only: left out
for i = 1, 1201 do Auction(3000, 1, 7 + i) end -- (more than a batch: read over several frames)
local function Chat(pat) for _, line in ipairs(M.chat or {}) do if line:find(pat, 1, true) then return true end end return false end

out("== its button")
local f = CreateFrame("Frame", "ClaraSniperFrame", AuctionHouseFrame)
ClaraSniper_OnLoad(f)
f:Show()
check(f.Full and f.Full:GetText() == "Full scan" and f.Full:IsEnabled(), "at the top right: Full scan")
out("== the whole auction house at once")
M.chat = {}
played = 0
f.Full:Click()
check(replicated == 1 and not f.Full:IsEnabled() and f.Full:GetText():find("Scanning", 1, true), "asked of the game; the button: " .. f.Full:GetText())
M.Fire("REPLICATE_ITEM_LIST_UPDATE")
local midway = f.Full:GetText()
local pct = tonumber(midway:match("(%d+) %%"))
check(pct and pct > 0 and pct < 90 and Sn.full ~= nil, "read a batch a frame: " .. midway)
M.Fire("REPLICATE_ITEM_LIST_UPDATE") -- (sent again: read once)
Run()
check(Sn.full == nil, "done")
local d = Sn.deals["2589:0:0:0"]
check(d and d.price == 50 and math.floor(d.off + 0.5) == 50, "Linen Cloth at 50 a unit, half its usual price: a deal")
check(played > 0, "heard")
check(H.Reference("Forever/9999", 1, "median") == 500, "a new item: its price kept in the history (" .. tostring(H.Reference("Forever/9999", 1, "median")) .. ")")
check(H.Reference("Forever/3000", 1, "median") == 8, "the lowest of its 1201 auctions kept (" .. tostring(H.Reference("Forever/3000", 1, "median")) .. ")")
check(H.Reference("Forever/82800", 0, "median") == nil and H.Reference("Forever/2590", 0, "median") == nil, "a pet cage, bids only: left out")
check(Chat("full scan done: 1206 auctions read, 3 items' prices kept"), "said in the chat")
local Pr = ns.Prices
check(Pr and Pr.db and Pr.db.items["Forever/2589"] and Pr.db.items["Forever/2589"].m == 50 and Pr.db.items["Forever/9999"].m == 500,
  "among the prices shared with the other accounts (as Auctionator's scans' prices)")
check(records["2589"].m == 50 and records["9999"] and records["9999"].m == 500, "and in Auctionator's records (its tooltips' price)")
out("== then: the game's 15 minutes")
check(not f.Full:IsEnabled() and f.Full:GetText() == "Full scan (15 min)", "waiting: " .. f.Full:GetText())
f.Full:Click()
check(replicated == 1, "not asked again meanwhile")
now = now + 16 * 60
Sn.Refresh()
check(f.Full:IsEnabled() and f.Full:GetText() == "Full scan", "16 minutes on: ready again")
out("== nothing sent back")
M.chat = {}
f.Full:Click()
Run()
check(replicated == 2 and Sn.full == nil and Chat("sent nothing back"), "said, the button waiting again")
out("== the auction house closed meanwhile")
now = now + 16 * 60
Sn.Refresh() -- (the tab's ticker, every 5 seconds)
f.Full:Click()
M.Fire("REPLICATE_ITEM_LIST_UPDATE")
M.Fire("AUCTION_HOUSE_CLOSED")
Run()
check(Sn.full == nil and replicated == 3, "stopped (" .. tostring(Sn.full) .. ", " .. replicated .. ")")
out(fails .. " failure(s)")
return fails
