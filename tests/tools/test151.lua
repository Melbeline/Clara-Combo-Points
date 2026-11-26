-- The mail recipients arranged by dragging (Modules/Mail): a name dragged, a copy of its button following the mouse,
-- the list showing where it would go (the name there faint and lit, the others moved aside); dropped on the names:
-- the player's arrangement kept, Last sent becoming My order; dropped away or where it was: nothing changed; held below
-- the names: the list scrolls; the click of the release not taken as a click; Last sent: newest first again, the
-- arrangement kept; the name mailed last: always first in My order (top left), the others in the arrangement; By category: its blocks in that order; the box off: no
-- drag; My order and By category kept through a reload (Clean).
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
function UnitLevel() return 10 end
local NAMES = { "Lia Moon", "Lola Elle", "Ana Sun", "Bea Star", "Cid Rock", "Dan Leaf", "Eve Rain", "Fay Wind",
  "Gus Hill", "Hal Snow", "Ivy Dale", "Jon Mist", "Kai Fern", "Lex Sand", "Mae Glow", "Ned Ash", "Ola Bay", "Pia Dew" }
local recipients = {}
for i, n in ipairs(NAMES) do recipients[n:lower()] = { name = n, last = 1000 - i, cats = {} } end
recipients["ana sun"].cats.friend = true; recipients["eve rain"].cats.friend = true
ClaraMailDB = { recipients = recipients }
local now = 100
GetTime = function() return now end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Fire("MAIL_SHOW")
local Mail = ns.Mail
local panel = Mail.panel
Mail.toggle:Click()
check(panel:IsShown(), "the window open")

