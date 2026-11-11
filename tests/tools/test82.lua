-- The Battle.net toast (ChatPlace.lua): just above the general chat's tabs, each time the game lays its alerts out
-- and as it shows; the alert column itself (the friends button) left where it is
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
ChatFrame1Tab = CreateFrame("Button", "ChatFrame1Tab", UIParent)
ChatAlertFrame = CreateFrame("Frame", "ChatAlertFrame", UIParent)
ChatAlertFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 200) -- (the game's: above the chat's buttons)
BNToastFrame = CreateFrame("Frame", "BNToastFrame", UIParent); BNToastFrame:Hide()
function ChatAlertFrame:UpdateAnchors() BNToastFrame:ClearAllPoints(); BNToastFrame:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 0) end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD", true, false)
local function Above() local p, rel, rp, x, y = BNToastFrame:GetPoint(1) return #BNToastFrame._points == 1 and p == "BOTTOMLEFT" and rel == ChatFrame1Tab and rp == "TOPLEFT" and y == 4 end
ChatAlertFrame:UpdateAnchors(); BNToastFrame:Show()
check(Above(), "a friend online: the toast just above the chat's tabs")
local _, rel = ChatAlertFrame:GetPoint(1)
check(rel == UIParent, "the alert column (the friends button) left where the game put it")
out(string.format("\n%d failure(s)", fails))
return fails
