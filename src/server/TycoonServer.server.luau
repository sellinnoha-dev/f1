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

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local formatMoney = require(ReplicatedStorage:WaitForChild("FormatMoney"))

-- On fait apparaître les persos nous-mêmes, directement dans leur garage
Players.CharacterAutoLoads = false

-- Couleurs utilisées partout
local COLOR_FLOOR = Color3.fromRGB(70, 70, 75)
local COLOR_DARK = Color3.fromRGB(35, 35, 40)
local COLOR_BUTTON = Color3.fromRGB(0, 200, 90)
local COLOR_BUTTON_DENIED = Color3.fromRGB(220, 40, 40)
local COLOR_GOLD = Color3.fromRGB(255, 200, 0)

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

-- ============================================================
-- Les pièces qui roulent sur le tapis
-- ============================================================

-- Forme des pièces auto qui sortent des machines (voir "drop" dans Config)
local DROP_SHAPES = {
	bolt = { size = Vector3.new(1.4, 0.7, 0.7), shape = Enum.PartType.Cylinder, material = Enum.Material.Metal },
	tire = { size = Vector3.new(0.9, 2, 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Rubber, flat = true },
	engine = { size = Vector3.new(1.8, 1.4, 1.6), shape = Enum.PartType.Block, material = Enum.Material.Metal },
	panel = { size = Vector3.new(2.2, 0.5, 1.6), shape = Enum.PartType.Block, material = Enum.Material.SmoothPlastic },
	rim = { size = Vector3.new(0.6, 2, 2), shape = Enum.PartType.Cylinder, material = Enum.Material.Foil, flat = true },
}

local function spawnDrop(plot, item)
	local look = DROP_SHAPES[item.drop] or DROP_SHAPES.bolt
	local drop = Instance.new("Part")
	drop.Name = "Drop"
	drop.Shape = look.shape
	drop.Size = look.size
	drop.Color = item.color
	drop.Material = look.material
	drop.CFrame = at(plot, -25, 5, item.z)
	if look.flat then
		-- Pneus et jantes posés à plat sur le tapis
		drop.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	end
	drop:SetAttribute("Value", item.value)
	drop:SetAttribute("Plot", plot.index)
	drop.Parent = plot.drops
	-- Le serveur gère la physique : un tricheur ne peut pas déplacer les pièces
	drop:SetNetworkOwner(nil)
	Debris:AddItem(drop, Config.DropLifetime)
end

-- Une pièce touche le collecteur : on la vend
local function onCollect(plot, hit)
	local value = hit:GetAttribute("Value")
	if not value or hit:GetAttribute("Plot") ~= plot.index then
		return
	end
	hit:SetAttribute("Plot", nil) -- empêche de compter la même pièce deux fois
	hit:Destroy()

	local owner = plot.owner
	local cash = owner and getCash(owner)
	if cash then
		local multiplier = owner:GetAttribute("CashMultiplier") or 1
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
		local value = hit:GetAttribute("Value")
		if not value or hit:GetAttribute("Plot") ~= plot.index or hit:GetAttribute(tag) then
			return
		end
		hit:SetAttribute(tag, true)
		hit:SetAttribute("Value", value * item.multiplier)
		hit.Color = item.color -- la pièce prend la couleur de la machine
	end)
end

local function buildWalls(plot, item, model)
	local walls = {
		{ Vector3.new(80, 12, 1), Vector3.new(0, 6, -40) }, -- fond
		{ Vector3.new(1, 12, 80), Vector3.new(-40, 6, 0) }, -- gauche
		{ Vector3.new(1, 12, 80), Vector3.new(40, 6, 0) },  -- droite
	}
	for _, wall in ipairs(walls) do
		local size, pos = wall[1], wall[2]
		makePart(model, {
			Name = "Wall", Size = size, CFrame = at(plot, pos.X, pos.Y, pos.Z),
			Color = item.color, Material = Enum.Material.Brick,
		})
	end
end

-- Voiture de showroom sur un podium qui tourne
local function buildCar(plot, item, model)
	local p = item.position
	makePart(model, {
		Name = "Podium", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 16, 16),
		CFrame = at(plot, p.X, 0.5, p.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLOR_DARK, Material = Enum.Material.Marble,
	})

	local base = at(plot, p.X, 1, p.Z) -- dessus du podium
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

	-- Rotation du podium
	car.WorldPivot = base
	task.spawn(function()
		local angle = 0
		while car.Parent do
			angle += math.rad(1)
			car:PivotTo(base * CFrame.Angles(0, angle, 0))
			task.wait(1 / 30)
		end
	end)
end

local builders = {
	dropper = buildDropper,
	upgrader = buildUpgrader,
	walls = buildWalls,
	car = buildCar,
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

local function tryBuy(plot, item, button, hit)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player or player ~= plot.owner or plot.buying then
		return
	end
	local data = playerData[player]
	local cash = getCash(player)
	if not data or not cash or data.owned[item.id] then
		return
	end

	if cash.Value < item.price then
		-- Pas assez d'argent : le bouton clignote en rouge
		if not button:GetAttribute("Flashing") then
			button:SetAttribute("Flashing", true)
			button.Color = COLOR_BUTTON_DENIED
			task.delay(0.5, function()
				button.Color = COLOR_BUTTON
				button:SetAttribute("Flashing", nil)
			end)
		end
		return
	end

	plot.buying = true
	cash.Value -= item.price
	data.owned[item.id] = true
	buildItem(plot, item)
	refreshButtons(plot)
	plot.buying = false
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
end

-- Bouton doré pour acheter le Game Pass "Argent x2"
local function createGamePassPad(plot)
	local owner = plot.owner
	if Config.CashX2GamePassId == 0 or not owner or owner:GetAttribute("CashMultiplier") == 2 then
		return
	end
	local pad = makePart(plot.model, {
		Name = "GamePassPad", Size = Vector3.new(5, 0.6, 5), CFrame = at(plot, 6, 0.3, -14),
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

	makePart(model, {
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

-- Place centrale où se rejoignent les routes
makePart(plotsFolder, {
	Name = "Plaza", Size = Vector3.new(30, 0.2, 30), CFrame = CFrame.new(0, 0.12, 0),
	Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt,
})

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
	plot.signLabel.Text = player.DisplayName .. "'s Garage"

	-- Reconstruit tout ce que le joueur avait acheté (sauvegarde)
	for _, item in ipairs(Config.Items) do
		if data.owned[item.id] then
			buildItem(plot, item)
		end
	end
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
	plot.signLabel.Text = "Free Garage"
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
	local data = { owned = {}, cash = Config.StartingCash, loaded = true }
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
		dataStore:SetAsync("player_" .. player.UserId, { cash = cash.Value, owned = owned })
	end)
	if not ok then
		warn("[Tycoon] Sauvegarde impossible pour", player.Name, err)
	end
end

-- ============================================================
-- Arrivée / départ des joueurs
-- ============================================================

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

	local plot = getFreePlot()
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
	saveData(player)
	local data = playerData[player]
	if data and data.plot then
		releasePlot(data.plot)
	end
	playerData[player] = nil
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

-- Sauvegarde automatique régulière (au cas où le serveur plante)
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)
