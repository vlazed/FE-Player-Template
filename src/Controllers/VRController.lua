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

local VRController = {}
VRController.__index = VRController

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


--rotate the jointMotor player character motor through jointRot's x,y,z rotation attributes
local function moveJoint(rotTable, jointRotName, jointMotor, addVector, rotXadd, rotYadd, rotZadd)
	local jointRot = rotTable[jointRotName] -- assign to table containg x,y,z rotations
	-- CFrame object which contains X,Y,Z rotation
	local jointLook

	if jointRotName == "neck" then -- the neck and waist require different CFrame calculations
		jointLook = CFrame.fromOrientation(math.rad(rotXadd) + (math.pi - jointRot.x), math.rad(rotYadd), jointRot.z) + addVector
	else --normal joint
		jointLook = CFrame.fromOrientation(math.rad(rotXadd) + (jointRot.x), math.rad(rotYadd) + jointRot.y, (math.pi - jointRot.z) + math.rad(rotZadd)) + addVector
	end
	-- if upper leg is not visible enough to have an accurate pose estimation
	if jointRot.visibility < 0.8 and (jointRotName:find("hip") or jointRotName:find("knee")) then 
		jointLook = CFrame.fromOrientation(jointRot.x + math.rad(rotXadd), jointRot.y + math.rad(rotYadd), jointRot.z + math.rad(rotZadd)) + addVector		
	end

	local jointTween = TweenC0(jointMotor, jointLook) -- animate the joint movement into a smooth tween.
	jointTween:Play()
end


function VRController:_rotateBodyR6()
	-- elbows
	if self.data.left_shoulder then
		moveJoint(self.data, "left_shoulder", self._nexoCharacter.Torso["Left Shoulder"], 
		Vector3.new(-1,0.5,0), 0,-90,360-math.deg(self.data.left_shoulder.z))
	end
	if self.data.right_shoulder then
		moveJoint(self.data, "right_shoulder", self._nexoCharacter.Torso["Right Shoulder"], 
		Vector3.new(1,0.5,0), 0,90,360-math.deg(self.data.right_shoulder.z))
	end
	
	-- lower legs (knees to ankle)
	if self.data.left_knee then
		moveJoint(self.data, "left_knee", self._nexoCharacter.Torso["Left Hip"], 
		Vector3.new(1,-1,0), 0,-90,0) --360-math.deg(self.data.left_hip.z) - (360-math.deg(self.data.waist.z))
	end
	if self.data.right_knee then
		moveJoint(self.data, "right_knee", self._nexoCharacter.Torso["Right Hip"], 
		Vector3.new(-1,-1,0), 0,90,0) -- 360-math.deg(self.data.right_hip.z) - (360-math.deg(self.data.waist.z))
	end

	-- neck/head
	if self.data.neck then
		moveJoint(self.data, "neck", self._nexoCharacter.Torso.Neck, 
		Vector3.new(0,1,0), -90,-180,0)
	end
	print(self.data.neck)
	print(self.data.left_shoulder)
	print(self.data.right_shoulder)
end


function VRController:_rotateBodyR15() 	
	-- shoulders
	moveJoint(self.data, "left_shoulder", self._nexoCharacter.LeftUpperArm.LeftShoulder, 
		Vector3.new(-1,0.5,0), 0,0,180)
	moveJoint(self.data, "right_shoulder", self._nexoCharacter.RightUpperArm.RightShoulder, 
		Vector3.new(1,0.5,0), 0,0,180)

	-- elbows
	moveJoint(self.data, "left_elbow", self._nexoCharacter.LeftLowerArm.LeftElbow, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(self.data.left_shoulder.z))
	moveJoint(self.data, "right_elbow", self._nexoCharacter.RightLowerArm.RightElbow, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(self.data.right_shoulder.z))

	-- upper legs (hips to knees)
	moveJoint(self.data, "left_hip", self._nexoCharacter.LeftUpperLeg.LeftHip, 
		Vector3.new(-0.5,-0.2,0), 0,0,180+(360-math.deg(self.data.waist.z)))
	moveJoint(self.data, "right_hip", self._nexoCharacter.RightUpperLeg.RightHip, 
		Vector3.new(0.5,-0.2,0), 0,0,180+(360-math.deg(self.data.waist.z)))

	-- lower legs (knees to ankle)
	moveJoint(self.data, "left_knee", self._nexoCharacter.LeftLowerLeg.LeftKnee, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(self.data.left_hip.z) - (360-math.deg(self.data.waist.z)))
	moveJoint(self.data, "right_knee", self._nexoCharacter.RightLowerLeg.RightKnee, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(self.data.right_hip.z) - (360-math.deg(self.data.waist.z)))

	-- hips (upper and lower torso)
	moveJoint(self.data, "waist", self._nexoCharacter.UpperTorso.Waist,
		Vector3.new(0,0,0), 0,0,0) 

	-- neck/head
	moveJoint(self.data, "neck", self._nexoCharacter.Head.Neck, 
		Vector3.new(0,0.8,0), 0,0,0)
end


function VRController.new()
    local self = setmetatable({}, VRController)

    self._enabled = false
    self._url = "http://127.0.0.1:3000/download_pose/"
    self._character = Player.getCharacter()
    self._nexoCharacter = Player.getNexoCharacter()
    self._connected = false

    self.raw_data = {}
    self.data = {}
    
    return self
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
    if not self._enabled then return end
     
	local plrRots = {} --contains landmark rotations around the body for this particular player

    local response = game:HttpGetAsync(self._url) -- example.com/download_poses
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

	for limb,rots_array in pairs(self.data) do
		print(limb)
		print(rots_array.x)
	end
	--print(#self.data)
end


function VRController:Update()
    local hum = self._character:FindFirstChild("Humanoid")
    self:GetPose()
    if hum then
        if hum.RigType == Enum.HumanoidRigType.R6 then
            self:SetPoseR6()
        else
            self:SetPoseR15()
        end
    end 
end


function VRController:Destroy()
    self._enabled = false
    self._connected = false
end


return VRController