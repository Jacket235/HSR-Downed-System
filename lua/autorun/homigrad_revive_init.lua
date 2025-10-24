if SERVER then
	AddCSLuaFile("revive/client/cl_revive.lua")
	AddCSLuaFile("revive/sh_revive.lua")
	include("revive/server/sv_revive.lua")
	include("revive/sh_revive.lua")

	resource.AddFile("materials/tlou_online_hud/small-health.png")
	
	resource.AddSingleFile("resource/fonts/D-DIN.ttf")
	resource.AddSingleFile("resource/fonts/D-DIN-Bold.ttf")
	resource.AddSingleFile("resource/fonts/D-DINCondensed.ttf")
	resource.AddSingleFile("resource/fonts/D-DINCondensed-Bold.ttf")
	resource.AddSingleFile("resource/fonts/D-DINExp.ttf")
	resource.AddSingleFile("resource/fonts/D-DINExp-Bold.ttf")
	resource.AddSingleFile("resource/fonts/D-DINExp-Italic.ttf")
	resource.AddSingleFile("resource/fonts/D-DIN-Italic.ttf")
else
	include("revive/client/cl_revive.lua")
	include("revive/sh_revive.lua")
end