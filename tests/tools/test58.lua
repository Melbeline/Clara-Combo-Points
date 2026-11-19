-- Reverse Engineering (Modules/Crafting): what the account's characters hold (bags, bank, mail, what
-- was mailed to them), the recipes kept, the search ("Name" in quotes: that recipe alone), the filter,
-- the subcomponents with their icons and chests, the text list, and the game's professions window
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false, tullarange = false,
  names = false, tooltipanchor = false } }
Enum = Enum or {}
Enum.CraftingReagentType = { Basic = 1, Optional = 2 }
Enum.BagIndex = { Keyring = -1, Backpack = 0, ReagentBag = 5, CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, AccountBankTab_1 = 15 }

-- the items
local ITEMS = {
  [100] = "Tranquil Mechanical Yeti", [101] = "Cured Rugged Hide", [102] = "Thorium Widget", [103] = "Globe of Water",
  [104] = "Truesilver Transformer", [105] = "Gold Power Core", [106] = "Gold Bar", [107] = "Thorium Bar",
  [108] = "Runecloth", [109] = "Rugged Hide", [110] = "Refined Deeprock Salt", [111] = "Mithril Gyro-Shot",
}
for id, name in pairs(ITEMS) do M.ITEMS[id] = { name, 1000 + id, 7, 0 } end
-- containers: S.container[bag] = { { itemID, stackCount }, ... }
S.container = { [0] = { { 102, 5 }, { 103, 2 }, { 104, 2 }, { 106, 4 }, { 107, 55 }, { 108, 23 } } }
C_Container = {
  GetContainerNumSlots = function(bag) return #(S.container[bag] or {}) end,
  GetContainerItemInfo = function(bag, slot)
    local x = (S.container[bag] or {})[slot]
    return x and { itemID = x[1], stackCount = x[2] }
  end,
}
local function Bags()
  S.bags = {}
  for bag = 0, 5 do for _, x in ipairs(S.container[bag] or {}) do S.bags[x[1]] = (S.bags[x[1]] or 0) + x[2] end end
end
Bags()
-- the recipes
local RECIPES = {
  [1] = { out = 100, name = "Tranquil Mechanical Yeti", r = { { 101, 1 }, { 102, 4 }, { 103, 2 }, { 104, 2 }, { 105, 1 } } },
  [2] = { out = 105, name = "Gold Power Core", r = { { 106, 1 } } },
  [3] = { out = 102, name = "Thorium Widget", r = { { 107, 3 }, { 108, 1 } } },
  [5] = { out = 111, name = "Mithril Gyro-Shot", r = { { 106, 2 }, { 108, 1 } } },
}
local nameFilter = ""
C_TradeSkillUI = {
  GetRecipeSchematic = function(id)
    local r = RECIPES[id]
    if not r then return nil end
    local slots = {}
    for i, x in ipairs(r.r) do slots[i] = { reagents = { { itemID = x[1] } }, quantityRequired = x[2], reagentType = 1 } end
    return { outputItemID = r.out, quantityMin = 1, reagentSlotSchematics = slots, name = r.name }
  end,
  GetRecipeRequirements = function(id) return id == 2 and { { name = "Anvil", met = true } } or {} end,
  GetFilteredRecipeIDs = function() return { 1, 2, 3, 5 } end,
  GetRecipeInfo = function(id) return RECIPES[id] and { recipeID = id, name = RECIPES[id].name, learned = true } end,
  GetBaseProfessionInfo = function() return { professionName = "Engineering" } end,
  GetRecipeItemNameFilter = function() return nameFilter end,
  SetRecipeItemNameFilter = function(t) nameFilter = t or "" end,
}
-- the account: an alt that knows Leatherworking (one of its recipes kept), with Rugged Hide
ClaraCraftDB = {
  chars = { ["Alt-Forever"] = { bags = { [109] = 6 }, bank = {}, mail = {}, sent = {}, at = 1, class = "DRUID" } },
  recipes = { [4] = { o = 101, m = 1, r = { 109, 1, 110, 1 }, p = "Leatherworking", w = { ["Alt-Forever"] = true } } },
}
-- the mail
local inbox, outgoing = {}, {}
function GetInboxNumItems() return #inbox end
function GetInboxItem(i, j) local x = inbox[i] and inbox[i][j]; if x then return ITEMS[x[1]], x[1], 1, x[2] end end
function GetSendMailItem(i) local x = outgoing[i]; if x then return ITEMS[x[1]], x[1], 1, x[2] end end
function SendMail(name) end
ATTACHMENTS_MAX_SEND, ATTACHMENTS_MAX_RECEIVE = 12, 16
-- the game's filter menu
local menus = {}
Menu = { ModifyMenu = function(tag, fn) menus[tag] = fn end }

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
if not ns.Craft then out("(no Reverse Engineering in this version)"); out(""); out("0 failure(s)"); return end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
Run()
local C = ns.Craft
local db = ClaraCraftDB

