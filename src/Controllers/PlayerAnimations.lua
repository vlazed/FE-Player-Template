local PlayerAnimations = {}

local directory = script.Parent.Animations

if game:GetService("Players").LocalPlayer.Character.Humanoid.RigType == Enum.HumanoidRigType.R6 then
    directory = directory.R6
else
    directory = directory.R15
end

PlayerAnimations.Walk = require(directory.Move)
PlayerAnimations.Jump = require(directory.Jump)
PlayerAnimations.Fall = require(directory.Fall)
PlayerAnimations.Sprint = require(directory.Sprint)
PlayerAnimations.Run = require(directory.Run)
PlayerAnimations.Idle = require(directory.Idle)
PlayerAnimations.Roll = require(directory.DodgeGround)

PlayerAnimations.FlyIdle = require(directory.FlyIdle)
PlayerAnimations.FlyWalk = require(directory.FlyWalk)
PlayerAnimations.FlySprint = require(directory.FlySprint)
PlayerAnimations.FlyFall = require(directory.FlyFall)
PlayerAnimations.FlyJump = require(directory.FlyJump)
PlayerAnimations.Flip = require(directory.DodgeAir)

return PlayerAnimations