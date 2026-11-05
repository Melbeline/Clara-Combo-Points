-- Clara Combo Points - Alt + left click on an item in the bags disenchants it, for an enchanter:
-- one click, one Disenchant, on that item. The game's own secure button does it (its spell, and
-- the item it aims at: target-bag, target-slot), laid over the item while Alt is held and it can
-- be disenchanted (a weapon or armour, uncommon to epic). Over the game's bags and ClassicUI's
-- alike: their tooltip names the item (GameTooltip:SetBagItem). Not in a fight (the game moves no
-- such button then). A box in the game's options (Esc > Options > AddOns > Clara Combo Points)
-- turns it off.

local ADDON, ns = ...

local DISENCHANT = 13262
local issecret = issecretvalue or function() return false end

function ns:DisenchantClick() return not (self.sv and self.sv.disenchantClick == false) end

local button = CreateFrame("Button", "ClaraDisenchantButton", UIParent, "SecureActionButtonTemplate")
button:SetFrameStrata("TOOLTIP")
button:RegisterForClicks("LeftButtonUp") -- (the release only: one click, one cast)
for _, prefix in ipairs({ "", "alt-" }) do
  button:SetAttribute(prefix .. "type1", "spell")
  button:SetAttribute(prefix .. "spell1", DISENCHANT)
end
button:Hide()
local mark = button:CreateTexture(nil, "OVERLAY")
mark:SetAllPoints()
mark:SetColorTexture(0.64, 0.21, 0.93, 0.25) -- (the enchanting purple, light: the item still shows)

local last = {} -- the bag item whose tooltip showed last: its button, bag, slot
-- Alt pressed or let go heard only while a bag item's tooltip was shown last; the fight's start
-- only while the button shows (put away before it)
local events = CreateFrame("Frame")

local function Hide()
  if InCombatLockdown() or not button:IsShown() then return end
  button:Hide()
  button:ClearAllPoints()
  events:UnregisterEvent("PLAYER_REGEN_DISABLED")
end
ns.HideDisenchant = Hide

function ns:SetDisenchantClick(on)
  if not self.sv then return end
  if on then self.sv.disenchantClick = nil else self.sv.disenchantClick = false end
  if not on then Hide() end
end

local function Known()
  if IsPlayerSpell then return IsPlayerSpell(DISENCHANT) == true end
  return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(DISENCHANT) == true
end

-- A weapon or armour, uncommon to epic
local function Disenchantable(bag, slot)
  if not (C_Container and C_Container.GetContainerItemInfo and C_Item and C_Item.GetItemInfoInstant) then return false end
  local info = C_Container.GetContainerItemInfo(bag, slot)
  if type(info) ~= "table" or issecret(info.itemID) or issecret(info.quality) or not info.itemID then return false end
  local quality = info.quality
  if not quality or quality < 2 or quality > 4 then return false end
  local classID = select(6, C_Item.GetItemInfoInstant(info.itemID))
  return classID == 2 or classID == 4 -- (weapon, armour)
end

-- (a protected button's state can come back secret: never tested, counted as no)
local function Yes(f, method)
  if not (f and type(f[method]) == "function") then return false end
  local ok, v = pcall(f[method], f)
  return ok and not issecret(v) and v == true
end

local function Show()
  if InCombatLockdown() or not ns:DisenchantClick() or not IsAltKeyDown() then return end
  local owner = last.owner
  if not (Yes(owner, "IsVisible") and Yes(owner, "IsMouseOver")) then return end
  if not (Known() and Disenchantable(last.bag, last.slot)) then return end
  button:SetAttribute("target-bag", last.bag)
  button:SetAttribute("target-slot", last.slot)
  button:ClearAllPoints()
  button:SetAllPoints(owner)
  button:Show()
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
end

-- The item's tooltip, from over it
button:SetScript("OnEnter", function(self)
  if not last.bag then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetBagItem(last.bag, last.slot)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
  GameTooltip:Hide()
  Hide()
end)
button:HookScript("PostClick", Hide)

if GameTooltip and GameTooltip.SetBagItem then
  hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if not owner or owner == button then return end
    last.owner, last.bag, last.slot = owner, bag, slot
    if ns:DisenchantClick() and Known() then events:RegisterEvent("MODIFIER_STATE_CHANGED") end
    Show()
  end)
end

events:SetScript("OnEvent", function(self, event, key, down)
  if event == "PLAYER_REGEN_DISABLED" then
    Hide() -- (before the fight's lock)
  elseif key == "LALT" or key == "RALT" then
    local owner = last.owner
    if not button:IsShown() and not (Yes(owner, "IsVisible") and Yes(owner, "IsMouseOver")) then
      self:UnregisterEvent("MODIFIER_STATE_CHANGED") -- (off the bags: until the next item's tooltip)
      return
    end
    if down == 1 then Show() else Hide() end
  end
end)
