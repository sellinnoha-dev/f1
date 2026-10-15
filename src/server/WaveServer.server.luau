-- ============================================================
-- Tsunami Critters : le moteur du jeu (côté serveur)
-- Carte, vague, créatures, bases des joueurs, améliorations, sauvegarde.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local formatMoney = require(ReplicatedStorage:WaitForChild("FormatMoney"))

print("[Tsunami] Version " .. tostring(Config.Version))

-- On gère nous-mêmes l'apparition des personnages (dans sa base)
Players.CharacterAutoLoads = false

local raritiesById, rarityIndex, creaturesById, creaturesByRarity = {}, {}, {}, {}
for index, rarity in ipairs(Config.Rarities) do
	raritiesById[rarity.id] = rarity
	rarityIndex[rarity.id] = index
	creaturesByRarity[rarity.id] = {}
end
for _, def in ipairs(Config.Creatures) do
	creaturesById[def.id] = def
	table.insert(creaturesByRarity[def.rarity], def)
end

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = ReplicatedStorage

local function notify(player, text)
	if player and player.Parent then
		notifyEvent:FireClient(player, text)
	end
end

local function notifyAll(text)
	notifyEvent:FireAllClients(text)
end

-- ============================================================
-- Petits outils
-- ============================================================

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

-- Étiquette au-dessus d'un objet : un titre et un sous-titre
local function createBillboard(part, title, subtitle, offsetY, width, titleColor, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(width or 8, 0, subtitle and 2.4 or 1.3, 0)
	gui.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	gui.MaxDistance = maxDistance or 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = part
	local function addLabel(name, text, posY, height, color)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.fromScale(0, posY)
		label.Size = UDim2.fromScale(1, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0
		label.Text = text
		label.Parent = gui
	end
	if subtitle then
		addLabel("Title", title, 0, 0.55, titleColor or Color3.new(1, 1, 1))
		addLabel("Subtitle", subtitle, 0.57, 0.43, Color3.fromRGB(255, 220, 80))
	else
		addLabel("Title", title, 0, 1, titleColor or Color3.new(1, 1, 1))
	end
	return gui
end

local function setBillboard(gui, title, subtitle)
	local titleLabel = gui:FindFirstChild("Title")
	local subtitleLabel = gui:FindFirstChild("Subtitle")
	if titleLabel and title then
		titleLabel.Text = title
	end
	if subtitleLabel and subtitle then
		subtitleLabel.Text = subtitle
	end
end

local function getCash(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function vertical(cframe)
	-- Les cylindres Roblox sont couchés (axe X) : on les met debout
	return cframe * CFrame.Angles(0, 0, math.rad(90))
end

-- ============================================================
-- Construction des créatures (formes simples + accessoires)
-- ============================================================

local assetsFolder = ServerStorage:FindFirstChild("Assets")

-- Une créature : modèle dont le pivot est sous ses pieds, tourné vers -Z
local function buildCreature(def)
	local look = def.look
	local rarity = raritiesById[def.rarity]
	local s = look.size or 3
	local accent = look.accent or Color3.new(1, 1, 1)
	local model = Instance.new("Model")
	model.Name = def.name

	local function piece(props)
		props.CanCollide = false
		props.CanTouch = false
		props.CastShadow = false
		if not props.Material then
			props.Material = Enum.Material.SmoothPlastic
		end
		return makePart(model, props)
	end

	-- Corps
	local body, height, front
	if look.body == "block" then
		height = s * 0.9
		body = piece({ Name = "Body", Size = Vector3.new(s, height, s * 0.8), CFrame = CFrame.new(0, height / 2, 0),
			Color = look.color, Material = look.material })
		front = -s * 0.4
	elseif look.body == "cylinder" then
		height = s * 1.3
		body = piece({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, s * 0.8, s * 0.8),
			CFrame = vertical(CFrame.new(0, height / 2, 0)), Color = look.color, Material = look.material })
		front = -s * 0.4
	else
		height = s
		body = piece({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s),
			CFrame = CFrame.new(0, height / 2, 0), Color = look.color, Material = look.material })
		front = -s * 0.44
	end
	local top = height
	local eyeY = height * 0.62

	-- Yeux (blanc + pupille noire)
	local eyeCount = look.eyes or 2
	local eyeX = ({ { 0 }, { -0.2, 0.2 }, { -0.26, 0, 0.26 } })[math.clamp(eyeCount, 1, 3)]
	for _, x in ipairs(eyeX) do
		piece({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.3,
			CFrame = CFrame.new(x * s, eyeY, front), Color = Color3.new(1, 1, 1) })
		piece({ Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.15,
			CFrame = CFrame.new(x * s, eyeY, front - s * 0.12), Color = Color3.fromRGB(15, 15, 20) })
	end
	-- Bouche
	piece({ Name = "Mouth", Size = Vector3.new(s * 0.3, s * 0.07, s * 0.06), CFrame = CFrame.new(0, height * 0.36, front - s * 0.02),
		Color = Color3.fromRGB(60, 20, 20) })

	local dark = Color3.fromRGB(25, 25, 30)
	local extras = {}
	for _, extra in ipairs(look.extras or {}) do
		extras[extra] = true
	end

	if extras.antenna then
		piece({ Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.6, s * 0.06, s * 0.06),
			CFrame = vertical(CFrame.new(0, top + s * 0.28, 0)), Color = dark })
		piece({ Name = "AntennaBall", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.2,
			CFrame = CFrame.new(0, top + s * 0.62, 0), Color = accent, Material = Enum.Material.Neon })
		top += s * 0.7
	end
	if extras.feet then
		for _, x in ipairs({ -0.25, 0.25 }) do
			piece({ Name = "Foot", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.3, s * 0.18, s * 0.38),
				CFrame = CFrame.new(x * s, s * 0.06, -s * 0.12), Color = accent })
		end
	end
	if extras.mustache then
		for _, side in ipairs({ -1, 1 }) do
			piece({ Name = "Mustache", Size = Vector3.new(s * 0.24, s * 0.08, s * 0.06),
				CFrame = CFrame.new(side * s * 0.12, height * 0.45, front - s * 0.04) * CFrame.Angles(0, 0, math.rad(side * -15)),
				Color = dark })
		end
	end
	if extras.brows then
		for _, x in ipairs(eyeX) do
			local side = x < 0 and -1 or (x > 0 and 1 or 0)
			piece({ Name = "Brow", Size = Vector3.new(s * 0.22, s * 0.06, s * 0.06),
				CFrame = CFrame.new(x * s, eyeY + s * 0.2, front - s * 0.06) * CFrame.Angles(0, 0, math.rad(side * 20)),
				Color = dark })
		end
	end
	if extras.shades then
		piece({ Name = "Shades", Size = Vector3.new(s * (eyeCount == 3 and 0.95 or 0.75), s * 0.17, s * 0.06),
			CFrame = CFrame.new(0, eyeY, front - s * 0.16), Color = dark, Reflectance = 0.4 })
	end
	if extras.headband then
		piece({ Name = "Headband", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.14, s * 0.86, s * 0.86),
			CFrame = vertical(CFrame.new(0, height * 0.86, 0)), Color = accent })
		piece({ Name = "BandTail", Size = Vector3.new(s * 0.08, s * 0.1, s * 0.4),
			CFrame = CFrame.new(s * 0.1, height * 0.82, s * 0.55) * CFrame.Angles(math.rad(-20), 0, 0), Color = accent })
	end
	if extras.tophat then
		piece({ Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.06, s * 0.85, s * 0.85),
			CFrame = vertical(CFrame.new(0, top - s * 0.02, 0)), Color = accent })
		piece({ Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.5, s * 0.52, s * 0.52),
			CFrame = vertical(CFrame.new(0, top + s * 0.25, 0)), Color = accent })
		top += s * 0.5
	end
	if extras.wizardhat then
		local y = top - s * 0.05
		for i, size in ipairs({ { 0.12, 0.9 }, { 0.35, 0.55 }, { 0.35, 0.3 } }) do
			piece({ Name = "WizardHat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * size[1], s * size[2], s * size[2]),
				CFrame = vertical(CFrame.new(0, y + s * size[1] / 2, 0)), Color = accent })
			y += s * size[1]
			if i == 3 then
				piece({ Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.18,
					CFrame = CFrame.new(0, y + s * 0.05, 0), Color = Color3.fromRGB(255, 230, 0), Material = Enum.Material.Neon })
			end
		end
		top = y + s * 0.15
	end
	if extras.crown then
		local gold = Color3.fromRGB(255, 200, 30)
		piece({ Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.22, s * 0.55, s * 0.55),
			CFrame = vertical(CFrame.new(0, top + s * 0.08, 0)), Color = gold, Reflectance = 0.3, Material = Enum.Material.Metal })
		for i = 0, 4 do
			local angle = i / 5 * 2 * math.pi
			piece({ Name = "CrownSpike", Size = Vector3.new(s * 0.09, s * 0.2, s * 0.09),
				CFrame = CFrame.new(math.cos(angle) * s * 0.24, top + s * 0.28, math.sin(angle) * s * 0.24),
				Color = gold, Material = Enum.Material.Metal, Reflectance = 0.3 })
		end
		piece({ Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.12,
			CFrame = CFrame.new(0, top + s * 0.1, -s * 0.28), Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.Neon })
		top += s * 0.4
	end
	if extras.propeller then
		piece({ Name = "PropRod", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.3, s * 0.07, s * 0.07),
			CFrame = vertical(CFrame.new(0, top + s * 0.13, 0)), Color = dark })
		for _, angle in ipairs({ 0, 90 }) do
			piece({ Name = "PropBlade", Size = Vector3.new(s * 1.1, s * 0.04, s * 0.16),
				CFrame = CFrame.new(0, top + s * 0.3, 0) * CFrame.Angles(0, math.rad(angle), 0), Color = accent })
		end
		top += s * 0.35
	end
	if extras.shell then
		piece({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.9,
			CFrame = CFrame.new(0, height * 0.6, s * 0.42), Color = accent })
		piece({ Name = "ShellSpiral", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.4,
			CFrame = CFrame.new(s * 0.36, height * 0.62, s * 0.45), Color = Color3.new(1, 1, 1) })
		for _, side in ipairs({ -1, 1 }) do
			piece({ Name = "Exhaust", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.3, s * 0.12, s * 0.12),
				CFrame = CFrame.new(side * s * 0.15, height * 0.4, s * 0.9) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(180, 180, 190), Material = Enum.Material.Metal })
		end
	end
	if extras.wings then
		for _, side in ipairs({ -1, 1 }) do
			piece({ Name = "Wing", Size = Vector3.new(s * 0.08, s * 0.5, s * 0.75),
				CFrame = CFrame.new(side * s * 0.55, height * 0.62, s * 0.15) * CFrame.Angles(0, 0, math.rad(side * -30)),
				Color = Color3.new(1, 1, 1), Transparency = 0.15 })
		end
	end
	if extras.horns then
		for _, side in ipairs({ -1, 1 }) do
			piece({ Name = "Horn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.4, s * 0.12, s * 0.12),
				CFrame = CFrame.new(side * s * 0.25, height + s * 0.05, 0) * CFrame.Angles(0, 0, math.rad(90 - side * 25)),
				Color = accent })
		end
	end
	if extras.halo then
		piece({ Name = "Halo", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.06, s * 0.65, s * 0.65),
			CFrame = vertical(CFrame.new(0, top + s * 0.3, 0)), Color = Color3.fromRGB(255, 240, 120),
			Material = Enum.Material.Neon, Transparency = 0.2 })
		top += s * 0.35
	end

	-- Effets des grandes raretés
	local level = rarityIndex[def.rarity] or 1
	if level >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10
		light.Brightness = 2
		light.Parent = body
	end
	if level >= 5 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarity.color
		sparkles.Parent = body
	end

	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()
	model:SetAttribute("Height", top)
	return model
