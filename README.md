# Tsunami Critters 🌊

Un jeu Roblox : cours sur le chemin pour attraper des **créatures délirantes**, ramène-les dans ta base
pour gagner de l'argent… et cache-toi dans une **tranchée** quand le tsunami arrive !

## Comment on joue

1. Tu apparais dans ta **base** (zone sûre : la vague n'y va jamais).
2. Le chemin part vers la mer. Plus tu vas loin, plus les créatures sont rares :
   COMMON → RARE → EPIC → LEGENDARY → MYTHIC → SECRET.
3. Maintiens **E** sur une créature pour l'attraper : elle se met au-dessus de ta tête.
4. Rentre dans ta base : elle se pose sur un piédestal et rapporte de l'argent chaque seconde.
5. Toutes les 35 s, un **tsunami** arrive (alerte 7 s avant). Saute dans une **tranchée** (bordures jaunes)
   pour qu'il passe au-dessus de toi. S'il te touche, tu meurs et tu perds ce que tu portes.
   Après chaque vague, toutes les créatures sont renouvelées, et parfois (4 %) une créature **DIVINE**
   apparaît juste devant les bases, avec une aura arc-en-ciel et une annonce pour tout le serveur.
6. Dans ta base, marche sur les boutons verts pour acheter : **SPEED** (courir plus vite),
   **CARRY** (porter plus de créatures), **PEDESTALS** (plus de places).
7. Sur un piédestal, maintiens **E** pour vendre la créature (gain par seconde × 30).
8. Tout le monde a une **batte** (barre d'outils en bas, touche 1) : frappe un joueur qui porte des créatures,
   il les lâche par terre et retourne dans sa base. Sinon, ça le repousse juste un peu.
9. **Boutique d'objets** au fond de la zone des bases, ou bouton **SHOP** à gauche de l'écran
   (un objet = une utilisation, 3 max de chaque). Ils vont dans ta barre d'outils, à côté de la batte.
10. Menu à gauche : **SHOP** (objets + Game Pass en Robux), **UPGRADES** (acheter les améliorations de n'importe où),
    **INDEX** (toutes les créatures, celles pas encore trouvées sont cachées).

## Bots

Dans Studio, 3 bots prennent des bases libres et jouent : ils vont chercher les créatures qu'ils ont le temps
d'attraper avant la vague, se cachent dans les tranchées, rentrent, achètent des améliorations et donnent des
coups de batte à ceux qui portent une créature. Leur pensée s'affiche au-dessus de leur tête.
Réglages : `Config.BotsEnabled`, `Config.BotCount`, `Config.BotsOnlyInStudio`.

## Game Pass (Robux)

Dans `Config.GamePasses` : 2x Cash, +2 Carry, Speed Boost. Crée chaque pass sur le Creator Dashboard
(**Monetization → Passes**), puis remplace `id = 0` par son numéro. Tant que c'est 0, le bouton affiche « coming soon ».
   - **Invisibility Cloak** (débloqué avec une créature RARE) : invisible 12 s (tu te vois en fantôme,
     bouton **REAPPEAR** pour revenir avant la fin).
   - **Freeze Ray** (EPIC) : gèle le joueur le plus proche pendant 4 s.
   - **Raid Key** (LEGENDARY) : 20 s pour traverser le mur d'énergie d'une autre base et voler une créature
     (maintiens E dessus). Si le voleur meurt, la créature revient à son propriétaire.

## Ajouter de la musique (et des sons)

Le code ne peut pas choisir une musique à ta place (les sons Roblox doivent être autorisés pour ton jeu), donc :
1. Dans l'Explorateur, clic droit sur **SoundService → Insérer un objet → Folder**, renomme-le **`Music`**.
2. Ouvre la **Boîte à outils**, catégorie **Audio**, cherche « chill » ou « lofi ».
   Prends de préférence un son publié par **Roblox** (ceux-là sont utilisables dans tous les jeux).
3. Clique dessus pour l'insérer, puis glisse le son (il arrive dans Workspace) dans le dossier **Music**.
   Tu peux en mettre plusieurs : ils passent au hasard. La musique ne joue que dans la zone des bases
   (elle se coupe doucement quand tu pars sur le chemin).
4. Optionnel : un dossier **`Sounds`** dans SoundService avec des sons nommés **`Siren`**, **`Wave`** ou **`Divine`**
   remplace les sons par défaut de l'alerte, de la vague et de la créature divine.

## Installer le jeu dans Studio (sans Rojo)

1. Dans Roblox Studio : **Fichier → Nouveau → Baseplate** (une NOUVELLE place, pas Garage Tycoon).
2. Clique dans la barre de commande en bas (« Exécuter une commande… » ; sinon **Fenêtre → Barre de commande**).
3. Colle cette ligne puis **Entrée** :

```lua
local H = game:GetService("HttpService") H.HttpEnabled = true loadstring(H:GetAsync("https://raw.githubusercontent.com/sellinnoha-dev/f1/main/tools/StudioUpdate.luau?v=" .. os.time(), true))()
```

4. La Sortie affiche « Mise à jour terminée : 5/5 ». Fais **Fichier → Enregistrer sous** (ex. `TsunamiCritters.rbxlx`), puis **F5**.

Pour mettre à jour plus tard : même ligne (flèche du haut dans la barre de commande), jeu arrêté,
et **ferme l'onglet Config** s'il est ouvert.

## Panneau de test (Studio uniquement)

À droite de l'écran : **+$10K**, **+$1M**, **Wave now** (vague dans 3 s), **Spawn Legendary**, **Spawn SECRET**
(une créature rare apparaît dans la zone COMMON, tout près de la base), **Spawn DIVINE**, **Unlock items**.

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
| `src/shared/ItemModels.luau` | Les modèles 3D des objets (boutique et barre d'objets) |
| `src/client/WaveClient.client.luau` | L'écran du joueur : argent, alerte, vague animée, panneau de test |
| `tools/StudioUpdate.luau` | Installe / met à jour les scripts dans Studio |
| `build/TsunamiCritters.rbxlx` | Le jeu construit avec Rojo |
| `garage-tycoon/` | L'ancien projet Garage Tycoon (archivé) |
