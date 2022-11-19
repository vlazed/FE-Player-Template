local Project = script:FindFirstAncestor("FE-Player-Template")
local Player = require(Project.Player)

local AnimationController = {}

local i = 1
local timediff = 0
local oldInterp = 0
local time = 0

local lastKF = {}

local function _pose(character, keyframe, interp)
    interp = interp or 1

	local function animateTorso(cf, lastCF, alpha)
        lastCF = lastCF or cf
		cf = cf or CFrame.new()

        local hrp = Player.getNexoCharacter().HumanoidRootPart
		local C0 = hrp["RootJoint"].C0
		local C1 = hrp["RootJoint"].C1
		
        local cfLerp = lastCF:Lerp(cf, alpha)
		character.Torso.CFrame = hrp.CFrame * (C0 * cfLerp * C1:Inverse())
	end
	local function animateLimb(limb, motor, cf, lastCF, alpha) -- Local to torso
		cf = cf or CFrame.new()
        lastCF = lastCF or cf
		
        local cfLerp = lastCF:Lerp(cf, alpha)
        limb.CFrame = character.Torso.CFrame * (motor.C0 * cfLerp * motor.C1:inverse())
	end
	local function animateHats(filterTable)
        filterTable = filterTable or {}

		for i,v in ipairs(Player.getNexoCharacter():GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                local characterAttachment = Player.getNexoCharacter().Torso:FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter().Head:FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter()["Left Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter()["Right Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter()["Right Leg"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter()["Left Leg"]:FindFirstChild(accessoryAttachment.Name)
                v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
			end				
		end
		for i,v in ipairs(Player.getCharacter():GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                local characterAttachment = Player.getCharacter().Torso:FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter().Head:FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter()["Left Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter()["Right Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter()["Right Leg"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter()["Left Leg"]:FindFirstChild(accessoryAttachment.Name)
				v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
			end				
		end
	end

	local kfB = lastKF["HumanoidRootPart"] and lastKF["HumanoidRootPart"]["Torso"] or lastKF["Torso"]
    local kfA = keyframe["HumanoidRootPart"] and keyframe["HumanoidRootPart"]["Torso"] or keyframe["Torso"]
	if kfA then
		if kfA.CFrame then
			animateTorso(kfA.CFrame, kfB.CFrame, interp)
		end
		if kfA["Right Leg"] then
			animateLimb(character["Right Leg"], Player.getNexoCharacter().Torso["Right Hip"], kfA["Right Leg"].CFrame, kfB["Right Leg"].CFrame, interp)
		end
		if kfA["Left Leg"] then
			animateLimb(character["Left Leg"], Player.getNexoCharacter().Torso["Left Hip"], kfA["Left Leg"].CFrame, kfB["Left Leg"].CFrame, interp)
		end
		if kfA["Right Arm"] then
			animateLimb(character["Right Arm"], Player.getNexoCharacter().Torso["Right Shoulder"], kfA["Right Arm"].CFrame, kfB["Right Arm"].CFrame, interp)
		end
		if kfA["Left Arm"] then
			animateLimb(character["Left Arm"], Player.getNexoCharacter().Torso["Left Shoulder"], kfA["Left Arm"].CFrame, kfB["Left Arm"].CFrame, interp)
		end
		if kfA["Head"] then
			animateLimb(character["Head"], Player.getNexoCharacter().Torso["Neck"], kfA["Head"].CFrame, kfB["Head"].CFrame, interp)
			animateHats()
		end
	end
end


local function _animate(char, keyframeTable, interp)

    local current_i = (i - 1 + (0 % #keyframeTable) + #keyframeTable) % #keyframeTable + 1
    local next_i = (i - 1 + (1 % #keyframeTable) + #keyframeTable) % #keyframeTable + 1

    timediff = keyframeTable[next_i]["Time"] - keyframeTable[current_i]["Time"]
    
    if interp then
        time += 1/60
    else
        time += 1/30
    end
    if time > timediff then
        i = next_i
        time = 0
    elseif timediff < 0 then
        i = 1
        time = 0
        timediff = 0
    elseif timediff == 0 then
        timediff = 0.1
    end

    interp = (interp and time/timediff or 1)
    if interp == math.huge then
        print("Large number! Dampening...")
        interp = 1
    end
    if oldInterp > interp then
        interp = oldInterp
    end
    oldInterp = interp

    lastKF = keyframeTable[current_i]
    _pose(char, keyframeTable[i], interp)
end


function AnimationController.Animate(keyframeTable, canInterp)
    if Player.GetState("Respawning") then return end
    local char = Player.getCharacter()
    _animate(char, keyframeTable, canInterp)
end


return AnimationController