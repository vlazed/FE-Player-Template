local Project = script:FindFirstAncestor("FE-Player-Template")
local Player = require(Project.Player)
local AnimationController = require(Project.Controllers.AnimationController)

local Thread = require(Project.Util.Thread)
local ControllerSettings = require(Project.Controllers.ControllerSettings)

local EmoteController = {}

local initialized = false
local focusConnection, focusLostConnection, updateConnection
local chatbar

local PlayerGui = Player.getPlayerGui()

EmoteController.Focusing = false
EmoteController.Emoting = false

local EmoteLayer = AnimationController.new()

local Emote = {}

local function getEmoteName(message)
	if string.sub(message, 1, 3) == "/e " then
		return string.sub(message, 4)
	elseif string.sub(message, 1, 7) == "/emote " then
		return string.sub(message, 8)
	end

	return nil
end


function EmoteController:NotChatted()
    local startChattingAnim = Player:GetAnimation("StartChatting").Keyframes
    local startChatDuration = startChattingAnim[#startChattingAnim]["Time"] - 0.1

    if startChattingAnim then
        Emote = startChattingAnim
        EmoteLayer.i = EmoteLayer.length
        EmoteLayer.increment = -1
        self.Emoting = true
    end

    task.delay(startChatDuration, function() 
        self.Emoting = false 
        EmoteLayer.i = 1
        EmoteLayer.increment = 1
    end)
    
    self.Focusing = false
end


function EmoteController:ChooseChatAnim(message)
    local capitals = message:gsub("%l", "")
    local string_sum = message:len()

    local index = math.random(1, 4)
    local anim

    if capitals:len()/string_sum > 0.5 then
        print("Shout")
        anim = "ChattedShout" .. tostring(index)
    else
        print("Talk")
        anim = "ChattedNormal" .. tostring(index)
    end

    anim = Player:GetAnimation(anim)
    if anim then
        return anim.Keyframes
    end
end


function EmoteController:Chatted(message)
    local emote = getEmoteName(message)
    local animation
    local duration
    if emote then
        print("Emoting!")
        animation = Player:GetAnimation(emote).Keyframes
    else
        animation = self:ChooseChatAnim(message)
        print(message)
    end

    if animation then
        Emote = animation
        duration = animation[#animation]["Time"] - 0.1
        EmoteLayer.i = 1
        EmoteLayer.increment = 1
        self.Emoting = true
    end

    self.Focusing = false

    task.delay(duration, function() 
        self.Emoting = false 
    end)
end


function EmoteController:Chatting()
    
    local startChattingAnim = Player:GetAnimation("StartChatting").Keyframes
    local startChatDuration = startChattingAnim[#startChattingAnim]["Time"] - 0.1

    Emote = startChattingAnim

    print("Chatting something")

    local ChattingAnim = Player:GetAnimation("Chatting").Keyframes

    self.Focusing = true

    if ChattingAnim and self.Focusing then
        task.delay(startChatDuration, function() Emote = ChattingAnim end)
    end
end


function EmoteController:Update()
    if self.Focusing or self.Emoting then
        --print(#Emote)
        --print("Animating Emote")
        EmoteLayer:Animate(
            Emote,
            true, 
            24 * Player:GetAnimationSpeed()
        )     
    end    
end


function EmoteController:Init()
    if initialized then return end
    local Settings = ControllerSettings.GetSettings()

    local chatbar = PlayerGui.Chat:FindFirstChild("ChatBar", true)
    if chatbar then
        focusConnection = chatbar.Focused:Connect(function() self:Chatting() end)
        focusLostConnection = chatbar.FocusLost:Connect(function(enterPressed) 
            if enterPressed and string.len(chatbar.text) > 0 then
                self:Chatted(chatbar.Text)
            else
                self:NotChatted()
            end
        end)
    end

    initialized = true
end


function EmoteController:Stop()
    if not initialized then return end
    
    focusConnection:Disconnect()
    focusLostConnection:Disconnect()
    initialized = false
end

return EmoteController