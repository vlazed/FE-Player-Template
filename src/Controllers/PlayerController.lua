local Project = script:FindFirstAncestor("FE-Player-Template")

local ActionHandler = require(Project.Controllers.ActionHandler)
local AnimationController = require(Project.Controllers.AnimationController)
local ControllerSettings = require(Project.Controllers.ControllerSettings)
local PlayerAnimations = require(script.Parent.PlayerAnimations)

local Player = require(Project.Player)

local SendNotification = require(Project.Util.SendNotification)
local FastTween = require(Project.Util.FastTween)
local Thread = require(Project.Util.Thread)
local Signal = require(Project.Packages.Signal)

local RunService = game:GetService("RunService")

local PlayerController = {}

PlayerController.Dancing = false
PlayerController.AnimationTable = {}

local connection

PlayerController.StoppedIdling = Signal.new()
PlayerController.StoppedWalking = Signal.new()
PlayerController.StoppedFalling = Signal.new()
PlayerController.StoppedRunning = Signal.new()
PlayerController.StoppedJumping = Signal.new()


-- Nexo Loader that I got from a FE Bike script
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
		if E:IsA('BasePart')then 
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
		if A==true then 
			s.Position=k.Hit.p 
            b.HumanoidRootPart.Position=k.Hit.p 
		else 
			s.Position=y.Torso.Position 
            b.HumanoidRootPart.Position=y.Torso.Position 
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

	local u=Instance.new('BindableEvent')
	d(c,u.Event:Connect(function()
		y:Destroy()
		e=true 
		local v=false 
		for D,E in next,b:GetDescendants()do 
			if E:IsA('BasePart')then 
				E.Anchored=true 
			end 
		end 
		local w=b.Humanoid:Clone()
		b.Humanoid:Destroy()
		w.Parent=b 
		game.Players:Chat('-re')
		for D,E in pairs(c)do 
			E:Disconnect()
		end 
		game:GetService("StarterGui"):SetCore("ResetButtonCallback",true)
		u:Remove()
	end))

	game:GetService("StarterGui"):SetCore("ResetButtonCallback",u)
end    


function PlayerController:SetAnimation(animTable)
	PlayerController.Animation = animTable
end


function PlayerController:Sprint()
	local Settings = ControllerSettings:GetSettings()
	print("Sprinting")
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	local tweenInfo = {0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In}

	FastTween(humA, tweenInfo, {WalkSpeed = Settings.sprintSpeed})
	FastTween(humB, tweenInfo, {WalkSpeed = Settings.sprintSpeed})

	humA.JumpPower = Settings.sprintJump
	humB.JumpPower = Settings.sprintJump
	AnimationController.Animate(PlayerAnimations.sprintTable.Keyframes, true)
end


function PlayerController:Walk()
	local Settings = ControllerSettings:GetSettings()
	print("Walk")
	local tweenInfo = {0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In}
	local humA, humB = Player.getHumanoid(), Player.getNexoHumanoid()

	humA.JumpPower = Settings.jumpPower
	humB.JumpPower = Settings.jumpPower
	FastTween(humA, tweenInfo, {WalkSpeed = Settings.walkSpeed})
	FastTween(humB, tweenInfo, {WalkSpeed = Settings.walkSpeed})
	AnimationController.Animate(PlayerAnimations.moveTable.Keyframes, true)
end


function PlayerController:Fall()
	print("Fall")
	AnimationController.Animate(PlayerAnimations.fallTable.Keyframes, false)
end


function PlayerController:Jump()
	print("Jump")
	AnimationController.Animate(PlayerAnimations.jumpTable.Keyframes, true)
end


function PlayerController:Idle()
	print("Idle")
	AnimationController.Animate(PlayerAnimations.idleTable.Keyframes, true)
end


function PlayerController:Update()
    local char = Player.getCharacter()
	local nexoChar = Player.getNexoCharacter()

	print(Player.GetStateTable())

	if char.Humanoid.Jump then
		Player.SetState("Jumping", true)
		PlayerController:Jump()
	elseif nexoChar.HumanoidRootPart.AssemblyLinearVelocity.Y < -10 then
		Player.SetState("Falling", true)
		PlayerController:Fall()
	elseif Player.GetState("Sprinting") then
		PlayerController:Sprint()
	elseif char.Humanoid.MoveDirection.Magnitude > 0 then
		Player.SetState("Walking", true)
		PlayerController:Walk()
	else
		Player.SetState("Idling", true)
		PlayerController:Idle()
	end

	if Player.GetState("Respawning") then
		PlayerController:Respawn()
		return
	end

	ActionHandler:Update()
end    


function PlayerController:Init(canClickFling)
	local Settings = ControllerSettings:GetSettings()

    canClickFling = canClickFling or false

	print("Loading Player")
    _NexoLoad(canClickFling)

    connection = Thread.DelayRepeat(Settings.DT, self.Update)
	ActionHandler:Init()
end

function PlayerController:Respawn()
    local char = game:GetService("Players").LocalPlayer.Character

	SendNotification("Respawning")

	connection:Disconnect()
	if char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid"):ChangeState(15) 
    end

	char:ClearAllChildren()
	local newChar = Instance.new("Model")
	newChar.Parent = workspace
	game:GetService("Players").LocalPlayer.Character = newChar
	task.wait()
	game:GetService("Players").LocalPlayer.Character = char
	newChar:Destroy()

	ActionHandler:Stop()

	task.wait(0.2)
	Player.SetState("Respawning", false)
end    


return PlayerController