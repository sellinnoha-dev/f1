-- ============================================================
-- Garage Tycoon : réglages du jeu
-- C'est ICI que tu modifies les prix, les gains et les objets.
-- Pas besoin de toucher au script serveur pour équilibrer le jeu.
-- ============================================================

local Config = {}

-- Version du jeu, affichée dans la Sortie au lancement
Config.Version = "14 - panneau de test"

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
	{ name = "Saver", smartness = 0.95, patience = 90, trading = 0.03 },
	{ name = "Trader", smartness = 0.8, patience = 45, trading = 0.25 },
	{ name = "Rusher", smartness = 0.6, patience = 10, trading = 0.08 },
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
-- Liste des objets à acheter, dans l'ordre de progression.
--   kind     : "dropper" (fabrique des pièces), "upgrader" (multiplie la valeur),
--              "walls" (décor), "car" (voiture de showroom), "floor" (étage VIP),
--              "perk" (bureau qui donne un bonus permanent)
--   requires : l'objet à posséder avant que le bouton apparaisse
--   value    : argent rapporté par pièce (dropper)
--   interval : secondes entre deux pièces (dropper)
--   drop     : forme de la pièce fabriquée : "bolt", "tire", "engine", "panel", "rim"
--   model    : nom du modèle à utiliser s'il est rangé dans ServerStorage > Assets
--   z        : position le long du tapis roulant (dropper / upgrader)
--   income   : argent rapporté chaque seconde (voitures du showroom)
--   position : emplacement du podium (Y = 16 pour l'étage VIP)
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
		id = "car1", name = "Showroom: Sport Car", kind = "car", style = "coupe", model = "SportCar",
		price = 3000, requires = "dropper4",
		color = Color3.fromRGB(20, 60, 160),
		position = Vector3.new(28, 0, 26), income = 20,
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
		id = "car2", name = "Showroom: Sport Car 2", kind = "car", style = "coupe", model = "SportCar2",
		price = 12000, requires = "dropper5",
		color = Color3.fromRGB(240, 240, 240),
		position = Vector3.new(28, 0, 12), income = 60,
		button = Vector3.new(0, 0, 0),
	},
	{
		id = "car3", name = "Showroom: Sport Car 3", kind = "car", style = "coupe", model = "SportCar3",
		price = 30000, requires = "car2",
		color = Color3.fromRGB(20, 20, 25),
		position = Vector3.new(28, 0, -2), income = 120,
		button = Vector3.new(8, 0, 0),
	},
	{
		id = "floor2", name = "VIP Upper Floor", kind = "floor",
		price = 40000, requires = "car3",
		color = Color3.fromRGB(170, 220, 255),
		button = Vector3.new(-8, 0, -8),
	},
	{
		id = "car4", name = "Showroom: Supercar", kind = "car", style = "super", model = "Supercar",
		price = 60000, requires = "floor2",
		color = Color3.fromRGB(230, 30, 30),
		position = Vector3.new(28, 16, -16), income = 250,
		button = Vector3.new(16, 0, 0),
	},
	{
		id = "car5", name = "Showroom: Hypercar", kind = "car", style = "super", model = "Supercar2",
		price = 120000, requires = "car4",
		color = Color3.fromRGB(255, 190, 0),
		position = Vector3.new(28, 16, -30), income = 600,
		button = Vector3.new(0, 0, -8),
	},
}

return Config
