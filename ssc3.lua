--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
--// Head expanders
local HeadConnections = {}

--// Local Player & Variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// ESP Chams Storage
local ChamsObjects = {}

--// Helper Functions
local function getLocalParts()
	local char = LocalPlayer.Character
	if not char then return nil, nil, nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return char, humanoid, root
end

local function getPlayerInfo(player)
	if not player or player == LocalPlayer then return nil end
	if not player.Parent then return nil end
	local char = player.Character
	if not char then return nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not humanoid or not root or not head then return nil end
	if humanoid.Health <= 0 then return nil end
	return {
		player = player,
		character = char,
		humanoid = humanoid,
		rootPart = root,
		head = head
	}
end

local function isTeammate(player)
	if not player then return false end
	if not player.Parent then return false end
	return player.Team == LocalPlayer.Team
end

local function worldToViewport(pos)
	local screen, onScreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(screen.X, screen.Y), onScreen, screen.Z
end

local function getDistance(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

--// Wall Check Function
local function isVisible(targetPart, ignoreList)
	local _, _, localRoot = getLocalParts()
	if not localRoot then return false end
	
	ignoreList = ignoreList or {}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera, unpack(ignoreList)}
	rayParams.IgnoreWater = true
	
	local origin = Camera.CFrame.Position
	local direction = (targetPart.Position - origin)
	local result = Workspace:Raycast(origin, direction, rayParams)
	
	if not result then return true end
	return result.Instance:IsDescendantOf(targetPart.Parent)
end

--// Get Prediction Position
local function getPredictionPosition(targetPart, prediction)
	if not targetPart then return nil end
	local velocity = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
	return targetPart.Position + (velocity * prediction)
end

-- Wait for character to load initially
repeat task.wait() until LocalPlayer.Character
repeat task.wait() until LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

--// GUI Library (Kavo)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("SSC3", "BloodTheme")

--// Configuration Storage
local Config = {
	Aimbot = {
		Enabled = false,
		Target = nil,
		Smoothness = 0.15,
		FOV = 100,
		Range = 1000,
		AimPart = "Head",
		Active = false,
		DrawFOV = false,
		FOVColor = Color3.fromRGB(255, 255, 255),
		Prediction = 0.165,
		HitboxScale = 1.0,
		TeamCheck = false,
		VisibleCheck = false,
	    Keybind = Enum.UserInputType.MouseButton2
	},
	ESP = {
    Enabled = false,

    Names = false,
    Distance = false,
    Health = false,

    Boxes = false,
    BoxColor = Color3.fromRGB(255, 0, 0),
    BoxOutline = false,

    HealthBar = false,

    Tracers = false,
    TracerColor = Color3.fromRGB(0, 255, 0),

    Skeleton = false,

    TeamCheck = false,
    VisibleCheck = false,

    Chams = false,
    ChamsColor = Color3.fromRGB(255, 0, 0),
    ChamsOutlineColor = Color3.fromRGB(0, 0, 0),

    TextScale = false
    },

	Misc = {
		Fly = false,
		FlySpeed = 50,
		JumpPower = 50,
		NoFall = false,
		WalkSpeed = 16,
		InfiniteJump = false,
		AntiAFK = false,
		SpeedBypass = false
	}
}



--//==================================================
--// ESP SYSTEM
--//==================================================

local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "ESPSystem"
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ESPGui.Parent = CoreGui

local ESPObjects = {}

--//==================================================
--// SKELETON FUNCTIONS
--// These MUST be outside updateESP()
--//==================================================

local function removeSkeleton(skeleton)
	if not skeleton then
		return
	end

	for _, data in ipairs(skeleton) do
		if data.beam then
			data.beam:Destroy()
		end

		if data.attachment0 then
			data.attachment0:Destroy()
		end

		if data.attachment1 then
			data.attachment1:Destroy()
		end
	end
end

local function createSkeleton(character)
	if not character then
		return nil
	end

	local skeleton = {}

	-- R15 + R6 connections
	local connections = {
		-- R15 body
		{"Head", "UpperTorso"},
		{"UpperTorso", "LowerTorso"},

		-- Left arm
		{"UpperTorso", "LeftUpperArm"},
		{"LeftUpperArm", "LeftLowerArm"},
		{"LeftLowerArm", "LeftHand"},

		-- Right arm
		{"UpperTorso", "RightUpperArm"},
		{"RightUpperArm", "RightLowerArm"},
		{"RightLowerArm", "RightHand"},

		-- Left leg
		{"LowerTorso", "LeftUpperLeg"},
		{"LeftUpperLeg", "LeftLowerLeg"},
		{"LeftLowerLeg", "LeftFoot"},

		-- Right leg
		{"LowerTorso", "RightUpperLeg"},
		{"RightUpperLeg", "RightLowerLeg"},
		{"RightLowerLeg", "RightFoot"},

		-- R6
		{"Torso", "Head"},
		{"Torso", "Left Arm"},
		{"Torso", "Right Arm"},
		{"Torso", "Left Leg"},
		{"Torso", "Right Leg"}
	}

	for _, connection in ipairs(connections) do
		local part0 = character:FindFirstChild(connection[1])
		local part1 = character:FindFirstChild(connection[2])

		if part0 and part1
			and part0:IsA("BasePart")
			and part1:IsA("BasePart") then

			local attachment0 = Instance.new("Attachment")
			attachment0.Name = "DashClient_Skeleton_A"
			attachment0.Parent = part0

			local attachment1 = Instance.new("Attachment")
			attachment1.Name = "DashClient_Skeleton_B"
			attachment1.Parent = part1

			local beam = Instance.new("Beam")
			beam.Name = "DashClient_Skeleton_Beam"

			beam.Attachment0 = attachment0
			beam.Attachment1 = attachment1

			beam.Width0 = 0.06
			beam.Width1 = 0.06

			beam.FaceCamera = true
			beam.LightEmission = 1

			beam.Transparency = NumberSequence.new(0)

			beam.Color = ColorSequence.new(
				Config.ESP.BoxColor
			)

			beam.Enabled = false

			beam.Parent = part0

			table.insert(skeleton, {
				beam = beam,
				attachment0 = attachment0,
				attachment1 = attachment1
			})
		end
	end

	return skeleton
end

local function updateSkeleton(skeleton, color, enabled)
	if not skeleton then
		return
	end

	for _, data in ipairs(skeleton) do
		if data.beam
			and data.beam.Parent then

			data.beam.Color =
				ColorSequence.new(color)

			data.beam.Enabled = enabled
		end
	end
end

--//==================================================
--// 3D BOX FUNCTIONS
--//==================================================

local function create3DBox(character)
	if not character then
		return nil
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		return nil
	end

	-- Get the REAL bounding box of the entire character
	local boundingCFrame, boundingSize =
		character:GetBoundingBox()

	-- Convert the bounding box position
	-- into the HRP's local space.
	local relativeCFrame =
		root.CFrame:ToObjectSpace(
			boundingCFrame
		)

	local box =
		Instance.new("BoxHandleAdornment")

	box.Name =
		"DashClient_3DBox"

	box.Adornee = root

	box.Size =
		boundingSize

	box.CFrame =
		relativeCFrame

	box.AlwaysOnTop = true
	box.ZIndex = 5

	box.Transparency = 1

	box.Color3 =
		Config.ESP.BoxColor

	box.Visible = true

	box.Parent = root

	return box
