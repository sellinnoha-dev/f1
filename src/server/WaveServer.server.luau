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
local ItemModels = require(ReplicatedStorage:WaitForChild("ItemModels"))

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
	if player and player.Parent and player:IsA("Player") then
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
		label.Font = Enum.Font.FredokaOne
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

-- Les bots sont de faux joueurs (un dossier + un personnage) : ces petites
-- fonctions marchent pour les deux
local botCharacters = {} -- [bot] = son personnage

local function characterOf(owner)
	if not owner then
		return nil
	end
	if owner:IsA("Player") then
		return owner.Character
	end
	return botCharacters[owner]
end

local function ownerId(owner)
	if owner:IsA("Player") then
		return owner.UserId
	end
	return -(owner:GetAttribute("BotId") or 1)
end

-- Tous ceux qui jouent : les vrais joueurs + les bots
local function allAgents()
	local list = Players:GetPlayers()
	for bot in pairs(botCharacters) do
		table.insert(list, bot)
	end
	return list
end

local function getRoot(player)
	local character = characterOf(player)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local character = characterOf(player)
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

	if extras.cape then
		piece({ Name = "Cape", Size = Vector3.new(s * 0.95, height * 0.85, s * 0.08),
			CFrame = CFrame.new(0, height * 0.48, s * 0.5) * CFrame.Angles(math.rad(-10), 0, 0),
			Color = accent, Material = Enum.Material.Fabric })
		piece({ Name = "CapeClasp", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.16,
			CFrame = CFrame.new(0, height * 0.88, s * 0.4), Color = Color3.fromRGB(255, 200, 30), Material = Enum.Material.Metal })
	end
	if extras.staff then
		piece({ Name = "Staff", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height * 1.4, s * 0.1, s * 0.1),
			CFrame = vertical(CFrame.new(s * 0.72, height * 0.7, -s * 0.1)), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood })
		local orb = piece({ Name = "StaffOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.32,
			CFrame = CFrame.new(s * 0.72, height * 1.42, -s * 0.1), Color = accent, Material = Enum.Material.Neon })
		local orbLight = Instance.new("PointLight")
		orbLight.Color = accent
		orbLight.Range = 8
		orbLight.Parent = orb
	end
	if extras.monocle then
		piece({ Name = "Monocle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.03, s * 0.36, s * 0.36),
			CFrame = CFrame.new(eyeX[#eyeX] * s, eyeY, front - s * 0.17) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(255, 200, 30), Material = Enum.Material.Glass, Transparency = 0.4 })
	end
	if extras.tail then
		piece({ Name = "Tail", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.7, s * 0.18, s * 0.18),
			CFrame = CFrame.new(0, height * 0.25, s * 0.65) * CFrame.Angles(0, math.rad(90), math.rad(30)), Color = look.color })
		piece({ Name = "TailTip", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.28,
			CFrame = CFrame.new(0, height * 0.42, s * 0.95), Color = accent, Material = Enum.Material.Neon })
	end
	if extras.flames then
		local burner = piece({ Name = "Burner", Size = Vector3.one * s * 0.3, CFrame = CFrame.new(0, height * 0.45, s * 0.7),
			Transparency = 1 })
		local fire = Instance.new("Fire")
		fire.Color = accent
		fire.SecondaryColor = Color3.fromRGB(255, 240, 120)
		fire.Size = s * 0.9
		fire.Heat = 8
		fire.Parent = burner
	end
	if extras.orbit then
		for i = 0, 3 do
			local angle = i / 4 * 2 * math.pi
			piece({ Name = "OrbitGem", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.2,
				CFrame = CFrame.new(math.cos(angle) * s * 0.9, height * 0.5 + math.sin(angle * 2) * s * 0.2, math.sin(angle) * s * 0.9),
				Color = accent, Material = Enum.Material.Neon })
		end
	end

	-- Effets des grandes raretés : plus c'est rare, plus ça brille
	local level = rarityIndex[def.rarity] or 1
	local function emitter(texture, color, rate, size, speed, lifetime)
		local particles = Instance.new("ParticleEmitter")
		particles.Texture = texture
		particles.Color = ColorSequence.new(color)
		particles.Rate = rate
		particles.Size = NumberSequence.new(size, 0)
		particles.Speed = NumberRange.new(speed * 0.5, speed)
		particles.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.LightEmission = 1
		particles.Parent = body
		return particles
	end
	if level >= 4 then
		-- Disque lumineux sous les pieds + paillettes + lumière
		piece({ Name = "GlowDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, s * (level >= 5 and 1.9 or 1.5), s * (level >= 5 and 1.9 or 1.5)),
			CFrame = vertical(CFrame.new(0, 0.06, 0)), Color = rarity.color, Material = Enum.Material.Neon, Transparency = 0.35 })
		emitter("rbxasset://textures/particles/sparkles_main.dds", rarity.color, 8, s * 0.25, 2, 1.5)
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 12
		light.Brightness = 2.5
		light.Parent = body
	end
	if level >= 5 then
		-- Aura qui monte autour de la créature
		local aura = emitter("rbxasset://textures/particles/smoke_main.dds", rarity.color, 12, s * 0.5, 3, 1.4)
		aura.EmissionDirection = Enum.NormalId.Top
		aura.SpreadAngle = Vector2.new(25, 25)
		aura.Transparency = NumberSequence.new(0.5, 1)
	end
	if level >= 6 then
		piece({ Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 1.7, CFrame = CFrame.new(0, height * 0.5, 0),
			Color = rarity.color, Material = Enum.Material.ForceField, Transparency = 0 })
	end
	if def.rarity == "divine" then
		-- Divine : bulle arc-en-ciel, anneaux, tempête de paillettes (les couleurs bougent côté joueur)
		piece({ Name = "Aura", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 2.2, CFrame = CFrame.new(0, height * 0.5, 0),
			Color = Color3.fromRGB(255, 120, 255), Material = Enum.Material.ForceField, Transparency = 0 })
		for i, tilt in ipairs({ 20, -25 }) do
			piece({ Name = "Aura", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, s * (1.5 + i * 0.3), s * (1.5 + i * 0.3)),
				CFrame = CFrame.new(0, height * 0.5, 0) * CFrame.Angles(math.rad(tilt), 0, math.rad(90)),
				Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.25 })
		end
		emitter("rbxasset://textures/particles/sparkles_main.dds", Color3.new(1, 1, 1), 40, s * 0.35, 6, 2)
		CollectionService:AddTag(model, "Divine")
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
	-- Marches des deux côtés pour sortir (on saute dessus puis dehors)
	for _, x in ipairs({ range[1] + 2, range[2] - 2 }) do
		makePart(map, {
			Name = "TrenchStep", Size = Vector3.new(4, depth / 2, Config.PathWidth),
			CFrame = CFrame.new(x, -depth + depth / 4, 0),
			Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Slate,
		})
	end
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
local carrying = {} -- [player] = { { id, owner = joueur volé ou nil }... }
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

-- Game Pass possédé ? (les bots n'en ont jamais)
local function hasPass(owner, key)
	return owner ~= nil and owner:GetAttribute("Pass_" .. key) == true
end

local function carryMax(data, owner)
	local bonus = (owner and hasPass(owner, "carry")) and 2 or 0
	return 1 + upgradeLevel(data, "carry") * upgradesById.carry.perLevel + bonus
end

-- Infos pour l'écran du joueur (menus UPGRADES et INDEX)
local function syncStats(owner)
	local data = playerData[owner]
	if not data then
		return
	end
	for _, upgrade in ipairs(Config.Upgrades) do
		owner:SetAttribute("Up_" .. upgrade.id, upgradeLevel(data, upgrade.id))
	end
	owner:SetAttribute("Best", data.best or 0)
	local found = {}
	for id in pairs(data.discovered or {}) do
		table.insert(found, id)
	end
	owner:SetAttribute("Discovered", table.concat(found, ","))
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
		-- Murs de côté : trop hauts pour sauter par-dessus
		makePart(model, {
			Name = "SideWall", Size = Vector3.new(1, 12, 44), CFrame = at(plot, x, 6, 0),
			Color = Color3.fromRGB(200, 225, 240), Material = Enum.Material.Glass, Transparency = 0.45,
		})
		makePart(model, {
			Name = "WallTrim", Size = Vector3.new(1.4, 0.6, 44.6), CFrame = at(plot, x, 12.2, 0),
			Color = plot.color, Material = Enum.Material.Neon,
		})
	end
	-- Mur d'énergie à l'entrée : il bloque tout le monde, sauf le propriétaire et
	-- ceux qui ont une Raid Key active (la collision est réglée chez chaque joueur, voir WaveClient)
	for _, x in ipairs({ -22.5, 22.5 }) do
		makePart(model, {
			Name = "GatePost", Size = Vector3.new(1.6, 13, 1.6), CFrame = at(plot, x, 6.5, -22.5),
			Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal,
		})
	end
	plot.barrier = makePart(model, {
		Name = "Barrier", Size = Vector3.new(44, 12, 0.6), CFrame = at(plot, 0, 6, -22.5),
		Color = plot.color, Material = Enum.Material.ForceField, Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	})
	plot.barrier:SetAttribute("OwnerId", 0)
	CollectionService:AddTag(plot.barrier, "BaseBarrier")
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
local tryStealCritter -- défini plus bas (partie "Objets et vol")

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
	prompt:SetAttribute("OwnerId", ownerId(plot.owner))
	CollectionService:AddTag(prompt, "OwnerOnly")
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		if player == plot.owner then
			sellCreature(plot, index)
		end
	end)

	-- Les autres joueurs (avec une Raid Key active) peuvent la voler
	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.ActionText = "STEAL"
	stealPrompt.ObjectText = def.name
	stealPrompt.HoldDuration = 1.5
	stealPrompt.MaxActivationDistance = 9
	stealPrompt.RequiresLineOfSight = false
	stealPrompt:SetAttribute("OwnerId", ownerId(plot.owner))
	CollectionService:AddTag(stealPrompt, "ThiefOnly")
	stealPrompt.Parent = base
	stealPrompt.Triggered:Connect(function(player)
		if player ~= plot.owner then
			tryStealCritter(player, plot, index)
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
			+ (hasPass(player, "speed") and 8 or 0)
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
	player:SetAttribute("CarryMax", carryMax(data, player))
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
	syncStats(player)
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
	local character = characterOf(player)
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
	for _, carried in ipairs(list) do
		local def = creaturesById[carried.id]
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
	if #list >= carryMax(data, player) then
		notify(player, "Your hands are full! Bring them back to your base (or upgrade CARRY).")
		return
	end
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	removeGroundCreature(entry)
	table.insert(list, { id = entry.def.id })
	if data.discovered and not data.discovered[entry.def.id] then
		data.discovered[entry.def.id] = true
		notify(player, "NEW critter discovered: " .. entry.def.name .. "! (check your INDEX)")
		syncStats(player)
	end
	updateCarryVisual(player)
	local rarity = raritiesById[entry.def.rarity]
	notify(player, "Got " .. entry.def.name .. " (" .. rarity.name .. ")! Run back to your base!")
	if entry.divine then
		notifyAll(player.Name .. " caught the DIVINE " .. entry.def.name .. "!!!")
		workspace:SetAttribute("DivineAt", 0)
	elseif rarityIndex[entry.def.rarity] >= 5 then
		notifyAll(player.Name .. " grabbed a " .. rarity.name .. " " .. entry.def.name .. "!")
	end
end

-- Tire une créature pour une zone selon les chances de chaque rareté
local function rollCreature(zoneIndex)
	local chances = Config.Zones[zoneIndex].chances or { [Config.Zones[zoneIndex].rarity] = 1 }
	local total = 0
	for _, weight in pairs(chances) do
		total += weight
	end
	local pick = math.random() * total
	local rarityId = Config.Zones[zoneIndex].rarity
	for _, rarity in ipairs(Config.Rarities) do
		local weight = chances[rarity.id]
		if weight then
			pick -= weight
			if pick <= 0 then
				rarityId = rarity.id
				break
			end
		end
	end
	-- Aucune créature de cette rareté ? On descend d'un cran
	for i = rarityIndex[rarityId], 1, -1 do
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

local placeGroundCreature -- défini juste en dessous
local function spawnCreature(zoneIndex, forcedDef, fromX, toX)
	local zone = Config.Zones[zoneIndex]
	local x
	for _ = 1, 10 do
		local candidate = math.random(fromX or (zone.from + 12), toX or (zone.to - 6))
		if not nearTrench(candidate, 6) then
			x = candidate
			break
		end
	end
	if not x then
		return
	end
	local def = forcedDef or rollCreature(zoneIndex)
	local z = math.random(-HALF_WIDTH + 6, HALF_WIDTH - 6)
	return placeGroundCreature(def, Vector3.new(x, 0.2, z), zoneIndex)
end

-- Pose une créature au sol (attrapable avec E)
function placeGroundCreature(def, position, zoneIndex)
	local model = makeCreatureModel(def)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(math.random(-60, 60)) + math.pi / 2, 0))
	model.Parent = creatureFolder
	local x = position.X
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

-- Remplit toutes les zones (au lancement et après chaque vague : nouvelles créatures)
local function refillAll()
	for zoneIndex, zone in ipairs(Config.Zones) do
		for _ = zoneCount(zoneIndex) + 1, zone.count or 4 do
			spawnCreature(zoneIndex)
		end
	end
end

-- La créature DIVINE : aura, colonne de lumière, annonce à tout le serveur
local function spawnDivine(forcedDef)
	local list = creaturesByRarity.divine
	if not list or #list == 0 then
		return
	end
	local def = forcedDef or list[math.random(#list)]
	local entry = spawnCreature(1, def, 25, 70)
	if not entry then
		return
	end
	entry.divine = true
	local root = entry.model.PrimaryPart
	local function auraPart(props)
		props.Anchored = false
		props.CanCollide = false
		props.CanTouch = false
		props.CanQuery = false
		props.CastShadow = false
		props.Massless = true
		local part = makePart(entry.model, props)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	-- Colonne de lumière visible de loin
	auraPart({ Name = "Aura", Shape = Enum.PartType.Cylinder, Size = Vector3.new(300, 3, 3),
		CFrame = vertical(CFrame.new(root.Position + Vector3.new(0, 150, 0))), Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255), Transparency = 0.55 })
	workspace:SetAttribute("DivineName", def.name)
	workspace:SetAttribute("DivineAt", workspace:GetServerTimeNow())
	notifyAll("A DIVINE " .. def.name .. " appeared right in front of the bases!!!")
	return entry
end

task.spawn(function()
	refillAll()
	while true do
		task.wait(Config.SpawnInterval)
		for zoneIndex, zone in ipairs(Config.Zones) do
			if zoneCount(zoneIndex) < (zone.count or 4) then
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
		local carried = list[i]
		local def = creaturesById[carried.id]
		data.creatures[free] = def.id
		table.remove(list, i)
		renderPedestal(data.plot, free)
		placed += 1
		data.best = math.max(data.best or 0, rarityIndex[def.rarity])
		notify(player, def.name .. " is now in your base: +$" .. formatMoney(def.income) .. "/s")
		if carried.owner then
			notify(carried.owner, player.Name .. " stole your " .. def.name .. "!")
		end
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

-- Rend une créature à son propriétaire (place libre, sinon il touche son prix de vente)
local function giveBack(owner, id)
	local data = owner and owner.Parent and playerData[owner]
	local def = creaturesById[id]
	if not data or not def then
		return
	end
	for index = 1, pedestalCount(data) do
		if not data.creatures[index] then
			data.creatures[index] = id
			renderPedestal(data.plot, index)
			notify(owner, "Your " .. def.name .. " is back!")
			return
		end
	end
	local cash = getCash(owner)
	if cash then
		cash.Value += def.income * Config.SellMultiplier
	end
end

local function loseCarried(player)
	local list = carrying[player]
	if list and #list > 0 then
		carrying[player] = {}
		for _, carried in ipairs(list) do
			if carried.owner then
				giveBack(carried.owner, carried.id)
			end
		end
		updateCarryVisual(player)
		notify(player, "You lost " .. #list .. " critter(s)!")
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
		for _, player in ipairs(allAgents()) do
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
			-- Après la vague : toutes nouvelles créatures, et peut-être une DIVINE
			task.spawn(function()
				refillAll()
				if math.random() < Config.DivineChance then
					spawnDivine()
				end
			end)
		end
	end
end)


-- ============================================================
-- Objets et vol : cape d'invisibilité, rayon gelant, clé de raid
-- ============================================================

local raidUntil = {} -- [joueur] = os.clock() de fin de la clé de raid
local itemsById = {}
for _, item in ipairs(Config.Items) do
	itemsById[item.id] = item
end

local function raidActive(player)
	return os.clock() < (raidUntil[player] or 0)
end

function tryStealCritter(thief, plot, index)
	local victim = plot.owner
	local victimData = victim and playerData[victim]
	local thiefData = playerData[thief]
	local def = victimData and creaturesById[victimData.creatures[index]]
	if not def or not thiefData or not thiefData.plot or thiefData.plot == plot then
		return
	end
	if not raidActive(thief) then
		notify(thief, "You need an active Raid Key to steal!")
		return
	end
	local list = carrying[thief] or {}
	carrying[thief] = list
	if #list >= carryMax(thiefData, thief) then
		notify(thief, "Your hands are full!")
		return
	end
	victimData.creatures[index] = nil
	renderPedestal(plot, index)
	table.insert(list, { id = def.id, owner = victim })
	updateCarryVisual(thief)
	notify(thief, "You stole " .. def.name .. "! Run back to your base!")
	notify(victim, thief.Name .. " is stealing your " .. def.name .. "! Freeze them!")
end

-- Les bases sont protégées : sans clé de raid, on est repoussé dehors
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, plot in ipairs(plots) do
			if plot.owner then
				for _, player in ipairs(allAgents()) do
					local root = player ~= plot.owner and getRoot(player)
					if root and inPlot(plot, root.Position) and not raidActive(player) then
						characterOf(player):PivotTo(at(plot, 0, 4, -32))
						notify(player, "This base is protected! (a Raid Key lets you in)")
					end
				end
			end
		end
	end
end)

-- Petit nuage de fumée (disparition / réapparition)
local function poof(position, color)
	local holder = makePart(workspace, {
		Name = "Poof", Size = Vector3.one, CFrame = CFrame.new(position), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false,
	})
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(color)
	smoke.Size = NumberSequence.new(3, 6)
	smoke.Transparency = NumberSequence.new(0.2, 1)
	smoke.Lifetime = NumberRange.new(0.6, 1)
	smoke.Speed = NumberRange.new(6, 12)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Rate = 0
	smoke.Parent = holder
	smoke:Emit(40)
	task.delay(2, function()
		holder:Destroy()
	end)
end

-- Rend un personnage invisible pour les autres (sauf les créatures qu'il porte)
local invisibleUntil = {} -- [joueur] = os.clock() de fin
local function setInvisible(player, invisible)
	local character = characterOf(player)
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if (descendant:IsA("BasePart") or descendant:IsA("Decal")) and descendant.Name ~= "HumanoidRootPart"
			and not descendant:FindFirstAncestor("CarriedCritters") then
			if invisible then
				if descendant:GetAttribute("OriginalTransparency") == nil then
					descendant:SetAttribute("OriginalTransparency", descendant.Transparency)
				end
				descendant.Transparency = 1
			elseif descendant:GetAttribute("OriginalTransparency") ~= nil then
				descendant.Transparency = descendant:GetAttribute("OriginalTransparency")
				descendant:SetAttribute("OriginalTransparency", nil)
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = invisible and Enum.HumanoidDisplayDistanceType.None
			or Enum.HumanoidDisplayDistanceType.Viewer
	end
	local root = getRoot(player)
	if root then
		poof(root.Position, Color3.fromRGB(190, 160, 255))
	end
	if invisible then
		player:SetAttribute("InvisibleUntil", workspace:GetServerTimeNow() + itemsById.cloak.duration)
	else
		invisibleUntil[player] = nil
		player:SetAttribute("InvisibleUntil", 0)
	end
end

local function freezePlayer(target, duration)
	local root = getRoot(target)
	if not root then
		return
	end
	root.Anchored = true
	target:SetAttribute("FrozenUntil", workspace:GetServerTimeNow() + duration)
	local ice = makePart(workspace, {
		Name = "Ice", Size = Vector3.new(5, 7, 5), CFrame = root.CFrame * CFrame.new(0, -0.5, 0),
		Color = Color3.fromRGB(150, 230, 255), Material = Enum.Material.Ice, Transparency = 0.35,
		CanCollide = false, CanQuery = false,
	})
	task.delay(duration, function()
		ice:Destroy()
		if root.Parent then
			root.Anchored = false
		end
	end)
end

-- Rayon de glace visible entre le tireur et la cible
local function iceBeam(from, to)
	local distance = (to - from).Magnitude
	local beam = makePart(workspace, {
		Name = "IceBeam", Size = Vector3.new(0.5, 0.5, distance),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2),
		Color = Color3.fromRGB(120, 240, 255), Material = Enum.Material.Neon,
		CanCollide = false, CanQuery = false, CanTouch = false,
	})
	task.delay(0.35, function()
		beam:Destroy()
	end)
end

-- Utiliser un objet : renvoie true s'il a servi (on en retire alors un du stock)
local function useItem(player, item)
	local character = characterOf(player)
	local root = getRoot(player)
	local humanoid = getHumanoid(player)
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if item.id == "cloak" then
		if invisibleUntil[player] then
			notify(player, "You are already invisible!")
			return false
		end
		local untilTime = os.clock() + item.duration
		invisibleUntil[player] = untilTime
		setInvisible(player, true)
		notify(player, "You are invisible for " .. item.duration .. "s! (press REAPPEAR to come back)")
		task.delay(item.duration, function()
			if invisibleUntil[player] == untilTime and characterOf(player) == character then
				setInvisible(player, false)
				notify(player, "You are visible again.")
			end
		end)
		return true
	elseif item.id == "freeze" then
		local target, best = nil, item.range
		for _, other in ipairs(allAgents()) do
			local otherRoot = other ~= player and getRoot(other)
			local otherHumanoid = otherRoot and getHumanoid(other)
			if otherHumanoid and otherHumanoid.Health > 0 then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance < best then
					target, best = other, distance
				end
			end
		end
		if not target then
			notify(player, "Nobody close enough to freeze (" .. item.range .. " studs)!")
			return false
		end
		iceBeam(root.Position, getRoot(target).Position)
		freezePlayer(target, item.duration)
		notify(player, "You froze " .. target.Name .. "!")
		notify(target, player.Name .. " froze you!")
		return true
	elseif item.id == "raidkey" then
		raidUntil[player] = os.clock() + item.duration
		player:SetAttribute("RaidUntil", workspace:GetServerTimeNow() + item.duration)
		notify(player, "Raid Key active for " .. item.duration .. "s: walk through a base's energy wall and hold E on a critter!")
		return true
	end
	return false
end

local MAX_ITEMS = 3

-- Position du modèle dans la main : la pointe vers l'avant (+Z), la poignée au centre
local HOLD = {
	cloak = CFrame.new(0, -1.45, 0),
	freeze = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0.6, 0.75, 0),
	raidkey = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(1, 0, 0),
}

local syncItemTools -- défini juste en dessous

-- Un vrai objet Roblox (Tool) avec le modèle 3D de l'objet dans la main
local function makeItemTool(player, item)
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.ToolTip = item.description
	tool:SetAttribute("ItemId", item.id)
	tool.GripPos = Vector3.zero
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	local model = ItemModels.build(item.id)
	model:PivotTo(HOLD[item.id] or CFrame.new())
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
			part.Parent = tool
		end
	end
	model:Destroy()
	local busy = false
	tool.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local data = playerData[player]
		if item.id == "cloak" and invisibleUntil[player] then
			setInvisible(player, false) -- recliquer avec la cape = réapparaître
		elseif data and (data.items[item.id] or 0) > 0 and useItem(player, item) then
			data.items[item.id] -= 1
			syncItemTools(player)
		end
		busy = false
	end)
	return tool
