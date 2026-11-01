-- Interfaccia del giocatore (statistiche, barra di avanzamento, negozio, notifiche)
-- e animazione/raccolta delle monete.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CollectCoin = remotes:WaitForChild("CollectCoin") :: RemoteEvent
local BuyItem = remotes:WaitForChild("BuyItem") :: RemoteFunction
local ResetProgress = remotes:WaitForChild("ResetProgress") :: RemoteEvent
local Notify = remotes:WaitForChild("Notify") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(35, 22, 45)
local GREEN = Color3.fromRGB(70, 190, 90)
local RED = Color3.fromRGB(255, 110, 110)

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function round(parent: Instance, radius: number?)
	new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function pad(parent: Instance, px: number)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

local gui = new("ScreenGui", {
	Name = "FugaDallaLavaHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

---------------------------------------------------------------------
-- Pannello statistiche
---------------------------------------------------------------------
local statsPanel = new("Frame", {
	Name = "Stats",
	Position = UDim2.fromOffset(16, 16),
	Size = UDim2.fromOffset(210, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	Parent = gui,
})
round(statsPanel, 12)
pad(statsPanel, 10)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = statsPanel })

local function statLabel(order: number, text: string): TextLabel
	return new("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		Parent = statsPanel,
	})
end
local coinsLabel = statLabel(1, "🪙 0")
local stageLabel = statLabel(2, "🏁 Livello 0 / " .. Config.NUM_STAGES)
local winsLabel = statLabel(3, "🏆 Vittorie: 0")

local function button(text: string, color: Color3, position: UDim2): TextButton
	local b = new("TextButton", {
		Text = text,
		Font = FONT,
		TextSize = 22,
		TextColor3 = WHITE,
		BackgroundColor3 = color,
		Position = position,
		Size = UDim2.fromOffset(210, 44),
		Parent = gui,
	})
	round(b, 10)
	new("UIStroke", {
		Thickness = 2,
		Transparency = 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = b,
	})
	return b
end
local shopButton = button("🛒 Negozio", Color3.fromRGB(255, 165, 40), UDim2.fromOffset(16, 140))
local resetButton = button("↺ Ricomincia", Color3.fromRGB(215, 60, 60), UDim2.fromOffset(16, 192))

---------------------------------------------------------------------
-- Barra di avanzamento
---------------------------------------------------------------------
local progressBack = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.new(0.4, 0, 0, 24),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	Parent = gui,
})
round(progressBack, 12)
new("UISizeConstraint", { MinSize = Vector2.new(200, 24), MaxSize = Vector2.new(460, 24), Parent = progressBack })
local progressFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(255, 110, 40),
	Parent = progressBack,
})
round(progressFill, 12)
local progressText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 16,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Text = "",
	ZIndex = 2,
	Parent = progressBack,
})

---------------------------------------------------------------------
-- Notifiche
---------------------------------------------------------------------
local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 1,
	TextTransparency = 1,
	Font = FONT,
	TextSize = 22,
	TextColor3 = WHITE,
	Text = "",
	Parent = gui,
})
round(toast, 10)
new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = toast })

local toastToken = 0
local function showToast(text: string, color: Color3?)
	toastToken += 1
	local myToken = toastToken
	toast.Text = text
	toast.TextColor3 = color or WHITE
	toast.BackgroundTransparency = 0.2
	toast.TextTransparency = 0
	task.delay(3, function()
		if myToken == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end
Notify.OnClientEvent:Connect(showToast)

---------------------------------------------------------------------
-- Negozio
---------------------------------------------------------------------
local shopFrame = new("Frame", {
	Name = "Shop",
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.9, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = PANEL,
	Parent = gui,
})
round(shopFrame, 16)
pad(shopFrame, 16)
new("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge), Parent = shopFrame })
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = shopFrame })
new("TextLabel", {
	LayoutOrder = 0,
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 30,
	TextColor3 = WHITE,
	Text = "🛒 Negozio",
	Parent = shopFrame,
})

for index, item in Config.SHOP do
	local row = new("Frame", {
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = Color3.fromRGB(60, 40, 75),
		Parent = shopFrame,
	})
	round(row, 10)
	new("TextLabel", {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -150, 0, 28),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 22,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = item.Name,
		Parent = row,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -150, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(210, 200, 225),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = item.Description,
		Parent = row,
	})
	local buy = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(120, 44),
		Font = FONT,
		TextSize = 20,
		TextColor3 = WHITE,
		Parent = row,
	})
	round(buy, 10)

	local attribute = "Owned_" .. item.Id
	local function refresh()
		if player:GetAttribute(attribute) then
			buy.Text = "✔ Tuo"
			buy.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
			buy.AutoButtonColor = false
		else
			buy.Text = item.Price .. " 🪙"
			buy.BackgroundColor3 = GREEN
			buy.AutoButtonColor = true
		end
	end
	refresh()
	player:GetAttributeChangedSignal(attribute):Connect(refresh)

	local busy = false
	buy.Activated:Connect(function()
		if busy or player:GetAttribute(attribute) then
			return
		end
		busy = true
		local ok, success, message = pcall(function()
			return BuyItem:InvokeServer(item.Id)
		end)
		busy = false
		if ok then
			showToast(message, if success then Color3.fromRGB(120, 255, 140) else RED)
		else
			showToast("Errore di connessione, riprova.", RED)
		end
	end)
