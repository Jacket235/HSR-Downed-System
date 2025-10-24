util.AddNetworkString("downedPlayerLocations")
util.AddNetworkString("revivingPlayer")
util.AddNetworkString("revivingPlayerStop")

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

local function storeHandBones(ragdoll, ply)
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
	ply:SetPos(ragdollPos)

	for _, weaponInfo in pairs(downed_ragdoll.weapons or {}) do
        local weapon = ply:Give(weaponInfo.class)
        if IsValid(weapon) then
            weapon:SetClip1(weaponInfo.clip1)
            weapon:SetClip2(weaponInfo.clip2)
            ply:SetAmmo(weaponInfo.primaryAmmo, weapon:GetPrimaryAmmoType())
            ply:SetAmmo(weaponInfo.secondaryAmmo, weapon:GetSecondaryAmmoType())
        end
    end

    ply:SetNWBool("downed", false)
    ply:SetNWEntity("downed_ragdoll", nil)
    downedPlayers[ply] = nil
end

downedPlayers = {}

hook.Add("PlayerHurt", "homigrad_style_revives_ph", function(ply, atkr, hp, dmg)
	-- if ply:IsBot() then
		if not ply:GetNWBool("downed") and hp <= 0  then 
			ply:SetHealth(1)

			local ragdoll = createDownedRagdoll(ply)
			storeHandBones(ragdoll, ply)
			storeWeapons(ragdoll, ply)
			local controller = createRagdollController(ply, ragdoll)
			downedPlayers[ply] = ragdoll
		end
	-- end
end)

hook.Add("Think", "homigrad_style_revives_bleed_out", function()
	PrintTable(downedPlayers)
	for _, ply in ipairs(player.GetAll()) do
		if not ply:GetNWBool("downed") then continue end

		local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

		if IsValid(downed_ragdoll) then
			local elapsedTime = CurTime() - downed_ragdoll:GetNWFloat("bleedOutStartTime") 

			if elapsedTime >= 30 then
				ply:SetNWBool("downed", false)
				ply:Kill()	
			end
		end
	end
end)

hook.Add("Think", "homigrad_style_revives_ragdoll_control", function()
	for _, ply in ipairs(player.GetAll()) do
		if not ply:GetNWBool("downed") or not IsValid(ply:GetNWEntity("downed_ragdoll")) then continue end

		local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")

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

		net.Start("downedPlayerLocations")
			net.WriteTable(downedPlayers)
		net.Send(player.GetAll())
	end
end)

hook.Add("PlayerUse", "homigrad_style_revives_pu", function(ply, ent)
	if ent:GetNWEntity("owner") and ent:GetClass() == "prop_ragdoll" then
		local plyDowned = ent:GetNWEntity("owner")

		for player, rag in pairs(downedPlayers) do
			if player != plyDowned then continue end
			if IsValid(rag:GetNWEntity("saviour")) then continue end

			rag:SetNWEntity("saviour", ply)
			rag:SetNWFloat("reviveStartTime", CurTime())
		end
	end
end)

net.Receive("revivingPlayer", function(len, ply)
	local downedPlayer = net.ReadEntity()
	local downed_ragdoll = downedPlayer:GetNWEntity("downed_ragdoll")

	if not IsValid(downed_ragdoll) then return end

	local startReviveTime = downed_ragdoll:GetNWFloat("reviveStartTime", CurTime())
	local reviveTime = CurTime() - startReviveTime

	if IsValid(downed_ragdoll:GetNWEntity("saviour")) and reviveTime >= 5 then
		revivePlayer(downedPlayer)
	end 

	net.Start("revivingPlayer")
		net.WriteEntity(downedPlayer)
	net.Send(ply)
end)

net.Receive("revivingPlayerStop", function()
	local downedPlayerRagdoll = net.ReadEntity()
	if not IsValid(downedPlayerRagdoll) then return end

	downedPlayerRagdoll:SetNWEntity("saviour", nil)
	downedPlayerRagdoll:SetNWFloat("reviveStartTime", 0)
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