out("== the account's characters")
check(C and db.chars["Lola-Forever"] and db.chars["Lola-Forever"].bags[107] == 55, "this character's bags read at login")
check(C.IsMine("Alt") and C.IsMine("alt-forever") and not C.IsMine("Stranger"), "a character met here is one of the account's; a stranger is not")
S.container[6] = { { 110, 3 } }
S.container[15] = { { 108, 40 } }
M.Fire("BANKFRAME_OPENED")
check(C.Bank(110) == 3 and C.AccountBank(108) == 40, "the bank opened: its tabs read, the account's apart")
M.Fire("BANKFRAME_CLOSED")
S.container[6] = nil
check(C.Bank(110) == 3, "the bank closed: as read at the visit")
M.Fire("MAIL_SHOW")
outgoing = { { 106, 2 } }
SendMail("Alt", "gold", "")
M.Fire("MAIL_SEND_SUCCESS")
local function SentTo(key, id) local n = 0 for _, s in pairs(db.sends) do if s.to == key then n = n + (s.items[id] or 0) end end return n end
check(SentTo("Alt-Forever", 106) == 2 and C.Mailed("Alt-Forever", 106) == 2, "gold mailed to an alt: counted on it")
outgoing = { { 108, 5 } }
SendMail("Stranger", "cloth", "")
M.Fire("MAIL_SEND_SUCCESS")
check(db.chars["Stranger-Forever"] == nil and SentTo("Stranger-Forever", 108) == 0, "to another player: nothing kept")
ns.Mail = { db = { own = {} }, HasCategory = function(name, cat) return name == "Bankie" and cat == "bankalt" end }
outgoing = { { 107, 20 } }
SendMail("Bankie", "bars", "")
M.Fire("MAIL_SEND_SUCCESS")
check(db.chars["Bankie-Forever"] and SentTo("Bankie-Forever", 107) == 20 and db.chars["Bankie-Forever"].remote,
  "to a Bank alt of the mail module (another account's, never met): kept on it")
