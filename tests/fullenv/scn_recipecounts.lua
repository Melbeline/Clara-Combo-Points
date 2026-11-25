-- The recipe list's craftable counts (RecipeCounts.lua) on the game's own row template (ProfessionsRecipeListRecipeTemplate):
-- Clara's count and its fitting run on a real row, no error. (The harness's hooksecurefunc does nothing: they are called
-- as the hooks would be; test145 checks the counts and colours.)
local H = ...
local env, ns = H.env, H.ns
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
check(ns.RecipeCountRow ~= nil and ns.RecipeCraftable ~= nil, "loaded")
local ok, row = pcall(env.CreateFrame, "Button", nil, env.UIParent, "ProfessionsRecipeListRecipeTemplate")
print("scenario: the game's recipe row " .. tostring(ok and row ~= nil) .. " " .. tostring(not ok and row or ""))
if ok and row then
  local info = { recipeID = 2538, name = "Charred Wolf Meat", learned = true, relativeDifficulty = 0 }
  local node = { data = { recipeInfo = info } }
  row.GetElementData = function() return node end
  local e
  ok, e = pcall(ns.RecipeCountRow, row, false)
  check(ok, "Clara's count on it: no error " .. tostring(e or ""))
  ok, e = pcall(ns.RecipeCountFit, row)
  check(ok, "its name fitted: no error " .. tostring(e or ""))
end
print("scenario: recipecounts failures " .. fails)
