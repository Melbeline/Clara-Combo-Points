-- Clara Combo Points - the mail module's window (MailData.lua holds its data): a button right of
-- the Send Mail window's To field opens, above it (beside it when there is no room above), the
-- characters mail was sent to, three to a row, newest first (top left, then left to right); the
-- mouse wheel shows older ones. A click puts the name in To; a right-click puts the character in
-- categories (several at once). Sort by: the newest first, or a category's characters first, in a
-- framed block. Add/remove categories: add one, delete one, reset them, or reset everything. Export /
-- Import (title bar): the whole of it as a line of text, for another account. The game's own window
-- look; ClassicUI's when it runs (its ClaraMailSkin: Modules/ClassicUI/Windows/ClaraMail.lua).

local ADDON, ns = ...
local L = ns.L
local M = ns.Mail
if not M then return end

local COLS, ROWS = 3, 5
local TITLE_H, SORT_H = 24, 26  -- the title bar; the Sort by row under it
local ROW_H, NAME_H = 28, 22    -- a row of names; a name's button
local GAP, PAD = 6, 12          -- between names; the window's margins
local ARROWS_W = 20             -- the scroll arrows, right of the names
local BLOCK_PAD = 3             -- the sorted category's frame, around its names

local panel, toggle, sortButton, manage, exportButton, importButton, emptyText, upButton, downButton
local cells, rows = {}, {}
local first = 0 -- rows scrolled past
local textBox

