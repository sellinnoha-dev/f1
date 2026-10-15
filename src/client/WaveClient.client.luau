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
	-- Musiques : tous les sons rangés dans SoundService (dossier Music ou directement dedans)
	task.wait(2)
	local tracks = {}
	for _, child in ipairs(SoundService:GetDescendants()) do
		if child:IsA("Sound") and not ({ Siren = true, Wave = true, Divine = true })[child.Name] then
			table.insert(tracks, child)
		end
	end
	print("[Tsunami] Musiques trouvées dans SoundService :", #tracks)
	if #tracks == 0 then
		return
	end
	while true do
		local track = tracks[math.random(#tracks)]
		music = track
		track.Looped = #tracks == 1
		track.Volume = 0
		track:Play()
		if #tracks == 1 then
			return -- une seule musique : elle tourne en boucle
		end
		local started = os.clock()
		while not track.IsLoaded and os.clock() - started < 10 do
			task.wait(0.5)
		end
		if track.TimeLength > 0 then
			track.Ended:Wait()
		else
			warn("[Tsunami] La musique " .. track.Name .. " ne se charge pas (son privé ?)")
			task.wait(30)
		end
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
-- Menu à gauche (comme dans les jeux Roblox) : SHOP, UPGRADES, INDEX
-- ============================================================
local useEvent = ReplicatedStorage:WaitForChild("UseItem", 10)
local shopEvent = ReplicatedStorage:WaitForChild("ShopAction", 10)
local MarketplaceService = game:GetService("MarketplaceService")

local function useItem(itemId)
	if useEvent then
		useEvent:FireServer(itemId)
	end
end

local raritiesById, rarityIndex = {}, {}
for index, rarity in ipairs(Config.Rarities) do
	raritiesById[rarity.id] = rarity
	rarityIndex[rarity.id] = index
end

local function localNotify(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = Config.GameName, Text = text, Duration = 4 })
	end)
end

local function makeButton(parent, text, color, props)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.AutoButtonColor = true
	for key, value in pairs(props or {}) do
		button[key] = value
	end
	button.Parent = parent
	rounded(button, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	return button
end

-- Fenêtre au centre de l'écran
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(620, 420)
panel.BackgroundColor3 = Color3.fromRGB(25, 35, 60)
panel.Visible = false
panel.Parent = gui
rounded(panel, 16)
local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 3
panelStroke.Color = Color3.fromRGB(80, 200, 255)
panelStroke.Parent = panel
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local panelTitle = textLabel(panel, { Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -90, 0, 40),
	TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.LuckiestGuy })
local closeButton = makeButton(panel, "X", Color3.fromRGB(220, 60, 60), {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(40, 40),
})
local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(14, 104)
content.Size = UDim2.new(1, -28, 1, -118)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 8
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new()
content.Parent = panel
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(180, 220)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = content

local currentTab = nil
local shopTab = "ITEMS"

-- Onglets du SHOP (sous le titre)
local subTabs = Instance.new("Frame")
subTabs.Position = UDim2.fromOffset(14, 58)
subTabs.Size = UDim2.new(1, -28, 0, 38)
subTabs.BackgroundTransparency = 1
subTabs.Parent = panel
local subLayout = Instance.new("UIListLayout")
subLayout.FillDirection = Enum.FillDirection.Horizontal
subLayout.Padding = UDim.new(0, 8)
subLayout.Parent = subTabs
local subButtons = {}

local function card(color, order)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(40, 55, 90)
	frame.LayoutOrder = order
	frame.Parent = content
	rounded(frame, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = color
	stroke.Parent = frame
	return frame
end

local function viewport(parent, model, height, silhouette)
	local view = Instance.new("ViewportFrame")
	if silhouette then
		view.ImageColor3 = Color3.new(0, 0, 0)
	end
	view.Position = UDim2.fromOffset(10, 8)
	view.Size = UDim2.new(1, -20, 0, height)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.new(1, 1, 1)
	view.Parent = parent
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local center, size = model:GetBoundingBox()
	local distance = size.Magnitude * 1.3
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(distance * 0.5, distance * 0.3, -distance), center.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

local tabs = {}

local critterModels = ReplicatedStorage:WaitForChild("CritterModels", 10)

local function critterPreview(id)
	local source = critterModels and critterModels:FindFirstChild(id)
	return source and source:Clone() or nil
end

-- Petite caisse en bois (pour les cartes du SHOP)
local function crateModel(color)
	local model = Instance.new("Model")
	local function part(size, cframe, partColor, material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cframe
		p.Color = partColor
		p.Material = material or Enum.Material.Wood
		p.Parent = model
		return p
	end
	part(Vector3.new(3, 2.4, 3), CFrame.new(0, 0, 0), Color3.fromRGB(150, 100, 55))
	part(Vector3.new(3.2, 0.5, 3.2), CFrame.new(0, 1.35, 0), color, Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -1.4, 1.4 }) do
		part(Vector3.new(0.3, 2.5, 3.1), CFrame.new(x, 0, 0), Color3.fromRGB(110, 70, 35))
	end
	local lock = part(Vector3.new(0.7, 0.7, 0.2), CFrame.new(0, 0.6, -1.6), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
	model.PrimaryPart = lock
	return model
end

local SHOP_TABS = { "ITEMS", "CRATES", "BOOSTS", "ROBUX" }
local shopBuilders = {}

function shopBuilders.ITEMS()
	local best = player:GetAttribute("Best") or 0
	for index, item in ipairs(Config.Items) do
		local frame = card(item.color, index)
		viewport(frame, ItemModels.build(item.id), 90)
		textLabel(frame, { Position = UDim2.fromOffset(8, 100), Size = UDim2.new(1, -16, 0, 24), Text = item.name })
		textLabel(frame, { Position = UDim2.fromOffset(8, 124), Size = UDim2.new(1, -16, 0, 34), Text = item.description,
			TextColor3 = Color3.fromRGB(200, 210, 230), Font = Enum.Font.FredokaOne, TextWrapped = true })
		local needed = item.requires and rarityIndex[item.requires] or 0
		local count = player:GetAttribute("Item_" .. item.id) or 0
		if best < needed then
			local rarity = raritiesById[item.requires]
			textLabel(frame, { Position = UDim2.fromOffset(8, 160), Size = UDim2.new(1, -16, 0, 18),
				Text = "LOCKED: get a " .. rarity.name, TextColor3 = rarity.color, Font = Enum.Font.FredokaOne })
		else
			textLabel(frame, { Position = UDim2.fromOffset(8, 160), Size = UDim2.new(1, -16, 0, 18),
				Text = "You have " .. count .. "/3", TextColor3 = Color3.fromRGB(150, 255, 170), Font = Enum.Font.FredokaOne })
		end
		local buy = makeButton(frame, "$" .. formatMoney(item.price), best >= needed and Color3.fromRGB(60, 200, 90)
			or Color3.fromRGB(100, 100, 110), { Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32) })
		buy.Activated:Connect(function()
			shopEvent:FireServer("item", item.id)
		end)
	end
end

function shopBuilders.CRATES()
	for index, crate in ipairs(Config.Crates or {}) do
		local frame = card(crate.color, index)
		viewport(frame, crateModel(crate.color), 80)
		textLabel(frame, { Position = UDim2.fromOffset(8, 90), Size = UDim2.new(1, -16, 0, 26), Text = crate.name,
			TextColor3 = crate.color })
		-- Chances de chaque rareté
		local lines = {}
		for _, rarity in ipairs(Config.Rarities) do
			local chance = crate.chances[rarity.id]
			if chance then
				table.insert(lines, rarity.name .. " " .. chance .. "%")
			end
		end
		textLabel(frame, { Position = UDim2.fromOffset(8, 118), Size = UDim2.new(1, -16, 0, 56), Text = table.concat(lines, "\n"),
			TextColor3 = Color3.fromRGB(200, 210, 230), Font = Enum.Font.FredokaOne, TextWrapped = true })
		local buy = makeButton(frame, "OPEN $" .. formatMoney(crate.price),
			cash.Value >= crate.price and Color3.fromRGB(60, 200, 90) or Color3.fromRGB(100, 100, 110),
			{ Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32) })
		buy.Activated:Connect(function()
			shopEvent:FireServer("crate", crate.id)
		end)
	end
end

function shopBuilders.BOOSTS()
	for index, boost in ipairs(Config.Boosts or {}) do
		local frame = card(boost.color, index)
		textLabel(frame, { Position = UDim2.fromOffset(8, 14), Size = UDim2.new(1, -16, 0, 56),
			Text = boost.id == "speed" and "»»" or "x2", TextColor3 = boost.color, Font = Enum.Font.LuckiestGuy })
		textLabel(frame, { Position = UDim2.fromOffset(8, 76), Size = UDim2.new(1, -16, 0, 28), Text = boost.name })
		textLabel(frame, { Position = UDim2.fromOffset(8, 106), Size = UDim2.new(1, -16, 0, 44), Text = boost.description,
			TextColor3 = Color3.fromRGB(200, 210, 230), Font = Enum.Font.FredokaOne, TextWrapped = true })
		local left = (player:GetAttribute("Boost_" .. boost.id) or 0) - workspace:GetServerTimeNow()
		if left > 0 then
			textLabel(frame, { Position = UDim2.fromOffset(8, 152), Size = UDim2.new(1, -16, 0, 18),
				Text = "Active: " .. math.ceil(left / 60) .. " min left", TextColor3 = Color3.fromRGB(150, 255, 170),
				Font = Enum.Font.FredokaOne })
		end
		local price = math.max(boost.price, math.floor((player:GetAttribute("Income") or 0) * boost.incomeMinutes * 60))
		local buy = makeButton(frame, "$" .. formatMoney(price),
			cash.Value >= price and Color3.fromRGB(60, 200, 90) or Color3.fromRGB(100, 100, 110),
			{ Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32) })
		buy.Activated:Connect(function()
			shopEvent:FireServer("boost", boost.id)
		end)
	end
