return {
	Properties = {
		Looping = false,
		Priority = Enum.AnimationPriority.Movement,
		Framerate = 60,
	},
	Keyframes = {
		{
			["Time"] = 0,
			["HumanoidRootPart"] = {
				["LowerTorso"] = {
					CFrame = CFrame.new(-0.25, 0.826, -0.126) * CFrame.Angles(math.rad(-10.027), math.rad(-3.38), math.rad(8.365)),
					["UpperTorso"] = {
						CFrame = CFrame.Angles(math.rad(-9.282), math.rad(6.875), math.rad(-5.844)),
						["LeftUpperArm"] = {
							CFrame = CFrame.Angles(math.rad(-24.809), math.rad(-2.177), math.rad(-99.294)),
							["LeftLowerArm"] = {
								CFrame = CFrame.Angles(math.rad(70.588), math.rad(-19.939), math.rad(-6.818)),
								["LeftHand"] = {
									CFrame = CFrame.Angles(math.rad(28.247), math.rad(16.616), math.rad(-49.561)),
								},
							},
						},
						["RightUpperArm"] = {
							CFrame = CFrame.Angles(math.rad(0.115), math.rad(4.87), math.rad(78.209)),
							["RightLowerArm"] = {
								CFrame = CFrame.Angles(math.rad(43.889), math.rad(14.897), math.rad(15.011)),
								["RightHand"] = {
									CFrame = CFrame.Angles(math.rad(3.896), math.rad(-7.219), math.rad(31.742)),
								},
							},
						},
						["Head"] = {
							CFrame = CFrame.Angles(math.rad(-26.872), math.rad(3.151), math.rad(1.604)),
						},
					},
					["LeftUpperLeg"] = {
						CFrame = CFrame.Angles(math.rad(45.779), math.rad(10.485), math.rad(-20.97)),
						["LeftLowerLeg"] = {
							CFrame = CFrame.Angles(math.rad(-51.337), math.rad(-4.813), math.rad(2.865)),
							["LeftFoot"] = {
								CFrame = CFrame.Angles(math.rad(-6.303), math.rad(-1.146), math.rad(9.11)),
							},
						},
					},
					["RightUpperLeg"] = {
						CFrame = CFrame.Angles(math.rad(102.559), math.rad(2.865), math.rad(9.282)),
						["RightLowerLeg"] = {
							CFrame = CFrame.Angles(math.rad(-137.624), math.rad(-1.146), math.rad(-1.031)),
							["RightFoot"] = {
								CFrame = CFrame.Angles(math.rad(5.73), math.rad(-1.662), math.rad(-11.345)),
							},
						},
					},
				},
			},
		},
	}
}