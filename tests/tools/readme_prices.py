import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, (old[:70], s.count(old))
    s = s.replace(old, new)
rep("LootOptimizer Forever (à côté de lui), Reverse Engineering.",
    "LootOptimizer Forever (à côté de lui), Prix de l'HV partagés, Reverse Engineering.")
lines = s.split("\n")
row = [l for l in lines if l.startswith("| **LootOptimizer Forever** |")][0]
rep(row + "\n", row + "\n" +
    "| **Prix de l'HV partagés** | Les **prix de l'hôtel des ventes**, les mêmes sur **tous tes comptes WoW** : chaque prix vu par un scan d'**Auctionator** (il doit être installé ; sa licence ne permet pas de copier son code : Clara lit et écrit ses prix pendant qu'il tourne) est gardé, le plus récent de chaque objet. **En direct**, quand deux de tes comptes sont connectés (la synchro) : les nouveaux prix des **objets que tes personnages possèdent** (sacs, banque, courrier), toutes les 20 secondes au plus — jamais un scan entier, qui inonderait le serveur. **Entre deux sessions** : tous, par le script Windows (dossier `Synchro` : **relance Installer.bat** après cette mise à jour). Un prix plus récent venu d'un autre compte va dans les **prix d'Auctionator lui-même** (son prix, l'historique de ce jour-là) : ses infobulles et **LootOptimizer Forever** l'ont aussitôt ; les prix de plus de 30 jours sont oubliés. Indépendant de tout scanner : Auctionator seul suffit à l'alimenter. Pas dans la version Light. | — |\n")
open(p, "w", encoding="utf-8").write(s)
print("ok")
