import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
lines = s.split("\n")
i = [k for k, l in enumerate(lines) if l.startswith("| **Leatrix Plus** |")][0]
row = lines[i]
cells = row.split(" | ")
# the description cell: the second one
assert len(cells) >= 3, cells[:2]
cells[1] = cells[1] + " **Ses options sont de vraies pages du menu du jeu** (Échap > Options > AddOns > Clara > Interface > Leatrix Plus) : une page par page de sa fenêtre (Automatisation, Social, Chat, Texte, Interface, Cadres, Système, Réglages), ses titres de section, ses cases à elle (marquées * quand elles demandent un rechargement, avec un bouton Recharger l'interface), et sous une option qui a un engrenage les réglages de son panneau (curseurs, cases, menus déroulants ; grisés tant que l'option est coupée ; ils apparaissent une fois l'option activée et l'interface rechargée), puis **Plus de réglages…** pour le reste du panneau (listes, textes, positions). Chaque réglage passe par la commande d'origine de Leatrix : il fait exactement la même chose. Sa fenêtre reste à un clic (ou `/ltp`)."
lines[i] = " | ".join(cells)
s = "\n".join(lines)
old = "La fenêtre de Leatrix Plus reste une fenêtre à part, ouverte depuis sa page ; DoesItDie a ses pages dans le menu du jeu (sa fenêtre d'aperçu à un clic)."
if old in s:
    s = s.replace(old, "Leatrix Plus et DoesItDie ont leurs pages dans le menu du jeu, faites de ses propres commandes ; leurs fenêtres restent à un clic (/ltp, /did).")
open(p, "w", encoding="utf-8").write(s)
print("ok", p)
