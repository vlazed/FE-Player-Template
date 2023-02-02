--[[
    Vlazed

    This is an example custom locomotion module, which modifies the PlayerController's locomotion scalars
    to provide controllable biking speed via the W and S keys. This also changes the tilt and move vectors
    of the character on the bicycle.
--]]

local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Player = require(Project.Player)
local PlayerController = require(Project.Controllers.PlayerController)
local ActionHandler = require(Project.Controllers.ActionHandler)
local SendNotification = require(Project.Util.SendNotification)
local Animation = require(Project.Controllers.Animations.Animation)

local Bike = {}
Bike.Name = "Bike"
Bike.Type = "Movement"

--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow loses the accessory.
--]]
local Vehicle = "Back Bike"

local Animations = script.Parent.Animations

local onBike = false
local isMounting = false
local isDismounting = false

local BikeButton = Enum.KeyCode.R
local TrickButton = Enum.KeyCode.G

Bike.Initialized = false

--[[
    An example of an animation table with fields to access those animations. All animation tables
    must have the fields listed below. Access the wiki for a list of animation fields
--]]
Bike.Animations = {Emotes = {}}
Bike.Tricks = {}
Bike.Settings = {
    IdleSpeed = 0,
    WalkSpeed = 20,
    RunSpeed = 40,
    SprintSpeed = 500,
    JumpPower = 100,
    RunJumpPower = 120,
    SprintJumpPower = 150,
    
    IdleTweenTime = 1,
    WalkTweenTime = 0.5,
    RunTweenTime = 2,
    SprintTweenTime = 2,
    
    IdleTiltRate = 1,
	FallTiltRate = 3,
	JumpTiltRate = 3,
	WalkTiltRate = 0.5,
	RunTiltRate = 6,
    SprintTiltRate = 64,

    WalkTiltMagnitude = 0.6,
    RunTiltMagnitude = 0.6,
    SprintTiltMagnitude = 8,
    JumpTiltMagnitude = 0.1,
}

local function populateEmoteTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name:lower()] = Animation.new(v.Name, animation, animation.Properties.Framerate, false)
        end    
    end
end

local function populateAnimationTable(inputTable: table, targetTable: table)
    for _,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name] = Animation.new(v.Name, animation, animation.Properties.Framerate, true, false)                
        end
    end
end

local function populateTrickTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            table.insert(targetTable, Animation.new(v.Name, animation, animation.Properties.Framerate, false, true))
            table.sort(targetTable, function(k2, k1) return k1.Name > k2.Name end)             
        end
    end
end


populateAnimationTable(Animations:GetChildren(), Bike.Animations)
populateTrickTable(Animations.Tricks:GetChildren(), Bike.Tricks)
populateEmoteTable(Animations.Emotes:GetChildren(), Bike.Animations.Emotes)


Bike.TrickIndex = 1


function Bike:_InitializeAnimations()
    --PlayerController.LayerA:LoadAnimation(MountBike)
    --PlayerController.LayerA:LoadAnimation(DismountBike)
    
    self.Animations["Roll"]:ConnectStop(self.OnStopAnimation)

    self.Animations["LandSoft"]:ConnectStop(self.OnStopAnimation)
    self.Animations["LandHard"]:ConnectStop(self.OnStopAnimation)
    
end


--[[
    Some weird looping behavior occurs if you have animation overrides that run with a keybind.
    Best to have an OnStopAnimation callback to ensure that bugs don't occur.
--]]
function Bike.OnStopAnimation(animation: Animation)
    if animation.Name == "MountBike" then
        isMounting = false
    elseif animation.Name == "DismountBike" then
        isDismounting = false
    elseif animation.Name == "Roll" then
        Player.Dodging = false
    elseif animation.Name:find("Land") then
        Player.Landing = false
    elseif animation.Name:find("Stop") then
        Player.Slowing = false
    end
end


--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function Bike:ProcessInputs(char, Accessory)
    if Player.Focusing then return end
    
    if ActionHandler.IsKeyDownBool(BikeButton) then
        if not onBike and not isMounting then
            self:Mount(Accessory)
        elseif onBike and not isDismounting then
            self:Dismount(Accessory)            
        end
    end
