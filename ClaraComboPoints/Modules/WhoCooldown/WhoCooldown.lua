-- Clara Combo Points - /who cooldown: after a /who the server refuses another for a while ("You must wait a moment
-- longer before using /who again."). The time left shows on the Who list's search button: a line crossing it from
-- left to right over a faint fill (default), or the seconds left in place of its text; a light flash when /who is
-- ready again, as the game's buttons at the end of a cooldown. Its two boxes on its card: neither, nothing shown.
-- The game tells no such time: Clara learns it from the server's answers and keeps it across sessions. From 5 s, it
-- goes down when a /who is taken sooner, up just past a delay the server refused (never longer than it must).
-- Buttons: the group finder's Who list (WoW Forever's, its magnifier), the old Who frame's Refresh, ClassicUI
-- Forever's Who List (its Refresh: ns:WhoCooldownAttach). Card on Esc > Options > AddOns > Clara > Interface, and in
-- Clara's Improvements tab. Saved with Clara's settings (ClaraComboPointsDB.whoCD).

local ADDON, ns = ...
local L = ns.L
local issecretvalue = issecretvalue or function() return false end

local DEFAULT, MIN, MAX = 5, 0.5, 60
local MARGIN = 0.5    -- past a refused delay
local ANSWER = 1.5    -- the server's refusal comes within this after the /who
local FLASH = 0.45    -- the flash fades in this

local runs = ns:QolRuns("whocooldown")

local function Store()
  local sv = ns.sv
  if not sv then return nil end
  sv.whoCD = sv.whoCD or {}
  return sv.whoCD
end
function ns:WhoCooldownMode()
  local s = Store()
  local mode = s and s.mode
  if mode == "count" or mode == "none" then return mode end
  return "bar"
end
local function SetMode(mode)
  local s = Store()
  if s then s.mode = mode ~= "bar" and mode or nil end
  ns:WhoCooldownRefresh()
end

