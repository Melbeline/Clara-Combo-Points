-- Clara Combo Points - XToLevel 12.1.5 (XToLevelNG, by Atli Þór and Bjarke Istrup Pedersen;
-- LICENSE.txt), built in (QoL.lua): how many kills, quests, dungeons and battlegrounds are left
-- to the next level, in a small window, a LibDataBroker feed and the tooltips. The first of the
-- module's files: it tells the others (and their libraries) whether they run, and gives them
-- their shared table. Its settings and each character's data are saved in ClaraXToLevelDB; its
-- pages in the game's options sit under Interface improvements. Its windows are templates here,
-- made by Glue.lua only while it runs (frames of an XML file are made, and shown, in every
-- session), with names of their own (ClaraXToLevel_...: no clash with the standalone's).
-- The built-in one takes over from the standalone XToLevel: while that one is enabled it runs for
-- the session, its settings and this character's data are carried over at logout where Clara's
-- copy has none yet, and it is turned off for the character (QoL.lua), so that the built-in one
-- runs from the next reload.

local ADDON, ns = ...

ns.XToLevelRuns = ns:QolRuns("xtolevel")
if ns.XToLevelRuns then
  ns.XToLevelPrivate = {} -- (the standalone's own `...` table)
elseif ns:QolTakesOver("xtolevel") then
  -- what Clara's copy has not got yet: this character's data and profile, the other profiles
  local function Missing(into, from, key)
    if type(from) == "table" and from[key] ~= nil and into[key] == nil then
      into[key] = type(from[key]) == "table" and CopyTable(from[key]) or from[key]
    end
  end
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGOUT")
  f:SetScript("OnEvent", function()
    local own = _G.XToLevelDB
    if type(own) ~= "table" then return end
    if type(ClaraXToLevelDB) ~= "table" then ClaraXToLevelDB = {} end
    -- this character's key, as the standalone's AceDB has it (it depends on the client's realms)
    local x = _G.XToLevel
    local keys = type(x) == "table" and type(x.db) == "table" and type(x.db.keys) == "table" and x.db.keys
    local db, me = ClaraXToLevelDB, keys and keys.char or (UnitName("player") .. " - " .. GetRealmName())
    for _, part in ipairs({ "char", "profileKeys", "profiles" }) do
      if type(own[part]) == "table" then
        db[part] = type(db[part]) == "table" and db[part] or {}
        if part == "profiles" then
          for name in pairs(own.profiles) do Missing(db.profiles, own.profiles, name) end
        else
          Missing(db[part], own[part], me)
        end
      end
    end
    Missing(db, own, "global")
  end)
end
