-- ============================================================
-- Tsunami Critters : installe / met à jour le jeu depuis GitHub, sans Rojo.
-- À lancer depuis la barre de commande de Roblox Studio (jeu ARRÊTÉ),
-- dans une NOUVELLE place "Baseplate" (pas dans Garage Tycoon).
-- Ne touche pas à tes modèles (ServerStorage > Assets).
-- ============================================================

local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local BASE = "https://raw.githubusercontent.com/sellinnoha-dev/f1/main/src/"
local API = "https://api.github.com/repos/sellinnoha-dev/f1/contents/src/"

-- Sécurité : on ne mélange pas les deux jeux
if ServerScriptService:FindFirstChild("TycoonServer") then
	warn("[Tsunami] Tu es dans la place de Garage Tycoon ! Ouvre une NOUVELLE place (Fichier > Nouveau > Baseplate), puis relance la ligne.")
	return
end

-- { fichier sur GitHub, service, nom dans Studio, type de script }
local FILES = {
	{ "shared/Config.luau", game:GetService("ReplicatedStorage"), "Config", "ModuleScript" },
	{ "shared/FormatMoney.luau", game:GetService("ReplicatedStorage"), "FormatMoney", "ModuleScript" },
	{ "server/WaveServer.server.luau", ServerScriptService, "WaveServer", "Script" },
	{ "client/WaveClient.client.luau", game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "WaveClient", "LocalScript" },
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
		warn("[Tsunami] Impossible de télécharger " .. path .. " : " .. tostring(source))
	end
end

local config = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
local version = config and config.Source:match('Config.Version = "([^"]*)"') or "?"
print(string.format("[Tsunami] Mise à jour terminée : %d/%d scripts à jour (version %s). Fais Ctrl+S puis F5.",
	updated, #FILES, version))
