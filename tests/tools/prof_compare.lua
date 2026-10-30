-- the click buttons' check, with the mock's slow GetRect replaced by a fixed answer (a C call in game)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local CLASS = PROF_CLASS or "ROGUE"
S.class = CLASS; S.locale = "enUS"
if CLASS == "DRUID" then S.powerType = 3; S.forms = { 5487, 768 }; S.form = 2 end
S.knownSpells = { [1752] = true, [5171] = true, [2098] = true, [2983] = true, [5277] = true, [1784] = true, [1766] = true, [1943] = true,
  [5487] = true, [768] = true, [6807] = true, [1082] = true, [5221] = true, [16979] = true, [774] = true, [5215] = true }
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.now = 100
local p = ns.sv.profiles[CLASS]
if CLASS == "DRUID" then
  p.rows.above[1] = { 6807, 1082, 5221, 16979 }; p.rows.below[1] = { 774, 5215 }
else
  p.rows.above[1] = { 5171, 2983, 5277, 1784 }; p.rows.below[1] = { 1943, 1766, 2098 }
end
ns:LayoutIcons(); ns:UpdateVisibility()
for _ = 1, 3 do M.Frame(0.016) end
local fixed = {}
for _, f in ipairs(M.frames) do
  if f.GetRect then
    local l, b, w, h = f:GetRect()
    local x, y = f.GetCenter and f:GetCenter()
    f.GetRect = function() return l, b, w, h end
    if f.GetCenter then f.GetCenter = function() return x, y end end
  end
end
local function measure(label, n, fn)
  collectgarbage("collect"); collectgarbage("stop")
  local k0, t0 = collectgarbage("count"), os.clock()
  for i = 1, n do fn(i) end
  local k1, t1 = collectgarbage("count"), os.clock()
  collectgarbage("restart")
  out(("%-44s %8.2f us  %8.3f KB  per call"):format(label, (t1 - t0) / n * 1e6, (k1 - k0) / n))
end
ns:SyncClickers()
measure(CLASS .. ": click check, nothing changed", 2000, function() ns:SyncClickers() end)
measure(CLASS .. ": UpdateVisibility", 2000, function() ns:UpdateVisibility() end)
measure(CLASS .. ": 1 minute out of combat (4 checks/s)", 1, function()
  for i = 1, 240 do M.now = M.now + .25; ns:SyncClickers() end
end)
measure(CLASS .. ": 1 minute, 2 minutes after login", 1, function()
  M.now = M.now + 120
  for i = 1, 240 do M.now = M.now + .25; ns:SyncClickers() end
end)
return 0
