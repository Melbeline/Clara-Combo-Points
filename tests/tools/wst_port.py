# Ports WeaponSwingTimer 1.60.1 (Forever) into Clara Combo Points (Modules/WeaponSwingTimer).
# usage: python -I wst_port.py <WeaponSwingTimer source dir> <ClaraComboPoints dir>
# Every edit is anchored on text that must appear an exact number of times.
import os, sys, shutil

SRC, OUT = sys.argv[1], sys.argv[2]
MOD = os.path.join(OUT, "Modules", "WeaponSwingTimer")
os.makedirs(os.path.join(MOD, "Images"), exist_ok=True)
FILES = ["localization.lua", "WeaponSwingTimer_ranged_base_speed.lua", "WeaponSwingTimer_Utils.lua",
         "WeaponSwingTimer_Player.lua", "WeaponSwingTimer_Target.lua", "WeaponSwingTimer_Castbar.lua",
         "WeaponSwingTimer_Hunter.lua", "WeaponSwingTimer_Range.lua", "WeaponSwingTimer_Config.lua",
         "WeaponSwingTimer_Core.lua"]

def load(name):
    b = open(os.path.join(SRC, name), "rb").read()
    if b.startswith(b"\xef\xbb\xbf"): b = b[3:]
    return b.decode("utf-8").replace("\r\n", "\n")

def sub(text, old, new, count=1, where=""):
    n = text.count(old)
    if n != count:
        raise SystemExit("anchor count %d != %d in %s: %r" % (n, count, where, old[:90]))
    return text.replace(old, new)

HEADER = ("local _, ClaraNS = ...\n"
          "local E = ClaraNS.WST\n"
          "if not E then return end -- (Clara Combo Points, QoL.lua: the module does not run)\n"
          "setfenv(1, E.env) -- its globals are its own (Env.lua)\n"
          "local addon_name, addon_data = \"ClaraWST\", E.data\n")
IMG_OLD = "Interface/AddOns/WeaponSwingTimer/Images/"
IMG_NEW = "Interface/AddOns/ClaraComboPoints/Modules/WeaponSwingTimer/Images/"

out = {}
for name in FILES:
    t = load(name)
    t = sub(t, "local addon_name, addon_data = ...\n", HEADER, 1, name)
    t = t.replace(IMG_OLD, IMG_NEW)
    out[name] = t

# Utils: the chat prefix, a local, and the copy of nested tables
u = out["WeaponSwingTimer_Utils.lua"]
u = sub(u, '\tchat_msg = "|cFF00FFB0" .. addon_name .. ": |r" .. msg\n',
           '\tlocal chat_msg = "|cFF00FFB0WeaponSwingTimer: |r" .. msg\n', 1, "Utils")
u = sub(u, "            dst[k] = DeepCopy(v, {})\n", "            dst[k] = addon_data.utils.DeepCopy(v, {})\n", 1, "Utils")
out["WeaponSwingTimer_Utils.lua"] = u

# Player: GetSpellInfo is not a global in this client (paladins: every frame)
p = out["WeaponSwingTimer_Player.lua"]
p = sub(p, "\t\t\tlocal _, _, _, gcd, _,  _, _ = GetSpellInfo(19750)\n",
           "\t\t\tlocal info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(19750)\n"
           "\t\t\tlocal gcd = info and info.castTime\n", 1, "Player")
out["WeaponSwingTimer_Player.lua"] = p

# Hunter: the ranged bar on hunters only (a new box, on by default)
h = out["WeaponSwingTimer_Hunter.lua"]
h = sub(h, "\tenabled = true,\n\twidth = 300,\n\theight = 12,\n\tfontsize = 12,\n",
           "\tenabled = true,\n\thunters_only = true, -- (Clara Combo Points: the bar on hunters only)\n"
           "\twidth = 300,\n\theight = 12,\n\tfontsize = 12,\n", 1, "Hunter defaults")
h = sub(h, "--- Initializing variables for calculations and function calls\naddon_data.hunter.shooting = false\n",
           "--- Shown: enabled, and on a hunter unless it shows for every class (Clara Combo Points)\n"
           "addon_data.hunter.IsShown = function()\n"
           "    local settings = character_hunter_settings\n"
           "    if not (settings and settings.enabled) then return false end\n"
           "    if settings.hunters_only == false then return true end\n"
           "    local _, class = UnitClass(\"player\")\n"
           "    return class == \"HUNTER\"\n"
           "end\n"
           "--- Initializing variables for calculations and function calls\naddon_data.hunter.shooting = false\n", 1, "Hunter IsShown")
h = sub(h, "        if character_hunter_settings.enabled == nil then\n"
           "        local _, class = UnitClass(\"player\")\n"
           "        character_hunter_settings.enabled = (class == \"HUNTER\" or class == \"MAGE\" or class == \"PRIEST\" or class == \"WARLOCK\")\n"
           "    end\n", "", 1, "Hunter dead class default")
h = sub(h, "    local settings = character_hunter_settings\n    if settings.enabled then\n        -- Check to see if we have moved\n",
           "    local settings = character_hunter_settings\n    if addon_data.hunter.IsShown() then\n        -- Check to see if we have moved\n", 1, "Hunter OnUpdate")
