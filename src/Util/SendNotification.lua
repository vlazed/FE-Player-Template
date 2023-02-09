return function(title, text, buttonText, duration, icon)
	text = text or ""
	buttonText = buttonText or ""
	duration = duration or 1
	icon = icon or "rbxassetid://4688867958"

	game.StarterGui:SetCore("SendNotification", 
		{
			Title = title, 
			Text = text, 
			Icon = icon, 
			Duration = duration, 
			Button1 = buttonText
		}
	)
end