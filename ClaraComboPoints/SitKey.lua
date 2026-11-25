-- Clara Combo Points - Shift+Space sits down (or stands up): the game's own Sit/Stand key (its binding command, as
-- Esc > Options > Keybindings > Movement has it), through an override binding of this addon's: the player's own
-- bindings left as they are. A key the player binds to Shift+Space themselves wins: the module lets it go, its box
-- (Esc > Options > AddOns > Clara Combo Points) unticks. Ticked again, it takes the key back: the player's binding of
-- Shift+Space removed. In a fight, a change waits for its end (the game allows none then). On by default.
-- The very first time (the account's first login with it, as the game loads its bindings: until 10 seconds after the
-- world shows), the box is ticked and the key taken even when it was bound (a spell, a macro...): that binding
-- removed, and a line in the chat says what it was. After that, the rule above.
-- (The game's bindings know one Shift: the left one's and the right one's the same key.)

local ADDON, ns = ...

local KEY, ACTION = "SHIFT-SPACE", "SITORSTAND"
local owner = CreateFrame("Frame")
local bound, reclaim
local first -- the very first login with it: the key taken whatever was on it
local L = ns.L

function ns:SitKey() return not (self.sv and self.sv.sitKey == false) end

-- The player's own binding of the key (overrides aside), if any
local function Theirs()
  local a = GetBindingAction and GetBindingAction(KEY)
  if type(a) ~= "string" or (issecretvalue and issecretvalue(a)) or a == "" then return nil end
  return a
end

local function Fighting() return InCombatLockdown and InCombatLockdown() end

-- A binding as the player knows it: a spell's, a macro's, an item's name; the game's name of a command
local function Named(action)
  local kind, name = action:match("^(%u+) (.+)$")
  if (kind == "SPELL" or kind == "MACRO" or kind == "ITEM") and name then return name end
  return _G["BINDING_NAME_" .. action] or action
end

local function Apply()
  local sv = ns.sv
  if not sv or Fighting() or not (SetOverrideBinding and ClearOverrideBindings) then return end -- (again as the fight ends)
  local want = ns:SitKey()
  local theirs = Theirs()
  if first and theirs and theirs ~= ACTION then
    -- the very first time: on, the key taken, what was there said
    sv.sitKey = nil
    want, reclaim = true, true
    if DEFAULT_CHAT_FRAME and L and L.SIT_KEY_TAKEN then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Clara|r: " .. L.SIT_KEY_TAKEN:format(Named(theirs)))
    end
  end
  if want and theirs and theirs ~= ACTION then
    if reclaim then
      -- ticked again: the key taken back
      if SetBinding then SetBinding(KEY) end
      if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    else
      -- the player's choice wins
      sv.sitKey = false
      want = false
      if ns.RefreshSettingsPage then ns:RefreshSettingsPage() end
    end
  end
  reclaim = nil
  if want and not bound then
    SetOverrideBinding(owner, false, KEY, ACTION)
    bound = true
  elseif not want and bound then
    ClearOverrideBindings(owner)
    bound = nil
  end
end
ns.SitKeyApply = Apply

function ns:SetSitKey(on)
  if not self.sv then return end
  if on then
    self.sv.sitKey = nil
    reclaim = true
  else
    self.sv.sitKey = false
    reclaim = nil
  end
  Apply()
end

-- Whether the override is the addon's now (for its test)
function ns:SitKeyBound() return bound and true or false end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("UPDATE_BINDINGS")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    local sv = ns.sv
    if sv and not sv.sitKeyInit then -- (the very first time: on, whatever the box said before)
      first = true
      sv.sitKey = nil
      self:RegisterEvent("PLAYER_ENTERING_WORLD")
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    local function Done()
      first = nil
      if ns.sv then ns.sv.sitKeyInit = true end
    end
    if C_Timer and C_Timer.After then C_Timer.After(10, Done) else Done() end
  end
  Apply()
end)
