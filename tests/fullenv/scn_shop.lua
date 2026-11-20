-- The Shop buttons with the game's own code: the micro menu's Shop button and the Escape menu's, as the game makes
-- them; Clara's in their place; no error
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
local micro = rawget(env, "StoreMicroButton")
print("scenario: StoreMicroButton " .. tostring(micro) .. ", GameMenuFrame " .. tostring(rawget(env, "GameMenuFrame")))
if micro then
  check(micro.tooltipText == "Clara", "its tooltip: " .. tostring(micro.tooltipText))
  local ok, e = pcall(function() if micro.UpdateMicroButton then micro:UpdateMicroButton() end end)
  check(ok and micro.tooltipText == "Clara", "the game's update: still Clara " .. tostring(e or ""))
end
local menu = rawget(env, "GameMenuFrame")
if menu and menu.InitButtons then
  local ok, e = pcall(menu.InitButtons, menu)
  check(ok, "the game's menu made " .. tostring(e or ""))
  local names = {}
  for _, b in ipairs(menu.buttons or {}) do names[#names + 1] = tostring(b:GetText()) end
  print("scenario: its buttons " .. table.concat(names, ", "))
end
print("scenario: shop failures " .. fails)
