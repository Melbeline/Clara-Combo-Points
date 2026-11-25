-- Easy Fishing 2.0 (the standalone addon: ADDON_DIR is its folder): Clara Combo Points' fishing files run in it as they
-- are (Fishing.lua, FishingMode.lua, byte for byte the same as Clara's), its own button and binding (EasyFishingButton:
-- the key the player bound in 1.0.x kept), its saved settings (EasyFishingDB: 1.0.x's carried over, the sounds its
-- mode had turned off given back), the fishing mode Clara's (master volume ×2 by default), the portrait's menu entry
-- (out of combat, Fishing known), and beside Clara: Clara's module standing aside, no button of Clara's in the way.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local CLARA = "/home/user/Clara-Combo-Points/ClaraComboPoints"
local toc = io.open(ADDON_DIR .. "/EasyFishing.toc", "rb")
if not toc then out("(Easy Fishing's own test: run it with its folder)"); out(""); out("0 failure(s)"); return end
toc:close()

out("== the shared files, byte for byte")
local function Read(p) local f = io.open(p, "rb"); if not f then return nil end local s = f:read("*a"); f:close() return s end
for _, f in ipairs({ "Fishing.lua", "FishingMode.lua" }) do
  check(Read(ADDON_DIR .. "/" .. f) ~= nil and Read(ADDON_DIR .. "/" .. f) == Read(CLARA .. "/" .. f), f .. ": Clara's, as it is")
end

GetBuildInfo = function() return "1.60.1", "71000", "Nov 25 2026", 16001 end
local cvars = { Sound_EnableMusic = "0", Sound_EnableAmbience = "0", Sound_MasterVolume = "0.4", Sound_SFXVolume = "1",
  Sound_EnableAllSound = "1", Sound_EnableSFX = "1" }
C_CVar = C_CVar or {}
C_CVar.GetCVar = function(n) return cvars[n] end
C_CVar.SetCVar = function(n, v) cvars[n] = tostring(v) end
-- 1.0.9's saved settings: its mode on (music and ambience turned off by it), a pole's weapons kept
EasyFishingDB = { mode = true, modeVolume = 80, sound = { Sound_EnableMusic = "1", Sound_EnableAmbience = "1" },
  soundSet = { Sound_EnableMusic = "0", Sound_EnableAmbience = "0" }, weapons = { ["Player-1"] = { main = "item:1" } } }
local ns = {}
S.class = "HUNTER"; S.locale = "enUS"
M.LoadAddonAs(ADDON_DIR, "EasyFishing.toc", "EasyFishing", ns)
M.Fire("ADDON_LOADED", "EasyFishing")

out("== 1.0.x's settings carried over")
local db = EasyFishingDB
check(db.fishingMode == true and db.mode == nil and db.v2, "its mode: on")
check(db.fishingWeapons and db.fishingWeapons["Player-1"] and db.weapons == nil, "the weapons a pole replaced: kept")
check(db.modeVolume == nil and db.sound == nil, "1.0.x's own fields gone")
M.Fire("PLAYER_LOGIN")
check(ns:FishingMode(), "the mode on at login (Clara's)")
check(cvars.Sound_EnableMusic == "0" and db.fishingSound and db.fishingSound.Sound_EnableMusic == "1",
  "the music 1.0.x turned off: still to be given back (" .. tostring(db.fishingSound and db.fishingSound.Sound_EnableMusic) .. ")")
check(cvars.Sound_MasterVolume == "0.8", "the master volume ×2 (" .. tostring(cvars.Sound_MasterVolume) .. ")")
ns:SetFishingMode(false)
check(cvars.Sound_EnableMusic == "1" and cvars.Sound_EnableAmbience == "1" and cvars.Sound_MasterVolume == "0.4",
  "the mode off: the music, the ambience and the volume given back")

out("== its key")
check(_G.EasyFishingButton ~= nil and _G.ClaraFishingButton == nil, "its own button (EasyFishingButton), none of Clara's")
check(_G["BINDING_NAME_CLICK EasyFishingButton:LeftButton"] ~= nil and BINDING_HEADER_EASYFISHING == "Easy Fishing",
  "its binding named, under Easy Fishing (the key bound in 1.0.x: the same binding)")
check(BINDING_CATEGORY_CLARA == nil, "no Clara category of its own making")

out("== the portrait's menu")
local entries = {}
local root = { CreateDivider = function() end, CreateTitle = function(_, t) entries[#entries + 1] = t end,
  CreateCheckbox = function(_, t) entries[#entries + 1] = t; return { SetTooltip = function() end } end }
IsPlayerSpell = function(id) return id == 7620 end
ns.MenuEntries(nil, root)
check(entries[1] == "Fishing" and entries[2] == "Fishing mode", "a Fishing section, its mode box")
entries = {}
S.inCombat = true
ns.MenuEntries(nil, root)
S.inCombat = false
check(#entries == 0, "in combat: nothing added (the game refuses it)")

out("== beside Clara")
local cns = {}
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false, tooltipanchor = false } }
C_AddOns = C_AddOns or {}
local loaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(name) if name == "EasyFishing" then return true, true end return loaded and loaded(name) end
local enabled = C_AddOns.GetAddOnEnableState
C_AddOns.GetAddOnEnableState = function(name, ...) if name == "EasyFishing" then return 2 end return enabled and enabled(name, ...) or 0 end
M.LoadAddon(CLARA, cns)
M.Fire("ADDON_LOADED", "ClaraComboPoints")
check(not cns:QolRuns("fishing"), "Clara's fishing module stands aside")
check(not cns:FishingModeOffered(), "no fishing line of Clara's in the menu")
check(_G.EasyFishingButton ~= nil, "Easy Fishing's button still there")
out("")
out(fails .. " failure(s)")
