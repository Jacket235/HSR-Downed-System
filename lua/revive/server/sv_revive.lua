local function createDownedRagdoll(ply)
	local ragdoll = ents.Create("prop_ragdoll")
	ragdoll.health = 100
	ragdoll:SetNWFloat("bleedOutStartTime", CurTime())
	ragdoll:SetModel(ply:GetModel())
	ragdoll:SetPos(ply:GetPos())
	ragdoll:SetAngles(ply:GetAngles())
	ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ragdoll:Spawn()
	ragdoll:Activate()

	// this part was just stolen from the original shit homigrad code
    local vel = ply:GetVelocity()/1 + (force or Vector(0,0,0))
	for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local physobj = ragdoll:GetPhysicsObjectNum( i )
		local ragbonename = ragdoll:GetBoneName(ragdoll:TranslatePhysBoneToBone(i))
		local bone = ply:LookupBone(ragbonename)
		if(bone)then
			local bonemat = ply:GetBoneMatrix(bone)
			if(bonemat)then
				local bonepos = bonemat:GetTranslation()
				local boneang = bonemat:GetAngles()
				physobj:SetPos(bonepos, true)
				physobj:SetAngles(boneang)
				if not ply:Alive() then vel = vel end
				physobj:AddVelocity(vel)
			end
		end
	end

	ply:SetNWBool("downed", true)
	ply:SetNWEntity("downed_ragdoll", ragdoll)

	return ragdoll
end

local function createRagdollController(ply, ragdoll)
	ragdoll.bullseye = ents.Create("npc_bullseye")
	ragdoll:SetNWEntity("owner", ply)

	local bullseye = ragdoll.bullseye
	local ragdollHead = ragdoll:GetPhysicsObjectNum(10)
	bullseye:SetPos(ragdollHead:GetPos())
	bullseye:SetParent(ragdoll, ragdoll:LookupAttachment("eyes"))
	bullseye:SetHealth(1000)
	bullseye:Spawn()
	bullseye:Activate()
	bullseye:SetSolid(SOLID_NONE)

	ply:Spectate(OBS_MODE_CHASE)
	ply:UnSpectate()
	ply:SetMoveType(MOVETYPE_OBSERVER)
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	ply:SpectateEntity(ply:GetNWEntity("downed_ragdoll"))
	ply:StripWeapons()
end

hook.Add("PlayerHurt", "homigrad_style_revives_ph", function(ply, atkr, hp, dmg)
	if hp <= 0 and not ply:GetNWBool("downed") then 
		ply:SetHealth(1)

		local ragdoll = createDownedRagdoll(ply)
		local controller = createRagdollController(ply, ragdoll)
	end
end)

hook.Add("Think", "homigrad_style_revives_think", function()
	for _, ply in ipairs(player.GetAll()) do
		if ply:GetNWBool("downed") then
			local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

			if IsValid(downed_ragdoll) then
				local elapsedTime = CurTime() - downed_ragdoll:GetNWFloat("bleedOutStartTime") 

				if elapsedTime >= 5 then
					ply:Kill()
					ply:SetNWBool("downed", false)
				end
			end
		end
	end
end)

hook.Add("PlayerDeath", "homigrad_style_revives_pd", function(ply, _, atkr)
	if IsValid(ply:GetRagdollEntity()) then 
		ply:GetRagdollEntity():Remove()
	end

	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

	if IsValid(downed_ragdoll) then
		ply:SetNWBool("downed", false)
        ply:Spectate(OBS_MODE_CHASE)
        ply:SetMoveType(MOVETYPE_OBSERVER)
        ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        ply:SpectateEntity(downed_ragdoll)
    end
end)

hook.Add("PlayerSpawn", "homigrad_style_revives_ps", function(ply, _)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")
	
	if IsValid(downed_ragdoll) and IsValid(downed_ragdoll.bullseye) then
		ply:UnSpectate()
		downed_ragdoll:Remove()
		downed_ragdoll.bullseye:Remove()
		ply:SetNWBool("downed", false)
		ply:SetNWEntity("downed_ragdoll", nil)
	end
end)