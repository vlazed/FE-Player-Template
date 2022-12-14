local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local ActionHandler = require(Project.Controllers.ActionHandler)
local Animation = require(Project.Controllers.Animations.Animation)
local AnimationController = require(Project.Controllers.AnimationController)
local ControllerSettings = require(Project.Controllers.ControllerSettings)
local EmoteController = require(Project.Controllers.EmoteController)

local Network = require(Project.Util.Network)

-- TODO: Determine CFrame-based implementation for R6 IK Foot Placement 
--local R6IKController = require(Project.Controllers.R6IKController)

local Player = require(Project.Player)

local SendNotification = require(Project.Util.SendNotification)
local FastTween = require(Project.Util.FastTween)
local Thread = require(Project.Util.Thread)
local Signal = require(Project.Packages.Signal)
local Spring = require(Project.Util.Spring)

local RunService = game:GetService("RunService")

local PlayerController = {}

local FALLEN_PARTS_THRESHOLD = 0.25

local respawnConnection

local EPSILON = 1e-4
local DEBUG = false

local moveVector = Player.getHumanoidRootPart().CFrame.LookVector
local tiltVector = Vector3.new(0, 1, 0)
local tiltSpring = Spring.new(2, tiltVector)
local moveSpring = Spring.new(2, moveVector)

PlayerController.AttackPosition = Vector3.new()

local Mouse = Player.getMouse()

local IKArmController
local IKLegController

if Player:GetRigType() == Enum.HumanoidRigType.R6 then
	IKArmController = require(Project.Controllers.IKB.R6.Arm)
	IKLegController = require(Project.Controllers.IKB.R6.Leg)
else
	IKArmController = require(Project.Controllers.IKB.R15.AL)
	IKLegController = require(Project.Controllers.IKB.R15.AL)
end

PlayerController.LeftArm = nil 
PlayerController.RightArm = nil
PlayerController.LeftLeg = nil 
PlayerController.RightLeg = nil

PlayerController.ResetTransform = false

local posSpring = Spring.new(1, Vector3.new())

local toggleFling = false
local debounce = false

local fallingSpeed = 0
local currentFlipDelay = 0

local previousCFrame = CFrame.identity

PlayerController.Animation = Animation.new("Blank", {}, 30, false)
PlayerController.Framerate = 30
PlayerController.LerpEnabled = false

PlayerController.Buoyancy = nil

local connection

PlayerController.Modules = {}

-- Animation Controller Layers
PlayerController.LayerA = AnimationController.new(Player.AnimationModule)
PlayerController.LayerB = AnimationController.new()
PlayerController.DanceLayer = AnimationController.new(false)
PlayerController.Initialized = false

local nexoConnections

local massPollRate = 1
local massExecuteTime = tick() + 1/massPollRate

local updateModuleRate = 1
local moduleExecuteTime = tick() + 1/updateModuleRate

local previousVelocity = Vector3.new()

local animationConnections = {}

-- https://raw.githubusercontent.com/CenteredSniper/Kenzen/master/ZendeyReanimate.lua
local function setPhysicsOptimizations()
	if RunService:IsStudio() then return end

	settings()["Physics"].PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
	settings()["Physics"].AllowSleep = false
	settings()["Physics"].ForceCSGv2 = false
	settings()["Physics"].DisableCSGv2 = true
	settings()["Physics"].UseCSGv2 = false
	settings()["Physics"].ThrottleAdjustTime = math.huge - math.huge

	sethiddenproperty(workspace,"PhysicsSteppingMethod",Enum.PhysicsSteppingMethod.Fixed)
	--sethiddenproperty(workspace,"PhysicsSimulationRate",Enum.PhysicsSimulationRate.Fixed240Hz)
	sethiddenproperty(workspace, "SignalBehavior", "Immediate")

	workspace.InterpolationThrottling = Enum.InterpolationThrottlingMode.Disabled
	workspace.Retargeting = "Disabled"
end


