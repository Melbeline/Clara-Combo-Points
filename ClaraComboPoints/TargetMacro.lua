-- Clara Combo Points - the target's name into a macro: a double click on the target frame's name writes it in the
-- macro "ClaraTarget" (made the first time, the account's: "/tm8" then "/tar <name>"): its "/tar" (or "/target") line
-- takes the name, every other line of the macro (a "/cast" added by the player...) left as it is. A double left click
-- writes its first word only ("Hatefury" for "Hatefury Felsworn"); a double middle click, the whole name. The game lets no addon change a macro in a fight:
-- written as the fight ends, a line says so. A box on Clara's page (on by default).

local ADDON, ns = ...
local L = ns.L

local MACRO = "ClaraTarget"
local ICON = "INV_MISC_QUESTIONMARK" -- (the game's own pick: the first spell of the macro)
local DOUBLE = 0.4 -- seconds: two clicks this close, a double one
local MAX_BODY = 255

local issecret = issecretvalue or function() return false end

function ns:TargetMacro() return not (self.sv and self.sv.targetMacro == false) end
function ns:SetTargetMacro(on)
  if not self.sv then return end
  if on then self.sv.targetMacro = nil else self.sv.targetMacro = false end
end

local function Say(text)
  if DEFAULT_CHAT_FRAME and text then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Clara|r: " .. text) end
end

-- The macro's text with its "/tar" line set to the name (the first such line; none: one after a "/tm" line, else first)
local function Body(old, name)
  local line = "/tar " .. name
  local lines, done = {}, false
  for l in ((old or "") .. "\n"):gmatch("(.-)\r?\n") do
    local low = l:lower()
    if not done and (low:match("^%s*/tar%s") or low:match("^%s*/tar$") or low:match("^%s*/target%s")) then
      l, done = line, true
    end
    lines[#lines + 1] = l
  end
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  if not done then
    local at = 1
    for i, l in ipairs(lines) do
      local low = l:lower()
      if low:match("^%s*/tm%s*%d") or low:match("^%s*/targetmarker") then at = i + 1 break end
    end
    table.insert(lines, at, line)
  end
  return table.concat(lines, "\n")
end
ns.TargetMacroBody = Body -- (for its test)

-- Written in the macro (made the first time); false and why when it cannot be
local function Write(name)
  if not (GetMacroIndexByName and EditMacro and CreateMacro) then return false end
  local index = GetMacroIndexByName(MACRO)
  if type(index) == "number" and index > 0 then
    local _, icon, old = GetMacroInfo(index)
    local body = Body(old, name)
    if #body > MAX_BODY then return false, L.TM_TOO_LONG end
    EditMacro(index, MACRO, icon or ICON, body)
    return true
  end
  local body = "/tm8\n/tar " .. name
  local account, character = GetNumMacros()
  local maxAccount, maxCharacter = tonumber(MAX_ACCOUNT_MACROS) or 120, tonumber(MAX_CHARACTER_MACROS) or 18
  account, character = tonumber(account) or 0, tonumber(character) or 0
  if account < maxAccount then
    CreateMacro(MACRO, ICON, body, false)
  elseif character < maxCharacter then
    CreateMacro(MACRO, ICON, body, true)
  else
    return false, L.TM_FULL
  end
  return true
end

local pending -- (a name double-clicked in a fight: written as it ends)
local function Apply(name)
  if InCombatLockdown and InCombatLockdown() then
    pending = name
    Say(L.TM_AFTER_FIGHT:format(name))
    return
  end
  local ok, why = Write(name)
  if ok then
    Say(L.TM_WRITTEN:format(MACRO, name))
  elseif why then
    Say(why)
  end
end

-- A double click on the target's name: its first word (left), the whole name (middle)
local last, lastAt = nil, 0
local function OnUp(_, button)
  if not ns:TargetMacro() then return end
  if button ~= "LeftButton" and button ~= "MiddleButton" then last = nil return end
  local now = GetTime()
  if button ~= last or now - lastAt > DOUBLE then
    last, lastAt = button, now
    return
  end
  last = nil
  local name = UnitName and UnitName("target")
  if type(name) ~= "string" or issecret(name) or name == "" then return end
  if button == "LeftButton" then name = name:match("^(%S+)") or name end
  Apply(name)
end
ns.TargetMacroClick = OnUp -- (for its test)

-- Hooked on the button of ours over the target frame's name (GameFixes.lua lays it, above a chat over the frame)
local hooked = setmetatable({}, { __mode = "k" })
local function Hook()
  for _, b in ipairs(ns.unitCatchers or {}) do
    if b.claraFrame == "TargetFrame" and b.claraSpot == "name" and not hooked[b] and b.HookScript then
      hooked[b] = true
      b:HookScript("OnMouseUp", OnUp)
    end
  end
end
ns.OnUnitCatchers = Hook

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
  Hook()
  if event == "PLAYER_REGEN_ENABLED" and pending then
    local name = pending
    pending = nil
    Apply(name)
  end
end)
