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

function AnimationController:_lookAtMouse(torso)
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

    local headCF
    if torso.Name == "Torso" then
        if AnimationController.TorsoLook then
            torso.CFrame *= CFrame.fromOrientation(
                math.clamp(-angleX, -math.pi/32, math.pi/32),
                math.clamp(-angleY, -math.pi/8, math.pi/8), 
                math.clamp(-angleY, -math.pi/64, math.pi/64)
            )                
        end
        headCF = CFrame.fromOrientation(
            math.clamp(angleX, -math.pi/16, math.pi/4), 
            math.clamp(-angleY, -math.pi/16, math.pi/16),
            math.clamp(-angleY, -math.pi/2.5, math.pi/2.5)
        )
        --]]
    else
        if AnimationController.TorsoLook then
            torso.CFrame *= CFrame.fromOrientation(
                math.clamp(-angleX, -math.pi/32, math.pi/32), 
                math.clamp(-angleY, -math.pi/16, math.pi/16), 
                math.clamp(-angleY, -math.pi/16, math.pi/16) 
            )                
        end
        headCF = CFrame.fromOrientation(
            math.clamp(-angleX, -math.pi/2, math.pi/2), 
            math.clamp(-angleY, -math.pi/2, math.pi/2), 
            math.clamp(-angleY, -math.pi/16, math.pi/16) 
        )
    end

    return headCF
end


function AnimationController:_parseToolMappingR6(kf, toolMapping, weight)
    
    local function animateTool(tool, parent, offset, motor)
        if not offset.CFrame then return end

        local nexoTool = self.NexoCharacter:FindFirstChild(tool.Parent.Name)
        
        local parentCF = parent.CFrame
        local cfLerp = CFrame.identity:Lerp(offset.CFrame, 1)        
        
        FastTween(motor, {0.1}, {Transform = cfLerp})
        --print(c0)
        --print(tool)
        tool.CFrame = parentCF * (motor.c0 * motor.Transform * motor.c1:Inverse()) 
        nexoTool.Handle.CFrame = tool.CFrame
    end

    for limb, tool in pairs(toolMapping) do
        local limb = self.Character:FindFirstChild(limb)
        
        if limb.Name == "Torso" then
            if kf[tool[1].Name] then    
                animateTool(tool[1], limb, kf[tool[1].Name], tool[2], tool[3])
            end
        else
            if kf[limb.Name] then
                if kf[limb.Name][tool[1].Name] then    
                    animateTool(tool[1], limb, kf[limb.Name][tool[1].Name], tool[2], tool[3])
                end                    
            end
        end

    end
end


function AnimationController:_parseToolMappingR15(kf, toolMapping, weight)
    local function animateTool(tool, parent, offset)
        if not offset then return end
        
        local attachment = tool:FindFirstChildOfClass("Attachment")
        local attachmentCF = attachment.CFrame
        local parentCF = parent:FindFirstChild(attachment.Name).CFrame or parent.CFrame
        local cfLerp = CFrame.identity:Lerp(offset, weight)
        
        tool.Handle.CFrame = parentCF * cfLerp * attachmentCF:inverse()
    end

    for limb, tool in pairs(toolMapping) do
        local limb = self.Character:FindFirstChild(limb)
        
        if limb and kf[limb][tool] then
            animateTool(tool, limb, kf[limb][tool])
            return
        end
    end
end



