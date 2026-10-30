-- Fishing mode (FishingMode.lua): music, ambience, voices, reverb and distance filtering off,
-- effects at 100 %, master volume xN (never past 100 %), sound in the background; given back when off and at logout (a setting the player changed
-- meanwhile left as it is), on again at login; its line in the portrait's menu, its box on the
-- Fishing card of the professions window (the game's and ClassicUI's)
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

local START = { Sound_EnableMusic = "1", Sound_EnableAmbience = "1", Sound_EnableDialog = "1", Sound_EnableErrorSpeech = "1",
  Sound_EnableEmoteSounds = "1", Sound_EnablePetSounds = "1", Sound_EnableAllSound = "1", Sound_EnableSFX = "1",
  Sound_EnableGameplaySFX = "1", Sound_EnableSoundWhenGameIsInBG = "0", Sound_SFXVolume = "0.4", Sound_GameplaySFX = "1",
  Sound_MasterVolume = "0.5", Sound_MusicVolume = "0.7", Sound_EnableReverb = "1", Sound_EnablePositionalLowPassFilter = "1" }
local CVARS = {}
for k, v in pairs(START) do CVARS[k] = v end
C_CVar = { GetCVar = function(n) return CVARS[n] end, SetCVar = function(n, v) CVARS[n] = tostring(v) end }
local fishSkill = 4
function GetProfessions() return nil, nil, nil, fishSkill, nil end
local loaded = {}
C_AddOns = C_AddOns or {}
C_AddOns.IsAddOnLoaded = function(name) return loaded[name] == true end

local ns = {}
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
Run()
-- A new session: the file's own frame hears PLAYER_LOGIN again
local function Login()
  for f in pairs(M.eventFrames) do
    local script = f._scripts and f._scripts.OnEvent
    if script and (debug.getinfo(script, "S").source or ""):find("FishingMode") then script(f, "PLAYER_LOGIN") end
  end
end

check(not ns:FishingMode() and CVARS.Sound_EnableMusic == "1", "off at first, nothing touched")
-- the portrait's menu: its line, last of the section
local function FindLine()
  M.OpenUnitMenu("SELF")
  for _, fn in ipairs(M.menuModifiers.MENU_UNIT_SELF) do
    local found
    local root = { elements = {} }
    function root:EnumerateElementDescriptions() return ipairs(self.elements) end
    function root:Insert(d, i) if i then table.insert(self.elements, i, d) else table.insert(self.elements, d) end return d end
    function root:CreateButton(t, c) return self:Insert({ text = t, callback = c }) end
    fn(UIParent, root, {})
    for _, more in ipairs(root.elements) do
      for i, d in ipairs(more.elements or {}) do if d.text == "Fishing mode" then return d, i, more.elements end end
    end
  end
end
local d, at, elements = FindLine()
check(d ~= nil and d.isSelected() == false, "a Fishing mode line in the portrait's menu (under More...)")
check(d and elements[at + 1] and elements[at + 1].text == "Options", "the last box, above Options")
d.setSelected()
check(ns:FishingMode(), "the line turns it on")
check(CVARS.Sound_EnableMusic == "0" and CVARS.Sound_EnableAmbience == "0" and CVARS.Sound_EnableDialog == "0"
  and CVARS.Sound_EnableErrorSpeech == "0" and CVARS.Sound_EnableEmoteSounds == "0" and CVARS.Sound_EnablePetSounds == "0",
  "music, ambience, dialogue and the other voices off")
check(CVARS.Sound_EnableReverb == "0" and CVARS.Sound_EnablePositionalLowPassFilter == "0", "reverb and distance filtering off")
check(CVARS.Sound_EnableSFX == "1" and CVARS.Sound_EnableGameplaySFX == "1" and CVARS.Sound_EnableSoundWhenGameIsInBG == "1",
  "effects on, sound in the background")
