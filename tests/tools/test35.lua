-- BuyEmAll built in: Shift + click on a merchant's item, any amount, a stack at a time
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- WoW Forever; only BuyEmAll built in
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false } }

-- a merchant: 1 = Refreshing Spring Water (5 a lot, stacks of 20, 25 copper a lot),
-- 2 = Heavy Leather Ball (one, 1 copper, no stack), 3 = Mark of Honor bought with tokens
local ITEMS = {
  { name = "Refreshing Spring Water", price = 25, stackCount = 5, numAvailable = -1, link = "|Hitem:159:|h", maxStack = 20 },
  { name = "Heavy Leather Ball", price = 1, stackCount = 1, numAvailable = -1, link = "|Hitem:18662:|h", maxStack = 1 },
  { name = "Mark of Honor", price = 0, stackCount = 1, numAvailable = -1, link = "|Hitem:20558:|h", maxStack = 100,
    hasExtendedCost = true, costs = { { "token.blp", 2, "|Hitem:900:|h" } } },
}
C_MerchantFrame = { GetItemInfo = function(i)
  local it = ITEMS[i]
  return { name = it.name, price = it.price, stackCount = it.stackCount, numAvailable = it.numAvailable,
    hasExtendedCost = it.hasExtendedCost or false }
end }
function GetMerchantItemLink(i) return ITEMS[i].link end
function GetMerchantItemMaxStack(i) return ITEMS[i].maxStack end
function GetMerchantItemCostInfo(i) return ITEMS[i].costs and #ITEMS[i].costs or 0 end
function GetMerchantItemCostItem(i, n) return unpack(ITEMS[i].costs[n]) end
local money = 1000
function GetMoney() return money end
local bought = {}
function BuyMerchantItem(i, n) bought[#bought + 1] = i .. "x" .. tostring(n) end
-- bags: 4 slots in the backpack, one holding 15 water; the rest empty
local BAG = { [1] = { itemID = 159, stackCount = 15 } }
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
  GetContainerNumFreeSlots = function(bag) return 0, 0 end,
  GetContainerItemInfo = function(bag, slot) return bag == 0 and BAG[slot] or nil end,
}
C_Item = C_Item or {}
C_Item.GetItemFamily = function() return 0 end
C_Item.GetItemCount = function(id) return id == 900 and 7 or 0 end
-- the game's Shift + click, as WoW Forever's merchant code does it
local opened = 0
function MerchantItemButton_BuyMultipleStacks(button) opened = opened + 1 end
function MerchantItemButton_OnModifiedClick(button) MerchantItemButton_BuyMultipleStacks(button) end
local clickedOne
function MerchantItemButton_OnClick(button) clickedOne = button:GetID() end
MerchantFrame = CreateFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame.selectedTab = 1
local buttons = {}
for i = 1, 3 do
  buttons[i] = CreateFrame("Button", nil, MerchantFrame)
  buttons[i].GetID = function() return i end
