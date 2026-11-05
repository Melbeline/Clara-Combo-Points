local _, ClaraNS = ... -- (Clara Combo Points: ClassicUI Forever built in, QoL.lua)
if not (type(ClaraNS) == "table" and ClaraNS.ClassicUIRuns) then return end
local ns = ClaraNS.ClassicUIPrivate

-- The 1.x Who tab. Takes /who results over from the client's own window while on.

local S = ns.social
local L = ns.L
local IsSecret, Safe = ns.IsSecret, ns.Safe

local active = false
local panel, tab
local results = {}
local sort = { field = "name", reverse = false }
local clientWho -- LFGWhoListFrame from its first sighting: a global frame is never replaced

-- Classic Era's header widths; x is each row text's start, under its header.
local COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 83, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 87, w = 105, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 192, w = 32, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 224, w = 92, justify = "LEFT" },
}

-- The second column is zone, guild or race, picked from its header's arrow; it shows and sorts by it.
local WHO_FIELDS = {
    { key = "zone", label = ZONE or "Zone" },
    { key = "guild", label = GUILD or "Guild" },
    { key = "race", label = _G.RACE or "Race" },
}
local SCROLL_DOWN = "Interface/ChatFrame/UI-ChatIcon-ScrollDown-"
-- Foot buttons (Classic Era: 85, 120, 120 wide at 7, 92, 212 from the window's left; the panel starts 8 in).
local WHO_REFRESH_BUTTON_X = -1
local WHO_REFRESH_BUTTON_WIDTH = 85
local WHO_ADD_FRIEND_BUTTON_X = 84
local WHO_ADD_FRIEND_BUTTON_WIDTH = 120
local WHO_GROUP_INVITE_BUTTON_X = 204
local WHO_GROUP_INVITE_BUTTON_WIDTH = 120
local WHO_BUTTONS_Y = -7
local FIELD_ARROW = { set = "file", highlightSet = "raw", add = true }
-- Era's common-dropdown-classic-textholder (the wide one: the small one ovals out over a plate this wide), round a 24 tall button.
local HOLDER_COORDS, HOLDER_BUTTON_H = { 0.38672, 0.81641, 0.00391, 0.16406 }, 24

local function WhoField()
    local want = ns.db and ns.db.whoColumn
    for _, field in ipairs(WHO_FIELDS) do
        if field.key == want then return field end
    end
    return WHO_FIELDS[1]
end

local function Collect()
    wipe(results)
    if not (C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo) then return 0 end
    local ok, shown, total = pcall(C_FriendList.GetNumWhoResults)
    if not ok then return 0 end
    shown = Safe(shown, 0) or 0
    for i = 1, shown do
        local fine, info = pcall(C_FriendList.GetWhoInfo, i)
        if fine and type(info) == "table" and info.fullName and not IsSecret(info.fullName) then
            results[#results + 1] = {
                name = info.fullName,
                guild = Safe(info.fullGuildName, ""),
                zone = Safe(info.area, ""),
                level = Safe(info.level, 0),
                class = Safe(info.classStr, ""),
                classFile = Safe(info.filename, nil),
                race = Safe(info.raceStr, ""),
            }
        end
    end
    -- Sorted here: the client's sort re-announces the list and flashes its who window.
    local key = sort.field or "name"
    if key == "zone" then key = WhoField().key end
    local reverse = sort.reverse
    table.sort(results, function(a, b)
        local x, y = a[key], b[key]
        if x == y then x, y = a.name, b.name end
        if type(x) == "string" then x, y = x:lower(), tostring(y):lower() end
        if reverse then return x > y end
        return x < y
    end)
    return Safe(total, shown) or shown
end

---------------------------------------------------------------- the list

local function UpdateRows()
    if not panel then return end
    local offset = ns.ListOffset(panel.bar)
    local shown = S.RowCount(panel)
    local key = WhoField().key
    for i, row in ipairs(panel.rows) do
        local entry = i <= shown and results[offset + i] or nil
        if entry then
            -- Selected by list position, not by name.
            S.ShowRow(row, entry, entry[key] or "", entry.level, entry.class, entry.classFile, panel.selected == offset + i)
        else
            S.HideRow(row)
        end
    end
    panel.bar:SetRange(math.max(0, #results - shown))
end

local function SelectedEntry()
    return panel and panel.selected and results[panel.selected]
end

local function UpdateButtons()
    if not panel then return end
    local entry = SelectedEntry()
    panel.add:SetEnabled(entry and true or false)
    panel.invite:SetEnabled(entry and true or false)
end

-- The client writes its own title back on its updates, so this runs from there too.
local function DressWindow()
    if FriendsFrameTitleText then FriendsFrameTitleText:SetText(WHO_LIST or "Who List") end
end

local function Refresh()
    if not panel or not panel:IsShown() then return end
    local total = Collect()
    panel.found:SetText(format(WHO_NUM_RESULTS or "%d People Found", total or #results))
    DressWindow()
    UpdateRows()
    UpdateButtons()
end

local function ShowRowMenu(entry) S.ShowPlayerMenu(panel, entry) end

local function Row_OnClick(self, button)
    if not self.entry then return end
    for i, entry in ipairs(results) do
        if entry == self.entry then panel.selected = i end
    end
    UpdateRows()
    UpdateButtons()
    if button == "RightButton" and self.entry.name ~= UnitName("player") then
        ShowRowMenu(self.entry)
    end
end

local function Row_OnDoubleClick(self)
    if self.entry then ns.Whisper(self.entry.name) end
end

-- (Clara Combo Points) Over any row, short name or long (Forever's surnames cut some short): the whole name, the
-- character's race, and the middle column when that is cut.
local function Row_OnEnter(self)
    local entry = self.entry
    if not entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.name, 1, 0.82, 0)
    if entry.race and entry.race ~= "" then GameTooltip:AddLine(entry.race, 1, 1, 1) end
    local fieldCut = self.Zone:IsTruncated()
    if fieldCut and self.Zone:GetText() ~= entry.race then GameTooltip:AddLine(self.Zone:GetText(), 1, 1, 1) end
    GameTooltip:Show()
end

local function Header_OnClick(self)
    S.ToggleSort(sort, self.key)
    Refresh()
end

local function HideRowMenu()
    local menu = S.playerMenu
    if menu and menu:IsShown() then menu:Hide() end
end

-- The client's who window (in the group finder) opens itself on results; closed while ours is up.
local function CloseClientWhoWindow()
    local who = clientWho or _G["LFGWhoListFrame"]
    clientWho = who
    local parent = _G["LFGParentFrame"]
    -- Only when ours is up to replace it.
    if not (FriendsFrame and FriendsFrame:IsVisible()) then return end
    -- Never turned from here: that marked the finder's page ours, refusing its opens in a fight.
    if who and who:IsShown() and parent and parent:IsShown() then
        ns.HidePanel(parent)
        -- Its opening re-laid the social window at the game's spot: ours goes back now, not with the window watch.
        if ns.windowEdit then ns.windowEdit.PlaceAll() end
    end
end

-- The client's panels in the window, hidden while the who list is up.
local hidden = { key = "fcuiWhoHidden", swept = "fcuiWhoSwept", pending = false }
S.SettleFrame(hidden)

local function HideBlizzardPanels()
    CloseClientWhoWindow()
    S.HidePanels(hidden, panel)
end

local function ShowBlizzardPanels()
    S.ShowPanels(hidden)
end

local function SelectOurTab(on)
    if not tab then return end
    S.SelectFriendsTab(tab, on)
end

-- Ours back in front after the client's list (WHO_LIST_UPDATE) and each panel swap.
local function FrontAgain()
    if active and panel and panel:IsShown() then
        HideBlizzardPanels()
        SelectOurTab(true)
        DressWindow()
    end
end

---------------------------------------------------------------- the panel

-- The game's Who filters (class, race, zone) under rows that sort at once: Class by class, Race, Zone and Guild by the
-- second column, which then shows that field. (Clara Combo Points: no Sort By, the column heads sort.)
local function FilterEntries(header)
    local function Column(key)
        for _, field in ipairs(WHO_FIELDS) do
            if field.key == key then
                ns.db.whoColumn = key
                if header.Text then header.Text:SetText(field.label) end
            end
        end
        sort.field, sort.reverse = "zone", false
        Refresh()
    end
    local function ColumnRadio(key) return function() return sort.field == "zone" and WhoField().key == key end end
    local entries = S.WhoFilterEntries()
    local class, race, zone = entries[1], entries[2], entries[3]
    class.radio = function() return sort.field == "class" end
    class.pick = function() sort.field, sort.reverse = "class", false Refresh() end
    race.radio, race.pick = ColumnRadio("race"), function() Column("race") end
    zone.radio, zone.pick = ColumnRadio("zone"), function() Column("zone") end
    entries[#entries + 1] = { GUILD or "Guild", radio = ColumnRadio("guild"), pick = function() Column("guild") end,
        close = true }
    class.close, race.close, zone.close = true, true, true -- (Clara Combo Points: the list sorted, the menu shut)
    return entries
end

-- The filter arrow on the second column's plate.
local function FieldArrow(header, column)
    if column.key ~= "zone" then return end
    if header.Text then header.Text:SetText(WhoField().label) end
    -- Era's dropdown box round the plate: its text holder, shadow margins scaled to the plate's height.
    local holder = header:CreateTexture(nil, "ARTWORK", nil, -8)
    ns.SetTex(holder, "dropdownClassic")
    holder:SetTexCoord(unpack(HOLDER_COORDS))
    local k = header:GetHeight() / HOLDER_BUTTON_H
    holder:SetPoint("TOPLEFT", header, "TOPLEFT", -9 * k, 8 * k)
    holder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 8 * k, -9 * k)
    local arrow = ns.NewFrame("Button", nil, header)
    arrow:SetSize(22, 22)
    arrow:SetPoint("RIGHT", header, "RIGHT", 1, 0)
    ns.DressStates(arrow, SCROLL_DOWN .. "Up", SCROLL_DOWN .. "Down", nil, ns.ART.HILIGHT, FIELD_ARROW)
    local menu
    arrow:SetScript("OnClick", function()
        if not menu then
            menu = ns.TreeMenu(FilterEntries(header))
            menu:Follow(panel)
        end
        menu:Toggle(header)
    end)
end

-- (Clara Combo Points) The columns widened or narrowed by dragging the grip between two heads: the one on the left takes
-- what the one on the right gives (the four keep the list's width); kept in the profile (db.whoWidths). A right-click
-- on a grip puts every column back.
local MIN_W = { name = 40, zone = 50, level = 24, class = 40 }
local GRIP_W = 8
local TEXT_GAP = 6 -- (as the rows' texts: SocialWindow.lua)

local function Widths()
    local saved = ns.db and type(ns.db.whoWidths) == "table" and ns.db.whoWidths
    local widths, total, sum = {}, 0, 0
    for _, column in ipairs(COLUMNS) do total = total + column.w end
    for i, column in ipairs(COLUMNS) do
        local w = saved and tonumber(saved[column.key]) or column.w
        widths[i] = math.max(MIN_W[column.key] or 20, math.floor(w + 0.5))
        sum = sum + widths[i]
    end
    if sum ~= total then -- (a saved set that no longer fits: the game's)
        for i, column in ipairs(COLUMNS) do widths[i] = column.w end
    end
    return widths
end

local function ApplyWidths(widths)
    if not panel then return end
    local x = COLUMNS[1].x
    for i, column in ipairs(COLUMNS) do
        local w = widths[i]
        if panel.headers and panel.headers[i] then panel.headers[i]:SetWidth(w) end
        local key = column.key:gsub("^%l", string.upper)
        for _, row in ipairs(panel.rows or {}) do
            local text = row[key]
            if text then
                text:ClearAllPoints()
                text:SetPoint("LEFT", row, "LEFT", x, 0)
                text:SetWidth(w - TEXT_GAP)
            end
        end
        x = x + w
    end
end

local function SaveWidths(widths)
    ns.db.whoWidths = {}
    local same = true
    for i, column in ipairs(COLUMNS) do
        ns.db.whoWidths[column.key] = widths[i]
        if widths[i] ~= column.w then same = false end
    end
    if same then ns.db.whoWidths = nil end
end

local function GripTip(grip)
    GameTooltip:SetOwner(grip, "ANCHOR_TOP")
    GameTooltip:SetText(L["WHO_COLUMN_GRIP"], 1, 1, 1)
    GameTooltip:AddLine(L["WHO_COLUMN_GRIP_RESET"], 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function ColumnGrips()
    if type(panel.headers) ~= "table" or #panel.headers < #COLUMNS then return end
    for i = 1, #COLUMNS - 1 do
        local left = panel.headers[i]
        local grip = ns.NewFrame("Button", nil, panel.headerRow)
        grip:SetSize(GRIP_W, 20)
        grip:SetPoint("CENTER", left, "RIGHT", 0, 0)
        grip:SetFrameLevel(left:GetFrameLevel() + 5)
        grip:RegisterForClicks("RightButtonUp")
        local line = grip:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 0.82, 0, 0.6)
        line:SetPoint("TOP", grip, "TOP", 0, -2)
        line:SetPoint("BOTTOM", grip, "BOTTOM", 0, 2)
        line:SetWidth(2)
        line:Hide()
        grip.line = line
        grip:SetScript("OnEnter", function(self) self.line:Show() GripTip(self) end)
        grip:SetScript("OnLeave", function(self) if not self.dragging then self.line:Hide() end ns.HideTip() end)
        grip:SetScript("OnClick", function()
            ns.db.whoWidths = nil
            ApplyWidths(Widths())
        end)
        grip:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local widths = Widths()
            local scale = self:GetEffectiveScale()
            self.dragging = { widths = widths, from = (GetCursorPosition()) / scale, a = widths[i], b = widths[i + 1] }
            ns.HideTip()
            self:SetScript("OnUpdate", function(me)
                local drag = me.dragging
                if not drag then return end
                local delta = (GetCursorPosition()) / scale - drag.from
                local pair = drag.a + drag.b
                local minA, minB = MIN_W[COLUMNS[i].key] or 20, MIN_W[COLUMNS[i + 1].key] or 20
                local a = math.floor(math.max(minA, math.min(pair - minB, drag.a + delta)) + 0.5)
                if a ~= drag.widths[i] then
                    drag.widths[i], drag.widths[i + 1] = a, pair - a
                    ApplyWidths(drag.widths)
                end
            end)
        end)
        grip:SetScript("OnMouseUp", function(self, button)
            if button ~= "LeftButton" or not self.dragging then return end
            SaveWidths(self.dragging.widths)
            self.dragging = nil
            self:SetScript("OnUpdate", nil)
            if not self:IsMouseOver() then self.line:Hide() end
        end)
        grip:SetScript("OnHide", function(self)
            if self.dragging then SaveWidths(self.dragging.widths) end
            self.dragging = nil
            self:SetScript("OnUpdate", nil)
            self.line:Hide()
        end)
    end
end
ns.WhoColumnWidths = function() return Widths() end -- (for the tests)

-- The bar runs the pane's full height, down beside the count to the search line.
local function Build()
    local host = FriendsFrame
    if not host then return end
    panel = S.NewPanel(host, "ClassicUIForeverWhoPanel")

    -- The foot as Classic Era lays it: Refresh, Add Friend, Group Invite at its widths, each from the panel's left.
    panel.add = ns.PanelButton(panel, ADD_FRIEND or "Add Friend", WHO_ADD_FRIEND_BUTTON_WIDTH)
    panel.add:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", WHO_ADD_FRIEND_BUTTON_X, WHO_BUTTONS_Y)
    panel.refresh = ns.PanelButton(panel, REFRESH or "Refresh", WHO_REFRESH_BUTTON_WIDTH)
    panel.refresh:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", WHO_REFRESH_BUTTON_X, WHO_BUTTONS_Y)
    panel.refresh:SetScript("OnClick", function()
        S.SendWho(panel.query and panel.query:GetText())
    end)

    panel.add:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry then S.AddFriend(entry.name) end
    end)

    panel.invite = ns.PanelButton(panel, GROUP_INVITE or "Group Invite", WHO_GROUP_INVITE_BUTTON_WIDTH)
    panel.invite:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", WHO_GROUP_INVITE_BUTTON_X, WHO_BUTTONS_Y)
    panel.invite:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry then S.Invite(entry.name) end
    end)

    -- No stone bar over the buttons (the search line's border is the line);
    -- kept invisible as the list foot's anchor.
    panel.divider = ns.StoneBar(panel)
    panel.divider:SetAlpha(0)
    panel.divider:SetPoint("BOTTOM", panel.refresh, "TOP", 0, 3)
    S.Span(panel.divider, host)

    local headerRow, headers = S.HeaderRow(panel, host, COLUMNS, Header_OnClick, FieldArrow)
    panel.headerRow, panel.headers = headerRow, headers
    panel.listBox = S.ListBox(panel, host, headerRow, panel.divider)

    panel.found = panel.listBox:CreateFontString(nil, "ARTWORK")
    panel.found:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    panel.found:SetPoint("BOTTOM", panel.listBox, "BOTTOM", 0, 19)

    -- The old query line: a who search without the slash command.
    S.SearchLine(panel, function(self)
        S.SendWho(self:GetText())
        self:ClearFocus()
    end)

    -- Era's inset runs down round the search line to the buttons.
    panel.insetFoot = panel.refresh
    S.ScrollRows(panel, panel.found, 2, UpdateRows, COLUMNS, Row_OnClick, Row_OnDoubleClick, S.PlaceListBar)
    for _, row in ipairs(panel.rows) do
        row:HookScript("OnEnter", Row_OnEnter)
        row:HookScript("OnLeave", ns.HideTip)
    end
    ColumnGrips()
    ApplyWidths(Widths())

    panel:SetScript("OnShow", function()
        -- Results come to this window, not the chat frame.
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
        Refresh()
    end)
    panel:SetScript("OnHide", function()
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, false) end
    end)

    local driver = ns.EventFrame("WHO_LIST_UPDATE", function()
        if not active then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
        DressWindow()
        Refresh()
        -- The client shows its list on this event too; ours goes back in front next frame.
        ns.Sched.NextFrame("who.front", FrontAgain)
    end)
    panel.driver = driver
    -- /who, the Who key or a finder reopened on its Who page shows the client's list: sent away the frame it shows.
    ns.Sched.OnFrame(driver, { name = "who.driver", every = 0, fn = function()
        if not active then return end
        local who = clientWho
        if not who then
            who = _G["LFGWhoListFrame"]
            if not who then return end
            clientWho = who
        end
        if not who:IsVisible() then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
    end })
    -- Shown only while the module is on (SetActive); it still hears the event.
    if not active then driver:Hide() end
end

---------------------------------------------------------------- the tabs

local function ShowWho()
    if not panel then return end
    -- The finder those tabs open is Forever's alone.
    if ns.OnForever() then
        S.BuildWhoFinderTabs(FriendsFrame, panel)
        S.SyncWhoFinderTabs()
    end
    ns.HideGuildRoster()
    HideBlizzardPanels()
    panel:Show()
    SelectOurTab(true)
    DressWindow()
    Refresh()
end

local function HideWho()
    if not panel then return end
    HideRowMenu()
    panel:Hide()
    SelectOurTab(false)
    ShowBlizzardPanels()
    ns.RestoreFriendsTitle()
end
ns.HideWhoList = HideWho

-- Public API (Core/API.lua): our Who panel, nil until built.
function ns.WhoPanel() return panel end

function ns.OpenWhoList()
    if not active or not FriendsFrame then return false end
    if not panel then Build() end
    if not ns.ShowPanel(FriendsFrame) then return false end
    ShowWho()
    return true
end

local function OnClientTab() if active then HideWho() end end
local function OnSocialShow() if active then S.PlaceTabs() end end
local function OnSocialHide() if panel then HideWho() end end
-- The client swaps its own panel in by name; ours goes back over it.
local SOCIAL_HOOKS = { tabClick = OnClientTab, showSubFrame = FrontAgain, update = FrontAgain,
    onShow = OnSocialShow, onHide = OnSocialHide }

local function BuildTab()
    local host = FriendsFrame
    if not host or tab then return end
    tab = S.NewTab(host, "ClassicUIForeverWhoTab", 91, WHO or "Who")
    S.whoTab = tab
    SelectOurTab(false)
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        if active then ShowWho() else S.OpenFinderWho() end
    end)
    S.HookFriendsFrame(host, SOCIAL_HOOKS)
end

-- Forever's social window has no Who tab of the game's: with our list off ours stays, opening its Who page instead.
local function StandsIn() return not FRIEND_TAB_WHO end

local function StandIn()
    if active or not StandsIn() then return end
    BuildTab()
    if not tab then return end
    tab:SetShown(not S.WhoTabHidden())
    S.WatchSocialWho(tab, true)
    S.PlaceTabs()
end

-- The first tab says Contacts on this client; 1.x said Friends.
local function RenameFirstTab()
    local first = _G["FriendsFrameTab1"]
    if not first or not first.SetText then return end
    first:SetText(FRIENDS or "Friends")
    ns.FitBottomTab(first)
end

-- The module's switch, its only writer. The watch does nothing while off, so its frame shows only while on.
local function SetActive(on)
    active = on
    local driver = panel and panel.driver
    if driver then driver:SetShown(on) end
end

local function Apply()
    SetActive(true)
    if not FriendsFrame then ns.MissingPiece("FriendsFrame") return end
    -- Never during a fight: see ns.WhenCalm.
    ns.WhenCalm("social", function()
        if not active then return end
        if not panel then Build() end
        BuildTab()
        RenameFirstTab()
        if tab then
            tab:SetShown(not S.WhoTabHidden())
            S.WatchSocialWho(tab, false)
            S.ClientWhoTab(true)
        end
        S.PlaceTabs()
        S.UseOpener("whoList", true)
    end)
end

local function Restore()
    SetActive(false)
    HideWho()
    S.UseOpener("whoList", false)
    if FriendsFrame and StandsIn() then
        ns.WhenCalm("social.whoStandIn", StandIn)
    elseif tab then
        tab:Hide()
    end
    if S.ClientWhoTab(S.WhoTabHidden()) then S.PlaceTabs() end
end

-- In a fight too: only widget calls (the game's tab takes its mouse back after it).
ns.OnToggle(function(key)
    if key ~= "hideWhoTab" then return end
    local hidden = S.WhoTabHidden()
    if active or StandsIn() then
        if not tab then return end
        tab:SetShown(not hidden)
    elseif not S.ClientWhoTab(hidden) then
        return
    end
    S.PlaceTabs()
end)

ns.RegisterModule("whoList", { apply = Apply, restore = Restore })
