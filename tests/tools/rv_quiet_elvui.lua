local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local function has(text) for _, t in ipairs(M.chat) do if t == text then return true end end return false end
local function say(text, stack) M.stack = stack; ChatFrame1:AddMessage(text); M.stack = nil end
-- a whisper received at login, handled by ElvUI's chat module (it replaces the chat frames' OnEvent)
local ELVUI_EVENT = "[Interface/AddOns/ElvUI/Game/Shared/Modules/Chat/Chat.lua]:2400: in function 'ChatFrame_MessageEventHandler'\n"
  .. "[Interface/AddOns/ElvUI/Game/Shared/Modules/Chat/Chat.lua]:2589: in function 'ChatFrame_OnEvent'\n[C]: in ?"
-- Leatrix Plus (built in) restoring the chat after a reload
local LEA_RESTORE = "[Interface/AddOns/ClaraComboPoints/Modules/LeatrixPlus/Leatrix_Plus.lua]:7380: in function 'Player'\n[C]: in ?"
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.now = 5
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
say("[Guild] Bob: hi everyone", LEA_RESTORE)
M.now = 20
M.Fire("PLAYER_ENTERING_WORLD", true, false)
say("[Anna] whispers: are you coming?", ELVUI_EVENT)
say("Guild Message of the Day: raid at 8", ELVUI_EVENT)
out("restored chat line kept: " .. tostring(has("[Guild] Bob: hi everyone")))
out("whisper kept: " .. tostring(has("[Anna] whispers: are you coming?")))
out("guild MOTD kept: " .. tostring(has("Guild Message of the Day: raid at 8")))
