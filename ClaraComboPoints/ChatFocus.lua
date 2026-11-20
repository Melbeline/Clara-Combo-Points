-- Clara Combo Points - the chat's typing bar as in WoW Classic 1.15.9: opened (Enter), it keeps the keyboard until
-- the message is sent (Enter) or dropped (Escape); a left click anywhere else (the world, a window, a button) no
-- longer takes it away. The game lets go of the keyboard at each left click outside the box that has it
-- (EventImplementation.lua, ClearCurrentKeyboardFocus), unless that box has a "sticky" focus; a chat typing bar asks
-- the frames registered with ChatFrameUtil.RegisterForStickyFocus (the game's own way: its dressing room is one).
-- This one is registered while the setting is on, and keeps it whenever a chat typing bar has the keyboard. A click
-- in another typing box still moves the keyboard there (the game does that itself). On by default; its box on
-- Clara's page. Off: unregistered, the game's own way back at once.

local ADDON, ns = ...

function ns:ChatKeepsFocus() return not self.sv or self.sv.chatKeepsFocus ~= false end

local keeper = {}
-- (asked only while a chat typing bar has the keyboard; true for any of them: never a half answer that would let the
-- game drop the keyboard from code it then counts as ours)
function keeper:HasStickyFocus()
  local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  return focus ~= nil and type(focus) == "table" and focus.chatFrame ~= nil
end
ns.ChatFocusKeeper = keeper

local registered = false
local function Apply()
  local util = ChatFrameUtil
  if not (util and util.RegisterForStickyFocus and util.UnregisterForStickyFocus) then return end
  local want = ns:ChatKeepsFocus()
  if want and not registered then
    util.RegisterForStickyFocus(keeper)
    registered = true
  elseif not want and registered then
    util.UnregisterForStickyFocus(keeper)
    registered = false
  end
end
ns.ApplyChatFocus = Apply

function ns:SetChatKeepsFocus(on)
  if not self.sv then return end
  if on then self.sv.chatKeepsFocus = nil else self.sv.chatKeepsFocus = false end
  Apply()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Apply()
end)
