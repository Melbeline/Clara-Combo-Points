-- Clara Combo Points - Reverse Engineering in ClassicUI's professions window (its Skills/TradeSkill.lua
-- calls these, added there as it is built in): the list's search and filter, the chests on the recipe's
-- reagents, and the panel under them in the recipe's scrolling pane.

local ADDON, ns = ...
local C = ns.Craft
if not C then return end

-- The list: a recipe kept if the search finds it and the filter lets it through
function ns.CraftMatch(id, info, query) return C.Match(id, info and info.name, query) end
function ns.CraftShown(id) return C.Shown(id) end

local panel

-- The recipe shown: the chests on its reagents; the panel made, laid in CraftClassicPlace
function ns.CraftClassicDetail(detail, info)
  for _, button in ipairs(detail.reagents or {}) do
    if button:IsShown() then
      C.MarkChest(button, button.itemID, button.icon)
    elseif button.claraChest then
      button.claraChest:Hide()
    end
  end
  if not panel then
    panel = C.NewPanel(detail, function() if ns.ClassicTradeRefresh then ns.ClassicTradeRefresh() end end)
  end
  panel.recipe = info and info.recipeID
end

-- Under the reagents (bottom: where they end in the pane); returns where the pane's content ends now
function ns.CraftClassicPlace(detail, bottom)
  if not panel then return bottom end
  local scroll = detail:GetParent()
  local width = (scroll and scroll.GetWidth and scroll:GetWidth() or 0) - 16
  if width < 150 then width = 300 end
  local height = panel:Update(panel.recipe, width)
  panel.frame:ClearAllPoints()
  panel.frame:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -(bottom + 6))
  if height > 0 then return bottom + height + 10 end
  return bottom
end

-- An option changed: the window drawn again (its own refresh, while it shows)
C.Redraws[#C.Redraws + 1] = function() if ns.ClassicTradeRefresh then ns.ClassicTradeRefresh() end end
