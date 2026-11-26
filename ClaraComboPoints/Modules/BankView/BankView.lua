-- Clara Combo Points - the bank seen from anywhere: the micro menu's Shop button (Clara's) opens a window drawn as WoW
-- Forever's own bank (its portrait frame, its tiled background, 8 columns of its bank slots, 88 to a page, its page tabs
-- on the right, the character's bank then the account bank, its bag slots under them, its search box), read-only: the
-- bank as it was last seen, slot by slot (Reverse Engineering's data, Modules/Crafting: read each time a bank is open,
-- shared between the player's own WoW accounts by the sync, never a friend's). A menu at its top picks the character:
-- every one of the player's characters seen at a bank. An item: its tooltip, Shift-click to link it. The search line
-- lights the items whose name holds it. "Seen ... ago" under it. A right click on the button: Clara's options (the
-- Escape menu's Clara button too). In every item's tooltip: how many each of the player's characters has, in its bags,
-- bank and mail, and the account bank. A box on Clara's page (on by default).

local ADDON, ns = ...
local L = ns.L
local C = ns.Craft
if not C then return end -- (Reverse Engineering's data off: no bank kept)

local issecret = issecretvalue or function() return false end
local function Call(obj, method, ...) if obj and obj[method] then return obj[method](obj, ...) end end
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local PER_PAGE = 88           -- slots on a page, as the game's bank
local COLUMNS = 8
local SLOT, GAP_X, GAP_Y = 37, 13, 10
local FIRST_X, FIRST_Y = 47, -63
local BASE_HEIGHT, ROW_HEIGHT, BASE_ROWS = 460, 47, 6
local WIDTH = 560
local BAG_SLOTS = 6           -- the bank's bag slots under the items (its tabs past the first)
local TIP_MAX = 8             -- characters listed in an item's tooltip, at most

function ns:BankView() return not (self.sv and self.sv.bankView == false) end
local Claim = function() end
function ns:SetBankView(on)
  if not self.sv then return end
  if on then self.sv.bankView = nil else self.sv.bankView = false end
  Claim()
end

---------------------------------------------------------------------------
-- The characters and their banks
---------------------------------------------------------------------------
local function Me() return C.me end

-- A character's name as the gold tracker knows it ("First Surname"), else from its key
local function NameOf(key)
  local G = ns.Money
  local rec = G and G.db and G.db.chars and G.db.chars[key]
  if rec and G.FullName then return G.FullName(rec) end
  return (key:match("^([^%-]+)")) or key
end

local function ClassHex(class)
  local color = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
    or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
  if not color then return "ffffffff" end
  if color.GenerateHexColor then return color:GenerateHexColor() end
  return ("ff%02x%02x%02x"):format(floor((color.r or 1) * 255), floor((color.g or 1) * 255), floor((color.b or 1) * 255))
end

-- The player's characters: this one first, then by name
local function Characters()
  local list = {}
  for key, c in pairs(C.db and C.db.chars or {}) do
    if type(c) == "table" then list[#list + 1] = key end -- (a bank never seen: listed all the same, said so)
  end
  table.sort(list, function(a, b)
    if (a == Me()) ~= (b == Me()) then return a == Me() end
    return NameOf(a) < NameOf(b)
  end)
  return list
end
ns.BankViewCharacters = Characters -- (for the tests)

local function Total(view)
  local n = 0
  for _, s in ipairs(view and view.t or {}) do n = n + s end
  return n
end

local function Pages(view) return max(1, ceil(Total(view) / PER_PAGE)) end

-- A slot's item: its item string, its count, its ID
local function Parse(entry)
  if type(entry) ~= "string" then return nil end
  local item, count = entry:match("^(item:[%-%d:]+);(%d+)$")
  item = item or entry
  local id = tonumber(item:match("^item:(%d+)"))
  return item, tonumber(count) or 1, id
end

local function Ago(at)
  if type(at) ~= "number" or at <= 0 then return nil end
  local s = max(0, time() - at)
  if s < 3600 then return L.BV_MINUTES:format(max(1, floor(s / 60))) end
  if s < 86400 then return L.BV_HOURS:format(floor(s / 3600)) end
  return L.BV_DAYS:format(floor(s / 86400))
end

---------------------------------------------------------------------------
-- The window, drawn as the game's bank
---------------------------------------------------------------------------
local frame, search, dropdown, seenText, bagText
local buttons, bagButtons, pageTabs = {}, {}, {}
local state = { who = nil, bank = "char", page = 1 }

local function CurrentView()
  if state.bank == "account" then return C.db.accountView end
  local c = C.db.chars[state.who or Me() or ""]
  return c and c.view
end

local function Matches(id, text)
  if text == "" then return true end
  local name = id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if type(name) ~= "string" or issecret(name) then return false end
  return ns:SearchKey(name):find(text, 1, true) ~= nil
end

local function SetSlot(b, entry, text)
  local item, count, id = Parse(entry)
  b.link = item
  local icon = id and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or nil
  if SetItemButtonTexture then SetItemButtonTexture(b, icon) elseif b.icon then b.icon:SetTexture(icon) end
  if SetItemButtonCount then SetItemButtonCount(b, item and count or 0) end
  local quality = id and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id) or nil
  if SetItemButtonQuality then pcall(SetItemButtonQuality, b, item and quality or nil, item) end
  local lit = not item or Matches(id, text)
  b.dim = not lit
  if b.SetMatchesSearch then pcall(b.SetMatchesSearch, b, lit) end
  if b.icon and b.icon.SetDesaturated then b.icon:SetDesaturated(not lit) end
  b:SetAlpha(lit and 1 or 0.35)
end

local Refresh

-- The page tabs on the right: this character's bank's pages, then the account bank's
local function PageTab(i)
  local tab = pageTabs[i]
  if tab then return tab end
  local ok, made = pcall(CreateFrame, "Frame", nil, frame, "LargeSideTabButtonTemplate")
  tab = ok and made or CreateFrame("Frame", nil, frame)
  if not ok then tab:SetSize(43, 55) end
  if not tab.Icon then
    tab.Icon = tab:CreateTexture(nil, "ARTWORK")
    tab.Icon:SetPoint("CENTER")
    tab.Icon:SetSize(28, 28)
  end
  tab:EnableMouse(true)
  tab:SetScript("OnMouseUp", function(self)
    state.bank, state.page = self.bank, self.page
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
    Refresh()
  end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.bank == "account" and L.BV_ACCOUNT or L.BV_CHAR_BANK, 1, 1, 1)
    if self.pages and self.pages > 1 then GameTooltip:AddLine(L.BV_PAGE:format(self.page, self.pages), 0.8, 0.8, 0.8) end
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  pageTabs[i] = tab
  return tab
end

local CHAR_ICONS = { "Interface/ICONS/INV_SideTab_Bank_c60", "Interface/ICONS/ACHIEVEMENT_GUILDPERK_MOBILEBANKING",
  "Interface/ICONS/TRADE_ARCHAEOLOGY_CHESTOFTINYGLASSANIMALS", "Interface/ICONS/Ability_Racial_PackHobgoblin" }
local ACCOUNT_ICON = "Interface/ICONS/UI_Warbands"

local function LayTabs()
  local n, last = 0, nil
  local function Add(bank, view)
    local pages = Pages(view)
    for page = 1, pages do
      n = n + 1
      local tab = PageTab(n)
      tab.bank, tab.page, tab.pages = bank, page, pages
      tab.Icon:SetTexture(bank == "account" and ACCOUNT_ICON or CHAR_ICONS[min(page, #CHAR_ICONS)])
      tab:ClearAllPoints()
      if last then tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2) else tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60) end
      local on = state.bank == bank and state.page == page
      if tab.SetChecked then pcall(tab.SetChecked, tab, on) end
      if tab.SelectedTexture then tab.SelectedTexture:SetShown(on) end
      tab:Show()
      last = tab
    end
  end
  local c = C.db.chars[state.who or Me() or ""]
  Add("char", c and c.view)
  if C.db.accountView then Add("account", C.db.accountView) end
  for i = n + 1, #pageTabs do pageTabs[i]:Hide() end
end

Refresh = function()
  if not (frame and frame:IsShown()) then return end
  local view = CurrentView()
  local total = Total(view)
  local pages = Pages(view)
  if state.page > pages then state.page = pages end
  local from = (state.page - 1) * PER_PAGE
  local shownSlots = max(0, min(PER_PAGE, total - from))
  local rows = ceil(shownSlots / COLUMNS)
  frame:SetHeight(BASE_HEIGHT + max(0, rows - BASE_ROWS) * ROW_HEIGHT)
  local text = search and ns:SearchKey(search:GetText() or "") or ""
  for i = 1, PER_PAGE do
    local b = buttons[i]
    if i <= shownSlots then
      SetSlot(b, view.s[from + i], text)
      b:Show()
    else
      b.link = nil
      b:Hide()
    end
  end
  -- (its bag slots: the bank's tabs past the first, their bags' icons)
  for i = 1, BAG_SLOTS do
    local b = bagButtons[i]
    local icon = view and view.b and view.b[i + 1]
    local has = view and view.t and view.t[i + 1] ~= nil
    if SetItemButtonTexture then SetItemButtonTexture(b, icon) elseif b.icon then b.icon:SetTexture(icon) end
    if b.Lock then b.Lock:SetShown(not has) end
    b:SetShown(state.bank == "char")
  end
  bagText:SetShown(state.bank == "char")
  local name = state.bank == "account" and L.BV_ACCOUNT or L.BV_TITLE:format(NameOf(state.who or Me() or "?"))
  if frame.SetTitle then frame:SetTitle(name) end
  local ago = Ago(view and view.at)
  if not view then
    seenText:SetText(L.BV_NEVER)
  elseif pages > 1 then
    seenText:SetText(L.BV_SEEN:format(ago or "?") .. "  ·  " .. L.BV_PAGE:format(state.page, pages))
  else
    seenText:SetText(L.BV_SEEN:format(ago or "?"))
  end
  if dropdown and dropdown.SetText then
    local who = state.who or Me()
    local c = C.db.chars[who or ""]
    dropdown:SetText(("|c%s%s|r"):format(ClassHex(c and c.class), NameOf(who or "?")))
  end
  LayTabs()
end
ns.BankViewRefresh = function() if Refresh then Refresh() end end

local function ItemButton(parent)
  local ok, b = pcall(CreateFrame, "ItemButton", nil, parent)
  if not ok or not b then
    -- (no ItemButton widget: a button with its icon of its own)
    b = CreateFrame("Button", nil, parent)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
  end
  b:SetSize(SLOT, SLOT)
  return b
end

local function Build()
  frame = CreateFrame("Frame", "ClaraBankFrame", UIParent, "PortraitFrameTemplate")
  frame:SetSize(WIDTH, BASE_HEIGHT)
  frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
  Call(frame, "SetToplevel", true)
  frame:SetFrameStrata("MEDIUM")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  Call(frame, "SetClampedToScreen", true)
  Call(frame, "RegisterForDrag", "LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "ClaraBankFrame") end
  if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, "Interface/ICONS/INV_SideTab_Bank_c60") end
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  Call(bg, "SetAtlas", "bank-frame-background")
  if bg.SetHorizTile then bg:SetHorizTile(true); bg:SetVertTile(true) end
  bg:SetPoint("TOPLEFT", 0, -20)
  bg:SetPoint("BOTTOMRIGHT", 0, 30)
  local divider = frame:CreateTexture(nil, "ARTWORK")
  Call(divider, "SetAtlas", "bank-divider", true)
  Call(divider, "SetScale", 0.48)
  divider:SetPoint("BOTTOM", 0, 220)

  for i = 1, PER_PAGE do
    local b = ItemButton(frame)
    local col, row = (i - 1) % COLUMNS, floor((i - 1) / COLUMNS)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", FIRST_X + col * (SLOT + GAP_X), FIRST_Y - row * (SLOT + GAP_Y))
    if b.SetNormalAtlas then b:SetNormalAtlas("bank-frame-item-slotframe") end
    local back = b:CreateTexture(nil, "BACKGROUND")
    Call(back, "SetAtlas", "bags-item-bankslot64")
    back:SetAllPoints()
    Call(b, "RegisterForClicks", "LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self)
      if not self.link then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
      if not self.link then return end
      local _, link = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(self.link)
      if HandleModifiedItemClick then HandleModifiedItemClick(link or self.link) end
    end)
    buttons[i] = b
  end

  bagText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  bagText:SetSize(120, 40)
  bagText:SetPoint("BOTTOMLEFT", 15, 67)
  bagText:SetJustifyH("RIGHT")
  bagText:SetText(BAGSLOTTEXT_COLON or L.BV_BAGS)
  for i = 1, BAG_SLOTS do
    local b = ItemButton(frame)
    Call(b, "SetScale", 0.75)
    if b.SetNormalAtlas then b:SetNormalAtlas("bank-frame-bag-slotframe") end
    local back = b:CreateTexture(nil, "BACKGROUND")
    Call(back, "SetAtlas", "bank-frame-bag-slot-bg")
    back:SetAllPoints()
    b.Lock = b:CreateTexture(nil, "OVERLAY")
    Call(b.Lock, "SetAtlas", "bankslot-icon-lock")
    b.Lock:SetAllPoints()
    b:SetPoint("LEFT", frame, "BOTTOMLEFT", 200 + (i - 1) * 50, 115)
    b:EnableMouse(false)
    bagButtons[i] = b
  end

  search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
  search:SetSize(110, 20)
  search:SetPoint("TOPRIGHT", -56, -33)
  Call(search, "SetAutoFocus", false)
  search:HookScript("OnTextChanged", function() Refresh() end)

  local okD, dd = pcall(CreateFrame, "DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
  if okD and dd then
    dropdown = dd
    dropdown:SetWidth(180)
    dropdown:SetPoint("TOPLEFT", 60, -31)
    dropdown:SetupMenu(function(_, root)
      for _, key in ipairs(Characters()) do
        local c = C.db.chars[key]
        local label = ("|c%s%s|r"):format(ClassHex(c and c.class), NameOf(key))
        if not (c and c.view) then label = label .. " |cff808080(" .. L.BV_NOT_SEEN .. ")|r" end
        root:CreateRadio(label, function() return (state.who or Me()) == key end, function()
          state.who, state.bank, state.page = key, "char", 1
          Refresh()
        end, key)
      end
    end)
  end

  seenText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  seenText:SetPoint("BOTTOM", 0, 12)
  frame:SetScript("OnShow", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
    Refresh()
  end)
  frame:SetScript("OnHide", function() if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end end)
  ns.BankViewFrame, ns.BankViewButtons, ns.BankViewSearch = frame, buttons, search -- (for the tests)
  ns.BankViewTabs, ns.BankViewBags = pageTabs, bagButtons
end

function ns.BankViewToggle(who)
  if not frame then Build() end
  if who then state.who, state.bank, state.page = who, "char", 1 end
  if frame:IsShown() and not who then frame:Hide() else frame:Show(); Refresh() end
end

-- (the bank just seen, the window open: shown again)
C.BankSeen = function() if frame and frame:IsShown() then Refresh() end end

---------------------------------------------------------------------------
-- The micro menu's Shop button (Clara's, ShopButton.lua): a click opens this window, a right click Clara's options
---------------------------------------------------------------------------
Claim = function()
  if ns:BankView() then
    ns.ShopMicroUse = {
      title = L.BV_BUTTON,
      click = function(mouse)
        if mouse == "RightButton" then
          if ns.ToggleOptions then ns:ToggleOptions() end
        else
          ns.BankViewToggle()
        end
      end,
      tip = function(tip) tip:AddLine(L.BV_BUTTON_TIP, 0.6, 0.6, 0.6, true) end,
    }
  else
    ns.ShopMicroUse = nil
    if frame then frame:Hide() end
  end
  if ns.ShopDress then ns.ShopDress() end
end

---------------------------------------------------------------------------
-- In an item's tooltip: how many each of the player's characters has, and the account bank
---------------------------------------------------------------------------
function ns.BankViewCounts(id)
  local rows, total = {}, 0
  for key, c in pairs(C.db and C.db.chars or {}) do
    if type(c) == "table" then
      local bags, bank, mail = (c.bags or {})[id] or 0, (c.bank or {})[id] or 0, (c.mail or {})[id] or 0
      if bags + bank + mail > 0 then
        local parts = {}
        if bank > 0 then parts[#parts + 1] = L.BV_TIP_BANK:format(bank) end
        if bags > 0 then parts[#parts + 1] = L.BV_TIP_BAGS:format(bags) end
        if mail > 0 then parts[#parts + 1] = L.BV_TIP_MAIL:format(mail) end
        rows[#rows + 1] = { key = key, name = NameOf(key), class = c.class, n = bags + bank + mail, text = table.concat(parts, ", ") }
        total = total + bags + bank + mail
      end
    end
  end
  table.sort(rows, function(a, b)
    if a.n ~= b.n then return a.n > b.n end
    return a.name < b.name
  end)
  local account = (C.db and C.db.account or {})[id] or 0
  return rows, total + account, account
end

local function AddCounts(tip, data)
  if not ns:BankView() or not (tip == GameTooltip or tip == ItemRefTooltip) then return end
  if type(data) ~= "table" or issecret(data.id) or type(data.id) ~= "number" then return end
  local rows, total, account = ns.BankViewCounts(data.id)
  if #rows == 0 and account == 0 then return end
  tip:AddLine(" ")
  for i, r in ipairs(rows) do
    if i > TIP_MAX then
      tip:AddLine(L.BV_TIP_MORE:format(#rows - TIP_MAX), 0.6, 0.6, 0.6)
      break
    end
    tip:AddDoubleLine(("|c%s%s|r"):format(ClassHex(r.class), r.name), r.text, 1, 1, 1, 0.8, 0.8, 0.8)
  end
  if account > 0 then tip:AddDoubleLine(L.BV_ACCOUNT, L.BV_TIP_BANK:format(account), 0.4, 0.78, 1, 0.8, 0.8, 0.8) end
  if #rows + (account > 0 and 1 or 0) > 1 then tip:AddDoubleLine(L.BV_TIP_TOTAL, tostring(total), 1, 0.82, 0, 1, 0.82, 0) end
end
ns.BankViewAddCounts = AddCounts -- (for the tests)
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data) pcall(AddCounts, tip, data) end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() Claim() end)
Claim()
