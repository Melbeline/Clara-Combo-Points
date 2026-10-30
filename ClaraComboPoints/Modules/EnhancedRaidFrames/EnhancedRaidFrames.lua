-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2025 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

--- EnhancedRaidFrames is the main addon object for the Enhanced Raid Frames add-on.
-- (Clara Combo Points: kept in the module's shared table, not a global; only while it runs, Bootstrap.lua)
local _, ClaraNS = ...
if not ClaraNS.ERFRuns then return end
---@class EnhancedRaidFrames : AceAddon-3.0 @The main addon object for the Enhanced Raid Frames add-on
ClaraNS.ERF = LibStub("AceAddon-3.0"):NewAddon("EnhancedRaidFrames", "AceTimer-3.0", "AceHook-3.0",
		"AceEvent-3.0", "AceBucket-3.0", "AceConsole-3.0", "AceSerializer-3.0")
local EnhancedRaidFrames = ClaraNS.ERF

-- Import libraries
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Called directly after the addon is fully loaded.
--- We do initialization tasks here, such as loading our saved variables or setting up slash commands.
function EnhancedRaidFrames:OnInitialize()
	-- Set up our database
	self:InitializeDatabase()

	-- Run our database migration if necessary
	self:MigrateDatabase()

	-- Setup config panels in the Blizzard interface options
	self:InitializeConfigPanels()

	-- Register callbacks for profile switching
	self.db.RegisterCallback(self, "OnProfileChanged", function()
		self:MigrateDatabase()
		self:RefreshConfig()
	end)
	self.db.RegisterCallback(self, "OnProfileCopied", function()
		self:MigrateDatabase()
		self:RefreshConfig()
	end)
	self.db.RegisterCallback(self, "OnProfileReset", function()
		self:MigrateDatabase()
		self:RefreshConfig()
	end)

	-- (Clara Combo Points) Its main box in the Improvements tab
	ClaraNS:SetQolSwitches("enhancedraidframes", {
		{ label = "ERF_SW_MARKERS", get = function() return self.db.profile.showTargetMarkers end,
		  set = function(on) self.db.profile.showTargetMarkers = on and true or false; self:RefreshConfig() end },
	})
end

--- Called during the PLAYER_LOGIN event when most of the data provided by the game is already present.
--- We perform more startup tasks here, such as registering events, hooking functions, creating frames, or getting 
--- information from the game that wasn't yet available during :OnInitialize()
function EnhancedRaidFrames:OnEnable()
	-- (WoW Forever) The debuff types the player can remove, for the "Dispel" wildcard (AuraListeners.lua)
	self:UpdateMyDispelTypes()

	-- Populate our starting config values
	self:RefreshConfig()
	
	-- Run a full update of all auras for a starting point
	self:UpdateAllAuras()

	-- (THROTTLED) Force a full update of all group member's auras when the group roster changes
	self:RegisterBucketEvent("GROUP_ROSTER_UPDATE", 1, function() -- 1 second throttle to avoid lagging the game
		self:UpdateAllAuras()
	end)

	-- Force a full update of all stock aura visibilities, target markers, and ranges when the group roster changes
	self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		self:UpdateAllStockAuraVisibility()
		self:UpdateAllTargetMarkers()
	end)

	-- Force a full update of all frames when a raid target icon changes
	self:RegisterEvent("RAID_TARGET_UPDATE", function()
		self:UpdateAllTargetMarkers()
	end)

	-- Hook our UpdateInRange function to the default CompactUnitFrame_UpdateInRange function.
	-- Using SecureHook ensures that our function will run 'after' the default function, which is what we want.
	self:SecureHook("CompactUnitFrame_UpdateInRange", function(frame)
		self:UpdateInRange(frame)
	end)
	-- (WoW Forever: the frame's alpha is set again by the game when its center status icon updates)
	if CompactUnitFrame_UpdateCenterStatusIcon then
		self:SecureHook("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
			self:UpdateInRange(frame)
		end)
	end

	-- (WoW Forever) A frame given another unit: its game aura slots follow (GameAuras.lua)
	if CompactUnitFrame_SetUnit then
		self:SecureHook("CompactUnitFrame_SetUnit", function(frame)
			self:UpdateGameAuraUnit(frame)
		end)
	end

	-- (WoW Forever) In combat the auras are secret: the addon's own indicators wait (the game's aura
	-- slots go on), and are read again as it ends; frames that came meanwhile get their slots then
	self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		self:UpdateAllAuras()
	end)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		self:SetUpPendingGameAuras()
		self:UpdateAllAuras()
		self:UpdateAllTargetMarkers()
	end)
	self:RegisterEvent("SPELLS_CHANGED", function()
		self:UpdateMyDispelTypes()
	end)

	-- Register our slash command to open the config panel
	self:RegisterChatCommand("erf", function()
		ClaraNS:OpenSettingsTo(ClaraNS.erfCategory)
	end)
