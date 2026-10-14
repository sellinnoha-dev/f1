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
