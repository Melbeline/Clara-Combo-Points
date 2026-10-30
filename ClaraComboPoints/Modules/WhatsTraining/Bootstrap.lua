-- Clara Combo Points - What's Training? 11.0.0-beta25 (by Sveng; MIT, LICENSE), built in (QoL.lua): what your
-- class trainer (and weapon masters, the pet trainer, the tomes) can teach you, now and at the next levels, with
-- its cost; and the recipes your professions can still learn, where. Its WoW Forever version: a tab of its own in
-- Forever's spellbook (the book's own pages, parchment), its window (/wt), its list in the professions window.
-- ClassicUI's spellbook (when it runs) has its "What can I train?" side tab: it opens that window, the classic
-- list, beside the book. The first of the module's files: it tells the others whether they run and gives them
-- their own shared table. Its settings keep their names (WT_...), saved with Clara's: the standalone's, carried
-- over by name. The standalone What's Training takes over for the session it is enabled in, and is turned off
-- for the character (QoL.lua), so that the built-in one runs from the next reload.

local ADDON, ns = ...

ns.WhatsTrainingRuns = ns:QolRuns("whatstraining")
if ns.WhatsTrainingRuns then
  ns.WhatsTrainingPrivate = {} -- (the standalone's own `...` table)
end

-- Its window (the one /wt opens), from the Improvements tab
ns:SetQolOpener("whatstraining", function()
  local open = SlashCmdList and SlashCmdList.WHATSTRAINING
  if type(open) == "function" and not InCombatLockdown() then open("") end
end)
