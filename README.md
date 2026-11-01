# 🔥 Fuga dalla Lava

Un obby (percorso a ostacoli) per **Roblox** sospeso sopra un mare di lava.
Supera 30 livelli di difficoltà crescente, raccogli monete, compra potenziamenti
e raggiungi il traguardo!

## Caratteristiche

- **30 livelli generati proceduralmente**: il percorso viene costruito via script all'avvio, quindi non serve modellare nulla in Studio. Cambia `MAP_SEED` in `Config.luau` per avere un percorso diverso.
- **5 tipi di ostacolo**:
  - 🟦 Salti tra piattaforme che si rimpiccioliscono
  - 🟥 Pavimento con strisce di lava
  - 🔵 Piattaforme mobili
  - ⚪ Disco con barre di lava rotanti (doppie nella seconda metà)
  - 🧊 Piattaforme di ghiaccio che scompaiono a ritmo
- **Checkpoint** con respawn automatico all'ultimo livello raggiunto
- **Monete** da raccogliere (anche sopra la lava, per i più coraggiosi) + ricompense per checkpoint e traguardo
- **Negozio**: Scarpe Veloci, Molla Magica, Scia Dorata
- **Salvataggio dei progressi** con DataStore (livello, monete, vittorie, oggetti)
- **Classifica** (Livello / Monete / Vittorie) e HUD con barra di avanzamento
- Controlli anti-imbroglio lato server (niente salti di checkpoint, monete validate per distanza e tempo)

## Struttura

```
default.project.json        Progetto Rojo (mappa le cartelle nei servizi di Roblox)
src/shared/Config.luau      → ReplicatedStorage.Shared.Config   (tutte le impostazioni)
src/server/MapBuilder.luau  → ServerScriptService.Server         (genera la mappa)
src/server/Main.server.luau → ServerScriptService.Server         (logica di gioco e salvataggi)
src/client/HUD.client.luau  → StarterPlayerScripts.Client        (interfaccia e monete)
```

## Come avviarlo in Roblox Studio

### Opzione A — Rojo (consigliata)

1. Installa [Rokit](https://github.com/rojo-rbx/rokit) e, nella cartella del progetto, esegui:
   ```bash
   rokit install
   ```
2. Installa il plugin Rojo in Roblox Studio (`rojo plugin install`).
3. Avvia il server di sincronizzazione:
   ```bash
   rojo serve
   ```
4. In Studio apri una **Baseplate** nuova, elimina la `Baseplate` e la `SpawnLocation` presenti, apri il plugin Rojo e premi **Connect**.
5. Premi **Play** ▶️.

In alternativa puoi creare direttamente il file del gioco:
```bash
rojo build -o FugaDallaLava.rbxlx
```
e aprirlo con Roblox Studio.

### Opzione B — Copia e incolla manuale

1. In Studio crea in **ReplicatedStorage** una `Folder` chiamata `Shared` con dentro un `ModuleScript` chiamato `Config` → incolla `src/shared/Config.luau`.
2. In **ServerScriptService** crea una `Folder` chiamata `Server` con dentro:
   - un `ModuleScript` chiamato `MapBuilder` → incolla `src/server/MapBuilder.luau`
   - uno `Script` chiamato `Main` → incolla `src/server/Main.server.luau`
3. In **StarterPlayer › StarterPlayerScripts** crea un `LocalScript` chiamato `HUD` → incolla `src/client/HUD.client.luau`.
4. Elimina la `Baseplate` e la `SpawnLocation` di default e premi **Play**.

## Pubblicazione

1. **File › Publish to Roblox** in Studio.
2. Per far funzionare i salvataggi: **Game Settings › Security › Enable Studio Access to API Services** (in Studio) — sui server pubblicati i DataStore funzionano automaticamente.

## Personalizzazione

Tutto si regola in `src/shared/Config.luau`: numero di livelli, seme della mappa,
ricompense, velocità base, prezzi e oggetti del negozio.