end

-- Met la barre d'outils à jour : un outil par objet possédé, avec la quantité dans le nom
function syncItemTools(player)
	local data = playerData[player]
	if not data or not player:IsA("Player") then
		return
	end
	local backpack = player:FindFirstChild("Backpack")
	for _, item in ipairs(Config.Items) do
		local count = data.items[item.id] or 0
		player:SetAttribute("Item_" .. item.id, count)
		local tool
		for _, container in ipairs({ backpack, player.Character }) do
			if container then
				for _, child in ipairs(container:GetChildren()) do
					if child:IsA("Tool") and child:GetAttribute("ItemId") == item.id then
						tool = child
					end
				end
			end
		end
		if count > 0 then
			if not tool and backpack then
				tool = makeItemTool(player, item)
				tool.Parent = backpack
			end
			if tool then
				tool.Name = item.name .. " x" .. count
			end
		elseif tool then
			tool:Destroy()
		end
	end
end

local function setItemCount(player, itemId, count)
	local data = playerData[player]
	if data then
		data.items[itemId] = count
		syncItemTools(player)
	end
end

local function buyItem(player, item)
	local data = playerData[player]
	local cash = getCash(player)
	if not data or not cash then
		return
	end
	local needed = rarityIndex[item.requires] or 1
	if (data.best or 0) < needed then
		notify(player, item.name .. " is locked: get a " .. raritiesById[item.requires].name .. " critter first!")
		return
	end
	local count = data.items[item.id] or 0
	if count >= MAX_ITEMS then
		notify(player, "You can't carry more than " .. MAX_ITEMS .. " " .. item.name .. "s!")
		return
	end
	if cash.Value < item.price then
		notify(player, "Not enough cash! " .. item.name .. " costs $" .. formatMoney(item.price))
		return
	end
	cash.Value -= item.price
	setItemCount(player, item.id, count + 1)
	notify(player, "You bought a " .. item.name .. "! It's in your toolbar, next to your bat.")
