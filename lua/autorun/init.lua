if SERVER then
	AddCSLuaFile("revive/client/cl_revive.lua")
	AddCSLuaFile("revive/sh_revive.lua")
	include("revive/server/sv_revive.lua")
	include("revive/sh_revive.lua")
else
	include("revive/client/cl_revive.lua")
	include("revive/sh_revive.lua")
end