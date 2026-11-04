import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, (old[:70], s.count(old))
    s = s.replace(old, new)
rep("- **Économie et métiers** : BuyEmAll, Courrier, Or des personnages, Reverse Engineering.",
    "- **Économie et métiers** : BuyEmAll, Courrier, Or des personnages, LootOptimizer Forever (à côté de lui), Reverse Engineering.")
lines = s.split("\n")
row = [l for l in lines if l.startswith("| **Or des personnages** |")][0]
rep(row + "\n", row + "\n" +
    "| **LootOptimizer Forever** | **À côté de LOF** (son propre addon : il faut l'installer ; sa licence ne permet pas de copier son code, alors Clara le modifie de l'extérieur, pendant qu'il tourne) : sa fenêtre **« sacs pleins » compacte** (sans portrait ni la bande vide sous son titre, et plus petite) ; **aucune fenêtre quand le butin vaut moins que chaque objet des sacs** qu'il pourrait remplacer (une ligne dans le chat à la place ; le butin reste sur le corps) — ses autres fenêtres (un échange rentable, une pièce d'équipement, un objet de quête, un composant, rien d'échangeable) s'ouvrent toujours ; ses fenêtres dans l'apparence de Clara (avec ClassicUI : l'ancienne fenêtre de ClassicUI et ses boutons rouges ; ses panneaux simples : la bordure de dialogue du jeu). Une case pour chacun sur sa page (Échap > Options > AddOns > Clara > Économie et métiers). Pas dans la version Light. | — |\n")
open(p, "w", encoding="utf-8").write(s)
print("ok")
