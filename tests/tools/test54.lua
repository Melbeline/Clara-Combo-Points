-- The general chat's place and size kept apart from Edit Mode (ChatPlace.lua), put back after Edit
-- Mode's layout, Edit Mode's again once moved in it; Reset chat position, last in the tabs' menu
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

CHAT_FRAME_ANCHOR_OFFSET_Y = 85
Enum = Enum or {}
Enum.EditModeSystem = { ChatFrame = 7 }
EditModePresetLayoutManager = { GetDefaultSystemAnchorInfo = function(_, system)
  return { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 35, offsetY = 85 }
end }
local editMode = false
EditModeManagerFrame = { IsEditModeActive = function() return editMode end }
ChatFrame1:SetSize(430, 170)
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 35, 85)
function ChatFrame1:ApplySystemAnchor() self:ClearAllPoints(); self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 35, 85) end
function ChatFrame1:UpdateSystemSettingHeight() self:SetSize(self:GetWidth(), 170) end
function ChatFrame1:OnDragStop() end
function ChatFrame1:GetID() return 1 end
local menus = {}
Menu = { ModifyMenu = function(tag, fn) menus[#menus + 1] = { tag = tag, fn = fn } end }
local saved = {}
function FCF_SavePositionAndDimensions(f) saved[#saved + 1] = f end
local other = CreateFrame("Frame", "ChatFrame3", UIParent)
other:SetSize(300, 150); other:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 900, -50)
function FCF_GetChatFrameByID(id) return id == 3 and other or ChatFrame1 end

local ns = {}
S.class = "MAGE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
local function Run() while M.timers and #M.timers > 0 do M.RunTimer() end end
Run()

-- sized outside Edit Mode (the grip): kept
ChatFrame1:SetSize(600, 260)
ChatFrame1.GetLeft = function() return 35 end
ChatFrame1.GetBottom = function() return 85 end
ns.ChatPlace.Keep()
local place = ClaraComboPointsDB.chatPlace
check(place and place.x == 35 and place.y == 85 and place.w == 600 and place.h == 260, "sized outside Edit Mode: kept")
-- Edit Mode lays it out again (a reload): put back
ChatFrame1:UpdateSystemSettingHeight(); ChatFrame1:ApplySystemAnchor()
Run()
check(math.floor(ChatFrame1:GetHeight() + .5) == 260 and math.floor(ChatFrame1:GetWidth() + .5) == 600, "Edit Mode's layout: our size put back")
-- moved in Edit Mode: Edit Mode's again
editMode = true
ChatFrame1:OnDragStop()
check(ClaraComboPointsDB.chatPlace == nil, "moved in Edit Mode: Edit Mode's again")
editMode = false

-- the tabs' menu: Reset chat position, last
local entry
for _, m in ipairs(menus) do if m.tag == "MENU_FCF_TAB" then entry = m end end
check(entry ~= nil, "an entry in the chat tabs' menu")
local items = {}
local root; root = { CreateDivider = function() items[#items + 1] = "-" end,
  CreateButton = function(_, text, fn) items[#items + 1] = text; root.click = fn end }
local tab1 = { GetID = function() return 1 end }
entry.fn(tab1, root)
check(items[#items] == "Reset chat position" and items[#items - 1] == "-", "Reset chat position, after a divider")
ChatFrame1.GetLeft = function() return -400 end -- (lost off the screen)
root.click()
place = ClaraComboPointsDB.chatPlace
check(place and place.x == 35 and place.y == 85 and place.w == 600, "the general chat back where the game first puts it, its size kept")
local _, rel, rp, x, y = ChatFrame1:GetPoint(1)
check(rel == UIParent and rp == "BOTTOMLEFT" and x == 35 and y == 85, "and there now")
-- an undocked window: the middle of the screen
items = {}
entry.fn({ GetID = function() return 3 end }, root)
root.click()
local p, rel2 = other:GetPoint(1)
check(p == "CENTER" and rel2 == UIParent and saved[#saved] == other, "an undocked window: the middle of the screen, saved")
out("")
out(fails .. " failure(s)")
