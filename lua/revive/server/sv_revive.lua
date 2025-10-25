util.AddNetworkString("downedPlayerLocations")

include("revive/sh_revive.lua")

local function createDownedRagdoll(ply)
	local ragdoll = ents.Create("prop_ragdoll")
	ragdoll:SetNWFloat("bleedOutStartTime", CurTime())
	ragdoll:SetModel(ply:GetModel())
	ragdoll:SetPos(ply:GetPos())
	ragdoll:SetAngles(ply:GetAngles())
	ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ragdoll:Spawn()
	ragdoll:Activate()

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

local function storeBones(ragdoll, ply)
	local function findPhysBone(bonename)
		local boneIndex = ply:LookupBone(bonename)
		if not boneIndex then return nil end
		local physID = ragdoll:TranslateBoneToPhysBone(boneIndex)
		return physID
	end

	ragdoll.LeftHandPhys  = findPhysBone("ValveBiped.Bip01_L_Hand")
	ragdoll.RightHandPhys = findPhysBone("ValveBiped.Bip01_R_Hand")
end

local function storeWeapons(ragdoll, ply)
	ragdoll.weapons = {}

	for _, weapon in pairs(ply:GetWeapons()) do
	    local weaponInfo = {
	        class = weapon:GetClass(),
	        clip1 = weapon:Clip1(),
	        clip2 = weapon:Clip2(),
	        primaryAmmo = ply:GetAmmoCount(weapon:GetPrimaryAmmoType()),
	        secondaryAmmo = ply:GetAmmoCount(weapon:GetSecondaryAmmoType())
	    }
	    table.insert(ragdoll.weapons, weaponInfo)
	end
end

local function revivePlayer(ply)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")
	local ragdollPos = downed_ragdoll:GetPhysicsObject():GetPos()

	ply:UnSpectate()
	ply:Spawn()
	ply:SetHealth(ply:GetMaxHealth() * .5)
	ply:StripWeapons()
	ply:StripAmmo()
	ply:SetPos(ragdollPos)

	for _, weaponInfo in pairs(downed_ragdoll.weapons or {}) do
        local weapon = ply:Give(weaponInfo.class)
        if IsValid(weapon) then
            weapon:SetClip1(weaponInfo.clip1)
            weapon:SetClip2(weaponInfo.clip2)

            local primaryType = weapon:GetPrimaryAmmoType()
        	local secondaryType = weapon:GetSecondaryAmmoType()

            ply:SetAmmo(weaponInfo.primaryAmmo, primaryType)
            ply:SetAmmo(weaponInfo.secondaryAmmo, secondaryType)
        end
    end

    ply:SetNWBool("downed", false)
    ply:SetNWEntity("downed_ragdoll", nil)
    downedPlayers[ply] = nil
end

downedPlayers = {}

hook.Add("PlayerHurt", "homigrad_style_revives_ph", function(ply, atkr, hp, dmg)
	if not ply:GetNWBool("downed") and hp <= 0  then 
		ply:SetHealth(1)

		local ragdoll = createDownedRagdoll(ply)
		storeBones(ragdoll, ply)
		storeWeapons(ragdoll, ply)
		local controller = createRagdollController(ply, ragdoll)
		downedPlayers[ply] = ragdoll
	end
end)

hook.Add("Think", "homigrad_style_revives_bleed_out", function()
	if table.IsEmpty(downedPlayers) then return end

	for ply, rag in pairs(downedPlayers) do
		if not ply:GetNWBool("downed") or not IsValid(rag) then continue end

		local savior = rag:GetNWEntity("savior")
		local startBleedOutTime = rag:GetNWFloat("bleedOutStartTime")

		if IsValid(savior) and not rag.pauseBleedOutTime then
			rag.pauseBleedOutTime = CurTime()
			rag:SetNWFloat("bleedOutPausedElapsed", CurTime() - startBleedOutTime)
		end
		if not IsValid(savior) and rag.pauseBleedOutTime then
			local pauseDuration = CurTime() - rag.pauseBleedOutTime
			rag.pauseBleedOutTime = nil
			rag:SetNWFloat("bleedOutStartTime", startBleedOutTime + pauseDuration)
			rag:SetNWFloat("bleedOutPausedElapsed", -1)
			startBleedOutTime = rag:GetNWFloat("bleedOutStartTime")
		end

		local elapsedTime = CurTime() - startBleedOutTime
		
		if rag.pauseBleedOutTime then continue end

		if elapsedTime >= BLEED_OUT_TIME then
			ply:SetNWBool("downed", false)
			ply:Kill()	
		end
	end
end)

