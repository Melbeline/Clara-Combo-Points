-- Clara Combo Points - a quest shared from the chat. Its "Quest accepted: <quest>" line: a double middle click on the
-- quest's name shares it with the group; with the box ticked (off by default; Clara's page), the quest tracker's bubble
-- (its "..." in progress mark) ends the line, and a left click on it shares the quest too.
-- The game lets no addon share a quest (QuestLogPushQuest is protected): as the quest log's own Share (QuestLogCore),
-- a secure pad presses the game's Share for the player. Over a quest of these lines, out of combat, an unseen pad takes
-- the place under the mouse; its click runs, in one press, the map opened, its quest pane and the quest's header, the
-- quest's row and the game's Share, then Back, the pane and the map shut as they were. Out of a group, in a fight, or
-- with the world map open (the press needs it shut), a line says why instead.

local ADDON, ns = ...
local L = ns.L

local LINK = "addon:" .. ADDON .. ":qshare:" -- addon:ClaraComboPoints:qshare:<quest|share>:<questID>
local DOUBLE = 0.5 -- two middle clicks this close: a double one
-- The tracker's bubble: its round mark, its "..." over it (Blizzard_POIButton: a quest in progress)
local BUBBLE = "|A:UI-QuestPoi-QuestNumber:18:18|a|A:Quest-In-Progress-Icon-yellow:12:12:-15:0|a"

function ns:QuestShareBubble() return self.sv ~= nil and self.sv.questShareBubble == true end
function ns:SetQuestShareBubble(on)
  if not self.sv then return end
  self.sv.questShareBubble = on and true or nil
end

local function Say(text, r, g, b)
  if text and UIErrorsFrame then UIErrorsFrame:AddMessage(text, r or 1, g or 0.1, b or 0.1) end
end

---------------------------------------------------------------------------
-- The game's Share pressed for the player (QuestLogCore's own sequence, for any quest of the log)
---------------------------------------------------------------------------
local STEPS = { "Open", "AimPane", "Pane", "AimHeader", "Header", "AimRow", "Row", "Share", "Back", "AimShut", "Shut",
  "AimClose", "Close" }
local AIMED = { "Pane", "Header", "Row", "Share", "Back", "Shut", "Close" }
local proxies, macro, armedID, openedPane, shared

local function SetIf(frame, name, value)
  if frame:GetAttribute(name) ~= value then frame:SetAttribute(name, value) end
end

local function Aim(step, target) SetIf(proxies[step], "clickbutton", target or nil) end
local function Disarm() for _, step in ipairs(AIMED) do Aim(step, nil) end end
local function MapUp() return armedID ~= nil and not InCombatLockdown() and WorldMapFrame and WorldMapFrame:IsShown() end

local function AimPane()
  shared, openedPane = false, false
  Disarm()
  if not MapUp() then return end
  local toggle = WorldMapFrame.SidePanelToggle
  openedPane = not QuestMapFrame:IsShown() and toggle ~= nil and toggle.OpenButton ~= nil
  Aim("Pane", openedPane and toggle.OpenButton or nil)
end

local function FoldedHeader(questID)
  local header, found
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and info.isHeader then
      header = info.isCollapsed and i or nil
    elseif info and info.questID == questID then
      found = true
      break
    end
  end
  local pool = found and header and QuestScrollFrame and QuestScrollFrame.headerFramePool
  if not pool then return nil end
  for button in pool:EnumerateActive() do
    if button.questLogIndex == header then return button end
  end
end

local function AimHeader()
  if MapUp() and QuestMapFrame:IsShown() then Aim("Header", FoldedHeader(armedID)) end
end

local function AimRow()
  if not (MapUp() and QuestMapFrame:IsShown()) then return end
  local find = _G.QuestLogQuests_GetQuestButton
  local row = find and find(armedID)
  local details = QuestMapFrame.DetailsFrame
  local back = details and details.BackFrame and details.BackFrame.BackButton
  if not (row and issecurevariable(row, "questID") and details and details.ShareButton and back) then return end
  shared = true
  Aim("Row", row)
  Aim("Share", details.ShareButton)
  Aim("Back", back)
