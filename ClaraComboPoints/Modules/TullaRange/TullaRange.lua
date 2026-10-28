-- Clara Combo Points - tullaRange 11.1.0 (Tuller; MIT, LICENSE), built in (QoL.lua): the action
-- buttons' icons colored while their action is out of range, lacks mana or cannot be used, in a
-- color, an opacity and a desaturation of one's own for each (tullaRange's look and settings), each
-- with a box to turn it off: the game's own look then. Out of range at 75 % opacity, out of mana
-- off, by default. Settings in ClaraTullaRangeDB, one set for the account.
-- WoW Forever's buttons say when an action goes in or out of range (ActionButton_UpdateRangeIndicator,
-- on ACTION_RANGE_CHECK_UPDATE; the pet bar's every 0.2 s) and when it becomes usable or not
-- (UpdateUsable, after which the game has painted the icon again): the icons are colored then,
-- never polled. tullaRange's standalone addon is turned off for the character while this one runs
-- (its Vanilla version never starts there: its engine is not in that TOC).

local ADDON, ns = ...

ns.TullaRangeRuns = ns:QolRuns("tullarange")
if not ns.TullaRangeRuns then return end

local STATES = { "oor", "oom", "unusable" }
-- color (r, g, b, opacity), desaturated, and on
local DEFAULTS = {
  oor = { 1, 0.3, 0.1, 0.75, desaturate = true, on = true },
  oom = { 0.1, 0.3, 1, 1, desaturate = true, on = false },
  unusable = { 0.4, 0.4, 0.4, 1, desaturate = false, on = true },
}

local db
local function Load()
  if type(ClaraTullaRangeDB) ~= "table" then ClaraTullaRangeDB = {} end
  db = ClaraTullaRangeDB
  for _, state in ipairs(STATES) do
    local d, s = DEFAULTS[state], db[state]
    if type(s) ~= "table" then s = {}; db[state] = s end
    for i = 1, 4 do
      if type(s[i]) ~= "number" then s[i] = d[i] end
    end
    if type(s.desaturate) ~= "boolean" then s.desaturate = d.desaturate end
    if type(s.on) ~= "boolean" then s.on = d.on end
  end
