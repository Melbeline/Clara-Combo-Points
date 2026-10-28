-- Clara Combo Points - the mail module's extra slots. Once the mail's twelve slots are full, two
-- slots more end their second row, then a row more under them each time the last is full (up to six
-- rows), the window taller. What is put there goes in the next mails, sent by themselves once Send is
-- clicked: 12 a mail, to the same character, the subject followed by (2/3); the money and the C.O.D.
-- in the first only, each mail its postage. A mail that fails stops them, the rest kept. Items get
-- there dropped on them, right-clicked in the bags while the mail is full, or chosen for a character
-- (MailItems.lua). Right-click on one: taken off; a click: on the cursor. Should the game send a mail
-- on a click only, Send says which one is next (Send (2/3)).

local ADDON, ns = ...
local L = ns.L
local M = ns.Mail
if not M then return end

local PER_MAIL = ATTACHMENTS_MAX_SEND or 12
local PER_ROW = ATTACHMENTS_PER_ROW_SEND or 7
local GAME_ROWS = 2
local MAX_ROWS = 6
local ROOM = MAX_ROWS * PER_ROW - PER_MAIL -- the extra slots
local STEP = 0.1 -- between two attachments
local NEXT = 0.3 -- after a mail sent (the game empties the mail first)
local WAIT = 5   -- a mail sent without an answer: the game wants a click

local queue = {}     -- the stacks of the extra slots, in order: { bag, slot, id }
local chain          -- the mails of one send: { part, to, subject, armed, sending, waiting }
local manual = false -- the game sends on a click only (found this session)
local slots = {}     -- the extra slots' buttons
local grown, base, barPoint = false, nil, nil -- the window's height, its lower bar's anchor, before

local function Notice(text) if M.Notice then M.Notice(text) end end

local function Find(bag, slot)
  for i, q in ipairs(queue) do
    if q.bag == bag and q.slot == slot then return i end
  end
end
function M.Queued(bag, slot) return Find(bag, slot) ~= nil end

local function Attachments()
  local n = 0
  for i = 1, PER_MAIL do
    if HasSendMailItem(i) then n = n + 1 end
  end
  return n
end

-- the mail being written, and how many there are (while it is filled: what it still holds, off)
local function Parts()
  local part = chain and chain.part or 1
  local rest = #queue
  if chain and chain.filling then rest = math.max(0, rest - (PER_MAIL - Attachments())) end
  return part, part + math.ceil(rest / PER_MAIL)
end

local function Plain(subject) return (subject:gsub(" %(%d+/%d+%)$", "")) end
local function Numbered(subject, part, total)
  if total <= 1 then return subject end
  return ("%s (%d/%d)"):format(subject, part, total)
end

---------------------------------------------------------------------------
-- Send: which mail is next
---------------------------------------------------------------------------
local small = false
local function Fonts(button, on)
  if on == small then return end
  small = on
  button:SetNormalFontObject(on and GameFontNormalSmall or GameFontNormal)
  button:SetHighlightFontObject(on and GameFontHighlightSmall or GameFontHighlight)
  button:SetDisabledFontObject(on and GameFontDisableSmall or GameFontDisable)
end

local function Label()
  local button = SendMailMailButton
  if not button then return end
  local part, total = Parts()
  local text = SEND_LABEL or "Send"
  if total > 1 then text = ("%s (%d/%d)"):format(text, part, total) end
  if button:GetText() == text then return end
  Fonts(button, false)
  button:SetText(text)
  local fs = button:GetFontString()
  if total > 1 and fs and fs:GetStringWidth() > button:GetWidth() - 12 then Fonts(button, true) end
end

---------------------------------------------------------------------------
-- The extra slots
---------------------------------------------------------------------------
local Refresh

-- the bag slot last picked up (the stack an item on the cursor comes from)
local picked
local function Picked(id)
  if picked then
    local now, locked = M.SlotInfo(picked[1], picked[2])
    if now == id and locked then return picked[1], picked[2] end
  end
  for _, bag in ipairs(M.Bags()) do
    for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
      local now, locked = M.SlotInfo(bag, slot)
      if now == id and locked and not Find(bag, slot) then return bag, slot end
    end
  end
end