end

-- Version "modèle perso" : si un modèle porte le nom de la créature dans ServerStorage > Assets
local function buildCustomCreature(def)
	local asset = assetsFolder and assetsFolder:FindFirstChild(def.name)
	if not asset or not (asset:IsA("Model") or asset:IsA("BasePart")) then
		return nil
	end
	local clone = asset:Clone()
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	local model = clone
	if clone:IsA("BasePart") then
		model = Instance.new("Model")
		clone.Parent = model
	end
	model.Name = def.name
	local parts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	if #parts == 0 then
		return nil
	end
	local box, size = model:GetBoundingBox()
	local target = (def.look.size or 3) * 1.4
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	model:ScaleTo(model:GetScale() * target / math.max(size.X, size.Y, size.Z))
	local biggest = parts[1]
	for _, part in ipairs(parts) do
		part.CanCollide = false
		part.CanTouch = false
		if part.Size.Magnitude > biggest.Size.Magnitude then
			biggest = part
		end
	end
	model.PrimaryPart = biggest
	model:PivotTo(CFrame.new())
	local _, newSize = model:GetBoundingBox()
	model:SetAttribute("Height", newSize.Y)
	return model
end

-- Construit la créature puis soude tout à la pièce principale (ancrée seule)
local function makeCreatureModel(def)
	local model = buildCustomCreature(def) or buildCreature(def)
	local root = model.PrimaryPart
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
			part.Anchored = false
			part.Massless = true
		end
	end
	root.Anchored = true
	return model
