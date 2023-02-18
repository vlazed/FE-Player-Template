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

local GozeSpear = {}
GozeSpear.Name = "Goze Spear"
GozeSpear.Type = "Action"
GozeSpear.Icon = ""

GozeSpear.Initialized = false


--[[
    If a module requires an accessory, make sure to provide a failsafe in case that the Player does not own
    or somehow lose the accessory.
--]]
local Sword = "Dragonbone Spear"

local Animations = script.Parent.Animations
local Emotes = Animations.Emotes
local Equipped = Animations.Equipped
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

local EquippedLightAttacks = {}
local EquippedHeavyAttacks = {}

local UnequippedLightAttacks = {}
local UnequippedHeavyAttacks = {}


local function setToolMap(accessory, animation, limbName, handleName)
    local motor = Player:ConstructMotor(
            handleName,
            limbName,
            accessory.Handle,
            CFrame.new(-1.348, 0.101, 0.9)*CFrame.fromOrientation(0, 0, math.rad(-48)),
            CFrame.new(0, 0, 0) * CFrame.fromOrientation(0,0,0)
        )
        animation.ToolMap[limbName] = {
            accessory.Handle, 
            motor
        }
end


local function unsetToolMap(animation, limbName)
        animation.ToolMap[limbName] = {}
end


local function populateEmoteTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name:lower()] = Animation.new(v.Name, animation, animation.Properties.Framerate, false)
        end    
    end
end

local function populateAnimationTableUnequipped(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name] = Animation.new(v.Name, animation, animation.Properties.Framerate, true, false)
        end
    end
end

local function populateAnimationTableEquipped(inputTable: table, targetTable: table)
    local Accessory = Player.getCharacter():FindFirstChild(Sword)

    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            targetTable[v.Name] = Animation.new(v.Name, animation, animation.Properties.Framerate, true, false)
            setToolMap(Accessory, targetTable[v.Name], "Right Arm", "Handle")
        end
    end
end

local function populateAttackTable(inputTable: table, targetTable: table)
    for i,v in ipairs(inputTable) do
        if v:IsA("ModuleScript") then
            local animation = require(v)
            table.insert(targetTable, Animation.new(v.Name, animation, animation.Properties.Framerate, false, false))
            table.sort(targetTable, function(k2, k1) return k1.Name > k2.Name end)  
        end
    end
end

local UnequippSword
local EquippSword

local connections = {}

function GozeSpear:_FillAnimations()
    populateAnimationTableUnequipped(Unequipped:GetChildren(), UnequippedAnimations)
    populateAnimationTableEquipped(Equipped:GetChildren(), EquippedAnimations)
    populateEmoteTable(Emotes:GetChildren(), EquippedAnimations.Emotes)
    populateEmoteTable(Emotes:GetChildren(), UnequippedAnimations.Emotes)
    populateAttackTable(Unequipped.LightAttacks:GetChildren(), UnequippedLightAttacks)
    populateAttackTable(Unequipped.HeavyAttacks:GetChildren(), UnequippedHeavyAttacks)
    populateAttackTable(Equipped.LightAttacks:GetChildren(), EquippedLightAttacks)
    populateAttackTable(Equipped.HeavyAttacks:GetChildren(), EquippedHeavyAttacks)

    UnequippSword = EquippedAnimations.Unequip
    EquippSword = UnequippedAnimations.Equip
end


