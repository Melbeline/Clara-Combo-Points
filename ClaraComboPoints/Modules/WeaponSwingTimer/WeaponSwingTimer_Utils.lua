local _, ClaraNS = ...
local E = ClaraNS.WST
if not E then return end -- (Clara Combo Points, QoL.lua: the module does not run)
setfenv(1, E.env) -- its globals are its own (Env.lua)
local addon_name, addon_data = "ClaraWST", E.data

addon_data.utils = {}

-- Sends the given message to the chat frame with the addon name in front.
addon_data.utils.PrintMsg = function(msg)
	local chat_msg = "|cFF00FFB0WeaponSwingTimer: |r" .. msg
	DEFAULT_CHAT_FRAME:AddMessage(chat_msg)
end

-- Rounds the given number to the given step.
-- If num was 1.17 and step was 0.1 then this would return 1.1
addon_data.utils.SimpleRound = function(num, step)
    return floor(num / step) * step
end

-- used for searching through nested tables
addon_data.utils.DeepCopy = function(src, dst)
    if type(src) ~= "table" then return src end
    dst = dst or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = addon_data.utils.DeepCopy(v, {})
        else
            dst[k] = v
        end
    end
    return dst
end