--[[
	Animation Recorder by Vlazed
	
	Given a time resolution and interval, this script will attempt to record your character's current animation
	
	The animation will be saved in your workspace, in a .lua file with the following contents:
	
	
	```
	return {
		Properties = {
			Looping = true,
			Priority = Enum.AnimationPriority.Movement
		},
		Keyframes = {
			{
				["Time"] = 0,
				["HumanoidRootPart"] = {
					["Torso"] = {
						CFrame = CFrame.new(0, 0, 0)
					}
				}
			}
		}
	
	}
	```
	
	This can only be loaded into a keyframesequence using a modified keyframesequence to modulescript plugin, which you can find in the 
	FE-Player-Template repository.
	
	The format above is based on code from the plugin. All credits is given to their respective owners.
--]]

local DEBUG = false

local RESOLUTION = 0.05
local INTERVAL = 15

local frames = INTERVAL / RESOLUTION

local function d_print(...)
	if DEBUG then
		d_print = print
	end
end

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local recordButton = Enum.KeyCode.P


local function sendNotification(title, text, buttonText, duration)
	text = text or ""
	buttonText = buttonText or ""
	duration = duration or 1

	game.StarterGui:SetCore("SendNotification", 
		{
			Title = title, 
			Text = text, 
			Icon = "rbxassetid://4688867958", 
			Duration = duration, 
			Button1 = buttonText
		}
	)
end


local function isExistent()
	local exists = LocalPlayer.Character
	-- TODO: Consider case when character model hierarchy is nonstandard
	if exists then
		--d_print("Character "..exists.Name.." exists.")
		return exists
	else
		--d_print("Character doesn't exist")
		return false
	end
end


local function isAlive()
	local character = isExistent()
	if not character then return false end

	--d_print("Character "..character.Name.." exists.")

	local humanoid = character:FindFirstChild("Humanoid")

	if 
		not humanoid
		or humanoid:GetState() == Enum.HumanoidStateType.Dead 
		or humanoid.Health == 0
		or not character
	then
		--d_print("Not alive")
		return false 
	end

	--d_print("Alive")
	return character, humanoid
end


local function round(num, idp)
	local mult = 10^(idp or 3)
	return math.floor(num * mult + 0.5) / mult
end


local function ConvertCFrame(cf, degrees)
	local str = ""
	if round(cf.X) ~= 0 or round(cf.Y) ~= 0 or round(cf.Z) ~= 0 then
		str = ("CFrame.new(%s, %s, %s)"):format(round(cf.X), round(cf.Y), round(cf.Z))
	else
		str = "CFrame.new()"
	end

	local x, y, z = cf:toEulerAnglesXYZ()
	x, y, z = round(x), round(y), round(z)
	if x ~= 0 or y ~= 0 or z ~= 0 then
		if str == "CFrame.new()" then
			str = ""
		else
			str = str.." * "
		end	

		str = str.."CFrame.Angles("
		local function AddAngle(n, comma)
			str = str..((not degrees or n == 0) and n or "math.rad("..round(math.deg(n))..")")..(comma and ", " or ")")
		end

		AddAngle(x, true)
		AddAngle(y, true)
		AddAngle(z)
	end

	return str
end


local function capturePoseR15(character: Model, timePosition: number) : string
	local source = ""


	local function AddLine(text: string, depth: number)
		source = source.."\n"..string.rep("	", depth or 0)..text
	end

	local function GetPose(start, depth, motor: Motor6D, closing)
		local depth = depth or 2

		local hidden-- = (start.Name == "HumanoidRootPart")
		if hidden then
			depth = depth - 1
		end

		AddLine('["'..start.Name..'"] = {', depth)

		if ConvertCFrame(motor.Transform, true) ~= "CFrame.new()" then
			AddLine("CFrame = "..ConvertCFrame(motor.Transform, true)..",", depth + 1)
		end			

		if closing then
			AddLine('},', depth)
		end
	end

	AddLine("{", 2)
	AddLine('["Time"] = '..round(timePosition)..",", 3)
	AddLine('["HumanoidRootPart"] = {', 3)
	GetPose(character.LowerTorso, 4, character.LowerTorso.Root)

	GetPose(character.LeftUpperLeg, 5, character.LeftUpperLeg.LeftHip)
	GetPose(character.LeftLowerLeg, 6, character.LeftLowerLeg.LeftKnee)
	GetPose(character.LeftFoot, 7, character.LeftFoot.LeftAnkle, true)
	AddLine('},', 6)
	AddLine('},', 5)

	GetPose(character.RightUpperLeg, 5, character.RightUpperLeg.RightHip)
	GetPose(character.RightLowerLeg, 6, character.RightLowerLeg.RightKnee)
	GetPose(character.RightFoot, 7, character.RightFoot.RightAnkle, true)
	AddLine('},', 6)
	AddLine('},', 5)

	GetPose(character.UpperTorso, 5, character.UpperTorso.Waist)	
	GetPose(character.Head, 6, character.Head.Neck, true)

	GetPose(character.RightUpperArm, 6, character.RightUpperArm.RightShoulder)
	GetPose(character.RightLowerArm, 7, character.RightLowerArm.RightElbow)
	GetPose(character.RightHand, 8, character.RightHand.RightWrist, true)
	AddLine('},', 7)
	AddLine('},', 6)

	GetPose(character.LeftUpperArm, 6, character.LeftUpperArm.LeftShoulder)
	GetPose(character.LeftLowerArm, 7, character.LeftLowerArm.LeftElbow)
	GetPose(character.LeftHand, 8, character.LeftHand.LeftWrist, true)
	AddLine('},', 7)
	AddLine('},', 6)

	AddLine('},', 5)
	AddLine('},', 4)
	AddLine('},', 3) 
	AddLine('},', 2) -- Closing Bracket

	return source