-- The cells, in their order (rows of three); the names they show
local cells = {}
for _, f in ipairs(M.frames) do
  if f._parent == panel and f._kind == "Button" and f.RegisterForDrag and f:GetScript("OnDragStart") then cells[#cells + 1] = f end
end
local function Shown()
  local t = {}
  for _, b in ipairs(cells) do if b:IsShown() and b.entry then t[#t + 1] = b.entry.name end end
  return table.concat(t, ",")
end
local function Cell(name) for _, b in ipairs(cells) do if b:IsShown() and b.entry and b.entry.name == name then return b end end end
local ghost
local function Start(name)
  local b = Cell(name)
  M.CursorOn(b); M.mouseDown = true
  b:GetScript("OnDragStart")(b)
  ghost = _G.ClaraMailDragGhost
  return b
end
-- The mouse over the n-th place of the names (where the name dragged would go)
local function Move(slot)
  M.CursorOn(cells[slot])
  Mail.DragFollow(ghost, 0.01)
end
local function Drop(b)
  M.mouseDown = false
  b:GetScript("OnDragStop")(b)
end
local L = ns.L

out("== Last sent")
check(Shown():sub(1, 26) == "Lia Moon,Lola Elle,Ana Sun", "newest first (" .. Shown():sub(1, 40) .. ")")
check(Mail.db.sort == "last", "sorted by Last sent")

out("== dragged: where it would go, shown")
local from = Start("Ana Sun")
check(ghost and ghost:IsShown() and ghost:GetText() == "Ana Sun", "a copy of its button follows the mouse")
check(Cell("Ana Sun"):GetAlpha() < 1, "at its place: faint")
Move(1)
check(Shown():sub(1, 26) == "Lia Moon,Ana Sun,Lola Elle", "over the first place: second, the name mailed last staying first (" .. Shown():sub(1, 30) .. ")")
check(Cell("Ana Sun"):GetAlpha() < 1, "where it would go: faint")
check(Mail.db.sort == "last" and #Mail.db.order == 0, "nothing kept yet")
Move(3)
check(Shown():sub(1, 35) == "Lia Moon,Lola Elle,Ana Sun,Bea Star", "back over its own place: as it was")
Move(4)
check(Shown():sub(1, 35) == "Lia Moon,Lola Elle,Bea Star,Ana Sun", "over the fourth: there, after Bea Star")

out("== dropped")
Drop(from)
check(not ghost:IsShown(), "the copy gone")
check(Shown():sub(1, 35) == "Lia Moon,Lola Elle,Bea Star,Ana Sun", "it stays there")
check(Mail.db.sort == "custom" and Mail.db.order[4] == "ana sun", "kept: My order (" .. tostring(Mail.db.sort) .. ")")
check(Cell("Ana Sun"):GetAlpha() == 1, "no longer faint")
local chosen = SendMailNameEditBox:GetText()
Cell("Bea Star"):Click()
check(SendMailNameEditBox:GetText() == chosen, "the release's click: not a click on a name")
now = now + 1
Cell("Bea Star"):Click()
check(SendMailNameEditBox:GetText() == "Bea Star", "a click later: the name in To")

out("== dropped where it was, or away")
local order = table.concat(Mail.db.order, ",")
from = Start("Lia Moon"); Move(2); Move(1); Drop(from)
check(table.concat(Mail.db.order, ",") == order, "back where it was: nothing changed")
from = Start("Lia Moon"); Move(2)
M.cursorX, M.cursorY = 5, 5 -- (far from the window)
Mail.DragFollow(ghost, 0.01)
check(Shown():sub(1, 18) == "Lia Moon,Lola Elle", "away from the names: shown as it was")
Drop(from)
check(table.concat(Mail.db.order, ",") == order, "dropped away: nothing changed")

out("== held below the names: the list scrolls")
from = Start("Lia Moon")
local last = cells[#cells]
M.CursorOn(last); M.cursorY = M.cursorY - 22 -- (under the last row)
local before = Shown()
for _ = 1, 40 do now = now + 0.01; Mail.DragFollow(ghost, 0.1) end
check(Shown() ~= before, "scrolled")
M.mouseDown = false; Mail.DragFollow(ghost, 0.01) -- (let go: seen by the copy)
check(not ghost:IsShown(), "let go: the drag over")
check(Mail.db.order[1] ~= "lia moon", "dropped further down: moved")

out("== the sorts")
Mail.db.sort = "last"; Mail.OnShow() -- (the mailbox opened again: at the top)
local top = Shown():sub(1, 26)
check(top == "Lia Moon,Lola Elle,Ana Sun", "Last sent: newest first again (" .. top .. ")")
check(#Mail.db.order >= #NAMES, "the arrangement kept")
Mail.db.sort = "custom"; Mail.Changed()
check(Shown():sub(1, 18) == "Lia Moon,Lola Elle", "My order: the name mailed last first (moved down by hand all the same), then the arrangement (" .. Shown():sub(1, 30) .. ")")
Mail.Record("Zed New"); Mail.Changed()
check(Shown():sub(1, 17) == "Zed New,Lola Elle", "a name mailed since: first, the one before back in its place (" .. Shown():sub(1, 30) .. ")")
Mail.Record("Bea Star"); Mail.Changed()
local mine = Shown()
check(mine:sub(1, 8) == "Bea Star" and mine:find("Zed New", 1, true) > 9, "a name already in the arrangement, mailed: first (" .. mine:sub(1, 30) .. ")")
Mail.db.sort = "bycat"; Mail.Changed()
local s = Shown()
check(s:find("Ana Sun,Eve Rain", 1, true) or s:find("Eve Rain,Ana Sun", 1, true), "By category: its block")
Mail.db.order = Mail.Moved(Mail.db.order, "ana sun", "eve rain", true); Mail.Changed()
check(Shown():find("Eve Rain,Ana Sun", 1, true), "its names in the arrangement's order")

out("== kept through a reload")
if not Mail.Clean then -- (a version without the saved data's check exposed)
  Mail.Clean = function(t) local saved = ClaraMailDB; ClaraMailDB = t; Mail.Init(); local c = Mail.db; ClaraMailDB = saved; Mail.Init(); return c end
end
for _, sort in ipairs({ "custom", "bycat" }) do
  local c = Mail.Clean({ recipients = Mail.db.recipients, categories = Mail.db.categories, sort = sort, order = Mail.db.order })
  check(c.sort == sort, sort .. " kept")
end
local c = Mail.Clean({ recipients = Mail.db.recipients, order = { "ana sun", 12, "nobody", "ana sun", "lia moon" } })
check(#c.order == 2 and c.order[1] == "ana sun" and c.order[2] == "lia moon", "the arrangement checked: unknown and twice out")

out("== the box off")
Mail.db.fixed = true
Mail.db.sort = "custom"; Mail.Changed()
order = table.concat(Mail.db.order, ",")
from = Start(Cell(cells[1].entry.name).entry.name)
check(not (ghost and ghost:IsShown()), "no drag")
Drop(from)
check(table.concat(Mail.db.order, ",") == order, "nothing changed")
out("")
out(fails .. " failure(s)")
