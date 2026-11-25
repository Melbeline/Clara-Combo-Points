-- Clara Combo Points - an enchant put on in one click: a box beside the professions window's Enchant button (shown
-- for an enchant), unticked by default, the account's. Ticked, the game's "Do you want to replace X with Y?" is
-- answered Yes for the player as it opens: the enchant the player chose put on over the one there, by the game's own
-- call (the one its Yes button makes), its window taken away. For an enchant put on an item from the professions
-- window, from the bags, or in the trade window (each one the player's own Enchant).

local ADDON, ns = ...
local L = ns.L

-- The game's window for each, and its Yes
local YES = {
  REPLACE_TRADESKILL_ENCHANT = "ReplaceTradeskillEnchant",
  REPLACE_ENCHANT = "ReplaceEnchant",
  TRADE_REPLACE_ENCHANT = "ReplaceTradeEnchant",
}

function ns:EnchantConfirm() return self.sv and self.sv.enchantConfirm == true or false end
function ns:SetEnchantConfirm(on)
  if not self.sv then return end
  self.sv.enchantConfirm = on and true or nil
  if ns.EnchantConfirmUpdate then ns.EnchantConfirmUpdate() end
end

local function Hide(which)
  if StaticPopup_Hide then StaticPopup_Hide(which) end
end

local function Answer(which)
  local name = YES[which]
  if not (name and ns:EnchantConfirm()) then return end
  local fn = (C_Item and C_Item[name]) or _G[name]
  if type(fn) ~= "function" then return end
  if not pcall(fn) then return end -- (the game's window left: the player answers)
  Hide(which)
  -- (the game's window opened after this, the same moment: taken away too)
  if C_Timer and C_Timer.After then C_Timer.After(0, function() Hide(which) end) end
end
ns.EnchantConfirmAnswer = Answer -- (for its test)

local events = CreateFrame("Frame")
for which in pairs(YES) do pcall(events.RegisterEvent, events, which) end
events:SetScript("OnEvent", function(_, event) Answer(event) end)

---------------------------------------------------------------------------
-- The box, left of the Enchant button (left of Enchant All when the game shows it), its name left of it
---------------------------------------------------------------------------
local box

local function IsEnchant(page)
  local form = page.SchematicForm
  local ok, yes = pcall(function()
    local t = form and form.GetTransaction and form:GetTransaction()
    return t and Enum and Enum.TradeskillRecipeType and t:IsRecipeType(Enum.TradeskillRecipeType.Enchant)
  end)
  if ok and yes ~= nil then return yes and true or false end
  local text = page.CreateButton and page.CreateButton:GetText()
  return CREATE_PROFESSION_ENCHANT ~= nil and text == CREATE_PROFESSION_ENCHANT
end

local function Update()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  if not (box and page) then return end
  local all = page.CreateAllButton
  local left = (all and all:IsShown()) and all or page.CreateButton
  box:ClearAllPoints()
  box:SetPoint("RIGHT", left, "LEFT", -4, 0)
  box:SetChecked(ns:EnchantConfirm())
  box:SetShown(page.CreateButton:IsShown() and IsEnchant(page))
end
ns.EnchantConfirmUpdate = Update

local function Setup()
  local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
  if box or not (page and page.CreateButton) then return end
  box = CreateFrame("CheckButton", "ClaraEnchantConfirmBox", page, "UICheckButtonTemplate")
  box:SetSize(24, 24)
  local text = box.Text or box.text
  if text then
    text:ClearAllPoints()
    text:SetPoint("RIGHT", box, "LEFT", 0, 1)
    text:SetFontObject("GameFontNormalSmall")
    text:SetText(L.ENCHANT_CONFIRM)
  end
  box:SetHitRectInsets(text and -((text:GetStringWidth() or 60) + 2) or 0, 0, 0, 0)
  box:SetScript("OnClick", function(self)
    if PlaySound and SOUNDKIT then PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
    ns:SetEnchantConfirm(self:GetChecked() and true or false)
  end)
  box:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L.ENCHANT_CONFIRM, 1, 1, 1)
    GameTooltip:AddLine(L.ENCHANT_CONFIRM_TIP, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  box:Hide()
  if type(page.ValidateControls) == "function" then hooksecurefunc(page, "ValidateControls", Update) end
  page:HookScript("OnShow", Update)
  Update()
end
ns.EnchantConfirmSetup = Setup -- (for its test)
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", Setup)
end
