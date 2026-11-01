-- Logica principale del server: dati dei giocatori, checkpoint, lava, monete, negozio, traguardo.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))

local map = MapBuilder.build()

---------------------------------------------------------------------
-- Remote
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function makeRemote(className: string, name: string)
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end
local CollectCoin = makeRemote("RemoteEvent", "CollectCoin") :: RemoteEvent
local BuyItem = makeRemote("RemoteFunction", "BuyItem") :: RemoteFunction
local ResetProgress = makeRemote("RemoteEvent", "ResetProgress") :: RemoteEvent
local Notify = makeRemote("RemoteEvent", "Notify") :: RemoteEvent
remotes.Parent = ReplicatedStorage

local shopById = {}
for _, item in Config.SHOP do
	shopById[item.Id] = item
end

local GREEN = Color3.fromRGB(120, 255, 140)
local RED = Color3.fromRGB(255, 110, 110)
local GOLD = Color3.fromRGB(255, 215, 60)

---------------------------------------------------------------------
-- Dati dei giocatori
---------------------------------------------------------------------
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Fuga dalla Lava] DataStore non disponibile:", result)
	end
end

type Session = {
	Stage: number,
	Coins: number,
	Wins: number,
	Finished: boolean,
	Owned: { [string]: boolean },
	canSave: boolean,
	coinTimes: { [string]: number },
	lastReset: number,
}

local sessions: { [Player]: Session } = {}

local function dataKey(player: Player): string
	return "player_" .. player.UserId
end

local function loadData(player: Player)
	local data = { Stage = 0, Coins = 0, Wins = 0, Finished = false, Owned = {} }
	if not store then
		return data, false
	end
	local ok, result = pcall(function()
		return (store :: DataStore):GetAsync(dataKey(player))
	end)
	if not ok then
		warn("[Fuga dalla Lava] Impossibile caricare i dati di " .. player.Name .. ": " .. tostring(result))
		return data, false
	end
	if type(result) == "table" then
		data.Stage = math.clamp(math.floor(tonumber(result.Stage) or 0), 0, Config.NUM_STAGES)
		data.Coins = math.max(0, math.floor(tonumber(result.Coins) or 0))
		data.Wins = math.max(0, math.floor(tonumber(result.Wins) or 0))
		data.Finished = result.Finished == true
		if type(result.Owned) == "table" then
			for _, id in result.Owned do
				if shopById[id] then
					data.Owned[id] = true
				end
			end
		end
	end
	return data, true
end

local function saveData(player: Player)
	local s = sessions[player]
	if not s or not s.canSave or not store then
		return
	end
	local owned = {}
	for id in s.Owned do
		table.insert(owned, id)
	end
	local payload = { Stage = s.Stage, Coins = s.Coins, Wins = s.Wins, Finished = s.Finished, Owned = owned }
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(dataKey(player), payload, { player.UserId })
	end)
	if not ok then
		warn("[Fuga dalla Lava] Salvataggio fallito per " .. player.Name .. ": " .. tostring(err))
	end
end

local function setStat(player: Player, key: string, value: number)
	local s = sessions[player]
	if not s then
		return
	end
	(s :: any)[key] = value
	local leaderstats = player:FindFirstChild("leaderstats")
	local stat = leaderstats and leaderstats:FindFirstChild(Config.STAT_NAMES[key])
	if stat then
		(stat :: IntValue).Value = value
	end
end

local function notify(player: Player, text: string, color: Color3?)
	Notify:FireClient(player, text, color)
end

local function playerFromHit(hit: BasePart): (Player?, Humanoid?)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return player, humanoid
end

---------------------------------------------------------------------
-- Personaggio: potenziamenti e respawn al checkpoint
---------------------------------------------------------------------
local function applyUpgrades(player: Player, character: Model)
	local s = sessions[player]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not s or not humanoid then
		return
	end

	humanoid.WalkSpeed = Config.BASE_WALKSPEED
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.BASE_JUMPHEIGHT

	for id in s.Owned do
		local item = shopById[id]
		if item.Kind == "WalkSpeed" then
			humanoid.WalkSpeed = item.Value
		elseif item.Kind == "JumpHeight" then
			humanoid.JumpHeight = item.Value
		elseif item.Kind == "Trail" and root and not root:FindFirstChild("GoldTrail") then
			local top = Instance.new("Attachment")
			top.Name = "TrailTop"
			top.Position = Vector3.new(0, 0.8, 0)
			top.Parent = root
			local bottom = Instance.new("Attachment")
			bottom.Name = "TrailBottom"
			bottom.Position = Vector3.new(0, -0.8, 0)
			bottom.Parent = root
			local trail = Instance.new("Trail")
			trail.Name = "GoldTrail"
			trail.Attachment0 = top
			trail.Attachment1 = bottom
			trail.Lifetime = 0.6
			trail.LightEmission = 1
			trail.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 110, 30))
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = root
		end
	end
end

local function sendToCheckpoint(player: Player, character: Model)
	local s = sessions[player]
	if not s then
		return
	end
	local pad = map.checkpoints[s.Stage] or map.checkpoints[0]
	local target = pad.CFrame * CFrame.new(0, pad.Size.Y / 2 + 3.5, 0)
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 3)
	end)
	if character.Parent then
		character:PivotTo(target)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("Humanoid", 10)
	if not character.Parent then
		character.AncestryChanged:Wait()
	end
	task.wait() -- lascia completare lo spawn predefinito
	if player.Character ~= character then
		return
	end
	applyUpgrades(player, character)
	sendToCheckpoint(player, character)
