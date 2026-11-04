-- Clara Combo Points - a sniper for the auction house: a tab beside Auctionator's (Buy, Sell, Cancel...), in its
-- tab strip at the bottom of the auction house. Started, it looks over the whole auction house again and again
-- (the game's own browse, every item's lowest price, page after page; a pause between two passes) and lists at
-- once the items whose lowest price is a given share under their usual price, the best first. Their usual price:
-- the median (or the mean) of their days' lowest prices over 24 hours, 3, 7, 15 or 30 days, 3, 6 or 12 months, or
-- all time (History.lua), switched with one click; the share with a slider (0 to 100 %) or typed in its box. A row
-- clicked opens the item in the game's own buy view (each purchase: one click, as the game wants). Needs
-- Auctionator (its tab strip; its records feed the prices): none of its code is here, its tab strip is given a
-- tab through what it offers other addons (Auctionator.Tabs.Register).
local ADDON, ns = ...
local L = ns.L

local DEFAULTS = { window = 7, mode = "median", pct = 40, sound = true }
local PAUSE = 10        -- seconds between two passes
local ROWS, ROW_H = 13, 22
local WINDOW_KEYS = { [1] = "SNIPER_W_1", [3] = "SNIPER_W_3", [7] = "SNIPER_W_7", [15] = "SNIPER_W_15",
  [30] = "SNIPER_W_30", [91] = "SNIPER_W_91", [182] = "SNIPER_W_182", [365] = "SNIPER_W_365", [0] = "SNIPER_W_0" }

local function Get(key)
  local saved = ns.sv and ns.sv.sniper
  local v = saved and saved[key]
  if v == nil then return DEFAULTS[key] end
  return v
end
local function Set(key, v)
  if not ns.sv then return end
  local saved = ns.sv.sniper or {}
  if v == DEFAULTS[key] then saved[key] = nil else saved[key] = v end
  ns.sv.sniper = next(saved) and saved or nil
end
ns.SniperGet, ns.SniperSet = Get, Set

if not ns:QolRuns("sniper") then return end
local H = ns.PriceHistory

local Sn = { deals = {}, seen = {}, passes = 0, running = false }
ns.Sniper = Sn

---------------------------------------------------------------------------
-- The auction house, through Auctionator's own calls when it has them (they wait for the game's throttle)
---------------------------------------------------------------------------
local function AH() local a = _G.Auctionator; return a and a.AH end
local QUERY = { searchString = "", sorts = {}, filters = {}, itemClassFilters = {} }
local function SendBrowse()
  local ah = AH()
  if ah and ah.SendBrowseQuery then ah.SendBrowseQuery(QUERY) else C_AuctionHouse.SendBrowseQuery(QUERY) end
end
local function More()
  local ah = AH()
  if ah and ah.RequestMoreBrowseResults then ah.RequestMoreBrowseResults() else C_AuctionHouse.RequestMoreBrowseResults() end
end
local function Full()
  local ah = AH()
  if ah and ah.HasFullBrowseResults then return ah.HasFullBrowseResults() end
  return C_AuctionHouse.HasFullBrowseResults()
end

-- An item's Auctionator keys (the gear ones by item level first), as it reads its own records
local function Keys(result)
  local a = _G.Auctionator
  if a and a.Utilities and a.Utilities.DBKeyFromBrowseResult then
    local ok, keys = pcall(a.Utilities.DBKeyFromBrowseResult, result)
    if ok and type(keys) == "table" then return keys end
  end
  local k = result.itemKey or {}
  if (k.battlePetSpeciesID or 0) ~= 0 then return { "p:" .. k.battlePetSpeciesID } end
  return { tostring(k.itemID) }
end
local function Id(result)
  local k = result.itemKey or {}
  return (k.itemID or 0) .. ":" .. (k.itemLevel or 0) .. ":" .. (k.itemSuffix or 0) .. ":" .. (k.battlePetSpeciesID or 0)
end

-- How many prices a usual price needs to be trusted: two in the last 24 hours, else three days
local function Needed(window) return window == 1 and 2 or 3 end
Sn.Needed = Needed

-- A result's deal: how far under its usual price (%), that price, how many prices it rests on
function Sn.Judge(result)
  local realm = H.Realm()
  if not (realm and result and result.minPrice and result.minPrice > 0) then return nil end
  local window, mode = Get("window"), Get("mode")
  for _, key in ipairs(Keys(result)) do
    local ref, n = H.Reference(realm .. "/" .. key, window, mode)
    if ref and ref > 0 and n >= Needed(window) then
      return (ref - result.minPrice) / ref * 100, ref, n
    end
  end
  return nil
