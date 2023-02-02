local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end
local RunService = game:GetService("RunService")

local Network = require(Project.Util.Network)
local SendNotification = require(Project.Util.SendNotification)

local Player = require(Project.Player)


-- https://v3rmillion.net/showthread.php?tid=1073859
-- Modified to borrow netless implementations from Nexo
return function(canClickFling, controller)
    local plr  = game:GetService("Players").LocalPlayer
	local char = plr.Character

	-- Grabbed from Nexo
	local c={}
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
		end))
		table.insert(connections, rs.Heartbeat:Connect(function()
			for i,v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
		end))
		table.insert(connections, rs.RenderStepped:Connect(function()
			for i,v in ipairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
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
					s.Position = controller.AttackPosition
					hrp.Position = controller.AttackPosition
				else
					s.Position=fakechar.UpperTorso.Position
					hrp.Position=fakechar.HumanoidRootPart.Position
				end
				if Player:GetFramerate() > 25 then
					hrp.BodyAngularVelocity.AngularVelocity = (controller.ToggleFling or Player.Attacking:GetState()) and Vector3.new(2147483646,2147483646,2147483646) or Vector3.new(5, 5, 5)
					hrp.AngularVelocity.Enabled = controller.ToggleFling
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

		controller:Respawn()
		return
	end

	SendNotification("R15 Reanimation", "Loaded")
	return c
end