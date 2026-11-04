#!/usr/bin/env python3
"""LFG Forever 0.29.0 (GPLv3, by Artefius) -> Clara Combo Points' Modules/LFGForever.
Usage: lfg_port.py <LFGForever folder (with core/)> <ClaraComboPoints folder>
Copies core/*.lua + settings.xml + LICENSE, rewrites each file's header to Clara's private table, renames the
saved tables, and applies Clara's changes (each replacement must match exactly once)."""
import os, re, shutil, sys

src, clara = sys.argv[1], sys.argv[2]
core = os.path.join(src, "core")
dst = os.path.join(clara, "Modules", "LFGForever")
os.makedirs(dst, exist_ok=True)

ORDER = ["locale.lua", "db.lua", "main.lua", "relations.lua", "talents.lua", "settings.lua", "settings.xml",
         "listpanel.lua", "whisperlog.lua", "filterpanel_shared.lua", "filterpanel_miscellaneous.lua",
         "filterpanel_groupclasses.lua", "filterpanel.lua", "window.lua", "blizzardtab.lua", "minimap.lua",
         "slash.lua"]

HEADER = ("local addonName, ClaraNS = ... -- (Clara Combo Points: LFG Forever built in, QoL.lua; addonName is Clara's)\n"
          "if not ClaraNS.LFGForeverRuns then return end\n"
          "local LFGF = ClaraNS.LFGForeverPrivate")


def once(text, old, new, name):
    n = text.count(old)
    if n != 1:
        raise SystemExit("%s: %d matches for %r" % (name, n, old[:70]))
    return text.replace(old, new)


EDITS = {}

# ---------------------------------------------------------------- locale.lua: Clara's translations first
EDITS["locale.lua"] = [
    ('\tMINIMAP_LEFT_CLICK = "Left-click to open or close.",\n',
     '\t-- Clara: the arrow that closes the filters\' panel (core/window.lua)\n'
     '\tCLARA_SHOW_FILTERS = "Show filters and whispers",\n'
     '\tCLARA_HIDE_FILTERS = "Hide filters and whispers",\n\n'
     '\tMINIMAP_LEFT_CLICK = "Left-click to open or close.",\n'),
    ("local pack = FindPack()\n",
     "-- Clara: its own French and German words (Locale_Clara.lua), checked as a pack's are; a pack, if one\n"
     "-- loads, still has the last word.\n"
     "for key, value in pairs(ClaraNS.LFGForeverStrings or {}) do\n"
     "\tif type(key) == \"string\" and Accepts(key, L[key], value) then\n"
     "\t\tL[key] = value\n"
     "\tend\n"
     "end\n\n"
     "local pack = FindPack()\n"),
]

# ---------------------------------------------------------------- db.lua: Clara's saved tables, one more key
EDITS["db.lua"] = [
    ('[ACCOUNT] = "LFGForeverDB",', '[ACCOUNT] = "ClaraLFGForeverDB", -- (Clara: its own saved tables)'),
    ('[CHARACTER] = "LFGForeverCharDB",', '[CHARACTER] = "ClaraLFGForeverCharDB",'),
    ('\t{ key = "minimapAngle", scope = ACCOUNT, type = "number", default = 225 },\n',
     '\t{ key = "minimapAngle", scope = ACCOUNT, type = "number", default = 225 },\n\n'
     '\t-- Clara: the filters\' panel open (core/window.lua\'s arrow); closed until opened.\n'
     '\t{ key = "filtersShown", scope = ACCOUNT, type = "boolean", default = false },\n'),
]

# ---------------------------------------------------------------- main.lua: no load greeting; Clara's key row
EDITS["main.lua"] = [
    ('EventUtil.ContinueOnAddOnLoaded(addonName, function()\n'
     '\tlocal version = C_AddOns.GetAddOnMetadata(addonName, "Version")\n'
     '\n'
     '\t-- print() is the FrameXML global from Blizzard_PrintHandler.lua:93; it\n'
     '\t-- routes through securecall to the default chat frame.\n'
     '\tif version then\n'
     '\t\tprint(L.LOADED_VERSION_FORMAT:format(LFGF.TITLE, version, LFGF.SLASH_COMMAND))\n'
     '\telse\n'
     '\t\tprint(L.LOADED_FORMAT:format(LFGF.TITLE, LFGF.SLASH_COMMAND))\n'
     '\tend\n'
     'end)\n',
     '-- Clara: built in, it does not greet (Clara\'s modules load quietly); the version is the one it came as\n'
     '-- (C_AddOns.GetAddOnMetadata(addonName) would be Clara\'s).\n'
     'LFGF.VERSION = "0.29.0"\n'),
    ('\tOpenSettingsCategory(Settings.KEYBINDINGS_CATEGORY_ID, LFGF.TITLE)\n',
     '\t-- Clara: its key is in the section of Clara\'s built-in modules (Clara\'s Bindings.xml)\n'
     '\tOpenSettingsCategory(Settings.KEYBINDINGS_CATEGORY_ID, _G.BINDING_CATEGORY_CLARA_QOL or LFGF.TITLE)\n'),
]