end

--- Called when our addon is manually being disabled during a running session.
--- We primarily use this to unhook scripts, unregister events, or hide frames that we created.
function EnhancedRaidFrames:OnDisable()
	-- Empty --
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Create a table containing our default database values
function EnhancedRaidFrames:InitializeDatabase()
	-- Set up database defaults
	local defaults = self:CreateDefaults()

	-- Create database object
	-- (Clara Combo Points: ClaraEnhancedRaidFramesDB, the standalone's EnhancedRaidFramesDB carried over
	-- into it once, Bootstrap.lua; no LibDualSpec on WoW Forever)
	self.db = AceDB:New("ClaraEnhancedRaidFramesDB", defaults)
end

--- Set up our configuration panels and add them to the Blizzard interface options
function EnhancedRaidFrames:InitializeConfigPanels()
	-- Build our config panels
	AceConfigRegistry:RegisterOptionsTable("Enhanced Raid Frames", self:CreateGeneralOptions())
	AceConfigRegistry:RegisterOptionsTable("ERF Indicator Options", self:CreateIndicatorOptions())
	AceConfigRegistry:RegisterOptionsTable("ERF Target Marker Options", self:CreateIconOptions())
	AceConfigRegistry:RegisterOptionsTable("ERF Profiles", AceDBOptions:GetOptionsTable(self.db))
	AceConfigRegistry:RegisterOptionsTable("ERF Import Export Profile Options", self:CreateProfileImportExportOptions())

	-- Add to config panels to in-game interface options
	-- (Clara Combo Points: under Interface improvements, its four pages under its own)
	local _, main = AceConfigDialog:AddToBlizOptions("Enhanced Raid Frames", "Enhanced Raid Frames",
			ClaraNS.qolCategory and ClaraNS.qolCategory:GetID() or nil)
	ClaraNS.erfCategory = main and Settings.GetCategory and Settings.GetCategory(main) or main
	AceConfigDialog:AddToBlizOptions("ERF Indicator Options", L["Indicator Options"], main)
	AceConfigDialog:AddToBlizOptions("ERF Target Marker Options", L["Target Marker Options"], main)
	AceConfigDialog:AddToBlizOptions("ERF Profiles", L["Profiles"], main)
	AceConfigDialog:AddToBlizOptions("ERF Import Export Profile Options",
			(L["Profile"] .. " " .. L["Import"] .. "/" .. L["Export"]), main)
end

--- Refresh everything that is affected by changes to the configuration
function EnhancedRaidFrames:RefreshConfig()
	self:GenerateAuraStrings()
	self:UpdateAllGameAuraFilters() -- (WoW Forever: what the game's aura slots show, GameAuras.lua)
	self:UpdateAllAuras() -- Update all auras to reflect new settings
	self:UpdateScale()
	if CompactRaidFrameContainer and CompactRaidFrameContainer.ApplyToFrames then
		-- 10.0 refactored CompactRaidFrameContainer with new functionality
		CompactRaidFrameContainer:ApplyToFrames("normal", function(frame)
			self:UpdateIndicators(frame, true)
			self:UpdateBackgroundAlpha(frame)
			self:UpdateInRange(frame)
			self:UpdateTargetMarker(frame, true)
			self:UpdateStockAuraVisibility(frame)
		end)
	else
		CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "normal", function(frame)
			self:UpdateIndicators(frame, true)
			self:UpdateBackgroundAlpha(frame)
			self:UpdateInRange(frame)
			self:UpdateTargetMarker(frame, true)
			self:UpdateStockAuraVisibility(frame)
		end)
	end
end