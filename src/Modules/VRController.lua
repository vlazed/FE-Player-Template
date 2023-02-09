--[[
    Modification of AerodynamicRocket's VR Webcam to integrate with FE-Player-Template
--]]

local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Player = require(Project.Player)

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local ActionHandler = require(Project.Controllers.ActionHandler)
local PlayerController = require(Project.Controllers.PlayerController)

local SendNotification = require(Project.Util.SendNotification)

local VRController = {}
VRController.Name = "VRWebcam"
VRController.Type = "Core"
VRController.Icon = ""

local ToggleButton = Enum.KeyCode.Quote

local Initialized = false
local isEnabled = false
local debounce = false

VRController._url = "http://127.0.0.1:3000/download_pose/"
VRController._character = nil
VRController._nexoCharacter = nil
VRController._connected = false

VRController.raw_data = {}
VRController.data = {}


-- order of compressed sent data
local landmarks_order = {
	"neck",
	"left_shoulder",
	"right_shoulder",
	"left_elbow",
	"right_elbow",
	"waist",
	"left_hip",
	"right_hip",
	"left_knee",
	"right_knee",
}

local default_state = {
    ["neck"] = {x=0, y=0, z=0, visibility = 0},
    ["left_shoulder"] = {x=0, y=0, z=0, visibility = 0},
    ["right_shoulder"] = {x=0, y=0, z=0, visibility = 0},
    ["left_elbow"] = {x=0, y=0, z=0, visibility = 0},
    ["right_elbow"] = {x=0, y=0, z=0, visibility = 0},
    ["waist"] = {x=0, y=0, z=0, visibility = 0},
    ["left_hip"] = {x=0, y=0, z=0, visibility = 0},
    ["right_hip"] = {x=0, y=0, z=0, visibility = 0},
    ["left_knee"] = {x=0, y=0, z=0, visibility = 0},
    ["right_knee"] = {x=0, y=0, z=0, visibility = 0},
}


local function dictionary_length(dictionary)
	local counter = 0 
	for _, v in pairs(dictionary) do
		counter =counter + 1
	end
	return counter
end


local function TweenC0(Motor, EndCF) -- always use local variables, TweenC0 has been made local
	local prop = {}
	prop.C0 = EndCF
	local info = TweenInfo.new(0.1)
	return TweenService:Create(Motor, info, prop)
end


local function R15toR6(character, r6Character)
	local function getRelative(cf1,cf2)
		return cf2:ToObjectSpace(cf1)
	end

	local r6Poses = {
		["Right Arm"] = {CFrame = CFrame.identity},
		["Left Arm"] = {CFrame = CFrame.identity},
		["Right Leg"] = {CFrame = CFrame.identity},
		["Left Leg"] = {CFrame = CFrame.identity},
		["Torso"] = {CFrame = CFrame.identity},
		["Head"] = {CFrame = CFrame.identity},
	}

	if r6Poses["Right Arm"] then
		local rel = getRelative(
			character.RightLowerArm.CFrame,
			character.UpperTorso.CFrame
		)*CFrame.new(0,character.RightLowerArm.Size.Y*0.25,0)
		local motor = r6Character.Torso["Right Shoulder"]
		r6Poses["Right Arm"].CFrame=motor.C0:Inverse()*(rel*motor.C1)
	end
	-------------------------------------------- Left Arm
	if r6Poses["Left Arm"] then
		local rel = getRelative(
			character.LeftLowerArm.CFrame,
			character.UpperTorso.CFrame
		)*CFrame.new(0,character.LeftLowerArm.Size.Y*0.25,0)
		local motor = r6Character.Torso["Left Shoulder"]
		r6Poses["Left Arm"].CFrame=motor.C0:Inverse()*(rel*motor.C1)
	end
	-------------------------------------------- Right Leg
	if r6Poses["Right Leg"] then
		local rel = getRelative(
			character.RightLowerLeg.CFrame,
			character.UpperTorso.CFrame
		)*CFrame.new(0,character.RightLowerLeg.Size.Y*0.25,0)
		local motor = r6Character.Torso["Right Hip"]
		r6Poses["Right Leg"].CFrame=motor.C0:Inverse()*(rel*motor.C1)
	end
	-------------------------------------------- Left Leg
	if r6Poses["Left Leg"] then
		local rel = getRelative(
			character.LeftLowerLeg.CFrame,
			character.UpperTorso.CFrame
		)*CFrame.new(0,character.LeftLowerLeg.Size.Y*0.25,0)
		local motor = r6Character.Torso["Left Hip"]
		r6Poses["Left Leg"].CFrame=motor.C0:Inverse()*(rel*motor.C1)
	end
	-------------------------------------------- Torso
	if r6Poses.Torso then
		local rel = getRelative(
			character.UpperTorso.CFrame,
			character.HumanoidRootPart.CFrame
		)
		local motor = r6Character.HumanoidRootPart["RootJoint"]
		r6Poses.Torso.CFrame=motor.C0:Inverse()*(rel*motor.C1)
	end

	return r6Poses
