-- Clara Combo Points - a new rank of a spell, just learned, takes the place of the rank just below
-- it on the action bars: only the buttons holding that rank (the highest known until then), and
-- only at that moment. A lower rank put on a bar on purpose (downranking) is never touched, nor a
-- button changed afterwards. Out of combat (the game moves no action then: done when it ends),
-- the cursor left as it was.

local ADDON, ns = ...

local PickupSpell = (C_Spell and C_Spell.PickupSpell) or PickupSpell
local GetSpellName = function(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id))
end
local GetSubtext = (C_Spell and C_Spell.GetSpellSubtext) or GetSpellSubtext
local MAX_SLOT = 180

local function Rank(id)
  local text = GetSubtext and GetSubtext(id)
  return type(text) == "string" and tonumber(text:match("(%d+)")) or nil
end

local function Known(id)
  return IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))
end

local TRIES = 10
local queue = {}       -- spells learned, waiting for their bars (in combat, or the spellbook not updated yet): tries
local frame = CreateFrame("Frame")

-- The buttons holding the rank just below the one learned
local function Swap(id)
  local name, rank = GetSpellName(id), Rank(id)
  if not (name and rank and rank > 1) then return true end
  -- the rank just below (the highest until now: ranks are learned in order); lower ones are
  -- downranks, left as they are
  local slots = {}
  for slot = 1, MAX_SLOT do
    local kind, spell = GetActionInfo(slot)
    if kind == "spell" and spell and spell ~= id and Rank(spell) == rank - 1 and GetSpellName(spell) == name then
      slots[#slots + 1] = slot
    end
  end
  if #slots == 0 then return true end
  if GetCursorInfo() then return false end -- (something held: later)
  for _, slot in ipairs(slots) do
    PickupSpell(id)
    PlaceAction(slot)
    ClearCursor() -- (the rank below, back from the bar)
  end
  return true
end

local function Run()
  if InCombatLockdown() then frame:RegisterEvent("PLAYER_REGEN_ENABLED") return end
  frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  for id, tries in pairs(queue) do
    if Known(id) and Swap(id) or tries >= TRIES then queue[id] = nil else queue[id] = tries + 1 end
  end
  if next(queue) then C_Timer.After(1, Run) end
end

local done = {}        -- spells already handled, when: the game tells a learning twice (its event, its chat line)
function ns:SpellLearned(id)
  if type(id) ~= "number" or (issecretvalue and issecretvalue(id)) then return end
  if queue[id] or (done[id] and GetTime() - done[id] < 10) then return end
  done[id] = GetTime()
  queue[id] = 1
  C_Timer.After(0.5, Run) -- (after the spellbook's update)
end

frame:SetScript("OnEvent", Run) -- (the fight over; the learned spells come from LearnedSpells.lua)
