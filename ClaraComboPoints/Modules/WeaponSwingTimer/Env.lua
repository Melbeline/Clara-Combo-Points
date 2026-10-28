-- Clara Combo Points - WeaponSwingTimer 1.60.1 (Forever), built in (QoL.lua), with its own entry
-- in the game's options and its own commands (/wst). The first of the module's files: it gives
-- the others their table and their own globals (each file runs in E.env), or nothing (they then
-- do nothing) when the module does not run.
-- While the standalone WeaponSwingTimer addon runs instead, its settings (every profile, and
-- which character uses which) are copied at login and logout: turning it off later, the
-- built-in copy starts from them, nothing to set again. Where they were at WeaponSwingTimer's own
-- defaults, Clara's apply: no main-hand / off-hand bars, the ranged bar on hunters only.

local ADDON, ns = ...

local E = { ADDON = ADDON, SV = "ClaraWSTDB" }

-- Clara's defaults, over WeaponSwingTimer's
local OVERRIDES = {
  player = { enabled = false, is_locked = true },  -- your main-hand and off-hand bars: never by default
  target = { enabled = false, is_locked = true },  -- the target's too
  hunter = { is_locked = true },                   -- (hunters_only: the module's own new key, on)
  castbar = { is_locked = true },
  range = { is_locked = true },
  core = { welcome_message = false },
}
local SECTIONS = { "core", "player", "target", "hunter", "range", "castbar" }

-- Before the saved data opens (WeaponSwingTimer_Core.lua): an install imported from the standalone
-- loses the values still at WeaponSwingTimer's defaults (so that Clara's apply), once; then
-- Clara's defaults replace WeaponSwingTimer's.
function E.PrepareSaved(data)
  local own = {}
  for _, s in ipairs(SECTIONS) do own[s] = CopyTable(data[s].default_settings) end
  local sv = _G[E.SV]
  if type(sv) == "table" and type(sv.global) == "table" and sv.global.wstImportPending then
    for _, profile in pairs(type(sv.profiles) == "table" and sv.profiles or {}) do
      for s, defaults in pairs(own) do
        local t = type(profile) == "table" and profile[s]
        if type(t) == "table" then
          for key, value in pairs(defaults) do if t[key] == value then t[key] = nil end end
          if next(t) == nil then profile[s] = nil end
        end
      end
    end
    sv.global.wstImportPending = nil
  end
  for s, over in pairs(OVERRIDES) do
    for key, value in pairs(over) do data[s].default_settings[key] = value end
  end
end

if ns:QolRuns("wst") then
  E.data = {}
  E.env = setmetatable({}, { __index = _G })
  ns.WST = E
elseif ns:QolState("wst") == "standalone" then
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    local src = _G.WSTProfileDB
    if type(src) ~= "table" or type(src.profiles) ~= "table" then return end
    local dst = type(_G[E.SV]) == "table" and _G[E.SV] or {}
    _G[E.SV] = dst
    dst.profiles = CopyTable(src.profiles)
    dst.profileKeys = type(src.profileKeys) == "table" and CopyTable(src.profileKeys) or nil
    dst.global = type(dst.global) == "table" and dst.global or {}
    dst.global.wstImportPending = true
  end)
end

-- Its main switches, on its page of Clara's options window (Improvements tab): the settings of
-- this character's profile, as the module's own panel sets them
if E.env then
  local env = E.env
  local function Settings(section) return env["character_" .. section .. "_settings"] end
  local function Update(section)
    local part = E.data[section]
    if part and part.UpdateVisualsOnSettingsChange then part.UpdateVisualsOnSettingsChange() end
  end
  local function Switch(label, section, key, default)
    return {
      label = label,
      get = function()
        local t = Settings(section)
        if not t then return false end
        if t[key] == nil then return default end
        return t[key] and true or false
      end,
      set = function(on)
        local t = Settings(section)
        if not t then return end
        t[key] = on and true or false
        Update(section)
      end,
    }
  end
  local LOCKED = { "player", "target", "hunter", "range", "castbar" }
  ns:SetQolSwitches("wst", {
    Switch("WST_SW_HUNTER", "hunter", "enabled", false),
    Switch("WST_SW_HUNTERS_ONLY", "hunter", "hunters_only", true),
    Switch("WST_SW_PLAYER", "player", "enabled", false),
    Switch("WST_SW_TARGET", "target", "enabled", false),
    { -- the distance box on the target and focus frames (UnitBoxes.lua): a hunter's by default
      label = "WST_SW_RANGE_BOX",
      get = function() local r = E.data.range; return r and r.FrameBoxOn and r.FrameBoxOn() or false end,
      set = function(on) local r = E.data.range; if r and r.SetFrameBox then r.SetFrameBox(on) end end,
    },
    {
      label = "WST_SW_LOCKED",
      get = function() local t = Settings("player"); return not t or t.is_locked ~= false end,
      set = function(on) -- (as its panel's lock box: every bar)
        for _, section in ipairs(LOCKED) do
          local t = Settings(section)
          if t then t.is_locked = on and true or false end
          local part = E.data[section]
          if part and part.frame then part.frame:EnableMouse(not on) end
        end
      end,
    },
  })
end

-- Its options: /wst, of whichever copy runs
ns:SetQolOpener("wst", function()
  if SlashCmdList and SlashCmdList.WEAPONSWINGTIMER_CONFIG then SlashCmdList.WEAPONSWINGTIMER_CONFIG("") end
end)
