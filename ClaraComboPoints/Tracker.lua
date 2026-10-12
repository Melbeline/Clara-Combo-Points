-- Clara Combo Points - buff, debuff and spell icons
-- Up to three rows above the HUD (growing upward) and three below the bar (growing downward),
-- 20 icons each. Warriors start with one row where the combo points would be: Sunder Armor,
-- Demoralizing Shout, Hamstring, Battle Shout, Bloodrage.
--
-- Spells are kept as IDs (or names) and looked up by spell name, so every rank matches, in
-- every client language. Each icon shows, in this order:
--   - the aura when it is up (your buffs first, then the target's debuffs, then your debuffs),
--     with its stacks and time left;
--   - else the spell's own cooldown (not the global cooldown) when it runs;
--   - else the spell ready (spells with a cooldown) or the aura missing (grayed out).
-- Icons look like the action bar buttons: the game's button frame around them, its cooldown
-- swipe and countdown numbers ("2m" from two minutes up, then "1:59", then seconds), charges
-- and stacks bottom right.
--
-- By default the icons fill cells shaped like the combo points (cropped, not stretched); they
-- can be kept square instead, at the chosen size.

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
local LOOKUPS = { { "player", "HELPFUL" }, { "target", "HARMFUL" }, { "player", "HARMFUL" } }

local rows = { above = {}, below = {} }
local dirty

local function Plain(v)
  if not issecretvalue(v) and type(v) == "number" then return v end
end

function ns:SpellIcon(spell)
  if GetSpellTexture then
    local ok, icon = pcall(GetSpellTexture, spell)
    if ok and icon and not issecretvalue(icon) then return icon end
  end
  return QUESTION_MARK
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

function ns:LayoutIcons()
  local db = self.db
  if not db then return end
  local look = db.icons
  local size, square = look.size, look.square
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
        local w = square and size or (self.WIDTH - (n - 1) * self.CP_GAP) / n
        row:ClearAllPoints()
        row:SetSize(square and (n * size + (n - 1) * self.CP_GAP) or self.WIDTH, size)
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
          LayoutFrame(slot, w, size)
          local inset = min(w, size) * 3 / 45
          slot.cd:ClearAllPoints()
          slot.cd:SetPoint("TOPLEFT", inset, -inset)
          slot.cd:SetPoint("BOTTOMRIGHT", -inset, inset)
          SetSlotFonts(slot, w, size)
          slot.spell = spells[i]
          slot.name = self:SpellName(spells[i])
          slot.spellIcon = self:SpellIcon(spells[i])
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
local function FindAura(name)
  for _, lookup in ipairs(LOOKUPS) do
    local unit = lookup[1]
    if unit ~= "target" or UnitExists("target") then
      local aura = ns:FindAura(unit, name, lookup[2])
      if aura then return aura, unit end
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

local function SetSlot(slot, look)
  slot.cd:Clear()
  slot.cd:SetReverse(false)
  if slot.cd.SetHideCountdownNumbers then slot.cd:SetHideCountdownNumbers(not look.timers) end
  slot.count:SetText("")
  local aura, unit, running
  if ns.preview then
    -- a sample: lit, with a cooldown under way
    slot.icon:SetTexture(slot.spellIcon)
    slot.icon:SetDesaturated(false)
    slot:SetAlpha(1)
    slot:Show()
    slot.cd:SetCooldown(GetTime() - 15, 45)
    return
  end
  if slot.name then aura, unit = FindAura(slot.name) end
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
    if ends and duration and ends > 0 and duration > 0 then
      slot.cd:SetReverse(look.reverse)
      slot.cd:SetCooldown(ends - duration, duration)
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
  else
    slot.icon:SetTexture(slot.spellIcon)
    running = SpellCooldown(slot)
  end
  if not (aura and Plain(aura.applications) and aura.applications > 1) then
    local charges = Charges(slot)
    if charges ~= nil then slot.count:SetText(charges) end
  end
  local lit = aura or running or slot.hasCooldown
  slot.icon:SetDesaturated(not lit)
  slot:SetAlpha(lit and 1 or MISSING_ALPHA)
  slot:SetShown(lit or look.missing)
end

function ns:UpdateIcons()
  dirty = false
  if not self.db or not self.hud:IsShown() then
    dirty = true -- catch up when shown
    return
  end
  local look = self.db.icons
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      for i = 1, #(row.spells or {}) do SetSlot(row.slots[i], look) end
    end
  end
end

-- Aura and cooldown events can come in bursts: the icons are refreshed once, on the next frame.
function ns:MarkIconsDirty()
  dirty = true
end

function ns:UpdateIconsIfDirty()
  if dirty then self:UpdateIcons() end
end

---------------------------------------------------------------------------
-- Editing (options)
---------------------------------------------------------------------------
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
  if GetSpellInfo then
    local ok, info = pcall(GetSpellInfo, text)
    if ok and type(info) == "table" and Plain(info.spellID) then return info.spellID end
  end
  return text, nil, true
end

-- at: position in the row (default: last)
function ns:AddIcon(side, k, text, at)
  local spells = self.db.rows[side][k]
  local spell, err, byName = self:ParseSpell(text)
  if not spell then return false, err end
  local name = self:SpellName(spell) or tostring(spell)
  for _, other in ipairs(spells) do
    if other == spell or self:SpellName(other) == name then return false, L.DUPLICATE:format(name) end
  end
  if #spells >= self.MAX_ICONS then return false, L.ROW_FULL:format(self.MAX_ICONS) end
  table.insert(spells, max(1, min(at or #spells + 1, #spells + 1)), spell)
  self:LayoutIcons()
  self:RefreshOptions()
  return true, (byName and L.ADDED_BY_NAME or L.ADDED):format(name, RowName(side, k))
end

function ns:RemoveIcon(side, k, i)
  table.remove(self.db.rows[side][k], i)
  self:LayoutIcons()
  self:RefreshOptions()
end

-- Moves icon i of one row to position j of the same or another row (drag and drop).
function ns:MoveIconTo(fromSide, fromK, i, toSide, toK, j)
  local from, to = self.db.rows[fromSide][fromK], self.db.rows[toSide][toK]
  local spell = from[i]
  if spell == nil then return false end
  if from ~= to then
    local name = self:SpellName(spell) or tostring(spell)
    for _, other in ipairs(to) do
      if other == spell or self:SpellName(other) == name then return false, L.DUPLICATE:format(name) end
    end
    if #to >= self.MAX_ICONS then return false, L.ROW_FULL:format(self.MAX_ICONS) end
  end
  table.remove(from, i)
  table.insert(to, max(1, min(j, #to + 1)), spell)
  self:LayoutIcons()
  self:RefreshOptions()
  return true
end

function ns:ClearRow(side, k)
  wipe(self.db.rows[side][k])
  self:LayoutIcons()
  self:RefreshOptions()
end
