-- ============================================================
-- Garage Tycoon : réglages du jeu
-- C'est ICI que tu modifies les prix, les gains et les objets.
-- Pas besoin de toucher au script serveur pour équilibrer le jeu.
-- ============================================================

local Config = {}

-- Argent donné à un nouveau joueur
Config.StartingCash = 0

-- Nombre de garages sur la carte (= nombre max de joueurs par serveur)
Config.PlotCount = 4
-- Distance entre le centre de la carte et chaque garage (en studs)
Config.PlotDistance = 100

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

-- ============================================================
-- Liste des objets à acheter, dans l'ordre de progression.
--   kind     : "dropper" (fabrique des pièces), "upgrader" (multiplie la valeur),
--              "walls" (décor), "car" (voiture de showroom)
--   requires : l'objet à posséder avant que le bouton apparaisse
--   value    : argent rapporté par pièce (dropper)
--   interval : secondes entre deux pièces (dropper)
--   z        : position le long du tapis roulant (dropper / upgrader)
--   button   : position du bouton d'achat dans le garage
-- ============================================================
Config.Items = {
	{
		id = "dropper1", name = "Bolt Workbench", kind = "dropper",
		price = 0, requires = nil,
		value = 1, interval = 2, z = 18,
		color = Color3.fromRGB(160, 160, 170),
		button = Vector3.new(0, 0, 24),
	},
	{
		id = "dropper2", name = "Tire Station", kind = "dropper",
		price = 60, requires = "dropper1",
		value = 3, interval = 2, z = 10,
		color = Color3.fromRGB(40, 40, 40),
		button = Vector3.new(8, 0, 24),
	},
	{
		id = "walls", name = "Garage Walls", kind = "walls",
		price = 150, requires = "dropper2",
		color = Color3.fromRGB(200, 200, 205),
		button = Vector3.new(16, 0, 24),
	},
	{
		id = "paint", name = "Paint Booth (x2)", kind = "upgrader",
		price = 300, requires = "dropper2",
		multiplier = 2, z = -20,
		color = Color3.fromRGB(255, 60, 60),
		button = Vector3.new(0, 0, 16),
	},
	{
		id = "dropper3", name = "Engine Bench", kind = "dropper",
		price = 750, requires = "paint",
		value = 8, interval = 2, z = 2,
		color = Color3.fromRGB(90, 90, 100),
		button = Vector3.new(8, 0, 16),
	},
	{
		id = "dropper4", name = "Body Shop Line", kind = "dropper",
		price = 2000, requires = "dropper3",
		value = 20, interval = 2, z = -6,
		color = Color3.fromRGB(30, 90, 200),
		button = Vector3.new(16, 0, 16),
	},
	{
		id = "car1", name = "Showroom: Sport Coupe", kind = "car", style = "coupe",
		price = 4500, requires = "dropper4",
		color = Color3.fromRGB(20, 60, 160),
		position = Vector3.new(24, 0, -10),
		button = Vector3.new(0, 0, 8),
	},
	{
		id = "dropper5", name = "Assembly Robot", kind = "dropper",
		price = 9000, requires = "dropper4",
		value = 50, interval = 1.5, z = -14,
		color = Color3.fromRGB(255, 170, 0),
		button = Vector3.new(8, 0, 8),
	},
	{
		id = "polish", name = "Polish Station (x1.5)", kind = "upgrader",
		price = 20000, requires = "dropper5",
		multiplier = 1.5, z = -24,
		color = Color3.fromRGB(80, 220, 255),
		button = Vector3.new(16, 0, 8),
	},
	{
		id = "car2", name = "Showroom: Supercar", kind = "car", style = "super",
		price = 50000, requires = "polish",
		color = Color3.fromRGB(230, 30, 30),
		position = Vector3.new(24, 0, -27),
		button = Vector3.new(0, 0, 0),
	},
}

return Config
