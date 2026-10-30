-- memory kept by each file at load, and after login
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
S.class = "ROGUE"; S.locale = "enUS"
-- (not Forever: the modules stay off)
local ns = {}
local dir = ADDON_DIR
local toc = assert(io.open(dir .. "/ClaraComboPoints.toc", "rb")):read("*a")
collectgarbage("collect")
local start = collectgarbage("count")
local per = {}
for file in toc:gmatch("[^\r\n]+") do
  if not file:match("^##") and file:match("%.lua$") then
    collectgarbage("collect")
    local k0 = collectgarbage("count")
    local f = assert(io.open(dir .. "/" .. file:gsub("\\", "/"), "rb"))
    local chunk = assert(loadstring(f:read("*a"), "@" .. file)); f:close()
    chunk("ClaraComboPoints", ns)
    chunk = nil
    collectgarbage("collect")
    per[#per + 1] = { file, collectgarbage("count") - k0 }
  end
end
for _, e in ipairs(per) do if e[2] > 5 then out(("%8.1f KB  %s"):format(e[2], e[1])) end end
collectgarbage("collect")
out(("files loaded: %.1f KB"):format(collectgarbage("count") - start))
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
for _ = 1, 3 do M.Frame(0.016) end
collectgarbage("collect")
out(("after login: %.1f KB"):format(collectgarbage("count") - start))
SlashCmdList.CLARACOMBOPOINTS("")
M.Frame(0.016)
collectgarbage("collect")
out(("options opened: %.1f KB"):format(collectgarbage("count") - start))
return 0
