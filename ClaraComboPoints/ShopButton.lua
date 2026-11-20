-- Clara Combo Points - the game's Shop buttons open Clara instead: the micro menu's Shop button (its tooltip "Clara",
-- its "new" mark never shown, enabled whatever the store's state) and the Escape menu's Shop button (named "Clara").
-- A click opens Clara's options, as /clara does; the game's store itself is never opened from them. Only those two
-- buttons are touched: the Escape menu makes its buttons again each time it opens, each with its own click, so the
-- one changed here is changed again each time and no other button ever gets its click.

local ADDON, ns = ...

local TITLE = "Clara"

local function Open()
  if ns.ToggleOptions then ns:ToggleOptions() end
end

---------------------------------------------------------------------------
-- The micro menu's Shop button
---------------------------------------------------------------------------
local micro
local function Dress(button)
  button.tooltipText = TITLE
  if button.NotificationOverlay then button.NotificationOverlay:Hide() end
  if button.IsEnabled and not button:IsEnabled() and button.Enable then button:Enable() end
end
local function DressMicro()
  local button = _G.StoreMicroButton
  if micro or type(button) ~= "table" or not button.SetScript then return end
  micro = button
  button:SetScript("OnClick", function() Open() end)
  -- (the game sets its state again as the store's changes: Clara's tooltip, no "new" mark, enabled, each time)
  if hooksecurefunc then
    if type(button.UpdateMicroButton) == "function" then hooksecurefunc(button, "UpdateMicroButton", Dress) end
    if type(button.SetHasNotification) == "function" then hooksecurefunc(button, "SetHasNotification", Dress) end
  end
  Dress(button)
end
ns.ShopMicroButton = function() return micro end -- (for the tests)

---------------------------------------------------------------------------
-- The Escape menu's Shop button
---------------------------------------------------------------------------
local function DressMenu(menu)
  for _, button in ipairs(type(menu) == "table" and menu.buttons or {}) do
    if button.GetText and button:GetText() == BLIZZARD_STORE then
      button:SetText(TITLE)
      if button.SetEnabled then button:SetEnabled(true) end
      button:SetScript("OnEnter", nil)
      button:SetScript("OnLeave", nil)
      button:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION) end
        HideUIPanel(menu)
        Open()
      end)
    end
  end
end
ns.ShopDressMenu = DressMenu -- (for the tests)
local menuHooked = false
local function HookMenu()
  local menu = _G.GameMenuFrame
  if menuHooked or type(menu) ~= "table" or type(menu.InitButtons) ~= "function" or not hooksecurefunc then return end
  menuHooked = true
  hooksecurefunc(menu, "InitButtons", DressMenu)
  DressMenu(menu)
end

local function Hook()
  DressMicro()
  HookMenu()
end
Hook()
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self)
  Hook()
  if micro and menuHooked then self:UnregisterAllEvents() end
end)
