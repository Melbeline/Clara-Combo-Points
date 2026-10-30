-- Clara Combo Points - BuyEmAll Classic 1.0.4 (by Jordy141), built in (QoL.lua). At a merchant,
-- Shift + click on an item opens a small window to buy any amount of it: the arrows or the
-- keyboard, Stack (up to the next full stack; right-click: a stack less) and Max (as many as fit
-- in the bags and can be paid for). Buying more than a stack asks first (a box turns that off);
-- the purchase goes one stack at a time, half a second apart.
-- Rewritten for WoW Forever's merchant code (C_MerchantFrame, C_CurrencyInfo, the game's own
-- Shift + click); its window is made here, only when the module runs. The standalone's setting
-- (per character there) is carried over while it runs instead.

local ADDON, ns = ...
local L = ns.L

-- Ask before buying more than a stack? (saved with Clara's settings: only "no" is kept)
local function Confirm() return not (ns.sv and ns.sv.buyemallConfirm == false) end
local function SetConfirm(on)
  if not ns.sv then return end
  if on then ns.sv.buyemallConfirm = nil else ns.sv.buyemallConfirm = false end
end

-- The standalone runs instead: its setting is kept for the day it is turned off
if ns:QolState("buyemall") == "standalone" then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    local v = _G.BEAConfirmToggle
    if v == false or v == 0 then SetConfirm(false) elseif v ~= nil then SetConfirm(true) end
  end)
end

-- Its page in the game's options, under its theme's page of Clara Combo Points: the one setting
local subcategory
local function RegisterSettings()
  if subcategory or not (ns:QolCategory("buyemall") and Settings and Settings.RegisterVerticalLayoutSubcategory
    and Settings.RegisterProxySetting and Settings.CreateCheckbox) then return end
  local ok = pcall(function()
    local category = Settings.RegisterVerticalLayoutSubcategory(ns:QolCategory("buyemall"), "BuyEmAll")
    local setting = Settings.RegisterProxySetting(category, "ClaraBuyEmAllConfirm", Settings.VarType and Settings.VarType.Boolean or "boolean",
      L.BEA_SW_CONFIRM, true, Confirm, function(v) SetConfirm(v); ns:RefreshQol() end)
    Settings.CreateCheckbox(category, setting, L.BEA_SW_CONFIRM_TIP)
    subcategory = category
  end)
  if not ok then subcategory = nil end
end

if not ns:QolRuns("buyemall") then return end

ns:SetQolSwitches("buyemall", {
  { label = "BEA_SW_CONFIRM", get = Confirm, set = SetConfirm },
})
ns:SetQolOpener("buyemall", function() ns:OpenSettingsTo(subcategory) end)

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local B = {} -- the purchase being set up

---------------------------------------------------------------------------
-- What the merchant and the bags say
---------------------------------------------------------------------------
local function ItemInfo(index)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(index)
    if info then return info.name, info.price or 0, info.stackCount or 1, info.numAvailable or -1, info.hasExtendedCost end
    return
  end
  local name, _, price, quantity, numAvailable, _, _, extendedCost = GetMerchantItemInfo(index)
  return name, price or 0, quantity or 1, numAvailable or -1, extendedCost
end

-- quantity held and most that can be held of a currency (from its link)
local function Currency(link)
  local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfoFromLink and C_CurrencyInfo.GetCurrencyInfoFromLink(link)
  if info then return info.quantity or 0, info.maxQuantity or 0 end
  return 0, 0
end

local GetItemFamily = C_Item and C_Item.GetItemFamily or GetItemFamily
local GetItemCount = C_Item and C_Item.GetItemCount or GetItemCount

-- How many of the item fit in the bags: free slots (in a bag that takes it) and the room left
-- on its stacks already there.
local function Fit(itemID, maxStack)
  local family = GetItemFamily and GetItemFamily(itemID) or 0
  local room = 0
  for bag = 0, NUM_BAG_SLOTS or 4 do
    local _, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
    local takes = not bagFamily or bagFamily == 0 or (family and bit.band(family, bagFamily) ~= 0)
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if not info then
        if takes then room = room + maxStack end
      elseif info.itemID == itemID then
        room = room + max(0, maxStack - (info.stackCount or 0))
      end
    end
  end
  return room
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "ClaraBuyEmAllFrame", UIParent)
frame:SetSize(230, 134)
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:EnableKeyboard(true)
frame:Hide()