end

local function update3DBox(box, character)
	if not box then
		return
	end

	if not character then
		box.Visible = false
		return
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		box.Visible = false
		return
	end

	local boundingCFrame, boundingSize =
		character:GetBoundingBox()

	local relativeCFrame =
		root.CFrame:ToObjectSpace(
			boundingCFrame
		)

	box.Adornee = root
	box.Size = boundingSize
	box.CFrame = relativeCFrame

	box.Color3 =
		Config.ESP.BoxColor

	box.AlwaysOnTop = true

	box.Transparency =
		Config.ESP.BoxOutline
		and 0.90
		or 0.80

	box.Visible = true
end

local function remove3DBox(box)
	if box then
		box:Destroy()
	end
end

--//==================================================
--// ESP CREATION
--//==================================================

local function createESP(player)
	if not player then
		return
	end

	if ESPObjects[player] then
		return
	end

	local main = Instance.new("Frame")

	main.Name =
		player.Name .. "_ESP"

	main.BackgroundTransparency = 1
	main.BorderSizePixel = 0

	main.Size =
		UDim2.new(1, 0, 1, 0)

	main.Position =
		UDim2.new(0, 0, 0, 0)

	main.Visible = false
	main.Parent = ESPGui

	--// 2D BOX
	local box = Instance.new("Frame")

	box.Name = "Box"

	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0

	box.Visible = false
	box.Parent = main

	local stroke = Instance.new("UIStroke")

	stroke.Thickness = 1.5

	stroke.Color =
		Config.ESP.BoxColor

	stroke.ApplyStrokeMode =
		Enum.ApplyStrokeMode.Border

	stroke.Parent = box

	--// NAME
	local name = Instance.new("TextLabel")

	name.Name = "Name"

	name.BackgroundTransparency = 1

	name.Size =
		UDim2.new(0, 250, 0, 18)

	name.AnchorPoint =
		Vector2.new(0.5, 1)

	name.Font =
		Enum.Font.GothamBold

	name.TextSize = 13

	name.TextColor3 =
		Config.ESP.BoxColor

	name.TextStrokeTransparency = 0.80

	name.TextStrokeColor3 =
		Color3.new(0, 0, 0)

	name.Text =
		player.Name

	name.Visible = false

	name.Parent = main

	--// DISTANCE
	local dist = Instance.new("TextLabel")

	dist.Name = "Dist"

	dist.BackgroundTransparency = 1

	dist.Size =
		UDim2.new(0, 150, 0, 16)

	dist.AnchorPoint =
		Vector2.new(0.5, 0)

	dist.Font =
		Enum.Font.Gotham

	dist.TextSize = 11

	dist.TextColor3 =
		Color3.new(1, 1, 1)

	dist.TextStrokeTransparency = 0.80

	dist.TextStrokeColor3 =
		Color3.new(0, 0, 0)

	dist.Visible = false

	dist.Parent = main

	--// HEALTH TEXT
	local hpText = Instance.new("TextLabel")

	hpText.Name = "HPText"

	hpText.BackgroundTransparency = 1

	hpText.Size =
		UDim2.new(0, 70, 0, 16)

	hpText.AnchorPoint =
		Vector2.new(0, 0.5)

	hpText.Font =
		Enum.Font.GothamBold

	hpText.TextSize = 11

	hpText.TextColor3 =
		Color3.new(1, 1, 1)

	hpText.TextStrokeTransparency = 0.80

	hpText.TextStrokeColor3 =
		Color3.new(0, 0, 0)

	hpText.Visible = false

	hpText.Parent = main

	--// HEALTH BAR BACKGROUND
	local hpBg = Instance.new("Frame")

	hpBg.Name = "HPBg"

	hpBg.BorderSizePixel = 0

	hpBg.BackgroundColor3 =
		Color3.fromRGB(40, 40, 40)

	hpBg.Size =
		UDim2.new(0, 4, 0, 100)

	hpBg.Visible = false

	hpBg.Parent = main

	--// HEALTH BAR
	local hpBar = Instance.new("Frame")

	hpBar.Name = "HPBar"

	hpBar.BorderSizePixel = 0

	hpBar.BackgroundColor3 =
		Color3.fromRGB(0, 255, 0)

	hpBar.AnchorPoint =
		Vector2.new(0, 1)

	hpBar.Position =
		UDim2.new(0, 0, 1, 0)

	hpBar.Size =
		UDim2.new(1, 0, 1, 0)

	hpBar.Parent = hpBg

	--// TRACER
	local tracer = Instance.new("Frame")

	tracer.Name = "Tracer"

	tracer.BorderSizePixel = 0

	tracer.BackgroundColor3 =
		Config.ESP.TracerColor

	tracer.AnchorPoint =
		Vector2.new(0.5, 0)

	tracer.Visible = false

	tracer.Parent = main

	--// SAVE EVERYTHING
	ESPObjects[player] = {

		main = main,

		box = box,
		stroke = stroke,

		name = name,
		dist = dist,

		hpText = hpText,

		hpBg = hpBg,
		hpBar = hpBar,

		tracer = tracer,

		-- 3D
		box3D = nil,

		-- Skeleton
		skeleton = nil,
		skeletonCharacter = nil
	}
end

--//==================================================
--// ESP REMOVAL
--//==================================================

local function removeESP(player)
	local obj =
		ESPObjects[player]

	if not obj then
		return
	end

	-- Remove skeleton
	if obj.skeleton then
		removeSkeleton(
			obj.skeleton
		)

		obj.skeleton = nil
	end

	-- Remove 3D box
	if obj.box3D then
		remove3DBox(
			obj.box3D
		)

		obj.box3D = nil
	end

	-- Remove GUI
	if obj.main then
		obj.main:Destroy()
	end

	ESPObjects[player] = nil
end

--//==================================================
--// ESP UPDATE
--//==================================================

