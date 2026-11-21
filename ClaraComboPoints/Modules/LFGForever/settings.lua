-- LFGForever -- core/settings.lua
--
-- The addon's page under Options -> AddOns, and the saved tables behind it
-- (LFGForeverDB account-wide; LFGForeverCharDB per character): the whisper
-- log size (Clara: the two auto-whispers and their messages removed); a Search section (Show all level
-- activities, Show suggested level ranges, the two guild / friend mark
-- options, Sort players by); and a Miscellaneous section (the Open LFG Forever key binding, Show
-- minimap button, a Report a bug button, a Reset window position and size
-- button).
--
-- BLIZZARD'S OWN SETTINGS PANEL, BUILT FROM ITS OWN CONTROLS -- the pattern
-- BugSack uses on this very client (examples/BugSack/config.lua, whose Forever
-- build loads it with no game-type condition). No layout code of ours: the
-- category, the setting and the slider are all Blizzard's, so the page looks
-- and behaves like every other one in the panel. No libraries either
-- (AceConfig would draw the same panel through the same API).
--
-- THE API LOADS ON CAMELOT: `element_check.py global Settings` ->
-- Blizzard_Settings_Shared/Blizzard_Settings.lua:6, LOADS; and SettingsPanel is
-- in the running-client frame dump (Frames.lua:311).
--
-- IT WAITS FOR ADDON_LOADED because the saved table does not exist before it:
-- the client assigns LFGForeverDB from disk just before that event, or leaves it
-- nil on a first install. RegisterAddOnSetting asserts it is handed a table
-- (Blizzard_Setting.lua:418), so registering at file scope would error.
local addonName, ClaraNS = ... -- (Clara Combo Points: LFG Forever built in, QoL.lua; addonName is Clara's)
if not ClaraNS.LFGForeverRuns then return end
local LFGF = ClaraNS.LFGForeverPrivate
-- Every word this file shows, from core/locale.lua (loaded first).
local L = LFGF.L

-- EVERY SAVED KEY, its Settings variable, its saved table, type and default
-- come from core/db.lua (LFGF.SAVED_KEYS, loaded second). This page only says
-- which rows to build, in which order, with which words.
local SAVED = {}
for _, entry in ipairs(LFGF.SAVED_KEYS) do
	SAVED[entry.key] = entry
end

-- core/db.lua's Lua type names, as Blizzard's Settings.VarType names them
-- (Blizzard_Settings.lua; the three kinds this page uses).
local VAR_TYPE_NAMES = { boolean = "Boolean", number = "Number", string = "String" }

--- Register one saved key as a Blizzard add-on setting. Blizzard writes the
--- entry's default into its table when the key is nil -- `== nil`, so a saved
--- false, 0 or "" survives (Blizzard_Setting.lua:398-402, :426).
local function RegisterSetting(category, key, label)
	local entry = assert(SAVED[key], key)
	return Settings.RegisterAddOnSetting(category,                          -- :174
		entry.variable, entry.key, LFGF.SavedTable(entry.scope),
		Settings.VarType[VAR_TYPE_NAMES[entry.type]], label, entry.default)
end

-- 50 to 500 in steps of 50, around the default of 200 -- a slider rather than a
-- text box, so no value outside the range can be entered at all.
local WHISPER_LOG_SIZE_MIN, WHISPER_LOG_SIZE_MAX, WHISPER_LOG_SIZE_STEP = 50, 500, 50

local WHISPER_LOG_SIZE_LABEL = L.SETTINGS_WHISPER_LOG_SIZE_LABEL
local WHISPER_LOG_SIZE_TOOLTIP = L.SETTINGS_WHISPER_LOG_SIZE_TOOLTIP

-------------------------------------------------------
---------- Search
-------------------------------------------------------
-- One of Blizzard's checkbox rows under a header: LFG Forever's own copy of
-- the "Show All Level Ranges" option Blizzard keeps in its Group Finder's gear
-- menu (Blizzard_LFGVanilla_Browse.lua:1274-1280). Saved in LFGForeverDB, NOT
-- in Blizzard's CVar -- see showAllLevelRanges in core/db.lua for why -- so
-- the two finders' options are independent. Its change is re-announced over EventRegistry, and core/filterpanel.lua
-- rebuilds its dropdowns at once.
local SEARCH_HEADER = L.SETTINGS_SEARCH_HEADER
-- The label is our own, in the page's sentence case. Until 0.9.0-dev.7 it
-- was Blizzard's string for the same checkbox, LFG_LIST_IGNORE_SUGGESTED_LEVEL
-- ("Show All Level Ranges", GlobalStrings/enUS.lua:13597), whose Title Case
-- stood out among this page's labels. The wording is the author's
-- (0.9.0-dev.9), kept within the ~28 characters a row label fits: one line,
-- no wrap, from x = 37 to 85 short of the row's centre
-- (Blizzard_SettingControls.lua:338-341). A spec holds it to that.
local SHOW_ALL_LEVEL_RANGES_LABEL = L.SETTINGS_SHOW_ALL_LEVELS_LABEL
local SHOW_ALL_LEVEL_RANGES_TOOLTIP = L.SETTINGS_SHOW_ALL_LEVELS_TOOLTIP

-- The section's second checkbox: each activity's suggested level range after
-- its name in the activity menu (LFGF.ActivityMenuText, core/filterpanel.lua).
-- Read when the menu is built, and the menu is rebuilt on every open, so a
-- change needs no announcement. The label is our own, in the author's wording
-- (0.9.0-dev.9), and kept under the ~28 characters a row label fits on one
-- line (Blizzard_SettingControls.lua:338-341).
local SHOW_ACTIVITY_LEVEL_RANGES_LABEL = L.SETTINGS_SHOW_LEVEL_RANGES_LABEL
local SHOW_ACTIVITY_LEVEL_RANGES_TOOLTIP = L.SETTINGS_SHOW_LEVEL_RANGES_TOOLTIP

-------------------------------------------------------
---------- Guild and friends (in the Search section)
-------------------------------------------------------
-- Two of Blizzard's own checkbox rows, the last two of Search. They had their
-- own "Guild and friends" header until 0.8.0-dev.3. Each governs its mark in
-- BOTH lists -- the icon and the moving up -- and, when off, every call to its
-- API; core/relations.lua reads them through LFGF.MarkGuildmates /
-- LFGF.MarkFriends (core/main.lua); the defaults are in core/db.lua.
--
-- A change shows on the NEXT search, and on a whisper row the next time it is
-- drawn -- the same rule the marks already follow, so nothing listens here.

-- The row reads "Mark guild members"; the variable and the saved key keep the
-- names they shipped with (core/db.lua), so a choice already saved is not lost
-- to a relabel.
local MARK_GUILDMATES_LABEL = L.SETTINGS_MARK_GUILDMATES_LABEL
local MARK_GUILDMATES_TOOLTIP = L.SETTINGS_MARK_GUILDMATES_TOOLTIP

-- Until 0.21.0-dev.7 this row read "Mark friends (Experimental)", the tag and a
-- tooltip warning in Blizzard's warning colour, because the friend system was
-- disabled in the Forever beta. Confirmed working in the client (2026-10-12),
-- it is a plain row like the guild one. .claude/rules/relation-icons.md
local MARK_FRIENDS_LABEL = L.SETTINGS_MARK_FRIENDS_LABEL
local MARK_FRIENDS_TOOLTIP = L.SETTINGS_MARK_FRIENDS_TOOLTIP

-------------------------------------------------------
---------- Sort players by (the last row of Search)
-------------------------------------------------------
-- Blizzard's own dropdown row (Settings.CreateDropdown, Blizzard_Settings.lua
-- :410), built the way BugSack builds its font-size dropdown on this client.
-- Each option's tooltip becomes a line of the row's own tooltip (:416-496).
-- It orders the Players box of the list (core/listpanel.lua), which sorts
-- again on the announcement below. .claude/rules/player-sort-order.md

