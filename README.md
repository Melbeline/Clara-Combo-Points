# Clara-Combo-Points

Addon autonome pour **World of Warcraft: Forever** (bêta 1.60.1, Interface 16001), portage du WeakAura Classic « Complete Rogue » de Faineantt (https://wago.io/WouewStiD).

Pour **voleur** et **druide en forme de félin**.

- **Ligne du haut** : 5 cases de points de combo (jaune → orange → rose).
- **Barre du bas** : l'énergie, avec sa valeur en chiffres.

## Installation

Copier le dossier `ClaraComboPoints` dans le dossier `Interface\AddOns` de ton client WoW Forever (le même que celui où se trouve ForeverRogueCP), puis relancer le jeu ou faire `/reload`.

## Utilisation

`/clara` ou `/cl` ouvre les options :

| Réglage | Détail |
|---|---|
| Position | Verrouiller / déverrouiller (barre déplaçable au clic gauche quand déverrouillée), retour à la position par défaut |
| Échelle | Boutons 50 → 300 % en un clic, ou n'importe quelle valeur de 10 à 500 % tapée dans la case (100 % par défaut) |
| Opacité globale | Opacité de tout l'addon |
| Couleurs et opacité | Chaque case de combo, la barre d'énergie, le fond des cases vides et le texte : couleur via le sélecteur de couleur de Blizzard (roue, luminosité, opacité) + curseur d'opacité indépendant |
| Police | 20 polices (Arial Narrow par défaut, Friz Quadrata, Morpheus, Skurri, Emily's Candy, Bangers, Luckiest Guy, Chewy, Permanent Marker, Creepster, Pirata One, MedievalSharp, Cinzel Decorative, Bebas Neue, Russo One, Black Ops One, Audiowide, Righteous, Press Start 2P, Share Tech Mono) + celles de LibSharedMedia si un autre addon les fournit ; taille ; contour |
| Avancé | Source des points de combo (cible / joueur), druide : barre seulement en forme de félin (coché par défaut), aperçu 5 points, tout réinitialiser |

Commandes rapides : `/cl lock`, `/cl unlock`, `/cl scale 120`, `/cl reset`.

À l'ouverture des options, la barre affiche les 5 points pour voir les couleurs. L'aperçu se coupe à la fermeture des options ou en entrant en combat.

## Fonctionnement

- **Points de combo** : lus directement dans le jeu (`GetComboPoints("player", "target")`). Pas de table de sorts : le nombre est toujours exact, crits, talents et procs compris, et rien n'est à mettre à jour si les sorts changent. Pas de cible ou cible amicale : 0. Retour sur une cible qui avait des points : le bon nombre s'affiche. Cible morte : les points disparaissent dès l'événement de mort (`UNIT_HEALTH`), sans attendre le serveur.
- **Énergie** : lue à chaque image affichée, donc chaque point régénéré s'affiche à l'image même où le client l'a. Si la valeur n'a pas changé, ça ne coûte qu'une comparaison.
- **Valeurs secrètes** : Forever peut cacher ces nombres aux addons (« secret values »). L'addon ne les lit jamais : il les passe directement aux barres et au texte, qui les acceptent. L'affichage fonctionne donc dans les deux cas.
- **Taille** : à 100 %, la barre fait 292 × 53 pixels sur un client 2560×1440 fenêtré (1359 px de haut), quelle que soit l'échelle d'interface du jeu. Elle suit la hauteur de la fenêtre.
- **Druide** : la barre apparaît en forme de félin et disparaît dans les autres formes, comme la barre de combo de Blizzard (elle suit le passage de la ressource à l'énergie). Elle reste visible dans toutes les formes quand elle est déverrouillée ou que les options sont ouvertes, pour pouvoir la placer et la régler. L'option « Druide : barre seulement en forme de félin » la laisse affichée en permanence si on la décoche.
- **Léger** : aucune bibliothèque, aucune texture à charger. Rien ne tourne tant que la barre est cachée (druide hors félin). Sur une autre classe que voleur ou druide, l'addon reste inactif : aucun événement, aucune mise à jour.

## Licences des polices

Les polices de `Media/Fonts` viennent de Google Fonts, sous licence SIL Open Font License ou Apache 2.0 (voir `Media/Fonts/Licenses`).
