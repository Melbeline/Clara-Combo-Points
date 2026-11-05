-- Clara Combo Points - in the game's group finder (Looking For Group, right click on the eye by the
-- minimap), the zone where each listed player (a group's leader) is, on a third line under the
-- name and the activity: the name and the activity lifted a little so the three fit in the row. As
-- the game gives it with the listing. On by default; a box turns it off (Leatrix Plus's Interface
-- page, or the game's options for Clara Combo Points without Leatrix Plus).

local ADDON, ns = ...

local issecret = issecretvalue or function() return false end
local LIFT = 7        -- the name and the activity, higher by this (the zone's line)
local LIFT_NESTED = 4 -- (the taller rows, their playstyle line under the zone)

function ns:GroupFinderZone() return not (self.sv and self.sv.lfgZone == false) end

local function Zone(entry)
  if not (ns:GroupFinderZone() and entry.resultID and C_LFGList and C_LFGList.GetSearchResultLeaderInfo) then return end
  local ok, info = pcall(C_LFGList.GetSearchResultLeaderInfo, entry.resultID)
  local zone = ok and type(info) == "table" and info.areaName
  if type(zone) ~= "string" or issecret(zone) or zone == "" then return end
  return zone
end

local function Lift(entry, lift)
  local icon = entry.PartyIcon
  if not icon then return end
  if not entry.claraIconPoint then
    local point, rel, relPoint, x, y = icon:GetPoint(1)
    if issecretvalue and (issecretvalue(point) or issecretvalue(rel) or issecretvalue(relPoint) or issecretvalue(x) or issecretvalue(y)) then
      point, rel, relPoint, x, y = nil, nil, nil, nil, nil
    end
    entry.claraIconPoint = { point or "TOPLEFT", rel or entry, relPoint or "TOPLEFT", x or 8, y or -14 }
  end
  local p = entry.claraIconPoint
  icon:ClearAllPoints()
  icon:SetPoint(p[1], p[2], p[3], p[4], p[5] + lift)
end

local function Dress(entry)
  if type(entry) ~= "table" or not entry.ActivityName then return end
  local zone = Zone(entry)
  local line = entry.claraZone
  if not line then
    if not zone then return end
    line = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", entry.ActivityName, "BOTTOMLEFT", 0, -1)
    line:SetJustifyH("LEFT")
    if line.SetWordWrap then line:SetWordWrap(false) end
    line:SetWidth(entry.NameMaxWidth or 220)
    entry.claraZone = line
  end
  local nested = entry.PlaystyleLabel ~= nil
  if zone then
    line:SetText(zone)
    local color = (entry.isDelisted and LFGBROWSE_DELISTED_FONT_COLOR) or HIGHLIGHT_FONT_COLOR
    if color then line:SetTextColor(color.r, color.g, color.b) end
    line:Show()
    Lift(entry, nested and LIFT_NESTED or LIFT)
    if nested then
      entry.PlaystyleLabel:ClearAllPoints()
      entry.PlaystyleLabel:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -1)
    end
  else
    line:Hide()
    Lift(entry, 0)
    if nested then
      entry.PlaystyleLabel:ClearAllPoints()
      entry.PlaystyleLabel:SetPoint("TOPLEFT", entry.ActivityName, "BOTTOMLEFT", 0, -2)
    end
  end
end
ns.DressGroupFinderEntry = Dress

-- Shown again with the box's change
function ns:SetGroupFinderZone(on)
  if not self.sv then return end
  if on then self.sv.lfgZone = nil else self.sv.lfgZone = false end
  local browse = LFGBrowseFrame
  if browse and browse:IsVisible() and browse.ScrollBox and browse.ScrollBox.ForEachFrame then
    browse.ScrollBox:ForEachFrame(Dress)
  end
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
    if type(LFGBrowseSearchEntry_Update) == "function" then hooksecurefunc("LFGBrowseSearchEntry_Update", Dress) end
  end)
end
