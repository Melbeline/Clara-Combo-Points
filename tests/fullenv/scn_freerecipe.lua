-- ClassicUI's trade skill window (avec): a recipe that costs no reagents (WoW Forever 70938's C_TradeSkillUI.HasNoReagentCost:
-- a talent can waive them) counts as craftable (Create on, up to 99 at once), never as one the bags make; a recipe
-- with its reagents counted from the bags as before; the talents changed, each recipe's cost read again
local H = ...
local env, ns = H.env, H.ns
local P = ns.ClassicUIPrivate
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
if not (P and P.TradeCraftable) then print("scenario FAIL no trade skill count") return end
local free = { [9001] = true }
local reads = 0
local need = 2
env.C_TradeSkillUI.HasNoReagentCost = function(id) return free[id] == true end
env.C_TradeSkillUI.GetRecipeSchematic = function(id)
  reads = reads + 1
  return { recipeID = id, reagentSlotSchematics = { { reagentType = env.Enum.CraftingReagentType and env.Enum.CraftingReagentType.Basic, quantityRequired = need, dataSlotIndex = 1,
    reagents = { { itemID = 2589 } } } } }
end
local have = 5
env.C_Item = env.C_Item or {}
local count = env.C_Item.GetItemCount
env.C_Item.GetItemCount = function(id, ...) if id == 2589 then return have end return count and count(id, ...) or 0 end
env.GetItemCount = function(id) if id == 2589 then return have end return 0 end
check(P.TradeFree(9001) and not P.TradeFree(9002), "free: the one the game says costs nothing")
check(P.TradeCraftable({ recipeID = 9001 }) == 99, "free: Create on, up to 99 at once (" .. tostring(P.TradeCraftable({ recipeID = 9001 })) .. ")")
local got = P.TradeCraftable({ recipeID = 9002 })
check(got == 2, "with reagents: what the bags make, 5 linen for 2 each (" .. tostring(got) .. ")")
local before = reads
P.TradeCraftable({ recipeID = 9002 })
check(reads == before, "its cost read once")
need = 1
H.Fire("PLAYER_TALENT_UPDATE")
got = P.TradeCraftable({ recipeID = 9002 })
check(reads == before + 1 and got == 5, "the talents changed: its cost read again, 1 each now (" .. tostring(got) .. ")")
free[9002] = true
check(P.TradeCraftable({ recipeID = 9002 }) == 99, "a talent made it free: craftable")
env.C_TradeSkillUI.HasNoReagentCost = nil
check(P.TradeCraftable({ recipeID = 9001 }) ~= 99, "an older build without the call: counted from the bags")
print(("scenario %d failure(s)"):format(fails))
