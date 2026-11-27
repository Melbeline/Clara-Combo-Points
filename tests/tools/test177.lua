-- Chat blacklist (Modules/ChatFilter): a word of its list hides the lines holding it, every variant by default (accents,
-- case, symbols inside, letters one by one, digits for letters, look-alike letters), as a whole word unless "inside
-- other words"; unticked, the word as written only. Raid symbols in any writing. Not your lines, your friends', the
-- game staff's; whispers (on), group, raid, guild, communities each with its own box. Repeated messages, Cyrillic, Chinese with theirs. Each line decided
-- once (each window asks). Its window: add, change, turn off, remove; its button under the chat's channel button.
local M, S = MOCK, MOCK.state
local out = function(s) io.write(tostring(s), "\n") end
local fails = 0
local function check(c, m) out((c and "  ok   " or "  FAIL ") .. m); if not c then fails = fails + 1 end end

GetBuildInfo = function() return "1.60.1", "70000", "Oct 1 2026", 16001 end
ClaraComboPointsDB = { qol = { lfgforever = false, whatstraining = false, doesitdie = false, enhancedraidframes = false, buyemall = false, leatrix = false, nodesight = false, wst = false, dynamiccam = false,
  dialogkey = false, xtolevel = false, minimapdrawer = false, classicui = false, tullarange = false, names = false,
  tooltipanchor = false, mail = false, reverseengineering = false } }
local friends = { ["Player-1-FRIEND"] = true }
C_FriendList = C_FriendList or {}
C_FriendList.IsFriend = function(guid) return friends[guid] == true end
UnitGUID = function(u) return u == "player" and "Player-1-ME" or nil end
ChatFrameChannelButton = CreateFrame("Button", "ChatFrameChannelButton", UIParent)
ChatFrameChannelButton:SetSize(27, 26)
local ns = {}
S.class = "PRIEST"; S.locale = "enUS"
M.LoadAddon(ADDON_DIR, ns)
M.Fire("ADDON_LOADED", "ClaraComboPoints"); M.Fire("PLAYER_LOGIN")
if not ns.ChatFilterFilter then out("(no chat blacklist in this version)"); out(""); out("0 failure(s)"); return end

local line = 100
local function Say(event, text, author, guid, flags, channel)
  line = line + 1
  return ns.ChatFilterFilter(nil, event or "CHAT_MSG_CHANNEL", text, author or "Spammer", "", channel or "2. Trade", "", flags or "", 0, 2, "Trade", 0, line, guid or "Player-1-0042")
end

out("== every variant of a word")
local rested = ns.ChatFilterAdd("rested")
check(rested and rested.variants == nil and rested.inword == nil, "added: every variant, a whole word (the defaults)")
for _, t in ipairs({ "rested", "Buy REStED now", "rêstéd!!", "reStEd", "r.e.s.t.e.d", "r e s t e d", "r3$ted", "ｒｅｓｔｅｄ", "rеstеd" }) do
  check(Say(nil, t) == true, "hidden: " .. t)
end
check(Say(nil, "I am interested") == false, "a whole word: \"interested\" left alone")
check(Say(nil, "restedxp guide") == false, "\"restedxp\" left alone too (another word)")
rested.inword = true
check(Say(nil, "I am interested") == true and Say(nil, "restedxp guide") == true, "inside other words, ticked: hidden")
rested.inword = nil
check((rested.hits or 0) >= 10, "its count of lines hidden: " .. tostring(rested.hits))

out("== the word as written only (its box unticked)")
local exact = ns.ChatFilterAdd("Gold4U", false)
check(exact and exact.variants == false, "added as written")
check(Say(nil, "WTS by Gold4U cheap") == true, "as written: hidden")
check(Say(nil, "WTS by gold4u cheap") == false and Say(nil, "WTS by Gôld4U") == false, "another case, an accent: left alone")
check(Say(nil, "WTS by Gold4Ucom") == false, "inside another word: left alone")

