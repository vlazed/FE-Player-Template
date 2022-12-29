local UserInputService = game:GetService("UserInputService")
local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local PlayerController = require(Project.Controllers.PlayerController)
local FastTween = require(Project.Util.FastTween)

local AnimPlayer = {}

local connection
local timePosition, timeline, play, rewind, skipForward, skipBack, skipFrameForward, skipFrameBack, handle, tab, speedMultiplier
local oldPlayerPosition 
local framePosition = 0
local minimized = false

local speed = 1

local tweenInfo = { 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out }

AnimPlayer.Playing = false

local currentAnimation = {}

local canDrag = false
local clicking = false

local pollRate = 10
local nextTime = tick() + 1/pollRate

local function tweenAllGuis(guis, properties)
    local function hasProperty(object, propertyName)
        local success, _ = pcall(function() 
            object[propertyName] = object[propertyName]
        end)
        return success
    end

    for i, gui in pairs(guis) do
        if hasProperty(gui, "ImageTransparency") then
            FastTween(gui, tweenInfo, {ImageTransparency = properties.ImageTransparency})
        end
        if hasProperty(gui, "BackgroundTransparency") then
            if gui.Name == "Selection" then
                FastTween(gui, tweenInfo, {BackgroundTransparency = 1})
            else
                FastTween(gui, tweenInfo, {BackgroundTransparency = properties.BackgroundTransparency})
            end
            if gui:IsA("ImageLabel") or gui:IsA("TextLabel") then
                FastTween(gui, tweenInfo, {BackgroundTransparency = 1})
            end
        end
        if hasProperty(gui, "TextTransparency") then
            FastTween(gui, tweenInfo, {TextTransparency = properties.TextTransparency})
        end
    end
end

local function minimizeToTab(frame)
    if minimized then return end
    minimized = true

    tweenAllGuis(
        frame:GetDescendants(), 
        {
            ImageTransparency = 1, 
            BackgroundTransparencySelection = 1, 
            BackgroundTransparency = 1, 
            TextTransparency = 1, 
            Transparency = 1
        }
    )

    FastTween(frame, tweenInfo, {Position = frame.Parent.AnimList.PlayerTab.Position, BackgroundTransparency = 1}) -- Cheap and quick
    oldPlayerPosition = frame.Position
end

local function maximizeFromTab(frame)
    if not minimized then return end
    minimized = false
    --print("Maximizing tab")

    tweenAllGuis(
        frame:GetDescendants(), 
        {
            ImageTransparency = 0, 
            BackgroundTransparencySelection = 1, 
            BackgroundTransparency = 0, 
            TextTransparency = 0, 
            Transparency = 0
        }
    )

    FastTween(frame, tweenInfo, {Position = oldPlayerPosition, BackgroundTransparency = 0})
end

local function setupInput(selection, beganFunc, ...)
    local args = {...}
    selection.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(selection, tweenInfo, { BackgroundTransparency = 1 })
            
            beganFunc(table.unpack(args))
        end
    end)
    
    selection.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(selection, tweenInfo, { BackgroundTransparency = 1 })
        end
    end)

    selection.MouseEnter:Connect(function()
        FastTween(selection, tweenInfo, { BackgroundTransparency = 0.9 })
    end)

    selection.MouseLeave:Connect(function()
        FastTween(selection, tweenInfo, { BackgroundTransparency = 1 })
    end)
end


local function setTimePosition()
    local pos = currentAnimation:GetIndex() / currentAnimation.UpperBound
    FastTween(timePosition, tweenInfo, {Position = UDim2.fromScale(pos, 0)})
end


local function changeFramePosition()

    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local relMousePosRelToTimeline = (mouse.X - timeline.AbsolutePosition.X) / timeline.AbsoluteSize.X

    local pos = math.clamp(relMousePosRelToTimeline, 0, 1)

    framePosition = math.round(pos * (currentAnimation.UpperBound - currentAnimation.LowerBound + 1))
    currentAnimation:SetIndex(framePosition)

end


