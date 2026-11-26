-- Clara Combo Points - the target's name into a macro, and following it, by a double click on the target frame.
-- On its name: the macro "ClaraTarget" (made the first time, the account's: "/tm 8" then "/tar <name>"): its "/tar"
-- (or "/target") line takes the name, every other line of the macro (a "/cast" added by the player...) left as it is.
-- A double left click writes its first word only ("Hatefury" for "Hatefury Felsworn"); a double middle click, the
-- whole name. On its portrait: a double left click follows the target (no macro: the target frame's own click runs
-- "/follow", as the game's menu Follow; out of a fight); Shift + double left click, its first word goes in the macro
-- "ClaraFollow" (its "/follow" line, made the first time: "/follow <name>"); Shift + double right click, its whole
-- name. The two spots never share a point: where the name's and the portrait's overlap, a double click does nothing.
-- A player's whole name is "First Surname", as the game's own menu gives it: written so.
-- The game lets no addon change a macro in a fight: written as the fight ends, a line says so. A macro's icon is
-- chosen once, as it is made: one the player picks later stays. A "/tm8" line (the first versions made it so: the
-- game reads no such command) mended to "/tm 8". A box on Clara's page for each spot (on by default); another says in
-- the chat what went in a macro (off by default).

local ADDON, ns = ...
local L = ns.L

local ICON = 134400 -- (the question mark, a file number as the game's own macro window gives: the first spell's icon)
local DOUBLE = 0.5 -- seconds: two clicks this close, a double one
local MAX_BODY = 255

local issecret = issecretvalue or function() return false end

function ns:TargetMacro() return not (self.sv and self.sv.targetMacro == false) end
function ns:SetTargetMacro(on)
  if not self.sv then return end
  if on then self.sv.targetMacro = nil else self.sv.targetMacro = false end
end
function ns:FollowClick() return not (self.sv and self.sv.followClick == false) end
function ns:SetFollowClick(on)
  if not self.sv then return end
  if on then self.sv.followClick = nil else self.sv.followClick = false end
end
function ns:TargetMacroSay() return (self.sv and self.sv.targetMacroSay == true) or false end
function ns:SetTargetMacroSay(on)
  if self.sv then self.sv.targetMacroSay = on and true or nil end
end

local function Say(text)
  if DEFAULT_CHAT_FRAME and text then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Clara|r: " .. text) end
end

-- The two macros: their name, the line the name goes in, the lines that are that line, the lines it goes after
local TARGET = {
  name = "ClaraTarget", verb = "/tar", first = "/tm 8\n/tar ",
  is = { "^%s*/tar%s", "^%s*/tar$", "^%s*/target%s" },
  after = { "^%s*/tm%s*%d", "^%s*/targetmarker" },
}
local FOLLOW = {
  name = "ClaraFollow", verb = "/follow", first = "/follow ",
  is = { "^%s*/follow%s", "^%s*/follow$", "^%s*/fol%s", "^%s*/f%s", "^%s*/f$" },
  after = {},
}

local function Matches(low, patterns)
  for _, p in ipairs(patterns) do if low:match(p) then return true end end
  return false
end

-- The macro's text with its line set to the name (the first such line; none: one after a line it goes after, else first)
local function Body(old, name, macro)
  macro = macro or TARGET
  local line = macro.verb .. " " .. name
  local lines, done = {}, false
  for l in ((old or "") .. "\n"):gmatch("(.-)\r?\n") do
    l = l:gsub("^(%s*/[tT][mM])(%d+%s*)$", "%1 %2") -- ("/tm8": "/tm 8")
    if not done and Matches(l:lower(), macro.is) then l, done = line, true end
    lines[#lines + 1] = l
  end
  while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
  if not done then
    local at = 1
    for i, l in ipairs(lines) do
      if Matches(l:lower(), macro.after) then at = i + 1 break end
    end
    table.insert(lines, at, line)
  end
  return table.concat(lines, "\n")
end
ns.TargetMacroBody = Body -- (for its test)

-- What happened last, for /cl souris
local seen = { button = 0, event = 0 }
local lastWhat, followWhat, blocked = "nothing yet", "nothing yet", nil

-- The macro's text now (nil: no macro of that name)
local function Current(macro)
  local index = GetMacroIndexByName and GetMacroIndexByName(macro.name)
  if type(index) ~= "number" or index <= 0 then return nil, index end
  local _, _, body = GetMacroInfo(index)
  return body, index
end

-- Written in the macro (made the first time); false and why when it cannot be
local function Write(macro, name)
  if not (GetMacroIndexByName and EditMacro and CreateMacro) then return false, "no macro functions" end
  local old, index = Current(macro)
  if old then
    local body = Body(old, name, macro)
    if #body > MAX_BODY then return false, L.TM_TOO_LONG:format(macro.name) end
    EditMacro(index, nil, nil, body) -- (its name and icon left as they are, as the game's own macro window does)
    return true
  end
  local body = macro.first .. name
  local account, character = GetNumMacros()
  local maxAccount, maxCharacter = tonumber(MAX_ACCOUNT_MACROS) or 120, tonumber(MAX_CHARACTER_MACROS) or 18
  account, character = tonumber(account) or 0, tonumber(character) or 0
  if account < maxAccount then
    CreateMacro(macro.name, ICON, body, false)
  elseif character < maxCharacter then
    CreateMacro(macro.name, ICON, body, true)
  else
    return false, L.TM_FULL:format(macro.name)
  end
  return true
end

-- Is its line with the name in the macro now?
local function Kept(macro, name)
  local body = Current(macro)
  return type(body) == "string" and (body .. "\n"):find(macro.verb .. " " .. name .. "\n", 1, true) ~= nil
end

local function Note(macro, text)
  if macro == FOLLOW then followWhat = text else lastWhat = text end
end

local function Apply(macro, name)
  local line = macro.verb .. " " .. name
  if InCombatLockdown and InCombatLockdown() then
    macro.pending = name
    Note(macro, "in a fight: " .. name .. " waits for its end")
    Say(L.TM_AFTER_FIGHT:format(line, macro.name))
    return
  end
  local ok, done, why = pcall(Write, macro, name)
  if not ok then
    Note(macro, "error: " .. tostring(done))
    Say(L.TM_ERROR:format(macro.name, tostring(done)))
    return
  end
  if not done then
    Note(macro, "not written: " .. tostring(why))
    if why then Say(why) end
    return
  end
  if Kept(macro, name) then
    Note(macro, "written: " .. name)
    if ns:TargetMacroSay() then Say(L.TM_WRITTEN:format(macro.name, line)) end
    return
  end
  -- (not there at once: looked at again a moment later, the game's answer may come late)
  Note(macro, "written, not in the macro yet: " .. name)
  local function Again()
    if Kept(macro, name) then
      Note(macro, "written (late): " .. name)
      if ns:TargetMacroSay() then Say(L.TM_WRITTEN:format(macro.name, line)) end
    else
      local body = Current(macro)
      Note(macro, "not kept by the game: " .. name .. (blocked and (", blocked: " .. blocked) or "")
        .. ", the macro now: " .. (body and body:gsub("\n", " | ") or "none"))
      Say(L.TM_NOT_KEPT:format(macro.name))
    end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.5, Again) else Again() end
end

-- The target's whole name, as the game's own menu gives it ("First Surname" for a player, the creature's name), or nil
-- (said when the game hides it)
local function Whole()
  local ok, name = pcall(ns.FullName, ns, "target")
  if ok and type(name) == "string" and not issecret(name) and name ~= "" then return name end
  name = UnitName and UnitName("target")
  return name
end

local function TargetName(macro)
  local name = Whole()
  if issecret(name) then
    Note(macro, "the target's name hidden by the game (secret)")
    Say(L.TM_SECRET:format(macro.name))
    return nil
  end
  if type(name) ~= "string" or name == "" then Note(macro, "no target name") return nil end
  return name
end

-- A double click: two releases of one button close together. One release can be seen twice (the button of ours over
-- the spot, and the game's own event for every release): counted once.
local function Clicks()
  local c = { last = nil, lastAt = 0 }
  -- true on the second release of a double click
  function c.Double(button, from, buttons)
    local now = GetTime()
    if now == c.doneAt and button == c.doneButton then return false end
    c.doneAt, c.doneButton = now, button
    seen[from or "button"] = (seen[from or "button"] or 0) + 1
    if not buttons[button] then c.last = nil return false end
    if button ~= c.last or now - c.lastAt > DOUBLE then
      c.last, c.lastAt = button, now
      return false, true
    end
    c.last = nil
    return true
  end
  return c
end

-- On the name: its first word (left), the whole name (middle)
local nameClicks = Clicks()
local NAME_BUTTONS = { LeftButton = true, MiddleButton = true }
local function OnUp(_, button, from)
  if not ns:TargetMacro() then return end
  local double, first = nameClicks.Double(button, from, NAME_BUTTONS)
  if first then lastWhat = "one " .. tostring(button) .. " release, waiting for the second" end
  if not double then return end
  local name = TargetName(TARGET)
  if not name then return end
  if button == "LeftButton" then name = name:match("^(%S+)") or name end
  Apply(TARGET, name)
end
ns.TargetMacroClick = OnUp -- (for its test)

-- The follow: the game refuses it to an addon (FollowUnit from one is blocked), not to the target frame's own click. So
-- after a first plain left click on the portrait, for half a second the frame's next plain left click runs "/follow"
-- (its "type1" a macro), as the game's menu Follow; then the frame as it was (what another addon put there, Clique's,
-- given back). The game lets no frame of its change in a fight: none then (undone as one starts).
local armed, armGen, saved = false, 0, nil
local function Disarm()
  if not armed then return end
  if InCombatLockdown and InCombatLockdown() then return end
  local f = _G.TargetFrame
  armed = false
  if type(f) == "table" and f.SetAttribute then
    f:SetAttribute("type1", saved and saved.type or nil)
    f:SetAttribute("macrotext1", saved and saved.text or nil)
  end
  saved = nil
end
local function Arm()
  if not ns:FollowClick() then return end
  if InCombatLockdown and InCombatLockdown() then followWhat = "in a fight: the target frame can't be changed" return end
  local f = _G.TargetFrame
  if not (type(f) == "table" and f.SetAttribute and f.GetAttribute) then return end
  if not armed then saved = { type = f:GetAttribute("type1"), text = f:GetAttribute("macrotext1") } end
  armed = true
  armGen = armGen + 1
  local gen = armGen
  f:SetAttribute("type1", "macro")
  f:SetAttribute("macrotext1", "/follow")
  local function Later() if gen == armGen then Disarm() end end
  if C_Timer and C_Timer.After then C_Timer.After(DOUBLE, Later) end
end
ns.TargetFollowArmed = function() return armed end -- (for its test)

-- On the portrait: a plain double left click follows it (the frame's own click, armed by the first); Shift + double
-- left click: its first word in ClaraFollow; Shift + double right click: its whole name
local portraitClicks = Clicks()
local PORTRAIT_BUTTONS = { LeftButton = true, RightButton = true }
local function OnPortraitUp(_, button, from)
  if not ns:FollowClick() then return end
  local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
  local double, first = portraitClicks.Double(button, from, PORTRAIT_BUTTONS)
  if first then
    followWhat = "one " .. tostring(button) .. " release, waiting for the second"
    -- (armed on the next frame: this release's own click, its target, done first)
    if button == "LeftButton" and not shift and not (IsControlKeyDown and IsControlKeyDown()) and not (IsAltKeyDown and IsAltKeyDown()) then
      if C_Timer and C_Timer.After then C_Timer.After(0, Arm) else Arm() end
    end
  end
  if not double then return end
  if shift then
    local name = TargetName(FOLLOW)
    if not name then return end
    if button == "LeftButton" then name = name:match("^(%S+)") or name end
    Apply(FOLLOW, name)
    return
  end
  if button == "LeftButton" then
    followWhat = armed and "followed (the target frame's own click: /follow)" or "not followed: the frame was not ready (" .. tostring(followWhat) .. ")"
  end
end
ns.FollowClickUp = OnPortraitUp -- (for its test)

-- The spots over the target frame: the buttons of ours (GameFixes.lua lays them, above a chat over the frame) and the
-- game's own name and portrait
local function Spots(spot)
  local list = {}
  for _, b in ipairs(ns.unitCatchers or {}) do
    if b.claraFrame == "TargetFrame" and b.claraSpot == spot then list[#list + 1] = b end
  end
  local f = _G.TargetFrame
  if type(f) ~= "table" then return list end
  local own
  if spot == "name" then
    local content = f.TargetFrameContent
    local main = type(content) == "table" and content.TargetFrameContentMain
    own = (type(main) == "table" and main.Name) or f.name
  else
    local container = f.TargetFrameContainer
    own = type(container) == "table" and container.Portrait or f.portrait
  end
  if type(own) == "table" then list[#list + 1] = own end
  return list
end

local function Over(spot)
  for _, s in ipairs(Spots(spot)) do
    local ok, over = pcall(s.IsMouseOver, s)
    if ok and over == true then return true end
  end
  return false
end

-- Which spot the mouse is on: "name", "portrait", or nil (neither, both, or the target frame hidden)
local function Where()
  local f = _G.TargetFrame
  if type(f) ~= "table" or not (f.IsVisible and f:IsVisible()) then return nil end
  local name, portrait = Over("name"), Over("portrait")
  if name and not portrait then return "name" end
  if portrait and not name then return "portrait" end
  return nil
end

local function Route(button, from)
  local where = Where()
  if where == "name" then
    if ns:TargetMacro() then OnUp(nil, button, from) end
  elseif where == "portrait" then
    if ns:FollowClick() then OnPortraitUp(nil, button, from) end
  end
end

-- Hooked on the buttons over the name and the portrait; the game's event for every release: the same click caught
-- when another frame lies over them
local hooked = setmetatable({}, { __mode = "k" })
local function Hook()
  for _, b in ipairs(ns.unitCatchers or {}) do
    if b.claraFrame == "TargetFrame" and (b.claraSpot == "name" or b.claraSpot == "portrait") and not hooked[b] and b.HookScript then
      hooked[b] = true
      b:HookScript("OnMouseUp", function(_, button) Route(button, "button") end)
    end
  end
end
ns.OnUnitCatchers = Hook

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("GLOBAL_MOUSE_UP")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(_, event, a, b)
  if event == "GLOBAL_MOUSE_UP" then
    if ns:TargetMacro() or ns:FollowClick() then Route(a, "event") end
    return
  end
  if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    if a == ADDON and type(b) == "string" and (b:find("Macro", 1, true) or b:find("Follow", 1, true)) then blocked = b end
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then Disarm() return end -- (the last moment the game lets it)
  Hook()
  Disarm()
  if event == "PLAYER_REGEN_ENABLED" then
    for _, macro in ipairs({ TARGET, FOLLOW }) do
      if macro.pending then
        local name = macro.pending
        macro.pending = nil
        Apply(macro, name)
      end
    end
  end
end)

-- /cl souris: the target macro's line (the mouse on the target's name or portrait while it is taken)
function ns:TargetMacroReport()
  local hooks = 0
  for _ in pairs(hooked) do hooks = hooks + 1 end
  local body, index = Current(TARGET)
  local fbody, findex = Current(FOLLOW)
  local function Text(t, i) return t and ("#" .. tostring(i) .. " " .. t:gsub("\n", " | ")) or ("none (" .. tostring(i) .. ")") end
  return ("target macro: on %s, follow on %s, spots over the name %d, over the portrait %d (hooked %d), the mouse"
    .. " now on %s, releases seen by the buttons %d, by the game's event %d, last: %s, follow last: %s, blocked: %s,"
    .. " ClaraTarget %s, ClaraFollow %s"):format(
    tostring(self:TargetMacro()), tostring(self:FollowClick()), #Spots("name"), #Spots("portrait"), hooks,
    tostring(Where()), seen.button or 0, seen.event or 0, lastWhat, followWhat, blocked or "no",
    Text(body, index), Text(fbody, findex))
end
