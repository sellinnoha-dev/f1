-- ============================================================
-- Tsunami Critters : ce que voit le joueur
-- Argent, alerte tsunami, vague animée, créatures qui flottent, panneau de test.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local formatMoney = require(ReplicatedStorage:WaitForChild("FormatMoney"))
local ItemModels = require(ReplicatedStorage:WaitForChild("ItemModels"))
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "TsunamiHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function textLabel(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	for key, value in pairs(props) do
		label[key] = value
	end
	label.Parent = parent
	return label
end

-- ============================================================
-- Argent (en bas au centre)
-- ============================================================
local cashFrame = Instance.new("Frame")
cashFrame.AnchorPoint = Vector2.new(0.5, 1)
cashFrame.Position = UDim2.new(0.5, 0, 1, -84)
cashFrame.Size = UDim2.fromOffset(240, 60)
cashFrame.BackgroundColor3 = Color3.fromRGB(15, 30, 50)
cashFrame.BackgroundTransparency = 0.15
cashFrame.Parent = gui
rounded(cashFrame, 14)
local cashStroke = Instance.new("UIStroke")
cashStroke.Color = Color3.fromRGB(80, 200, 255)
cashStroke.Thickness = 2
cashStroke.Parent = cashFrame
local cashScale = Instance.new("UIScale")
cashScale.Parent = cashFrame
local cashLabel = textLabel(cashFrame, {
	Size = UDim2.new(1, -20, 0.7, 0), Position = UDim2.new(0, 10, 0, 4), TextColor3 = Color3.fromRGB(255, 220, 60),
})
local incomeLabel = textLabel(cashFrame, {
	Size = UDim2.new(1, -20, 0.28, 0), Position = UDim2.new(0, 10, 0.7, -2), Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.fromRGB(150, 255, 170),
})

local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
local lastCash = cash.Value
local function updateCash()
	cashLabel.Text = "$" .. formatMoney(cash.Value)
	if cash.Value > lastCash then
		cashScale.Scale = 1.1
		TweenService:Create(cashScale, TweenInfo.new(0.2), { Scale = 1 }):Play()
	end
	lastCash = cash.Value
end
cash.Changed:Connect(updateCash)
updateCash()

local function updateIncome()
	incomeLabel.Text = "+$" .. formatMoney(player:GetAttribute("Income") or 0) .. "/s"
end
player:GetAttributeChangedSignal("Income"):Connect(updateIncome)
updateIncome()

-- Créatures portées (au-dessus de l'argent)
local carryLabel = textLabel(gui, {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(260, 26),
	Font = Enum.Font.FredokaOne,
})
local function updateCarry()
	local count = player:GetAttribute("Carrying") or 0
	local max = player:GetAttribute("CarryMax") or 1
	carryLabel.Text = "Carrying " .. count .. "/" .. max
	carryLabel.TextColor3 = count > 0 and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(220, 220, 220)
end
player:GetAttributeChangedSignal("Carrying"):Connect(updateCarry)
player:GetAttributeChangedSignal("CarryMax"):Connect(updateCarry)
updateCarry()

-- ============================================================
-- Bandeau d'alerte (en haut au centre)
-- ============================================================
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 10)
banner.Size = UDim2.fromOffset(460, 54)
banner.BackgroundColor3 = Color3.fromRGB(15, 30, 50)
banner.BackgroundTransparency = 0.2
banner.Parent = gui
rounded(banner, 12)
local bannerLabel = textLabel(banner, { Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5) })

-- ============================================================
-- Notifications du serveur
-- ============================================================
ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = Config.GameName, Text = text, Duration = 5 })
	end)
end)

-- ============================================================
-- Sons et musique
--   SoundService > Music  : tes musiques (jouées au hasard, en boucle)
--   SoundService > Sounds : "Siren", "Wave", "Divine" pour remplacer les sons par défaut
-- ============================================================
local SoundService = game:GetService("SoundService")

local function getSound(name, fallbackId, volume, speed)
	local folder = SoundService:FindFirstChild("Sounds")
	local custom = folder and folder:FindFirstChild(name)
	local sound
	if custom and custom:IsA("Sound") then
		sound = custom:Clone()
	else
		sound = Instance.new("Sound")
		sound.SoundId = fallbackId
		sound.Volume = volume
		sound.PlaybackSpeed = speed or 1
	end
	sound.Name = name
	sound.Parent = SoundService
	return sound
end

