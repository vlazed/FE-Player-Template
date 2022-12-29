local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local ControllerSettings = require(Project.Controllers.ControllerSettings)
local Player = require(Project.Player)
local Spring = require(Project.Util.Spring)
local VectorUtil = require(Project.Util.VectorUtil)
local Thread = require(Project.Util.Thread)
local FastTween = require(Project.Util.FastTween)

local AnimationController = {}
AnimationController.__index = AnimationController

AnimationController.R6Legs = {}
AnimationController.TiltVector = Vector3.new(0,1,0)
AnimationController.MoveVector = Vector3.new(0,0,-1)
AnimationController.LookVector = Vector3.new(0,0,-1)

AnimationController.XDirection = 0
AnimationController.ZDirection = 0

local lookSpring = Spring.new(2, AnimationController.MoveVector)
local angleSpringY = Spring.new(16, 0)
local angleSpringX = Spring.new(16, 0)

local function playerIKControl(R6Legs)
    local Settings = ControllerSettings:GetSettings()

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {Player.getCharacter(), Player.getNexoCharacter()}
	local DOWN = 10*Vector3.new(0,-1,0)
	local CF			=CFrame.new 
	local ANGLES		=CFrame.Angles

	if Player:GetState("Walking") then
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

local function lookAtMouse(torso)
    local Settings = ControllerSettings:GetSettings()
    local camera = workspace.CurrentCamera

	local mouse = Player.getMouse()
	
	local head = Player.getCharacter():FindFirstChild("Head")
	local look = lookSpring:Update(Settings.DT, mouse.Hit.Position - head.CFrame.Position)

    local angleY = VectorUtil.AngleBetweenSigned(look - look:Dot(torso.CFrame.UpVector)*torso.CFrame.UpVector, torso.CFrame.LookVector, torso.CFrame.UpVector)
    local angleX = VectorUtil.AngleBetweenSigned(look - look:Dot(camera.CFrame.RightVector)*camera.CFrame.RightVector, camera.CFrame.LookVector * Vector3.new(1,0,1), camera.CFrame.RightVector)
    
    angleY = angleSpringY:Update(Settings.DT, angleY)
    angleX = angleSpringX:Update(Settings.DT, angleX)

    --print(-math.deg(angleY))
    --print(math.deg(angleX))
    lookSpring.f = 8

    local torsoCF
    local headCF
    if torso.Name == "Torso" then
        torso.CFrame *= CFrame.fromOrientation(
            math.clamp(-angleX, -math.pi/32, math.pi/32),
            math.clamp(-angleY, -math.pi/8, math.pi/8), 
            math.clamp(-angleY, -math.pi/64, math.pi/64)
        )
        headCF = CFrame.fromOrientation(
            math.clamp(angleX, -math.pi/16, math.pi/4), 
            math.clamp(-angleY, -math.pi/8, math.pi/8),
            math.clamp(-angleY, -math.pi/2.5, math.pi/2.5)
        )
    else
        torsoCF *= CFrame.fromOrientation(
            math.clamp(-angleX, -math.pi/32, math.pi/32), 
            math.clamp(-angleY, -math.pi/16, math.pi/16), 
            math.clamp(-angleY, -math.pi/16, math.pi/16) 
        )
        headCF = CFrame.fromOrientation(
            math.clamp(-angleX, -math.pi/2, math.pi/2), 
            math.clamp(-angleY, -math.pi/2, math.pi/2), 
            math.clamp(-angleY, -math.pi/16, math.pi/16) 
        )
    end

    return headCF
end

