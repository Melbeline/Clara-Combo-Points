-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2025 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

-- (Clara Combo Points: the built-in Enhanced Raid Frames' addon object, EnhancedRaidFrames.lua; none
-- while the module does not run)
local _, ClaraNS = ...
local EnhancedRaidFrames = ClaraNS.ERF
if not EnhancedRaidFrames then return end

local issecretvalue = issecretvalue or function() return false end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

-- (WoW Forever) While auras are secret (combat, and some instances) addons cannot read them: the
-- addon's own indicators wait, the game's aura slots go on (GameAuras.lua)
function EnhancedRaidFrames.AurasSecret()
	if C_Secrets and C_Secrets.ShouldAurasBeSecret then
		local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
		if ok and secret == true then
			return true
		end
	end
	return InCombatLockdown() == true
end

-- (WoW Forever) The debuff types the player can remove, from the spells Forever gives each class
-- (in place of LibDispel, whose Classic spell IDs are only checked on the Classic project)
local DISPELS = {
	DRUID = { [2782] = { "Curse" }, [8946] = { "Poison" }, [2893] = { "Poison" } }, -- Remove Curse, Cure / Abolish Poison
	MAGE = { [475] = { "Curse" } }, -- Remove Lesser Curse
	PALADIN = { [1152] = { "Poison", "Disease" }, [4987] = { "Magic", "Poison", "Disease" } }, -- Purify, Cleanse
	PRIEST = { [527] = { "Magic" }, [988] = { "Magic" }, [528] = { "Disease" }, [552] = { "Disease" } }, -- Dispel Magic, Cure / Abolish Disease
	SHAMAN = { [526] = { "Poison" }, [2870] = { "Disease" }, [8166] = { "Poison" }, [8170] = { "Disease" } }, -- Cure Poison / Disease, their totems
}
-- the Felhunter's Devour Magic, ranks 1 to 4
local PET_DISPELS = { [19505] = "Magic", [19731] = "Magic", [19734] = "Magic", [19736] = "Magic" }

local function Known(id, pet)
	if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
		local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, id, pet and Enum.SpellBookSpellBank.Pet or nil, true)
		if ok and known then
			return true
		end
	end
	if not pet and IsPlayerSpell and IsPlayerSpell(id) then
		return true
	end
	return pet and IsSpellKnown and IsSpellKnown(id, true) or false
end

function EnhancedRaidFrames:UpdateMyDispelTypes()
	local types = {}
	local _, class = UnitClass("player")
	for id, kinds in pairs(DISPELS[class] or {}) do
		if Known(id) then
			for _, kind in ipairs(kinds) do
				types[kind] = true
			end
		end
	end
	if class == "WARLOCK" then
		for id, kind in pairs(PET_DISPELS) do
			if Known(id, true) then
				types[kind] = true
			end
		end
	end
	self.myDispelTypes = types
	if self.UpdateAllGameAuraFilters then
		self:UpdateAllGameAuraFilters()
	end
end

function EnhancedRaidFrames:GetMyDispelTypes()
	return self.myDispelTypes or {}
end


--- Creates a listener for the UNIT_AURA event attached to a specified raid frame
---@param frame table @The raid frame to create the listener for
function EnhancedRaidFrames:CreateAuraListener(frame)
	-- Skip the visibility check in ShouldContinue() as we need the listener to exist even if the frame is hidden
	if not self.ShouldContinue(frame, true) then
		return
	end

	-- To stop us from creating redundant frames we should try to re-capture them when possible.
	if not _G[frame:GetName() .. "-ERF_auraListenerFrame"] then
		frame.ERF_auraListenerFrame = CreateFrame("Frame", frame:GetName() .. "-ERF_auraListenerFrame", frame)
	else
		frame.ERF_auraListenerFrame = _G[frame:GetName() .. "-ERF_auraListenerFrame"]
		-- If we capture an old indicator frame, we should reattach it to the current unit frame.
		frame.ERF_auraListenerFrame:SetParent(frame)
	end

	-- Register the unit event
	frame.ERF_auraListenerFrame:UnregisterAllEvents() -- Clear any existing events
	frame.ERF_auraListenerFrame:RegisterUnitEvent("UNIT_AURA", frame.unit)

	-- Assign the OnEvent callback for the listener frame
	-- (WoW Forever has the UNIT_AURA payload of 10.0: the Classic path is left out)
	frame.ERF_auraListenerFrame:SetScript("OnEvent", function(_, _, _, payload)
		self:UpdateUnitAuras(frame, payload or {})
	end)
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Scans all raid frame units and updates the unitAuras table with all auras on each unit.
function EnhancedRaidFrames:UpdateAllAuras()
	-- Iterate over all raid frame units, forcing a full refresh and re-creating the listener frame
	-- It is important that we re-create the listener frame for each unit to ensure that the listener is attached to the correct unit
	CompactRaidFrameContainer:ApplyToFrames("normal", function(frame)
		self:UpdateUnitAuras(frame, {}, true)
	end)
end

