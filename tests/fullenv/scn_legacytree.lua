-- The Legacy window opened on its Legacy Tree page (LegacyTree.lua) in the harness: the game's own Legacy addon
-- loaded if the harness can (load on demand), its window shown: the tree page, no error. test153 checks the rest.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns.LegacyTreeOnShow ~= nil, "loaded")
local load = rawget(env, "LegacySystemFrame_LoadUI")
local ok, e = true, nil
if load then ok, e = pcall(load) end
print("scenario: the game's loader " .. tostring(load ~= nil) .. " " .. tostring(ok) .. " " .. tostring(e or ""))
if H.Fire then pcall(H.Fire, "ADDON_LOADED", "Blizzard_LegacySystem") end
local frame = rawget(env, "LegacySystemFrame")
print("scenario: the game's Legacy window " .. tostring(frame ~= nil))
if frame then
  ok, e = pcall(function() frame:Hide(); frame:Show() end)
  check(ok, "shown: no error " .. tostring(e or ""))
  ok, e = pcall(ns.LegacyTreeOnShow, frame)
  check(ok, "its tree page picked: no error " .. tostring(e or ""))
  print("scenario: its page " .. tostring(frame.currentPage))
end
print("scenario: legacytree failures " .. fails)