function AnimationController:_poseR15(character, keyframe, interp, filterTable, looking)
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
        if 
        not (
            Player.Dancing 
            or Player.Attacking:GetState() 
            or Player.Dodging 
            or Player.Emoting:GetState()
            or Player.Landing
            or Player.FightMode:GetState()
            or Player.Slowing
            or Player:GetState("Idling")
        )
        then
            character.LowerTorso.CFrame = CFrame.fromMatrix(
                character.LowerTorso.CFrame.Position,
                self.TiltVector:Cross(-self.MoveVector), 
                self.TiltVector
            )
        end
	end

	local function animateLimb(limb, parent, motor, cf, lastCF, alpha, lookCF) -- Local to parent
        lastCF = lastCF or CFrame.new()
        cf = cf or lastCF
		
        lookCF = lookCF or CFrame.new()

        local cfLerp = lastCF:Lerp(cf, alpha)
        motor.Transform = cfLerp
        limb.CFrame = parent.CFrame * (motor.C0 * cfLerp * lookCF * motor.C1:inverse())
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

    --print(kfA)

    local headCF, torsoCF

	if kfA then
        if looking then
            headCF = lookAtMouse(character["UpperTorso"])
        end

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
                interp,
                torsoCF
            )
		end
        if kfA["UpperTorso"]["Head"] then
			animateLimb(
                character["Head"], 
                character["UpperTorso"],
                Player.getNexoCharacter().Head["Neck"], 
                kfA["UpperTorso"]["Head"].CFrame, 
                kfB["UpperTorso"]["Head"].CFrame, 
                interp,
                headCF
            )

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


-- FIXME: Buggy behavior
function AnimationController:Flip(xDir, zDir, dt)
    dt = dt or 10
	local torso = Player.getCharacter().Torso
    local nexoTorso = Player.getNexoCharacter().HumanoidRootPart
    local dtheta = CFrame.Angles(-dt * math.deg(xDir), 0, dt * math.deg(zDir))
	--torso.CFrame *= CFrame.Angles(-dt * math.deg(xDir), 0, dt * math.deg(zDir))
    FastTween(nexoTorso, {0.1}, {CFrame = nexoTorso.CFrame*dtheta})
    --nexoTorso.CFrame *= CFrame.Angles(-dt * math.deg(xDir), 0, dt * math.deg(zDir))
end


