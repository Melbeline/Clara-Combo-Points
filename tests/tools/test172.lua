-- The bank from anywhere (Modules/BankView): the Shop micro button opens a window drawn as WoW Forever's bank, the
-- bank of a character as it was last seen slot by slot (Reverse Engineering's data); 8 columns, 88 to a page, its page
-- tabs (the character's bank, then the account bank); the character picked; the search lights the items found; "seen
-- ... ago"; never seen: said; a right click on the button: Clara's options; the box off: the button Clara's again. The
-- bank read slot by slot as it is open (tabs, items, counts). In an item's tooltip: each character's counts, the
-- account bank, the total.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false,
  leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false,
  classicui = false, tullarange = false, tooltipanchor = false } }
local now = 1800000000
time = function() return now end
GetNormalizedRealmName = function() return "Forever" end
local oldName = UnitName
function UnitName(u) if u == "player" then return "Elle" end return oldName(u) end
-- Elle's bank: 2 tabs (28 + 70 slots: 98, two pages); Lia's never seen; the account bank (24)
local s1 = {}
s1[1] = "item:2589;20"; s1[2] = "item:2592;5"; s1[90] = "item:4306;12"
ClaraCraftDB = { chars = {
  ["Elle-Forever"] = { bags = { [2589] = 3 }, bank = { [2589] = 20, [2592] = 5, [4306] = 12 }, mail = {}, at = now - 7200, class = "HUNTER",
    view = { at = now - 7200, t = { 28, 70 }, b = { [2] = 133639 }, s = s1 } },
  ["Lia-Forever"] = { bags = { [2589] = 7 }, bank = {}, mail = { [2589] = 1 }, at = 1, class = "PRIEST" },
}, account = { [2589] = 4 }, accountAt = now - 60, accountView = { at = now - 60, t = { 24 }, b = {}, s = { [3] = "item:2589;4" } } }
local names = { [2589] = "Linen Cloth", [2592] = "Wool Cloth", [4306] = "Silk Cloth" }
C_Item = C_Item or {}
C_Item.GetItemNameByID = function(id) return names[id] end
C_Item.GetItemIconByID = function(id) return 1000 + id end
C_Item.GetItemQualityByID = function() return 1 end
function SetItemButtonTexture(b, t) b._tex = t end
function SetItemButtonCount(b, n) b._count = n end
function SetItemButtonQuality() end
StoreMicroButton = CreateFrame("Button", "StoreMicroButton", UIParent)
local optionsOpened = 0
S.class = "HUNTER"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
ns.ToggleOptions = function() optionsOpened = optionsOpened + 1 end
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.BankViewToggle then out("(no bank view in this version)"); out(""); out("0 failure(s)"); return end

out("== the Shop button: the bank, a right click Clara's options")
local shop = StoreMicroButton
check(shop.tooltipText == ns.L.BV_BUTTON, "its tooltip: " .. tostring(shop.tooltipText))
shop:GetScript("OnClick")(shop, "LeftButton")
local f = ns.BankViewFrame
check(f and f:IsShown(), "a click: the bank window shown")
shop:GetScript("OnClick")(shop, "RightButton")
check(optionsOpened == 1, "a right click: Clara's options")