end
Load() -- (saved variables load first: ## LoadSavedVariablesFirst)

---------------------------------------------------------------------------
-- What a button's action is: usable, lacking mana, out of range (nil: no action, or unreadable)
---------------------------------------------------------------------------
local CA = C_ActionBar or {}
local HasAction = CA.HasAction or HasAction
local IsUsableAction = CA.IsUsableAction or IsUsableAction
local IsActionInRange = CA.IsActionInRange or IsActionInRange
local issecret = issecretvalue or function() return false end
local function Secret(a, b, c) return issecret(a) or issecret(b) or issecret(c) end

local function ActionState(button, checksRange, inRange)
  local action = button.action
  if not action or Secret(action) or not (HasAction and IsUsableAction) or not HasAction(action) then return nil end
  local usable, noMana = IsUsableAction(action)
  if Secret(usable, noMana) then return nil end
  local oor
  if checksRange ~= nil then
    if Secret(checksRange, inRange) then return nil end
    oor = checksRange and not inRange
  else
    local range = IsActionInRange and IsActionInRange(action)
    if Secret(range) then return nil end
    oor = range == false
  end
  return usable and true or false, noMana and true or false, oor and true or false
end

local function PetState(button, checksRange, inRange)
  if not (GetPetActionInfo and GetPetActionSlotUsable) then return nil end
  local id = button:GetID()
  local _, texture, _, _, _, _, spellID, checks, range = GetPetActionInfo(id)
  if not texture then return nil end
  if checksRange == nil then checksRange, inRange = checks, range end
  if Secret(checksRange, inRange) then return nil end
  local usable = GetPetActionSlotUsable(id)
  local noMana = false
  if spellID and C_Spell and C_Spell.IsSpellUsable then
    local _, lacking = C_Spell.IsSpellUsable(spellID)
    noMana = not Secret(lacking) and lacking == true
  end
  if Secret(usable) then return nil end
  return usable and true or false, noMana, (checksRange and not inRange) and true or false
end

-- The state shown: the first of these that is on (tullaRange's order); false: the game's own look.
local function Pick(usable, noMana, oor)
  if noMana and db.oom.on then return "oom" end
  if oor and db.oor.on then return "oor" end
  if not usable and not noMana and db.unusable.on then return "unusable" end
  return false
end

-- The game's colors (ActionBarActionButtonMixin:UpdateUsable, PetActionButtonMixin:UpdateButtonState)
local function GameLook(pet, usable, noMana)
  if usable then return 1, 1, 1 end
  if noMana and not pet then return 0.5, 0.5, 1 end
  return 0.4, 0.4, 0.4
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })  -- the buttons watched
local pets = setmetatable({}, { __mode = "k" })    -- of them, the pet bar's
local painted = setmetatable({}, { __mode = "k" }) -- button -> the state on its icon (false: the game's)
local desaturated = setmetatable({}, { __mode = "k" }) -- the icons this desaturated

-- repaint: the game has just painted the icon (its own look on it now)
local function Update(button, repaint, checksRange, inRange)
  local icon = button.icon
  if not (icon and db) then return end
  local pet = pets[button]
  local usable, noMana, oor
  if pet then
    usable, noMana, oor = PetState(button, checksRange, inRange)
  else
    usable, noMana, oor = ActionState(button, checksRange, inRange)
  end
  if repaint then painted[button] = nil end
  if usable == nil then return end
  local state = Pick(usable, noMana, oor)
  local was = painted[button]
  if was == state or (was == nil and state == false and not repaint) then return end
  painted[button] = state
  local color = state and db[state]
  local grey = color and color.desaturate or false
  if grey or desaturated[button] then
    icon:SetDesaturated(grey)
    desaturated[button] = grey or nil
  end
  if color then
    icon:SetVertexColor(color[1], color[2], color[3], color[4])
  elseif not repaint then
    local r, g, b = GameLook(pet, usable, noMana)
    icon:SetVertexColor(r, g, b, 1)
  end
end

local function Repaint(button) Update(button, true) end

local function Watch(button)
  if not button or hooked[button] or not button.icon then return end
  hooked[button] = true
  if type(button.UpdateUsable) == "function" then hooksecurefunc(button, "UpdateUsable", Repaint) end
  Update(button, true)
end

local function WatchPet(button)
  if not button or hooked[button] or not button.icon then return end
  hooked[button] = true
  pets[button] = true
  if type(button.UpdateButtonState) == "function" then hooksecurefunc(button, "UpdateButtonState", Repaint) end
  Update(button, true)
end

local function OnRange(button, checksRange, inRange)
  if hooked[button] then Update(button, false, checksRange, inRange) end
end

-- All the icons painted again (the settings changed)
local function Refresh()
  for button in pairs(hooked) do
    if painted[button] ~= nil then painted[button] = "" end -- (whatever is on it: painted again)
    Update(button, false)
  end
end

local function Start()
  local events = ActionBarButtonEventsFrame
  if events and type(events.frames) == "table" then
    for _, button in pairs(events.frames) do Watch(button) end
    if type(events.RegisterFrame) == "function" then
      hooksecurefunc(events, "RegisterFrame", function(_, button) Watch(button) end)
    end
  end
  local petBar = PetActionBar
  local list = petBar and type(petBar.actionButtons) == "table" and petBar.actionButtons or nil
  for i = 1, NUM_PET_ACTION_SLOTS or 10 do WatchPet(list and list[i] or _G["PetActionButton" .. i]) end
  if type(ActionButton_UpdateRangeIndicator) == "function" then
    hooksecurefunc("ActionButton_UpdateRangeIndicator", OnRange)
  end
end

ns.TullaRange = {
  STATES = STATES,
  DEFAULTS = DEFAULTS,
  Settings = function() return db end,
  Refresh = Refresh,
  -- one state back to its defaults (all of them without a state)
  Reset = function(state)
    for _, s in ipairs(STATES) do
      if state == nil or state == s then db[s] = nil end
    end
    Load()
    Refresh()
  end,
}

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Start()
end)
