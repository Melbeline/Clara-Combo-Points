-- Clara Combo Points - a click on an icon of the HUD casts its spell (icons locked), when the
-- character knows that spell; the other icons (a debuff on the target, another class's aura...)
-- take no click.
-- Casting needs the game's secure action buttons, which addons can neither move, show nor hide
-- in combat. They live in a layer of their own over the HUD (outside it, so that the HUD stays
-- free to move and hide in combat), placed on the icons out of combat; in combat they stay where
-- the icons were when it began. A druid's buttons only answer in the form they were placed in
-- (another form moves the icons).

local _, ns = ...

local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local SYNC_EVERY = .25 -- out of combat, the buttons follow the icons this often (when they moved)

local layer   -- the buttons' frame, a child of UIParent
local placed  -- what the buttons were placed for (nothing to do while it stays the same)
local buttons = {}

local function Known(id)
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  return C_SpellBook ~= nil and C_SpellBook.IsSpellKnown ~= nil and C_SpellBook.IsSpellKnown(id) == true
end

-- What a click on an icon casts: the rank chosen for it, else its spell by name (the highest
-- rank the character has); nothing when the character does not know it. Also its spell ID.
local function Castable(slot)
  local spell = slot.spell
  if spell == nil then return end
  if slot.exact then
    if type(spell) == "number" and Known(spell) then return spell, spell end
    return
  end
  local name = slot.name or (type(spell) == "string" and spell) or nil
  local info = name and GetSpellInfo and GetSpellInfo(name)
  if info and type(info.spellID) == "number" and Known(info.spellID) then return name, info.spellID end
  if type(spell) == "number" and Known(spell) then return spell, spell end
end

local function Tooltip(self)
  if not GameTooltip or not self.spellID then return end
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  if not (GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID)) then
    GameTooltip:SetText(tostring(self.spell))
  end
  GameTooltip:Show()
end

local function Button(i)
  local b = buttons[i]
  if b then return b end
  b = CreateFrame("Button", "ClaraComboPointsClick" .. i, layer, "SecureActionButtonTemplate")
  b:RegisterForClicks("LeftButtonUp")
  b:SetAttribute("useOnKeyDown", false)
  b:SetAttribute("type1", "spell")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnEnter", Tooltip)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  buttons[i] = b
  return b
end

-- The castable icons shown, each with its rect in UIParent units; none while the icons are
-- edited, the bar is unlocked or the HUD is hidden.
local function Wanted()
  local list, db = {}, ns.db
  if not (ns.enabled and db and db.locked and not ns:EditingIcons()) then return list end
  if not (ns.hud:IsVisible() and ns.iconLayer:IsVisible()) then return list end
  local ui = UIParent:GetEffectiveScale()
  ns:ForEachIcon(function(slot)
    if not slot:IsVisible() then return end
    local spell, id = Castable(slot)
    if spell == nil then return end
    local l, b, w, h = slot:GetRect()
    if not l then return end
    local s = slot:GetEffectiveScale() / ui
    list[#list + 1] = { spell = spell, id = id, l = l * s, b = b * s, w = w * s, h = h * s }
  end)
  return list
end

-- A druid's buttons only show in the form they were placed in.
local function FormDriver()
  local _, class = UnitClass("player")
  if class ~= "DRUID" or not GetShapeshiftForm then return end
  local form = GetShapeshiftForm()
  if type(form) ~= "number" or issecretvalue and issecretvalue(form) then return end
  if form > 0 then return ("[form:%d] show; hide"):format(form) end
  return "[noform] show; hide"
end

-- Puts the buttons on the icons (out of combat; in combat, nothing can move them).
function ns:SyncClickers()
  if not self.hud or InCombatLockdown() then return end
  if not layer then
    layer = CreateFrame("Frame", "ClaraComboPointsClicks", UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata(self.hud:GetFrameStrata())
    layer:SetFrameLevel(self.hud:GetFrameLevel() + 50)
  end
  local list = Wanted()
  local driver = #list > 0 and FormDriver() or nil
  local parts = { driver or "" }
  for _, w in ipairs(list) do
    parts[#parts + 1] = ("%s:%.1f:%.1f:%.1f:%.1f"):format(tostring(w.spell), w.l, w.b, w.w, w.h)
  end
  local key = table.concat(parts, "|")
  if key == placed then return end
  placed = key
  for i, w in ipairs(list) do
    local b = Button(i)
    b:SetAttribute("spell", w.spell)
    b.spell, b.spellID = w.spell, w.id
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", w.l, w.b)
    b:SetSize(w.w, w.h)
    b:Show()
  end
  for i = #list + 1, #buttons do buttons[i]:Hide() end
  if driver then
    RegisterStateDriver(layer, "visibility", driver)
  else
    UnregisterStateDriver(layer, "visibility")
    layer:Show()
  end
end

-- The castable spells and the buttons now (for /cl debug and the tests).
function ns:ClickButtons() return buttons, layer end

-- Out of combat the buttons follow the icons (moved, resized, shown or hidden); the last chance
-- is the moment combat starts.
local ticker = CreateFrame("Frame")
local wait = 0
table.insert(ns.onEnable, function()
  ticker:SetScript("OnUpdate", function(_, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = SYNC_EVERY
    if not InCombatLockdown() then ns:SyncClickers() end
  end)
  ticker:RegisterEvent("PLAYER_REGEN_DISABLED")
  ticker:RegisterEvent("SPELLS_CHANGED")
  ticker:SetScript("OnEvent", function() ns:SyncClickers() end)
end)