end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
local frame = ClaraBuyEmAllFrame
local function text(fs) return fs and fs:GetText() and tostring(fs:GetText()) end
local regions = {}
for _, r in ipairs(M.regions) do if r._parent == frame and r._kind == "FontString" then regions[#regions + 1] = r end end
local amount, cost = regions[1], regions[2]
local function button(label)
  for _, f in ipairs(M.frames) do
    if f._parent == frame and f.GetText and f:GetText() == label then return f end
  end
end
local okay, stack, maxB = button("Okay"), button("Stack"), button("Max")

out("== Shift + click")
check(ns:QolRuns("buyemall") and frame, "the module runs; its window is made")
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
check(opened == 0 and frame:IsShown(), "its window instead of the game's")
check(text(amount) == "1", "starts at one: " .. tostring(text(amount)))
-- room: 3 free slots x 20 + 5 left on the 15 = 65; money: 1000 / 5 copper = 200
maxB:Click()
check(text(amount) == "65", "Max: as many as fit in the bags (65): " .. tostring(text(amount)))
check(text(cost) == "3s 25c", "the price of 65: " .. tostring(text(cost)))
M.Key(frame, "BACKSPACE")
check(text(amount) == "65", "Backspace only takes back typed digits")
M.Key(frame, "2", "2"); M.Key(frame, "5", "5")
check(text(amount) == "25", "typed: 25 (" .. tostring(text(amount)) .. ")")
check(frame._propagate == false, "the digits stay in the window (not the action bars)")
M.Key(frame, "W")
check(frame._propagate == true, "any other key goes on to the game (moving)")
-- (the bags' room past full stacks, 5, comes first: 5, 25, 45, 65)
stack:Click("LeftButton")
check(text(amount) == "45", "Stack: up to the next stack mark (45): " .. tostring(text(amount)))
stack:Click("RightButton"); stack:Click("RightButton")
check(text(amount) == "5", "right-click: a stack less each time (5): " .. tostring(text(amount)))

out("== buying")
M.Key(frame, "ENTER")
check(not frame:IsShown() and not M.popup, "a stack: no question")
for _ = 1, 3 do M.Frame(.6) end
check(table.concat(bought, " ") == "1x5", "bought: " .. table.concat(bought, " "))
bought = {}
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
maxB:Click()
okay:Click()
check(M.popup and M.popup.text == "Buy 65 × Refreshing Spring Water?", "past a stack: asks first (" .. tostring(M.popup and M.popup.text) .. ")")
M.PopupClick(1)
for _ = 1, 8 do M.Frame(.6) end
check(table.concat(bought, " ") == "1x20 1x20 1x20 1x5", "a stack at a time, half a second apart: " .. table.concat(bought, " "))

out("== the setting")
ns:SetQolEnabled("buyemall", true)
local sw = ns.qolSwitches.buyemall[1]
check(sw.label == "BEA_SW_CONFIRM" and sw.get() == true, "asks first by default")
sw.set(false)
check(ClaraComboPointsDB.buyemallConfirm == false, "turned off: kept")
bought = {}
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
maxB:Click(); okay:Click()
check(not M.popup and not frame:IsShown(), "then buys without asking")
for _ = 1, 8 do M.Frame(.6) end
check(#bought == 4, "all of it")
SlashCmdList.CLARABUYEMALL("confirm")
check(sw.get() == true and ClaraComboPointsDB.buyemallConfirm == nil, "/buyemall confirm: asks again")
local sub = M.subcategories and M.subcategories.BuyEmAll
check(sub and sub.parent == ns.qolThemes.economy and sub.settings[1].GetValue() == true, "its page under Economy and professions, in the game's options")
sub.settings[1]:SetValue(false)
check(sw.get() == false, "its box there sets the same")
sw.set(true)

out("== other purchases")
MerchantItemButton_OnModifiedClick(buttons[2], "LeftButton")
check(frame:IsShown() and text(amount) == "1", "one at a time item: the window")
maxB:Click()
check(text(amount) == "3", "Max: one per free slot (3; the water's slot is not free): " .. tostring(text(amount)))
frame:Hide()
MerchantItemButton_OnModifiedClick(buttons[3], "LeftButton")
-- 7 tokens, 2 each: 3
check(frame:IsShown(), "paid with tokens: the window")
maxB:Click()
check(text(amount) == "3", "Max: as many as the tokens pay for (3): " .. tostring(text(amount)))
check(text(cost) == "6 |Ttoken.blp:0|t", "the price in tokens: " .. tostring(text(cost)))
MerchantFrame:Hide()
check(not frame:IsShown(), "the merchant closed: the window too")
money = 7
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
check(not frame:IsShown() and clickedOne == 1, "only one affordable: bought as a plain click")

out("== in combat")
money = 1000
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
S.inCombat = true
local ok = pcall(M.Key, frame, "W")
check(ok, "a key in combat: no forbidden call (the game keeps the keyboard choice as it was)")
S.inCombat = false
frame:Hide()

out("")
out(fails .. " failure(s)")
