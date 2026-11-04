-- The sniper (Modules/Sniper): its prices over time (each day's lowest; 24 hours, 30 days, then weeks, then
-- months, all time; kept as strings), the usual price over each window (median or mean, with how many prices it
-- rests on), its tab in Auctionator's strip (registered as Auctionator lets addons), a pass over the whole auction
-- house (page after page) listing at once the items far enough under their usual price (the best first, a sound
-- for a new one), the window, the median/mean and the share changed with one click and the list redone at once,
-- the slider and its box agreeing, a row opening the game's buy view, a pause then the next pass.
-- Auctionator and the auction house stood in for (as Auctionator 341 and the game's C_AuctionHouse are).
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
  enemycasts = false, reverseengineering = false, money = false, lofplus = false, prices = false } }
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

out("== its tab in Auctionator's strip")
check(registered and registered.tabTemplate == "ClaraSniperTabFrameTemplate" and registered.tabFrameName == "ClaraSniperFrame",
  "registered as Auctionator lets addons add a tab")
check(registered and registered.tabOrder > 3 and registered.tabOrder < 4, "between Cancel and Auctionator's own options: the last but one")

out("== its prices over time")
M.Fire("AUCTION_HOUSE_SHOW")
check(H.db.seeded.Forever, "Auctionator's own history taken once")
local ref, n = H.Reference("Forever/2589", 7, "median")
check(ref == 100 and n == 7, "7 days: Linen Cloth at 100, on 7 days (" .. tostring(ref) .. ", " .. tostring(n) .. ")")
Auctionator.Database:SetPrice("2589", 80)
check(H.Get("Forever/2589").d[2000] == 80, "a price seen today: the day's lowest")
check(H.Reference("Forever/2589", 1, "median") == 80, "24 hours: the prices seen since")
-- a long history: a price a day for 400 days of Wool Cloth (2592), going up by 1
for d = 1601, 2000 do H.Add("Forever/2592", 1000 + (d - 1601), DayAt(d)) end
local h = H.Get("Forever/2592")
local daily, weeks, months = 0, 0, 0
for _ in pairs(h.d) do daily = daily + 1 end
for _ in pairs(h.w) do weeks = weeks + 1 end
for _ in pairs(h.m) do months = months + 1 end
check(daily == 30 and weeks >= 45 and weeks <= 53 and months >= 1, "kept small: 30 days, then weeks, then months (" .. daily .. "/" .. weeks .. "/" .. months .. ")")
local r3 = H.Reference("Forever/2592", 3, "median")
local r30 = H.Reference("Forever/2592", 30, "median")
local r182 = H.Reference("Forever/2592", 182, "median")
local rall, nall = H.Reference("Forever/2592", 0, "mean")
check(r3 == 1398, "3 days: the last three's median (" .. tostring(r3) .. ")")
check(r30 >= 1383 and r30 <= 1385, "30 days (" .. tostring(r30) .. ")")
check(r182 >= 1300 and r182 <= 1312, "6 months: days and weeks (" .. tostring(r182) .. ")")
check(nall == 400 and math.abs(rall - 1199.5) < 1, "all time: the mean of every day (" .. tostring(rall) .. ", " .. tostring(nall) .. ")")
local mean7 = H.Reference("Forever/2592", 7, "mean")
check(mean7 == 1396, "the mean too (7 days: " .. tostring(mean7) .. ")")
-- kept as a string, read back the same
local packed = H.Pack(h)
local back = H.Unpack(packed)
check(H.Pack(back) == packed and type(packed) == "string", "kept as a string, read back the same")
M.Fire("PLAYER_LOGOUT")
check(type(ClaraPriceHistoryDB.items["Forever/2592"]) == "string", "saved in ClaraPriceHistoryDB")

out("== a pass over the auction house")
local f = CreateFrame("Frame", "ClaraSniperFrame", AuctionHouseFrame)
ClaraSniper_OnLoad(f)
f:Show()
check(f.Go and #f.windows == 9 and f.Slider and f.Box and f.Mode, "the tab: start, nine windows, median/mean, slider and its box")
check(f.Box:GetText() == "40", "a deal: 40 % under by default")
-- the browse: Wool Cloth at 700 (half its usual 1396), Linen Cloth at 95 (just under), a new item (no history)
pages[1] = {
  { itemKey = { itemID = 2592, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }, minPrice = 700, totalQuantity = 5 },
  { itemKey = { itemID = 2589, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }, minPrice = 95, totalQuantity = 20 },
  { itemKey = { itemID = 4306, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }, minPrice = 1, totalQuantity = 1 },
}
ns.SniperSet("window", 7)
f.Go:GetScript("OnClick")(f.Go)
check(Sn.running and sent == 1, "started: one browse")
M.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check(more == 1, "not all yet: the next page asked")
local deals = Sn.Sorted()
check(#deals == 1 and deals[1].result.itemKey.itemID == 2592 and math.floor(deals[1].off + 0.5) == 50, "at once: Wool Cloth, 50 % under")
check(played == 1, "a sound for it")
check(f.rows[1]:IsShown() and f.rows[1].cells.off:GetText():find("-50", 1, true), "listed")
M.Fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = { itemID = 2775, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }, minPrice = 5, totalQuantity = 1 } })
check(not Sn.waiting and Sn.passes == 1, "all pages: the pass done")
check(Sn.seen["4306:0:0:0"] and not Sn.deals["4306:0:0:0"], "an item without enough prices: not a deal")

out("== one click: another window, the mean, another share")
f.Box:SetText("3"); f.Box:GetScript("OnEnterPressed")(f.Box)
check(ns.SniperGet("pct") == 3 and math.floor(f.Slider:GetValue() + 0.5) == 3, "typed in its box: the slider follows")
check(Sn.deals["2589:0:0:0"], "3 %: Linen Cloth now a deal (95 under 100)")
f.Slider:SetValue(60)
check(ns.SniperGet("pct") == 60 and f.Box:GetText() == "60" and #Sn.Sorted() == 0, "the slider to 60 %: its box follows, no deal left")
f.Slider:SetValue(40)
local all = f.windows[9]
all:GetScript("OnClick")(all)
check(ns.SniperGet("window") == 0 and Sn.deals["2592:0:0:0"] and math.floor(Sn.deals["2592:0:0:0"].off + 0.5) == 42, "all time: the list redone at once (42 % under)")
f.Mode:GetScript("OnClick")(f.Mode)
check(ns.SniperGet("mode") == "mean", "the mean, one click")
check(f.Mode:GetText() == "Mean", "its button says it")

out("== a row: the game's buy view")
f.rows[1]:GetScript("OnClick")(f.rows[1])
check(selected and selected.itemKey.itemID == 2592, "the game's own buy view, on that item")

out("== the next pass, after a pause; stopped")
Run()
check(sent == 2, "a pause, then the next pass")
f.Go:GetScript("OnClick")(f.Go)
check(not Sn.running and f.Go:GetText() == "Start sniping", "stopped")
M.Fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
M.Fire("AUCTION_HOUSE_CLOSED")
Run()
check(sent == 2, "no pass after it is stopped")

out(fails .. " failure(s)")
