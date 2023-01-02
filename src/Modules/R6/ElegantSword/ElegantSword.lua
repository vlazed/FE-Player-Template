--[[
    Vlazed

    The following is an example module that interfaces with the template's controllers and provides its own animation package for
    movement. Every module must have the following functions:
        - An update function (StaffWielder:Update())
        - A process state function (processStates(args))
        - A process input function (processInputs(args))
        - An initialization function (StaffWielder:Init())
        - A stopping function (StaffWielder:Stop())
    
    In addition, all animation packages (folders with animation data) must have the following files, with a .lua extension:
        - Walk
        - Run
        - Sprint
        - Jump
        - Fall
        - Fly variants of the above (prefixed with Fly*Name* e.g. FlyWalk)
        - DodgeGround
        - DodgeAir
    If none of the above are provided, as a failsafe the Player will default to a set of animations found in Controllers/Animations

    The premise of a module is to allow the player to switch between different animation styles or modes without having to run
    different scripts. For example, this allows the player to
        - Switch between different fighting animations,
        - Equip different weapons on their character, or
        - Populate a keyboard with different emotes (with a known emote mapping), for instance to simulate playing notes.
--]]

local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local RunService = game:GetService("RunService")

local Player = require(Project.Player)
local Mouse = Player.getPlayer():GetMouse()

local PlayerController = require(Project.Controllers.PlayerController)
local ActionHandler = require(Project.Controllers.ActionHandler)
local Animation = require(Project.Controllers.Animations.Animation)
local Spring = require(Project.Util.Spring)

local ElegantSword = {}
ElegantSword.Name = "Elegant Sword"

ElegantSword.Initialized = false

local updateAccessoriesPollRate = 5
local nextUpdateTime = tick() + 1 / updateAccessoriesPollRate

local capeSpring = Spring.new(4, 0)

--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow lose the accessory.
--]]
local Sword = "Angel Sword"
local Bow = "Meshes/CompoundBowAccessory"
local Capes = {
    ["GreenCape"] = CFrame.new(0, 1.75, 0)
}
local Cape = nil

local Animations = script.Parent.Animations
local Emotes = Animations.Emotes
local EquippedSword = Animations.EquippedSword
local EquippedBow = Animations.EquippedBow
local Unequipped = Animations.Unequipped
local filterTable = {}
 
local Sit = Animation.new("Sit", require(Unequipped.Sit), 30, true)

local Keybinds = {
    Enum.KeyCode.Q,    -- Equip/Unequip
    Enum.KeyCode.F,    -- Light Attack
    Enum.KeyCode.G,    -- Heavy Attack
    Enum.KeyCode.Z,    -- Dodging
}

local EquipSwordButton = Enum.KeyCode.Q
local EquipBowButton = Enum.KeyCode.E
local LightAttackButton = Enum.KeyCode.F
local HeavyAttackButton = Enum.KeyCode.G
local DodgeButton = Enum.KeyCode.Z
local SitButton = Enum.KeyCode.C

--[[
    An example of an animation table with fields to access those animations. All animation tables
    will need the fields listed below. Access the wiki for a list of animation fields
    - Walk
    - Run
    - Sprint
    - Jump
    - Fall
    - Idle
    - Roll
    - Flip

--]]

local UnequippedAnimations = {Emotes = {}}

local EquippedSwordAnimations = {Emotes = {}}
local EquippedBowAnimations = {Emotes = {}}

local EquippedSwordAttacks = {}

local EquippedBowAttacks = {}

local EquippedKickAttacks = {}

local UnequippedLightAttacks = {}

local UnequippedHeavyAttacks = {}

local bowStretchConnection
local bowReleaseConnection


local function populateEmoteTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name:lower()] = Animation.new(v.Name, animation, animation.Properties.Framerate, false)
        end    
    end
end

local function populateAnimationTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name] = Animation.new(v.Name, animation, animation.Properties.Framerate, true, true)                
        end
    end
end

