local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local RunService = game:GetService("RunService")

local Thread = require(Project.Util.Thread)
local PlayerController = require(Project.Controllers.PlayerController)
local Player = require(Project.Player)
local Animation = require(Project.Controllers.Animations.Animation)
local FastTween = require(Project.Util.FastTween)

local rbxmSuite 
if not RunService:IsStudio() then
    rbxmSuite = loadstring(game:HttpGetAsync("https://github.com/richie0866/rbxm-suite/releases/latest/download/rbxm-suite.lua"))()
end

local Sidebar = {}

local tweenInfo = { 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out }

local animbar, modbar, handle, animtemplate, modtemplate, animtab, modtab

local previousAnimation = Animation.new()

local minimized = false

local connection

Sidebar.SelectedModule = nil

function Sidebar:CreateAnimationElement(filePath)

    local animTable = {}
    local keyframes = {}

    local fullname = filePath:match("([^\\]+)$")
    local name = fullname:match("^([^%.]+)") or ""
    local extension = fullname:match("([^%.]+)$")

    if extension ~= "lua" then
        return
    end

    local element = animtemplate:Clone()
    element.Name = filePath
    element.Title.Text = name

    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(element.Selection, tweenInfo, { BackgroundTransparency = 0.4 })
            
            animTable = loadfile(filePath)()
            keyframes = Animation.new(name, animTable, animTable.Properties.Framerate, true)
            table.sort(keyframes.KeyframeSequence, function(k1, k2) 
                return k1["Time"] < k2["Time"] 
            end)
            if previousAnimation.Name ~= keyframes.Name then
                Player.Dancing = true
                keyframes._index = 1
                if previousAnimation and previousAnimation.Name ~= "" then
                    PlayerController.DanceLayer:UnloadAnimation(previousAnimation)
                end
                PlayerController.DanceLayer:LoadAnimation(keyframes)
                PlayerController:SetAnimation(keyframes)
                previousAnimation = keyframes
            elseif previousAnimation.Name == keyframes.Name then
                PlayerController.DanceLayer:UnloadAnimations()
                Player.Dancing = false
            end
        end
    end)

    element.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(element.Selection, tweenInfo, { BackgroundTransparency = 0.6 })
        end
    end)

    element.MouseEnter:Connect(function()
        FastTween(element, tweenInfo, { BackgroundTransparency = 0.6 })
    end)

    element.MouseLeave:Connect(function()
        FastTween(element, tweenInfo, { BackgroundTransparency = 1 })
    end)

    element.Parent = animbar
    animbar.CanvasSize = UDim2.new(0, 0, 0, #animbar:GetChildren() * element.AbsoluteSize.Y)

end


function Sidebar:CreateModuleElement(file)

    local element = modtemplate:Clone()
    element.Name = file.Name
    element.Title.Text = file.Name

    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(element.Selection, tweenInfo, { BackgroundTransparency = 0.4 })
            
            if self.SelectedModule then
                self.SelectedModule:Stop()
                self.SelectedModule = nil
            else
                self.SelectedModule = require(file)
                self.SelectedModule:Init()
            end
        end
    end)

    element.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(element.Selection, tweenInfo, { BackgroundTransparency = 0.6 })
        end
    end)

    element.MouseEnter:Connect(function()
        FastTween(element, tweenInfo, { BackgroundTransparency = 0.6 })
    end)

    element.MouseLeave:Connect(function()
        FastTween(element, tweenInfo, { BackgroundTransparency = 1 })
    end)

    element.Parent = modbar
    modbar.CanvasSize = UDim2.new(0, 0, 0, #modbar:GetChildren() * element.AbsoluteSize.Y)

end


function Sidebar:Update()
    --print("Checking for new files")
    local animfiles 
    local internalmodfiles
    local externalmodfiles

    if listfiles then
        if Player.getHumanoid().RigType == Enum.HumanoidRigType.R15 then
            animfiles = listfiles("fe-player-template/animations/R15")
            --internalmodfiles = Project.Modules.R15:GetChildren()
            externalmodfiles = listfiles("fe-player-template/modules/R15")
        else
            animfiles = listfiles("fe-player-template/animations/R6")
            --internalmodfiles = Project.Modules.R6:GetChildren()
            externalmodfiles = listfiles("fe-player-template/modules/R6")
        end    
    else
        animfiles = game:GetService("ReplicatedStorage").Anims:GetChildren()
        internalmodfiles = game:GetService("ReplicatedStorage").Anims:GetChildren()
    end

    for _,element in ipairs(animbar:GetChildren()) do
        if element:IsA("Frame") and not table.find(animfiles, element.Name) then
            element:Destroy()
        end
    end

    --[[
    for _,element in ipairs(modbar:GetChildren()) do
        if element:IsA("Frame") and not table.find(internalmodfiles, element.Name) then
            element:Destroy()
        end
    end
    ]]

    for _,element in ipairs(modbar:GetChildren()) do
        if element:IsA("Frame") and not table.find(externalmodfiles, element.Name) then
            element:Destroy()
        end
    end

    for _,filePath in ipairs(animfiles) do
        if not animbar:FindFirstChild(filePath) then
            self:CreateAnimationElement(filePath)
        end
    end

    --[[
    for _,folder in ipairs(internalmodfiles) do
        if not modbar:FindFirstChild(folder) then
            local file = folder:FindFirstChildOfClass("ModuleScript")
            if file then
                self:CreateModuleElement(file)
            end
        end
    end
    --]]

    -- TODO: Figure out how to support external animation modules
    if not RunService:IsStudio() then
    
        for _,filePath in ipairs(externalmodfiles) do
            if not modbar:FindFirstChild(filePath) then
                local fileModule = rbxmSuite.launch(filePath, {
                    runscripts = false,
                    deferred = true,
                    nocache = false,
                    nocirculardeps = true,
                    -- TODO: Remove unused packages 
                    debug = true,
                    verbose = false
                })
                if Player.getHumanoid().RigType == Enum.HumanoidRigType.R15 then
                    fileModule.Parent = Project.Modules.R15
                else
                    fileModule.Parent = Project.Modules.R6
                end
                local moduleScript = fileModule:FindFirstChildOfClass("ModuleScript")
                if moduleScript then
                    self:CreateModuleElement(moduleScript)
                end
            end
        end
    end

end


function Sidebar:Init(frame)

    animbar = frame.Animations
    modbar = frame.Modules
    handle = frame.Handle

    animtab = frame.AnimTab
    modtab = frame.ModuleTab

    animtab.Selection.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(animtab.Selection, tweenInfo, { BackgroundTransparency = 0.8 })
            animbar.Visible = true
            modbar.Visible = false
        end
    end)

    animtab.Selection.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(animtab.Selection, tweenInfo, { BackgroundTransparency = 1 })
        end
    end)

    animtab.Selection.MouseEnter:Connect(function()
        FastTween(animtab.Selection, tweenInfo, { BackgroundTransparency = 0.95 })
    end)

    animtab.Selection.MouseLeave:Connect(function()
        FastTween(animtab.Selection, tweenInfo, { BackgroundTransparency = 1 })
    end)

    modtab.Selection.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(modtab.Selection, tweenInfo, { BackgroundTransparency = 0.8 })
            animbar.Visible = false
            modbar.Visible = true
        end
    end)

    modtab.Selection.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(modtab.Selection, tweenInfo, { BackgroundTransparency = 1 })
        end
    end)

    modtab.Selection.MouseEnter:Connect(function()
        FastTween(modtab.Selection, tweenInfo, { BackgroundTransparency = 0.95 })
    end)

    modtab.Selection.MouseLeave:Connect(function()
        FastTween(modtab.Selection, tweenInfo, { BackgroundTransparency = 1 })
    end)

    handle.Minimize.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(handle.Minimize, tweenInfo, { BackgroundTransparency = 0.8 })
            minimized = not minimized
            if minimized then
                FastTween(frame, tweenInfo, { Size = UDim2.new(0, 208, 0, 0) })
            else
                FastTween(frame, tweenInfo, { Size = UDim2.new(0, 208, 0, 393) })
            end
        end
    end)

    handle.Minimize.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(handle.Minimize, tweenInfo, { BackgroundTransparency = 1 })
        end
    end)

    handle.Minimize.MouseEnter:Connect(function()
        FastTween(handle.Minimize, tweenInfo, { BackgroundTransparency = 0.95 })
    end)

    handle.Minimize.MouseLeave:Connect(function()
        FastTween(handle.Minimize, tweenInfo, { BackgroundTransparency = 1 })
    end)

    animtemplate = animbar.Animation
    animtemplate.Parent = nil

    modtemplate = modbar.Module
    modtemplate.Parent = nil

    if not RunService:IsStudio() then
        connection = Thread.DelayRepeat(1, self.Update, self)
        self:Update()
    end
end

function Sidebar:Remove()
    connection:Disconnect()
end

return Sidebar