--[[
local R6Legs
local LeftLeg
local RightLeg
]]
-- https://v3rmillion.net/showthread.php?tid=1073859
-- Modified to borrow netless implementations from Nexo
local function _R15ReanimLoad()
	local plr  = game:GetService("Players").LocalPlayer
	local char = plr.Character

	-- Grabbed from Nexo
	local c={}
	nexoConnections = c
	local d=table.insert 
    for D,E in next,char:GetDescendants()do 
		if E:IsA("BasePart")then 
			Network:RetainPart(E)
			Network:FollowPart(E)

			d(c,game:GetService("RunService").Heartbeat:connect(function()
				pcall(function()
					E.Velocity=Vector3.new(1,1,1) * 17.325
					if RunService:IsClient() then
						sethiddenproperty(game.Players.LocalPlayer,"MaximumSimulationRadius",math.huge)
						sethiddenproperty(game.Players.LocalPlayer,"SimulationRadius",999999999)
					end
					game.Players.LocalPlayer.ReplicationFocus=workspace 
				end)
			end))
		end 
	end 

	--making variables
	local rs = game:GetService("RunService")
	local e=false
	local cam  = workspace:WaitForChild("Camera")

	local folder=Instance.new('Folder')
	folder.Name='CWExtra'
	char.Archivable=true
    folder.Parent = char

	local fakechar = char:Clone()
	for D,E in next,fakechar:GetDescendants()do 
		if E:IsA('BasePart') or E:IsA('Decal') then 
			E.Transparency=1 
		end 
	end 

	local h = 5.65
	local function anchorAllParts(value)
		char.UpperTorso.Anchored = value
		char.LowerTorso.Anchored = value
		char.RightUpperArm.Anchored = value
		char.LeftUpperArm.Anchored = value
		char.RightUpperLeg.Anchored = value
		char.LeftUpperLeg.Anchored = value
		char.RightLowerArm.Anchored = value
		char.LeftLowerArm.Anchored = value
		char.RightLowerLeg.Anchored = value
		char.LeftLowerLeg.Anchored = value
		char.RightHand.Anchored = value
		char.LeftHand.Anchored = value
		char.RightFoot.Anchored = value
		char.LeftFoot.Anchored = value
	end

	plr.Character = nil
	plr.Character = char

	char.Humanoid.WalkSpeed = 0
	char.Humanoid.JumpPower = 0
	anchorAllParts(true)
	char.Animate.Disabled = true
	SendNotification('R15 Reanimation','Reanimating...\nPlease wait '..h..' seconds.')
	wait(h)
	anchorAllParts(false)
	SendNotification('R15 Reanimation','Reanimated')
	char.Humanoid.Health = 0
	fakechar.Animate.Disabled = true
	
	fakechar.Parent = folder
	fakechar.HumanoidRootPart.CFrame=char.HumanoidRootPart.CFrame
	cam.CameraSubject = fakechar:FindFirstChildOfClass("Humanoid")

	fakechar.Name='NexoPD'

	local connections = {}
	local kill = false
	--creating aling function which will be used to hold your body parts
	local function Align(Part1, Part0, Position, Angle)
		Part1.CanCollide = false

		local AlignPos = Instance.new("AlignPosition")
		AlignPos.ApplyAtCenterOfMass = true
		AlignPos.MaxForce = 100000
		AlignPos.MaxVelocity = math.huge
		AlignPos.ReactionForceEnabled = false
		AlignPos.Responsiveness = 200
		AlignPos.RigidityEnabled = false
		AlignPos.Parent = Part1

		local AlignOri = Instance.new("AlignOrientation")
		AlignOri.MaxAngularVelocity = math.huge
		AlignOri.MaxTorque = 100000
		AlignOri.PrimaryAxisOnly = false
		AlignOri.ReactionTorqueEnabled = false
		AlignOri.Responsiveness = 200
		AlignOri.RigidityEnabled = false
		AlignOri.Parent = Part1

		local at1 = Instance.new("Attachment")
		at1.Parent = Part1
		local at2 = Instance.new("Attachment")
		at2.Parent = Part0
		at2.Orientation = Angle
		at2.Position = Position
		
		AlignPos.Attachment0 = at1
		AlignPos.Attachment1 = at2
		AlignOri.Attachment0 = at1
		AlignOri.Attachment1 = at2
	end

	local success, fail = pcall(function()
		-- Make the fake character invisible
		for _,v in pairs(fakechar:GetDescendants()) do
			if v:IsA("MeshPart") then
				v.Transparency = 1
			elseif v:IsA("SpecialMesh") then
				v.MeshId = "rbxassetid://0"
			end
		end

			-- Noclipping
		table.insert(connections, rs.Stepped:Connect(function()
			for i,v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
			--[[
			fakechar:FindFirstChild("Head").CanCollide = false
			fakechar:FindFirstChild("UpperTorso").CanCollide = false
			fakechar:FindFirstChild("LowerTorso").CanCollide = false
			fakechar:FindFirstChild("RightUpperLeg").CanCollide = false
			fakechar:FindFirstChild("RightLowerLeg").CanCollide = false
			fakechar:FindFirstChild("LeftUpperLeg").CanCollide = false
			fakechar:FindFirstChild("LeftLowerLeg").CanCollide = false
			fakechar:FindFirstChild("RightUpperArm").CanCollide = false
			fakechar:FindFirstChild("RightLowerArm").CanCollide = false
			fakechar:FindFirstChild("LeftUpperArm").CanCollide = false
			fakechar:FindFirstChild("LeftLowerArm").CanCollide = false
			fakechar:FindFirstChild("LeftHand").CanCollide = false
			fakechar:FindFirstChild("LeftFoot").CanCollide = false
			fakechar:FindFirstChild("RightFoot").CanCollide = false
			fakechar:FindFirstChild("RightHand").CanCollide = false
			fakechar:FindFirstChild("HumanoidRootPart").CanCollide = false
			char.HumanoidRootPart.CanCollide = true
			char.Head.CanCollide = false
			char.UpperTorso.CanCollide = false
			char.LowerTorso.CanCollide = false
			char.RightUpperArm.CanCollide = false
			char.LeftUpperArm.CanCollide = false
			char.RightUpperLeg.CanCollide = false
			char.LeftUpperLeg.CanCollide = false
			char.RightLowerArm.CanCollide = false
			char.LeftLowerArm.CanCollide = false
			char.RightLowerLeg.CanCollide = false
			char.LeftLowerLeg.CanCollide = false
			char.RightHand.CanCollide = false
			char.LeftHand.CanCollide = false
			char.RightFoot.CanCollide = false
			char.LeftFoot.CanCollide = false
			]]
		end))
		table.insert(connections, rs.Heartbeat:Connect(function()
			for i,v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
			--[[
			fakechar:FindFirstChild("Head").CanCollide = false
			fakechar:FindFirstChild("UpperTorso").CanCollide = false
			fakechar:FindFirstChild("LowerTorso").CanCollide = false
			fakechar:FindFirstChild("RightUpperLeg").CanCollide = false
			fakechar:FindFirstChild("RightLowerLeg").CanCollide = false
			fakechar:FindFirstChild("LeftUpperLeg").CanCollide = false
			fakechar:FindFirstChild("LeftLowerLeg").CanCollide = false
			fakechar:FindFirstChild("RightUpperArm").CanCollide = false
			fakechar:FindFirstChild("RightLowerArm").CanCollide = false
			fakechar:FindFirstChild("LeftUpperArm").CanCollide = false
			fakechar:FindFirstChild("LeftLowerArm").CanCollide = false
			fakechar:FindFirstChild("LeftHand").CanCollide = false
			fakechar:FindFirstChild("LeftFoot").CanCollide = false
			fakechar:FindFirstChild("RightFoot").CanCollide = false
			fakechar:FindFirstChild("RightHand").CanCollide = false
			fakechar:FindFirstChild("HumanoidRootPart").CanCollide = false
			char.HumanoidRootPart.CanCollide = true
			char.Head.CanCollide = false
			char.UpperTorso.CanCollide = false
			char.LowerTorso.CanCollide = false
			char.RightUpperArm.CanCollide = false
			char.LeftUpperArm.CanCollide = false
			char.RightUpperLeg.CanCollide = false
			char.LeftUpperLeg.CanCollide = false
			char.RightLowerArm.CanCollide = false
			char.LeftLowerArm.CanCollide = false
			char.RightLowerLeg.CanCollide = false
			char.LeftLowerLeg.CanCollide = false
			char.RightHand.CanCollide = false
			char.LeftHand.CanCollide = false
			char.RightFoot.CanCollide = false
			char.LeftFoot.CanCollide = false
			]]
		end))
		table.insert(connections, rs.RenderStepped:Connect(function()
			for i,v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
			--[[
			fakechar:FindFirstChild("Head").CanCollide = false
			fakechar:FindFirstChild("UpperTorso").CanCollide = false
			fakechar:FindFirstChild("LowerTorso").CanCollide = false
			fakechar:FindFirstChild("RightUpperLeg").CanCollide = false
			fakechar:FindFirstChild("RightLowerLeg").CanCollide = false
			fakechar:FindFirstChild("LeftUpperLeg").CanCollide = false
			fakechar:FindFirstChild("LeftLowerLeg").CanCollide = false
			fakechar:FindFirstChild("RightUpperArm").CanCollide = false
			fakechar:FindFirstChild("RightLowerArm").CanCollide = false
			fakechar:FindFirstChild("LeftUpperArm").CanCollide = false
			fakechar:FindFirstChild("LeftLowerArm").CanCollide = false
			fakechar:FindFirstChild("LeftHand").CanCollide = false
			fakechar:FindFirstChild("LeftFoot").CanCollide = false
			fakechar:FindFirstChild("RightFoot").CanCollide = false
			fakechar:FindFirstChild("RightHand").CanCollide = false
			fakechar:FindFirstChild("HumanoidRootPart").CanCollide = false
			char.HumanoidRootPart.CanCollide = true
			char.Head.CanCollide = false
			char.UpperTorso.CanCollide = false
			char.LowerTorso.CanCollide = false
			char.RightUpperArm.CanCollide = false
			char.LeftUpperArm.CanCollide = false
			char.RightUpperLeg.CanCollide = false
			char.LeftUpperLeg.CanCollide = false
			char.RightLowerArm.CanCollide = false
			char.LeftLowerArm.CanCollide = false
			char.RightLowerLeg.CanCollide = false
			char.LeftLowerLeg.CanCollide = false
			char.RightHand.CanCollide = false
			char.LeftHand.CanCollide = false
			char.RightFoot.CanCollide = false
			char.LeftFoot.CanCollide = false
			]]
		end))

		-- using the align function to prevent body parts from falling
		for _,v in pairs(char:GetChildren()) do
			if v:IsA("MeshPart") or v.Name == "Head" then
				if v.Name == "UpperTorso" then
					Align(char[v.Name], fakechar[v.Name], Vector3.new(0,0,0),Vector3.new(0,0,0))
				else
					Align(char[v.Name], fakechar[v.Name], Vector3.new(0,0,0),Vector3.new(0,0,0))
				end
			end
		end

		local function i(D,E,F,G)
			Instance.new("Attachment",D)
			Instance.new("AlignPosition",D)
			Instance.new("AlignOrientation",D)
			Instance.new("Attachment",E)
	
			D.Attachment.Name=D.Name 
			E.Attachment.Name=D.Name 
			D.AlignPosition.Attachment0=D[D.Name]
			D.AlignOrientation.Attachment0=D[D.Name]
			D.AlignPosition.Attachment1=E[D.Name]
			D.AlignOrientation.Attachment1=E[D.Name]
			E[D.Name].Position=F or Vector3.new()
			D[D.Name].Orientation=G or Vector3.new()
			D.AlignPosition.MaxForce=999999999 
			D.AlignPosition.MaxVelocity=math.huge 
			D.AlignPosition.ReactionForceEnabled=false 
			D.AlignPosition.Responsiveness=math.huge 
			D.AlignOrientation.Responsiveness=math.huge 
			D.AlignPosition.RigidityEnabled=false 
			D.AlignOrientation.MaxTorque=999999999 
			D.Massless=true 
		end

		for D,E in next,char:GetDescendants()do 
			if E:IsA('Accessory')then 
				i(E.Handle,fakechar[E.Name].Handle)
			end 
		end 

		local k=plr:GetMouse()

		local z=Instance.new("Part")
		z.CanCollide=false 
		z.Transparency=1
		z.Parent = folder
	
		d(c,rs.RenderStepped:Connect(function()
			local D=workspace.CurrentCamera.CFrame.lookVector 
			local E=fakechar["HumanoidRootPart"]
			z.Position=E.Position 
			z.CFrame=CFrame.new(z.Position,Vector3.new(D.X*10000,D.Y,D.Z*10000))
		end))
		local l,m,n,o,p=false,false,false,false,false
		local function q(D)
			local r=Instance.new('BodyAngularVelocity')
			local b=Instance.new('AngularVelocity')
			r.AngularVelocity=Vector3.new(2147483646,2147483646,2147483646)
			r.MaxTorque=Vector3.new(2147483646,2147483646,2147483646)
			b.AngularVelocity = Vector3.new(2147483646,2147483646,2147483646)
			b.MaxTorque = 2147483646
			b.Attachment0 = Player.getCharacterRootAttachment()
			b.Parent = D
			r.Parent = D
		end 
		q(char.HumanoidRootPart)
		k=plr:GetMouse()
		
		local s=Instance.new('BodyPosition')
		s.P=9e9 
		s.D=9e9 
		s.MaxForce=Vector3.new(99999,99999,99999)
		s.Position = char.HumanoidRootPart.Position
		s.Parent = char.HumanoidRootPart
		

		local A 
		d(c,rs.Heartbeat:Connect(function()
			if not char:FindFirstChild("HumanoidRootPart") then return end
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if rs:IsStudio() then 
				hrp.Anchored = true
			end
			if A==true then 
				s.Position=k.Hit.p 
				hrp.Position=k.Hit.p 
			else
				if Player.Attacking:GetState() then
					s.Position = PlayerController.AttackPosition
					hrp.Position = PlayerController.AttackPosition
				else
					s.Position=fakechar.UpperTorso.Position
					hrp.Position=fakechar.HumanoidRootPart.Position
				end
				--b.HumanoidRootPart.CanCollide = not toggleFling
				if Player:GetFramerate() > 25 then
					hrp.BodyAngularVelocity.AngularVelocity = (toggleFling or Player.Attacking:GetState()) and Vector3.new(2147483646,2147483646,2147483646) or Vector3.new(5, 5, 5)
					hrp.AngularVelocity.Enabled = toggleFling
				else
					s.Position=fakechar.UpperTorso.Position
					hrp.Position=fakechar.UpperTorso.Position
					hrp.AngularVelocity.Enabled = false
					hrp.BodyAngularVelocity.AngularVelocity = Vector3.new(5, 5, 5)
				end
			end
		end))

		local B=Instance.new("SelectionBox")
		B.Adornee=char.HumanoidRootPart 
		B.LineThickness=0.02 
		B.Color3=Color3.fromRGB(250,0,0)
		B.Parent=char.HumanoidRootPart 
		B.Name="RAINBOW"

	end)

	if fail then
		warn(fail)
		--plr.Character = char
		--char:BreakJoints()
		--fakechar:Destroy()

		PlayerController:Respawn()
		return
	end

	SendNotification("R15 Reanimation", "Loaded")
