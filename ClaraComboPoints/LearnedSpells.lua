-- Clara Combo Points - a spell just learned is taken from its chat line ("You have learned a new
-- ability: [Stealth].") with the mouse: pressed on the spell's name, it comes on the cursor, to
-- put on an action bar or on the HUD. Any spell taken on the cursor (from the spellbook, an
-- action bar...), the same. While it is held, the HUD's icon rows open for it, even locked; they close again once it is placed - 5
-- seconds after it lands on the HUD, to move it if it went to the wrong place. Nothing to set:
-- always on.

local _, ns = ...

local GRACE = 5          -- seconds to move the spell again after it landed on the HUD
local learned = {}       -- spell IDs learned this session
local hovered            -- the link under the mouse in a chat window
local watcher = CreateFrame("Frame")

local PickupSpell = (C_Spell and C_Spell.PickupSpell) or PickupSpell

-- The game's "learned" lines in the client's language, as patterns.
local patterns = {}
for _, key in ipairs({ "ERR_LEARN_ABILITY_S", "ERR_LEARN_SPELL_S", "ERR_LEARN_PASSIVE_S" }) do
  local text = _G[key]
  if type(text) == "string" then
    local pattern = text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
    patterns[#patterns + 1] = pattern
  end
end

local function SpellOfLink(link)
  if type(link) ~= "string" then return end
  return tonumber(link:match("^spell:(%d+)") or link:match("|Hspell:(%d+)"))
end

local function Learned(message)
  if type(message) ~= "string" then return end
  for _, pattern in ipairs(patterns) do
    local what = message:match(pattern)
    if what then
      for id in what:gmatch("|Hspell:(%d+)") do
        learned[tonumber(id)] = true
        if ns.SpellLearned then ns:SpellLearned(tonumber(id)) end -- (its new rank on the bars: SpellRanks.lua)
      end
      return
    end
  end
end

local function HeldSpell()
  if not GetCursorInfo then return end
  local kind, _, _, spellID = GetCursorInfo()
  if kind == "spell" then return spellID or true end
end

-- The rows open for the spell held (Core: ns:EditingIcons()), then close again.
local function Refresh()
  ns:LayoutIcons()
  ns:UpdateVisibility()
  ns:ApplyFade()
end

local function EndChatDrop()
  if not ns.chatDrop then return end
  ns.chatDrop = nil
  Refresh()
end

-- The spell now on the cursor: the rows open for it.
local function Hold(id)
  ns.chatDrop = { spell = id }
  Refresh()
end

-- A press (or a click) on a learned spell's name in the chat: the spell on the cursor.
local function Grab(link)
  local id = SpellOfLink(link)
  if not id or not learned[id] or not PickupSpell or not ns.db then return end
  local held = HeldSpell()
  if held == id then return end      -- already held (the press, then the click)
  if GetCursorInfo and GetCursorInfo() then return end -- something else is held
  if not pcall(PickupSpell, id) or not HeldSpell() then return end -- (a passive spell stays put)
  if ItemRefTooltip and ItemRefTooltip:IsShown() then ItemRefTooltip:Hide() end
  Hold(id)
end

-- Taken from the spellbook (the game's own pickup, run first): the same.
local function FromBook()
  local id = HeldSpell()
  if not id or not ns.db or (ns.chatDrop and ns.chatDrop.spell == id and not ns.chatDrop.placed) then return end
  Hold(id)
end

-- Put on the HUD (Tracker.lua, a drop or a move): the rows stay open GRACE seconds more,
-- longer while an icon is being moved.
function ns:ChatDropPlaced()
  local d = self.chatDrop
  if not d then return end
  d.placed = true
  local token = {}
  d.token = token
  C_Timer.After(GRACE, function()
    if ns.chatDrop ~= d or d.token ~= token then return end
    if ns:DraggingIcon() then return end -- let go later: a new grace (Tracker.lua)
    EndChatDrop()
  end)
end

local function HookChat(frame)
  if type(frame) ~= "table" or frame.claraLearned or not frame.HookScript then return end
  frame.claraLearned = true
  frame:HookScript("OnHyperlinkEnter", function(_, link) hovered = link end)
  frame:HookScript("OnHyperlinkLeave", function() hovered = nil end)
  frame:HookScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and hovered then Grab(hovered) end
  end)
end

watcher:SetScript("OnEvent", function(_, event, arg1)
  if event == "CHAT_MSG_SYSTEM" then
    Learned(arg1)
  elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
    if type(arg1) == "number" then
      learned[arg1] = true
      if ns.SpellLearned then ns:SpellLearned(arg1) end
    end
  elseif event == "CURSOR_CHANGED" then
    -- a spell taken (the spellbook, an action bar...): the rows open for it; let go on an
    -- action bar, or nowhere: they close (on the HUD, its grace runs)
    local held, d = HeldSpell(), ns.chatDrop
    if held and ns.db and (not d or d.placed or d.spell ~= held) then
      Hold(held)
    elseif not held and d and not d.placed then
      EndChatDrop()
    end
  end
end)

-- On for this character (Core.lua): the chat windows, and the lines that teach a spell.
table.insert(ns.onEnable, function()
  watcher:RegisterEvent("CHAT_MSG_SYSTEM")
  watcher:RegisterEvent("CURSOR_CHANGED")
  pcall(watcher.RegisterEvent, watcher, "LEARNED_SPELL_IN_SKILL_LINE") -- not in every client build
  for i = 1, NUM_CHAT_WINDOWS or 10 do HookChat(_G["ChatFrame" .. i]) end
  -- a click without the press (some chat windows): the same
  if hooksecurefunc and SetItemRef then
    hooksecurefunc("SetItemRef", function(link, _, button)
      if button == "LeftButton" and not (IsModifiedClick and IsModifiedClick()) then Grab(link) end
    end)
  end
  if hooksecurefunc and C_SpellBook and C_SpellBook.PickupSpellBookItem then
    hooksecurefunc(C_SpellBook, "PickupSpellBookItem", FromBook)
  end
  if hooksecurefunc and PickupSpellBookItem then hooksecurefunc("PickupSpellBookItem", FromBook) end -- (older clients)
  if hooksecurefunc and FCF_OpenTemporaryWindow then -- whisper windows, opened later
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
      for i = 1, NUM_CHAT_WINDOWS or 10 do HookChat(_G["ChatFrame" .. i]) end
    end)
  end
end)

ns.LearnedSpells = learned -- (for the tests)
