-- ============================================================
-- Garage Tycoon : mise à jour depuis GitHub, sans Rojo.
-- À lancer depuis la barre de commande de Roblox Studio (jeu ARRÊTÉ) :
--   la ligne à coller est dans le README, section "Mettre à jour le jeu".
-- Remplace le code des scripts par la dernière version du dépôt.
-- Ne touche pas à tes modèles (ServerStorage > Assets) ni au reste de la carte.
-- ============================================================

local HttpService = game:GetService("HttpService")
local BASE = "https://raw.githubusercontent.com/sellinnoha-dev/f1/main/src/"

-- { fichier sur GitHub, service, nom dans Studio, type de script }
local FILES = {
	{ "shared/Config.luau", game:GetService("ReplicatedStorage"), "Config", "ModuleScript" },
	{ "shared/FormatMoney.luau", game:GetService("ReplicatedStorage"), "FormatMoney", "ModuleScript" },
	{ "server/TycoonServer.server.luau", game:GetService("ServerScriptService"), "TycoonServer", "Script" },
	{ "client/CashHud.client.luau", game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "CashHud", "LocalScript" },
	{ "client/CarSpinner.client.luau", game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "CarSpinner", "LocalScript" },
}

local stamp = tostring(os.time()) -- évite de récupérer une vieille version en cache
local updated = 0
for _, file in ipairs(FILES) do
	local path, parent, name, className = file[1], file[2], file[3], file[4]
	local ok, source = pcall(function()
		return HttpService:GetAsync(BASE .. path .. "?v=" .. stamp, true)
	end)
	if ok then
		local script = parent:FindFirstChild(name)
		if not script or script.ClassName ~= className then
			if script then
				script:Destroy()
			end
			script = Instance.new(className)
			script.Name = name
			script.Parent = parent
		end
		script.Source = source
		updated += 1
	else
		warn("[Garage Tycoon] Impossible de télécharger " .. path .. " : " .. tostring(source))
	end
end

print(string.format("[Garage Tycoon] Mise à jour terminée : %d/%d scripts à jour. Fais Ctrl+S puis F5.", updated, #FILES))