end

function shopBuilders.ROBUX()
	for index, pass in ipairs(Config.GamePasses or {}) do
		local frame = card(Color3.fromRGB(255, 200, 40), index)
		textLabel(frame, { Position = UDim2.fromOffset(8, 14), Size = UDim2.new(1, -16, 0, 60), Text = "R$",
			TextColor3 = Color3.fromRGB(255, 220, 60), Font = Enum.Font.LuckiestGuy })
		textLabel(frame, { Position = UDim2.fromOffset(8, 84), Size = UDim2.new(1, -16, 0, 30), Text = pass.name })
		textLabel(frame, { Position = UDim2.fromOffset(8, 118), Size = UDim2.new(1, -16, 0, 44), Text = pass.description,
			TextColor3 = Color3.fromRGB(200, 210, 230), Font = Enum.Font.FredokaOne, TextWrapped = true })
		local owned = player:GetAttribute("Pass_" .. pass.key) == true
		local buy = makeButton(frame, owned and "OWNED" or ("R$ " .. pass.robux), owned and Color3.fromRGB(100, 100, 110)
			or Color3.fromRGB(255, 170, 0), { Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32) })
		buy.Activated:Connect(function()
			if owned then
				return
			end
			if pass.id == 0 then
				localNotify(pass.name .. ": coming soon!")
			else
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)
	end
