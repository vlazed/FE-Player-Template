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

local all_plr_url = "https://example.com/download_poses/" --URL where pose for all players is downloaded


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


local function TweenC0(Motor, EndCF) -- always use local variables, TweenC0 has been made local
	local prop = {}
	prop.C0 = EndCF
	local info = TweenInfo.new(0.5)
	return TweenService:Create(Motor, info, prop)
end


--rotate the jointMotor player character motor through jointRot's x,y,z rotation attributes
local function moveJoint(rotTable, jointRotName, jointMotor, addVector, rotXadd, rotYadd, rotZadd)
	local jointRot = rotTable[jointRotName] -- assign to table containg x,y,z rotations
	-- CFrame object which contains X,Y,Z rotation
	local jointLook

	if jointRotName == "neck" then -- the neck and waist require different CFrame calculations
		jointLook = CFrame.fromEulerAnglesXYZ(0, jointRot.z, 0) + addVector
	else --normal joint
		jointLook = CFrame.fromEulerAnglesXYZ(0 + math.rad(rotXadd), 0 + math.rad(rotYadd), jointRot.z + math.rad(rotZadd)) + addVector
	end
	-- if upper leg is not visible enough to have an accurate pose estimation
	if jointRot.visibility < 0.8 and (jointRotName:find("hip") or jointRotName:find("knee")) then 
		jointLook = CFrame.fromEulerAnglesXYZ(0, 0, 0) + addVector		
	end

	local jointTween = TweenC0(jointMotor, jointLook) -- animate the joint movement into a smooth tween.
	jointTween:Play()
end


local function rotateBodyR6(plrRots, chr)
	-- elbows
	moveJoint(plrRots, "left_elbow", chr.Torso["Left Shoulder"], 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.left_shoulder.z))
	moveJoint(plrRots, "right_elbow", chr.Torso["Right Shoulder"], 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.right_shoulder.z))

	-- lower legs (knees to ankle)
	moveJoint(plrRots, "left_knee", chr.Torso["Left Hip"], 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.left_hip.z) - (360-math.deg(plrRots.waist.z)))
	moveJoint(plrRots, "right_knee", chr.Torso["Right Hip"], 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.right_hip.z) - (360-math.deg(plrRots.waist.z)))

	-- neck/head
	moveJoint(plrRots, "neck", chr.Torso.Neck, 
		Vector3.new(0,0.8,0), 0,0,0)
end


local function rotateBodyR15(plrRots, chr) 	
	-- shoulders
	moveJoint(plrRots, "left_shoulder", chr.LeftUpperArm.LeftShoulder, 
		Vector3.new(-1,0.5,0), 0,0,180)
	moveJoint(plrRots, "right_shoulder", chr.RightUpperArm.RightShoulder, 
		Vector3.new(1,0.5,0), 0,0,180)

	-- elbows
	moveJoint(plrRots, "left_elbow", chr.LeftLowerArm.LeftElbow, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.left_shoulder.z))
	moveJoint(plrRots, "right_elbow", chr.RightLowerArm.RightElbow, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.right_shoulder.z))

	-- upper legs (hips to knees)
	moveJoint(plrRots, "left_hip", chr.LeftUpperLeg.LeftHip, 
		Vector3.new(-0.5,-0.2,0), 0,0,180+(360-math.deg(plrRots.waist.z)))
	moveJoint(plrRots, "right_hip", chr.RightUpperLeg.RightHip, 
		Vector3.new(0.5,-0.2,0), 0,0,180+(360-math.deg(plrRots.waist.z)))

	-- lower legs (knees to ankle)
	moveJoint(plrRots, "left_knee", chr.LeftLowerLeg.LeftKnee, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.left_hip.z) - (360-math.deg(plrRots.waist.z)))
	moveJoint(plrRots, "right_knee", chr.RightLowerLeg.RightKnee, 
		Vector3.new(0,-0.5,0), 0,0,360-math.deg(plrRots.right_hip.z) - (360-math.deg(plrRots.waist.z)))

	-- hips (upper and lower torso)
	moveJoint(plrRots, "waist", chr.UpperTorso.Waist,
		Vector3.new(0,0,0), 0,0,0) 

	-- neck/head
	moveJoint(plrRots, "neck", chr.Head.Neck, 
		Vector3.new(0,0.8,0), 0,0,0)
end


function VRController.new()
    local self = setmetatable({}, VRController)

    self._enabled = false
    self._url = all_plr_url
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
    if #self.data == 0 then return end

    for plrName,plrRots in pairs(self.data) do	
        local success, response = pcall(function() 
            local chr = self._character
            if chr == nil then return end -- if they don't exist in-game then skip this player 
            
            rotateBodyR6(plrRots, chr)
        end)
         
        if not success then
            print("Error rotating user", plrName..":", response)
        end
    end
end


function VRController:SetPoseR15()
    if #self.data == 0 then return end

    for plrName,plrRots in pairs(self.data) do	
        local success, response = pcall(function() 
            local chr = self._character
            if chr == nil then return end -- if they don't exist in-game then skip this player 
            
            rotateBodyR15(plrRots, chr)
        end)
         
        if not success then
            print("Error rotating user", plrName..":", response)
        end
    end
end


function VRController:GetPose()
    if not self._enabled then return end
     
    local response = game:HttpGetAsync(self._url) -- example.com/download_poses
    self.raw_data = HttpService:JSONDecode(response)

    for plrName,plrData in pairs(self.raw_data) do
        local success, response = pcall(function() --in case a player purposefully sent malformed rotatio data that causes an error here
            local plrRots = {} --contains landmark rotations around the body for this particular player
            
            for i,ln_name in pairs(landmarks_order) do -- use this order to tell which index is at what landmark
                local rots_array = plrData[i]
                local rots_dict = { -- dictionary of x,y,z and visibility
                    x = rots_array[1], -- lua starts indices at 1 and not 0!
                    y = rots_array[2],
                    z = rots_array[3],
                    visibility = rots_array[4]
                }
                plrRots[ln_name] = rots_dict
            end
            
            self.data[plrName] = plrRots
        end)
        
        if not success then --their rotation data is malformed
            print("Error parsing user data of", plrName..":", response)
        end
    end
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