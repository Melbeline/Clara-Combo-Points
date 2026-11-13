-- ClassicUI's trainer at a pet trainer: an ability the pet knows already (its spellbook, this rank or a higher one)
-- listed as Already Known (grey, Train off), as Era's, though WoW Forever's pet trainer gives it as available; hidden
-- with Already Known unticked; a class trainer's list left as the game gives it
local H = ...
local env, ns = H.env, H.ns
local P = ns.ClassicUIPrivate
local fails = 0
local function check(c, m) print((c and "scenario ok   " or "scenario FAIL ") .. m) if not c then fails = fails + 1 end end
if not (P and P.TrainerServices) then print("scenario FAIL no trainer list") return end
local services = {
  { "Great Stamina", "available", "Rank 1" }, { "Growl", "available", "Rank 1" }, { "Natural Armor", "available", "Rank 1" },
  { "Growl", "available", "Rank 2" }, { "Great Stamina", "available", "Rank 2" }, { "Natural Armor", "unavailable", "Rank 2" },
}
local pet = { { "Attack", "" }, { "Growl", "Rank 2" }, { "Great Stamina", "Rank 1" }, { "Natural Armor", "Rank 1" }, { "Claw", "Rank 1" } }
local trainerType, usedShown = 1, true
rawset(env.Enum, "TrainerType", { General = 0, TalentsObsolete = 1, Tradeskills = 2, Pet = 3 }) -- (the game's values)
local petType = 3
env.C_Trainer = env.C_Trainer or {}
env.C_Trainer.GetTrainerType = function() return trainerType end
env.GetNumTrainerServices = function() return #services end
env.GetTrainerServiceInfo = function(i) local s = services[i] if s then return s[1], s[2], 136000, 1, s[3], nil end end
env.GetTrainerServiceTypeFilter = function(kind) if kind == "used" then return usedShown end return true end
env.C_SpellBook = env.C_SpellBook or {}
env.C_SpellBook.HasPetSpells = function() return #pet, "PET" end
env.C_SpellBook.GetSpellBookItemName = function(i, bank) local s = pet[i] if s and bank == env.Enum.SpellBookSpellBank.Pet then return s[1], s[2] end end
local function Kinds()
  local order, groups = P.TrainerServices()
  local out = {}
  for _, category in ipairs(order) do
    for _, line in ipairs(groups[category]) do out[#out + 1] = line.name .. " " .. line.sub .. "=" .. line.kind end
  end
  return table.concat(out, ", ")
end
trainerType = petType
local got = Kinds()
check(got == "Great Stamina Rank 1=used, Growl Rank 1=used, Natural Armor Rank 1=used, Growl Rank 2=used, Great Stamina Rank 2=available, Natural Armor Rank 2=unavailable", got)
usedShown = false
got = Kinds()
check(got == "Great Stamina Rank 2=available, Natural Armor Rank 2=unavailable", "Already Known unticked: hidden (" .. got .. ")")
usedShown, trainerType = true, 0
got = Kinds()
check(not got:find("=used", 1, true), "a class trainer: the game's list as it is (" .. got .. ")")
print("scenario: pet trainer failures " .. fails)