function GozeSpear:_InitializeAnimations()
    PlayerController.LayerA:LoadAnimation(Sit)
    PlayerController.LayerB:LoadAnimation(EquippSword)
    PlayerController.LayerB:LoadAnimation(UnequippSword)

    UnequippSword:ConnectStop(self.OnStopAnimation)
    EquippSword:ConnectStop(self.OnStopAnimation)
    EquippedAnimations["Roll"]:ConnectStop(self.OnStopAnimation)
    UnequippedAnimations["Roll"]:ConnectStop(self.OnStopAnimation)

    print("Attacks One")
    for i,v in ipairs(UnequippedLightAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
        --v:ConnectStop(self.OnStopAnimation)
    end
    for i,v in ipairs(UnequippedHeavyAttacks) do
        PlayerController.LayerA:LoadAnimation(v)
        --v:ConnectStop(self.OnStopAnimation)
    end
    print("Attacks Two")
end

local LightAttacks = {}
local HeavyAttacks = {}

local AttackIndex = 1

local Equipping = false
local Unequipping = false

local EquippedSword = false
local Sitting = false

local attack
local prevAttack


function GozeSpear:EquipSword()
    Unequipping = false
    Equipping = true
    EquippSword:Stop()
    EquippSword:Play()
    task.delay(25/30, function() self:Equip() end)
end


function GozeSpear:UnequipSword()
    Equipping = false
    Unequipping = true
    UnequippSword:Stop()
    UnequippSword:Play()
    task.delay(25/30, function() self:Unequip() end)
end


--[[
    An example of an input processing function. Ideally, one should provide some debounce
    implementation to prevent inputs from processing on the update step
--]]
function GozeSpear:ProcessInputs()
    if Player.Focusing or Player.Emoting:GetState() or Player.ChatEmoting:GetState() then return end

    if ActionHandler.IsKeyDownBool(EquipButton) then
        --print("EquipButton")
        if not EquippedSword and not Equipping then
            self:EquipSword()
        elseif EquippedSword and not Unequipping then
            self:UnequipSword()
        end
    elseif ActionHandler.IsKeyDownBool(SitButton) then
        --print("SitButotn")
        Sitting = not Sitting
        if Sit:IsPlaying() and not Sitting then
            Sit:Stop()
        else
            Sit:Play()
        end
    end

    if ActionHandler.IsKeyDownBool(LightAttackButton) and not Player.Attacking:GetState() then
        AttackIndex = (AttackIndex - 1 + (0 % #LightAttacks) + #LightAttacks) % #LightAttacks + 1
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
        AttackIndex = (AttackIndex - 1 + (0 % #HeavyAttacks) + #HeavyAttacks) % #HeavyAttacks + 1
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
function GozeSpear.OnStopAnimation(animation: Animation)
    if animation.Name == "Equip" then
        Equipping = false
    elseif animation.Name == "Unequip" then
        Unequipping = false
    elseif animation.Name == "Roll" then
        Player.Dodging = false
    elseif animation.Name:find("Land") then
        Player.Landing = false
    elseif animation.Name:find("Stop") then
        Player.Slowing = false
    elseif animation.Name:Find("Attack") then
        PlayerController.AttackPosition =  Player.getNexoHumanoidRootPart().CFrame:PointToWorldSpace(Vector3.new(0, 0, -1))
    end
end


--[[
    An example of a state processing function. 
--]]
function GozeSpear:ProcessStates(char, AccessorySword)

        if EquippedSword then
            LightAttacks = EquippedLightAttacks
            HeavyAttacks = EquippedHeavyAttacks
        else
            LightAttacks = UnequippedLightAttacks
            HeavyAttacks = UnequippedHeavyAttacks
        end

    if Player.Attacking:GetState() then
        if char:FindFirstChild("HumanoidRootPart") then
            if EquippedSword and AccessorySword then
                AccessorySword.Handle.RotVelocity = Vector3.new()
                PlayerController.AttackPosition = Vector3.new(AccessorySword.Handle.Position.X, char.Torso.Position.Y, AccessorySword.Handle.Position.Z)
            else
                AccessorySword.Handle.RotVelocity = Vector3.new()
                PlayerController.AttackPosition =  Player.getNexoHumanoidRootPart().CFrame:PointToWorldSpace(Vector3.new(0, 0, -1))
            end
        end
    end
end


function GozeSpear:Unequip()
    local Accessory = Player.getCharacter():FindFirstChild(Sword)

    filterTable[Sword] = nil
    EquippedSword = false

    Player:SetAnimationModule(UnequippedAnimations)
    PlayerController.LayerA.FilterTable = filterTable
    PlayerController.LayerB.FilterTable = filterTable
    for _,attack in ipairs(UnequippedLightAttacks) do
        PlayerController.LayerA:LoadAnimation(attack)
    end
    for _,attack in ipairs(UnequippedHeavyAttacks) do
        PlayerController.LayerA:LoadAnimation(attack)
    end

    unsetToolMap(EquippSword, "Right Arm")
    unsetToolMap(UnequippSword, "Right Arm")
    AttackIndex = 1
end


function GozeSpear:Equip()
    local Accessory = Player.getCharacter():FindFirstChild(Sword)

    if Accessory then
        EquippedSword = true
        Player:SetAnimationModule(EquippedAnimations)
        for _,attack in ipairs(EquippedLightAttacks) do
            PlayerController.LayerA:LoadAnimation(attack)
            setToolMap(Accessory, attack, "Right Arm", "Handle")
        end
        for _,attack in ipairs(EquippedHeavyAttacks) do
            PlayerController.LayerA:LoadAnimation(attack)
            setToolMap(Accessory, attack, "Right Arm", "Handle")
        end

        setToolMap(Accessory, EquippSword, "Right Arm", "Handle")
        setToolMap(Accessory, UnequippSword, "Right Arm", "Handle")

        filterTable[Sword] = Accessory
    end
    
    PlayerController.LayerA.FilterTable = filterTable
    PlayerController.LayerB.FilterTable = filterTable
    AttackIndex = 1
end


--[[
    An update function. Generally, this function should only contain the processInputs or processStates function.
--]]
function GozeSpear:Update()
    --print("Update")
    local AccessorySword = Player.getCharacter():FindFirstChild(Sword)
    local char = Player.getCharacter()

    self:ProcessInputs()

    self:ProcessStates(char, AccessorySword)

end


function GozeSpear:Init()
    if self.Initialized then return end
    self:_FillAnimations()
    Player:SetAnimationModule(UnequippedAnimations)
    PlayerController.LayerA:UpdateModule(UnequippedAnimations)
    PlayerController.LayerB.Looking = false
    self:_InitializeAnimations()
    PlayerController.Modules[self.Name] = self
    PlayerController:Init()
    self.Initialized = true
end


function GozeSpear:Stop()
    Player:ResetAnimationModule()
    PlayerController.LayerA.FilterTable = {}
    PlayerController.LayerB.FilterTable = {}
    PlayerController.Modules[self.Name] = nil
    self.Initialized = false
end


function GozeSpear:__tostring()
    return self.Name
end


return GozeSpear