local box = frame:CreateTexture(nil, "BORDER")
box:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame")
box:SetTexCoord(.10546875, .578125, .109375, .3671875)
box:SetSize(121, 33)
box:SetPoint("TOP", 1, -16)
local amount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
amount:SetJustifyH("RIGHT")
amount:SetPoint("RIGHT", box, "RIGHT", -12, 2)
local cost = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
cost:SetPoint("TOP", 0, -52)

local function Arrow(side, x)
  local b = CreateFrame("Button", nil, frame)
  b:SetSize(16, 16)
  b:SetPoint(side == "Left" and "TOPRIGHT" or "TOPLEFT", box, "TOP", x, -8)
  b:SetNormalTexture("Interface\\MoneyFrame\\Arrow-" .. side .. "-Up")
  b:SetPushedTexture("Interface\\MoneyFrame\\Arrow-" .. side .. "-Down")
  b:SetDisabledTexture("Interface\\MoneyFrame\\Arrow-" .. side .. "-Disabled")
  return b
end
local left, right = Arrow("Left", -60), Arrow("Right", 63)

local function Button(label, point, x, y, relative)
  local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  b:SetSize(78, 22)
  b:SetText(label)
  b:SetPoint(point, relative or frame, relative and "TOP" or "BOTTOM", x, y)
  return b
end
local okay = Button(OKAY or "Okay", "RIGHT", -3, 24)
local cancel = Button(CANCEL or "Cancel", "LEFT", 5, 24)
local stack = Button(L.BEA_STACK, "BOTTOM", 0, 2, okay)
local maxButton = Button(L.BEA_MAX, "BOTTOM", 0, 2, cancel)
stack:RegisterForClicks("LeftButtonUp", "RightButtonUp")
-- a dialog box: the game's, or Classic's (Look.lua)
ns:DressDialog(frame, { fill = true, buttons = { okay, cancel, stack, maxButton } })

