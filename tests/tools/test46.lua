-- The mail module's extra slots (Modules/Mail/MailExtra.lua): two slots more once the mail is full,
-- then a row more each time the last is full, the window taller; items dropped there or left over
-- from a character's; the next mails sent by themselves after Send (numbered, no money), or on a
-- click when the game wants one; a failure stops them
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false } }
SEND_LABEL = "Send"
ATTACHMENTS_MAX_SEND, ATTACHMENTS_PER_ROW_SEND = 12, 7
MailFrame = CreateFrame("Frame", "MailFrame", UIParent)
MailFrame:SetSize(338, 424)
MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -100)
SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
SendMailFrame:SetAllPoints(MailFrame)
SendMailNameEditBox = CreateFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
SendMailNameEditBox:SetSize(109, 25)
SendMailNameEditBox:SetPoint("TOPLEFT", SendMailFrame, "TOPLEFT", 90, -30)
SendMailSubjectEditBox = CreateFrame("EditBox", "SendMailSubjectEditBox", SendMailFrame)
SendMailScrollFrame = CreateFrame("Frame", "SendMailScrollFrame", SendMailFrame)
SendMailScrollChildFrame = CreateFrame("Frame", "SendMailScrollChildFrame", SendMailScrollFrame)
SendMailHorizontalBarLeft = SendMailFrame:CreateTexture("SendMailHorizontalBarLeft", "BACKGROUND")
SendMailHorizontalBarLeft:SetPoint("TOPLEFT", SendMailFrame, "TOPLEFT", 2, -337)
SendMailHorizontalBarLeft2 = SendMailFrame:CreateTexture("SendMailHorizontalBarLeft2", "BACKGROUND")
SendStationeryBackgroundLeft = SendMailScrollFrame:CreateTexture("SendStationeryBackgroundLeft", "BACKGROUND")
SendStationeryBackgroundRight = SendMailScrollFrame:CreateTexture("SendStationeryBackgroundRight", "BACKGROUND")
SendMailMailButton = CreateFrame("Button", "SendMailMailButton", SendMailFrame)
SendMailMailButton:SetSize(80, 22)
SendMailMailButton:SetText("Send")
function UnitLevel() return 20 end
local realUnitName = UnitName
function UnitName(u) if u == "player" then return "Lola Elle" end return realUnitName(u) end

-- the bags (a stack: locked while on the cursor or in the mail), the cursor, the mail
local BAGS = {}
for slot = 1, 16 do BAGS[slot] = { id = 2447, count = slot } end -- (Peacebloom: 16 stacks, its count its slot)
BAGS[17] = { id = 765, count = 5 }
BAGS[18] = { id = 6948, count = 1, bound = true }
local function Bag(bag, slot) return bag == 0 and BAGS[slot] or nil end
local cursor
C_Container = {
  GetContainerNumSlots = function(bag) return bag == 0 and 20 or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local it = Bag(bag, slot)
    if it then return { itemID = it.id, stackCount = it.count, isLocked = it.locked or false, iconFileID = 100 + it.id,
      quality = 1, isBound = it.bound or false } end
  end,
  PickupContainerItem = function(bag, slot)
    local it = Bag(bag, slot)
    if it and not it.locked then cursor = slot; it.locked = true end
  end,
  UseContainerItem = function() end, -- (the mail full: nothing)
}
function GetCursorInfo() if cursor then return "item", BAGS[cursor].id end end
function ClearCursor() if cursor then BAGS[cursor].locked = nil end cursor = nil end
local attached = {}
function HasSendMailItem(i) return attached[i] ~= nil end
function ClickSendMailItemButton(i, clear)
  if clear then
    if attached[i] then BAGS[attached[i]].locked = nil end
    attached[i] = nil
  elseif cursor then
    attached[i] = cursor
    cursor = nil
  end
end
for i = 1, 12 do
  local b = CreateFrame("Button", "SendMailAttachment" .. i, SendMailFrame)
  b:SetSize(37, 37)
  b.GetID = function() return i end
