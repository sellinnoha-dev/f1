-- ============================================================
-- Tsunami Critters : TOUS LES RÉGLAGES DU JEU
-- Change les chiffres ici pour équilibrer le jeu, sans toucher au reste du code.
-- ============================================================

local Config = {}

-- Version du jeu, affichée dans la Sortie au lancement
Config.Version = "3 - batte et objets"
Config.GameName = "Tsunami Critters"

Config.StartingCash = 0

-- Sauvegarde (marche seulement une fois le jeu publié, ou avec l'accès API dans Studio)
Config.SaveEnabled = true
Config.DataStoreName = "TsunamiCritters_v1"
Config.AutosaveInterval = 120

-- ============================================================
-- CARTE : un long chemin entre deux falaises, de la base (X = 0) jusqu'à la mer
-- ============================================================
Config.PathLength = 1500
Config.PathWidth = 60
-- Tranchées où se cacher (position le long du chemin) : de plus en plus espacées
Config.Trenches = { 100, 200, 310, 430, 560, 700, 850, 1010, 1180, 1360 }
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
	-- Jamais sur le chemin : apparaît parfois devant les bases après une vague
	{ id = "divine", name = "DIVINE", color = Color3.fromRGB(255, 255, 255) },
}

-- Zones du chemin (dans l'ordre, depuis la base)
--   chances = probabilité de chaque rareté dans la zone ; count = créatures en même temps
Config.Zones = {
	{ rarity = "common", from = 0, to = 200, count = 6, color = Color3.fromRGB(120, 180, 95),
		chances = { common = 90, rare = 10 } },
	{ rarity = "rare", from = 200, to = 450, count = 5, color = Color3.fromRGB(95, 150, 200),
		chances = { common = 30, rare = 62, epic = 8 } },
	{ rarity = "epic", from = 450, to = 700, count = 5, color = Color3.fromRGB(150, 110, 200),
		chances = { rare = 35, epic = 58, legendary = 7 } },
	{ rarity = "legendary", from = 700, to = 950, count = 4, color = Color3.fromRGB(220, 180, 80),
		chances = { epic = 45, legendary = 50, mythic = 5 } },
	{ rarity = "mythic", from = 950, to = 1250, count = 3, color = Color3.fromRGB(200, 90, 100),
		chances = { legendary = 55, mythic = 42, secret = 3 } },
	{ rarity = "secret", from = 1250, to = 1500, count = 3, color = Color3.fromRGB(60, 200, 190),
		chances = { mythic = 80, secret = 20 } },
}
Config.SpawnInterval = 4 -- secondes entre deux apparitions (par zone)

-- Créature DIVINE : après chaque vague, petite chance qu'elle apparaisse devant les bases
-- (elle reste jusqu'à la vague suivante)
Config.DivineChance = 0.04

-- ============================================================
-- LA VAGUE
-- ============================================================
Config.WaveInterval = 35 -- secondes de calme entre deux vagues
Config.WaveWarning = 7 -- alerte avant l'arrivée
Config.WaveStartX = 1580 -- la vague part de la mer
Config.WaveThickness = 40
Config.SafeDepth = -3 -- dans une tranchée (plus bas que ça), la vague passe au-dessus
Config.WaveTypes = {
	{ name = "TSUNAMI", speed = 50, height = 60, weight = 60, color = Color3.fromRGB(30, 100, 190) },
	{ name = "FAST TSUNAMI", speed = 80, height = 50, weight = 25, color = Color3.fromRGB(25, 140, 200) },
	{ name = "GIANT TSUNAMI", speed = 40, height = 120, weight = 12, color = Color3.fromRGB(15, 55, 140) },
	{ name = "LIGHTNING TSUNAMI", speed = 120, height = 55, weight = 3, color = Color3.fromRGB(110, 60, 200) },
}

-- ============================================================
-- BASE ET AMÉLIORATIONS
-- ============================================================
Config.PlotCount = 8
Config.BasePedestals = 6
Config.SellMultiplier = 30 -- prix de vente d'une créature = son gain par seconde x 30

Config.Upgrades = {
	{ id = "speed", name = "SPEED", perLevel = 2, description = "+2 walk speed",
		prices = { 150, 500, 1500, 5000, 15000, 50000, 150000, 500000 } },
	{ id = "carry", name = "CARRY", perLevel = 1, description = "+1 critter carried",
		prices = { 3000, 50000, 750000 } },
	{ id = "pedestals", name = "PEDESTALS", perLevel = 2, description = "+2 pedestals",
		prices = { 800, 8000, 80000 } },
}

-- ============================================================
-- OBJETS (boutique au fond de la zone des bases). Un objet = une utilisation.
-- requires = rareté qu'il faut avoir déjà obtenue pour le débloquer
-- ============================================================
Config.Items = {
	{ id = "cloak", name = "Invisibility Cloak", requires = "rare", price = 5000, duration = 12,
		color = Color3.fromRGB(170, 200, 255), description = "Invisible for 12s" },
	{ id = "freeze", name = "Freeze Ray", requires = "epic", price = 25000, duration = 4, range = 45,
		color = Color3.fromRGB(120, 230, 255), description = "Freeze the closest player for 4s" },
	{ id = "raidkey", name = "Raid Key", requires = "legendary", price = 100000, duration = 20,
		color = Color3.fromRGB(255, 200, 40), description = "Enter another base for 20s and steal a critter" },
}

-- ============================================================
-- CRÉATURES : 3 par rareté. income = argent par seconde dans ta base.
-- look : body = "ball", "block" ou "cylinder" ; extras = accessoires
--   (antenna, feet, mustache, tophat, shades, propeller, headband, crown,
--    wizardhat, shell, wings, halo, horns, brows, cape, staff, monocle, tail, flames, orbit)
-- Musique et sons : voir le README (dossiers Music et Sounds dans SoundService)
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
		look = { body = "ball", size = 4.6, color = Color3.fromRGB(140, 70, 200), accent = Color3.fromRGB(200, 30, 50),
			eyes = 2, extras = { "crown", "mustache", "monocle", "cape", "feet" } } },
	{ id = "pizza", name = "Pizza Wizard", rarity = "legendary", income = 260,
		look = { body = "block", size = 4.4, color = Color3.fromRGB(240, 150, 50), accent = Color3.fromRGB(60, 50, 180),
			eyes = 2, extras = { "wizardhat", "brows", "staff", "cape" } } },
	{ id = "snail", name = "Turbo Snail", rarity = "legendary", income = 300,
		look = { body = "ball", size = 4.4, color = Color3.fromRGB(120, 220, 200), accent = Color3.fromRGB(255, 90, 30),
			eyes = 2, extras = { "shell", "antenna", "shades", "flames" } } },

	{ id = "spaghetti", name = "Lord Spaghetti", rarity = "mythic", income = 1100,
		look = { body = "cylinder", size = 5, color = Color3.fromRGB(250, 210, 120), accent = Color3.fromRGB(200, 30, 30),
			eyes = 2, extras = { "crown", "wings", "mustache", "cape", "staff" } } },
	{ id = "toast", name = "Cosmic Toast", rarity = "mythic", income = 1300,
		look = { body = "block", size = 5, color = Color3.fromRGB(80, 60, 160), accent = Color3.fromRGB(0, 230, 255),
			eyes = 3, extras = { "halo", "wings", "orbit" }, material = Enum.Material.Neon } },
	{ id = "pickle", name = "Dragon Pickle", rarity = "mythic", income = 1500,
		look = { body = "cylinder", size = 5.2, color = Color3.fromRGB(90, 170, 50), accent = Color3.fromRGB(255, 120, 0),
			eyes = 2, extras = { "horns", "wings", "brows", "tail", "flames" } } },

	{ id = "duck", name = "The Golden Duck", rarity = "secret", income = 6000,
		look = { body = "ball", size = 5.5, color = Color3.fromRGB(255, 200, 30), accent = Color3.fromRGB(255, 120, 0),
			eyes = 2, extras = { "crown", "halo", "feet", "cape", "orbit" }, material = Enum.Material.Foil } },
	{ id = "glitch", name = "Glitch Cat", rarity = "secret", income = 8000,
		look = { body = "block", size = 5.5, color = Color3.fromRGB(20, 20, 30), accent = Color3.fromRGB(0, 255, 120),
			eyes = 3, extras = { "horns", "antenna", "shades", "tail", "orbit" } } },
	{ id = "kingbloop", name = "King Bloop", rarity = "secret", income = 10000,
		look = { body = "ball", size = 6, color = Color3.fromRGB(0, 230, 200), accent = Color3.fromRGB(255, 215, 0),
			eyes = 2, extras = { "crown", "wings", "halo", "feet", "cape", "staff" }, material = Enum.Material.Glass } },

	{ id = "prism", name = "Prism Prince", rarity = "divine", income = 50000,
		look = { body = "ball", size = 6.5, color = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(255, 120, 255),
			eyes = 3, extras = { "crown", "wings", "halo", "cape", "orbit", "staff" }, material = Enum.Material.Glass } },
	{ id = "astral", name = "Astral Noodle", rarity = "divine", income = 75000,
		look = { body = "cylinder", size = 6.5, color = Color3.fromRGB(40, 20, 90), accent = Color3.fromRGB(255, 230, 120),
			eyes = 2, extras = { "horns", "wings", "halo", "mustache", "tail", "flames", "orbit" }, material = Enum.Material.Neon } },
}

return Config