# ---------------------------------------------------------------- settings.lua: a page under Clara's
EDITS["settings.lua"] = [
    ('local MESSAGE_ROW_TEMPLATE = "LFGForeverSettingsMessageRowTemplate"',
     'local MESSAGE_ROW_TEMPLATE = "ClaraLFGForeverSettingsMessageRowTemplate" -- (Clara: named apart from the standalone\'s)'),
    ('LFGForeverSettingsMessageRowMixin = {}\nlocal MessageRow = LFGForeverSettingsMessageRowMixin',
     'ClaraLFGForeverSettingsMessageRowMixin = {}\nlocal MessageRow = ClaraLFGForeverSettingsMessageRowMixin'),
    ('\tlocal category, layout = Settings.RegisterVerticalLayoutCategory(LFGF.TITLE) -- :154\n',
     '\t-- Clara: its page under its theme\'s page of Clara (else a page of its own)\n'
     '\tlocal parent = ClaraNS:QolCategory("lfgforever")\n'
     '\tlocal category, layout\n'
     '\tif parent and Settings.RegisterVerticalLayoutSubcategory then\n'
     '\t\tcategory, layout = Settings.RegisterVerticalLayoutSubcategory(parent, LFGF.TITLE)\n'
     '\telse\n'
     '\t\tcategory, layout = Settings.RegisterVerticalLayoutCategory(LFGF.TITLE) -- :154\n'
     '\tend\n'),
    ('\tlayout:AddInitializer(CreateSettingsButtonInitializer(REPORT_BUG_LABEL,\n'
     '\t\tREPORT_BUG_BUTTON, ShowReportBug, REPORT_BUG_TOOLTIP, false))\n',
     '\t-- Clara: no bug report row (this copy is Clara\'s: its bugs are not its author\'s to hear about)\n'),
    ('\tSettings.RegisterAddOnCategory(category)                                -- :134\n',
     '\tif not parent then Settings.RegisterAddOnCategory(category) end            -- :134\n'),
]

EDITS["settings.xml"] = [
    ('<Frame name="LFGForeverSettingsMessageRowTemplate" mixin="LFGForeverSettingsMessageRowMixin" virtual="true">',
     '<Frame name="ClaraLFGForeverSettingsMessageRowTemplate" mixin="ClaraLFGForeverSettingsMessageRowMixin" virtual="true">'),
]

# ---------------------------------------------------------------- slash.lua: Clara's binding
EDITS["slash.lua"] = [
    ('BINDING_HEADER_LFGFOREVER = LFGF.TITLE\nBINDING_NAME_LFGFOREVER_TOGGLE = L.BINDING_OPEN_WINDOW\n',
     '-- Clara: its binding is Clara\'s (Bindings.xml, CLARA_LFGFOREVER_TOGGLE, in the section of Clara\'s modules)\n'
     'BINDING_NAME_CLARA_LFGFOREVER_TOGGLE = L.BINDING_OPEN_WINDOW\n'),
]

# ---------------------------------------------------------------- minimap.lua: the compartment, where there is one
EDITS["minimap.lua"] = [
    ('EventUtil.ContinueOnAddOnLoaded(addonName, function()\n\tbutton = button or BuildButton()\nend)\n',
     'EventUtil.ContinueOnAddOnLoaded(addonName, function()\n\tbutton = button or BuildButton()\nend)\n\n'
     '-- Clara: the AddOns dropdown by the minimap reads TOC fields, Clara\'s; so the entry is given to it here, on\n'
     '-- the clients that have it (not WoW Forever\'s, today).\n'
     'EventUtil.ContinueOnAddOnLoaded(addonName, function()\n'
     '\tlocal compartment = _G.AddonCompartmentFrame\n'
     '\tif not (compartment and compartment.RegisterAddon) then\n'
     '\t\treturn\n'
     '\tend\n'
     '\tcompartment:RegisterAddon({\n'
     '\t\ttext = LFGF.TITLE,\n'
     '\t\ticon = LFGF.ICON_ATLAS,\n'
     '\t\tfunc = function(_, inputData) LFGForever_OnAddonCompartmentClick(nil, inputData and inputData.buttonName) end,\n'
     '\t\tfuncOnEnter = function(menuButton) LFGForever_OnAddonCompartmentEnter(nil, menuButton) end,\n'
     '\t\tfuncOnLeave = function() LFGForever_OnAddonCompartmentLeave() end,\n'
     '\t})\n'
     'end)\n'),
]