ns:SetQolSwitches("whocooldown", {
  { label = "WHO_CD_BAR", get = function() return ns:WhoCooldownMode() == "bar" end,
    set = function(on) SetMode(on and "bar" or "none") end },
  { label = "WHO_CD_COUNT", get = function() return ns:WhoCooldownMode() == "count" end,
    set = function(on) SetMode(on and "count" or "none") end },
})
function ns:WhoCooldownAttach() end -- (turned off: nothing; ClassicUI's Who List calls it)
function ns:WhoCooldownRefresh() end
if not runs then return end

local F = C_FriendList
if not (F and F.SendWho) then return end

---------------------------------------------------------------------------
-- The cooldown, as learned: the longest delay refused (low), the shortest taken (high)
---------------------------------------------------------------------------
local function Clamp(v) return math.max(MIN, math.min(MAX, v)) end
local function Round(v) return math.floor(v * 10 + .5) / 10 end
function ns:WhoCooldownLength()
  local s = Store() or {}
  local low, high = tonumber(s.low), tonumber(s.high)
  local length = low and (low + MARGIN) or DEFAULT
  if high and high < length then length = high end
  return Clamp(length)
end

local taken       -- when the last /who the server took was sent
local pending     -- a /who sent, its answer awaited: { at = }
local shown       -- the cooldown on the buttons: { from =, length = }
local flashAt     -- when the flash started
local driver = CreateFrame("Frame")
driver:Hide()

local function Start(from, length)
  shown = { from = from, length = length }
  flashAt = nil
  driver:Show()
end

local function Taken(at)
  local s = Store()
  if s and taken then
    local d = at - taken
    if d >= MIN and (not s.high or d < s.high) then s.high = Round(d) end
    if s.low and s.high and s.high <= s.low then s.low = nil end
  end
  taken = at
  Start(at, ns:WhoCooldownLength())
end

local function Refused(at)
  local s = Store()
  if s and taken then
    local d = at - taken
    if d >= 0 and (not s.low or d > s.low) then s.low = Round(d) end
    if s.low and s.high and s.high <= s.low then s.high = nil end
    local length = ns:WhoCooldownLength()
    local left = taken + length - GetTime()
    if left < MARGIN then length = length + (MARGIN - left) end
    Start(taken, length)
  else
    Start(at, ns:WhoCooldownLength())
  end
end

-- The server's refusal: a system line naming the command, right after the /who (any language: its slash command)
local function IsRefusal(text)
  if type(text) ~= "string" or issecretvalue(text) then return false end
  local lower = text:lower()
  if lower:find("/who", 1, true) then return true end
  for i = 1, 4 do
    local cmd = _G["SLASH_WHO" .. i]
    if type(cmd) == "string" and cmd ~= "" and lower:find(cmd:lower(), 1, true) then return true end
  end
  return false
end

hooksecurefunc(F, "SendWho", function()
  pending = { at = GetTime() }
  driver:Show()
end)

---------------------------------------------------------------------------
-- The buttons: a line and a faint fill over them, or the seconds in place of their text; the flash at the end
---------------------------------------------------------------------------
local buttons = {}
ns.whoCooldownButtons = buttons -- (button -> its overlay, line, fill, flash, count: read by the tests)

local function Parts(button)
  local p = buttons[button]
  if p then return p end
  p = {}
  local o = CreateFrame("Frame", nil, button)
  o:SetAllPoints(button)
  o:SetFrameLevel((button:GetFrameLevel() or 1) + 3)
  if o.EnableMouse then o:EnableMouse(false) end
  p.overlay = o
  p.fill = o:CreateTexture(nil, "ARTWORK")
  p.fill:SetColorTexture(1, 1, 1, .12)
  p.line = o:CreateTexture(nil, "OVERLAY")
  p.line:SetColorTexture(.85, .85, .85, .65)
  p.flash = o:CreateTexture(nil, "OVERLAY", nil, 2)
  local hl = button.GetHighlightTexture and button:GetHighlightTexture()
  local file = hl and hl.GetTexture and hl:GetTexture()
  if file then
    p.flash:SetTexture(file)
    if hl.GetTexCoord then p.flash:SetTexCoord(hl:GetTexCoord()) end
  else
    p.flash:SetColorTexture(1, 1, 1, .6)
  end
  p.flash:SetBlendMode("ADD")
  p.flash:SetAllPoints(button)
  p.flash:SetAlpha(0)
  p.count = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  p.count:SetPoint("CENTER")
  o:Hide()
  buttons[button] = p
  return p
end

-- The button's own text, put back
local function Restore(button, p)
  if p.label ~= nil then
    button:SetText(p.label)
    p.label = nil
  end
  p.count:SetText("")
end

local function Show(button, p, mode, left, length)
  local o = p.overlay
  o:Show()
  local done = 1 - left / length
  if mode == "bar" then
    Restore(button, p)
    local width, height = button:GetWidth() or 0, button:GetHeight() or 0
    local inset = 4
    local span = math.max(0, width - 2 * inset)
    local x = inset + span * done
    p.fill:ClearAllPoints()
    p.fill:SetPoint("TOPLEFT", o, "TOPLEFT", inset, -inset)
    p.fill:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", inset, inset)
    p.fill:SetWidth(math.max(.01, x - inset))
    p.fill:Show()
    p.line:ClearAllPoints()
    p.line:SetSize(2, math.max(2, height - 2 * inset))
    p.line:SetPoint("CENTER", o, "LEFT", x, 0)
    p.line:Show()
  else
    p.fill:Hide()
    p.line:Hide()
    local n = tostring(math.ceil(left))
    local text = button.GetText and button:GetText()
    if text ~= nil and p.label == nil and text ~= "" then p.label = text end
    if p.label ~= nil then
      button:SetText(n)
    else
      p.count:SetText(n)
    end
  end
end

local function Hide(button, p)
  Restore(button, p)
  p.fill:Hide()
  p.line:Hide()
  if p.flash:GetAlpha() <= 0 then p.overlay:Hide() end
end

local function Update()
  local now = GetTime()
  if pending and now - pending.at > ANSWER then
    local at = pending.at
    pending = nil
    Taken(at)
  end
  local mode = ns:WhoCooldownMode()
  local left = shown and (shown.from + shown.length - now)
  if shown and left <= 0 then
    shown = nil
    if mode ~= "none" then flashAt = now end
  end
  local flash = flashAt and math.max(0, 1 - (now - flashAt) / FLASH) or 0
  if flashAt and flash <= 0 then flashAt = nil end
  for button, p in pairs(buttons) do
    local visible = button.IsVisible and button:IsVisible()
    if shown and mode ~= "none" and visible then
      Show(button, p, mode, left, shown.length)
    else
      Hide(button, p)
    end
    if flash > 0 and visible then
      p.overlay:Show()
      p.flash:SetAlpha(flash * .9)
    else
      p.flash:SetAlpha(0)
      if not (shown and mode ~= "none" and visible) then p.overlay:Hide() end
    end
  end
  if not pending and not shown and not flashAt then driver:Hide() end
end
driver:SetScript("OnUpdate", Update)

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SYSTEM")
events:RegisterEvent("WHO_LIST_UPDATE")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

local function WatchGameButtons()
  local lfg = _G.LFGWhoListFrame
  if lfg and lfg.WhoSearch then ns:WhoCooldownAttach(lfg.WhoSearch) end
  if _G.WhoFrameWhoButton then ns:WhoCooldownAttach(_G.WhoFrameWhoButton) end
end

events:SetScript("OnEvent", function(_, event, text)
  if event == "CHAT_MSG_SYSTEM" then
    if pending and GetTime() - pending.at <= ANSWER and IsRefusal(text) then
      local at = pending.at
      pending = nil
      Refused(at)
    end
  elseif event == "WHO_LIST_UPDATE" then
    if pending then
      local at = pending.at
      pending = nil
      Taken(at)
    end
  else
    WatchGameButtons()
  end
end)

function ns:WhoCooldownAttach(button)
  if type(button) ~= "table" or not button.CreateTexture then return end
  Parts(button)
  if shown or flashAt then driver:Show() end
end
function ns:WhoCooldownRefresh()
  for button, p in pairs(buttons) do Hide(button, p) end
  if shown or flashAt or pending then driver:Show() end
end
WatchGameButtons()
