# Tests de Clara (hors jeu)

Copie de sauvegarde de l'environnement de test de l'addon : un faux WoW Forever en Lua 5.1, qui
charge le code de l'addon et vérifie ce qu'il fait, sans le jeu. Rien ici n'est chargé par le jeu.

## Installation

```
python3 -m venv venv
venv/bin/pip install lupa pillow
```

Les mesures de texte utilisent la police Liberation Sans (`/usr/share/fonts/truetype/liberation/`).

## Lancer

- Toute la suite, sur le dossier `ClaraComboPoints` d'une branche :
  `bash tools/runall2.sh /chemin/vers/ClaraComboPoints` (n'affiche que les tests qui échouent, puis `finished`).
- Un seul test : `venv/bin/python -I tools/run.py $PWD/tools /chemin/vers/ClaraComboPoints test34.lua`.
- Les harnais d'un module (mock plus permissif, un module à la fois) :
  `venv/bin/python -I ui_lea_run.py tools/<module>_harness.lua /chemin/vers/ClaraComboPoints`
  (Leatrix Plus : `tools/lea_harness_clara.lua` sur le dossier `Modules/LeatrixPlus`).
  ClassicUI (branche avec) : `run_cui.sh <dossier de la branche>`, mémoire limitée.

## Contenu

- `tools/wowmock.lua` : le faux jeu (cadres, événements, options, menus, combat).
- `tools/test*.lua` : les scénarios, un par fonction de l'addon.
- `tools/*_harness.lua` : les harnais des modules intégrés.
- `tools/render.*`, `tools/prof_*`, `tools/bench*` : rendus d'images et mesures de performance.
- `apply_locale_delta.py`, `unused_keys.py` : outils de report des traductions entre branches.
- `usage_stats.py` : compte des tokens d'une session Claude Code à partir de son historique.

Ces tests ne remplacent pas le jeu : ils prouvent que le code se charge et réagit comme prévu à ce
qui est simulé, pas le rendu à l'écran ni le comportement face aux vraies données du jeu.
