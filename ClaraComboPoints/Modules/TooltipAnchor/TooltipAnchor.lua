-- Clara Combo Points - Tooltip Anchor: where the tooltips the game puts in its corner open (those
-- of the world's units and of the frames that leave it to the game: GameTooltip_SetDefaultAnchor):
-- in the game's place, at the mouse (following it), or at an anchor one moves. The tooltip is held
-- by the corner one picks: its bottom right one by default, or top right, bottom left, top left.
-- The anchor ("Tooltip Anchor", dragged, a cross to put it away) in ClassicUI's art while ClassicUI
-- runs, the game's otherwise; shown or put away (unlocked, locked) by a button on its page or
-- /tiptac anchor, its option left as it is. Its bottom is the tooltip's health bar's when one shows
-- (a unit's), else the tooltip's own. The tooltips of the buttons by the bags (the micro menu, the
-- latency, the keyring, the bags and the backpack), which the game puts by their button, go there
-- too. Its page in Esc > Options > AddOns > Clara Combo Points, its theme's page, its boxes on its
-- theme's page. Saved in ClaraTooltipAnchorDB, for the account.

local ADDON, ns = ...
local L = ns.L

local MODES = { "game", "cursor", "anchor" }
local CORNERS = { "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMLEFT", "TOPLEFT" }
-- the tooltip's corner a little off the mouse, clear of its arrow (which points down and right)
local CURSOR_GAP = { BOTTOMRIGHT = { -4, 4 }, TOPRIGHT = { -4, -4 }, BOTTOMLEFT = { 4, 4 }, TOPLEFT = { 18, -24 } }

local function Has(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

local db
local function Load()
  if type(ClaraTooltipAnchorDB) ~= "table" then ClaraTooltipAnchorDB = {} end
  db = ClaraTooltipAnchorDB
  if not Has(MODES, db.mode) then db.mode = "cursor" end
  if not Has(CORNERS, db.corner) then db.corner = "BOTTOMRIGHT" end
  if type(db.x) ~= "number" or type(db.y) ~= "number" then db.x, db.y = nil, nil end
end

local runs = ns:QolRuns("tooltipanchor")
-- Leatrix Plus's own cursor anchor stays off while this places the tooltips
function ns.TooltipAnchorActive() return runs and db ~= nil and db.mode ~= "game" end

ns:SetQolOpener("tooltipanchor", function() ns:OpenSettingsTo(ns.tooltipAnchorCategory) end)
if not runs then return end
Load()

---------------------------------------------------------------------------
-- The anchor
---------------------------------------------------------------------------
local anchor = CreateFrame("Frame", "ClaraTooltipAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(140, 30)
anchor:SetFrameStrata("DIALOG")
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:Hide()
if anchor.SetBackdrop then
  anchor:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  anchor:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
  anchor:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
end
anchor.text = anchor:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
anchor.text:SetPoint("LEFT", 10, 0)
anchor.text:SetText("Tooltip Anchor")

-- Its cross: ClassicUI's (its close buttons' art, in its theme) while it runs, the game's otherwise;
-- made at login, ClassicUI's files being loaded by then
local function MakeClose()
  local close
  local classic = ns.ClassicUIRuns and ns.ClassicUIPrivate
  if classic and classic.SetTex then
    close = CreateFrame("Button", nil, anchor)
    for _, part in ipairs({ { "SetNormalTexture", "closeUp" }, { "SetPushedTexture", "closeDown" },
      { "SetHighlightTexture", "closeHighlight" } }) do
      local tex = close:CreateTexture(nil, part[1] == "SetHighlightTexture" and "HIGHLIGHT" or "ARTWORK")
      tex:SetAllPoints()
      classic.SetTex(tex, part[2])
      close[part[1]](close, tex)
    end
  else
    close = CreateFrame("Button", nil, anchor, "UIPanelCloseButton")
  end
  close:SetSize(24, 24)
  close:SetPoint("RIGHT", -3, 0)
  close:SetScript("OnClick", function() anchor:Hide() end)
  anchor:SetWidth(math.max(140, (anchor.text:GetStringWidth() or 100) + 46))
end

local function PlaceAnchor()
  anchor:ClearAllPoints()
  if db.x and db.y then
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
  else
    anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -110, 130) -- (about where the game puts them)
  end
end
anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
anchor:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local left, bottom = self:GetLeft(), self:GetBottom()
  if left and bottom then
    db.x, db.y = math.floor(left + 0.5), math.floor(bottom + 0.5)
  end
  PlaceAnchor()
end)

---------------------------------------------------------------------------
-- The tooltips
---------------------------------------------------------------------------
local following -- the tooltip held at the mouse, and its owner
local followOwner
local follower = CreateFrame("Frame")
follower:Hide()

local function AtCursor(tooltip)
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  local gap = CURSOR_GAP[db.corner]
  tooltip:ClearAllPoints()
  tooltip:SetPoint(db.corner, UIParent, "BOTTOMLEFT", x / scale + gap[1], y / scale + gap[2])
end

follower:SetScript("OnUpdate", function(self)
  local tooltip = following
  if not (tooltip and tooltip:IsShown() and tooltip:GetOwner() == followOwner) or db.mode ~= "cursor" then
    following, followOwner = nil, nil
    self:Hide()
    return
  end
  AtCursor(tooltip)
end)

-- The tooltip's health bar under it (a unit's): the anchor holds its bottom rather than the tooltip's
local function BarBelow(tooltip)
  local bar = tooltip == GameTooltip and GameTooltipStatusBar
  if not (bar and bar:IsShown() and bar.GetPoint) then return 0 end
  local point, rel, relPoint, _, y = bar:GetPoint(1)
  if rel ~= tooltip or not (point and point:find("^TOP") and relPoint and relPoint:find("^BOTTOM")) then return 0 end
  return math.max(0, -(y or 0)) + (bar:GetHeight() or 0)
