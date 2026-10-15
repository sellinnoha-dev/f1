-- ============================================================
-- Garage Tycoon : script serveur principal
-- Construit les garages, fait tourner les machines, gère l'argent,
-- les achats, la sauvegarde et le Game Pass.
-- Les réglages (prix, gains...) sont dans ReplicatedStorage > Config.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local formatMoney = require(ReplicatedStorage:WaitForChild("FormatMoney"))
print("[Tycoon] Garage Tycoon version " .. tostring(Config.Version))

-- On fait apparaître les persos nous-mêmes, directement dans leur garage
Players.CharacterAutoLoads = false

-- Couleurs utilisées partout
local COLOR_FLOOR = Color3.fromRGB(70, 70, 75)
local COLOR_DARK = Color3.fromRGB(35, 35, 40)
local COLOR_BUTTON = Color3.fromRGB(0, 200, 90)
local COLOR_BUTTON_DENIED = Color3.fromRGB(220, 40, 40)
local COLOR_GOLD = Color3.fromRGB(255, 200, 0)
local COLOR_REBIRTH = Color3.fromRGB(170, 70, 255)

-- Accès rapide à un objet par son id : itemsById["paint"]
local itemsById = {}
for _, item in ipairs(Config.Items) do
	itemsById[item.id] = item
end

-- La DataStore peut échouer (jeu pas encore publié, accès API désactivé dans Studio).
-- Dans ce cas on joue sans sauvegarde au lieu de planter.
local dataStore = nil
if Config.SaveEnabled then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		dataStore = result
	else
		warn("[Tycoon] Sauvegarde désactivée :", result)
	end
end

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Tycoons"
plotsFolder.Parent = workspace

local plots = {}      -- la liste des garages
local playerData = {} -- [player] = { owned = {}, cash = n, loaded = bool, plot = garage }

-- ============================================================
-- Petits outils
-- ============================================================