end

local function AimShut()
  local toggle = WorldMapFrame.SidePanelToggle
  if MapUp() and openedPane and toggle then Aim("Shut", toggle.CloseButton) end
end

local function AimClose()
  local border = WorldMapFrame.BorderFrame
  if MapUp() then Aim("Close", border and border.CloseButton or nil) end
end

local AIMS = { AimPane = AimPane, AimHeader = AimHeader, AimRow = AimRow, AimShut = AimShut, AimClose = AimClose }

local function Proxy(name)
  local proxy = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  proxy:SetSize(1, 1)
  proxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
  proxy:EnableMouse(false)
  proxy:RegisterForClicks("AnyUp", "AnyDown")
  proxy:SetAttribute("useOnKeyDown", false)
  proxy:SetAttribute("type", "click")
  return proxy
end

local function Build()
  if proxies then return end
  proxies = {}
  local lines = {}
  for i, step in ipairs(STEPS) do
    proxies[step] = Proxy("ClaraQuestShareStep" .. i)
    if AIMS[step] then proxies[step]:SetScript("PreClick", AIMS[step]) end
    lines[i] = string.format(step == "Open" and "/click [nomod] %s" or "/click %s", proxies[step]:GetName())
  end
  macro = table.concat(lines, "\n")
end

-- The sequence aimed at this quest (out of combat), its macro; nil when it cannot run, and why said
local function Arm(questID)
  if InCombatLockdown() then
    if ERR_NOT_IN_COMBAT then Say(ERR_NOT_IN_COMBAT) end
    return nil
  end
  if not (IsInGroup and IsInGroup()) then return Say(L.QUEST_SHARE_NOT_IN_GROUP) end
  if not (C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)) then return nil end
  if not (WorldMapFrame and QuestMapFrame and MinimapCluster and MinimapCluster.ZoneTextButton) then return nil end
  if WorldMapFrame:IsShown() then return Say(L.QUEST_SHARE_CLOSE_MAP) end
  Build()
  armedID = questID
  Aim("Open", MinimapCluster.ZoneTextButton)
  Disarm()
  return macro
end

local function After()
  if not proxies or InCombatLockdown() then return end
  Disarm()
  Aim("Open", nil)
  if armedID and not shared then Say(L.QUEST_SHARE_FROM_MAP) end
  armedID = nil
end

---------------------------------------------------------------------------
-- The pad: under the mouse over a quest of these lines, out of combat
---------------------------------------------------------------------------
local pad, hovered, lastMiddle