out("== a phrase, raid symbols")
ns.ChatFilterAdd("{rt8} wts gold")
check(Say(nil, "{skull} WTS GOLD cheap") == true, "{skull}: the same symbol")
check(Say(nil, "{crâne}wts  gold!!") == true, "{crâne} in French, no space after it")
check(Say(nil, "{rt7} wts gold") == false, "another symbol: left alone")
check(ns.ChatFilterFold("{Skull} WTS") == " rt8 wts ", "folded: " .. ns.ChatFilterFold("{Skull} WTS"))

out("== who is never hidden")
check(Say(nil, "rested", "Me", "Player-1-ME") == false, "your own lines")
check(Say(nil, "rested", "Pal", "Player-1-FRIEND") == false, "a friend's")
check(Say(nil, "rested", "GM", "Player-1-0099", "GM") == false, "the game staff's")
check(Say("CHAT_MSG_PARTY", "rested") == false and Say("CHAT_MSG_RAID", "rested") == false and Say("CHAT_MSG_GUILD", "rested") == false
  and Say("CHAT_MSG_COMMUNITIES_CHANNEL", "rested") == false, "group, raid, guild, communities: not by default")
check(Say("CHAT_MSG_WHISPER", "rested") == true and Say("CHAT_MSG_SAY", "rested") == true and Say("CHAT_MSG_YELL", "rested") == true, "whispers (by default), say, yell: hidden")
local st = ns.ChatFilterStore()
st.party = true
check(Say("CHAT_MSG_PARTY", "rested") == true and Say("CHAT_MSG_INSTANCE_CHAT", "rested") == true and Say("CHAT_MSG_RAID", "rested") == false
  and Say("CHAT_MSG_GUILD", "rested") == false, "the group's box alone: the group (and instance) only")
