-- The mail module's items (Modules/Mail/MailItems.lua): middle-click in the bags, given to a
-- character (a category, a character of it), dropped on a name; attached once when the character is
-- chosen; a stack taken off not attached again for that mail; dormant when the category goes
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false } }
MailFrame = CreateFrame("Frame", "MailFrame", UIParent)
MailFrame:SetSize(338, 424)
MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -300)
SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
SendMailFrame:SetAllPoints(MailFrame)
SendMailNameEditBox = CreateFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
SendMailNameEditBox:SetSize(109, 25)
SendMailNameEditBox:SetPoint("TOPLEFT", SendMailFrame, "TOPLEFT", 90, -30)
function SendMail() end
function UnitLevel() return 20 end
local realUnitName = UnitName
function UnitName(u) if u == "player" then return "Lola Elle" end return realUnitName(u) end

-- the bags, the cursor, the mail's attachments
local BAGS = { [0] = { [1] = { id = 2447, count = 20 }, [2] = { id = 2447, count = 8 }, [3] = { id = 765, count = 5 } },
  [1] = { [4] = { id = 2447, count = 3 } } }
local cursor, held
C_Container = {
  GetContainerNumSlots = function(bag) return (bag == 0 or bag == 1) and 16 or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local it = BAGS[bag] and BAGS[bag][slot]
    if it then return { itemID = it.id, stackCount = it.count, isLocked = it.locked or false } end
  end,
  PickupContainerItem = function(bag, slot) cursor = { bag = bag, slot = slot } end,
}
function GetCursorInfo()
  if cursor then return "item", BAGS[cursor.bag][cursor.slot].id end
  if held then return "item", held end
end
function ClearCursor() cursor, held = nil, nil end
ATTACHMENTS_MAX_SEND = 12
local attached = {}
function HasSendMailItem(i) return attached[i] ~= nil end
function ClickSendMailItemButton(i, clear)
  if clear then
    local a = attached[i]
    if a then BAGS[a.bag][a.slot].locked = nil end
    attached[i] = nil
  elseif cursor then
    attached[i] = cursor
    BAGS[cursor.bag][cursor.slot].locked = true
    cursor = nil
  end
end
function GetSendMailItem(i)
  local a = attached[i]
  if a then local it = BAGS[a.bag][a.slot] return "item", it.id, 0, it.count, 1 end
end
for i = 1, 12 do
  local b = CreateFrame("Button", "SendMailAttachment" .. i, SendMailFrame)
  b.GetID = function() return i end
