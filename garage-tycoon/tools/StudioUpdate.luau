-- ============================================================
-- Garage Tycoon : mise à jour depuis GitHub, sans Rojo.
-- À lancer depuis la barre de commande de Roblox Studio (jeu ARRÊTÉ) :
--   la ligne à coller est dans le README, section "Mettre à jour le jeu".
-- Remplace le code des scripts par la dernière version du dépôt.
-- Ne touche pas à tes modèles (ServerStorage > Assets) ni au reste de la carte.
-- ============================================================

local HttpService = game:GetService("HttpService")
local BASE = "https://raw.githubusercontent.com/sellinnoha-dev/f1/main/src/"
local API = "https://api.github.com/repos/sellinnoha-dev/f1/contents/src/"

-- { fichier sur GitHub, service, nom dans Studio, type de script }
local FILES = {
	{ "shared/Config.luau", game:GetService("ReplicatedStorage"), "Config", "ModuleScript" },
	{ "shared/FormatMoney.luau", game:GetService("ReplicatedStorage"), "FormatMoney", "ModuleScript" },
	{ "server/TycoonServer.server.luau", game:GetService("ServerScriptService"), "TycoonServer", "Script" },
	{ "client/CashHud.client.luau", game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "CashHud", "LocalScript" },
	{ "client/CarSpinner.client.luau", game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "CarSpinner", "LocalScript" },
}

local stamp = tostring(os.time())

-- L'API GitHub donne toujours la dernière version (raw.githubusercontent garde
-- parfois une vieille copie en cache quelques minutes). En secours, on utilise raw.
local function fetch(path)
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = API .. path .. "?ref=main&v=" .. stamp,
			Method = "GET",
			Headers = { Accept = "application/vnd.github.raw" },
		})
	end)
	if ok and response.Success then
		return response.Body
	end
	return HttpService:GetAsync(BASE .. path .. "?v=" .. stamp, true)
end
local updated = 0
for _, file in ipairs(FILES) do
	local path, parent, name, className = file[1], file[2], file[3], file[4]
	local ok, source = pcall(fetch, path)
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

local config = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
local version = config and config.Source:match('Config.Version = "([^"]*)"') or "?"
print(string.format("[Garage Tycoon] Mise à jour terminée : %d/%d scripts à jour (version %s). Fais Ctrl+S puis F5.",
	updated, #FILES, version))