end

-- Le joueur clique sur un objet de sa barre (ou appuie sur 1, 2, 3)
local useEvent = Instance.new("RemoteEvent")
useEvent.Name = "UseItem"
useEvent.Parent = ReplicatedStorage
local lastUse = {}
useEvent.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" then
		return
	end
	if itemId == "reappear" then
		if invisibleUntil[player] then
			setInvisible(player, false)
		end
		return
	end
	local item = itemsById[itemId]
	local data = playerData[player]
	if not item or not data or (data.items[itemId] or 0) <= 0 then
		return
	end
	if os.clock() < (lastUse[player] or 0) then
		return
	end
	lastUse[player] = os.clock() + 0.5
	if useItem(player, item) then
		setItemCount(player, itemId, (data.items[itemId] or 1) - 1)
	end
end)

-- La boutique, au fond de la zone des bases
do
	local shopX = -200
	makePart(map, {
		Name = "ShopFloor", Size = Vector3.new(18, 0.4, 34), CFrame = CFrame.new(shopX, 0.2, 0),
		Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal,
	})
	makePart(map, {
		Name = "ShopRoof", Size = Vector3.new(18, 1, 34), CFrame = CFrame.new(shopX, 14, 0),
		Color = Color3.fromRGB(80, 60, 160), Material = Enum.Material.SmoothPlastic,
	})
	for _, z in ipairs({ -16, 16 }) do
		for _, x in ipairs({ -8, 8 }) do
			makePart(map, {
				Name = "ShopPost", Size = Vector3.new(1, 14, 1), CFrame = CFrame.new(shopX + x, 7, z),
				Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon,
			})
		end
	end
	local sign = makePart(map, {
		Name = "ShopSign", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(shopX, 18, 0),
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	createBillboard(sign, "ITEM SHOP", "Unlocked by your rarest critter", 0, 18, Color3.fromRGB(255, 200, 40), 250)
	for i, item in ipairs(Config.Items) do
		local z = (i - (#Config.Items + 1) / 2) * 10
		local stand = makePart(map, {
			Name = "Stand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 4, 4),
			CFrame = vertical(CFrame.new(shopX, 1.5, z)), Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.Metal,
		})
		makePart(map, {
			Name = "StandRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 4.3, 4.3),
			CFrame = vertical(CFrame.new(shopX, 3, z)), Color = item.color, Material = Enum.Material.Neon, CanCollide = false,
		})
		-- Le modèle de l'objet flotte et tourne au-dessus du socle
		local display = ItemModels.build(item.id, true)
		display:ScaleTo(1.4)
		display:PivotTo(CFrame.new(shopX, 5.5, z))
		display.Parent = map
		makeBobbing(display)
		createBillboard(display.PrimaryPart, item.name, "$" .. formatMoney(item.price) .. "  ·  needs " .. raritiesById[item.requires].name,
			3, 11, item.color, 60)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy $" .. formatMoney(item.price)
		prompt.ObjectText = item.name .. " - " .. item.description
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = stand
		prompt.Triggered:Connect(function(player)
			buyItem(player, item)
		end)
	end
end


-- ============================================================
-- La batte : chaque joueur l'a. Frapper quelqu'un qui porte des créatures
-- le renvoie dans sa base, et il lâche ce qu'il portait.
-- ============================================================

local function zoneAt(x)
	for index, zone in ipairs(Config.Zones) do
		if x >= zone.from and x < zone.to then
			return index
		end
	end
	return 1
end

-- Les créatures portées tombent par terre (les volées retournent chez leur propriétaire)
local function dropCarried(player, position)
	local list = carrying[player]
	if not list or #list == 0 then
		return 0
	end
	carrying[player] = {}
	for i, carried in ipairs(list) do
		if carried.owner then
			giveBack(carried.owner, carried.id)
		else
			local x = math.max(position.X, 5)
			local spot = Vector3.new(x + (i - 1) * 4, 0.2, math.clamp(position.Z, -HALF_WIDTH + 4, HALF_WIDTH - 4))
			placeGroundCreature(creaturesById[carried.id], spot, zoneAt(x))
		end
	end
	updateCarryVisual(player)
	return #list
end

local function sendHome(player)
	local data = playerData[player]
	local root = getRoot(player)
	if data and data.plot and root then
		poof(root.Position, Color3.fromRGB(255, 255, 255))
		characterOf(player):PivotTo(data.plot.spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

-- Petites étoiles qui jaillissent quand on se fait frapper
local function hitStars(position)
	local holder = makePart(workspace, {
		Name = "Bonk", Size = Vector3.one, CFrame = CFrame.new(position), Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false,
	})
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80))
	stars.Size = NumberSequence.new(1.5, 0)
	stars.Lifetime = NumberRange.new(0.4, 0.8)
	stars.Speed = NumberRange.new(10, 20)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.LightEmission = 1
	stars.Rate = 0
	stars.Parent = holder
	stars:Emit(30)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_jump_land.mp3"
	sound.Volume = 2
	sound.PlaybackSpeed = 0.8
	sound.Parent = holder
	sound:Play()
	task.delay(2, function()
		holder:Destroy()
	end)
end

-- Mouvement du bras : élan vers le haut, puis gros coup vers l'avant
local TweenService = game:GetService("TweenService")
local function swingArm(character)
	local shoulder = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
	if not shoulder or not shoulder:IsA("Motor6D") then
		return
	end
	local original = shoulder:GetAttribute("OriginalC0")
	if not original then
		original = shoulder.C0
		shoulder:SetAttribute("OriginalC0", original)
	end
	local r15 = shoulder.Name == "RightShoulder"
	local function pose(degrees)
		local angle = math.rad(degrees)
		return original * (r15 and CFrame.Angles(angle, 0, 0) or CFrame.Angles(0, 0, angle))
	end
	task.spawn(function()
		local windup = TweenService:Create(shoulder, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = pose(75) })
		windup:Play()
		windup.Completed:Wait()
		local smash = TweenService:Create(shoulder, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.In), { C0 = pose(-70) })
		smash:Play()
		smash.Completed:Wait()
		TweenService:Create(shoulder, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = original }):Play()
	end)
