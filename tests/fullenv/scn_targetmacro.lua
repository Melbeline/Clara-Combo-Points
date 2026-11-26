-- The target's name into a macro, and following it (TargetMacro.lua) in the harness: the buttons over the real target
-- frame's name and portrait (GameFixes.lua) carry the double click's hook; two clicks on the name write the macro,
-- two on the portrait follow the target; the mouse over both: nothing.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local catcher, portrait
for _, b in ipairs(ns.unitCatchers or {}) do
  if b.claraFrame == "TargetFrame" and b.claraSpot == "name" then catcher = b end
  if b.claraFrame == "TargetFrame" and b.claraSpot == "portrait" then portrait = b end
end
check(catcher ~= nil and portrait ~= nil, "the buttons over the target's name and portrait made: " .. tostring(#(ns.unitCatchers or {})) .. " catchers")
local written, followed
env.GetMacroIndexByName = function() return 0 end
env.GetNumMacros = function() return 0, 0 end
env.CreateMacro = function(name, icon, body) written = body return 1 end
env.EditMacro = function() end
env.FollowUnit = function(u) followed = u end
env.UnitName = function(u) if u == "target" then return "Hatefury Felsworn" end end
env.UnitNameUnmodified = function(u) if u == "target" then return "Hatefury Felsworn" end end
local overName, overPortrait = false, false
local tf = env.TargetFrame
if tf then tf.IsVisible = function() return true end end
if catcher and portrait then
  catcher.IsMouseOver = function() return overName end
  portrait.IsMouseOver = function() return overPortrait end
  local up, pup = catcher:GetScript("OnMouseUp"), portrait:GetScript("OnMouseUp")
  check(up ~= nil and pup ~= nil, "their OnMouseUp hooked")
  if up and pup then
    local t = 500
    env.GetTime = function() return t end -- (two releases, a fifth of a second apart)
    local function Double(fn, b)
      local ok, e = pcall(fn, b, "LeftButton")
      t = t + 0.2
      local ok2, e2 = pcall(fn, b, "LeftButton")
      t = t + 2
      return ok and ok2, e or e2
    end
    overName = true
    local ok, e = Double(up, catcher)
    check(ok and written == "/tm 8\n/tar Hatefury" and not followed, "a double click on the name: the macro written, the first word " .. tostring(e or written))
    overName, overPortrait = false, true
    ok, e = Double(pup, portrait)
    check(ok and followed == "Hatefury Felsworn", "a double click on the portrait: followed " .. tostring(e or followed))
    followed, written = nil, nil
    overName, overPortrait = true, true
    ok, e = Double(pup, portrait)
    local ok3 = Double(up, catcher)
    check(ok and ok3 and not followed and not written, "the mouse over both: nothing " .. tostring(e))
  end
end
local ok, line = pcall(ns.TargetMacroReport, ns)
check(ok and type(line) == "string" and line:find("follow last: followed", 1, true) ~= nil, "its /cl souris line: " .. tostring(line))
print("scenario: targetmacro failures " .. fails)