local function populateAttackTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            table.insert(targetTable, Animation.new(v.Name, animation, animation.Properties.Framerate, false, true))
            table.sort(targetTable, function(k2, k1) return k1.Name > k2.Name end)             
        end
    end
end

populateAnimationTable(Unequipped:GetChildren(), UnequippedAnimations)
populateAnimationTable(EquippedSword:GetChildren(), EquippedSwordAnimations)
populateAnimationTable(EquippedBow:GetChildren(), EquippedBowAnimations)
populateEmoteTable(Emotes:GetChildren(), EquippedSwordAnimations.Emotes)
populateEmoteTable(Emotes:GetChildren(), EquippedBowAnimations.Emotes)
populateEmoteTable(Emotes:GetChildren(), UnequippedAnimations.Emotes)
populateAttackTable(Unequipped.Punches:GetChildren(), UnequippedLightAttacks)
populateAttackTable(Unequipped.Kicks:GetChildren(), UnequippedHeavyAttacks)
populateAttackTable(EquippedSword.Slashes:GetChildren(), EquippedSwordAttacks)
populateAttackTable(EquippedSword.Kicks:GetChildren(), EquippedKickAttacks)
populateAttackTable(EquippedBow.Attacks:GetChildren(), EquippedBowAttacks)

local UnequippSword = EquippedSwordAnimations.Unequip
local UnequippBow = EquippedBowAnimations.UnequipBow
local StretchBow = EquippedBowAnimations.BowStretchA
local ShootBow = EquippedBowAttacks[1]
StretchBow.Looking = false
ShootBow.Looking = false
local EquippSword = UnequippedAnimations.Equip
local EquippBow = UnequippedAnimations.EquipBow

print(EquippedBowAttacks)

local connections = {}

