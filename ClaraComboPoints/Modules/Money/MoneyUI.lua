-- Clara - the gold window (Money.lua's data). A right click on the money at the bottom of the backpack opens
-- it (the game's bags and ClassicUI's alike: ClassicUI keeps the game's money frame); its left click stays the
-- game's. One column per WoW account (ICKSTU, WANJ, WoW1...: by name), its characters the highest level first,
-- each with its gold; the account's total under it, every account's at the top.
--   Reorder: drag a character up or down, the others making way as it moves; the order is kept for that
--   account (By level puts the levels back).
--   Each account's box hides its column, leaving a thin strip: a click on the strip shows it again.
--   Right-click an account's name to rename it; a character, to forget it (one deleted or no longer played).
local ADDON, ns = ...
local G = ns.Money
if not G then return end
local L = ns.L

local COL_W, STRIP_W, ROW_H, HEAD_H, MAX_ROWS = 200, 18, 18, 22, 24
local PAD, GAP, TOP_H, FOOT_H = 14, 8, 50, 52
local frame
local cols = {}
local reorder = false
local drag -- { col, key, index, order }

local function Coins(copper)
  copper = copper or 0
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(copper) end
  if GetMoneyString then return GetMoneyString(copper, true) end
  return tostring(math.floor(copper / 10000)) .. "g"
end

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

local function AccountLabel(id, i)
  return G.AccountName(id) or L.MONEY_ACCOUNT_DEFAULT:format(i)
end

---------------------------------------------------------------------------
-- Dialogs: renaming an account, forgetting a character
---------------------------------------------------------------------------
StaticPopupDialogs.CLARA_MONEY_RENAME = {
  text = "%s", button1 = ACCEPT or "OK", button2 = CANCEL or "Cancel", hasEditBox = true, maxLetters = 24,
  OnShow = function(self, data) local box = self.editBox or self.EditBox; if box then box:SetText(data.name or ""); box:HighlightText() end end,
  OnAccept = function(self, data) local box = self.editBox or self.EditBox; if box then G.Rename(data.id, box:GetText()) end end,
  EditBoxOnEnterPressed = function(self, data)
    G.Rename(data.id, self:GetText())
    self:GetParent():Hide()
  end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs.CLARA_MONEY_FORGET = {
  text = "%s", button1 = YES or "Yes", button2 = NO or "No",
  OnAccept = function(_, data) G.Forget(data.key) end,
  timeout = 0, whileDead = true, hideOnEscape = true,
}

---------------------------------------------------------------------------
-- A column
---------------------------------------------------------------------------
local Refresh

local function RowTooltip(row)
  local rec = row.key and G.db.chars[row.key]
  if not rec then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(rec.n .. (rec.r ~= "" and (" - " .. rec.r) or ""), ClassColor(rec.c))
  GameTooltip:AddLine((LEVEL or "Level") .. " " .. rec.l, 1, 1, 1)
  GameTooltip:AddLine(Coins(rec.m), 1, 1, 1)
  if rec.at and rec.at > 1 then GameTooltip:AddLine(L.MONEY_SEEN:format(date("%d/%m/%Y %H:%M", rec.at)), 0.6, 0.6, 0.6) end
  if reorder then GameTooltip:AddLine(L.MONEY_DRAG_TIP, 0.5, 0.8, 1, true)
  elseif row.key ~= G.Me() then GameTooltip:AddLine(L.MONEY_FORGET_TIP, 0.6, 0.6, 0.6, true) end
  GameTooltip:Show()
end

local function StartDrag(col, row)
  local order = {}
  for i, key in ipairs(col.keys) do order[i] = key end
  drag = { col = col, key = row.key, order = order, row = row }
  row:SetFrameLevel(col.body:GetFrameLevel() + 10)
  row:SetAlpha(0.85)
end

local function DragIndex(col)
  local _, y = GetCursorPosition()
  y = y / col.body:GetEffectiveScale()
  local top = col.body:GetTop() or y
  local index = math.floor((top - y) / ROW_H) + 1
  return math.max(1, math.min(#drag.order, index))
end

-- the rows where they go while dragging: the dragged one under the cursor, the others making way
local function PlaceDrag()
  local col = drag.col
  local order = {}
  for _, key in ipairs(drag.order) do if key ~= drag.key then order[#order + 1] = key end end
  local index = DragIndex(col)
  table.insert(order, index, drag.key)
  drag.preview = order
  local byKey = {}
  for _, row in ipairs(col.rows) do if row.key then byKey[row.key] = row end end
  for i, key in ipairs(order) do
    local row = byKey[key]
    if row and row ~= drag.row then
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", col.body, "TOPLEFT", 0, -(i - 1 - col.offset) * ROW_H)
      row:SetShown(i > col.offset and i <= col.offset + MAX_ROWS)
    end
  end
  local _, y = GetCursorPosition()
  y = y / col.body:GetEffectiveScale()
  local dy = math.max(-(#order - 1) * ROW_H, math.min(0, y - (col.body:GetTop() or y) + ROW_H / 2))
  drag.row:ClearAllPoints()
  drag.row:SetPoint("TOPLEFT", col.body, "TOPLEFT", 0, dy)
end

local function EndDrag()
  if not drag then return end
  local col, order = drag.col, drag.preview
  drag.row:SetAlpha(1)
  drag.row:SetFrameLevel(col.body:GetFrameLevel() + 1)
  drag = nil
  if order then G.db.order[col.id] = order end
  Refresh()
end

local function NewRow(col, i)
  local row = CreateFrame("Button", nil, col.body)
  row:SetSize(COL_W, ROW_H)
  row:RegisterForClicks("RightButtonUp")
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", 4, 0)
  row.name:SetJustifyH("LEFT")
  row.money = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.money:SetPoint("RIGHT", -4, 0)
  row.money:SetJustifyH("RIGHT")
  row.name:SetPoint("RIGHT", row.money, "LEFT", -4, 0)
  row.mark = row:CreateTexture(nil, "BACKGROUND")
  row.mark:SetAllPoints()
  row.mark:SetColorTexture(1, 0.82, 0, 0.12)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  row:SetScript("OnEnter", RowTooltip)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and reorder and self.key then StartDrag(col, self) end
  end)
  row:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then EndDrag() end end)
  row:SetScript("OnClick", function(self)
    if reorder or not self.key or self.key == G.Me() then return end
    local rec = G.db.chars[self.key]
    if rec then StaticPopup_Show("CLARA_MONEY_FORGET", L.MONEY_FORGET_ASK:format(rec.n), nil, { key = self.key }) end
  end)
  col.rows[i] = row
  return row
end

local function Col(id)
  local col = cols[id]
  if col then return col end
  col = { id = id, rows = {}, offset = 0 }
  cols[id] = col
  local box = CreateFrame("Frame", nil, frame)
  col.box = box
  -- its head: the box (shown or hidden) and the account's name
  col.check = CreateFrame("CheckButton", nil, box, "UICheckButtonTemplate")
  col.check:SetSize(20, 20)
  col.check:SetPoint("TOPLEFT", 0, 0)
  col.check:SetScript("OnClick", function(self)
    G.db.collapsed[id] = not self:GetChecked() or nil
    Refresh()
  end)
  col.check:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.MONEY_HIDE_TIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  col.check:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ns:DressCheck(col.check)
  col.title = CreateFrame("Button", nil, box)
  col.title:SetPoint("LEFT", col.check, "RIGHT", 2, 0)
  col.title:SetSize(COL_W - 24, HEAD_H)
  col.title:RegisterForClicks("RightButtonUp")
  col.title.text = col.title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  col.title.text:SetPoint("LEFT")
  col.title:SetScript("OnClick", function()
    StaticPopup_Show("CLARA_MONEY_RENAME", L.MONEY_RENAME_ASK, nil, { id = id, name = G.AccountName(id) })
  end)
  col.title:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.MONEY_RENAME_TIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  col.title:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- its characters, under it; the wheel scrolls a long list
  col.body = CreateFrame("Frame", nil, box)
  col.body:SetPoint("TOPLEFT", 0, -HEAD_H - 2)
  col.body:SetWidth(COL_W)
  col.body:EnableMouseWheel(true)
  col.body:SetScript("OnMouseWheel", function(_, delta)
    local most = math.max(0, #(col.keys or {}) - MAX_ROWS)
    col.offset = math.max(0, math.min(most, col.offset - delta))
    Refresh()
  end)
  col.total = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  col.total:SetPoint("TOPRIGHT", col.body, "BOTTOMRIGHT", -4, -4)
  -- hidden: a thin strip, a click shows the column again
  col.strip = CreateFrame("Button", nil, frame)
  col.strip:SetWidth(STRIP_W)
  local bg = col.strip:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 0.82, 0, 0.18)
  local hl = col.strip:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.15)
  col.strip.arrow = col.strip:CreateTexture(nil, "ARTWORK")
  col.strip.arrow:SetSize(14, 14)
  col.strip.arrow:SetPoint("TOP", 0, -4)
  col.strip.arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  col.strip:SetScript("OnClick", function()
    G.db.collapsed[id] = nil
    Refresh()
  end)
  col.strip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.MONEY_SHOW_TIP:format(self.label or ""), 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  col.strip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return col
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Build()
  frame = CreateFrame("Frame", "ClaraMoneyFrame", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    G.db.pos = { point, rel, x, y }
  end)
  frame:Hide()
  tinsert(UISpecialFrames, "ClaraMoneyFrame")
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOP", 0, -14)
  frame.title:SetText(L.MONEY_TITLE)
  frame.total = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.total:SetPoint("TOP", frame.title, "BOTTOM", 0, -6)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  frame.reorder = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.reorder:SetSize(120, 22)
  frame.reorder:SetPoint("BOTTOMLEFT", PAD, 14)
  frame.reorder:SetScript("OnClick", function()
    reorder = not reorder
    Refresh()
  end)
  frame.reorder:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.MONEY_REORDER_TIP, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame.reorder:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.byLevel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.byLevel:SetSize(120, 22)
  frame.byLevel:SetPoint("LEFT", frame.reorder, "RIGHT", 6, 0)
  frame.byLevel:SetText(L.MONEY_BY_LEVEL)
  frame.byLevel:SetScript("OnClick", function()
    G.db.order = {}
    Refresh()
  end)
  frame:SetScript("OnUpdate", function() if drag then PlaceDrag() end end)
  frame:SetScript("OnHide", function() if drag then EndDrag() end reorder = false end)
  ns:DressDialog(frame, { fill = true, close = close, buttons = { frame.reorder, frame.byLevel } })
end

function Refresh()
  if not (frame and frame:IsShown()) then return end
  local ids = G.Accounts()
  local me = G.Me()
  local x, rows = PAD, 0
  for _, col in pairs(cols) do col.box:Hide(); col.strip:Hide() end
  for i, id in ipairs(ids) do
    local col = Col(id)
    local label = AccountLabel(id, i)
    if G.db.collapsed[id] then
      col.strip.label = label
      col.strip:ClearAllPoints()
      col.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -TOP_H)
      col.strip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, FOOT_H - 6)
      col.strip:Show()
      x = x + STRIP_W + GAP
    else
      col.box:ClearAllPoints()
      col.box:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -TOP_H)
      col.box:SetSize(COL_W, 10)
      col.box:Show()
      col.check:SetChecked(true)
      col.title.text:SetText(label)
      col.keys = G.List(id)
      col.offset = math.max(0, math.min(col.offset, #col.keys - MAX_ROWS))
      local shown = math.min(#col.keys, MAX_ROWS)
      col.body:SetHeight(math.max(1, shown) * ROW_H)
      for r, key in ipairs(col.keys) do
        local row = col.rows[r] or NewRow(col, r)
        local rec = G.db.chars[key]
        row.key = key
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", col.body, "TOPLEFT", 0, -(r - 1 - col.offset) * ROW_H)
        row:SetShown(r > col.offset and r <= col.offset + MAX_ROWS)
        row.name:SetText(("|cff9d9d9d%d|r %s"):format(rec.l, rec.n))
        row.name:SetTextColor(ClassColor(rec.c))
        row.money:SetText(Coins(rec.m))
        row.mark:SetShown(key == me)
      end
      for r = #col.keys + 1, #col.rows do col.rows[r].key = nil; col.rows[r]:Hide() end
      col.total:SetText(Coins(G.Total(id)))
      rows = math.max(rows, shown)
      x = x + COL_W + GAP
    end
  end
  frame.total:SetText(L.MONEY_TOTAL:format(Coins(G.Total())))
  frame.reorder:SetText(reorder and L.MONEY_REORDER_DONE or L.MONEY_REORDER)
  frame:SetSize(math.max(x - GAP + PAD, 280), TOP_H + HEAD_H + 2 + math.max(1, rows) * ROW_H + 22 + FOOT_H)
end
G.Refresh = Refresh
G.Changed = function() if frame and frame:IsShown() and not drag then Refresh() end end

local function Place()
  frame:ClearAllPoints()
  local pos = G.db.pos
  if pos and pos[1] then
    frame:SetPoint(pos[1], UIParent, pos[2] or pos[1], pos[3] or 0, pos[4] or 0)
    return
  end
  local bag = (ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() and ContainerFrameCombinedBags)
    or (ContainerFrame1 and ContainerFrame1:IsShown() and ContainerFrame1)
  if bag then frame:SetPoint("BOTTOMRIGHT", bag, "BOTTOMLEFT", -8, 0) else frame:SetPoint("CENTER") end
end

function G.Toggle(show)
  if not G.db then return end
  if not frame then Build() end
  if frame:IsShown() and not show then frame:Hide() return end
  Place()
  frame:Show()
  Refresh()
end

---------------------------------------------------------------------------
-- The bags' money: its right click
---------------------------------------------------------------------------
local function Hint(self)
  if not GameTooltip:IsOwned(self) then
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.MONEY_TITLE)
  end
  GameTooltip:AddLine(L.MONEY_HINT, 0.5, 0.8, 1, true)
  GameTooltip:Show()
end

local function HookMoney(money)
  if not money or money.claraMoney then return end
  money.claraMoney = true
  for _, part in ipairs({ money, money.GoldButton, money.SilverButton, money.CopperButton }) do
    if part and part.HookScript then
      part:HookScript("OnMouseUp", function(_, button) if button == "RightButton" then G.Toggle() end end)
      if part ~= money then
        part:HookScript("OnEnter", Hint)
        part:HookScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
      end
    end
  end
end
G.HookMoney = HookMoney

function G.Started()
  HookMoney(ContainerFrame1 and ContainerFrame1.MoneyFrame or ContainerFrame1MoneyFrame)
  HookMoney(ContainerFrameCombinedBags and ContainerFrameCombinedBags.MoneyFrame)
end
