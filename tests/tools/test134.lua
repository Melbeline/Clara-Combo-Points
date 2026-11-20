-- The game's Shop buttons open Clara (ShopButton.lua): the micro menu's (a click opens Clara's options, its tooltip
-- "Clara", its "new" mark never shown, enabled whatever the store's state) and the Escape menu's (named "Clara", a
-- click hides the menu and opens Clara's options); the Escape menu's other buttons untouched, its Shop button changed
-- again each time the menu makes its buttons
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

BLIZZARD_STORE = "Shop"
local storeOpened = 0
function ToggleStoreUI() storeOpened = storeOpened + 1 end
-- the game's micro menu Shop button (StoreMicroButtonMixin)
StoreMicroButton = CreateFrame("Button", "StoreMicroButton", UIParent)
StoreMicroButton.tooltipText = BLIZZARD_STORE
StoreMicroButton.NotificationOverlay = StoreMicroButton:CreateTexture()
StoreMicroButton:SetScript("OnClick", function() ToggleStoreUI() end)
function StoreMicroButton:SetHasNotification(has) self.NotificationOverlay:SetShown(has) end
function StoreMicroButton:UpdateMicroButton() self:SetHasNotification(true) end
-- the game's Escape menu: its buttons made again each time it opens (MainMenuFrameMixin.AddButton)
GameMenuFrame = CreateFrame("Frame", "GameMenuFrame", UIParent)
local pool = {}
function GameMenuFrame:InitButtons()
  self.buttons = {}
  for i, entry in ipairs({ { "Options" }, { BLIZZARD_STORE, function() ToggleStoreUI() end }, { "AddOns" }, { "Log Out" } }) do
    local b = pool[i] or CreateFrame("Button", nil, self)
    pool[i] = b
    b:SetText(entry[1])
    b:SetScript("OnClick", entry[2] or function() self.clicked = entry[1] end)
    table.insert(self.buttons, b)
  end
end
local hidden = 0
function HideUIPanel(f) if f == GameMenuFrame then hidden = hidden + 1 end end

local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local opened = 0
ns.ToggleOptions = function() opened = opened + 1 end

out("== the micro menu's Shop button")
check(ns.ShopMicroButton() == StoreMicroButton, "taken")
StoreMicroButton:GetScript("OnClick")(StoreMicroButton, "LeftButton")
check(opened == 1 and storeOpened == 0, "a click: Clara's options, not the store")
check(StoreMicroButton.tooltipText == "Clara", "its tooltip: Clara")
StoreMicroButton:SetHasNotification(true)
check(not StoreMicroButton.NotificationOverlay:IsShown(), "its new mark never shown")
StoreMicroButton:Disable()
StoreMicroButton:UpdateMicroButton()
check(StoreMicroButton:IsEnabled() and StoreMicroButton.tooltipText == "Clara" and not StoreMicroButton.NotificationOverlay:IsShown(),
  "the game setting its state again: still Clara, enabled, no mark")

out("== the Escape menu's Shop button")
GameMenuFrame:InitButtons()
local shop = GameMenuFrame.buttons[2]
check(shop:GetText() == "Clara", "named Clara")
shop:GetScript("OnClick")(shop)
check(opened == 2 and hidden == 1 and storeOpened == 0, "a click: the menu hidden, Clara's options, not the store")
GameMenuFrame.buttons[4]:GetScript("OnClick")(GameMenuFrame.buttons[4])
check(GameMenuFrame.clicked == "Log Out" and GameMenuFrame.buttons[1]:GetText() == "Options" and GameMenuFrame.buttons[4]:GetText() == "Log Out",
  "the other buttons untouched")
GameMenuFrame:InitButtons()
check(GameMenuFrame.buttons[2]:GetText() == "Clara", "made again as the menu opens again: Clara again")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
