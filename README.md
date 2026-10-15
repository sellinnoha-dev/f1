# Tsunami Critters 🌊

Un jeu Roblox : cours sur le chemin pour attraper des **créatures délirantes**, ramène-les dans ta base
pour gagner de l'argent… et cache-toi dans une **tranchée** quand le tsunami arrive !

## Comment on joue

1. Tu apparais dans ta **base** (zone sûre : la vague n'y va jamais).
2. Le chemin part vers la mer. Plus tu vas loin, plus les créatures sont rares :
   COMMON → RARE → EPIC → LEGENDARY → MYTHIC → SECRET.
3. Maintiens **E** sur une créature pour l'attraper : elle se met au-dessus de ta tête.
4. Rentre dans ta base : elle se pose sur un piédestal et rapporte de l'argent chaque seconde.
5. Toutes les 40 s, un **tsunami** arrive (alerte 8 s avant). Saute dans une **tranchée** (bordures jaunes)
   pour qu'il passe au-dessus de toi. S'il te touche, tu meurs et tu perds ce que tu portes.
6. Dans ta base, marche sur les boutons verts pour acheter : **SPEED** (courir plus vite),
   **CARRY** (porter plus de créatures), **PEDESTALS** (plus de places).
7. Sur un piédestal, maintiens **E** pour vendre la créature (gain par seconde × 30).

## Installer le jeu dans Studio (sans Rojo)

1. Dans Roblox Studio : **Fichier → Nouveau → Baseplate** (une NOUVELLE place, pas Garage Tycoon).
2. Clique dans la barre de commande en bas (« Exécuter une commande… » ; sinon **Fenêtre → Barre de commande**).
3. Colle cette ligne puis **Entrée** :

```lua
local H = game:GetService("HttpService") H.HttpEnabled = true loadstring(H:GetAsync("https://raw.githubusercontent.com/sellinnoha-dev/f1/main/tools/StudioUpdate.luau?v=" .. os.time(), true))()
```

4. La Sortie affiche « Mise à jour terminée : 4/4 ». Fais **Fichier → Enregistrer sous** (ex. `TsunamiCritters.rbxlx`), puis **F5**.

Pour mettre à jour plus tard : même ligne (flèche du haut dans la barre de commande), jeu arrêté,
et **ferme l'onglet Config** s'il est ouvert.

## Panneau de test (Studio uniquement)

À droite de l'écran : **+$10K**, **+$1M**, **Wave now** (vague dans 3 s), **Spawn Legendary**, **Spawn SECRET**
(une créature rare apparaît dans la zone COMMON, tout près de la base).

## Tes propres créatures

Les 18 créatures sont construites par le code (formes + accessoires). Pour en remplacer une par ton modèle :
crée un dossier **`Assets`** dans **ServerStorage** et range ton modèle dedans avec **exactement** le nom de la créature
(ex. `Bloop`, `Sir Wobbleton`). Le jeu le met à la bonne taille.

## Réglages

Tout est dans `src/shared/Config.luau` : vitesse et types de vagues, temps entre les vagues, position des tranchées,
gains des créatures, prix des améliorations.

## Organisation du dépôt

| Fichier | Rôle |
|---|---|
| `src/shared/Config.luau` | Tous les réglages |
| `src/server/WaveServer.server.luau` | Le moteur : carte, vague, créatures, bases, sauvegarde |
| `src/client/WaveClient.client.luau` | L'écran du joueur : argent, alerte, vague animée, panneau de test |
| `tools/StudioUpdate.luau` | Installe / met à jour les scripts dans Studio |
| `build/TsunamiCritters.rbxlx` | Le jeu construit avec Rojo |
| `garage-tycoon/` | L'ancien projet Garage Tycoon (archivé) |
