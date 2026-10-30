-- Clara Combo Points - Names' page in the game's options (Esc > Options > AddOns > Names), its own
-- entry: a box for each place surnames are hidden, and one's own name and surname over one's head
-- (the game's own settings, turned with them). The same boxes on its page of the options window's
-- its theme's page. Built the first time it is shown.

local ADDON, ns = ...
local L = ns.L

ns:SetQolOpener("names", function() ns:OpenSettingsTo(ns.namesCategory) end)

local N = ns.Names
if not N then return end -- (the module does not run)

-- The boxes: a place's surnames hidden, or one's own name / surname over one's head
local BOXES = {
  { label = "NAMES_TARGET", place = "target" },
  { label = "NAMES_FOCUS", place = "focus" },
  { label = "NAMES_PARTY", place = "party" },
  { label = "NAMES_PETS", place = "pets" },
  { label = "NAMES_TOOLTIP", place = "tooltip" },
  { label = "NAMES_PLATES", place = "plates" },
  { label = "NAMES_CHAT", place = "chat" },
  { label = "NAMES_OVERHEAD", place = "overhead" },
  { label = "NAMES_MY_SURNAME", own = "surname" },
  { label = "NAMES_MY_NAME", own = "name" },
}
local function Get(box)
  if box.place then return N.Hidden(box.place) end
  local name, surname = N.OwnHidden()
  if box.own == "name" then return name end
  return surname
end
local function Set(box, hide)
  if box.place then N.SetHidden(box.place, hide)
  elseif box.own == "name" then N.SetOwnName(hide)
  else N.SetOwnSurname(hide) end
end
-- The other players' surnames over their heads: only with a setting of the client's to turn off
local function Possible(box) return box.place ~= "overhead" or #N.OverheadSettings() > 0 end

local switches = {}
for _, box in ipairs(BOXES) do
  switches[#switches + 1] = { label = box.label, get = function() return Get(box) end, set = function(on) Set(box, on) end }
end
ns:SetQolSwitches("names", switches)

local page = CreateFrame("Frame") -- the game's options panel takes it in and sizes it
page:Hide()
local built
local updates = {}

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

local function Text(fontObject, y, x)
  local fs = page:CreateFontString(nil, "ARTWORK", fontObject)
  fs:SetPoint("TOPLEFT", x or 14, y)
  fs:SetPoint("RIGHT", -24, 0)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(true)
  return fs
end

local function Update()
  for _, fn in ipairs(updates) do fn() end
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText(L.NAMES_TITLE)
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = Text("GameFontHighlightSmall", -62)
  hint:SetTextColor(.6, .6, .65)
  hint:SetText(L.NAMES_HINT)

  local y = -100
  for i, box in ipairs(BOXES) do
    if i == 1 or box.own == "surname" then
      local header = Text("GameFontNormal", y - 4)
      header:SetText(box.own and L.NAMES_HEAD_OWN or L.NAMES_HEAD_HIDE)
      y = y - 26
    end
    local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", 10, y)
    local text = check.Text or check.text
    text:SetFontObject("GameFontHighlight")
    text:SetText(L[box.label])
    check:SetScript("OnClick", function(self)
      Click()
      Set(box, self:GetChecked() and true or false)
      Update()
      if ns.RefreshOptions then ns:RefreshOptions() end
    end)
    local note
    if box.place == "overhead" then
      note = Text("GameFontDisableSmall", y - 24, 40)
      y = y - 14
    end
    updates[#updates + 1] = function()
      local possible = Possible(box)
      check:SetChecked(possible and Get(box))
      check:SetEnabled(possible)
      if note then
        local found = N.OverheadSettings()
        note:SetText(#found > 0 and L.NAMES_OVERHEAD_FOUND:format(table.concat(found, ", ")) or L.NAMES_OVERHEAD_NONE)
      end
    end
    y = y - 28
  end

  -- ClassicUI's own "Hide last names" hides them all at once, over these boxes
  local classic = ns.ClassicUIPrivate
  if classic then
    local warn = Text("GameFontNormalSmall", y - 10)
    warn:SetTextColor(1, .5, .25)
    updates[#updates + 1] = function()
      local on = classic.db and classic.db.hideLastNames == true
      warn:SetText(on and L.NAMES_CLASSICUI or "")
    end
  end
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Update()
end)

-- The game's settings changed elsewhere (its own options, a box of its theme's page)
function ns.NamesChanged()
  if built and page:IsVisible() then Update() end
  if ns.RefreshOptions then ns:RefreshOptions() end
end

-- (under its theme's page of Clara Combo Points)
if Settings and Settings.RegisterCanvasLayoutSubcategory and ns:QolCategory("names") then
  local ok, category = pcall(Settings.RegisterCanvasLayoutSubcategory, ns:QolCategory("names"), page, "Names")
  if ok and category then ns.namesCategory = category end
end
ns.namesPage = page
