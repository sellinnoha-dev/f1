-- Transforme un nombre en texte court : 1500 -> "1.5K", 2000000 -> "2M"
-- Utilisé par le serveur (panneaux) et par le client (compteur d'argent).
return function(n)
	n = math.floor(n)
	local text
	if n >= 1e9 then
		text = string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		text = string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		text = string.format("%.1fK", n / 1e3)
	else
		return tostring(n)
	end
	return (text:gsub("%.0([KMB])", "%1"))
end