end
C_Item = { GetItemNameByID = function(id) return ({ [2447] = "Peacebloom", [765] = "Silverleaf" })[id] end }
local focus
function GetMouseFoci() return { focus } end
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
local function Attached()
  local t = {}
  for i = 1, 12 do local a = attached[i] if a then t[#t + 1] = i .. ":" .. BAGS[a.bag][a.slot].id .. "/" .. a.bag .. "." .. a.slot end end
  return table.concat(t, " ")
end
local function ClearMail()
  for i = 1, 12 do ClickSendMailItemButton(i, true) end
end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local Mail = ns.Mail
local plants = Mail.AddCategory("Banque plantes")
Mail.SetCategory("Lola Rose", plants, true)
Mail.SetCategory("Chloe Moon", "bankalt", true)
Mail.SetCategory("Lia Love", "bankalt", true)
check(Mail.HasCategory("Lola Elle", "mainalt"), "this character Main/alt (level 20)")

-- a middle-click on a bag slot: its menu
local function BagSlot(bag, slot)
  local f = CreateFrame("Button", nil, UIParent)
  f.GetBagID = function() return bag end
  f.GetID = function() return slot end
  return f
end
focus = BagSlot(0, 1)
M.Fire("GLOBAL_MOUSE_UP", "LeftButton")
check(M.menu == nil, "a left click: nothing")
M.Fire("GLOBAL_MOUSE_UP", "MiddleButton")
local function Items()
  local t = {}
  for _, it in ipairs(M.menu and M.menu.items or {}) do
    local s = it.text or ("<" .. it.kind .. ">")
    if it.items and #it.items > 0 then
      local sub = {}
      for _, x in ipairs(it.items) do sub[#sub + 1] = x.text end
      s = s .. " > [" .. table.concat(sub, ", ") .. "]"
    end
    t[#t + 1] = s
  end
  return table.concat(t, " | ")
end
check(Items() == "Peacebloom | Main/alt (Lola Elle) | Bank alt > [Chloe Moon, Lia Love] | Banque plantes (Lola Rose) | <divider> | Reset",
  "middle-click: the categories with characters, several: a submenu (" .. Items() .. ")")
M.MenuPick("Banque plantes (Lola Rose)")
check(ClaraMailDB.items[2447] and ClaraMailDB.items[2447].cat == plants and ClaraMailDB.items[2447].who == "Lola Rose", "Peacebloom: to Lola Rose, through Banque plantes")
check(Mail.ItemTarget(2447) == "Lola Rose (Banque plantes)", "where it goes: " .. tostring(Mail.ItemTarget(2447)))
focus = BagSlot(0, 3)
M.Fire("GLOBAL_MOUSE_UP", "MiddleButton")
M.MenuSubPick("Bank alt", "Lia Love")
check(ClaraMailDB.items[765] and ClaraMailDB.items[765].who == "Lia Love" and ClaraMailDB.items[765].cat == "bankalt", "Silverleaf: to Lia Love, picked among the Bank alts")

-- a bag addon's button: its tooltip's item, when in the bags
GameTooltip.GetOwner = function(self) return self._owner end
GameTooltip.IsShown = function(self) return self._shown end
GameTooltip.GetItem = function(self) return "x", self._link end
local foreign = CreateFrame("Button", nil, UIParent)
focus = foreign
GameTooltip:SetOwner(foreign); GameTooltip._link = "|cffffffff|Hitem:765::::|h[Silverleaf]|h|r"; GameTooltip:Show()
M.Fire("GLOBAL_MOUSE_UP", "MiddleButton")
check(M.menu and M.menu.items[1].text == "Silverleaf", "a bag addon's button: the item of its tooltip")
M.menu:Close()
GameTooltip._link = "|cffffffff|Hitem:9999::::|h[Elsewhere]|h|r"
M.Fire("GLOBAL_MOUSE_UP", "MiddleButton")
check(M.menu == nil, "an item not in the bags (a tooltip elsewhere): nothing")
GameTooltip:Hide()

-- the mailbox: a name chosen, its items attached once
M.Fire("MAIL_SHOW")
Mail.toggle:Click()
local function Cell(name)
  for _, f in ipairs(M.frames) do
    if f._parent == Mail.panel and f._kind == "Button" and f.entry and f.entry.name == name and f:IsShown() then return f end
  end
end
Cell("Lola Rose"):Click("LeftButton")
Run()
check(SendMailNameEditBox:GetText() == "Lola Rose", "Lola Rose in To")
check(Attached() == "1:2447/0.1 2:2447/0.2 3:2447/1.4", "her three stacks of Peacebloom attached, not the Silverleaf (" .. Attached() .. ")")
-- one taken off by hand (right-click): not attached again for this mail
local b2 = _G.SendMailAttachment2
b2._scripts.PreClick(b2, "RightButton")
ClickSendMailItemButton(2, true)
BAGS[1][5] = { id = 2447, count = 1 } -- (another stack of it, come since)
Cell("Lola Rose"):Click("LeftButton")
Run()
check(Attached() == "1:2447/0.1 2:2447/1.5 3:2447/1.4", "chosen again: the stack taken off stays off, another of the item is taken (" .. Attached() .. ")")
BAGS[1][5] = nil
attached[2] = nil
-- sent: a new mail starts afresh
ClearMail()
M.Fire("MAIL_SEND_SUCCESS")
Cell("Lola Rose"):Click("LeftButton")
Run()
check(Attached() == "1:2447/0.1 2:2447/0.2 3:2447/1.4", "the next mail: all of them again")
ClearMail()

-- typed in To, then Enter
SendMailNameEditBox:SetText("lia love")
SendMailNameEditBox._scripts.OnEnterPressed(SendMailNameEditBox)
Run()
check(Attached() == "1:765/0.3", "typed in To, Enter: her Silverleaf (" .. Attached() .. ")")
ClearMail()
SendMailNameEditBox:SetText("Nobody Here")
SendMailNameEditBox._scripts.OnTabPressed(SendMailNameEditBox)
Run()
check(Attached() == "", "another name: nothing")

-- dormant: its category gone, or no longer the character's
Mail.DeleteCategory(plants)
Cell("Lola Rose"):Click("LeftButton")
Run()
check(Attached() == "" and ClaraMailDB.items[2447] and Mail.ItemTarget(2447) == nil, "Banque plantes deleted: kept, does nothing")
Mail.SetCategory("Lia Love", "bankalt", false)
Mail.Chosen("Lia Love")
Run()
check(Attached() == "", "Lia no longer a Bank alt: nothing")

-- dropped on a name (or clicked on it, held): to that character
held = 765
Mail.Changed()
Cell("Chloe Moon"):Click("LeftButton")
check(ClaraMailDB.items[765].who == "Chloe Moon" and ClaraMailDB.items[765].cat == nil and GetCursorInfo() == nil
  and SendMailNameEditBox:GetText() ~= "Chloe Moon", "an item dropped on Chloe Moon: hers (not put in To)")
Cell("Chloe Moon"):Click("LeftButton")
Run()
check(Attached() == "1:765/0.3", "Chloe chosen: her Silverleaf")
ClearMail()

-- the mail full: no more attached
for i = 1, 12 do attached[i] = { bag = 0, slot = 3 } end
BAGS[0][3].locked = nil
Mail.Chosen("Chloe Moon")
Run()
check(Attached():find("1:765/0.3", 1, true) ~= nil, "a full mail: nothing more taken")
for i = 1, 12 do attached[i] = nil end

-- Reset: no character any more (no question)
focus = BagSlot(0, 3)
M.Fire("GLOBAL_MOUSE_UP", "MiddleButton")
M.MenuPick("Reset")
check(ClaraMailDB.items[765] == nil and M.popup == nil, "Reset: no character any more, no question")
-- no category with characters: said so
Mail.ResetCategories()
for _, r in pairs(ClaraMailDB.recipients) do wipe(r.cats) end
M.Fire("GLOBAL_MOUSE_UP", "MiddleButton")
check(Items():find(ns.L.MAIL_ITEM_NO_CATEGORY, 1, true) ~= nil, "no category with characters: said so")
out("")
out(fails .. " failure(s)")