local sirenSound = getSound("Siren", "rbxasset://sounds/electronicpingshort.wav", 0.8, 0.55)
local waveSound = getSound("Wave", "rbxasset://sounds/action_swim.mp3", 0, 0.35)
waveSound.Looped = true
local divineSound = getSound("Divine", "rbxasset://sounds/electronicpingshort.wav", 1, 1.6)

-- Musique d'ambiance : chaque son du dossier Music, dans un ordre au hasard
local music = nil
task.spawn(function()
	local folder = SoundService:WaitForChild("Music", 5)
	if not folder then
		return
	end
	local tracks = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Sound") then
			table.insert(tracks, child)
		end
	end
	if #tracks == 0 then
		return
	end
	while true do
		local track = tracks[math.random(#tracks)]
		music = track
		track.Looped = false
		track:Play()
		if track.TimeLength == 0 then
			track.Loaded:Wait()
		end
		track.Ended:Wait()
		task.wait(1)
	end
end)

-- ============================================================
-- Ambiance : le ciel s'assombrit quand le tsunami arrive
-- ============================================================
local Lighting = game:GetService("Lighting")
local mood = Instance.new("ColorCorrectionEffect")
mood.Name = "TsunamiMood"
mood.Parent = Lighting
local currentMood = nil
local function setMood(name)
	if currentMood == name then
		return
	end
	currentMood = name
	local goal
	if name == "storm" then
		goal = { TintColor = Color3.fromRGB(165, 185, 225), Brightness = -0.1, Contrast = 0.15, Saturation = -0.3 }
	else
		goal = { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 }
	end
	TweenService:Create(mood, TweenInfo.new(name == "storm" and 3 or 5), goal):Play()
end

-- Éclaboussure bleue à l'écran quand la vague passe tout près
local splash = Instance.new("Frame")
splash.Size = UDim2.fromScale(1, 1)
splash.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
splash.BackgroundTransparency = 1
splash.BorderSizePixel = 0
splash.ZIndex = 0
splash.Parent = gui

-- ============================================================
-- La vague : dessinée ici (plus fluide), le serveur calcule la même position
-- ============================================================
local wave = nil -- { model, parts... }

local function wavePart(model, name, size, props, class)
	local part = Instance.new(class or "Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = model
	return part
end

local function addSpray(part, rate, size, speed)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255))
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.2) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(0.8, 1.6)
	spray.Rate = rate
	spray.Speed = NumberRange.new(speed * 0.5, speed)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Acceleration = Vector3.new(0, -20, 0)
	spray.Parent = part
	return spray
end

local CURL_SEGMENTS = 7

local function buildWave(height, color)
	local model = Instance.new("Model")
	model.Name = "Tsunami"
	local width = Config.PathWidth + 60
	local thickness = Config.WaveThickness
	local light = color:Lerp(Color3.fromRGB(150, 220, 255), 0.45)
	local w = { model = model, height = height, curl = {} }
	w.body = wavePart(model, "Body", Vector3.new(thickness, height + 12, width), { Color = color, Transparency = 0.05 })
	-- Couche animée (reflets qui bougent) par-dessus l'eau
	w.shimmer = wavePart(model, "Shimmer", Vector3.new(thickness + 0.6, height + 12.6, width + 0.6), {
		Color = light, Material = Enum.Material.ForceField, Transparency = 0,
	})
	-- La crête qui s'enroule vers l'avant
	local radius = math.max(8, height * 0.22)
	w.radius = radius
	local segment = radius * 2 * math.pi * (150 / 360) / CURL_SEGMENTS + 1
	for i = 1, CURL_SEGMENTS do
		w.curl[i] = wavePart(model, "Curl", Vector3.new(segment, 5, width), {
			Color = color:Lerp(light, i / CURL_SEGMENTS), Transparency = 0.05,
		})
	end
	w.foam = wavePart(model, "Foam", Vector3.new(thickness * 0.8, 3, width), { Color = Color3.fromRGB(240, 250, 255) })
	addSpray(w.foam, 120, 7, 30)
	addSpray(w.curl[CURL_SEGMENTS], 80, 6, 18)
	w.ground = wavePart(model, "GroundSpray", Vector3.new(2, 2, width), { Transparency = 1 })
	addSpray(w.ground, 150, 9, 40)
	model.Parent = workspace
	return w
end

