# fullenv : le faux jeu fondé sur la vraie API

- `extract_apidoc.py <Blizzard_APIDocumentationGenerated> apidoc.lua` : lit la documentation de l'API
  générée par le client (fonctions, types de retour, méthodes des cadres, énumérations, constantes).
- `index_framexml.py <Interface/AddOns> framexml_index.lua` : indexe le code d'interface du client
  (fonctions et tables globales, constantes, cadres et modèles XML, polices, parentKey, noms globaux lus).
- `doctypes.lua` : renvoie des valeurs du bon type pour toute fonction ou méthode documentée.

`apidoc.lua` et `framexml_index.lua` se régénèrent à partir des fichiers du client (non inclus ici).

## Tout l'addon d'un coup

- `make_full.py` assemble `full_harness.lua` (le faux jeu de `tools/cui_harness.lua` + `full_tail.lua`).
- `run_full.sh <dossier ClaraComboPoints> <nom>` : charge tout le `.toc` (Lua et XML) avec tous les modules
  activés, joue une session (connexion, combat, fenêtres, chaque page d'options, chaque commande slash,
  chaque fenêtre de module, déconnexion) et écrit `full_out_<nom>.txt` : fichiers bloqués, erreurs,
  fonctions C_ inconnues du jeu, modèles inconnus, noms globaux inconnus.
- `FULL_SCENARIO=<fichier.lua> run_full.sh …` : joue en plus, avant la déconnexion, un scénario à soi (il reçoit
  `{ env, ns, Fire, RunTimers, Updates }`) ; ses erreurs vont dans le rapport. `scn_lfg_skin.lua` : la fenêtre de
  LFG Forever habillée par ClassicUI (version avec ClassicUI), sa flèche et Relancer la recherche cliqués.