local function updateESP()

	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end

	local _, _, localRoot =
		getLocalParts()

	if not localRoot then
		return
	end

	for player, obj in pairs(ESPObjects) do

		--==================================================
		-- MASTER ESP TOGGLE
		--==================================================

		if not Config.ESP.Enabled then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		--==================================================
		-- PLAYER VALIDATION
		--==================================================

		if not player
			or not player.Parent then

			removeESP(player)
			continue
		end

		local info =
			getPlayerInfo(player)

		if not info then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		--==================================================
		-- TEAM CHECK
		--==================================================

		if Config.ESP.TeamCheck
			and isTeammate(player) then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		--==================================================
		-- VISIBLE CHECK
		--==================================================

		if Config.ESP.VisibleCheck
			and not isVisible(
				info.rootPart,
				{info.character}
			) then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		local character =
			info.character

		local humanoid =
			info.humanoid

		local root =
			info.rootPart

		local head =
			info.head

		--==================================================
		-- SCREEN POSITION
		--==================================================

		local rootPoint, rootOnScreen =
			worldToViewport(
				root.Position
			)

		local headPoint, headOnScreen =
			worldToViewport(
				head.Position +
				Vector3.new(0, 0.5, 0)
			)

		if not rootOnScreen
			and not headOnScreen then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			continue
		end

		obj.main.Visible = true

		local boxColor =
			Config.ESP.BoxColor

		--==================================================
		-- 3D BOX
		--==================================================

		if Config.ESP.Boxes then

			if not obj.box3D
				or not obj.box3D.Parent then

				if obj.box3D then
					remove3DBox(
						obj.box3D
					)
				end

				obj.box3D =
					create3DBox(
						character
					)
			end

			update3DBox(
				obj.box3D,
				character
			)

		else

			if obj.box3D then
				obj.box3D.Visible = false
			end
		end

		--==================================================
		-- NAME
		--==================================================

		if Config.ESP.Names then

			obj.name.Visible = true

			obj.name.Text =
				player.Name

			obj.name.TextColor3 =
				boxColor

			obj.name.Position =
				UDim2.fromOffset(
					headPoint.X,
					headPoint.Y - 10
				)

		else

			obj.name.Visible = false
		end

		--==================================================
		-- DISTANCE
		--==================================================

		local distance =
			getDistance(
				localRoot.Position,
				root.Position
			)

		if Config.ESP.Distance then

			obj.dist.Visible = true

			obj.dist.Text =
				math.floor(distance)
				.. " studs"

			obj.dist.Position =
				UDim2.fromOffset(
					rootPoint.X,
					rootPoint.Y + 10
				)

		else

			obj.dist.Visible = false
		end

		--==================================================
		-- HEALTH
		--==================================================

		local health =
			math.max(
				humanoid.Health,
				0
			)

		local maxHealth =
			math.max(
				humanoid.MaxHealth,
				1
			)

		local healthPercent =
			math.clamp(
				health / maxHealth,
				0,
				1
			)

		if Config.ESP.Health then

			obj.hpText.Visible = true

			obj.hpText.Text =
				math.floor(health)
				.. " HP"

			obj.hpText.TextColor3 =
				boxColor

			obj.hpText.Position =
				UDim2.fromOffset(
					headPoint.X + 45,
					headPoint.Y
				)

		else

			obj.hpText.Visible = false
		end

		--==================================================
		-- HEALTH BAR
		--==================================================

		if Config.ESP.HealthBar then

			obj.hpBg.Visible = true

			obj.hpBg.Position =
				UDim2.fromOffset(
					rootPoint.X - 45,
					rootPoint.Y - 50
				)

			obj.hpBar.Size =
				UDim2.new(
					1,
					0,
					healthPercent,
					0
				)

			obj.hpBar.Position =
				UDim2.new(
					0,
					0,
					1,
					0
				)

			obj.hpBar.BackgroundColor3 =
				Color3.new(
					1 - healthPercent,
					healthPercent,
					0
				)

		else

			obj.hpBg.Visible = false
		end

		--==================================================
		-- TRACER
		--==================================================

		if Config.ESP.Tracers then

			obj.tracer.Visible = true

			local viewport =
				camera.ViewportSize

			local startPoint =
				Vector2.new(
					viewport.X / 2,
					viewport.Y
				)

			local endPoint =
				rootPoint

			local difference =
				endPoint - startPoint

			local length =
				difference.Magnitude

			obj.tracer.Position =
				UDim2.fromOffset(
					startPoint.X,
					startPoint.Y
				)

			obj.tracer.Size =
				UDim2.fromOffset(
					2,
					length
				)

			obj.tracer.Rotation =
				math.deg(
					math.atan2(
						difference.Y,
						difference.X
					)
				) + 90

			obj.tracer.BackgroundColor3 =
				Config.ESP.TracerColor

		else

			obj.tracer.Visible = false
		end

		--==================================================
		-- SKELETON
		--==================================================

		if Config.ESP.Skeleton then

			-- Character changed / respawned
			if obj.skeletonCharacter
				~= character then

				if obj.skeleton then

					removeSkeleton(
						obj.skeleton
					)
				end

				obj.skeleton =
					createSkeleton(
						character
					)

				obj.skeletonCharacter =
					character
			end

			updateSkeleton(
				obj.skeleton,
				boxColor,
				true
			)

		else

			if obj.skeleton then

				updateSkeleton(
					obj.skeleton,
					boxColor,
					false
				)
			end
		end
	end
end
--// Aimbot Module
local Aimbot = {
	Target = nil,
	Holding = false
}

function Aimbot:FindTarget()
	if not Config.Aimbot.Enabled then return nil end
	if not self.Holding then return nil end
	
	local closest = nil
	local closestDist = math.huge
	local _, _, localRoot = getLocalParts()
	if not localRoot then return nil end
	
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	
	for _, p in pairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		
		local info = getPlayerInfo(p)
		if not info then continue end
		if Config.Aimbot.TeamCheck and isTeammate(p) then continue end
		
		local part = info.character:FindFirstChild(Config.Aimbot.AimPart) or info.head
		if not part then continue end
		
		local dist = getDistance(localRoot.Position, part.Position)
		if dist > Config.Aimbot.Range then continue end
		
		local screen, onScreen = worldToViewport(part.Position)
		if not onScreen then continue end
		
		local fromCenter = (screen - center).Magnitude
		if fromCenter > Config.Aimbot.FOV then continue end
		
		if dist < closestDist then
			closestDist = dist
			closest = p
		end
	end
	
	return closest
end

function Aimbot:AimAt(target)
	local info = getPlayerInfo(target)
	if not info then return end
	
	local part = info.character:FindFirstChild(Config.Aimbot.AimPart) or info.head
	if not part then return end
	
	local pos = part.Position
	local velocity = part.AssemblyLinearVelocity or part.Velocity or Vector3.zero
	pos = pos + (velocity * Config.Aimbot.Prediction)
	
	local targetCF = CFrame.new(Camera.CFrame.Position, pos)
	Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.Aimbot.Smoothness)
end

--// Input Handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Config.Aimbot.Keybind then
		Aimbot.Holding = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Config.Aimbot.Keybind then
		Aimbot.Holding = false
	end
end)

--// RenderStepped (put this in your main loop)
RunService.RenderStepped:Connect(function()
	if Config.Aimbot.Enabled then
		Aimbot.Target = Aimbot:FindTarget()
		if Aimbot.Target then
			Aimbot:AimAt(Aimbot.Target)
		end
	end
end)
--// Misc Module
local Misc = {  
	FlyActive = false,  
	OrigWalk = 16,  
	OrigJump = 50,  
	NoclipConnection = nil  
}  

function Misc:SetupFly()
	local _, hum, root = getLocalParts()
	if not hum or not root then return end
	
	local vel = Instance.new("BodyVelocity")
	vel.Name = "FlyVel"
	vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	vel.Velocity = Vector3.zero
	vel.Parent = root
	
	local gyro = Instance.new("BodyGyro")
	gyro.Name = "FlyGyro"
	gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	gyro.P = 9e4
	gyro.Parent = root
	
	hum.PlatformStand = true
	self.FlyActive = true
end

function Misc:CleanupFly()
	local _, hum, root = getLocalParts()
	if root then
		local v = root:FindFirstChild("FlyVel")
		local g = root:FindFirstChild("FlyGyro")
		if v then v:Destroy() end
		if g then g:Destroy() end
	end
	if hum then hum.PlatformStand = false end
	self.FlyActive = false
end

