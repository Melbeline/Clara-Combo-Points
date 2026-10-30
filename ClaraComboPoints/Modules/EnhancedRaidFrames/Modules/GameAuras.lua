-- Clara Combo Points - Enhanced Raid Frames on WoW Forever: the game's aura slots over each indicator.
-- In combat (and in some instances) Forever hides auras from addons; its aura containers, made for
-- addons, still show them: each indicator gets one of the game's aura buttons for buffs and one for
-- debuffs, told what to show, and the game fills them itself (icon, swipe, time left, stacks), in
-- combat too. On a group member the game matches buffs by spell ID and debuffs by type only:
--   buffs, by name or spell ID: every rank of the name (Clara's spell catalog), the IDs it was seen
--     under out of combat, and the one the player knows;
--   debuffs by type: Magic, Curse, Poison, Disease, and "Dispel" (the types the player can remove).
-- Debuffs named one by one and "missing only" indicators stay the addon's own reading (AuraIndicators.lua),
-- shown while auras are readable. Its look follows the indicator's settings, set while auras are
-- readable (the game closes its buttons to addons while they are secret: changes wait until then).

-- (Clara Combo Points: the built-in Enhanced Raid Frames' addon object, EnhancedRaidFrames.lua; none
-- while the module does not run)
local _, ClaraNS = ...
local EnhancedRaidFrames = ClaraNS.ERF
if not EnhancedRaidFrames then return end
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

local TEMPLATE = "CustomAuraContainerTemplate"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DISPEL_WILDCARDS = { magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease" }
local KINDS = { "HELPFUL", "HARMFUL" }

-- What each indicator's slots show: watch[i] = { ids = set, types = set, mine, meOnly } (nil: none)
local watch = {}
EnhancedRaidFrames.gameAuraWatch = watch

local frames = {} -- the raid frames that have slots
local pending = {} -- frames waiting for combat to end (slots made, or restyled, only then)

-- (a call the game refuses is skipped; its message kept for a report: EnhancedRaidFrames.gameAuraError)
local function Pcall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then EnhancedRaidFrames.gameAuraError = err end
	return ok, err
end

-------------------------------------------------------------------------
-- What to show
-------------------------------------------------------------------------

--- The spell IDs a name stands for: the ranks Clara's catalog knows, the ones it was seen under,
--- and the one the player knows by that name
---@param name string @A lowercased aura name
---@param ids table @The set to add them to
function EnhancedRaidFrames:AddNameIDs(name, ids)
	if ClaraNS.CatalogRecords then
		local ok, records = Pcall(ClaraNS.CatalogRecords, ClaraNS, nil, name)
		for _, rec in ipairs(ok and records or {}) do
			for _, r in ipairs(rec.ranks or {}) do
				if r[2] then ids[r[2]] = true end
				if r[3] then ids[r[3]] = true end
			end
		end
	end
	local learned = self.db.global.auraIDs and self.db.global.auraIDs[name]
	for id in pairs(learned or {}) do
		ids[id] = true
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = Pcall(C_Spell.GetSpellInfo, name)
		if ok and type(info) == "table" and type(info.spellID) == "number" then
			ids[info.spellID] = true
		end
	end
end

--- Rebuilds what each indicator's slots show, from its aura list and settings
function EnhancedRaidFrames:BuildGameAuraWatch()
	local myTypes = self:GetMyDispelTypes()
	for i = 1, 9 do
		local cfg = self.db.profile["indicator-" .. i]
		local entries = self.auraStrings and self.auraStrings[i] or {}
		local w
		if not cfg.missingOnly and entries[1] then
			local ids, types = {}, {}
			for _, entry in ipairs(entries) do
				if DISPEL_WILDCARDS[entry] then
					types[DISPEL_WILDCARDS[entry]] = true
				elseif entry == "dispel" then
					for kind in pairs(myTypes) do
						types[kind] = true
					end
				elseif tonumber(entry) then
					ids[tonumber(entry)] = true
				elseif entry ~= "bleed" then -- (no bleed type on WoW Forever)
					self:AddNameIDs(entry, ids)
				end
			end
			w = { ids = next(ids) and ids or nil, types = next(types) and types or nil,
				  mine = cfg.mineOnly or nil, meOnly = cfg.meOnly }
		end
		watch[i] = w
	end
end

--- What of this indicator shows out of combat only (WoW Forever): a line for its options, under its list
---@param i number @The indicator position
---@return string @Empty when all of it shows in combat too
function EnhancedRaidFrames:CombatNote(i)
	local cfg = self.db.profile["indicator-" .. i]
	local entries = self.auraStrings and self.auraStrings[i] or {}
	if not entries[1] then
		return ""
	end
	if cfg.missingOnly then
		return self.RED_COLOR:WrapTextInColorCode(L["forever_note_missing"])
	end
	local lines, debuffs = {}, {}
	for _, entry in ipairs(entries) do
		if entry == "bleed" then
			lines[#lines + 1] = L["forever_note_bleed"]
		elseif not DISPEL_WILDCARDS[entry] and entry ~= "dispel" and ClaraNS.CatalogRecords then
			-- (a debuff Clara's catalog knows by that name or ID: the game's slots show debuffs by type only)
			local ok, records = Pcall(ClaraNS.CatalogRecords, ClaraNS, tonumber(entry), not tonumber(entry) and entry or nil)
			for _, rec in ipairs(ok and records or {}) do
				if rec.kind == "DEBUFF" then
					debuffs[#debuffs + 1] = rec.name or entry
					break
				end
			end
		end
	end
	if debuffs[1] then
		table.insert(lines, 1, L["forever_note_debuffs"]:format(table.concat(debuffs, ", ")))
	end
	return #lines > 0 and self.RED_COLOR:WrapTextInColorCode(table.concat(lines, "\n")) or ""
end

--- Does the game's slot of this indicator show this aura? (Then the addon's own indicator does not.)
---@param i number @The indicator position
---@param aura table @A readable aura (AuraListeners.lua)
function EnhancedRaidFrames:GameAuraCovers(i, aura)
	local w = watch[i]
	if not w or not self.gameAurasAvailable then
		return false
	end
	if aura.isHelpful then
		return w.ids ~= nil and w.ids[aura.spellId] == true
	end
	return aura.isHarmful and w.types ~= nil and aura.dispelName ~= nil and w.types[aura.dispelName] == true or false
end

--- A watched name seen under a spell ID: its slots take that ID too (once per frame at most)
---@param name string @The lowercased aura name
---@param id number @Its spell ID
function EnhancedRaidFrames:LearnAuraID(name, id)
	local all = self.db.global.auraIDs or {}
	self.db.global.auraIDs = all
	all[name] = all[name] or {}
	if all[name][id] then
		return
	end
	all[name][id] = true
	if not self.learnPending then
		self.learnPending = true
		C_Timer.After(0, function()
			self.learnPending = nil
			self:UpdateAllGameAuraFilters()
		end)
	end
end

-------------------------------------------------------------------------
-- The slots
-------------------------------------------------------------------------

local function SlotKey(frame, i, kind)
	return "ERF" .. frame:GetName() .. "-" .. i .. kind
end

--- Gives a raid frame its container and two slots per indicator (out of combat)
---@param frame table @The raid frame
function EnhancedRaidFrames:SetUpGameAuras(frame)
	if frame.ERF_auraContainer == false or not frame.ERF_indicatorFrames then
		return
	end
	if InCombatLockdown() or self.AurasSecret() then
		pending[frame] = true
		return
	end
	local container = frame.ERF_auraContainer
	if not container then
		local ok, made = Pcall(CreateFrame, "AuraContainer", nil, frame, TEMPLATE)
		if not ok or not made or not made.AddAuraSlot then
			frame.ERF_auraContainer = false -- (not this client)
			return
		end
		container = made
		container:SetPoint("TOPLEFT", frame, "TOPLEFT")
		container:SetSize(1, 1)
		container:SetFrameLevel(frame:GetFrameLevel() + 4)
		if container.SetEditModePreviewEnabled then
			container:SetEditModePreviewEnabled(false)
		end
		frame.ERF_auraContainer = container
		frame.ERF_slots = {}
		self.gameAurasAvailable = true
	end
	for i = 1, 9 do
		frame.ERF_slots[i] = frame.ERF_slots[i] or {}
		for _, kind in ipairs(KINDS) do
			if not frame.ERF_slots[i][kind] then
				local rec = { key = SlotKey(frame, i, kind), enabled = true }
				local ok = Pcall(container.AddAuraSlot, container, rec.key, kind, {
					candidateFilters = { includeSpellIDs = {} },
					initializeFrame = function(button)
						button:SetAllPoints(frame.ERF_indicatorFrames[i])
						if button.EnableMouse then
							button:EnableMouse(false) -- (clicks go to the raid frame)
						end
						rec.button = button
						rec.icon = button:CreateTexture(nil, "ARTWORK")
						rec.icon:SetAllPoints()
						rec.square = button:CreateTexture(nil, "ARTWORK")
						rec.square:SetAllPoints()
						rec.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
						rec.cooldown:SetAllPoints()
						rec.cooldown:SetReverse(true)
						rec.cooldown:SetDrawBling(false)
						rec.cooldown:SetDrawEdge(false)
						if rec.cooldown.SetHideCountdownNumbers then
							rec.cooldown:SetHideCountdownNumbers(true)
						end
						local over = CreateFrame("Frame", nil, button)
						over:SetAllPoints()
						over:SetFrameLevel(rec.cooldown:GetFrameLevel() + 2)
						rec.countdown = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
						rec.countdown:SetPoint("CENTER")
						rec.stack = over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
						rec.stack:SetJustifyH("RIGHT")
						self:StyleGameAuraSlot(rec, i)
					end,
				})
				if ok and rec.button then
					frame.ERF_slots[i][kind] = rec
					Pcall(container.SetAuraSlotEnabled, container, rec.key, false)
					rec.enabled = false
				end
			end
		end
	end
	frames[frame] = true
	pending[frame] = nil
	self:UpdateGameAuraUnit(frame)
end

--- Frames that came (or changed look) during combat: set up now
function EnhancedRaidFrames:SetUpPendingGameAuras()
	for frame in pairs(pending) do
		pending[frame] = nil
		self:SetUpGameAuras(frame)
		self:StyleGameAuras(frame)
	end
end

--- The slots' look, from the indicator's settings (while auras are readable)
---@param rec table @A slot
---@param i number @Its indicator position
function EnhancedRaidFrames:StyleGameAuraSlot(rec, i)
	local cfg = self.db.profile["indicator-" .. i]
	local button = rec.button
	button:SetAlpha(cfg.indicatorAlpha)

	-- the aura's icon, or a square of color (by debuff type, or the indicator's color)
	if button.ClearDispelTypeTextures then
		button:ClearDispelTypeTextures()
	end
	if cfg.showIcon then
		rec.square:Hide()
		rec.icon:Show()
		button:SetIcon(rec.icon)
	else
		if button.ClearIcon then
			button:ClearIcon()
		end
		rec.icon:Hide()
		rec.square:SetTexture(WHITE)
		local base = cfg.indicatorColor
		local function Color(c) return { r = c.r, g = c.g, b = c.b } end
		local colors = { None = { r = base[1], g = base[2], b = base[3] } }
		for _, kind in ipairs({ "Magic", "Curse", "Poison", "Disease" }) do
			colors[kind] = colors.None
		end
		if cfg.colorIndicatorByDebuff then
			colors.Magic, colors.Curse = Color(self.BLUE_COLOR), Color(self.PURPLE_COLOR)
			colors.Poison, colors.Disease = Color(self.GREEN_COLOR), Color(self.BROWN_COLOR)
		end
		local assets = {}
		for kind in pairs(colors) do
			assets[kind] = { asset = WHITE }
		end
		Pcall(button.AddDispelTypeTexture, button, rec.square, {
			showWhenHelpful = true, showWhenHarmful = true, showWithoutDispelType = true,
			style = Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
			customDispelAssetMap = assets, customDispelColorMap = colors,
		})
	end

	-- the swipe
	if cfg.showCountdownSwipe then
		button:SetDurationCooldown(rec.cooldown)
	else
		button:ClearDurationCooldown()
		rec.cooldown:Hide()
	end

	-- the time left, colored by it (red, then yellow, then the text's color) if so set
	local font = LibStub("LibSharedMedia-3.0"):Fetch("font", self.db.profile.indicatorFont) or "Fonts\\ARIALN.TTF"
	if cfg.showCountdownText then
		rec.countdown:SetFont(font, cfg.textSize, "OUTLINE")
		rec.countdown:SetTextColor(unpack(cfg.textColor))
		local options
		if cfg.colorTextByTime and C_CurveUtil and C_CurveUtil.CreateColorCurve then
			local curve = C_CurveUtil.CreateColorCurve()
			if curve.SetType and Enum.LuaCurveType then
				curve:SetType(Enum.LuaCurveType.Step)
			end
			curve:AddPoint(0, self.RED_COLOR)
			if cfg.colorTextByTime_low ~= 0 then
				curve:AddPoint(cfg.colorTextByTime_low + 0.5, cfg.colorTextByTime_high ~= 0 and self.YELLOW_COLOR or CreateColor(unpack(cfg.textColor)))
			end
			if cfg.colorTextByTime_high ~= 0 then
				curve:AddPoint(cfg.colorTextByTime_high + 0.5, CreateColor(unpack(cfg.textColor)))
			end
			options = { textColor = { curve = curve, property = Enum.DurationTextBindingProperty
				and Enum.DurationTextBindingProperty.RemainingDuration or 0 } }
		end
		button:SetDurationText(rec.countdown, options)
	else
		button:ClearDurationText()
		rec.countdown:SetText("")
	end

	-- the stacks
	if cfg.showStackSize then
		rec.stack:ClearAllPoints()
		local where = cfg.stackSizeLocation or "BOTTOMRIGHT"
		local x = where:find("LEFT") and -3 or 4
		local y = where:find("TOP") and 2 or -2
		rec.stack:SetPoint(where, button, where, x, y)
		button:SetApplicationCount(rec.stack)
	else
		button:ClearApplicationCount()
		rec.stack:SetText("")
	end
end

--- Every slot of a frame takes the settings' look (waits for readable auras)
---@param frame table @The raid frame
function EnhancedRaidFrames:StyleGameAuras(frame)
	if not frame.ERF_slots then
		return
	end
	if self.AurasSecret() then
		pending[frame] = true
		return
	end
	for i, slots in pairs(frame.ERF_slots) do
		for _, rec in pairs(slots) do
			Pcall(self.StyleGameAuraSlot, self, rec, i)
		end
	end
end

--- The frame's unit: its container watches it, and its slots what they show for it
---@param frame table @The raid frame
function EnhancedRaidFrames:UpdateGameAuraUnit(frame)
	local container = frame.ERF_auraContainer
	if not container then
		return
	end
	if frame.unit and container.ERF_unit ~= frame.unit then
		if Pcall(container.SetUnit, container, frame.unit) then
			container.ERF_unit = frame.unit
		end
	end
	self:UpdateGameAuraFilters(frame)
end

local function SetKey(set)
	if not set then return "" end
	local list = {}
	for k in pairs(set) do list[#list + 1] = tostring(k) end
	table.sort(list)
	return table.concat(list, ",")
end

--- Each slot of a frame told what to show, and turned on or off (the game takes this in combat too)
---@param frame table @The raid frame
function EnhancedRaidFrames:UpdateGameAuraFilters(frame)
	local container = frame.ERF_auraContainer
	if not container or not frame.ERF_slots then
		return
	end
	for i = 1, 9 do
		local w = watch[i]
		local slots = frame.ERF_slots[i] or {}
		for _, kind in ipairs(KINDS) do
			local rec = slots[kind]
			if rec then
				local set = w and (kind == "HELPFUL" and w.ids or kind == "HARMFUL" and w.types)
				local on = set ~= nil and set ~= false and (not w.meOnly or frame.unit == "player")
				if on then
					local key = SetKey(set) .. (w.mine and "|mine" or "")
					if rec.filterKey ~= key then
						local filters = { isFromPlayerOrPlayerPet = w.mine }
						if kind == "HELPFUL" then
							filters.includeSpellIDs = set
						else
							filters.includeDispelTypes = set
						end
						if Pcall(container.SetAuraSlotCandidateFilters, container, rec.key, filters) then
							rec.filterKey = key
						end
					end
				end
				if rec.enabled ~= on and Pcall(container.SetAuraSlotEnabled, container, rec.key, on) then
					rec.enabled = on
				end
			end
		end
	end
end

--- What every frame's slots show, after the settings, the player's dispels or a learned ID changed
function EnhancedRaidFrames:UpdateAllGameAuraFilters()
	if not self.db or not self.auraStrings then
		return
	end
	self:BuildGameAuraWatch()
	for frame in pairs(frames) do
		self:UpdateGameAuraFilters(frame)
	end
end
