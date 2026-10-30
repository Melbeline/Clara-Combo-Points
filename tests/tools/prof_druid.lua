local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
S.class = "DRUID"; S.locale = "enUS"; S.powerType = 3
S.forms = { 5487, 768 }; S.form = 2
S.knownSpells = { [5487] = true, [768] = true, [6807] = true, [1082] = true, [5221] = true, [16979] = true, [774] = true, [5215] = true }
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.now = 100
local p = ns.sv.profiles.DRUID
p.rows.above[1] = { 6807, 1082, 5221, 16979 }
p.rows.below[1] = { 774, 5215 }
ns:LayoutIcons(); ns:UpdateVisibility()
for _ = 1, 5 do M.Frame(0.016) end
local function measure(label, n, fn)
  collectgarbage("collect"); collectgarbage("stop")
  local k0, t0 = collectgarbage("count"), os.clock()
  for i = 1, n do fn(i) end
  local k1, t1 = collectgarbage("count"), os.clock()
  collectgarbage("restart")
  out(("%-40s %8.2f us  %8.3f KB  per call"):format(label, (t1 - t0) / n * 1e6, (k1 - k0) / n))
end
local list = ns:ClickButtons()
local shown = 0 for _, b in ipairs(list) do if b:IsShown() then shown = shown + 1 end end
out("druid click buttons shown: " .. shown)
measure("SyncClickers druid, nothing changed", 500, function() ns:SyncClickers() end)
local ticker
for _, f in ipairs(M.frames) do
  if f._scripts and f._scripts.OnUpdate and f._events and f._events.SPELLS_CHANGED then ticker = f end
end
measure("Clicks ticker per frame (druid)", 3000, function() ticker._scripts.OnUpdate(ticker, 0.016) end)
return 0