--- The options, in LFGF.PLAYER_SORT_ORDERS' order. A FUNCTION, as Blizzard's
--- menu calls it every time it is built (CreateDropdownOptionInserter,
--- :524-526); each option is saved by its name (core/main.lua).
local function PlayerSortOptions()
	local words = {
		newest = { L.PLAYER_SORT_NEWEST, L.PLAYER_SORT_NEWEST_TOOLTIP },
		oldest = { L.PLAYER_SORT_OLDEST, L.PLAYER_SORT_OLDEST_TOOLTIP },
		levelHigh = { L.PLAYER_SORT_LEVEL_HIGH, L.PLAYER_SORT_LEVEL_HIGH_TOOLTIP },
		levelLow = { L.PLAYER_SORT_LEVEL_LOW, L.PLAYER_SORT_LEVEL_LOW_TOOLTIP },
		class = { L.PLAYER_SORT_CLASS, L.PLAYER_SORT_CLASS_TOOLTIP },
	}
	local container = Settings.CreateControlTextContainer()                 -- :261
	for _, order in ipairs(LFGF.PLAYER_SORT_ORDERS) do
		container:Add(order, words[order][1], words[order][2])
	end
	return container:GetData()
end

-------------------------------------------------------
---------- Miscellaneous
-------------------------------------------------------
-- The last section, four rows in the author's order: the key binding, Show
-- minimap button, Report a bug, Reset window position. Headed with Blizzard's own string by
-- default (MISCELLANEOUS, GlobalStrings/enUS.lua:14324, through core/locale.lua),
-- so it is translated with the client unless a language pack replaces it.
-- Until 0.8.0-dev.3 the first two had headers of their own, Minimap and
-- Report a bug.

