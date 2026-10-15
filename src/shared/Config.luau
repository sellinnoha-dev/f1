-- ============================================================
-- Tsunami Critters : TOUS LES RÉGLAGES DU JEU
-- Change les chiffres ici pour équilibrer le jeu, sans toucher au reste du code.
-- ============================================================

local Config = {}

-- Version du jeu, affichée dans la Sortie au lancement
Config.Version = "1 - premiere vague"
Config.GameName = "Tsunami Critters"

Config.StartingCash = 0

-- Sauvegarde (marche seulement une fois le jeu publié, ou avec l'accès API dans Studio)
Config.SaveEnabled = true
Config.DataStoreName = "TsunamiCritters_v1"
Config.AutosaveInterval = 120

-- ============================================================
-- CARTE : un long chemin entre deux falaises, de la base (X = 0) jusqu'à la mer
-- ============================================================
Config.PathLength = 900
Config.PathWidth = 60
-- Tranchées où se cacher (position le long du chemin)
Config.Trenches = { 90, 200, 310, 420, 530, 640, 750, 860 }
Config.TrenchLength = 14
Config.TrenchDepth = 9

-- ============================================================
-- RARETÉS : plus on va loin, plus les créatures sont rares
-- ============================================================
Config.Rarities = {
	{ id = "common", name = "COMMON", color = Color3.fromRGB(200, 200, 200) },
	{ id = "rare", name = "RARE", color = Color3.fromRGB(70, 150, 255) },
	{ id = "epic", name = "EPIC", color = Color3.fromRGB(180, 80, 255) },
	{ id = "legendary", name = "LEGENDARY", color = Color3.fromRGB(255, 190, 0) },
	{ id = "mythic", name = "MYTHIC", color = Color3.fromRGB(255, 50, 80) },
	{ id = "secret", name = "SECRET", color = Color3.fromRGB(0, 255, 220) },
}

-- Zones du chemin (dans l'ordre, depuis la base)
Config.Zones = {
	{ rarity = "common", from = 0, to = 150, color = Color3.fromRGB(120, 180, 95) },
	{ rarity = "rare", from = 150, to = 300, color = Color3.fromRGB(95, 150, 200) },
	{ rarity = "epic", from = 300, to = 450, color = Color3.fromRGB(150, 110, 200) },
	{ rarity = "legendary", from = 450, to = 600, color = Color3.fromRGB(220, 180, 80) },
	{ rarity = "mythic", from = 600, to = 750, color = Color3.fromRGB(200, 90, 100) },
	{ rarity = "secret", from = 750, to = 900, color = Color3.fromRGB(60, 200, 190) },
}
Config.CreaturesPerZone = 5
Config.SpawnInterval = 3 -- secondes entre deux apparitions (par zone)
Config.BetterRarityChance = 0.15 -- chance qu'une créature de la rareté au-dessus apparaisse

-- ============================================================
-- LA VAGUE
-- ============================================================
Config.WaveInterval = 40 -- secondes de calme entre deux vagues
Config.WaveWarning = 8 -- alerte avant l'arrivée
Config.WaveStartX = 960 -- la vague part de la mer
Config.WaveThickness = 30
Config.SafeDepth = -3 -- dans une tranchée (plus bas que ça), la vague passe au-dessus
Config.WaveTypes = {
	{ name = "TSUNAMI", speed = 40, height = 45, weight = 60, color = Color3.fromRGB(40, 120, 220) },
	{ name = "FAST TSUNAMI", speed = 65, height = 35, weight = 25, color = Color3.fromRGB(30, 170, 230) },
	{ name = "GIANT TSUNAMI", speed = 32, height = 90, weight = 12, color = Color3.fromRGB(20, 70, 170) },
	{ name = "LIGHTNING TSUNAMI", speed = 100, height = 40, weight = 3, color = Color3.fromRGB(150, 80, 255) },
}

-- ============================================================
-- BASE ET AMÉLIORATIONS
-- ============================================================
Config.PlotCount = 8
Config.BasePedestals = 6
Config.SellMultiplier = 30 -- prix de vente d'une créature = son gain par seconde x 30

Config.Upgrades = {
	{ id = "speed", name = "SPEED", perLevel = 3, description = "+3 walk speed",
		prices = { 100, 300, 900, 2500, 7000, 20000, 55000, 150000, 400000, 1000000 } },
	{ id = "carry", name = "CARRY", perLevel = 1, description = "+1 critter carried",
		prices = { 2000, 25000, 300000 } },
	{ id = "pedestals", name = "PEDESTALS", perLevel = 2, description = "+2 pedestals",
		prices = { 500, 5000, 50000 } },
}

-- ============================================================
-- CRÉATURES : 3 par rareté. income = argent par seconde dans ta base.
-- look : body = "ball", "block" ou "cylinder" ; extras = accessoires
--   (antenna, feet, mustache, tophat, shades, propeller, headband, crown,
--    wizardhat, shell, wings, halo, horns, brows)
-- Pour utiliser ton propre modèle : range-le dans ServerStorage > Assets
-- avec exactement le même nom que la créature (ex. "Bloop").
-- ============================================================
Config.Creatures = {
	{ id = "bloop", name = "Bloop", rarity = "common", income = 1,
		look = { body = "ball", size = 3, color = Color3.fromRGB(90, 200, 90), accent = Color3.fromRGB(255, 230, 0),
			eyes = 2, extras = { "antenna", "feet" } } },
	{ id = "toasty", name = "Toasty", rarity = "common", income = 2,
		look = { body = "block", size = 3, color = Color3.fromRGB(225, 180, 110), accent = Color3.fromRGB(140, 90, 40),
			eyes = 2, extras = { "feet", "brows" } } },
	{ id = "pebble", name = "Pebble Pete", rarity = "common", income = 3,
		look = { body = "ball", size = 3.2, color = Color3.fromRGB(150, 150, 155), accent = Color3.fromRGB(60, 40, 30),
			eyes = 1, extras = { "mustache", "feet" }, material = Enum.Material.Slate } },

	{ id = "noodle", name = "Captain Noodle", rarity = "rare", income = 10,
		look = { body = "cylinder", size = 3.2, color = Color3.fromRGB(250, 220, 100), accent = Color3.fromRGB(30, 30, 35),
			eyes = 2, extras = { "tophat", "mustache" } } },
	{ id = "potato", name = "Disco Potato", rarity = "rare", income = 13,
		look = { body = "ball", size = 3.4, color = Color3.fromRGB(170, 120, 70), accent = Color3.fromRGB(255, 80, 200),
			eyes = 2, extras = { "shades", "feet", "antenna" } } },
	{ id = "cloud", name = "Grumpy Cloud", rarity = "rare", income = 16,
		look = { body = "ball", size = 3.6, color = Color3.fromRGB(240, 240, 250), accent = Color3.fromRGB(80, 80, 100),
			eyes = 2, extras = { "brows", "wings" } } },

	{ id = "frog", name = "Rocket Frog", rarity = "epic", income = 45,
		look = { body = "ball", size = 3.6, color = Color3.fromRGB(40, 160, 70), accent = Color3.fromRGB(255, 90, 30),
			eyes = 2, extras = { "propeller", "feet" } } },
	{ id = "banana", name = "Banana Ninja", rarity = "epic", income = 55,
		look = { body = "cylinder", size = 3.4, color = Color3.fromRGB(255, 225, 60), accent = Color3.fromRGB(220, 30, 40),
			eyes = 2, extras = { "headband", "brows", "feet" } } },
	{ id = "cactus", name = "Cactus Cowboy", rarity = "epic", income = 65,
		look = { body = "cylinder", size = 3.6, color = Color3.fromRGB(60, 140, 70), accent = Color3.fromRGB(130, 80, 40),
			eyes = 2, extras = { "tophat", "mustache" } } },

	{ id = "wobbleton", name = "Sir Wobbleton", rarity = "legendary", income = 220,
		look = { body = "ball", size = 4, color = Color3.fromRGB(140, 70, 200), accent = Color3.fromRGB(255, 200, 0),
			eyes = 2, extras = { "crown", "mustache", "feet" } } },
	{ id = "pizza", name = "Pizza Wizard", rarity = "legendary", income = 260,
		look = { body = "block", size = 3.8, color = Color3.fromRGB(240, 150, 50), accent = Color3.fromRGB(60, 50, 180),
			eyes = 2, extras = { "wizardhat", "brows" } } },
	{ id = "snail", name = "Turbo Snail", rarity = "legendary", income = 300,
		look = { body = "ball", size = 3.6, color = Color3.fromRGB(120, 220, 200), accent = Color3.fromRGB(230, 60, 60),
			eyes = 2, extras = { "shell", "antenna", "shades" } } },

	{ id = "spaghetti", name = "Lord Spaghetti", rarity = "mythic", income = 1100,
		look = { body = "cylinder", size = 4, color = Color3.fromRGB(250, 210, 120), accent = Color3.fromRGB(200, 30, 30),
			eyes = 2, extras = { "crown", "wings", "mustache" } } },
	{ id = "toast", name = "Cosmic Toast", rarity = "mythic", income = 1300,
		look = { body = "block", size = 4, color = Color3.fromRGB(80, 60, 160), accent = Color3.fromRGB(0, 230, 255),
			eyes = 3, extras = { "halo", "wings" }, material = Enum.Material.Neon } },
	{ id = "pickle", name = "Dragon Pickle", rarity = "mythic", income = 1500,
		look = { body = "cylinder", size = 4.2, color = Color3.fromRGB(90, 170, 50), accent = Color3.fromRGB(255, 120, 0),
			eyes = 2, extras = { "horns", "wings", "brows" } } },

	{ id = "duck", name = "The Golden Duck", rarity = "secret", income = 6000,
		look = { body = "ball", size = 4.5, color = Color3.fromRGB(255, 200, 30), accent = Color3.fromRGB(255, 120, 0),
			eyes = 2, extras = { "crown", "halo", "feet" }, material = Enum.Material.Foil } },
	{ id = "glitch", name = "Glitch Cat", rarity = "secret", income = 8000,
		look = { body = "block", size = 4.4, color = Color3.fromRGB(20, 20, 30), accent = Color3.fromRGB(0, 255, 120),
			eyes = 3, extras = { "horns", "antenna", "shades" } } },
	{ id = "kingbloop", name = "King Bloop", rarity = "secret", income = 10000,
		look = { body = "ball", size = 5, color = Color3.fromRGB(0, 230, 200), accent = Color3.fromRGB(255, 215, 0),
			eyes = 2, extras = { "crown", "wings", "halo", "feet" }, material = Enum.Material.Glass } },
}

return Config
