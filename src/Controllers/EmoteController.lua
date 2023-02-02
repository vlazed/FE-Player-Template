local Project
if getgenv then
	Project = script:FindFirstAncestor(getgenv().PROJECT_NAME)
else
	Project = script:FindFirstAncestor(_G.PROJECT_NAME)
end

local Player = require(Project.Player)
local AnimationController = require(Project.Controllers.AnimationController)

local EmoteController = {}

local initialized = false

local focusConnection, focusLostConnection, updateConnection

local PlayerGui = Player.getPlayerGui()

local EmoteLayer = {}

EmoteController.PointRight = false
EmoteController.PointLeft = false

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


function EmoteController:_InitializeEmotes()
    EmoteLayer:UpdateModule(Player:GetDefaultEmotes())
    EmoteLayer:UpdateModule(Player.AnimationModule.Emotes)
    --print(EmoteLayer.AnimationTable)
end


function EmoteController:_InitializeStates()
    Player:GetDefaultEmotes()["startchatting"].Stopped:Connect(self.OnStopAnimation)
    Player.Emoting.OnTrue:Connect(self.OnEmote)
end


function EmoteController:_CleanUpStates()
    Player:GetDefaultEmotes()["startchatting"].Stopped:DisconnectAll()
    Player.Emoting.OnTrue:DisconnectAll()
end


function EmoteController:NotChatted()
    local startChattingAnim = Player:GetAnimation("StartChatting")
    local chattingAnim = Player:GetAnimation("Chatting")

    startChattingAnim.Increment = -1
    startChattingAnim:SetIndex(startChattingAnim.Length)
    chattingAnim:Stop()
    startChattingAnim:Play()
    
    Player.Focusing = false
end


function EmoteController:ChooseChatAnim(message)
    local capitals = message:gsub("%l", "")
    local string_sum = message:len()

    local index = math.random(1, 4)
    local anim

    if capitals:len()/string_sum > 0.5 then
        --print("Shout")
        anim = "ChattedShout" .. tostring(index)
    else
        --print("Talk")
        anim = "ChattedNormal" .. tostring(index)
    end

    anim = Player:GetAnimation(anim)
    if anim then
        return anim
    end
end


function EmoteController:Chatted(message)
    local emote = getEmoteName(message)
    local animation

    local chattingAnim = Player:GetAnimation("Chatting")
    chattingAnim:Stop()

    if emote then
        animation = Player:GetAnimation(emote)
    else
        animation = self:ChooseChatAnim(message)
    end

    if emote == "pointright" then
        self.PointRight = not self.PointRight
    elseif emote == "pointleft" then
        self.PointLeft = not self.PointLeft
    end

    if animation and emote then
        Emote = animation
        Emote:Stop()
        Emote.Increment = 1
        Emote.Looking = false
    elseif animation then
        ChatEmote = animation
        ChatEmote:Stop()
        Emote.Increment = 1
        ChatEmote.Looking = true
    end

    animation.Framerate = 24

    animation:Play()
    Player.Focusing = false
end


function EmoteController:Chatting()
    
    local startChattingAnim = Player:GetAnimation("StartChatting")

    startChattingAnim.Increment = 1
    startChattingAnim:Play()

    ChatEmote = Player:GetAnimation("Chatting")

    --print("Chatting something")

    Player.Focusing = true
end


function EmoteController:Update()
    EmoteLayer:Animate()
end


function EmoteController.OnStopAnimation(emote: Animation)
    print(emote.Name)
    if emote.Name == "StartChatting" and Player.Focusing then
        --print("Chatting")
        Player:GetAnimation("Chatting"):Play()
    else
        Player:GetAnimation("Chatting"):Stop()
    end
end


function EmoteController.OnEmote(state: State)
    if state:GetName() == "StartChatting" then
        ChatEmote:Play()
        Emote:Stop()
    elseif state:GetName() == "Emoting" then
        Emote:Play()
        ChatEmote:Stop()
    end
end


function EmoteController:Init()
    if initialized then return end
    
    EmoteLayer = AnimationController.new()

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

    self:_InitializeEmotes()
    self:_InitializeStates()
    initialized = true
end


function EmoteController:Stop()
    if not initialized then return end
    
    focusConnection:Disconnect()
    focusLostConnection:Disconnect()
    self:_CleanUpStates()
    initialized = false
end

return EmoteController