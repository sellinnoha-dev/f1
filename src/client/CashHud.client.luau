-- ============================================================
-- Compteur d'argent affiché en bas de l'écran (côté joueur)
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local formatMoney = require(ReplicatedStorage:WaitForChild("FormatMoney"))
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "CashHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -24)
frame.Size = UDim2.fromOffset(240, 64)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
frame.BackgroundTransparency = 0.2
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 200, 0)
stroke.Thickness = 2
stroke.Parent = frame

local scale = Instance.new("UIScale")
scale.Parent = frame

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBlack
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(255, 200, 0)
label.Text = "$0"
label.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = frame

-- Bonus de rebirth affiché au-dessus du compteur
local bonusLabel = Instance.new("TextLabel")
bonusLabel.AnchorPoint = Vector2.new(0.5, 1)
bonusLabel.Position = UDim2.new(0.5, 0, 0, -4)
bonusLabel.Size = UDim2.new(1, 0, 0, 22)
bonusLabel.BackgroundTransparency = 1
bonusLabel.Font = Enum.Font.GothamBold
bonusLabel.TextScaled = true
bonusLabel.TextColor3 = Color3.fromRGB(200, 140, 255)
bonusLabel.TextStrokeTransparency = 0.3
bonusLabel.Visible = false
bonusLabel.Parent = frame

local leaderstats = player:WaitForChild("leaderstats")
local cash = leaderstats:WaitForChild("Cash")
local rebirths = leaderstats:WaitForChild("Rebirths")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local function updateBonus()
	local bonus = math.floor(Config.RebirthBonus * rebirths.Value * 100 + 0.5)
	bonusLabel.Text = "Rebirth " .. rebirths.Value .. "  ·  +" .. bonus .. "% cash"
	bonusLabel.Visible = rebirths.Value > 0
end
rebirths.Changed:Connect(updateBonus)
updateBonus()
local lastValue = cash.Value

local function update()
	label.Text = "$" .. formatMoney(cash.Value)
	-- Petit effet "pop" quand l'argent augmente
	if cash.Value > lastValue then
		scale.Scale = 1.12
		TweenService:Create(scale, TweenInfo.new(0.2), { Scale = 1 }):Play()
	end
	lastValue = cash.Value
end

cash.Changed:Connect(update)
update()

-- Notifications envoyées par le serveur (ventes au marché, etc.)
local StarterGui = game:GetService("StarterGui")
ReplicatedStorage:WaitForChild("Notify").OnClientEvent:Connect(function(text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = "Garage Tycoon", Text = text, Duration = 5 })
	end)
end)

-- ============================================================
-- Panneau de test (seulement dans Roblox Studio) : boutons pour aller plus vite
-- ============================================================
local RunService = game:GetService("RunService")
if RunService:IsStudio() then
	local testEvent = ReplicatedStorage:WaitForChild("TestCommand", 10)
	if testEvent then
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -12, 0.5, 0)
		panel.Size = UDim2.fromOffset(150, 240)
		panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		panel.BackgroundTransparency = 0.25
		panel.Parent = gui
		local panelCorner = Instance.new("UICorner")
		panelCorner.CornerRadius = UDim.new(0, 10)
		panelCorner.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Parent = panel
		local panelPadding = Instance.new("UIPadding")
		panelPadding.PaddingTop = UDim.new(0, 8)
		panelPadding.Parent = panel

		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromOffset(130, 18)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 200, 0)
		title.Text = "TEST (Studio)"
		title.Parent = panel

		local function addButton(text, command, amount)
			local button = Instance.new("TextButton")
			button.Size = UDim2.fromOffset(130, 28)
			button.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
			button.Font = Enum.Font.GothamBold
			button.TextScaled = true
			button.TextColor3 = Color3.new(1, 1, 1)
			button.Text = text
			button.Parent = panel
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = button
			button.Activated:Connect(function()
				testEvent:FireServer(command, amount)
			end)
		end
		addButton("+ $10K", "addcash", 10000)
		addButton("+ $250K", "addcash", 250000)
		addButton("+1 Rebirth", "addrebirth", 1)
		addButton("Reset Rebirths", "rebirths", 0)
		addButton("Belt: Legendary", "deliver", 4)
		addButton("Belt: EXTREME", "deliver", 6)
	end
end

-- ============================================================
-- Touches E/F : n'affiche que celles qui te concernent
-- (vendre = ton garage, voler = le garage des autres)
-- ============================================================
local CollectionService = game:GetService("CollectionService")

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
