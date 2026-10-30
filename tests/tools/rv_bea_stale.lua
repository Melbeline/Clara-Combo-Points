-- BuyEmAll built in: Shift + click on a merchant's item, any amount, a stack at a time
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- WoW Forever; only BuyEmAll built in
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { leatrix = false, nodesight = false, wst = false } }

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

out("== A: window open on water, then Shift + click on water with only 7 copper (max 1)")
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
check(frame:IsShown(), "window open on water")
money = 7
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
out("  window still shown: " .. tostring(frame:IsShown()) .. "  B.split nil?")
local ok, err = pcall(M.Key, frame, "ENTER")
check(ok, "Enter on the stale window: " .. tostring(err))
local ok2, err2 = pcall(function() okay:Click() end)
check(ok2, "Okay on the stale window: " .. tostring(err2))
frame:Hide()

out("== B: question pending for water, then Shift + click on the ball")
money = 1000; bought = {}
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
maxB:Click(); okay:Click()
out("  popup: " .. tostring(M.popup and M.popup.text))
MerchantItemButton_OnModifiedClick(buttons[2], "LeftButton")
out("  popup still: " .. tostring(M.popup and M.popup.text))
M.PopupClick(1)
for _ = 1, 80 do M.Frame(.6) end
check(not bought[1] or bought[1]:match("^1x"), "the water bought (not the ball): " .. table.concat(bought, " "))

out("== C: question pending for water, then Shift + click on an unaffordable ball (max 0)")
frame:Hide(); bought = {}
MerchantItemButton_OnModifiedClick(buttons[1], "LeftButton")
maxB:Click(); okay:Click()
out("  popup: " .. tostring(M.popup and M.popup.text))
money = 0
local ok3, err3 = pcall(MerchantItemButton_OnModifiedClick, buttons[2], "LeftButton")
out("  open ball: " .. tostring(ok3) .. " " .. tostring(err3) .. " shown " .. tostring(frame:IsShown()))
local ok4, err4 = pcall(function() maxB:Click() end)
local ok5, err5 = pcall(function() frame:GetScript("OnKeyDown")(frame, "RIGHT") end)
check(ok5, "Right arrow on the stale window: " .. tostring(err5))
out(fails .. " failure(s)")
