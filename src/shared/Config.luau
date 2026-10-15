-- ============================================================
-- Garage Tycoon : réglages du jeu
-- C'est ICI que tu modifies les prix, les gains et les objets.
-- Pas besoin de toucher au script serveur pour équilibrer le jeu.
-- ============================================================

local Config = {}

-- Version du jeu, affichée dans la Sortie au lancement
Config.Version = "18 - vol de voitures"

-- Argent donné à un nouveau joueur
Config.StartingCash = 0

-- Mode test : argent de départ quand tu joues dans Roblox Studio (F5).
-- N'a AUCUN effet dans le vrai jeu publié. Plus simple : tape "/cash 250000" dans le chat pendant le test.
Config.StudioTestCash = 0

-- Nombre de garages sur la carte (= nombre max de joueurs par serveur)
Config.PlotCount = 8
-- Distance entre le centre de la carte et chaque garage (en studs)
Config.PlotDistance = 170

-- Rebirth : quand tout est acheté, le joueur peut recommencer à zéro contre un bonus permanent
Config.RebirthCost = 150000 -- prix du 1er rebirth (x2 pour le 2e, x3 pour le 3e...)
Config.RebirthBonus = 0.5 -- +50 % d'argent par rebirth
Config.RebirthButton = Vector3.new(16, 0, -8)

-- Niveaux du garage : chaque rebirth fait passer au niveau suivant
-- (sol, murs, néons, lampadaires, façade plus haute, plantes, tapis rouge...)
Config.GarageTiers = {
	{
		name = "STANDARD", lamps = 0,
		floorColor = Color3.fromRGB(70, 70, 75), floorMaterial = Enum.Material.Concrete,
		wallColor = Color3.fromRGB(200, 200, 205), wallMaterial = Enum.Material.Brick,
		trimColor = Color3.fromRGB(255, 200, 0),
	},
	{
		name = "BRONZE", lamps = 2,
		floorColor = Color3.fromRGB(125, 90, 60), floorMaterial = Enum.Material.WoodPlanks,
		wallColor = Color3.fromRGB(175, 115, 75), wallMaterial = Enum.Material.Brick,
		trimColor = Color3.fromRGB(205, 127, 50),
	},
	{
		name = "SILVER", lamps = 4,
		floorColor = Color3.fromRGB(215, 215, 220), floorMaterial = Enum.Material.Marble,
		wallColor = Color3.fromRGB(235, 235, 240), wallMaterial = Enum.Material.SmoothPlastic,
		trimColor = Color3.fromRGB(120, 200, 255),
	},
	{
		name = "GOLD", lamps = 6,
		floorColor = Color3.fromRGB(30, 30, 35), floorMaterial = Enum.Material.Slate,
		wallColor = Color3.fromRGB(45, 45, 50), wallMaterial = Enum.Material.Marble,
		trimColor = Color3.fromRGB(255, 200, 0),
	},
	{
		name = "DIAMOND", lamps = 6,
		floorColor = Color3.fromRGB(200, 235, 255), floorMaterial = Enum.Material.Marble,
		wallColor = Color3.fromRGB(235, 248, 255), wallMaterial = Enum.Material.Glass,
		trimColor = Color3.fromRGB(150, 240, 255),
	},
}

-- Bots : faux joueurs qui jouent tout seuls dans les garages libres
Config.BotsEnabled = true
Config.BotsOnlyInStudio = true -- true = seulement quand tu testes dans Studio
Config.BotCount = 3
Config.BotTradeCooldown = 120 -- secondes minimum entre deux ventes d'un même bot
-- Personnalités : smartness = chance de faire le meilleur choix,
-- patience = secondes qu'il accepte d'attendre pour économiser, trading = envie de vendre au marché
Config.BotPersonalities = {
	{ name = "Saver", smartness = 0.95, patience = 90, trading = 0.03, steal = 0.02, lock = 0.25 },
	{ name = "Trader", smartness = 0.8, patience = 45, trading = 0.25, steal = 0.06, lock = 0.12 },
	{ name = "Rusher", smartness = 0.6, patience = 10, trading = 0.08, steal = 0.15, lock = 0.05 },
}

-- Marché de voitures (centre de la carte)
Config.MarketSlots = 8 -- nombre d'emplacements de vente
Config.MarketDuration = 180 -- secondes avant qu'une voiture invendue revienne
Config.MarketBuyerPrice = 0.8 -- l'acheteur paie 80 % du prix boutique (une bonne affaire)
Config.MarketSellerBonus = 1.5 -- le vendeur touche 150 % du prix boutique

