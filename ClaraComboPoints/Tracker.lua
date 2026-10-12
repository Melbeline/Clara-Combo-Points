-- Clara Combo Points - buff and debuff icons
-- Up to three rows above the HUD (growing upward) and three below the bar (growing downward),
-- 20 icons each. Warriors start with one row where the combo points would be: Sunder Armor,
-- Demoralizing Shout, Hamstring, Battle Shout, Bloodrage.
--
-- Spells are kept as IDs (or names) and auras are looked up by spell name, so every rank
-- matches, in every client language: first among your buffs, then the target's debuffs, then
-- your debuffs. An active aura lights its icon with the colour of its place in the row (the
-- combo point colours, yellow to pink); a missing one is grayed out.
--
-- By default the icons fill cells shaped like the combo points (cropped, not stretched); they
-- can be kept square instead, at the chosen size.

local ADDON, ns = ...
local L = ns.L

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local issecretvalue = issecretvalue or function() return false end
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local GetSpellInfo = (C_Spell and C_Spell.GetSpellInfo) or nil
local GetDisplayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
local TRIM = .08                -- icon border cut off
local MISSING_ALPHA = .45
local LOOKUPS = { { "player", "HELPFUL" }, { "target", "HARMFUL" }, { "player", "HARMFUL" } }

local rows = { above = {}, below = {} }
local timed = {}  -- slots counting down
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

local function RowName(side, k)
  return (side == "above" and L.ROW_ABOVE or L.ROW_BELOW):format(k)
end
ns.RowName = function(_, side, k) return RowName(side, k) end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function NewSlot(row)
  local slot = CreateFrame("Frame", nil, row)
  slot.edge = slot:CreateTexture(nil, "BACKGROUND")
  slot.edge:SetAllPoints()
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.timer = slot:CreateFontString(nil, "OVERLAY")
  slot.timer:SetPoint("CENTER")
  slot.count = slot:CreateFontString(nil, "OVERLAY")
  slot.count:SetPoint("BOTTOMRIGHT", -1, 1)
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

function ns:LayoutIcons()
  local db = self.db
  if not db then return end
  local look = db.icons
  local size, square = look.size, look.square
  local edge = size >= 16 and 2 or 1
  local flags = self:GetOutline()
  if flags == "" then flags = "OUTLINE" end -- always readable over an icon
  wipe(timed)
  for _, side in ipairs(self.SIDES) do
    -- each row sits on the previous one; empty rows take no room
    local anchor = self.powerBar
    if side == "above" and self.comboRow:IsShown() then anchor = self.comboRow end
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
          slot.icon:ClearAllPoints()
          slot.icon:SetPoint("TOPLEFT", edge, -edge)
          slot.icon:SetPoint("BOTTOMRIGHT", -edge, edge)
          Crop(slot.icon, w - 2 * edge, size - 2 * edge)
          slot.spell = spells[i]
          slot.name = self:SpellName(spells[i])
          slot.spellIcon = self:SpellIcon(spells[i])
          slot.colorKey = "cp" .. ceil(i * 5 / n) -- yellow to pink along the row
          self:SetFont(slot.timer, max(8, floor(min(w, size) * .5)), flags)
          self:SetFont(slot.count, max(7, floor(size * .38)), flags)
          slot.on = nil
        end
        row:Show()
      end
    end
  end
  self:ColorIcons()
  self:UpdateIcons()
end

function ns:ColorIcons()
  local colors = self.db and self.db.colors
  if not colors then return end
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      for i = 1, #(row.spells or {}) do
        local slot = row.slots[i]
        local c = slot.on and colors[slot.colorKey] or colors.bg
        slot.edge:SetColorTexture(c.r, c.g, c.b, c.a)
        local t = colors.text
        slot.timer:SetTextColor(t.r, t.g, t.b, t.a)
        slot.count:SetTextColor(t.r, t.g, t.b, t.a)
      end
    end
  end
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

local function FormatTime(left)
  if left >= 3600 then return ceil(left / 3600) .. "h" end
  if left >= 60 then return ceil(left / 60) .. "m" end
  if left >= 3 then return tostring(ceil(left)) end
  return ("%.1f"):format(left)
end