end


local function capturePoseR6(character: Model, timePosition: number) : string
	local source = ""


	local function AddLine(text: string, depth: number)
		source = source.."\n"..string.rep("	", depth or 0)..text
	end

	local function GetPose(start, depth, motor: Motor6D, closing)
		local depth = depth or 2

		local hidden-- = (start.Name == "HumanoidRootPart")
		if hidden then
			depth = depth - 1
		end

		AddLine('["'..start.Name..'"] = {', depth)

		if ConvertCFrame(motor.Transform, true) ~= "CFrame.new()" then
			AddLine("CFrame = "..ConvertCFrame(motor.Transform, true)..",", depth + 1)
		end			

		if closing then
			AddLine('},', depth)
		end
	end

	AddLine("{", 2)
	AddLine('["Time"] = '..round(timePosition)..",", 3)
	AddLine('["HumanoidRootPart"] = {', 3)
	GetPose(character.Torso, 4, character.HumanoidRootPart.RootJoint)
	GetPose(character["Left Leg"], 5, character.Torso["Left Hip"], true)
	GetPose(character["Right Leg"], 5, character.Torso["Right Hip"], true)
	GetPose(character["Left Arm"], 5, character.Torso["Left Shoulder"], true)
	GetPose(character["Right Arm"], 5, character.Torso["Right Shoulder"], true)
	GetPose(character["Head"], 5, character.Torso["Neck"], true)
	AddLine('},', 4)
	AddLine('},', 3)
	AddLine('},', 2) -- Closing Bracket

	return source
end


local function recordCharacterPoses(_, is, _) : string
	if is == Enum.UserInputState.End then return end
	
	local dt = DateTime.now()
	local fileName = "RecordedAnimation-"..dt:FormatLocalTime("MMDDYYYYHHmmss", "en-us")..".lua"
	local source = "return {"

	local character, humanoid = isAlive()
	local rigtype = humanoid.RigType

	local function AddLine(text: string, depth: number)
		source = source.."\n"..string.rep("	", depth or 0)..text
	end

	AddLine("Properties = {", 1)
	AddLine("Looping = true,", 2)
	AddLine("Priority = Enum.AnimationPriority.Action", 2)
	AddLine("},", 1)

	AddLine("Keyframes = {", 1)

	local keyframe = 0 

	if rigtype == Enum.HumanoidRigType.R6 then
		sendNotification("Recording R6", "Detected R6 Rig", "Close", 1)
		repeat
			source = source .. capturePoseR6(character, keyframe * RESOLUTION)
			task.wait(RESOLUTION)
			keyframe += 1
		until keyframe > frames
	else
		sendNotification("Recording R15", "Detected R15 Rig", "Close", 1)
		repeat
			source = source .. capturePoseR15(character, keyframe * RESOLUTION)
			task.wait(RESOLUTION)
			keyframe += 1
		until keyframe > frames
	end

	AddLine("}\n}", 1)		

	if writefile then
		writefile(fileName, source)
	else
		local modulescript = Instance.new("ModuleScript")
		--modulescript.Name = fileName
		--modulescript.Source = source
		print(source)
	end
	
	sendNotification("Finished recording", "Saved to\n"..fileName, "Close", 1)
end


sendNotification("Animation Recorder", "Press R to record your character", "Close", 1)

ContextActionService:UnbindAction("RecordAnimations")
ContextActionService:BindAction("RecordAnimations", recordCharacterPoses, false, recordButton)