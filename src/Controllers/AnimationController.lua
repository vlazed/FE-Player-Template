local Project = script:FindFirstAncestor("FE-Player-Template")
local ControllerSettings = require(Project.Controllers.ControllerSettings)
local Player = require(Project.Player)
local Spring = require(Project.Util.Spring)
local VectorUtil = require(Project.Util.VectorUtil)

local AnimationController = {}
AnimationController.__index = AnimationController

AnimationController.R6Legs = {}
AnimationController.TiltVector = Vector3.new(0,1,0)
AnimationController.MoveVector = Vector3.new(0,0,-1)
AnimationController.LookVector = Vector3.new(0,0,-1)

local lookSpring = Spring.new(2, AnimationController.MoveVector)

local lastFilterTable = {}

local restTableR6 = {
	{
		["Time"] = 0,
		["HumanoidRootPart"] = {
			["Torso"] = {
				CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
				["Left Leg"] = {
					CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
				},
				["Right Arm"] = {
					CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
				},
				["Head"] = {
					CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
				},
				["Right Leg"] = {
					CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
				},
				["Left Arm"] = {
					CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
				},
		    },
	    },
    }
}


local restTableR15 = {
    {
        ["Time"] = 0,
        ["HumanoidRootPart"] = {
            ["LowerTorso"] = {
                CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                ["UpperTorso"] = {
                    CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                    ["LeftUpperArm"] = {
                        CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                        ["LeftLowerArm"] = {
                            CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                            ["LeftHand"] = {
                                CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                            },
                        },
                    },
                    ["RightUpperArm"] = {
                        CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                        ["RightLowerArm"] = {
                            CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                            ["RightHand"] = {
                                CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                            },
                        },
                    },
                    ["Head"] = {
                        CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                    },
                },
                ["RightUpperLeg"] = {
                    CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                    ["RightLowerLeg"] = {
                        CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                        ["RightFoot"] = {
                            CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                        },
                    },
                },
                ["LeftUpperLeg"] = {
                    CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                    ["LeftLowerLeg"] = {
                        CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                        ["LeftFoot"] = {
                            CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0),
                        },
                    },
                },
            },
        },
    },
}


local function playerIKControl(R6Legs)
    local Settings = ControllerSettings:GetSettings()

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {Player.getCharacter(), Player.getNexoCharacter()}
	local DOWN = 10*Vector3.new(0,-1,0)
	local CF			=CFrame.new 
	local ANGLES		=CFrame.Angles

	if Player.GetState("Walking") then
		for _, Leg in pairs(R6Legs) do
			local strideCF = Leg.StrideCF or CFrame.new(0, 0, -2 / 2)
			local strideOffset = Leg.StrideOffset or 0
			local raycastParams = params
			local IKTolerance = Leg.IKTolerance or 0

			local hip			=Leg.HipAttachment.WorldPosition
			--Position of where the lower leg should be, spread out
			local ground		=Leg.FootAttachment.WorldPosition
			local desiredPos	=(CF(ground, ground+AnimationController.MoveVector)*strideCF).p
			local offset		=(desiredPos-hip)--vector from hip to the circle
			local raycastResult = workspace:Raycast(hip,offset.unit*(offset.magnitude+strideOffset),raycastParams)
			local footPos = raycastResult and raycastResult.Position or (hip + offset.unit*(offset.magnitude+strideOffset))

			--Do IK towards foot pos
			--Leg.CCDIKController:CCDIKIterateOnce(footPos,IKTolerance)
			--Iterating once won't fully track the footPos, needs to iterate until
			Leg.CCDIKController:CCDIKIterateUntil(footPos,IKTolerance)
		end
	else--stand still
		for _, Leg in pairs(R6Legs) do
			local strideOffset = Leg.StrideOffset or 0
			local raycastParams = params
			local IKTolerance = Leg.IKTolerance or 0

			local hip			=Leg.HipAttachment.WorldPosition
			--Position of where the lower leg should be, spread out
			local desiredPos		=Leg.FootAttachment.WorldPosition+DOWN
			local offset		=(desiredPos-hip)--vector from hip to the circle
			local raycastResult = workspace:Raycast(hip,offset.unit*(offset.magnitude+strideOffset),raycastParams)
			local footPos = raycastResult and raycastResult.Position or (hip + offset.unit*(offset.magnitude+strideOffset))

			--Do IK towards foot pos
			Leg.CCDIKController:CCDIKIterateOnce(footPos,IKTolerance, Settings.DT)
			--Leg.LimbChain:IterateOnce(footPos,0.1)
			--Leg.LimbChain:UpdateMotors()
		end
	end