end

local function swingBat(player)
	local root = getRoot(player)
	if not root then
		return
	end
	local look = root.CFrame.LookVector
	for _, other in ipairs(allAgents()) do
		local otherRoot = other ~= player and getRoot(other)
		local humanoid = otherRoot and getHumanoid(other)
		if humanoid and humanoid.Health > 0 then
			local offset = otherRoot.Position - root.Position
			if offset.Magnitude < 9 and offset.Unit:Dot(look) > 0.2 then
				local dropped = dropCarried(other, otherRoot.Position)
				hitStars(otherRoot.Position + Vector3.new(0, 2, 0))
				if dropped > 0 then
					sendHome(other)
					notify(other, player.Name .. " bonked you! You dropped your critters.")
					notify(player, "BONK! " .. other.Name .. " dropped " .. dropped .. " critter(s) and went home!")
				else
					-- Personne à voler ? Juste une petite poussée
					otherRoot.AssemblyLinearVelocity = look * 60 + Vector3.new(0, 30, 0)
				end
			end
		end
	end
end

local useBat -- défini juste en dessous
local function makeBat()
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = "Bonk players carrying critters: they drop them and go home!"
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, 0, -1.4)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 4)
	handle.Color = Color3.fromRGB(190, 140, 80)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local function batPart(name, size, offset, color, material, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Shape = shape or Enum.PartType.Block
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.Massless = true
		part.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = tool
	end
	-- Gros bout de la batte, poignée scotchée et pommeau
	batPart("Barrel", Vector3.new(2.4, 0.7, 0.7), CFrame.new(0, 0, 0.9) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(200, 150, 90), Enum.Material.Wood, Enum.PartType.Cylinder)
	batPart("Tip", Vector3.new(0.72, 0.72, 0.72), CFrame.new(0, 0, 2.1), Color3.fromRGB(200, 150, 90), Enum.Material.Wood,
		Enum.PartType.Ball)
	batPart("Tape", Vector3.new(1.2, 0.42, 0.42), CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(30, 30, 35), Enum.Material.Fabric, Enum.PartType.Cylinder)
	batPart("Knob", Vector3.new(0.2, 0.55, 0.55), CFrame.new(0, 0, -2) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	-- Traînée blanche derrière la batte pendant le coup
	local tipAttachment = Instance.new("Attachment")
	tipAttachment.Position = Vector3.new(0, 0, 2.2)
	tipAttachment.Parent = handle
	local baseAttachment = Instance.new("Attachment")
	baseAttachment.Position = Vector3.new(0, 0, 0)
	baseAttachment.Parent = handle
	local trail = Instance.new("Trail")
	trail.Attachment0 = tipAttachment
	trail.Attachment1 = baseAttachment
	trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = handle
	local whoosh = Instance.new("Sound")
	whoosh.SoundId = "rbxasset://sounds/swordslash.wav"
	whoosh.Volume = 1
	whoosh.Parent = handle

	local ready = 0
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player or os.clock() < ready then
			return
		end
		ready = os.clock() + 0.8
		useBat(player, tool)
	end)
	return tool
end

-- Un coup de batte (joueur ou bot) : bras, traînée, son, puis le coup touche
function useBat(owner, tool)
	local character = characterOf(owner)
	if not character then
		return
	end
	swingArm(character)
	local handle = tool and tool:FindFirstChild("Handle")
	local trail = handle and handle:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = true
		task.delay(0.4, function()
			trail.Enabled = false
		end)
	end
	local whoosh = handle and handle:FindFirstChildOfClass("Sound")
	if whoosh then
		whoosh:Play()
	end
	task.delay(0.18, function()
		swingBat(owner)
	end)
end

local function giveBat(player)
	local backpack = player:WaitForChild("Backpack", 5)
	if backpack and not backpack:FindFirstChild("Bat") and not (player.Character and player.Character:FindFirstChild("Bat")) then
		makeBat().Parent = backpack
	end
end

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
	local data = { creatures = {}, upgrades = {}, items = {}, discovered = {}, cash = Config.StartingCash, best = 0, loaded = true }
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
		data.best = tonumber(saved.best) or 0
		if type(saved.discovered) == "table" then
			for _, id in ipairs(saved.discovered) do
				if creaturesById[id] then
					data.discovered[id] = true
				end
			end
		end
		if type(saved.items) == "table" then
			for _, item in ipairs(Config.Items) do
				local count = tonumber(saved.items[item.id])
				if count then
					data.items[item.id] = math.clamp(math.floor(count), 0, 3)
				end
			end
		end
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
	local discovered = {}
	for id in pairs(data.discovered) do
		table.insert(discovered, id)
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
			best = data.best,
			items = data.items,
			discovered = discovered,
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
	invisibleUntil[player] = nil
	player:SetAttribute("InvisibleUntil", 0)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	applySpeed(player)
	updateCarryAttributes(player)
	task.spawn(function()
		giveBat(player)
		syncItemTools(player)
	end)
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
		loseCarried(player)
		updateCarryAttributes(player)
		task.delay(3, function()
			if player.Character == character then
				spawnCharacter(player)
			end
		end)
	end)
