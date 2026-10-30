local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
S.bags = { [13452] = 0 }
-- the real GetItemSpell returns nothing while the item's data is not loaded
local real = C_Item.GetItemSpell
C_Item.GetItemSpell = function(i)
  local id = type(i) == "number" and i or tonumber(tostring(i):match("item:(%d+)"))
  if (S.uncachedItems or {})[id] then return end
  return real(i)
end
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
M.Frame(0.1)
ns:ClearRow("above", 1)
ns:AddIcon("above", 1, "item:13452") -- Elixir of the Mongoose (none carried)
-- next login: the elixir's data not loaded yet
S.uncachedItems = { [13452] = true }
local before = M.itemRequests or 0
local okA, errA = pcall(ns.ApplyAll, ns); out("ApplyAll with the elixir not loaded: ok=" .. tostring(okA) .. " " .. tostring(errA)); M.Frame(0.1)
out("item data requested at layout: " .. tostring((M.itemRequests or 0) > before))
-- bought: data arrives, bags change
S.uncachedItems = nil
S.bags[13452] = 3
M.Fire("GET_ITEM_INFO_RECEIVED", 13452, true)
M.Fire("BAG_UPDATE_DELAYED"); M.Frame(0.1)
local row
for _, f in ipairs(M.frames) do if f._parent == ns.iconLayer and f.side == "above" and f.k == 1 then row = f end end
local slot = row.slots[1]
out("slot.name = " .. tostring(slot.name) .. ", itemSpell = " .. tostring(slot.itemSpell))
S.auras = { player = { { name = "Elixir of the Mongoose", icon = 134812, applications = 0, duration = 3600, expirationTime = 3000, spellId = 17538 } } }
M.now = 10
M.Fire("UNIT_AURA", "player"); M.Frame(0.1)
out("buff up: swipe = " .. tostring(slot.cd._cd and slot.cd._cd[2]))
