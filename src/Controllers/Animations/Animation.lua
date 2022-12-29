local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Signal = require(Project.Packages.Signal)
local Maid = require(Project.Packages.Maid)

local Animation = {}
Animation.__index = Animation

function Animation.new(name: string, keyframeSequence: table, framerate: number, looking: boolean) : Animation
    local self = setmetatable({}, Animation)

    self.Name = name or ""
    self._playing = false
    self._index = 1

    self.TimeDiff = 0
    self.Time = 0

    self.Increment = 1
    self.Speed = 1

    self.IsInterpolating = true

    self.FilterTable = {}

    self.Looking = looking or false

    -- Check if modulescript or keyframesequence instance
    self.Properties = {}
    self.KeyframeSequence = keyframeSequence or {}
    self.Priority = Enum.AnimationPriority.Core
    self.Looping = false
    self.Framerate = 30
    
    if self.KeyframeSequence.Keyframes then
        --print("Module script")
        self.KeyframeSequence = keyframeSequence.Keyframes
        self.Properties = keyframeSequence.Properties
        self.Priority = keyframeSequence.Properties.Priority
        self.Looping = keyframeSequence.Properties.Looping
        self.Framerate = keyframeSequence.Properties.Framerate or 30
    elseif typeof(keyframeSequence) == 'Instance' then
        --print("Keyframe sequence")
        self.KeyframeSequence = keyframeSequence:GetChildren()
        table.sort(self.KeyframeSequence, function(k1, k2)
            return k1["Time"] < k2["Time"]
        end)
        self.Priority = keyframeSequence.Priority
        self.Looping = keyframeSequence.Loop
        self.Framerate = framerate or 30
        self.Properties = {
            Priority = self.Priority,
            Looping = self.Looping,
            Framerate = self.Framerate
        }
    else
        self.KeyframeSequence = {}
        self.Priority = Enum.AnimationPriority.Core
        self.Looping = true
        self.Framerate = framerate or 30
        self.Properties = {
            Priority = self.Priority,
            Looping = self.Looping,
            Framerate = self.Framerate
        }
    end

    self.Length = #self.KeyframeSequence
    self.UpperBound = self.Length
    self.LowerBound = 1

    if self.UpperBound > 0 then
        self.TimeLength = self.KeyframeSequence[self.UpperBound]["Time"]
    else
        self.Length = 1
        self.UpperBound = 1
        self.TimeLength = 1
    end

    self._maid = Maid.new()

    self.Stopped = Signal.new()
    self.Looped = Signal.new()

    return self
end


function Animation:GetIndex()
    return self._index
end


function Animation:SetIndex(value: number)
    self._index = value
end


function Animation:NextFrame(direction)
    self:SetIndex((self:GetIndex() - 1 + (direction % self.UpperBound) + self.UpperBound) % self.UpperBound + self.LowerBound)
end


function Animation:IsPlaying()
    return self._playing
end


function Animation:Play(reversed: boolean)
    self._playing = true
    self.Increment = reversed and -1 or 1
end


function Animation:_Stop()
    self._playing = false
    self._index = 1
end


function Animation:Stop()
    self:_Stop()
    self.Stopped:Fire(self)
end


function Animation:Freeze()
    self.Increment = 0
end


function Animation:Pause()
    self._playing = false
end


function Animation:ConnectStop(callback)
    self._maid:GiveTask(self.Stopped:Connect(callback))
end


function Animation:ConnectLoop(callback)
    self._maid:GiveTask(self.Looped:Connect(callback))
end


function Animation:Destroy()
    self._maid:Destroy()
    self._playing = false
end


function Animation:__tostring()
    return self.Name 
end

return Animation