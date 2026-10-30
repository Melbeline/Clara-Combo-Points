-- the real class spell lists (SpellCatalog.lua)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")

out("== the lists")
local order, total, bad = {}, 0, {}
local KINDS = { BUFF = true, DEBUFF = true, SELFDEBUFF = true, SPELL = true, IMBUE = true }
for _, class in ipairs(ns.SPELL_CATALOG) do
  order[#order + 1] = class.class
  local seen = {}
  for _, spell in ipairs(class.spells) do
    total = total + 1
    if not KINDS[spell[1]] or #spell < 2 then bad[#bad + 1] = class.class .. ":" .. tostring(spell[2]) end
    for r = 2, #spell do
      local id = spell[r]
      if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) or seen[id] then bad[#bad + 1] = class.class .. ":" .. tostring(id) end
      seen[id] = true
    end
    if spell.alt then
      if #spell.alt > #spell - 1 then bad[#bad + 1] = class.class .. ": alt longer than ranks " .. spell[2] end
      for _, a in ipairs(spell.alt) do
        if a then
          if seen[a] then bad[#bad + 1] = class.class .. ": alt twice " .. a end
          seen[a] = true
        end
      end
    end
  end
end
check(table.concat(order, ",") == "PRIEST,MAGE,WARLOCK,ROGUE,DRUID,HUNTER,SHAMAN,PALADIN,WARRIOR,GENERAL,HUMAN,DWARF,NIGHTELF,GNOME,"
  .. "SKYBORNE_ALLIANCE,ORC,UNDEAD,TAUREN,TROLL,SKYBORNE_HORDE", "classes in the asked order, then the General tab and the races")
check(total > 300, "every class's buffs and debuffs (" .. total .. " spells)")
check(#bad == 0, "kinds and IDs well formed, no ID twice in a class " .. table.concat(bad, " "))

out("== used by the addon")
local ok, msg = ns:AddIcon("below", 1, "renew")
check(ok and ns.db.rows.below[1][1] == 6075, "'renew' found: the highest rank this client knows (" .. tostring(msg) .. ")")
local ranks = ns:SpellRanks(6075)
check(ranks and #ranks == 3 and ranks[3][1] == 3 and ranks[3][2] == 6075 and ranks[3][3] == 425270, "Renew ranks with Forever's second IDs")
local ids = ns:RankIDs(6075)
check(ids[6075] and ids[425270] and not ids[6074], "rank 3 only: both of its IDs")
SlashCmdList.CLARACOMBOPOINTS("")
for _, f in ipairs(M.frames) do if f.page == 3 then f:Click() end end
local heads = {}
for _, g in ipairs(ClaraComboPointsSpells.groups) do heads[#heads + 1] = g.class .. "=" .. #g.recs end
check(#heads >= 3, "panel built from the real lists, spells this client knows only: " .. table.concat(heads, " "))
ClaraComboPointsOptions:Hide()

out(string.format("\n%d failure(s)", fails))
return fails
