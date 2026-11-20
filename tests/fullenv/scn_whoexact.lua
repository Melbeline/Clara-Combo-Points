-- Exact names on the Who tab, with the harness's frames: the game's Who tab as WhoList.xml makes it (its search line
-- a SearchBoxTemplate at 56,-40, 255 wide), the group finder loaded, the box made, the line narrower, a name typed
-- and the box ticked and unticked: no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local frame = rawget(env, "LFGWhoListFrame")
print("scenario: the game's LFGWhoListFrame " .. tostring(frame) .. ", its EditBox " .. tostring(frame and frame.EditBox))
if not (frame and frame.EditBox) then
  local ok, e = pcall(function()
    frame = env.CreateFrame("Frame", "LFGWhoListFrame", env.UIParent)
    local edit = env.CreateFrame("EditBox", "WhoFrameEditBox", frame, "SearchBoxTemplate")
    edit:SetSize(255, 20)
    edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 56, -40)
    frame.EditBox = edit
  end)
  check(ok, "a Who tab as the game makes it " .. tostring(e or ""))
end
H.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
local exact = ns.WhoExactBox and ns.WhoExactBox()
check(exact ~= nil, "the exact names box made")
if exact then
  local edit = frame.EditBox
  local _, _, _, x = edit:GetPoint(1)
  print("scenario: the line at " .. tostring(x) .. ", " .. tostring(edit:GetWidth()) .. " wide")
  local ok, e = pcall(function()
    exact:SetChecked(true); exact:GetScript("OnClick")(exact)
    edit:SetText("charlotte"); edit:GetScript("OnTextChanged")(edit, true)
    exact:GetScript("OnEnter")(exact); exact:GetScript("OnLeave")(exact)
    exact:SetChecked(false); exact:GetScript("OnClick")(exact)
  end)
  check(ok, "ticked, typed, its tooltip, unticked: no error " .. tostring(e or ""))
  print("scenario: the line's text after " .. tostring(edit:GetText()))
end
-- Sort by guild: the game's filter menu, its Sort part, Guild after Level
local util = rawget(env, "LFGWhoListFilterUtil")
local MU = rawget(env, "MenuUtil")
print("scenario: LFGWhoListFilterUtil " .. tostring(util) .. ", root descriptions " .. tostring(MU and MU.CreateRootMenuDescription))
if util and util.SetupFilterMenu and MU and MU.CreateRootMenuDescription and rawget(env, "MenuVariants") then
  local ok, e = pcall(function()
    local root = MU.CreateRootMenuDescription(env.MenuVariants.GetDefaultContextMenuMixin())
    util.InitSortOptions(root)
    local texts = {}
    for _, d in root:EnumerateElementDescriptions() do
      for _, c in d:EnumerateElementDescriptions() do texts[#texts + 1] = tostring(MU.GetElementText(c)) end
    end
    print("scenario: its Sort part " .. table.concat(texts, ","))
  end)
  check(ok, "the game's Sort part made, Guild added: no error " .. tostring(e or ""))
elseif ns.WhoAddGuildSort then
  local ok, e = pcall(ns.WhoAddGuildSort, nil)
  check(ok, "no menu in the harness: nothing done, no error " .. tostring(e or ""))
end
print("scenario: who exact failures " .. fails)