local function placeWave(w, front, now)
	local h = w.height
	local t = Config.WaveThickness
	-- Arrivée à la zone des bases : la vague s'écrase et s'enfonce dans le sol
	local bob = math.sin(now * 2.5) * 1.2 - math.max(0, 60 - front) * 1.4
	w.body.CFrame = CFrame.new(front + t / 2, (h + 12) / 2 - 12 + bob, 0)
	w.shimmer.CFrame = w.body.CFrame
	-- Crête : un quart de cercle au sommet, penché vers l'avant (vers la base)
	local r = w.radius
	local center = Vector3.new(front + r * 0.3, h - r + bob, 0)
	for i, part in ipairs(w.curl) do
		local angle = math.rad(150) * (i - 0.5) / CURL_SEGMENTS
		local position = center + Vector3.new(-math.sin(angle) * r, math.cos(angle) * r, 0)
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, angle)
	end
	w.foam.CFrame = CFrame.new(front + t * 0.45, h + 1.5 + bob, 0)
	w.ground.CFrame = CFrame.new(front - 2, 0.5, 0)
end

local lastSiren = 0
local lastSplash = 0
local lastDivine = workspace:GetAttribute("DivineAt") or 0

RunService.RenderStepped:Connect(function()
	local state = workspace:GetAttribute("WaveState")
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- Dans la zone des bases (avant le chemin) : pas d'effets de vague, et la musique chill
	local inBase = not root or root.Position.X < 0
	setMood((state == "warning" or state == "active") and not inBase and "storm" or "calm")
	if music then
		local target = inBase and 0.35 or 0
		music.Volume += (target - music.Volume) * 0.05
	end

	if state == "active" then
		local height = workspace:GetAttribute("WaveHeight") or 40
		if not wave then
			wave = buildWave(height, workspace:GetAttribute("WaveColor") or Color3.fromRGB(40, 120, 220))
			waveSound:Play()
		end
		local speed = workspace:GetAttribute("WaveSpeed") or 40
		local front = Config.WaveStartX - speed * (now - (workspace:GetAttribute("WaveStart") or now))
		placeWave(wave, front, now)

		local distance = root and math.abs(root.Position.X - front) or 1000
		waveSound.Volume = inBase and 0.2 or math.clamp(3 * (1 - distance / 400), 0.3, 3)
		if inBase then
			distance = 1000 -- pas de tremblement ni d'éclaboussure dans la base
		end
		-- La caméra tremble de plus en plus fort quand la vague approche
		if humanoid then
			if distance < 200 then
				local strength = (1 - distance / 200) ^ 2 * 1.6
				humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * strength
			else
				humanoid.CameraOffset = Vector3.zero
			end
		end
		if distance < 12 and now - lastSplash > 1.5 then
			lastSplash = now
			splash.BackgroundTransparency = 0.35
			TweenService:Create(splash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		end
		-- La vague éclair fait clignoter le ciel
		if (workspace:GetAttribute("WaveName") or ""):find("LIGHTNING") and math.random() < 0.03 then
			mood.Brightness = 0.5
			TweenService:Create(mood, TweenInfo.new(0.3), { Brightness = -0.1 }):Play()
		end
	elseif wave then
		wave.model:Destroy()
		wave = nil
		waveSound:Stop()
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	end

	-- Bandeau + sirène
	if state == "warning" then
		local left = math.max(0, math.ceil((workspace:GetAttribute("WaveNextAt") or now) - now))
		bannerLabel.Text = "TSUNAMI IN " .. left .. "s - HIDE IN A TRENCH!"
		local flash = math.floor(now * 4) % 2 == 0
		banner.BackgroundColor3 = flash and Color3.fromRGB(200, 30, 40) or Color3.fromRGB(90, 10, 20)
		if now - lastSiren > 0.5 and not inBase then
			lastSiren = now
			sirenSound:Play()
		end
	elseif state == "active" then
		bannerLabel.Text = tostring(workspace:GetAttribute("WaveName") or "TSUNAMI") .. "! STAY LOW!"
		banner.BackgroundColor3 = Color3.fromRGB(20, 80, 180)
	else
		local left = math.max(0, math.ceil((workspace:GetAttribute("WaveNextAt") or now) - now))
		bannerLabel.Text = "Next tsunami in " .. left .. "s"
		banner.BackgroundColor3 = Color3.fromRGB(15, 30, 50)
	end
end)

-- ============================================================
-- Créature DIVINE : grosse annonce arc-en-ciel + aura qui change de couleur
-- ============================================================
local divineFrame = Instance.new("Frame")
divineFrame.AnchorPoint = Vector2.new(0.5, 0.5)
divineFrame.Position = UDim2.fromScale(0.5, 0.28)
divineFrame.Size = UDim2.fromScale(0.75, 0.2)
divineFrame.BackgroundTransparency = 1
divineFrame.Visible = false
divineFrame.Parent = gui
local divineScale = Instance.new("UIScale")
divineScale.Parent = divineFrame

local divineTitle = textLabel(divineFrame, {
	Size = UDim2.fromScale(1, 0.62), Font = Enum.Font.LuckiestGuy, Text = "DIVINE CRITTER!",
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 1,
})
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 4
titleStroke.Color = Color3.fromRGB(40, 0, 60)
titleStroke.Parent = divineTitle
local rainbowGradient = Instance.new("UIGradient")
rainbowGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 255, 120)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 100, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
})
rainbowGradient.Parent = divineTitle
local divineSub = textLabel(divineFrame, {
	Position = UDim2.fromScale(0.1, 0.66), Size = UDim2.fromScale(0.8, 0.3), Font = Enum.Font.FredokaOne,
	TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0,
})
local divineUntil = 0