--- Called by our UNIT_AURA listeners and is used to store unit aura information for a given unit.
--- Unit aura information for tracked auras is stored in the ERF_unitAuras table.
--- It uses the C_UnitAuras API that was added in 10.0.
---@param parentFrame table @The raid frame to update
---@param payload table @The payload from the UNIT_AURA event
---@param forceRefresh boolean @Whether or not to force a full refresh
function EnhancedRaidFrames:UpdateUnitAuras(parentFrame, payload, forceRefresh)
	if not self.ShouldContinue(parentFrame) then
		return
	end

	-- (WoW Forever) Secret auras: nothing read; the addon's own indicators cleared (the game's slots
	-- show what they can), read again once combat ends (PLAYER_REGEN_ENABLED)
	if self.AurasSecret() then
		if not parentFrame.ERF_auraListenerFrame or forceRefresh then
			self:CreateAuraListener(parentFrame)
		end
		if parentFrame.ERF_unitAuras ~= nil or forceRefresh then
			parentFrame.ERF_unitAuras = nil
			self:UpdateIndicators(parentFrame)
		end
		return
	end
	
	-- Create a listener frame for the unit if we don't happen to have one yet, or we're forcing a re-creation
	if not parentFrame.ERF_auraListenerFrame or forceRefresh then
		self:CreateAuraListener(parentFrame)
		payload.isFullUpdate = true -- Force a full update if we're forcing a refresh
	end
	
	-- Create the main table for the unit
	if not parentFrame.ERF_unitAuras then
		parentFrame.ERF_unitAuras = {}
		payload.isFullUpdate = true -- Force a full update if we don't have a table for the unit yet
	end

	-- Flag to determine if we need to run an update on the indicators since we only care about select auras
	-- This should filter out a lot of unnecessary updates from triggering an indicator update
	local shouldRunUpdate = false
	
	-- If we get a full update signal, reset the table and rescan all auras for the unit
	if payload.isFullUpdate then
		-- Clear out the table
		parentFrame.ERF_unitAuras = {}
		-- Iterate through all buffs and debuffs on the unit
		for _, filter in pairs({ "HELPFUL", "HARMFUL" }) do
			AuraUtil.ForEachAura(parentFrame.unit, filter, nil, function(auraData)
				-- Add our auraData to the ERF_unitAuras table
				local updateFlag = self:addToAuraTable(parentFrame, auraData)
				if updateFlag then
					shouldRunUpdate = true
				end
			end, true);
		end
	end

	-- If one or more new auras were added, update the table with their payload information
	if payload.addedAuras then
		for _, auraData in pairs(payload.addedAuras) do
			-- Add our auraData to the ERF_unitAuras table
			local updateFlag = self:addToAuraTable(parentFrame, auraData)
			if updateFlag then
				shouldRunUpdate = true
			end
		end
	end

	-- If one or more auras were updated, query their updated information and add it to the table
	if payload.updatedAuraInstanceIDs then
		for _, auraInstanceID in pairs(payload.updatedAuraInstanceIDs) do
			local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(parentFrame.unit, auraInstanceID)
			-- Though rare, it is possible for auraData to be nil if the aura was removed just prior to us querying it.
			if auraData then
				-- Add our auraData to the ERF_unitAuras table
				local updateFlag = self:addToAuraTable(parentFrame, auraData)
				if updateFlag then
					shouldRunUpdate = true
				end
			end
		end
	end

	-- If one or more auras was removed, remove them from the table
	if payload.removedAuraInstanceIDs then
		for _, auraInstanceID in pairs(payload.removedAuraInstanceIDs) do
			if parentFrame.ERF_unitAuras[auraInstanceID] then
				-- Set the table entry to nil to remove it
				parentFrame.ERF_unitAuras[auraInstanceID] = nil
				shouldRunUpdate = true
			end
		end
	end

	-- Only update the indicators if we added, updated, or removed a tracked aura
	if shouldRunUpdate then
		self:UpdateIndicators(parentFrame)
	end
end

--- Add or update an aura to the ERFAuras table
---@param parentFrame table @The raid frame that we're updating
---@param auraData table @Payload from UNIT_AURA event
---@return boolean @True if we added or updated an aura
function EnhancedRaidFrames:addToAuraTable(parentFrame, auraData)
	-- (WoW Forever) A secret aura is never compared or kept; no bleed type there
	if not auraData or issecretvalue(auraData) or issecretvalue(auraData.name) or issecretvalue(auraData.spellId)
			or issecretvalue(auraData.dispelName) or issecretvalue(auraData.isHarmful) or type(auraData.name) ~= "string" then
		return false
	end
	
	-- Quickly check if we're watching for this aura, and ignore if we aren't
	-- It's important to use the 4th argument in string.find to turn off pattern matching, 
	-- otherwise strings with parentheses in them will fail to be found
	if self.allAuras:find(" " .. auraData.name:lower() .. " ", 1, true)
			or self.allAuras:find(auraData.spellId, 1, true)
			-- Check if the aura is a debuff, if aura string contains the "dispel" wildcard, and if the player can dispel this type
			or (auraData.isHarmful and self.allAuras:find("dispel", 1, true) and auraData.dispelName and self:GetMyDispelTypes()[auraData.dispelName])
			-- Check if the aura is a debuff, and if it has a dispelName see if we're tracking the wildcard for it
			or (auraData.isHarmful and auraData.dispelName and auraData.dispelName ~= "" and self.allAuras:find(auraData.dispelName:lower(), 1, true)) then

		-- Lowercase the aura name for consistency
		auraData.name = auraData.name:lower()

		-- (WoW Forever) The spell ID a watched name was seen under, for the game's aura slots
		if auraData.isHelpful and type(auraData.spellId) == "number" then
			self:LearnAuraID(auraData.name, auraData.spellId)
		end

		if auraData.auraInstanceID then
			-- For 10.0 and newer
			-- Add our auraData to the ERF_unitAuras table using the auraInstanceID as the key
			parentFrame.ERF_unitAuras[auraData.auraInstanceID] = auraData
		else
			-- For 9.x and older
			-- Append our auraData to the ERF_unitAuras table
			table.insert(parentFrame.ERF_unitAuras, auraData)
		end

		-- Return true if we added or updated an aura
		return true
	end
end
