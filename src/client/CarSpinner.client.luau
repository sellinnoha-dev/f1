-- ============================================================
-- Fait tourner les voitures des showrooms (côté joueur).
-- Le serveur pose les voitures et les marque "SpinningCar" ;
-- ici on les fait tourner localement, sans rien envoyer sur le réseau.
-- ============================================================

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPEED = math.rad(30) -- degrés par seconde

local cars = {} -- [voiture] = { root, base, offset }

local function add(car)
	cars[car] = {}
end

local function remove(car)
	cars[car] = nil
end

CollectionService:GetInstanceAddedSignal("SpinningCar"):Connect(add)
CollectionService:GetInstanceRemovedSignal("SpinningCar"):Connect(remove)
for _, car in ipairs(CollectionService:GetTagged("SpinningCar")) do
	add(car)
end

RunService.RenderStepped:Connect(function()
	local rotation = CFrame.Angles(0, os.clock() * SPEED, 0)
	for car, state in pairs(cars) do
		if not state.offset then
			-- Les pièces peuvent arriver un peu après la voiture : on attend qu'elles soient là
			local root = car.PrimaryPart
			local base = car:GetAttribute("SpinBase")
			if not root or not base then
				continue
			end
			state.root = root
			state.base = base
			state.offset = base:ToObjectSpace(root.CFrame)
		end
		state.root.CFrame = state.base * rotation * state.offset
	end
end)
