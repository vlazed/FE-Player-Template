local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Signal = require(Project.Packages.Signal)

local Animation = {}
Animation.__index = Animation

function Animation.new(name: string, keyframeSequence: table, framerate: number, looking: boolean) : Animation
    local self = setmetatable({}, Animation)

    self.Name = name
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
    self.KeyframeSequence = {}
    self.Priority = Enum.AnimationPriority.Core
    self.Looping = false
    self.Framerate = 30
    if keyframeSequence.Keyframes then
        --print("Module script")
        self.KeyframeSequence = keyframeSequence.Keyframes
        self.Priority = keyframeSequence.Properties.Priority
        self.Looping = keyframeSequence.Properties.Looping
        self.Framerate = keyframeSequence.Properties.Framerate or 30
    else
        --print("Keyframe sequence")
        self.KeyframeSequence = keyframeSequence:GetChildren()
        table.sort(self.KeyframeSequence, function(k1, k2)
            return k1["Time"] < k2["Time"]
        end)
        self.Priority = keyframeSequence.Priority
        self.Looping = keyframeSequence.Loop
        self.Framerate = framerate or 30
    end

    self.Length = #self.KeyframeSequence
    self.UpperBound = self.Length
    self.LowerBound = 1

    self.TimeLength = self.KeyframeSequence[self.UpperBound]["Time"]

    self.Stopped = Signal.new()
    self.Looped = Signal.new()

    return self
end


function Animation:IsPlaying()
    return self._playing
end


function Animation:Play()
    self._playing = true
end


function Animation:_Stop()
    self._playing = false
    self._index = 1
end


function Animation:Stop()
    self:_Stop()
    self.Stopped:Fire(self)
end


function Animation:Pause()
    self._playing = false
end


function Animation:__tostring()
    return self.Name 
end

return Animation