function AnimationController:_poseAccessoryR15(keyframe, toolMapping)
    local kfLowerTorso = keyframe["HumanoidRootPart"] and keyframe["HumanoidRootPart"]["LowerTorso"]
    local kfUpperTorso = kfLowerTorso and kfLowerTorso["UpperTorso"]
    local kfHead = kfUpperTorso and kfUpperTorso["Head"]
    local kfRightUpperArm = kfUpperTorso and kfUpperTorso["RightUpperArm"]
    local kfLeftUpperArm = kfUpperTorso and kfUpperTorso["LeftUpperArm"]
    local kfRightLowerArm = kfUpperTorso and kfRightUpperArm["RightLowerArm"]
    local kfLeftLowerArm = kfUpperTorso and kfLeftUpperArm["LeftLowerArm"]
    local kfRightHand = kfRightUpperArm and kfRightLowerArm["RightHand"]
    local kfLeftHand = kfLeftUpperArm and kfLeftLowerArm["LeftHand"]
    local kfRightUpperLeg = kfLowerTorso and kfLowerTorso["RightUpperLeg"]
    local kfLeftUpperLeg = kfLowerTorso and kfLowerTorso["LeftUpperLeg"]
    local kfRightLowerLeg = kfRightUpperLeg and kfRightUpperLeg["RightLowerLeg"]
    local kfLeftLowerLeg = kfLeftUpperLeg and kfLeftUpperLeg["LeftLowerLeg"]
    local kfRightFoot = kfRightLowerLeg and kfRightLowerLeg["RightFoot"]
    local kfLeftFoot = kfLeftLowerLeg and kfLeftLowerLeg["LeftFoot"]
    
    -- FIXME: Think of an iterative process to parse keyframes
    self:_parseToolMappingR15(kfLowerTorso, toolMapping)
    self:_parseToolMappingR15(kfUpperTorso, toolMapping)
    self:_parseToolMappingR15(kfRightUpperArm, toolMapping)
    self:_parseToolMappingR15(kfLeftUpperArm, toolMapping)
    self:_parseToolMappingR15(kfRightUpperArm, toolMapping)
    self:_parseToolMappingR15(kfLeftLowerArm, toolMapping)
    self:_parseToolMappingR15(kfRightHand, toolMapping)
    self:_parseToolMappingR15(kfLeftHand, toolMapping)
    self:_parseToolMappingR15(kfRightUpperLeg, toolMapping)
    self:_parseToolMappingR15(kfLeftUpperLeg, toolMapping)
    self:_parseToolMappingR15(kfRightUpperLeg, toolMapping)
    self:_parseToolMappingR15(kfLeftLowerLeg, toolMapping)
    self:_parseToolMappingR15(kfRightFoot, toolMapping)
    self:_parseToolMappingR15(kfLeftFoot, toolMapping)
    self:_parseToolMappingR15(kfHead, toolMapping)
end