end

local refreshPanel -- défini plus bas

for _, name in ipairs(SHOP_TABS) do
	local button = makeButton(subTabs, name, Color3.fromRGB(50, 70, 110), { Size = UDim2.fromOffset(130, 36) })
	subButtons[name] = button
	button.Activated:Connect(function()
		shopTab = name
		refreshPanel()
	end)
end

function tabs.SHOP()
	for name, button in pairs(subButtons) do
		button.BackgroundColor3 = name == shopTab and Color3.fromRGB(60, 200, 90) or Color3.fromRGB(50, 70, 110)
	end
	shopBuilders[shopTab]()
end

function tabs.UPGRADES()
	local cashValue = cash.Value
	for index, upgrade in ipairs(Config.Upgrades) do
		local frame = card(Color3.fromRGB(80, 200, 255), index)
		local level = player:GetAttribute("Up_" .. upgrade.id) or 0
		local price = upgrade.prices[level + 1]
		textLabel(frame, { Position = UDim2.fromOffset(8, 16), Size = UDim2.new(1, -16, 0, 44), Text = upgrade.name,
			Font = Enum.Font.LuckiestGuy, TextColor3 = Color3.fromRGB(120, 220, 255) })
		textLabel(frame, { Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 0, 30),
			Text = "Level " .. level .. " / " .. #upgrade.prices })
		textLabel(frame, { Position = UDim2.fromOffset(8, 102), Size = UDim2.new(1, -16, 0, 40), Text = upgrade.description,
			TextColor3 = Color3.fromRGB(200, 210, 230), Font = Enum.Font.FredokaOne, TextWrapped = true })
		local canBuy = price and cashValue >= price
		local buy = makeButton(frame, price and ("$" .. formatMoney(price)) or "MAX",
			canBuy and Color3.fromRGB(60, 200, 90) or Color3.fromRGB(100, 100, 110),
			{ Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32) })
		buy.Activated:Connect(function()
			shopEvent:FireServer("upgrade", upgrade.id)
		end)
	end
