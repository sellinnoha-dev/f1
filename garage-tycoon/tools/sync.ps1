# ============================================================
# Garage Tycoon : synchro automatique GitHub -> ce PC -> Roblox Studio
# Lancé par GarageTycoon.bat. Laisse la fenêtre ouverte pendant que tu travailles :
# chaque nouvelle version envoyée sur GitHub arrive toute seule dans Studio.
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # accélère les téléchargements

$Repo = "sellinnoha-dev/f1"
$RojoVersion = "7.4.4"
$Root = Join-Path $env:USERPROFILE "GarageTycoon"
$Project = Join-Path $Root "project"
$Rojo = Join-Path $Root "rojo.exe"
$CheckEverySeconds = 60 # GitHub limite à 60 vérifications par heure sans compte

New-Item -ItemType Directory -Force -Path $Root | Out-Null

# Identifiant de la dernière version publiée sur GitHub
function Get-LatestSha {
	try {
		(Invoke-RestMethod "https://api.github.com/repos/$Repo/commits/main" -Headers @{ "User-Agent" = "GarageTycoonSync" }).sha
	} catch {
		$null
	}
}

# Télécharge le projet et remplace les fichiers locaux par la nouvelle version
function Update-Project {
	$zip = Join-Path $Root "repo.zip"
	$tmp = Join-Path $Root "tmp"
	Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/main.zip" -OutFile $zip
	if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
	Expand-Archive $zip $tmp -Force
	$source = Get-ChildItem $tmp -Directory | Select-Object -First 1
	# Ne jamais écraser le fichier de jeu déjà présent : il peut contenir tes modèles
	$keep = @()
	if (Test-Path (Join-Path $Project "build\GarageTycoon.rbxlx")) { $keep = @("/XF", "GarageTycoon.rbxlx") }
	robocopy $source.FullName $Project /MIR /NFL /NDL /NJH /NJS /NP @keep | Out-Null
	Remove-Item $zip -Force
	Remove-Item $tmp -Recurse -Force
}

if (-not (Test-Path $Rojo)) {
	Write-Host "Premiere utilisation : installation de Rojo..."
	$zip = Join-Path $Root "rojo.zip"
	Invoke-WebRequest "https://github.com/rojo-rbx/rojo/releases/download/v$RojoVersion/rojo-$RojoVersion-windows-x86_64.zip" -OutFile $zip
	Expand-Archive $zip $Root -Force
	Remove-Item $zip -Force
	& $Rojo plugin install
	Write-Host ""
	Write-Host "Plugin Rojo installe. Si Roblox Studio etait ouvert, ferme-le et relance-le."
}

Write-Host "Recuperation de la derniere version du jeu..."
$sha = Get-LatestSha
Update-Project

$server = Start-Process -FilePath $Rojo -ArgumentList "serve", "`"$Project\default.project.json`"" -NoNewWindow -PassThru

Write-Host ""
Write-Host "=========================================================="
Write-Host " Synchro active !"
Write-Host " 1. Dans Studio, ouvre : $Project\build\GarageTycoon.rbxlx"
Write-Host " 2. Onglet Plugins > Rojo > Connect"
Write-Host " Laisse cette fenetre ouverte : les nouvelles versions"
Write-Host " arrivent toutes seules dans Studio."
Write-Host "=========================================================="

try {
	while ($true) {
		Start-Sleep -Seconds $CheckEverySeconds
		if ($server.HasExited) {
			Write-Host "Rojo s'est arrete. Relance GarageTycoon.bat."
			break
		}
		$latest = Get-LatestSha
		if ($latest -and $latest -ne $sha) {
			Update-Project
			$sha = $latest
			Write-Host "$(Get-Date -Format HH:mm:ss)  Nouvelle version recue ! Appuie sur F5 dans Studio pour tester."
		}
	}
} finally {
	if (-not $server.HasExited) { Stop-Process -Id $server.Id }
}
