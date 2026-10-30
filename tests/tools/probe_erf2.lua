local M, S = MOCK, MOCK.state
local src = assert(io.open(TOOLS_DIR .. "/test63.lua")):read("*a")
src = src:gsub('out%("== the game.s aura slots"%).*$', 'return ERF, mate, ns')
local ERF, mate, ns = assert(loadstring(src))()
io.write("watch1 ", tostring(ERF.gameAuraWatch[1]), " ids ", tostring(ERF.gameAuraWatch[1] and ERF.gameAuraWatch[1].ids), "\n")
local c = mate.ERF_auraContainer
io.write("container ", tostring(c), "\n")
for k, s in pairs(c and c._slots or {}) do if k:find("%-1HELP") then io.write(k, " enabled=", tostring(s.enabled), " filters=", tostring(s.filters), "\n") end end
io.write("catalog renew: ", tostring(#ns:CatalogRecords(nil, "renew")), "\n")
for _, e in ipairs(M.errors or {}) do io.write("ERR ", tostring(e), "\n") end
local key = "ERF" .. mate:GetName() .. "-1HELPFUL"
io.write("direct: ", tostring(pcall(c.SetAuraSlotCandidateFilters, c, key, { includeSpellIDs = { [1] = true } })), "\n")
io.write(select(2, pcall(c.SetAuraSlotCandidateFilters, c, key, { includeSpellIDs = { [1] = true } })) or "no err", "\n")
local ok, err = pcall(function()
  local rec = mate.ERF_slots[1].HELPFUL
  io.write("rec.key=", tostring(rec.key), " filterKey=", tostring(rec.filterKey), " enabled=", tostring(rec.enabled), "\n")
end)
io.write("pcall ", tostring(ok), " ", tostring(err), "\n")
io.write("gameAuraError ", tostring(ERF.gameAuraError), "\n")