-- The key binding: "Open LFG Forever" and a Keybindings button that opens
-- Blizzard's own Keybindings page at the LFG Forever section
-- (LFGF.OpenKeybindings, core/main.lua), where Blizzard's code picks, unbinds
-- and saves the key. A button row like Blizzard's own link to its Ping
-- keybindings, which also stays out of the settings search
-- (PingSystem.lua:89-90): the search finds the key itself on Blizzard's page.
-- The button never uses the binding, so the row is there whatever the client
-- knows: with Bindings.xml missing, Blizzard's page has no section to scroll to.
--
-- NEVER BLIZZARD'S KEY ROW HERE (CreateKeybindingEntryInitializer). That
-- helper writes MatchesSearchTags and GetBindingText onto the row in its
-- caller's code (Blizzard_Keybindings.lua:537-563), so from here they are our
-- values, and the settings search calls MatchesSearchTags on every row
-- outside its protected calls (Blizzard_SettingsPanel.lua:628). A client
-- taint log proved it: one keystroke in the search box tainted Blizzard's
-- settings list, and Blizzard's Keybindings page then could not change any
-- key in combat (SetBinding() blocked). .claude/rules/keybinding.md, *Taint*.
local function KeybindingRow()
	return CreateSettingsButtonInitializer(L.BINDING_OPEN_WINDOW, L.KEYBINDINGS,
		LFGF.OpenKeybindings, L.SETTINGS_KEYBINDING_TOOLTIP, false)
end

-- Show minimap button: one of Blizzard's checkbox rows. core/minimap.lua builds
-- the button either way and only shows or hides it, so the change is immediate
-- rather than waiting for a reload.
local SHOW_MINIMAP_BUTTON_LABEL = L.SETTINGS_MINIMAP_BUTTON_LABEL
local SHOW_MINIMAP_BUTTON_TOOLTIP = L.SETTINGS_MINIMAP_BUTTON_TOOLTIP

-- Report a bug: one of Blizzard's own button rows -- "Found a bug or have an
-- idea?" beside a Discord button. The whole
-- sentence does not fit: a row's label runs from x = 37 to 85 short of the
-- row's centre and does not wrap (Blizzard_SettingControls.lua:340-341,
-- SettingsListElementTemplate wordwrap="false"), about 200px on this 920-wide
-- panel. The button carries the "tell us on" half.
local DISCORD_URL = "https://discord.com/invite/z6BU5Rkdsy"

local REPORT_BUG_LABEL = L.SETTINGS_REPORT_BUG_LABEL
-- A name, so not a key: it reads "Discord" in every language.
local REPORT_BUG_BUTTON = "Discord"
local REPORT_BUG_TOOLTIP = L.SETTINGS_REPORT_BUG_TOOLTIP

