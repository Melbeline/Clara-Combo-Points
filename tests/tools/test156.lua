-- The Improvements tab's search (Options.lua): over the list of modules, a search box; as it is typed, only the modules
-- whose words in Clara's window hold every word typed (name, line in the list, what it does, its switches; capitals and
-- accents aside) stay in the list, one under the other; the module shown not among them: the first found shown; none:
-- said; emptied: all of them back. Words found only in a module's own options pages (Esc > Options > AddOns): not found.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end
local ns = {}
S.class = "ROGUE"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN"); M.Fire("PLAYER_ENTERING_WORLD")
ns:ShowOptions()
local p = ClaraComboPointsOptions
check(p and p.qolTab, "the window and its Improvements tab")
p.qolTab:Click()
local view = p.qolView
check(view and view:IsShown() and view.search, "the Improvements tab: the search over the list")
local L = ns.L
local mods = ns.QOL_MODULES
-- the list's buttons, by module (its name on it)
local function Listed()
  local t = {}
  for _, f in ipairs(M.frames) do
    if f.name and f.desc and f.SetActive and f:IsShown() and f:IsVisible() then
      local _, _, _, _, y = f:GetPoint(1)
      t[#t + 1] = { name = f.name:GetText(), y = y }
    end
  end
  table.sort(t, function(a, b) return a.y > b.y end)
  return t
end
local all = #Listed()
check(all >= 10, "all the modules listed (" .. all .. ")")

out("== a word")
M.Type(view.search, "mail")
local l = Listed()
local mailName = L.QOL_NAV_MAIL or "Mail"
local has = false
for _, e in ipairs(l) do if e.name == mailName then has = true end end
check(has and #l < all, "the mail module kept, fewer listed (" .. #l .. ")")
check(#l > 0 and l[1].y == -2, "the first one at the top of the list")
local ordered = true
for k = 2, #l do if l[k - 1].y - l[k].y ~= 56 then ordered = false end end
check(ordered, "one under the other, no gaps")

out("== words in its description and switches, capitals and accents aside")
local about = L.QOL_ABOUT_MAIL or ""
local word = about:match("(%a%a%a%a%a%a%a+)")
M.Type(view.search, word and word:upper() or "")
l = Listed()
has = false
for _, e in ipairs(l) do if e.name == mailName then has = true end end
check(word and has, "a word of what it does: found (" .. tostring(word) .. ")")
M.Type(view.search, "mail zzzz")
check(#Listed() == 0 and view.search ~= nil, "every word needed: none")
M.Type(view.search, "qqqqqqq")
check(#Listed() == 0, "nothing found: an empty list")

out("== the module shown")
ns.sv.window.qol = "mail"
M.Type(view.search, "")
check(#Listed() == all, "emptied: all of them back")
M.Type(view.search, "mail")
check(ns.sv.window.qol == "mail", "the module shown among those found: kept")
M.Type(view.search, L.QOL_NAV_BUYEMALL or "BuyEmAll")
check(ns.sv.window.qol == "buyemall", "not among them: the first found shown (" .. tostring(ns.sv.window.qol) .. ")")
M.Type(view.search, "")
out("")
out(fails .. " failure(s)")
