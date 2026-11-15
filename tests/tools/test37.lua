-- /who by first name or surname (Who.lua): a one-word search in quotes lists only the players whose
-- first name or surname is that word, accents aside; anything else (/who lea) as the game gives it. On the game's
-- own Who list (the group finder's): its rows that do not match taken out, all of them (the game's RemoveByPredicate
-- takes out the first only), its count line the players left.
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
WHO_FRAME_TOTAL_TEMPLATE = "%d People Found"
-- the game's data provider (Blizzard_SharedXML/DataProvider.lua): RemoveByPredicate takes out the FIRST match only
local function Provider(onlyFirst)
  local p = { collection = {} }
  function p:Insert(e) self.collection[#self.collection + 1] = e end
  function p:GetSize() return #self.collection end
  function p:Find(i) return self.collection[i] end
  function p:RemoveIndex(i) table.remove(self.collection, i) end
  function p:RemoveByPredicate(pred)
    for i, e in ipairs(self.collection) do if pred(e) then table.remove(self.collection, i) return end end
  end
  if not onlyFirst then
    function p:RemoveAllByPredicate(pred)
      for i = #self.collection, 1, -1 do if pred(self.collection[i]) then table.remove(self.collection, i) end end
    end
  end
  return p
end
-- the game's Who list (the group finder's third tab, WoW Forever): its scroll box, its count line
LFGWhoListFrame = CreateFrame("Frame", "LFGWhoListFrame", UIParent)
local totals = { text = "" }
function totals:SetText(t) self.text = t end
LFGWhoListFrame.WhoFrameTotals = totals
local box = { provider = nil }
function box:SetDataProvider(p) self.provider = p end
function box:GetParent() return LFGWhoListFrame end
LFGWhoListFrame.ScrollBox = box
local onlyFirst = false
local function UpdateWhoList() -- (LFGWhoListMixin:UpdateWhoList, as the game has it)
  local n, total = C_FriendList.GetNumWhoResults()
  totals:SetText(WHO_FRAME_TOTAL_TEMPLATE:format(total))
  local p = Provider(onlyFirst)
  for i = 1, n do p:Insert({ index = i, info = C_FriendList.GetWhoInfo(i) }) end
  box:SetDataProvider(p)
end
S.class = "ROGUE"; S.locale = "enUS"
local ns = {}
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
M.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
local F = C_FriendList
-- the list shown: the names in the game's scroll box, and its count line
local function List()
  local names = {}
  for _, e in ipairs(box.provider and box.provider.collection or {}) do names[#names + 1] = e.info and e.info.fullName or "?" end
  return table.concat(names, ", "), totals.text
end
local function Search(text, results)
  F.SendWho(text)
  RESULTS = results
  UpdateWhoList()
  return List()
end

local LEA = { { "Lea Dubois" }, { "Léa Martin" }, { "Leah Stone" }, { "Anna Lëa" }, { "Aleandra Vex" }, { "Bob Smith", "Lea's Guild" },
  { "Mira Lea" }, { "Cléa Noir" }, { "Lea-Marie Dupont" }, { "Leafrunner Oak" } }
local ALL = "Lea Dubois, Léa Martin, Leah Stone, Anna Lëa, Aleandra Vex, Bob Smith, Mira Lea, Cléa Noir, Lea-Marie Dupont, Leafrunner Oak"
out("== a name in quotes")
local list, total = Search('"lea"', LEA)
check(list == "Lea Dubois, Léa Martin, Anna Lëa, Mira Lea, Lea-Marie Dupont", "first names and surnames that are Lea, accents aside: " .. list)
check(total == "5 People Found", "the count: the players listed (" .. tostring(total) .. ")")
check(sent[#sent] == '"lea"', "the search sent as typed")
check(Search('"LÉA"', LEA) == "Lea Dubois, Léa Martin, Anna Lëa, Mira Lea, Lea-Marie Dupont", '"LÉA" (capitals, an accent): the same')
check(Search('n-"lea"', LEA) == "Lea Dubois, Léa Martin, Anna Lëa, Mira Lea, Lea-Marie Dupont", 'n-"lea" (the name filter): the same')
local none, count = Search('"lea"', { { "Bob Smith", "Lea's Guild" }, { "Leah Stone" } })
check(none == "" and count == "0 People Found", "no first name or surname is Lea: nobody (" .. none .. ")")

out("== without quotes: the game's own search")
check(Search("lea", LEA) == ALL, "/who lea: every name with lea in it (Leah, Aleandra, Leafrunner...)")
check(Search("n-lea", LEA) == ALL, "/who n-lea: the same")

out("== other searches: as the game gives them")
for _, q in ipairs({ "lea 10", "60", "g-Lea", "z-Elwynn", "c-Mage", "lea smith", '"lea smith"', '"lea" 10', "", "15-20" }) do
  check(Search(q, LEA) == ALL, ("%q: all"):format(q))
end

out("== a list with only the game's RemoveByPredicate (the first match each time): all of them out too")
onlyFirst = true
check(Search('"lea"', LEA) == "Lea Dubois, Léa Martin, Anna Lëa, Mira Lea, Lea-Marie Dupont", "the same five")
onlyFirst = false
local _, allCount = Search("lea", LEA)
check(allCount == "10 People Found", "without quotes: the game's count left as it is")

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