end

local closeButton = new("TextButton", {
	LayoutOrder = 100,
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = Color3.fromRGB(90, 70, 110),
	Font = FONT,
	TextSize = 20,
	TextColor3 = WHITE,
	Text = "Chiudi",
	Parent = shopFrame,
})
round(closeButton, 10)

shopButton.Activated:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
end)
closeButton.Activated:Connect(function()
	shopFrame.Visible = false
end)

---------------------------------------------------------------------
-- Ricomincia (con conferma)
---------------------------------------------------------------------
local RESET_TEXT = "↺ Ricomincia"
local confirmUntil = 0
resetButton.Activated:Connect(function()
	if os.clock() < confirmUntil then
		confirmUntil = 0
		resetButton.Text = RESET_TEXT
		ResetProgress:FireServer()
	else
		confirmUntil = os.clock() + 3
		resetButton.Text = "Sicuro? Clicca ancora"
		task.delay(3, function()
			if os.clock() >= confirmUntil then
				resetButton.Text = RESET_TEXT
			end
		end)
	end
end)

---------------------------------------------------------------------
-- Monete: animazione e raccolta (lato client, validata dal server)
---------------------------------------------------------------------
local coinSound = new("Sound", {
	SoundId = "rbxasset://sounds/electronicpingshort.wav",
	Volume = 0.5,
	Parent = SoundService,
})

local activeCoins: { [BasePart]: { base: Vector3, offset: number } } = {}
local hiddenUntil: { [string]: number } = {}

local function registerCoin(coin: Instance)
	if coin:IsA("BasePart") then
		activeCoins[coin] = { base = coin.Position, offset = math.random() * math.pi * 2 }
	end
end

task.spawn(function()
	local coinsFolder = workspace:WaitForChild("Obby"):WaitForChild("Coins")
	coinsFolder.ChildAdded:Connect(registerCoin)
	coinsFolder.ChildRemoved:Connect(function(coin)
		activeCoins[coin :: BasePart] = nil
	end)
	for _, coin in coinsFolder:GetChildren() do
		registerCoin(coin)
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid ~= nil and humanoid.Health > 0

	for coin, info in activeCoins do
		if (hiddenUntil[coin.Name] or 0) > t then
			coin.Transparency = 1
			continue
		end
		coin.Transparency = 0
		local spin = t * 2.5 + info.offset
		coin.CFrame = CFrame.new(info.base + Vector3.new(0, math.sin(spin) * 0.4, 0)) * CFrame.Angles(0, spin, 0)

		if alive and root and (root.Position - info.base).Magnitude < Config.COIN_PICKUP_RADIUS then
			hiddenUntil[coin.Name] = t + Config.COIN_RESPAWN_TIME
			coin.Transparency = 1
			coinSound:Play()
			CollectCoin:FireServer(coin.Name)
		end
	end
end)

---------------------------------------------------------------------
-- Collegamento alle statistiche
---------------------------------------------------------------------
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats")
	local coinsValue = leaderstats:WaitForChild(Config.STAT_NAMES.Coins) :: IntValue
	local stageValue = leaderstats:WaitForChild(Config.STAT_NAMES.Stage) :: IntValue
	local winsValue = leaderstats:WaitForChild(Config.STAT_NAMES.Wins) :: IntValue

	local lastCoins = coinsValue.Value
	local function update()
		coinsLabel.Text = "🪙 " .. coinsValue.Value
		stageLabel.Text = ("🏁 Livello %d / %d"):format(stageValue.Value, Config.NUM_STAGES)
		winsLabel.Text = "🏆 Vittorie: " .. winsValue.Value

		local fraction = math.clamp(stageValue.Value / Config.NUM_STAGES, 0, 1)
		TweenService:Create(progressFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(fraction, 1) }):Play()
		progressText.Text = ("%d%% del percorso"):format(math.floor(fraction * 100))

		if coinsValue.Value > lastCoins then
			coinsLabel.TextSize = 30
			TweenService:Create(coinsLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), { TextSize = 22 }):Play()
		end
		lastCoins = coinsValue.Value
	end

	coinsValue.Changed:Connect(update)
	stageValue.Changed:Connect(update)
	winsValue.Changed:Connect(update)
	update()
end)
