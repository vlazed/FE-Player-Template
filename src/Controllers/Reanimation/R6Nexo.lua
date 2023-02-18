local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end
local RunService = game:GetService("RunService")

local Network = require(Project.Util.Network)

local Player = require(Project.Player)

return function(canClickFling, controller)
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
	task.wait(h)
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
	y.Humanoid.BreakJointsOnDeath = false
	y.Humanoid.DisplayDistanceType = "None"

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
			--Network:RetainPart(E)
			--Network:FollowPart(E) 
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
			--E.Handle:BreakJoints()
			if not x:IsStudio() then 
				sethiddenproperty(E,"BackendAccoutrementState",0) 
			end
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
		if D.Name == "HumanoidRootPart" then
			b.AngularVelocity = Vector3.new(2147483646,2147483646,2147483646)
			b.MaxTorque = 2147483646
			b.Attachment0 = D["RootAttachment"]
			b.Parent = D	
		else
			b.AngularVelocity = Vector3.new(2147483646,2147483646,2147483646)
			b.MaxTorque = 2147483646
			b.Attachment0 = D:FindFirstChildOfClass("Attachment")
			b.Parent = D
		end
        r.Parent = D
	end 
	q(b.HumanoidRootPart)
	q(b.Torso)
	q(b["Right Arm"])
	q(b["Left Arm"])
	q(b["Right Leg"])
	q(b["Left Leg"])
	k=a:GetMouse()
	
	local s=Instance.new('BodyPosition')
	s.P=9e9 
    s.D=9e9 
    s.MaxForce=Vector3.new(9e9, 9e9, 9e9)
	s.Position = b.HumanoidRootPart.Position
    s.Parent = b.HumanoidRootPart
	
	local A
	
	local function controlFling(angularVelocity)
		if not b:FindFirstChild("HumanoidRootPart") then return end

		local noVelocity = Vector3.new()

		local hrp = b:FindFirstChild("HumanoidRootPart")
		local rightarm = b:FindFirstChild("Right Arm")
		local leftarm = b:FindFirstChild("Left Arm")
		local torso = b:FindFirstChild("Torso")
		local leftleg = b:FindFirstChild("Left Leg")
		local rightleg = b:FindFirstChild("Right Leg")
		if x:IsStudio() then 
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
				s.Position=y.Torso.Position
				b.HumanoidRootPart.Position=y.HumanoidRootPart.Position
			end
			--b.HumanoidRootPart.CanCollide = not toggleFling
			if Player:GetFramerate() > 25 then
				if controller.ToggleFling or Player.Attacking:GetState() then
			
					hrp.BodyAngularVelocity.AngularVelocity = angularVelocity
					hrp.RotVelocity = angularVelocity
	
					torso.BodyAngularVelocity.AngularVelocity = controller.LimbFling and angularVelocity or noVelocity
					rightarm.BodyAngularVelocity.AngularVelocity = controller.LimbFling and angularVelocity or noVelocity
					leftarm.BodyAngularVelocity.AngularVelocity = controller.LimbFling and angularVelocity or noVelocity
					rightleg.BodyAngularVelocity.AngularVelocity = controller.LimbFling and angularVelocity or noVelocity
					leftleg.BodyAngularVelocity.AngularVelocity = controller.LimbFling and angularVelocity or noVelocity

					torso.RotVelocity = controller.LimbFling and angularVelocity or noVelocity
					rightarm.RotVelocity = controller.LimbFling and angularVelocity or noVelocity
					leftarm.RotVelocity = controller.LimbFling and angularVelocity or noVelocity
					rightleg.RotVelocity = controller.LimbFling and angularVelocity or noVelocity
					leftleg.RotVelocity = controller.LimbFling and angularVelocity or noVelocity


				else
					
					hrp.BodyAngularVelocity.AngularVelocity = Vector3.new(5, 5, 5)
					hrp.RotVelocity = Vector3.new(5, 5, 5)

					torso.BodyAngularVelocity.AngularVelocity = noVelocity
					rightarm.BodyAngularVelocity.AngularVelocity = noVelocity
					leftarm.BodyAngularVelocity.AngularVelocity = noVelocity
					leftleg.BodyAngularVelocity.AngularVelocity = noVelocity
					rightleg.BodyAngularVelocity.AngularVelocity = noVelocity

					torso.RotVelocity = noVelocity
					rightarm.RotVelocity = noVelocity
					leftarm.RotVelocity = noVelocity
					rightleg.RotVelocity =  noVelocity
					leftleg.RotVelocity = noVelocity

				end
				hrp.AngularVelocity.Enabled = controller.ToggleFling
			else
				s.Position=y.Torso.Position
				hrp.Position=y.Torso.Position
				hrp.AngularVelocity.Enabled = true
				hrp.BodyAngularVelocity.AngularVelocity = Vector3.new(5, 5, 5)
			end
		end 
	end

	d(c,x.Stepped:Connect(function() controlFling(Vector3.new(100, 100, 100)) end))
	d(c,x.RenderStepped:Connect(function() controlFling(Vector3.new(100, 100, 100)) end))
	d(c,x.Heartbeat:Connect(function() controlFling(Vector3.new(2000000000000000000, 2000000000000000000, 2000000000000000000)) end))
	
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

	return c
end