---------------------------------------------------------------------------
-- The amount
---------------------------------------------------------------------------
-- The amount the Stack button sets: up to the next full stack (the first: what is left of the
-- bags' room after full stacks)
local function StackClick()
  local increase = (B.partialFit == 0 and B.stack or B.partialFit) - (B.split % B.stack)
  return B.split + (increase == 0 and B.stack or increase)
end

-- An amount bought with another currency: a whole number of the merchant's lots
local function Lots(n)
  if not B.alt then return n end
  local rest = n % B.preset
  if rest < B.preset / 2 then return n - rest end
  return n + B.preset - rest
end

local function Update()
  B.stackClick = StackClick()
  left:SetEnabled(B.split > (B.alt and B.preset or 1))
  right:SetEnabled(B.split < B.max)
  maxButton:SetEnabled(B.split < B.max)
  stack:SetEnabled(B.max >= B.stackClick)
  amount:SetText(B.split)
  if not B.alt then
    local copper = ceil(B.split * B.price / max(1, B.preset))
    cost:SetText(GetMoneyString and GetMoneyString(copper, true) or tostring(copper))
  else
    local lots, parts = Lots(B.split) / B.preset, {}
    for i, price in ipairs(B.altPrice) do
      parts[#parts + 1] = ("%d |T%s:0|t"):format(lots * price, tostring(B.altTexture[i] or ""))
    end
    cost:SetText(table.concat(parts, "  "))
  end
end

local function SetSplit(n)
  B.split = max(B.alt and B.preset or 1, min(n, B.max))
  Update()
end

---------------------------------------------------------------------------
-- Buying: one stack each half second, until done or the merchant closes
---------------------------------------------------------------------------
local loop = CreateFrame("Frame")
loop:Hide()
local queue = {}
loop:SetScript("OnUpdate", function(self, elapsed)
  self.wait = (self.wait or 0) - elapsed
  if self.wait > 0 then return end
  self.wait = .5
  local n = table.remove(queue, 1)
  if not n then self:Hide() return end
  BuyMerchantItem(queue.index, n)
end)
loop:RegisterEvent("MERCHANT_CLOSED")
loop:SetScript("OnEvent", function(self) wipe(queue); self:Hide() end)

local function Purchase(n)
  frame:Hide()
  wipe(queue)
  queue.index = B.index
  local per = max(1, B.stack)
  while n > 0 do
    queue[#queue + 1] = min(n, per)
    n = n - per
  end
  loop.wait = 0
  loop:Show()
end

StaticPopupDialogs.CLARA_BUYEMALL_CONFIRM = {
  text = L.BEA_CONFIRM,
  button1 = YES, button2 = NO,
  OnAccept = function(_, data) if data then Purchase(data) end end,
  timeout = 0, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs.CLARA_BUYEMALL_CONFIRM_ONE = {
  text = L.BEA_CONFIRM,
  button1 = YES, button2 = NO,
  OnAccept = function(_, data) if data then BuyMerchantItem(data) end end,
  timeout = 0, hideOnEscape = true, preferredIndex = 3,
}

local function Verify(n)
  n = Lots(n or B.split)
  if n <= 0 then return end
  if n > B.stack and n > B.preset and Confirm() then
    StaticPopup_Show("CLARA_BUYEMALL_CONFIRM", n, B.name, n)
  else
    Purchase(n)
  end
end

---------------------------------------------------------------------------
-- The buttons and the keyboard
---------------------------------------------------------------------------
local LINES = {
  stack = { label = "BEA_STACK_PURCH", field = "stackClick",
    { label = "BEA_STACK_SIZE", field = "stack" }, { label = "BEA_PARTIAL", field = "partialFit" } },
  max = { label = "BEA_MAX_PURCH", field = "max",
    { label = "BEA_AFFORD", field = "afford" }, { label = "BEA_FIT", field = "fit" },
    { label = "BEA_AVAILABLE", field = "available", hide = function() return B.available <= 1 end } },
}
local function Tooltip(button)
  local lines = LINES[button == maxButton and "max" or "stack"]
  local total = B[lines.field] or 0
  GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
  GameTooltip:SetText(L[lines.label] .. "|cffffffff - |r" .. GREEN_FONT_COLOR_CODE .. total .. "|r")
  for _, line in ipairs(lines) do
    if not (line.hide and line.hide()) then
      local value = B[line.field] or 0
      local color = value == total and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
      GameTooltip:AddDoubleLine(L[line.label], value, 1, 1, 1, color.r, color.g, color.b)
    end
  end
  GameTooltip:Show()
end
for _, b in ipairs({ stack, maxButton }) do
  b:SetScript("OnEnter", Tooltip)
  b:SetScript("OnLeave", GameTooltip_Hide)
end

left:SetScript("OnClick", function() B.typing = false; SetSplit(B.split - (B.alt and B.preset or 1)) end)
right:SetScript("OnClick", function() B.typing = false; SetSplit(B.split + (B.alt and B.preset or 1)) end)
okay:SetScript("OnClick", function() Verify() end)
cancel:SetScript("OnClick", function() frame:Hide() end)
maxButton:SetScript("OnClick", function(self) B.typing = false; SetSplit(B.max); Tooltip(self) end)
stack:SetScript("OnClick", function(self, button)
  B.typing = false
  if button == "RightButton" then
    SetSplit(B.split <= B.stack and 1 or B.split - B.stack)
  else
    SetSplit(B.stackClick)
  end
  if self:IsEnabled() then Tooltip(self) else GameTooltip:Hide() end
end)

-- typed digits make the amount (up to the most that can be bought)
frame:SetScript("OnChar", function(_, text)
  if text < "0" or text > "9" then return end
  if not B.typing then B.typing = true; B.split = 0 end
  local typed = B.split * 10 + tonumber(text)
  B.split = typed == 0 and 1 or min(typed, B.max) -- (a first 0: one)
  Update()
end)

-- the keys the window uses; any other goes on to the game (out of combat: the game only lets an
-- addon choose that then)
local function Key(key)
  if key:find("^NUMPAD%d$") or key:find("^%d$") then return true end
  if key == "BACKSPACE" or key == "DELETE" then
    if B.typing and B.split > 1 then
      B.split = floor(B.split / 10)
      if B.split <= 1 then B.split, B.typing = 1, false end
      SetSplit(B.split)
    end
    return true
  elseif key == "ENTER" or key == "NUMPADENTER" then
    Verify()
    return true
  elseif key == "ESCAPE" then
    frame:Hide()
    return true
  elseif key == "LEFT" or key == "DOWN" then
    left:Click()
    return true
  elseif key == "RIGHT" or key == "UP" then
    right:Click()
    return true
  end
  return false
end
frame:SetScript("OnKeyDown", function(self, key)
  local used = Key(key)
  if not InCombatLockdown() and self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not used) end
end)
frame:SetScript("OnShow", function(self)
  if not InCombatLockdown() and self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
end)
frame:SetScript("OnHide", function()
  StaticPopup_Hide("CLARA_BUYEMALL_CONFIRM")
  GameTooltip_Hide()
end)

---------------------------------------------------------------------------
-- Shift + click on a merchant's item
---------------------------------------------------------------------------
local function Open(button)
  local index = button:GetID()
  local name, price, preset, available, extended = ItemInfo(index)
  if not name then return false end
  local link = GetMerchantItemLink(index)
  wipe(B)
  B.index, B.name, B.price, B.preset, B.available = index, name, price, max(1, preset), available
  B.typing, B.alt = false, false
  if not link then -- (something bought without a link: one, after asking)
    StaticPopup_Show("CLARA_BUYEMALL_CONFIRM_ONE", preset, name, index)
    return true
  end
  local maxStack = GetMerchantItemMaxStack(index) or 1
  if link:find("currency:", 1, true) then
    local have, most = Currency(link)
    B.stack = B.preset
    B.fit = most > 0 and max(0, most - have) or 10000000
  else
    local itemID = tonumber(link:match("item:(%d+)"))
    B.stack = max(1, maxStack)
    B.fit = itemID and Fit(itemID, B.stack) or 0
  end
  B.partialFit = B.fit % B.stack

  if extended and price == 0 then
    -- paid with items or currencies: as many as each of them allows
    B.alt = true
    B.altPrice, B.altTexture = {}, {}
    local afford
    for i = 1, GetMerchantItemCostInfo(index) or 0 do
      local texture, value, costLink = GetMerchantItemCostItem(index, i)
      if value and value > 0 and costLink then
        local have = costLink:find("currency:", 1, true) and (Currency(costLink))
          or GetItemCount(tonumber(costLink:match("item:(%d+)")) or costLink, true)
        B.altPrice[#B.altPrice + 1], B.altTexture[#B.altTexture + 1] = value, texture
        local can = floor((have or 0) / value) * B.preset
        afford = afford and min(afford, can) or can
      end
    end
    B.afford = afford or 0
  else
    B.afford = price == 0 and B.fit or floor(GetMoney() / ceil(price / B.preset))
  end
  B.max = min(B.fit, B.afford)
  if available > -1 then B.max = min(B.max, available * (B.alt and B.preset or 1)) end
  if B.max <= 0 then return true end
  if B.max == 1 then MerchantItemButton_OnClick(button, "LeftButton") return true end
  B.split = B.alt and B.preset or 1
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 0)
  frame:Show()
  Update()
  return true
end

-- WoW Forever: the game's Shift + click opens its own window here; this one opens instead
if type(MerchantItemButton_BuyMultipleStacks) == "function" then
  local own = MerchantItemButton_BuyMultipleStacks
  MerchantItemButton_BuyMultipleStacks = function(button)
    if not Open(button) then return own(button) end
  end
elseif type(MerchantItemButton_OnModifiedClick) == "function" then
  local own = MerchantItemButton_OnModifiedClick
  MerchantItemButton_OnModifiedClick = function(button, ...)
    if MerchantFrame.selectedTab == 1 and IsModifiedClick("SPLITSTACK") and not IsControlKeyDown()
      and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) and Open(button) then return end
    return own(button, ...)
  end
end
if MerchantFrame then MerchantFrame:HookScript("OnHide", function() frame:Hide() end) end

-- /buyemall confirm: ask before buying more than a stack, or not (as the standalone's command)
SLASH_CLARABUYEMALL1 = "/buyemall"
SlashCmdList.CLARABUYEMALL = function(msg)
  if (msg or ""):match("^%s*(.-)%s*$"):lower() == "confirm" then
    SetConfirm(not Confirm())
    ns:RefreshQol()
    print("BuyEmAll: " .. (Confirm() and L.BEA_CONFIRM_ON or L.BEA_CONFIRM_OFF))
  else
    ns:OpenQol("buyemall")
  end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  RegisterSettings()
end)