end

function tabs.INDEX()
	local found = {}
	for id in string.gmatch(player:GetAttribute("Discovered") or "", "[^,]+") do
		found[id] = true
	end
	local count = 0
	for index, def in ipairs(Config.Creatures) do
		local rarity = raritiesById[def.rarity]
		local known = found[def.id] == true
		if known then
			count += 1
		end
		local frame = card(rarity.color, (rarityIndex[def.rarity] or 1) * 100 + index)
		-- La créature en 3D (en silhouette noire tant qu'elle n'est pas trouvée)
		local preview = critterPreview(def.id)
		if preview then
			viewport(frame, preview, 100, not known)
		end
		textLabel(frame, { Position = UDim2.fromOffset(8, 116), Size = UDim2.new(1, -16, 0, 28), Text = known and def.name or "???" })
		textLabel(frame, { Position = UDim2.fromOffset(8, 148), Size = UDim2.new(1, -16, 0, 22), Text = rarity.name,
			TextColor3 = rarity.color, Font = Enum.Font.FredokaOne })
		textLabel(frame, { Position = UDim2.fromOffset(8, 176), Size = UDim2.new(1, -16, 0, 22),
			Text = known and ("$" .. formatMoney(def.income) .. "/s") or "Not found yet",
			TextColor3 = Color3.fromRGB(255, 220, 60), Font = Enum.Font.FredokaOne })
	end
	panelTitle.Text = "INDEX  " .. count .. " / " .. #Config.Creatures
end

function refreshPanel()
	subTabs.Visible = currentTab == "SHOP"
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
	if currentTab then
		panelTitle.Text = currentTab
		tabs[currentTab]()
	end
end

local function openTab(name)
	if currentTab == name and panel.Visible then
		panel.Visible = false
		currentTab = nil
		return
	end
	currentTab = name
	panel.Visible = true
	panelScale.Scale = 0.6
	TweenService:Create(panelScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	refreshPanel()
end
closeButton.Activated:Connect(function()
	panel.Visible = false
	currentTab = nil
end)

-- Le menu se met à jour tout seul quand quelque chose change
local refreshQueued = false
local function queueRefresh()
	if panel.Visible and not refreshQueued then
		refreshQueued = true
		task.delay(0.3, function()
			refreshQueued = false
			if panel.Visible then
				refreshPanel()
			end
		end)
	end
end
player.AttributeChanged:Connect(queueRefresh)
cash.Changed:Connect(function()
	if currentTab == "UPGRADES" then
		queueRefresh()
	end
end)

local sideMenu = Instance.new("Frame")
sideMenu.AnchorPoint = Vector2.new(0, 0.5)
sideMenu.Position = UDim2.new(0, 12, 0.5, 0)
sideMenu.Size = UDim2.fromOffset(130, 190)
sideMenu.BackgroundTransparency = 1
sideMenu.Parent = gui
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 10)
sideLayout.Parent = sideMenu
for _, entry in ipairs({
	{ "SHOP", "🛒 SHOP", Color3.fromRGB(60, 200, 90) },
	{ "UPGRADES", "⚡ UPGRADES", Color3.fromRGB(40, 140, 255) },
	{ "INDEX", "📖 INDEX", Color3.fromRGB(170, 80, 255) },
}) do
	local button = makeButton(sideMenu, entry[2], entry[3], { Size = UDim2.fromOffset(130, 52) })
	button.Activated:Connect(function()
		openTab(entry[1])
	end)
