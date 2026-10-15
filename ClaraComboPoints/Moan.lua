-- Clara Combo Points - /moan, the emote of the original game (patch 1.12): "<Name> moans
-- suggestively." or, with a target (the one selected, or a name typed after it), "<Name> moans
-- suggestively at <Target>." Sent as an emote, so everyone around sees it. (The game never had a
-- voice for it: no character sound file of the game is a moan.) Nothing to set.

local _, ns = ...
local L = ns.L

local Send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

-- Who it is aimed at: a name typed after /moan, else the target (not yourself).
local function Target(msg)
  local name = type(msg) == "string" and msg:match("^%s*(%S+)") or nil
  if name then return name end
  if UnitExists and UnitExists("target") and not (UnitIsUnit and UnitIsUnit("target", "player")) then
    local target = UnitName("target")
    if type(target) == "string" and not (issecretvalue and issecretvalue(target)) then return target end
  end
end

function ns:Moan(msg)
  local target = Target(msg)
  local text = target and L.MOAN_AT:format(target) or L.MOAN
  if Send then Send(text, "EMOTE") end
end

SLASH_CLARAMOAN1 = "/moan"
SlashCmdList.CLARAMOAN = function(msg) ns:Moan(msg) end