local function SetSlot(slot, aura, unit, look, colors)
  local on = aura ~= nil or ns.preview
  slot.on = on
  local c = on and colors[slot.colorKey] or colors.bg
  slot.edge:SetColorTexture(c.r, c.g, c.b, c.a)
  slot.expires = nil
  slot.timer:SetText("")
  slot.count:SetText("")
  if not on then
    slot.icon:SetTexture(slot.spellIcon)
    slot.icon:SetDesaturated(true)
    slot:SetAlpha(MISSING_ALPHA)
    slot:SetShown(look.missing)
    return
  end
  slot.icon:SetDesaturated(false)
  slot:SetAlpha(1)
  slot:Show()
  if not aura then -- preview
    slot.icon:SetTexture(slot.spellIcon)
    if look.timers then slot.timer:SetText("9") end
    return
  end
  local icon = aura.icon
  if issecretvalue(icon) or not icon then icon = slot.spellIcon end
  slot.icon:SetTexture(icon)
  local stacks = aura.applications
  if issecretvalue(stacks) then
    if GetDisplayCount then
      local ok, text = pcall(GetDisplayCount, unit, aura.auraInstanceID, 2)
      if ok and text then slot.count:SetText(text) end
    end
  elseif type(stacks) == "number" and stacks > 1 then
    slot.count:SetText(stacks)
  end
  local ends, duration = Plain(aura.expirationTime), Plain(aura.duration)
  if look.timers and ends and duration and ends > 0 and duration > 0 then
    slot.expires = ends
    timed[slot] = true
  end
end

function ns:UpdateIcons()
  dirty = false
  if not self.db or not self.hud:IsShown() then
    dirty = true -- catch up when shown
    return
  end
  wipe(timed)
  local look, colors = self.db.icons, self.db.colors
  for _, side in ipairs(self.SIDES) do
    for _, row in pairs(rows[side]) do
      for i = 1, #(row.spells or {}) do
        local slot = row.slots[i]
        local aura, unit
        if not self.preview and slot.name then aura, unit = FindAura(slot.name) end
        SetSlot(slot, aura, unit, look, colors)
      end
    end
  end
  self:UpdateIconTimers()
end

-- Aura events can come in bursts: the icons are refreshed once, on the next frame.
function ns:MarkIconsDirty()
  dirty = true
end

function ns:UpdateIconsIfDirty()
  if dirty then self:UpdateIcons() end
end

function ns:UpdateIconTimers()
  if not next(timed) then return end
  local now = GetTime()
  for slot in pairs(timed) do
    local left = slot.expires - now
    if left > 0 then
      slot.timer:SetText(FormatTime(left))
    else
      slot.timer:SetText("")
      timed[slot] = nil
    end
  end
end

---------------------------------------------------------------------------
-- Editing (options)
---------------------------------------------------------------------------
-- "7386", a spell link, or a name. A known name is stored as its ID (so it follows the
-- client language); an unknown one is tracked by the name as typed.
function ns:ParseSpell(text)
  text = (text or ""):match("^%s*(.-)%s*$")
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

function ns:AddIcon(side, k, text)
  local spells = self.db.rows[side][k]
  local spell, err, byName = self:ParseSpell(text)
  if not spell then return false, err end
  local name = self:SpellName(spell) or tostring(spell)
  for _, other in ipairs(spells) do
    if other == spell or self:SpellName(other) == name then return false, L.DUPLICATE:format(name) end
  end
  if #spells >= self.MAX_ICONS then return false, L.ROW_FULL:format(self.MAX_ICONS) end
  spells[#spells + 1] = spell
  self:LayoutIcons()
  self:RefreshOptions()
  return true, (byName and L.ADDED_BY_NAME or L.ADDED):format(name, RowName(side, k))
end

function ns:RemoveIcon(side, k, i)
  table.remove(self.db.rows[side][k], i)
  self:LayoutIcons()
  self:RefreshOptions()
end

function ns:MoveIcon(side, k, i, delta)
  local spells = self.db.rows[side][k]
  local j = i + delta
  if j < 1 or j > #spells then return end
  spells[i], spells[j] = spells[j], spells[i]
  self:LayoutIcons()
  self:RefreshOptions()
end

function ns:ClearRow(side, k)
  wipe(self.db.rows[side][k])
  self:LayoutIcons()
  self:RefreshOptions()
end