-- Crée une pièce ancrée avec les propriétés données, puis la place dans parent
local function makePart(parent, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = parent
	return part
end

-- Position dans le repère du garage : (0, 0, 0) = centre du sol du garage
local function at(plot, x, y, z)
	return plot.cframe * CFrame.new(x, y, z)
end

-- Texte flottant au-dessus d'une pièce
-- Texte flottant au-dessus d'une pièce : un titre blanc et, en option, une ligne dorée.
-- La taille est en studs : le texte rapetisse avec la distance, comme un vrai panneau,
-- donc les textes lointains ne se chevauchent plus.
local function createBillboard(part, title, subtitle, offsetY, width)
	width = width or 7
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(width, 0, subtitle and 2.6 or 1.4, 0)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = part

	local function addLabel(text, posY, height, color)
		local label = Instance.new("TextLabel")
		label.Position = UDim2.fromScale(0, posY)
		label.Size = UDim2.fromScale(1, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.Text = text
		label.Parent = gui
		return label
	end

	if subtitle then
		addLabel(title, 0, 0.5, Color3.new(1, 1, 1))
		addLabel(subtitle, 0.52, 0.48, COLOR_GOLD)
	else
		addLabel(title, 0, 1, Color3.new(1, 1, 1))
	end
	return gui
end

local function getCash(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function getRebirths(player)
	local stats = player:FindFirstChild("leaderstats")
	local rebirths = stats and stats:FindFirstChild("Rebirths")
	return rebirths and rebirths.Value or 0
end

-- Nom affiché d'un propriétaire (joueur ou bot)
local function displayName(owner)
	return owner:IsA("Player") and owner.DisplayName or owner.Name
end

-- Messages en bas à droite de l'écran du joueur (ignorés pour les bots)
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = ReplicatedStorage

local function notify(owner, text)
	if owner and owner:IsA("Player") then
		notifyEvent:FireClient(owner, text)
	end
end

-- Niveau du garage selon le nombre de rebirths (Standard, Bronze, Argent...)
local function getTier(owner)
	local index = math.min((owner and getRebirths(owner) or 0) + 1, #Config.GarageTiers)
	return Config.GarageTiers[index], index
end

-- Multiplicateur total d'argent : Game Pass x2 et bonus de rebirth
local function getMultiplier(player)
	return (player:GetAttribute("CashMultiplier") or 1) * (1 + Config.RebirthBonus * getRebirths(player))
end

-- ============================================================
-- Les pièces qui roulent sur le tapis
-- ============================================================

-- ============================================================
-- Modèles de la Boîte à outils (optionnels)
-- Range tes modèles dans ServerStorage > Assets, avec les noms indiqués
-- dans Config ("model = ..."). S'ils n'y sont pas, on garde les formes simples.
-- ============================================================

local function getAsset(name)
	local folder = ServerStorage:FindFirstChild("Assets")
	return name and folder and folder:FindFirstChild(name)
end

-- Copie un modèle sans ses scripts (sécurité) ni ses sons, et le met à la bonne taille
local function cloneAsset(asset, targetSize)
	local clone = asset:Clone()
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	if clone:IsA("BasePart") then
		local biggest = math.max(clone.Size.X, clone.Size.Y, clone.Size.Z)
		clone.Size *= targetSize / biggest
	elseif clone:IsA("Model") then
		local _, size = clone:GetBoundingBox()
		local biggest = math.max(size.X, size.Y, size.Z)
		clone:ScaleTo(clone:GetScale() * targetSize / biggest)
	else
		clone:Destroy()
		return nil
	end
	return clone
end

local function getParts(object)
	if object:IsA("BasePart") then
		return { object }
	end
	local parts = {}
	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Retrouve la pièce (ou le modèle) qui porte la valeur à partir de la partie touchée
local function getDrop(hit)
	local current = hit
	while current and current ~= workspace do
		if current:GetAttribute("Value") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Forme des pièces auto qui sortent des machines (voir "drop" dans Config)
local DROP_SHAPES = {
	bolt = { size = Vector3.new(1.4, 0.7, 0.7), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal },
	tire = { size = Vector3.new(0.9, 2, 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Rubber, flat = true },
	engine = { size = Vector3.new(1.8, 1.4, 1.6), shape = Enum.PartType.Block, material = Enum.Material.Metal },
	panel = { size = Vector3.new(2.2, 0.5, 1.6), shape = Enum.PartType.Block, material = Enum.Material.SmoothPlastic },
	rim = { size = Vector3.new(0.6, 2, 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Foil, flat = true },
}

-- Crée une pièce à partir d'un modèle de la Boîte à outils, soudé en un seul bloc
-- Pièce à partir d'un modèle de la Boîte à outils.
-- Pour éviter le lag, la physique est gérée par une simple boîte invisible ;
-- le modèle n'est qu'un "habillage" soudé dessus, sans collisions.
local function makeDropFromAsset(asset, look, spawnCFrame)
	local clone = cloneAsset(asset, math.max(look.size.X, look.size.Y, look.size.Z) * 1.4)
	if not clone then
		return nil, nil
	end
	local parts = getParts(clone)
	if #parts == 0 then
		clone:Destroy()
		return nil, nil
	end

	local drop = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Hitbox"
	root.Size = look.size
	root.Transparency = 1
	root.CFrame = spawnCFrame
	root.Parent = drop
	drop.PrimaryPart = root

	-- Centre l'habillage sur la boîte
	local box = clone:IsA("Model") and clone:GetBoundingBox() or clone.CFrame
	clone:PivotTo(clone:GetPivot() + (spawnCFrame.Position - box.Position))
	for _, part in ipairs(parts) do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root
	end
	clone.Parent = drop
	return drop, root
end

local function spawnDrop(plot, item)
	local look = DROP_SHAPES[item.drop] or DROP_SHAPES.bolt
	local spawnCFrame = at(plot, -25, 5, item.z)
	local drop, root

	-- Trop de pièces sur le tapis : on attend qu'il se vide (évite le lag)
	if #plot.drops:GetChildren() >= Config.MaxDropsPerPlot then
		return
	end

	local asset = getAsset(item.model)
	if asset then
		drop, root = makeDropFromAsset(asset, look, spawnCFrame)
	end
	if not drop then
		drop = Instance.new("Part")
		drop.Shape = look.shape
		drop.Size = look.size
		drop.Color = item.color
		drop.Material = look.material
		drop.CFrame = spawnCFrame
		if look.flat then
			-- Pneus et jantes posés à plat sur le tapis
			drop.CFrame *= CFrame.Angles(0, 0, math.rad(90))
		end
		drop:SetAttribute("Tintable", true)
		root = drop
	end

	drop.Name = "Drop"
	drop:SetAttribute("Value", item.value)
	drop:SetAttribute("Plot", plot.index)
	drop.Parent = plot.drops
	-- Le serveur gère la physique : un tricheur ne peut pas déplacer les pièces
	root:SetNetworkOwner(nil)
	Debris:AddItem(drop, Config.DropLifetime)
end

-- Une pièce touche le collecteur : on la vend
local function onCollect(plot, hit)
	local drop = getDrop(hit)
	local value = drop and drop:GetAttribute("Value")
	if not value or drop:GetAttribute("Plot") ~= plot.index then
		return
	end
	drop:SetAttribute("Plot", nil) -- empêche de compter la même pièce deux fois
	drop:Destroy()

	local owner = plot.owner
	local cash = owner and getCash(owner)
	if cash then
		local multiplier = getMultiplier(owner)
		cash.Value += math.floor(value * multiplier + 0.5)
	end
end

-- ============================================================
-- Construction des objets achetés
-- ============================================================

local function buildDropper(plot, item, model)
	makePart(model, {
		Name = "Pillar", Size = Vector3.new(1, 8, 1), CFrame = at(plot, -28, 4, item.z),
		Color = COLOR_DARK, Material = Enum.Material.Metal,
	})
	local head = makePart(model, {
		Name = "Head", Size = Vector3.new(6, 3, 4), CFrame = at(plot, -25.5, 7.5, item.z),
		Color = item.color, Material = Enum.Material.Metal,
	})
	createBillboard(head, item.name, "+$" .. formatMoney(item.value), 3.2, 6)

	-- Boucle de production : s'arrête toute seule quand la machine est détruite
	task.spawn(function()
		while model.Parent do
			task.wait(item.interval)
			if not model.Parent then
				break
			end
			spawnDrop(plot, item)
		end
	end)
end

local function buildUpgrader(plot, item, model)
	for _, x in ipairs({ -27.75, -22.25 }) do
		makePart(model, {
			Name = "Post", Size = Vector3.new(0.5, 5, 0.5), CFrame = at(plot, x, 2.5, item.z),
			Color = COLOR_DARK, Material = Enum.Material.Metal,
		})
	end
	makePart(model, {
		Name = "Top", Size = Vector3.new(6, 0.5, 0.5), CFrame = at(plot, -25, 5.25, item.z),
		Color = COLOR_DARK, Material = Enum.Material.Metal,
	})
	local gate = makePart(model, {
		Name = "Gate", Size = Vector3.new(5, 4, 0.4), CFrame = at(plot, -25, 2.5, item.z),
		Color = item.color, Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false,
	})
	createBillboard(gate, item.name, nil, 3.6, 6)

	local tag = "Upgraded_" .. item.id
	gate.Touched:Connect(function(hit)
		local drop = getDrop(hit)
		local value = drop and drop:GetAttribute("Value")
		if not value or drop:GetAttribute("Plot") ~= plot.index or drop:GetAttribute(tag) then
			return
		end
		drop:SetAttribute(tag, true)
		drop:SetAttribute("Value", value * item.multiplier)
		if drop:GetAttribute("Tintable") then
			drop.Color = item.color -- la pièce prend la couleur de la machine
		end
	end)
end

local function buildWalls(plot, item, model)
	local walls = {
		{ Vector3.new(80, 16, 1), Vector3.new(0, 8, -40) }, -- fond
		{ Vector3.new(1, 16, 80), Vector3.new(-40, 8, 0) }, -- gauche
		{ Vector3.new(1, 16, 80), Vector3.new(40, 8, 0) },  -- droite
	}
	local tier = getTier(plot.owner)
	for _, wall in ipairs(walls) do
		local size, pos = wall[1], wall[2]
		makePart(model, {
			Name = "Wall", Size = size, CFrame = at(plot, pos.X, pos.Y, pos.Z),
			Color = tier.wallColor, Material = tier.wallMaterial,
		})
	end
end

-- Prépare une voiture à tourner sur son podium.
-- La rotation est faite par chaque joueur (script CarSpinner) : le serveur ne déplace rien,
-- donc pas de lag réseau, même avec des voitures de centaines de pièces.
local function spinOnPodium(car, base)
	local parts = getParts(car)
	if #parts == 0 then
		return
	end
	-- La plus grosse pièce sert d'axe, toutes les autres lui sont soudées
	local root = parts[1]
	for _, part in ipairs(parts) do
		if part.Size.Magnitude > root.Size.Magnitude then
			root = part
		end
	end
	for _, part in ipairs(parts) do
		part.CanCollide = false
		part.CanTouch = false
		if part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
		end
	end
	for _, part in ipairs(parts) do
		if part ~= root then
			part.Anchored = false
			part.Massless = true
		end
	end
	root.Anchored = true
	car.PrimaryPart = root
	car:SetAttribute("SpinBase", base)
	CollectionService:AddTag(car, "SpinningCar")
end

-- Place une voiture de la Boîte à outils sur le podium. Renvoie false si impossible.
local function placeAssetCar(item, model, base)
	local asset = getAsset(item.model)
	local clone = asset and cloneAsset(asset, item.style == "super" and 12 or 11)
	if not clone then
		return false
	end
	local car = clone
	if clone:IsA("BasePart") then
		car = Instance.new("Model")
		clone.Parent = car
	end
	for _, part in ipairs(getParts(car)) do
		part.Anchored = true
	end
	-- Le point de pivot devient le dessous de la voiture, pour la poser pile sur le podium
	local box, size = car:GetBoundingBox()
	car.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	car.Name = "Car"
	car.Parent = model
	car:PivotTo(base)
	spinOnPodium(car, base)
	return true
end

-- Pose une voiture (modèle de la Boîte à outils, sinon voiture simple) sur un podium
local function placeCar(item, model, base)
	if placeAssetCar(item, model, base) then
		return
	end

	local car = Instance.new("Model")
	car.Name = "Car"
	car.Parent = model

	local function carPart(name, size, x, y, z, color, material, extra)
		local props = {
			Name = name, Size = size, CFrame = base * CFrame.new(x, y, z),
			Color = color, Material = material,
		}
		for key, value in pairs(extra or {}) do
			props[key] = value
		end
		return makePart(car, props)
	end

	local glass = Color3.fromRGB(20, 25, 35)
	if item.style == "super" then
		carPart("Body", Vector3.new(5.4, 1.2, 11), 0, 1.4, 0, item.color, Enum.Material.SmoothPlastic)
		carPart("Cabin", Vector3.new(4.6, 1.1, 4.5), 0, 2.55, 0.5, glass, Enum.Material.Glass, { Transparency = 0.2 })
		carPart("Spoiler", Vector3.new(5, 0.3, 1.2), 0, 2.9, 5, COLOR_DARK, Enum.Material.SmoothPlastic)
		for _, x in ipairs({ -1.8, 1.8 }) do
			carPart("SpoilerLeg", Vector3.new(0.3, 0.9, 0.3), x, 2.35, 5, COLOR_DARK, Enum.Material.SmoothPlastic)
		end
	else
		carPart("Body", Vector3.new(5, 1.6, 10), 0, 1.6, 0, item.color, Enum.Material.SmoothPlastic)
		carPart("Cabin", Vector3.new(4.4, 1.6, 5), 0, 3.2, 0.5, glass, Enum.Material.Glass, { Transparency = 0.2 })
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		carPart("Headlight", Vector3.new(1, 0.4, 0.2), x, 1.6, -5.1, Color3.new(1, 1, 1), Enum.Material.Neon)
	end
	for _, x in ipairs({ -2.6, 2.6 }) do
		for _, z in ipairs({ -3.2, 3.2 }) do
			carPart("Wheel", Vector3.new(1, 2.4, 2.4), x, 1.2, z, Color3.fromRGB(20, 20, 20),
				Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
		end
	end

	car.WorldPivot = base
	spinOnPodium(car, base)
end

local listCar -- défini plus bas, dans la partie "Marché"

-- Voiture de showroom sur son podium
local function buildCar(plot, item, model)
	local p = item.position -- p.Y = hauteur de l'étage (0 = rez-de-chaussée)
	local podium = makePart(model, {
		Name = "Podium", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 12, 12),
		CFrame = at(plot, p.X, p.Y + 0.5, p.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLOR_DARK, Material = Enum.Material.Marble,
	})
	if item.income then
		createBillboard(podium, item.name, "+$" .. formatMoney(item.income) .. "/s", 7, 9)
	end

	-- Touche E : mettre la voiture en vente au marché
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell at Market"
	prompt.ObjectText = "Get $" .. formatMoney(math.floor(item.price * Config.MarketSellerBonus))
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = podium
	prompt.Triggered:Connect(function(player)
		if player == plot.owner then
			listCar(plot, item)
		end
	end)

	placeCar(item, model, at(plot, p.X, p.Y + 1, p.Z))
end

-- Étage VIP : dalle sur la moitié droite du garage, escalier, rambardes et murs
local FLOOR_Y = 16 -- hauteur du sol de l'étage

local function buildUpperFloor(plot, item, model)
	local function block(name, size, x, y, z, color, material, extra)
		local props = {
			Name = name, Size = size, CFrame = at(plot, x, y, z),
			Color = color, Material = material,
		}
		for key, value in pairs(extra or {}) do
			props[key] = value
		end
		return makePart(model, props)
	end
	local tier = getTier(plot.owner)
	local floorColor = Color3.fromRGB(225, 225, 230)
	local glass = { Transparency = 0.5 }

	-- Dalle de l'étage et palier en haut de l'escalier
	block("UpperFloor", Vector3.new(24, 1, 80), 28, FLOOR_Y - 0.5, 0, floorColor, Enum.Material.Marble)
	block("Landing", Vector3.new(14, 1, 4.5), 9, FLOOR_Y - 0.5, -37.25, floorColor, Enum.Material.Marble)

	-- Escalier contre le mur du fond : 16 marches de 1 stud
	local steps = 16
	local depth = 1.6
	for i = 1, steps do
		local height = FLOOR_Y * i / steps
		block("Step", Vector3.new(6, height, depth), 5, height / 2, -12 - (i - 0.5) * depth,
			COLOR_DARK, Enum.Material.Concrete)
	end

	-- Piliers sous la dalle
	for _, z in ipairs({ 36, 4, -24 }) do
		block("Pillar", Vector3.new(1, FLOOR_Y - 1, 1), 16.5, (FLOOR_Y - 1) / 2, z, COLOR_DARK, Enum.Material.Metal)
	end

	-- Rambardes en verre et murs de l'étage
	block("Railing", Vector3.new(0.4, 3, 75), 16.2, FLOOR_Y + 1.5, 2.5, item.color, Enum.Material.Glass, glass)
	block("Railing", Vector3.new(8, 3, 0.4), 12, FLOOR_Y + 1.5, -35.2, item.color, Enum.Material.Glass, glass)
	block("Railing", Vector3.new(24, 3, 0.4), 28, FLOOR_Y + 1.5, 39.8, item.color, Enum.Material.Glass, glass)
	block("UpperWall", Vector3.new(1, 10, 80), 40, FLOOR_Y + 5, 0, tier.wallColor, tier.wallMaterial)
	block("UpperWall", Vector3.new(38, 10, 1), 21, FLOOR_Y + 5, -40, tier.wallColor, tier.wallMaterial)

	-- Bande lumineuse et panneau
	local strip = block("NeonStrip", Vector3.new(0.3, 0.4, 78), 39.4, FLOOR_Y + 9, 0, tier.trimColor, Enum.Material.Neon)
	createBillboard(strip, "VIP SHOWROOM", nil, 2, 16)
end

local builders = {
	dropper = buildDropper,
	upgrader = buildUpgrader,
	walls = buildWalls,
	car = buildCar,
	floor = buildUpperFloor,
}

local function buildItem(plot, item)
	local model = Instance.new("Model")
	model.Name = item.id
	model.Parent = plot.items
	builders[item.kind](plot, item, model)
end

-- ============================================================
-- Boutons d'achat
-- ============================================================

local refreshButtons -- déclarée ici car createButton en a besoin

-- Pas assez d'argent : le bouton clignote en rouge
local function flashDenied(button)
	if button:GetAttribute("Flashing") then
		return
	end
	local original = button.Color
	button:SetAttribute("Flashing", true)
	button.Color = COLOR_BUTTON_DENIED
	task.delay(0.5, function()
		button.Color = original
		button:SetAttribute("Flashing", nil)
	end)
end

-- Achat d'un objet par le propriétaire du garage (joueur ou bot). Renvoie true si acheté.
local function purchase(plot, owner, item)
	if owner ~= plot.owner or plot.buying then
		return false
	end
	local data = playerData[owner]
	local cash = getCash(owner)
	if not data or not cash or data.owned[item.id] or cash.Value < item.price then
		return false
	end
	plot.buying = true
	cash.Value -= item.price
	data.owned[item.id] = true
	buildItem(plot, item)
	refreshButtons(plot)
	plot.buying = false
	return true
end

local function tryBuy(plot, item, button, hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or player ~= plot.owner then
		return
	end
	local cash = getCash(player)
	if cash and cash.Value < item.price then
		flashDenied(button)
		return
	end
	purchase(plot, player, item)
end

local function createButton(plot, item)
	local pos = item.button
	local button = makePart(plot.model, {
		Name = "Button_" .. item.id, Size = Vector3.new(4, 0.6, 4),
		CFrame = at(plot, pos.X, 0.3, pos.Z), Color = COLOR_BUTTON, Material = Enum.Material.Neon,
	})
	local priceText = item.price == 0 and "FREE" or ("$" .. formatMoney(item.price))
	createBillboard(button, item.name, priceText, 3, 7)
	button.Touched:Connect(function(hit)
		tryBuy(plot, item, button, hit)
	end)
	return button
end

-- ============================================================
-- Rebirth : quand tout est acheté, on recommence à zéro
-- contre un bonus d'argent permanent
-- ============================================================

local function getRebirthCost(player)
	return Config.RebirthCost * (getRebirths(player) + 1)
end

local applyTheme -- défini plus bas : décore le garage selon son niveau

-- Rebirth du propriétaire (joueur ou bot). Renvoie true si effectué.
local function performRebirth(plot, owner)
	if owner ~= plot.owner or plot.buying then
		return false
	end
	local data = playerData[owner]
	local cash = getCash(owner)
	local rebirths = owner.leaderstats:FindFirstChild("Rebirths")
	if not data or not cash or not rebirths or cash.Value < getRebirthCost(owner) then
		return false
	end

	plot.buying = true
	rebirths.Value += 1
	cash.Value = Config.StartingCash
	data.owned = {}
	plot.items:ClearAllChildren()
	plot.drops:ClearAllChildren()
	for _, oldButton in pairs(plot.buttons) do
		oldButton:Destroy()
	end
	plot.buttons = {}
	plot.rebirthButton:Destroy()
	plot.rebirthButton = nil
	applyTheme(plot)
	refreshButtons(plot)
	plot.buying = false
	local tier = getTier(owner)
	notify(owner, "Rebirth! Your garage is now " .. tier.name .. " level!")
	return true
end

local function doRebirth(plot, button, hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or player ~= plot.owner then
		return
	end
	local cash = getCash(player)
	if cash and cash.Value < getRebirthCost(player) then
		flashDenied(button)
		return
	end
	performRebirth(plot, player)
end

local function createRebirthButton(plot)
	local pos = Config.RebirthButton
	local button = makePart(plot.model, {
		Name = "RebirthButton", Size = Vector3.new(5, 0.6, 5),
		CFrame = at(plot, pos.X, 0.3, pos.Z), Color = COLOR_REBIRTH, Material = Enum.Material.Neon,
	})
	local bonus = math.floor(Config.RebirthBonus * 100 + 0.5)
	createBillboard(button, "REBIRTH (+" .. bonus .. "% cash)", "$" .. formatMoney(getRebirthCost(plot.owner)), 3, 9)
	button.Touched:Connect(function(hit)
		doRebirth(plot, button, hit)
	end)
	return button
end

-- Affiche les boutons des objets débloqués et pas encore achetés
function refreshButtons(plot)
	local data = plot.owner and playerData[plot.owner]
	if not data then
		return
	end
	for _, item in ipairs(Config.Items) do
		local visible = not data.owned[item.id] and (item.requires == nil or data.owned[item.requires])
		local button = plot.buttons[item.id]
		if visible and not button then
			plot.buttons[item.id] = createButton(plot, item)
		elseif not visible and button then
			button:Destroy()
			plot.buttons[item.id] = nil
		end
	end

	-- Le bouton de rebirth apparaît quand tout est acheté
	local allOwned = true
	for _, item in ipairs(Config.Items) do
		if not data.owned[item.id] then
			allOwned = false
			break
		end
	end
	if allOwned and not plot.rebirthButton then
		plot.rebirthButton = createRebirthButton(plot)
	elseif not allOwned and plot.rebirthButton then
		plot.rebirthButton:Destroy()
		plot.rebirthButton = nil
	end
end

-- Bouton doré pour acheter le Game Pass "Argent x2"
local function createGamePassPad(plot)
	local owner = plot.owner
	if Config.CashX2GamePassId == 0 or not owner or not owner:IsA("Player") or owner:GetAttribute("CashMultiplier") == 2 then
		return
	end
	local pad = makePart(plot.model, {
		Name = "GamePassPad", Size = Vector3.new(5, 0.6, 5), CFrame = at(plot, Config.GamePassPad.X, 0.3, Config.GamePassPad.Z),
		Color = COLOR_GOLD, Material = Enum.Material.Neon,
	})
	createBillboard(pad, "2x CASH", "Game Pass", 3, 7)

	local cooldown = false
	pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if cooldown or not player or player ~= plot.owner or player:GetAttribute("CashMultiplier") == 2 then
			return
		end
		cooldown = true
		MarketplaceService:PromptGamePassPurchase(player, Config.CashX2GamePassId)
		task.delay(5, function()
			cooldown = false
		end)
	end)
	plot.passPad = pad
end

-- ============================================================
-- Création des garages (vides au démarrage)
-- ============================================================

local function createPlot(index)
	-- Les garages sont répartis en cercle, l'entrée tournée vers le centre
	local angle = (index - 1) * (2 * math.pi / Config.PlotCount)
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.PlotDistance + Vector3.new(0, 1, 0)
	local outward = Vector3.new(position.X, 0, position.Z).Unit

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = plotsFolder

	local plot = {
		index = index,
		cframe = CFrame.lookAt(position, position + outward),
		model = model,
		owner = nil,
		buttons = {},
		buying = false,
	}

	plot.items = Instance.new("Folder")
	plot.items.Name = "Items"
	plot.items.Parent = model
	plot.drops = Instance.new("Folder")
	plot.drops.Name = "Drops"
	plot.drops.Parent = model

	plot.decor = Instance.new("Folder")
	plot.decor.Name = "Decor"
	plot.decor.Parent = model

	plot.floor = makePart(model, {
		Name = "Floor", Size = Vector3.new(80, 1, 80), CFrame = at(plot, 0, -0.5, 0),
		Color = COLOR_FLOOR, Material = Enum.Material.Concrete,
	})

	-- Tapis roulant : une pièce ancrée avec une vitesse pousse ce qui est posé dessus
	local conveyor = makePart(model, {
		Name = "Conveyor", Size = Vector3.new(4, 1, 52), CFrame = at(plot, -25, 0.5, -2),
		Color = Color3.fromRGB(25, 25, 25), Material = Enum.Material.DiamondPlate,
	})
	conveyor.AssemblyLinearVelocity = plot.cframe:VectorToWorldSpace(Vector3.new(0, 0, -Config.ConveyorSpeed))
	for _, x in ipairs({ -27.25, -22.75 }) do
		makePart(model, {
			Name = "Rail", Size = Vector3.new(0.5, 1.5, 52), CFrame = at(plot, x, 1.25, -2),
			Color = COLOR_DARK, Material = Enum.Material.Metal,
		})
	end

	local collector = makePart(model, {
		Name = "Collector", Size = Vector3.new(6, 3, 4), CFrame = at(plot, -25, 1.5, -30),
		Color = Color3.fromRGB(0, 255, 120), Material = Enum.Material.Neon,
	})
	createBillboard(collector, "SELL", nil, 3, 5)
	collector.Touched:Connect(function(hit)
		onCollect(plot, hit)
	end)

	-- Arche d'entrée avec le nom du propriétaire
	for _, x in ipairs({ -15.5, 15.5 }) do
		makePart(model, {
			Name = "SignPost", Size = Vector3.new(1, 14, 1), CFrame = at(plot, x, 7, 40),
			Color = COLOR_DARK, Material = Enum.Material.Metal,
		})
	end
	local sign = makePart(model, {
		Name = "Sign", Size = Vector3.new(32, 5, 1), CFrame = at(plot, 0, 14.5, 40),
		Color = COLOR_DARK, Material = Enum.Material.SmoothPlastic,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back -- face tournée vers le centre de la carte
	surface.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = COLOR_GOLD
	label.Text = "Free Garage"
	label.Parent = surface
	plot.signLabel = label

	-- Route entre le centre de la carte et l'entrée du garage
	makePart(model, {
		Name = "Road", Size = Vector3.new(16, 0.2, 48), CFrame = at(plot, 0, -0.9, 64),
		Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt,
	})
	for z = 44, 84, 8 do
		makePart(model, {
			Name = "RoadLine", Size = Vector3.new(0.6, 0.2, 3), CFrame = at(plot, 0, -0.78, z),
			Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic,
		})
	end

	return plot
end

for i = 1, Config.PlotCount do
	plots[i] = createPlot(i)
end

-- ============================================================
-- Marché de voitures (au centre de la carte)
-- Un joueur y met une de ses voitures ; les autres peuvent l'acheter moins cher
-- qu'en boutique, et le vendeur touche un bonus. Invendue = elle revient.
-- ============================================================

local marketFolder = Instance.new("Folder")
marketFolder.Name = "CarMarket"
marketFolder.Parent = workspace

makePart(marketFolder, {
	Name = "MarketFloor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 64, 64),
	CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt,
})
local marketSign = makePart(marketFolder, {
	Name = "MarketSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 14, 0),
	Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
})
createBillboard(marketSign, "CAR MARKET", "Buy cars from other players!", 0, 26)

local slots = {}

local function setSlotLabel(slot, title, subtitle)
	if slot.label then
		slot.label:Destroy()
	end
	slot.label = createBillboard(slot.podium, title, subtitle, 7, 10)
end

local function buyPrice(item)
	return math.floor(item.price * Config.MarketBuyerPrice)
end

local function clearSlot(slot)
	slot.listing = nil
	slot.display:ClearAllChildren()
	slot.prompt.Enabled = false
	setSlotLabel(slot, "EMPTY SPOT", "Sell a car from your showroom")
end

-- Rend une voiture invendue à son propriétaire
local function returnCar(slot)
	local listing = slot.listing
	clearSlot(slot)
	local seller, item = listing.seller, listing.item
	local data = playerData[seller]
	if not data then
		return
	end
	if data.owned[item.id] then
		-- Il l'a rachetée entre-temps : on le rembourse
		local cash = getCash(seller)
		if cash then
			cash.Value += item.price
		end
	elseif data.plot then
		data.owned[item.id] = true
		buildItem(data.plot, item)
		refreshButtons(data.plot)
	end
	notify(seller, item.name .. " was not sold and is back in your garage.")
end

local function buyCar(slot, buyer)
	local listing = slot.listing
	if not listing then
		return
	end
	local item, seller = listing.item, listing.seller
	if buyer == seller then
		returnCar(slot) -- le vendeur retire sa voiture
		return
	end
	local data = playerData[buyer]
	local cash = getCash(buyer)
	if not data or not data.plot or not cash then
		return
	end
	if data.owned[item.id] then
		notify(buyer, "You already own this car!")
		return
	end
	if item.requires and not data.owned[item.requires] then
		notify(buyer, "Unlock " .. itemsById[item.requires].name .. " first!")
		return
	end
	local price = buyPrice(item)
	if cash.Value < price then
		notify(buyer, "Not enough cash! You need $" .. formatMoney(price))
		return
	end

	cash.Value -= price
	data.owned[item.id] = true
	buildItem(data.plot, item)
	refreshButtons(data.plot)
	clearSlot(slot)
	notify(buyer, "You bought " .. item.name .. "!")

	local sellerCash = playerData[seller] and getCash(seller)
	if sellerCash then
		local earned = math.floor(item.price * Config.MarketSellerBonus)
		sellerCash.Value += earned
		notify(seller, displayName(buyer) .. " bought your " .. item.name .. "! +$" .. formatMoney(earned))
	end
end

for i = 1, Config.MarketSlots do
	local angle = (i - 0.5) * (2 * math.pi / Config.MarketSlots)
	local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 22
	local podium = makePart(marketFolder, {
		Name = "MarketSlot" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 12, 12),
		CFrame = CFrame.new(position + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLOR_DARK, Material = Enum.Material.Marble,
	})
	makePart(marketFolder, {
		Name = "SlotRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 13, 13),
		CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLOR_GOLD, Material = Enum.Material.Neon,
	})
	local display = Instance.new("Model")
	display.Name = "Display"
	display.Parent = marketFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = podium

	local slot = {
		podium = podium,
		display = display,
		prompt = prompt,
		base = CFrame.lookAt(position + Vector3.new(0, 1.3, 0), Vector3.zero + Vector3.new(0, 1.3, 0)),
	}
	prompt.Triggered:Connect(function(player)
		buyCar(slot, player)
	end)
	clearSlot(slot)
	slots[i] = slot
end

-- Met une voiture du showroom en vente au marché
function listCar(plot, item)
	local seller = plot.owner
	local data = seller and playerData[seller]
	if not data or not data.owned[item.id] then
		return
	end
	local freeSlot = nil
	for _, slot in ipairs(slots) do
		if not slot.listing then
			freeSlot = slot
			break
		end
	end
	if not freeSlot then
		notify(seller, "The market is full, try again later!")
		return
	end

	-- La voiture quitte le showroom du vendeur
	data.owned[item.id] = nil
	local carModel = plot.items:FindFirstChild(item.id)
	if carModel then
		carModel:Destroy()
	end
	refreshButtons(plot)

	freeSlot.listing = { seller = seller, item = item, expires = os.clock() + Config.MarketDuration }
	placeCar(item, freeSlot.display, freeSlot.base)
	freeSlot.prompt.ActionText = "Buy for $" .. formatMoney(buyPrice(item))
	freeSlot.prompt.ObjectText = item.name .. " (seller: " .. displayName(seller) .. ")"
	freeSlot.prompt.Enabled = true
	setSlotLabel(freeSlot, item.name, "$" .. formatMoney(buyPrice(item)) .. "  ·  " .. displayName(seller))
	local minutes = math.floor(Config.MarketDuration / 60 + 0.5)
	notify(seller, item.name .. " is on the market for " .. minutes .. " min. Sold = +$"
		.. formatMoney(math.floor(item.price * Config.MarketSellerBonus)) .. "!")
end

-- Annonces expirées : la voiture revient chez le vendeur
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, slot in ipairs(slots) do
			if slot.listing and now >= slot.listing.expires then
				returnCar(slot)
			end
		end
	end
end)

-- Le vendeur quitte le jeu : ses voitures en vente lui sont rendues (avant la sauvegarde)
local function cancelListings(player)
	local data = playerData[player]
	for _, slot in ipairs(slots) do
		if slot.listing and slot.listing.seller == player then
			if data then
				data.owned[slot.listing.item.id] = true
			end
			clearSlot(slot)
		end
	end
end

-- ============================================================
-- Niveau du garage : plus de rebirths = garage plus luxueux et plus grand
-- ============================================================

function applyTheme(plot)
	local tier, level = getTier(plot.owner)
	plot.floor.Color = tier.floorColor
	plot.floor.Material = tier.floorMaterial
	plot.signLabel.TextColor3 = tier.trimColor
	plot.decor:ClearAllChildren()

	local function deco(name, size, x, y, z, color, material, extra)
		local props = {
			Name = name, Size = size, CFrame = at(plot, x, y, z),
			Color = color, Material = material,
		}
		for key, value in pairs(extra or {}) do
			props[key] = value
		end
		return makePart(plot.decor, props)
	end

	-- Les murs déjà construits prennent la couleur du niveau
	for _, part in ipairs(plot.items:GetDescendants()) do
		if part:IsA("BasePart") and (part.Name == "Wall" or part.Name == "UpperWall") then
			part.Color = tier.wallColor
			part.Material = tier.wallMaterial
		end
	end

	if level >= 2 then
		-- Néons au sol tout autour du garage
		local trim = { Material = Enum.Material.Neon }
		deco("Trim", Vector3.new(80, 0.1, 0.4), 0, 0.05, -39.6, tier.trimColor, Enum.Material.Neon, trim)
		deco("Trim", Vector3.new(0.4, 0.1, 80), -39.6, 0.05, 0, tier.trimColor, Enum.Material.Neon, trim)
		deco("Trim", Vector3.new(0.4, 0.1, 80), 39.6, 0.05, 0, tier.trimColor, Enum.Material.Neon, trim)

		-- Façade derrière le garage : elle monte à chaque niveau, le bâtiment paraît plus grand
		local height = 16 + level * 8
		deco("Facade", Vector3.new(84, height, 2), 0, height / 2, -42, tier.wallColor, tier.wallMaterial)
		local crown = deco("FacadeCrown", Vector3.new(84, 1, 2.4), 0, height + 0.5, -42, tier.trimColor, Enum.Material.Neon)
		createBillboard(crown, tier.name .. " GARAGE", nil, 4, 40)
	end

	-- Lampadaires de chaque côté de l'entrée (plus nombreux à chaque niveau)
	local lampSpots = { { -22, 38 }, { 22, 38 }, { -38, 20 }, { 38, 20 }, { -38, -10 }, { 38, -10 } }
	for i = 1, math.min(tier.lamps, #lampSpots) do
		local spot = lampSpots[i]
		deco("LampPole", Vector3.new(0.6, 12, 0.6), spot[1], 6, spot[2], COLOR_DARK, Enum.Material.Metal)
		local bulb = deco("LampBulb", Vector3.new(1.6, 1.6, 1.6), spot[1], 12.5, spot[2], tier.trimColor,
			Enum.Material.Neon, { Shape = Enum.PartType.Ball })
		local light = Instance.new("PointLight")
		light.Color = tier.trimColor
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = bulb
	end

	if level >= 3 then
		-- Plantes à l'entrée
		for _, x in ipairs({ -12, 12 }) do
			deco("Pot", Vector3.new(2.5, 2, 2.5), x, 1, 36, Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
			deco("Plant", Vector3.new(4, 4, 4), x, 4, 36, Color3.fromRGB(40, 140, 60), Enum.Material.Grass,
				{ Shape = Enum.PartType.Ball })
		end
	end

	if level >= 4 then
		-- Tapis rouge de l'entrée
		deco("RedCarpet", Vector3.new(6, 0.1, 30), 0, 0.06, 25, Color3.fromRGB(170, 20, 30), Enum.Material.Fabric)
	end

	if level >= 5 then
		-- Paillettes sur l'enseigne
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = tier.trimColor
		sparkles.Parent = plot.decor:FindFirstChild("FacadeCrown")
	end
end

local function getFreePlot()
	for _, plot in ipairs(plots) do
		if not plot.owner then
			return plot
		end
	end
	return nil
end

local function assignPlot(plot, player)
	local data = playerData[player]
	plot.owner = player
	data.plot = plot
	plot.signLabel.Text = displayName(player) .. "'s Garage"

	-- Reconstruit tout ce que le joueur avait acheté (sauvegarde)
	for _, item in ipairs(Config.Items) do
		if data.owned[item.id] then
			buildItem(plot, item)
		end
	end
	applyTheme(plot)
	refreshButtons(plot)
	createGamePassPad(plot)
end

local function releasePlot(plot)
	plot.owner = nil
	plot.items:ClearAllChildren()
	plot.drops:ClearAllChildren()
	for _, button in pairs(plot.buttons) do
		button:Destroy()
	end
	plot.buttons = {}
	if plot.passPad then
		plot.passPad:Destroy()
		plot.passPad = nil
	end
	if plot.rebirthButton then
		plot.rebirthButton:Destroy()
		plot.rebirthButton = nil
	end
	plot.signLabel.Text = "Free Garage"
	applyTheme(plot)
end

-- Fait (ré)apparaître le perso dans son garage
local function spawnPlayer(player)
	if not player.Parent then
		return
	end
	player:LoadCharacter() -- attend que le perso soit chargé
	local data = playerData[player]
	local character = player.Character
	if character and data and data.plot then
		character:PivotTo(at(data.plot, 0, 4, 30))
	end
end

-- ============================================================
-- Sauvegarde
-- ============================================================

local function loadData(player)
	local startingCash = Config.StartingCash
	if RunService:IsStudio() and Config.StudioTestCash > 0 then
		startingCash = Config.StudioTestCash -- mode test : uniquement dans Studio
	end
	local data = { owned = {}, cash = startingCash, rebirths = 0, loaded = true }
	if not dataStore then
		return data
	end
	local ok, saved = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)
	if not ok then
		-- On ne sauvegardera pas ce joueur, sinon on écraserait sa vraie partie
		warn("[Tycoon] Chargement impossible pour", player.Name, saved)
		data.loaded = false
	elseif type(saved) == "table" then
		data.cash = tonumber(saved.cash) or data.cash
		data.rebirths = tonumber(saved.rebirths) or 0
		if type(saved.owned) == "table" then
			for _, id in ipairs(saved.owned) do
				if itemsById[id] then
					data.owned[id] = true
				end
			end
		end
	end
	return data
end

local function saveData(player)
	local data = playerData[player]
	local cash = getCash(player)
	if not dataStore or not data or not data.loaded or not cash then
		return
	end
	local owned = {}
	for id in pairs(data.owned) do
		table.insert(owned, id)
	end
	local ok, err = pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, {
			cash = cash.Value,
			owned = owned,
			rebirths = getRebirths(player),
		})
	end)
	if not ok then
		warn("[Tycoon] Sauvegarde impossible pour", player.Name, err)
	end
end

-- ============================================================
-- Arrivée / départ des joueurs
-- ============================================================

local freeBotPlot -- défini plus bas, dans la partie "Bots" : libère le garage d'un bot

local function onPlayerAdded(player)
	local data = loadData(player)
	if not player.Parent then
		return -- le joueur est parti pendant le chargement
	end
	playerData[player] = data

	-- "leaderstats" = le tableau des scores en haut à droite de l'écran
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	player:SetAttribute("CashMultiplier", 1)
	if Config.CashX2GamePassId ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.CashX2GamePassId)
		end)
		if ok and owns then
			player:SetAttribute("CashMultiplier", 2)
		end
	end

	local plot = getFreePlot() or (freeBotPlot and freeBotPlot())
	if not plot then
		warn("[Tycoon] Plus de garage libre pour", player.Name)
		player:LoadCharacter()
		return
	end
	assignPlot(plot, player)

	-- Quand le perso meurt, il réapparaît dans son garage après quelques secondes
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid").Died:Connect(function()
			task.wait(Players.RespawnTime)
			spawnPlayer(player)
		end)
	end)
	spawnPlayer(player)
end

local function onPlayerRemoving(player)
	cancelListings(player)
	saveData(player)
	local data = playerData[player]
	if data and data.plot then
		releasePlot(data.plot)
	end
	playerData[player] = nil
end

-- ============================================================
-- Bots : faux joueurs qui jouent tout seuls (pour voir le jeu à plusieurs)
-- Ils achètent, font des rebirths et utilisent le marché comme des joueurs.
-- ============================================================

local BOT_NAMES = { "TurboMax", "NitroLina", "GearBoy", "DriftKing", "PistonPro", "RimQueen" }
local bots = {} -- [bot] = { plot, character }
local botsFolder = Instance.new("Folder")
botsFolder.Name = "Bots"
botsFolder.Parent = ServerStorage

local function createBotCharacter(bot, plot)
	local ok, character = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local color = Color3.fromHSV(math.random(), 0.6, 0.9)
		description.HeadColor = Color3.fromRGB(240, 200, 160)
		description.TorsoColor = color
		description.LeftArmColor = color
		description.RightArmColor = color
		description.LeftLegColor = COLOR_DARK
		description.RightLegColor = COLOR_DARK
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not character or not bots[bot] then
		return nil
	end
	character.Name = bot.Name
	character:FindFirstChildOfClass("Humanoid").DisplayName = bot.Name .. " [BOT]"
	character.Parent = workspace
	character:PivotTo(at(plot, 0, 4, 30))
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root:SetNetworkOwner(nil)
	end
	return character
end

-- Le bot marche vers un point (abandonne au bout de quelques secondes s'il est bloqué)
local function botWalkTo(state, position)
	local humanoid = state.character and state.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local arrived = false
	local connection = humanoid.MoveToFinished:Connect(function()
		arrived = true
	end)
	humanoid:MoveTo(position)
	local elapsed = 0
	while not arrived and elapsed < 6 do
		elapsed += task.wait(0.2)
	end
	connection:Disconnect()
end

local function botBrain(bot, state)
	while bots[bot] do
		task.wait(math.random(15, 35) / 10)
		local plot = state.plot
		local data = playerData[bot]
		local cash = getCash(bot)
		if not bots[bot] or not data or not cash then
			break
		end

		-- 1) Acheter le prochain objet abordable
		local target = nil
		for _, item in ipairs(Config.Items) do
			if plot.buttons[item.id] and cash.Value >= item.price then
				target = item
				break
			end
		end

		if target then
			botWalkTo(state, at(plot, target.button.X, 3, target.button.Z).Position)
			if bots[bot] then
				purchase(plot, bot, target)
			end
		elseif plot.rebirthButton and cash.Value >= getRebirthCost(bot) then
			-- 2) Rebirth quand tout est acheté
			botWalkTo(state, at(plot, Config.RebirthButton.X, 3, Config.RebirthButton.Z).Position)
			if bots[bot] then
				performRebirth(plot, bot)
			end
		else
			-- 3) Utiliser le marché de temps en temps
			if math.random() < Config.BotMarketChance then
				local cars = {}
				for _, item in ipairs(Config.Items) do
					if item.kind == "car" and data.owned[item.id] then
						table.insert(cars, item)
					end
				end
				if #cars > 0 then
					listCar(plot, cars[math.random(#cars)])
				end
			end
			for _, slot in ipairs(slots) do
				if slot.listing and slot.listing.seller ~= bot and math.random() < Config.BotMarketChance then
					buyCar(slot, bot)
					break
				end
			end
			-- 4) Se promener dans son garage
			botWalkTo(state, at(plot, math.random(-15, 20), 3, math.random(-5, 32)).Position)
		end
	end
end

local function createBot(plot)
	local used = {}
	for bot in pairs(bots) do
		used[bot.Name] = true
	end
	local name = "Bot"
	for _, candidate in ipairs(BOT_NAMES) do
		if not used[candidate] then
			name = candidate
			break
		end
	end

	-- Un bot est un simple dossier qui imite un joueur (leaderstats, attributs)
	local bot = Instance.new("Folder")
	bot.Name = name
	bot:SetAttribute("IsBot", true)
	bot:SetAttribute("CashMultiplier", 1)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = bot
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	bot.Parent = botsFolder

	playerData[bot] = { owned = {}, cash = 0, rebirths = 0, loaded = false }
	local state = { plot = plot }
	bots[bot] = state
	assignPlot(plot, bot)
	task.spawn(function()
		state.character = createBotCharacter(bot, plot)
	end)
	task.spawn(botBrain, bot, state)
	return bot
end

local function removeBot(bot)
	local state = bots[bot]
	if not state then
		return
	end
	bots[bot] = nil
	cancelListings(bot)
	if state.character then
		state.character:Destroy()
	end
	releasePlot(state.plot)
	playerData[bot] = nil
	bot:Destroy()
end

-- Un vrai joueur arrive et tous les garages sont pris : un bot lui laisse sa place
freeBotPlot = function()
	for bot, state in pairs(bots) do
		local plot = state.plot
		removeBot(bot)
		return plot
	end
	return nil
end

if Config.BotsEnabled and (RunService:IsStudio() or not Config.BotsOnlyInStudio) then
	task.delay(3, function()
		for _ = 1, Config.BotCount do
			local plot = getFreePlot()
			if plot then
				createBot(plot)
			end
		end
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if purchased and passId == Config.CashX2GamePassId then
		player:SetAttribute("CashMultiplier", 2)
		local data = playerData[player]
		if data and data.plot and data.plot.passPad then
			data.plot.passPad:Destroy()
			data.plot.passPad = nil
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
-- Joueurs déjà connectés avant que ce script démarre (arrive dans Studio)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Sauvegarde quand le serveur s'éteint
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

-- Revenus des voitures : chaque voiture du showroom rapporte de l'argent chaque seconde
task.spawn(function()
	while true do
		task.wait(1)
		for _, plot in ipairs(plots) do
			local owner = plot.owner
			local data = owner and playerData[owner]
			local cash = owner and getCash(owner)
			if data and cash then
				local income = 0
				for _, item in ipairs(Config.Items) do
					if item.income and data.owned[item.id] then
						income += item.income
					end
				end
				if income > 0 then
					cash.Value += math.floor(income * getMultiplier(owner) + 0.5)
				end
			end
		end
	end
end)

-- Sauvegarde automatique régulière (au cas où le serveur plante)
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)