function Misc:UpdateFly()
	local _, hum, root = getLocalParts()
	if not hum or not root then return end
	
	if Config.Misc.Fly then
		if not self.FlyActive then
			self.OrigWalk = hum.WalkSpeed
			self.OrigJump = hum.JumpPower
			self:SetupFly()
		end
		
		local dir = Vector3.zero
		
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
		
		if dir.Magnitude > 0 then dir = dir.Unit * Config.Misc.FlySpeed end
		
		local v = root:FindFirstChild("FlyVel")
		local g = root:FindFirstChild("FlyGyro")
		if v then v.Velocity = dir end
		if g then g.CFrame = Camera.CFrame end
	else
		if self.FlyActive then
			self:CleanupFly()
			hum.WalkSpeed = self.OrigWalk
			hum.JumpPower = self.OrigJump
		end
	end
end

function Misc:UpdateStats()
	local _, hum = getLocalParts()
	if not hum then return end
	
	if Config.Misc.SpeedBypass then
		-- Use heartbeat to constantly reset speed (bypasses some detections)
		hum.WalkSpeed = Config.Misc.WalkSpeed
	else
		hum.WalkSpeed = Config.Misc.WalkSpeed
	end
	
	hum.JumpPower = Config.Misc.JumpPower
end

local jumpConn = nil
function Misc:UpdateInfiniteJump()
	if Config.Misc.InfiniteJump then
		if not jumpConn then
			jumpConn = UserInputService.JumpRequest:Connect(function()
				local _, h = getLocalParts()
				if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
			end)
		end
	elseif jumpConn then
		jumpConn:Disconnect()
		jumpConn = nil
	end
end

function Misc:UpdateAntiAFK()
	if Config.Misc.AntiAFK then
		if not self.AFKConnection then
			self.AFKConnection = LocalPlayer.Idled:Connect(function()
				local VirtualUser = game:GetService("VirtualUser")
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	elseif self.AFKConnection then
		self.AFKConnection:Disconnect()
		self.AFKConnection = nil
	end
end

--// UI Setup
local aimTab = Window:NewTab("Aimbot")
local aimSec = aimTab:NewSection("Settings")

aimSec:NewToggle("Enabled", "Toggle aimbot", function(v) Config.Aimbot.Enabled = v end)
aimSec:NewSlider("Smoothness", "Aim smoothness (higher = smoother)", 1, 100, function(v) Config.Aimbot.Smoothness = v/100 end)
aimSec:NewSlider("FOV", "Aimbot FOV", 10, 500, function(v) Config.Aimbot.FOV = v end)
aimSec:NewSlider("Range", "Max range", 50, 2000, function(v) Config.Aimbot.Range = v end)
aimSec:NewSlider("Prediction", "Movement prediction", 0, 50, function(v) Config.Aimbot.Prediction = v/100 end)
aimSec:NewTextBox("Aim Part", "Head, HumanoidRootPart", function(v) Config.Aimbot.AimPart = v end)
aimSec:NewToggle("Draw FOV", "Show FOV circle", function(v) Config.Aimbot.DrawFOV = v end)
aimSec:NewColorPicker("FOV Color", "", Config.Aimbot.FOVColor, function(c) Config.Aimbot.FOVColor = c end)
aimSec:NewToggle("Team Check", "Ignore teammates", function(v) Config.Aimbot.TeamCheck = v end)
aimSec:NewToggle("Visible Check", "Only aim at visible targets", function(v) Config.Aimbot.VisibleCheck = v end)

local espTab = Window:NewTab("ESP")
local espSec = espTab:NewSection("Settings")

espSec:NewToggle("Enabled", "Master ESP toggle", function(v) Config.ESP.Enabled = v end)

espSec:NewToggle("Boxes", "Show player boxes", function(v) Config.ESP.Boxes = v end)
espSec:NewToggle("Box Outline", "Corner style boxes", function(v) Config.ESP.BoxOutline = v end)
espSec:NewColorPicker("Box Color", "", Config.ESP.BoxColor, function(c) Config.ESP.BoxColor = c end)

espSec:NewToggle("Names", "Show player names", function(v) Config.ESP.Names = v end)
espSec:NewToggle("Distance", "Show distance", function(v) Config.ESP.Distance = v end)
espSec:NewToggle("Health Bar", "Show health bar", function(v) Config.ESP.HealthBar = v end)

espSec:NewToggle("Tracers", "Lines to players", function(v) Config.ESP.Tracers = v end)
espSec:NewColorPicker("Tracer Color", "", Config.ESP.TracerColor, function(c) Config.ESP.TracerColor = c end)

espSec:NewToggle("Chams", "See through walls", function(v) Config.ESP.Chams = v end)
espSec:NewColorPicker("Chams Fill", "", Config.ESP.ChamsColor, function(c) Config.ESP.ChamsColor = c end)
espSec:NewColorPicker("Chams Outline", "", Config.ESP.ChamsOutlineColor, function(c) Config.ESP.ChamsOutlineColor = c end)

espSec:NewToggle("Team Check", "Ignore teammates", function(v) Config.ESP.TeamCheck = v end)
espSec:NewToggle("Visible Check", "Only show visible", function(v) Config.ESP.VisibleCheck = v end)
espSec:NewToggle("Skeleton ESP", "Skeleton of roblox character", function(v) Config.ESP.Skeleton = v end)

local miscTab = Window:NewTab("Misc")
local miscSec = miscTab:NewSection("Settings")

miscSec:NewToggle("Fly", "Enable flight", function(v) Config.Misc.Fly = v end)
miscSec:NewSlider("Fly Speed", "", 10, 200, function(v) Config.Misc.FlySpeed = v end)
miscSec:NewSlider("Walk Speed", "", 16, 200, function(v) Config.Misc.WalkSpeed = v; Misc:UpdateStats() end)
miscSec:NewSlider("Jump Power", "", 50, 200, function(v) Config.Misc.JumpPower = v; Misc:UpdateStats() end)
miscSec:NewToggle("Infinite Jump", "", function(v) Config.Misc.InfiniteJump = v; Misc:UpdateInfiniteJump() end)
miscSec:NewToggle("No Fall", "Prevent ragdoll", function(v) Config.Misc.NoFall = v end)
miscSec:NewToggle("Anti AFK", "Prevent idle kick", function(v) Config.Misc.AntiAFK = v; Misc:UpdateAntiAFK() end)
miscSec:NewToggle("Speed Bypass", "Try to bypass speed detect", function(v) Config.Misc.SpeedBypass = v end)
miscSec:NewToggle("Noclip", "Go thru walls", function(v) Config.Misc.Noclip = v end)
miscSec:NewSlider("Head Expander", "", 1, 50, function (v)Config.Misc.HeadExpanders = v end)
--// Player Management
Players.PlayerAdded:Connect(function(p)
	if p ~= LocalPlayer then
		createESP(p)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	removeESP(p)
end)

for _, p in pairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then createESP(p) end
end

--// Character Respawn Handling
LocalPlayer.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	Misc.FlyActive = false
	Misc:CleanupFly()
	Misc:UpdateStats()
end)

--// Main Loop
Misc:UpdateStats()
Misc:UpdateInfiniteJump()
Misc:UpdateAntiAFK()

RunService.RenderStepped:Connect(function()
	updateFOV()
	
	-- Aimbot
	if Config.Aimbot.Enabled and Aimbot.Holding then
		local target = Aimbot:FindTarget()
		if target then
			Aimbot.Target = target
			Aimbot.LastTarget = target
			Aimbot:AimAt(target)
		end
	else
		Aimbot.Target = nil
		if not Aimbot.Holding then
			Aimbot.LastTarget = nil
		end
	end
	
	updateESP()
	Misc:UpdateFly()
	
	local _, hum = getLocalParts()
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not Config.Misc.NoFall)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not Config.Misc.NoFall)
		
		if Config.Misc.SpeedBypass then
			hum.WalkSpeed = Config.Misc.WalkSpeed
		end
	end
