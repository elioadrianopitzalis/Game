-- Genera proceduralmente il percorso a ostacoli sospeso sopra un mare di lava.
-- Non serve costruire nulla a mano in Studio: tutto viene creato all'avvio del server.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local PLATFORM_COLORS = {
	Color3.fromRGB(255, 111, 145),
	Color3.fromRGB(255, 190, 92),
	Color3.fromRGB(120, 220, 140),
	Color3.fromRGB(100, 180, 255),
	Color3.fromRGB(190, 140, 255),
}
local LAVA_COLOR = Color3.fromRGB(255, 80, 20)
local CHECKPOINT_COLOR = Color3.fromRGB(60, 200, 90)
local MOVER_COLOR = Color3.fromRGB(80, 160, 255)
local VANISH_COLOR = Color3.fromRGB(235, 245, 255)
local GOLD = Color3.fromRGB(255, 205, 50)

local SECTION_NAMES = { "Jumps", "LavaFloor", "Moving", "Spinner", "Vanishing" }

-- Stato della generazione
local rng: Random
local platformsFolder: Folder
local coinsFolder: Folder
local movers = {}
local spinners = {}
local vanishers = {}
local coins = {}
local coinCount = 0

local function newPart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function randomColor(): Color3
	return PLATFORM_COLORS[rng:NextInteger(1, #PLATFORM_COLORS)]
end

-- Piattaforma definita dalla superficie superiore: centro X, quota Y del piano, Z del bordo vicino.
local function platform(sizeX: number, sizeZ: number, x: number, topY: number, zStart: number, color: Color3?): Part
	return newPart(
		platformsFolder,
		Vector3.new(sizeX, 1, sizeZ),
		CFrame.new(x, topY - 0.5, zStart + sizeZ / 2),
		color or randomColor()
	)
end

local function makeKill(part: BasePart)
	part.Color = LAVA_COLOR
	part.Material = Enum.Material.Neon
	CollectionService:AddTag(part, "Kill")
end

local function addCoin(position: Vector3)
	coinCount += 1
	local coin = Instance.new("Part")
	coin.Name = "Coin" .. coinCount
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2.5, 2.5)
	coin.CFrame = CFrame.new(position)
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.Color = GOLD
	coin.Material = Enum.Material.Neon
	coin.Parent = coinsFolder
	coins[coin.Name] = coin
end

local function billboard(parent: BasePart, text: string, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 50)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
end

---------------------------------------------------------------------
-- Sezioni del percorso. Ognuna riceve il "cursore" (X centrale, quota Y,
-- Z del bordo finale dell'ultima piattaforma) e la difficoltà d (0..1),
-- e restituisce il nuovo cursore.
---------------------------------------------------------------------
local Sections = {}

-- Salti tra piattaforme sempre più piccole e distanti
function Sections.Jumps(cur: Vector3, d: number): Vector3
	local n = 4 + math.floor(d * 3)
	local x, y, z = cur.X, cur.Y, cur.Z
	for _ = 1, n do
		local size = math.max(3.5, 8 - d * 4 - rng:NextNumber(0, 1))
		local gap = 4 + d * 2.5 + rng:NextNumber(0, 1)
		x = math.clamp(x + rng:NextNumber(-5, 5), -14, 14)
		y += rng:NextNumber(-1, 1.5)
		z += gap
		platform(size, size, x, y, z)
		if rng:NextNumber() < 0.35 then
			addCoin(Vector3.new(x, y + 3, z + size / 2))
		end
		z += size
	end
	return Vector3.new(x, y, z)
end

-- Pavimento con strisce di lava da saltare
function Sections.LavaFloor(cur: Vector3, d: number): Vector3
	local width = 10
	local n = 3 + math.floor(d * 3)
	local x, y = cur.X, cur.Y
	local z = cur.Z + 3
	platform(width, 4, x, y, z)
	z += 4
	for _ = 1, n do
		local lavaLen = 3.5 + d * 3 + rng:NextNumber(0, 1)
		local lava = platform(width, lavaLen, x, y, z)
		makeKill(lava)
		if rng:NextNumber() < 0.5 then
			addCoin(Vector3.new(x, y + 4.5, z + lavaLen / 2))
		end
		z += lavaLen
		local safeLen = math.max(3, 6 - d * 3)
		platform(width, safeLen, x, y, z)
		z += safeLen
	end
	return Vector3.new(x, y, z)
end

-- Piattaforme che scorrono avanti e indietro
function Sections.Moving(cur: Vector3, d: number): Vector3
	local n = 3 + math.floor(d * 2)
	local x, y, z = cur.X, cur.Y, cur.Z
	for _ = 1, n do
		z += 3 + d * 2
		local size = 7
		local p = platform(size, size, x, y, z, MOVER_COLOR)
		p.Material = Enum.Material.Glass
		table.insert(movers, {
			part = p,
			base = p.CFrame,
			axis = Vector3.xAxis,
			amplitude = 6 + d * 6,
			speed = 1 + d * 1.2 + rng:NextNumber(0, 0.4),
			phase = rng:NextNumber(0, math.pi * 2),
		})
		z += size
	end
	return Vector3.new(x, y, z)
end

-- Disco con una (o due) barre di lava rotanti da saltare
function Sections.Spinner(cur: Vector3, d: number): Vector3
	local radius = 14
	local x, y = cur.X, cur.Y
	local z = cur.Z + 3
	local center = Vector3.new(x, y, z + radius)

	local disk = newPart(
		platformsFolder,
		Vector3.new(1, radius * 2, radius * 2),
		CFrame.new(center - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(240, 240, 250)
	)
	disk.Shape = Enum.PartType.Cylinder

	local hub = newPart(
		platformsFolder,
		Vector3.new(2.5, 3, 3),
		CFrame.new(center + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(60, 60, 70),
		Enum.Material.Metal
	)
	hub.Shape = Enum.PartType.Cylinder

	local barCount = if d > 0.5 then 2 else 1
	local speed = 1.2 + d * 1.8
	for i = 1, barCount do
		local pivot = CFrame.new(center + Vector3.new(0, 1.25, 0))
		local bar = newPart(platformsFolder, Vector3.new(radius * 2 - 1, 1, 1), pivot, LAVA_COLOR)
		makeKill(bar)
		table.insert(spinners, { part = bar, pivot = pivot, speed = speed, phase = (i - 1) * math.pi / 2 })
	end

	addCoin(center + Vector3.new(8, 3, 0))
	addCoin(center + Vector3.new(-8, 3, 0))
	return Vector3.new(x, y, z + radius * 2)
end

-- Piattaforme che scompaiono a ritmo
function Sections.Vanishing(cur: Vector3, d: number): Vector3
	local n = 4 + math.floor(d * 2)
	local x, y, z = cur.X, cur.Y, cur.Z
	local period = 4 - d
	for i = 1, n do
		z += 3.5
		local size = 6
		local p = platform(size, size, x, y, z, VANISH_COLOR)
		p.Material = Enum.Material.Ice
		table.insert(vanishers, { part = p, phase = i * 0.6, period = period, state = "" })
		if i == n then
			addCoin(Vector3.new(x, y + 3, z + size / 2))
		end
		z += size
	end
	return Vector3.new(x, y, z)
end

---------------------------------------------------------------------

local function checkpoint(stage: number, cur: Vector3): (BasePart, Vector3)
	local isStart = stage == 0
	local size = if isStart then 20 else 12
	local zStart = if isStart then cur.Z else cur.Z + 4

	local pad: BasePart
	if isStart then
		local spawnPad = Instance.new("SpawnLocation")
		spawnPad.Duration = 0
		spawnPad.Neutral = true
		pad = spawnPad
	else
		pad = Instance.new("Part")
	end
	pad.Name = if isStart then "Start" else "Checkpoint" .. stage
	pad.Anchored = true
	pad.Size = Vector3.new(size, 1, size)
	pad.CFrame = CFrame.new(cur.X, cur.Y - 0.5, zStart + size / 2)
	pad.Color = if isStart then GOLD else CHECKPOINT_COLOR
	pad.Material = Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad:SetAttribute("Stage", stage)
	billboard(pad, if isStart then "🔥 FUGA DALLA LAVA 🔥" else "Livello " .. stage, 6)
	pad.Parent = platformsFolder

	-- Bandierina decorativa
	local poleX = cur.X + size / 2 - 1
	local pole = newPart(platformsFolder, Vector3.new(0.5, 8, 0.5), CFrame.new(poleX, cur.Y + 4, zStart + 1), Color3.new(0.9, 0.9, 0.9))
	pole.CanCollide = false
	local flag = newPart(platformsFolder, Vector3.new(0.2, 2, 3), CFrame.new(poleX, cur.Y + 7, zStart + 2.5), pad.Color, Enum.Material.Neon)
	flag.CanCollide = false

	return pad, Vector3.new(cur.X, cur.Y, zStart + size)
end

local function buildFinish(cur: Vector3): (BasePart, number)
	local size = 24
	local zStart = cur.Z + 4
	platform(size, size, cur.X, cur.Y, zStart, GOLD)
	local center = Vector3.new(cur.X, cur.Y, zStart + size / 2)

	-- Arco del traguardo
	for _, side in { -1, 1 } do
		newPart(platformsFolder, Vector3.new(1.5, 10, 1.5), CFrame.new(center + Vector3.new(side * 6, 5, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.Marble)
	end
	local beam = newPart(platformsFolder, Vector3.new(13.5, 1.5, 1.5), CFrame.new(center + Vector3.new(0, 10.5, 0)), LAVA_COLOR, Enum.Material.Neon)
	billboard(beam, "🏆 TRAGUARDO 🏆", 3)

	local goal = newPart(platformsFolder, Vector3.new(8, 0.4, 8), CFrame.new(center + Vector3.new(0, 0.2, 0)), Color3.fromRGB(255, 240, 120), Enum.Material.Neon)
	goal.Name = "Traguardo"
	goal.CanCollide = false
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = GOLD
	sparkles.Parent = goal

	return goal, zStart + size
end

local function buildScenery(courseEnd: number)
	-- Mare di lava sotto al percorso (diviso in blocchi: le Part hanno un limite di 2048 stud)
	local seaY = Config.START_HEIGHT - 40
	local z = -200
	while z < courseEnd + 200 do
		local sea = newPart(platformsFolder, Vector3.new(800, 4, 1000), CFrame.new(0, seaY, z + 500), LAVA_COLOR, Enum.Material.CrackedLava)
		sea.Name = "MareDiLava"
		CollectionService:AddTag(sea, "Kill")
		z += 1000
	end

	-- Nuvole decorative
	for _ = 1, 70 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local cloud = newPart(
			platformsFolder,
			Vector3.one * rng:NextNumber(10, 28),
			CFrame.new(side * rng:NextNumber(45, 140), Config.START_HEIGHT + rng:NextNumber(-25, 40), rng:NextNumber(-50, courseEnd + 50)),
			Color3.new(1, 1, 1)
		)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = 0.25
		cloud.CanCollide = false
		cloud.CanTouch = false
		cloud.CanQuery = false
		cloud.CastShadow = false
	end
end

local function setupLighting()
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Color = Color3.fromRGB(255, 200, 160)
		atmosphere.Decay = Color3.fromRGB(255, 120, 80)
		atmosphere.Glare = 0.4
		atmosphere.Haze = 1.5
		atmosphere.Parent = Lighting
	end
end

local function startAnimations()
	RunService.Heartbeat:Connect(function()
		local t = os.clock()

		for _, m in movers do
			local angle = t * m.speed + m.phase
			m.part.CFrame = m.base + m.axis * (m.amplitude * math.sin(angle))
			-- La velocità fa sì che il giocatore venga trasportato dalla piattaforma
			m.part.AssemblyLinearVelocity = m.axis * (m.amplitude * m.speed * math.cos(angle))
		end

		for _, s in spinners do
			s.part.CFrame = s.pivot * CFrame.Angles(0, t * s.speed + s.phase, 0)
		end

		for _, v in vanishers do
			local cycle = ((t + v.phase) % v.period) / v.period
			local state = if cycle < 0.6 then "solid" elseif cycle < 0.8 then "warning" else "gone"
			if state ~= v.state then
				v.state = state
				v.part.Transparency = if state == "solid" then 0 elseif state == "warning" then 0.5 else 0.9
				v.part.CanCollide = state ~= "gone"
			end
		end
	end)
end

local function pickSection(stage: number, last: string?): string
	if stage == 1 then
		return "Jumps"
	elseif stage == 2 then
		return "LavaFloor"
	end
	local name
	repeat
		name = SECTION_NAMES[rng:NextInteger(1, #SECTION_NAMES)]
	until name ~= last
	return name
end

export type Map = {
	checkpoints: { [number]: BasePart },
	finish: BasePart,
	coins: { [string]: BasePart },
}

function MapBuilder.build(): Map
	rng = Random.new(Config.MAP_SEED)

	local root = Instance.new("Folder")
	root.Name = "Obby"
	platformsFolder = Instance.new("Folder")
	platformsFolder.Name = "Platforms"
	platformsFolder.Parent = root
	coinsFolder = Instance.new("Folder")
	coinsFolder.Name = "Coins"
	coinsFolder.Parent = root

	local checkpoints = {}
	local cur = Vector3.new(0, Config.START_HEIGHT, -10)
	local pad
	pad, cur = checkpoint(0, cur)
	checkpoints[0] = pad

	local last = nil
	for stage = 1, Config.NUM_STAGES do
		local difficulty = (stage - 1) / math.max(1, Config.NUM_STAGES - 1)
		local name = pickSection(stage, last)
		cur = Sections[name](cur, difficulty)
		last = name
		pad, cur = checkpoint(stage, cur)
		checkpoints[stage] = pad
	end

	local finish, courseEnd = buildFinish(cur)
	buildScenery(courseEnd)
	setupLighting()

	root.Parent = workspace
	startAnimations()

	return {
		checkpoints = checkpoints,
		finish = finish,
		coins = coins,
	}
end

return MapBuilder
