local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Player = require(Project.Player)
local AnimationController = require(Project.Controllers.AnimationController)

local ControllerSettings = require(Project.Controllers.ControllerSettings)

local EmoteController = {}

local initialized = false
local focusConnection, focusLostConnection, updateConnection
local chatbar

local PlayerGui = Player.getPlayerGui()

local EmoteLayer = AnimationController.new(Player.AnimationModule.Emotes)

local Emote = {}
local ChatEmote = {}

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
        ChatEmote = startChattingAnim
        EmoteLayer.i = EmoteLayer.length
        EmoteLayer.increment = -1
        Player.ChatEmoting = true
    end

    task.delay(startChatDuration, function() 
        Player.ChatEmoting = false
        Player.Emoting = false

        EmoteLayer.i = 1
        EmoteLayer.increment = 1

        EmoteLayer.looking = false
    end)
    
    Player.Focusing = false
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
        animation = Player:GetAnimation(emote)
        if animation then 
            animation = animation.Keyframes
        end
    else
        animation = self:ChooseChatAnim(message)
        print(message)
    end

    if animation and emote then
        Emote = animation
        duration = animation[#animation]["Time"] - 0.1
        EmoteLayer.i = 1
        EmoteLayer.increment = 1
        EmoteLayer.looking = false
        
        Player.Emoting = true
    elseif animation then
        ChatEmote = animation
        duration = animation[#animation]["Time"] - 0.1
        EmoteLayer.i = 1
        EmoteLayer.increment = 1
        Player.ChatEmoting = true
    end

    Player.Focusing = false

    task.delay(duration, function() 
        Player.Emoting = false 
        Player.ChatEmoting = false

        EmoteLayer.looking = false
    end)
end


function EmoteController:Chatting()
    
    local startChattingAnim = Player:GetAnimation("StartChatting").Keyframes
    local startChatDuration = startChattingAnim[#startChattingAnim]["Time"] - 0.1

    ChatEmote = startChattingAnim
    EmoteLayer.looking = true

    print("Chatting something")

    local ChattingAnim = Player:GetAnimation("Chatting").Keyframes

    Player.Focusing = true

    if ChattingAnim and Player.Focusing then
        task.delay(startChatDuration, function() ChatEmote = ChattingAnim end)
    end
end


function EmoteController:Update()
    
    if Player.Emoting then
        --print(#Emote)
        --print("Animating Emote")
        EmoteLayer:Animate(
            Emote,
            true, 
            24
        )
    elseif Player.ChatEmoting or Player.Focusing then
        --print(#Emote)
        --print("Animating Emote")
        EmoteLayer:Animate(
            ChatEmote,
            true, 
            24
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