check(CVARS.Sound_SFXVolume == "1" and CVARS.Sound_GameplaySFX == "1", "sound effects at 100 %")
check(CVARS.Sound_MasterVolume == "1", "x2: master volume 50 -> 100 %")
check(CVARS.Sound_MusicVolume == "0.7", "the music's volume itself not touched")
-- x10: never past 100 %
ns:SetFishingBoost(10)
check(CVARS.Sound_MasterVolume == "1" and ns:FishingBoost() == 10, "x10: 100 % at most")
-- the player sets the master volume meanwhile: taken as theirs
CVARS.Sound_MasterVolume = "0.3"
ns:SetFishingBoost(2)
check(CVARS.Sound_MasterVolume == "0.6", "a master volume the player set meanwhile: the boost from it")
CVARS.Sound_EnableAmbience = "1" -- (the player turns ambience back on)
ns:SetFishingMode(false)
check(not ns:FishingMode() and CVARS.Sound_EnableMusic == "1" and CVARS.Sound_EnableSoundWhenGameIsInBG == "0"
  and CVARS.Sound_SFXVolume == "0.4" and CVARS.Sound_EnableReverb == "1" and CVARS.Sound_EnablePositionalLowPassFilter == "1",
  "off: all given back")
check(CVARS.Sound_MasterVolume == "0.3", "the master volume the player set meanwhile kept")
check(ClaraComboPointsDB.fishingSound == nil and ClaraComboPointsDB.fishingSoundSet == nil, "nothing left kept")
-- logout and login: given back at logout, on again at login
ns:SetFishingMode(true)
M.Fire("PLAYER_LOGOUT")
check(CVARS.Sound_EnableMusic == "1" and CVARS.Sound_SFXVolume == "0.4" and ns:FishingMode(), "logout: the game saves its own settings, the mode stays on")
Login()
check(CVARS.Sound_EnableMusic == "0" and CVARS.Sound_SFXVolume == "1" and CVARS.Sound_MasterVolume == "0.6", "login: on again")
-- the game closed in fishing mode (no logout): given back at the next login, the mode off
ClaraComboPointsDB.fishingMode = nil
Login()
check(CVARS.Sound_EnableMusic == "1" and CVARS.Sound_SFXVolume == "0.4" and CVARS.Sound_EnableSoundWhenGameIsInBG == "0",
  "closed in fishing mode: given back at the next login")

-- the professions window's Fishing card
local frame = CreateFrame("Frame", "ProfessionsFrame", UIParent)
local page = CreateFrame("Frame", nil, frame); frame.BookPage = page
page.ProfessionsContentFrame = CreateFrame("Frame", nil, page)
local card = CreateFrame("Frame", nil, page.ProfessionsContentFrame)
page.ProfessionsContentFrame.SecondaryProfession2 = card
card:SetSize(225, 275)
card.missingHeader = card:CreateFontString(); card.missingHeader:Hide()
card.SpellButton1 = CreateFrame("CheckButton", nil, card)
function page:Update() card.professionInitialized = fishSkill ~= nil; card.missingHeader:SetShown(fishSkill == nil) end
page:SetScript("OnShow", function(self) self:Update() end)
page:Hide()
loaded.Blizzard_Professions = true
M.Fire("ADDON_LOADED", "Blizzard_Professions") -- (the game loads its professions window)
page:Show(); Run()
local box = card.claraFishingMode
check(box ~= nil and box:IsShown() and not box:GetChecked(), "a box on the Fishing card")
local p, rel, rp, x, y = box:GetPoint(1)
check(p == "TOPLEFT" and rel == card and x == 18 and y == -76, "under the card's skill bar (the game's book)")
check((box.Text or box.text):GetText() == "Fishing mode", "named")
box:Click()
check(ns:FishingMode() and CVARS.Sound_EnableMusic == "0", "the box turns it on")
-- ClassicUI's book: left of the row's spells
ns.ClassicUIPrivate = { prof = { shown = true } }
card:SetSize(305, 52)
card.SpellButton1:SetSize(30, 30)
card.SpellButton1:SetPoint("TOPLEFT", card, "TOPLEFT", 154, -6)
page:Update(); Run()
p, rel, rp, x, y = box:GetPoint(1)
check(p == "RIGHT" and rel == card and rp == "TOPLEFT" and x == 140 and y == -15,
  "ClassicUI's book: left of the row's spell, hung on the card (not on the casting button)")
ns.ClassicUIPrivate = nil
box:Click()
check(not ns:FishingMode() and CVARS.Sound_EnableMusic == "1", "and off")
-- no Fishing learned: no box, no line
fishSkill = nil; S.knownSpells = {}
page:Update(); Run()
check(not box:IsShown(), "Fishing not learned: no box")
check(FindLine() == nil, "nor a line in the portrait's menu")
out("")
out(fails .. " failure(s)")
