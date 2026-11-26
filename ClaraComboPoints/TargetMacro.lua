-- Clara Combo Points - the target's name into a macro: a double click on the target frame's name writes it in the
-- macro "ClaraTarget" (made the first time, the account's: "/tm8" then "/tar <name>"): its "/tar" (or "/target") line
-- takes the name, every other line of the macro (a "/cast" added by the player...) left as it is. A double left click
-- writes its first word only ("Hatefury" for "Hatefury Felsworn"); a double middle click, the whole name. The game lets no addon change a macro in a fight:
-- written as the fight ends, a line says so. Its icon is chosen once, as it is made: one the player picks later stays.
-- A box on Clara's page (on by default).

local ADDON, ns = ...
local L = ns.L

local MACRO = "ClaraTarget"
local ICON = 134400 -- (the question mark, a file number as the game's own macro window gives: the first spell's icon)
local DOUBLE = 0.5 -- seconds: two clicks this close, a double one
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

-- What happened last, for /cl souris
local seen = { button = 0, event = 0 }
local lastWhat, blocked = "nothing yet", nil

-- The macro's text now (nil: no macro of that name)
local function Current()
  local index = GetMacroIndexByName and GetMacroIndexByName(MACRO)
  if type(index) ~= "number" or index <= 0 then return nil, index end
  local _, _, body = GetMacroInfo(index)
  return body, index
end

-- Written in the macro (made the first time); false and why when it cannot be
local function Write(name)
  if not (GetMacroIndexByName and EditMacro and CreateMacro) then return false, "no macro functions" end
  local old, index = Current()
  if old then
    local body = Body(old, name)
    if #body > MAX_BODY then return false, L.TM_TOO_LONG end
    EditMacro(index, nil, nil, body) -- (its name and icon left as they are, as the game's own macro window does)
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

-- Is "/tar <name>" in the macro now?
local function Kept(name)
  local body = Current()
  return type(body) == "string" and (body .. "\n"):find("/tar " .. name .. "\n", 1, true) ~= nil
end

local pending -- (a name double-clicked in a fight: written as it ends)
local function Apply(name)
  if InCombatLockdown and InCombatLockdown() then
    pending = name
    lastWhat = "in a fight: " .. name .. " waits for its end"
    Say(L.TM_AFTER_FIGHT:format(name))
    return
  end
  local ok, done, why = pcall(Write, name)
  if not ok then
    lastWhat = "error: " .. tostring(done)
    Say(L.TM_ERROR:format(tostring(done)))
    return
  end
  if not done then
    lastWhat = "not written: " .. tostring(why)
    if why then Say(why) end
    return
  end
  if Kept(name) then
    lastWhat = "written: " .. name
    Say(L.TM_WRITTEN:format(MACRO, name))
    return
  end
  -- (not there at once: looked at again a moment later, the game's answer may come late)
  lastWhat = "written, not in the macro yet: " .. name
  local function Again()
    if Kept(name) then
      lastWhat = "written (late): " .. name
      Say(L.TM_WRITTEN:format(MACRO, name))
    else
      local body = Current()
      lastWhat = "not kept by the game: " .. name .. (blocked and (", blocked: " .. blocked) or "")
        .. ", the macro now: " .. (body and body:gsub("\n", " | ") or "none")
      Say(L.TM_NOT_KEPT)
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.5, Again) else Again() end
end

-- A double click on the target's name: its first word (left), the whole name (middle). One release can be seen
-- twice (the button of ours over the name, and the game's own event for every release): counted once.
local last, lastAt = nil, 0
local doneAt, doneButton
local function OnUp(_, button, from)
  if not ns:TargetMacro() then return end
  local now = GetTime()
  if now == doneAt and button == doneButton then return end
  doneAt, doneButton = now, button
  seen[from or "button"] = (seen[from or "button"] or 0) + 1
  if button ~= "LeftButton" and button ~= "MiddleButton" then last = nil return end
  if button ~= last or now - lastAt > DOUBLE then
    last, lastAt = button, now
    lastWhat = "one " .. tostring(button) .. " release, waiting for the second"
    return
  end
  last = nil
  local name = UnitName and UnitName("target")
  if issecret(name) then
    lastWhat = "the target's name hidden by the game (secret)"
    Say(L.TM_SECRET)
    return
  end
  if type(name) ~= "string" or name == "" then lastWhat = "no target name" return end
  if button == "LeftButton" then name = name:match("^(%S+)") or name end
  Apply(name)
end
ns.TargetMacroClick = OnUp -- (for its test)

-- The spots over the target frame's name: the button of ours (GameFixes.lua lays it, above a chat over the frame)
-- and the game's own name
local function Spots()
  local list = {}
  for _, b in ipairs(ns.unitCatchers or {}) do
    if b.claraFrame == "TargetFrame" and b.claraSpot == "name" then list[#list + 1] = b end
  end
  local f = _G.TargetFrame
  local content = type(f) == "table" and f.TargetFrameContent
  local main = type(content) == "table" and content.TargetFrameContentMain
  local label = (type(main) == "table" and main.Name) or (type(f) == "table" and f.name) or nil
  if type(label) == "table" then list[#list + 1] = label end
  return list
end

local function OverName()
  local f = _G.TargetFrame
  if type(f) ~= "table" or not (f.IsVisible and f:IsVisible()) then return false end
  for _, spot in ipairs(Spots()) do
    local ok, over = pcall(spot.IsMouseOver, spot)
    if ok and over == true then return true end
  end
  return false
end

-- Hooked on the button over the name; the game's event for every release, the name under the mouse: the same click
-- caught when another frame lies over the name
local hooked = setmetatable({}, { __mode = "k" })
local function Hook()
  for _, b in ipairs(ns.unitCatchers or {}) do
    if b.claraFrame == "TargetFrame" and b.claraSpot == "name" and not hooked[b] and b.HookScript then
      hooked[b] = true
      b:HookScript("OnMouseUp", function(self, button) OnUp(self, button, "button") end)
    end
  end
end
ns.OnUnitCatchers = Hook

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GLOBAL_MOUSE_UP")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(_, event, a, b)
  if event == "GLOBAL_MOUSE_UP" then
    if ns:TargetMacro() and OverName() then OnUp(nil, a, "event") end
    return
  end
  if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    if a == ADDON and type(b) == "string" and b:find("Macro", 1, true) then blocked = b end
    return
  end
  Hook()
  if event == "PLAYER_REGEN_ENABLED" and pending then
    local name = pending
    pending = nil
    Apply(name)
  end
end)

-- /cl souris: the target macro's line (the mouse on the target's name while it is taken)
function ns:TargetMacroReport()
  local spots, hooks = Spots(), 0
  for _ in pairs(hooked) do hooks = hooks + 1 end
  local body, index = Current()
  return ("target macro: on %s, spots over the name %d (hooked %d), mouse over the name now %s, releases seen by"
    .. " the button %d, by the game's event %d, last: %s, blocked: %s, macro %s"):format(
    tostring(self:TargetMacro()), #spots, hooks, tostring(OverName()), seen.button or 0, seen.event or 0, lastWhat,
    blocked or "no", body and ("#" .. tostring(index) .. " " .. body:gsub("\n", " | ")) or ("none (" .. tostring(index) .. ")"))
end
