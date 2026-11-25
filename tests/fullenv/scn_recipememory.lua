-- The professions window opened again on the recipe picked last (RecipeMemory.lua) in the harness: its hooks on the
-- game's own crafting page (its template, if the harness builds it): the page set up, a recipe picked, set up again;
-- no error. test152 checks the rest.
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns.RecipeMemoryRestore ~= nil, "loaded")
local ok, page = pcall(env.CreateFrame, "Frame", nil, env.UIParent, "ProfessionsCraftingPageTemplate")
print("scenario: the game's crafting page made here " .. tostring(ok and page ~= nil))
if ok and page then
  page.professionInfo = { professionID = 185 }
  local e
  ok, e = pcall(ns.RecipeMemoryPicked, page, { recipeID = 2538 }, page.RecipeList)
  check(ok, "a recipe picked: no error " .. tostring(e or ""))
  ok, e = pcall(ns.RecipeMemoryRestore, page, { professionID = 185 })
  check(ok, "set up again: no error " .. tostring(e or ""))
end
print("scenario: recipememory failures " .. fails)
