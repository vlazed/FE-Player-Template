local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local ActionHandler = require(Project.Controllers.ActionHandler)
local AnimationController = require(Project.Controllers.AnimationController)
local ControllerSettings = require(Project.Controllers.ControllerSettings)
local EmoteController = require(Project.Controllers.EmoteController)

-- TODO: Determine CFrame-based implementation for R6 IK Foot Placement 
--local R6IKController = require(Project.Controllers.R6IKController)

local Player = require(Project.Player)

local SendNotification = require(Project.Util.SendNotification)
local FastTween = require(Project.Util.FastTween)
local Thread = require(Project.Util.Thread)
local Signal = require(Project.Packages.Signal)
local Spring = require(Project.Util.Spring)
local EmoteController = require(Project.Controllers.EmoteController)

local RunService = game:GetService("RunService")

local PlayerController = {}

local FALLEN_PARTS_THRESHOLD = 0.25

local respawnConnection

local moveVector = Vector3.new(1, 0, 0)
local tiltVector = Vector3.new(0, 1, 0)
local tiltSpring = Spring.new(2, tiltVector)
local moveSpring = Spring.new(2, moveVector)

local toggleFling = false
local debounce = false

local fallingSpeed = 0

local previousCFrame = CFrame.new()

PlayerController.Animation = {}
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