end


--rotate the jointMotor player character motor through jointRot's x,y,z rotation attributes
local function moveJointR6(rotTable, jointRotName, jointMotor, addVector, rotXadd, rotYadd, rotZadd)
	local jointRot = rotTable[jointRotName] -- assign to table containg x,y,z rotations
	-- CFrame object which contains X,Y,Z rotation
	local jointLook

	if jointRotName == "neck" then -- the neck and waist require different CFrame calculations
		local neckX = (math.abs(jointRot.x) > 0) and (math.pi-jointRot.x + math.abs(jointRot.z)) or jointRot.x 
		jointLook = CFrame.fromOrientation(neckX + math.rad(rotXadd), math.rad(rotYadd), jointRot.z + math.rad(rotZadd)) + addVector
	else --normal joint
		jointLook = CFrame.fromOrientation(math.rad(rotXadd) + jointRot.x, math.rad(rotYadd), jointRot.z + math.rad(rotZadd)) + addVector
	end

	-- if upper arm is not visible enough to have an accurate pose estimation
	if jointRot.visibility < 0.4 and (jointRotName:find("shoulder") or jointRotName:find("elbow")) then 
		jointLook = CFrame.fromOrientation(math.rad(rotXadd), math.rad(rotYadd), math.rad(rotZadd)) + addVector		
	end

	-- if upper leg is not visible enough to have an accurate pose estimation
	if jointRot.visibility < 0.8 and (jointRotName:find("hip") or jointRotName:find("knee")) then 
		jointLook = CFrame.fromOrientation(math.rad(rotXadd), math.rad(rotYadd), math.rad(rotZadd)) + addVector		
	end

	local jointTween = TweenC0(jointMotor, jointLook) -- animate the joint movement into a smooth tween.
	jointTween:Play()
end


local function moveJointR15(rotTable, jointRotName, jointMotor, addVector, rotXadd, rotYadd, rotZadd)
	local jointRot = rotTable[jointRotName] -- assign to table containg x,y,z rotations
	-- CFrame object which contains X,Y,Z rotation
	local jointLook

	if jointRotName == "neck" then -- the neck and waist require different CFrame calculations
		jointLook = CFrame.fromEulerAnglesXYZ((math.pi + 1.2*jointRot.x), jointRot.z, 0)
	elseif jointRotName:find("elbow") then
		local elbowX = (math.abs(jointRot.z) > 0) and (9*math.pi/8-jointRot.z * 1.2) or jointRot.z 
		jointLook = CFrame.fromOrientation(math.clamp(elbowX + rotZadd, 0, math.pi), 0, 0)
	elseif jointRotName == "left_shoulder" then
		local shoulderX = (math.abs(jointRot.z) > 0) and (math.pi-jointRot.z) or jointRot.z
		local shoulderY = (math.abs(jointRot.z) > 0) and (math.pi/2+jointRot.x) or jointRot.x 
		jointLook = CFrame.fromOrientation(shoulderX, shoulderY, 0)
	elseif jointRotName == "right_shoulder" then
		local shoulderX = (math.abs(jointRot.z) > 0) and (math.pi+jointRot.z) or jointRot.z 
		local shoulderY = (math.abs(jointRot.z) > 0) and (math.pi/2+jointRot.x) or jointRot.x
		jointLook = CFrame.fromOrientation(shoulderX, shoulderY, 0)
	else --normal joint
		jointLook = CFrame.fromEulerAnglesXYZ(0 + math.rad(rotXadd), 0 + math.rad(rotYadd), jointRot.z + math.rad(rotZadd))
	end

	-- if upper leg is not visible enough to have an accurate pose estimation
	if jointRot.visibility < 0.8 and (jointRotName:find("hip") or jointRotName:find("knee")) then 
		jointLook = CFrame.fromEulerAnglesXYZ(0, 0, 0)		
	end

	local jointTween = TweenC0(jointMotor, jointLook + addVector) -- animate the joint movement into a smooth tween.
	jointTween:Play()
