# Garage Tycoon 🚗

Un jeu Roblox de type **tycoon** : chaque joueur a son garage, des machines fabriquent des pièces auto qui roulent sur un tapis jusqu'au collecteur, et l'argent gagné sert à acheter de nouvelles machines, des améliorations et des voitures de showroom.

## Ce que contient la version 1

- 4 garages par serveur, attribués automatiquement aux joueurs
- 5 machines de production (dropper), 2 améliorations (x2 et x1.5), des murs, 2 voitures de showroom sur podium tournant
- Environ 25 à 30 minutes de progression
- Sauvegarde automatique de l'argent et des achats
- Un Game Pass « Argent x2 » prêt à brancher (c'est lui qui peut rapporter de vrais Robux)

## Organisation du dépôt

| Fichier | Rôle |
|---|---|
| `build/GarageTycoon.rbxlx` | Le jeu complet, prêt à ouvrir dans Roblox Studio |
| `src/shared/Config.luau` | **Les réglages** : prix, gains, ordre des objets. C'est ici que tu équilibres le jeu |
| `src/server/TycoonServer.server.luau` | Le moteur du jeu (garages, machines, argent, sauvegarde) |
| `src/client/CashHud.client.luau` | Le compteur d'argent affiché en bas de l'écran |
| `src/shared/FormatMoney.luau` | Affiche les montants en version courte (1.5K, 2M…) |
| `default.project.json` | Fichier [Rojo](https://rojo.space) qui sert à reconstruire le `.rbxlx` à partir du code |

## Lancer le jeu sur ton PC (Windows)

1. Installe **Roblox Studio** depuis https://create.roblox.com et connecte-toi avec ton compte Roblox.
2. Sur GitHub, ouvre `build/GarageTycoon.rbxlx`, puis clique sur le bouton **Download raw file** (l'icône de téléchargement en haut à droite du fichier).
3. Double-clique sur le fichier téléchargé : il s'ouvre dans Roblox Studio.
4. Clique sur **Play** (ou appuie sur `F5`). Tu apparais dans ton garage.
5. Marche sur le bouton vert **Bolt Workbench (FREE)** : la première machine apparaît et l'argent commence à tomber.

> Dans Studio, la sauvegarde ne fonctionne pas tant que le jeu n'est pas publié. C'est normal : un message jaune s'affiche dans la fenêtre Output et le jeu marche quand même.

## Mettre à jour le jeu (sans Rojo)

1. Ouvre ton jeu dans Studio, **jeu arrêté** (pas en mode Play).
2. Clique dans la barre en bas de Studio « Exécuter une commande… » (si elle n'est pas là : **Fenêtre → Barre de commande**).
3. Colle cette ligne puis appuie sur **Entrée** :

```lua
local H = game:GetService("HttpService") H.HttpEnabled = true loadstring(H:GetAsync("https://raw.githubusercontent.com/sellinnoha-dev/f1/main/tools/StudioUpdate.luau?v=" .. os.time(), true))()
```

4. La Sortie affiche « Mise à jour terminée : 4/4 ». Fais **Ctrl + S** puis **F5**.

Astuce : la prochaine fois, clique dans la barre de commande et appuie sur **flèche du haut** pour retrouver la ligne.

## Utiliser de vrais modèles de la Boîte à outils

Le jeu peut remplacer ses formes simples par des modèles choisis dans la Boîte à outils de Studio.
1. Dans **ServerStorage**, crée un dossier nommé **`Assets`**.
2. Range dedans tes modèles avec exactement ces noms :

| Nom | Utilisé pour |
|---|---|
| `Bolt` | pièce de la Bolt Workbench |
| `Tire` | pièce de la Tire Station |
| `Engine` | pièce de l'Engine Bench |
| `Panel` | pièce de la Body Shop Line |
| `Rim` | pièce de la Rim Factory |
| `SportCar` | voiture du 1er podium |
| `SportCar2` | voiture du 2e podium |
| `SportCar3` | voiture du 3e podium |
| `Supercar` | voiture du 4e podium |
| `Supercar2` | voiture du 5e podium |

Le jeu les met à la bonne taille et supprime les scripts qu'ils contiennent. Il manque un modèle ? La forme simple est utilisée à la place.
Enregistre ton jeu (**Fichier → Enregistrer sous**) en dehors du dossier `project`, par exemple `C:\Users\<toi>\GarageTycoon\MonGarage.rbxlx`.

## Publier le jeu sur Roblox

1. Dans Studio : **File → Publish to Roblox**, puis choisis un nom et une description.
2. **Home → Game Settings → Security** : active **Enable Studio Access to API Services**, sinon la sauvegarde ne marchera pas pendant tes tests.
3. **Game Settings → Places** (ou dans le Creator Dashboard) : règle le **nombre maximum de joueurs à 4**, puisqu'il y a 4 garages.
4. Rends le jeu public quand tu es prêt (Creator Dashboard → ton expérience → Privacy → Public).

## Brancher le Game Pass « Argent x2 »

1. Va sur https://create.roblox.com/dashboard/creations, ouvre ton expérience, puis **Monetization → Passes → Create a Pass**.
2. Ajoute une image et un nom (par exemple « 2x Cash »), puis enregistre.
3. Ouvre le pass, va dans **Sales**, active **Item for Sale** et fixe un prix (pour ce type de pass, on voit souvent entre 99 et 199 Robux).
4. Copie l'**ID** du pass (le nombre dans l'URL).
5. Dans Studio, ouvre `ReplicatedStorage → Config` et remplace `Config.CashX2GamePassId = 0` par ton ID.
6. Republie le jeu. Un bouton doré « 2x CASH » apparaît dans chaque garage.

Sur chaque vente, Roblox te reverse environ 70 % des Robux. Pour convertir tes Robux en euros (programme DevEx), il faut au minimum 30 000 Robux gagnés et un compte vérifié. Vérifie les conditions et le taux actuels sur la page officielle DevEx.

## Modifier le jeu

- **Changer un prix ou un gain** : modifie `Config.luau`, rien d'autre à toucher.
- **Ajouter une machine** : copie un bloc `dropper` dans `Config.Items`, donne-lui un nouvel `id`, choisis un `z` libre sur le tapis (entre 24 et -18) et une position de `button` libre.
- Si tu modifies les fichiers dans `src/`, reconstruis le jeu avec Rojo : `rojo build default.project.json -o build/GarageTycoon.rbxlx`.

## Idées pour la suite

- Un système de **rebirth** : on repart de zéro avec un multiplicateur permanent (ça augmente beaucoup le temps de jeu).
- Une interface d'argent plus jolie, avec un « +$ » animé à chaque vente.
- Plus de voitures (BMW, Mercedes… en style générique, sans les logos des marques).
- Des **Developer Products** : des achats répétables, comme un pack d'argent.
