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

local PlayerController = require(Project.Controllers.PlayerController)
local ActionHandler = require(Project.Controllers.ActionHandler)
local Animation = require(Project.Controllers.Animations.Animation)

local ElegantSword = {}
ElegantSword.Name = "Elegant Sword"

ElegantSword.Initialized = false

--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow lose the accessory.
--]]
local Sword = "Angel Sword"

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

local EquipButton = Enum.KeyCode.Q
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

local EquippedAnimations = {Emotes = {}}

local EquippedSwordAttacks = {}

local EquippedBowAttacks = {}

local EquippedKickAttacks = {}

local UnequippedLightAttacks = {}

local UnequippedHeavyAttacks = {}


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
            targetTable[v.Name] = Animation.new(v.Name, animation, animation.Properties.Framerate, true)                
        end
    end
end

local function populateAttackTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            table.insert(targetTable, Animation.new(v.Name, animation, animation.Properties.Framerate, true))
            table.sort(targetTable, function(k2, k1) return k1.Name > k2.Name end)             
        end
    end
end

populateAnimationTable(Unequipped:GetChildren(), UnequippedAnimations)
populateAnimationTable(EquippedSword:GetChildren(), EquippedAnimations)
populateEmoteTable(Emotes:GetChildren(), EquippedAnimations.Emotes)
populateEmoteTable(Emotes:GetChildren(), UnequippedAnimations.Emotes)
populateAttackTable(Unequipped.Punches:GetChildren(), UnequippedLightAttacks)
populateAttackTable(Unequipped.Kicks:GetChildren(), UnequippedHeavyAttacks)
populateAttackTable(EquippedSword.Slashes:GetChildren(), EquippedSwordAttacks)
populateAttackTable(EquippedSword.Kicks:GetChildren(), EquippedKickAttacks)

local Unequipp = EquippedAnimations.Unequip
local Equipp = UnequippedAnimations.Equip

function ElegantSword:_InitializeAnimations()
    PlayerController.LayerA:LoadAnimation(Sit)
    PlayerController.LayerB:LoadAnimation(Equipp)
    PlayerController.LayerB:LoadAnimation(Unequipp)

    Unequipp.Stopped:Connect(self.OnStopAnimation)
    Equipp.Stopped:Connect(self.OnStopAnimation)
    EquippedAnimations["Roll"].Stopped:Connect(self.OnStopAnimation)
    UnequippedAnimations["Roll"].Stopped:Connect(self.OnStopAnimation)

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

local Equipped = false
local Sitting = false

local attack
local prevAttack

--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function ElegantSword:ProcessInputs()
    if Player.Focusing or Player.Emoting:GetState() then return end

    if ActionHandler.IsKeyDownBool(EquipButton) then
        --print("EquipButton")
        if not Equipped and not Equipping then
            Unequipping = false
            Equipping = true
            Equipp:Stop()
            Equipp:Play()
            task.delay(25/30, function() self:Equip() end)
        elseif Equipped and not Unequipping then
            Equipping = false
            Unequipping = true
            Unequipp:Stop()
            Unequipp:Play()
            task.delay(25/30, function() self:Unequip() end)
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
    end
end


--[[
    An example of a state processing function. 
--]]
function ElegantSword:ProcessStates(char, Accessory)
    if Equipped and Accessory then
        local nexoAccessory = Player.getNexoCharacter():FindFirstChild(Accessory.Name)

        if not RunService:IsStudio() then
            Accessory.Handle.CFrame = 
                char["Right Arm"].CFrame * char["Right Arm"].RightGripAttachment.CFrame 
                    * Accessory.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
                    * CFrame.fromOrientation(0, -0, math.rad(29.01))
                    * CFrame.fromOrientation(math.rad(-90), 0, 0)
                    * CFrame.fromOrientation(0, math.rad(90), 0)
                    * CFrame.new(0,-3,-0.3)
            
            nexoAccessory.Handle.CFrame = 
                char["Right Arm"].CFrame * char["Right Arm"].RightGripAttachment.CFrame 
                    * Accessory.Handle:FindFirstChildOfClass("Attachment").CFrame:Inverse()
                    * CFrame.fromOrientation(0, -0, math.rad(29.01))
                    * CFrame.fromOrientation(math.rad(-90), 0, 0)
                    * CFrame.fromOrientation(0, math.rad(90), 0)
                    * CFrame.new(0,-3,-0.3)
        end
        
        LightAttacks = EquippedSwordAttacks
        HeavyAttacks = EquippedKickAttacks
    else
        LightAttacks = UnequippedLightAttacks
        HeavyAttacks = UnequippedHeavyAttacks
    end

    if Player.Attacking:GetState() then
        if char:FindFirstChild("HumanoidRootPart") then
            if Equipped and Accessory then
                PlayerController.AttackPosition = Accessory.Handle.Position
            else
                PlayerController.AttackPosition =  Player.getNexoHumanoidRootPart().CFrame:PointToWorldSpace(Vector3.new(0, 0, -1))
            end
        end
    end
end


function ElegantSword:Unequip()
    Equipped = false
    filterTable[Sword] = nil
    Player:SetAnimationModule(UnequippedAnimations)
    PlayerController.LayerA.FilterTable = filterTable
    for i,v in ipairs(UnequippedLightAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    for i,v in ipairs(UnequippedHeavyAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    AttackIndex = 1
end


function ElegantSword:Equip()
    Equipped = true
    local AccessorySword = Player.getCharacter():FindFirstChild(Sword)
    if AccessorySword then
        filterTable[Sword] = AccessorySword
    end
    Player:SetAnimationModule(EquippedAnimations)
    PlayerController.LayerA.FilterTable = filterTable
    PlayerController.LayerB.FilterTable = filterTable
    for i,v in ipairs(EquippedSwordAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    for i,v in ipairs(EquippedKickAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
    end
    AttackIndex = 1
end

--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function ElegantSword:Update()
    --print("Update")
    local AccessorySword = Player.getCharacter():FindFirstChild(Sword)
    local char = Player.getCharacter()

    self:ProcessInputs()

    self:ProcessStates(char, AccessorySword)
end

function ElegantSword:Init()
    if self.Initialized then return end
    Player:SetAnimationModule(UnequippedAnimations)
    PlayerController.LayerA:UpdateModule(UnequippedAnimations)
    self:_InitializeAnimations()
    PlayerController.Modules[self] = self
    PlayerController:Init()
    self.Initialized = true
end


function ElegantSword:Stop()
    Player:ResetAnimationModule()
    PlayerController.Modules[self] = nil
    self.Initialized = false
end


function ElegantSword:__tostring()
    return self.Name
end


return ElegantSword