HSR = {}
HSR.downedPlayers = {}

HSR.RAGDOLL_BLEED_OUT_TIME = 30
HSR.RAGDOLL_GIVE_UP_TIME = 1
HSR.RAGDOLL_REVIVE_TIME = 5
HSR.GIVE_UP_KEY = IN_JUMP -- If you change this, then you will have to change the text on line 160 in cl_revive.lua

HSR.boneToHitGroup = { 
    ["ValveBiped.Bip01_Head1"] = 1,
    ["ValveBiped.Bip01_R_UpperArm"] = 5,
    ["ValveBiped.Bip01_R_Forearm"] = 5,
    ["ValveBiped.Bip01_R_Hand"] = 5,
    ["ValveBiped.Bip01_L_UpperArm"] = 4,
    ["ValveBiped.Bip01_L_Forearm"] = 4,
    ["ValveBiped.Bip01_L_Hand"] = 4,
    ["ValveBiped.Bip01_Pelvis"] = 3,
    ["ValveBiped.Bip01_Spine2"] = 2,
    ["ValveBiped.Bip01_L_Thigh"] = 6,
    ["ValveBiped.Bip01_L_Calf"] = 6,
    ["ValveBiped.Bip01_L_Foot"] = 6,
    ["ValveBiped.Bip01_R_Thigh"] = 7,
    ["ValveBiped.Bip01_R_Calf"] = 7,
    ["ValveBiped.Bip01_R_Foot"] = 7
}

HSR.ragdollDamageBoneMultiplier = {		
	[HITGROUP_LEFTLEG] = 1,
	[HITGROUP_RIGHTLEG] = 1,

	[HITGROUP_GENERIC] = 2,

	[HITGROUP_LEFTARM] = 1,
	[HITGROUP_RIGHTARM] = 1,

	[HITGROUP_CHEST] = 2,
	[HITGROUP_STOMACH] = 2,

	[HITGROUP_HEAD] = 5,
}

function HSR.createDownedRagdoll(ply)
	local ragdoll = ents.Create("prop_ragdoll")
	ragdoll:SetNWFloat("bleedOutStartTime", CurTime())
	ragdoll:SetModel(ply:GetModel())
	ragdoll:SetPos(ply:GetPos())
	ragdoll:SetAngles(ply:GetAngles())
	ragdoll:SetNWVector("rag_ply_color", ply:GetPlayerColor())
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
	ply:SetNotSolid(true)
	ply:DrawViewModel(false)
	ply:SetNoDraw(true)
	ply:SetNoTarget(true)
	ply:SetMoveType(MOVETYPE_NONE)
	ply:SetLocalVelocity(Vector(0, 0, 0))

	return ragdoll
end

function HSR.createRagdollBullseye(ply, ragdoll)
	ragdoll.bullseye = ents.Create("npc_bullseye")
	ragdoll:SetNWEntity("owner", ply)

	local bullseye = ragdoll.bullseye
	bullseye:SetPos(ragdoll:GetPos() + Vector(0, 0, 8))
	bullseye:SetParent(ragdoll)
	bullseye:SetHealth(1000)
	bullseye:Spawn()
	bullseye:Activate()
	bullseye:SetSolid(SOLID_NONE)
	ply:StripWeapons()
end

function HSR.storeBones(ragdoll, ply)
	local function findPhysBone(bonename)
		local boneIndex = ply:LookupBone(bonename)
		if not boneIndex then return nil end
		local physID = ragdoll:TranslateBoneToPhysBone(boneIndex)
		return physID
	end

	ragdoll.LeftHandPhys  = findPhysBone("ValveBiped.Bip01_L_Hand")
	ragdoll.RightHandPhys = findPhysBone("ValveBiped.Bip01_R_Hand")
end

function HSR.storeWeapons(ragdoll, ply)
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

function HSR.revivePlayer(ply)
	local downed_ragdoll = ply:GetNWEntity("downed_ragdoll")
	local ragdollPos = downed_ragdoll:GetPhysicsObject():GetPos()

	ply:UnSpectate()
	ply:Spawn()
	ply:SetHealth(ply:GetMaxHealth() * .3)
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
    HSR.downedPlayers[ply] = nil
end

function HSR.getPhysicsBoneDamageInfo(ent, dmgInfo)
    -- Get the position where the damage occurred
    local pos = dmgInfo:GetDamagePosition()

    -- Get the direction of the damage force and normalize it
    local dir = dmgInfo:GetDamageForce():GetNormalized()

    -- Multiply the normalized direction by a scaling factor
    dir:Mul(1024 * 8)

    -- Initialize trace parameters
    local tr = {}
    tr.start = pos                      -- The start of the trace is the damage position
    tr.endpos = pos + dir               -- The endpoint of the trace is the damage position + scaled direction
    tr.filter = filter                   -- Filter entities to ignore during the trace (likely a player or other entities)
    filterEnt = ent                      -- Set the entity to be filtered (ignored in the trace)
    tr.ignoreworld = true                -- Ignore the world when tracing, only consider entities

    -- Perform the trace and store the result
    local result = util.TraceLine(tr)
    
    -- Check if the trace didn't hit the entity (i.e., the damage came from outside the entity)
    if result.Entity ~= ent then
        -- If the trace misses the entity, reverse the trace direction
        tr.endpos = pos - dir

        -- Perform a second trace in the reverse direction and return the physics bone hit
        return util.TraceLine(tr).PhysicsBone
    else
        -- If the trace hits the entity, return the physics bone it hit
        return result.PhysicsBone
    end
end