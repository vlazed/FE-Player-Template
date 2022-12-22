local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end


local Signal = require(Project.Packages.Signal)

local State = {}
State.__index = State

State.States = {}


function State.new(name: string, value: boolean)
	local self = setmetatable({}, State)
	
	self._name = name
	self._value = value
	self.OnChanged = Signal.new()
	self.OnTrue = Signal.new()
	self.OnFalse = Signal.new()
	self.PreviousState = nil

	State.States[self._name] = self

	return self
end


function State:GetPreviousState()
	return self.PreviousState
end


function State:SetPreviousState(state: State)
	self.PreviousState = state
end


function State:SetState(value: boolean)
	value = value or false
	if self._value and value then return end
	self._value = value
	if value then
		self.OnTrue:Fire()
	else
		self.OnFalse:Fire()
	end
	self.OnChanged:Fire()
end


function State:GetEnabledState()
	for i, state in pairs(State.States) do
		if state:GetState() then return state end
	end
end


function State:GetStateName()
	return self._name
end


function State:GetState()
	return self._value
end


function State:__tostring()
	return self:GetStateName()
end

function State:Remove()
	self.OnChanged:DisconnectAll()
	self.OnTrue:DisconnectAll()
	self.OnFalse:DisconnectAll()

	State.States[self._name] = nil
end

return State