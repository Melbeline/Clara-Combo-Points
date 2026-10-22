-- Clara Combo Points - items on the icon rows (consumables: potions, elixirs, flasks, food,
-- scrolls, bandages, poisons, oils, stones...). A row keeps an item as "item:ID", next to the
-- spells. Its icon shows how many you carry, the item's cooldown, and the buff it gives while
-- it is up (an elixir, a flask, a scroll) or, for an item that enchants a weapon (a poison, an
-- oil, a stone), the enchantment while one of your weapons has it. A click uses it (a weapon's
-- item: left click on the main hand, right click on the off hand).

local _, ns = ...

local GetItemNameByID = C_Item and C_Item.GetItemNameByID
local GetItemIconByID = C_Item and C_Item.GetItemIconByID
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount
local GetItemCooldown = (C_Item and C_Item.GetItemCooldown) or (C_Container and C_Container.GetItemCooldown)
local RequestLoad = C_Item and C_Item.RequestLoadItemDataByID
local issecretvalue = issecretvalue or function() return false end

local CONSUMABLE, ENHANCEMENT = 0, 8 -- item classes
local CONSUMABLE_ENHANCEMENT = 6     -- consumable subclass: weapon enhancements

local function Plain(v)
  if not issecretvalue(v) and v ~= nil then return v end
  return nil -- (always a value: type(Plain(x)) must not get none)
end

-- The item ID of a row entry's "item:ID", else nil.
function ns:ItemOf(spell)
  return type(spell) == "string" and tonumber(spell:match("^item:(%d+)$")) or nil
end

-- "item:ID" for an item the game knows that has a use (a potion, a poison, a hearthstone...),
-- else nil: leather or a mace stays in the bags.
function ns:ItemEntry(id)
  id = tonumber(id)
  if not id or id <= 0 or id ~= math.floor(id) then return end
  if GetItemInfoInstant then
    local ok, known = pcall(GetItemInfoInstant, id)
    if not ok or not known then return end
  end
  if GetItemSpell and not self:ItemSpell(id) then return end
  return "item:" .. id
end

-- Names and icons come with the item's data, which the game may load later: asked for, and
-- the icons laid out again when it arrives (Core.lua: GET_ITEM_INFO_RECEIVED).
local waiting = {}
local function Ask(id)
  if RequestLoad and not waiting[id] then
    waiting[id] = true
    pcall(RequestLoad, id)
  end
end
function ns:ItemArrived(id)
  if waiting[id] then
    waiting[id] = nil
    return true
  end
end

function ns:ItemName(id)
  local name
  if GetItemNameByID then
    local ok, n = pcall(GetItemNameByID, id)
    if ok then name = Plain(n) end
  elseif GetItemInfo then
    local ok, n = pcall(GetItemInfo, id)
    if ok then name = Plain(n) end
  end
  if type(name) == "string" and name ~= "" then return name end
  Ask(id)
end

function ns:ItemIcon(id)
  local icon
  if GetItemIconByID then
    local ok, i = pcall(GetItemIconByID, id)
    if ok then icon = Plain(i) end
  end
  if not icon and GetItemInfoInstant then
    local ok, _, _, _, _, i = pcall(GetItemInfoInstant, id)
    if ok then icon = Plain(i) end
  end
  return icon
end

-- The spell the item casts when used: its name (the buff it gives often has it) and ID.
function ns:ItemSpell(id)
  if not GetItemSpell then return end
  local ok, name, spellID = pcall(GetItemSpell, id)
  if ok and type(Plain(name)) == "string" then return name, Plain(spellID) end
end

-- How many you carry (bags), or nil if unknown.
function ns:ItemCount(id)
  if not GetItemCount then return end
  local ok, n = pcall(GetItemCount, id)
  n = ok and Plain(n)
  if type(n) == "number" then return n end
end

-- The item's cooldown: start, duration (nil while there is none).
function ns:ItemCooldown(id)
  if not GetItemCooldown then return end
  local ok, start, duration, enable = pcall(GetItemCooldown, id)
  if not ok then return end
  if type(start) == "table" then -- (a cooldown info table)
    start, duration, enable = start.startTime, start.duration, start.isEnabled
  end
  start, duration = Plain(start), Plain(duration)
  if type(start) == "number" and type(duration) == "number" and start > 0 and duration > 0 and enable ~= false and enable ~= 0 then
    return start, duration
  end
end

---------------------------------------------------------------------------
-- Items that enchant a weapon: from their kind (weapon enhancements), or learned when one was
-- used and an enchantment showed up on a weapon. Each has an imbue key (Tracker.lua): the item
-- itself.
---------------------------------------------------------------------------
function ns:IsWeaponItem(id)
  if self.sv and self.sv.enchantItems and self.sv.enchantItems[id] then return true end
  if GetItemInfoInstant then
    local ok, _, _, _, _, _, class, subclass = pcall(GetItemInfoInstant, id)
    if ok and (class == ENHANCEMENT or (class == CONSUMABLE and subclass == CONSUMABLE_ENHANCEMENT)) then return true end
  end
  return false
end

-- The imbue key of a row entry that is a weapon's item (Tracker.lua: ns:ImbueKey).
function ns:ItemImbueKey(spell)
  local id = self:ItemOf(spell)
  if not id or not self:IsWeaponItem(id) then return end
  return "item:" .. id
end

-- The items on the rows, by the name of the spell they cast (rebuilt with the layout).
local bySpell = {}
function ns:WatchItemSpells(list)
  wipe(bySpell)
  for _, id in ipairs(list) do
    local name = self:ItemSpell(id)
    if name then
      bySpell[name] = bySpell[name] or {}
      table.insert(bySpell[name], id)
    end
  end
end

-- A spell cast: an item of the rows used. One that may enchant a weapon: the enchantment that
-- shows up next is its own (and from then on it is known to be a weapon's item).
function ns:ItemSpellDone(spell, name)
  for _, id in ipairs(bySpell[name] or {}) do
    self:ImbueStarted(self:ItemImbueKey("item:" .. id) or ("item:" .. id))
    return
  end
end

-- An enchantment learned for an item: that item enchants weapons.
function ns:ItemEnchantLearned(key)
  local id = tonumber(type(key) == "string" and key:match("^item:(%d+)$"))
  if not id or not self.sv or self.sv.enchantItems[id] then return end
  self.sv.enchantItems[id] = true
  self:LayoutIcons() -- its icon watches the weapons from now on
end
