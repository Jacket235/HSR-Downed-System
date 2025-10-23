if SERVER then
	AddCSLuaFile("revive/client/cl_revive.lua")
	AddCSLuaFile("revive/sh_revive.lua")
	include("revive/server/sv_revive.lua")
	include("revive/sh_revive.lua")

	resource.AddFile("materials/tlou_online_hud/small-health.png")
else
	include("revive/client/cl_revive.lua")
	include("revive/sh_revive.lua")
end