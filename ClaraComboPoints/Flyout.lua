-- Clara Combo Points - the character window's equipment flyout (Alt over a slot, or the arrow by it while the
-- equipment manager is open): the right column's (hands to trinkets) opens to its right, as the left column's does,
-- rather than over the model; the weapons' opens under them rather than above. Its first button (into the bags) sits
-- level with the slot, or right under it. The game's items and their order are kept. With the game's own window and
-- with ClassicUI Forever's, which keeps the game's slots.

local ADDON, ns = ...

local SIDE = { "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
  "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot" }
local UNDER = { "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }
local ARROW_GAP = 5 -- (the game's, between a slot and its arrow)
local GAP = 2       -- between the slot, or its arrow, and the flyout's border

local turned = {} -- slot -> "RIGHT" or "DOWN"

-- A slot's flyout turned, its arrow moved and pointing the new way.
local function Turn(name, direction)
  local slot = _G[name]
  if not slot then return end
  slot.flyoutDirection = direction
  turned[slot] = direction
  local arrow = slot.popoutButton
  if not arrow then return end
  arrow:ClearAllPoints()
  if direction == "DOWN" then
    arrow:SetPoint("TOP", slot, "BOTTOM", 0, -ARROW_GAP)
  else
    arrow:SetPoint("LEFT", slot, "RIGHT", ARROW_GAP, 0)
  end
  if EquipmentFlyoutPopoutButton_RefreshVisualState then EquipmentFlyoutPopoutButton_RefreshVisualState(arrow) end
end

-- After the game lays the flyout out (from the arrow, which is narrower than the slot): its buttons' frame from the
-- slot itself, so that its first button starts level with it (to its right) or right under it.
local function Place()
  local flyout = EquipmentFlyoutFrame
  local slot = flyout and flyout.button
  local direction = slot and turned[slot]
  local frame = flyout and flyout.buttonFrame
  if not (direction and frame) then return end
  local border = EQUIPMENTFLYOUT_BORDERWIDTH or 3
  local arrow = slot.popoutButton
  local arrowShown = arrow and arrow:IsShown()
  frame:ClearAllPoints()
  if direction == "DOWN" then
    local below = arrowShown and (ARROW_GAP + arrow:GetHeight()) or 0
    frame:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", -border, -(below + GAP))
  else
    local beside = arrowShown and (ARROW_GAP + arrow:GetWidth()) or 0
    frame:SetPoint("TOPLEFT", slot, "TOPRIGHT", beside + GAP, border)
  end
end

if not (EquipmentFlyout_UpdateItems and EquipmentFlyoutFrame) then return end

local setup = CreateFrame("Frame")
setup:RegisterEvent("PLAYER_LOGIN")
setup:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  for _, name in ipairs(SIDE) do Turn(name, "RIGHT") end
  for _, name in ipairs(UNDER) do Turn(name, "DOWN") end
  hooksecurefunc("EquipmentFlyout_UpdateItems", Place)
end)