end


-- ============================================================
-- Ouverture de caisse : roulette de créatures qui ralentit, puis la grande révélation
-- ============================================================
local crateEvent = ReplicatedStorage:WaitForChild("CrateOpened", 10)
local rollFrame = Instance.new("Frame")
rollFrame.AnchorPoint = Vector2.new(0.5, 0.5)
rollFrame.Position = UDim2.fromScale(0.5, 0.5)
rollFrame.Size = UDim2.fromOffset(640, 300)
rollFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 45)
rollFrame.Visible = false
rollFrame.ZIndex = 20
rollFrame.Parent = gui
rounded(rollFrame, 16)
local rollStroke = Instance.new("UIStroke")
rollStroke.Thickness = 4
rollStroke.Parent = rollFrame
local rollTitle = textLabel(rollFrame, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 40),
	Font = Enum.Font.LuckiestGuy, ZIndex = 21 })
local strip = Instance.new("Frame")
strip.Position = UDim2.fromOffset(10, 60)
strip.Size = UDim2.new(1, -20, 0, 170)
strip.BackgroundColor3 = Color3.fromRGB(12, 15, 28)
strip.ClipsDescendants = true
strip.ZIndex = 21
strip.Parent = rollFrame
rounded(strip, 10)
local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0)
marker.Position = UDim2.new(0.5, 0, 0, 52)
marker.Size = UDim2.fromOffset(6, 186)
marker.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
marker.ZIndex = 25
marker.Parent = rollFrame
local rollResult = textLabel(rollFrame, { Position = UDim2.fromOffset(10, 240), Size = UDim2.new(1, -20, 0, 48),
	Font = Enum.Font.LuckiestGuy, ZIndex = 21 })