end


function VRController:_rotateBodyR6()

	local DummyR15 = Project.Assets.DummyR15
	local workspaceDummy = workspace:FindFirstChild(DummyR15.Name) 
	if not workspaceDummy then
		workspaceDummy = DummyR15:Clone()
		workspaceDummy:MoveTo(Vector3.new(0, 100, 0))
		workspaceDummy.Parent = workspace
	end
	self:_rotateBodyR15(workspaceDummy)
	local r6Poses = R15toR6(workspaceDummy, self._nexoCharacter)

	if isEnabled then
		for _,limb in ipairs(self._character:GetChildren()) do
			if limb:IsA("BasePart") then
				print("Limb:" .. limb.Name)
				if r6Poses[limb.Name] then
					print("Rotating limb:" .. limb.Name)
					print(r6Poses[limb.Name].CFrame)
					if limb.Name ~= "Torso" then					
						limb.CFrame = self._character.Torso.CFrame * r6Poses[limb.Name].CFrame
					else
						limb.CFrame = self._nexoCharacter.HumanoidRootPart.CFrame * r6Poses[limb.Name].CFrame
					end
				end
			end
		end
	else
		moveJointR6(self.data, "right_elbow", self._nexoCharacter.Torso["Left Shoulder"], 
		Vector3.new(-1,0.5,0), 0,-90,0)
		
		moveJointR6(self.data, "left_elbow", self._nexoCharacter.Torso["Right Shoulder"], 
		Vector3.new(1,0.5,0), 0,90,0)
		
		moveJointR6(self.data, "left_knee", self._nexoCharacter.Torso["Left Hip"], 
		Vector3.new(-1,-1,0), 0,-90,0) --360-math.deg(self.data.left_hip.z) - (360-math.deg(self.data.waist.z))
	
		moveJointR6(self.data, "right_knee", self._nexoCharacter.Torso["Right Hip"], 
		Vector3.new(1,-1,0), 0,90,0) -- 360-math.deg(self.data.right_hip.z) - (360-math.deg(self.data.waist.z))
	
		moveJointR6(self.data, "neck", self._nexoCharacter.Torso.Neck, 
		Vector3.new(0,1,0), -90,-180,0)
	end
end


function VRController:_rotateBodyR15(character)
	character = character or self._nexoCharacter 	
	-- shoulders
	moveJointR15(
		self.data, 
		"left_shoulder", 
		character.LeftUpperArm.LeftShoulder, 
		Vector3.new(-1,0.5,0), 
		math.deg(self.data.left_shoulder.x),
		math.deg(self.data.left_shoulder.z)+math.deg(self.data.left_shoulder.x),
		0
	)
	moveJointR15(
		self.data, 
		"right_shoulder", 
		character.RightUpperArm.RightShoulder, 
		Vector3.new(1,0.563,0), 
		math.deg(self.data.right_shoulder.x),
		math.deg(self.data.right_shoulder.z)-math.deg(self.data.right_shoulder.x),
		0
	)

	-- elbows
	moveJointR15(
		self.data, 
		"left_elbow", 
		character.LeftLowerArm.LeftElbow, 
		Vector3.new(0,-0.334,0), 
		0,
		0,
		-self.data.left_shoulder.z
	)
	moveJointR15(
		self.data, 
		"right_elbow", 
		character.RightLowerArm.RightElbow, 
		Vector3.new(0,-0.334,0), 
		0,
		0,
		-self.data.right_shoulder.z
	)

	-- upper legs (hips to knees)
	moveJointR15(self.data, "left_hip", character.LeftUpperLeg.LeftHip, 
		Vector3.new(-0.5,-0.2,0), 0,0,180+(360-math.deg(self.data.waist.z)))
	moveJointR15(self.data, "right_hip", character.RightUpperLeg.RightHip, 
		Vector3.new(0.5,-0.2,0), 0,0,180+(360-math.deg(self.data.waist.z)))

	-- lower legs (knees to ankle)
	moveJointR15(self.data, "left_knee", character.LeftLowerLeg.LeftKnee, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(self.data.left_hip.z) - (360-math.deg(self.data.waist.z)))
	moveJointR15(self.data, "right_knee", character.RightLowerLeg.RightKnee, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(self.data.right_hip.z) - (360-math.deg(self.data.waist.z)))

	-- hips (upper and lower torso)
	moveJointR15(self.data, "waist", character.UpperTorso.Waist,
		Vector3.new(0,0,0), 0,0,0) 

	-- neck/head
	moveJointR15(self.data, "neck", character.Head.Neck, 
		Vector3.new(0,0.8,0), 0,0,0)
