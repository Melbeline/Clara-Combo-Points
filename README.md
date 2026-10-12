# Clara-Combo-Points

Addon autonome pour **World of Warcraft: Forever** (bêta 1.60.1, Interface 16001), portage du WeakAura Classic « Complete Rogue » de Faineantt (https://wago.io/WouewStiD).

Pour **voleur**, **druide** (forme de félin et forme d'ours) et **guerrier**.

- **Ligne du haut** : 5 cases de points de combo (jaune → orange → rose). Chez le guerrier, des icônes de buffs et debuffs à la place.
- **Barre du bas** : l'énergie ou la rage, avec sa valeur en chiffres.
- **Lignes d'icônes** en option : jusqu'à 3 au-dessus et 3 en dessous, 20 icônes chacune, pour les trois classes.

## Installation

Copier le dossier `ClaraComboPoints` dans le dossier `Interface\AddOns` de ton client WoW Forever (le même que celui où se trouve ForeverRogueCP), puis relancer le jeu ou faire `/reload`.

## Utilisation

`/clara` ou `/cl` ouvre les options. La fenêtre utilise les modèles de fenêtres de Blizzard, comme le grimoire ou la fiche de personnage : cadre métal avec portrait et croix rouge, encarts sombres, boutons rouges, onglets, cases à cocher et curseurs du jeu.

En haut de la fenêtre :
- **Onglets Voleur / Druide / Guerrier** : chaque classe a son propre profil (position, échelle, couleurs, police, icônes…), commun à tous tes personnages de cette classe. La fenêtre s'ouvre sur l'onglet de ton personnage ; pendant qu'elle est ouverte, la barre affiche le profil de l'onglet choisi, pour régler une autre classe et voir le résultat.
- **Drapeaux FR / DE / GB** : langue de l'addon (français, allemand, anglais). Par défaut, celle du client (anglais pour les autres langues).

En bas, trois pages : **Barre**, **Police et avancé**, **Icônes**.

| Réglage | Détail |
|---|---|
| Position | Verrouiller / déverrouiller (barre déplaçable au clic gauche quand déverrouillée), retour à la position par défaut |
| Échelle | Boutons 50 → 300 % en un clic, ou n'importe quelle valeur de 10 à 500 % tapée dans la case (100 % par défaut) |
| Opacité globale | Opacité de tout l'addon |
| Hors combat | Hors combat, la barre s'atténue (coché par défaut) : opacité de la barre d'énergie / rage et opacité des points de combo / icônes réglables séparément (20 % par défaut). Pleine opacité en combat, quand la barre est déverrouillée et pendant que les options sont ouvertes (sauf 2 s après un réglage hors combat, pour voir le résultat) |
| Couleurs et opacité | Chaque case de combo (ou couleur d'icône), la barre d'énergie, la barre de rage, la rage à consommer, le fond des cases vides et la valeur : couleur via le sélecteur de couleur de Blizzard (roue, luminosité, opacité) + curseur d'opacité indépendant. Seules les couleurs utiles à la classe de l'onglet sont listées |
| Police | 20 polices (Arial Narrow par défaut, Friz Quadrata, Morpheus, Skurri, Emily's Candy, Bangers, Luckiest Guy, Chewy, Permanent Marker, Creepster, Pirata One, MedievalSharp, Cinzel Decorative, Bebas Neue, Russo One, Black Ops One, Audiowide, Righteous, Press Start 2P, Share Tech Mono) + celles de LibSharedMedia si un autre addon les fournit ; chaque nom est écrit dans sa police, à une taille proche des autres ; taille ; contour ; afficher la valeur |
| Avancé | Source des points de combo (cible / joueur), barre seulement en forme de félin et d'ours (onglet Druide, coché par défaut), rage qui va être consommée (onglets Druide et Guerrier, cochée par défaut), aperçu, réinitialiser l'onglet |
| Icônes | Garder les icônes carrées (sinon elles prennent la forme des cases de combo), taille, temps restant, auras absentes grisées ou cachées ; lignes d'icônes à remplir avec l'ID ou le nom de n'importe quel sort |

Commandes rapides : `/cl lock`, `/cl unlock`, `/cl scale 120`, `/cl reset`.

**Reload UI** : clic droit sur le portrait de ton personnage, section « Other Options », juste au-dessus de « Edit Mode » : recharge l'interface (comme `/reload`). Fonctionne sur toutes les classes et tous les clients.

À l'ouverture des options, tout s'allume (5 points, toutes les icônes) pour voir les couleurs. L'aperçu se coupe à la fermeture des options ou en entrant en combat.

## Icônes de buffs et debuffs

Page **Icônes** : clique sur une ligne (Haut 1 à 3, Bas 1 à 3) pour la choisir, puis tape l'**ID** du sort (par exemple `7386`) ou son **nom** et valide. Les lignes du haut s'empilent vers le haut, celles du bas vers le bas ; une ligne vide ne prend pas de place. Sur une icône : clic gauche = vers la gauche, Maj+clic = vers la droite, clic droit = retirer. 20 icônes au maximum par ligne.

- **Guerrier** : par défaut, une ligne à la place des points de combo, dans l'ordre de la capture : Fracasser armure, Cri démoralisant, Brise-genou, Cri de guerre, Rage sanguinaire.
- **Voleur et druide** : aucune icône par défaut ; leurs lignes se placent au-dessus des points de combo et sous la barre.
- Les auras sont cherchées **par nom de sort** : tous les rangs comptent, dans toutes les langues du client. D'abord tes buffs, puis les debuffs de ta cible (de n'importe qui : Fracasser armure d'un autre guerrier compte aussi), puis tes debuffs.
- Une aura active s'allume avec la couleur de sa place dans la ligne (jaune → rose, les couleurs des points de combo), avec ses charges (Fracasser armure ×5) et le temps restant. Une aura absente est grisée, ou cachée si tu décoches l'option (les autres gardent leur place).
- Un nom tapé que ton personnage ne connaît pas est suivi par son nom tel quel (point d'interrogation comme icône tant que l'aura n'a pas été vue).

## Rage qui va être consommée

Sur la barre de rage, la partie qui va partir est marquée en clair, depuis la fin de la barre :
- **Frappe héroïque**, **Enchaînement** (guerrier) et **Mutiler** (druide) en attente du prochain coup : leur coût, jusqu'au coup.
- **Heurtoir** (guerrier) pendant son incantation : son coût.
- **Régénération frénétique** (druide) : 10 rage par seconde restante, au plus ce que tu as.

Les techniques instantanées dépensent leur rage tout de suite : rien à prévoir pour elles. Les coûts sont lus dans le jeu (talents compris).

## Fonctionnement

- **Points de combo** : lus directement dans le jeu (`GetComboPoints("player", "target")`). Pas de table de sorts : le nombre est toujours exact, crits, talents et procs compris, et rien n'est à mettre à jour si les sorts changent. Pas de cible ou cible amicale : 0. Retour sur une cible qui avait des points : le bon nombre s'affiche. Cible morte : les points disparaissent dès l'événement de mort (`UNIT_HEALTH`), sans attendre le serveur.
- **Énergie et rage** : lues à chaque image affichée, donc chaque point s'affiche à l'image même où le client l'a. Si la valeur n'a pas changé, ça ne coûte qu'une comparaison. Couleur de la rage prise sur la capture de référence.
- **Valeurs secrètes** : Forever peut cacher ces nombres aux addons (« secret values »). L'addon ne les lit jamais : il les passe directement aux barres et au texte, qui les acceptent ; le marqueur de rage à consommer s'accroche à la fin de la barre sans lire la rage. L'affichage fonctionne donc dans les deux cas. Pour les icônes, si le jeu cachait une aura aux addons, elle apparaîtrait comme absente.
- **Taille** : à 100 %, la barre fait 292 × 53 pixels sur un client 2560×1440 fenêtré (1359 px de haut), quelle que soit l'échelle d'interface du jeu. Elle suit la hauteur de la fenêtre.
- **Druide** : la barre apparaît en forme de félin (énergie) et en forme d'ours (rage), et disparaît dans les autres formes (elle suit la ressource du personnage, comme la barre de combo de Blizzard). En ours, les cases vides ne sont pas dessinées : la ligne du haut ne montre que les points que la cible a vraiment, et tout revient d'un coup en repassant en félin. Elle reste visible dans toutes les formes tant qu'elle est déverrouillée ou que les options sont ouvertes. L'option « Afficher seulement en forme de félin et d'ours » la laisse affichée en permanence si on la décoche.
- **Guerrier** : pas de points de combo, la barre de rage seule, avec la ligne d'icônes posée dessus.
- **Langues** : l'addon ne dépend jamais de la langue du client (classes, ressources, événements et sorts sont lus par leurs identifiants internes), il marche donc sur tous les clients. Seuls les textes affichés changent avec le drapeau choisi.
- **Mise à jour** : tes anciens réglages sont gardés (depuis 1.0 / 1.1, ils sont copiés dans les profils voleur et druide). Le profil guerrier démarre avec les réglages par défaut.
- **Léger** : aucune bibliothèque, aucune texture à charger. Tant que la barre est cachée (druide hors félin et ours), l'addon ne lit plus rien : il se remet à jour d'un coup quand elle réapparaît. Les icônes ne sont relues que quand une aura change (une fois par image au plus). Sur une autre classe que voleur, druide ou guerrier, l'addon reste inactif : aucun événement, aucune mise à jour.

## Licences des polices

Les polices de `Media/Fonts` viennent de Google Fonts, sous licence SIL Open Font License ou Apache 2.0 (voir `Media/Fonts/Licenses`).
