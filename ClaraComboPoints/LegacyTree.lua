-- Clara Combo Points - the Legacy window (WoW Forever's Legacy button, its key) opened on its Legacy Tree page rather
-- than on Progress Track, the first page the game shows. As the window shows, its tree page is picked the way its tab
-- picks it (the game's own event); the challenges, opened from an achievement, still open on their page (the game
-- picks it just after). On by default; its box on Clara's page.

local ADDON, ns = ...

local TREE_PAGE = 3 -- (Blizzard_LegacySystem.xml: 1 Progress Track, 2 Challenges, 3 Legacy Tree)

function ns:LegacyTree() return not (self.sv and self.sv.legacyTree == false) end
function ns:SetLegacyTree(on)
  if not self.sv then return end
  if on then self.sv.legacyTree = nil else self.sv.legacyTree = false end
end

local function OnShow(frame)
  if not ns:LegacyTree() or type(frame.Pages) ~= "table" or not frame.Pages[TREE_PAGE] then return end
  if frame.currentPage == TREE_PAGE then return end
  if EventRegistry and EventRegistry.TriggerEvent then
    EventRegistry:TriggerEvent("Legacy.SelectPage", TREE_PAGE)
  elseif frame.SelectPage then
    frame:SelectPage(TREE_PAGE)
  end
end
ns.LegacyTreeOnShow = OnShow -- (for its test)

local hooked
local function Setup()
  local frame = LegacySystemFrame
  if not frame or hooked then return end
  hooked = true
  frame:HookScript("OnShow", OnShow)
  if frame:IsShown() then OnShow(frame) end
end
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
  EventUtil.ContinueOnAddOnLoaded("Blizzard_LegacySystem", Setup)
end