end


--[[
    An example of a state processing function. 
--]]
function Bike:ProcessStates(char, Accessory)
    local hum = char.Humanoid
    local nexoHum = Player.getNexoHumanoid()

    if onBike then
        local groundSpeed = (char.Torso.AssemblyLinearVelocity * Vector3.new(1,0,1)).Magnitude
        if (groundSpeed < 0.1) then
            self.Animations.Walk:Stop()
            self.Animations.Idle:Play()
        else
            self.Animations.Idle:Stop()
            self.Animations.Walk:Play()
            self.Animations.Walk.Framerate = 60 / (hum.WalkSpeed / 20)
            self.Animations.Run.Framerate = 60 / (hum.WalkSpeed / 20)
            self.Animations.Sprint.Framerate = 60 / (hum.WalkSpeed / 20)
        end
    end
end

--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function Bike:Update()
    local char = Player.getCharacter()
    local accessory = char:FindFirstChild(Vehicle)

    self:ProcessInputs(char, accessory)

    self:ProcessStates(char)
end


function Bike:DetachBike()
    Player.Looking = true
    for _, animation in pairs(self.Animations) do
        if animation.ToolMap then
            animation.ToolMap["Torso"] = nil
        end            
    end
    PlayerController.LayerA.TorsoLook = true
    PlayerController.LayerB.TorsoLook = true
    PlayerController.LayerA.FilterTable[Vehicle] = nil
    PlayerController.LayerB.FilterTable[Vehicle] = nil
    Player:ResetAnimationModule()
    Player:SetAnimationModule(Player.DefaultModule)
    onBike = false

    PlayerController:ResetLocomotionScalars()
    SendNotification("Bike Detached", "", "Close", 1)
end

function Bike:AttachBike(bike)
    Player.Looking = false
    for _, animation in pairs(self.Animations) do
        if animation.ToolMap then
            local motor = Player:ConstructMotor(
                "Handle",
                "Torso",
                bike.Handle,
                CFrame.new(0.306, 0.068, 0.74)*CFrame.fromOrientation(0,math.rad(90),0),
                CFrame.new(0, 0, 0) * CFrame.fromOrientation(0,0,0)
            )
            animation.ToolMap["Torso"] = {
                bike.Handle, 
                motor
            }            
            if animation.Name == "Sprint" then
                animation.Looking = false
            end
        end
    end
    PlayerController.LayerA.TorsoLook = false
    PlayerController.LayerB.TorsoLook = false
    Player:SetAnimationModule(self.Animations)
    PlayerController.LayerA:UpdateModule(self.Animations)
    PlayerController.LayerA.FilterTable[bike.Name] = bike
    PlayerController.LayerB.FilterTable[bike.Name] = bike

    Bike:SetLocomotionScalars()
    onBike = true
    SendNotification("Bike Attached", "", "Close", 1)
end


function Bike:Mount(bike)
    isDismounting = false
    isMounting = true
    --MountBike:Stop()
    --MountBike:Play()
    SendNotification("Mounting Bike", "", "Close", 1)
    task.delay(1, function() self:AttachBike(bike) end)
end


function Bike:Dismount(bike)
    isDismounting = true
    isMounting = false
    --DismountBike:Stop()
    --DismountBike:Play()
    SendNotification("Dismounting Bike", "", "Close", 1)
    task.delay(1, function() self:DetachBike(bike) end)
end


function Bike:SetLocomotionScalars()
    PlayerController:SetSettings(self.Settings)
end


function Bike:Init()
    if self.Initialized then return end
    PlayerController.Modules[self] = self
    PlayerController:Init()
    Bike.Initialized = true
end


function Bike:Stop()
    self:DetachBike()
    onBike = false
    isMounting = false
    isDismounting = false
    PlayerController.Modules[self] = nil
    PlayerController:ResetLocomotionScalars()
    self.Initialized = false
end


return Bike