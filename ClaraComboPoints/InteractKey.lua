-- Clara Combo Points - the game's Interact Key for everything, at the keyboard: while its own
-- settings have it (Esc > Options > Controls: Enable Interact Key checked, Interact With Target
-- bound), an icon shows over what the key will take - a creature to loot or talk to, an object,
-- a herb, an ore, the bobber - as the game's gamepad mode shows it. One press, one action: the
-- game's own key does it. Its settings given back once the key is off or unbound. A box in the
-- game's options (Esc > Options > AddOns > Clara Combo Points) turns it off.

local ADDON, ns = ...

local ANY = Enum and Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any or 3
local ICONS = { SoftTargetIconInteract = "1", SoftTargetIconGameObject = "1" }

local function Get(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  return GetCVar and GetCVar(name)
end
local function Set(name, value)
  if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(name, value) elseif SetCVar then SetCVar(name, value) end
end

function ns:InteractIcons() return not (self.sv and self.sv.interactIcons == false) end

-- The game's key on and bound
local function KeyOn()
  return tonumber(Get("softTargetInteract")) == ANY and GetBindingKey("INTERACTTARGET") ~= nil
end

-- The icons on (the former values kept, given back at the next login should the game close
-- meanwhile), or given back
local applying
local function Apply()
  local sv = ns.sv
  if not sv or applying then return end
  applying = true
  local on = ns:InteractIcons() and KeyOn()
  if on then
    sv.interactCVars = sv.interactCVars or {}
    for name, value in pairs(ICONS) do
      local now = Get(name)
      if now ~= nil and now ~= value then
        if sv.interactCVars[name] == nil then sv.interactCVars[name] = now end
        Set(name, value)
      end
    end
    if next(sv.interactCVars) == nil then sv.interactCVars = nil end
  elseif sv.interactCVars then
    for name, value in pairs(sv.interactCVars) do Set(name, value) end
    sv.interactCVars = nil
  end
  applying = nil
end

function ns:SetInteractIcons(on)
  if not self.sv then return end
  if on then self.sv.interactIcons = nil else self.sv.interactIcons = false end
  Apply()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
  if event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("UPDATE_BINDINGS")
    self:RegisterEvent("CVAR_UPDATE")
    Apply()
  elseif event == "CVAR_UPDATE" then
    if type(name) == "string" and name:lower() == "softtargetinteract" then Apply() end
  else
    Apply()
  end
end)
