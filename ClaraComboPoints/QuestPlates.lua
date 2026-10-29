-- Clara Combo Points - on a nameplate, a small quest mark and its progress (3/8) when the creature
-- is part of a quest of yours not done yet: read from the game's own tooltip for it (the objective
-- lines under the quest's title). Nameplates the game keeps to itself (in dungeons) are left alone.
-- On by default; a box turns it off (Leatrix Plus's Interface page, or the game's options for
-- Clara Combo Points without Leatrix Plus).

local ADDON, ns = ...

local issecret = issecretvalue or function() return false end
local OBJECTIVE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8

function ns:QuestPlates() return not (self.sv and self.sv.questPlates == false) end

-- The progress of the first objective not done yet ("" when it has no count), or nil
local function Progress(unit)
  if not (C_TooltipInfo and C_TooltipInfo.GetUnit) or UnitIsPlayer(unit) then return end
  local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return end
  for _, line in ipairs(data.lines) do
    if line.type == OBJECTIVE and not line.completed then
      local text = line.leftText
      if type(text) == "string" and not issecret(text) then
        local have, need = text:match("(%d+)%s*/%s*(%d+)")
        if not have then return "" end
        if tonumber(have) < tonumber(need) then return have .. "/" .. need end
      end
    end
  end
end

local function Plate(unit)
  local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
  if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
  return plate
end

local function Mark(plate)
  local mark = plate.claraQuest
  if mark then return mark end
  mark = CreateFrame("Frame", nil, plate)
  mark:SetSize(14, 14)
  local bar = plate.UnitFrame and (plate.UnitFrame.healthBar or plate.UnitFrame.HealthBarsContainer)
  mark:SetPoint("RIGHT", bar or plate, "LEFT", -2, 0)
  mark.icon = mark:CreateTexture(nil, "OVERLAY")
  mark.icon:SetAllPoints()
  if not (mark.icon.SetAtlas and mark.icon:SetAtlas("QuestNormal")) then
    mark.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
  end
  mark.text = mark:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
  mark.text:SetPoint("RIGHT", mark, "LEFT", -1, 0)
  mark.text:SetTextColor(1, .82, 0)
  plate.claraQuest = mark
  return mark
end

local function Update(unit)
  local plate = Plate(unit)
  if not plate then return end
  local progress = ns:QuestPlates() and Progress(unit)
  if progress then
    local mark = Mark(plate)
    mark.text:SetText(progress)
    mark:Show()
  elseif plate.claraQuest then
    plate.claraQuest:Hide()
  end
end

local function Each(fn)
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
    local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    fn(plate, unit)
  end
end

local pending
local function Refresh()
  pending = nil
  Each(function(plate, unit)
    if unit then Update(unit) elseif plate.claraQuest then plate.claraQuest:Hide() end
  end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then
    Update(unit)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    local plate = Plate(unit)
    if plate and plate.claraQuest then plate.claraQuest:Hide() end
  elseif not pending then -- (the quest log changed: all of them, once)
    pending = true
    C_Timer.After(0.3, Refresh)
  end
end)

local function Listen()
  local on = ns:QuestPlates()
  for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE" }) do
    if on then events:RegisterEvent(event) else events:UnregisterEvent(event) end
  end
end

function ns:SetQuestPlates(on)
  if not self.sv then return end
  if on then self.sv.questPlates = nil else self.sv.questPlates = false end
  Listen()
  Refresh()
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_LOGIN")
  Listen()
end)