# ---------------------------------------------------------------- window.lua: the filters' panel closes
WINDOW_HELPERS = r'''
-- CLARA: THE FILTERS' PANEL CLOSES. An arrow at the top right of the list, in
-- the strip above it, closes the right panel (Filters and Whispers) and opens
-- it again; it stays as it was left (filtersShown, account-wide), closed until
-- it is first opened. Closed, the window is narrower by the panel's width and
-- the gutter (a moved window keeps its left edge, the default one stays
-- centred), and a Search Again button beside the arrow searches with the
-- panel's filters as they stand. The saved width is always the open window's,
-- so the list keeps its own width either way.

--- The width the panel and its gutter take.
local function FiltersRoom(frame)
	local width = LFGF.ReadableNumbers(frame.Content.FilterPanel:GetWidth())
	return (width or 600) + PANEL_GUTTER
end

--- What the window has less than with the panel open.
local function ClosedRoom(frame)
	if frame.filtersShown then
		return 0
	end
	return FiltersRoom(frame)
end
'''

WINDOW_TOGGLE = r'''
-- CLARA: the arrow and the Search Again button (see ClosedRoom above).
local TOGGLE_SIZE, TOGGLE_GAP = 24, 4

--- The two columns as the panel is: the list to the panel's left edge, or to
--- the window's right edge; the smallest width with them; the arrow's way.
local function LayFilters(frame)
	local content = frame.Content
	local filter, list = content.FilterPanel, content.ListPanel
	local shown = frame.filtersShown
	filter:SetShown(shown)
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", content, "TOPLEFT", INSET_LEFT, INSET_TOP)
	if shown then
		list:SetPoint("BOTTOMRIGHT", filter, "BOTTOMLEFT", -PANEL_GUTTER, 0)
	else
		list:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
	end
	local minWidth = WIDTH - ClosedRoom(frame)
	frame:SetResizeBounds(minWidth, HEIGHT)
	if frame.ResizeButton and frame.ResizeButton.SetMinWidth then
		frame.ResizeButton:SetMinWidth(minWidth)
	end
	if frame.FiltersToggle then
		-- Pointing where the panel goes: right to open it, left to close it.
		SquareButton_SetIcon(frame.FiltersToggle, shown and "LEFT" or "RIGHT")
		frame.FiltersSearch:SetShown(not shown)
		if shown then
			frame.FiltersToggle:UnlockHighlight()
		end
	end
end

--- Open or close the panel, the window's width with it.
local function SetFiltersShown(frame, shown)
	shown = shown == true
	if frame.filtersShown == shown then
		return
	end
	local room = FiltersRoom(frame)
	local moved = SavedPosition() ~= nil
	if moved then
		PinTopLeft(frame)
	end
	frame.filtersShown = shown
	LFGF.SaveValue("filtersShown", shown)
	LayFilters(frame)
	local width = LFGF.ReadableNumbers(frame:GetWidth())
	if width then
		frame:SetWidth(shown and width + room or math.max(width - room, WIDTH - room))
	end
	if moved then
		SavePosition(frame)
	end
end
LFGF.SetFiltersShown = function(shown)
	if window then
		SetFiltersShown(window, shown)
	end
end

local function ShowTip(owner, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(text, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:Show()
end

local function BuildFilterToggle(frame, content)
	local list, filter = content.ListPanel, content.FilterPanel

	local toggle = CreateFrame("Button", nil, content, "UIPanelSquareButton")
	toggle:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
	toggle:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", 0, TOGGLE_GAP)
	toggle:SetScript("OnClick", function(self)
		LFGF.PlayClick()
		SetFiltersShown(frame, not frame.filtersShown)
		if self:IsMouseOver() then
			ShowTip(self, frame.filtersShown and L.CLARA_HIDE_FILTERS or L.CLARA_SHOW_FILTERS)
		end
	end)
	toggle:SetScript("OnEnter", function(self)
		ShowTip(self, frame.filtersShown and L.CLARA_HIDE_FILTERS or L.CLARA_SHOW_FILTERS)
	end)
	toggle:SetScript("OnLeave", GameTooltip_Hide)
	frame.FiltersToggle = toggle

	-- The panel's own Search button, while the panel is closed: the game's
	-- Search Again (its refresh arrow), as the game's group browser has one.
	local search = CreateFrame("Button", nil, content, "UIPanelSquareButton")
	search:SetSize(TOGGLE_SIZE, TOGGLE_SIZE)
	search:SetPoint("RIGHT", toggle, "LEFT", -TOGGLE_GAP, 0)
	search.icon:SetTexture([[Interface\Buttons\UI-RefreshButton]])
	search.icon:SetTexCoord(0, 1, 0, 1)
	search.icon:SetSize(14, 14)
	search:SetScript("OnClick", function()
		LFGF.PlayClick()
		filter:RequestSearch()
	end)
	search:SetScript("OnEnter", function(self) ShowTip(self, L.SEARCH_AGAIN) end)
	search:SetScript("OnLeave", GameTooltip_Hide)
	frame.FiltersSearch = search
	-- Usable when the panel's own button is (a category chosen, no search running).
	local function SyncSearch()
		search:SetEnabled(filter.SearchButton:IsEnabled())
	end
	hooksecurefunc(filter, "UpdateSearchState", SyncSearch)
	SyncSearch()

	-- A whisper while the panel is closed: the arrow lit, as the Whispers tab glows, until it is opened.
	EventRegistry:RegisterCallback(LFGF.EVENT_WHISPER_RECEIVED, function()
		if not frame.filtersShown then
			toggle:LockHighlight()
		end
	end, toggle)

	frame.filtersShown = LFGF.SavedValue("filtersShown") == true
	LayFilters(frame)
	if not frame.filtersShown then
		local width = LFGF.ReadableNumbers(frame:GetWidth())
		if width then
			frame:SetWidth(math.max(width - FiltersRoom(frame), WIDTH - FiltersRoom(frame)))
		end
	end
end

-- CLARA: the window in Clara's look -- ClassicUI's old window while ClassicUI
-- runs (its ClaraLFGForeverSkin, Modules/ClassicUI/Windows/ClaraLFGForever.lua,
-- in the version with ClassicUI), else the game's own, as it is.
local function DressWindow(frame)
	local classic = ClaraNS.ClassicUIPrivate
	if not (classic and classic.ClaraLFGForeverSkin) then
		return
	end
	local watcher = CreateFrame("Frame", nil, frame)
	watcher:SetScript("OnShow", function(self)
		self:SetScript("OnShow", nil)
		pcall(classic.ClaraLFGForeverSkin, frame)
	end)
end
'''