end
-- the game's update: two rows, the bar under the letter
function SendMailFrame_Update()
  for i = 1, 12 do
    local row, col = math.floor((i - 1) / 7), (i - 1) % 7
    _G["SendMailAttachment" .. i]:SetPoint("TOPLEFT", SendMailFrame, "BOTTOMLEFT", 15 + 45 * col, 127 + 44 * (1 - row))
  end
  SendMailScrollFrame:SetHeight(154)
  SendMailHorizontalBarLeft2:SetPoint("TOPLEFT", SendMailFrame, "BOTTOMLEFT", 2, 191)
end
C_Item = { GetItemNameByID = function(id) return ({ [2447] = "Peacebloom", [765] = "Silverleaf" })[id] end }
GameTooltip.SetBagItem = function(self, bag, slot) self._bagItem = bag .. ":" .. slot end

-- the mail sent: answered by the game (or not); its items gone from the bags; the mail emptied
local sent, answer = {}, true
local function Reset()
  for i = 1, 12 do
    if attached[i] then BAGS[attached[i]] = nil end
    attached[i] = nil
  end
  SendMailNameEditBox:SetText("")
  SendMailSubjectEditBox:SetText("")
  SendMailFrame_Update()
end
function SendMail(to, subject, body)
  local items = {}
  for i = 1, 12 do if attached[i] then items[#items + 1] = attached[i] end end
  sent[#sent + 1] = { to = to, subject = subject, body = body, items = table.concat(items, ",") }
  if answer then C_Timer.After(0, function() Reset(); M.Fire("MAIL_SEND_SUCCESS") end) end
end
local cod, money = 0, 0
function SetSendMailCOD(v) cod = v end
function SetSendMailMoney(v) money = v end
-- Send clicked: the game's own (its PreClick first)
local function ClickSend(subject)
  if subject then SendMailSubjectEditBox:SetText(subject) end
  local pre = SendMailMailButton._scripts and SendMailMailButton._scripts.PreClick
  if pre then pre(SendMailMailButton, "LeftButton") end
  SendMail(SendMailNameEditBox:GetText(), SendMailSubjectEditBox:GetText(), "a letter")
end

local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
local function Attach(slot)
  for i = 1, 12 do
    if not attached[i] then
      C_Container.PickupContainerItem(0, slot)
      ClickSendMailItemButton(i)
      return
    end
  end
end
local function Extra(i) return _G["ClaraMailExtraSlot" .. i] end
local function ExtraShown()
  local n = 0
  for i = 1, 30 do if Extra(i) and Extra(i):IsShown() then n = n + 1 end end
  return n
end
local function H() return math.floor(MailFrame:GetHeight() + .5) end
local function Point(f) local _, _, _, x, y = f:GetPoint(1) return x .. "," .. y end
local function Queued()
  local t = {}
  for i = 1, 30 do
    local b = Extra(i)
    if b and b:IsShown() and b.icon:IsShown() then t[#t + 1] = b.count:GetText() end
  end
  return table.concat(t, " ")
end

-- the bag window, as the game draws it: an item greyed while locked (SetItemButtonDesaturated)
function GetItemButtonIconTexture(button) return button.icon end
function SetItemButtonDesaturated(button, desaturated)
  local icon = GetItemButtonIconTexture(button)
  if icon then icon:SetDesaturated(desaturated) end
end
local bagFrame = CreateFrame("Frame", "ContainerFrame1", UIParent)
bagFrame.buttons = {}
for slot = 1, 20 do
  local b = CreateFrame("Button", nil, bagFrame)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.GetBagID = function() return 0 end
  b.GetID = function() return slot end
  bagFrame.buttons[slot] = b
end
function bagFrame:EnumerateValidItems() return ipairs(self.buttons) end
function ContainerFrameUtil_EnumerateContainerFrames() return ipairs({ bagFrame }) end
local function GameUpdate() -- (the game redraws its bag: each item greyed while locked)
  for slot, b in ipairs(bagFrame.buttons) do SetItemButtonDesaturated(b, BAGS[slot] ~= nil and BAGS[slot].locked == true) end
end
local function Grey(slot) return bagFrame.buttons[slot].icon._desat == true end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local Mail, L = ns.Mail, ns.L
M.Fire("MAIL_SHOW")
SendMailFrame:Show()
SendMailFrame_Update()

-- a mail not full: as the game has it
for slot = 1, 11 do Attach(slot) end
SendMailFrame_Update()
check(ExtraShown() == 0 and H() == 424, "11 items: no slot more, the window as it is")
-- full: two slots more on the second row
Attach(12)
SendMailFrame_Update()
check(ExtraShown() == 2 and Point(Extra(1)) == "240,127" and Point(Extra(2)) == "285,127" and H() == 424,
  "12 items: two slots more end the second row (" .. ExtraShown() .. ", " .. Point(Extra(1)) .. ")")
check(SendMailMailButton:GetText() == "Send", "Send as it is (" .. tostring(SendMailMailButton:GetText()) .. ")")

-- an item dropped on one: there; then the other full too: a third row, the window taller
C_Container.PickupContainerItem(0, 13)
Extra(1)._scripts.OnReceiveDrag(Extra(1))
check(GetCursorInfo() == nil and not BAGS[13].locked and Queued() == "13", "dropped: in the slot more, back in the bag (" .. Queued() .. ")")
check(SendMailMailButton:GetText() == "Send (1/2)", "Send says there are two mails (" .. tostring(SendMailMailButton:GetText()) .. ")")
C_Container.PickupContainerItem(0, 14)
Extra(2)._scripts.OnClick(Extra(2), "LeftButton")
check(Grey(13) and Grey(14) and not Grey(15), "the items in the slots more greyed in the bag, as those in the mail")
GameUpdate()
check(Grey(13) and Grey(14) and Grey(1) and not Grey(15), "the game redraws its bag: kept grey")
check(Queued() == "13 14" and ExtraShown() == 9 and H() == 468,
  "the second row full: a third row, the window 44 taller (" .. ExtraShown() .. ", " .. H() .. ")")
check(Point(SendMailAttachment1) == "15,215" and Point(SendMailAttachment8) == "15,171" and Point(Extra(3)) == "15,127",
  "the game's rows up a row, the new one under them (" .. Point(SendMailAttachment1) .. ", " .. Point(Extra(3)) .. ")")
local _, _, _, _, barY = SendMailHorizontalBarLeft:GetPoint(1)
local _, _, _, _, bar2Y = SendMailHorizontalBarLeft2:GetPoint(1)
check(math.floor(barY + .5) == 87 and select(3, SendMailHorizontalBarLeft:GetPoint(1)) == "BOTTOMLEFT" and bar2Y == 235,
  "the bars kept on the slots (" .. tostring(barY) .. ", " .. tostring(bar2Y) .. ")")
-- the game updates the mail meanwhile: kept
SendMailFrame_Update()
check(Point(SendMailAttachment1) == "15,215" and H() == 468, "the game's update: the rows kept")
-- a tooltip: the item, and which mail
Extra(2)._scripts.OnEnter(Extra(2))
check(GameTooltip._bagItem == "0:14", "its tooltip: the bag's item")
Extra(4)._scripts.OnEnter(Extra(4))
-- right-click: off; the third row gone, the window back
Extra(2)._scripts.OnClick(Extra(2), "RightButton")
check(Grey(13) and not Grey(14), "taken off: its colour back")
check(Queued() == "13" and ExtraShown() == 2 and H() == 424 and Point(SendMailAttachment1) == "15,171",
  "right-click: taken off, back to two rows (" .. ExtraShown() .. ", " .. Point(SendMailAttachment1) .. ")")
-- a click with nothing held: on the cursor
Extra(1)._scripts.OnClick(Extra(1), "LeftButton")
check(Queued() == "" and cursor == 13, "a click: on the cursor")
ClearCursor()

-- a character's items, more than the mail holds: the rest to the slots more
local plants = Mail.AddCategory("Plants")
Mail.SetCategory("Lola Rose", plants, true)
Mail.AssignItem(2447, plants, "Lola Rose")
for i = 1, 12 do ClickSendMailItemButton(i, true) end
SendMailFrame_Update()
check(ExtraShown() == 0, "the mail emptied: no slot more")
Mail.Chosen("Lola Rose")
Run()
SendMailFrame_Update()
check(Queued() == "13 15 16" and ExtraShown() == 9,
  "16 stacks: 12 in the mail, the rest in the slots more, not the one taken off (" .. Queued() .. ")")

-- Send: numbered, the next one sent by itself (same character, no money, numbered)
SendMailNameEditBox:SetText("Lola Rose")
ClickSend("Plants")
check(sent[1].subject == "Plants (1/2)" and sent[1].body == "a letter", "the first: Plants (1/2) (" .. sent[1].subject .. ")")
money, cod = 500, 0
Run()
check(#sent == 2 and sent[2].to == "Lola Rose" and sent[2].subject == "Plants (2/2)" and sent[2].body == ""
  and sent[2].items == "13,15,16" and money == 0, "the second sent by itself: " .. (sent[2] and (sent[2].subject .. " [" .. sent[2].items .. "]") or "none"))
check(Queued() == "" and SendMailMailButton:GetText() == "Send" and ExtraShown() == 0 and H() == 424,
  "all sent: the slots more gone, Send as it is")

-- the game wants a click: Send says which one
answer = false
for slot = 1, 12 do BAGS[slot] = { id = 2447, count = slot } end
BAGS[13] = { id = 765, count = 5 }
for slot = 1, 12 do Attach(slot) end
SendMailFrame_Update()
C_Container.PickupContainerItem(0, 13)
Extra(1)._scripts.OnReceiveDrag(Extra(1))
SendMailNameEditBox:SetText("Lia Love")
ClickSend("Herbs")
Reset(); M.Fire("MAIL_SEND_SUCCESS")
Run()
check(#sent == 4 and sent[4].subject == "Herbs (2/2)" and SendMailMailButton:GetText() == "Send (2/2)",
  "no answer: Send (2/2), the next mail ready (" .. tostring(SendMailMailButton:GetText()) .. ")")
check(SendMailNameEditBox:GetText() == "Lia Love" and attached[1] == 13, "the next mail ready: Lia Love, the Silverleaf")
-- the click: sent, done
answer = true
ClickSend()
Run()
check(#sent == 5 and sent[5].subject == "Herbs (2/2)" and SendMailMailButton:GetText() == "Send", "clicked: the last one, done")

-- a failure: stopped, the rest kept
for slot = 1, 12 do BAGS[slot] = { id = 2447, count = slot } end
BAGS[13] = { id = 765, count = 5 }
for slot = 1, 12 do Attach(slot) end
SendMailFrame_Update()
C_Container.PickupContainerItem(0, 13)
Extra(1)._scripts.OnReceiveDrag(Extra(1))
answer = false
SendMailNameEditBox:SetText("Nobody")
ClickSend("Stuff")
M.Fire("MAIL_FAILED")
Run()
check(#sent == 6 and Queued() == "5" and SendMailMailButton:GetText() == "Send (1/2)", "failed: nothing more sent, the rest kept")
-- the mailbox shut: all gone
check(Grey(5), "the rest waiting in the slots more: grey")
M.Fire("MAIL_CLOSED")
SendMailFrame:Hide()
-- (the game gives the mail's items back as it shuts, and redraws its bag)
for i = 1, 12 do if attached[i] and BAGS[attached[i]] then BAGS[attached[i]].locked = nil end attached[i] = nil end
GameUpdate()
check(not Grey(5) and not Grey(1), "the mailbox shut: their colour back (" .. tostring(BAGS[5] and BAGS[5].locked) .. ")")
check(H() == 424 and SendMailMailButton:GetText() == "Send", "shut: the window as it was")

-- a bound item, right-clicked while full: not taken (an unbound one is)
SendMailFrame:Show()
for i = 1, 12 do attached[i] = nil end
for slot = 1, 12 do BAGS[slot] = { id = 2447, count = slot } BAGS[slot].locked = nil end
for slot = 1, 12 do Attach(slot) end
SendMailFrame_Update()
C_Container.UseContainerItem(0, 18)
Run()
check(Queued() == "", "a bound item right-clicked: not taken")
C_Container.UseContainerItem(0, 17)
Run()
check(Queued() == "5", "an item right-clicked while the mail is full: in the slots more (" .. Queued() .. ")")
out("")
out(fails .. " failure(s)")
