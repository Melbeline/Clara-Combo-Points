-- The mail module (Modules/Mail): recipients by the To field, newest first, categories, sorting,
-- resets, export / import, the account's own characters as Main/alt from level 3
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- WoW Forever; every other module off
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false } }
-- the game's mail window: To, the send call
MailFrame = CreateFrame("Frame", "MailFrame", UIParent)
MailFrame:SetSize(338, 424)
MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -300)
SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame)
SendMailFrame:SetAllPoints(MailFrame)
SendMailNameEditBox = CreateFrame("EditBox", "SendMailNameEditBox", SendMailFrame)
SendMailNameEditBox:SetSize(109, 25)
SendMailNameEditBox:SetPoint("TOPLEFT", SendMailFrame, "TOPLEFT", 90, -30)
SendMailCancelButton = CreateFrame("Button", "SendMailCancelButton", SendMailFrame)
SendMailCancelButton:SetSize(80, 22)
SendMailCancelButton:SetPoint("BOTTOMRIGHT", SendMailFrame, "BOTTOMRIGHT", -7, 4)
local sent = {}
function SendMail(name, subject, body) sent[#sent + 1] = name end
local level, me = 2, "Lola Elle"
function UnitLevel() return level end
local realUnitName = UnitName
function UnitName(u) if u == "player" then return me end return realUnitName(u) end
local now = 1000
time = function() return now end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local Mail = ns.Mail
check(Mail and ns:QolState("mail") == "on", "the mail module runs (WoW Forever)")
check(type(ClaraMailDB) == "table" and #ClaraMailDB.categories == 4, "four categories to start with")
local names = {}
for _, c in ipairs(Mail.Categories()) do names[#names + 1] = c.name end
check(table.concat(names, ", ") == "Main/alt, Bank alt, Friend, Customer", "Main/alt, Bank alt, Friend, Customer (" .. table.concat(names, ", ") .. ")")
check(next(ClaraMailDB.recipients) == nil, "level 2: this character not in the list yet")

-- level 3: in the list, Main/alt
level = 3
M.Fire("PLAYER_LEVEL_UP", 3); while M.timers and #M.timers > 0 do M.RunTimer() end
check(Mail.HasCategory("Lola Elle", "mainalt"), "level 3: this character in the list, Main/alt")

-- mails sent: newest first
local function Send(name)
  now = now + 10
  SendMail(name, "s", "b")
  M.Fire("MAIL_SEND_SUCCESS")
end
M.Fire("MAIL_SHOW")
for _, n in ipairs({ "Charlotte Ella", "Lia Love", "Chloe Moon", "Lola Rose" }) do Send(n) end
Send("lia love") -- (the same character, lower case: kept as first written, moved first)
local function Order(sort)
  local list = Mail.Sorted(sort)
  local t = {}
  for _, r in ipairs(list) do t[#t + 1] = r.name end
  return table.concat(t, ", ")
end
check(Order("last") == "Lia Love, Lola Rose, Chloe Moon, Charlotte Ella", "Last sent: newest first; this character, logged in, left out (the game refuses mail to oneself) (" .. Order("last") .. ")")
M.Fire("MAIL_FAILED")

-- the window: closed at first; the button by To opens it
local panel, toggle = Mail.panel, Mail.toggle
check(panel and toggle and not panel:IsShown(), "built with the mailbox; the list shut at first")
local p, rel, rp, x = toggle:GetPoint(1)
check(rel == SendMailCancelButton and p == "BOTTOMRIGHT" and rp == "TOPRIGHT", "its button at the window's bottom right, above Cancel")
toggle:Click()
check(panel:IsShown() and ClaraMailDB.open == true, "a click: the list shown (kept open for next time)")
check(math.abs(panel:GetBottom() - (MailFrame:GetTop() + 2)) < 1 and math.abs(panel:GetLeft() - MailFrame:GetLeft()) < 1
  and math.abs(panel:GetRight() - MailFrame:GetRight()) < 1, "above the mail window, as wide")

-- the names: three to a row, newest top left
local cells = {}
for _, f in ipairs(M.frames) do
  if f._parent == panel and f._kind == "Button" and f._template == "UIPanelButtonTemplate" and f.entry ~= nil or (f._parent == panel and f._kind == "Button" and f.entry) then
    cells[#cells + 1] = f
  end
end
local function Shown()
  local list = {}
  for _, f in ipairs(M.frames) do
    if f._parent == panel and f._kind == "Button" and f.entry and f:IsShown() then list[#list + 1] = f end
  end
  table.sort(list, function(a, b)
    if math.abs(a:GetTop() - b:GetTop()) > 1 then return a:GetTop() > b:GetTop() end
    return a:GetLeft() < b:GetLeft()
  end)
  local t = {}
  for _, f in ipairs(list) do t[#t + 1] = f:GetText() end
  return table.concat(t, ", "), list
end
local text, list = Shown()
check(text == "Lia Love, Lola Rose, Chloe Moon, Charlotte Ella", "shown left to right, then the next row (" .. text .. ")")
check(math.abs(list[1]:GetTop() - list[3]:GetTop()) < 1 and list[4]:GetTop() < list[1]:GetTop() - 20, "three to a row")
check(list[1]:GetRight() <= panel:GetRight() - 12 and list[3]:GetRight() <= panel:GetRight() - 20, "inside the window, clear of its arrows")

-- the search box: only the names holding the text (case and accents ignored)
local search = panel.search
check(search ~= nil, "a search box under Sort by")
search:SetText("LOLA"); search._scripts.OnTextChanged(search)
check(Shown() == "Lola Rose", "searched \"LOLA\": Lola Rose (" .. Shown() .. ")")
search:SetText("chlo\195\169"); search._scripts.OnTextChanged(search)
check(Shown() == "Chloe Moon", "searched \"chloé\": Chloe (accents ignored) (" .. Shown() .. ")")
search:SetText("zz"); search._scripts.OnTextChanged(search)
check(Shown() == "", "nothing found: no name")
search:SetText(""); search._scripts.OnTextChanged(search)
check(Shown() == "Lia Love, Lola Rose, Chloe Moon, Charlotte Ella", "cleared: all the names again")
-- a click: in To
list[2]:Click("LeftButton")
check(SendMailNameEditBox:GetText() == "Lola Rose", "a click: the name in To")
-- its tooltip: its categories
Mail.SetCategory("Charlotte Ella", "friend", true)
list[4]._scripts.OnEnter(list[4])
check(GameTooltip._lines[1] == "Charlotte Ella" and GameTooltip._lines[2] == "Friend", "its tooltip: its categories")
Mail.SetCategory("Charlotte Ella", "friend", false)
list[1]._scripts.OnEnter(list[1])
check(GameTooltip._lines[2] == "No category", "none: said so")

-- a right-click: its categories, several at once
list[3]:Click("RightButton")
local items = {}
for _, it in ipairs(M.menu and M.menu.items or {}) do items[#items + 1] = it.text or ("<" .. it.kind .. ">") end
check(table.concat(items, " | ") == "Chloe Moon | Main/alt | Bank alt | Friend | Customer | <divider> | Reset category | Remove from the list",
  "right-click: its categories, reset, remove (" .. table.concat(items, " | ") .. ")")
M.MenuPick("Bank alt")
list[3]:Click("RightButton")
M.MenuPick("Friend")
check(Mail.HasCategory("Chloe Moon", "bankalt") and Mail.HasCategory("Chloe Moon", "friend"), "two categories at once")
list[1]:Click("RightButton")
M.MenuPick("Bank alt")

-- Sort by a category: its characters first, framed
local function Pick(owner, text)
  owner:Click()
  M.MenuPick(text)
end
local sortButton
for _, f in ipairs(M.frames) do if f._parent == panel and f.text and f._kind == "Button" and not f.entry and f.text.GetText then sortButton = f end end
check(sortButton and sortButton.text:GetText() == "Last sent", "Sort by: Last sent")
-- the header fits: Sort by, its list, Add/remove categories; the title clear of Export / Import
local function HeaderFits()
  local label = panel.sortLabel
  local exportB, importB
  for _, f in ipairs(M.frames) do
    if f._parent == panel and f._kind == "Button" and f.GetText then
      if f:GetText() == ns.L.MAIL_EXPORT then exportB = f elseif f:GetText() == ns.L.MAIL_IMPORT then importB = f end
    end
  end
  local manageB
  for _, f in ipairs(M.frames) do if f._parent == panel and f._kind == "Button" and f.GetText and f:GetText() == ns.L.MAIL_MANAGE then manageB = f end end
  local title = panel.TitleContainer and panel.TitleContainer.TitleText
  local titleRight = title and (title:GetLeft() + title:GetStringWidth()) or 0
  local ok = label:GetLeft() >= panel:GetLeft() + 10 and sortButton:GetLeft() >= label:GetLeft() + label:GetStringWidth()
    and manageB:GetLeft() >= sortButton:GetRight() and manageB:GetRight() <= panel:GetRight() - 10
    and exportB:GetRight() <= importB:GetLeft() + 1 and titleRight <= exportB:GetLeft()
  return ok, ("sort %d..%d, manage %d..%d of %d; title to %d, export from %d"):format(sortButton:GetLeft() - panel:GetLeft(),
    sortButton:GetRight() - panel:GetLeft(), manageB:GetLeft() - panel:GetLeft(), manageB:GetRight() - panel:GetLeft(),
    panel:GetWidth(), titleRight - panel:GetLeft(), exportB:GetLeft() - panel:GetLeft())
end
local fits, where = HeaderFits()
check(fits, "the header fits (" .. where .. ")")
Pick(sortButton, "Bank alt")
text, list = Shown()
check(text == "Lia Love, Chloe Moon, Lola Rose, Charlotte Ella", "Bank alt first (newest first among them), the rest after on a new row (" .. text .. ")")
check(math.abs(list[3]:GetTop() - list[1]:GetTop()) > 20, "the others start on the next row")
local framed = 0
for _, f in ipairs(M.frames) do if f._parent == panel and f.lines and f:IsShown() then framed = framed + 1 end end
check(framed == 1 and sortButton.text:GetText() == "Bank alt", "one framed row (the category's)")
Pick(sortButton, "Last sent")
-- the category buttons: one click, that category alone; again (or All): every name
local chip, allChip
for _, f in ipairs(M.frames) do
  if f._parent == panel and f.GetText and f:IsShown() then
    if f:GetText() == "Bank alt" and f ~= sortButton then chip = f end
    if f:GetText() == "All" then allChip = f end
  end
end
check(chip and allChip, "a button for each category, and All")
chip:Click()
check(Shown() == "Lia Love, Chloe Moon", "Bank alt's button: its characters alone (" .. Shown() .. ")")
chip:Click()
check(Shown() == "Lia Love, Lola Rose, Chloe Moon, Charlotte Ella", "clicked again: every name (" .. Shown() .. ")")
-- By category: each category in its block, its name above it, the others last
Mail.SetCategory("Lia Love", "friend", true)
Pick(sortButton, "By category")
local titlesShown = {}
for _, r in ipairs(M.regions) do
  if r._kind == "FontString" and r._parent == panel and r:IsShown() and (r:GetText() == "Bank alt" or r:GetText() == "Friend" or r:GetText() == "No category") then
    titlesShown[#titlesShown + 1] = r:GetText()
  end
end
check(#titlesShown == 3, "By category: the categories' names over their blocks, then No category (" .. table.concat(titlesShown, ", ") .. ")")
check(sortButton.text:GetText() == "By category", "Sort by shows it")
Mail.SetCategory("Lia Love", "friend", false)
Pick(sortButton, "Last sent")

-- Add/remove categories: add (a field, Enter or its button), delete, resets
local manage
for _, f in ipairs(M.frames) do if f._parent == panel and f._kind == "Button" and f.GetText and f:GetText() == "Add/remove categories" then manage = f end end
check(manage ~= nil, "Add/remove categories")
Pick(manage, "Add a category...")
check(M.popup and M.popup.info.hasEditBox, "a name asked")
M.popup.editBox = { GetText = function() return "  Banque plantes " end }
M.PopupClick(1)
local plants
for _, c in ipairs(Mail.Categories()) do if c.name == "Banque plantes" then plants = c.id end end
check(plants ~= nil, "Banque plantes added")
Pick(manage, "Add a category...")
M.popup.editBox = { GetText = function() return "banque PLANTES" end }
M.PopupClick(1)
check(#Mail.Categories() == 5, "the same name again: refused")
local function ByName(n) local _, l = Shown() for _, f in ipairs(l) do if f:GetText() == n then return f end end end
ByName("Charlotte Ella"):Click("RightButton")
M.MenuPick("Banque plantes")
check(Mail.HasCategory("Charlotte Ella", plants), "the new category in the right-click menu")
ClaraMailDB.items[2447] = { cat = plants, who = "Charlotte Ella" } -- (an item given to it: stage 2)
Pick(manage, "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14:14|t Banque plantes")
check(M.popup and M.popup.text:find("Banque plantes", 1, true) and M.popup.text:find("1 character", 1, true), "deleting asks, how many lose it")
M.PopupClick(1)
check(#Mail.Categories() == 4 and not Mail.HasCategory("Charlotte Ella", plants) and ClaraMailDB.items[2447].cat == plants,
  "deleted: gone from the character; the item keeps it, dormant")
Pick(manage, "Reset categories...")
check(M.popup and M.popup.info.showAlert and M.popup.text:find("NO character", 1, true), "reset categories: a big, explicit question")
M.PopupClick(1)
check(not Mail.HasCategory("Chloe Moon", "bankalt") and not Mail.HasCategory("Lola Elle", "mainalt") and ClaraMailDB.items[2447]
  and next(ClaraMailDB.recipients) ~= nil, "no character in any category; names and items kept")
M.Fire("PLAYER_LOGIN")
-- (this character again at the next login)
Mail.AddOwn()
check(Mail.HasCategory("Lola Elle", "mainalt"), "this character Main/alt again")

-- export / import
local line = Mail.Export()
check(line:sub(1, 6) == "CCPM1:", "export: a line of text")
local data = Mail.ReadExport("  " .. line .. "\n")
check(data and data.items[2447] and data.recipients["lia love"].name == "Lia Love", "read back whole")
check(Mail.ReadExport("CCP1:abc") == nil and select(2, Mail.ReadExport("nonsense")) == ns.L.MAIL_IMPORT_BAD, "other text: refused")
local importButton
for _, f in ipairs(M.frames) do if f._parent == panel and f._kind == "Button" and f.GetText and f:GetText() == "Import" then importButton = f end end
Pick(manage, "Reset everything...")
check(M.popup and M.popup.info.showAlert and M.popup.text:find("EVERYTHING", 1, true), "reset everything: a big, explicit question")
M.PopupClick(1)
check(next(ClaraMailDB.recipients) == nil and next(ClaraMailDB.items) == nil and #ClaraMailDB.categories == 4, "everything gone")
importButton:Click()
local box
for _, f in ipairs(M.frames) do if f.onAction and f:IsShown() then box = f end end
check(box ~= nil, "Import: a box to paste in")
box.onAction("nonsense")
check(box:IsShown() and M.popup == nil and next(ClaraMailDB.recipients) == nil, "other text: refused, nothing changed")
box.onAction(line)
check(M.popup and M.popup.info.showAlert and M.popup.text:find("Replace", 1, true), "asks before replacing")
M.PopupClick(1)
check(not box:IsShown(), "imported: the box shut")
check(ClaraMailDB.items[2447] and ClaraMailDB.recipients["lia love"] and ClaraMailDB.open == true, "imported: all back; the window's state kept")

-- many names: the wheel shows older ones
for i = 1, 20 do Send("Alt" .. i) end
Pick(sortButton, "Last sent")
text = Shown()
check(text:sub(1, 16) == "Alt20, Alt19, Al" and select(2, Shown())[15] ~= nil and #select(2, Shown()) == 15, "five rows of three")
panel._scripts.OnShow(panel)
local wheel
for _, f in ipairs(M.frames) do if f._parent == panel and f._scripts and f._scripts.OnMouseWheel and not f.entry then wheel = f end end
wheel._scripts.OnMouseWheel(wheel, -1)
text = Shown()
check(text:sub(1, 19) == "Alt17, Alt16, Alt15", "the wheel: a row further (" .. text:sub(1, 30) .. ")")
for _ = 1, 20 do wheel._scripts.OnMouseWheel(wheel, -1) end
local _, last = Shown()
check(last[#last]:GetText() == "Charlotte Ella", "down to the oldest")

-- the mailbox shut and opened again: the window as left
M.Fire("MAIL_CLOSED"); M.Fire("MAIL_SHOW")
check(panel:IsShown(), "opened again: the list too (left open)")
panel.close:Click()
check(not panel:IsShown() and ClaraMailDB.open == nil, "its close button: shut, and next time too")
M.Fire("MAIL_CLOSED"); M.Fire("MAIL_SHOW")
check(not panel:IsShown(), "next time: shut")

-- no room above the mail window: beside it
MailFrame:ClearAllPoints()
MailFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -60)
toggle:Click()
check(math.abs(panel:GetLeft() - (MailFrame:GetRight() + 4)) < 1 and math.abs(panel:GetTop() - MailFrame:GetTop()) < 1, "no room above: beside it")
out("")
out(fails .. " failure(s)")