local function Pad()
  if pad then return pad end
  pad = CreateFrame("Button", "ClaraQuestSharePad", UIParent, "SecureActionButtonTemplate")
  pad:SetSize(26, 18)
  pad:SetFrameStrata("TOOLTIP")
  pad:RegisterForClicks("LeftButtonUp", "MiddleButtonUp")
  pad:SetAttribute("useOnKeyDown", false)
  pad:SetAttribute("type", "macro")
  pad:SetAttribute("macrotext", "")
  pad:Hide()
  pad:SetScript("PreClick", function(self, button)
    if InCombatLockdown() then return end
    local text = ""
    local target = hovered
    if target then
      local go = false
      if button == "LeftButton" and target.kind == "share" then
        go = true
      elseif button == "MiddleButton" then
        if lastMiddle and lastMiddle.id == target.id and GetTime() - lastMiddle.at <= DOUBLE then
          go, lastMiddle = true, nil
        else
          lastMiddle = { id = target.id, at = GetTime() }
        end
      end
      if go then text = Arm(target.id) or "" end
    end
    SetIf(self, "macrotext", text)
  end)
  pad:SetScript("PostClick", function(self)
    if InCombatLockdown() then return end
    if self:GetAttribute("macrotext") ~= "" then After() end
    SetIf(self, "macrotext", "")
  end)
  pad:SetScript("OnLeave", function(self)
    hovered = nil
    if not InCombatLockdown() then self:Hide() end
  end)
  pad:SetScript("OnEnter", function(self)
    if not hovered then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(hovered.kind == "share" and L.QUEST_SHARE_TIP_BUBBLE or L.QUEST_SHARE_TIP_NAME, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  pad:HookScript("OnLeave", GameTooltip_Hide)
  return pad
end

local function Parse(link)
  if type(link) ~= "string" or link:sub(1, #LINK) ~= LINK then return nil end
  local kind, id = link:sub(#LINK + 1):match("^(%a+):(%d+)$")
  if not kind then return nil end
  return { kind = kind, id = tonumber(id) }
end

local function OnLinkEnter(_, link)
  local target = Parse(link)
  if not target or InCombatLockdown() then return end
  hovered = target
  local p = Pad()
  local scale = UIParent:GetEffectiveScale()
  local x, y = GetCursorPosition()
  p:ClearAllPoints()
  p:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
  p:Show()
end

-- A click on one where no pad stood (in a fight): why nothing happens
if EventRegistry and EventRegistry.RegisterCallback then
  EventRegistry:RegisterCallback("SetItemRef", function(_, link, _, button)
    local target = Parse(link)
    if not target then return end
    if InCombatLockdown() and (target.kind == "share" or button == "MiddleButton") and ERR_NOT_IN_COMBAT then
      Say(ERR_NOT_IN_COMBAT)
    end
  end, ns)
end

local hookedFrames = {}
local function HookChatFrames()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local frame = _G["ChatFrame" .. i]
    if frame and not hookedFrames[frame] then
      hookedFrames[frame] = true
      frame:HookScript("OnHyperlinkEnter", OnLinkEnter)
    end
  end
end

---------------------------------------------------------------------------
-- The "Quest accepted" lines: the quest's name a link (a double middle click shares it), the bubble after it
---------------------------------------------------------------------------
local accepted -- the pattern of the game's line ("Quest accepted: %s")
local recent = {} -- questIDs just accepted (QUEST_ACCEPTED), their time

local function Pattern()
  if accepted == nil then
    local fmt = ERR_QUEST_ACCEPTED_S
    accepted = type(fmt) == "string" and ("^" .. fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$") or false
  end
  return accepted or nil
end

local function QuestByTitle(title)
  local now = GetTime()
  for id, at in pairs(recent) do
    if now - at > 60 then
      recent[id] = nil
    elseif now - at < 5 and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id) == title then
      return id
    end
  end
  for i = 1, C_QuestLog.GetNumQuestLogEntries() do
    local info = C_QuestLog.GetInfo(i)
    if info and not info.isHeader and info.title == title then return info.questID end
  end
end

local function Filter(_, _, msg, ...)
  if type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return false end
  local pattern = Pattern()
  local title = pattern and msg:match(pattern)
  if not title or title:find("|H", 1, true) then return false end
  local questID = QuestByTitle(title)
  if not questID then return false end
  local link = ("|H%squest:%d|h%s|h"):format(LINK, questID, title)
  local line = ERR_QUEST_ACCEPTED_S:format(link)
  if ns:QuestShareBubble() then line = line .. " " .. ("|H%sshare:%d|h%s|h"):format(LINK, questID, BUBBLE) end
  return false, line, ...
end
ns.QuestShareFilter = Filter

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event, questID)
  if event == "PLAYER_LOGIN" then
    HookChatFrames()
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then add("CHAT_MSG_SYSTEM", Filter) end
  elseif event == "QUEST_ACCEPTED" then
    if type(questID) == "number" then recent[questID] = GetTime() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- (the fight begins: the pad away while it still may be moved)
    hovered = nil
    if pad and pad:IsShown() then pad:Hide() end
  end
end)