-- Flash blanc à l'écran quand elle apparaît
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

workspace:GetAttributeChangedSignal("DivineAt"):Connect(function()
	local at = workspace:GetAttribute("DivineAt") or 0
	if at <= lastDivine then
		return
	end
	lastDivine = at
	divineSub.Text = tostring(workspace:GetAttribute("DivineName")) .. " appeared in front of the bases! GO GO GO!"
	divineUntil = os.clock() + 7
	divineFrame.Visible = true
	divineScale.Scale = 0.2
	TweenService:Create(divineScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	flash.BackgroundTransparency = 0.3
	TweenService:Create(flash, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
	task.spawn(function()
		for _ = 1, 4 do
			divineSound:Play()
			task.wait(0.25)
		end
	end)
end)

-- Étiquettes des créatures divines : écriture arc-en-ciel
local function decorateDivine(model)
	task.wait(0.5)
	for _, billboard in ipairs(model:GetDescendants()) do
		if billboard:IsA("BillboardGui") and not billboard:FindFirstChild("Decorated") then
			local marker = Instance.new("Folder")
			marker.Name = "Decorated"
			marker.Parent = billboard
			billboard.Size = UDim2.new(billboard.Size.X.Scale * 1.4, 0, billboard.Size.Y.Scale * 1.4, 0)
			local title = billboard:FindFirstChild("Title")
			if title then
				title.Font = Enum.Font.LuckiestGuy
				title.TextColor3 = Color3.new(1, 1, 1)
				rainbowGradient:Clone().Parent = title
			end
		end
	end
end
CollectionService:GetInstanceAddedSignal("Divine"):Connect(decorateDivine)
for _, model in ipairs(CollectionService:GetTagged("Divine")) do
	task.spawn(decorateDivine, model)
end

RunService.Heartbeat:Connect(function()
	local hue = (os.clock() * 0.3) % 1
	local rainbow = Color3.fromHSV(hue, 0.7, 1)
	-- Le dégradé arc-en-ciel défile
	local offset = (os.clock() * 0.5) % 2 - 1
	for _, gradient in ipairs({ rainbowGradient }) do
		gradient.Offset = Vector2.new(offset, 0)
	end
	if divineFrame.Visible then
		divineFrame.Rotation = math.sin(os.clock() * 5) * 2.5
		if os.clock() > divineUntil then
			divineFrame.Visible = false
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("Divine")) do
		for _, part in ipairs(model:GetDescendants()) do
			if part.Name == "Aura" and part:IsA("BasePart") then
				part.Color = rainbow
			elseif part:IsA("UIGradient") then
				part.Offset = Vector2.new(offset, 0)
			end
		end
		local light = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = rainbow
		end
	end
end)

-- Temps restant de la clé de raid (sous le compteur de créatures portées)
local raidLabel = textLabel(gui, {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -178), Size = UDim2.fromOffset(260, 24),
	Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 200, 40), Visible = false,
})
RunService.Heartbeat:Connect(function()
	local left = (player:GetAttribute("RaidUntil") or 0) - workspace:GetServerTimeNow()
	raidLabel.Visible = left > 0
	if left > 0 then
		raidLabel.Text = "RAID KEY: " .. math.ceil(left) .. "s"
	end
end)

