-- Group quest progress with the harness's frames: the game's tooltip for an item (its post calls run); an item and
-- a creature a member needs: Clara's line written as the tooltip shows (the hook on its Show); no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local G = ns.GroupQuests
check(G ~= nil, "the module runs")
local tip = rawget(env, "GameTooltip")
if G and tip then
  G.Heard("F~Q^2945^0^Gyrodrillmatic Excavationators^12,24,i,Linen Cloth~Q^2928^0^Gyro^4,10,m,Kobold Vermin slain", "PARTY", "Lia Moon-Living Flame")
  check(G.members["lia moon"] ~= nil, "a member heard")
  local ok, e = pcall(function() tip:SetOwner(env.UIParent, "ANCHOR_NONE"); tip:SetItemByID(2589) end)
  check(ok, "the game's tooltip for an item, the post calls and Show run " .. tostring(e or ""))
  local texts = {}
  for i = 1, (tonumber(tip:NumLines()) or 0) do
    local fs = rawget(env, "GameTooltipTextLeft" .. i)
    texts[#texts + 1] = tostring(fs and fs:GetText())
  end
  print("scenario: its lines: " .. table.concat(texts, " | "))
  -- (the harness's tooltip keeps no lines: what is added is caught)
  local added = {}
  local oldAdd = tip.AddLine
  tip.AddLine = function(self, text, ...) added[#added + 1] = tostring(text) return oldAdd(self, text, ...) end
  local function Added(a, b) for _, t in ipairs(added) do if t:find(a, 1, true) and t:find(b, 1, true) then return true end end return false end
  -- the game's own process (InternalProcessInfo) with data of the harness's: the line after Show
  local data = { type = env.Enum.TooltipDataType.Item, lines = { { leftText = "Linen Cloth", type = 22 } } }
  ok, e = pcall(function()
    -- (the harness's tooltip is a plain frame, without the game's data mixin: its order, post calls then Show)
    tip:SetOwner(env.UIParent, "ANCHOR_NONE")
    G.PostCall(tip, data)
    tip:Show()
    G.Shown(tip) -- (the harness's hooksecurefunc hooks nothing: Clara's hook on Show, called as the game would)
  end)
  local found = Added("Lia Moon", "12/24")
  print("scenario: added " .. table.concat(added, " | "))
  check(ok and found, "the game's own build of an item tooltip: Lia Moon's 12/24 written " .. tostring(e or ""))
  local unit = { type = env.Enum.TooltipDataType.Unit, guid = "Creature-0-1-2-3-113-0", lines = { { leftText = "Kobold Vermin", type = 2 } } }
  ok, e = pcall(function() tip:SetOwner(env.UIParent, "ANCHOR_NONE"); G.PostCall(tip, unit); tip:Show(); G.Shown(tip) end)
  found = Added("Lia Moon", "Kobold Vermin slain")
  if env.Enum.TooltipDataType.Unit == env.Enum.TooltipDataType.Item then
    check(ok, "a creature's: no error (the harness's enums are all 0: an item and a creature not told apart, its line not checked) " .. tostring(e or ""))
  else
    check(ok and found, "a creature's: her 4/10 written " .. tostring(e or ""))
  end
  tip.AddLine = oldAdd
  ok, e = pcall(G.Update, true)
  check(ok, "the log sent (not in a group: nothing) " .. tostring(e or ""))
  ok, e = pcall(G.Report)
  check(ok, "/cl quetes " .. tostring(e or ""))
end
print("scenario: groupquests failures " .. fails)