end


function VRController:Init()
    if Initialized then return end
    
    self._url = "http://127.0.0.1:3000/download_pose/"
    self._connected = false

    self.raw_data = {}
    self.data = {}
    
    SendNotification("VR Webcam Loaded", "Press ' to toggle VR", "Close", 2, self.Icon)

    Initialized = true
    PlayerController.Modules[self.Name] = self
end


function VRController:IsConnected()
    return self._connected
end


function VRController:EnableVR()
    self._enabled = true
end


function VRController:DisableVR()
    self._enabled = false
end


function VRController:SetPoseR6()
    if dictionary_length(self.data) == 0 then return end

    local success, response = pcall(function() 
            
        self:_rotateBodyR6()
    end)
         
    if not success then
        print("Error rotating user:", response)
    end
end


function VRController:SetPoseR15()
    if dictionary_length(self.data) == 0 then return end

    local success, response = pcall(function() 
        
        self:_rotateBodyR15()
    end)
         
    if not success then
        print("Error rotating user:", response)
    end
end


function VRController:GetPose()
    if not isEnabled then return end
     
	local plrRots = {} --contains landmark rotations around the body for this particular player

    local response = game:HttpGetAsync(self._url) -- example.com/download_poses
	if response:len() == 0 then return end
    self.raw_data = HttpService:JSONDecode(response)

    for rots_index,rots_array in ipairs(self.raw_data) do
        local success, response = pcall(function() --in case a player purposefully sent malformed rotatio data that causes an error here
            
			local rots_dict = { -- dictionary of x,y,z and visibility
				x = rots_array[1], -- lua starts indices at 1 and not 0!
				y = rots_array[2],
				z = rots_array[3],
				visibility = rots_array[4]
			}
			plrRots[landmarks_order[rots_index]] = rots_dict
			self.data = plrRots
        end)
        
        if not success then --their rotation data is malformed
            print("Error parsing user data:", response)
        end
    end
	--print(#self.data)
end


function VRController:ProcessInputs()
    if debounce or Player.Focusing or Player.Emoting:GetState() or Player.ChatEmoting:GetState() then return end
    if ActionHandler.IsKeyDownBool(ToggleButton) then
        isEnabled = not isEnabled
        debounce = true
        SendNotification("VR Enabled:", tostring(isEnabled), "Close", 2, self.Icon)
        task.delay(1, function() debounce = false end)
    end
end


function VRController:Update()
    self._character = Player.getCharacter()
    self._nexoCharacter = Player.getNexoCharacter()
    
    local hum = self._character:FindFirstChild("Humanoid")

    self:ProcessInputs()

    self:GetPose()
    if hum then
        if hum.RigType == Enum.HumanoidRigType.R6 then
            self:SetPoseR6()
        else
            self:SetPoseR15()
        end
    end 

	
    if not isEnabled then
        self.data = default_state
        if hum.RigType == Enum.HumanoidRigType.R6 then
            self:_rotateBodyR6()
        else
            self:_rotateBodyR15()
        end
    end
end


function VRController:Stop()
    self._enabled = false
    self._connected = false
	isEnabled = false
    
    SendNotification("VR Stopped", "", "Close", 2, self.Icon)
    PlayerController.Modules[self.Name] = nil
    Initialized = false
end


return VRController