end)
--// Noclip Variables
local NoclipConnection = nil

--// Noclip Function
local function updateNoclip()
	if Config.Misc.Noclip then
		if not NoclipConnection then
			NoclipConnection = RunService.Stepped:Connect(function()
				local char = LocalPlayer.Character
				if char then
					for _, part in pairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end)
		end
	elseif NoclipConnection then
		NoclipConnection:Disconnect()
		NoclipConnection = nil
		-- Re-enable collision
		local char = LocalPlayer.Character
		if char then
			for _, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
			-- Keep HRP non-colliding for normal movement
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CanCollide = false end
		end
	end
end

--// Add to your RenderStepped or create a new connection
RunService.RenderStepped:Connect(function()
	if Config.Misc.Noclip then
		updateNoclip()
	end
end)

--// Character respawn handling
LocalPlayer.CharacterAdded:Connect(function(char)
	if Config.Misc.Noclip then
		task.wait(0.1)
		updateNoclip()
	end
end)
function Misc:UpdateNoclip()
	if Config.Misc.Noclip then
		if not self.NoclipConnection then
			self.NoclipConnection = RunService.Stepped:Connect(function()
				local char = LocalPlayer.Character
				if not char then return end
				for _, part in pairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end)
		end
	elseif self.NoclipConnection then
		self.NoclipConnection:Disconnect()
		self.NoclipConnection = nil
	end
end
--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
--// Head expanders
local HeadConnections = {}

--// Local Player & Variables
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--// ESP Chams Storage
local ChamsObjects = {}

--// Helper Functions
local function getLocalParts()
	local char = LocalPlayer.Character
	if not char then return nil, nil, nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	return char, humanoid, root
end

local function getPlayerInfo(player)
	if not player or player == LocalPlayer then return nil end
	if not player.Parent then return nil end
	local char = player.Character
	if not char then return nil end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not humanoid or not root or not head then return nil end
	if humanoid.Health <= 0 then return nil end
	return {
		player = player,
		character = char,
		humanoid = humanoid,
		rootPart = root,
		head = head
	}
end

local function isTeammate(player)
	if not player then return false end
	if not player.Parent then return false end
	return player.Team == LocalPlayer.Team
end

local function worldToViewport(pos)
	local screen, onScreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(screen.X, screen.Y), onScreen, screen.Z
end

local function getDistance(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

--// Wall Check Function
local function isVisible(targetPart, ignoreList)
	local _, _, localRoot = getLocalParts()
	if not localRoot then return false end
	
	ignoreList = ignoreList or {}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera, unpack(ignoreList)}
	rayParams.IgnoreWater = true
	
	local origin = Camera.CFrame.Position
	local direction = (targetPart.Position - origin)
	local result = Workspace:Raycast(origin, direction, rayParams)
	
	if not result then return true end
	return result.Instance:IsDescendantOf(targetPart.Parent)
end

--// Get Prediction Position
local function getPredictionPosition(targetPart, prediction)
	if not targetPart then return nil end
	local velocity = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
	return targetPart.Position + (velocity * prediction)
end

-- Wait for character to load initially
repeat task.wait() until LocalPlayer.Character
repeat task.wait() until LocalPlayer.Character:FindFirstChild("HumanoidRootPart")



--// FOV Circle
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Filled = false

local function updateFOV()
	FOVCircle.Visible = Config.Aimbot.DrawFOV and Config.Aimbot.Enabled
	if FOVCircle.Visible then
		FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		FOVCircle.Radius = Config.Aimbot.FOV
		FOVCircle.Color = Config.Aimbot.FOVColor
	end
end

--//==================================================
--// ESP SYSTEM
--//==================================================

local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "ESPSystem"
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ESPGui.Parent = CoreGui

local ESPObjects = {}

--//==================================================
--// SKELETON FUNCTIONS
--// These MUST be outside updateESP()
--//==================================================

local function removeSkeleton(skeleton)
	if not skeleton then
		return
	end

	for _, data in ipairs(skeleton) do
		if data.beam then
			data.beam:Destroy()
		end

		if data.attachment0 then
			data.attachment0:Destroy()
		end

		if data.attachment1 then
			data.attachment1:Destroy()
		end
	end
end

local function createSkeleton(character)
	if not character then
		return nil
	end

	local skeleton = {}

	-- R15 + R6 connections
	local connections = {
		-- R15 body
		{"Head", "UpperTorso"},
		{"UpperTorso", "LowerTorso"},

		-- Left arm
		{"UpperTorso", "LeftUpperArm"},
		{"LeftUpperArm", "LeftLowerArm"},
		{"LeftLowerArm", "LeftHand"},

		-- Right arm
		{"UpperTorso", "RightUpperArm"},
		{"RightUpperArm", "RightLowerArm"},
		{"RightLowerArm", "RightHand"},

		-- Left leg
		{"LowerTorso", "LeftUpperLeg"},
		{"LeftUpperLeg", "LeftLowerLeg"},
		{"LeftLowerLeg", "LeftFoot"},

		-- Right leg
		{"LowerTorso", "RightUpperLeg"},
		{"RightUpperLeg", "RightLowerLeg"},
		{"RightLowerLeg", "RightFoot"},

		-- R6
		{"Torso", "Head"},
		{"Torso", "Left Arm"},
		{"Torso", "Right Arm"},
		{"Torso", "Left Leg"},
		{"Torso", "Right Leg"}
	}

	for _, connection in ipairs(connections) do
		local part0 = character:FindFirstChild(connection[1])
		local part1 = character:FindFirstChild(connection[2])

		if part0 and part1
			and part0:IsA("BasePart")
			and part1:IsA("BasePart") then

			local attachment0 = Instance.new("Attachment")
			attachment0.Name = "DashClient_Skeleton_A"
			attachment0.Parent = part0

			local attachment1 = Instance.new("Attachment")
			attachment1.Name = "DashClient_Skeleton_B"
			attachment1.Parent = part1

			local beam = Instance.new("Beam")
			beam.Name = "DashClient_Skeleton_Beam"

			beam.Attachment0 = attachment0
			beam.Attachment1 = attachment1

			beam.Width0 = 0.06
			beam.Width1 = 0.06

			beam.FaceCamera = true
			beam.LightEmission = 1

			beam.Transparency = NumberSequence.new(0)

			beam.Color = ColorSequence.new(
				Config.ESP.BoxColor
			)

			beam.Enabled = false

			beam.Parent = part0

			table.insert(skeleton, {
				beam = beam,
				attachment0 = attachment0,
				attachment1 = attachment1
			})
		end
	end

	return skeleton
end

local function updateSkeleton(skeleton, color, enabled)
	if not skeleton then
		return
	end

	for _, data in ipairs(skeleton) do
		if data.beam
			and data.beam.Parent then

			data.beam.Color =
				ColorSequence.new(color)

			data.beam.Enabled = enabled
		end
	end
end

--//==================================================
--// 3D BOX FUNCTIONS
--//==================================================