end

-- Donne une base libre à un joueur ou un bot
local function claimPlot(owner, data)
	local plot
	for _, candidate in ipairs(plots) do
		if not candidate.owner then
			plot = candidate
			break
		end
	end
	if not plot then
		return nil
	end
	plot.owner = owner
	data.plot = plot
	if owner:IsA("Player") then
		owner.RespawnLocation = plot.spawn
	end
	setBillboard(plot.sign, owner.Name .. "'s BASE", "")
	plot.barrier:SetAttribute("OwnerId", ownerId(owner))
	plot.barrier.Transparency = 0
	renderPedestals(plot)
	buildPads(plot)
	return plot
end

local function releasePlot(owner)
	local data = playerData[owner]
	if data and data.plot then
		local plot = data.plot
		plot.owner = nil
		data.plot = nil
		plot.pedestalFolder:ClearAllChildren()
		plot.padFolder:ClearAllChildren()
		setBillboard(plot.sign, "FREE BASE", "")
		plot.barrier:SetAttribute("OwnerId", 0)
		plot.barrier.Transparency = 1
	end
end

local freeBotPlot -- défini plus bas (partie "Bots") : un bot laisse sa base à un vrai joueur

-- Game Pass : achetés avec des Robux (les ID sont à mettre dans Config.GamePasses)
local MarketplaceService = game:GetService("MarketplaceService")
local passesById = {}
for _, pass in ipairs(Config.GamePasses or {}) do
	if pass.id ~= 0 then
		passesById[pass.id] = pass
	end
