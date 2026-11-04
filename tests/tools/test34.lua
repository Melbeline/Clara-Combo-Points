-- Clara in the game's options (Esc > Options > AddOns): first of the list, its first page the bar's options
-- (the options window, embedded), then the modules by theme, each module's own pages under its theme
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local function shownText(text)
  for _, r in ipairs(M.regions) do
    if r._text == text and r:IsVisible() then return r end
  end
end
local function shownCheck(text)
  for _, f in ipairs(M.frames) do
    local t = f._kind == "CheckButton" and (f.Text or f.text)
    if t and t._text == text and f:IsVisible() then return f end
  end
end
local function shownButton(text)
  for _, f in ipairs(M.frames) do
    if f._kind == "Button" and f.GetText and f:GetText() == text and f:IsVisible() then return f end
  end
end

-- WoW Forever; every module turned off by hand (so none of them loads here)
GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false, dialogkey = false, xtolevel = false, minimapdrawer = false, mail = false, classicui = false,
  tullarange = false, names = false, tooltipanchor = false, idtip = false, soloraidframe = false, enemycasts = false, reverseengineering = false } }
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
-- a module's switches (as WeaponSwingTimer's would be when it runs)
local ranged = true
ns:SetQolSwitches("wst", {
  { label = "WST_SW_HUNTER", get = function() return ranged end, set = function(on) ranged = on end },
})
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("PLAYER_ENTERING_WORLD", true, false)

out("== its place in the list")
local top = ns.settingsCategory
check(top and top.name == " Clara" and top.parent == nil, "Clara: an AddOns entry whose name starts with a space, first of the list")
local children = {}
for _, c in ipairs(M.settingsCategories) do if c.parent == top then children[#children + 1] = c end end
local names = {}
for i, c in ipairs(children) do names[i] = c.name end
check(table.concat(names, ",") == "Clara Combo Points,Combat,Interface,Quests and progress,Economy and professions",
  "under it: Clara Combo Points (the bar) first, then the themes (" .. table.concat(names, ",") .. ")")
local scan = ns.scanCategory
check(scan and scan.parent == ns.qolThemes.quests, "UnitScan under Quests and progress")
for _, m in ipairs(ns.QOL_MODULES) do
  check(ns.qolThemes[m.theme] ~= nil and ns:QolCategory(m.key) == ns.qolThemes[m.theme], m.name .. ": on the " .. m.theme .. " page")
end

out("== Clara Combo Points: the options window, in the page")
local core = ns.coreCategory
check(core and core.parent == top and core.frame == ns.corePage, "its page")
M.ShowSettingsPage(core)
local panel = ClaraComboPointsOptions
check(panel and panel:IsShown() and panel:GetParent() == ns.corePage, "the window, held by the page")
check(not panel.NineSlice:IsShown() and not panel.CloseButton:IsShown() and not panel.grip:IsShown()
  and not panel.opacity:IsShown(), "without its frame, its corner, its opacity")
check(panel.detach and panel.detach:IsShown(), "a button to put it in its own window")
local special = false
for _, n in ipairs(UISpecialFrames) do if n == panel:GetName() then special = true end end
check(not special, "Esc closes the game's options, not the page's content")
check(panel:GetAlpha() == 1, "fully opaque there")
check(#panel.Tabs == 9, "the nine class tabs, no Improvements tab")
ns.corePage:Hide()
check(not panel:IsShown(), "the page closed: hidden with it")
M.ShowSettingsPage(core)
panel.detach:Click()
check(panel:IsShown() and panel:GetParent() == UIParent and panel.NineSlice:IsShown() and panel.grip:IsShown(),
  "its button: back in its own window, its frame again")
special = false
for _, n in ipairs(UISpecialFrames) do if n == panel:GetName() then special = true end end
check(special and not panel.detach:IsShown(), "Esc closes it again; no button there")
ns.corePage:Hide() -- (the game's options closed by the button: its page with them)
panel:Hide()
SlashCmdList.CLARACOMBOPOINTS("")
check(panel:IsShown() and panel:GetParent() == UIParent, "/cl: its own window")
M.ShowSettingsPage(core)
check(panel:GetParent() == ns.corePage, "the page again: taken back")
SlashCmdList.CLARACOMBOPOINTS("")
check(panel:IsShown() and panel:GetParent() == UIParent, "/cl while it is in the page: out in its window")
ns.corePage:Hide()
panel:Hide()

out("== a theme's page")
local economy = ns.qolThemes.economy
M.ShowSettingsPage(economy)
local page = ns.qolThemePages.economy
check(shownText("Economy and professions"), "its title")
for _, m in ipairs(ns.QOL_MODULES) do -- (the Light version: fewer)
  if m.theme == "economy" then check(page["check_" .. m.key] and page["check_" .. m.key]:IsVisible(), m.key .. ": listed") end
end
check(not page.check_wst, "only its theme's modules")
check(shownText("BuyEmAll") and shownText("Buy in bulk at merchants") == nil, "each by its name")
local box = page.check_buyemall
check(box and box:GetChecked() == false, "turned off: its box unticked")
check(shownText("Turned off."), "where it stands: turned off")
box:Click()
check(ns.sv.qol.buyemall == nil and ns:QolEnabled("buyemall"), "ticked: on, saved")
check(shownText("Turned on: from the next reload."), "from the next reload")
check(ns:QolState("buyemall") == "off", "not loaded midway")
check(page.open_buyemall and not page.open_buyemall:IsEnabled(), "its options: none while it does not run")
check(shownButton("Reload UI"), "a button to reload")
ns:SetQolEnabled("buyemall", false)

out("== switches, while the module runs")
local combat = ns.qolThemes.combat
local QolState = ns.QolState
ns.QolState = function(self, key) if key == "wst" then return "on" end return QolState(self, key) end
M.ShowSettingsPage(combat)
local cpage = ns.qolThemePages.combat
check(cpage.check_wst and cpage.check_wst:IsVisible(), "WeaponSwingTimer on the Combat page")
check(shownText("Swing timer bars: your main hand and off hand, your target's, and your ranged shots. By default, only the ranged bar, and only on hunters. Command: /wst."),
  "what it does")
ns.QolState = QolState

out("== another addon's page in the game's options, by its name")
M.openedCategory = nil
SettingsPanel.GetCategory = function(_, name) if name == "NodeSight" then return { GetID = function() return 77 end } end end
ns:OpenSettingsTo("NodeSight")
check(M.openedCategory == 77, "found and opened (standalone NodeSight)")
M.openedCategory = nil
local ok = pcall(ns.OpenSettingsTo, ns, "Nothing")
check(ok and M.openedCategory == nil, "not found: nothing opens, no error")
SettingsPanel.GetCategory = nil

out("== not WoW Forever")
GetBuildInfo = function() return "12.0.1", "1", "", 120001 end
ClaraComboPointsDB = nil
local ns2 = {}
M.LoadAddon(ADDON_DIR, ns2)
local allOff = #ns2.QOL_MODULES > 0
for _, m in ipairs(ns2.QOL_MODULES) do if ns2:QolState(m.key) ~= "unavailable" then allOff = false end end
check(allOff, "every module: unavailable")
check(ns2:QolStatusText(ns2.QOL_MODULES[1]) == "Only in World of Warcraft: Forever.", "says so")

out("")
out(fails .. " failure(s)")