st.party, st.raid = nil, true
check(Say("CHAT_MSG_RAID", "rested") == true and Say("CHAT_MSG_RAID_WARNING", "rested") == true and Say("CHAT_MSG_PARTY", "rested") == false, "the raid's alone")
st.raid, st.guild = nil, true
check(Say("CHAT_MSG_GUILD", "rested") == true and Say("CHAT_MSG_OFFICER", "rested") == true and Say("CHAT_MSG_RAID", "rested") == false, "the guild's alone")
st.guild, st.communities = nil, true
check(Say("CHAT_MSG_COMMUNITIES_CHANNEL", "rested") == true and Say("CHAT_MSG_GUILD", "rested") == false, "the communities' alone")
st.communities, st.whisper = nil, false
check(Say("CHAT_MSG_WHISPER", "rested") == false and Say("CHAT_MSG_SAY", "rested") == true, "the whispers' box unticked: whispers shown, say still filtered")
st.whisper = nil
st.group = true -- (the first version's single box)
st = ns.ChatFilterStore()
check(st.group == nil and st.party and st.raid and st.guild and st.communities, "the first version's single box: each of them ticked")
st.party, st.raid, st.guild, st.communities = nil, nil, nil, nil

out("== each line decided once (every window asks)")
local before = rested.hits
line = line + 1
local a = ns.ChatFilterFilter(nil, "CHAT_MSG_CHANNEL", "rested", "X", "", "2. Trade", "", "", 0, 2, "Trade", 0, line, "Player-1-7")
local b = ns.ChatFilterFilter(nil, "CHAT_MSG_CHANNEL", "rested", "X", "", "2. Trade", "", "", 0, 2, "Trade", 0, line, "Player-1-7")
check(a == true and b == true and rested.hits == before + 1, "hidden in both windows, counted once")
local secret = M.Secret("rested")
local ok, res = pcall(ns.ChatFilterFilter, nil, "CHAT_MSG_CHANNEL", secret, "X", "", "", "", "", 0, 2, "", 0, 999, "Player-1-7")
check(ok and res == false, "a line the game keeps secret: left alone, no error")

out("== repeated messages, Cyrillic, Chinese (their boxes)")
check(Say(nil, "LFM Deadmines", "Bob") == false and Say(nil, "LFM Deadmines", "Bob") == false, "repeated, its box off: shown")
ns.ChatFilterStore().repeats = true
check(Say(nil, "LFG BFD", "Ann") == false and Say(nil, "LFG BFD", "Ann") == true, "its box on: the copy within a minute hidden")
check(Say(nil, "LFG BFD", "Joe") == false, "another player's same words: shown")
M.now = (M.now or 0) + 61
check(Say(nil, "LFG BFD", "Ann") == false, "a minute later: shown again")
check(Say(nil, "Привет всем") == false, "Cyrillic, its box off: shown")
ns.ChatFilterStore().cyrillic = true
check(Say(nil, "Привет всем") == true, "its box on: hidden")
ns.ChatFilterStore().chinese = true
check(Say(nil, "金币出售 cheap") == true and Say(nil, "plain english") == false, "Chinese: hidden; Latin left alone")
ns.ChatFilterStore().off = true
check(Say(nil, "rested") == false, "the blacklist turned off: nothing hidden")
ns.ChatFilterStore().off = nil

out("== its window and its button")
local button = ns.ChatFilterButton()
local p, rel, rp, x, y = button:GetPoint(1)
check(button and p == "TOP" and rel == ChatFrameChannelButton and rp == "BOTTOM" and y == -2, "its button under the chat's channel button")
button:GetScript("OnClick")(button, "LeftButton")
local win = ClaraChatFilter
check(win and win:IsShown(), "a left click: its window")
check(win.rows[1] and win.rows[1].entry == rested and win.rows[1].text:GetText() == "rested", "the list: " .. tostring(win.rows[1] and win.rows[1].text:GetText()))
check(win.rows[3].text:GetText():find("UI%-RaidTargetingIcon_8") ~= nil, "a raid symbol drawn: " .. tostring(win.rows[3].text:GetText()))
win.box:SetText("boost")
win.add:GetScript("OnClick")(win.add)
local words = ns.ChatFilterStore().words
check(words[#words].text == "boost" and win.box:GetText() == "", "written and added: in the list")
win.rows[#words]:GetScript("OnClick")(win.rows[#words])
check(win.box:GetText() == "boost" and win.add:GetText() == ns.L.CF_SAVE, "a click on it: in the box to change")
win.box:SetText("boosting")
win.add:GetScript("OnClick")(win.add)
check(words[#words].text == "boosting" and #words == 4, "changed, not added again")
win.rows[#words].del:GetScript("OnClick")(win.rows[#words].del)
check(#words == 3, "its cross: taken out")
win.rows[1].on:SetChecked(false)
win.rows[1].on:GetScript("OnClick")(win.rows[1].on)
check(rested.off == true and Say(nil, "rested") == false, "its box unticked: off, kept in the list")
win.rows[1].on:SetChecked(true)
win.rows[1].on:GetScript("OnClick")(win.rows[1].on)
check(rested.off == nil and Say(nil, "rested") == true, "ticked again: on")
button:GetScript("OnClick")(button, "RightButton")
check(ns.ChatFilterStore().off == true, "a right click on its button: the blacklist off")
button:GetScript("OnClick")(button, "RightButton")
check(ns.ChatFilterStore().off == nil, "again: on")
win.optWhisper:SetChecked(false)
win.optWhisper:GetScript("OnClick")(win.optWhisper)
check(ns.ChatFilterStore().whisper == false, "the window's whispers box unticked: kept")
win.optWhisper:SetChecked(true)
win.optWhisper:GetScript("OnClick")(win.optWhisper)
check(ns.ChatFilterStore().whisper == nil, "ticked again: the default")
win.optGuild:SetChecked(true)
win.optGuild:GetScript("OnClick")(win.optGuild)
check(ns.ChatFilterStore().guild == true and Say("CHAT_MSG_GUILD", "rested") == true, "the guild's box in the window: the guild filtered")
win.optGuild:SetChecked(false)
win.optGuild:GetScript("OnClick")(win.optGuild)
local sw = ns.qolSwitches.chatfilter
sw[1].set(false)
check(not button:IsShown() and ns.ChatFilterStore().noButton == true, "its card's box: the button hidden")
sw[1].set(true)
check(button:IsShown(), "shown again")

out("")
out(fails .. " failure(s)")