end

local function creatureLabel(model, def, offset)
	local rarity = raritiesById[def.rarity]
	return createBillboard(model.PrimaryPart, def.name, rarity.name .. "  ·  $" .. formatMoney(def.income) .. "/s",
		offset or ((model:GetAttribute("Height") or 3) - model.PrimaryPart.Position.Y + model:GetPivot().Y + 1.8), 9, rarity.color)
end

-- La créature flotte et tourne doucement (animé côté joueur, voir WaveClient)
local function makeBobbing(model)
	model:SetAttribute("BaseCFrame", model.PrimaryPart.CFrame)
	CollectionService:AddTag(model, "Bobbing")
end

-- ============================================================
-- La carte
-- ============================================================

-- La plaque par défaut boucherait les tranchées : on la retire
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
		child:Destroy()
	end
end
Lighting.ClockTime = 14
Lighting.Brightness = 2.5

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local PATH_END = Config.PathLength
local HALF_WIDTH = Config.PathWidth / 2
local GROUND_BOTTOM = -24

local function groundPiece(fromX, toX, color, material)
	if toX - fromX <= 0.1 then
		return
	end
	makePart(map, {
		Name = "Ground", Size = Vector3.new(toX - fromX, -GROUND_BOTTOM, Config.PathWidth),
		CFrame = CFrame.new((fromX + toX) / 2, GROUND_BOTTOM / 2, 0),
		Color = color, Material = material or Enum.Material.Grass,
	})
end

-- Sol du chemin, zone par zone, en laissant les trous des tranchées
local trenchRanges = {}
for _, x in ipairs(Config.Trenches) do
	table.insert(trenchRanges, { x - Config.TrenchLength / 2, x + Config.TrenchLength / 2 })
end
for _, zone in ipairs(Config.Zones) do
	local cursor = zone.from
	for _, range in ipairs(trenchRanges) do
		if range[2] > zone.from and range[1] < zone.to then
			groundPiece(cursor, math.max(cursor, range[1]), zone.color)
			cursor = math.min(zone.to, range[2])
		end
	end
	groundPiece(cursor, zone.to, zone.color)
end