h = sub(h, "    if settings.enabled then\n        frame.shot_bar_text:SetText(",
           "    if addon_data.hunter.IsShown() then\n        frame.shot_bar_text:SetText(", 1, "Hunter visuals")
h = sub(h, "\tif settings.enabled then\n        frame:EnableMouse(not settings.is_locked)\n",
           "\tif addon_data.hunter.IsShown() then\n        frame:EnableMouse(not settings.is_locked)\n", 1, "Hunter settings change")
h = sub(h, "    panel.enabled_checkbox:SetChecked(settings.enabled)\n    panel.show_multishot_clip_bar_checkbox",
           "    panel.enabled_checkbox:SetChecked(settings.enabled)\n"
           "    panel.hunters_only_checkbox:SetChecked(settings.hunters_only ~= false)\n"
           "    panel.show_multishot_clip_bar_checkbox", 1, "Hunter panel values")
h = sub(h, "addon_data.hunter.EnabledCheckBoxOnClick = function(self)\n"
           "    character_hunter_settings.enabled = self:GetChecked()\n"
           "    addon_data.hunter.UpdateVisualsOnSettingsChange()\nend\n",
           "addon_data.hunter.EnabledCheckBoxOnClick = function(self)\n"
           "    character_hunter_settings.enabled = self:GetChecked()\n"
           "    addon_data.hunter.UpdateVisualsOnSettingsChange()\nend\n\n"
           "addon_data.hunter.HuntersOnlyCheckBoxOnClick = function(self)\n"
           "    character_hunter_settings.hunters_only = self:GetChecked() and true or false\n"
           "    addon_data.hunter.UpdateVisualsOnSettingsChange()\nend\n", 1, "Hunter click")
h = sub(h, "    panel.show_text_checkbox:SetPoint(\"TOPLEFT\", 10, -150)\n",
           "    panel.show_text_checkbox:SetPoint(\"TOPLEFT\", 10, -150)\n\n"
           "    -- Hunters only Checkbox (Clara Combo Points)\n"
           "    panel.hunters_only_checkbox = addon_data.config.CheckBoxFactory(\n"
           "        \"HunterHuntersOnlyCheckBox\",\n"
           "        panel,\n"
           "        L[\"Hunters only\"],\n"
           "        L[\"Shows the shot bar on hunters only (unticked: on every class, for wands).\"],\n"
           "        addon_data.hunter.HuntersOnlyCheckBoxOnClick)\n"
           "    panel.hunters_only_checkbox:SetPoint(\"TOPLEFT\", 10, -170)\n", 1, "Hunter checkbox")
# the bar shows nowhere until enabled: its OnUpdate also hides it when not shown
out["WeaponSwingTimer_Hunter.lua"] = h

# Config: no global names, no logo, checkbox text through its key
c = out["WeaponSwingTimer_Config.lua"]
c = sub(c, 'addon_data.config.config_parent_panel = CreateFrame("Frame", "MyFrame", UIParent)',
           'addon_data.config.config_parent_panel = CreateFrame("Frame", nil, UIParent)', 1, "Config root")
c = sub(c, "    panel.logo = panel:CreateTexture(nil, 'ARTWORK')\t\n"
           "    panel.logo:SetTexture('" + IMG_NEW + "LandingPage')\t\n"
           "    panel.logo:SetSize(1024, 1024)\t\n"
           "    panel.logo:SetPoint('TOPLEFT', 5, -10)\n", "", 1, "Config logo")
c = sub(c, "    getglobal(checkbox:GetName() .. 'Text'):SetText(checkbtn_text)\n",
           "    local label = checkbox.Text or _G[checkbox:GetName() .. 'Text']\n    label:SetText(checkbtn_text)\n", 1, "Config getglobal")
c = c.replace('"WST_CONFIRM_DELETE_PROFILE"', '"CLARA_WST_CONFIRM_DELETE_PROFILE"')
c = c.replace('"WST_CONFIRM_RESET_PROFILE"', '"CLARA_WST_CONFIRM_RESET_PROFILE"')
out["WeaponSwingTimer_Config.lua"] = c

# Range: its slash command in the real global table
r = out["WeaponSwingTimer_Range.lua"]
r = sub(r, "SLASH_WSTRANGEDEBUG1 = ", "_G.SLASH_WSTRANGEDEBUG1 = ", 1, "Range slash")
out["WeaponSwingTimer_Range.lua"] = r

# Core
k = out["WeaponSwingTimer_Core.lua"]
k = sub(k, '    addon_data.db = AceDB:New("WSTProfileDB", addon_data.defaults, true)\n'
           '    -- added legacy settings check that was per character, for migrating into account wide\n'
           '    addon_data.core.CheckLegacySettingsOrWarn()\n'
           '    addon_data.core.MigrateLegacyPerCharToProfile()\n',
           '    E.PrepareSaved(addon_data) -- (Env.lua: an imported standalone install, Clara\'s defaults)\n'
           '    addon_data.db = AceDB:New(E.SV, addon_data.defaults, true)\n', 1, "Core InitDB")