end

local function lookAtMouse(torso, neck)
    local Settings = ControllerSettings:GetSettings()


	local mouse = Player.getMouse()
	
	local head = Player.getCharacter():FindFirstChild("Head")
	local look = lookSpring:Update(Settings.DT, mouse.Hit.Position - head.CFrame.Position)

	local hrp = Player.getNexoHumanoidRootPart()
    local lowerTorso = torso.Parent:FindFirstChild("LowerTorso")
    local root = hrp:FindFirstChild("RootJoint") or torso:FindFirstChild("Waist")

    local angleY = VectorUtil.AngleBetweenSigned(look - look:Dot(torso.CFrame.UpVector)*torso.CFrame.UpVector.Unit, torso.CFrame.LookVector, torso.CFrame.UpVector)
    local angleX = VectorUtil.AngleBetweenSigned(look - look:Dot(torso.CFrame.RightVector)*torso.CFrame.RightVector.Unit, torso.CFrame.LookVector, torso.CFrame.RightVector)
    --print(-math.deg(angleY))
    --print(math.deg(angleX))
    lookSpring.f = 8
    if torso.Name == "Torso" then
        torso.CFrame *= CFrame.fromOrientation(
            math.clamp(-angleX, -math.pi/32, math.pi/32),
            math.clamp(-angleY, -math.pi/8, math.pi/8), 
            math.clamp(-angleY, -math.pi/64, math.pi/64)
        )
        head.CFrame = torso.CFrame * (neck.C0 * CFrame.fromOrientation(
            math.clamp(angleX, -math.pi/4, math.pi/4), 
            math.clamp(-angleY, -math.pi/16, math.pi/16),
            math.clamp(-angleY, -math.pi/2, math.pi/2)
        ) * neck.C1:Inverse())
    else
            torso.CFrame *= CFrame.fromOrientation(
                math.clamp(-angleX, -math.pi/32, math.pi/32), 
                math.clamp(-angleY, -math.pi/16, math.pi/16), 
                math.clamp(-angleY, -math.pi/16, math.pi/16) 
            )
        head.CFrame = torso.CFrame * (neck.C0 * CFrame.fromOrientation(
            math.clamp(-angleX, -math.pi/2, math.pi/2), 
            math.clamp(-angleY, -math.pi/2, math.pi/2), 
            math.clamp(-angleY, -math.pi/16, math.pi/16) 
        ) * neck.C1:Inverse())
    end
end