-- https://raw.githubusercontent.com/CenteredSniper/Kenzen/master/ZendeyReanimate.lua
local function setPhysicsOptimizations()
	if RunService:IsStudio() then return end

	settings()["Physics"].PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
	settings()["Physics"].AllowSleep = false
	settings()["Physics"].ForceCSGv2 = false
	settings()["Physics"].DisableCSGv2 = true
	settings()["Physics"].UseCSGv2 = false
	settings()["Physics"].ThrottleAdjustTime = math.huge

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
	local d=table.insert 
    for D,E in next,char:GetDescendants()do 
		if E:IsA("BasePart")then 
			d(c,game:GetService("RunService").Heartbeat:connect(function()
				pcall(function()
					E.Velocity=Vector3.new(-30,0,0)
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
		end))
		table.insert(connections, rs.Heartbeat:Connect(function()
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
		end))
		table.insert(connections, rs.RenderStepped:Connect(function()
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
			r.AngularVelocity=Vector3.new(9e9,9e9,9e9)
			r.MaxTorque=Vector3.new(9e9,9e9,9e9)
			b.AngularVelocity = Vector3.new(9e9,9e9,9e9)
			b.MaxTorque = 9e9
			b.Attachment0 = D["RootAttachment"]
			b.Parent = D
			r.Parent = D
		end 
		q(char.HumanoidRootPart)
		k=plr:GetMouse()
		local s=Instance.new('BodyPosition')
		s.P=9e9 
		s.D=9e9 
		s.MaxForce=Vector3.new(99999,99999,99999)
		s.Parent = char.HumanoidRootPart

		local A 
		d(c,rs.Heartbeat:Connect(function()
			if A==true then  
				char.HumanoidRootPart.Position=k.Hit.p 
			else 
				char.HumanoidRootPart.Position=fakechar.LowerTorso.Position 
			end 
		end))

		local B=Instance.new("SelectionBox")
		B.Adornee=char.HumanoidRootPart 
		B.LineThickness=0.02 
		B.Color3=Color3.fromRGB(250,0,0)
		B.Parent=char.HumanoidRootPart 
		B.Name="RAINBOW"
	
		local t = B 
		
		d(c,k.KeyDown:Connect(function(D)
			if D==' 'then
				p=true 
			end 
			if D=='w'then 
				l=true 
			end 
			if D=='s'then 
				m=true 
			end 
			if D=='a'then 
				n=true 
			end 
			if D=='d'then 
				o=true 
			end 
		end))
	
		d(c,k.KeyUp:Connect(function(D)
			if D==' 'then 
				p=false 
			end 
			if D=='w'then 
				l=false 
			end 
			if D=='s'then 
				m=false 
			end 
			if D=='a'then 
				n=false 
			end 
			if D=='d'then 
				o=false 
			end 
		end))
	
		local function C(D,E,F)
			z.CFrame=z.CFrame*CFrame.new(-D,E,-F)
			fakechar.Humanoid.WalkToPoint=z.Position 
		end 
	
		d(c,rs.RenderStepped:Connect(function()
			if l==true then 
				C(0,0,1e4)
			end 
			if m==true then 
				C(0,0,-1e4)
			end 
			if n==true then 
				C(1e4,0,0)
			end 
			if o==true then 
				C(-1e4,0,0)
			end 
			if p==true then 
				fakechar.Humanoid.Jump=true 
			end 
			if l~=true and n~=true and m~=true and o~=true then 
				fakechar.Humanoid.WalkToPoint=fakechar.HumanoidRootPart.Position 
			end 
		end))

		nexoConnections = c
	end)

	if fail then
		warn(fail)
		plr.Character = char
		char:BreakJoints()
		fakechar:Destroy()

		kill = true
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
			--E.Massless = true
			d(c,game:GetService("RunService").Heartbeat:connect(function()
				pcall(function()
					E.Velocity=Vector3.new(-30,0,0)
					if RunService:IsClient() then
						sethiddenproperty(game.Players.LocalPlayer,"MaximumSimulationRadius",math.huge)
						sethiddenproperty(game.Players.LocalPlayer,"SimulationRadius",999999999)
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
		r.AngularVelocity=Vector3.new(9e9,9e9,9e9)
		r.MaxTorque=Vector3.new(9e9,9e9,9e9)
        r.Parent = D
	end 
	q(b.HumanoidRootPart)
	k=a:GetMouse()
	local s=Instance.new('BodyPosition')
	s.P=9e9 
    s.D=9e9 
    s.MaxForce=Vector3.new(99999,99999,99999)
    s.Parent = b.HumanoidRootPart

	local A 
	d(c,x.Heartbeat:Connect(function()
		if x:IsStudio() then 
			b.HumanoidRootPart.Anchored = true
		end
		if A==true then 
			b.HumanoidRootPart.CanCollide = toggleFling
			s.Position=k.Hit.p 
            b.HumanoidRootPart.Position=k.Hit.p 
		else 
			s.Position=y.Torso.Position 
		end 
		b.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
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

	d(c,k.KeyDown:Connect(function(D)
		if D==' 'then
			p=true 
		end 
		if D=='w'then 
			l=true 
		end 
		if D=='s'then 
			m=true 
		end 
		if D=='a'then 
			n=true 
		end 
		if D=='d'then 
			o=true 
		end 
	end))

	d(c,k.KeyUp:Connect(function(D)
		if D==' 'then 
			p=false 
        end 
		if D=='w'then 
			l=false 
		end 
		if D=='s'then 
			m=false 
		end 
		if D=='a'then 
			n=false 
		end 
		if D=='d'then 
			o=false 
		end 
	end))

	local function C(D,E,F)
		z.CFrame=z.CFrame*CFrame.new(-D,E,-F)
		y.Humanoid.WalkToPoint=z.Position 
	end 

	d(c,x.RenderStepped:Connect(function()
		if l==true then 
			C(0,0,1e4)
		end 
		if m==true then 
			C(0,0,-1e4)
        end 
		if n==true then 
			C(1e4,0,0)
		end 
		if o==true then 
			C(-1e4,0,0)
		end 
		if p==true then 
			y.Humanoid.Jump=true 
		end 
		if l~=true and n~=true and m~=true and o~=true then 
			y.Humanoid.WalkToPoint=y.HumanoidRootPart.Position 
		end 
	end))

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


function PlayerController:_InitializeStates()	
	Player:GetStateClass("Idling").OnTrue:Connect(self.OnIdle)
	Player:GetStateClass("Falling").OnTrue:Connect(self.OnFall)
	Player:GetStateClass("Jumping").OnTrue:Connect(self.OnJump)
	Player:GetStateClass("Walking").OnTrue:Connect(self.OnWalk)

	Player:GetAnimation("Roll").Stopped:Connect(self.OnStopAnimation)

	Player.Sprinting.OnFalse:Connect(self.StoppedState)
	Player.Running.OnFalse:Connect(self.StoppedState)
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
			Player:GetAnimation("Run"):Play()
			Player:GetAnimation("Run").Framerate = 30 / (humA.WalkSpeed/32)
		elseif Player.Sprinting:GetState() then
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


function PlayerController:Jump()
	local Settings = ControllerSettings:GetSettings()

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

	tiltSpring.f = 8 * Player:GetAnimationSpeed()

	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	humA.JumpPower = Settings.jumpPower
	humB.JumpPower = Settings.jumpPower
	FastTween(humA, tweenInfo, {WalkSpeed = 0})
	FastTween(humB, tweenInfo, {WalkSpeed = 0})

	if Player.Dancing then return end
	
	if Player.Flying then
		Player.Transition(2)
	elseif Player.Swimming then
		tiltSpring.f = 10 * Player:GetAnimationSpeed()
		if Player.Dancing then return end
	elseif Player.FightMode then
		Player.Transition(2)
	else
		Player.Transition(1)
	end
end


function PlayerController:Fly()
	local Settings = ControllerSettings:GetSettings()
	local Camera = workspace.CurrentCamera

	local humanoid = Player.getHumanoid()
	local hrp = Player.getNexoHumanoidRootPart()
	local float = hrp:FindFirstChild("Float")
	local alignRot = hrp:FindFirstChild("FaceForward")
	
	float.Enabled = Player.Flying
	alignRot.Enabled = Player.Flying
	
	local walkSpeed = humanoid.WalkSpeed
	local moveDirection = humanoid.MoveDirection
	
	local ascent = (ActionHandler.IsKeyDown(Settings.ascendButton) - ActionHandler.IsKeyDown(Settings.crouchButton)) * Settings.ascentSpeed * Vector3.new(0,1,0)

	alignRot.CFrame = CFrame.fromMatrix(hrp.CFrame.Position, Camera.CFrame.XVector, Camera.CFrame.YVector)
	float.Position = hrp.Position + moveDirection * walkSpeed + ascent * walkSpeed/16
end


function PlayerController:DodgeGround()
	if Player.Dancing or Player.Swimming then return end
	Player.getNexoHumanoidRootPart().CFrame = Player.getNexoHumanoidRootPart().CFrame + moveVector * 0.3 / Player:GetAnimationSpeed()
	self.LayerA:LoadAnimation(Player:GetAnimation("Roll"))
	if not Player:GetAnimation("Roll"):IsPlaying() then
		Player:GetAnimation("Roll"):Play()
	end
end


-- Flip Implementation: Use feFlip to rotate character latitudinally or longitudinally, then animate character twist motion
function PlayerController:DodgeAir()
	if Player.Dancing or Player.Swimming then return end
	--print("Dodging in Air")
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


function PlayerController:ProcessStates(char, nexoChar)

	local nexoHum = Player.getNexoHumanoid()
	local hum = Player.getHumanoid()
	local height = nexoChar.HumanoidRootPart.CFrame.Position.Y 

	if Player:GetState("Respawning") then
		self:Respawn()	
	end

	local fallenPercent = math.abs((height - workspace.FallenPartsDestroyHeight) / workspace.FallenPartsDestroyHeight)
	if fallenPercent < FALLEN_PARTS_THRESHOLD then
		nexoChar.HumanoidRootPart.CFrame = previousCFrame + Vector3.new(0, 5, 0)
		nexoChar.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new()
	end

	if Player.Dancing and not self.Animation:IsPlaying() then
		self.DanceLayer:LoadAnimation(self.Animation)
		self.Animation:Play()
	end

	if Player:GetState("Jumping") then
		Player:GetStateClass("Jumping"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Jumping", true)
		nexoChar.Humanoid.Jump = true
		char.Humanoid.Jump = true
		self:Jump()
	elseif not (Player:OnGround() or Player.Flying) then
		Player:GetStateClass("Falling"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Falling", true)
		fallingSpeed = nexoChar.HumanoidRootPart.AssemblyLinearVelocity.Y
		self:Fall()
	elseif Player.Running:GetState() or Player.Sprinting:GetState() then
		Player.Running:SetPreviousState(Player:GetEnabledLocomotionState())
		Player.Sprinting:SetPreviousState(Player:GetEnabledLocomotionState())
		self:Sprint()
	elseif char.Humanoid.MoveDirection.Magnitude > 0 and not Player:GetState("Jumping") then
		Player:GetStateClass("Walking"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Walking", true)
		self:Walk()
	else
		Player:GetStateClass("Idling"):SetPreviousState(Player:GetEnabledLocomotionState())
		Player:SetState("Idling", true)
		self:Idle()
	end

	if not (Player:GetState("Falling") or Player:GetState("Jumping") or Player.Flying or Player.Swimming) then
		--print("Setting CFrame")
		previousCFrame = nexoChar.HumanoidRootPart.CFrame
	end

	if Player.Dodging then
		if Player:GetState("Falling") or Player:GetState("Jumping") then
			self:DodgeAir()
		else
			self:DodgeGround()
		end
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

	if tick() >= massExecuteTime then
		Player:UpdateMass()
		massExecuteTime = tick() + 1 / massPollRate
	end
end


function PlayerController:ProcessInputs()
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
		end
	end
end


function PlayerController:RunUpdateTable()
	for i, module in pairs(self.Modules) do
		module:Update()
	end
end


function PlayerController:Update()

    local char = Player.getCharacter()
	local nexoChar = Player.getNexoCharacter()

	if char:FindFirstChild("HumanoidRootPart") then
		if char.Humanoid.RigType == Enum.HumanoidRigType.R6 then
			char.HumanoidRootPart.Position=nexoChar.Torso.Position + (not toggleFling and 1 or 0)*Vector3.new(0,50,0)
		else
			char.HumanoidRootPart.Position=nexoChar.LowerTorso.Position + (not toggleFling and 1 or 0)*Vector3.new(0,50,0)
		end
		char.HumanoidRootPart.Anchored = not toggleFling
		char.HumanoidRootPart.CanCollide = toggleFling
	end

	self:Fly()

	self:ProcessInputs()

	self:LeanCharacter(char)

	self:ProcessStates(char, nexoChar)

	self:RunUpdateTable()
	
	ActionHandler:Update()
	self.LayerA:Animate()
	EmoteController:Update()
	
end    


function PlayerController:OnIdle()
	print("Idling")
	local nexoHRP = Player.getNexoHumanoidRootPart()
	print(fallingSpeed)
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
		Player:GetAnimation("Idle"):Play()
		if Player:GetStateClass("Idling").PreviousState:GetName() == "Falling" then
			if math.abs(fallingSpeed) > 150 then
				Player:GetAnimation("LandHard").Framerate = 30
				Player.Landing = true
				Player:GetAnimation("LandHard"):Play()
				print("Landed HARD")
			else
				Player.Landing = true
				Player:GetAnimation("LandSoft"):Play()
				print("Landed")
			end
		end	
	end
end


function PlayerController.OnStopAnimation(animation: Animation)
	if Player.Dodging or animation.Name == "Roll" then
		Player.Dodging = false
	elseif animation.Name == "LandSoft" or animation.Name == "LandHard" then
		Player.Landing = false
	end
end


local function delayStopAnim(anim: Animation)
	if Player:GetEnabledLocomotionState():GetName() == "Idling" then
		anim:Play()
	end
end


function PlayerController.StoppedState(state)
	if state:GetName() == "Sprinting" then
		print("Skidded HARD")
		Player:GetAnimation("Sprint"):Stop()
		task.delay(0.05, delayStopAnim, Player:GetAnimation("SprintStop"))
	elseif state:GetName() == "Running" then
		print("Skidded")
		Player:GetAnimation("Run"):Stop()
		task.delay(0.05, delayStopAnim, Player:GetAnimation("RunStop"))
	end
end


function PlayerController:OnWalk()
	if Player.Flying then
		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyWalk"):Play()			
	else
		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Jump"):Stop()
		Player:GetAnimation("Walk"):Play()	
	end
end


function PlayerController:OnJump()
	if Player.Flying then
		print("FlyJump")
		Player:GetAnimation("FlyFall"):Pause()
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyJump"):Play()
	else
		print("Jump")
		Player:GetAnimation("Fall"):Pause()
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Jump"):Play()
	end
end


function PlayerController:OnFall()
	if Player.Flying then
		print("FlyFall")
		Player:GetAnimation("FlyWalk"):Pause()
		Player:GetAnimation("FlyJump"):Stop()
		Player:GetAnimation("FlyFall"):Play()
	else
		print("Fall")
		Player:GetAnimation("Walk"):Pause()
		Player:GetAnimation("Jump"):Stop()
		Player:GetAnimation("Fall"):Play()
	end
end


function PlayerController:Init(canClickFling)
	if self.Initialized then return end
	local Settings = ControllerSettings:GetSettings()

    canClickFling = canClickFling or false

	print("Loading Player")
	setPhysicsOptimizations()
	if Player.getHumanoid().RigType == Enum.HumanoidRigType.R15 then
		_R15ReanimLoad()
	else
		_NexoLoad(canClickFling)
		--R6Legs, LeftLeg, RightLeg = R6IKController.givePlayerIK()
		--AnimationController.R6Legs = R6Legs
	end

	initializeControls()
	previousCFrame = Player.getNexoHumanoidRootPart().CFrame

    connection = Thread.DelayRepeat(Settings.DT, self.Update, self)
	ActionHandler:Init()
	EmoteController:Init()

	self:_InitializeStates()

	self.Initialized = true
end

function PlayerController:Respawn()
    local char = game:GetService("Players").LocalPlayer.Character

	local oldCFrame = Player.getCharacter().Torso.CFrame

	SendNotification("Respawning")

	connection:Disconnect()

	for i, conn in pairs(nexoConnections)do 
		conn:Disconnect()
	end 

	table.clear(nexoConnections)

	if char:FindFirstChildOfClass("Humanoid") then
		char:FindFirstChildOfClass("Humanoid"):ChangeState(15) 
	end

	table.clear(self.Modules)
	
	char:ClearAllChildren()
	local newChar = Instance.new("Model")
	newChar.Parent = workspace
	game:GetService("Players").LocalPlayer.Character = newChar
	task.wait()
	game:GetService("Players").LocalPlayer.Character = char
	newChar:Destroy()	

	ActionHandler:Stop()
	EmoteController:Stop()
	self.LayerA:Destroy()
	self.LayerB:Destroy()
	self.DanceLayer:Destroy()

	if getgenv then
		getgenv().Running = false
	end

	respawnConnection = Player.getPlayer().CharacterAdded:Connect(function()
		task.wait()
		Player.getCharacter().HumanoidRootPart.CFrame = oldCFrame
		respawnConnection:Disconnect()
	end)

	task.wait(0.5)
	Player:SetState("Respawning", false)
	Player:CleanStates()
	self.Initialized = false
end    


return PlayerController