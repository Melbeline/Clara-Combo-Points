-- (shared by cql3 and test108) Share Quest's whole chain, played as the game plays a macro: its text cut at 255
-- characters (the game's limit), each /click running the proxy's PreClick then pressing its clickbutton; the game's
-- world map, its quest panel (its toggle only hides the panel when the panel is not as the player keeps it), the
-- quest's row, Share, Back, the map's own close button. Shared three times in a row: the map shut each time.
return function(M, S, check, ns, Q, F)
  local shared, closes = {}, 0
  local prefPanel = false -- (the player keeps the map's quest panel shut)
  WorldMapFrame:Hide()
  QuestMapFrame:Hide()
  WorldMapFrame.BorderFrame = CreateFrame("Frame", nil, WorldMapFrame)
  WorldMapFrame.BorderFrame.CloseButton = CreateFrame("Button", nil, WorldMapFrame.BorderFrame)
  WorldMapFrame.BorderFrame.CloseButton:SetScript("OnClick", function() closes = closes + 1 WorldMapFrame:Hide() end)
  local toggle = {}
  toggle.OpenButton = CreateFrame("Button", nil, WorldMapFrame)
  toggle.OpenButton:SetScript("OnClick", function() QuestMapFrame:Show() end)
  toggle.CloseButton = CreateFrame("Button", nil, WorldMapFrame)
  toggle.CloseButton:SetScript("OnClick", function() QuestMapFrame:Hide() end)
  WorldMapFrame.SidePanelToggle = toggle
  MinimapCluster.ZoneTextButton:SetScript("OnClick", function()
    if WorldMapFrame:IsShown() then
      if QuestMapFrame:IsShown() ~= prefPanel then QuestMapFrame:SetShown(prefPanel) else WorldMapFrame:Hide() end
    else
      WorldMapFrame:Show()
      QuestMapFrame:SetShown(prefPanel)
    end
  end)
  local details = CreateFrame("Frame", nil, QuestMapFrame)
  details.ShareButton = CreateFrame("Button", nil, details)
  details.BackFrame = { BackButton = CreateFrame("Button", nil, details) }
  QuestMapFrame.DetailsFrame = details
  local row = CreateFrame("Button", nil, QuestMapFrame)
  local showing
  row:SetScript("OnClick", function(self) showing = self.questID end)
  details.ShareButton:SetScript("OnClick", function() if showing then shared[#shared + 1] = showing end end)
  details.BackFrame.BackButton:SetScript("OnClick", function() showing = nil end)
  QuestScrollFrame = { headerFramePool = { EnumerateActive = function() return function() end end } }
  function QuestLogQuests_GetQuestButton(id) if QuestMapFrame:IsShown() then row.questID = id return row end end
  issecurevariable = issecurevariable or function() return true end
  local function Press(pad)
    local text = pad:GetAttribute("macrotext") or ""
    text = text:sub(1, 255) -- (the game runs no more)
    for line in text:gmatch("[^\n]+") do
      local mod, name = line:match("^/click (%[nomod%] )(%S+)$")
      name = name or line:match("^/click (%S+)$")
      local proxy = name and _G[name]
      if proxy then
        local pre = proxy:GetScript("PreClick")
        if pre then pre(proxy, "LeftButton", false) end
        local target = proxy:GetAttribute("clickbutton")
        if target then target:Click("LeftButton") end
      end
    end
    local post = pad:GetScript("PostClick")
    if post then post(pad, "LeftButton", false) end
  end
  S.group = "party"
  M.Fire("GROUP_ROSTER_UPDATE")
  while M.timers and #M.timers > 0 do M.RunTimer() end
  if not (F() and F():IsShown()) then Q.Toggle() end
  local frame = F()
  while M.timers and #M.timers > 0 do M.RunTimer() end
  local pad = frame.share.pad
  local errs = UIErrorsFrame.messages
  for n = 1, 3 do
    M.Tick()
    local text = pad:GetAttribute("macrotext") or ""
    check(pad:IsShown() and #text > 0 and #text <= 255, ("share %d: the pad armed, its macro %d characters (the game's 255 at most)"):format(n, #text))
    local before = #errs
    Press(pad)
    check(shared[n] == Q.QL.SelectedID(), ("share %d: the game's own Share pressed for the picked quest"):format(n))
    check(not WorldMapFrame:IsShown() and not QuestMapFrame:IsShown(), ("share %d: the map shut again, its panel as kept"):format(n))
    check(#errs == before, ("share %d: no message"):format(n))
  end
  check(closes == 3, "shut by its own close button each time (" .. closes .. ")")
  prefPanel = true
  M.Tick()
  Press(pad)
  check(not WorldMapFrame:IsShown() and #shared == 4, "the quest panel kept open by the player: shared, the map shut")
end
