"""Builds full_harness.lua: the mock of tools/cui_harness.lua (up to its Budget) + full_tail.lua."""
import os
base = os.path.dirname(os.path.abspath(__file__)) + "/../"
lines = open(base + "tools/cui_harness.lua").read().split("\n")
end = next(i for i, l in enumerate(lines) if l.startswith("local addonCalls"))
head = "\n".join(lines[:end])
def rep(a, b):
    global head
    assert head.count(a) == 1, a[:60]
    head = head.replace(a, b)
rep("-- Harness for the ClassicUI Forever module of Clara Combo Points (lupa, Lua 5.1), on a permissive\n-- mock of the game API (taken from the DialogKey / XToLevel one). ADDON = the ClaraComboPoints folder.",
    "-- The whole of Clara (lupa, Lua 5.1): every file of its TOC, every module on, a session played; on the mock of\n-- the ClassicUI harness, typed from the game's API documentation. ADDON = the ClaraComboPoints folder. Run by full_run.py.\n-- Made by make_full.py: edit full_tail.lua or tools/cui_harness.lua, not this file.")
rep("    for k in pairs(idx.parentkeys) do PARENTKEYS[k] = true end", "    for k in pairs(idx.parentkeys) do PARENTKEYS[k] = true end\n    for k in pairs(idx.templates) do FXTEMPLATES[k] = true end")
rep("local FXNUM, FXEXPR, FXTABLES, FXKNOWN = {}, {}, {}, {}", "local FXNUM, FXEXPR, FXTABLES, FXKNOWN = {}, {}, {}, {}\nFXTEMPLATES = {}")
# a capital global the game's code never names: still its own name as text (a global string the client has), reported
rep("    UNKNOWN_CAPS[k] = true; return nil", "    UNKNOWN_CAPS[k] = true; rawset(t, k, k); return k")
head += """
BLIZZ_ADDONS = { "Blizzard_Professions", "Blizzard_ProfessionsBook", "Blizzard_PlayerSpells", "Blizzard_TrainerUI", "Blizzard_Settings",
  "Blizzard_WorldMap", "Blizzard_Collections", "Blizzard_InspectUI", "Blizzard_AuctionHouseUI", "Blizzard_Communities",
  "Blizzard_GroupFinder_VanillaStyle", "Blizzard_TimeManager", "Blizzard_MacroUI", "Blizzard_EncounterJournal", "Blizzard_AchievementUI",
  "Blizzard_Calendar", "Blizzard_GuildBankUI", "Blizzard_ItemSocketingUI", "Blizzard_LegacySystem", "Blizzard_ClickBindingUI",
  "Blizzard_PlayerChoice", "Blizzard_DeathRecap" }
-- WoW's Lua: getfenv(0) is _G; strings have split, join, trim
rawset(env, "getfenv", function(f) if f == 0 or f == nil then return env end if type(f) == "number" then return getfenv(f + 1) end return getfenv(f) end)
-- loadstring's chunks run in _G, as in the game
rawset(env, "loadstring", function(src, name) local f, e = loadstring(src, name); if f then setfenv(f, env) end return f, e end)
string.split = function(sep, s, n) return env.strsplit(sep, s, n) end -- ("\001"):split(s) is strsplit("\001", s)
string.trim = function(s) return env.strtrim(s) end
string.join = function(sep, ...) return env.strjoin(sep, ...) end
-- names the cui harness keeps nil for its own checks: here as the game has them
for k in pairs(NILS) do
  if FXKNOWN[k] or DOCT.namespaces[k] or DOCT.globals[k] then NILS[k] = nil end
end
-- legacy C functions the documentation leaves out (assumed present, as in every client since 8.2)
for _, k in ipairs({ "MuteSoundFile", "UnmuteSoundFile" }) do FXKNOWN[k] = true end
for _, d in ipairs({ "In", "Out", "Left", "Right", "Up", "Down" }) do FXKNOWN["MoveView" .. d .. "Start"] = true; FXKNOWN["MoveView" .. d .. "Stop"] = true end
"""
open(base + "fullenv/full_harness.lua", "w").write(head + open(base + "fullenv/full_tail.lua").read())
print("full_harness.lua written")