-- THE LINK IS SHOWN TO COPY, NOT OPENED. Addon code may do neither of the
-- obvious things: LaunchURL and CopyToClipboard are both HasRestrictions
-- (URLDocumentation.lua:12, OsDocumentation.lua:12), and CopyToClipboard has
-- already been refused from this addon in the client. So the popup holds the
-- link in a text box, selected, for the player's own Ctrl+C -- what every
-- example addon that shows a link does.
local REPORT_BUG_POPUP = "LFGFOREVER_REPORT_BUG"
local REPORT_BUG_POPUP_TEXT = L.REPORT_BUG_POPUP_TEXT

-- Wide enough to show the whole link; GameDialogMixin:SetupEditBox reads it
-- (GameDialog.lua:253). The default is 130 (GameDialog.xml:212).
local REPORT_BUG_EDITBOX_WIDTH = 260

-- ALWAYS SET, because the text box is shared. Blizzard reuses four popup
-- frames, one edit box each (GameDialog.xml:348-367, StaticPopup.lua:389-393),
-- and SetupEditBox applies a letter limit ONLY when the dialog defines one
-- (GameDialog.lua:248-251); nothing resets it. Without this the popup inherits
-- whatever limit the previous dialog left -- 24 after Blizzard's generic input
-- box (GameDialogDefs.lua:213), 31 after a guild note -- and the link does not
-- fit. Exactly the link's length also keeps the copy box from growing. The link
-- is plain ASCII, so its byte length is its letter count.
local REPORT_BUG_MAX_LETTERS = #DISCORD_URL