local function Add(bag, slot, id)
  if Find(bag, slot) then return true end
  if #queue >= ROOM then return false end
  queue[#queue + 1] = { bag = bag, slot = slot, id = id }
  return true
end

-- the item on the cursor, from the bags: to the extra slots
local function Dropped()
  local kind, id = GetCursorInfo()
  if kind ~= "item" or type(id) ~= "number" then return end
  local bag, slot = Picked(id)
  if not bag then return end -- (not from the bags)
  ClearCursor()
  if not Add(bag, slot, id) then Notice(L.MAIL_EXTRA_FULL:format(1)) end
  Refresh()
end

local function Clicked(self, mouse)
  if GetCursorInfo() then return Dropped() end
  local q = queue[self.index]
  if not q then return end
  table.remove(queue, self.index)
  if mouse == "RightButton" then
    M.Skip(q.bag, q.slot) -- (as one taken off the mail: not attached again for it)
  else
    C_Container.PickupContainerItem(q.bag, q.slot)
  end
  Refresh()
end

local function Enter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local q = queue[self.index]
  if q then
    GameTooltip:SetBagItem(q.bag, q.slot)
    local part, total = Parts()
    GameTooltip:AddLine(L.MAIL_EXTRA_PART:format(part + math.ceil(self.index / PER_MAIL), total), .4, .78, 1)
  else
    GameTooltip:SetText(L.MAIL_EXTRA_TIP, 1, 1, 1, 1, true)
  end
  GameTooltip:Show()
end

local function Leave() GameTooltip:Hide() end

local function Slot(i)
  if slots[i] then return slots[i] end
  local b = CreateFrame("Button", "ClaraMailExtraSlot" .. i, SendMailFrame)
  b.index = i
  b:SetSize(37, 37)
  local back = b:CreateTexture(nil, "BACKGROUND")
  back:SetTexture("Interface\\Buttons\\UI-Slot-Background")
  back:SetSize(39, 39)
  back:SetPoint("TOPLEFT", -1, 1)
  back:SetTexCoord(0, .640625, 0, .640625)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
  b.border:SetAllPoints()
  b.border:Hide()
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetJustifyH("RIGHT")
  b.count:SetPoint("BOTTOMRIGHT", -5, 2)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", Clicked)
  b:SetScript("OnDragStart", Clicked)
  b:SetScript("OnReceiveDrag", Dropped)
  b:SetScript("OnEnter", Enter)
  b:SetScript("OnLeave", Leave)
  slots[i] = b
  return b
end

local function Paint(b)
  local q = queue[b.index]
  local info = q and C_Container.GetContainerItemInfo(q.bag, q.slot)
  if type(info) ~= "table" or info.itemID ~= q.id then
    b.icon:Hide()
    b.border:Hide()
    b.count:SetText("")
    return
  end
  b.icon:SetTexture(info.iconFileID)
  b.icon:SetDesaturated(info.isLocked and true or false)
  b.icon:Show()
  b.count:SetText((info.stackCount or 1) > 1 and info.stackCount or "")
  local color = info.quality and info.quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.quality]
  if color then
    b.border:SetVertexColor(color.r, color.g, color.b)
    b.border:Show()
  else
    b.border:Hide()
  end
end