inbox = { { { 110, 1 } } }
M.Fire("MAIL_INBOX_UPDATE"); Run()
check(db.chars["Lola-Forever"].mail[110] == 1, "this character's mailbox read")
M.Fire("MAIL_CLOSED")
local others = C.Others(106)
check(#others == 1 and others[1].name == "Alt" and others[1].mail == 2, "who else has some: the alt, by mail")

out("== the recipes")
M.Fire("TRADE_SKILL_SHOW"); Run()
check(db.recipes[1] and db.recipes[2].p == "Engineering" and db.recipes[2].w["Lola-Forever"], "the window's recipes kept, with their profession and who knows them")
check(C.RecipeFor(105) == 2 and C.RecipeFor(101) == 4, "an item's recipe: this window's, or another character's kept")
check(C.Craftable(2) == 4 and C.Craftable(3) == 18, "how many the bags make (4 Gold Power Cores, 18 Thorium Widgets)")

out("== the search")
check(C.Match(1, "Tranquil Mechanical Yeti", "gold power core") and C.Match(2, "Gold Power Core", "gold power core")
  and not C.Match(3, "Thorium Widget", "gold power core"), "a name: the recipes made from it, and its own")
check(C.Match(2, "Gold Power Core", '"Gold power core"') and not C.Match(1, "Tranquil Mechanical Yeti", '"Gold power core"'),
  '"Name" in quotes: that recipe alone')
check(C.Match(2, "Gold Power Core", "gôld POWER"), "accents and case aside")
check(C.Match(3, "Thorium Widget", "") and C.Match(3, "Thorium Widget", "  "), "nothing typed: every recipe")
C.SetOption("search", false)
check(not C.Match(1, "Tranquil Mechanical Yeti", "gold power core") and C.Match(2, "Gold Power Core", "gold power"),
  "the search box unticked: names only, as before")
C.SetOption("search", true)

out("== the filter")
check(C.Shown(1), "off: every recipe")
C.ToggleFilter("on")
check(C.Shown(2) and C.Shown(3) and not C.Shown(1), "all reagents in the bags: Gold Power Core and Thorium Widget, not the Yeti")
C.ToggleFilter("part")
check(C.Shown(1), "even some of them: the Yeti too")
C.ToggleFilter("part"); C.ToggleFilter("on")
C.ToggleFilter("bank")
check(C.Filter().on and C.Filter().bank, "ticking the bank turns the filter on")
C.ToggleFilter("bank"); C.ToggleFilter("on")

out("== the subcomponents, with their icons")
local subs = C.Subs(1)
check(#subs == 3 and subs[1].recipe == 4 and subs[2].recipe == 3 and subs[3].recipe == 2, "each reagent a profession makes, in the reagents' order")
local panel = C.NewPanel(UIParent)
local h = panel:Update(1, 300)
check(h > 100 and panel.title:IsShown() and panel.title:GetText() == "Subcomponents", "the panel: its title, as tall as its blocks")
local headers = panel.headers.items
check(headers[1].name:GetText() == "Cured Rugged Hide" and headers[1].sub:GetText():find("Leatherworking : Alt", 1, true),
  "a reagent of another profession: who of the account makes it")
check(headers[3].name:GetText() == "Gold Power Core" and headers[3].count:GetText() == 4 and headers[3].sub:GetText():find("Anvil", 1, true),
  "Gold Power Core: 4 from the bags, its tools")
local function Reagent(id) for _, b in ipairs(panel.reagents.items) do if b:IsShown() and b.itemID == id then return b end end end
local gold, hide, salt = Reagent(106), Reagent(109), Reagent(110)
check(gold and gold.count:GetText() == "4/1" and not gold.icon._desat, "Gold Bar: 4/1, lit (enough in the bags)")
check(hide and hide.count:GetText() == "0/1" and hide.icon._desat, "Rugged Hide: 0/1, grey")
check(headers[1].icon._desat and headers[1].count:GetText() == "", "Cured Rugged Hide: none can be made, grey")
check(salt and salt.claraChest and salt.claraChest:IsShown() and not salt.claraChest.icon._desat, "Refined Deeprock Salt in the bank: its chest, lit")
check(hide.claraChest and hide.claraChest:IsShown() and hide.claraChest.icon._desat, "Rugged Hide only on the alt: its chest, grey")
check(gold.claraChest and gold.claraChest:IsShown() and gold.claraChest.icon._desat, "Gold Bar mailed to the alt: its chest, grey")
salt.claraChest:GetScript("OnEnter")(salt.claraChest)
local tip = table.concat(GameTooltip._lines, " | ")
check(tip:find("In your bank\t3", 1, true) and tip:find("In your bags\t0", 1, true), "its tooltip: the bank and the bags")
hide.claraChest:GetScript("OnEnter")(hide.claraChest)
tip = table.concat(GameTooltip._lines, " | ")
check(tip:find("Your other characters", 1, true) and tip:find("Alt\t6", 1, true) and tip:find("bags 6", 1, true), "and the account's other characters")
C.SetOption("chest", false)
panel:Update(1, 300)
check(not salt.claraChest:IsShown(), "chests unticked: none")
C.SetOption("chest", true)

out("== as text, as Reverse Engineering")
C.SetMode("text")
h = panel:Update(1, 300)
local lines = {}
for _, b in ipairs(panel.texts.items) do if b:IsShown() then lines[#lines + 1] = b.text:GetText() end end
local all = table.concat(lines, "\n")
check(panel.head:GetText():find("Raw Materials Needed for Tranquil Mechanical Yeti:", 1, true), "its title")
check(all:find("|cff00ff00Thorium Bar|r  |cff00ff0055/12|r", 1, true), "Thorium Bar: 55/12, green (for the widgets)")
check(all:find("Rugged Hide|r  |cffffd1000/1", 1, true) and not all:find("Thorium Widget", 1, true), "only raw materials: Rugged Hide 0/1, no widget")
check(all:find("|cff00ff00Refined Deeprock Salt|r  |cff00ff003/1", 1, true), "the bank counts here, as in the addon (3/1)")
panel.toggle:Click()
panel:Update(1, 300) -- (the window's own redraw)
lines = {}
for _, b in ipairs(panel.texts.items) do if b:IsShown() then lines[#lines + 1] = b.text:GetText() end end
all = table.concat(lines, "\n")
check(C.Nested() and all:find("Thorium Widget", 1, true) and panel.head:GetText():find("Materials for", 1, true),
  "its button: the tree, crafted reagents with their icons")
C.SetMode("off")
check(panel:Update(1, 300) == 0 and not panel.frame:IsShown(), "nothing: nothing shown")
C.SetMode("icons")

out("== the game's professions window")
local function Node(data, parent)
  local n = { data = data, nodes = {}, parent = parent }
  function n:GetNodes() return self.nodes end
  function n:GetData() return self.data end
  function n:Insert(d) local c = Node(d, self); table.insert(self.nodes, c); return c end
  function n:Remove(c) for i, x in ipairs(self.nodes) do if x == c then table.remove(self.nodes, i) return end end end
  return n
end
local function Provider()
  local root = Node({})
  local p = { root = root, invalidated = 0 }
  function p:GetRootNode() return self.root end
  function p:Invalidate() self.invalidated = self.invalidated + 1 end
  function p:IsEmpty() return #self.root.nodes == 0 end
  local cat = root:Insert({ categoryInfo = { name = "Devices" } })
  cat:Insert({ topPadding = true })
  for _, id in ipairs({ 1, 2, 3, 5 }) do cat:Insert({ recipeInfo = { recipeID = id, name = RECIPES[id].name } }) end
  cat:Insert({ bottomPadding = true })
  return p
end
local function Listed(p)
  local ids = {}
  for _, cat in ipairs(p.root.nodes) do
    for _, n in ipairs(cat.nodes) do if n.data.recipeInfo then ids[#ids + 1] = n.data.recipeInfo.recipeID end end
  end
  return table.concat(ids, ",")
end
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
ProfessionsFrame.refreshed = 0
function ProfessionsFrame:Refresh() self.refreshed = self.refreshed + 1 end
local page = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.CraftingPage = page
local form = CreateFrame("Frame", nil, page)
form:SetSize(493, 484)
page.SchematicForm = form
form.Reagents = CreateFrame("Frame", nil, form)
form.Reagents:SetSize(300, 140)
form.Reagents:SetPoint("TOPLEFT", 20, -120)
local slots = {}
for i, x in ipairs(RECIPES[1].r) do
  slots[i] = { Button = CreateFrame("Button", nil, form), GetReagentSlotSchematic = function() return { reagents = { { itemID = x[1] } } } end }
end
function form:GetSlotsByReagentType() return slots end
function form:Init(info) self.info = info end
function form:Refresh() end
function form:GetRecipeInfo() return self.info end
local list = CreateFrame("Frame", nil, page)
page.RecipeList = list
list.SearchBox = CreateFrame("EditBox", nil, list)
list.ScrollBox = CreateFrame("Frame", nil, list)
function list.ScrollBox:SetDataProvider(p) self.provider = p end
list.NoResultsText = list:CreateFontString(nil, "ARTWORK", "GameFontNormal")
list:SetSize(274, 484)
list:SetPoint("TOPLEFT", page, "TOPLEFT", 5, -72)
form:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0) -- (the game's: beside the list)
local maximized = 0
function page:SetMaximized() maximized = maximized + 1; form:ClearAllPoints(); form:SetPoint("TOPLEFT", list, "TOPRIGHT", 2, 0) end
M.Fire("ADDON_LOADED", "Blizzard_Professions")
ProfessionsFrame:Show(); page:Show(); form:Show()
db.chars["Alt-Forever"].bank[103] = 2
form:Init({ recipeID = 1, name = "Tranquil Mechanical Yeti" })
Run()
check(slots[5].Button.claraChest == nil or not slots[5].Button.claraChest:IsShown(), "a reagent nowhere else (Gold Power Core): no chest")
check(slots[3].Button.claraChest and slots[3].Button.claraChest:IsShown() and slots[3].Button.claraChest.icon._desat,
  "Globe of Water in the alt's bank: a grey chest on the game's own reagent button")
local p = Provider()
list.ScrollBox:SetDataProvider(p)
check(Listed(p) == "1,2,3,5", "nothing typed, no filter: the game's list as it is")
nameFilter = "gold power core"
list.SearchBox:SetText("gold power core")
list.SearchBox:GetScript("OnTextChanged")(list.SearchBox)
check(nameFilter == "", "a search typed: the game's own filter on names left empty")
Run()
check(ProfessionsFrame.refreshed >= 1, "the list made again")
p = Provider()
list.ScrollBox:SetDataProvider(p)
check(Listed(p) == "1,2" and p.invalidated > 0, "Gold Power Core: the recipes made from it, and its own")
list.SearchBox:SetText('"Gold power core"')
list.SearchBox:GetScript("OnTextChanged")(list.SearchBox)
p = Provider()
list.ScrollBox:SetDataProvider(p)
check(Listed(p) == "2", '"Gold power core": that recipe alone')
list.SearchBox:SetText("nothing like it")
list.SearchBox:GetScript("OnTextChanged")(list.SearchBox)
p = Provider()
list.ScrollBox:SetDataProvider(p)
check(#p.root.nodes == 0 and list.NoResultsText:IsShown(), "no match: the list empty, the game's No results")
list.SearchBox:SetText("~30")
list.SearchBox:GetScript("OnTextChanged")(list.SearchBox)
p = Provider()
list.ScrollBox:SetDataProvider(p)
check(Listed(p) == "1,2,3,5", "the game's level search (~30): left to the game")
list.SearchBox:SetText("")
list.SearchBox:GetScript("OnTextChanged")(list.SearchBox)
local root = { items = {} }
function root:CreateDivider() end
function root:CreateTitle(t) self.title = t end
function root:CreateCheckbox(text, get, set) table.insert(self.items, { text = text, get = get, set = set }) end
menus.MENU_PROFESSIONS_FILTER(nil, root)
check(#root.items == 3 and root.items[1].text == "Only the recipes whose reagents are in your bags", "the filter menu: its three boxes")
root.items[1].set()
p = Provider()
list.ScrollBox:SetDataProvider(p)
check(Listed(p) == "2,3,5", "ticked: only what the bags make")
root.items[1].set()
check(not C.FilterOn(), "unticked: off again")

out("== the whole recipe pane scrolls as one: the game's form in a scroll frame of its size and place")
local function Kids(parent) local t = {} for _, f in ipairs(M.frames) do if f._parent == parent then t[#t + 1] = f end end return t end
function page:GetChildren() return unpack(Kids(self)) end
local pane, holder, re = ns.CraftGamePane()
check(pane and pane._kind == "ScrollFrame" and pane._parent == page and holder and form._parent == holder,
  "the form in the pane's scrolled frame, the pane on the page")
local p1, rel1, rp1, x1 = pane:GetPoint(1)
check(p1 == "TOPLEFT" and rel1 == list and rp1 == "TOPRIGHT" and x1 == 2, "the pane where the game put the form (beside the list)")
local fp, frel = form:GetPoint(1)
check(fp == "TOPLEFT" and frel == holder, "the form at the top of what scrolls")
check(math.abs(pane:GetHeight() - 484) < 0.01 and math.abs(pane:GetWidth() - 493) < 0.01, "the pane: the form's own size")
page:SetMaximized()
p1, rel1 = pane:GetPoint(1)
fp, frel = form:GetPoint(1)
check(rel1 == list and frel == holder, "the game moving the form again (maximized): the pane moved, the form back in it")
local function Under() local _, rel, relPoint = re:GetPoint(1) return rel, relPoint end
form:Init({ recipeID = 1, name = "Tranquil Mechanical Yeti" }); Run()
check(select(1, Under()) == form.Reagents, "the panel under the reagents, no scroll of its own")
check(re._parent == holder, "the panel in what scrolls")
local tall = form:GetHeight()
check(tall >= 484, ("the form as tall as what it holds (%d)"):format(tall))
pane:SetVerticalScroll(120)
form:Init({ recipeID = 2, name = "Gold Power Core" }); Run()
check((pane._vs or 0) == 0, "another recipe: from the top")
form:Hide(); Run()
check(math.abs(form:GetHeight() - 484) < 0.01, "the form hidden (ForeverRecipes' own pane in its place): its own height")
form:Show()

out("== with ForeverRecipes: the panel under its Difficulty and Source panels, all in the pane")
form:Init({ recipeID = 1, name = "Tranquil Mechanical Yeti" }); Run()
ForeverRecipes = {}
local difficulty = CreateFrame("Frame", nil, page)
difficulty.estimateRows = {}; difficulty.bar = CreateFrame("Frame", nil, difficulty); difficulty.req = difficulty:CreateFontString()
difficulty:SetPoint("TOPLEFT", form, "TOPLEFT", 22, -270); difficulty:SetHeight(112)
local source = CreateFrame("Frame", nil, page)
source.rows = {}; source.content = source
source:SetPoint("TOPLEFT", difficulty, "BOTTOMLEFT", 0, -12); source:SetHeight(24)
difficulty:Show(); source:Show()
form:Init({ recipeID = 1, name = "Tranquil Mechanical Yeti" }); Run()
local rel, relPoint = Under()
check(rel == source and relPoint == "BOTTOMLEFT", "its Source shown: the panel under it")
check(difficulty._parent == holder and source._parent == holder, "its panels in the pane: scrolled and cut with the recipe")
check(form:GetHeight() > 484, ("the form taller than its own: the pane scrolls (%d)"):format(form:GetHeight()))
check(pane.ScrollBar:IsShown(), "its bar shown")
source:Hide(); Run()
check(select(1, Under()) == difficulty, "its Source hidden (its option): under its Difficulty, placed again at once")
difficulty:Hide(); Run()
check(select(1, Under()) == form.Reagents, "a recipe it knows nothing of (its panels hidden): under the reagents again")
difficulty:Show(); source:Show(); Run()
check(select(1, Under()) == source, "shown again: under its Source")
check(next(rawget(difficulty, "estimateRows")) == nil and source.content == source, "its frames left as they were")
difficulty:Hide(); source:Hide(); Run()
ForeverRecipes = nil

if ns.CraftClassicDetail then
  out("== ClassicUI's professions window (its hooks)")
  check(ns.CraftMatch(2, { name = "Gold Power Core" }, '"gold power core"') and not ns.CraftMatch(1, { name = "Tranquil Mechanical Yeti" }, '"gold power core"'),
    "its list: the same search")
  local scrollPane = CreateFrame("ScrollFrame", nil, UIParent)
  scrollPane:SetSize(316, 300)
  local detail = CreateFrame("Frame", nil, scrollPane)
  detail.reagents = {}
  for i, x in ipairs(RECIPES[1].r) do
    local b = CreateFrame("Button", nil, detail)
    b.icon = b:CreateTexture()
    b.itemID = x[1]
    if i <= 5 then b:Show() else b:Hide() end
    detail.reagents[i] = b
  end
  ns.CraftClassicDetail(detail, { recipeID = 1 })
  check(detail.reagents[3].claraChest and detail.reagents[3].claraChest:IsShown(), "a chest on its reagent buttons")
  local bottom = ns.CraftClassicPlace(detail, 180)
  check(bottom > 300, "the panel under the reagents, the pane's content longer (" .. bottom .. ")")
  local refreshed = 0
  ns.ClassicTradeRefresh = function() refreshed = refreshed + 1 end
  local entries = ns.CraftFilterEntries()
  check(entries[1].divider and #entries == 4 and type(entries[2].toggle) == "function", "its filter menu: a divider and the three boxes")
  entries[2].toggle(); Run()
  check(C.FilterOn() and refreshed >= 1, "ticked there: the window's list made again")
  entries[2].toggle(); Run()
end

out("")
out(fails .. " failure(s)")
