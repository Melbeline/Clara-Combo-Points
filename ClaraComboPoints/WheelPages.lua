-- Clara - the mouse wheel turns the pages of a window that has pages, as the game's merchant, mailbox,
-- stable, collections and spellbook already do: down the next page, up the previous one, stopping at the
-- first and the last (no wrap). Here the one paged window of the game without it: a book, a letter or a
-- plaque (ItemTextFrame). Its text scrolls first when a page is longer than the window; at the end of the
-- text, the wheel turns the page. One notch, one page turned (the game's own page functions).
local ADDON, ns = ...

local function TurnItemText(delta)
  if delta < 0 then
    if ItemTextNextPageButton and ItemTextNextPageButton:IsShown() and ItemTextFrame_NextPageOnClick then
      ItemTextFrame_NextPageOnClick()
      return true
    end
  elseif ItemTextPrevPageButton and ItemTextPrevPageButton:IsShown() and ItemTextFrame_PrevPageOnClick then
    ItemTextFrame_PrevPageOnClick()
    return true
  end
  return false
end

local function Hook()
  local frame, scroll = ItemTextFrame, ItemTextScrollFrame
  if not frame or frame.claraWheel then return end
  frame.claraWheel = true
  -- over the window's frame (title, borders, page buttons): the page turns
  if not frame:GetScript("OnMouseWheel") then
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) TurnItemText(delta) end)
  end
  -- over the text: it scrolls while it can, then the page turns
  if scroll and scroll.GetVerticalScroll then
    local scrollWheel = scroll:GetScript("OnMouseWheel")
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
      local before = self:GetVerticalScroll()
      if scrollWheel then scrollWheel(self, delta) end
      if self:GetVerticalScroll() == before then TurnItemText(delta) end
    end)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  Hook()
end)