function AnimationController:_poseR15(keyframe, interp, animation)
    interp = interp or 1

    local reflected = animation.Reflected
    local offset = animation.Offset
    local weight = animation.Weight

	local function animateTorso(cf, lastCF)
        lastCF = lastCF or CFrame.identity
		cf = cf or lastCF

        local hrp = self.NexoCharacter.HumanoidRootPart
        local lowerTorso = self.NexoCharacter.LowerTorso
		local C0 = self.NexoCharacter.LowerTorso["Root"].C0
		local C1 = self.NexoCharacter.LowerTorso["Root"].C1
		
        if reflected then
            local x, y, z = cf:ToOrientation()
            cf = CFrame.new(-cf.Position.X, cf.Position.Y, cf.Position.Z) 
                * CFrame.fromOrientation(x, -y, -z)
        end

        local cfLerp = CFrame.identity:Lerp(cf * offset, weight)

        FastTween(lowerTorso["Root"], {0.1}, {Transform = cfLerp})

        local lookAt = CFrame.lookAt(hrp.CFrame.Position, hrp.CFrame.Position+self.MoveVector)
        if Player.Flipping then
            self:Flip(self.XDirection, self.ZDirection)
        else
            FastTween(hrp, {0.1}, {CFrame = lookAt})
        end

		self.Character.LowerTorso.CFrame = hrp.CFrame * (C0 * cfLerp * C1:Inverse())

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
        ) and
            Player.Leaning
        then
            self.Character.LowerTorso.CFrame = CFrame.fromMatrix(
                self.Character.LowerTorso.CFrame.Position,
                self.TiltVector:Cross(-self.MoveVector), 
                self.TiltVector
            )
        end
	end

	local function animateLimb(limb, parent, motor, cf, lastCF, lookCF) -- Local to parent
        lastCF = lastCF or CFrame.identity
        cf = cf or lastCF

        if reflected then
            local x, y, z = cf:ToOrientation()
            cf = CFrame.new(-cf.Position.X, cf.Position.Y, cf.Position.Z) 
                * CFrame.fromOrientation(x, -y, -z)
        end

        local cfLerp = CFrame.identity:Lerp(cf, weight)

        FastTween(motor, {0.1}, {Transform = cfLerp})

        if lookCF then
            limb.CFrame = parent.CFrame * (motor.C0 * CFrame.new(motor.Transform.Position) * lookCF * motor.C1:inverse())
        else
            limb.CFrame = parent.CFrame * (motor.C0 * motor.Transform * motor.C1:inverse())
        end
	end

	local function animateHats(filterTable)
        filterTable = filterTable or {}

		for i,v in ipairs(self.NexoCharacter:GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v.Name] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                local characterAttachment = self.NexoCharacter:FindFirstChild("UpperTorso"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter():FindFirstChild("LowerTorso"):FindFirstChild(accessoryAttachment.Name) 
                    or Player.getCharacter():FindFirstChild("Head"):FindFirstChild(accessoryAttachment.Name) 
                    or self.NexoCharacter:FindFirstChild("Left Arm"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("Right Arm"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("Right Leg"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("Left Leg"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("LeftUpperArm"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("RightUpperArm"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("RightUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("LeftUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("LeftLowerArm"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("RightLowerArm"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("RightLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("LeftLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("LeftFoot"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("RightFoot"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("RightHand"):FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter:FindFirstChild("LeftHand"):FindFirstChild(accessoryAttachment.Name)

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

	
    local kfA = keyframe["HumanoidRootPart"] and keyframe["HumanoidRootPart"]["LowerTorso"] or keyframe["LowerTorso"]
    local kfB = self.lastKF["HumanoidRootPart"] and self.lastKF["HumanoidRootPart"]["LowerTorso"] or self.lastKF["LowerTorso"] or kfA
    
    --print(kfA)

    local headCF, torsoCF

	if kfA and kfB then

		if kfA.CFrame then
			animateTorso(kfA.CFrame, kfB.CFrame)
		end

		if kfA["RightUpperLeg"] then
			animateLimb(
                self.Character["RightUpperLeg"], 
                self.Character["LowerTorso"], 
                self.NexoCharacter.RightUpperLeg["RightHip"], 
                kfA["RightUpperLeg"].CFrame, 
                kfB["RightUpperLeg"].CFrame
            )
		end
		if kfA["LeftUpperLeg"] then
			animateLimb(
                self.Character["LeftUpperLeg"], 
                self.Character["LowerTorso"], 
                self.NexoCharacter.LeftUpperLeg["LeftHip"], 
                kfA["LeftUpperLeg"].CFrame, 
                kfB["LeftUpperLeg"].CFrame
            )
		end
		if kfA["RightUpperLeg"]["RightLowerLeg"] then
			animateLimb(
                self.Character["RightLowerLeg"], 
                self.Character["RightUpperLeg"], 
                self.NexoCharacter.RightLowerLeg["RightKnee"], 
                kfA["RightUpperLeg"]["RightLowerLeg"].CFrame, 
                kfB["RightUpperLeg"]["RightLowerLeg"].CFrame
            )
		end
		if kfA["LeftUpperLeg"]["LeftLowerLeg"] then
			animateLimb(
                self.Character["LeftLowerLeg"], 
                self.Character["LeftUpperLeg"],
                self.NexoCharacter.LeftLowerLeg["LeftKnee"], 
                kfA["LeftUpperLeg"]["LeftLowerLeg"].CFrame, 
                kfB["LeftUpperLeg"]["LeftLowerLeg"].CFrame
            )
		end
		if kfA["RightUpperLeg"]["RightLowerLeg"]["RightFoot"] then
			animateLimb(
                self.Character["RightFoot"], 
                self.Character["RightLowerLeg"],
                self.NexoCharacter.RightFoot["RightAnkle"], 
                kfA["RightUpperLeg"]["RightLowerLeg"]["RightFoot"].CFrame, 
                kfB["RightUpperLeg"]["RightLowerLeg"]["RightFoot"].CFrame 
            )
		end
		if kfA["LeftUpperLeg"]["LeftLowerLeg"]["LeftFoot"] then
			animateLimb(
                self.Character["LeftFoot"], 
                self.Character["LeftLowerLeg"],
                self.NexoCharacter.LeftFoot["LeftAnkle"], 
                kfA["LeftUpperLeg"]["LeftLowerLeg"]["LeftFoot"].CFrame, 
                kfB["LeftUpperLeg"]["LeftLowerLeg"]["LeftFoot"].CFrame
            )
		end
        if kfA["UpperTorso"] then
			animateLimb(
                self.Character["UpperTorso"], 
                self.Character["LowerTorso"], 
                self.NexoCharacter.UpperTorso["Waist"], 
                kfA["UpperTorso"].CFrame, 
                kfB["UpperTorso"].CFrame, 
                torsoCF
            )
		end
        if animation.Looking and self.Looking then
            headCF = self:_lookAtMouse(self.Character["UpperTorso"])
        end
        if kfA["UpperTorso"]["Head"] then
			animateLimb(
                self.Character["Head"], 
                self.Character["UpperTorso"],
                self.NexoCharacter.Head["Neck"], 
                kfA["UpperTorso"]["Head"].CFrame, 
                kfB["UpperTorso"]["Head"].CFrame, 
                headCF
            )

            animateHats(self.FilterTable)
		end
        if kfA["UpperTorso"]["RightUpperArm"] then
			animateLimb(
                self.Character["RightUpperArm"], 
                self.Character["UpperTorso"], 
                self.NexoCharacter.RightUpperArm["RightShoulder"], 
                kfA["UpperTorso"]["RightUpperArm"].CFrame, 
                kfB["UpperTorso"]["RightUpperArm"].CFrame
            )
		end
		if kfA["UpperTorso"]["LeftUpperArm"] then
			animateLimb(
                self.Character["LeftUpperArm"], 
                self.Character["UpperTorso"], 
                self.NexoCharacter.LeftUpperArm["LeftShoulder"], 
                kfA["UpperTorso"]["LeftUpperArm"].CFrame, 
                kfB["UpperTorso"]["LeftUpperArm"].CFrame
            )
		end
		if kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"] then
			animateLimb(
                self.Character["RightLowerArm"], 
                self.Character["RightUpperArm"],
                self.NexoCharacter.RightLowerArm["RightElbow"], 
                kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"].CFrame, 
                kfB["UpperTorso"]["RightUpperArm"]["RightLowerArm"].CFrame
            )
		end
		if kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"] then
			animateLimb(
                self.Character["LeftLowerArm"], 
                self.Character["LeftUpperArm"],
                self.NexoCharacter.LeftLowerArm["LeftElbow"], 
                kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"].CFrame, 
                kfB["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"].CFrame
            )
		end
		if kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"]["RightHand"] then
			animateLimb(
                self.Character["RightHand"], 
                self.Character["RightLowerArm"],
                self.NexoCharacter.RightHand["RightWrist"], 
                kfA["UpperTorso"]["RightUpperArm"]["RightLowerArm"]["RightHand"].CFrame, 
                kfB["UpperTorso"]["RightUpperArm"]["RightLowerArm"]["RightHand"].CFrame
            )
		end
		if kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"]["LeftHand"] then
			animateLimb(
                self.Character["LeftHand"], 
                self.Character["LeftLowerArm"],
                self.NexoCharacter.LeftHand["LeftWrist"], 
                kfA["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"]["LeftHand"].CFrame, 
                kfB["UpperTorso"]["LeftUpperArm"]["LeftLowerArm"]["LeftHand"].CFrame
            )
		end
	end
end


-- FIXME: Buggy behavior
function AnimationController:Flip(xDir, zDir, dt)
    dt = dt or 10
	local hrp = Player.getNexoHumanoidRootPart()

    local dtheta = CFrame.Angles(-dt * math.deg(xDir), 0, dt * math.deg(zDir))
    FastTween(hrp, {0.1}, {CFrame = hrp.CFrame*dtheta})
end


function AnimationController:_poseAccessoryR6(keyframe, toolMapping, weight)
    local kf = keyframe["HumanoidRootPart"] and keyframe["HumanoidRootPart"]["Torso"] or keyframe["Torso"]
    
    weight = math.clamp(weight, 0, 1)
    
    if kf then
        self:_parseToolMappingR6(kf, toolMapping, weight)
    end
end


function AnimationController:_poseR6(keyframe, interp, animation)
    interp = interp or 1
    local offset = animation.Offset
    local weight = animation.Weight

	local function animateTorso(cf, lastCF)
        lastCF = lastCF or CFrame.identity
		cf = cf or lastCF

        local hrp = Player.getNexoHumanoidRootPart()
        if not hrp then return end

		local C0 = hrp["RootJoint"].C0
		local C1 = hrp["RootJoint"].C1

        if animation.Reflected then
            local x, y, z = cf:ToOrientation()
            cf = CFrame.new(-cf.Position.X, cf.Position.Y, cf.Position.Z) 
                * CFrame.fromOrientation(x, -y, -z)
        end
		
        local cfLerp = CFrame.identity:Lerp(cf * offset, weight)
    
        FastTween(hrp["RootJoint"], {0.1}, {Transform = cfLerp})

        local lookAt = CFrame.lookAt(hrp.CFrame.Position, hrp.CFrame.Position+self.MoveVector)
        if Player.Flipping then
            self:Flip(self.XDirection, self.ZDirection)
        else
            FastTween(hrp, {0.1}, {CFrame = lookAt})
            --hrp.CFrame = CFrame.lookAt(hrp.CFrame.Position, hrp.CFrame.Position+self.MoveVector)
        end

        local torso = self.Character:FindFirstChild("Torso")
        local nexoTorso = self.NexoCharacter:FindFirstChild("Torso")
        if not torso then return end
        if not nexoTorso then return end

		torso.CFrame = hrp.CFrame *  (C0 * hrp["RootJoint"].Transform * C1:Inverse())
        nexoTorso.CFrame = hrp.CFrame *  (C0 * hrp["RootJoint"].Transform * C1:Inverse())

        if 
            not (
                Player.Dancing or 
                Player.Attacking:GetState() or 
                Player.Dodging or 
                Player.Emoting:GetState() or 
                Player.Landing or
                Player.FightMode:GetState() or
                Player.Slowing or
                Player:GetState("Idling") or
                Player.Climbing:GetState()
            ) and
            Player.Leaning
        then
            local tiltFrame = CFrame.fromMatrix(
                torso.CFrame.Position,
                self.TiltVector:Cross(-self.MoveVector), 
                self.TiltVector)
            torso.CFrame = tiltFrame 
            nexoTorso.CFrame = tiltFrame
        end
	end

	local function animateLimb(limb, motor, cf, lastCF, lookCF) -- Local to torso
        lastCF = lastCF or CFrame.identity
        cf = cf or lastCF

        local torso = self.Character:FindFirstChild("Torso")


        if animation.Reflected then
            print("Reflect limb")
            local x, y, z = cf:ToOrientation()
            cf = CFrame.new(-cf.Position.X, cf.Position.Y, cf.Position.Z) 
                * CFrame.fromOrientation(x, -y, -z)
        end    

        local cfLerp = CFrame.identity:Lerp(cf, animation.Weight)

        if not limb then return end
        if not torso then return end
        
        FastTween(motor, {0.1}, {Transform = cfLerp})
        
        if lookCF then
            limb.CFrame = torso.CFrame * (motor.C0 * CFrame.new(motor.Transform.Position) * lookCF * motor.C1:inverse())
        else
            limb.CFrame = torso.CFrame * (motor.C0 * motor.Transform * motor.C1:inverse())
        end
	end

	local function animateHats(filterTable)
        filterTable = filterTable or {}

        local nexoTorso = self.NexoCharacter:FindFirstChild("Torso")

		for i,v in ipairs(self.NexoCharacter:GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v.Name] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                local characterAttachment = nexoTorso:FindFirstChild(accessoryAttachment.Name) 
                    or self.NexoCharacter.Head:FindFirstChild(accessoryAttachment.Name) 
                    or self.NexoCharacter["Left Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter["Right Arm"]:FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter["Right Leg"]:FindFirstChild(accessoryAttachment.Name)
                    or self.NexoCharacter["Left Leg"]:FindFirstChild(accessoryAttachment.Name)
                v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
			end		
		end
        
		for i,v in ipairs(Player.getCharacter():GetChildren()) do
			if v:IsA("Accessory") and not filterTable[v.Name] then
                local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
                 local characterAttachment = self.Character.Torso:FindFirstChild(accessoryAttachment.Name) 
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

    local leftarm = self.Character:FindFirstChild("Left Arm")
    local rightarm = self.Character:FindFirstChild("Right Arm")
    local leftleg = self.Character:FindFirstChild("Left Leg")
    local rightleg = self.Character:FindFirstChild("Right Leg")
    local head = self.Character:FindFirstChild("Head")
    local torso = self.Character:FindFirstChild("Torso")

    local nexoTorso = self.NexoCharacter:FindFirstChild("Torso")
    
    local reflected = animation.Reflected

	if kfA and kfB then
        if kfA.CFrame then
			animateTorso(kfA.CFrame, kfB.CFrame)
		end
		if kfA["Right Leg"] and kfB["Right Leg"] then
            if reflected then
                animateLimb(leftleg, nexoTorso["Left Hip"], kfA["Right Leg"].CFrame, kfB["Right Leg"].CFrame)
            else
                animateLimb(rightleg, nexoTorso["Right Hip"], kfA["Right Leg"].CFrame, kfB["Right Leg"].CFrame)
            end
		end
		if kfA["Left Leg"] and kfB["Left Leg"] then
            if reflected then
                animateLimb(rightleg, nexoTorso["Right Hip"], kfA["Left Leg"].CFrame, kfB["Left Leg"].CFrame)
            else
                animateLimb(leftleg, nexoTorso["Left Hip"], kfA["Left Leg"].CFrame, kfB["Left Leg"].CFrame)
            end
		end
        if animation.Looking and torso and self.Looking then
            headCF = self:_lookAtMouse(torso) 
        end
		if kfA["Head"] and kfB["Head"] then
			animateLimb(head, nexoTorso["Neck"], kfA["Head"].CFrame, kfB["Head"].CFrame, headCF)
		end
        if kfA["Right Arm"] and kfB["Right Arm"] then
            if reflected then
                animateLimb(leftarm, nexoTorso["Left Shoulder"], kfA["Right Arm"].CFrame, kfB["Right Arm"].CFrame)
            else
                animateLimb(rightarm, nexoTorso["Right Shoulder"], kfA["Right Arm"].CFrame, kfB["Right Arm"].CFrame)
            end
		end
		if kfA["Left Arm"] and kfB["Left Arm"] then
            if reflected then
                animateLimb(rightarm, nexoTorso["Right Shoulder"], kfA["Left Arm"].CFrame, kfB["Left Arm"].CFrame)
            else
                animateLimb(leftarm, nexoTorso["Left Shoulder"], kfA["Left Arm"].CFrame, kfB["Left Arm"].CFrame)
            end
		end
        animateHats(self.FilterTable)
	end
end


function AnimationController:_animateStep(animation: Animation)

    local framerate = animation.Framerate
    local speed = animation.Speed
    speed *= Player:GetAnimationSpeed()
    framerate *=  Player:GetAnimationSpeed()

    local current_i = (animation:GetIndex() - 1 + animation.UpperBound) % animation.UpperBound + animation.LowerBound
    local offset = 0

    if animation.Increment >= 1 then
        offset = (animation.Increment * speed) % animation.UpperBound
    elseif animation.Increment < 0 then
        offset = -(animation.UpperBound - (animation.Increment * speed) % animation.UpperBound)
    end

    if speed >= 1 then
        offset = math.floor(offset)
    elseif speed >= 0 then
        offset = math.ceil(offset)
    elseif speed < 0 then
        offset = math.ceil(offset)
    elseif speed <= -1 then
        offset = math.floor(offset)
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
    
    animation.TimeDiff = math.abs(animation.KeyframeSequence[next_i]["Time"] - animation.KeyframeSequence[current_i]["Time"]) / speed

    if not Player.Transitioning then
        animation.Time += 1/framerate * speed
    else
        animation.Time += 1/framerate/2 * speed
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

    if self.Character.Humanoid.RigType == Enum.HumanoidRigType.R6 then
        self:_poseR6(
            animation.KeyframeSequence[animation:GetIndex()], 
            interp,
            animation
        )
        self:_poseAccessoryR6(animation.KeyframeSequence[animation:GetIndex()], animation.ToolMap, animation.Weight)
    else 
        self:_poseR15(
            animation.KeyframeSequence[animation:GetIndex()], 
            interp, 
            animation
        )
        self:_poseAccessoryR15(animation.KeyframeSequence[animation:GetIndex()], animation.ToolMap, animation.Weight)
    end

    
end


function AnimationController:_AnimatePriority(priority: Enum)
    local char = Player.getCharacter()

    for i, animation in pairs(self.AnimationTable[priority]) do
        if animation._playing then
            self:_animateStep(animation) 
        end
    end
end


function AnimationController:Animate()
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
        for _, anim in pairs(table) do
            self:UnloadAnimation(anim)
        end
    end
end


function AnimationController:UnloadAnimation(animation: Animation)
    self.AnimationTable[animation.Priority][animation.Name]:Destroy()
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

    self.TorsoLook = true
    self.Looking = Player.Looking
    self.CurrentModule = animationModule
    self.Character = Player.getCharacter()
    self.NexoCharacter = Player.getNexoCharacter()

    self.Playing = true

    if animationModule then
        self:_InitializeAnimations(animationModule)
    end

    return self
end


function AnimationController:Destroy()
    self:UnloadAnimations()
end


return AnimationController