end


-- Nexo Character Reanimation
local function _NexoLoad(canClickFling)
    canClickFling = canClickFling or false

	local a=game.Players.LocalPlayer 
	local b=game.Players.LocalPlayer.Character 
	if not b or not b.Parent then
		b = a.CharacterAdded:Wait()
	end
	local c={}
	local d=table.insert 
	local e=false 
	
    for D,E in next,b:GetDescendants()do 
		if E:IsA("BasePart")then 
			Network:RetainPart(E)
			Network:FollowPart(E)
			
			d(c,game:GetService("RunService").Heartbeat:connect(function()
				pcall(function()
					E.Velocity=Vector3.new(1,1,1) * 17.325
					if RunService:IsClient() then
						sethiddenproperty(game.Players.LocalPlayer,"MaximumSimulationRadius",math.huge)
						sethiddenproperty(game.Players.LocalPlayer,"SimulationRadius",1000)
					end
					game.Players.LocalPlayer.ReplicationFocus=workspace 
				end)
			end))
			
		end 
	end 
	

    local function f(D,E,F)
		game.StarterGui:SetCore("SendNotification",{Title=D;Text=E;Duration=F or 5;})
	end 
	
    local x=game:GetService("RunService")
	local g=Instance.new('Folder')
	g.Name='CWExtra'
	b.Archivable=true
    g.Parent = b

    local y=b:Clone()
	y.Name='NexoPD'
	for D,E in next,y:GetDescendants()do 
		if E:IsA('BasePart') or E:IsA('Decal') then 
			E.Transparency=1 
		end 
	end 
	local h=5.65 
	a.Character=nil 
	a.Character=b 
	b.Humanoid.AutoRotate=false 
	b.Humanoid.WalkSpeed=0 
	b.Humanoid.JumpPower=0 
	b.Torso.Anchored=true 
	b["Right Arm"].Anchored = true
	b["Left Arm"].Anchored = true
	b["Right Leg"].Anchored = true
	b["Left Leg"].Anchored = true
	b.Animate.Disabled = true
	f('Nexo','Reanimating...\nPlease wait '..h..' seconds.')
	wait(h)
	b.Torso.Anchored=false
	b["Right Arm"].Anchored = false
	b["Left Arm"].Anchored = false
	b["Right Leg"].Anchored = false
	b["Left Leg"].Anchored = false
	f('Nexo','Reanimated..')
	b.Humanoid.Health=0 
	y.Animate.Disabled=true 
	y.Parent=g 
	y.HumanoidRootPart.CFrame=b.HumanoidRootPart.CFrame*CFrame.new(0,5,0)

	local function i(D,E,F,G)
		Instance.new("Attachment",D)
		Instance.new("AlignPosition",D)
		Instance.new("AlignOrientation",D)
		Instance.new("Attachment",E)

		D.Attachment.Name=D.Name 
		E.Attachment.Name=D.Name 
		D.AlignPosition.Attachment0=D[D.Name]
		D.AlignOrientation.Attachment0=D[D.Name]
		D.AlignPosition.Attachment1=E[D.Name]
		D.AlignOrientation.Attachment1=E[D.Name]
		E[D.Name].Position=F or Vector3.new()
		D[D.Name].Orientation=G or Vector3.new()
		D.AlignPosition.MaxForce=999999999 
		D.AlignPosition.MaxVelocity=math.huge 
		D.AlignPosition.ReactionForceEnabled=false 
		D.AlignPosition.Responsiveness=math.huge 
		D.AlignOrientation.Responsiveness=math.huge 
		D.AlignPosition.RigidityEnabled=false 
		D.AlignOrientation.MaxTorque=999999999 
		D.Massless=true
		D.RootPriority = 127
	end 
	local function j(D,E,F)
		Instance.new("Attachment",D)
		Instance.new("AlignPosition",D)
		Instance.new("Attachment",E)

		D.Attachment.Name=D.Name 
		E.Attachment.Name=D.Name 
		D.AlignPosition.Attachment0=D[D.Name]
		D.AlignPosition.Attachment1=E[D.Name]
		E[D.Name].Position=F or Vector3.new()
		D.AlignPosition.MaxForce=999999999 
		D.AlignPosition.MaxVelocity=math.huge 
		D.AlignPosition.ReactionForceEnabled=false 
		D.AlignPosition.Responsiveness=math.huge 
		D.Massless=true 
		D.RootPriority = 127
	end 
	for D,E in next,b:GetDescendants()do 
		if E:IsA('BasePart')then 
			d(c,x.RenderStepped:Connect(function()
				E.CanCollide=false 
			end))
		end 
	end 
	for D,E in next,b:GetDescendants()do 
		if E:IsA('BasePart')then 
			d(c,x.Stepped:Connect(function()
				E.CanCollide=false
			end))
		end 
	end 
	for D,E in next,y:GetDescendants()do 
		if E:IsA('BasePart')then 
			d(c,x.RenderStepped:Connect(function()
				E.CanCollide=false 
			end))
		end 
	end 
	for D,E in next,y:GetDescendants()do 
		if E:IsA('BasePart') then 
			d(c,x.Stepped:Connect(function()
				E.CanCollide=false 
			end))
		end 
	end 
	for D,E in next,b:GetDescendants()do 
		if E:IsA('Accessory')then 
			i(E.Handle,y[E.Name].Handle)
		end 
	end 

    i(b['Head'],y['Head'])
	i(b['Torso'],y['Torso'])
	j(b['HumanoidRootPart'],y['Torso'],Vector3.new(0,0,0))
	i(b['Right Arm'],y['Right Arm'])
	i(b['Left Arm'],y['Left Arm'])
	i(b['Right Leg'],y['Right Leg'])
	i(b['Left Leg'],y['Left Leg'])
	local k=a:GetMouse()

    local z=Instance.new("Part")
	z.CanCollide=false 
	z.Transparency=1
    z.Parent = g

    d(c,x.RenderStepped:Connect(function()
		local D=workspace.CurrentCamera.CFrame.lookVector 
		local E=y["HumanoidRootPart"]
		z.Position=E.Position 
		z.CFrame=CFrame.new(z.Position,Vector3.new(D.X*10000,D.Y,D.Z*10000))
	end))
	local l,m,n,o,p=false,false,false,false,false
	local function q(D)
		local r=Instance.new('BodyAngularVelocity')
		local b=Instance.new('AngularVelocity')
		r.AngularVelocity=Vector3.new(2147483646,2147483646,2147483646)
		r.P=math.huge
		r.MaxTorque = Vector3.new(1,1,1) * math.huge
		b.AngularVelocity = Vector3.new(2147483646,2147483646,2147483646)
		b.MaxTorque = 2147483646
		b.Attachment0 = D["RootAttachment"]
		b.Parent = D
        r.Parent = D
	end 
	q(b.HumanoidRootPart)
	k=a:GetMouse()
	
	local s=Instance.new('BodyPosition')
	s.P=9e9 
    s.D=9e9 
    s.MaxForce=Vector3.new(99999,99999,99999)
	s.Position = b.HumanoidRootPart.Position
    s.Parent = b.HumanoidRootPart
	
	local A 
	d(c,x.Heartbeat:Connect(function()
		if not b:FindFirstChild("HumanoidRootPart") then return end
		local hrp = b:FindFirstChild("HumanoidRootPart")
		if x:IsStudio() then 
			hrp.Anchored = true
		end
		if A==true then 
			s.Position=k.Hit.p 
            hrp.Position=k.Hit.p 
		else
	
			if Player.Attacking:GetState() then
				s.Position = PlayerController.AttackPosition
				hrp.Position = PlayerController.AttackPosition
			else
				s.Position=y.Torso.Position
				b.HumanoidRootPart.Position=y.HumanoidRootPart.Position
			end
			--b.HumanoidRootPart.CanCollide = not toggleFling
			if Player:GetFramerate() > 25 then
				hrp.BodyAngularVelocity.AngularVelocity = (toggleFling or Player.Attacking:GetState()) and Vector3.new(2147483646,2147483646,2147483646) or Vector3.new(5, 5, 5)
				hrp.AngularVelocity.Enabled = toggleFling
			else
				s.Position=y.Torso.Position
				hrp.Position=y.Torso.Position
				hrp.AngularVelocity.Enabled = false
				hrp.BodyAngularVelocity.AngularVelocity = Vector3.new(5, 5, 5)
			end
		end 
	end))

	local B=Instance.new("SelectionBox")
	B.Adornee=b.HumanoidRootPart 
    B.LineThickness=0.02 
    B.Color3=Color3.fromRGB(250,0,0)
    B.Parent=b.HumanoidRootPart 
    B.Name="RAINBOW"

	local t = B 
	if canClickFling then 
		d(c,k.Button1Down:Connect(function()
			A=true 
		end))
		d(c,k.Button1Up:Connect(function()
			A=false 
		end))
	end 

	workspace.CurrentCamera.CameraSubject=y.Humanoid 

	nexoConnections = c

