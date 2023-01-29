local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local ControllerSettings = require(Project.Controllers.ControllerSettings)
local ActionHandler = require(Project.Controllers.ActionHandler)
local PlayerController = require(Project.Controllers.PlayerController)
local SendNotification = require(Project.Util.SendNotification)
local FastTween = require(Project.Util.FastTween)
local Player = require(Project.Player)

local Mimic = {}
Mimic.Name = "Mimic"
Mimic.Type = "Core"

local Mouse = Player.getMouse()

local Initialized = false
local Copying = false
local CopyButton = Enum.KeyCode.M
local FrontButton = Enum.KeyCode.Comma

local targetCharacter = nil
local targetName = ""
local debounce = false
local isInFront = false

local clickConnection

local default_offset = CFrame.new(0.5,0,-6)
local forward_offset = default_offset

local R15_TO_R6_CORRESPONDENCE = {
    ["LeftLowerArm"] = "Left Arm",
    ["RightLowerArm"] = "Right Arm",
    ["LeftLowerLeg"] = "Left Leg",
    ["RightLowerLeg"] = "Right Leg",
    ["UpperTorso"] = "Torso",
    ["Head"] = "Head"
}

local R6_TO_R15_CORRESPONDENCE = {
    ["Left Arm"] = "LeftUpperArm",
    ["Right Arm"] = "RightUpperArm",
    ["Left Leg"] = "LeftUpperLeg",
    ["Right Leg"] = "RightUpperLeg",
    ["Torso"] = "LowerTorso",
    ["Head"] = "Head"
}

local function goUpHierarchy(input, targetClass)
	local parent = input.Parent
	local stop = workspace.ClassName

	if parent.ClassName == stop then
		return nil
	elseif parent.ClassName == targetClass then
		targetCharacter = parent
		return parent
	else
		goUpHierarchy(parent, targetClass)
	end
end


local function getUserFromClick()
	local part = Mouse.Target
	if not part then return end
	local potentialModel = goUpHierarchy(part, "Model")

	if not potentialModel and targetCharacter then potentialModel = targetCharacter end

	if potentialModel then
		if potentialModel:FindFirstChildOfClass("Humanoid") then
            targetName = targetCharacter.Name
			SendNotification("Found character", targetCharacter.Name, "Close", 1)
		else
			SendNotification(part.Name .. " is a parent of " .. potentialModel.Name)
		end
	else
		SendNotification("Did not find a guy", "", "Close", 1)
	end
end


