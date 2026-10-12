-- Clara Combo Points - buff, debuff and spell icons
-- Up to three rows above the HUD (growing upward) and three below the bar (growing downward),
-- 20 icons each. Warriors start with one row where the combo points would be: Sunder Armor,
-- Demoralizing Shout, Hamstring, Battle Shout, Bloodrage.
--
-- Spells are kept as IDs (or names) and looked up by spell name, so every rank matches (unless
-- one rank is picked), in every client language. Each icon watches where its entry says (auto:
-- your buffs, then the target's debuffs, then your debuffs; or only you, or only the target,
-- any / enemy / friendly) and shows, in this order:
--   - the aura when it is up, with its stacks and time left;
--   - else the spell's own cooldown (not the global cooldown) when it runs;
--   - else the spell ready (spells with a cooldown) or the aura missing (grayed out).
-- Icons look like the action bar buttons: the game's button frame around them, the art kept
-- inside it by the button's mask, its cooldown swipe and countdown numbers ("2m" from two
-- minutes up, then "1:59", then seconds), charges and stacks bottom right.
--
-- Shapes: the row shares the bar's width (cells cropped, not stretched), or each icon is a
-- combo point cell, or square at the chosen size.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local issecretvalue = issecretvalue or function() return false end
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo) or nil
local GetSpellCooldown = C_Spell and C_Spell.GetSpellCooldown
local GetSpellCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration
local GetSpellCharges = C_Spell and C_Spell.GetSpellCharges
local GetDisplayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local FRAME_ATLAS = "UI-HUD-ActionBar-IconFrame" -- the action button frame
local FONT = "Fonts\\FRIZQT__.TTF"
local TRIM = .08             -- icon border cut off
local CORNER = .22           -- share of the button frame (and of the icon's short side) in a corner
local MISSING_ALPHA = .45
local GCD = 1.5              -- a cooldown this short is only the global cooldown
local ABBREV = 120           -- countdown: "2m" from two minutes up, "1:59" below
local MASK_ATLAS = "UI-HUD-ActionBar-IconFrame-Mask" -- keeps the icon art inside the frame
local MASK_SCALE = 64 / 45
local CAST_WINDOW = 1.5      -- an aura that appears this soon after your cast of the same spell is that spell's
-- where each icon looks for its aura (on = the entry's condition; auto for plain entries)
local LOOKUPS = {
  auto   = { { "player", "HELPFUL" }, { "target", "HARMFUL" }, { "player", "HARMFUL" } },
  self   = { { "player", "HELPFUL" }, { "player", "HARMFUL" } },
  target = { { "target", "HELPFUL" }, { "target", "HARMFUL" } },
  enemy  = { { "target", "HARMFUL" }, { "target", "HELPFUL" } },
  friend = { { "target", "HELPFUL" }, { "target", "HARMFUL" } },
}
ns.CONDITIONS = { "auto", "self", "target", "enemy", "friend" }
local GetUnitAuraInstanceIDs = C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs
local GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
local GetAuraDataByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local IsSpellHarmful = C_Spell and C_Spell.IsSpellHarmful
local IsSpellHelpful = C_Spell and C_Spell.IsSpellHelpful

-- A row entry: a spell ID or name, or { spell = ID or name, on = condition, exact = true }
-- (exact: this rank only).
function ns:EntrySpell(entry) if type(entry) == "table" then return entry.spell end return entry end
function ns:EntryOn(entry) return type(entry) == "table" and entry.on or "auto" end

local rows = { above = {}, below = {} }
local dirty

local function Plain(v)
  if not issecretvalue(v) and type(v) == "number" then return v end
end

-- Lower case, accented capitals included (string.lower leaves "É" or "Ü" as they are).
local function Fold(s)
  return (s:lower():gsub("\195([\128-\158])", function(c) return "\195" .. string.char(c:byte() + 32) end))
end
ns.Fold = function(_, s) return Fold(s) end

function ns:SpellIcon(spell)
  if GetSpellTexture then
    local ok, icon = pcall(GetSpellTexture, spell)
    if ok and icon and not issecretvalue(icon) then return icon end
  end
  return QUESTION_MARK
end

-- The icon of a row entry's spell (one tracked by name: its icon once seen).
function ns:EntryIcon(spell)
  local icon = self:SpellIcon(spell)
  if icon == QUESTION_MARK and self:SpellName(spell) then return self:SeenIcon(self:SpellName(spell)) end
  return icon
end

-- Icons of spells tracked by name (unknown to this character), learned when the aura is seen.
function ns:SeenIcon(name)
  local seen = self.sv and self.sv.seenIcons
  return seen and seen[name] or QUESTION_MARK
end

function ns:RememberIcon(name, icon)
  if self.sv and name and (type(icon) == "number" or type(icon) == "string") then
    self.sv.seenIcons[name] = icon
  end
end

local function RowName(side, k)
  return (side == "above" and L.ROW_ABOVE or L.ROW_BELOW):format(k)
end
ns.RowName = function(_, side, k) return RowName(side, k) end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
-- The button frame art, cut in nine so it fits square icons and combo-point-shaped cells
-- alike (corners keep their size, edges stretch). Without atlas info: drawn whole.
local frameArt
local function FrameArt()
  if frameArt == nil then
    frameArt = false
    if C_Texture and C_Texture.GetAtlasInfo then
      local ok, info = pcall(C_Texture.GetAtlasInfo, FRAME_ATLAS)
      if ok and type(info) == "table" and info.file and Plain(info.leftTexCoord) then
        frameArt = { file = info.file, info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord }
      end
    end
  end
  return frameArt
end

local PIECES = { -- column, row (1 = left/top, 2 = middle, 3 = right/bottom)
  { 1, 1 }, { 2, 1 }, { 3, 1 }, { 1, 2 }, { 3, 2 }, { 1, 3 }, { 2, 3 }, { 3, 3 },
}

local function LayoutFrame(slot, w, h)
  local art = FrameArt()
  if not art then
    slot.frame[1]:SetAllPoints()
    slot.frame[1]:SetAtlas(FRAME_ATLAS)
    return
  end
  local c = min(w, h) * CORNER
  local l, r, t, b = art[1], art[2], art[3], art[4]
  local du, dv = (r - l) * CORNER, (b - t) * CORNER
  local us = { l, l + du, r - du, r }
  local vs = { t, t + dv, b - dv, b }
  local xs = { 0, c, w - c, w }
  local ys = { 0, c, h - c, h }
  for i, piece in ipairs(PIECES) do
    local tex, col, row = slot.frame[i], piece[1], piece[2]
    tex:SetTexture(art.file)
    tex:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", slot, "TOPLEFT", xs[col], -ys[row])
    tex:SetSize(xs[col + 1] - xs[col], ys[row + 1] - ys[row])
  end
end

local function NewSlot(row)
  local slot = CreateFrame("Frame", nil, row)
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon:SetAllPoints()
  -- the button's own mask: the art stays inside the frame's rounded corners
  -- (drawn 64/45 of the icon's size, as the game's buttons do: its opaque part is 45/64 of it)
  if slot.CreateMaskTexture and slot.icon.AddMaskTexture then
    slot.mask = slot:CreateMaskTexture()
    slot.mask:SetAtlas(MASK_ATLAS)
    slot.mask:SetPoint("CENTER", slot.icon)
    slot.icon:AddMaskTexture(slot.mask)
  end
  -- swipe and countdown numbers, like an action button
  slot.cd = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
  slot.cd:SetDrawBling(false)
  slot.cd:SetDrawEdge(false)
  if slot.cd.SetCountdownAbbrevThreshold then slot.cd:SetCountdownAbbrevThreshold(ABBREV) end
  -- button frame and count above the swipe
  slot.over = CreateFrame("Frame", nil, slot)
  slot.over:SetAllPoints()
  slot.over:SetFrameLevel(slot:GetFrameLevel() + 3)
  slot.frame = {}
  for i = 1, FrameArt() and #PIECES or 1 do slot.frame[i] = slot.over:CreateTexture(nil, "OVERLAY") end
  slot.count = slot.over:CreateFontString(nil, "OVERLAY")
  return slot
end

local function GetRow(side, k)
  local row = rows[side][k]
  if not row then
    row = CreateFrame("Frame", nil, ns.iconLayer)
    row.slots = {}
    rows[side][k] = row
  end
  return row
end

-- Shows the middle of the icon in a w x h area, without stretching it.
local function Crop(tex, w, h)
  local span = 1 - 2 * TRIM
  if w >= h then
    local half = span * h / w / 2
    tex:SetTexCoord(TRIM, 1 - TRIM, .5 - half, .5 + half)
  else
    local half = span * w / h / 2
    tex:SetTexCoord(.5 - half, .5 + half, TRIM, 1 - TRIM)
  end
end

local function SetSlotFonts(slot, w, h)
  local s = min(w, h)
  local countFont = NumberFontNormal and NumberFontNormal.GetFont and NumberFontNormal:GetFont() or FONT
  slot.count:SetFont(countFont, max(8, floor(s * .4)), "OUTLINE")
  slot.count:ClearAllPoints()
  slot.count:SetPoint("BOTTOMRIGHT", -max(1, s * 5 / 45), max(1, s * 5 / 45))
  local fs = slot.cd.GetCountdownFontString and slot.cd:GetCountdownFontString()
  if fs then
    local path = fs:GetFont()
    fs:SetFont(path or FONT, max(9, floor(s * .48)), "OUTLINE")
  end
end

-- Spells known to have a cooldown of their own: ready, they show lit rather than grayed out.
local function HasCooldown(slot)
  local learned = ns.sv and ns.sv.cooldownSpells
  if slot.name and learned and learned[slot.name] then return true end
  if type(slot.spell) == "number" and GetSpellBaseCooldown then
    local ok, ms = pcall(GetSpellBaseCooldown, slot.spell)
    if ok and Plain(ms) and ms > GCD * 1000 then return true end
  end
  return false
end

-- Harmful (put on enemies) or helpful, when the game says.
local function Yes(fn, spell)
  if not fn then return nil end
  local ok, v = pcall(fn, spell)
  return ok and not issecretvalue(v) and v == true or nil
end
local function SpellNature(spell)
  if type(spell) ~= "number" then return end
  return Yes(IsSpellHarmful, spell), Yes(IsSpellHelpful, spell)
end

function ns:LayoutIcons()
  local db = self.db
  if not db then return end
  local look = db.icons
  local shape = look.shape
  local size = shape == "CELL" and self.CP_HEIGHT or look.size
  local cellW = (self.WIDTH - 4 * self.CP_GAP) / 5 -- a combo point cell
  for _, side in ipairs(self.SIDES) do
    -- each row sits on the previous one; empty rows take no room
    -- (in Bear Form without combo points, the rows above sit on the rage bar: see Core.lua)
    local anchor = self.powerBar
    if side == "above" and self.comboRow:IsShown() and not self.iconsOnBar then anchor = self.comboRow end
    for k = 1, self.MAX_ROWS do
      local spells = db.rows[side][k]
      local row = GetRow(side, k)
      local n = #spells
      row.spells = spells
      for i = n + 1, #row.slots do row.slots[i]:Hide() end
      if n == 0 then
        row:Hide()
      else
        -- FILL: the row shares the bar's width; CELL: each icon the size of a combo point
        -- cell, however many there are; SQUARE: square icons. CELL and SQUARE rows are
        -- centred on the bar.
        local w = (shape == "SQUARE" and size) or (shape == "CELL" and cellW)
          or (self.WIDTH - (n - 1) * self.CP_GAP) / n
        row:ClearAllPoints()
        row:SetSize(shape == "FILL" and self.WIDTH or (n * w + (n - 1) * self.CP_GAP), size)
        if side == "above" then
          row:SetPoint("BOTTOM", anchor, "TOP", 0, self.ROW_GAP)
        else
          row:SetPoint("TOP", anchor, "BOTTOM", 0, -self.ROW_GAP)
        end
        anchor = row
        for i = 1, n do
          local slot = row.slots[i] or NewSlot(row)
          row.slots[i] = slot
          slot:ClearAllPoints()
          slot:SetSize(w, size)
          slot:SetPoint("TOPLEFT", (i - 1) * (w + self.CP_GAP), 0)
          Crop(slot.icon, w, size)
          if slot.mask then slot.mask:SetSize(w * MASK_SCALE, size * MASK_SCALE) end
          LayoutFrame(slot, w, size)
          local inset = min(w, size) * 3 / 45
          slot.cd:ClearAllPoints()
          slot.cd:SetPoint("TOPLEFT", inset, -inset)
          slot.cd:SetPoint("BOTTOMRIGHT", -inset, inset)
          SetSlotFonts(slot, w, size)
          local spell, on = self:EntrySpell(spells[i]), self:EntryOn(spells[i])
          local exactFlag = type(spells[i]) == "table" and spells[i].exact or nil
          if slot.spell ~= spell or slot.on ~= on or slot.exactFlag ~= exactFlag then
            slot.inst = nil -- another spell, or another place or rank to watch
          end
          slot.spell, slot.on, slot.exactFlag = spell, on, exactFlag
          slot.exact = type(spells[i]) == "table" and spells[i].exact and type(spell) == "number" and self:RankIDs(spell) or nil
          slot.name = self:SpellName(spell)
          slot.byName = type(spell) == "string"
          slot.harmful, slot.helpful = SpellNature(spell)
          slot.spellIcon = self:SpellIcon(spell)
          if slot.spellIcon == QUESTION_MARK and slot.name then slot.spellIcon = self:SeenIcon(slot.name) end
          slot.hasCooldown = HasCooldown(slot)
        end
        row:Show()
      end
    end
    if side == "above" then self:AnchorMoverText(anchor) end
  end
  self:MarkIconsDirty() -- states read on the next frame, once
end

---------------------------------------------------------------------------
-- Live state
---------------------------------------------------------------------------
local function Bool(v) return not issecretvalue(v) and v == true end

-- Is the target one this icon watches? (any target, or only an enemy / a friend)
local function TargetFits(on)
  if not UnitExists("target") then return false end
  if on == "enemy" then return Bool(UnitCanAttack("player", "target")) end
  if on == "friend" then return not Bool(UnitCanAttack("player", "target")) end
  return true
end

local function TargetGUID()
  local guid = UnitGUID and UnitGUID("target")
  if not issecretvalue(guid) then return guid end
end

-- A spell typed by name and unknown to this character ("renew"): the unit's auras are read one
-- by one, without minding upper / lower case.
local function ScanAuras(unit, name, filter)
  if not GetAuraDataByIndex then return end
  local wanted = Fold(name)
  for i = 1, 255 do
    local ok, aura = pcall(GetAuraDataByIndex, unit, i, filter)
    if not ok or issecretvalue(aura) or type(aura) ~= "table" then return end
    local auraName = aura.name
    if not issecretvalue(auraName) and type(auraName) == "string" and Fold(auraName) == wanted then return aura end
  end
end

-- By name, where the icon's condition says. Only works while the game shows the aura to
-- addons (out of combat; in combat the game hides most auras): see the instance tracking.
-- Also says when the aura is there in another rank than the one watched.
local function FindAura(slot)
  local otherRank
  for _, lookup in ipairs(LOOKUPS[slot.on] or LOOKUPS.auto) do
    local unit = lookup[1]
    if unit ~= "target" or TargetFits(slot.on) then
      local aura = ns:FindAura(unit, slot.name, lookup[2])
      if not aura and slot.byName then aura = ScanAuras(unit, slot.name, lookup[2]) end
      if aura then
        if not slot.exact or issecretvalue(aura.spellId) or slot.exact[aura.spellId] then return aura, unit end
        otherRank = true
      end
    end
  end
  return nil, nil, otherRank
end

---------------------------------------------------------------------------
-- In combat the game hides aura details from addons, but still lists each unit's aura
-- instances. An aura seen out of combat is followed by its instance; one that appears just
-- after you cast the same spell is taken to be that spell's. Time left and stacks then come
-- from the game's own duration object and stack text, which addons may display.
---------------------------------------------------------------------------
local present = { player = {}, target = {} }   -- aura instances on each unit now: HELPFUL / HARMFUL
local fresh = { player = {}, target = {} }     -- instances that appeared lately: time
local casts = {}                               -- spell name (lower case) -> { time, spell ID } of your last cast

local function ListAuras(unit)
  local set = {}
  if not GetUnitAuraInstanceIDs or (unit == "target" and not UnitExists("target")) then return set end
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    local ok, ids = pcall(GetUnitAuraInstanceIDs, unit, filter)
    if ok and not issecretvalue(ids) and type(ids) == "table" then
      for _, id in ipairs(ids) do
        if Plain(id) then set[id] = filter end
      end
    end
  end
  return set
end

-- Target changes, counted (the target's GUID may be hidden from addons).
local targetEpoch, seenEpoch = 0, 0
function ns:TargetChanged()
  targetEpoch = targetEpoch + 1
  self:MarkIconsDirty()
end

local function RefreshInstances()
  local now = GetTime()
  if targetEpoch ~= seenEpoch then
    seenEpoch = targetEpoch
    wipe(fresh.target)
    present.target = ListAuras("target") -- another target: the auras it has are not new
  end
  for unit, old in pairs(present) do
    local set = ListAuras(unit)
    for id in pairs(set) do
      if not old[id] then fresh[unit][id] = now end
    end
    for id, t in pairs(fresh[unit]) do
      if not set[id] or now - t > CAST_WINDOW then fresh[unit][id] = nil end
    end
    present[unit] = set
  end
end

-- Your cast of a spell (Core.lua forwards UNIT_SPELLCAST_SUCCEEDED for the player).
function ns:NoteCast(spellID)
  local name = Plain(spellID) and self:SpellName(spellID)
  if name then
    casts[Fold(name)] = { GetTime(), spellID, targetEpoch }
    self:MarkIconsDirty()
  end
end

local function Remember(slot, unit, aura)
  local id = Plain(aura.auraInstanceID)
  if not id then return end
  local icon = aura.icon
  slot.inst = { unit = unit, id = id, guid = unit == "target" and TargetGUID() or nil, epoch = targetEpoch,
    icon = (not issecretvalue(icon) and icon) or slot.spellIcon }
end

-- The aura this icon follows, if it is still there. One on a target counts while that target
-- stays targeted, or again when it is targeted back (if its GUID can be read).
local function Followed(slot)
  local inst = slot.inst
  if not inst then return end
  if inst.unit == "target" then
    if not TargetFits(slot.on) then return end
    if inst.epoch ~= targetEpoch then
      local guid = TargetGUID()
      if not (guid and inst.guid == guid) then return end
      inst.epoch = targetEpoch
    end
  end
  if present[inst.unit][inst.id] then return inst end
  slot.inst = nil -- gone
end

-- Where a cast of this icon's spell puts its aura. Without a condition: a harmful spell on
-- the target, a helpful one on you or your target.
local HARMFUL_CAST = { { "target", "HARMFUL" } }
local HELPFUL_CAST = { { "player", "HELPFUL" }, { "target", "HELPFUL" } }
local function CastLookups(slot)
  if slot.on == "auto" then
    if slot.harmful then return HARMFUL_CAST end
    if slot.helpful then return HELPFUL_CAST end
  end
  return LOOKUPS[slot.on] or LOOKUPS.auto
end

-- An aura that appeared just after your cast of this icon's spell, where the icon looks.
local function JustCast(slot)
  local last = slot.name and casts[Fold(slot.name)]
  if not last or GetTime() - last[1] > CAST_WINDOW or (slot.exact and not slot.exact[last[2]]) then return end
  local cast = last[1]
  for _, lookup in ipairs(CastLookups(slot)) do
    local unit = lookup[1]
    if unit ~= "target" or (TargetFits(slot.on) and last[3] == targetEpoch) then -- still the target cast on
      local newest, when
      for id, t in pairs(fresh[unit]) do
        if present[unit][id] == lookup[2] and t >= cast - .2 and (not when or t > when) then newest, when = id, t end
      end
      if newest then
        fresh[unit][newest] = nil
        slot.inst = { unit = unit, id = newest, guid = unit == "target" and TargetGUID() or nil, epoch = targetEpoch, icon = slot.spellIcon }
        return slot.inst
      end
    end
  end
end

-- The spell's own cooldown, global cooldown left out: put on the swipe, true while it runs.
local function SpellCooldown(slot)
  if not GetSpellCooldown or not slot.name then return false end
  local ok, info = pcall(GetSpellCooldown, slot.name)
  if not ok or issecretvalue(info) or type(info) ~= "table" then return false end -- unknown spell
  if info.isActive ~= true or info.isOnGCD == true then return false end
  local duration = Plain(info.duration)
  if duration and duration <= GCD then return false end
  if duration and slot.name and ns.sv and not ns.sv.cooldownSpells[slot.name] then
    ns.sv.cooldownSpells[slot.name] = true -- lit when ready from now on
    slot.hasCooldown = true
  end
  if GetSpellCooldownDuration and slot.cd.SetCooldownFromDurationObject then
    local okD, d = pcall(GetSpellCooldownDuration, slot.name, true)
    if okD and d and pcall(slot.cd.SetCooldownFromDurationObject, slot.cd, d, true) then return true end
  end
  local start = Plain(info.startTime)
  if start and duration then
    slot.cd:SetCooldown(start, duration, Plain(info.modRate) or 1)
    return true
  end
  return false
end

-- Charges of a spell that has some (possibly secret: only handed to SetText).
local function Charges(slot)
  if not GetSpellCharges or not slot.name then return end
  local ok, info = pcall(GetSpellCharges, slot.name)
  if ok and not issecretvalue(info) and type(info) == "table" then
    local most = Plain(info.maxCharges)
    if most and most > 1 then return info.currentCharges end
  end
end

-- The aura an icon shows: found by name, else followed or just cast. Runs while the bar is
-- hidden too (a druid out of Cat and Bear Form), so the buffs cast meanwhile are followed.
local function Track(slot)
  if not slot.name then return end
  local aura, unit, otherRank = FindAura(slot)
  if aura then
    Remember(slot, unit, aura)
    return aura, unit
  end
  if otherRank then
    slot.inst = nil -- seen, in another rank: not this one
    return
  end
  return nil, nil, Followed(slot) or JustCast(slot)
end

local function SetSlot(slot, look, aura, unit, inst)
  slot.cd:Clear()
  slot.cd:SetReverse(false)
  if slot.cd.SetHideCountdownNumbers then slot.cd:SetHideCountdownNumbers(not look.timers) end
  slot.count:SetText("")
  local running
  if ns.preview then
    -- a sample: lit, with a cooldown under way
    slot.icon:SetTexture(slot.spellIcon)
    slot.icon:SetDesaturated(false)
    slot:SetAlpha(1)
    slot:Show()
    slot.cd:SetCooldown(GetTime() - 15, 45)
    return
  end
  if aura then
    local icon = aura.icon
    if issecretvalue(icon) or not icon then
      icon = slot.spellIcon
    elseif slot.spellIcon == QUESTION_MARK then
      slot.spellIcon = icon -- a spell tracked by name: its icon is known from now on
      ns:RememberIcon(slot.name, icon)
    end
    slot.icon:SetTexture(icon)
    local ends, duration = Plain(aura.expirationTime), Plain(aura.duration)
    if ends and duration then
      if ends > 0 and duration > 0 then
        slot.cd:SetReverse(look.reverse)
        slot.cd:SetCooldown(ends - duration, duration)
      end
    elseif GetAuraDuration and slot.cd.SetCooldownFromDurationObject then
      -- times hidden: the game's duration object (possibly secret, only handed to the swipe)
      local ok, d = pcall(GetAuraDuration, unit, aura.auraInstanceID)
      if ok and d then
        slot.cd:SetReverse(look.reverse)
        pcall(slot.cd.SetCooldownFromDurationObject, slot.cd, d, true)
      end
    end
    local stacks = aura.applications
    if issecretvalue(stacks) then
      if GetDisplayCount then
        local ok, text = pcall(GetDisplayCount, unit, aura.auraInstanceID, 2)
        if ok then slot.count:SetText(text) end -- possibly secret: only handed to SetText
      end
    elseif type(stacks) == "number" and stacks > 1 then
      slot.count:SetText(stacks)
    end
  elseif inst then
    -- hidden details (in combat): the game's duration object and stack text
    slot.icon:SetTexture(inst.icon or slot.spellIcon)
    if GetAuraDuration then
      local ok, d = pcall(GetAuraDuration, inst.unit, inst.id)
      if ok and d and slot.cd.SetCooldownFromDurationObject then
        slot.cd:SetReverse(look.reverse)
        pcall(slot.cd.SetCooldownFromDurationObject, slot.cd, d, true)
      end
    end
    if GetDisplayCount then
      local ok, text = pcall(GetDisplayCount, inst.unit, inst.id, 2)
      if ok then slot.count:SetText(text) end
    end
  else
    slot.icon:SetTexture(slot.spellIcon)
    running = SpellCooldown(slot)
  end
  if not inst and not (aura and Plain(aura.applications) and aura.applications > 1) then
    local charges = Charges(slot)
    if charges ~= nil then slot.count:SetText(charges) end
  end
  local lit = aura or inst or running or slot.hasCooldown
  slot.icon:SetDesaturated(not lit)
  slot:SetAlpha(lit and 1 or MISSING_ALPHA)
  slot:SetShown(lit or look.missing)
end

function ns:UpdateIcons()
  dirty = false
  if not self.db then return end
  RefreshInstances()
  local shown, look = self.hud:IsShown(), self.db.icons
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      for i = 1, #(row.spells or {}) do
        local slot = row.slots[i]
        local aura, unit, inst = Track(slot)
        if shown then SetSlot(slot, look, aura, unit, inst) end -- (drawn when the bar shows again)
      end
    end
  end
end

-- While the bar is hidden its OnUpdate does not run: this frame catches up instead.
local catchUp = CreateFrame("Frame")
catchUp:Hide()
catchUp:SetScript("OnUpdate", function(self)
  self:Hide()
  ns:UpdateIconsIfDirty()
end)

-- Aura and cooldown events can come in bursts: the icons are refreshed once, on the next frame.
function ns:MarkIconsDirty()
  dirty = true
  if self.hud and not self.hud:IsShown() then catchUp:Show() end
end

function ns:UpdateIconsIfDirty()
  if dirty then self:UpdateIcons() end
end

---------------------------------------------------------------------------
-- Editing (options)
---------------------------------------------------------------------------
-- A spell's ID from its name in the client's language: your spellbook first, then the class
-- spell lists (spells of other classes), then the auras on you and your target, without
-- minding upper / lower case.
function ns:SpellByName(text)
  if GetSpellInfo then
    local ok, info = pcall(GetSpellInfo, text)
    if ok and type(info) == "table" and Plain(info.spellID) then return info.spellID end
  end
  local rec = self:CatalogRecord(text)
  if rec then return rec.ranks[#rec.ranks][2] end -- its highest rank
  for _, unit in ipairs({ "player", "target" }) do
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
      local aura = UnitExists(unit) and ScanAuras(unit, text, filter)
      if aura and Plain(aura.spellId) and self:SpellName(aura.spellId) then return aura.spellId end
    end
  end
end

-- "7386", a spell link, or a name. A known name is stored as its ID (so it follows the
-- client language); an unknown one is tracked by the name as typed.
function ns:ParseSpell(text)
  text = tostring(text or ""):match("^%s*(.-)%s*$")
  if text == "" then return end
  local id = tonumber(text) or tonumber(text:match("spell:(%d+)"))
  if id then
    if id > 0 and id == floor(id) and self:SpellName(id) then return id end
    return nil, L.UNKNOWN_ID:format(text)
  end
  text = text:match("^%[(.+)%]$") or text
  local found = self:SpellByName(text)
  if found then return found end
  return text, nil, true
end

-- Same spell watched the same way (the same spell may be watched on you and on the target,
-- and one rank apart from all ranks).
local function Exact(entry) return type(entry) == "table" and entry.exact or nil end
local function Same(a, b)
  if ns:EntryOn(a) ~= ns:EntryOn(b) then return false end
  local sa, sb = ns:EntrySpell(a), ns:EntrySpell(b)
  if sa == sb then return Exact(a) == Exact(b) end
  if Exact(a) or Exact(b) then return false end
  local na, nb = ns:SpellName(sa), ns:SpellName(sb)
  return na ~= nil and nb ~= nil and Fold(na) == Fold(nb)
end

local function Duplicate(spells, entry, except)
  for i, other in ipairs(spells) do
    if i ~= except and Same(other, entry) then return true end
  end
end
function ns:IsDuplicate(spells, entry, except) return Duplicate(spells, entry, except) == true end

-- entry: text typed (ID, link or name), a spell ID, or { spell =, on =, exact = }.
-- at: position in the row (default: last).
function ns:AddIcon(side, k, entry, at)
  local spells = self.db.rows[side][k]
  local spell, err, byName
  if type(entry) == "table" then
    spell = entry.spell
  else
    spell, err, byName = self:ParseSpell(entry)
    entry = spell
  end
  if not spell then return false, err end
  local name = self:SpellName(spell) or tostring(spell)
  if type(spell) == "number" then
    for i, other in ipairs(spells) do
      if type(self:EntrySpell(other)) == "string" and Same(other, entry) then
        spells[i] = entry -- a name typed by hand ("renew"): from now on followed by its ID
        self:LayoutIcons()
        self:RefreshOptions()
        return true, L.ADDED:format(name, RowName(side, k))
      end
    end
  end
  if Duplicate(spells, entry) then return false, L.DUPLICATE:format(name) end
  if #spells >= self.MAX_ICONS then return false, L.ROW_FULL:format(self.MAX_ICONS) end
  table.insert(spells, max(1, min(at or #spells + 1, #spells + 1)), entry)
  self:LayoutIcons()
  self:RefreshOptions()
  return true, (byName and L.ADDED_BY_NAME or L.ADDED):format(name, RowName(side, k))
end

function ns:RemoveIcon(side, k, i)
  table.remove(self.db.rows[side][k], i)
  self:LayoutIcons()
  self:RefreshOptions()
end

-- Changes icon i: its spell (or rank), where it looks for its aura (auto, self, target, enemy
-- target, friend target) and whether only that rank counts. nil keeps the current value.
function ns:SetIconEntry(side, k, i, spell, on, exact)
  local spells = self.db.rows[side][k]
  local entry = spells[i]
  if entry == nil then return false end
  if spell == nil then spell = self:EntrySpell(entry) end
  if on == nil then on = self:EntryOn(entry) end
  if exact == nil then exact = Exact(entry) end
  exact = exact and type(spell) == "number" or nil
  local changed = (on == "auto" and not exact) and spell or { spell = spell, on = on, exact = exact }
  if Duplicate(spells, changed, i) then return false, L.DUPLICATE:format(self:SpellName(spell) or tostring(spell)) end
  spells[i] = changed
  self:LayoutIcons()
  self:RefreshOptions()
  return true
end

function ns:SetIconCondition(side, k, i, on) return self:SetIconEntry(side, k, i, nil, on) end

---------------------------------------------------------------------------
-- Class spell lists (SpellCatalog.lua): { kind, rank 1 ID, rank 2 ID, ... } per spell
---------------------------------------------------------------------------
-- (alt: the same ranks under other IDs, as some spells have in Forever)
local catalogIndex -- spell ID and lower-case name -> { kind =, class =, ranks = { { rank, ID, other ID } known here } }
local function CatalogIndex()
  if catalogIndex then return catalogIndex end
  catalogIndex = {}
  for _, class in ipairs(ns.SPELL_CATALOG or {}) do
    for _, spell in ipairs(class.spells) do
      local rec = { kind = spell[1], class = class.class, ranks = {} }
      for r = 2, #spell do
        local id, alt = spell[r], spell.alt and spell.alt[r - 1] or nil
        if not ns:SpellName(id) then id, alt = alt, nil end
        local name = id and ns:SpellName(id)
        if name then
          rec.name = rec.name or name
          rec.ranks[#rec.ranks + 1] = { r - 1, id, alt or nil }
          catalogIndex[id] = rec
          if alt then catalogIndex[alt] = rec end
        end
      end
      if rec.name and not catalogIndex[Fold(rec.name)] then catalogIndex[Fold(rec.name)] = rec end
    end
  end
  return catalogIndex
end

-- The IDs of one rank (several when the game has the same rank twice), for "this rank only".
function ns:RankIDs(spell)
  local ids = { [spell] = true }
  local rec = self:CatalogRecord(spell)
  for _, r in ipairs(rec and rec.ranks or {}) do
    if r[2] == spell or r[3] == spell then
      ids[r[2]] = true
      if r[3] then ids[r[3]] = true end
    end
  end
  return ids
end

-- The class spell list entry of a spell (ID or name), if any.
function ns:CatalogRecord(spell)
  local index = CatalogIndex()
  if type(spell) == "string" then return index[Fold(spell)] end
  return index[spell]
end

-- The ranks this client knows, { { rank, ID }, ... }, when there are more than one.
function ns:SpellRanks(spell)
  local rec = self:CatalogRecord(spell)
  if rec and #rec.ranks > 1 then return rec.ranks end
end

-- Moves icon i of one row to position j of the same or another row (drag and drop).
function ns:MoveIconTo(fromSide, fromK, i, toSide, toK, j)
  local from, to = self.db.rows[fromSide][fromK], self.db.rows[toSide][toK]
  local entry = from[i]
  if entry == nil then return false end
  if from ~= to then
    if Duplicate(to, entry) then
      return false, L.DUPLICATE:format(self:SpellName(self:EntrySpell(entry)) or tostring(self:EntrySpell(entry)))
    end
    if #to >= self.MAX_ICONS then return false, L.ROW_FULL:format(self.MAX_ICONS) end
  end
  table.remove(from, i)
  table.insert(to, max(1, min(j, #to + 1)), entry)
  self:LayoutIcons()
  self:RefreshOptions()
  return true
end

function ns:ClearRow(side, k)
  wipe(self.db.rows[side][k])
  self:LayoutIcons()
  self:RefreshOptions()
end
