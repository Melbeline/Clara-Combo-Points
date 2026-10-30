# fullenv : le faux jeu fondé sur la vraie API

- `extract_apidoc.py <Blizzard_APIDocumentationGenerated> apidoc.lua` : lit la documentation de l'API
  générée par le client (fonctions, types de retour, méthodes des cadres, énumérations, constantes).
- `index_framexml.py <Interface/AddOns> framexml_index.lua` : indexe le code d'interface du client
  (fonctions et tables globales, constantes, cadres et modèles XML, polices, parentKey, noms globaux lus).
- `doctypes.lua` : renvoie des valeurs du bon type pour toute fonction ou méthode documentée.

`apidoc.lua` et `framexml_index.lua` se régénèrent à partir des fichiers du client (non inclus ici).
