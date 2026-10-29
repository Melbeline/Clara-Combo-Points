-- Clara Combo Points - one key to fish, with the keyboard and mouse (no gamepad mode): its key
-- binding (Esc > Options > Keybindings > Clara Combo Points: Fish / Reel in) casts Fishing; while
-- the line is out, the same key is the game's own Interact Key (INTERACTTARGET), which reels in
-- the bobber the game itself picks (its soft interact target): one press, one action, the moment
-- left to the player. While fishing, the game's interact settings are set as its gamepad mode sets
-- them (the interact key on for the keyboard too, 20 yards, an icon over the bobber), then given
-- back. A box in the game's options (Esc > Options > AddOns > Clara Combo Points) lets a right
-- click reel in too while fishing (the right click turning the camera again after).

local ADDON, ns = ...
local L = ns.L

local FISHING = { 7620, 7731, 7732, 18248, 131474 } -- (its ranks, and the later single spell)
-- The game's interact settings while fishing (its gamepad mode's: Blizzard_Gamepad/Core.lua)
local ANY = Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any or 3
local CVARS = {
  SoftTargetInteract = { value = tostring(ANY) },
  SoftTargetInteractRange = { value = "20", atLeast = true },
  SoftTargetInteractArc = { value = "1", atLeast = true },
  SoftTargetIconGameObject = { value = "1" },
  SoftTargetIconInteract = { value = "1" },
}

BINDING_CATEGORY_CLARA = "Clara Combo Points"
_G["BINDING_NAME_CLICK ClaraFishingButton:LeftButton"] = L.FISH_BINDING

function ns:FishingRightClick() return self.sv ~= nil and self.sv.fishingRightClick == true end
function ns:SetFishingRightClick(on)
  if not self.sv then return end
  self.sv.fishingRightClick = on and true or nil
end

local button = CreateFrame("Button", "ClaraFishingButton", UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp", "AnyDown") -- (the game's template acts on one of them: one press, one cast)
button:SetAttribute("type", "spell")
button:Hide()

local fishingName -- Fishing's name in the game's language, once known
local function FishingName()
  for _, id in ipairs(FISHING) do
    if IsPlayerSpell and IsPlayerSpell(id) then
      local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id))
      if name then return name end
    end
  end
end

local function Learn()
  if InCombatLockdown() then return end
  local name = FishingName()
  if name and name ~= fishingName then
    fishingName = name
    button:SetAttribute("spell", name)
  end
end

---------------------------------------------------------------------------
-- While the line is out
---------------------------------------------------------------------------
local owner = CreateFrame("Frame") -- (the override bindings')
local fishing = false

local function SetCVarValue(name, value)
  if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(name, value) elseif SetCVar then SetCVar(name, value) end
end
local function GetCVarValue(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  return GetCVar and GetCVar(name)
end

-- The game's settings for it, the former values kept (in the saved settings: given back at the
-- next login should the game close meanwhile)
local function Settings(on)
  local sv = ns.sv
  if not sv then return end
  if on then
    sv.fishingCVars = sv.fishingCVars or {}
    for name, want in pairs(CVARS) do
      local now = GetCVarValue(name)
      local lower = want.atLeast and tonumber(now) and tonumber(now) >= tonumber(want.value)
      if now ~= nil and tostring(now) ~= want.value and not lower then
        if sv.fishingCVars[name] == nil then sv.fishingCVars[name] = tostring(now) end
        SetCVarValue(name, want.value)
      end
    end
    if next(sv.fishingCVars) == nil then sv.fishingCVars = nil end
  elseif sv.fishingCVars then
    for name, value in pairs(sv.fishingCVars) do SetCVarValue(name, value) end
    sv.fishingCVars = nil
  end
end

local function Reel(on)
  if InCombatLockdown() or on == fishing then return end
  fishing = on
  ClearOverrideBindings(owner)
  if on then
    for _, key in ipairs({ GetBindingKey("CLICK ClaraFishingButton:LeftButton") }) do
      SetOverrideBinding(owner, true, key, "INTERACTTARGET")
    end
    if ns:FishingRightClick() then SetOverrideBinding(owner, true, "BUTTON2", "INTERACTTARGET") end
  end
  Settings(on)
end
ns.FishingReel = Reel

local function IsFishing(spellID)
  if not (fishingName and spellID) or (issecretvalue and issecretvalue(spellID)) then return false end
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or (GetSpellInfo and GetSpellInfo(spellID))
  return name == fishingName
end

-- (WoW Forever only: its interact key and soft targeting)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, _, _, spellID)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    Settings(false) -- (given back, should the game have closed while fishing)
    if not ns.FOREVER then return end
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
    self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
    Learn()
  elseif event == "SPELLS_CHANGED" then
    Learn()
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    if IsFishing(spellID) then Reel(true) end
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LOGOUT" then
    Reel(false)
  end
end)