-- Tranchées : fond, marche pour remonter, bordures jaunes
for _, range in ipairs(trenchRanges) do
	local length = range[2] - range[1]
	local depth = Config.TrenchDepth
	makePart(map, {
		Name = "TrenchFloor", Size = Vector3.new(length, -GROUND_BOTTOM - depth, Config.PathWidth),
		CFrame = CFrame.new((range[1] + range[2]) / 2, (GROUND_BOTTOM - depth) / 2, 0),
		Color = Color3.fromRGB(70, 60, 50), Material = Enum.Material.Slate,
	})
	-- Marche côté base pour sortir (on saute dessus puis dehors)
	makePart(map, {
		Name = "TrenchStep", Size = Vector3.new(4, depth / 2, Config.PathWidth),
		CFrame = CFrame.new(range[1] + 2, -depth + depth / 4, 0),
		Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Slate,
	})
	for _, x in ipairs({ range[1], range[2] }) do
		makePart(map, {
			Name = "TrenchEdge", Size = Vector3.new(0.6, 0.2, Config.PathWidth), CFrame = CFrame.new(x, 0.1, 0),
			Color = Color3.fromRGB(255, 210, 0), Material = Enum.Material.Neon, CanCollide = false,
		})
	end
	local sign = makePart(map, {
		Name = "TrenchSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new((range[1] + range[2]) / 2, 5, 0),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	createBillboard(sign, "SAFE TRENCH", nil, 0, 10, Color3.fromRGB(120, 255, 140), 120)
end

-- Falaises de chaque côté du chemin
for _, side in ipairs({ -1, 1 }) do
	makePart(map, {
		Name = "Cliff", Size = Vector3.new(PATH_END + 40, 64, 16),
		CFrame = CFrame.new(PATH_END / 2 + 20, 32 + GROUND_BOTTOM, side * (HALF_WIDTH + 8)),
		Color = Color3.fromRGB(120, 105, 90), Material = Enum.Material.Rock,
	})
end

-- Mer au bout du chemin
makePart(map, {
	Name = "Beach", Size = Vector3.new(40, 2, Config.PathWidth), CFrame = CFrame.new(PATH_END + 20, -1.5, 0),
	Color = Color3.fromRGB(235, 215, 160), Material = Enum.Material.Sand,
})
makePart(map, {
	Name = "Sea", Size = Vector3.new(400, 2, 600), CFrame = CFrame.new(PATH_END + 240, -3, 0),
	Color = Color3.fromRGB(40, 120, 200), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false,
})
makePart(map, {
	Name = "SeaFloor", Size = Vector3.new(400, 2, 600), CFrame = CFrame.new(PATH_END + 240, -12, 0),
	Color = Color3.fromRGB(210, 190, 140), Material = Enum.Material.Sand,
})

-- Arches à l'entrée de chaque zone
for _, zone in ipairs(Config.Zones) do
	local rarity = raritiesById[zone.rarity]
	local x = zone.from + 4
	for _, side in ipairs({ -1, 1 }) do
		makePart(map, {
			Name = "ArchPost", Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(x, 9, side * (HALF_WIDTH - 1)),
			Color = rarity.color, Material = Enum.Material.Neon,
		})
	end
	local beam = makePart(map, {
		Name = "ArchBeam", Size = Vector3.new(2, 2.5, Config.PathWidth), CFrame = CFrame.new(x, 18, 0),
		Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.Metal,
	})
	createBillboard(beam, rarity.name .. " ZONE", nil, 3, 18, rarity.color, 250)
end

-- Zone des bases (côté X négatif) : la vague ne va pas jusque-là
local BASE_MIN_X = -215
makePart(map, {
	Name = "BaseGround", Size = Vector3.new(-BASE_MIN_X, -GROUND_BOTTOM, 220),
	CFrame = CFrame.new(BASE_MIN_X / 2, GROUND_BOTTOM / 2, 0),
	Color = Color3.fromRGB(95, 160, 80), Material = Enum.Material.Grass,
})
makePart(map, {
	Name = "Avenue", Size = Vector3.new(-BASE_MIN_X, 0.2, 24), CFrame = CFrame.new(BASE_MIN_X / 2, 0.05, 0),
	Color = Color3.fromRGB(200, 195, 185), Material = Enum.Material.Concrete,
})
for _, wall in ipairs({
	{ size = Vector3.new(4, 10, 220), position = Vector3.new(BASE_MIN_X - 2, 5, 0) },
	{ size = Vector3.new(-BASE_MIN_X, 10, 4), position = Vector3.new(BASE_MIN_X / 2, 5, 112) },
	{ size = Vector3.new(-BASE_MIN_X, 10, 4), position = Vector3.new(BASE_MIN_X / 2, 5, -112) },
	{ size = Vector3.new(4, 10, 110 - HALF_WIDTH - 16), position = Vector3.new(2, 5, (110 + HALF_WIDTH + 16) / 2) },
	{ size = Vector3.new(4, 10, 110 - HALF_WIDTH - 16), position = Vector3.new(2, 5, -(110 + HALF_WIDTH + 16) / 2) },
}) do
	makePart(map, {
		Name = "Wall", Size = wall.size, CFrame = CFrame.new(wall.position),
		Color = Color3.fromRGB(200, 190, 175), Material = Enum.Material.Brick,
	})
end
local safeSign = makePart(map, {
	Name = "SafeSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(-6, 12, 0),
	Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
})
createBillboard(safeSign, "SAFE ZONE", "The wave never comes here", 0, 16, Color3.fromRGB(120, 255, 140), 200)

-- ============================================================
-- Les bases des joueurs
-- ============================================================

local playerData = {} -- [player] = { creatures = {[index] = id}, upgrades = {}, plot, loaded }
local carrying = {} -- [player] = { ids... }
local plots = {}

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Plots"
plotsFolder.Parent = workspace

local PEDESTAL_SPOTS = {}
for _, z in ipairs({ 15, 6 }) do
	for _, x in ipairs({ -17.5, -10.5, -3.5, 3.5, 10.5, 17.5 }) do
		table.insert(PEDESTAL_SPOTS, Vector3.new(x, 0, z))
	end
end
local PAD_SPOTS = { Vector3.new(-13, 0, -15), Vector3.new(0, 0, -15), Vector3.new(13, 0, -15) }
local upgradesById = {}
for index, upgrade in ipairs(Config.Upgrades) do
	upgradesById[upgrade.id] = upgrade
	upgrade.pad = PAD_SPOTS[index]
end

local function at(plot, x, y, z)
	return plot.cframe * CFrame.new(x, y, z)
end

local function upgradeLevel(data, id)
	return (data and data.upgrades[id]) or 0
end

local function pedestalCount(data)
	local upgrade = upgradesById.pedestals
	return math.min(#PEDESTAL_SPOTS, Config.BasePedestals + upgradeLevel(data, "pedestals") * upgrade.perLevel)
end

local function carryMax(data)
	return 1 + upgradeLevel(data, "carry") * upgradesById.carry.perLevel
end

local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(120, 200, 255), Color3.fromRGB(140, 230, 140), Color3.fromRGB(255, 210, 100),
	Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 160, 220), Color3.fromRGB(120, 240, 220), Color3.fromRGB(255, 170, 90),
}

local function createPlot(index)
	local side = index <= Config.PlotCount / 2 and 1 or -1
	local column = (index - 1) % math.ceil(Config.PlotCount / 2)
	local center = Vector3.new(-32 - column * 50, 0, side * 72)
	local plot = {
		index = index,
		cframe = CFrame.lookAt(center, Vector3.new(center.X, 0, 0)), -- l'avant regarde l'avenue
		color = PLOT_COLORS[index],
		owner = nil,
		pedestals = {},
	}
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = plotsFolder
	plot.model = model

	makePart(model, {
		Name = "Floor", Size = Vector3.new(44, 1, 44), CFrame = at(plot, 0, -0.3, 0),
		Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.SmoothPlastic,
	})
	for _, edge in ipairs({ { 0, -22, 44, 0.6 }, { 0, 22, 44, 0.6 }, { -22, 0, 0.6, 44 }, { 22, 0, 0.6, 44 } }) do
		makePart(model, {
			Name = "Border", Size = Vector3.new(edge[3], 0.3, edge[4]), CFrame = at(plot, edge[1], 0.25, edge[2]),
			Color = plot.color, Material = Enum.Material.Neon, CanCollide = false,
		})
	end
	-- Mur du fond et petites barrières sur les côtés
	makePart(model, {
		Name = "BackWall", Size = Vector3.new(44, 12, 1), CFrame = at(plot, 0, 6, 22.5),
		Color = plot.color, Material = Enum.Material.SmoothPlastic,
	})
	for _, x in ipairs({ -22.5, 22.5 }) do
		makePart(model, {
			Name = "SideFence", Size = Vector3.new(1, 3, 44), CFrame = at(plot, x, 1.5, 0),
			Color = Color3.fromRGB(240, 240, 245), Material = Enum.Material.SmoothPlastic,
		})
	end
	local signPart = makePart(model, {
		Name = "Sign", Size = Vector3.new(1, 1, 1), CFrame = at(plot, 0, 15, 22),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	plot.sign = createBillboard(signPart, "FREE BASE", "", 0, 22, plot.color, 250)

	-- Point d'apparition du propriétaire
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlotSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = at(plot, 0, 0.3, -5)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.5
	spawn.Color = plot.color
	spawn.Material = Enum.Material.Neon
	spawn.CanCollide = false
	spawn.Parent = model
	for _, decal in ipairs(spawn:GetChildren()) do
		decal:Destroy()
	end
	plot.spawn = spawn

	plot.pedestalFolder = Instance.new("Folder")
	plot.pedestalFolder.Name = "Pedestals"
	plot.pedestalFolder.Parent = model
	plot.padFolder = Instance.new("Folder")
	plot.padFolder.Name = "Pads"
	plot.padFolder.Parent = model
	return plot
end

for i = 1, Config.PlotCount do
	plots[i] = createPlot(i)
end

-- Est-ce qu'une position est dans la base ?
local function inPlot(plot, position)
	local localPosition = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPosition.X) < 22.5 and math.abs(localPosition.Z) < 22.5 and localPosition.Y < 20
end

local renderPedestal -- défini juste en dessous

local function sellCreature(plot, index)
	local owner = plot.owner
	local data = owner and playerData[owner]
	local def = data and creaturesById[data.creatures[index]]
	local cash = owner and getCash(owner)
	if not def or not cash then
		return
	end
	data.creatures[index] = nil
	local price = def.income * Config.SellMultiplier
	cash.Value += price
	notify(owner, "Sold " .. def.name .. " for $" .. formatMoney(price))
	renderPedestal(plot, index)
end

function renderPedestal(plot, index)
	local old = plot.pedestalFolder:FindFirstChild("Pedestal" .. index)
	if old then
		old:Destroy()
	end
	local data = plot.owner and playerData[plot.owner]
	if not data then
		return
	end
	local spot = PEDESTAL_SPOTS[index]
	local model = Instance.new("Model")
	model.Name = "Pedestal" .. index
	model.Parent = plot.pedestalFolder
	local unlocked = index <= pedestalCount(data)
	local base = makePart(model, {
		Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 5.5, 5.5),
		CFrame = vertical(at(plot, spot.X, 0.5, spot.Z)),
		Color = unlocked and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(150, 150, 155),
		Material = Enum.Material.Metal, Transparency = unlocked and 0 or 0.6,
	})
	makePart(model, {
		Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 5.8, 5.8),
		CFrame = vertical(at(plot, spot.X, 0.9, spot.Z)), Color = unlocked and plot.color or Color3.fromRGB(120, 120, 120),
		Material = Enum.Material.Neon, CanCollide = false, Transparency = unlocked and 0 or 0.6,
	})
	if not unlocked then
		createBillboard(base, "LOCKED", "Buy PEDESTALS", 2, 6, Color3.fromRGB(180, 180, 180), 50)
		return
	end
	local def = creaturesById[data.creatures[index]]
	if not def then
		return
	end
	local creature = makeCreatureModel(def)
	creature:PivotTo(at(plot, spot.X, 1.1, spot.Z))
	creature.Parent = model
	makeBobbing(creature)
	creatureLabel(creature, def)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell $" .. formatMoney(def.income * Config.SellMultiplier)
	prompt.ObjectText = def.name
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerId", plot.owner.UserId)
	CollectionService:AddTag(prompt, "OwnerOnly")
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		if player == plot.owner then
			sellCreature(plot, index)
		end
	end)
