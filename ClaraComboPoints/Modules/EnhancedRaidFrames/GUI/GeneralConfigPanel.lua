-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2025 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

-- (Clara Combo Points: the built-in Enhanced Raid Frames' addon object, EnhancedRaidFrames.lua; none
-- while the module does not run)
local _, ClaraNS = ...
local EnhancedRaidFrames = ClaraNS.ERF
if not EnhancedRaidFrames then return end

-- Import libraries
local L = LibStub("AceLocale-3.0"):GetLocale("EnhancedRaidFrames")

-- Constants
local THIRD_WIDTH = 1.25

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Populate our "General" options table for our Blizzard interface options
function EnhancedRaidFrames:CreateGeneralOptions()
	local generalOptions = {
		type = "group",
		childGroups = "tree",
		name = L["General Options"],
		args = {
			instructions = {
				type = "description",
				name = L["generalOptions_desc"],
				fontSize = "medium",
				order = 2,
			},
			-------------------------------------------------
			topSpacer = {
				type = "header",
				name = "",
				order = 3,
			},
			blizzardRaidOptionsButton = {
				type = 'execute',
				name = L["Open the Blizzard Raid Profiles Options"],
				desc = L["blizzardRaidOptionsButton_desc"],
				func = function()
					if not InCombatLockdown() and Settings.INTERFACE_CATEGORY_ID then
						Settings.OpenToCategory(Settings.INTERFACE_CATEGORY_ID, RAID_FRAMES_LABEL)
					end
				end,
				width = THIRD_WIDTH * 1.5,
				order = 4,
			},
			-------------------------------------------------
			textHeader = {
				type = "header",
				name = L["Default Icon Visibility"],
				order = 10,
			},
			-- (WoW Forever: the game draws its frames' own buffs and debuffs in a secure display; they
			-- are shown or hidden in its raid profile options, the button above, not here)
			stockIcons = {
				type = "description",
				name = L["forever_stockIcons_desc"],
				fontSize = "medium",
				order = 11,
			},
			-------------------------------------------------
			visualOptions = {
				type = "header",
				name = L["General"],
				order = 30,
			},
			powerBarOffset = {
				type = "toggle",
				name = L["Power Bar Vertical Offset"],
				desc = L["powerBarOffset_desc"],
				get = function()
					return self.db.profile.powerBarOffset
				end,
				set = function(_, value)
					self.db.profile.powerBarOffset = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 31,
			},
			frameScale = {
				type = "range",
				name = L["Raidframe Scale"],
				desc = L["frameScale_desc"],
				isPercent = true,
				min = 0.5,
				max = 2,
				step = 0.01,
				get = function()
					return self.db.profile.frameScale
				end,
				set = function(_, value)
					self.db.profile.frameScale = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 32,
			},
			backgroundAlpha = {
				type = "range",
				name = L["Background Opacity"],
				desc = L["backgroundAlpha_desc"],
				isPercent = true,
				min = 0,
				max = 1,
				step = 0.01,
				get = function()
					return self.db.profile.backgroundAlpha
				end,
				set = function(_, value)
					self.db.profile.backgroundAlpha = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 33,
			},
			mouseoverCastCompat = {
				type = "toggle",
				name = L["Mouseover Cast Compatibility"],
				desc = L["mouseoverCast_desc"],
				get = function()
					return self.db.profile.mouseoverCastCompat
				end,
				set = function(_, value)
					self.db.profile.mouseoverCastCompat = value
					self:SetAllMouseBehavior()
				end,
				width = THIRD_WIDTH,
				order = 34,
			},
			indicatorFont = {
				type = 'select',
				dialogControl = "LSM30_Font",
				name = L["Indicator Font"],
				desc = L["indicatorFont_desc"],
				values = AceGUIWidgetLSMlists.font,
				get = function()
					return self.db.profile.indicatorFont
				end,
				set = function(_, value)
					self.db.profile.indicatorFont = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 35,
			},
			-------------------------------------------------
			outOfRangeOptions = {
				type = "header",
				name = L["Out-of-Range"],
				order = 40,
			},
			-- (WoW Forever: no custom distance, Forever keeps the distance to group members secret)
			rangeNote = {
				type = "description",
				name = L["forever_range_desc"],
				fontSize = "medium",
				order = 41,
			},
			rangeAlpha = {
				type = "range",
				name = L["Out-of-Range Opacity"],
				desc = L["rangeAlpha_desc"],
				isPercent = true,
				min = 0,
				max = 1,
				step = 0.01,
				get = function()
					return self.db.profile.rangeAlpha
				end,
				set = function(_, value)
					self.db.profile.rangeAlpha = value
					self:RefreshConfig()
				end,
				width = THIRD_WIDTH,
				order = 43,
			},
		}
	}

	return generalOptions
end
