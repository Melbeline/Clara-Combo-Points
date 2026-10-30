-- Profiling: a rogue in combat for N frames, with the usual events. Prints time, garbage
-- and the hot lines of the addon (sampled every K instructions; each sample goes to the
-- innermost frame in the addon's own files).
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local CLASS = PROF_CLASS or "ROGUE"
S.class = CLASS; S.locale = "enUS"
S.knownSpells = { [1752] = true, [5171] = true, [2098] = true, [2983] = true, [5277] = true, [1784] = true, [1766] = true, [1943] = true }
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
M.now = 100
local p = ns.sv.profiles[CLASS]
p.rows.above[1] = { 5171, 2983, 5277, 1784 }
p.rows.below[1] = { 1943, 1766, 2098 }
ns:LayoutIcons(); ns:UpdateVisibility()
S.target = { cp = 0, hostile = true, name = "Boar" }
M.Fire("PLAYER_TARGET_CHANGED")
S.inCombat = true; M.Fire("PLAYER_REGEN_DISABLED")
S.auras = { player = { { name = "Slice and Dice", icon = 1, applications = 0, duration = 21, expirationTime = 121, id = 1, spellId = 5171 } },
  target = { { name = "Rupture", icon = 2, applications = 0, duration = 16, expirationTime = 116, harmful = true, id = 2, spellId = 1943, sourceUnit = "player" } } }
S.cooldowns = S.cooldowns or {}
S.cooldowns["Sprint"] = { 100, 300 }
M.Frame(0.016)

local N = PROF_FRAMES or 3000
local function scenario()
  for i = 1, N do
    S.energy = (S.energy + 0.16) % 100
    if i % 30 == 0 then M.Fire("UNIT_POWER_FREQUENT", "player", "ENERGY") end
    if i % 8 == 0 then M.Fire("SPELL_UPDATE_COOLDOWN") end
    if i % 20 == 0 then M.Fire("UNIT_AURA", "player", {}) ; M.Fire("UNIT_AURA", "target", {}) end
    if i % 90 == 0 then S.target.cp = (S.target.cp + 1) % 6; S.playerCP = S.target.cp; M.Fire("UNIT_POWER_UPDATE", "player", "COMBO_POINTS") end
    if i % 45 == 0 then M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 1752) end
    M.Frame(0.016)
  end
end

-- 1) time and garbage
collectgarbage("collect"); collectgarbage("stop")
local k0, t0 = collectgarbage("count"), os.clock()
scenario()
local k1, t1 = collectgarbage("count"), os.clock()
collectgarbage("restart")
out(("%d frames: %.3f s, %.1f KB garbage (%.2f KB / frame) [mock included]"):format(N, t1 - t0, k1 - k0, (k1 - k0) / N))

-- 2) hot lines
local hits, total = {}, 0
local function addonFrame()
  for lvl = 2, 40 do
    local info = debug.getinfo(lvl, "Sl")
    if not info then return end
    local src = info.source
    if src:sub(1, 1) == "@" and not src:find("wowmock") and not src:find("prof_") then
      return src:sub(2) .. ":" .. (info.currentline or 0)
    end
  end
end
debug.sethook(function()
  total = total + 1
  local k = addonFrame()
  if k then hits[k] = (hits[k] or 0) + 1 end
end, "", PROF_K or 200)
scenario()
debug.sethook()
local list = {}
for k, v in pairs(hits) do list[#list + 1] = { k, v } end
table.sort(list, function(a, b) return a[2] > b[2] end)
local inAddon = 0
for _, e in ipairs(list) do inAddon = inAddon + e[2] end
out(("samples: %d, under addon code: %d"):format(total, inAddon))
for i = 1, math.min(PROF_TOP or 40, #list) do out(("%6d  %s"):format(list[i][2], list[i][1])) end
return 0