end

local function renderPedestals(plot)
	plot.pedestalFolder:ClearAllChildren()
	for index in ipairs(PEDESTAL_SPOTS) do
		renderPedestal(plot, index)
	end
end

-- ============================================================
-- Améliorations (on marche sur le bouton pour acheter)
-- ============================================================

local function applySpeed(player)
	local humanoid = getHumanoid(player)
	local data = playerData[player]
	if humanoid and data then
		humanoid.WalkSpeed = 16 + upgradeLevel(data, "speed") * upgradesById.speed.perLevel
	end
end

local function padText(data, upgrade)
	local level = upgradeLevel(data, upgrade.id)
	local price = upgrade.prices[level + 1]
	if not price then
		return upgrade.name .. " MAX", "Level " .. level
	end
	return upgrade.name .. " Lv " .. level, upgrade.description .. "  ·  $" .. formatMoney(price)
end

local function refreshPads(plot)
	local data = plot.owner and playerData[plot.owner]
	for _, upgrade in ipairs(Config.Upgrades) do
		local pad = plot.padFolder:FindFirstChild(upgrade.id)
		if pad and data then
			setBillboard(pad:FindFirstChildOfClass("BillboardGui"), padText(data, upgrade))
		end
	end
end

local function updateCarryAttributes(player)
	local data = playerData[player]
	player:SetAttribute("Carrying", #(carrying[player] or {}))
	player:SetAttribute("CarryMax", carryMax(data))
end

local function buyUpgrade(player, upgrade)
	local data = playerData[player]
	local cash = getCash(player)
	if not data or not cash or not data.plot then
		return
	end
	local level = upgradeLevel(data, upgrade.id)
	local price = upgrade.prices[level + 1]
	if not price then
		notify(player, upgrade.name .. " is already maxed!")
		return
	end
	if cash.Value < price then
		notify(player, "Not enough cash! " .. upgrade.name .. " costs $" .. formatMoney(price))
		return
	end
	cash.Value -= price
	data.upgrades[upgrade.id] = level + 1
	notify(player, upgrade.name .. " upgraded to level " .. (level + 1) .. "!")
	applySpeed(player)
	updateCarryAttributes(player)
	if upgrade.id == "pedestals" then
		renderPedestals(data.plot)
	end
	refreshPads(data.plot)
end

local function buildPads(plot)
	plot.padFolder:ClearAllChildren()
	for _, upgrade in ipairs(Config.Upgrades) do
		local pad = makePart(plot.padFolder, {
			Name = upgrade.id, Size = Vector3.new(7, 0.6, 7), CFrame = at(plot, upgrade.pad.X, 0.3, upgrade.pad.Z),
			Color = Color3.fromRGB(60, 220, 110), Material = Enum.Material.Neon,
		})
		createBillboard(pad, "", "", 4, 11, Color3.new(1, 1, 1), 70)
		local cooldown = {}
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or player ~= plot.owner or (cooldown[player] and os.clock() < cooldown[player]) then
				return
			end
			cooldown[player] = os.clock() + 1.2
			buyUpgrade(player, upgrade)
		end)
	end
	refreshPads(plot)
