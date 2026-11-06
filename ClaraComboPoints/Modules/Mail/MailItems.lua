-- Clara Combo Points - the mail module's items. A middle-click on an item in the bags (the game's,
-- ClassicUI's, or a bag addon's: the item of the tooltip it shows, when it is in the bags) opens a
-- small menu by it: the categories that have characters (a category of several: which of them), and
-- Reset. Dropped on a name of the recipients window, an item goes to that character. Once a character
-- is chosen (a click on its name, or its name typed in To, then Enter or Tab), its items in the bags
-- are attached, once (more than the mail holds: the rest in its extra slots, MailExtra.lua). A stack taken off the mail (right-click on it) is not attached again until the
-- mail is sent or the mailbox shut (that stack: its bag slot; the others of the item still are). An item whose category is gone, or no longer the character's,
-- keeps it but does nothing. The bag item's tooltip says where it goes.

local ADDON, ns = ...
local L = ns.L
local M = ns.Mail
if not M then return end

local STEP = 0.1 -- between two attachments (the game takes them one after another)

---------------------------------------------------------------------------
-- The items given to characters
---------------------------------------------------------------------------
function M.ItemAssignment(id)
  return M.db.items[id]
end

-- cat: the category it was given through (nil: dropped on the name); who: the character.
function M.AssignItem(id, cat, who)
  if type(id) ~= "number" then return end
  M.db.items[id] = { cat = cat, who = who }
end

function M.ClearItem(id)
  if type(id) == "number" then M.db.items[id] = nil end
end