function AnimPlayer:AttachToAnimation(animation: Animation)
    currentAnimation = animation
    currentAnimation.Speed = speed
end


function AnimPlayer:SkipFrame(direction: number)
    currentAnimation:NextFrame(direction)
end


function AnimPlayer:SkipToEnd(pos: number)
    pos = math.round(pos) or currentAnimation.UpperBound

    currentAnimation:SetIndex(pos)
end


function AnimPlayer:Play(isReversed)
    if self.Playing then
        self.Playing = false
        currentAnimation:Freeze()
    else
        self.Playing = true
        currentAnimation:Play(isReversed)
    end
end


function AnimPlayer:SetSpeed(speedMultiplier)
    speed = math.clamp(speedMultiplier, 0, math.huge)
end


function AnimPlayer:Update(frame)
    if tick() <= nextTime then return end
    nextTime = tick() + 1 / pollRate

    if canDrag and clicking then
        changeFramePosition()
    end
    self:AttachToAnimation(PlayerController.Animation)
    --print(currentAnimation.Name)
    setTimePosition()

    if frame.BackgroundTransparency == 1 then
        frame.Visible = false
    else
        frame.Visible = true
    end
    if self.Playing then
        play.Play.ImageTransparency = 1
        play.Pause.ImageTransparency = 0
    else
        play.Play.ImageTransparency = 0
        play.Pause.ImageTransparency = 1
    end
end

function AnimPlayer:Init(playerFrame: Frame)

    timeline = playerFrame.Timeline
    timePosition = timeline.TimePosition
    play = playerFrame.Play
    rewind = playerFrame.Rewind
    skipForward = playerFrame.RightSkip
    skipBack = playerFrame.LeftSkip
    skipFrameForward = playerFrame.RightFrame
    skipFrameBack = playerFrame.LeftFrame
    speedMultiplier = playerFrame.SpeedMultiplier

    handle = playerFrame.Handle
    tab = playerFrame.Parent.AnimList.PlayerTab

    self:AttachToAnimation(PlayerController.Animation)

    speedMultiplier.Text = tostring(currentAnimation.Speed) .. "x"

    setupInput(play.Selection, self.Play, self, false)
    setupInput(rewind.Selection, self.Play, self, true)
    setupInput(skipForward.Selection, self.SkipToEnd, self, currentAnimation.UpperBound)
    setupInput(skipBack.Selection, self.SkipToEnd, self, 1)
    setupInput(skipFrameForward.Selection, self.SkipFrame, self, 1)
    setupInput(skipFrameBack.Selection, self.SkipFrame, self, -1)

    setupInput(handle.Minimize, minimizeToTab)

    timeline.Selection.InputBegan:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            changeFramePosition()
        end
    end)

    timePosition.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            clicking = true
        end
    end)

    timePosition.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            clicking = false
            canDrag = false
        end
    end)

    timePosition.MouseEnter:Connect(function()
        if not clicking then
            canDrag = true
        end
    end)

    timePosition.MouseLeave:Connect(function()
        if not clicking then
            canDrag = false
        end
    end)

    handle.Minimize.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            minimizeToTab(playerFrame)
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

    tab.Selection.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            maximizeFromTab(playerFrame)
        end
    end)

    tab.Selection.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FastTween(tab.Selection, tweenInfo, { BackgroundTransparency = 1 })
        end
    end)

    tab.Selection.MouseEnter:Connect(function()
        FastTween(tab.Selection, tweenInfo, { BackgroundTransparency = 0.95 })
    end)

    tab.Selection.MouseLeave:Connect(function()
        FastTween(tab.Selection, tweenInfo, { BackgroundTransparency = 1 })
    end)
    
    speedMultiplier.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local num = string.gsub(speedMultiplier.Text, "x", "")
            num = tonumber(num)
            if num then
                self:SetSpeed(num) 
                speedMultiplier.Text = tostring(num) .. "x"
                print(currentAnimation.Speed)
            end
        end
    end)
end


function AnimPlayer:Remove()
    --connection:Disconnect()
end


return AnimPlayer