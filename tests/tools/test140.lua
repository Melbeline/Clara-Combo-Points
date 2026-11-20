-- The chat's typing bar as in Classic 1.15.9 (ChatFocus.lua): registered with the game's sticky focus (as its dressing
-- room), it keeps the keyboard at a left click elsewhere while a chat typing bar has it (the game's own check copied
-- from EventImplementation.lua's ClearCurrentKeyboardFocus); another typing box still loses it; the setting off: the
-- game's way back at once (unregistered), on again: registered again
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's sticky focus (ChatFrameUtil.lua) and the chat typing bar's own question (ChatFrameEditBox.lua)
local sticky = {}
ChatFrameUtil = ChatFrameUtil or {}
function ChatFrameUtil.RegisterForStickyFocus(frame) sticky[frame] = true end
function ChatFrameUtil.UnregisterForStickyFocus(frame) sticky[frame] = nil end
function ChatFrameUtil.HasStickyFocus()
  for frame in pairs(sticky) do if frame:HasStickyFocus() then return true end end
  return false
end
local focus
function GetCurrentKeyBoardFocus() return focus end
local function Box(chat)
  local b = CreateFrame("EditBox", nil, UIParent)
  b.cleared = 0
  function b:ClearFocus() self.cleared = self.cleared + 1; if focus == self then focus = nil end end
  if chat then
    b.chatFrame = CreateFrame("Frame", nil, UIParent)
    function b:HasStickyFocus() return ChatFrameUtil.HasStickyFocus() end
  end
  return b
end
-- the game's left click (EventImplementation.lua, ClearCurrentKeyboardFocus, without its other cases)
local function LeftClick()
  local box = GetCurrentKeyBoardFocus()
  if box and box.ClearFocus then
    if box.HasStickyFocus and box:HasStickyFocus() then return end
    box:ClearFocus()
  end
end

local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")

out("== on (by default)")
check(ns:ChatKeepsFocus() and sticky[ns.ChatFocusKeeper], "registered with the game's sticky focus")
local chat, other = Box(true), Box(false)
focus = chat
LeftClick()
check(focus == chat and chat.cleared == 0, "the chat typing bar open: a left click elsewhere leaves it the keyboard")
LeftClick(); LeftClick()
check(focus == chat and chat.cleared == 0, "every click: still")
focus = other
LeftClick()
check(focus == nil and other.cleared == 1, "another typing box (not the chat's): it loses the keyboard as the game does")
focus = nil
check(ns.ChatFocusKeeper:HasStickyFocus() == false, "no box with the keyboard: nothing kept")

out("== off: the game's way at once; on again")
ns:SetChatKeepsFocus(false)
check(not ns:ChatKeepsFocus() and not sticky[ns.ChatFocusKeeper] and ClaraComboPointsDB.chatKeepsFocus == false, "unregistered, kept off")
focus = chat
LeftClick()
check(focus == nil and chat.cleared == 1, "a left click elsewhere: the chat typing bar loses the keyboard (the game's)")
ns:SetChatKeepsFocus(true)
check(sticky[ns.ChatFocusKeeper] and ClaraComboPointsDB.chatKeepsFocus == nil, "on again: registered again")
focus = chat
LeftClick()
check(focus == chat, "kept again")
ns:SetChatKeepsFocus(true)
local n = 0
for _ in pairs(sticky) do n = n + 1 end
check(n == 1, "registered once")
out(fails == 0 and "ALL OK" or (fails .. " FAILED"))
