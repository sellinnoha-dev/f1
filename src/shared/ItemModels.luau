-- ============================================================
-- Modèles 3D des objets (cape, rayon gelant, clé de raid)
-- Utilisé par le serveur (boutique) et par le joueur (barre d'objets en bas).
-- ============================================================

local ItemModels = {}

local function piece(model, props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = model
	return part
end

local GOLD = Color3.fromRGB(255, 195, 40)

local builders = {}

-- Cape violette avec col doré
function builders.cloak(model)
	local main = piece(model, { Name = "Cape", Size = Vector3.new(1.6, 2.8, 0.15), CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(110, 50, 190), Material = Enum.Material.Fabric })
	for _, side in ipairs({ -1, 1 }) do
		piece(model, { Name = "CapeSide", Size = Vector3.new(0.9, 2.6, 0.15),
			CFrame = CFrame.new(side * 1.15, -0.1, 0.3) * CFrame.Angles(0, math.rad(side * -35), 0),
			Color = Color3.fromRGB(90, 40, 160), Material = Enum.Material.Fabric })
	end
	piece(model, { Name = "Lining", Size = Vector3.new(1.4, 2.5, 0.05), CFrame = CFrame.new(0, -0.05, -0.1),
		Color = Color3.fromRGB(200, 170, 255), Material = Enum.Material.Neon, Transparency = 0.3 })
	piece(model, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 0.3, 0.3),
		CFrame = CFrame.new(0, 1.45, 0.1), Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.3 })
	piece(model, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.4, CFrame = CFrame.new(0, 1.45, -0.15),
		Color = Color3.fromRGB(80, 255, 220), Material = Enum.Material.Neon })
	return main
end

-- Pistolet à glace : corps, canon lumineux, réservoir, poignée
function builders.freeze(model)
	local body = piece(model, { Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 0.75, 0.75),
		CFrame = CFrame.new(0, 0, 0), Color = Color3.fromRGB(225, 240, 255), Material = Enum.Material.Metal })
	piece(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 0.4, 0.4), CFrame = CFrame.new(1.5, 0, 0),
		Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon })
	piece(model, { Name = "Tip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.6, 0.6), CFrame = CFrame.new(2, 0, 0),
		Color = Color3.fromRGB(40, 80, 140), Material = Enum.Material.Metal })
	piece(model, { Name = "Tank", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.85, CFrame = CFrame.new(-0.3, 0.6, 0),
		Color = Color3.fromRGB(120, 240, 255), Material = Enum.Material.Ice, Transparency = 0.2 })
	piece(model, { Name = "Grip", Size = Vector3.new(0.4, 1, 0.45), CFrame = CFrame.new(-0.6, -0.75, 0) * CFrame.Angles(0, 0, math.rad(-15)),
		Color = Color3.fromRGB(40, 50, 70) })
	for i = 1, 3 do
		piece(model, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.8, 0.8),
			CFrame = CFrame.new(-0.7 + i * 0.4, 0, 0), Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon })
	end
	return body
end

-- Clé dorée avec une pierre précieuse
function builders.raidkey(model)
	local bow = piece(model, { Name = "Bow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.5, 1.5),
		CFrame = CFrame.new(-1, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.35 })
	piece(model, { Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.6, CFrame = CFrame.new(-1, 0, -0.1),
		Color = Color3.fromRGB(255, 40, 80), Material = Enum.Material.Neon })
	piece(model, { Name = "Shaft", Size = Vector3.new(2.2, 0.3, 0.3), CFrame = CFrame.new(0.8, 0, 0),
		Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.35 })
	for _, x in ipairs({ 1.5, 1.85 }) do
		piece(model, { Name = "Tooth", Size = Vector3.new(0.25, 0.5, 0.3), CFrame = CFrame.new(x, -0.35, 0),
			Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.35 })
	end
	return bow
end

-- Crée le modèle d'un objet, centré sur (0, 0, 0). weld = true : pièces soudées
-- à la pièce principale (seule ancrée), pour pouvoir la faire tourner.
function ItemModels.build(itemId, weld)
	local model = Instance.new("Model")
	model.Name = itemId
	local builder = builders[itemId]
	if not builder then
		return model
	end
	local main = builder(model)
	model.PrimaryPart = main
	main.PivotOffset = main.CFrame:Inverse() -- le pivot du modèle = son centre, sans rotation
	if weld then
		for _, part in ipairs(model:GetChildren()) do
			if part:IsA("BasePart") and part ~= main then
				local constraint = Instance.new("WeldConstraint")
				constraint.Part0 = main
				constraint.Part1 = part
				constraint.Parent = part
				part.Anchored = false
				part.Massless = true
			end
		end
	end
	return model
end

return ItemModels
