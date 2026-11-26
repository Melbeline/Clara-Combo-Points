-- The target's name into a macro (TargetMacro.lua) in the harness: the button over the real target frame's name
-- (GameFixes.lua) carries the double click's hook; two clicks on it write the macro.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local catcher
for _, b in ipairs(ns.unitCatchers or {}) do
  if b.claraFrame == "TargetFrame" and b.claraSpot == "name" then catcher = b end
end
check(catcher ~= nil, "the button over the target's name made: " .. tostring(#(ns.unitCatchers or {})) .. " catchers")
local written
env.GetMacroIndexByName = function() return 0 end
env.GetNumMacros = function() return 0, 0 end
env.CreateMacro = function(name, icon, body) written = body return 1 end
env.EditMacro = function() end
env.UnitName = function(u) if u == "target" then return "Hatefury Felsworn" end end
if catcher then
  local up = catcher:GetScript("OnMouseUp")
  check(up ~= nil, "its OnMouseUp hooked")
  if up then
    local t = 500
    env.GetTime = function() return t end -- (two releases, a fifth of a second apart)
    local ok, e = pcall(up, catcher, "LeftButton")
    t = t + 0.2
    ok, e = pcall(up, catcher, "LeftButton")
    check(ok and written == "/tm 8\n/tar Hatefury", "a double click: the macro written, the first word " .. tostring(e or written))
  end
end
local ok, line = pcall(ns.TargetMacroReport, ns)
check(ok and type(line) == "string" and line:find("Hatefury", 1, true) ~= nil, "its /cl souris line: " .. tostring(line))
print("scenario: targetmacro failures " .. fails)