---------------------------------------------------------------------------
-- The rows: the game's two, then ours (its own sizes, as SendMailFrame_Update has them)
---------------------------------------------------------------------------
local function Rows()
  if not SendMailFrame:IsShown() or (#queue == 0 and Attachments() < PER_MAIL) then return nil end
  local want = PER_MAIL + #queue + (#queue < ROOM and 1 or 0) -- (and one empty, while there is room)
  return math.max(GAME_ROWS, math.min(MAX_ROWS, math.ceil(want / PER_ROW)))
end

local function Layout(rows)
  local first = SendMailAttachment1
  local iconx, icony = first:GetWidth() + 2, first:GetHeight() + 2
  local areax = SendMailFrame:GetWidth() - 14
  local gapx1 = math.floor((areax - iconx * PER_ROW) / (PER_ROW - 1))
  local gapx2 = math.floor((areax - iconx * PER_ROW - gapx1 * (PER_ROW - 1)) / 2)
  local indentx, indenty = 14 + gapx2, 82 + 6 + icony
  local tabx, taby = iconx + gapx1 - 2, icony + 5
  if not grown then
    grown = true
    base = MailFrame:GetHeight()
    barPoint = { SendMailHorizontalBarLeft:GetPoint(1) }
  end
  local grow = (rows - GAME_ROWS) * taby
  MailFrame:SetHeight(base + grow)
  -- the letter as with the game's two rows, its bars kept on the slots
  local areay = 12 + 5 + icony * GAME_ROWS
  local scroll = 249 - areay
  SendMailScrollFrame:SetHeight(scroll)
  SendMailScrollChildFrame:SetHeight(scroll)
  for _, paper in pairs({ SendStationeryBackgroundLeft or false, SendStationeryBackgroundRight or false }) do
    if paper then
      paper:SetHeight(math.min(scroll, 256))
      paper:SetTexCoord(0, 1, 0, math.min(scroll, 256) / 256)
    end
  end
  SendMailHorizontalBarLeft2:SetPoint("TOPLEFT", SendMailFrame, "BOTTOMLEFT", 2, 96 + areay + grow)
  local point, _, relPoint, x, y = unpack(barPoint)
  if point == "TOPLEFT" and relPoint == "TOPLEFT" then
    SendMailHorizontalBarLeft:SetPoint("TOPLEFT", SendMailFrame, "BOTTOMLEFT", x, base + y)
  end
  for k = 1, rows * PER_ROW do
    local b = k <= PER_MAIL and _G["SendMailAttachment" .. k] or Slot(k - PER_MAIL)
    local row, col = math.floor((k - 1) / PER_ROW), (k - 1) % PER_ROW
    b:SetPoint("TOPLEFT", SendMailFrame, "BOTTOMLEFT", indentx + tabx * col, indenty + taby * (rows - 1 - row))
    if k <= PER_MAIL then b:Enable() else Paint(b) end
    b:Show()
  end
  for i = rows * PER_ROW - PER_MAIL + 1, #slots do slots[i]:Hide() end
end

-- the window as the game has it
local function Restore(fromGame)
  if grown and not fromGame then Layout(GAME_ROWS) end
  for _, b in ipairs(slots) do b:Hide() end
  if not grown then return end
  grown = false
  MailFrame:SetHeight(base)
  local point, rel, relPoint, x, y = unpack(barPoint)
  if point then SendMailHorizontalBarLeft:SetPoint(point, rel, relPoint, x, y) end
end

local hooked = false

function Refresh(fromGame)
  if not hooked then return end
  local rows = Rows()
  if rows then Layout(rows) else Restore(fromGame) end
  Label()
end

-- the stacks still there (moved in the bags: found again; gone: off)
local function Check()
  for i = #queue, 1, -1 do
    local q = queue[i]
    if M.SlotInfo(q.bag, q.slot) ~= q.id then
      local found
      for _, bag in ipairs(M.Bags()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
          local id, locked = M.SlotInfo(bag, slot)
          if not found and id == q.id and not locked and not Find(bag, slot) then found = { bag, slot } end
        end
      end
      if found then q.bag, q.slot = found[1], found[2] else table.remove(queue, i) end
    end
  end
end

-- what a character's items the mail could not hold (MailItems.lua)
function M.Overflow(jobs)
  if not hooked then return end
  local left = 0
  for _, job in ipairs(jobs) do
    if not Add(job.bag, job.slot, job.id) then left = left + 1 end
  end
  if left > 0 then Notice(L.MAIL_EXTRA_FULL:format(left)) end
  Refresh()
end

---------------------------------------------------------------------------
-- The next mails
---------------------------------------------------------------------------
local function Manual()
  manual = true
  Label()
  if SendMailMailButton then SendMailMailButton:Enable() end
  Notice(L.MAIL_EXTRA_CLICK:format(Parts()))
end

local function Send()
  if not (chain and SendMailFrame:IsShown()) then return end
  Label()
  if manual then return Notice(L.MAIL_EXTRA_CLICK:format(Parts())) end
  local token = {}
  chain.armed, chain.waiting = true, token
  if SetSendMailCOD then SetSendMailCOD(0) end
  if SetSendMailMoney then SetSendMailMoney(0) end
  if SendMailMailButton then SendMailMailButton:Disable() end
  SendMail(chain.to, SendMailSubjectEditBox:GetText(), "")
  C_Timer.After(WAIT, function()
    if chain and chain.waiting == token then
      chain.armed, chain.waiting = nil, nil
      Manual()
    end
  end)
end

-- the next mail: the character, the subject numbered, up to 12 of the extra slots
local function Next()
  if not (chain and chain.to and SendMailFrame:IsShown()) then return end
  SendMailNameEditBox:SetText(chain.to)
  chain.filling = true
  SendMailSubjectEditBox:SetText(Numbered(chain.subject, Parts()))
  local taken, put = {}, 0
  local function Step()
    if not (chain and SendMailFrame:IsShown()) then
      if chain then chain.filling = nil end
      return
    end
    if put < PER_MAIL and #queue > 0 then
      if GetCursorInfo() then return C_Timer.After(STEP, Step) end -- (the cursor busy: a moment)
      local index
      for i = 1, PER_MAIL do
        if not taken[i] and not HasSendMailItem(i) then index = i break end
      end
      if index then
        local q = table.remove(queue, 1)
        local id, locked = M.SlotInfo(q.bag, q.slot)
        if id == q.id and not locked then
          taken[index] = true
          put = put + 1
          C_Container.PickupContainerItem(q.bag, q.slot)
          ClickSendMailItemButton(index)
          if GetCursorInfo() then ClearCursor() end
        end
        Refresh()
        return C_Timer.After(STEP, Step)
      end
    end
    chain.filling = nil
    if put == 0 then -- (nothing left of them)
      chain = nil
      return Refresh()
    end
    SendMailSubjectEditBox:SetText(Numbered(chain.subject, Parts()))
    Send()
  end
  Step()
end

-- Send clicked: the mail numbered, when there are more
local function Sending()
  if #queue == 0 and not chain then return end
  chain = chain or { part = 1 }
  chain.armed = true
  local subject = SendMailSubjectEditBox:GetText()
  if subject ~= "" then SendMailSubjectEditBox:SetText(Numbered(Plain(subject), Parts())) end
end

---------------------------------------------------------------------------
-- The hooks and the events
---------------------------------------------------------------------------
local function Hook()
  if hooked or not (MailFrame and SendMailFrame and SendMailFrame_Update and SendMailMailButton and SendMailAttachment1
    and SendMailScrollFrame and SendMailScrollChildFrame and SendMailHorizontalBarLeft and SendMailHorizontalBarLeft2) then
    return
  end
  hooked = true
  hooksecurefunc("SendMailFrame_Update", function() Refresh(true) end)
  SendMailFrame:HookScript("OnShow", function() Refresh() end) -- (the game's update comes just before)
  SendMailFrame:HookScript("OnHide", function() Restore(true) end)
  SendMailMailButton:HookScript("PreClick", Sending)
end

if C_Container and C_Container.PickupContainerItem then
  hooksecurefunc(C_Container, "PickupContainerItem", function(bag, slot) picked = { bag, slot } end)
end

-- a right-click in the bags while the mail is full: to the extra slots (not a bound item)
if C_Container and C_Container.UseContainerItem then
  hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
    if not (hooked and SendMailFrame:IsShown()) or Attachments() < PER_MAIL then return end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if type(info) ~= "table" or info.isBound then return end
    local id = info.itemID
    C_Timer.After(.2, function()
      local now, locked = M.SlotInfo(bag, slot)
      if now ~= id or locked or not SendMailFrame:IsShown() or Attachments() < PER_MAIL then return end
      if not Add(bag, slot, id) then Notice(L.MAIL_EXTRA_FULL:format(1)) end
      Refresh()
    end)
  end)
end

hooksecurefunc("SendMail", function(to, subject)
  if not (chain and chain.armed) then return end
  chain.armed = nil
  chain.to, chain.subject, chain.sending = to, Plain(subject or ""), true
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED",
  "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event, who, what)
  if event == "MAIL_SHOW" then
    Hook()
  elseif event == "MAIL_CLOSED" then
    wipe(queue)
    chain = nil
    if hooked then Restore(true) end
    Label()
  elseif event == "MAIL_SEND_SUCCESS" then
    if chain and chain.sending then
      chain.sending, chain.waiting = nil, nil
      if #queue > 0 then
        chain.part = chain.part + 1
        C_Timer.After(NEXT, Next)
      else
        if chain.part > 1 then Notice(L.MAIL_EXTRA_DONE:format(chain.part, chain.to)) end
        chain = nil
      end
    end
    Label()
  elseif event == "MAIL_FAILED" then
    if chain then chain.armed, chain.sending, chain.waiting = nil, nil, nil end
    Label()
  elseif event == "BAG_UPDATE_DELAYED" then
    if hooked and #queue > 0 and SendMailFrame:IsShown() then
      Check()
      Refresh()
    end
  elseif who == ADDON and chain and chain.waiting and tostring(what):find("SendMail", 1, true) then
    chain.armed, chain.waiting = nil, nil -- (ADDON_ACTION_BLOCKED / FORBIDDEN: a click wanted)
    Manual()
  end
end)
