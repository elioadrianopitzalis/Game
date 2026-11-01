-- Configurazione condivisa tra server e client.
-- Modifica questi valori per cambiare difficoltà, ricompense e negozio.

local Config = {
	GAME_NAME = "Fuga dalla Lava",

	-- Percorso
	NUM_STAGES = 30, -- numero di livelli (checkpoint) prima del traguardo
	MAP_SEED = 2026, -- cambia il seme per generare un percorso diverso
	START_HEIGHT = 100, -- altezza del punto di partenza

	-- Monete
	COIN_VALUE = 1,
	COIN_RESPAWN_TIME = 45, -- secondi prima che una moneta ricompaia (per giocatore)
	COIN_PICKUP_RADIUS = 4,

	-- Ricompense
	CHECKPOINT_REWARD = 2, -- monete per ogni nuovo checkpoint raggiunto
	FINISH_REWARD = 50, -- monete per aver completato il percorso

	-- Personaggio
	BASE_WALKSPEED = 16,
	BASE_JUMPHEIGHT = 7.2,

	-- Salvataggi
	DATASTORE_NAME = "FugaDallaLava_v1",
	AUTOSAVE_INTERVAL = 120,

	-- Nomi mostrati nella classifica (leaderstats)
	STAT_NAMES = {
		Stage = "Livello",
		Coins = "Monete",
		Wins = "Vittorie",
	},

	-- Negozio. Kind: "WalkSpeed" | "JumpHeight" | "Trail"
	SHOP = {
		{
			Id = "SpeedBoost",
			Name = "Scarpe Veloci",
			Description = "Corri il 50% più veloce",
			Price = 30,
			Kind = "WalkSpeed",
			Value = 24,
		},
		{
			Id = "JumpBoost",
			Name = "Molla Magica",
			Description = "Salti molto più in alto",
			Price = 60,
			Kind = "JumpHeight",
			Value = 10,
		},
		{
			Id = "GoldTrail",
			Name = "Scia Dorata",
			Description = "Lasci una scia di fuoco dorato",
			Price = 100,
			Kind = "Trail",
		},
	},
}

return Config
