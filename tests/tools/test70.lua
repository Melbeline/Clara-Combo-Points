-- The gold tracker (Modules/Money): each character's gold on every WoW account, one column per account named
-- after its folder (the Windows script's), the highest level first; a right click on the backpack's money; a
-- column folded to a strip; a character dragged to a new place (the others making way); renamed, forgotten;
-- shared through the sync
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false,
  wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false, idtip = false, soloraidframe = false, enemycasts = false, reverseengineering = false } }
local money, level = 1234567, 42
function GetMoney() return money end
function UnitLevel(u) return u == "player" and level or 60 end
-- the backpack and its money (the game's coin buttons)
ContainerFrame1 = CreateFrame("Frame", "ContainerFrame1", UIParent)
ContainerFrame1.MoneyFrame = CreateFrame("Frame", "ContainerFrame1MoneyFrame", ContainerFrame1)
for _, k in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do ContainerFrame1.MoneyFrame[k] = CreateFrame("Button", nil, ContainerFrame1.MoneyFrame) end
-- the other accounts, as the Windows script brings them (their folder names)
ClaraSyncIncoming = {
  ["WANJ"] = { ClaraMoneyDB = { me = "wanjwanj", accounts = { iickstu1 = { n = "ICKSTU", at = 1 } }, chars = {
    ["Bob-Forever"] = { n = "Bob", r = "Forever", c = "WARRIOR", l = 60, m = 5000000, a = "wanjwanj", at = 100 },
    ["Zed-Forever"] = { n = "Zed", r = "Forever", c = "DRUID", l = 12, m = 300, a = "wanjwanj", at = 100 },
    ["Amy-Forever"] = { n = "Amy", r = "Forever", c = "ROGUE", l = 30, m = 10000, a = "wanjwanj", at = 100 } } } },
  ["101896528#1"] = { ClaraMoneyDB = { me = "wow1wow1", chars = {
    ["Kim-Forever"] = { n = "Kim", r = "Forever", c = "ROGUE", l = 25, m = 777, a = "wow1wow1", at = 100 } } } },
}
ClaraMoneyDB = { me = "iickstu1" }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 50 do if M.timers and #M.timers > 0 then M.RunTimer() end end -- (every timer of the login: their order is not fixed)
local G = ns.Money
if not ns.Sync then -- (the Light version: no sync between accounts; this account only)
  out("== the Light version: this account's characters only")
  local me = G.db.chars["Lola-Forever"]
  check(me and me.m == 1234567 and me.l == 42, "this character: its gold and level")
  check(#G.Accounts() == 1, "one column")
  local gold = ContainerFrame1.MoneyFrame.GoldButton
  gold:GetScript("OnMouseUp")(gold, "RightButton")
  check(ClaraMoneyFrame and ClaraMoneyFrame:IsShown(), "a right click: the gold window")
  out(fails .. " failure(s)")
  return
end

out("== this character, and the other accounts")
check(G and G.db.me == "iickstu1", "the account's own id kept")
local me = G.db.chars["Lola-Forever"]
check(me and me.m == 1234567 and me.l == 42 and me.c == "ROGUE" and me.a == "iickstu1", "this character: its gold, level and class")
check(G.db.chars["Bob-Forever"] and G.db.chars["Kim-Forever"], "the other accounts' characters, from the script's files")
check(G.AccountName("wanjwanj") == "WANJ" and G.AccountName("wow1wow1") == "WoW1", "named after their folders (123456789#1: WoW1)")
check(G.AccountName("iickstu1") == "ICKSTU", "this account's name: from the others")
local ids = G.Accounts()
check(#ids == 3 and G.AccountName(ids[1]) == "ICKSTU" and G.AccountName(ids[2]) == "WANJ" and G.AccountName(ids[3]) == "WoW1",
  "columns: ICKSTU, WANJ, WoW1")
local list = G.List("wanjwanj")
check(table.concat(list, ",") == "Bob-Forever,Amy-Forever,Zed-Forever", "the highest level first (" .. table.concat(list, ",") .. ")")
check(G.Total() == 1234567 + 5000000 + 300 + 10000 + 777 and G.Total("wanjwanj") == 5010300, "totals: each account's, all of them")

out("== the backpack's money: its right click")
local gold = ContainerFrame1.MoneyFrame.GoldButton
gold:GetScript("OnMouseUp")(gold, "LeftButton")
check(not (ClaraMoneyFrame and ClaraMoneyFrame:IsShown()), "a left click: the game's (no window)")
gold:GetScript("OnMouseUp")(gold, "RightButton")
local f = ClaraMoneyFrame
check(f and f:IsShown(), "a right click: the gold window")
gold:GetScript("OnEnter")(gold)
local lines = table.concat(GameTooltip._lines or {}, "|")
check(lines:find("Right-click: the gold of all your characters", 1, true) ~= nil, "its tooltip says so")

out("== a column folded, shown again")
local function Col(id) for _, c in pairs({}) do end end
local cols = {}
for _, fr in ipairs(M.frames) do if fr._kind == "CheckButton" and fr._parent and fr._parent._parent == f then cols[#cols + 1] = fr end end
check(#cols == 3, "a box per account (" .. #cols .. ")")
local box = cols[2]
box:SetChecked(false); box:GetScript("OnClick")(box)
check(G.db.collapsed["wanjwanj"] == true or G.db.collapsed["iickstu1"] == true or G.db.collapsed["wow1wow1"] == true, "unticked: its column folded")
local strip
for _, fr in ipairs(M.frames) do if fr._kind == "Button" and fr._parent == f and fr:IsShown() and fr:GetWidth() == 18 then strip = fr end end
check(strip ~= nil, "a thin strip in its place")
strip:GetScript("OnClick")(strip)
check(next(G.db.collapsed) == nil, "a click on the strip: shown again")

out("== reordering: dragged, the others making way")
local rows = {}
for _, fr in ipairs(M.frames) do
  if fr._kind == "Button" and fr.key and G.db.chars[fr.key] and G.db.chars[fr.key].a == "wanjwanj" and fr:IsShown() then rows[fr.key] = fr end
end
check(rows["Bob-Forever"] and rows["Zed-Forever"], "its rows")
local reorderButton
for _, fr in ipairs(M.frames) do if fr._kind == "Button" and fr.GetText and fr:GetText() == "Reorder" then reorderButton = fr end end
reorderButton:Click()
check(reorderButton:GetText() == "Done", "Reorder: the drag mode, its button now Done")
local zed = rows["Zed-Forever"]
zed:GetScript("OnMouseDown")(zed, "LeftButton")
-- the cursor over the first row of the column
local body = zed:GetParent()
M.cursorX, M.cursorY = 100, (body:GetTop() or 0) - 2
f:GetScript("OnUpdate")(f, 0.1)
zed:GetScript("OnMouseUp")(zed, "LeftButton")
check(table.concat(G.db.order["wanjwanj"] or {}, ",") == "Zed-Forever,Bob-Forever,Amy-Forever", "Zed dropped first: the order kept (" .. table.concat(G.db.order["wanjwanj"] or {}, ",") .. ")")
check(table.concat(G.List("wanjwanj"), ",") == "Zed-Forever,Bob-Forever,Amy-Forever", "shown in that order")
for _, fr in ipairs(M.frames) do if fr._kind == "Button" and fr.GetText and fr:GetText() == "By level" then fr:Click() end end
check(next(G.db.order) == nil and G.List("wanjwanj")[1] == "Bob-Forever", "By level: the levels back")

out("== renamed, forgotten")
G.Rename("wow1wow1", "Alt account")
check(G.AccountName("wow1wow1") == "Alt account" and G.db.accounts["wow1wow1"].at > 1, "renamed: the player's name, newer than the folder's")
local kimRow
for _, fr in ipairs(M.frames) do if fr._kind == "Button" and fr.key == "Kim-Forever" then kimRow = fr end end
reorderButton:Click() -- (out of the drag mode)
kimRow:GetScript("OnClick")(kimRow, "RightButton")
check(M.popup and M.popup.which == "CLARA_MONEY_FORGET", "right-click a character: asked to forget it")
M.PopupClick(1)
check(G.db.chars["Kim-Forever"] == nil and G.db.gone["Kim-Forever"], "forgotten, and remembered as gone (for the other accounts)")

out("== shared: its gold sent when it changes")
check(G.Touched ~= nil, "the sync carries it")
money = 2000000
M.Fire("PLAYER_MONEY")
check(G.db.chars["Lola-Forever"].m == 2000000, "the new gold kept")

out("== the surname, the other accounts' age")
UnitNameUnmodified = function(u) if u == "player" then return "Lola", "Rose" end return UnitName(u) end
money = 2000001
M.Fire("PLAYER_MONEY")
check(G.db.chars["Lola-Forever"].s == "Rose" and G.FullName(G.db.chars["Lola-Forever"]) == "Lola Rose", "its surname kept: Lola Rose")
check(G.FullName({ n = "Bob" }) == "Bob", "a record from before surnames: the first name alone")
check(G.Updated("wanjwanj") ~= nil, "another account: when it was last heard of")
local gold = ContainerFrame1.MoneyFrame.GoldButton
gold:GetScript("OnMouseUp")(gold, "RightButton")
local named, aged = false, false
for _, f in ipairs(M.regions) do
  local t = f.GetText and f:GetText()
  if t and tostring(t):find("Lola Rose", 1, true) then named = true end
  if t and tostring(t):find("ago", 1, true) then aged = true end
end
check(named, "shown with its surname in the gold window")
check(aged, "another account's column: updated ... ago")

out(fails .. " failure(s)")
