local rbxmSuite = loadstring(game:HttpGetAsync("https://github.com/richie0866/rbxm-suite/releases/latest/download/rbxm-suite.lua"))()

local FILENAME = "R6_Animations.rbxm"

local project = rbxmSuite.launch(FILENAME, {
    runscripts = false,
    deferred = true,
    nocache = false,
    nocirculardeps = true,
    debug = false,
    verbose = false
})


function round(num, idp)
	local mult = 10^(idp or 3)
	return math.floor(num * mult + 0.5) / mult
end


function ConvertCFrame(cf, degrees)
	local str = ""
	if round(cf.X) ~= 0 or round(cf.Y) ~= 0 or round(cf.Z) ~= 0 then
		str = ("CFrame.new(%s, %s, %s)"):format(round(cf.X), round(cf.Y), round(cf.Z))
	else
		str = "CFrame.new()"
	end
	
	local x, y, z = cf:toEulerAnglesXYZ()
	x, y, z = round(x), round(y), round(z)
	if x ~= 0 or y ~= 0 or z ~= 0 then
		if str == "CFrame.new()" then
			str = ""
		else
			str = str.." * "
		end	
		
		str = str.."CFrame.Angles("
		local function AddAngle(n, comma)
			str = str..((not degrees or n == 0) and n or "math.rad("..round(math.deg(n))..")")..(comma and ", " or ")")
		end
		
		AddAngle(x, true)
		AddAngle(y, true)
		AddAngle(z)
	end
	
	return str
end


function SequenceToModule(sequence)
	if sequence and sequence:IsA("KeyframeSequence") then
		local name = sequence.Name:gsub("_R6", "")
		name = name .. ".lua"
		local source = "return {"
		
		local function AddLine(text, depth)
			source = source.."\n"..string.rep("	", depth or 0)..text
		end
		
		AddLine("Properties = {", 1)
		AddLine("Looping = "..tostring(sequence.Loop)..",", 2)
		AddLine("Priority = Enum.AnimationPriority."..sequence.Priority.Name, 2)
		AddLine("},", 1)
		
		AddLine("Keyframes = {", 1)
		
		local function GetPoses(start, depth)
			local depth = depth or 2
			
			local hidden-- = (start.Name == "HumanoidRootPart")
			if hidden then
				depth = depth - 1
			end
			
			if start:IsA("Pose") and not hidden then
				AddLine('["'..start.Name..'"] = {', depth)
				
				if ConvertCFrame(start.CFrame, true) ~= "CFrame.new()" then
					AddLine("CFrame = "..ConvertCFrame(start.CFrame, true)..",", depth + 1)
				end
			end			
			
			for _, v in pairs(start:GetChildren()) do
				GetPoses(v, depth + 1)
			end
			
			if not hidden then
				AddLine('},', depth)
			end
		end
		
		for _, v in pairs(sequence:GetChildren()) do
			if v:IsA("Keyframe") then
				AddLine("{", 2)
				AddLine('["Time"] = '..round(v.Time)..",", 3)
				GetPoses(v)
			end
		end
		
		AddLine("}\n}", 1)
		
		writefile(name, source)
	else
		print("Conversion failed for ".. name)
	end
end


for i,v in ipairs(project:GetChildren()) do
	SequenceToModule(v)
end