-- Nombre max de pièces sur un tapis en même temps (limite le lag)
Config.MaxDropsPerPlot = 20

-- Vitesse du tapis roulant (studs par seconde)
Config.ConveyorSpeed = 8
-- Durée de vie d'une pièce avant d'être supprimée (évite les bugs si elle tombe)
Config.DropLifetime = 20

-- Sauvegarde (DataStore). Si tu changes le nom, tout le monde repart de zéro.
Config.SaveEnabled = true
Config.DataStoreName = "GarageTycoon_v1"
Config.AutosaveInterval = 120

-- Game Pass "Argent x2" : mets ici l'ID de ton Game Pass (voir README).
-- 0 = désactivé (le bouton doré n'apparaît pas).
Config.CashX2GamePassId = 0
Config.GamePassPad = Vector3.new(-10, 0, 30)

-- ============================================================
-- RARETÉS : plus c'est rare, moins ça apparaît sur le tapis (weight = chance)
-- ============================================================
Config.Rarities = {
	{ id = "common", name = "COMMON", color = Color3.fromRGB(200, 200, 200), weight = 50 },
	{ id = "rare", name = "RARE", color = Color3.fromRGB(70, 150, 255), weight = 25 },
	{ id = "epic", name = "EPIC", color = Color3.fromRGB(180, 80, 255), weight = 13 },
	{ id = "legendary", name = "LEGENDARY", color = Color3.fromRGB(255, 190, 0), weight = 7, announce = true },
	{ id = "mythic", name = "MYTHIC", color = Color3.fromRGB(255, 50, 80), weight = 4, announce = true },
	{ id = "extreme", name = "EXTREME LEGENDARY", color = Color3.fromRGB(0, 255, 220), weight = 1,
		announce = true, sparkles = true },
}

-- ============================================================
-- VOITURES : 2 par rareté. "model" = nom du modèle dans ServerStorage > Assets
-- (s'il manque, une voiture simple de la couleur indiquée est utilisée)
-- ============================================================
Config.Cars = {
	{ id = "hatch", name = "City Hatch", rarity = "common", model = "Common1", style = "coupe",
		price = 500, income = 4, color = Color3.fromRGB(150, 160, 170) },
	{ id = "compact", name = "Compact Cruiser", rarity = "common", model = "Common2", style = "coupe",
		price = 800, income = 6, color = Color3.fromRGB(120, 170, 120) },
	{ id = "coupe", name = "Sport Coupe", rarity = "rare", model = "SportCar", style = "coupe",
		price = 3000, income = 20, color = Color3.fromRGB(20, 60, 160) },
	{ id = "muscle", name = "Muscle Car", rarity = "rare", model = "SportCar2", style = "coupe",
		price = 4500, income = 28, color = Color3.fromRGB(240, 240, 240) },
	{ id = "track", name = "Track Racer", rarity = "epic", model = "SportCar3", style = "super",
		price = 15000, income = 80, color = Color3.fromRGB(20, 20, 25) },
	{ id = "rally", name = "Rally Beast", rarity = "epic", model = "Epic2", style = "super",
		price = 22000, income = 110, color = Color3.fromRGB(240, 120, 30) },
	{ id = "supercar", name = "Supercar", rarity = "legendary", model = "Supercar", style = "super",
		price = 60000, income = 250, color = Color3.fromRGB(230, 30, 30) },
	{ id = "gt", name = "Grand Tourer", rarity = "legendary", model = "Legendary2", style = "super",
		price = 80000, income = 330, color = Color3.fromRGB(30, 120, 80) },
	{ id = "hyper", name = "Hypercar", rarity = "mythic", model = "Supercar2", style = "super",
		price = 250000, income = 900, color = Color3.fromRGB(255, 190, 0) },
	{ id = "concept", name = "Concept X", rarity = "mythic", model = "Mythic2", style = "super",
		price = 350000, income = 1200, color = Color3.fromRGB(240, 240, 255) },
	{ id = "phantom", name = "Phantom Zero", rarity = "extreme", model = "Extreme1", style = "super",
		price = 1500000, income = 5000, color = Color3.fromRGB(10, 10, 15) },
	{ id = "neon", name = "Neon Ghost", rarity = "extreme", model = "Extreme2", style = "super",
		price = 2500000, income = 8000, color = Color3.fromRGB(0, 255, 220) },
}

-- ============================================================
-- VOITURES AUTOMATIQUES : toutes les voitures rangées dans ServerStorage > Assets
-- (sauf les pièces du tapis) reçoivent une rareté selon leur niveau de détail :
-- les plus détaillées (souvent les plus belles) sont les plus rares.
-- La liste Config.Cars ci-dessus ne sert alors qu'en secours (aucune voiture dans Assets).
-- ============================================================
Config.AutoCars = true
Config.DropModelNames = { "Bolt", "Tire", "Engine", "Panel", "Rim" } -- pas des voitures

-- Répartition : 20 % Common, 20 % Rare, 20 % Epic, 22 % Legendary (les très détaillées),
-- 12 % Mythic, 6 % Extreme (seulement les plus détaillées de toutes)
Config.AutoRarityShares = { 0.20, 0.20, 0.20, 0.22, 0.12, 0.06 }

-- Prix et gain de départ de chaque rareté (dans une même rareté, la plus belle coûte jusqu'à +60 %)
Config.RarityPricing = {
	common = { price = 500, income = 4 },
	rare = { price = 3000, income = 20 },
	epic = { price = 15000, income = 80 },
	legendary = { price = 60000, income = 250 },
	mythic = { price = 250000, income = 900 },
	extreme = { price = 1500000, income = 5000 },
}

-- Noms affichés (inventés, sans marque) tirés dans ces listes selon la rareté
Config.CarNames = {
	common = { "City Hatch", "Compact Cruiser", "Urban Mini", "Daily Driver", "Family Wagon", "Pocket Coupe" },
	rare = { "Sport Coupe", "Muscle Car", "Street Racer", "Turbo Hatch", "Drift King", "Road Runner" },
	epic = { "Track Racer", "Rally Beast", "Night Striker", "Apex GT", "Thunder RS", "Velocity S" },
	legendary = { "Supercar", "Grand Tourer", "Vortex V12", "Stallion GT", "Falcon R", "Monarch S" },
	mythic = { "Hypercar", "Concept X", "Aurora Zero", "Titan Hyper", "Eclipse R", "Valkyr" },
	extreme = { "Phantom Zero", "Neon Ghost", "Omega Prime", "Celestia", "Quantum X", "Inferno" },
}

-- Corrections à la main : nom du modèle dans Assets -> rareté et/ou nom affiché.
-- Exemple : ["MaVoiture"] = { rarity = "mythic", name = "Bavaria M5" },
Config.CarOverrides = {
}

-- Retire automatiquement les logos des modèles de voitures (autocollants et pièces
-- nommées Logo, Badge, Emblem...). Les logos dessinés directement dans la carrosserie restent.
Config.RemoveLogos = true

-- Places de parking du garage (requires = objet de la boutique qui la débloque)
Config.CarSlots = {
	{ position = Vector3.new(28, 0, 26) },
	{ position = Vector3.new(28, 0, 12) },
	{ position = Vector3.new(28, 0, -2) },
	{ position = Vector3.new(28, 0, -16), requires = "parking" },
	{ position = Vector3.new(28, 0, -30), requires = "parking" },
	{ position = Vector3.new(28, 16, 26), requires = "floor2" },
	{ position = Vector3.new(28, 16, 12), requires = "floor2" },
	{ position = Vector3.new(28, 16, -2), requires = "floor2" },
	{ position = Vector3.new(28, 16, -16), requires = "floor2" },
	{ position = Vector3.new(28, 16, -30), requires = "floor2" },
}

-- Tapis de livraison (anneau autour du marché) : une nouvelle voiture toutes les X secondes
Config.DeliveryInterval = 3
Config.DeliveryLoopTime = 50 -- secondes pour faire le tour (après, la voiture repart)
Config.DeliveryRadius = 44
Config.DeliveryMaxCars = 14
Config.DeliveryPrefill = 8 -- voitures déjà présentes au lancement (dont une Legendary)

-- Vol de voitures
Config.StealHoldTime = 2.5 -- secondes à maintenir E pour voler
Config.CarryWalkSpeed = 10 -- vitesse du voleur qui porte une voiture (normal = 16)
Config.CarryTimeout = 90 -- secondes max pour ramener la voiture, sinon elle revient
Config.LockDuration = 60 -- durée du bouclier du garage
Config.LockCooldown = 30 -- attente avant de pouvoir le réactiver

-- Vente rapide d'une voiture de son garage (touche F) : % du prix récupéré
Config.QuickSellRatio = 0.5
-- Au rebirth, on garde les voitures des X premières places
Config.RebirthKeepSlots = 3

-- ============================================================
-- Liste des objets à acheter, dans l'ordre de progression.
--   kind     : "dropper" (fabrique des pièces), "upgrader" (multiplie la valeur),
--              "walls" (décor), "parking" (places en plus), "floor" (étage VIP + 5 places),
--              "perk" (bureau qui donne un bonus permanent)
--   (les voitures ne sont plus dans la boutique : elles arrivent sur le tapis de livraison)
--   requires : l'objet à posséder avant que le bouton apparaisse
--   value    : argent rapporté par pièce (dropper)
--   interval : secondes entre deux pièces (dropper)
--   drop     : forme de la pièce fabriquée : "bolt", "tire", "engine", "panel", "rim"
--   model    : nom du modèle à utiliser s'il est rangé dans ServerStorage > Assets
--   z        : position le long du tapis roulant (dropper / upgrader)
--   choice   : embranchement : les objets avec le même "choice" s'excluent (on n'en prend qu'un)
--   carIncomeBonus / marketBonus : bonus des "perks" (bureaux)
--   button   : position du bouton d'achat dans le garage
-- ============================================================
Config.Items = {
	{
		id = "dropper1", name = "Bolt Workbench", kind = "dropper",
		price = 0, requires = nil,
		value = 4, interval = 2, z = 18, drop = "bolt", model = "Bolt",
		color = Color3.fromRGB(190, 190, 200),
		button = Vector3.new(0, 0, 24),
	},
	{
		id = "dropper2", name = "Tire Station", kind = "dropper",
		price = 25, requires = "dropper1",
		value = 10, interval = 2, z = 10, drop = "tire", model = "Tire",
		color = Color3.fromRGB(40, 40, 40),
		button = Vector3.new(8, 0, 24),
	},
	{
		id = "walls", name = "Garage Walls", kind = "walls",
		price = 75, requires = "dropper2",
		color = Color3.fromRGB(200, 200, 205),
		button = Vector3.new(16, 0, 24),
	},
	{
		id = "paint", name = "Paint Booth (x2 parts)", kind = "upgrader", choice = "early",
		price = 150, requires = "dropper2",
		multiplier = 2, z = -20,
		color = Color3.fromRGB(255, 60, 60),
		button = Vector3.new(0, 0, 16),
	},
	{
		-- Choix 1 : doubler les pièces maintenant, OU miser sur les voitures plus tard
		id = "salesmanager", name = "Sales Manager (+50% car $)", kind = "perk", choice = "early",
		price = 150, requires = "dropper2", carIncomeBonus = 0.5,
		color = Color3.fromRGB(60, 140, 255),
		position = Vector3.new(-35, 0, 30),
		button = Vector3.new(-8, 0, 16),
	},
	{
		id = "dropper3", name = "Engine Bench", kind = "dropper",
		price = 400, requires = "dropper2",
		value = 24, interval = 2, z = 2, drop = "engine", model = "Engine",
		color = Color3.fromRGB(90, 90, 100),
		button = Vector3.new(8, 0, 16),
	},
	{
		id = "dropper4", name = "Body Shop Line", kind = "dropper",
		price = 1200, requires = "dropper3",
		value = 60, interval = 2, z = -6, drop = "panel", model = "Panel",
		color = Color3.fromRGB(30, 90, 200),
		button = Vector3.new(16, 0, 16),
	},
	{
		-- 2 places de parking en plus au rez-de-chaussée
		id = "parking", name = "Extra Parking (+2 cars)", kind = "parking",
		price = 3000, requires = "dropper4",
		color = Color3.fromRGB(255, 255, 255),
		button = Vector3.new(0, 0, 8),
	},
	{
		id = "dropper5", name = "Rim Factory", kind = "dropper",
		price = 8000, requires = "dropper4",
		value = 160, interval = 2, z = -14, drop = "rim", model = "Rim",
		color = Color3.fromRGB(255, 170, 0),
		button = Vector3.new(8, 0, 8),
	},
	{
		id = "polish", name = "Polish Station (x1.5 parts)", kind = "upgrader", choice = "late",
		price = 20000, requires = "dropper5",
		multiplier = 1.5, z = -24,
		color = Color3.fromRGB(80, 220, 255),
		button = Vector3.new(16, 0, 8),
	},
	{
		-- Choix 2 : produire plus, OU mieux vendre au marché
		id = "contacts", name = "Market Contacts (+25% sales)", kind = "perk", choice = "late",
		price = 20000, requires = "dropper5", marketBonus = 0.25,
		color = Color3.fromRGB(255, 140, 40),
		position = Vector3.new(-35, 0, -30),
		button = Vector3.new(-8, 0, 8),
	},
	{
		id = "floor2", name = "VIP Upper Floor", kind = "floor",
		price = 40000, requires = "parking",
		color = Color3.fromRGB(170, 220, 255),
		button = Vector3.new(-8, 0, -8),
	},
}

return Config