local function create3DBox(character)
	if not character then
		return nil
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		return nil
	end

	-- Get the REAL bounding box of the entire character
	local boundingCFrame, boundingSize =
		character:GetBoundingBox()

	-- Convert the bounding box position
	-- into the HRP's local space.
	local relativeCFrame =
		root.CFrame:ToObjectSpace(
			boundingCFrame
		)

	local box =
		Instance.new("BoxHandleAdornment")

	box.Name =
		"DashClient_3DBox"

	box.Adornee = root

	box.Size =
		boundingSize

	box.CFrame =
		relativeCFrame

	box.AlwaysOnTop = true
	box.ZIndex = 5

	box.Transparency = 0.80

	box.Color3 =
		Config.ESP.BoxColor

	box.Visible = true

	box.Parent = root

	return box
end

local function update3DBox(box, character)
	if not box then
		return
	end

	if not character then
		box.Visible = false
		return
	end

	local root =
		character:FindFirstChild(
			"HumanoidRootPart"
		)

	if not root then
		box.Visible = false
		return
	end

	local boundingCFrame, boundingSize =
		character:GetBoundingBox()

	local relativeCFrame =
		root.CFrame:ToObjectSpace(
			boundingCFrame
		)

	box.Adornee = root
	box.Size = boundingSize
	box.CFrame = relativeCFrame

	box.Color3 =
		Config.ESP.BoxColor

	box.AlwaysOnTop = true

	box.Transparency =
		Config.ESP.BoxOutline
		and 0.90
		or 0.80

	box.Visible = true
end

local function remove3DBox(box)
	if box then
		box:Destroy()
	end
end

--//==================================================
--// ESP CREATION
--//==================================================

local function createESP(player)
	if not player then
		return
	end

	if ESPObjects[player] then
		return
	end

	local main = Instance.new("Frame")

	main.Name =
		player.Name .. "_ESP"

	main.BackgroundTransparency = 1
	main.BorderSizePixel = 0

	main.Size =
		UDim2.new(1, 0, 1, 0)

	main.Position =
		UDim2.new(0, 0, 0, 0)

	main.Visible = false
	main.Parent = ESPGui

	--// 2D BOX
	local box = Instance.new("Frame")

	box.Name = "Box"

	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0

	box.Visible = false
	box.Parent = main

	local stroke = Instance.new("UIStroke")

	stroke.Thickness = 1.5

	stroke.Color =
		Config.ESP.BoxColor

	stroke.ApplyStrokeMode =
		Enum.ApplyStrokeMode.Border

	stroke.Parent = box

	--// NAME
	local name = Instance.new("TextLabel")

	name.Name = "Name"

	name.BackgroundTransparency = 1

	name.Size =
		UDim2.new(0, 250, 0, 18)

	name.AnchorPoint =
		Vector2.new(0.5, 1)

	name.Font =
		Enum.Font.GothamBold

	name.TextSize = 13

	name.TextColor3 =
		Config.ESP.BoxColor

	name.TextStrokeTransparency = 0.5

	name.TextStrokeColor3 =
		Color3.new(0, 0, 0)

	name.Text =
		player.Name

	name.Visible = false

	name.Parent = main

	--// DISTANCE
	local dist = Instance.new("TextLabel")

	dist.Name = "Dist"

	dist.BackgroundTransparency = 1

	dist.Size =
		UDim2.new(0, 150, 0, 16)

	dist.AnchorPoint =
		Vector2.new(0.5, 0)

	dist.Font =
		Enum.Font.Gotham

	dist.TextSize = 11

	dist.TextColor3 =
		Color3.new(1, 1, 1)

	dist.TextStrokeTransparency = 0.5

	dist.TextStrokeColor3 =
		Color3.new(0, 0, 0)

	dist.Visible = false

	dist.Parent = main

	--// HEALTH TEXT
	local hpText = Instance.new("TextLabel")

	hpText.Name = "HPText"

	hpText.BackgroundTransparency = 1

	hpText.Size =
		UDim2.new(0, 70, 0, 16)

	hpText.AnchorPoint =
		Vector2.new(0, 0.5)

	hpText.Font =
		Enum.Font.GothamBold

	hpText.TextSize = 11

	hpText.TextColor3 =
		Color3.new(1, 1, 1)

	hpText.TextStrokeTransparency = 0.5

	hpText.TextStrokeColor3 =
		Color3.new(0, 0, 0)

	hpText.Visible = false

	hpText.Parent = main

	--// HEALTH BAR BACKGROUND
	local hpBg = Instance.new("Frame")

	hpBg.Name = "HPBg"

	hpBg.BorderSizePixel = 0

	hpBg.BackgroundColor3 =
		Color3.fromRGB(40, 40, 40)

	hpBg.Size =
		UDim2.new(0, 4, 0, 100)

	hpBg.Visible = false

	hpBg.Parent = main

	--// HEALTH BAR
	local hpBar = Instance.new("Frame")

	hpBar.Name = "HPBar"

	hpBar.BorderSizePixel = 0

	hpBar.BackgroundColor3 =
		Color3.fromRGB(0, 255, 0)

	hpBar.AnchorPoint =
		Vector2.new(0, 1)

	hpBar.Position =
		UDim2.new(0, 0, 1, 0)

	hpBar.Size =
		UDim2.new(1, 0, 1, 0)

	hpBar.Parent = hpBg

	--// TRACER
	local tracer = Instance.new("Frame")

	tracer.Name = "Tracer"

	tracer.BorderSizePixel = 0

	tracer.BackgroundColor3 =
		Config.ESP.TracerColor

	tracer.AnchorPoint =
		Vector2.new(0.5, 0)

	tracer.Visible = false

	tracer.Parent = main

	--// SAVE EVERYTHING
	ESPObjects[player] = {

		main = main,

		box = box,
		stroke = stroke,

		name = name,
		dist = dist,

		hpText = hpText,

		hpBg = hpBg,
		hpBar = hpBar,

		tracer = tracer,

		-- 3D
		box3D = nil,

		-- Skeleton
		skeleton = nil,
		skeletonCharacter = nil
	}
end

--//==================================================
--// ESP REMOVAL
--//==================================================

local function removeESP(player)
	local obj =
		ESPObjects[player]

	if not obj then
		return
	end

	-- Remove skeleton
	if obj.skeleton then
		removeSkeleton(
			obj.skeleton
		)

		obj.skeleton = nil
	end

	-- Remove 3D box
	if obj.box3D then
		remove3DBox(
			obj.box3D
		)

		obj.box3D = nil
	end

	-- Remove GUI
	if obj.main then
		obj.main:Destroy()
	end

	ESPObjects[player] = nil
end

--//==================================================
--// ESP UPDATE
--//==================================================