out("== this character's bank, its first page: 88 slots, its items, its tabs")
local b = ns.BankViewButtons
local shown = 0
for i = 1, 88 do if b[i]:IsShown() then shown = shown + 1 end end
check(shown == 88, "88 slots on the first page: " .. shown)
check(b[1]._tex == 3589 and b[1]._count == 20 and b[1].link == "item:2589", "slot 1: Linen Cloth x20")
check(b[3]._tex == nil and b[3].link == nil, "an empty slot")
local p1, rel, rp, x1, y1 = b[1]:GetPoint(1)
local _, _, _, x2 = b[2]:GetPoint(1)
local _, _, _, x9, y9 = b[9]:GetPoint(1)
check(x1 == 47 and y1 == -63 and x2 == 97 and x9 == 47 and y9 == -110, "laid as the game's bank: 8 columns, 13 and 10 apart")
local tabs = 0
for _, t in ipairs(ns.BankViewTabs) do if t:IsShown() then tabs = tabs + 1 end end
check(tabs == 3, "its page tabs: 2 pages of the character's bank, 1 of the account bank: " .. tabs)
check(ns.BankViewBags[1]._tex == 133639, "its bag slots: the second tab's bag")
out("== the second page")
ns.BankViewTabs[2]:GetScript("OnMouseUp")(ns.BankViewTabs[2])
shown = 0
for i = 1, 88 do if b[i]:IsShown() then shown = shown + 1 end end
check(shown == 10 and b[2]._tex == 5306 and b[2]._count == 12, "10 slots, slot 90 Silk Cloth x12: " .. shown)
out("== the search lights the items found")
ns.BankViewTabs[1]:GetScript("OnMouseUp")(ns.BankViewTabs[1])
ns.BankViewSearch:SetText("wool")
ns.BankViewRefresh()
check(b[2]:GetAlpha() == 1 and b[1]:GetAlpha() < 1, "Wool Cloth lit, Linen Cloth dimmed")
ns.BankViewSearch:SetText("")
ns.BankViewRefresh()
out("== the account bank")
ns.BankViewTabs[3]:GetScript("OnMouseUp")(ns.BankViewTabs[3])
shown = 0
for i = 1, 88 do if b[i]:IsShown() then shown = shown + 1 end end
check(shown == 24 and b[3]._count == 4, "24 slots, Linen Cloth x4: " .. shown)
out("== another character, never seen")
ns.BankViewToggle("Lia-Forever")
shown = 0
for i = 1, 88 do if b[i]:IsShown() then shown = shown + 1 end end
check(shown == 0, "no slot shown")
local chars = ns.BankViewCharacters()
check(chars[1] == "Elle-Forever" and chars[2] == "Lia-Forever", "the characters: this one first")
out("== the bank read slot by slot as it is open")
C_Container = C_Container or {}
local items = { [-1] = { [1] = { hyperlink = "|cffffffff|Hitem:2589::::::::40:::::::::|h[Linen Cloth]|h|r", stackCount = 7 } } }
C_Container.GetContainerNumSlots = function(bag) if bag == -1 then return 24 end if bag >= 5 and bag <= 11 then return 0 end return 0 end
C_Container.GetContainerItemInfo = function(bag, slot) return items[bag] and items[bag][slot] end
local v = ns.Craft.ViewOf({ -1, 5 })
check(v and v.t[1] == 24 and v.t[2] == 0 and v.s[1] == "item:2589::::::::40;7", "tabs and items (the item string, its count): " .. tostring(v and v.s[1]))
out("== an item's tooltip: each character's counts, the account bank, the total")
local tip = { lines = {} }
function tip:AddLine(l) self.lines[#self.lines + 1] = tostring(l) end
function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = tostring(l) .. " = " .. tostring(r) end
local real = GameTooltip
GameTooltip = tip
ns.BankViewAddCounts(tip, { id = 2589 })
GameTooltip = real
local all = table.concat(tip.lines, "\n")
check(all:find("Elle", 1, true) and all:find("= bank 20", 1, true), "Elle: bank 20 (her bags read again at the login: empty)")
check(all:find("Lia", 1, true) and all:find("bags 7, mail 1", 1, true), "Lia: bags 7, mail 1")
check(all:find("Account Bank = bank 4", 1, true) and all:find("Total = 32", 1, true), "the account bank, the total 32: " .. all:gsub("\n", " | "))
out("== the box off: the Shop button Clara's again")
ns:SetBankView(false)
check(shop.tooltipText == "Clara" and not f:IsShown(), "Clara's tooltip, the window put away")
shop:GetScript("OnClick")(shop, "LeftButton")
check(optionsOpened == 2, "a click: Clara's options")
ns:SetBankView(true)
out("")
out(fails .. " failure(s)")