k = sub(k, '    if character_core_settings.welcome_message then\t\n\t\taddon_data.utils.PrintMsg(load_message)\t\n\tend\n',
           '    -- (no welcome message: Clara Combo Points writes nothing in the chat)\n', 1, "Core welcome")
k = sub(k, '        if args[1] == "WeaponSwingTimer" then\n', '        if args[1] == E.ADDON then\n', 1, "Core ADDON_LOADED")
# unit events for the player (and the target) only, not every nameplate
for ev in ["UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_DELAYED",
           "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED_QUIET"]:
    k = sub(k, '    addon_data.core.core_frame:RegisterEvent("%s")\n' % ev,
               '    addon_data.core.core_frame:RegisterUnitEvent("%s", "player")\n' % ev, 1, "Core " + ev)
for ev in ["UNIT_COMBAT", "UNIT_INVENTORY_CHANGED"]:
    k = sub(k, '    addon_data.core.core_frame:RegisterEvent("%s")\n' % ev,
               '    addon_data.core.core_frame:RegisterUnitEvent("%s", "player", "target")\n' % ev, 1, "Core " + ev)
k = sub(k, 'SLASH_WEAPONSWINGTIMER_CONFIG1 = "/WeaponSwingTimer"\n'
           'SLASH_WEAPONSWINGTIMER_CONFIG2 = "/weaponswingtimer"\n'
           'SLASH_WEAPONSWINGTIMER_CONFIG3 = "/wst"\n'
           'SlashCmdList["WEAPONSWINGTIMER_CONFIG"] = function(option)\n'
           '    if Settings and Settings.OpenToCategory and addon_data.config.settingsCategoryID then\n'
           '        Settings.OpenToCategory(addon_data.config.settingsCategoryID)\n'
           '    elseif InterfaceOptionsFrame_OpenToCategory then\n'
           '        -- Fallback for older clients (called twice to work around a known bug)\n'
           '        InterfaceOptionsFrame_OpenToCategory("WeaponSwingTimer")\n'
           '        InterfaceOptionsFrame_OpenToCategory("WeaponSwingTimer")\n'
           '    end\n'
           'end\n',
           '_G.SLASH_WEAPONSWINGTIMER_CONFIG1 = "/WeaponSwingTimer"\n'
           '_G.SLASH_WEAPONSWINGTIMER_CONFIG2 = "/weaponswingtimer"\n'
           '_G.SLASH_WEAPONSWINGTIMER_CONFIG3 = "/wst"\n'
           'SlashCmdList["WEAPONSWINGTIMER_CONFIG"] = function(option)\n'
           '    if InCombatLockdown() then return end -- (the game\'s options do not open in combat)\n'
           '    if Settings and Settings.OpenToCategory and addon_data.config.settingsCategoryID then\n'
           '        Settings.OpenToCategory(addon_data.config.settingsCategoryID)\n'
           '    end\n'
           'end\n', 1, "Core slash")
out["WeaponSwingTimer_Core.lua"] = k

# Localization: the new box, in English, French and German
l = out["localization.lua"]
l += ('\n-- Clara Combo Points\n'
      'L["Hunters only"] = "Hunters only"\n'
      'L["Shows the shot bar on hunters only (unticked: on every class, for wands)."] = "Shows the shot bar on hunters only (unticked: on every class, for wands)."\n'
      'if GetLocale() == "frFR" then\n'
      '\tL["Hunters only"] = "Chasseurs seulement"\n'
      '\tL["Shows the shot bar on hunters only (unticked: on every class, for wands)."] = "N\'affiche la barre de tir que sur les chasseurs (décoché : sur toutes les classes, pour les baguettes)."\n'
      'elseif GetLocale() == "deDE" then\n'
      '\tL["Hunters only"] = "Nur Jäger"\n'
      '\tL["Shows the shot bar on hunters only (unticked: on every class, for wands)."] = "Zeigt die Schussleiste nur bei Jägern (abgewählt: bei allen Klassen, für Zauberstäbe)."\n'
      'end\n')
out["localization.lua"] = l

for name, t in out.items():
    with open(os.path.join(MOD, name), "w", encoding="utf-8", newline="\n") as f: f.write(t)
for img in ["Background", "Bar", "Border", "Spark"]:
    shutil.copyfile(os.path.join(SRC, "Images", img + ".blp"), os.path.join(MOD, "Images", img + ".blp"))
# the libraries (shared, version-checked by LibStub)
for lib, path in [("LibStub", "LibStub/LibStub.lua"), ("CallbackHandler-1.0", "CallbackHandler-1.0/CallbackHandler-1.0.lua"),
                  ("AceDB-3.0", "AceDB-3.0/AceDB-3.0.lua")]:
    d = os.path.join(OUT, "Libs", lib)
    os.makedirs(d, exist_ok=True)
    b = open(os.path.join(SRC, "Libs", "Ace3", path), "rb").read().replace(b"\r\n", b"\n")
    open(os.path.join(d, os.path.basename(path)), "wb").write(b)
print("ok", MOD)