end

-- ============================================================
-- Créatures sur le chemin : on les attrape et on les porte au-dessus de la tête
-- ============================================================

local creatureFolder = Instance.new("Folder")
creatureFolder.Name = "Critters"
creatureFolder.Parent = workspace

local groundCreatures = {} -- { def, model, zone, x }

local function removeGroundCreature(entry)
	entry.removed = true
	entry.model:Destroy()
	local position = table.find(groundCreatures, entry)
	if position then
		table.remove(groundCreatures, position)
	end
end

-- Mini-créatures empilées au-dessus de la tête de celui qui les porte
local function updateCarryVisual(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character then
		return
	end
	local old = character:FindFirstChild("CarriedCritters")
	if old then
		old:Destroy()
	end
	updateCarryAttributes(player)
	local list = carrying[player]
	if not head or not list or #list == 0 then
		return
	end
	local holder = Instance.new("Model")
	holder.Name = "CarriedCritters"
	holder.Parent = character
	local y = 1.2
	for _, id in ipairs(list) do
		local def = creaturesById[id]
		local creature = makeCreatureModel(def)
		creature:ScaleTo(0.6)
		local height = (creature:GetAttribute("Height") or 3) * 0.6
		creature:PivotTo(head.CFrame * CFrame.new(0, y, 0))
		creature.Parent = holder
		local root = creature.PrimaryPart
		root.Anchored = false
		root.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = root
		weld.Parent = root
		y += height
	end
end

local function grabCreature(player, entry)
	local data = playerData[player]
	if entry.removed or not data or not data.plot then
		return
	end
	local list = carrying[player] or {}
	carrying[player] = list
	if #list >= carryMax(data) then
		notify(player, "Your hands are full! Bring them back to your base (or upgrade CARRY).")
		return
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	removeGroundCreature(entry)
	table.insert(list, entry.def.id)
	updateCarryVisual(player)
	local rarity = raritiesById[entry.def.rarity]
	notify(player, "Got " .. entry.def.name .. " (" .. rarity.name .. ")! Run back to your base!")
	if rarityIndex[entry.def.rarity] >= 5 then
		notifyAll(player.Name .. " grabbed a " .. rarity.name .. " " .. entry.def.name .. "!")
	end
end

-- Tire une créature pour une zone (parfois de la rareté au-dessus)
local function rollCreature(zoneIndex)
	local level = zoneIndex
	if math.random() < Config.BetterRarityChance and Config.Rarities[level + 1] then
		level += 1
	end
	for i = level, 1, -1 do
		local list = creaturesByRarity[Config.Rarities[i].id]
		if #list > 0 then
			return list[math.random(#list)]
		end
	end
	return Config.Creatures[1]
end

local function nearTrench(x, margin)
	for _, range in ipairs(trenchRanges) do
		if x > range[1] - margin and x < range[2] + margin then
			return true
		end
	end
	return false
end

local function spawnCreature(zoneIndex, forcedDef)
	local zone = Config.Zones[zoneIndex]
	local x
	for _ = 1, 10 do
		local candidate = math.random(zone.from + 12, zone.to - 6)
		if not nearTrench(candidate, 6) then
			x = candidate
			break
		end
	end
	if not x then
		return
	end
	local def = forcedDef or rollCreature(zoneIndex)
	local model = makeCreatureModel(def)
	local z = math.random(-HALF_WIDTH + 6, HALF_WIDTH - 6)
	model:PivotTo(CFrame.new(x, 0.2, z) * CFrame.Angles(0, math.rad(math.random(-60, 60)) + math.pi / 2, 0))
	model.Parent = creatureFolder
	makeBobbing(model)
	creatureLabel(model, def)
	local entry = { def = def, model = model, zone = zoneIndex, x = x }
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = def.name .. " (" .. raritiesById[def.rarity].name .. ")"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		grabCreature(player, entry)
	end)
	table.insert(groundCreatures, entry)
	return entry
end

local function zoneCount(zoneIndex)
	local count = 0
	for _, entry in ipairs(groundCreatures) do
		if entry.zone == zoneIndex then
			count += 1
		end
	end
	return count
end

task.spawn(function()
	for zoneIndex in ipairs(Config.Zones) do
		for _ = 1, Config.CreaturesPerZone do
			spawnCreature(zoneIndex)
		end
	end
	while true do
		task.wait(Config.SpawnInterval)
		for zoneIndex in ipairs(Config.Zones) do
			if zoneCount(zoneIndex) < Config.CreaturesPerZone then
				spawnCreature(zoneIndex)
			end
		end
	end
end)

-- Ramène les créatures portées dans la base : chacune va sur un piédestal libre
local function deliver(player)
	local data = playerData[player]
	local list = carrying[player]
	if not data or not list or #list == 0 then
		return
	end
	local placed = 0
	for i = #list, 1, -1 do
		local free
		for index = 1, pedestalCount(data) do
			if not data.creatures[index] then
				free = index
				break
			end
		end
		if not free then
			break
		end
		local def = creaturesById[list[i]]
		data.creatures[free] = def.id
		table.remove(list, i)
		renderPedestal(data.plot, free)
		placed += 1
		notify(player, def.name .. " is now in your base: +$" .. formatMoney(def.income) .. "/s")
	end
	if #list > 0 and not data.fullWarned then
		data.fullWarned = true
		notify(player, "No free pedestal! Sell a critter (hold E on it) or buy PEDESTALS.")
	elseif #list == 0 then
		data.fullWarned = false
	end
	if placed > 0 then
		updateCarryVisual(player)
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		for player, data in pairs(playerData) do
			local root = getRoot(player)
			if root and data.plot and inPlot(data.plot, root.Position) then
				deliver(player)
			end
		end
	end
end)

-- ============================================================
-- La vague
-- ============================================================

workspace:SetAttribute("WaveState", "calm")
workspace:SetAttribute("WaveNextAt", workspace:GetServerTimeNow() + Config.WaveInterval)

local function pickWaveType()
	local total = 0
	for _, wave in ipairs(Config.WaveTypes) do
		total += wave.weight
	end
	local pick = math.random() * total
	for _, wave in ipairs(Config.WaveTypes) do
		pick -= wave.weight
		if pick <= 0 then
			return wave
		end
	end
	return Config.WaveTypes[1]
end

local function waveFront()
	local start = workspace:GetAttribute("WaveStart") or 0
	local speed = workspace:GetAttribute("WaveSpeed") or 40
	return Config.WaveStartX - speed * (workspace:GetServerTimeNow() - start)
end

local function loseCarried(player)
	if carrying[player] and #carrying[player] > 0 then
		local count = #carrying[player]
		carrying[player] = {}
		updateCarryVisual(player)
		notify(player, "You lost " .. count .. " critter(s)!")
	end
end

local function startWave(waveType)
	waveType = waveType or pickWaveType()
	workspace:SetAttribute("WaveName", waveType.name)
	workspace:SetAttribute("WaveSpeed", waveType.speed)
	workspace:SetAttribute("WaveHeight", waveType.height)
	workspace:SetAttribute("WaveColor", waveType.color)
	workspace:SetAttribute("WaveStart", workspace:GetServerTimeNow())
	workspace:SetAttribute("WaveState", "active")
end

RunService.Heartbeat:Connect(function()
	local state = workspace:GetAttribute("WaveState")
	local now = workspace:GetServerTimeNow()
	local nextAt = workspace:GetAttribute("WaveNextAt") or now
	if state == "calm" then
		if now >= nextAt - Config.WaveWarning then
			workspace:SetAttribute("WaveState", "warning")
		end
	elseif state == "warning" then
		if now >= nextAt then
			startWave()
		end
	elseif state == "active" then
		local front = waveFront()
		local back = front + Config.WaveThickness
		-- Les joueurs touchés (pas dans une tranchée, pas dans la zone sûre) sont emportés
		for _, player in ipairs(Players:GetPlayers()) do
			local root = getRoot(player)
			local humanoid = getHumanoid(player)
			if root and humanoid and humanoid.Health > 0 then
				local position = root.Position
				if position.X > 0 and position.X >= front - 2 and position.X <= back
					and position.Y > Config.SafeDepth then
					loseCarried(player)
					humanoid.Health = 0
					notify(player, "The " .. tostring(workspace:GetAttribute("WaveName")) .. " got you!")
				end
			end
		end
		-- Les créatures au sol sont emportées aussi (de nouvelles arrivent après)
		for i = #groundCreatures, 1, -1 do
			local entry = groundCreatures[i]
			if entry.x >= front and entry.x <= back then
				removeGroundCreature(entry)
			end
		end
		if front < -10 then
			workspace:SetAttribute("WaveState", "calm")
			workspace:SetAttribute("WaveNextAt", now + Config.WaveInterval)
		end
	end
end)

-- ============================================================
-- Sauvegarde
-- ============================================================

local dataStore = nil
if Config.SaveEnabled then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		dataStore = result
	else
		warn("[Tsunami] Sauvegarde désactivée (normal dans Studio si le jeu n'est pas publié) :", result)
	end
end

local function loadData(player)
	local data = { creatures = {}, upgrades = {}, cash = Config.StartingCash, loaded = true }
	if not dataStore then
		return data
	end
	local ok, saved = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)
	if not ok then
		warn("[Tsunami] Chargement impossible pour", player.Name, saved)
		data.loaded = false -- on ne sauvegardera pas : sinon on écraserait sa vraie partie
	elseif type(saved) == "table" then
		data.cash = tonumber(saved.cash) or data.cash
		if type(saved.upgrades) == "table" then
			for _, upgrade in ipairs(Config.Upgrades) do
				local level = tonumber(saved.upgrades[upgrade.id])
				if level then
					data.upgrades[upgrade.id] = math.clamp(math.floor(level), 0, #upgrade.prices)
				end
			end
		end
		if type(saved.creatures) == "table" then
			for _, item in ipairs(saved.creatures) do
				if type(item) == "table" and creaturesById[item.id] and PEDESTAL_SPOTS[item.index] then
					data.creatures[item.index] = item.id
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
	local creatures = {}
	for index, id in pairs(data.creatures) do
		table.insert(creatures, { index = index, id = id })
	end
	local ok, err = pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, {
			cash = cash.Value,
			upgrades = data.upgrades,
			creatures = creatures,
		})
	end)
	if not ok then
		warn("[Tsunami] Sauvegarde impossible pour", player.Name, err)
	end