-- Defined once, at file scope: StaticPopupDialogs is a shared registry, and the
-- key is namespaced because every addon's dialogs live in it.
StaticPopupDialogs[REPORT_BUG_POPUP] = {
	text = REPORT_BUG_POPUP_TEXT,
	button1 = L.CLOSE,
	hasEditBox = 1,
	maxLetters = REPORT_BUG_MAX_LETTERS,
	editBoxWidth = REPORT_BUG_EDITBOX_WIDTH,

	-- Runs synchronously inside StaticPopup_Show, with the link as `data`
	-- (StaticPopup.lua:591-596). The text box is reached through the dialog's
	-- accessor (GameDialog.lua:242), not a field.
	OnShow = function(dialog, url)
		local editBox = dialog:GetEditBox()
		editBox:SetText(url)
		editBox:SetFocus()
		editBox:HighlightText()
	end,

	-- READ-ONLY, the way a copy box should be: anything typed over the link is
	-- put back at once. The hook is called with the dialog's data
	-- (SharedTemplates.lua:69-74), which is the link itself.
	EditBoxOnTextChanged = function(editBox, url)
		if editBox:GetText() ~= url then
			editBox:SetText(url)
			editBox:HighlightText()
		end
	end,

	-- Escape in the box closes the popup -- Blizzard's own helper
	-- (StaticPopup.lua:152-154).
	EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,

	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

--- The Discord button's click: open the popup, the link passed as `data` -- the
--- FOURTH argument, so it is there before OnShow runs (StaticPopup.lua:309).
local function ShowReportBug()
	StaticPopup_Show(REPORT_BUG_POPUP, nil, nil, DISCORD_URL)
end

-- Reset window position and size: one of Blizzard's own button rows, the last
-- on the page. The label names the thing and the button, Blizzard's own RESET
-- (GlobalStrings/enUS.lua:18662), the action -- the Report a bug row's shape.
-- It resets AT ONCE, with no popup, by the author's decision: it is harmless,
-- and a drag undoes it. LFGF.ResetWindowPosition (core/window.lua) forgets the
-- saved position and size and, if the window exists, gives it the default
-- size and moves it to where it first opens (centred across, top level with
-- Blizzard's Group Finder); it is resolved at CALL time because window.lua
-- loads after this file. "Window position" until the window could be resized.
local RESET_WINDOW_LABEL = L.SETTINGS_RESET_WINDOW_LABEL
local RESET_WINDOW_TOOLTIP = L.SETTINGS_RESET_WINDOW_TOOLTIP

local function ResetWindowPosition()
	LFGF.ResetWindowPosition()
end

--- What Blizzard's Defaults button resets beyond the registered settings: the
--- window position, the saved Filters tab (LFGF.ForgetSavedFilters,
--- core/main.lua), every filter in My filters (LFGF.ForgetMyFilters) and which
--- Filters-tab sections are collapsed (LFGF.ForgetCollapsedFilterSections, which
--- expands an already-built panel's sections), all by the author's decisions -- on All Settings too, from whatever page it was
--- pressed. Forgetting the filters also puts an already-built filter panel's
--- boxes back and hides its My filters dropdown; the list is left to the next
--- Search. See .claude/rules/saved-filters.md and my-filters.md.
local function ResetOnDefaults()
	ResetWindowPosition()
	LFGF.ForgetSavedFilters()
	LFGF.ForgetMyFilters()
	LFGF.ForgetCollapsedFilterSections()
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	-- A first install has no saved table yet, and a character's first load no
	-- character table. LFGF.SavedTable (core/db.lua) creates each as a global,
	-- which is what makes the client save it on logout.
	local account, character = LFGF.SavedTable("account"), LFGF.SavedTable("character")
	-- Clara: the removed auto-whispers' keys cleared (core/db.lua, REMOVED_KEYS)
	for _, key in ipairs(LFGF.REMOVED_KEYS) do
		account[key], character[key] = nil, nil
	end

	-- The layout is kept for rows no Settings.Create* helper builds -- the
	-- headers and button rows below (Blizzard_ImplementationReadme.lua:13).
	-- Clara: its page under its theme's page of Clara (else a page of its own)
	local parent = ClaraNS:QolCategory("lfgforever")
	local category, layout
	if parent and Settings.RegisterVerticalLayoutSubcategory then
		category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, LFGF.TITLE)
	else
		category, layout = Settings.RegisterVerticalLayoutCategory(LFGF.TITLE) -- :154
	end

	local setting = RegisterSetting(category, "whisperLogSize", WHISPER_LOG_SIZE_LABEL)

	local options = Settings.CreateSliderOptions(                           -- :309
		WHISPER_LOG_SIZE_MIN, WHISPER_LOG_SIZE_MAX, WHISPER_LOG_SIZE_STEP)
	-- The number beside the slider, where Blizzard's own sliders show it
	-- (:302, MinimalSlider.lua:43).
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
	Settings.CreateSlider(category, setting, options, WHISPER_LOG_SIZE_TOOLTIP) -- :404

	-- Tell the log the moment the slider moves, so lowering the size trims at
	-- once rather than on the next whisper. The callback is invoked as
	-- (owner, setting, value) -- CallbackRegistry.lua:118-119, :212-214, the
	-- shape SettingMixin:SetValueChangedCallback unpacks (Blizzard_Setting.lua
	-- :265-267).
	Settings.SetOnValueChangedCallback(SAVED.whisperLogSize.variable, function(_, _, value) -- :665
		EventRegistry:TriggerEvent(LFGF.EVENT_WHISPER_LOG_SIZE_CHANGED, value)
	end)

	-- Search: a header, then two checkboxes, both labelled with our own text:
	-- Show all level activities (Blizzard's Group Finder has the same option) and
	-- Show suggested level ranges (which it has not).
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(SEARCH_HEADER))

	local showAllLevelRanges = RegisterSetting(category, "showAllLevelRanges",
		SHOW_ALL_LEVEL_RANGES_LABEL)
	Settings.CreateCheckbox(category, showAllLevelRanges, SHOW_ALL_LEVEL_RANGES_TOOLTIP)
	Settings.SetOnValueChangedCallback(SAVED.showAllLevelRanges.variable, function(_, _, value)
		EventRegistry:TriggerEvent(LFGF.EVENT_LEVEL_RANGES_CHANGED, value)
	end)

	local showActivityLevelRanges = RegisterSetting(category, "showActivityLevelRanges",
		SHOW_ACTIVITY_LEVEL_RANGES_LABEL)
	Settings.CreateCheckbox(category, showActivityLevelRanges, SHOW_ACTIVITY_LEVEL_RANGES_TOOLTIP)

	-- Guild and friends: the last two rows of Search, both Blizzard's own
	-- checkbox rows. Add-on settings, so Blizzard's Defaults button resets
	-- them too.
	local markGuildmates = RegisterSetting(category, "markGuildmates", MARK_GUILDMATES_LABEL)
	Settings.CreateCheckbox(category, markGuildmates, MARK_GUILDMATES_TOOLTIP)

	local markFriends = RegisterSetting(category, "markFriends", MARK_FRIENDS_LABEL)
	Settings.CreateCheckbox(category, markFriends, MARK_FRIENDS_TOOLTIP)

	-- Sort players by: after the two marks, which decide who is pinned above
	-- the chosen order. Its change is re-announced over EventRegistry, so the
	-- list sorts again without knowing the Settings API.
	local playerSortOrder = RegisterSetting(category, "playerSortOrder", L.SETTINGS_PLAYER_SORT_LABEL)
	Settings.CreateDropdown(category, playerSortOrder, PlayerSortOptions,     -- :410
		L.SETTINGS_PLAYER_SORT_TOOLTIP)
	Settings.SetOnValueChangedCallback(SAVED.playerSortOrder.variable, function(_, _, value)
		EventRegistry:TriggerEvent(LFGF.EVENT_PLAYER_SORT_ORDER_CHANGED, value)
	end)

	-- Miscellaneous: the header, then the key binding, Show minimap button,
	-- Report a bug and Reset window position.
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.MISCELLANEOUS))

	layout:AddInitializer(KeybindingRow())

	-- Show minimap button. Its change is re-announced over EventRegistry, the
	-- whisper log size's pattern above, so core/minimap.lua shows or hides the
	-- button without knowing the Settings API.

	local showMinimapButton = RegisterSetting(category, "showMinimapButton",
		SHOW_MINIMAP_BUTTON_LABEL)
	Settings.CreateCheckbox(category, showMinimapButton, SHOW_MINIMAP_BUTTON_TOOLTIP)
	Settings.SetOnValueChangedCallback(SAVED.showMinimapButton.variable, function(_, _, value)
		EventRegistry:TriggerEvent(LFGF.EVENT_MINIMAP_BUTTON_CHANGED, value)
	end)

	-- Report a bug, then Reset window position: Blizzard's own button rows
	-- (Blizzard_SettingControls.lua:1014), added the way BugSack adds its Wipe
	-- button on this client. The fifth argument must not be nil (:1019).
	-- FALSE, so the settings search does not find these rows: true would have
	-- Blizzard's function add search tags from our call (:1020-1023), our
	-- values, which the search reads outside its protected calls
	-- (Blizzard_SettingsPanel.lua:627-628). .claude/rules/settings-list-taint.md
	-- The section header is Blizzard's element too (:112), added the way
	-- Blizzard adds its own (Mainline/AudioOverrides.lua:5).
	-- Clara: no bug report row (this copy is Clara's: its bugs are not its author's to hear about)
	layout:AddInitializer(CreateSettingsButtonInitializer(RESET_WINDOW_LABEL,
		L.RESET, ResetWindowPosition, RESET_WINDOW_TOOLTIP, false))

	-- BLIZZARD'S DEFAULTS BUTTON RESETS THE WINDOW POSITION AND FORGETS THE
	-- SAVED FILTERS AND MY FILTERS TOO, by the author's decisions
	-- (ResetOnDefaults above). None is a registered setting, so Defaults does
	-- not touch them on its own. Its popup offers All Settings or These Settings
	-- (Blizzard_Dialogs.lua:2-17); each resets the registered settings and then
	-- announces it over EventRegistry -- Settings.Defaulted
	-- (Blizzard_SettingsPanel.lua:496) and Settings.CategoryDefaulted with the
	-- defaulted category (:550). Blizzard's own state that is not a setting row
	-- listens to exactly these two, comparing category IDs
	-- (Mainline/ColorblindOverrides.lua:82-89). EventRegistry runs each callback
	-- through securecallfunction (CallbackRegistry.lua:198-205), so nothing here
	-- runs inside Blizzard's defaults loop.
	--
	-- Owned by the category: one callback per owner per event
	-- (CallbackRegistry.lua:112-130), so the pair belongs to this page.
	EventRegistry:RegisterCallback("Settings.Defaulted", ResetOnDefaults, category)
	EventRegistry:RegisterCallback("Settings.CategoryDefaulted", function(_, defaulted)
		if defaulted and defaulted:GetID() == category:GetID() then
			ResetOnDefaults()
		end
	end, category)

	if not parent then Settings.RegisterAddOnCategory(category) end            -- :134

	-- Published for LFGF.OpenSettings (core/main.lua), which the minimap
	-- button's and the compartment entry's right click call.
	LFGF.settingsCategory = category
end)