end


local function initializeControls()
	local hrp = Player.getNexoHumanoidRootPart()
	
	local floatAttachment = hrp:FindFirstChild("Floater") or Instance.new("Attachment")
	if floatAttachment.Name ~= "Floater" then
		floatAttachment.Name = "Floater"
		floatAttachment.Parent = hrp
	end
	
	local float = hrp:FindFirstChild("Float") or Instance.new("AlignPosition")
	if float.Name ~= "Float" then
		float.Name = "Float"
		float.Mode = Enum.PositionAlignmentMode.OneAttachment
		float.Attachment0 = Player.getNexoCharacterRootAttachment()
		float.ApplyAtCenterOfMass = true
		float.Enabled = Player.Flying
		float.Parent = hrp
	end
	
	local alignRot = hrp:FindFirstChild("FaceForward") or Instance.new("AlignOrientation")
	if alignRot.Name ~= "FaceForward" then
		alignRot.Name = "FaceForward"
		alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignRot.Attachment0 = Player.getNexoCharacterRootAttachment()
		alignRot.PrimaryAxisOnly = false
		alignRot.RigidityEnabled = false
		alignRot.MaxTorque = 100000
		alignRot.AlignType = Enum.AlignType.Perpendicular
		alignRot.Enabled = false
		alignRot.Parent = hrp		
	end

	local buoyancyForce = hrp:FindFirstChild("Archimedes") or Instance.new("VectorForce")
	if buoyancyForce.Name ~= "Archimedes" then
		buoyancyForce.Name = "Archimedes"
		buoyancyForce.Force = Vector3.new(0,1,0) * Player.Mass * workspace.Gravity
		buoyancyForce.Attachment0 = Player.getNexoCharacterRootAttachment()
		buoyancyForce.ApplyAtCenterOfMass = true
		buoyancyForce.RelativeTo = Enum.ActuatorRelativeTo.World
		buoyancyForce.Parent = Player.getNexoHumanoidRootPart()
		PlayerController.Buoyancy = buoyancyForce	
	end
