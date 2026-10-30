-- Enhanced Raid Frames is a World of Warcraft® user interface addon.
-- Copyright (c) 2017-2025 Britt W. Yazel
-- This code is licensed under the MIT license (see LICENSE for details)

-- (Clara Combo Points: the built-in Enhanced Raid Frames' addon object, EnhancedRaidFrames.lua; none
-- while the module does not run)
local _, ClaraNS = ...
local EnhancedRaidFrames = ClaraNS.ERF
if not EnhancedRaidFrames then return end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

--- Set the visibility on the stock buff/debuff frames
--- (WoW Forever: the game draws its raid frames' buffs and debuffs itself, in a secure display that
--- addons must not touch; they are shown or hidden in the game's raid profile options, which the
--- General page opens. Nothing is hooked here.)
function EnhancedRaidFrames:UpdateAllStockAuraVisibility()
end

---@param frame table @The frame to set the visibility on
function EnhancedRaidFrames:UpdateStockAuraVisibility(frame)
end

local issecretvalue = issecretvalue or function() return false end

--- Updates the frame alpha based on if a unit is in range or not.
--- This function is secure hooked to the CompactUnitFrame_UpdateInRange function.
--- (WoW Forever: the game's in-range value is secret to addons, so it is never read here: the
--- game's own conclusion, frame.outOfRange, is handed to SetAlphaFromBoolean; no custom distance,
--- Forever hides distances. The game's "fade out of range" setting off: left alone.)
---@param frame table @The frame to update the alpha on
function EnhancedRaidFrames:UpdateInRange(frame)
	if not self.ShouldContinue(frame, true) then
		return
	end
	if frame.optionTable and not frame.optionTable.fadeOutOfRange then
		return
	end

	local outOfRange = frame.outOfRange
	if outOfRange == nil then
		return
	end
	if issecretvalue(outOfRange) then
		frame:SetAlphaFromBoolean(outOfRange, self.db.profile.rangeAlpha, 1)
	elseif outOfRange then
		frame:SetAlpha(self.db.profile.rangeAlpha)
	else
		frame:SetAlpha(1)
	end
end

--- Set the background alpha amount based on a defined value by the user.
---@param frame table @The frame to set the background alpha on
function EnhancedRaidFrames:UpdateBackgroundAlpha(frame)
	if not self.ShouldContinue(frame) then
		return
	end

	-- Set the background alpha to the user defined value
	frame.background:SetAlpha(self.db.profile.backgroundAlpha)
end

--- Set the scale of the overall raid frame container.
function EnhancedRaidFrames:UpdateScale()
	if not InCombatLockdown() then
		CompactRaidFrameContainer:SetScale(self.db.profile.frameScale)
		if CompactPartyFrame then
			CompactPartyFrame:SetScale(self.db.profile.frameScale)
		end
	end
end