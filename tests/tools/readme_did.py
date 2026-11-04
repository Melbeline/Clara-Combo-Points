import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, (p, old[:70], s.count(old))
    s = s.replace(old, new)
rep("les autres apparences de DoesItDie (rayures, pointillés, couleur par DoT…) restent au choix dans sa fenêtre d'options, avec un aperçu en direct. Sa page : Échap > Options > AddOns > Clara > Combat > DoesItDie.",
    "les autres apparences de DoesItDie (rayures, pointillés, couleur par DoT…) restent au choix. **Ses options sont de vraies pages du menu du jeu** (Échap > Options > AddOns > Clara > Combat > DoesItDie) : ses cases, curseurs et menus déroulants à lui, une page par sujet (Icône de mort, Marqueur, Effets, Texte, Barres de nom, Focus, Avancé), le bouton Par défaut du jeu pour remettre une page, et sur sa page principale ses apparences en un clic ; sa fenêtre avec l'**aperçu en direct** reste à un clic (ou `/did`). En français.")
old = "Les fenêtres de Leatrix Plus et de DoesItDie restent des fenêtres à part, ouvertes depuis leur page."
if old in s:
    rep(old, "La fenêtre de Leatrix Plus reste une fenêtre à part, ouverte depuis sa page ; DoesItDie a ses pages dans le menu du jeu (sa fenêtre d'aperçu à un clic).")
open(p, "w", encoding="utf-8").write(s)
print("ok", p)