end

-- ============================================================
-- Arrivée / départ des joueurs
-- ============================================================

local function spawnCharacter(player)
	if not player.Parent then
		return
	end
	player:LoadCharacter()
end

local function onCharacterAdded(player, character)
	carrying[player] = {}
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	applySpeed(player)
	updateCarryAttributes(player)
	-- Toujours apparaître dans sa propre base
	local data = playerData[player]
	if data and data.plot then
		task.defer(function()
			if character.Parent then
				character:PivotTo(data.plot.spawn.CFrame + Vector3.new(0, 4, 0))
			end
		end)
	end
	humanoid.Died:Connect(function()
		carrying[player] = {}
		updateCarryAttributes(player)
		task.delay(3, function()
			if player.Character == character then
				spawnCharacter(player)
			end
		end)
	end)
end

local function onPlayerAdded(player)
	local data = loadData(player)
	if not player.Parent then
		return
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = leaderstats
	leaderstats.Parent = player

	local plot
	for _, candidate in ipairs(plots) do
		if not candidate.owner then
			plot = candidate
			break
		end
	end
	playerData[player] = data
	carrying[player] = {}
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if not plot then
		warn("[Tsunami] Plus de base libre pour", player.Name)
		spawnCharacter(player)
		return
	end
	plot.owner = player
	data.plot = plot
	player.RespawnLocation = plot.spawn
	setBillboard(plot.sign, player.Name .. "'s BASE", "")
	renderPedestals(plot)
	buildPads(plot)
	updateCarryAttributes(player)
	spawnCharacter(player)
	notify(player, "Grab critters on the path and bring them back. When the TSUNAMI comes, hide in a trench!")