end

local function Sound()
  if Get("sound") and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN or SOUNDKIT.MAP_PING or 0) end
end

-- One result looked at: a deal kept (or dropped when it is no more one); a new deal heard
local function Look(result, quiet)
  if not result or (result.totalQuantity or 0) <= 0 then return false end
  local id = Id(result)
  Sn.seen[id] = result
  local off, ref, n = Sn.Judge(result)
  if off and off >= Get("pct") then
    local old = Sn.deals[id]
    local new = not old or old.price ~= result.minPrice
    Sn.deals[id] = { result = result, price = result.minPrice, ref = ref, off = off, n = n,
      qty = result.totalQuantity, at = old and not new and old.at or time() }
    return new and not quiet
  end
  Sn.deals[id] = nil
  return false
end

-- Every item seen again, as the window, the median/mean or the share changed (no search: at once)
function Sn.Rejudge()
  for id, result in pairs(Sn.seen) do Look(result, true) end
  if Sn.Refresh then Sn.Refresh() end
end

function Sn.Sorted()
  local list = {}
  for _, d in pairs(Sn.deals) do list[#list + 1] = d end
  table.sort(list, function(a, b)
    if math.abs(a.off - b.off) > 0.001 then return a.off > b.off end
    return a.price < b.price
  end)
  return list
end

---------------------------------------------------------------------------
-- The passes
---------------------------------------------------------------------------
local function Take(results)
  local heard = false
  for _, r in ipairs(results or {}) do if Look(r) then heard = true end end
  if heard then Sound() end
  if Sn.Refresh then Sn.Refresh() end
end

local function Visible() return Sn.frame ~= nil and Sn.frame:IsVisible() end

local function Pass()
  if not (Sn.running and Visible()) or Sn.waiting then return end
  Sn.waiting = true
  Sn.pageCount = 0
  SendBrowse()
  if Sn.Refresh then Sn.Refresh() end
end
Sn.Pass = Pass

local function Step()
  if not Full() then
    Sn.pageCount = (Sn.pageCount or 0) + 1
    More()
    return
  end
  Sn.waiting = false
  Sn.passes = Sn.passes + 1
  Sn.lastPass = time()
  if Sn.Refresh then Sn.Refresh() end
  if Sn.running then C_Timer.After(PAUSE, Pass) end
end

function Sn.Start()
  Sn.running = true
  Pass()
  if Sn.Refresh then Sn.Refresh() end
end
function Sn.Stop()
  Sn.running = false
  if Sn.Refresh then Sn.Refresh() end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "AUCTION_HOUSE_CLOSED" }) do
  events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event, added)
  if event == "AUCTION_HOUSE_CLOSED" then
    Sn.running, Sn.waiting = false, false
    return
  end
  if not Sn.waiting then return end -- (another search: not ours)
  if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
    Take(C_AuctionHouse.GetBrowseResults())
  else
    Take(added)
  end
  Step()
end)

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------
local function Money(c)
  if GetMoneyString then return GetMoneyString(c, true) end
  return tostring(c)
end

local function ItemText(result)
  local k = result.itemKey or {}
  local name, quality, icon
  if C_AuctionHouse.GetItemKeyInfo then
    local info = C_AuctionHouse.GetItemKeyInfo(k)
    if type(info) == "table" then name, quality, icon = info.itemName, info.quality, info.iconFileID end
  end
  if not name and C_Item and C_Item.GetItemInfo then
    local n, _, q, _, _, _, _, _, _, tex = C_Item.GetItemInfo(k.itemID)
    name, quality, icon = n, q, tex
  end
  name = name or ("item:" .. tostring(k.itemID))
  local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if color and color.hex then name = color.hex .. name .. "|r" end
  return name, icon
end

local COLUMNS = { -- key, x, width, justify
  { "name", 30, 300, "LEFT" }, { "price", 336, 120, "RIGHT" }, { "ref", 462, 120, "RIGHT" },
  { "off", 588, 64, "RIGHT" }, { "qty", 658, 46, "RIGHT" }, { "n", 710, 54, "RIGHT" },
}

