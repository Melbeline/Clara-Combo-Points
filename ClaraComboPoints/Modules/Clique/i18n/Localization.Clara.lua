local _, ClaraNS = ... -- (Clara Combo Points: Clique built in, Modules/Clique/Bootstrap.lua)
if not (type(ClaraNS) == "table" and ClaraNS.CliqueRuns) then return end
-- Clara Combo Points: the texts of what Clara adds to Clique (a binding kept off the target frame), in English, French
-- and German (after Clique's own: these win for the player's language)
local addon = ClaraNS.CliquePrivate

addon:RegisterLocale("enUS", {
    ["Not on the target frame"] = "Not on the target frame",
    ["not on the target frame"] = "not on the target frame",
    ["NOT_ON_TARGET_TOOLTIP"] = "The binding does nothing while the mouse is over the target frame (its portrait, name and bars): there the frame's own click, if it has one, is left alone. Everywhere else it works as set.",
    ["NOT_ON_TARGET_DISABLED"] = "Only for the bindings on unit frames.",
})

addon:RegisterLocale("frFR", {
    ["Not on the target frame"] = "Pas sur le portrait de la cible",
    ["not on the target frame"] = "pas sur le portrait de la cible",
    ["NOT_ON_TARGET_TOOLTIP"] = "Le raccourci ne fait rien quand la souris est sur le cadre de la cible (son portrait, son nom et ses barres) : là, le clic propre au cadre, s'il en a un, reste tel quel. Partout ailleurs, il marche comme réglé.",
    ["NOT_ON_TARGET_DISABLED"] = "Seulement pour les raccourcis sur les cadres d'unité.",
})

addon:RegisterLocale("deDE", {
    ["Not on the target frame"] = "Nicht auf dem Zielrahmen",
    ["not on the target frame"] = "nicht auf dem Zielrahmen",
    ["NOT_ON_TARGET_TOOLTIP"] = "Die Belegung tut nichts, solange die Maus über dem Zielrahmen ist (Porträt, Name und Leisten): dort bleibt der eigene Klick des Rahmens, falls er einen hat. Überall sonst wirkt sie wie eingestellt.",
    ["NOT_ON_TARGET_DISABLED"] = "Nur für die Belegungen auf Einheitenrahmen.",
})
