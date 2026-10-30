-- /who by first name or surname (Who.lua): a one-word search in quotes lists only the players whose
-- first name or surname is that word, accents aside; anything else (/who lea) as the game gives it.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

-- the game's results for the last search (names, guild, zone), as the server sends them
local RESULTS = {}
local sent = {}
C_FriendList = {
  GetNumWhoResults = function() return #RESULTS, #RESULTS end,
  GetWhoInfo = function(i) local r = RESULTS[i]; return r and { fullName = r[1], fullGuildName = r[2] or "", area = r[3] or "", level = 10 } end,
  SendWho = function(text) sent[#sent + 1] = text end,
}
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
local F = C_FriendList
-- a Who list reading the results, as the game's and ClassicUI Forever's do
local function List()
  local n, total = F.GetNumWhoResults()
  local names = {}
  for i = 1, n do local info = F.GetWhoInfo(i); names[#names + 1] = info and info.fullName or "?" end
  return table.concat(names, ", "), total
end
local function Search(text, results)
  F.SendWho(text)
  RESULTS = results
  return List()
end

local LEA = { { "Lea Dubois" }, { "Léa Martin" }, { "Leah Stone" }, { "Anna Lëa" }, { "Aleandra Vex" }, { "Bob Smith", "Lea's Guild" },
  { "Mira Lea" }, { "Cléa Noir" }, { "Lea-Marie Dupont" }, { "Leafrunner Oak" } }
local ALL = "Lea Dubois, Léa Martin, Leah Stone, Anna Lëa, Aleandra Vex, Bob Smith, Mira Lea, Cléa Noir, Lea-Marie Dupont, Leafrunner Oak"
out("== a name in quotes")
local list, total = Search('"lea"', LEA)
check(list == "Lea Dubois, Léa Martin, Anna Lëa, Mira Lea, Lea-Marie Dupont", "first names and surnames that are Lea, accents aside: " .. list)
check(total == 5, "the count: the players listed (" .. tostring(total) .. ")")
check(sent[#sent] == '"lea"', "the search sent as typed")
check(Search('"LÉA"', LEA) == "Lea Dubois, Léa Martin, Anna Lëa, Mira Lea, Lea-Marie Dupont", '"LÉA" (capitals, an accent): the same')
check(Search('n-"lea"', LEA) == "Lea Dubois, Léa Martin, Anna Lëa, Mira Lea, Lea-Marie Dupont", 'n-"lea" (the name filter): the same')
check(F.GetWhoInfo(6) == nil, "past the list: nothing")
local none, count = Search('"lea"', { { "Bob Smith", "Lea's Guild" }, { "Leah Stone" } })
check(none == "" and count == 0, "no first name or surname is Lea: nobody (" .. none .. ")")

out("== without quotes: the game's own search")
check(Search("lea", LEA) == ALL, "/who lea: every name with lea in it (Leah, Aleandra, Leafrunner...)")
check(Search("n-lea", LEA) == ALL, "/who n-lea: the same")

out("== other searches: as the game gives them")
for _, q in ipairs({ "lea 10", "60", "g-Lea", "z-Elwynn", "c-Mage", "lea smith", '"lea smith"', '"lea" 10', "", "15-20" }) do
  check(Search(q, LEA) == ALL, ("%q: all"):format(q))
end

out("== turned off")
check(ns:WhoNames() == true, "on by default")
ns:SetWhoNames(false)
check(ns.sv.whoNames == false and Search('"lea"', LEA) == ALL, "off: kept, every result")
ns:SetWhoNames(true)
check(ns.sv.whoNames == nil and not Search('"lea"', LEA):find("Leah", 1, true), "on again")

out("== its box in the game's options")
M.ShowSettingsPage(ns.settingsCategory)
local box = SettingsPanel and ns.settingsCategory.frame.whoNames
check(box and box:GetChecked() == true, "a box, ticked")
box:Click()
check(ns.sv.whoNames == false, "unticked: off")
box:Click()

out("")
out(fails .. " failure(s)")