function AnimationController:_poseR6(character, keyframe, interp, filterTable, looking)
    interp = interp or 1

    local nexoCharacter = Player.getNexoCharacter()

	local function animateTorso(cf, lastCF, alpha)
        lastCF = lastCF or CFrame.new()
		cf = cf or lastCF

        local hrp = Player.getNexoCharacter().HumanoidRootPart
		local C0 = hrp["RootJoint"].C0
		local C1 = hrp["RootJoint"].C1
		
        local cfLerp = lastCF:Lerp(cf, alpha)

        local angle = VectorUtil.AngleBetweenSigned(self.MoveVector, Vector3.new(0,0,1), Vector3.new(0,1,0))
        
        FastTween(hrp["RootJoint"], {0.1}, {Transform = cf})

        local lookAt = CFrame.lookAt(hrp.CFrame.Position, hrp.CFrame.Position+self.MoveVector)
        if Player.Flipping then
            self:Flip(self.XDirection, self.ZDirection)
        else
            FastTween(hrp, {0.1}, {CFrame = lookAt})
            --hrp.CFrame = CFrame.lookAt(hrp.CFrame.Position, hrp.CFrame.Position+self.MoveVector)
        end

		character.Torso.CFrame = hrp.CFrame *  (C0 * hrp["RootJoint"].Transform * C1:Inverse())
        nexoCharacter.Torso.CFrame = hrp.CFrame *  (C0 * hrp["RootJoint"].Transform * C1:Inverse())

        if 
            not (
                Player.Dancing or 
                Player.Attacking:GetState() or 
                Player.Dodging or 
                Player.Emoting:GetState() or 
                Player.Landing or
                Player.FightMode:GetState() or
                Player.Slowing or
                Player:GetState("Idling")
            )
        then
            local tiltFrame = CFrame.fromMatrix(
                character.Torso.CFrame.Position,
                self.TiltVector:Cross(-self.MoveVector), 
                self.TiltVector)
            character.Torso.CFrame = tiltFrame 
            nexoCharacter.Torso.CFrame = tiltFrame
        end
	end

	local function animateLimb(limb, motor, cf, lastCF, alpha, lookCF) -- Local to torso
        lastCF = lastCF or CFrame.new()
        cf = cf or lastCF
        lookCF = lookCF or CFrame.new()
		
        local cfLerp = lastCF:Lerp(cf, alpha)

        local nexoLimb = nexoCharacter:FindFirstChild(limb.Name)
        
        FastTween(motor, {0.1}, {Transform = cf * lookCF})

        limb.CFrame = character.Torso.CFrame * (motor.C0 * motor.Transform * motor.C1:inverse())
	end

	local function animateHats(filterTable)
        filterTable = filterTable or {}

		for i,v in ipairs(Player.getNexoCharacter():GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v.Name] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                local characterAttachment = Player.getNexoCharacter().Torso:FindFirstChild(accessoryAttachment.Name) 
                    or Player.getNexoCharacter().Head:FindFirstChild(accessoryAttachment.Name) 
                    or Player.getNexoCharacter()["Left Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter()["Right Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter()["Right Leg"]:FindFirstChild(accessoryAttachment.Name)
                    or Player.getNexoCharacter()["Left Leg"]:FindFirstChild(accessoryAttachment.Name)
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

    local headCF

	if kfA then
        if kfA.CFrame then
			animateTorso(kfA.CFrame, kfB.CFrame, interp)
		end
		if kfA["Right Leg"] and kfB["Right Leg"] then
			animateLimb(character["Right Leg"], nexoCharacter.Torso["Right Hip"], kfA["Right Leg"].CFrame, kfB["Right Leg"].CFrame, interp)
		end
		if kfA["Left Leg"] and kfB["Left Leg"] then
			animateLimb(character["Left Leg"], nexoCharacter.Torso["Left Hip"], kfA["Left Leg"].CFrame, kfB["Left Leg"].CFrame, interp)
		end
        if looking then
            headCF = lookAtMouse(character["Torso"]) 
        end
		if kfA["Head"] and kfB["Head"] then
			animateLimb(character["Head"], nexoCharacter.Torso["Neck"], kfA["Head"].CFrame, kfB["Head"].CFrame, interp, headCF)
		end
        if kfA["Right Arm"] and kfB["Right Arm"] then
            animateLimb(character["Right Arm"], nexoCharacter.Torso["Right Shoulder"], kfA["Right Arm"].CFrame, kfB["Right Arm"].CFrame, interp)
		end
		if kfA["Left Arm"] and kfB["Left Arm"] then
			animateLimb(character["Left Arm"], nexoCharacter.Torso["Left Shoulder"], kfA["Left Arm"].CFrame, kfB["Left Arm"].CFrame, interp)
		end
        animateHats(filterTable)
	end

    lastFilterTable = filterTable
end


function AnimationController:_animateStep(char, animation: Animation)

    local framerate = animation.Framerate
    framerate /=  Player:GetAnimationSpeed()
    --animation.Speed *= Player:GetAnimationSpeed()

    local current_i = (animation:GetIndex() - 1 + animation.UpperBound) % animation.UpperBound + animation.LowerBound
    local offset = 0

    if animation.Increment >= 1 then
        offset = (animation.Increment * animation.Speed) % animation.UpperBound
    elseif animation.Increment < 0 then
        offset = -(animation.UpperBound - (animation.Increment * animation.Speed) % animation.UpperBound)
    end

    local next_i = (animation:GetIndex() - 1 + math.ceil(offset) + animation.UpperBound) % animation.UpperBound + animation.LowerBound

    if offset > 0 then
        if (current_i > next_i) then
            if not animation.Looping then
                animation:Stop()
                return
            else
                animation.Looped:Fire()
            end
        end
    elseif offset < 0 then
        if (current_i < next_i) then
            if not animation.Looping then
                animation:Stop()
                return
            else
                animation.Looped:Fire()
            end
        end
    end
    
    animation.TimeDiff = math.abs(animation.KeyframeSequence[next_i]["Time"] - animation.KeyframeSequence[current_i]["Time"]) / animation.Speed

    if not Player.Transitioning then
        animation.Time += 1/framerate * animation.Speed
    else
        animation.Time += 1/framerate/2 * animation.Speed
    end

    if current_i > next_i then
        if animation.Increment > 0 then
            animation:SetIndex(1)
            animation.TimeDiff = 0
        end
    else
        if animation.Increment < 0 then
            animation:SetIndex(animation.UpperBound)
            animation.TimeDiff = 0
        end
    end

    if animation.Time > animation.TimeDiff then
        animation:SetIndex(next_i)
        self.lastKF = animation.KeyframeSequence[current_i]
        animation.Time = 0
    else 
        animation:SetIndex(current_i)
    end
    
    if animation.TimeDiff == 0 then
        animation.TimeDiff = 0.1
    end

    local interp = math.clamp((animation.IsInterpolating and animation.Time/animation.TimeDiff or 1), 0, 1)

    if char.Humanoid.RigType == Enum.HumanoidRigType.R6 then
        self:_poseR6(char, animation.KeyframeSequence[animation:GetIndex()], interp, self.FilterTable, animation.Looking)
    else 
        self:_poseR15(char, animation.KeyframeSequence[animation:GetIndex()], interp, self.FilterTable, animation.Looking)
    end

    
end


function AnimationController:_AnimatePriority(priority: Enum)
    local char = Player.getCharacter()

    for i, animation in pairs(self.AnimationTable[priority]) do
        if animation._playing then
            self:_animateStep(char, animation) 
        end
    end
end


function AnimationController:Animate(keyframeTable, canInterp, framerate, filterTable)
    if Player:GetState("Respawning") then return end

    self:_AnimatePriority(Enum.AnimationPriority.Core)
    self:_AnimatePriority(Enum.AnimationPriority.Idle)
    self:_AnimatePriority(Enum.AnimationPriority.Movement)
    self:_AnimatePriority(Enum.AnimationPriority.Action)
    self:_AnimatePriority(Enum.AnimationPriority.Action2)
    self:_AnimatePriority(Enum.AnimationPriority.Action3)
    self:_AnimatePriority(Enum.AnimationPriority.Action4)
end


function AnimationController:UnloadAnimations()
    for priority,table in pairs(self.AnimationTable) do
        for _, anim in ipairs(table) do
            self:UnloadAnimation(anim)
        end
    end
end


function AnimationController:UnloadAnimation(animation: Animation)
    self.AnimationTable[animation.Priority][animation.Name] = nil
end


function AnimationController:LoadAnimation(animation: Animation)
    self.AnimationTable[animation.Priority][animation.Name] = animation
end


function AnimationController:UpdateModule(animModule)
    if self.CurrentModule == animModule then return end

    print("Updating module")
    self.CurrentModule = animModule

    for index,animationTable in pairs(self.AnimationTable) do
        for i, animation in pairs(animModule) do
            if index == animation.Priority then
                animationTable[animation.Name] = animation
            end
        end
    end

    --print(self.AnimationTable)
end


function AnimationController:_InitializeAnimations(animModule)
    for index,animationTable in pairs(self.AnimationTable) do
        for i, animation in pairs(animModule) do
            if index == animation.Priority then
                animationTable[animation.Name] = animation
            end
        end
    end
end


function AnimationController.new(animationModule)
    local self = setmetatable({}, AnimationController)

    self.lastKF = {}

    self.FilterTable = {}
    self.AnimationTable = {
        [Enum.AnimationPriority.Core] = {},
        [Enum.AnimationPriority.Idle] = {},
        [Enum.AnimationPriority.Movement] = {},
        [Enum.AnimationPriority.Action] = {},
        [Enum.AnimationPriority.Action2] = {},
        [Enum.AnimationPriority.Action3] = {},
        [Enum.AnimationPriority.Action4] = {}
    }

    self.CurrentModule = animationModule

    if animationModule then
        self:_InitializeAnimations(animationModule)
    end

    return self
end


function AnimationController:Destroy()
    self:UnloadAnimations()
end


return AnimationController