-- ============================================================
-- Créatures qui flottent et tournent doucement (seulement celles qui sont proches)
-- ============================================================
local bobbing = {}
local function addBobbing(model)
	bobbing[model] = math.random() * 10
end
CollectionService:GetInstanceAddedSignal("Bobbing"):Connect(addBobbing)
CollectionService:GetInstanceRemovedSignal("Bobbing"):Connect(function(model)
	bobbing[model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged("Bobbing")) do
	addBobbing(model)
end

RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local t = os.clock()
	for model, phase in pairs(bobbing) do
		local root = model.PrimaryPart
		local base = model:GetAttribute("BaseCFrame")
		if root and base and root.Anchored and (base.Position - cameraPosition).Magnitude < 160 then
			root.CFrame = base * CFrame.new(0, 0.4 + math.sin(t * 2 + phase) * 0.35, 0)
				* CFrame.Angles(0, math.sin(t * 0.8 + phase) * 0.5, 0)
		end
	end
end)

-- ============================================================
-- Touches E : « Sell » seulement sur tes créatures, « STEAL » seulement chez les autres
-- ============================================================
local function filterPrompt(prompt, ownerOnly)
	local function apply()
		local mine = prompt:GetAttribute("OwnerId") == player.UserId
		prompt.Enabled = (ownerOnly and mine) or (not ownerOnly and not mine)
	end
	apply()
	prompt:GetAttributeChangedSignal("OwnerId"):Connect(apply)
end
for _, tag in ipairs({ "OwnerOnly", "ThiefOnly" }) do
	local ownerOnly = tag == "OwnerOnly"
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(prompt)
		filterPrompt(prompt, ownerOnly)
	end)
	for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
		filterPrompt(prompt, ownerOnly)
	end
end


-- ============================================================
-- Barre d'objets (en bas à gauche) : modèle 3D, quantité, touche Z / X / C
-- ============================================================
local useEvent = ReplicatedStorage:WaitForChild("UseItem", 10)
local ITEM_KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C }
local ITEM_KEY_NAMES = { "Z", "X", "C" }

local itemBar = Instance.new("Frame")
itemBar.AnchorPoint = Vector2.new(0, 1)
itemBar.Position = UDim2.new(0, 12, 1, -20)
itemBar.Size = UDim2.fromOffset(#Config.Items * 86, 84)
itemBar.BackgroundTransparency = 1
itemBar.Parent = gui
local itemLayout = Instance.new("UIListLayout")
itemLayout.FillDirection = Enum.FillDirection.Horizontal
itemLayout.Padding = UDim.new(0, 8)
itemLayout.Parent = itemBar

local function useItem(itemId)
	if useEvent then
		useEvent:FireServer(itemId)
	end
end

for index, item in ipairs(Config.Items) do
	local slot = Instance.new("TextButton")
	slot.Name = item.id
	slot.Size = UDim2.fromOffset(78, 78)
	slot.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
	slot.BackgroundTransparency = 0.15
	slot.Text = ""
	slot.AutoButtonColor = true
	slot.Visible = false
	slot.Parent = itemBar
	rounded(slot, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = item.color
	stroke.Thickness = 2
	stroke.Parent = slot
	-- Petite vue 3D de l'objet
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.new(1, -8, 1, -8)
	view.Position = UDim2.fromOffset(4, 4)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.new(1, 1, 1)
	view.Parent = slot
	local preview = ItemModels.build(item.id)
	preview.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local _, size = preview:GetBoundingBox()
	local distance = size.Magnitude * 1.4
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.5, distance * 0.35, -distance), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	local keyLabel = textLabel(slot, {
		Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(18, 18), Text = ITEM_KEY_NAMES[index],
		TextColor3 = Color3.fromRGB(255, 220, 60),
	})
	keyLabel.ZIndex = 3
	local countLabel = textLabel(slot, {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(30, 20), Text = "x0",
	})
	countLabel.ZIndex = 3
	local function refresh()
		local count = player:GetAttribute("Item_" .. item.id) or 0
		countLabel.Text = "x" .. count
		slot.Visible = count > 0
	end
	player:GetAttributeChangedSignal("Item_" .. item.id):Connect(refresh)
	refresh()
	slot.Activated:Connect(function()
		useItem(item.id)
	end)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	for index, key in ipairs(ITEM_KEYS) do
		if input.KeyCode == key and Config.Items[index] then
			useItem(Config.Items[index].id)
		end
	end
end)