local function animateHats_R15(filterTable)
    filterTable = filterTable or {}

    for i,v in ipairs(Player.getNexoCharacter():GetChildren()) do
        if v:IsA("Accessory") and not filterTable[v.Name] then
            local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
            local characterAttachment = Player.getNexoCharacter():FindFirstChild("UpperTorso"):FindFirstChild(accessoryAttachment.Name) 
                or Player.getCharacter():FindFirstChild("LowerTorso"):FindFirstChild(accessoryAttachment.Name) 
                or Player.getCharacter():FindFirstChild("Head"):FindFirstChild(accessoryAttachment.Name) 
                or Player.getNexoCharacter():FindFirstChild("Left Arm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("Right Arm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("Right Leg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("Left Leg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("LeftUpperArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("RightUpperArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("RightUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("LeftUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("LeftLowerArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("RightLowerArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("RightLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("LeftLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("LeftFoot"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("RightFoot"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("RightHand"):FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter():FindFirstChild("LeftHand"):FindFirstChild(accessoryAttachment.Name)

            v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
        end				
    end

    for i,v in ipairs(Player.getCharacter():GetChildren()) do
        if v:IsA("Accessory") and not filterTable[v.Name] then
            local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
             local characterAttachment = Player.getCharacter():FindFirstChild("UpperTorso"):FindFirstChild(accessoryAttachment.Name) 
                or Player.getCharacter():FindFirstChild("LowerTorso"):FindFirstChild(accessoryAttachment.Name) 
                or Player.getCharacter():FindFirstChild("Head"):FindFirstChild(accessoryAttachment.Name) 
                or Player.getCharacter():FindFirstChild("Left Arm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("Right Arm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("Right Leg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("Left Leg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("LeftUpperArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("RightUpperArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("RightUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("LeftUpperLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("LeftLowerArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("RightLowerArm"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("RightLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("LeftLowerLeg"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("LeftFoot"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("RightFoot"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("RightHand"):FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter():FindFirstChild("LeftHand"):FindFirstChild(accessoryAttachment.Name)

            v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
        end
    end
end


local function animateHats_R6(filterTable)
    filterTable = filterTable or {}

    for i,v in ipairs(Player.getNexoCharacter():GetChildren()) do
        if v:IsA("Accessory") and not filterTable[v.Name] then
            local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
            local characterAttachment = Player.getNexoCharacter().Torso:FindFirstChild(accessoryAttachment.Name) 
                or Player.getNexoCharacter().Head:FindFirstChild(accessoryAttachment.Name) 
                or Player.getNexoCharacter()["Left Arm"]:FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter()["Right Arm"]:FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter()["Right Leg"]:FindFirstChild(accessoryAttachment.Name)
                or Player.getNexoCharacter()["Left Leg"]:FindFirstChild(accessoryAttachment.Name)
            v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
        end		
    end
    
    for i,v in ipairs(Player.getCharacter():GetChildren()) do
        if v:IsA("Accessory") and not filterTable[v.Name] then
            local accessoryAttachment = v.Handle:FindFirstChildOfClass("Attachment")
             local characterAttachment = Player.getCharacter().Torso:FindFirstChild(accessoryAttachment.Name) 
                or Player.getCharacter().Head:FindFirstChild(accessoryAttachment.Name) 
                or Player.getCharacter()["Left Arm"]:FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter()["Right Arm"]:FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter()["Right Leg"]:FindFirstChild(accessoryAttachment.Name)
                or Player.getCharacter()["Left Leg"]:FindFirstChild(accessoryAttachment.Name)
            v.Handle.CFrame = characterAttachment.Parent.CFrame * characterAttachment.CFrame * accessoryAttachment.CFrame:inverse()
        end
    end
end


function Mimic:CopyCharacterPose(character)
    if not character then return end

    local myCharacter = Player.getCharacter()
    local myNexo = Player.getNexoCharacter() 
    local rigtype = Player:GetRigType()
    local theirRigType = character:FindFirstChildOfClass("Humanoid").RigType

    local myPart
    local theirPart
    local partName = ""
    local partOffset = CFrame.identity

    for _,instance in ipairs(character:GetChildren()) do
        
        if instance:IsA("BasePart") and instance.Name ~= "HumanoidRootPart" then
            theirPart = instance
            if rigtype == theirRigType then
                myPart = myCharacter:FindFirstChild(instance.Name)
            elseif theirRigType == Enum.HumanoidRigType.R15 and rigtype == Enum.HumanoidRigType.R6 then
                partName = R15_TO_R6_CORRESPONDENCE[instance.Name] or ""
                myPart = myCharacter:FindFirstChild(partName)
            elseif theirRigType == Enum.HumanoidRigType.R6 and rigtype == Enum.HumanoidRigType.R15 then
                partName = R6_TO_R15_CORRESPONDENCE[instance.Name] or ""
                myPart = myCharacter:FindFirstChild(partName)
            end
        end

        if rigtype == Enum.HumanoidRigType.R6 then
            if instance.Name == "UpperTorso" then
                partOffset = CFrame.new(0, -0.2, 0)
            end
            if instance.Name == "Head" then
                partOffset = CFrame.new(0, -0.05, 0)
            end
            if 
                instance.Name == "RightLowerArm" or 
                instance.Name == "LeftLowerArm" or
                instance.Name == "LeftLowerLeg" or
                instance.Name == "RightLowerLeg"
            then
                partOffset = CFrame.new(0, 0.2, 0)
            end 
        end

        if myPart and instance:IsA("BasePart") then
            local xz_vector = Vector3.zAxis + Vector3.xAxis
            if theirPart.Name == "Torso" then
                forward_offset = CFrame.new((theirPart.CFrame.LookVector * xz_vector).Unit * 6)
            end

            local nexoPart = myNexo:FindFirstChild(myPart.Name)
            local offset = CFrame.identity
            if isInFront then
                offset = forward_offset
            else
                offset = default_offset
            end

            local resultantFrame = CFrame.new(theirPart.CFrame.Position):ToWorldSpace(offset) * theirPart.CFrame.Rotation * partOffset
            
            myPart.CFrame = resultantFrame
            nexoPart.CFrame = myPart.CFrame
        end

    end
    
end


local function processInputs()
    if debounce or Player.Focusing or Player.Emoting:GetState() or Player.ChatEmoting:GetState() then return end
    if ActionHandler.IsKeyDownBool(CopyButton) then
        Copying = not Copying
        debounce = true
        SendNotification("Mimic Enabled", tostring(Copying), "Close", 2)
        task.delay(1, function() debounce = false end)
    elseif ActionHandler.IsKeyDownBool(FrontButton) then
        isInFront = not isInFront
        debounce = true
        SendNotification("In Front:", tostring(isInFront), "Close", 2)
        task.delay(1, function() debounce = false end)
    end
end


function Mimic:AnchorAllPartsFrom(character, anchorValue)
    for i,v in ipairs(character:GetChildren()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            v.Anchored = anchorValue
        elseif v:IsA("Accessory") then
            v.Handle.Anchored = anchorValue
        end
    end
end


function Mimic:Update()
    if Player:GetState("Respawning") or not Initialized then return end

    processInputs()

    local character = workspace:FindFirstChild(targetName)
    local myCharacter = Player.getCharacter()

    if Copying and character then
        PlayerController.LayerA.Playing = false
        PlayerController.LayerB.Playing = false
        PlayerController.DanceLayer.Playing = false
        self:CopyCharacterPose(character)
        --self:AnchorAllPartsFrom(myCharacter, true)
        if Player:GetRigType() == Enum.HumanoidRigType.R6 then
            animateHats_R6()
        else
            animateHats_R15()
        end
    else
        --self:AnchorAllPartsFrom(myCharacter, false)
        PlayerController.LayerA.Playing = true
        PlayerController.LayerB.Playing = true
        PlayerController.DanceLayer.Playing = true
    end
end


function Mimic:Init()
    if Initialized then return end
    
    Initialized = true
    clickConnection = Mouse.Button1Down:Connect(getUserFromClick)
    SendNotification("Mimic Loaded", "Press M to mimic a clicked humanoid", "Close", 2)
    PlayerController.Modules[self] = self
end


function Mimic:Stop()
    if not Initialized then return end 

    SendNotification("Mimic Stopped", "", "Close", 2)
    clickConnection:Disconnect()
    PlayerController.Modules[self] = nil
    Initialized = false
end


return Mimic