end

local function onPlayerRemoving(player)
	saveData(player)
	local data = playerData[player]
	if data and data.plot then
		local plot = data.plot
		plot.owner = nil
		plot.pedestalFolder:ClearAllChildren()
		plot.padFolder:ClearAllChildren()
		setBillboard(plot.sign, "FREE BASE", "")
	end
	playerData[player] = nil
	carrying[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)

-- Revenus : chaque créature exposée rapporte de l'argent chaque seconde
task.spawn(function()
	while true do
		task.wait(1)
		for player, data in pairs(playerData) do
			local cash = getCash(player)
			if cash then
				local income = 0
				for _, id in pairs(data.creatures) do
					local def = creaturesById[id]
					if def then
						income += def.income
					end
				end
				if income > 0 then
					cash.Value += income
				end
				player:SetAttribute("Income", income)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveData, player)
		end
	end
end)

-- ============================================================
-- Panneau de test (Studio uniquement)
-- ============================================================

if RunService:IsStudio() then
	local testEvent = Instance.new("RemoteEvent")
	testEvent.Name = "TestCommand"
	testEvent.Parent = ReplicatedStorage
	testEvent.OnServerEvent:Connect(function(player, command, amount)
		if typeof(command) ~= "string" or typeof(amount) ~= "number" then
			return
		end
		local cash = getCash(player)
		if command == "addcash" and cash then
			cash.Value += math.floor(amount)
		elseif command == "wavenow" then
			if workspace:GetAttribute("WaveState") ~= "active" then
				workspace:SetAttribute("WaveState", "warning")
				workspace:SetAttribute("WaveNextAt", workspace:GetServerTimeNow() + 3)
			end
		elseif command == "spawnrarity" then
			-- Fait apparaître une créature de cette rareté au début du chemin
			local rarity = Config.Rarities[amount]
			local list = rarity and creaturesByRarity[rarity.id]
			if list and #list > 0 then
				spawnCreature(1, list[math.random(#list)])
				notify(player, "Test: a " .. rarity.name .. " critter appeared in the COMMON zone")
			end
		end
	end)
end