local function updateESP()

	local camera =
		Workspace.CurrentCamera

	if not camera then
		return
	end

	local _, _, localRoot =
		getLocalParts()

	if not localRoot then
		return
	end

	for player, obj in pairs(ESPObjects) do

		--==================================================
		-- MASTER ESP TOGGLE
		--==================================================

		if not Config.ESP.Enabled then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		--==================================================
		-- PLAYER VALIDATION
		--==================================================

		if not player
			or not player.Parent then

			removeESP(player)
			continue
		end

		local info =
			getPlayerInfo(player)

		if not info then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		--==================================================
		-- TEAM CHECK
		--==================================================

		if Config.ESP.TeamCheck
			and isTeammate(player) then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		--==================================================
		-- VISIBLE CHECK
		--==================================================

		if Config.ESP.VisibleCheck
			and not isVisible(
				info.rootPart,
				{info.character}
			) then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			if obj.skeleton then
				updateSkeleton(
					obj.skeleton,
					Config.ESP.BoxColor,
					false
				)
			end

			continue
		end

		local character =
			info.character

		local humanoid =
			info.humanoid

		local root =
			info.rootPart

		local head =
			info.head

		--==================================================
		-- SCREEN POSITION
		--==================================================

		local rootPoint, rootOnScreen =
			worldToViewport(
				root.Position
			)

		local headPoint, headOnScreen =
			worldToViewport(
				head.Position +
				Vector3.new(0, 0.5, 0)
			)

		if not rootOnScreen
			and not headOnScreen then

			obj.main.Visible = false

			if obj.box3D then
				obj.box3D.Visible = false
			end

			continue
		end

		obj.main.Visible = true

		local boxColor =
			Config.ESP.BoxColor

		--==================================================
		-- 3D BOX
		--==================================================

		if Config.ESP.Boxes then

			if not obj.box3D
				or not obj.box3D.Parent then

				if obj.box3D then
					remove3DBox(
						obj.box3D
					)
				end

				obj.box3D =
					create3DBox(
						character
					)
			end

			update3DBox(
				obj.box3D,
				character
			)

		else

			if obj.box3D then
				obj.box3D.Visible = false
			end
		end

		--==================================================
		-- NAME
		--==================================================

		if Config.ESP.Names then

			obj.name.Visible = true

			obj.name.Text =
				player.Name

			obj.name.TextColor3 =
				boxColor

			obj.name.Position =
				UDim2.fromOffset(
					headPoint.X,
					headPoint.Y - 10
				)

		else

			obj.name.Visible = false
		end

		--==================================================
		-- DISTANCE
		--==================================================

		local distance =
			getDistance(
				localRoot.Position,
				root.Position
			)

		if Config.ESP.Distance then

			obj.dist.Visible = true

			obj.dist.Text =
				math.floor(distance)
				.. " studs"

			obj.dist.Position =
				UDim2.fromOffset(
					rootPoint.X,
					rootPoint.Y + 10
				)

		else

			obj.dist.Visible = false
		end

		--==================================================
		-- HEALTH
		--==================================================

		local health =
			math.max(
				humanoid.Health,
				0
			)

		local maxHealth =
			math.max(
				humanoid.MaxHealth,
				1
			)

		local healthPercent =
			math.clamp(
				health / maxHealth,
				0,
				1
			)

		if Config.ESP.Health then

			obj.hpText.Visible = true

			obj.hpText.Text =
				math.floor(health)
				.. " HP"

			obj.hpText.TextColor3 =
				boxColor

			obj.hpText.Position =
				UDim2.fromOffset(
					headPoint.X + 45,
					headPoint.Y
				)

		else

			obj.hpText.Visible = false
		end

		--==================================================
		-- HEALTH BAR
		--==================================================

		if Config.ESP.HealthBar then

			obj.hpBg.Visible = true

			obj.hpBg.Position =
				UDim2.fromOffset(
					rootPoint.X - 45,
					rootPoint.Y - 50
				)

			obj.hpBar.Size =
				UDim2.new(
					1,
					0,
					healthPercent,
					0
				)

			obj.hpBar.Position =
				UDim2.new(
					0,
					0,
					1,
					0
				)

			obj.hpBar.BackgroundColor3 =
				Color3.new(
					1 - healthPercent,
					healthPercent,
					0
				)

		else

			obj.hpBg.Visible = false
		end

		--==================================================
		-- TRACER
		--==================================================

		if Config.ESP.Tracers then

			obj.tracer.Visible = true

			local viewport =
				camera.ViewportSize

			local startPoint =
				Vector2.new(
					viewport.X / 2,
					viewport.Y
				)

			local endPoint =
				rootPoint

			local difference =
				endPoint - startPoint

			local length =
				difference.Magnitude

			obj.tracer.Position =
				UDim2.fromOffset(
					startPoint.X,
					startPoint.Y
				)

			obj.tracer.Size =
				UDim2.fromOffset(
					2,
					length
				)

			obj.tracer.Rotation =
				math.deg(
					math.atan2(
						difference.Y,
						difference.X
					)
				) + 90

			obj.tracer.BackgroundColor3 =
				Config.ESP.TracerColor

		else

			obj.tracer.Visible = false
		end

		--==================================================
		-- SKELETON
		--==================================================

		if Config.ESP.Skeleton then

			-- Character changed / respawned
			if obj.skeletonCharacter
				~= character then

				if obj.skeleton then

					removeSkeleton(
						obj.skeleton
					)
				end

				obj.skeleton =
					createSkeleton(
						character
					)

				obj.skeletonCharacter =
					character
			end

			updateSkeleton(
				obj.skeleton,
				boxColor,
				true
			)

		else

			if obj.skeleton then

				updateSkeleton(
					obj.skeleton,
					boxColor,
					false
				)
			end
		end
	end
end
--// Aimbot Module
local Aimbot = {
	Target = nil,
	Holding = false
}

function Aimbot:FindTarget()
	if not Config.Aimbot.Enabled then return nil end
	if not self.Holding then return nil end
	
	local closest = nil
	local closestDist = math.huge
	local _, _, localRoot = getLocalParts()
	if not localRoot then return nil end
	
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	
	for _, p in pairs(Players:GetPlayers()) do
		if p == LocalPlayer then continue end
		
		local info = getPlayerInfo(p)
		if not info then continue end
		if Config.Aimbot.TeamCheck and isTeammate(p) then continue end
		
		local part = info.character:FindFirstChild(Config.Aimbot.AimPart) or info.head
		if not part then continue end
		
		local dist = getDistance(localRoot.Position, part.Position)
		if dist > Config.Aimbot.Range then continue end
		
		local screen, onScreen = worldToViewport(part.Position)
		if not onScreen then continue end
		
		local fromCenter = (screen - center).Magnitude
		if fromCenter > Config.Aimbot.FOV then continue end
		
		if dist < closestDist then
			closestDist = dist
			closest = p
		end
	end
	
	return closest
end

function Aimbot:AimAt(target)
	local info = getPlayerInfo(target)
	if not info then return end
	
	local part = info.character:FindFirstChild(Config.Aimbot.AimPart) or info.head
	if not part then return end
	
	local pos = part.Position
	local velocity = part.AssemblyLinearVelocity or part.Velocity or Vector3.zero
	pos = pos + (velocity * Config.Aimbot.Prediction)
	
	local targetCF = CFrame.new(Camera.CFrame.Position, pos)
	Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.Aimbot.Smoothness)
end

--// Input Handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Config.Aimbot.Keybind then
		Aimbot.Holding = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Config.Aimbot.Keybind then
		Aimbot.Holding = false
	end
end)

--// RenderStepped (put this in your main loop)
RunService.RenderStepped:Connect(function()
	if Config.Aimbot.Enabled then
		Aimbot.Target = Aimbot:FindTarget()
		if Aimbot.Target then
			Aimbot:AimAt(Aimbot.Target)
		end
	end
end)
--// Misc Module
local Misc = {  
	FlyActive = false,  
	OrigWalk = 16,  
	OrigJump = 50,  
	NoclipConnection = nil  
}  