end

---------------------------------------------------------------------
-- Ingresso / uscita giocatori
---------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local data, canSave = loadData(player)
	if not player.Parent then
		return -- è uscito durante il caricamento
	end

	sessions[player] = {
		Stage = data.Stage,
		Coins = data.Coins,
		Wins = data.Wins,
		Finished = data.Finished,
		Owned = data.Owned,
		canSave = canSave,
		coinTimes = {},
		lastReset = 0,
	}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, key in { "Stage", "Coins", "Wins" } do
		local value = Instance.new("IntValue")
		value.Name = Config.STAT_NAMES[key]
		value.Value = (data :: any)[key]
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	for id in data.Owned do
		player:SetAttribute("Owned_" .. id, true)
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	if data.Stage > 0 then
		notify(player, "Bentornato! Riprendi dal livello " .. data.Stage)
	else
		notify(player, "Benvenuto! Raggiungi il traguardo senza toccare la lava 🔥")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	sessions[player] = nil
end)

game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			saveData(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			task.spawn(saveData, player)
		end
	end
end)

---------------------------------------------------------------------
-- Lava e ostacoli mortali
---------------------------------------------------------------------
local function connectKill(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	part.Touched:Connect(function(hit)
		local _, humanoid = playerFromHit(hit)
		if humanoid then
			humanoid.Health = 0
		end
	end)
end
for _, part in CollectionService:GetTagged("Kill") do
	connectKill(part)
end
CollectionService:GetInstanceAddedSignal("Kill"):Connect(connectKill)

---------------------------------------------------------------------
-- Checkpoint
---------------------------------------------------------------------
for stage, pad in map.checkpoints do
	if stage == 0 then
		continue
	end
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local s = player and sessions[player]
		if not player or not s or stage ~= s.Stage + 1 then
			return
		end
		setStat(player, "Stage", stage)
		setStat(player, "Coins", s.Coins + Config.CHECKPOINT_REWARD)
		notify(player, ("Livello %d / %d raggiunto! +%d 🪙"):format(stage, Config.NUM_STAGES, Config.CHECKPOINT_REWARD), GREEN)
	end)
end

---------------------------------------------------------------------
-- Traguardo
---------------------------------------------------------------------
map.finish.Touched:Connect(function(hit)
	local player = playerFromHit(hit)
	local s = player and sessions[player]
	if not player or not s or s.Finished or s.Stage < Config.NUM_STAGES then
		return
	end
	s.Finished = true
	setStat(player, "Wins", s.Wins + 1)
	setStat(player, "Coins", s.Coins + Config.FINISH_REWARD)
	notify(player, ("🏆 Ce l'hai fatta! +%d 🪙 — premi «Ricomincia» per rigiocare"):format(Config.FINISH_REWARD), GOLD)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			notify(other, "🏆 " .. player.DisplayName .. " è sfuggito alla lava!", GOLD)
		end
	end
	task.spawn(saveData, player)
end)

---------------------------------------------------------------------
-- Monete (la raccolta è gestita dal client, il server la valida)
---------------------------------------------------------------------
CollectCoin.OnServerEvent:Connect(function(player, coinId)
	if typeof(coinId) ~= "string" then
		return
	end
	local coin = map.coins[coinId]
	local s = sessions[player]
	if not coin or not s then
		return
	end

	local now = os.clock()
	local last = s.coinTimes[coinId]
	if last and now - last < Config.COIN_RESPAWN_TIME - 1 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - coin.Position).Magnitude > Config.COIN_PICKUP_RADIUS + 10 then
		return
	end

	s.coinTimes[coinId] = now
	setStat(player, "Coins", s.Coins + Config.COIN_VALUE)
end)

---------------------------------------------------------------------
-- Negozio
---------------------------------------------------------------------
BuyItem.OnServerInvoke = function(player, itemId)
	local s = sessions[player]
	local item = if typeof(itemId) == "string" then shopById[itemId] else nil
	if not s or not item then
		return false, "Oggetto non valido."
	end
	if s.Owned[item.Id] then
		return false, "Possiedi già questo oggetto."
	end
	if s.Coins < item.Price then
		return false, ("Ti servono ancora %d 🪙"):format(item.Price - s.Coins)
	end

	setStat(player, "Coins", s.Coins - item.Price)
	s.Owned[item.Id] = true
	player:SetAttribute("Owned_" .. item.Id, true)
	if player.Character then
		applyUpgrades(player, player.Character)
	end
	task.spawn(saveData, player)
	return true, "Hai comprato " .. item.Name .. "!"
end

---------------------------------------------------------------------
-- Ricomincia dall'inizio
---------------------------------------------------------------------
ResetProgress.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or os.clock() - s.lastReset < 3 then
		return
	end
	s.lastReset = os.clock()
	s.Finished = false
	setStat(player, "Stage", 0)
	player:LoadCharacter()
	notify(player, "Si riparte! Buona fortuna 🔥")
end)