local function Skin(kind, frame)
  local classic = ns.ClassicUIPrivate -- (ClassicUI built in, running)
  if classic and classic.ClaraMailSkin then
    classic.ClaraMailSkin(kind, frame)
  elseif kind == "window" then
    ns:DressWindow(frame, { portrait = false }) -- (Look.lua: Classic's dialog edge in the Light version)
  end
end

local function ClickSound()
  if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

---------------------------------------------------------------------------
-- The game's menus, opened on a button of ours; a click on that button while its menu is open
-- closes it (as Options.lua's)
---------------------------------------------------------------------------
local function MenuOpen(owner)
  local menu = owner.menu
  return menu ~= nil and menu:IsShown() and (not menu.GetOwnerRegion or menu:GetOwnerRegion() == owner)
end
local function OwnerHandlesPress(self, _, event)
  return event == "GLOBAL_MOUSE_DOWN" and MenuOpen(self)
end
local function ToggleMenu(owner, generator)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
  if MenuOpen(owner) then
    owner.menu:Close()
    owner.menu = nil
    return
  end
  owner.HandlesGlobalMouseEvent = OwnerHandlesPress
  owner.menu = MenuUtil.CreateContextMenu(owner, generator)
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------
local Refresh

local function SortName(id)
  if id == "last" then return L.MAIL_SORT_LAST end
  return M.CategoryName(id) or L.MAIL_SORT_LAST
end

-- The names in their cells: the sorted category's first, its last row filled with empty cells,
-- then the others. Returns the cells and how many rows the category's take.
local function Layout()
  local list, n = M.Sorted()
  local out = {}
  for i = 1, n do out[#out + 1] = list[i] end
  local blockRows = math.ceil(n / COLS)
  for _ = n + 1, blockRows * COLS do out[#out + 1] = false end
  for i = n + 1, #list do out[#out + 1] = list[i] end
  return out, blockRows
end

local function Scroll(delta)
  first = first - delta
  Refresh()
end

-- A name chosen: in To (MailUI2: the items given to that character attached).
local function Choose(r)
  if not (SendMailNameEditBox and r) then return end
  SendMailNameEditBox:SetText(r.name)
  SendMailNameEditBox:ClearFocus()
  if M.Chosen then M.Chosen(r.name) end
end

local function NameTooltip(self)
  local r = self.entry
  if not (r and GameTooltip) then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText(r.name, 1, 1, 1)
  local names = M.CategoryNames(r.name)
  if #names > 0 then
    GameTooltip:AddLine(table.concat(names, ", "), 1, .82, 0, true)
  else
    GameTooltip:AddLine(L.MAIL_NO_CATEGORY, .6, .6, .65, true)
  end
  local items = 0 -- (the items that go to it: MailItems.lua)
  if M.ItemGoesTo then
    for _, a in pairs(M.db.items) do if M.ItemGoesTo(a, r.name) then items = items + 1 end end
  end
  if items > 0 then GameTooltip:AddLine(L.MAIL_NAME_ITEMS:format(items), .4, .78, 1, true) end
  GameTooltip:AddLine(L.MAIL_NAME_TIP, .4, 1, .4, true)
  GameTooltip:Show()
end

-- Right-click: its categories (boxes), none, or out of the list.
local function NameMenu(self)
  local r = self.entry
  if not r then return end
  local name = r.name
  ToggleMenu(self, function(_, root)
    root:CreateTitle(name)
    for _, c in ipairs(M.Categories()) do
      root:CreateCheckbox(c.name, function() return M.HasCategory(name, c.id) end, function()
        M.SetCategory(name, c.id, not M.HasCategory(name, c.id))
        Refresh()
      end)
    end
    root:CreateDivider()
    root:CreateButton(L.MAIL_RESET_CATEGORY, function()
      M.ClearCategories(name)
      Refresh()
    end)
    root:CreateButton(L.MAIL_REMOVE_NAME, function()
      M.Remove(name)
      Refresh()
    end)
  end)
end

local function Cell(parent, i)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetHeight(NAME_H)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetNormalFontObject(GameFontNormalSmall)
  b:SetHighlightFontObject(GameFontHighlightSmall)
  local fs = b:GetFontString()
  if fs then fs:SetWordWrap(false) end
  b:SetScript("OnClick", function(self, button)
    ClickSound()
    if GameTooltip then GameTooltip:Hide() end
    if M.Dropped and M.Dropped(self.entry) then return end -- (an item held: given to that character)
    if button == "RightButton" then NameMenu(self) else Choose(self.entry) end
  end)
  b:SetScript("OnEnter", NameTooltip)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:EnableMouseWheel(true)
  b:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
  b:SetScript("OnReceiveDrag", function(self) if M.Dropped then M.Dropped(self.entry) end end)
  Skin("button", b)
  cells[i] = b
  return b
end

-- A row's frame (the sorted category's): a light fill, a grey border; its top on the block's first
-- row, its bottom on its last.
local function Row(parent, r)
  local f = CreateFrame("Frame", nil, parent)
  f:SetFrameLevel(parent:GetFrameLevel())
  local fill = f:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(.55, .55, .6, .14)
  local lines = {}
  for k, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetColorTexture(.62, .62, .66, .85)
    if side == "TOP" or side == "BOTTOM" then
      t:SetPoint(side .. "LEFT")
      t:SetPoint(side .. "RIGHT")
      t:SetHeight(1)
    else
      t:SetPoint("TOP" .. side)
      t:SetPoint("BOTTOM" .. side)
      t:SetWidth(1)
    end
    lines[side] = t
  end
  f.lines = lines
  f:Hide()
  rows[r] = f
  return f
end

-- The cells' places: the window's width shared out (it follows the mail window's).
local function Place()
  local w = panel:GetWidth()
  local inner = w - 2 * PAD - ARROWS_W
  local cellW = math.floor((inner - (COLS - 1) * GAP) / COLS)
  local top = -(TITLE_H + SORT_H + 10)
  for r = 1, ROWS do
    local y = top - (r - 1) * ROW_H
    local row = rows[r]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - BLOCK_PAD, y + BLOCK_PAD)
    row:SetSize(COLS * cellW + (COLS - 1) * GAP + 2 * BLOCK_PAD, NAME_H + 2 * BLOCK_PAD)
    for c = 1, COLS do
      local b = cells[(r - 1) * COLS + c]
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + (c - 1) * (cellW + GAP), y)
      b:SetWidth(cellW)
      local fs = b:GetFontString()
      if fs then fs:SetWidth(cellW - 10) end
    end
  end
  -- the Sort by row: the list takes what the label and the button leave
  local label = panel.sortLabel
  local room = w - 2 * PAD - (label:GetStringWidth() or 40) - 6 - 8 - manage:GetWidth()
  sortButton:SetWidth(math.max(80, math.min(170, room)))
end

function Refresh()
  if not (panel and panel:IsShown()) then return end
  local list, blockRows = Layout()
  local total = math.ceil(#list / COLS)
  first = math.max(0, math.min(first, total - ROWS))
  for r = 1, ROWS do
    local index = first + r
    local row = rows[r]
    local inBlock = index <= blockRows
    row:SetShown(inBlock)
    if inBlock then
      row.lines.TOP:SetShown(index == 1)
      row.lines.BOTTOM:SetShown(index == blockRows)
    end
    for c = 1, COLS do
      local b = cells[(r - 1) * COLS + c]
      local entry = list[(index - 1) * COLS + c]
      b.entry = entry or nil
      if entry then
        b:SetText(entry.name)
        b:Show()
      else
        b:Hide()
      end
    end
  end
  upButton:SetEnabled(first > 0)
  downButton:SetEnabled(first + ROWS < total)
  emptyText:SetShown(#list == 0)
  sortButton.text:SetText(SortName(M.db.sort))
end
M.Changed = function() Refresh() end

---------------------------------------------------------------------------
-- Sort by, Add/remove categories, Export / Import
---------------------------------------------------------------------------
local function SortMenu(self)
  ToggleMenu(self, function(_, root)
    root:CreateRadio(L.MAIL_SORT_LAST, function() return M.db.sort == "last" end, function()
      M.db.sort = "last"
      first = 0
      Refresh()
    end)
    for _, c in ipairs(M.Categories()) do
      root:CreateRadio(c.name, function() return M.db.sort == c.id end, function()
        M.db.sort = c.id
        first = 0
        Refresh()
      end)
    end
  end)
end

local function AskAdd()
  ns:AskText(L.MAIL_ADD_ASK, "", L.MAIL_ADD, function(text)
    local id, why = M.AddCategory(text)
    if not id then
      ns:ShowError(why == "exists" and L.MAIL_ADD_EXISTS or L.MAIL_ADD_EMPTY)
      return
    end
    Refresh()
  end)
end

local function AskDelete(c)
  local n = #M.Members(c.id)
  ns:Ask(L.MAIL_DELETE_ASK:format(c.name, n), false, { L.MAIL_DELETE, function()
    M.DeleteCategory(c.id)
    Refresh()
  end }, { L.CANCEL })
end

local function ManageMenu(self)
  ToggleMenu(self, function(_, root)
    root:CreateButton(L.MAIL_ADD_CATEGORY, AskAdd)
    root:CreateDivider()
    root:CreateTitle(L.MAIL_DELETE_TITLE)
    for _, c in ipairs(M.Categories()) do
      root:CreateButton("|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14:14|t " .. c.name, function() AskDelete(c) end)
    end
    root:CreateDivider()
    root:CreateButton(L.MAIL_RESET_CATEGORIES, function()
      ns:Ask(L.MAIL_RESET_CATEGORIES_ASK, true, { L.MAIL_RESET, function()
        M.ResetCategories()
        Refresh()
      end }, { L.CANCEL })
    end)
    root:CreateButton(L.MAIL_RESET_ALL, function()
      ns:Ask(L.MAIL_RESET_ALL_ASK, true, { L.MAIL_RESET, function()
        M.ResetAll()
        first = 0
        Refresh()
      end }, { L.CANCEL })
    end)
  end)
end

local function TextBox()
  if not textBox and ns.TextDialog then
    textBox = ns.TextDialog(UIParent)
    textBox:SetFrameStrata("FULLSCREEN_DIALOG") -- (dressed as Clara's other windows: Look.lua)
  end
  return textBox
end

local function Export()
  local box = TextBox()
  if box then box:Open(L.MAIL_EXPORT_TITLE, L.MAIL_EXPORT_HINT, M.Export(), L.SELECT_ALL, function() box:SelectAll() end) end
end

local function Import()
  local box = TextBox()
  if not box then return end
  box:Open(L.MAIL_IMPORT_TITLE, L.MAIL_IMPORT_HINT, nil, L.PROFILE_IMPORT, function(text)
    local data, why = M.ReadExport(text)
    if not data then
      box:ShowStatus(false, why)
      return
    end
    ns:Ask(L.MAIL_IMPORT_ASK, true, { L.PROFILE_IMPORT, function()
      M.Import(data)
      box:Hide()
      first = 0
      Refresh()
    end }, { L.CANCEL })
  end)
end

---------------------------------------------------------------------------
-- The window, and its button by To
---------------------------------------------------------------------------
local function SmallButton(parent, label, w, onClick, tip)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 18)
  b:SetNormalFontObject(GameFontNormalSmall)
  b:SetHighlightFontObject(GameFontHighlightSmall)
  b:SetText(label)
  b:SetScript("OnClick", function(self) ClickSound(); onClick(self) end)
  if tip then
    b:SetScript("OnEnter", function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(label)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  end
  Skin("button", b)
  return b
end

local function ArrowButton(parent, dir, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(18, 18)
  local base = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. dir .. "Button-"
  b:SetNormalTexture(base .. "Up")
  b:SetPushedTexture(base .. "Down")
  b:SetDisabledTexture(base .. "Disabled")
  b:SetHighlightTexture(base .. "Highlight", "ADD")
  b:SetScript("OnClick", function() ClickSound(); onClick() end)
  return b
end

local function Height() return TITLE_H + SORT_H + 10 + ROWS * ROW_H + 8 end

-- Above the mail window, as wide as it; beside it when the screen has no room above.
local function Anchor()
  local mail = MailFrame
  panel:ClearAllPoints()
  local top, screenTop = mail:GetTop(), UIParent:GetTop()
  local room = 0
  if top and screenTop then
    room = screenTop * UIParent:GetEffectiveScale() / panel:GetEffectiveScale() - top
  end
  if room >= Height() + 4 then
    panel:SetPoint("BOTTOMLEFT", mail, "TOPLEFT", 0, 2)
    panel:SetPoint("BOTTOMRIGHT", mail, "TOPRIGHT", 0, 2)
  else
    panel:SetPoint("TOPLEFT", mail, "TOPRIGHT", 4, 0)
    panel:SetWidth(math.max(338, mail:GetWidth() or 338))
  end
  panel:SetHeight(Height())
end

local function Build()
  panel = CreateFrame("Frame", "ClaraMailRecipients", SendMailFrame, "DefaultPanelTemplate")
  panel:EnableMouse(true)
  panel:SetFrameStrata("HIGH")
  panel:Hide()
  if panel.Bg then panel.Bg:SetVertexColor(.32, .32, .34) end
  local title = L.MAIL_TITLE
  if panel.SetTitle then panel:SetTitle(title) elseif panel.TitleContainer then panel.TitleContainer.TitleText:SetText(title) end
  local titleText = panel.TitleContainer and panel.TitleContainer.TitleText
  if titleText then -- (left: Export and Import take the right of the title bar)
    titleText:ClearAllPoints()
    titleText:SetPoint("LEFT", panel.TitleContainer, "LEFT", PAD, 0)
    titleText:SetJustifyH("LEFT")
  end
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 1, 0)
  close:SetScript("OnClick", function()
    ClickSound()
    M.db.open = nil
    panel:Hide()
  end)
  panel.close = close
  -- Export / Import, in the title bar left of the close button
  importButton = SmallButton(panel, L.MAIL_IMPORT, 56, Import, L.MAIL_IMPORT_TIP)
  importButton:SetPoint("RIGHT", close, "LEFT", -2, 0)
  exportButton = SmallButton(panel, L.MAIL_EXPORT, 56, Export, L.MAIL_EXPORT_TIP)
  exportButton:SetPoint("RIGHT", importButton, "LEFT", -2, 0)

  -- Sort by: the list, then Add/remove categories
  local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetText(L.MAIL_SORT_BY)
  label:SetPoint("TOPLEFT", PAD, -(TITLE_H + 9))
  panel.sortLabel = label
  sortButton = CreateFrame("Button", nil, panel)
  sortButton:SetSize(130, 20)
  sortButton:SetPoint("LEFT", label, "RIGHT", 6, 0)
  local bg = sortButton:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, .5)
  local hl = sortButton:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, .1)
  local arrow = sortButton:CreateTexture(nil, "ARTWORK")
  arrow:SetSize(18, 18)
  arrow:SetPoint("RIGHT", 1, 0)
  arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
  sortButton.text = sortButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sortButton.text:SetPoint("LEFT", 5, 0)
  sortButton.text:SetPoint("RIGHT", arrow, "LEFT", 0, 0)
  sortButton.text:SetJustifyH("LEFT")
  sortButton.text:SetWordWrap(false)
  sortButton:SetScript("OnClick", function(self) ClickSound(); SortMenu(self) end)
  Skin("dropdown", sortButton)
  manage = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  manage:SetNormalFontObject(GameFontNormalSmall)
  manage:SetHighlightFontObject(GameFontHighlightSmall)
  manage:SetText(L.MAIL_MANAGE)
  local fs = manage:GetFontString()
  manage:SetSize(math.max(110, math.ceil((fs and fs:GetStringWidth() or 100) + 24)), 20)
  manage:SetPoint("LEFT", sortButton, "RIGHT", 8, 0)
  manage:SetScript("OnClick", function(self) ClickSound(); ManageMenu(self) end)
  Skin("button", manage)

  -- the names, their rows' frames, the scroll arrows
  for r = 1, ROWS do Row(panel, r) end
  for i = 1, ROWS * COLS do Cell(panel, i) end
  local wheel = CreateFrame("Frame", nil, panel)
  wheel:SetPoint("TOPLEFT", PAD, -(TITLE_H + SORT_H + 6))
  wheel:SetPoint("BOTTOMRIGHT", -PAD, 6)
  wheel:SetFrameLevel(panel:GetFrameLevel())
  wheel:EnableMouseWheel(true)
  wheel:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
  upButton = ArrowButton(panel, "Up", function() Scroll(1) end)
  upButton:SetPoint("TOPRIGHT", -PAD + 2, -(TITLE_H + SORT_H + 10))
  downButton = ArrowButton(panel, "Down", function() Scroll(-1) end)
  downButton:SetPoint("BOTTOMRIGHT", -PAD + 2, 10)
  emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  emptyText:SetPoint("TOPLEFT", PAD, -(TITLE_H + SORT_H + 14))
  emptyText:SetPoint("RIGHT", -PAD - ARROWS_W, 0)
  emptyText:SetJustifyH("LEFT")
  emptyText:SetWordWrap(true)
  emptyText:SetText(L.MAIL_EMPTY)

  panel:SetScript("OnShow", function()
    Anchor()
    Place()
    Refresh()
  end)
  panel:SetScript("OnHide", function()
    if sortButton.menu and sortButton.menu.Close then sortButton.menu:Close() end
    if manage.menu and manage.menu.Close then manage.menu:Close() end
  end)
  Skin("window", panel)
  Skin("close", close)

  -- the button by To: opens or shuts it
  toggle = CreateFrame("Button", "ClaraMailRecipientsButton", SendMailFrame)
  toggle:SetSize(22, 22)
  toggle:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 8, 0)
  local icon = toggle:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\INV_Letter_15")
  icon:SetTexCoord(.06, .94, .06, .94)
  icon:SetAllPoints()
  toggle.icon = icon
  toggle:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  -- pressed: the icon a pixel down and right, as the game's square buttons
  toggle:SetScript("OnMouseDown", function()
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", 1, -1)
  end)
  toggle:SetScript("OnMouseUp", function()
    icon:ClearAllPoints()
    icon:SetAllPoints()
  end)
  toggle:SetScript("OnClick", function()
    ClickSound()
    if panel:IsShown() then
      M.db.open = nil
      panel:Hide()
    else
      M.db.open = true
      panel:Show()
    end
  end)
  toggle:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.MAIL_TITLE)
    GameTooltip:AddLine(L.MAIL_BUTTON_TIP, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  toggle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  Skin("toggle", toggle)
  M.panel, M.toggle = panel, toggle -- (for the tests)
end

-- The mailbox opened: the window as it was left (open or shut).
function M.OnShow()
  if not (SendMailFrame and SendMailNameEditBox and MailFrame) then return end
  if not panel then Build() end
  first = 0
  panel:SetShown(M.db.open == true)
  if panel:IsShown() then
    Anchor()
    Place()
    Refresh()
  end
end

function M.OnClose()
  if textBox then textBox:Hide() end
end
