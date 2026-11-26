-- Clara Combo Points - its page in the game's options (Esc > Options > AddOns): the options
-- window brought back on the screen, everything locked, the window's size, a full reset, and
-- how the addon works. Built the first time it is shown.

local ADDON, ns = ...
local L = ns.L

local floor = math.floor

local page = CreateFrame("Frame") -- the game's options panel takes it in and sizes it
page:Hide()
local built
local labels, updates = {}, {} -- texts (again on a language change), states shown

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

local body -- what the page shows, in a scroll frame: the whole page scrolls when it is taller than the game's panel
local scroll

local function Button(key, w, onClick)
  local b = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  b:SetSize(w, 24)
  if key then labels[#labels + 1] = function() b:SetText(L[key]) end end
  b:SetScript("OnClick", function(self) Click(); onClick(self) end)
  return b
end

local function Text(fontObject, key)
  local fs = body:CreateFontString(nil, "ARTWORK", fontObject)
  fs:SetJustifyH("LEFT")
  if key then labels[#labels + 1] = function() fs:SetText(L[key]) end end
  return fs
end

-- Under the window's size, the rest one under the other: each row placed under the shown one before it (a row not
-- shown takes no room), its texts wrapped in the page's width, its height theirs (Layout).
local TOP = 166 -- (where the rows start: under the window's size)
local rows = {}
local function Row(region, x, height, shown, gap)
  rows[#rows + 1] = { region = region, x = x, height = height, shown = shown, gap = gap or 0 }
end

local function Layout()
  if not body then return end
  local w = scroll:GetWidth()
  if not w or w <= 0 then w = 600 end
  body:SetWidth(w)
  local y = -TOP
  for _, r in ipairs(rows) do
    local on = r.shown == nil or r.shown() and true or false
    r.region:SetShown(on)
    if on then
      y = y - r.gap
      r.region:ClearAllPoints()
      r.region:SetPoint("TOPLEFT", body, "TOPLEFT", r.x, y)
      y = y - r.height(w - r.x)
    end
  end
  body:SetHeight(-y + 12)
end

-- A text row: wrapped in the page's width
local function TextRow(fs, x, gap)
  fs:SetWordWrap(true)
  Row(fs, x, function(w)
    fs:SetWidth(w - 14)
    return math.ceil(fs:GetStringHeight() or 12) + 4
  end, nil, gap)
end

-- A box and its words beside it, wrapped in the page's width (their first line beside the box)
local function Check(key, get, set, field, shown)
  local check = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  local text = check.Text or check.text
  text:ClearAllPoints()
  text:SetPoint("TOPLEFT", check, "TOPRIGHT", 0, -7)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(true)
  labels[#labels + 1] = function() text:SetText(L[key]) end
  check:SetScript("OnClick", function(self)
    Click()
    set(ns, self:GetChecked() and true or false)
  end)
  updates[#updates + 1] = function() check:SetChecked(get(ns)) end
  if field then page[field] = check end
  Row(check, 10, function(w)
    text:SetWidth(w - 40)
    return math.max(24, math.ceil(text:GetStringHeight() or 12) + 10)
  end, shown)
  return check
end

local function Update()
  for _, fn in ipairs(labels) do fn() end
  for _, fn in ipairs(updates) do fn() end
  Layout()
end

-- The options window (the game's options closed first, out of combat: they would cover it).
local function OpenOptions()
  if SettingsPanel and SettingsPanel:IsShown() and not InCombatLockdown() then SettingsPanel:Close(true) end
  ns:ShowOptions()
end

local function Build()
  built = true
  scroll = CreateFrame("ScrollFrame", "ClaraComboPointsSettingsScroll", page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  body = CreateFrame("Frame", nil, scroll)
  body:SetSize(600, 10)
  scroll:SetScrollChild(body)
  page.body = body

  local title = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText("Clara")
  local version = body:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
  version:SetText("v" .. ns.VERSION)
  local rule = body:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)

  -- First: the options window back in the middle of the screen, if it was left off it.
  local resetPos = Button("SP_RESET_POS", 270, function()
    ns:ResetWindowPosition()
  end)
  resetPos:SetPoint("TOPLEFT", 10, -66)
  Button("SP_OPEN", 220, OpenOptions):SetPoint("LEFT", resetPos, "RIGHT", 12, 0)

  local lock = Button(nil, 270, function()
    if ns:AllLocked() then ns:SetLocked(false) else ns:LockAll() end
    Update()
  end)
  lock:SetPoint("TOPLEFT", 10, -98)
  updates[#updates + 1] = function() lock:SetText(ns:AllLocked() and L.SP_UNLOCK or L.SP_LOCK_ALL) end
  Button("SP_RESET_ADDON", 220, function() ns:AskResetAddon() end):SetPoint("LEFT", lock, "RIGHT", 12, 0)

  -- The options window's size, as its bottom right corner sets it
  local sizeLabel = Text("GameFontNormal", "SP_WINDOW_SIZE")
  sizeLabel:SetPoint("TOPLEFT", 14, -142)
  local slider = CreateFrame("Slider", nil, body, "UISliderTemplate")
  slider:SetSize(200, 17)
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(ns.MIN_WINDOW_SCALE * 100, ns.MAX_WINDOW_SCALE * 100)
  slider:SetValueStep(5)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:SetPoint("LEFT", body, "TOPLEFT", 250, -149)
  local value = Text("GameFontHighlightSmall")
  value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
  slider:SetScript("OnValueChanged", function(self, v)
    v = floor(v / 5 + .5) * 5
    value:SetText(v .. " %")
    if not self.silent then ns:SetWindowScale(v / 100) end
  end)
  local defaultSize = Button("SP_DEFAULT_SIZE", 150, function()
    ns:SetWindowScale(nil)
    Update()
  end)
  defaultSize:SetPoint("LEFT", slider, "RIGHT", 60, 0)
  updates[#updates + 1] = function()
    local v = floor(ns:GetWindowScale() * 100 + .5)
    slider.silent = true
    slider:SetValue(v)
    slider.silent = false
    value:SetText(v .. " %")
  end
  local hint = Text("GameFontHighlightSmall", "SP_HINT")
  hint:SetTextColor(.6, .6, .65)
  TextRow(hint, 14)

  -- What the addon adds to the portrait's right-click menu, each part shown or not
  TextRow(Text("GameFontNormal", "SP_MENU"), 14, 10)
  local function MenuCheck(key, field)
    Check(key, function() return ns.sv.menu[field] ~= false end, function(_, on)
      ns:SetMenuOption(field, on) -- (the options window's Visibility page too)
    end)
  end
  MenuCheck("SP_MENU_LINE", "line")
  MenuCheck("SP_MENU_RELOAD", "reload")

  -- The chat quiet while logging in: the addons' messages of the first 10 seconds taken out
  Check("SP_QUIET_LOGIN", ns.QuietLogin, ns.SetQuietLogin, "quietLogin")
  -- /who by first name or surname (Who.lua)
  Check("SP_WHO_NAMES", ns.WhoNames, ns.SetWhoNames, "whoNames")
  -- The game's icon in the taskbar not flashing (GameFixes.lua)
  Check("SP_NO_BLINK", ns.NoBlink, ns.SetNoBlink, "noBlink")
  -- The threat percent over the game's target and focus frames (UnitBoxes.lua)
  Check("SP_THREAT_BOX", ns.ThreatBox, ns.SetThreatBox, "threatBox")
  -- Alt + left click in the bags: Disenchant (Disenchant.lua)
  Check("SP_DISENCHANT", ns.DisenchantClick, ns.SetDisenchantClick, "disenchant")

  -- Fishing mode, and how much louder its sound effects (FishingMode.lua); the module off, or Easy Fishing runs: not
  -- here (no room taken)
  local function Fishing() return ns:QolRuns("fishing") end
  Check("SP_FISHING_MODE", ns.FishingMode, ns.SetFishingMode, "fishingMode", Fishing)
  local boostRow = CreateFrame("Frame", nil, body)
  boostRow:SetSize(400, 30)
  local boostLabel = boostRow:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  boostLabel:SetPoint("TOPLEFT", 0, -6)
  labels[#labels + 1] = function() boostLabel:SetText(L.SP_FISHING_BOOST) end
  local boost = CreateFrame("Slider", nil, boostRow, "UISliderTemplate")
  boost:SetSize(200, 17)
  boost:SetOrientation("HORIZONTAL")
  boost:SetMinMaxValues(1, ns.FISHING_BOOST_MAX)
  boost:SetValueStep(1)
  if boost.SetObeyStepOnDrag then boost:SetObeyStepOnDrag(true) end
  boost:SetPoint("LEFT", boostRow, "TOPLEFT", 210, -13)
  local boostValue = boostRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  boostValue:SetPoint("LEFT", boost, "RIGHT", 8, 0)
  boost:SetScript("OnValueChanged", function(self, v)
    v = floor(v + .5)
    boostValue:SetText("×" .. v)
    if not self.silent then ns:SetFishingBoost(v) end
  end)
  updates[#updates + 1] = function()
    boost.silent = true
    boost:SetValue(ns:FishingBoost())
    boost.silent = false
    boostValue:SetText("×" .. ns:FishingBoost())
  end
  Row(boostRow, 40, function() return 34 end, Fishing)
  page.fishingBoost = boost

  -- More boxes, one under the other: the Interact Key's icons (InteractKey.lua); without Leatrix
  -- Plus (its Interface page has them otherwise), quest progress on nameplates (QuestPlates.lua)
  -- and the zone in the group finder (GroupFinderZone.lua)
  local function Box(key, get, set, field) Check(key, get, set, field) end
  Box("SP_INTERACT_ICONS", ns.InteractIcons, ns.SetInteractIcons, "interactIcons")
  Box("SP_LEVEL_SHOTS", ns.LevelShots, ns.SetLevelShots, "levelShots")
  Box("SP_BOSS_SHOTS", ns.BossShots, ns.SetBossShots, "bossShots")
  Box("SP_MUTE_CONDUCT", ns.MuteConduct, ns.SetMuteConduct, "muteConduct") -- (QuietLogin.lua)
  Box("SP_CHAT_FOCUS", ns.ChatKeepsFocus, ns.SetChatKeepsFocus, "chatFocus") -- (ChatFocus.lua)
  Box("SP_COMMUNITY_CHAT", ns.CommunityChat, ns.SetCommunityChat, "communityChat") -- (CommunityChat.lua)
  Box("SP_MAIL_SUBJECT", ns.MailSubject, ns.SetMailSubject, "mailSubject") -- (MailSubject.lua)
  Box("SP_QUEST_SHARE_BUBBLE", ns.QuestShareBubble, ns.SetQuestShareBubble, "questShareBubble") -- (QuestShare.lua)
  Box("SP_SIT_KEY", ns.SitKey, ns.SetSitKey, "sitKey") -- (SitKey.lua)
  Box("SP_LEGACY_TREE", ns.LegacyTree, ns.SetLegacyTree, "legacyTree") -- (LegacyTree.lua)
  if not ns:QolRuns("leatrix") then
    Box("QUEST_PLATES", ns.QuestPlates, ns.SetQuestPlates, "questPlates")
    Box("LFG_ZONE", ns.GroupFinderZone, ns.SetGroupFinderZone, "groupFinderZone")
  end

  -- How the addon works: its text in a framed box, the page scrolling over it
  TextRow(Text("GameFontNormalLarge", "SP_HOW"), 14, 12)
  local box = CreateFrame("Frame", nil, body, "InsetFrameTemplate")
  local readme = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  readme:SetPoint("TOPLEFT", 10, -8)
  readme:SetJustifyH("LEFT")
  if readme.SetJustifyV then readme:SetJustifyV("TOP") end
  if readme.SetSpacing then readme:SetSpacing(3) end
  readme:SetWordWrap(true)
  labels[#labels + 1] = function() readme:SetText(L.SP_README) end
  Row(box, 10, function(w)
    box:SetWidth(w - 10)
    readme:SetWidth(w - 34)
    local h = math.ceil(readme:GetStringHeight() or 0) + 18
    box:SetHeight(h)
    return h
  end, nil, 6)
  page.readme = readme

  scroll:SetScript("OnSizeChanged", Layout)
end

-- Shown by the game's options panel (each time it opens, and when the page is picked).
function page:OnRefresh()
  if not ns.sv then return end
  if not built then Build() end
  Update()
end

function ns:RefreshSettingsPage()
  if built and page:IsVisible() then Update() end
end

-- Registered as the addon loads, so the AddOns tab lists it from the first opening on: "Clara", its name
-- starting with a space (the game lists the addons by name, and a space comes before every letter and
-- "!": the first of the list). Under it, first, Clara Combo Points (the bar's own options: the options
-- window, Options.lua), then the modules' pages by theme (QoL.lua).
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, page, " Clara")
  if ok and category then
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
    if Settings.RegisterCanvasLayoutSubcategory and ns.CorePage then
      local ok2, core = pcall(Settings.RegisterCanvasLayoutSubcategory, category, ns.CorePage(), "Clara Combo Points")
      if ok2 and core then ns.coreCategory = core end
    end
  end
end
