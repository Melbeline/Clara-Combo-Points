-- Clara Combo Points - Shift+Space sits down (or stands up): the game's own Sit/Stand key (its binding command, as
-- Esc > Options > Keybindings > Movement has it), through an override binding of this addon's: the player's own
-- bindings left as they are. A key the player binds to Shift+Space themselves wins: the module lets it go, its box
-- (Esc > Options > AddOns > Clara Combo Points) unticks. Ticked again, it takes the key back: the player's binding of
-- Shift+Space removed. In a fight, a change waits for its end (the game allows none then). On by default.
-- (The game's bindings know one Shift: the left one's and the right one's the same key.)

local ADDON, ns = ...

local KEY, ACTION = "SHIFT-SPACE", "SITORSTAND"
local owner = CreateFrame("Frame")
local bound, reclaim

function ns:SitKey() return not (self.sv and self.sv.sitKey == false) end

-- The player's own binding of the key (overrides aside), if any
local function Theirs()
  local a = GetBindingAction and GetBindingAction(KEY)
  if a == nil or a == "" then return nil end
  return a
end

local function Fighting() return InCombatLockdown and InCombatLockdown() end

local function Apply()
  local sv = ns.sv
  if not sv or Fighting() or not (SetOverrideBinding and ClearOverrideBindings) then return end -- (again as the fight ends)
  local want = ns:SitKey()
  local theirs = Theirs()
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
  end
  Apply()
end)
