-- An enchant put on in one click (EnchantConfirm.lua) in the harness: the box made on the game's own crafting page (its
-- template, if the harness builds it), its update run; the game's three questions answered with the box ticked: no error.
-- test150 checks the rest.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns.EnchantConfirmSetup ~= nil and ns.EnchantConfirmAnswer ~= nil, "loaded")
local pf = rawget(env, "ProfessionsFrame")
print("scenario: the game's professions window " .. tostring(pf ~= nil and pf.CraftingPage ~= nil))
if not (pf and pf.CraftingPage) then
  local ok, page = pcall(env.CreateFrame, "Frame", nil, env.UIParent, "ProfessionsCraftingPageTemplate")
  print("scenario: its crafting page made here " .. tostring(ok and page ~= nil) .. " " .. tostring(not ok and page or ""))
  if ok and page then
    pf = pf or env.CreateFrame("Frame", "ProfessionsFrame", env.UIParent)
    pf.CraftingPage = page
    rawset(env, "ProfessionsFrame", pf)
  end
end
if pf and pf.CraftingPage then
  local ok, e = pcall(ns.EnchantConfirmSetup)
  check(ok, "the box made: no error " .. tostring(e or ""))
  ok, e = pcall(ns.EnchantConfirmUpdate)
  check(ok, "its update: no error " .. tostring(e or ""))
  check(rawget(env, "ClaraEnchantConfirmBox") ~= nil, "on the page")
end
ns:SetEnchantConfirm(true)
for _, which in ipairs({ "REPLACE_TRADESKILL_ENCHANT", "REPLACE_ENCHANT", "TRADE_REPLACE_ENCHANT" }) do
  local ok, e = pcall(ns.EnchantConfirmAnswer, which)
  check(ok, which .. " answered: no error " .. tostring(e or ""))
end
ns:SetEnchantConfirm(false)
print("scenario: enchantconfirm failures " .. fails)