end

local function acceleration(v1, v2, dt)
	dt = dt or 0.01
	return (v2-v1).Magnitude/dt
end

--[[
	Some scripts are able to bypass the noclip anti-fling. This is a safeguard against these
	types
--]]
local function detectFling(threshold: number, dt)
	threshold = threshold or 1000

	local currentVelocity = Vector3.new()
	local currentAcceleration = 0

	local nhrp = Player.getNexoHumanoidRootPart()
	if nhrp then
		currentVelocity = nhrp.AssemblyLinearVelocity + nhrp.AssemblyLinearVelocity
		currentAcceleration = acceleration(previousVelocity, currentVelocity, dt)
		previousVelocity = currentVelocity
	end

	--print(currentAcceleration)

	if currentAcceleration > threshold and not (Player.Sprinting:GetState() or Player.Running:GetState() or Player.Landing or Player.Flipping) then
		print("Detected Fling")
		nhrp.CFrame = previousCFrame:ToWorldSpace(CFrame.new(0, 5, 0))
		nhrp.AssemblyLinearVelocity = Vector3.new()
		Player.SetCFrame = false
		task.delay(1, function() Player.SetCFrame = true end)
	end
end


local function addAnimationConnection(connection: Signal)
	table.insert(animationConnections, connection)
end

