-- Clara Combo Points - every buff and debuff of each class: the class spells panel (Options.lua)
-- and spells typed by name (Tracker.lua).
-- { kind, rank 1 ID, rank 2 ID, ... } -- name
--   kind: BUFF (helpful), DEBUFF (on enemies), SELFDEBUFF (harmful, on yourself or your allies:
--   Weakened Soul, Forbearance...). alt: the same ranks under a second ID, as WoW Forever has
--   some spells twice (false: none for that rank).
-- Names are read from the game, in its language; spells the game does not know are left out.
-- Sources: LibClassicDurations, Classic Era spell data (checked rank by rank), and WoW Forever's
-- own spell and trainer tables (build 1.60.1) for its second IDs, its extra ranks and its spells.

local _, ns = ...

ns.SPELL_CATALOG = {
  { class = "PRIEST", spells = {
    { "BUFF", 552 }, -- Abolish Disease
    { "DEBUFF", 15269 }, -- Blackout
    { "BUFF", 27813, 27817, 27818 }, -- Blessed Recovery
    { "DEBUFF", 2944, 19276, 19277, 19278, 19279, 19280 }, -- Devouring Plague
    { "BUFF", 425294 }, -- Dispersion
    { "BUFF", 14752, 14818, 14819, 27841 }, -- Divine Spirit
    { "BUFF", 2651, 19289, 19291, 19292, 19293 }, -- Elune's Grace
    { "BUFF", 586, 9578, 9579, 9592, 10941, 10942 }, -- Fade
    { "BUFF", 6346 }, -- Fear Ward
    { "BUFF", 13896, 19271, 19273, 19274, 19275 }, -- Feedback
    { "BUFF", 14743, 27828 }, -- Focused Casting
    { "DEBUFF", 9035, 19281, 19282, 19283, 19284, 19285 }, -- Hex of Weakness
    { "DEBUFF", 14914, 15262, 15263, 15264, 15265, 15266, 15267, 15261 }, -- Holy Fire
    { "BUFF", 588, 7128, 602, 1006, 10951, 10952 }, -- Inner Fire
    { "BUFF", 14751 }, -- Inner Focus
    { "BUFF", 14893, 15357, 15359 }, -- Inspiration
    { "BUFF", 1706 }, -- Levitate
    { "BUFF", 7001, 27873, 27874 }, -- Lightwell Renew
    { "DEBUFF", 605, 10911, 10912 }, -- Mind Control
    { "DEBUFF", 15407, 17311, 17312, 17313, 17314, 18807 }, -- Mind Flay
    { "DEBUFF", 453, 8192, 10953 }, -- Mind Soothe
    { "BUFF", 402004 }, -- Pain Suppression
    { "BUFF", 10060 }, -- Power Infusion
    { "BUFF", 425207 }, -- Power Word: Barrier
    { "BUFF", 1243, 1244, 1245, 2791, 10937, 10938 }, -- Power Word: Fortitude
    { "BUFF", 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 }, -- Power Word: Shield
    { "BUFF", 21562, 21564 }, -- Prayer of Fortitude
    { "BUFF", 27683 }, -- Prayer of Shadow Protection
    { "BUFF", 27681 }, -- Prayer of Spirit
    { "DEBUFF", 8122, 8124, 10888, 10890 }, -- Psychic Scream
    { "BUFF", 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315, alt = { 425268, 425269, 425270, 425271, 425272, 425273, 425274, 425275, 425276, 425277 } }, -- Renew
    { "DEBUFF", 9484, 9485, 10955 }, -- Shackle Undead
    { "BUFF", 976, 10957, 10958 }, -- Shadow Protection
    { "DEBUFF", 15258 }, -- Shadow Vulnerability (Shadow Weaving)
    { "DEBUFF", 589, 594, 970, 992, 2767, 10892, 10893, 10894 }, -- Shadow Word: Pain
    { "BUFF", 15473 }, -- Shadowform
    { "BUFF", 18137, 19308, 19309, 19310, 19311, 19312 }, -- Shadowguard
    { "DEBUFF", 15487 }, -- Silence
    { "BUFF", 27827 }, -- Spirit of Redemption
    { "BUFF", 15271 }, -- Spirit Tap
    { "DEBUFF", 10797, 19296, 19299, 19302, 19303, 19304, 19305 }, -- Starshards
    { "BUFF", 2652, 19261, 19262, 19264, 19265, 19266 }, -- Touch of Weakness
    { "DEBUFF", 2943, 19249, 19251, 19252, 19253, 19254 }, -- Touch of Weakness
    { "DEBUFF", 15286 }, -- Vampiric Embrace
    { "SELFDEBUFF", 6788 }, -- Weakened Soul
  } },
  { class = "MAGE", spells = {
    { "BUFF", 1008, 8455, 10169, 10170 }, -- Amplify Magic
    { "BUFF", 23028 }, -- Arcane Brilliance
    { "BUFF", 1459, 1460, 1461, 10156, 10157 }, -- Arcane Intellect
    { "BUFF", 12042 }, -- Arcane Power
    { "BUFF", 425124 }, -- Arcane Surge
    { "DEBUFF", 11113, 13018, 13019, 13020, 13021 }, -- Blast Wave
    { "DEBUFF", 10, 6141, 8427, 10185, 10186, 10187 }, -- Blizzard
    { "DEBUFF", 6136 }, -- Chilled (Frost Armor)
    { "DEBUFF", 7321 }, -- Chilled (Ice Armor)
    { "DEBUFF", 12484, 12485, 12486 }, -- Chilled (Improved Blizzard)
    { "BUFF", 12536 }, -- Clearcasting
    { "BUFF", 28682 }, -- Combustion
    { "DEBUFF", 120, 8492, 10159, 10160, 10161 }, -- Cone of Cold
    { "DEBUFF", 18469 }, -- Counterspell - Silenced
    { "BUFF", 604, 8450, 8451, 10173, 10174 }, -- Dampen Magic
    { "BUFF", 2855 }, -- Detect Magic
    { "BUFF", 12051 }, -- Evocation
    { "DEBUFF", 22959 }, -- Fire Vulnerability
    { "BUFF", 543, 8457, 8458, 10223, 10225 }, -- Fire Ward
    { "DEBUFF", 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 }, -- Fireball
    { "DEBUFF", 2120, 2121, 8422, 8423, 10215, 10216 }, -- Flamestrike
    { "BUFF", 168, 7300, 7301 }, -- Frost Armor
    { "DEBUFF", 122, 865, 6131, 10230 }, -- Frost Nova
    { "BUFF", 6143, 8461, 8462, 10177, 28609 }, -- Frost Ward
    { "DEBUFF", 12494 }, -- Frostbite
    { "DEBUFF", 116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304 }, -- Frostbolt
    { "BUFF", 7302, 7320, 10219, 10220 }, -- Ice Armor
    { "BUFF", 11426, 13031, 13032, 13033 }, -- Ice Barrier
    { "BUFF", 11958 }, -- Ice Block
    { "DEBUFF", 12654 }, -- Ignite
    { "DEBUFF", 12355 }, -- Impact
    { "BUFF", 6117, 22782, 22783 }, -- Mage Armor
    { "BUFF", 1463, 8494, 8495, 10191, 10192, 10193 }, -- Mana Shield
    { "DEBUFF", 118, 12824, 12825, 12826 }, -- Polymorph
    { "DEBUFF", 28270 }, -- Polymorph: Cow
    { "DEBUFF", 28272 }, -- Polymorph: Pig
    { "DEBUFF", 28271 }, -- Polymorph: Turtle
    { "BUFF", 12043 }, -- Presence of Mind
    { "DEBUFF", 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 }, -- Pyroblast
    { "BUFF", 130 }, -- Slow Fall
    { "DEBUFF", 12579 }, -- Winter's Chill
  } },
  { class = "WARLOCK", spells = {
    { "DEBUFF", 18118 }, -- Aftermath
    { "BUFF", 18288 }, -- Amplify Curse
    { "DEBUFF", 710, 18647 }, -- Banish
    { "BUFF", 6307, 7804, 7805, 11766, 11767 }, -- Blood Pact
    { "BUFF", 18789 }, -- Burning Wish
    { "DEBUFF", 172, 6222, 6223, 7648, 11671, 11672, 25311 }, -- Corruption
    { "DEBUFF", 980, 1014, 6217, 11711, 11712, 11713 }, -- Curse of Agony
    { "DEBUFF", 603 }, -- Curse of Doom
    { "DEBUFF", 18223 }, -- Curse of Exhaustion
    { "DEBUFF", 704, 7658, 7659, 11717 }, -- Curse of Recklessness
    { "DEBUFF", 17862, 17937 }, -- Curse of Shadow
    { "DEBUFF", 440892, 1311676, 1311677, 1311680 }, -- Curse of the Elements
    { "DEBUFF", 1714, 11719 }, -- Curse of Tongues
    { "DEBUFF", 702, 1108, 6205, 7646, 11707, 11708 }, -- Curse of Weakness
    { "DEBUFF", 6789, 17925, 17926 }, -- Death Coil
    { "BUFF", 706, 1086, 11733, 11734, 11735 }, -- Demon Armor
    { "BUFF", 687, 696 }, -- Demon Skin
    { "BUFF", 132, 2970, 11743 }, -- Detect Invisibility
    { "DEBUFF", 689, 699, 709, 7651, 11699, 11700, alt = { 403677, 403685, 403686, 403687, 403688, 403689 } }, -- Drain Life
    { "DEBUFF", 5138, 6226, 11703, 11704 }, -- Drain Mana
    { "DEBUFF", 1120, 8288, 8289, 11675 }, -- Drain Soul
    { "DEBUFF", 5782, 6213, 6215 }, -- Fear
    { "BUFF", 18708 }, -- Fel Domination
    { "BUFF", 18792 }, -- Fel Energy
    { "BUFF", 18790 }, -- Fel Stamina
    { "BUFF", 2947, 8316, 8317, 11770, 11771 }, -- Fire Shield
    { "DEBUFF", 5484, 17928 }, -- Howl of Terror
    { "DEBUFF", 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 }, -- Immolate
    { "DEBUFF", 22703 }, -- Inferno Effect
    { "BUFF", 23762, 23837, 23838, 23839, 23840 }, -- Master Demonologist (Felhunter)
    { "BUFF", 23759, 23826, 23827, 23828, 23829 }, -- Master Demonologist (Imp)
    { "BUFF", 23761, 23833, 23834, 23835, 23836 }, -- Master Demonologist (Succubus)
    { "BUFF", 23760, 23841, 23842, 23843, 23844 }, -- Master Demonologist (Voidwalker)
    { "BUFF", 19480 }, -- Paranoia
    { "DEBUFF", 18093 }, -- Pyroclasm
    { "DEBUFF", 5740, 6219, 11677, 11678 }, -- Rain of Fire
    { "BUFF", 7812, 19438, 19440, 19441, 19442, 19443 }, -- Sacrifice
    { "DEBUFF", 6358 }, -- Seduction
    { "BUFF", 17941 }, -- Shadow Trance
    { "DEBUFF", 17794, 17798, 17797, 17799, 17800 }, -- Shadow Vulnerability (Improved Shadow Bolt)
    { "BUFF", 6229, 11739, 11740, 28610 }, -- Shadow Ward
    { "DEBUFF", 17877, 18867, 18868, 18869, 18870, 18871 }, -- Shadowburn
    { "DEBUFF", 18265, 18879, 18880, 18881 }, -- Siphon Life
    { "BUFF", 25228 }, -- Soul Link
    { "BUFF", 18371 }, -- Soul Siphon
    { "BUFF", 20707, 20762, 20763, 20764, 20765 }, -- Soulstone Resurrection
    { "DEBUFF", 24259 }, -- Spell Lock
    { "DEBUFF", 1098, 11725, 11726 }, -- Subjugate Demon
    { "BUFF", 18791 }, -- Touch of Shadow
    { "BUFF", 5697 }, -- Unending Breath
  } },
  { class = "ROGUE", spells = {
    { "BUFF", 13750 }, -- Adrenaline Rush
    { "BUFF", 13877 }, -- Blade Flurry
    { "DEBUFF", 2094 }, -- Blind
    { "DEBUFF", 1833 }, -- Cheap Shot
    { "BUFF", 14177 }, -- Cold Blood
    { "DEBUFF", 3409, 11201 }, -- Crippling Poison
    { "DEBUFF", 2818, 2819, 11353, 11354, 25349 }, -- Deadly Poison
    { "BUFF", 5277 }, -- Evasion
    { "DEBUFF", 8647, 8649, 8650, 11197, 11198 }, -- Expose Armor
    { "DEBUFF", 703, 8631, 8632, 8633, 11289, 11290 }, -- Garrote
    { "BUFF", 14278 }, -- Ghostly Strike
    { "DEBUFF", 1776, 1777, 8629, 11285, 11286 }, -- Gouge
    { "DEBUFF", 16511, 17347, 17348 }, -- Hemorrhage
    { "DEBUFF", 18425 }, -- Kick - Silenced
    { "DEBUFF", 408, 8643 }, -- Kidney Shot
    { "DEBUFF", 5530 }, -- Mace Stun Effect
    { "DEBUFF", 5760, 8692, 11398 }, -- Mind-numbing Poison
    { "BUFF", 14183 }, -- Premeditation
    { "BUFF", 14143, 14149 }, -- Remorseless
    { "DEBUFF", 14251 }, -- Riposte
    { "DEBUFF", 1943, 8639, 8640, 11273, 11274, 11275 }, -- Rupture
    { "DEBUFF", 6770, 2070, 11297 }, -- Sap
    { "BUFF", 5171, 6774 }, -- Slice and Dice
    { "BUFF", 2983, 8696, 11305 }, -- Sprint
    { "BUFF", 1784, 1785, 1786, 1787 }, -- Stealth
    { "BUFF", 11327, 11329 }, -- Vanish
    { "DEBUFF", 13218, 13222, 13223, 13224 }, -- Wound Poison
  } },
  { class = "DRUID", spells = {
    { "BUFF", 2893 }, -- Abolish Poison
    { "BUFF", 1066 }, -- Aquatic Form
    { "BUFF", 22812 }, -- Barkskin
    { "DEBUFF", 5211, 6798, 8983 }, -- Bash
    { "BUFF", 5487 }, -- Bear Form
    { "BUFF", 417141 }, -- Berserk
    { "BUFF", 768 }, -- Cat Form
    { "DEBUFF", 5209 }, -- Challenging Roar
    { "BUFF", 16870 }, -- Clearcasting
    { "BUFF", 1850, 9821 }, -- Dash
    { "DEBUFF", 99, 1735, 9490, 9747, 9898 }, -- Demoralizing Roar
    { "BUFF", 9634 }, -- Dire Bear Form
    { "BUFF", 5229 }, -- Enrage
    { "DEBUFF", 339, 1062, 5195, 5196, 9852, 9853 }, -- Entangling Roots
    { "DEBUFF", 19975, 19974, 19973, 19972, 19971, 19970 }, -- Entangling Roots (Nature's Grasp)
    { "DEBUFF", 770, 778, 9749, 9907 }, -- Faerie Fire
    { "DEBUFF", 16857, 17390, 17391, 17392 }, -- Faerie Fire (Feral)
    { "DEBUFF", 19675 }, -- Feral Charge Effect
    { "BUFF", 22842, 22895, 22896 }, -- Frenzied Regeneration
    { "BUFF", 21849, 21850 }, -- Gift of the Wild
    { "DEBUFF", 6795 }, -- Growl
    { "DEBUFF", 2637, 18657, 18658 }, -- Hibernate
    { "DEBUFF", 16914, 17401, 17402 }, -- Hurricane
    { "BUFF", 29166 }, -- Innervate
    { "DEBUFF", 5570, 24974, 24975, 24976, 24977 }, -- Insect Swarm
    { "BUFF", 24932 }, -- Leader of the Pack
    { "BUFF", 408124, alt = { 408245 } }, -- Lifebloom
    { "BUFF", 1126, 5232, 6756, 5234, 8907, 9884, 9885 }, -- Mark of the Wild
    { "DEBUFF", 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 }, -- Moonfire
    { "BUFF", 24907 }, -- Moonkin Aura
    { "BUFF", 24858 }, -- Moonkin Form
    { "BUFF", 16886 }, -- Nature's Grace
    { "BUFF", 16689, 16810, 16811, 16812, 16813, 17329 }, -- Nature's Grasp
    { "BUFF", 17116 }, -- Nature's Swiftness
    { "BUFF", 16864 }, -- Omen of Clarity
    { "DEBUFF", 9005, 9823, 9827 }, -- Pounce
    { "DEBUFF", 9007, 9824, 9826 }, -- Pounce Bleed
    { "BUFF", 5215, 6783, 9913 }, -- Prowl
    { "DEBUFF", 1822, 1823, 1824, 9904 }, -- Rake
    { "BUFF", 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 }, -- Regrowth
    { "BUFF", 774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 }, -- Rejuvenation
    { "DEBUFF", 1079, 9492, 9493, 9752, 9894, 9896 }, -- Rip
    { "DEBUFF", 2908, 8955, 9901 }, -- Soothe Animal
    { "DEBUFF", 16922 }, -- Starfire Stun
    { "BUFF", 408024 }, -- Survival Instincts
    { "BUFF", 467, 782, 1075, 8914, 9756, 9910 }, -- Thorns
    { "BUFF", 5217, 6793, 9845, 9846 }, -- Tiger's Fury
    { "BUFF", 740, 8918, 9862, 9863 }, -- Tranquility
    { "BUFF", 783 }, -- Travel Form
    { "BUFF", 408120, 1238214, 1238215 }, -- Wild Growth
  } },
  { class = "HUNTER", spells = {
    { "BUFF", 13161, 1299445, 1299446, 1299447 }, -- Aspect of the Beast
    { "BUFF", 5118 }, -- Aspect of the Cheetah
    { "BUFF", 13165, 14318, 14319, 14320, 14321, 14322, 25296 }, -- Aspect of the Hawk
    { "BUFF", 13163 }, -- Aspect of the Monkey
    { "BUFF", 13159 }, -- Aspect of the Pack
    { "BUFF", 20043, 20190 }, -- Aspect of the Wild
    { "DEBUFF", 5116 }, -- Concussive Shot
    { "DEBUFF", 19306, 20909, 20910 }, -- Counterattack
    { "SELFDEBUFF", 15571 }, -- Dazed
    { "BUFF", 19263 }, -- Deterrence
    { "DEBUFF", 19185 }, -- Entrapment
    { "DEBUFF", 13812, 14314, 14315 }, -- Explosive Trap Effect
    { "BUFF", 5384 }, -- Feign Death
    { "DEBUFF", 3355, 14308, 14309 }, -- Freezing Trap Effect
    { "DEBUFF", 13810 }, -- Frost Trap Aura
    { "DEBUFF", 1130, 14323, 14324, 14325 }, -- Hunter's Mark
    { "DEBUFF", 13797, 14298, 14299, 14300, 14301 }, -- Immolation Trap Effect
    { "DEBUFF", 19410 }, -- Improved Concussive Shot
    { "DEBUFF", 19229 }, -- Improved Wing Clip
    { "DEBUFF", 24394 }, -- Intimidation
    { "BUFF", 6150 }, -- Quick Shots
    { "BUFF", 3045 }, -- Rapid Fire
    { "DEBUFF", 1513, 14326, 14327 }, -- Scare Beast
    { "DEBUFF", 19503 }, -- Scatter Shot
    { "DEBUFF", 3043, 14275, 14276, 14277 }, -- Scorpid Sting
    { "DEBUFF", 1978, 13549, 13550, 13551, 13552, 13553, 13554, 13555, 25295, alt = { 425728, 425729, 425730, 425732, 425733, 425734, 425735, 425736, 425737 } }, -- Serpent Sting
    { "BUFF", 19579, 24529 }, -- Spirit Bond
    { "BUFF", 19506, 20905, 20906 }, -- Trueshot Aura
    { "DEBUFF", 3034, 14279, 14280 }, -- Viper Sting
    { "DEBUFF", 2974, 14267, 14268 }, -- Wing Clip
    { "DEBUFF", 19386, 24132, 24133 }, -- Wyvern Sting
    { "DEBUFF", 24131, 24134, 24135 }, -- Wyvern Sting (DoT)
  } },
  { class = "SHAMAN", spells = {
    { "BUFF", 16177, 16236, 16237 }, -- Ancestral Fortitude
    { "BUFF", 16246 }, -- Clearcasting
    { "BUFF", 408514, alt = { 408519 } }, -- Earth Shield
    { "DEBUFF", 3600 }, -- Earthbind
    { "BUFF", 30165, 29177, 29178 }, -- Elemental Devastation
    { "BUFF", 16166 }, -- Elemental Mastery
    { "BUFF", 8185, 10534, 10535 }, -- Fire Resistance
    { "DEBUFF", 8050, 8052, 8053, 10447, 10448, 29228 }, -- Flame Shock
    { "BUFF", 16257, 16277, 16278, 16279, 16280 }, -- Flurry
    { "BUFF", 29063 }, -- Focused Casting
    { "BUFF", 8182, 10476, 10477 }, -- Frost Resistance
    { "DEBUFF", 8056, 8058, 10472, 10473 }, -- Frost Shock
    { "DEBUFF", 8034, 8037, 10458, 16352, 16353 }, -- Frostbrand Attack
    { "BUFF", 2645 }, -- Ghost Wolf
    { "BUFF", 8836, 10626, 25360 }, -- Grace of Air
    { "BUFF", 8178 }, -- Grounding Totem Effect
    { "BUFF", 5672, 6371, 6372, 10460, 10461 }, -- Healing Stream
    { "BUFF", 29203 }, -- Healing Way
    { "BUFF", 324, 325, 905, 945, 8134, 10431, 10432 }, -- Lightning Shield
    { "BUFF", 408505 }, -- Maelstrom Weapon
    { "BUFF", 5677, 10491, 10493, 10494 }, -- Mana Spring
    { "BUFF", 16191, 17355, 17360 }, -- Mana Tide
    { "BUFF", 10596, 10598, 10599 }, -- Nature Resistance
    { "BUFF", 16188 }, -- Nature's Swiftness
    { "BUFF", 425336 }, -- Rage of the Farseer
    { "BUFF", 408521, 1239242, 1239243 }, -- Riptide
    { "BUFF", 6495 }, -- Sentry Totem
    { "BUFF", 408696 }, -- Spirit of the Alpha
    { "BUFF", 8072, 8156, 8157, 10403, 10404, 10405 }, -- Stoneskin
    { "DEBUFF", 17364 }, -- Stormstrike
    { "BUFF", 8076, 8162, 8163, 10441, 25362 }, -- Strength of Earth
    { "BUFF", 77747 }, -- Totemic Wrath
    { "BUFF", 25909 }, -- Tranquil Air
    { "BUFF", 131 }, -- Water Breathing
    { "BUFF", 408510 }, -- Water Shield
    { "BUFF", 546 }, -- Water Walking
    { "BUFF", 15108, 15109, 15110 }, -- Windwall
  } },
  { class = "PALADIN", spells = {
    { "BUFF", 407788 }, -- Avenging Wrath
    { "BUFF", 407613 }, -- Beacon of Light
    { "BUFF", 1044 }, -- Blessing of Freedom
    { "BUFF", 20217 }, -- Blessing of Kings
    { "BUFF", 19977, 19978, 19979 }, -- Blessing of Light
    { "BUFF", 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, -- Blessing of Might
    { "BUFF", 1022, 5599, 10278 }, -- Blessing of Protection
    { "BUFF", 6940, 20729 }, -- Blessing of Sacrifice
    { "BUFF", 1038 }, -- Blessing of Salvation
    { "BUFF", 20911, 20912, 20913, 20914 }, -- Blessing of Sanctuary
    { "BUFF", 19742, 19850, 19852, 19853, 19854, 25290 }, -- Blessing of Wisdom
    { "BUFF", 19746 }, -- Concentration Aura
    { "DEBUFF", 26573, 20116, 20922, 20923, 20924 }, -- Consecration
    { "BUFF", 465, 10290, 643, 10291, 1032, 10292, 10293 }, -- Devotion Aura
    { "BUFF", 20216 }, -- Divine Favor
    { "BUFF", 19753 }, -- Divine Intervention
    { "BUFF", 498, 5573 }, -- Divine Protection
    { "BUFF", 642, 1020 }, -- Divine Shield
    { "BUFF", 19891, 19899, 19900 }, -- Fire Resistance Aura
    { "SELFDEBUFF", 25771 }, -- Forbearance
    { "BUFF", 19888, 19897, 19898 }, -- Frost Resistance Aura
    { "BUFF", 25898 }, -- Greater Blessing of Kings
    { "BUFF", 25890 }, -- Greater Blessing of Light
    { "BUFF", 25782, 25916 }, -- Greater Blessing of Might
    { "BUFF", 25895 }, -- Greater Blessing of Salvation
    { "BUFF", 25899 }, -- Greater Blessing of Sanctuary
    { "BUFF", 25894, 25918 }, -- Greater Blessing of Wisdom
    { "BUFF", 415058 }, -- Guarded by the Light
    { "DEBUFF", 853, 5588, 5589, 10308 }, -- Hammer of Justice
    { "BUFF", 20925, 20927, 20928 }, -- Holy Shield
    { "BUFF", 425600 }, -- Horn of Lordaeron
    { "DEBUFF", 20184 }, -- Judgement of Justice
    { "DEBUFF", 20185, 20344, 20345, 20346 }, -- Judgement of Light
    { "DEBUFF", 21183, 20188, 20300, 20301, 20302, 20303 }, -- Judgement of the Crusader
    { "DEBUFF", 20186, 20354, 20355 }, -- Judgement of Wisdom
    { "BUFF", 20233, 20236 }, -- Lay on Hands (Improved Lay on Hands)
    { "BUFF", 1310909, 1311593, 1311597 }, -- Light's Vigil
    { "BUFF", 20128, 20131, 20132, 20133, 20134 }, -- Redoubt
    { "DEBUFF", 20066 }, -- Repentance
    { "BUFF", 7294, 10298, 10299, 10300, 10301 }, -- Retribution Aura
    { "BUFF", 25780, alt = { 407627 } }, -- Righteous Fury
    { "DEBUFF", 440675 }, -- Righteous Judgement
    { "BUFF", 412019 }, -- Sacred Shield
    { "BUFF", 20218 }, -- Sanctity Aura
    { "BUFF", 20375, 20915, 20918, 20919, 20920 }, -- Seal of Command
    { "BUFF", 1311649, 1311656, 20163, 20419, 20421, 20422, 20423 }, -- Seal of Fury
    { "BUFF", 20164 }, -- Seal of Justice
    { "BUFF", 20165, 20347, 20348, 20349 }, -- Seal of Light
    { "BUFF", 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293, alt = { 20154, false, false, false, false, false, false, false } }, -- Seal of Righteousness
    { "BUFF", 21082, 20162, 20305, 20306, 20307, 20308 }, -- Seal of the Crusader
    { "BUFF", 20166, 20356, 20357 }, -- Seal of Wisdom
    { "BUFF", 19876, 19895, 19896 }, -- Shadow Resistance Aura
    { "DEBUFF", 20170 }, -- Stun (Seal of Justice)
    { "BUFF", 1310994 }, -- Swift Judgement
    { "BUFF", 1311015 }, -- Templar's Bulwark
    { "DEBUFF", 2878, 5627, 10326 }, -- Turn Undead
    { "BUFF", 20050, 20052, 20053, 20054, 20055 }, -- Vengeance
    { "DEBUFF", 67, 26017, 26018 }, -- Vindication
    { "BUFF", 1310897 }, -- Voice of Truth
  } },
  { class = "WARRIOR", spells = {
    { "BUFF", 6673, 5242, 6192, 11549, 11550, 11551, 25289 }, -- Battle Shout
    { "BUFF", 2457 }, -- Battle Stance
    { "BUFF", 18499 }, -- Berserker Rage
    { "BUFF", 2458 }, -- Berserker Stance
    { "BUFF", 16488, 16490, 16491 }, -- Blood Craze
    { "BUFF", 29131 }, -- Bloodrage
    { "BUFF", 23885, 23886, 23887, 23888 }, -- Bloodthirst
    { "DEBUFF", 1161 }, -- Challenging Shout
    { "DEBUFF", 7922 }, -- Charge Stun
    { "BUFF", 403215 }, -- Commanding Shout
    { "DEBUFF", 12809 }, -- Concussion Blow
    { "BUFF", 12328 }, -- Death Wish
    { "DEBUFF", 12721 }, -- Deep Wound
    { "BUFF", 71 }, -- Defensive Stance
    { "DEBUFF", 1160, 6190, 11554, 11555, 11556 }, -- Demoralizing Shout
    { "DEBUFF", 676 }, -- Disarm
    { "BUFF", 12880, 14201, 14202, 14203, 14204 }, -- Enrage
    { "BUFF", 402913 }, -- Enraged Regeneration
    { "BUFF", 12966, 12967, 12968, 12969, 12970 }, -- Flurry
    { "DEBUFF", 1715, 7372, 7373 }, -- Hamstring
    { "DEBUFF", 23694 }, -- Improved Hamstring
    { "DEBUFF", 20253, 20614, 20615 }, -- Intercept Stun
    { "DEBUFF", 5246 }, -- Intimidating Shout
    { "DEBUFF", 20511 }, -- Intimidating Shout (main target)
    { "BUFF", 12976 }, -- Last Stand
    { "DEBUFF", 5530 }, -- Mace Stun Effect
    { "DEBUFF", 694, 7400, 7402, 20559, 20560 }, -- Mocking Blow
    { "DEBUFF", 12294, 21551, 21552, 21553 }, -- Mortal Strike
    { "DEBUFF", 12323 }, -- Piercing Howl
    { "BUFF", 426490 }, -- Rallying Cry
    { "BUFF", 1719 }, -- Recklessness
    { "DEBUFF", 772, 6546, 6547, 6548, 11572, 11573, 11574 }, -- Rend
    { "BUFF", 20230 }, -- Retaliation
    { "DEBUFF", 12798 }, -- Revenge Stun
    { "DEBUFF", 18498 }, -- Shield Bash - Silenced
    { "BUFF", 2565 }, -- Shield Block
    { "BUFF", 871 }, -- Shield Wall
    { "DEBUFF", 7386, 7405, 8380, 11596, 11597 }, -- Sunder Armor
    { "BUFF", 12292 }, -- Sweeping Strikes
    { "DEBUFF", 355 }, -- Taunt
    { "DEBUFF", 6343, 8198, 8204, 8205, 11580, 11581 }, -- Thunder Clap
  } },
}