local function rollCard(parent, def, x)
	local rarity = raritiesById[def.rarity]
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(x, 10)
	frame.Size = UDim2.fromOffset(120, 150)
	frame.BackgroundColor3 = Color3.fromRGB(40, 55, 90)
	frame.ZIndex = 22
	frame.Parent = parent
	rounded(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = rarity.color
	stroke.Parent = frame
	local preview = critterPreview(def.id)
	if preview then
		local view = viewport(frame, preview, 100)
		view.ZIndex = 23
	end
	local label = textLabel(frame, { Position = UDim2.fromOffset(4, 112), Size = UDim2.new(1, -8, 0, 32),
		Text = rarity.name, TextColor3 = rarity.color, Font = Enum.Font.FredokaOne })
	label.ZIndex = 23
end

local creaturesById = {}
for _, def in ipairs(Config.Creatures) do
	creaturesById[def.id] = def
end

if crateEvent then
	crateEvent.OnClientEvent:Connect(function(crateId, defId)
		local crate, result = nil, creaturesById[defId]
		for _, candidate in ipairs(Config.Crates or {}) do
			if candidate.id == crateId then
				crate = candidate
			end
		end
		if not crate or not result then
			return
		end
		panel.Visible = false
		currentTab = nil
		for _, child in ipairs(strip:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		-- Bande de 40 cartes tirées au hasard parmi les raretés de la caisse ; la 35e est le résultat
		local pool = {}
		for _, def in ipairs(Config.Creatures) do
			if crate.chances[def.rarity] then
				table.insert(pool, def)
			end
		end
		local reel = Instance.new("Frame")
		reel.BackgroundTransparency = 1
		reel.Size = UDim2.fromOffset(40 * 130, 170)
		reel.ZIndex = 21
		reel.Parent = strip
		for i = 1, 40 do
			local def = (i == 35) and result or pool[math.random(#pool)]
			rollCard(reel, def, (i - 1) * 130)
		end
		rollTitle.Text = crate.name:upper()
		rollTitle.TextColor3 = crate.color
		rollStroke.Color = crate.color
		rollResult.Text = ""
		rollFrame.Visible = true
		local stripWidth = strip.AbsoluteSize.X
		local finalX = -((35 - 1) * 130 + 60 - stripWidth / 2) + math.random(-40, 40)
		reel.Position = UDim2.fromOffset(0, 0)
		local spin = TweenService:Create(reel, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(finalX, 0) })
		spin:Play()
		spin.Completed:Wait()
		local rarity = raritiesById[result.rarity]
		rollResult.Text = "YOU GOT " .. result.name:upper() .. "!"
		rollResult.TextColor3 = rarity.color
		if (rarityIndex[result.rarity] or 1) >= 5 then
			flash.BackgroundTransparency = 0.3
			TweenService:Create(flash, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
			divineSound:Play()
		end
		task.wait(2.5)
		rollFrame.Visible = false
	end)
end

-- ============================================================
-- Boosts actifs : petites cases avec minuteur, en bas de l'écran
-- ============================================================
local boostBar = Instance.new("Frame")
boostBar.AnchorPoint = Vector2.new(0.5, 1)
boostBar.Position = UDim2.new(0.5, 0, 1, -212)
boostBar.Size = UDim2.fromOffset(300, 56)
boostBar.BackgroundTransparency = 1
boostBar.Parent = gui
local boostLayout = Instance.new("UIListLayout")
boostLayout.FillDirection = Enum.FillDirection.Horizontal
boostLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
boostLayout.Padding = UDim.new(0, 8)
boostLayout.Parent = boostBar
local boostSlots = {}
for _, boost in ipairs(Config.Boosts or {}) do
	local slot = Instance.new("Frame")
	slot.Size = UDim2.fromOffset(64, 56)
	slot.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
	slot.BackgroundTransparency = 0.15
	slot.Visible = false
	slot.Parent = boostBar
	rounded(slot, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = boost.color
	stroke.Thickness = 2
	stroke.Parent = slot
	textLabel(slot, { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 0, 30),
		Text = boost.id == "speed" and "»»" or "x2", TextColor3 = boost.color, Font = Enum.Font.LuckiestGuy })
	local timer = textLabel(slot, { Position = UDim2.fromOffset(2, 32), Size = UDim2.new(1, -4, 0, 20),
		Font = Enum.Font.FredokaOne })
	boostSlots[boost.id] = { frame = slot, timer = timer }
end
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		for id, slot in pairs(boostSlots) do
			local left = (player:GetAttribute("Boost_" .. id) or 0) - now
			slot.frame.Visible = left > 0
			if left > 0 then
				slot.timer.Text = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
			end
		end
		task.wait(0.5)
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
		local testPanel = Instance.new("Frame")
		testPanel.AnchorPoint = Vector2.new(1, 0.5)
		testPanel.Position = UDim2.new(1, -12, 0.5, 0)
		testPanel.Size = UDim2.fromOffset(150, 300)
		testPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		testPanel.BackgroundTransparency = 0.25
		testPanel.Parent = gui
		rounded(testPanel, 10)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = testPanel
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 8)
		padding.Parent = testPanel
		textLabel(testPanel, { Size = UDim2.fromOffset(130, 18), Text = "TEST (Studio)", TextColor3 = Color3.fromRGB(80, 200, 255) })
		local function addButton(text, command, amount)
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(130, 28)
			button.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
			button.Font = Enum.Font.FredokaOne
			button.TextScaled = true
			button.TextColor3 = Color3.new(1, 1, 1)
			button.Text = text
			button.Parent = testPanel
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