-- TODO: Use Maid or Trove to automate cleanup of animation connections at respawn
function PlayerController:_InitializeStates()	
	Player:GetStateClass("Idling").OnTrue:Connect(self.OnIdle)
	Player:GetStateClass("Falling").OnTrue:Connect(self.OnFall)
	Player:GetStateClass("Jumping").OnTrue:Connect(self.OnJump)
	Player:GetStateClass("Walking").OnTrue:Connect(self.OnWalk)

	Player.Crouching.OnTrue:Connect(self.OnCrouch)
	Player.Crouching.OnFalse:Connect(self.StoppedCrouch)

	Player:GetStateClass("Walking").OnFalse:Connect(self.StoppedState)

	Player:GetAnimation("Roll"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("Slide"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("FrontFlip"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("BackFlip"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("RightFlip"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("LeftFlip"):ConnectStop(self.OnStopAnimation)

	Player:GetAnimation("LandSoft"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("LandHard"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("SprintStop"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("RunStop"):ConnectStop(self.OnStopAnimation)
	Player:GetAnimation("WalkStop"):ConnectStop(self.OnStopAnimation)
	
	Player.FightMode.OnFalse:Connect(self.StoppedState)
	Player.Attacking.OnFalse:Connect(self.StoppedState)
	Player.Sprinting.OnFalse:Connect(self.StoppedState)
	Player.Running.OnFalse:Connect(self.StoppedState)

	Player.Climbing.OnTrue:Connect(self.OnClimb)
	Player.Climbing.OnFalse:Connect(self.StoppedState)

	Player:getNexoHumanoid():SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	Player:getHumanoid():SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	Player:getNexoHumanoid():SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	Player:getHumanoid():SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
end


function PlayerController:SetAnimation(animTable)
	self.Animation = animTable
end


function PlayerController:Sprint()
	local Settings = ControllerSettings:GetSettings()

	local runInfo = {1, Enum.EasingStyle.Linear, Enum.EasingDirection.In}
	local sprintInfo = {10, Enum.EasingStyle.Linear, Enum.EasingDirection.In}
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	if Player.Running:GetState() then
		FastTween(humA, runInfo, {WalkSpeed = Settings.runSpeed})
		FastTween(humB, runInfo, {WalkSpeed = Settings.runSpeed})
		humA.JumpPower = Settings.runJump
		humB.JumpPower = Settings.runJump
	elseif Player.Sprinting:GetState() then
		FastTween(humA, sprintInfo, {WalkSpeed = Settings.sprintSpeed})
		FastTween(humB, sprintInfo, {WalkSpeed = Settings.sprintSpeed})
		humA.JumpPower = Settings.sprintJump
		humB.JumpPower = Settings.sprintJump
	end

	if Player.Flying then
		tiltSpring.f = 2 * Player:GetAnimationSpeed()
		--print("SprintFlying")
		if Player.Dancing then return end
		Player.Transition(2)
	elseif Player.Swimming then
		tiltSpring.f = 10 * Player:GetAnimationSpeed()
		if Player.Dancing then return end
	else
		tiltSpring.f = 4 * Player:GetAnimationSpeed()

		if Player.Dancing then return end
		if Player.Running:GetState() then
			Player:GetAnimation("Run"):AdjustWeight(1, 1)
			Player:GetAnimation("Run"):Play()
			Player:GetAnimation("Run").Framerate = 30 / (humA.WalkSpeed/32)
		elseif Player.Sprinting:GetState() then
			Player:GetAnimation("Sprint"):AdjustWeight(1, 1)
			Player:GetAnimation("Sprint"):Play()
		end
		Player.Transition()
	end
end


function PlayerController:Walk()
	local Settings = ControllerSettings:GetSettings()
	local tweenInfo = {0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In}
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	humA.JumpPower = Settings.jumpPower
	humB.JumpPower = Settings.jumpPower
	FastTween(humA, tweenInfo, {WalkSpeed = Settings.walkSpeed})
	FastTween(humB, tweenInfo, {WalkSpeed = Settings.walkSpeed})

	if Player.Flying then
		tiltSpring.f = 1 * Player:GetAnimationSpeed()
		--print("WalkFly")
		if Player.Dancing then return end
		Player.Transition(1)
	elseif Player.Swimming then
		tiltSpring.f = 10 * Player:GetAnimationSpeed()
	else
		tiltSpring.f = 2 * Player:GetAnimationSpeed()
		--print("Walk")
		if Player.Dancing then return end
		Player.Transition()
	end
end


function PlayerController:Fall()
	local Settings = ControllerSettings:GetSettings()

	--print("Fall")
	if Player.Flying then
		tiltSpring.f = 1 * Player:GetAnimationSpeed()
		if Player.Dancing then return end
		Player.Transition(1)
	else
		tiltSpring.f = 3 * Player:GetAnimationSpeed()
		if Player.Dancing then return end
		Player.Transition()
	end
end


function PlayerController:Jump(char)
	local Settings = ControllerSettings:GetSettings()

	char = char or Player.getNexoCharacter()

	if Player:OnGround() then
		char.Humanoid.Jump = true
	elseif Player.Dodging and not Player:GetState("Jumping") then
		char.Humanoid:ChangeState(3)
		task.wait(Settings.DT)
		char.Humanoid:ChangeState(5)
	end

	if Player.Flying then
		--print("FlyingJump")
		tiltSpring.f = 1 * Player:GetAnimationSpeed()
		if Player.Dancing then return end
		Player.Transition(0.5)
	elseif Player.Swimming then
		--print("FlyingJump")
		tiltSpring.f = 1 * Player:GetAnimationSpeed()
		if Player.Dancing then return end
		Player.Transition(0.5)
	else
		--print("Jump")
		tiltSpring.f = 3 * Player:GetAnimationSpeed()
		if Player.Dancing then return end
		Player.Transition(0.5)
	end
end


function PlayerController:Idle()
	local Settings = ControllerSettings:GetSettings()
	local tweenInfo = {0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In}

	--tiltSpring.f = 8 * Player:GetAnimationSpeed()

	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	humA.JumpPower = Settings.jumpPower
	humB.JumpPower = Settings.jumpPower
	FastTween(humA, tweenInfo, {WalkSpeed = 0})
	FastTween(humB, tweenInfo, {WalkSpeed = 0})

	if Player.Landing then
		humA.WalkSpeed = 0
		humB.WalkSpeed = 0
	end

	if Player.Dancing then return end
	
	if Player.Flying then
		Player.Transition(2)
	elseif Player.Swimming then
		tiltSpring.f = 10 * Player:GetAnimationSpeed()
	else
		Player.Transition(1)
	end
end


function PlayerController:HoldTool(tool)
	local char = Player.getCharacter()
	local handle = tool:FindFirstChild("Handle")
	local rightGrip = CFrame.new(-Vector3.yAxis) * CFrame.fromOrientation(-90, 0, 0)
	if handle then
		handle.Velocity = Vector3.new(17.5, 17.5, 17.5)
		handle.CFrame = char["Right Arm"].CFrame * rightGrip * tool.Grip:Inverse()
	end
end


function PlayerController:Fly()
	local Settings = ControllerSettings:GetSettings()
	local Camera = workspace.CurrentCamera

	local humanoid = Player.getNexoHumanoid()
	local hrp = Player.getNexoHumanoidRootPart()
	local float = hrp:FindFirstChild("Float")
	local alignRot = hrp:FindFirstChild("FaceForward")
	
	float.Enabled = Player.Flying
	alignRot.Enabled = Player.Flying
	
	local walkSpeed = humanoid.WalkSpeed
	local moveDirection = humanoid.MoveDirection
	
	local ascent = (ActionHandler.IsKeyDown(Settings.ascendButton) - ActionHandler.IsKeyDown(Settings.crouchButton)) * Settings.ascentSpeed * Vector3.new(0,1,0)

	alignRot.CFrame = CFrame.fromMatrix(hrp.CFrame.Position, Camera.CFrame.XVector, Camera.CFrame.YVector)
	float.Position = hrp.Position + moveDirection * walkSpeed + ascent * humanoid.JumpPower / 50
end


function PlayerController:ToggleDebug()
	DEBUG = not DEBUG
end


function PlayerController:DodgeMove(direction)
	local hrp = Player.getNexoHumanoidRootPart()
	hrp.CFrame = hrp.CFrame + direction / Player:GetAnimationSpeed()
end


function PlayerController:Slide()
	if Player.DodgeMoving then
		self:DodgeMove(moveVector*0.1)
		return
	end

	local slide = Player:GetAnimation("Slide")
	local slideDelay = slide.Properties.DodgeTime or 1
	self.LayerA:LoadAnimation(slide)
	if not slide:IsPlaying() then
		slide:Play()
		Player.DodgeMoving = true
		task.delay(slideDelay, function() Player.DodgeMoving = false Player.Transition(2) end)
	end
end


function PlayerController:Invisible()
	if not Player.Invisible then 
		self.LayerA.Playing = true 
		self.LayerB.Playing = true 
		self.DanceLayer.Playing = true 
		return 
	end

	local nexoEquivalent
			
	for i,v in ipairs(Player.getCharacter():GetDescendants()) do
		if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
			v.CFrame = CFrame.new(0,1000,0)
		end
	end
end


function PlayerController:DodgeGround()
	if Player.Dancing or Player.Swimming then return end

	if Player.DodgeMoving then
		self:DodgeMove(moveVector * 0.3)
		return
	end

	local roll = Player:GetAnimation("Roll")
	local rollDelay = roll.Properties.DodgeTime or 1.35
	self.LayerA:LoadAnimation(roll)
	if not roll:IsPlaying() then
		roll:Play()
		Player.DodgeMoving = true
		task.delay(rollDelay, function() Player.DodgeMoving = false end)
	end
end


-- Flip Implementation: Use feFlip to rotate character latitudinally or longitudinally, then animate character twist motion
function PlayerController:DodgeAir(char)
	if Player.Dancing or Player.Swimming or Player.Flipping then return end
	local torso = char.HumanoidRootPart

	local flip

	local rightVector = torso.CFrame.RightVector
	local lookVector = torso.CFrame.lookVector
	local c0 = rightVector:Dot(moveVector) + EPSILON / 2
	local c1 = lookVector:Dot(moveVector) + EPSILON / 2

	if math.abs(c0) < EPSILON then
		if c1 >= 0 then
			flip = Player:GetAnimation("FrontFlip")
		else
			flip = Player:GetAnimation("BackFlip")
		end
	else
		if c0 >= 0 then
			flip = Player:GetAnimation("RightFlip")
		else
			flip = Player:GetAnimation("LeftFlip")
		end
	end

	--print(flip)
	currentFlipDelay = flip.Properties.DodgeTime or flip.TimeLength
	self.LayerA:LoadAnimation(flip)
	
	if not flip:IsPlaying() then
		flip:Play()
		Player.Flipping = true
		Player.DodgeMoving = true
		self.LayerA.XDirection = math.round(c1)
		self.LayerA.ZDirection = math.round(c0)
		self:Jump()
		torso:ApplyImpulse(Player:GetWeight()*(Vector3.new(0,0.5,0) + moveVector).Unit / 4)
		task.delay(currentFlipDelay, function() 
			Player.DodgeMoving = false
			Player.Flipping = false
		end)
	end

end


function PlayerController:LeanCharacter(char)

	local Settings = ControllerSettings:GetSettings()

	if char.Humanoid.MoveDirection.Magnitude > 0 and not Player.Dodging then
		moveVector = char.Humanoid.MoveDirection
	end

	local sprintConstant = Player.Sprinting:GetState() and 8 or 1 
	local runConstant = Player.Running:GetState() and 4 or 1
	local walkConstant = Player:GetState("Walking") and 0.25 or 1
	local jumpConstant = Player:GetState("Jumping") and 0.1 or 1
	local flyConstant = Player.Flying and 2 or 1

	tiltVector = Vector3.new(0,1,0) + char.Humanoid.MoveDirection * flyConstant * walkConstant * sprintConstant * jumpConstant * runConstant

	moveSpring.f = 2 * Player:GetAnimationSpeed()

	local tilt = tiltSpring:Update(Settings.DT, tiltVector)
	local move = moveSpring:Update(Settings.DT, moveVector)

	AnimationController.TiltVector = tilt
	AnimationController.MoveVector = move
	
end


function PlayerController:Climb()
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()
	Player:GetAnimation("Climb").Speed = humB.WalkSpeed / 16
end


function PlayerController:ProcessStates(char, nexoChar)

	local nexoHum = Player.getNexoHumanoid()
	local hum = Player.getHumanoid()
	local height = nexoChar.HumanoidRootPart.CFrame.Position.Y 
	local tool = char:FindFirstChildOfClass("Tool")

	local hrp = nexoChar:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local threshold = 5000

	if Player:GetState("Respawning") then
		self:Respawn()	
	end

	local fallenPercent = math.abs((height - workspace.FallenPartsDestroyHeight) / workspace.FallenPartsDestroyHeight)
	if fallenPercent < FALLEN_PARTS_THRESHOLD then
		hrp.CFrame = previousCFrame + Vector3.new(0, 5, 0)
		hrp.AssemblyLinearVelocity = Vector3.new()
	end

	if Player.Dancing then
		threshold *= 2
		if not self.Animation:IsPlaying() then
			self.Animation:Play()
		end
	end

	if 
		hum:GetState() == Enum.HumanoidStateType.Climbing 
		or nexoHum:GetState() == Enum.HumanoidStateType.Climbing 
	then
		self:Climb()
		Player.Climbing:SetState(true)
	else
		Player.Climbing:SetState(false)
	end

	if Player:GetState("Jumping") and not Player.Dodging then
		Player:GetStateClass("Jumping"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Jumping", true)
		threshold *= 4
		self:Jump(nexoChar)
	elseif not (Player:OnGround() or Player.Flying) then
		Player:GetStateClass("Falling"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Falling", true)
		fallingSpeed = hrp.AssemblyLinearVelocity.Y
		threshold *= 1.75
		self:Fall()
	elseif Player.Running:GetState() or Player.Sprinting:GetState() then
		Player.Running:SetPreviousState(Player:GetEnabledLocomotionState())
		Player.Sprinting:SetPreviousState(Player:GetEnabledLocomotionState())
		self:Sprint()
		threshold *= 10
	elseif char.Humanoid.MoveDirection.Magnitude > 0 and not (Player:GetState("Jumping") or Player:GetState("Falling"))  then
		Player:GetStateClass("Walking"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Walking", true)
		self:Walk()
		threshold *= 1.2
	else
		Player:GetStateClass("Idling"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Idling", true)
		--hrp.AssemblyLinearVelocity = Vector3.new()
		self:Idle()
	end

	if tool then
		Player:GetAnimation("ToolHold"):Play()
		self:HoldTool(tool)
	else
		Player:GetAnimation("ToolHold"):Stop()
	end

	if not (Player:GetState("Falling") or Player:GetState("Jumping") or Player.Flying or Player.Swimming) and Player.SetCFrame then
		--print("Setting CFrame")
		previousCFrame = hrp.CFrame
	end

	if Player.Dodging then
		if Player:GetState("Falling") or Player:GetState("Jumping") then
			nexoHum.PlatformStand = true
			self:DodgeAir(nexoChar)
		elseif Player.Running:GetState() or Player.Sprinting:GetState() then
			nexoHum.PlatformStand = false
			self:Slide()
		else
			nexoHum.PlatformStand = false
			self:DodgeGround()
		end
	else
		nexoHum.PlatformStand = false
	end

	if 
		hum:GetState() == Enum.HumanoidStateType.Swimming 
		or nexoHum:GetState() == Enum.HumanoidStateType.Swimming 
	then
		Player.Swimming = true
	else
		Player.Swimming = false
	end

	local ascent = ActionHandler.IsKeyDownBool(Enum.KeyCode.Space) and 1.5 or 1
	self.Buoyancy.Enabled = Player.Swimming
	self.Buoyancy.Force = Vector3.new(0,1,0) * Player:GetWeight() * ascent

	self.LayerA.looking = Player.Looking

	hum.AutoRotate = false
	nexoHum.AutoRotate = false
	nexoHum:Move(moveVector)

	if Player.Flying then
		threshold *= 12
	end

	if tick() >= massExecuteTime then
		Player:UpdateMass()
		massExecuteTime = tick() + 1 / massPollRate
	end
	if tick() >= moduleExecuteTime then
		self.LayerA:UpdateModule(Player:GetAnimationModule())
		moduleExecuteTime = tick() + 1 / updateModuleRate
	end
	detectFling(threshold)

	--print(Player.Landing)
	--print(Player.Slowing)
end


function PlayerController:ProcessInputs()
	local Settings = ControllerSettings:GetSettings()

	if not debounce then
		if ActionHandler.IsKeyDownBool(Enum.KeyCode.Equals) then
			toggleFling = not toggleFling
			debounce = true
			task.delay(0.2, function() debounce = false end)
		elseif ActionHandler.IsKeyDownBool(Enum.KeyCode.BackSlash) then
			self.LerpEnabled = not self.LerpEnabled
			debounce = true
			--print("LerpEnabled:", self.LerpEnabled)
			task.delay(0.2, function() debounce = false end)
		elseif ActionHandler.IsKeyDownBool(Settings.debugButton) then
			self:ToggleDebug()
			task.delay(0.2, function() debounce = false end)
		end
	end
end


function PlayerController:StopAllModules()
	for i, module in pairs(self.Modules) do
		module:Stop()
	end
end


function PlayerController:RunUpdateTable()
	for i, module in pairs(self.Modules) do
		module:Update()
	end
end


function PlayerController:ProcessAfterStates()
	self:Invisible()
end


function PlayerController:Update()

    local char = Player.getCharacter()
	local nexoChar = Player.getNexoCharacter()

	self:Fly()

	self:ProcessInputs()

	self:LeanCharacter(char)

	self:ProcessStates(char, nexoChar)

	ActionHandler:Update()
	self.LayerA:Animate()
	EmoteController:Update()
	self.DanceLayer:Animate()

	self.LayerB:Animate()

	if self.ResetTransform then
		self.RightArm:ResetTransform()
		self.LeftArm:ResetTransform()
	end

	--self.RightArm:Destroy()
	--self.LeftArm:Destroy()

--	self.ResetTransform = true

	if EmoteController.PointRight then
		self.RightArm:Solve(Mouse.Hit.Position, CFrame.Angles(0, 0, math.pi / 2))
	end
	if EmoteController.PointLeft then
		self.LeftArm:Solve(Mouse.Hit.Position, CFrame.Angles(0, 0, -math.pi / 2))
	end
--	self.RightArm:Solve(self.AttackPosition)
--	self.LeftArm:Solve(self.AttackPosition)


	self:RunUpdateTable()
	
	self:ProcessAfterStates()

	Network:Debug(DEBUG)
end    


function PlayerController:OnCrouch()
	local motionName = Player:GetEnabledLocomotionState():GetName()
	if motionName == "Idling" then
		Player:GetAnimation("Idle"):Stop()
		Player:GetAnimation("FightIdle"):Stop()
		Player:GetAnimation("CrouchIdle"):Play()
	elseif motionName == "Walking" or Player.Running:GetState() or Player.Sprinting:GetState() then 
		Player:GetAnimation("Run"):Pause()
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Sprint"):Pause()
		Player:GetAnimation("CrouchWalk"):Play()
	end
end


function PlayerController:StoppedCrouch()
	local motionName = Player:GetEnabledLocomotionState():GetName()
	Player:GetAnimation("CrouchIdle"):Stop()

	if motionName == "Idling" then
		Player:GetAnimation("Idle"):Play()
	elseif motionName == "Walking"  then 
		Player:GetAnimation("CrouchWalk"):Stop()
		Player:GetAnimation("Walk"):Play()
	elseif Player.Running:GetState() or Player.Sprinting:GetState() then
		if Player.Running:GetState() then 
			Player:GetAnimation("Run"):Play() 
		else 
			Player:GetAnimation("Sprint"):Play()
		end
	end
end


function PlayerController:OnClimb()
	Player:GetAnimation("Climb"):Play()
end


function PlayerController:OnIdle()
	--print("Idling")
	local nexoHRP = Player.getNexoHumanoidRootPart()
	--print(fallingSpeed)
	if Player.Dancing then return end
	if Player.Flying then
		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyIdle"):Play()
	else
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyIdle"):Stop()
		Player:GetAnimation("FlyFall"):Stop()
		Player:GetAnimation("FlyJump"):Stop()

		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Jump"):Stop()
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Walk").Weight = 0

		if Player.FightMode:GetState() then
			Player:GetAnimation("Idle"):Stop()
			Player:GetAnimation("FightIdle"):Play()
		else
			Player:GetAnimation("Idle"):Play()
			Player:GetAnimation("Idle"):AdjustWeight(1, 1)
			Player:GetAnimation("FightIdle"):Stop()
		end
		
		if Player:GetStateClass("Idling").PreviousState:GetName() == "Falling" then
			if math.abs(fallingSpeed) > 150 then
				Player:GetAnimation("LandHard").Framerate = 30
				Player.Landing = true
				Player:GetAnimation("LandHard"):Play()
				--print("Landed HARD")
			else
				Player.Landing = true
				Player:GetAnimation("LandSoft"):Play()
				--print("Landed")
			end
		end	
	end
end


function PlayerController:GetMoveVector()
	return moveVector
end


function PlayerController:SetMoveVector(vector: Vector3)
	moveVector = vector
end


function PlayerController:GetTiltVector()
	return tiltVector
end


function PlayerController.OnStopAnimation(animation: Animation)
	if animation.Name == "Roll" or animation.Name:find("Flip") or animation.Name == "Slide" then
		--print("Flipped")
		Player.Dodging = false
		Player.Flipping = false
	elseif animation.Name == "LandSoft" or animation.Name == "LandHard" then
		Player.Landing = false
	elseif animation.Name == "RunStop" or animation.Name == "SprintStop" or animation.Name == "WalkStop" then
		Player.Slowing = false
	end
end


local function delayStopAnim(anim: Animation)
	if Player:GetEnabledLocomotionState():GetName() == "Idling" then
		Player.Slowing = true
		anim:Play()
	end
end


function PlayerController.StoppedState(state)
	if state:GetName() == "Sprinting" then
		--print("Skidded HARD")
		Player:GetAnimation("Sprint"):Stop()
		Player:GetAnimation("Sprint").Weight = 0
		task.delay(0.05, delayStopAnim, Player:GetAnimation("SprintStop"))
	elseif state:GetName() == "Running" then
		--print("Skidded")
		Player:GetAnimation("Run"):Stop()
		Player:GetAnimation("Run").Weight = 0
		task.delay(0.05, delayStopAnim, Player:GetAnimation("RunStop"))
	elseif state:GetName() == "Walking" then
		--print("Skidded")
		Player:GetAnimation("Walk"):Stop()
		Player:GetAnimation("CrouchWalk"):Stop()
		if not Player.Crouching:GetState() then
			task.delay(0.01, delayStopAnim, Player:GetAnimation("WalkStop"))
		end
	elseif state:GetName() == "FightMode" then
		Player:GetAnimation("FightIdle"):Stop()
		Player:GetAnimation("Idle"):Play()
	elseif state:GetName() == "Attacking" then
		if Player.FightMode:GetState() then
			Player:GetAnimation("FightIdle"):Play()		
			Player:GetAnimation("Idle"):Stop()
		else
			Player:GetAnimation("FightIdle"):Stop()
			Player:GetAnimation("Idle"):Play()
		end
	elseif state:GetName() == "Climbing" then
		Player:GetAnimation("Climb"):Pause()
	end
end


function PlayerController:OnWalk()
	if Player.Flying then
		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyWalk"):Play()
	elseif Player.Crouching:GetState() then
		Player:GetAnimation("CrouchFall"):Pause()
		Player:GetAnimation("CrouchJump"):Stop()
		Player:GetAnimation("CrouchWalk"):Play()		
	else
		Player:GetAnimation("Walk"):AdjustWeight(1, 1)
		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Jump"):Stop()
		Player:GetAnimation("Walk"):Play()
	end
end


function PlayerController:OnJump()
	if Player.Flying then
		--print("FlyJump")
		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyJump"):Play()
	else
		--print("Jump")
		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Jump"):Play()
	end
end


function PlayerController:OnFall()
	if Player.Flying then
		--print("FlyFall")
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyFall"):Play()
	else
		--print("Fall")
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Fall"):Play()
	end
end


function PlayerController:Init(canClickFling)
	if self.Initialized then return end
	local Settings = ControllerSettings:GetSettings()

    canClickFling = canClickFling or false

	print("Loading Player")
	setPhysicsOptimizations()
	Player:HookFramerate()
	if Player.getHumanoid().RigType == Enum.HumanoidRigType.R15 then
		_R15ReanimLoad()
	else
		_NexoLoad(canClickFling)
		--R6Legs, LeftLeg, RightLeg = R6IKController.givePlayerIK()
		--AnimationController.R6Legs = R6Legs
	end


	PlayerController.RightArm = IKArmController.new(Player.getNexoCharacter(), "Right", "Arm")
	PlayerController.LeftArm = IKArmController.new(Player.getNexoCharacter(), "Left", "Arm")
	PlayerController.LeftLeg = IKLegController.new(Player.getNexoCharacter(), "Left", "Leg")
	PlayerController.RightLeg = IKLegController.new(Player.getNexoCharacter(), "Right", "Leg")

	coroutine.resume(Network["PartOwnership"]["Enable"])
	
	initializeControls()
	previousCFrame = Player.getNexoHumanoidRootPart().CFrame

    connection = Thread.DelayRepeat(Settings.DT, self.Update, self)
	ActionHandler:Init()
	EmoteController:Init()

	self:_InitializeStates()

	self.Initialized = true
end


function PlayerController:CleanConnections()

end


function PlayerController:Respawn()
    local char = game:GetService("Players").LocalPlayer.Character

	local oldCFrame = previousCFrame

	SendNotification("Respawning")

	if connection then
		connection:Disconnect()
	end

	for i, conn in pairs(nexoConnections)do 
		conn:Disconnect()
	end 

	table.clear(nexoConnections)
	Network:RemoveParts()
	coroutine.resume(Network["PartOwnership"]["Disable"])

	if char:FindFirstChildOfClass("Humanoid") then
		char:FindFirstChildOfClass("Humanoid"):ChangeState(15) 
	end

	ActionHandler:Stop()
	EmoteController:Stop()
	self.LayerA:Destroy()
	self.LayerB:Destroy()
	self.DanceLayer:Destroy()

	self:StopAllModules()
	
	char:ClearAllChildren()
	local newChar = Instance.new("Model")
	newChar.Parent = workspace
	game:GetService("Players").LocalPlayer.Character = newChar
	task.wait()
	game:GetService("Players").LocalPlayer.Character = char
	newChar:Destroy()	

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.CFrame = oldCFrame
	spawnLocation.Transparency = 0.5
	spawnLocation.Anchored = true
	spawnLocation.Parent = workspace
	Player.getPlayer().RespawnLocation = spawnLocation

	respawnConnection = Player.getPlayer().CharacterAdded:Connect(function()
		task.wait()
		local hrp = Player.getHumanoidRootPart()
		if hrp then
			hrp.CFrame = oldCFrame			
			Player.getCharacter():SetPrimaryPartCFrame(oldCFrame)
		end
		spawnLocation:Destroy()
		respawnConnection:Disconnect()
	end)

	task.wait(0.5)
	Player:SetState("Respawning", false)
	Player:CleanStates()
	Player:UnhookFramerate()

	if getgenv then
		getgenv().Running = false
	end
	self.Initialized = false
end    


return PlayerController