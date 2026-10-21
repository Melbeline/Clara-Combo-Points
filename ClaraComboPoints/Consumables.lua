-- Clara Combo Points - the consumables of the class spells panel, by kind, to put on the icon
-- rows (Items.lua). { kind, item ID, item ID, ... } -- names. kind: ITEM, or WEAPON (an item
-- that enchants a weapon: its icon watches the enchantment; the IDs of a line are one family,
-- every rank of a poison or of an oil, watched as one). Items the game does not know (WoW
-- Forever still hides some of its own) are left out of the panel.

local _, ns = ...

ns.CONSUMABLES = {
  { group = "POTIONS", items = {
    { "ITEM", 118, 858, 929, 1710, 3928, 13446 },   -- Minor, Lesser, (plain), Greater, Superior, Major Healing Potion
    { "ITEM", 2455, 3385, 3827, 6149, 13443, 13444 }, -- Minor, Lesser, (plain), Greater, Superior, Major Mana Potion
    { "ITEM", 5631, 5633, 13442 },                   -- Rage, Great Rage, Mighty Rage Potion
    { "ITEM", 2456, 9144, 18253 },                   -- Minor Rejuvenation, Wildvine, Major Rejuvenation Potion
    { "ITEM", 5634 },                                -- Free Action Potion
    { "ITEM", 3387 },                                -- Limited Invulnerability Potion
    { "ITEM", 2459 },                                -- Swiftness Potion
    { "ITEM", 9030 },                                -- Restorative Potion
    { "ITEM", 6048, 6049, 6050, 6051, 6052 },        -- Shadow, Fire, Frost, Holy, Nature Protection Potion
    { "ITEM", 13456, 13457, 13458, 13459, 13461 },   -- Greater Frost, Fire, Nature, Shadow, Arcane Protection Potion
  } },
  { group = "OTHER", items = {
    { "ITEM", 5512, 5511, 5509, 5510, 9421 },        -- Minor, Lesser, (plain), Greater, Major Healthstone
    { "ITEM", 5514, 5513, 8007, 8008 },              -- Mana Agate, Mana Jade, Mana Citrine, Mana Ruby
    { "ITEM", 20520, 12662 },                        -- Dark Rune, Demonic Rune
    { "ITEM", 7676 },                                -- Thistle Tea
    { "ITEM", 11951, 11952 },                        -- Whipper Root Tuber, Night Dragon's Breath
  } },
  { group = "BANDAGES", items = {
    { "ITEM", 1251, 2581, 3530, 3531, 6450, 6451, 8544, 8545, 14529, 14530 }, -- Linen to Heavy Runecloth Bandage
  } },
  { group = "WEAPON", items = {
    { "WEAPON", 6947, 6949, 6950, 8926, 8927, 8928 }, -- Instant Poison I to VI
    { "WEAPON", 2892, 2893, 8984, 8985, 20844 },     -- Deadly Poison I to V
    { "WEAPON", 3775, 3776 },                        -- Crippling Poison I, II
    { "WEAPON", 5237, 6951, 9186 },                  -- Mind-numbing Poison I to III
    { "WEAPON", 10918, 10920, 10921, 10922 },        -- Wound Poison I to IV
    { "WEAPON", 2862, 2863, 2871, 7964, 12404 },     -- Rough to Dense Sharpening Stone
    { "WEAPON", 18262 },                             -- Elemental Sharpening Stone
    { "WEAPON", 23122 },                             -- Consecrated Sharpening Stone
    { "WEAPON", 3239, 3240, 3241, 7965, 12643 },     -- Rough to Dense Weightstone
    { "WEAPON", 20744, 20746, 20750, 20749 },        -- Minor, Lesser, (plain), Brilliant Wizard Oil
    { "WEAPON", 20745, 20747, 20748 },               -- Minor, Lesser, Brilliant Mana Oil
    { "WEAPON", 23123 },                             -- Blessed Wizard Oil
    { "WEAPON", 3824 },                              -- Shadow Oil
    { "WEAPON", 3829 },                              -- Frost Oil
  } },
}