function ElegantSword:_InitializeAnimations()
    PlayerController.LayerA:LoadAnimation(Sit)
    PlayerController.LayerB:LoadAnimation(EquippSword)
    PlayerController.LayerB:LoadAnimation(EquippBow)
    PlayerController.LayerB:LoadAnimation(StretchBow)
    PlayerController.LayerB:LoadAnimation(ShootBow)
    PlayerController.LayerB:LoadAnimation(UnequippSword)
    PlayerController.LayerB:LoadAnimation(UnequippBow)

    UnequippSword:ConnectStop(self.OnStopAnimation)
    EquippSword:ConnectStop(self.OnStopAnimation)
    EquippedSwordAnimations["Roll"]:ConnectStop(self.OnStopAnimation)
    EquippedBowAnimations["Roll"]:ConnectStop(self.OnStopAnimation)
    UnequippedAnimations["Roll"]:ConnectStop(self.OnStopAnimation)

    StretchBow:ConnectStop(self.OnStopAnimation)

    EquippedSwordAnimations["LandSoft"]:ConnectStop(self.OnStopAnimation)
    EquippedBowAnimations["LandSoft"]:ConnectStop(self.OnStopAnimation)
    UnequippedAnimations["LandSoft"]:ConnectStop(self.OnStopAnimation)
    
    EquippedSwordAnimations["LandHard"]:ConnectStop(self.OnStopAnimation)
    EquippedBowAnimations["LandHard"]:ConnectStop(self.OnStopAnimation)
    UnequippedAnimations["LandHard"]:ConnectStop(self.OnStopAnimation)

    for i,v in ipairs(UnequippedLightAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    for i,v in ipairs(UnequippedHeavyAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
end

local LightAttacks = {}
local HeavyAttacks = {}

local AttackIndex = 1

local Equipping = false
local Unequipping = false

local EquippedSword = false
local EquippedBow = false
local Sitting = false

local attack
local prevAttack

function ElegantSword:EquipSword()
    Unequipping = false
    Equipping = true
    EquippSword:Stop()
    EquippSword:Play()
    task.delay(25/30, function() self:Equip(Sword) end)
end

function ElegantSword:UnequipSword()
    Equipping = false
    Unequipping = true
    UnequippSword:Stop()
    UnequippSword:Play()
    task.delay(25/30, function() self:Unequip(Sword) end)
end

local function stretchBow()
    Player.Attacking:SetState(true)
    if not StretchBow:IsPlaying() then
        StretchBow:Play()
    end
end


local function releaseArrow()
    Player.Attacking:SetState(false)
    StretchBow:Stop()
    ShootBow:Play()
end


function ElegantSword:EquipBow()
    Unequipping = false
    Equipping = true
    EquippBow:Stop()
    EquippBow:Play()
    bowStretchConnection = Mouse.Button1Down:Connect(stretchBow)
    bowReleaseConnection = Mouse.Button1Up:Connect(releaseArrow)
    task.delay(25/30, function() self:Equip(Bow) end)
end

function ElegantSword:UnequipBow()
    Equipping = false
    Unequipping = true
    UnequippBow:Stop()
    UnequippBow:Play()
    bowStretchConnection:Disconnect()
    bowReleaseConnection:Disconnect()
    task.delay(25/30, function() self:Unequip(Bow) end)
end

--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function ElegantSword:ProcessInputs()
    if Player.Focusing or Player.Emoting:GetState() or Player.ChatEmoting:GetState() then return end

    if ActionHandler.IsKeyDownBool(EquipSwordButton) then
        --print("EquipButton")
        if not (EquippedSword or EquippedBow) and not Equipping then
            self:EquipSword()
        elseif EquippedSword and not Unequipping then
            self:UnequipSword()
        end
    elseif ActionHandler.IsKeyDownBool(EquipBowButton) then
        if not (EquippedSword or EquippedBow) and not Equipping then
            self:EquipBow()
        elseif EquippedBow and not Unequipping then
            self:UnequipBow()
        end
    elseif ActionHandler.IsKeyDownBool(SitButton) then
        --print("SitButotn")
        Sitting = not Sitting
        if Sit:IsPlaying() then
            Sit:Stop()
        else
            Sit:Play()
        end
    end

    if ActionHandler.IsKeyDownBool(LightAttackButton) and not Player.Attacking:GetState() then
        attack = LightAttacks[AttackIndex]
        attack.Speed = 1.175
        attack:Play()
        if prevAttack then
            prevAttack:Stop()
        end
        Player:SetStateForDuration("FightMode", true, 4)
        Player.Attacking:SetState(true)
        task.delay(attack.TimeLength/2, function()
            Player.Attacking:SetState(false)
            AttackIndex = (AttackIndex - 1 + (1 % #LightAttacks) + #LightAttacks) % #LightAttacks + 1
            prevAttack = attack
        end)
    elseif ActionHandler.IsKeyDownBool(HeavyAttackButton) and not Player.Attacking:GetState() then
        attack = HeavyAttacks[AttackIndex]
        attack.Speed = 1.175
        attack:Play()
        if prevAttack then
            prevAttack:Stop()
        end
        Player:SetStateForDuration("FightMode", true, 4)
        Player.Attacking:SetState(true)
        task.delay(2*attack.TimeLength/3, function()
            Player.Attacking:SetState(false)
            AttackIndex = (AttackIndex - 1 + (1 % #HeavyAttacks) + #HeavyAttacks) % #HeavyAttacks + 1
        end)
    end
end


--[[
    Some weird looping behavior occurs if you have animation overrides that run with a keybind.
    Best to have an OnStopAnimation callback to ensure that bugs don't occur.
--]]
function ElegantSword.OnStopAnimation(animation: Animation)
    if animation.Name == "Equip" then
        Equipping = false
    elseif animation.Name == "Unequip" then
        Unequipping = false
    elseif animation.Name == "Roll" then
        Player.Dodging = false
    elseif animation.Name == "LandSoft" or animation.Name == "LandHard" then
        Player.Landing = false
    elseif animation.Name:find("Land") then
        Player.Landing = false
    elseif animation.Name:find("Stop") then
        Player.Slowing = false
    elseif animation.Name == "BowStretchA" and Player.Attacking:GetState() then
        animation:Play()
        animation:SetIndex(animation.Length)
        animation:Freeze()
    end
end


--[[
    An example of a state processing function. 
--]]
function ElegantSword:ProcessStates(char, AccessorySword, AccessoryBow)
  --  if not RunService:IsStudio() then

        if EquippedSword and AccessorySword then
            local nexoAccessorySword = Player.getNexoCharacter():FindFirstChild(AccessorySword.Name)
            local swordOffset = CFrame.fromOrientation(0, -0, math.rad(29.01))
            * CFrame.fromOrientation(math.rad(-90), 0, 0)
            * CFrame.fromOrientation(0, math.rad(90), 0)
            * CFrame.new(0,-3,-0.3)

            AccessorySword.Handle.CFrame = 
                char["Left Arm"].CFrame * char["Left Arm"].LeftGripAttachment.CFrame 
                    * nexoAccessorySword.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
                    * swordOffset
            
            nexoAccessorySword.Handle.CFrame = 
                char["Left Arm"].CFrame * char["Left Arm"].LeftGripAttachment.CFrame 
                    * nexoAccessorySword.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
                    * swordOffset
        
            LightAttacks = EquippedSwordAttacks
            HeavyAttacks = EquippedKickAttacks
        elseif EquippedBow and AccessoryBow then
            local nexoAccessoryBow = Player.getNexoCharacter():FindFirstChild(AccessoryBow.Name)
            local bowOffset = CFrame.fromOrientation(0, -0, math.rad(29.01))
            * CFrame.fromOrientation(math.rad(-90), 0, 0)
            * CFrame.fromOrientation(0, math.rad(-90), 0)
            * CFrame.new(0,0,-0.2)

            AccessoryBow.Handle.CFrame = 
            char["Right Arm"].CFrame * char["Right Arm"].RightGripAttachment.CFrame 
                * nexoAccessoryBow.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
                * bowOffset
        
            nexoAccessoryBow.Handle.CFrame = 
            char["Right Arm"].CFrame * char["Right Arm"].RightGripAttachment.CFrame 
                * nexoAccessoryBow.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
                * bowOffset

            LightAttacks = UnequippedLightAttacks
            HeavyAttacks = EquippedKickAttacks

        else
            LightAttacks = UnequippedLightAttacks
            HeavyAttacks = UnequippedHeavyAttacks
        end

        if Cape then
            local hrp = Player.getNexoHumanoidRootPart()
            local velocity = Vector3.new()
            local angularVelocity = Vector3.new()
            if hrp then
                velocity = hrp.AssemblyLinearVelocity
                angularVelocity = char.Torso.AssemblyAngularVelocity
            end
            
            --print("Moving cape")
            local nexoChar = Player.getNexoCharacter()
            local nexoCape = Player.getNexoCharacter():FindFirstChild(Cape.Name)

            local totalVelocity = capeSpring:Update(0.01, -velocity.Magnitude / 4 - angularVelocity.Y / 2)

            Cape.Handle.PivotOffset = Capes[Cape.Name]
            nexoCape.Handle.PivotOffset = Capes[Cape.Name]
            local currentPivot = Cape.Handle:GetPivot()
            
            --[[]]
            Cape.Handle:PivotTo(currentPivot * 
                CFrame.Angles(
                    math.clamp(math.rad(totalVelocity), math.rad(-30), 0),
                    0, 
                    0
                    )
                )
                nexoCape.Handle.CFrame = Cape.Handle.CFrame 
            --]]
        end
    --end

    if not EquippedBowAnimations.Hold:IsPlaying() and EquippedBow and not Equipping then
        EquippedBowAnimations.Hold.Looking = false
        EquippedBowAnimations.Hold:Play()
    elseif not EquippedBow then
        EquippedBowAnimations.Hold:Stop()
        EquippedBowAnimations.Idle:Stop()
    end


    if Player.Attacking:GetState() then
        if char:FindFirstChild("HumanoidRootPart") then
            if EquippedSword and AccessorySword then
                PlayerController.AttackPosition = Vector3.new(AccessorySword.Handle.Position.X, char.Torso.Position.Y, AccessorySword.Handle.Position.Z)
            elseif EquippedBow and AccessoryBow then 
                PlayerController.AttackPosition = Mouse.Hit.Position
            else
                PlayerController.AttackPosition =  Player.getNexoHumanoidRootPart().CFrame:PointToWorldSpace(Vector3.new(0, 0, -1))
            end
        end
    end
end


function ElegantSword:Unequip(accessory)
    if accessory == Sword then
        EquippedSword = false
        filterTable[Sword] = nil
    elseif accessory == Bow then
        EquippedBow = false
        filterTable[Bow] = nil
    end
    Player:SetAnimationModule(UnequippedAnimations)
    PlayerController.LayerA.FilterTable = filterTable
    PlayerController.LayerB.FilterTable = filterTable
    for i,v in ipairs(UnequippedLightAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    for i,v in ipairs(UnequippedHeavyAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    AttackIndex = 1
end


function ElegantSword:Equip(accessory)
    if accessory == Sword then
        EquippedSword = true
        Player:SetAnimationModule(EquippedSwordAnimations)
        for i,v in ipairs(EquippedSwordAttacks) do
            PlayerController.LayerA:LoadAnimation(v)
        end
        for i,v in ipairs(EquippedKickAttacks) do
            PlayerController.LayerA:LoadAnimation(v)
        end
    elseif  accessory == Bow then
        EquippedBow = true
        Player:SetAnimationModule(EquippedBowAnimations)
        for i,v in ipairs(EquippedBowAttacks) do
            PlayerController.LayerA:LoadAnimation(v)
        end
        for i,v in ipairs(EquippedKickAttacks) do
            PlayerController.LayerA:LoadAnimation(v)
        end
    end
    local Accessory = Player.getCharacter():FindFirstChild(accessory)
    if Accessory then
        filterTable[accessory] = Accessory
    end
    
    PlayerController.LayerA.FilterTable = filterTable
    PlayerController.LayerB.FilterTable = filterTable
    AttackIndex = 1
end


local function findCape()
    local char = Player.getCharacter()
    for _,v in ipairs(char:GetChildren()) do
        if Capes[v.Name] then 
            --print("Found cape")
            Cape = v
            filterTable[Cape.Name] = Cape
            PlayerController.LayerA.FilterTable = filterTable
            PlayerController.LayerB.FilterTable = filterTable
            return
        end
    end
end

--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function ElegantSword:Update()
    --print("Update")
    local AccessorySword = Player.getCharacter():FindFirstChild(Sword)
    local AccessoryBow = Player.getCharacter():FindFirstChild(Bow)
    local char = Player.getCharacter()

    self:ProcessInputs()

    self:ProcessStates(char, AccessorySword, AccessoryBow)

    if tick() > nextUpdateTime then
        nextUpdateTime = tick() + 1 / updateAccessoriesPollRate
        findCape()
    end
end


function ElegantSword:Init()
    if self.Initialized then return end
    Player:SetAnimationModule(UnequippedAnimations)
    PlayerController.LayerA:UpdateModule(UnequippedAnimations)
    PlayerController.LayerB.Looking = false
    self:_InitializeAnimations()
    findCape()
    PlayerController.Modules[self] = self
    PlayerController:Init()
    self.Initialized = true
end


function ElegantSword:Stop()
    Player:ResetAnimationModule()
    if EquippedBow then
        bowStretchConnection:Disconnect()
        bowReleaseConnection:Disconnect()
    end
    PlayerController.Modules[self] = nil
    self.Initialized = false
end


function ElegantSword:__tostring()
    return self.Name
end


return ElegantSword