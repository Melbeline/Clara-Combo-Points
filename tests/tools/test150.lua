-- An enchant put on in one click (EnchantConfirm.lua): the box left of the professions window's Enchant button (left
-- of Enchant All when shown), only for an enchant, unticked by default; ticked, the game's "replace this enchant?"
-- answered Yes as it opens (its own call), its window taken away (now, and the window opened after, the same moment);
-- the three of them (professions window, bags, trade window); unticked: left to the player; the call refused: the
-- window left.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

CREATE_PROFESSION_ENCHANT = "Enchant"
Enum = Enum or {}
Enum.TradeskillRecipeType = Enum.TradeskillRecipeType or { Item = 1, Salvage = 2, Enchant = 3, Recraft = 4, Gathering = 5 }
local called = {}
C_Item = C_Item or {}
local refuse = false
for _, n in ipairs({ "ReplaceTradeskillEnchant", "ReplaceEnchant", "ReplaceTradeEnchant" }) do
  C_Item[n] = function() if refuse then error("refused") end called[#called + 1] = n end
end
local shown = {}
function StaticPopup_Show(which) shown[which] = true end
function StaticPopup_Hide(which) shown[which] = nil end

-- The professions window's page, as the game makes it
ProfessionsFrame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
local page = CreateFrame("Frame", nil, ProfessionsFrame)
ProfessionsFrame.CraftingPage = page
page.CreateButton = CreateFrame("Button", nil, page)
page.CreateAllButton = CreateFrame("Button", nil, page)
page.CreateAllButton:Hide()
local kind = Enum.TradeskillRecipeType.Enchant
page.SchematicForm = { GetTransaction = function() return { IsRecipeType = function(_, t) return t == kind end } end }
function page:ValidateControls() end

local ns = {}
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.EnchantConfirmSetup then out("(no enchant box in this version)"); out(""); out("0 failure(s)"); return end
ns.EnchantConfirmSetup()
local box = _G.ClaraEnchantConfirmBox

out("== the box")
check(box ~= nil, "made on the page")
page:ValidateControls()
check(box:IsShown() and not box:GetChecked() and not ns:EnchantConfirm(), "for an enchant: shown, unticked")
local p = { box:GetPoint(1) }
check(p[1] == "RIGHT" and p[2] == page.CreateButton and p[3] == "LEFT", "left of the Enchant button")
page.CreateAllButton:Show(); page:ValidateControls()
p = { box:GetPoint(1) }
check(p[2] == page.CreateAllButton, "left of Enchant All when the game shows it")
page.CreateAllButton:Hide()
kind = Enum.TradeskillRecipeType.Item; page:ValidateControls()
check(not box:IsShown(), "another recipe: away")
kind = Enum.TradeskillRecipeType.Enchant; page:ValidateControls()
check(box:IsShown(), "an enchant again: back")

out("== unticked")
StaticPopup_Show("REPLACE_TRADESKILL_ENCHANT"); M.Fire("REPLACE_TRADESKILL_ENCHANT", "Old", "New")
check(#called == 0 and shown.REPLACE_TRADESKILL_ENCHANT, "the game's question left to the player")
StaticPopup_Hide("REPLACE_TRADESKILL_ENCHANT")

out("== ticked")
box:SetChecked(true); box:GetScript("OnClick")(box)
check(ns:EnchantConfirm() and ClaraComboPointsDB.enchantConfirm == true, "kept (the account's)")
StaticPopup_Show("REPLACE_TRADESKILL_ENCHANT"); M.Fire("REPLACE_TRADESKILL_ENCHANT", "Old", "New")
check(called[1] == "ReplaceTradeskillEnchant" and not shown.REPLACE_TRADESKILL_ENCHANT, "from the professions window: Yes, the window away")
M.Fire("REPLACE_ENCHANT", "Old", "New")
StaticPopup_Show("REPLACE_ENCHANT") -- (the game's window opened after Clara's answer)
for _ = 1, 50 do if not (M.timers and #M.timers > 0) then break end M.RunTimer() end
check(called[2] == "ReplaceEnchant" and not shown.REPLACE_ENCHANT, "from the bags: Yes, the window opened after it away too")
StaticPopup_Show("TRADE_REPLACE_ENCHANT"); M.Fire("TRADE_REPLACE_ENCHANT", "Old", "New")
check(called[3] == "ReplaceTradeEnchant" and not shown.TRADE_REPLACE_ENCHANT, "in the trade window: Yes")
refuse = true
StaticPopup_Show("REPLACE_ENCHANT"); M.Fire("REPLACE_ENCHANT", "Old", "New")
check(shown.REPLACE_ENCHANT, "the call refused: the window left for the player")
refuse = false; StaticPopup_Hide("REPLACE_ENCHANT")

out("== unticked again")
box:SetChecked(false); box:GetScript("OnClick")(box)
check(not ns:EnchantConfirm() and ClaraComboPointsDB.enchantConfirm == nil, "off")
local before = #called
StaticPopup_Show("REPLACE_ENCHANT"); M.Fire("REPLACE_ENCHANT", "Old", "New")
check(#called == before and shown.REPLACE_ENCHANT, "the question left to the player")
out("")
out(fails .. " failure(s)")
