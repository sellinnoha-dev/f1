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
	label.Font = Enum.Font.GothamBlack
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
cashFrame.Position = UDim2.new(0.5, 0, 1, -20)
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
	Size = UDim2.new(1, -20, 0.28, 0), Position = UDim2.new(0, 10, 0.7, -2), Font = Enum.Font.GothamBold,
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
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -86), Size = UDim2.fromOffset(260, 26),
	Font = Enum.Font.GothamBold,
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
-- La vague : dessinée ici (plus fluide), le serveur calcule la même position
-- ============================================================
local waveModel = nil

local function buildWave(height, color)
	local model = Instance.new("Model")
	model.Name = "Tsunami"
	local width = Config.PathWidth + 60
	local function wavePart(name, size, props)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size
		for key, value in pairs(props) do
			part[key] = value
		end
		part.Parent = model
		return part
	end
	local body = wavePart("Body", Vector3.new(Config.WaveThickness, height + 12, width), {
		Color = color, Material = Enum.Material.SmoothPlastic, Transparency = 0.2,
	})
	local crest = wavePart("Crest", Vector3.new(Config.WaveThickness * 0.7, 4, width), {
		Color = Color3.fromRGB(235, 250, 255), Material = Enum.Material.SmoothPlastic,
	})
	local lip = Instance.new("WedgePart")
	lip.Name = "Lip"
	lip.Anchored = true
	lip.CanCollide = false
	lip.CanQuery = false
	lip.CanTouch = false
	lip.CastShadow = false
	lip.Size = Vector3.new(width, 10, 12)
	lip.Color = Color3.fromRGB(220, 245, 255)
	lip.Transparency = 0.1
	lip.Parent = model
	local foam = Instance.new("ParticleEmitter")
	foam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	foam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	foam.Size = NumberSequence.new(6, 12)
	foam.Transparency = NumberSequence.new(0.3, 1)
	foam.Lifetime = NumberRange.new(0.8, 1.4)
	foam.Rate = 80
	foam.Speed = NumberRange.new(8, 16)
	foam.SpreadAngle = Vector2.new(40, 40)
	foam.Parent = crest
	model.Parent = workspace
	return model, body, crest, lip
end

local waveParts = {}

RunService.RenderStepped:Connect(function()
	local state = workspace:GetAttribute("WaveState")
	local now = workspace:GetServerTimeNow()
	if state == "active" then
		local height = workspace:GetAttribute("WaveHeight") or 40
		if not waveModel then
			local model, body, crest, lip = buildWave(height, workspace:GetAttribute("WaveColor") or Color3.fromRGB(40, 120, 220))
			waveModel = model
			waveParts = { body = body, crest = crest, lip = lip, height = height }
		end
		local speed = workspace:GetAttribute("WaveSpeed") or 40
		local front = Config.WaveStartX - speed * (now - (workspace:GetAttribute("WaveStart") or now))
		local h = waveParts.height
		local wobble = math.sin(now * 3) * 0.8
		waveParts.body.CFrame = CFrame.new(front + Config.WaveThickness / 2, (h + 12) / 2 - 12 + wobble, 0)
		waveParts.crest.CFrame = CFrame.new(front + Config.WaveThickness * 0.35, h + 2 + wobble, 0)
		-- La lèvre de la vague, penchée vers l'avant
		waveParts.lip.CFrame = CFrame.new(front - 4, h - 3 + wobble, 0) * CFrame.Angles(0, math.rad(90), 0)

		-- La caméra tremble quand la vague est proche
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local distance = math.abs(root.Position.X - front)
			if distance < 120 then
				local strength = (1 - distance / 120) * 0.35
				humanoid.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * strength * 2
			else
				humanoid.CameraOffset = Vector3.zero
			end
		end
	elseif waveModel then
		waveModel:Destroy()
		waveModel = nil
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
	end

	-- Bandeau
	if state == "warning" then
		local left = math.max(0, math.ceil((workspace:GetAttribute("WaveNextAt") or now) - now))
		bannerLabel.Text = "TSUNAMI IN " .. left .. "s - HIDE IN A TRENCH!"
		local flash = math.floor(now * 4) % 2 == 0
		banner.BackgroundColor3 = flash and Color3.fromRGB(200, 30, 40) or Color3.fromRGB(90, 10, 20)
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
-- Touche E « Sell » : seulement sur tes propres créatures
-- ============================================================
local function filterPrompt(prompt)
	local function apply()
		prompt.Enabled = prompt:GetAttribute("OwnerId") == player.UserId
	end
	apply()
	prompt:GetAttributeChangedSignal("OwnerId"):Connect(apply)
end
CollectionService:GetInstanceAddedSignal("OwnerOnly"):Connect(filterPrompt)
for _, prompt in ipairs(CollectionService:GetTagged("OwnerOnly")) do
	filterPrompt(prompt)
end

-- ============================================================
-- Panneau de test (seulement dans Roblox Studio)
-- ============================================================
if RunService:IsStudio() then
	local testEvent = ReplicatedStorage:WaitForChild("TestCommand", 10)
	if testEvent then
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -12, 0.5, 0)
		panel.Size = UDim2.fromOffset(150, 230)
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
			button.Font = Enum.Font.GothamBold
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
	end
end