function AnimationController:_poseR15(character, keyframe, interp, filterTable)
    interp = interp or 1

	local function animateTorso(cf, lastCF, alpha)
        lastCF = lastCF or CFrame.new()
		cf = cf or lastCF

        local hrp = Player.getNexoCharacter().HumanoidRootPart
		local C0 = Player.getNexoCharacter().LowerTorso["Root"].C0
		local C1 = Player.getNexoCharacter().LowerTorso["Root"].C1
		
        local cfLerp = lastCF:Lerp(cf, alpha)
        --print(alpha)
        local angle = VectorUtil.AngleBetweenSigned(self.MoveVector, Vector3.new(0,0,-1), Vector3.new(0,1,0))
        --print(math.deg(angle))
        Player.getNexoCharacter().LowerTorso["Root"].Transform = cfLerp
        hrp.CFrame = CFrame.lookAt(hrp.CFrame.Position, hrp.CFrame.Position+self.MoveVector)
		character.LowerTorso.CFrame = hrp.CFrame * (C0 * cfLerp * C1:Inverse())
        if not (Player.Dancing or Player.Attacking or Player.Dodging) then
            character.LowerTorso.CFrame = CFrame.fromMatrix(
                character.LowerTorso.CFrame.Position,
                self.TiltVector:Cross(-self.MoveVector), 
                self.TiltVector
            )
        end
	end

	local function animateLimb(limb, parent, motor, cf, lastCF, alpha) -- Local to parent
        lastCF = lastCF or CFrame.new()
        cf = cf or lastCF
		
        local cfLerp = lastCF:Lerp(cf, alpha)
        motor.Transform = cfLerp
        limb.CFrame = parent.CFrame * (motor.C0 * cfLerp * motor.C1:inverse())
	end

	local function animateHats(filterTable)
        filterTable = filterTable or {}

		for i,v in ipairs(Player.getNexoCharacter():GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v.Name] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                local characterAttachment = Player.getNexoCharacter():FindFirstChild("UpperTorso"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter():FindFirstChild("LowerTorso"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter():FindFirstChild("Head"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getNexoCharacter():FindFirstChild("Left Arm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("Right Arm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("Right Leg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("Left Leg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("LeftUpperArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("RightUpperArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("RightUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("LeftUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("LeftLowerArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("RightLowerArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("RightLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("LeftLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("LeftFoot"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("RightFoot"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("RightHand"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter():FindFirstChild("LeftHand"):FindFirstChild(accessoryAttachment.Name)
                v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
			end				
		end

		for i,v in ipairs(Player.getCharacter():GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v.Name] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                 local characterAttachment = Player.getCharacter():FindFirstChild("UpperTorso"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter():FindFirstChild("LowerTorso"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter():FindFirstChild("Head"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter():FindFirstChild("Left Arm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("Right Arm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("Right Leg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("Left Leg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("LeftUpperArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("RightUpperArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("RightUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("LeftUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("LeftLowerArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("RightLowerArm"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("RightLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("LeftLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("LeftFoot"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("RightFoot"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("RightHand"):FindFirstChild(accessoryAttachment.Name)
                    or Player.getCharacter():FindFirstChild("LeftHand"):FindFirstChild(accessoryAttachment.Name)
				v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
			end
		end
	end

	local kfB = self.lastKF["HumanoidRootPart"] and self.lastKF["HumanoidRootPart"]["LowerTorso"] or self.lastKF["LowerTorso"]
    local kfA = keyframe["HumanoidRootPart"] and keyframe["HumanoidRootPart"]["LowerTorso"] or keyframe["LowerTorso"]

    print(kfA)

	if kfA then
		if kfA.CFrame then
			animateTorso(kfA.CFrame, kfB.CFrame, interp)
		end
		if kfA["RightUpperLeg"] then
			animateLimb(
                character["RightUpperLeg"], 
                character["LowerTorso"], 
                Player.getNexoCharacter().RightUpperLeg["RightHip"], 
                kfA["RightUpperLeg"].CFrame, 
                kfB["RightUpperLeg"].CFrame, 
                interp
            )
		end
		if kfA["LeftUpperLeg"] then
			animateLimb(
                character["LeftUpperLeg"], 
                character["LowerTorso"], 
                Player.getNexoCharacter().LeftUpperLeg["LeftHip"], 
                kfA["LeftUpperLeg"].CFrame, 
                kfB["LeftUpperLeg"].CFrame, 
                interp
            )
		end
		if kfA["RightUpperLeg"]["RightLowerLeg"] then
			animateLimb(
                character["RightLowerLeg"], 
                character["RightUpperLeg"], 
                Player.getNexoCharacter().RightLowerLeg["RightKnee"], 
                kfA["RightUpperLeg"]["RightLowerLeg"].CFrame, 
                kfB["RightUpperLeg"]["RightLowerLeg"].CFrame, 
                interp
            )
		end
		if kfA["LeftUpperLeg"]["LeftLowerLeg"] then
			animateLimb(
                character["LeftLowerLeg"], 
                character["LeftUpperLeg"],
                Player.getNexoCharacter().LeftLowerLeg["LeftKnee"], 
                kfA["LeftUpperLeg"]["LeftLowerLeg"].CFrame, 
                kfB["LeftUpperLeg"]["LeftLowerLeg"].CFrame, 
                interp
            )
		end
		if kfA["RightUpperLeg"]["RightLowerLeg"]["RightFoot"] then
			animateLimb(
                character["RightFoot"], 
                character["RightLowerLeg"],
                Player.getNexoCharacter().RightFoot["RightAnkle"], 
                kfA["RightUpperLeg"]["RightLowerLeg"]["RightFoot"].CFrame, 
                kfB["RightUpperLeg"]["RightLowerLeg"]["RightFoot"].CFrame, 
                interp
            )
		end
		if kfA["LeftUpperLeg"]["LeftLowerLeg"]["LeftFoot"] then
			animateLimb(
                character["LeftFoot"], 
                character["LeftLowerLeg"],
                Player.getNexoCharacter().LeftFoot["LeftAnkle"], 
                kfA["LeftUpperLeg"]["LeftLowerLeg"]["LeftFoot"].CFrame, 
                kfB["LeftUpperLeg"]["LeftLowerLeg"]["LeftFoot"].CFrame, 
                interp
            )
		end
        if kfA["UpperTorso"] then
			animateLimb(
                character["UpperTorso"], 
                character["LowerTorso"], 
                Player.getNexoCharacter().UpperTorso["Waist"], 
                kfA["UpperTorso"].CFrame, 
                kfB["UpperTorso"].CFrame, 
                interp
            )
		end
        if kfA["UpperTorso"]["Head"] then
			animateLimb(
                character["Head"], 
                character["UpperTorso"],
                Player.getNexoCharacter().Head["Neck"], 
                kfA["UpperTorso"]["Head"].CFrame, 
                kfB["UpperTorso"]["Head"].CFrame, 
                interp
            )
            lookAtMouse(character["UpperTorso"], Player.getNexoCharacter().Head["Neck"])
			animateHats(filterTable)
		end
        if kfA["UpperTorso"]["RightUpperArm"] then
			animateLimb(
                character["RightUpperArm"], 
                character["UpperTorso"], 
                Player.getNexoCharacter().RightUpperArm["RightShoulder"], 
                kfA["UpperTorso"]["RightUpperArm"].CFrame, 
                kfB["UpperTorso"]["RightUpperArm"].CFrame, 
                interp
            )
		end
		if kfA["UpperTorso"]["LeftUpperArm"] then
			animateLimb(
                character["LeftUpperArm"], 
                character["UpperTorso"], 
                Player.getNexoCharacter().LeftUpperArm["LeftShoulder"], 
                kfA["UpperTorso"]["LeftUpperArm"].CFrame, 
                kfB["UpperTorso"]["LeftUpperArm"].CFrame, 
                interp
            )
		end
		if kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"] then
			animateLimb(
                character["RightLowerArm"], 
                character["RightUpperArm"],
                Player.getNexoCharacter().RightLowerArm["RightElbow"], 
                kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"].CFrame, 
                kfB["UpperTorso"]["RightUpperArm"]["RightLowerArm"].CFrame, 
                interp
            )
		end
		if kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"] then
			animateLimb(
                character["LeftLowerArm"], 
                character["LeftUpperArm"],
                Player.getNexoCharacter().LeftLowerArm["LeftElbow"], 
                kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"].CFrame, 
                kfB["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"].CFrame, 
                interp
            )
		end
		if kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"]["RightHand"] then
			animateLimb(
                character["RightHand"], 
                character["RightLowerArm"],
                Player.getNexoCharacter().RightHand["RightWrist"], 
                kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"]["RightHand"].CFrame, 
                kfB["UpperTorso"]["RightUpperArm"]["RightLowerArm"]["RightHand"].CFrame, 
                interp
            )
		end
		if kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"]["LeftHand"] then
			animateLimb(
                character["LeftHand"], 
                character["LeftLowerArm"],
                Player.getNexoCharacter().LeftHand["LeftWrist"], 
                kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"]["LeftHand"].CFrame, 
                kfB["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"]["LeftHand"].CFrame, 
                interp
            )
		end
	end

    lastFilterTable = filterTable
end

function AnimationController:_poseR6(character, keyframe, interp, filterTable)
    interp = interp or 1

	local function animateTorso(cf, lastCF, alpha)
        lastCF = lastCF or CFrame.new()
		cf = cf or lastCF

        local hrp = Player.getNexoCharacter().HumanoidRootPart
		local C0 = hrp["RootJoint"].C0
		local C1 = hrp["RootJoint"].C1
		
        local cfLerp = lastCF:Lerp(cf, alpha)

        local angle = VectorUtil.AngleBetweenSigned(self.MoveVector, Vector3.new(0,0,1), Vector3.new(0,1,0))

        hrp["RootJoint"].Transform = cfLerp
        
        hrp.CFrame = CFrame.lookAt(hrp.CFrame.Position, hrp.CFrame.Position+self.MoveVector)
		character.Torso.CFrame = hrp.CFrame *  (C0 * cfLerp * C1:Inverse())
        
        if not (Player.Dancing or Player.Attacking or Player.Dodging) then
            character.Torso.CFrame = CFrame.fromMatrix(
                character.Torso.CFrame.Position,
                self.TiltVector:Cross(-self.MoveVector), 
                self.TiltVector
            )
        end
	end

	local function animateLimb(limb, motor, cf, lastCF, alpha) -- Local to torso
        lastCF = lastCF or CFrame.new()
        cf = cf or lastCF
		
        local cfLerp = lastCF:Lerp(cf, alpha)
        motor.Transform = cfLerp
        
        limb.CFrame = character.Torso.CFrame * (motor.C0 * cfLerp * motor.C1:inverse())
	end

	local function animateHats(filterTable)
        filterTable = filterTable or {}

		for i,v in ipairs(Player.getNexoCharacter():GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v.Name] then
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
			if v:IsA("Accessory") and not filterTable[v.Name] then
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

	local kfB = self.lastKF["HumanoidRootPart"] and self.lastKF["HumanoidRootPart"]["Torso"] or self.lastKF["Torso"]
    local kfA = keyframe["HumanoidRootPart"] and keyframe["HumanoidRootPart"]["Torso"] or keyframe["Torso"]

	if kfA then
		if kfA.CFrame then
			animateTorso(kfA.CFrame, kfB.CFrame, interp)
		end
		if kfA["Right Leg"] and kfB["Right Leg"] then
			animateLimb(character["Right Leg"], Player.getNexoCharacter().Torso["Right Hip"], kfA["Right Leg"].CFrame, kfB["Right Leg"].CFrame, interp)
		end
		if kfA["Left Leg"] and kfB["Left Leg"] then
			animateLimb(character["Left Leg"], Player.getNexoCharacter().Torso["Left Hip"], kfA["Left Leg"].CFrame, kfB["Left Leg"].CFrame, interp)
		end
		if kfA["Head"] and kfB["Head"] then
			animateLimb(character["Head"], Player.getNexoCharacter().Torso["Neck"], kfA["Head"].CFrame, kfB["Head"].CFrame, interp)
            lookAtMouse(character["Torso"], Player.getNexoCharacter().Torso["Neck"])
			animateHats(filterTable)
		end
        if kfA["Right Arm"] and kfB["Right Arm"] then
            animateLimb(character["Right Arm"], Player.getNexoCharacter().Torso["Right Shoulder"], kfA["Right Arm"].CFrame, kfB["Right Arm"].CFrame, interp)
		end
		if kfA["Left Arm"] and kfB["Left Arm"] then
			animateLimb(character["Left Arm"], Player.getNexoCharacter().Torso["Left Shoulder"], kfA["Left Arm"].CFrame, kfB["Left Arm"].CFrame, interp)
		end
        --playerIKControl(AnimationController.R6Legs)
	end

    lastFilterTable = filterTable
end


function AnimationController:_animate(char, keyframeTable, interp, framerate, filterTable)

    framerate = framerate or 30

    local current_i = (self.i - 1 + (0 % #keyframeTable) + #keyframeTable) % #keyframeTable + 1
    local next_i = (self.i - 1 + (1 % #keyframeTable) + #keyframeTable) % #keyframeTable + 1

    self.timediff = keyframeTable[next_i]["Time"] - keyframeTable[current_i]["Time"]

    if self.lastKFTable ~= keyframeTable then
        self.i = 1
        self.time = 0
        self.timediff += 2
        if Player.Transitioning then 
            self.timediff += 4
        end
    end

    --print(keyframeTable)
    

    if not Player.Transitioning then
        self.time += 1/framerate
    else
        self.time += 1/framerate/2    
    end

    if self.time > self.timediff then
        self.i = next_i
        self.lastKF = self.lastKFTable[current_i]
        self.time = 0
    elseif self.time <= self.timediff then
        self.i = current_i
    elseif self.timediff < 0 then
        self.i = 1
        self.time = 0
        self.timediff = 1
    elseif self.timediff == 0 then
        self.timediff = 0.1
    end

    interp = math.clamp((interp and self.time/self.timediff or 1), 0, 1)
    
    --print(interp)
    self.lastKFTable = keyframeTable

    if char.Humanoid.RigType == Enum.HumanoidRigType.R6 then
        self:_poseR6(char, keyframeTable[self.i], interp, filterTable)
    else 
        self:_poseR15(char, keyframeTable[self.i], interp, filterTable)
    end
end


function AnimationController:Animate(keyframeTable, canInterp, framerate, filterTable)
    if Player.GetState("Respawning") then return end

    local char = Player.getCharacter()
    if keyframeTable then
        self:_animate(char, keyframeTable, canInterp, framerate, filterTable)
    else
        self:_animate(char, self.lastKFTable, canInterp, framerate, filterTable)
    end
end


function AnimationController:_InterpolateToRest()
    local char = Player.getCharacter()
    local hum = Player.getHumanoid()
    if hum.RigType == Enum.HumanoidRigType.R6 then
        self:_animate(char, self.lastKFTable, true, 30)
    else 
        self:_animate(char, self.lastKFTable, true, 30)
    end
end


function AnimationController.new()
    local self = setmetatable({}, AnimationController)

    self.i = 1
    
    self.timediff = 0
    self.time = 0

    self.lastKFTable = {}
    self.lastKF = {}

    return self
end



return AnimationController