-- ============================================================
-- Invisible : tu te vois en fantôme, avec le temps restant et un bouton pour réapparaître
-- ============================================================
local ghostFrame = Instance.new("Frame")
ghostFrame.AnchorPoint = Vector2.new(0.5, 0)
ghostFrame.Position = UDim2.new(0.5, 0, 0, 72)
ghostFrame.Size = UDim2.fromOffset(300, 46)
ghostFrame.BackgroundColor3 = Color3.fromRGB(70, 40, 130)
ghostFrame.BackgroundTransparency = 0.15
ghostFrame.Visible = false
ghostFrame.Parent = gui
rounded(ghostFrame, 10)
local ghostLabel = textLabel(ghostFrame, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(0.55, -10, 1, -12) })
local reappear = Instance.new("TextButton")
reappear.AnchorPoint = Vector2.new(1, 0.5)
reappear.Position = UDim2.new(1, -6, 0.5, 0)
reappear.Size = UDim2.new(0.42, 0, 1, -10)
reappear.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
reappear.Font = Enum.Font.FredokaOne
reappear.TextScaled = true
reappear.Text = "REAPPEAR"
reappear.TextColor3 = Color3.fromRGB(40, 20, 0)
reappear.Parent = ghostFrame
rounded(reappear, 8)
reappear.Activated:Connect(function()
	useItem("reappear")
end)

local frozenLabel = textLabel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(400, 60),
	Text = "FROZEN!", TextColor3 = Color3.fromRGB(150, 230, 255), Font = Enum.Font.LuckiestGuy, Visible = false,
})

local wasInvisible = false
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local left = (player:GetAttribute("InvisibleUntil") or 0) - now
	local invisible = left > 0
	ghostFrame.Visible = invisible
	if invisible then
		ghostLabel.Text = "INVISIBLE " .. math.ceil(left) .. "s"
	end
	-- Chez toi seulement : ton personnage reste visible en transparence
	local character = player.Character
	if character and (invisible or wasInvisible) then
		for _, part in ipairs(character:GetDescendants()) do
			if (part:IsA("BasePart") or part:IsA("Decal")) and part.Name ~= "HumanoidRootPart"
				and part:GetAttribute("OriginalTransparency") ~= nil then
				part.Transparency = invisible and 0.65 or part:GetAttribute("OriginalTransparency")
			end
		end
	end
	wasInvisible = invisible
	frozenLabel.Visible = (player:GetAttribute("FrozenUntil") or 0) > now
end)

-- ============================================================
-- Murs d'énergie des bases : solides pour toi, sauf dans ta base ou avec une Raid Key
-- ============================================================
task.spawn(function()
	while true do
		local raiding = (player:GetAttribute("RaidUntil") or 0) > workspace:GetServerTimeNow()
		for _, barrier in ipairs(CollectionService:GetTagged("BaseBarrier")) do
			local owner = barrier:GetAttribute("OwnerId") or 0
			barrier.CanCollide = owner ~= 0 and owner ~= player.UserId and not raiding
		end
		task.wait(0.25)
	end
end)

-- ============================================================
-- Panneau de test (seulement dans Roblox Studio)
-- ============================================================
if RunService:IsStudio() then
	local testEvent = ReplicatedStorage:WaitForChild("TestCommand", 10)
	if testEvent then
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -12, 0.5, 0)
		panel.Size = UDim2.fromOffset(150, 300)
		panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		panel.BackgroundTransparency = 0.25
		panel.Parent = gui
		rounded(panel, 10)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = panel
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 8)
		padding.Parent = panel
		textLabel(panel, { Size = UDim2.fromOffset(130, 18), Text = "TEST (Studio)", TextColor3 = Color3.fromRGB(80, 200, 255) })
		local function addButton(text, command, amount)
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(130, 28)
			button.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
			button.Font = Enum.Font.FredokaOne
			button.TextScaled = true
			button.TextColor3 = Color3.new(1, 1, 1)
			button.Text = text
			button.Parent = panel
			rounded(button, 6)
			button.Activated:Connect(function()
				testEvent:FireServer(command, amount)
			end)
		end
		addButton("+ $10K", "addcash", 10000)
		addButton("+ $1M", "addcash", 1000000)
		addButton("Wave now", "wavenow", 0)
		addButton("Spawn Legendary", "spawnrarity", 4)
		addButton("Spawn SECRET", "spawnrarity", 6)
		addButton("Spawn DIVINE", "spawndivine", 0)
		addButton("Unlock items", "unlockitems", 0)
	end
end