local function Build(f)
  Sn.frame = f
  f.offset = 0

  -- Start / Stop, and where it stands
  local go = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  go:SetSize(150, 24)
  go:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
  go:SetScript("OnClick", function() if Sn.running then Sn.Stop() else Sn.Start() end end)
  f.Go = go
  local status = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  status:SetPoint("LEFT", go, "RIGHT", 10, 0)
  status:SetJustifyH("LEFT")
  f.Status = status

  -- the window: nine buttons, one click
  local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", go, "BOTTOMLEFT", 0, -12)
  label:SetText(L.SNIPER_WINDOW)
  f.windows = {}
  local prev
  for _, w in ipairs(H.WINDOWS) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(48, 20)
    b:SetText(L[WINDOW_KEYS[w]])
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("LEFT", label, "RIGHT", 8, 0) end
    b:SetScript("OnClick", function()
      Set("window", w)
      Sn.Rejudge()
    end)
    b.window = w
    f.windows[#f.windows + 1] = b
    prev = b
  end
  -- median or mean, one click
  local mode = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  mode:SetSize(90, 20)
  mode:SetPoint("LEFT", prev, "RIGHT", 10, 0)
  mode:SetScript("OnClick", function()
    Set("mode", Get("mode") == "mean" and "median" or "mean")
    Sn.Rejudge()
  end)
  mode:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.SNIPER_MODE_TIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  mode:SetScript("OnLeave", GameTooltip_Hide)
  f.Mode = mode

  -- the share: a slider and its box
  local share = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  share:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -18)
  share:SetText(L.SNIPER_SHARE)
  local slider = CreateFrame("Slider", nil, f, "UISliderTemplate")
  slider:SetSize(220, 17)
  slider:SetPoint("LEFT", share, "RIGHT", 10, 0)
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(0, 100)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  box:SetSize(36, 20)
  box:SetPoint("LEFT", slider, "RIGHT", 12, 0)
  box:SetAutoFocus(false)
  box:SetNumeric(true)
  box:SetMaxLetters(3)
  box:SetJustifyH("CENTER")
  local unit = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  unit:SetPoint("LEFT", box, "RIGHT", 4, 0)
  unit:SetText(L.SNIPER_SHARE_UNIT)
  local function Apply(v, from)
    v = math.max(0, math.min(100, math.floor((tonumber(v) or Get("pct")) + 0.5)))
    if Get("pct") ~= v then Set("pct", v) end
    if from ~= "slider" then slider.silent = true; slider:SetValue(v); slider.silent = nil end
    if from ~= "box" or not box:HasFocus() then box:SetText(tostring(v)) end
    Sn.Rejudge()
  end
  slider:SetScript("OnValueChanged", function(self, v) if not self.silent then Apply(v, "slider") end end)
  box:SetScript("OnEnterPressed", function(self) Apply(self:GetText(), "box"); self:ClearFocus() end)
  box:SetScript("OnEditFocusLost", function(self) Apply(self:GetText(), "box") end)
  box:SetScript("OnEscapePressed", function(self) self:SetText(tostring(Get("pct"))); self:ClearFocus() end)
  f.Slider, f.Box = slider, box
  f.Apply = Apply

  local sound = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  sound:SetSize(22, 22)
  sound:SetPoint("LEFT", unit, "RIGHT", 18, 0)
  local soundText = sound.Text or sound.text
  if soundText then soundText:SetText(L.SNIPER_SOUND); soundText:SetFontObject("GameFontHighlightSmall") end
  sound:SetScript("OnClick", function(self) Set("sound", self:GetChecked() and true or false) end)
  f.Sound = sound

  -- the deals
  local top = -128
  local head = {}
  for _, c in ipairs(COLUMNS) do
    local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", f, "TOPLEFT", c[2], top)
    t:SetWidth(c[3])
    t:SetJustifyH(c[4])
    t:SetText(L["SNIPER_COL_" .. c[1]:upper()])
    head[#head + 1] = t
  end
  f.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, f)
    row:SetSize(760, ROW_H)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 6, top - 16 - (i - 1) * ROW_H)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.cells = {}
    for _, c in ipairs(COLUMNS) do
      local t = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      t:SetPoint("LEFT", row, "LEFT", c[2] - 6, 0)
      t:SetWidth(c[3])
      t:SetJustifyH(c[4])
      t:SetWordWrap(false)
      row.cells[c[1]] = t
    end
    row:SetScript("OnClick", function(self)
      if self.deal and AuctionHouseFrame and AuctionHouseFrame.SelectBrowseResult then
        AuctionHouseFrame:SelectBrowseResult(self.deal.result) -- (the game's buy view: one click per purchase)
      end
    end)
    row:SetScript("OnEnter", function(self)
      if not self.deal then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local k = self.deal.result.itemKey or {}
      if GameTooltip.SetItemKey then GameTooltip:SetItemKey(k.itemID, k.itemLevel or 0, k.itemSuffix or 0)
      elseif k.itemID then GameTooltip:SetItemByID(k.itemID) end
      GameTooltip:AddLine(L.SNIPER_ROW_TIP, 0.6, 0.8, 1, true)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:Hide()
    f.rows[i] = row
  end
  f.empty = f:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  f.empty:SetPoint("TOP", f, "TOP", 0, top - 60)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(self, delta)
    local count = #Sn.Sorted()
    self.offset = math.max(0, math.min(math.max(0, count - ROWS), self.offset - delta * 3))
    Sn.Refresh()
  end)
  f:HookScript("OnShow", function() Sn.Refresh(); if Sn.running and not Sn.waiting then Pass() end end)

  for _, b in ipairs({ go, mode, unpack(f.windows) }) do ns:DressButton(b) end
  ns:DressCheck(sound)
  if Sn.Refresh then Sn.Refresh() end
end

function Sn.Refresh()
  local f = Sn.frame
  if not f then return end
  f.Go:SetText(Sn.running and L.SNIPER_STOP or L.SNIPER_START)
  local count = 0
  for _ in pairs(Sn.deals) do count = count + 1 end
  local seen = 0
  for _ in pairs(Sn.seen) do seen = seen + 1 end
  local state = Sn.running and (Sn.waiting and L.SNIPER_SCANNING or L.SNIPER_WAITING) or L.SNIPER_STOPPED
  f.Status:SetText(L.SNIPER_STATUS:format(state, seen, count, Sn.passes))
  local window = Get("window")
  for _, b in ipairs(f.windows) do
    if b.window == window then b:LockHighlight() else b:UnlockHighlight() end
    if b.SetButtonState then b:SetButtonState(b.window == window and "PUSHED" or "NORMAL", b.window == window) end
  end
  f.Mode:SetText(Get("mode") == "mean" and L.SNIPER_MEAN or L.SNIPER_MEDIAN)
  local pct = Get("pct")
  if f.Slider:GetValue() ~= pct then f.Slider.silent = true; f.Slider:SetValue(pct); f.Slider.silent = nil end
  if not f.Box:HasFocus() then f.Box:SetText(tostring(pct)) end
  f.Sound:SetChecked(Get("sound") and true or false)
  local list = Sn.Sorted()
  f.offset = math.max(0, math.min(f.offset, math.max(0, #list - ROWS)))
  for i, row in ipairs(f.rows) do
    local d = list[f.offset + i]
    row.deal = d
    if d then
      local name, icon = ItemText(d.result)
      row.icon:SetTexture(icon or 134400)
      row.cells.name:SetText(name)
      row.cells.price:SetText(Money(d.price))
      row.cells.ref:SetText(Money(d.ref))
      row.cells.off:SetText(("|cff40ff40-%d %%|r"):format(math.floor(d.off + 0.5)))
      row.cells.qty:SetText(tostring(d.qty or ""))
      row.cells.n:SetText(L.SNIPER_DAYS:format(d.n))
      row:Show()
    else
      row:Hide()
    end
  end
  f.empty:SetText(#list == 0 and (Sn.running and L.SNIPER_NONE_YET or L.SNIPER_HINT) or "")
end

-- (the XML template's OnLoad, Sniper.xml)
function ClaraSniper_OnLoad(self) Build(self) end

-- The tab in Auctionator's strip (between its Cancel and its own options tab), as it lets other addons add theirs
local a = _G.Auctionator
if a and a.Tabs and a.Tabs.Register then
  a.Tabs.Register({
    name = "ClaraSniper",
    textLabel = L.SNIPER_TAB,
    tabTemplate = "ClaraSniperTabFrameTemplate",
    tabHeader = L.SNIPER_HEADER,
    tabFrameName = "ClaraSniperFrame",
    tabOrder = 3.5, -- (between Cancel and its own options: the last but one)
  })
  Sn.registered = true
end