end

local function applyPass(player, pass)
	player:SetAttribute("Pass_" .. pass.key, true)
	applySpeed(player)
	updateCarryAttributes(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local pass = passesById[passId]
	if purchased and pass then
		applyPass(player, pass)
		notify(player, "Thanks for buying " .. pass.name .. "!")
	end
end)

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

	for _, id in pairs(data.creatures) do
		data.discovered[id] = true
	end
	playerData[player] = data
	carrying[player] = {}
	for _, pass in pairs(passesById) do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if ok and owns then
			player:SetAttribute("Pass_" .. pass.key, true)
		end
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local plot = claimPlot(player, data) or (freeBotPlot and freeBotPlot() and claimPlot(player, data))
	if not plot then
		warn("[Tsunami] Plus de base libre pour", player.Name)
		spawnCharacter(player)
		return
	end
	updateCarryAttributes(player)
	syncStats(player)
	for _, item in ipairs(Config.Items) do
		player:SetAttribute("Item_" .. item.id, data.items[item.id] or 0)
	end
	spawnCharacter(player)
	notify(player, "Grab critters on the path and bring them back. When the TSUNAMI comes, hide in a trench!")
end

local function onPlayerRemoving(player)
	saveData(player)
	releasePlot(player)
	loseCarried(player) -- les créatures volées qu'il portait reviennent à leur propriétaire
	playerData[player] = nil
	carrying[player] = nil
	raidUntil[player] = nil
	invisibleUntil[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Achats depuis le menu SHOP / UPGRADES (n'importe où sur la carte)
local shopEvent = Instance.new("RemoteEvent")
shopEvent.Name = "ShopAction"
shopEvent.Parent = ReplicatedStorage
shopEvent.OnServerEvent:Connect(function(player, kind, id)
	if typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return
	end
	if kind == "item" and itemsById[id] then
		buyItem(player, itemsById[id])
	elseif kind == "upgrade" and upgradesById[id] then
		buyUpgrade(player, upgradesById[id])
	end
end)

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
					data.best = math.max(data.best or 0, def and rarityIndex[def.rarity] or 0)
					if def then
						income += def.income
					end
				end
				if hasPass(player, "cash2x") then
					income *= 2
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
-- Bots : de faux joueurs pour voir si le jeu est fun à plusieurs.
-- Ils calculent s'ils ont le temps d'aller chercher une créature avant la vague,
-- se cachent dans les tranchées, rentrent, achètent des améliorations et
-- frappent à la batte ceux qui portent des créatures.
-- ============================================================

local BOT_NAMES = { "TurboTom", "NoodleNina", "WaveRider", "CrispyKai", "LuckyLou", "DashDylan", "MegaMia" }
local BOT_PERSONALITIES = {
	{ name = "careful", margin = 4, greed = 0.7, aggression = 0.3 },
	{ name = "greedy", margin = 1.5, greed = 1.5, aggression = 0.5 },
	{ name = "bully", margin = 2.5, greed = 1, aggression = 1 },
}
local BOT_ANIMATIONS = { run = "rbxassetid://507767714", idle = "rbxassetid://507766388" }
local BASE_SHELTER = -8 -- devant l'entrée de la zone des bases
local botStates = {} -- [bot] = { personality, bat, thought, lastBonk }
local botCount = 0
local botFolder = Instance.new("Folder")
botFolder.Name = "Bots"
botFolder.Parent = ServerStorage

local function setThought(bot, text)
	local state = botStates[bot]
	if state and state.thought and state.thoughtText ~= text then
		state.thoughtText = text
		state.thought.Text = text
	end
end

local spawnBotCharacter -- défini juste en dessous

function spawnBotCharacter(bot)
	local state = botStates[bot]
	local data = playerData[bot]
	if not state or not data or not data.plot then
		return
	end
	local description = Instance.new("HumanoidDescription")
	local skin = Color3.fromHSV(math.random() * 0.1, math.random() * 0.4 + 0.2, math.random() * 0.4 + 0.5)
	local shirt = Color3.fromHSV(math.random(), 0.7, 0.9)
	local pants = Color3.fromHSV(math.random(), 0.5, 0.5)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = pants
	description.RightLegColor = pants
	local ok, character = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not character then
		warn("[Tsunami] Impossible de créer le bot :", character)
		return
	end
	character.Name = bot.Name
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	humanoid.DisplayName = bot.Name .. " [BOT]"
	character:PivotTo(data.plot.spawn.CFrame + Vector3.new(0, 4, 0))
	character.Parent = workspace
	root:SetNetworkOwner(nil)
	botCharacters[bot] = character
	carrying[bot] = {}
	applySpeed(bot)
	updateCarryAttributes(bot)

	-- Ce que le bot pense, au-dessus de sa tête
	local head = character:FindFirstChild("Head")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(9, 1.4)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 70
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	state.thought = label
	state.thoughtText = nil

	-- La batte dans la main
	local bat = makeBat()
	bat.Parent = character
	state.bat = bat

	-- Animations de course et d'attente (animations de base de Roblox)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local tracks = {}
	for name, id in pairs(BOT_ANIMATIONS) do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local loaded, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if loaded then
			tracks[name] = track
		end
	end
	if tracks.idle then
		tracks.idle:Play()
	end
	humanoid.Running:Connect(function(speed)
		if not tracks.run or not tracks.idle then
			return
		end
		if speed > 1 then
			if not tracks.run.IsPlaying then
				tracks.idle:Stop()
				tracks.run:Play()
			end
			tracks.run:AdjustSpeed(speed / 16)
		elseif tracks.run.IsPlaying then
			tracks.run:Stop()
			tracks.idle:Play()
		end
	end)

	humanoid.Died:Connect(function()
		loseCarried(bot)
		if botCharacters[bot] == character then
			botCharacters[bot] = nil
		end
		task.delay(3, function()
			character:Destroy()
			if botStates[bot] then
				spawnBotCharacter(bot)
			end
		end)
	end)
end

-- Dans combien de secondes la vague arrive à la position x ?
local function waveTimeAt(x, assumedSpeed)
	local now = workspace:GetServerTimeNow()
	if workspace:GetAttribute("WaveState") == "active" then
		local front = waveFront()
		if front + Config.WaveThickness < x then
			return Config.WaveInterval + (Config.WaveStartX - x) / assumedSpeed -- déjà passée ici
		end
		return math.max(0, (front - x) / (workspace:GetAttribute("WaveSpeed") or 50))
	end
	local nextAt = workspace:GetAttribute("WaveNextAt") or now
	return math.max(0, nextAt - now) + (Config.WaveStartX - x) / assumedSpeed
end

-- Abri le plus proche où le bot peut arriver avant la vague (tranchée ou zone des bases)
local function findShelter(x, speed, margin)
	local best, bestDistance, fallback, fallbackDistance = nil, math.huge, BASE_SHELTER, math.huge
	local options = { BASE_SHELTER }
	for _, trench in ipairs(Config.Trenches) do
		table.insert(options, trench)
	end
	for _, shelter in ipairs(options) do
		local distance = math.abs(x - shelter)
		if distance < fallbackDistance then
			fallback, fallbackDistance = shelter, distance
		end
		local wave = shelter == BASE_SHELTER and math.huge or waveTimeAt(shelter, 80)
		if distance / speed + margin < wave and distance < bestDistance then
			best, bestDistance = shelter, distance
		end
	end
	return best or fallback, (best and bestDistance or fallbackDistance) / speed
end

-- Prochain point de passage : sortir de la base par l'entrée, puis aller vers la cible
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function nextWaypoint(position, target, plot)
	local inside = inPlot(plot, position)
	local targetHome = inPlot(plot, target)
	if inside then
		if targetHome then
			return target
		end
		if plot.cframe:PointToObjectSpace(position).Z > -18 then
			return at(plot, 0, 0, -20).Position
		end
		return at(plot, 0, 0, -32).Position
	end
	local onPathSide = position.X > -3
	if targetHome then
		if onPathSide then
			return Vector3.new(-10, 0, math.clamp(position.Z, -18, 18))
		end
		local front = at(plot, 0, 0, -30).Position
		if (flat(position) - flat(front)).Magnitude > 5 then
			return front
		end
		return target
	end
	if not onPathSide and target.X > 0 then
		return Vector3.new(4, 0, math.clamp(target.Z, -18, 18))
	end
	return target
end

local function botBrain(bot)
	local state = botStates[bot]
	local personality = state.personality
	while botStates[bot] do
		task.wait(0.25)
		local data = playerData[bot]
		local root = getRoot(bot)
		local humanoid = getHumanoid(bot)
		if not data or not data.plot or not root or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local plot = data.plot
		local position = root.Position
		local x = position.X
		local speed = math.max(humanoid.WalkSpeed, 1)
		local list = carrying[bot] or {}
		local inTrench = position.Y < -2 and x > 0
		local target, mode = nil, nil

		-- 1) Quelqu'un porte une créature tout près ? Coup de batte !
		if os.clock() - (state.lastBonk or 0) > 1.2 then
			for _, other in ipairs(allAgents()) do
				local otherRoot = other ~= bot and getRoot(other)
				if otherRoot and carrying[other] and #carrying[other] > 0
					and (otherRoot.Position - position).Magnitude < 8 and math.random() < personality.aggression then
					state.lastBonk = os.clock()
					root.CFrame = CFrame.lookAt(position, Vector3.new(otherRoot.Position.X, position.Y, otherRoot.Position.Z))
					setThought(bot, "BONK! Drop that critter!")
					useBat(bot, state.bat)
					break
				end
			end
		end

		-- 2) Danger : la vague arrive -> se mettre à l'abri
		if x > -2 then
			local shelter, timeNeeded = findShelter(x, speed, personality.margin)
			local waveTime = waveTimeAt(x, 80)
			local waveActive = workspace:GetAttribute("WaveState") == "active"
			if inTrench and waveActive and waveFront() + Config.WaveThickness > x then
				mode = "hide"
				target = position
				setThought(bot, "Hiding... the wave is coming!")
			elseif waveTime < timeNeeded + personality.margin + 1 then
				mode = "hide"
				if shelter == BASE_SHELTER then
					target = Vector3.new(BASE_SHELTER - 6, 0, math.clamp(position.Z, -18, 18))
					setThought(bot, "Running back to safety!")
				else
					target = Vector3.new(shelter, -Config.TrenchDepth, math.clamp(position.Z, -20, 20))
					setThought(bot, "Quick, into the trench!")
				end
			end
		end

		-- 3) Les mains pleines (ou plus rien d'intéressant) -> retour à la base
		if not mode and #list >= carryMax(data, bot) then
			mode = "home"
		end

		-- 4) Chasser la créature la plus intéressante qu'il a le temps d'aller chercher
		if not mode then
			local best, bestScore = nil, 0
			for _, entry in ipairs(groundCreatures) do
				if not entry.removed then
					local spot = entry.model.PrimaryPart.Position
					local travel = (flat(spot) - flat(position)).Magnitude / speed
					local _, escape = findShelter(spot.X, speed, personality.margin)
					if travel + escape + personality.margin < waveTimeAt(spot.X, 80) then
						local score = (entry.def.income ^ (0.55 * personality.greed)) / (travel + 3)
						if score > bestScore then
							best, bestScore = entry, score
						end
					end
				end
			end
			if best and (#list == 0 or (flat(best.model.PrimaryPart.Position) - flat(position)).Magnitude < 100) then
				mode = "hunt"
				target = best.model.PrimaryPart.Position
				setThought(bot, "Going for " .. best.def.name .. "!")
				if (flat(target) - flat(position)).Magnitude < 7 then
					grabCreature(bot, best)
				end
			elseif #list > 0 then
				mode = "home"
			end
		end

		-- 5) À la maison : ranger, vendre si plein, acheter des améliorations
		if mode == "home" or not mode then
			target = data.plot.spawn.Position
			if mode == "home" then
				setThought(bot, "Bringing my critters home!")
			end
			if inPlot(plot, position) then
				if #list > 0 then
					-- Plus de place : il vend sa moins bonne créature
					local free = false
					for index = 1, pedestalCount(data) do
						if not data.creatures[index] then
							free = true
						end
					end
					if not free then
						local worst, worstIncome = nil, math.huge
						for index, id in pairs(data.creatures) do
							if creaturesById[id].income < worstIncome then
								worst, worstIncome = index, creaturesById[id].income
							end
						end
						if worst then
							sellCreature(plot, worst)
						end
					end
				else
					local cash = getCash(bot)
					local cheapest, cheapestPrice = nil, math.huge
					for _, upgrade in ipairs(Config.Upgrades) do
						local price = upgrade.prices[upgradeLevel(data, upgrade.id) + 1]
						if price and price < cheapestPrice then
							cheapest, cheapestPrice = upgrade, price
						end
					end
					if cheapest and cash and cash.Value >= cheapestPrice then
						setThought(bot, "Buying " .. cheapest.name .. "!")
						buyUpgrade(bot, cheapest)
					elseif not mode then
						setThought(bot, "Waiting for the next wave...")
					end
				end
			end
		end

		-- Déplacement (en passant par l'entrée de la base) ; saute pour sortir d'une tranchée
		if target then
			local waypoint = nextWaypoint(position, target, plot)
			humanoid:MoveTo(waypoint)
			if position.Y < -1.5 and mode ~= "hide" then
				humanoid.Jump = true
			end
		end
	end
end

local function createBot()
	local name = "Bot"
	for _, candidate in ipairs(BOT_NAMES) do
		local used = false
		for bot in pairs(botStates) do
			if bot.Name == candidate then
				used = true
			end
		end
		if not used then
			name = candidate
			break
		end
	end
	botCount += 1
	local bot = Instance.new("Folder")
	bot.Name = name
	bot:SetAttribute("BotId", botCount)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = bot
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	bot.Parent = botFolder
	local data = { creatures = {}, upgrades = {}, items = {}, discovered = {}, best = 0, loaded = false }
	playerData[bot] = data
	carrying[bot] = {}
	if not claimPlot(bot, data) then
		playerData[bot] = nil
		bot:Destroy()
		return nil
	end
	botStates[bot] = { personality = BOT_PERSONALITIES[(botCount - 1) % #BOT_PERSONALITIES + 1] }
	spawnBotCharacter(bot)
	task.spawn(botBrain, bot)
	return bot
end

-- Un vrai joueur arrive et toutes les bases sont prises : un bot lui laisse la sienne
function freeBotPlot()
	for bot in pairs(botStates) do
		botStates[bot] = nil
		local character = botCharacters[bot]
		botCharacters[bot] = nil
		if character then
			character:Destroy()
		end
		loseCarried(bot)
		releasePlot(bot)
		playerData[bot] = nil
		carrying[bot] = nil
		bot:Destroy()
		return true
	end
	return false
end

if Config.BotsEnabled and (RunService:IsStudio() or not Config.BotsOnlyInStudio) then
	task.delay(4, function()
		for _ = 1, Config.BotCount do
			createBot()
		end
	end)
end

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
		elseif command == "spawndivine" then
			spawnDivine()
		elseif command == "unlockitems" then
			local data = playerData[player]
			if data then
				data.best = #Config.Rarities
				syncStats(player)
				notify(player, "Test: all items unlocked")
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