hook.Add("Think", "homigrad_style_revives_ragdoll_control", function()
	if table.IsEmpty(downedPlayers) then return end

	for ply, rag in pairs(downedPlayers) do
		if not IsValid(ply) then
			if IsValid(rag) then
				rag:Remove()
			end

			downedPlayers[ply] = nil

			net.Start("downedPlayerLocations")
				net.WriteTable(downedPlayers)
			net.Send(player.GetAll())
			continue
		end
		if not ply:GetNWBool("downed") or not IsValid(ply:GetNWEntity("downed_ragdoll")) then continue end
		
		local downed_ragdoll = rag

		local headIndex = downed_ragdoll:LookupAttachment("eyes")
		local head = downed_ragdoll:GetAttachment(headIndex)

		local trace = util.TraceLine({
			start = head.Pos,
			endpos = head.Pos + ply:EyeAngles():Forward() * 150,
			filter = { ply, downed_ragdoll }
		})

		-- weak arm settings (injured feel)
        local springStrength = 15     -- weak pull
        local damping = 9             -- strong slowdown

		if ply:KeyDown(IN_ATTACK) and downed_ragdoll.LeftHandPhys then
			local phys = downed_ragdoll:GetPhysicsObjectNum(downed_ragdoll.LeftHandPhys)
			if not IsValid(phys) then continue end

            local targetPos = trace.HitPos
            local currentPos = phys:GetPos()
            local dir = targetPos - currentPos

            local dist = dir:Length()
            dir:Normalize()

            local vel = phys:GetVelocity()
            local force = dir * dist * springStrength - vel * damping

            -- clamp force so it can’t drag the body
            force.x = math.Clamp(force.x, -120, 120)
            force.y = math.Clamp(force.y, -120, 120)
            force.z = math.Clamp(force.z, -120, 120)

            phys:ApplyForceCenter(force)
		end

		if ply:KeyDown(IN_ATTACK2) then
			local phys = downed_ragdoll:GetPhysicsObjectNum(downed_ragdoll.RightHandPhys)
			if not IsValid(phys) then continue end

            local targetPos = trace.HitPos
            local currentPos = phys:GetPos()
            local dir = targetPos - currentPos

            local dist = dir:Length()
            dir:Normalize()

            local vel = phys:GetVelocity()
            local force = dir * dist * springStrength - vel * damping

            -- clamp force so it can’t drag the body
            force.x = math.Clamp(force.x, -120, 120)
            force.y = math.Clamp(force.y, -120, 120)
            force.z = math.Clamp(force.z, -120, 120)

            phys:ApplyForceCenter(force)
		end
	end

	net.Start("downedPlayerLocations")
		net.WriteTable(downedPlayers)
	net.Send(player.GetAll())
end)

hook.Add("Think", "homigrad_style_revives_reviving", function()
	if table.IsEmpty(downedPlayers) then return end
 
	for ply, rag in pairs(downedPlayers) do
		local savior = rag:GetNWEntity("savior")

		if IsValid(savior) then
			if not savior:KeyDown(IN_USE) then
				rag:SetNWEntity("savior", NULL)
				rag:SetNWFloat("reviveStartTime", CurTime())
			end

			local elapsedTime = CurTime() - rag:GetNWFloat("reviveStartTime") 

			if elapsedTime >= REVIVE_TIME then 
				revivePlayer(ply)

				downedPlayers[ply] = nil

				net.Start("downedPlayerLocations")
					net.WriteTable(downedPlayers)
				net.Send(player.GetAll())
			end
		end
	end
end)

hook.Add("PlayerUse", "homigrad_style_revives_pu", function(user, ent)
	if ent:GetNWEntity("owner") and ent:GetClass() == "prop_ragdoll" then
		local plyDowned = ent:GetNWEntity("owner")

		for ply, rag in pairs(downedPlayers) do
			if ent == rag then
				if IsValid(rag:GetNWEntity("savior")) then continue end
				if ply != plyDowned then continue end

				rag:SetNWEntity("savior", user)
				rag:SetNWFloat("reviveStartTime", CurTime())
			end
		end
	end
end)

hook.Add("PlayerDeath", "homigrad_style_revives_pd", function(ply, _, atkr)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

	if IsValid(downed_ragdoll) then 
		if IsValid(ply:GetRagdollEntity()) then
			ply:GetRagdollEntity():Remove()
		end

		ply:SetNWBool("downed", false)
        ply:Spectate(OBS_MODE_CHASE)
        ply:SetMoveType(MOVETYPE_OBSERVER)
        ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        ply:SpectateEntity(downed_ragdoll)
        downedPlayers[ply] = nil

        net.Start("downedPlayerLocations")
			net.WriteTable(downedPlayers)
		net.Send(player.GetAll())
	end
end)

hook.Add("PlayerSpawn", "homigrad_style_revives_ps", function(ply, _)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")
	
	if IsValid(downed_ragdoll) and IsValid(downed_ragdoll.bullseye) then
		ply:UnSpectate()
		downed_ragdoll:Remove()
		downed_ragdoll.bullseye:Remove()
		ply:SetNWEntity("downed_ragdoll", nil)
	end
end)