-- Clara Combo Points - Reverse Engineering, what shows under a recipe's reagents (in the game's
-- professions window and in ClassicUI's), as picked in its options:
--   with icons: "Subcomponents", each reagent a profession makes, in turn: its icon and how many the
--   bags make now, what it needs (tools), then its own reagents, lit when the bags hold enough, grey
--   otherwise; a chest on a reagent the bank (or another of the account's characters) holds, its
--   tooltip saying how many and who;
--   as text, as the addon Reverse Engineering lists it: every material down to the raw ones ("Raw
--   Materials Needed for"), or the tree of them ("Materials for"), a button at the top right switching.
-- Also its options page (under Interface improvements), its switches in the Improvements tab and the
-- entries of the professions windows' filter menus.

local ADDON, ns = ...
local L = ns.L
local C = ns.Craft
if not C then return end

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local BANKER = "Interface\\Minimap\\Tracking\\Banker"
local PLATE = "Interface\\QuestFrame\\UI-QuestItemNameFrame"
local DIVIDER = "Interface\\Common\\UI-TooltipDivider-Transparent"
local ICON, REAGENT_W, REAGENT_H, PITCH = 37, 147, 36, 39
local LINE_INDENT = 16

local function Icon(id)
  if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(id) end
  return GetItemIcon and GetItemIcon(id)
end

local function Link(id)
  local _, link = (C_Item and C_Item.GetItemInfo or GetItemInfo)(id)
  return link
end

local function ItemTip(self)
  if not self.itemID then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(self.itemID)
  GameTooltip:Show()
end

local function ItemClick(self)
  if not self.itemID or not (IsModifiedClick and IsModifiedClick()) then return end
  local link = Link(self.itemID)
  if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
end

---------------------------------------------------------------------------
-- The chest: in the bank, or on another of the account's characters
---------------------------------------------------------------------------
local function ClassColored(name, class)
  local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  return color and color.WrapTextInColorCode and color:WrapTextInColorCode(name) or name
end

local function ChestTip(self)
  local id = self.itemID
  if not id then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(C.ItemName(id) or ("item:" .. id), 1, 1, 1)
  local bank, account = C.Bank(id), C.AccountBank(id)
  GameTooltip:AddDoubleLine(L.CRAFT_TIP_BAGS, C.Bags(id), 1, .82, 0, 1, 1, 1)
  GameTooltip:AddDoubleLine(L.CRAFT_TIP_BANK, bank, 1, .82, 0, 1, 1, 1)
  if account > 0 then GameTooltip:AddDoubleLine(L.CRAFT_TIP_ACCOUNT, account, 1, .82, 0, 1, 1, 1) end
  local others = C.Others(id)
  if #others > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.CRAFT_TIP_OTHERS, 1, .82, 0)
    for _, o in ipairs(others) do
      local parts = {}
      if o.bags > 0 then parts[#parts + 1] = L.CRAFT_TIP_IN_BAGS:format(o.bags) end
      if o.bank > 0 then parts[#parts + 1] = L.CRAFT_TIP_IN_BANK:format(o.bank) end
      if o.mail > 0 then parts[#parts + 1] = L.CRAFT_TIP_IN_MAIL:format(o.mail) end
      GameTooltip:AddDoubleLine(ClassColored(o.name, o.class), o.total .. "  |cff999999(" .. table.concat(parts, ", ") .. ")|r",
        1, 1, 1, 1, 1, 1)
    end
  end
  GameTooltip:Show()
end

-- A chest on a reagent's icon: lit when the bank holds some, grey when only another character does
function C.MarkChest(owner, id, anchor)
  local chest = owner.claraChest
  local bank = id and C.Option("chest") and (C.Bank(id) + C.AccountBank(id)) or 0
  local others = id and C.Option("chest") and bank == 0 and #C.Others(id) > 0
  if bank == 0 and not others then
    if chest then chest:Hide() end
    return
  end
  if not chest then
    chest = CreateFrame("Button", nil, owner)
    chest:SetSize(16, 16)
    chest.icon = chest:CreateTexture(nil, "OVERLAY")
    chest.icon:SetAllPoints()
    chest.icon:SetTexture(BANKER)
    chest:SetScript("OnEnter", ChestTip)
    chest:SetScript("OnLeave", GameTooltip_Hide)
    owner.claraChest = chest
  end
  chest:SetFrameLevel(owner:GetFrameLevel() + 5)
  chest:ClearAllPoints()
  chest:SetPoint("CENTER", anchor or owner, "TOPRIGHT", -2, -2)
  chest.itemID = id
  chest.icon:SetDesaturated(others and true or false)
  chest.icon:SetAlpha(others and .75 or 1)
  chest:Show()
end

---------------------------------------------------------------------------
-- With icons: the subcomponents
---------------------------------------------------------------------------
local function NewHeader(parent)
  local h = CreateFrame("Button", nil, parent)
  h:SetSize(ICON, ICON)
  h.icon = h:CreateTexture(nil, "ARTWORK")
  h.icon:SetAllPoints()
  h.count = h:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  h.count:SetPoint("BOTTOMRIGHT", -2, 2)
  h.name = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  h.name:SetPoint("TOPLEFT", h, "TOPRIGHT", 6, -1)
  h.name:SetJustifyH("LEFT")
  h.name:SetWordWrap(false)
  h.sub = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  h.sub:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -2)
  h.sub:SetJustifyH("LEFT")
  h.sub:SetWordWrap(true)
  h.label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  h.label:SetText(SPELL_REAGENTS or "Reagents:")
  h:SetScript("OnEnter", ItemTip)
  h:SetScript("OnLeave", GameTooltip_Hide)
  h:SetScript("OnClick", ItemClick)
  return h
end

local function NewReagent(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(REAGENT_W, REAGENT_H)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(REAGENT_H - 2, REAGENT_H - 2)
  b.icon:SetPoint("LEFT")
  local plate = b:CreateTexture(nil, "BACKGROUND")
  plate:SetTexture(PLATE)
  plate:SetSize(118, 58)
  plate:SetPoint("LEFT", b.icon, "RIGHT", -8, 0)
  b.plate = plate
  b.name = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  b.name:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
  b.name:SetSize(REAGENT_W - REAGENT_H - 8, REAGENT_H - 6)
  b.name:SetJustifyH("LEFT")
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", -1, 1)
  b:SetScript("OnEnter", ItemTip)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", ItemClick)
  return b
end

local function Pool(make)
  local pool = { used = 0, items = {} }
  function pool:Get(parent)
    self.used = self.used + 1
    local item = self.items[self.used]
    if not item then
      item = make(parent)
      self.items[self.used] = item
    end
    return item
  end
  function pool:HideRest()
    for i = self.used + 1, #self.items do
      local item = self.items[i]
      item:Hide()
      if item.name and item.name.Hide and item.sub then item.name:Hide(); item.sub:Hide(); item.label:Hide() end
    end
  end
  return pool
end

-- The crafted reagents of a recipe, deepest last: { { item, recipe, need }, ... }, each once
local function Subs(recipeID)
  local out, seen = {}, { [recipeID] = true }
  local function Walk(id, depth)
    for _, reagent in ipairs(C.Reagents(id)) do
      local sub = C.RecipeFor(reagent[1])
      if sub and not seen[sub] and depth < 8 then
        seen[sub] = true
        out[#out + 1] = { item = reagent[1], recipe = sub }
        Walk(sub, depth + 1)
      end
    end
  end
  Walk(recipeID, 0)
  return out
end
C.Subs = Subs

local function LayIcons(p, recipeID, width)
  local f = p.frame
  local headers, reagents, lines = p.headers, p.reagents, p.lines
  headers.used, reagents.used, lines.used = 0, 0, 0
  local subs = Subs(recipeID)
  if #subs == 0 then
    headers:HideRest(); reagents:HideRest(); lines:HideRest()
    p.title:Hide()
    return 0
  end
  local y = 0
  local function Divider()
    local line = lines:Get(f)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 0, y)
    line:SetPoint("TOPRIGHT", 0, y)
    line:Show()
    y = y - 6
  end
  Divider()
  p.title:ClearAllPoints()
  p.title:SetPoint("TOPLEFT", 2, y)
  p.title:Show()
  y = y - 16
  local cols = max(1, floor((width + 4) / (REAGENT_W + 4)))
  local chest = C.Option("chest")
  for _, s in ipairs(subs) do
    Divider()
    local h = headers:Get(f)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", 2, y)
    h.itemID = C.Recipe(s.recipe) and C.Recipe(s.recipe).o or s.item
    h.icon:SetTexture(Icon(h.itemID))
    local made = C.Craftable(s.recipe)
    h.count:SetText(made > 0 and made or "")
    h.icon:SetDesaturated(made == 0)
    h.name:SetText(C.ItemName(h.itemID) or "")
    h.name:SetWidth(width - ICON - 12)
    if made > 0 then h.name:SetTextColor(1, .82, 0) else h.name:SetTextColor(.6, .6, .6) end
    local r = C.Recipe(s.recipe)
    local names, profession, mineToo = C.KnownBy(s.recipe)
    local sub = r and r.q and ((REQUIRES_LABEL or "Requires:") .. " " .. r.q) or ""
    if names and not mineToo and #names > 0 then
      sub = (sub ~= "" and sub .. "\n" or "") .. "|cff999999" .. (profession and (profession .. " : ") or "") .. table.concat(names, ", ") .. "|r"
    end
    h.sub:SetText(sub)
    h.sub:SetWidth(width - ICON - 12)
    h:Show(); h.name:Show(); h.sub:SetShown(sub ~= "")
    y = y - max(ICON, 16 + (sub ~= "" and h.sub:GetStringHeight() + 2 or 0)) - 4
    h.label:ClearAllPoints()
    h.label:SetPoint("TOPLEFT", f, "TOPLEFT", 2, y)
    h.label:Show()
    y = y - 14
    local list = C.Reagents(s.recipe)
    for i, reagent in ipairs(list) do
      local b = reagents:Get(f)
      local col, row = (i - 1) % cols, floor((i - 1) / cols)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", f, "TOPLEFT", 2 + col * (REAGENT_W + 4), y - row * PITCH)
      b.itemID = reagent[1]
      local have = C.Bags(reagent[1])
      b.icon:SetTexture(Icon(reagent[1]))
      b.name:SetText(C.ItemName(reagent[1]) or "")
      b.count:SetText(have .. "/" .. reagent[2])
      local enough = have >= reagent[2]
      b.icon:SetDesaturated(not enough)
      if enough then b.name:SetTextColor(1, 1, 1) else b.name:SetTextColor(.5, .5, .5) end
      b.plate:SetAlpha(enough and 1 or .6)
      if chest then C.MarkChest(b, reagent[1], b.icon) elseif b.claraChest then b.claraChest:Hide() end
      b:Show()
    end
    y = y - ceil(#list / cols) * PITCH - 2
  end
  headers:HideRest(); reagents:HideRest(); lines:HideRest()
  return -y + 4
end

---------------------------------------------------------------------------
-- As text: as Reverse Engineering lists it
---------------------------------------------------------------------------
local function Tree(recipeID, crafts, depth, path)
  local leaves, crafted = {}, {}
  for _, reagent in ipairs(C.Reagents(recipeID)) do
    local node = { id = reagent[1], need = reagent[2] * crafts, depth = depth, children = {} }
    local sub = C.RecipeFor(reagent[1])
    if sub and not path[sub] and depth < 8 then
      local r = C.Recipe(sub)
      path[sub] = true
      node.children = Tree(sub, ceil(node.need / (r and r.m or 1)), depth + 1, path)
      path[sub] = nil
      node.crafted = #node.children > 0
    end
    table.insert(node.crafted and crafted or leaves, node)
  end
  for _, node in ipairs(crafted) do leaves[#leaves + 1] = node end
  return leaves
end
C.Tree = Tree

local function Line(node, have, covered, crafted)
  local need = ceil(node.need)
  local done = have + (covered or 0) >= node.need - 0.001
  local name, count
  if done then name, count = "|cff00ff00", "|cff00ff00"
  elseif crafted then name, count = "|cff6cb6ff", "|cff6cb6ff"
  else name, count = "|cffffffff", "|cffffd100" end
  local icon = crafted and Icon(node.id)
  return (icon and ("|T" .. icon .. ":14|t ") or "") .. name .. (C.ItemName(node.id) or "?") .. "|r  " .. count .. have .. "/" .. need .. "|r"
end

local function Flatten(nodes)
  local order, byId = {}, {}
  local function Walk(list, fraction)
    for _, node in ipairs(list) do
      if node.crafted then
        local have = C.Have(node.id, true)
        Walk(node.children, max(fraction, node.need > 0 and min(1, have / node.need) or 0))
      else
        local leaf = byId[node.id]
        if not leaf then
          leaf = { id = node.id, need = 0, covered = 0, depth = 0 }
          byId[node.id] = leaf
          order[#order + 1] = leaf
        end
        leaf.need = leaf.need + node.need
        leaf.covered = leaf.covered + node.need * fraction
      end
    end
  end
  Walk(nodes, 0)
  return order
end
C.Flatten = Flatten

local function NewTextLine(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(14)
  b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  b.text:SetPoint("TOPLEFT")
  b.text:SetJustifyH("LEFT")
  b:SetScript("OnEnter", ItemTip)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", ItemClick)
  return b
end

local function LayText(p, recipeID, width)
  local f = p.frame
  local pool = p.texts
  pool.used = 0
  local r = C.Recipe(recipeID)
  local nodes = Tree(recipeID, 1, 0, { [recipeID] = true })
  if #nodes == 0 then
    pool:HideRest()
    p.head:Hide(); p.toggle:Hide()
    return 0
  end
  local nested = C.Nested()
  local name = (r and C.ItemName(r.o)) or (r and r.name) or ""
  p.head:SetText("|cffffd100" .. (nested and L.CRAFT_MATERIALS_FOR or L.CRAFT_RAW_FOR):format(name) .. "|r")
  p.head:SetWidth(width - 30)
  p.head:Show()
  local art = nested and "Interface\\Buttons\\UI-Panel-BiggerButton-Up" or "Interface\\Buttons\\UI-Panel-SmallerButton-Up"
  p.toggle:SetNormalTexture(art)
  p.toggle:Show()
  local y = -p.head:GetStringHeight() - 8
  local function Add(node, text)
    local b = pool:Get(f)
    local indent = (node.depth or 0) * LINE_INDENT
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + indent, y)
    b:SetWidth(max(40, width - 8 - indent))
    b.text:SetWidth(max(40, width - 8 - indent))
    b.text:SetText(text)
    b:SetHeight(b.text:GetStringHeight())
    b.itemID = node.id
    b:Show()
    y = y - b.text:GetStringHeight() - 2
  end
  if nested then
    local function Walk(list, fraction)
      for _, node in ipairs(list) do
        local have = C.Have(node.id, true)
        Add(node, Line(node, have, node.need * fraction, node.crafted))
        if node.crafted then Walk(node.children, max(fraction, node.need > 0 and min(1, have / node.need) or 0)) end
      end
    end
    Walk(nodes, 0)
  else
    for _, leaf in ipairs(Flatten(nodes)) do Add(leaf, Line(leaf, C.Have(leaf.id, true), leaf.covered, false)) end
  end
  pool:HideRest()
  return -y + 4
end

---------------------------------------------------------------------------
-- The panel: one of the two under a recipe's reagents (both windows make one)
---------------------------------------------------------------------------
local panels = {}

function C.NewPanel(parent, onChange)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(1, 1)
  local p = { frame = f, onChange = onChange }
  p.headers = Pool(NewHeader)
  p.reagents = Pool(NewReagent)
  p.lines = Pool(function(owner)
    local t = owner:CreateTexture(nil, "ARTWORK")
    t:SetTexture(DIVIDER)
    t:SetHeight(8)
    return t
  end)
  p.texts = Pool(NewTextLine)
  p.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  p.title:SetText(L.CRAFT_SUBCOMPONENTS)
  p.head = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  p.head:SetPoint("TOPLEFT", 4, -4)
  p.head:SetJustifyH("LEFT")
  p.toggle = CreateFrame("Button", nil, f)
  p.toggle:SetSize(22, 22)
  p.toggle:SetPoint("TOPRIGHT", 0, 0)
  p.toggle:SetScript("OnClick", function(self)
    C.SetNested(not C.Nested())
    if p.onChange then p.onChange() end
    if self:IsMouseOver() and self:GetScript("OnEnter") then self:GetScript("OnEnter")(self) end
  end)
  p.toggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(C.Nested() and L.CRAFT_SHOW_RAW or L.CRAFT_SHOW_NESTED)
    GameTooltip:Show()
  end)
  p.toggle:SetScript("OnLeave", GameTooltip_Hide)

  -- The recipe's: as the options say; its height (0: nothing shown)
  function p:Update(recipeID, width)
    local mode = C.Mode()
    local height = 0
    self.texts.used = 0
    if mode ~= "text" then self.texts:HideRest(); self.head:Hide(); self.toggle:Hide() end
    if mode ~= "icons" then
      self.headers.used, self.reagents.used, self.lines.used = 0, 0, 0
      self.headers:HideRest(); self.reagents:HideRest(); self.lines:HideRest(); self.title:Hide()
    end
    if recipeID and mode == "icons" then height = LayIcons(self, recipeID, width)
    elseif recipeID and mode == "text" then height = LayText(self, recipeID, width) end
    self.frame:SetSize(width, max(1, height))
    self.frame:SetShown(height > 0)
    return height
  end
  panels[#panels + 1] = p
  return p
end

-- Something changed (the bags, the bank, an option): each window draws again
C.Redraws = {}
function C.Changed()
  for _, fn in ipairs(C.Redraws) do fn() end
end

---------------------------------------------------------------------------
-- The filter menus' entries (the game's window and ClassicUI's)
---------------------------------------------------------------------------
function C.FilterEntries()
  return {
    { label = L.CRAFT_FILTER_ON, key = "on" },
    { label = L.CRAFT_FILTER_BANK, key = "bank" },
    { label = L.CRAFT_FILTER_PART, key = "part" },
  }
end

function C.ToggleFilter(key)
  C.SetFilter(key, not C.Filter()[key])
  if key ~= "on" and not C.Filter().on then C.SetFilter("on", true) end
  if C.Relist then C.Relist() end
end

-- ClassicUI's filter menu (Skills/TradeSkillExtras.lua asks for them)
function ns.CraftFilterEntries()
  local out = { { divider = true } }
  for _, e in ipairs(C.FilterEntries()) do
    out[#out + 1] = { e.label, check = function() return C.Filter()[e.key] == true end, toggle = function() C.ToggleFilter(e.key) end }
  end
  return out
end

---------------------------------------------------------------------------
-- Its options: a page under Interface improvements, switches in the Improvements tab
---------------------------------------------------------------------------
local function SetMode(mode)
  C.SetMode(mode)
  C.Changed()
end

ns:SetQolSwitches("reverseengineering", {
  { label = "CRAFT_SW_ICONS", get = function() return C.Mode() == "icons" end,
    set = function(on) SetMode(on and "icons" or "off") end },
  { label = "CRAFT_SW_TEXT", get = function() return C.Mode() == "text" end,
    set = function(on) SetMode(on and "text" or "off") end },
  { label = "CRAFT_SW_SEARCH", get = function() return C.Option("search") end,
    set = function(on) C.SetOption("search", on); if C.Relist then C.Relist() end end },
})

local page = CreateFrame("Frame")
page:Hide()
local built
local updates = {}

local function Click() if SOUNDKIT and PlaySound then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end end
local function Update() for _, fn in ipairs(updates) do fn() end end

local function Check(text, y, get, set, x)
  local check = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  check:SetSize(26, 26)
  check:SetPoint("TOPLEFT", x or 10, y)
  local label = check.Text or check.text
  label:SetFontObject("GameFontHighlight")
  label:SetText(text)
  check:SetScript("OnClick", function(self)
    Click()
    set(self:GetChecked() and true or false)
    Update()
    if ns.RefreshOptions then ns:RefreshOptions() end
  end)
  updates[#updates + 1] = function() check:SetChecked(get()) end
  return check
end

local function Text(font, text, y, color)
  local fs = page:CreateFontString(nil, "ARTWORK", font)
  fs:SetPoint("TOPLEFT", 14, y)
  fs:SetPoint("RIGHT", -24, 0)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(true)
  fs:SetText(text)
  if color then fs:SetTextColor(.6, .6, .65) end
  return fs
end

local function Build()
  built = true
  local title = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  title:SetText("Reverse Engineering")
  local rule = page:CreateTexture(nil, "ARTWORK")
  rule:SetAtlas("Options_HorizontalDivider", true)
  rule:SetPoint("TOP", 0, -50)
  local hint = Text("GameFontHighlightSmall", L.CRAFT_HINT, -62, true)
  local y = -62 - max(30, hint:GetStringHeight()) - 14
  Text("GameFontNormal", L.CRAFT_HEAD_SHOW, y)
  y = y - 22
  for _, mode in ipairs({ "icons", "text", "off" }) do
    local check = Check(L["CRAFT_MODE_" .. mode:upper()], y, function() return C.Mode() == mode end, function() SetMode(mode) end)
    if mode == "text" and not C.textAllowed then check:Disable() end
    y = y - 26
  end
  y = y - 10
  Text("GameFontNormal", L.CRAFT_HEAD_MORE, y)
  y = y - 22
  Check(L.CRAFT_OPT_CHEST, y, function() return C.Option("chest") end, function(on) C.SetOption("chest", on); C.Changed() end)
  y = y - 26
  Check(L.CRAFT_OPT_SEARCH, y, function() return C.Option("search") end,
    function(on) C.SetOption("search", on); if C.Relist then C.Relist() end end)
  y = y - 34
  Text("GameFontNormal", L.CRAFT_HEAD_FILTER, y)
  y = y - 22
  for _, e in ipairs(C.FilterEntries()) do
    Check(e.label, y, function() return C.Filter()[e.key] == true end, function() C.ToggleFilter(e.key) end)
    y = y - 26
  end
  Text("GameFontHighlightSmall", L.CRAFT_FILTER_HINT, y - 6, true)
end

page:SetScript("OnShow", function()
  if not built then Build() end
  Update()
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
  local ok, category = pcall(function()
    if ns.qolCategory and Settings.RegisterCanvasLayoutSubcategory then
      return Settings.RegisterCanvasLayoutSubcategory(ns.qolCategory, page, "Reverse Engineering")
    end
    local c = Settings.RegisterCanvasLayoutCategory(page, "Reverse Engineering")
    Settings.RegisterAddOnCategory(c)
    return c
  end)
  if ok and category then ns.craftCategory = category end
end
ns:SetQolOpener("reverseengineering", function() ns:OpenSettingsTo(ns.craftCategory) end)