function Misc:SetupFly()
	local _, hum, root = getLocalParts()
	if not hum or not root then return end
	
	local vel = Instance.new("BodyVelocity")
	vel.Name = "FlyVel"
	vel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	vel.Velocity = Vector3.zero
	vel.Parent = root
	
	local gyro = Instance.new("BodyGyro")
	gyro.Name = "FlyGyro"
	gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	gyro.P = 9e4
	gyro.Parent = root
	
	hum.PlatformStand = true
	self.FlyActive = true
end

function Misc:CleanupFly()
	local _, hum, root = getLocalParts()
	if root then
		local v = root:FindFirstChild("FlyVel")
		local g = root:FindFirstChild("FlyGyro")
		if v then v:Destroy() end
		if g then g:Destroy() end
	end
	if hum then hum.PlatformStand = false end
	self.FlyActive = false
end

function Misc:UpdateFly()
	local _, hum, root = getLocalParts()
	if not hum or not root then return end
	
	if Config.Misc.Fly then
		if not self.FlyActive then
			self.OrigWalk = hum.WalkSpeed
			self.OrigJump = hum.JumpPower
			self:SetupFly()
		end
		
		local dir = Vector3.zero
		
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
		
		if dir.Magnitude > 0 then dir = dir.Unit * Config.Misc.FlySpeed end
		
		local v = root:FindFirstChild("FlyVel")
		local g = root:FindFirstChild("FlyGyro")
		if v then v.Velocity = dir end
		if g then g.CFrame = Camera.CFrame end
	else
		if self.FlyActive then
			self:CleanupFly()
			hum.WalkSpeed = self.OrigWalk
			hum.JumpPower = self.OrigJump
		end
	end
end

function Misc:UpdateStats()
	local _, hum = getLocalParts()
	if not hum then return end
	
	if Config.Misc.SpeedBypass then
		-- Use heartbeat to constantly reset speed (bypasses some detections)
		hum.WalkSpeed = Config.Misc.WalkSpeed
	else
		hum.WalkSpeed = Config.Misc.WalkSpeed
	end
	
	hum.JumpPower = Config.Misc.JumpPower
end

local jumpConn = nil
function Misc:UpdateInfiniteJump()
	if Config.Misc.InfiniteJump then
		if not jumpConn then
			jumpConn = UserInputService.JumpRequest:Connect(function()
				local _, h = getLocalParts()
				if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
			end)
		end
	elseif jumpConn then
		jumpConn:Disconnect()
		jumpConn = nil
	end
end

function Misc:UpdateAntiAFK()
	if Config.Misc.AntiAFK then
		if not self.AFKConnection then
			self.AFKConnection = LocalPlayer.Idled:Connect(function()
				local VirtualUser = game:GetService("VirtualUser")
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	elseif self.AFKConnection then
		self.AFKConnection:Disconnect()
		self.AFKConnection = nil
	end
end


--// Player Management
Players.PlayerAdded:Connect(function(p)
	if p ~= LocalPlayer then
		createESP(p)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	removeESP(p)
end)

for _, p in pairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then createESP(p) end
end

--// Character Respawn Handling
LocalPlayer.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	Misc.FlyActive = false
	Misc:CleanupFly()
	Misc:UpdateStats()
end)

--// Main Loop
Misc:UpdateStats()
Misc:UpdateInfiniteJump()
Misc:UpdateAntiAFK()

RunService.RenderStepped:Connect(function()
	updateFOV()
	
	-- Aimbot
	if Config.Aimbot.Enabled and Aimbot.Holding then
		local target = Aimbot:FindTarget()
		if target then
			Aimbot.Target = target
			Aimbot.LastTarget = target
			Aimbot:AimAt(target)
		end
	else
		Aimbot.Target = nil
		if not Aimbot.Holding then
			Aimbot.LastTarget = nil
		end
	end
	
	updateESP()
	Misc:UpdateFly()
	
	local _, hum = getLocalParts()
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not Config.Misc.NoFall)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not Config.Misc.NoFall)
		
		if Config.Misc.SpeedBypass then
			hum.WalkSpeed = Config.Misc.WalkSpeed
		end
	end
end)
--// Noclip Variables
local NoclipConnection = nil

--// Noclip Function
local function updateNoclip()
	if Config.Misc.Noclip then
		if not NoclipConnection then
			NoclipConnection = RunService.Stepped:Connect(function()
				local char = LocalPlayer.Character
				if char then
					for _, part in pairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end)
		end
	elseif NoclipConnection then
		NoclipConnection:Disconnect()
		NoclipConnection = nil
		-- Re-enable collision
		local char = LocalPlayer.Character
		if char then
			for _, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
			-- Keep HRP non-colliding for normal movement
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.CanCollide = false end
		end
	end
end
--// Add to your RenderStepped or create a new connection
RunService.RenderStepped:Connect(function()
	if Config.Misc.Noclip then
		updateNoclip()
	end
end)

--// Character respawn handling
LocalPlayer.CharacterAdded:Connect(function(char)
	if Config.Misc.Noclip then
		task.wait(0.1)
		updateNoclip()
	end
end)
function Misc:UpdateNoclip()
	if Config.Misc.Noclip then
		if not self.NoclipConnection then
			self.NoclipConnection = RunService.Stepped:Connect(function()
				local char = LocalPlayer.Character
				if not char then return end
				for _, part in pairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end)
		end
	elseif self.NoclipConnection then
		self.NoclipConnection:Disconnect()
		self.NoclipConnection = nil
	end
end
local function updateHeadExpanders()
	for _, player in pairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		
		local char = player.Character
		if not char then 
			-- Remove connection if character gone
			if HeadConnections[player] then
				HeadConnections[player]:Disconnect()
				HeadConnections[player] = nil
			end
			continue 
		end
		
		local head = char:FindFirstChild("Head")
		if not head then continue end
		
		-- Check team
		if Config.Misc.TeamCheck and isTeammate(player) then
			if HeadConnections[player] then
				HeadConnections[player]:Disconnect()
				HeadConnections[player] = nil
			end
			head.Size = Vector3.new(2, 1, 1) -- Reset to default
			continue
		end
		
		if Config.Misc.HeadExpanders > 1 then
			-- Set head size
			local size = Config.Misc.HeadExpanders
			head.Size = Vector3.new(size, size, size)
			head.Massless = true
			
			-- Keep size updated
			if not HeadConnections[player] then
				HeadConnections[player] = RunService.Heartbeat:Connect(function()
					if not head or not head.Parent then return end
					if Config.Misc.HeadExpanders > 1 then
						head.Size = Vector3.new(Config.Misc.HeadExpanders, Config.Misc.HeadExpanders, Config.Misc.HeadExpanders)
					end
				end)
			end
		else
			-- Reset
			if HeadConnections[player] then
				HeadConnections[player]:Disconnect()
				HeadConnections[player] = nil
			end
			head.Size = Vector3.new(2, 1, 1)
		end
	end
end
--// Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	if HeadConnections[player] then
		HeadConnections[player]:Disconnect()
		HeadConnections[player] = nil
	end
end)
--// Add to RenderStepped loop
RunService.RenderStepped:Connect(function()
	updateHeadExpanders()
end)


--// INSERT KEY MENU TOGGLE
local menuVisible = true

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Insert then
		menuVisible = not menuVisible

		if Library and Library.ToggleUI then
			Library:ToggleUI()
		end
	end
end)
print("DashClient Loaded! v2.0")