end

local held -- the tooltip held at the anchor now
local function AtAnchor(tooltip)
  local lift = db.corner:find("^BOTTOM") and BarBelow(tooltip) or 0
  tooltip:ClearAllPoints()
  tooltip:SetPoint(db.corner, anchor, db.corner, 0, lift)
  held = tooltip
end

local function OnDefaultAnchor(tooltip, parent)
  if not (tooltip and db) or db.mode == "game" then return end
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  if db.mode == "cursor" then
    AtCursor(tooltip)
    if tooltip == GameTooltip then
      following, followOwner = tooltip, parent
      follower:Show()
    end
  else
    AtAnchor(tooltip)
  end
end

-- The health bar shown or hidden once the tooltip is filled: the tooltip held at the anchor moved with it
local function BarChanged()
  if db and db.mode == "anchor" and held == GameTooltip and GameTooltip:IsShown() then AtAnchor(GameTooltip) end
end

-- The buttons by the bags, whose tooltips the game puts by them: theirs follow the mode too
local BAG_BUTTONS = { "^CharacterBag%dSlot$", "^MainMenuBarBackpackButton$", "^KeyRingButton$", "^CharacterReagentBag%dSlot$",
  "MicroButton$", "Latency", "PerformanceBar" }
function ns.TooltipAnchorTakes(owner)
  local name = owner and owner.GetName and owner:GetName()
  if type(name) ~= "string" then return false end
  for _, pattern in ipairs(BAG_BUTTONS) do if name:find(pattern) then return true end end
  return false
end

local function OnSetOwner(tooltip, owner)
  if not (db and db.mode ~= "game" and ns.TooltipAnchorTakes(owner)) then return end
  if tooltip.IsForbidden and tooltip:IsForbidden() then return end
  if tooltip.SetAnchorType then tooltip:SetAnchorType("ANCHOR_NONE") end
  OnDefaultAnchor(tooltip, owner)
end

local function SetMode(mode)
  db.mode = mode
  if mode == "anchor" and not anchor:IsShown() and not (db.x and db.y) then anchor:Show() end
  if mode ~= "anchor" then anchor:Hide() end
end

-- Unlocked: the anchor shown, to be moved; locked: put away. Its option left as it is.
local function ToggleAnchor()
  if anchor:IsShown() then
    anchor:Hide()
  else
    PlaceAnchor()
    anchor:Show()
  end
  return anchor:IsShown()
end

ns.TooltipAnchor = {
  MODES = MODES, CORNERS = CORNERS, frame = anchor,
  Mode = function() return db.mode end,
  SetMode = SetMode,
  Corner = function() return db.corner end,
  SetCorner = function(corner) if Has(CORNERS, corner) then db.corner = corner end end,
  ShowAnchor = function() PlaceAnchor(); anchor:Show() end,
  ToggleAnchor = ToggleAnchor,
}