-- Does the item go to this character now? (given through a category: it still exists and is still
-- the character's; otherwise dormant)
function M.ItemGoesTo(a, name)
  local key = M.Key(name)
  if not (a and key and a.who and M.Key(a.who) == key) then return false end
  if a.cat then return M.CategoryName(a.cat) ~= nil and M.HasCategory(name, a.cat) end
  return true
end

-- Where it goes, in a few words (its tooltip, the menu): "Lola Rose (Banque plantes)", or nil.
function M.ItemTarget(id)
  local a = M.db.items[id]
  if not (a and a.who) then return nil end
  local cat = a.cat and M.CategoryName(a.cat)
  if a.cat and not (cat and M.HasCategory(a.who, a.cat)) then return nil, true end -- (dormant)
  return cat and ("%s (%s)"):format(a.who, cat) or a.who
end

local function Notice(text)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(text, 1, .82, 0, 1) end
end

local function ItemName(id)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not name and GetItemInfo then name = GetItemInfo(id) end
  return name or ("item:" .. id)
end

---------------------------------------------------------------------------
-- The bags
---------------------------------------------------------------------------
local function Bags()
  local last = NUM_BAG_SLOTS or 4
  local list = {}
  for bag = 0, last do list[#list + 1] = bag end
  local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
  if reagent and reagent > last then list[#list + 1] = reagent end
  return list
end

local function SlotInfo(bag, slot)
  local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
  if type(info) == "table" then return info.itemID, info.isLocked end
end

local function InBags(id)
  if not (C_Container and C_Container.GetContainerNumSlots) then return false end
  for _, bag in ipairs(Bags()) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      if SlotInfo(bag, slot) == id then return true end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- The middle-click menu
---------------------------------------------------------------------------
local function MouseFocus()
  local focus
  if GetMouseFoci then
    local foci = GetMouseFoci()
    focus = foci and foci[1]
  else
    focus = GetMouseFocus and GetMouseFocus()
  end
  if focus and focus.IsForbidden and focus:IsForbidden() then return end -- (the game's secure dialogs: not ours to read)
  return focus
end

-- The bag item under the mouse, and its button: the game's slot (and the bags made of its buttons),
-- else the item of the tooltip shown for that button, when it is one of the bags'.
local function ItemUnderMouse()
  local focus = MouseFocus()
  if not focus then return end
  local ok, bag = pcall(function() return focus.GetBagID and focus:GetBagID() end)
  local slot = ok and bag and focus.GetID and focus:GetID()
  if type(bag) == "number" and type(slot) == "number" then
    local id = SlotInfo(bag, slot)
    if id then return id, focus end
  end
  local tip = GameTooltip
  if tip and tip:IsShown() and tip.GetOwner and tip:GetOwner() == focus and tip.GetItem then
    local okItem, _, link = pcall(tip.GetItem, tip)
    local id = okItem and type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id and InBags(id) then return id, focus end
  end
end

local function Given(id, cat, who)
  M.AssignItem(id, cat, who)
  Notice(L.MAIL_ITEM_GIVEN:format(ItemName(id), who))
end

local function ItemMenu(_, root, id)
  root:CreateTitle(ItemName(id))
  local a = M.db.items[id]
  local any = false
  for _, c in ipairs(M.Categories()) do
    local members = M.Members(c.id)
    if #members == 1 then
      any = true
      local who = members[1].name
      root:CreateRadio(("%s (%s)"):format(c.name, who), function() return a ~= nil and a.cat == c.id and a.who == who end,
        function() Given(id, c.id, who) end)
    elseif #members > 1 then
      any = true
      local sub = root:CreateButton(c.name)
      if sub then
        for _, m in ipairs(members) do
          sub:CreateRadio(m.name, function() return a ~= nil and a.cat == c.id and a.who == m.name end,
            function() Given(id, c.id, m.name) end)
        end
      end
    end
  end
  if not any then root:CreateTitle(L.MAIL_ITEM_NO_CATEGORY) end
  root:CreateDivider()
  root:CreateButton(L.MAIL_ITEM_RESET, function()
    M.ClearItem(id)
    Notice(L.MAIL_ITEM_CLEARED:format(ItemName(id)))
  end)
end

-- By the item: the menu's bottom right on its top left (else at the cursor).
local function OpenItemMenu(id, owner)
  local generator = function(region, root) ItemMenu(region, root, id) end
  if Menu and Menu.GetManager and MenuUtil.CreateRootMenuDescription and CreateAnchor and MenuVariants then
    local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
    generator(owner, desc)
    local menu = Menu.GetManager():OpenMenu(owner, desc, CreateAnchor("BOTTOMRIGHT", owner, "TOPLEFT", 0, 0))
    if menu then return menu end
  end
  if MenuUtil and MenuUtil.CreateContextMenu then return MenuUtil.CreateContextMenu(owner, generator) end
end
M.OpenItemMenu = OpenItemMenu -- (for the tests)

---------------------------------------------------------------------------
-- An item dropped on a name of the recipients window (or clicked on it, held)
---------------------------------------------------------------------------
function M.Dropped(entry)
  if not (entry and GetCursorInfo) then return false end
  local kind, id = GetCursorInfo()
  if kind ~= "item" or type(id) ~= "number" then return false end
  ClearCursor()
  Given(id, nil, entry.name)
  return true
end

---------------------------------------------------------------------------
-- A character chosen: its items attached, once
---------------------------------------------------------------------------
local skipped = {} -- stacks taken off this mail by hand ("bag:slot"): not attached again until it is sent or shut
local from = {}    -- the attachments made here: index -> "bag:slot"
local queue, running = {}, false

local function Where(bag, slot) return bag .. ":" .. slot end

local function FreeAttachment(taken)
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    if not taken[i] and not (HasSendMailItem and HasSendMailItem(i)) then return i end
  end
end

local function Step()
  local job = table.remove(queue, 1)
  if not job or not (SendMailFrame and SendMailFrame:IsShown()) then
    running = false
    wipe(queue)
    return
  end
  local id, locked = SlotInfo(job.bag, job.slot)
  if id == job.id and not locked and not (GetCursorInfo and GetCursorInfo()) then
    local index = FreeAttachment(job.taken)
    if not index then -- (the mail full: this one and the rest to the extra slots, MailExtra.lua)
      running = false
      local rest = { job }
      for _, j in ipairs(queue) do rest[#rest + 1] = j end
      wipe(queue)
      if M.Overflow then M.Overflow(rest) end
      return
    end
    job.taken[index] = true
    from[index] = Where(job.bag, job.slot)
    C_Container.PickupContainerItem(job.bag, job.slot)
    ClickSendMailItemButton(index)
    if GetCursorInfo and GetCursorInfo() then ClearCursor() end
  end
  if #queue > 0 then C_Timer.After(STEP, Step) else running = false end
end

function M.Chosen(name)
  if not (M.Key(name) and C_Container and C_Container.GetContainerNumSlots and ClickSendMailItemButton) then return 0 end
  local taken, found = {}, 0
  for _, bag in ipairs(Bags()) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local id, locked = SlotInfo(bag, slot)
      if id and not locked and not skipped[Where(bag, slot)] and not (M.Queued and M.Queued(bag, slot))
        and M.ItemGoesTo(M.db.items[id], name) then
        queue[#queue + 1] = { bag = bag, slot = slot, id = id, taken = taken, to = name }
        found = found + 1
      end
    end
  end
  if found > 0 and not running then
    running = true
    Step()
  end
  return found
end

-- (for MailExtra.lua)
M.Bags, M.SlotInfo, M.Notice = Bags, SlotInfo, Notice
function M.Skip(bag, slot) skipped[Where(bag, slot)] = true end

-- the To field: Enter or Tab on a name
local function Typed(box)
  local text = box and box.GetText and box:GetText()
  if M.Key(text) then M.Chosen(text) end
end

-- a stack taken off the mail (right-click on it): that one not attached again for this mail
local function TakenOff(button, mouse)
  if mouse ~= "RightButton" or not (button and button.GetID) then return end
  local index = button:GetID()
  if from[index] then skipped[from[index]] = true end
  from[index] = nil
end

local hooked = false
local function Hook()
  if hooked or not SendMailFrame then return end
  hooked = true
  if SendMailNameEditBox then
    SendMailNameEditBox:HookScript("OnEnterPressed", Typed)
    SendMailNameEditBox:HookScript("OnTabPressed", Typed)
  end
  for i = 1, ATTACHMENTS_MAX_SEND or 12 do
    local b = _G["SendMailAttachment" .. i]
    if b then b:HookScript("PreClick", TakenOff) end
  end
end

-- the mailbox opened and shut, a mail sent: what was taken off starts again
local shown, closed, sent = M.OnShow, M.OnClose, M.Changed
function M.OnShow()
  Hook()
  wipe(skipped)
  wipe(from)
  if shown then shown() end
end
function M.OnClose()
  wipe(skipped)
  wipe(from)
  wipe(queue)
  running = false
  if closed then closed() end
end
function M.Changed()
  wipe(skipped)
  wipe(from)
  if sent then sent() end
end

---------------------------------------------------------------------------
-- The middle-click, and the bag item's tooltip
---------------------------------------------------------------------------
local clicks = CreateFrame("Frame")
clicks:RegisterEvent("PLAYER_LOGIN")
clicks:SetScript("OnEvent", function(self, event, button)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("GLOBAL_MOUSE_UP")
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
        if tip ~= GameTooltip or type(data) ~= "table" or type(data.id) ~= "number" then return end
        local target = M.ItemTarget(data.id)
        if target then tip:AddLine(L.MAIL_ITEM_TIP:format(target), .4, .78, 1) end
      end)
    end
    return
  end
  if button ~= "MiddleButton" then return end
  local id, owner = ItemUnderMouse()
  if id then OpenItemMenu(id, owner) end
end)