EDITS["window.lua"] = [
    ('local function SaveSize(frame)\n', WINDOW_HELPERS.lstrip("\n") + '\nlocal function SaveSize(frame)\n'),
    ('\t\tLFGF.SaveValue("windowWidth", width)\n',
     '\t\tLFGF.SaveValue("windowWidth", width + ClosedRoom(frame)) -- (Clara: the open window\'s width)\n'),
    ('local function BuildWindow()\n', WINDOW_TOGGLE.lstrip("\n") + '\nlocal function BuildWindow()\n'),
    ('\tBuildResizeButton(frame, content)\n\tClampToScreen(frame)\n',
     '\tBuildResizeButton(frame, content)\n'
     '\tBuildFilterToggle(frame, content) -- (Clara)\n'
     '\tClampToScreen(frame)\n'
     '\tframe.Content.CloseButton = closeButton -- (Clara: the close button, for ClassicUI\'s window)\n'
     '\tDressWindow(frame) -- (Clara)\n'),
    ('\t\twindow:SetSize(WIDTH, HEIGHT)\n',
     '\t\twindow:SetSize(WIDTH - ClosedRoom(window), HEIGHT) -- (Clara: the panel as it is)\n'),
]

HEADER_RE = re.compile(r"^local (?:_|addonName), LFGF = \.\.\.\n", re.M)

for name in ORDER:
    path = os.path.join(core, name)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    if name.endswith(".lua"):
        n = len(HEADER_RE.findall(text))
        if n != 1:
            raise SystemExit("%s: %d headers" % (name, n))
        text = HEADER_RE.sub(lambda m: HEADER + "\n", text, count=1)
        text = text.replace("-- LFGForever -- core/", "-- LFGForever -- core/", 1)
    for old, new in EDITS.get(name, []):
        text = once(text, old, new, name)
    if "LFGForeverDB" in re.sub(r"--[^\n]*", "", text).replace("ClaraLFGForeverDB", ""):
        raise SystemExit("%s still names LFGForeverDB in code" % name)
    with open(os.path.join(dst, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

shutil.copy(os.path.join(src, "LICENSE"), os.path.join(dst, "LICENSE"))
print("ported", len(ORDER), "files to", dst)
