import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, (old[:70], s.count(old))
    s = s.replace(old, new)
rep("Prix de l'HV partagés, Reverse Engineering.", "Prix de l'HV partagés, Sniper, Reverse Engineering.")
lines = s.split("\n")
row = [l for l in lines if l.startswith("| **Prix de l'HV partagés** |")][0]
rep(row + "\n", row + "\n" +
    "| **Sniper** | Un **onglet Sniper** dans l'hôtel des ventes, **à côté de ceux d'Auctionator** (Achats, Vente, Annulation…), dans la même rangée d'onglets (Auctionator doit être installé ; aucun code d'Auctionator n'est copié : l'onglet est ajouté comme Auctionator le permet aux autres addons). **Lancer le sniper** : tout l'hôtel des ventes est parcouru, page après page, encore et encore (une pause de 10 secondes entre deux passages, tant que l'onglet est ouvert), et les objets dont le prix le plus bas est **sous leur prix habituel d'au moins le pourcentage choisi** s'affichent **aussitôt**, les meilleurs en premier, avec un son pour chaque nouvelle affaire. **Prix habituel** : la **médiane** (par défaut : quelques prix bizarres ne la bougent pas) ou la **moyenne** des prix les plus bas de chaque jour, sur **24 h, 3 j, 7 j, 15 j, 30 j, 3 mois, 6 mois, 12 mois ou depuis toujours**, au choix **en un clic** (une rangée de boutons, sans menu) ; il faut au moins 3 jours de prix (2 prix pour 24 h) pour qu'un objet soit jugé. **Bonne affaire** : un **curseur de 0 à 100 %** dans l'onglet, avec une **case à côté** pour écrire le chiffre directement (par défaut 40 % sous le prix habituel). Un clic sur une ligne ouvre l'objet dans la vue d'achat du jeu (un clic par achat, comme le jeu l'exige). Les prix au fil du temps sont gardés à part (les 24 dernières heures, puis le plus bas de chaque jour sur 30 jours, puis par semaine sur un an, puis par mois, et depuis toujours), nourris par chaque recherche de l'hôtel des ventes (Auctionator enregistre les prix de toutes), par les prix des autres comptes, et au départ par l'historique d'Auctionator. Pas dans la version Light. | — |\n")
open(p, "w", encoding="utf-8").write(s)
print("ok")