-- /tiptac anchor: the anchor shown or put away (anything else: TipTac's own command, if it is there)
local tiptacOwn = SlashCmdList and SlashCmdList.TIPTAC
SLASH_CLARATIPTAC1 = "/tiptac"
SlashCmdList.CLARATIPTAC = function(msg)
  local word = (msg or ""):match("^%s*(%S*)"):lower()
  if word == "anchor" or word == "ancre" or word == "anker" then
    ToggleAnchor()
  elseif tiptacOwn then
    tiptacOwn(msg)
  else
    ns.Print(L.TA_COMMAND)
  end
end

ns:SetQolSwitches("tooltipanchor", {
  { label = "TA_SW_CURSOR", get = function() return db.mode == "cursor" end,
    set = function(on) SetMode(on and "cursor" or "game") end },
  { label = "TA_SW_ANCHOR", get = function() return db.mode == "anchor" end,
    set = function(on) SetMode(on and "anchor" or "game"); if on then PlaceAnchor(); anchor:Show() end end },
})

---------------------------------------------------------------------------
-- Its page: under its theme's page in Clara Combo Points' options
---------------------------------------------------------------------------
local page = CreateFrame("Frame")
page:Hide()
local built
local updates = {}

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end

local function Update() for _, fn in ipairs(updates) do fn() end end

local function Radio(label, y, get, set)
  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetPoint("TOPLEFT", 10, y)
  local text = check.Text or check.text
  text:SetFontObject("GameFontHighlight")
  text:SetText(label)
  check:SetScript("OnClick", function()
    Click()
    set()
    Update()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)
  updates[#updates + 1] = function() check:SetChecked(get()) end
  return check
end

local function Header(text, y)
  local fs = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetPoint("TOPLEFT", 14, y)
  fs:SetText(text)
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText("Tooltip Anchor")
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 14, -62)
  hint:SetPoint("RIGHT", -24, 0)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetTextColor(.6, .6, .65)
  hint:SetText(L.TA_HINT)

  Header(L.TA_HEAD_WHERE, -100)
  local y = -122
  for _, mode in ipairs(MODES) do
    Radio(L["TA_MODE_" .. mode:upper()], y, function() return db.mode == mode end, function() SetMode(mode) end)
    y = y - 26
  end
  -- unlock: the anchor shown, to be moved; lock: put away (the option above left as it is)
  local move = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  move:SetSize(260, 22)
  move:SetPoint("TOPLEFT", 40, y - 2)
  move:SetScript("OnClick", function()
    Click()
    ToggleAnchor()
    Update()
  end)
  updates[#updates + 1] = function() move:SetText(anchor:IsShown() and L.TA_LOCK or L.TA_UNLOCK) end
  anchor:HookScript("OnShow", Update)
  anchor:HookScript("OnHide", Update)
  local command = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  command:SetPoint("LEFT", move, "RIGHT", 10, 0)
  command:SetTextColor(.6, .6, .65)
  command:SetText("/tiptac anchor")
  y = y - 40
  Header(L.TA_HEAD_CORNER, y)
  y = y - 22
  for _, corner in ipairs(CORNERS) do
    Radio(L["TA_CORNER_" .. corner], y, function() return db.corner == corner end, function() db.corner = corner end)
    y = y - 26
  end
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Update()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local ok, category = pcall(function()
    if ns:QolCategory("tooltipanchor") and Settings.RegisterCanvasLayoutSubcategory then
      return Settings.RegisterCanvasLayoutSubcategory(ns:QolCategory("tooltipanchor"), page, "Tooltip Anchor")
    end
    local c = Settings.RegisterCanvasLayoutCategory(page, "Tooltip Anchor")
    Settings.RegisterAddOnCategory(c)
    return c
  end)
  if ok and category then ns.tooltipAnchorCategory = category end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  MakeClose()
  PlaceAnchor()
  if type(GameTooltip_SetDefaultAnchor) == "function" then hooksecurefunc("GameTooltip_SetDefaultAnchor", OnDefaultAnchor) end
  if GameTooltip and GameTooltip.SetOwner then hooksecurefunc(GameTooltip, "SetOwner", OnSetOwner) end
  if GameTooltipStatusBar and GameTooltipStatusBar.HookScript then
    GameTooltipStatusBar:HookScript("OnShow", BarChanged)
    GameTooltipStatusBar:HookScript("OnHide", BarChanged)
  end
  if GameTooltip and GameTooltip.HookScript then GameTooltip:HookScript("OnHide", function() held = nil end) end
end)
